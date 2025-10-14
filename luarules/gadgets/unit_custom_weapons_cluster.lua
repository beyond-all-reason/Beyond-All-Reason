local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Cluster Munitions',
		desc    = 'Projectiles split and scatter on impact.',
		author  = 'efrec',
		version = '1.1',
		date    = '2024-06-07',
		license = 'GNU GPL, v2 or later',
		layer   = 10, -- before fx_watersplash; Explosion is reverse iterated
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return false end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

-- Default settings ------------------------------------------------------------

local defaultSpawnTtl = 5		 -- detonate projectiles after time = ttl, by default

-- General settings ------------------------------------------------------------

local minSpawnNumber = 3         -- minimum number of spawned projectiles
local maxSpawnNumber = 24        -- protect game performance against stupid ideas
local minUnitBounces = "armpw"   -- smallest unit (name) that "bounces" projectiles at all
local minBulkReflect = 500       -- smallest unit bulk that "reflects" as if terrain
local waterDepthCoef = 0.1       -- reduce "separation" from ground in water by a multiple

-- CustomParams setup ----------------------------------------------------------
--
--   weapon = {
--       type := "Cannon"
--       customparams = {
--           cluster_def    := <string> | nil (see defaults)
--           cluster_number := <number> | nil (see defaults)
--       },
--   },
--  
--   <cluster_def> = {
--       weaponvelocity := <number> -- Will be ignored in favor of range if possible.
--       range          := <number> -- Preferred over and replaces weaponvelocity.
--   }

--------------------------------------------------------------------------------
-- Localize --------------------------------------------------------------------

local DirectionsUtil = VFS.Include("LuaRules/Gadgets/Include/DirectionsUtil.lua")

local max   = math.max
local min   = math.min
local rand  = math.random
local diag  = math.diag
local sqrt  = math.sqrt
local cos   = math.cos
local sin   = math.sin
local atan2 = math.atan2

local spGetGroundHeight       = Spring.GetGroundHeight
local spGetGroundNormal       = Spring.GetGroundNormal
local spGetUnitDefID          = Spring.GetUnitDefID
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetUnitRadius         = Spring.GetUnitRadius
local spGetUnitsInSphere      = Spring.GetUnitsInSphere
local spSpawnProjectile       = Spring.SpawnProjectile

local gameSpeed  = Game.gameSpeed
local mapGravity = Game.gravity / (gameSpeed * gameSpeed) * -1

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

local maxUnitRadius = 0

for _, unitDef in pairs(UnitDefs) do
	maxUnitRadius = max(maxUnitRadius, unitDef.radius)
end

defaultSpawnTtl = defaultSpawnTtl * gameSpeed

local spawnableTypes = {
	Cannon = true,
}

local clusterWeaponDefs = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	for _, weapon in pairs(unitDef.weapons) do
		local weaponDefID, weaponDef = weapon.weaponDef, WeaponDefs[weapon.weaponDef]
		local clusterDefName = weaponDef.customParams.cluster_def

		if clusterDefName then
			local clusterDef = WeaponDefNames[clusterDefName]
			local clusterCount = tonumber(weaponDef.customParams.cluster_number)

			if clusterCount < minSpawnNumber or clusterCount > maxSpawnNumber then
				Spring.Log(gadget:GetInfo().name, LOG.WARNING, weaponDef.name .. ': cluster_count of ' .. clusterCount .. ', clamping to ' .. minSpawnNumber .. '-' .. maxSpawnNumber)
				clusterCount = math.clamp(clusterCount, minSpawnNumber, maxSpawnNumber)
			end

			if clusterDef then
				if spawnableTypes[clusterDef.type] then
					local clusterRange = clusterDef.range or 0
					local clusterSpeed
					if clusterRange > 0 then
						clusterSpeed = sqrt(clusterRange * math.abs(mapGravity)) -- velocity @ 45deg to hit range
					else
						clusterSpeed = clusterDef.projectilespeed
					end

					clusterWeaponDefs[weaponDefID] = {
						number      = clusterCount,
						weaponID    = clusterDef.id,
						weaponSpeed = clusterSpeed,
						weaponTtl   = clusterDef.flighttime or defaultSpawnTtl,
					}
				else
					Spring.Log(gadget:GetInfo().name, LOG.ERROR, 'Invalid weapon spawn type: ' .. clusterDef.type)
				end
			else
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, 'Could not find weapon def matching cluster_def: ' .. clusterDefName)
			end
		end
	end
end

local removeIDs = {}
for weaponDefID, weaponData in pairs(clusterWeaponDefs) do
	if clusterWeaponDefs[weaponData.weaponID] and clusterWeaponDefs[clusterWeaponDefs[weaponData.weaponID].weaponID] then
		removeIDs[weaponData.weaponID] = true
	end
end
for weaponDefID in pairs(removeIDs) do
	Spring.Log(gadget:GetInfo().name, LOG.ERROR, 'Preventing nested explosions: ' .. WeaponDefs[weaponDefID].name)
	clusterWeaponDefs[weaponDefID] = nil
end

local unitBulks = {} -- Projectiles scatter away more against higher bulk values.

local function getUnitVolume(unitDef)
	local mo = unitDef.model
	local dx = mo.maxx - mo.minx
	local dy = mo.maxy - mo.miny
	local dz = mo.maxz - mo.minz
	local volume = dx * dy * dz

	local cv = unitDef.collisionVolume

	if cv.type == "sphere" or cv.type == "ellipsoid" then
		-- (4/3)πr => (1/6)πABC
		return volume * math.pi / 6
	elseif cv.type == "cylinder" then
		-- πr²h => (1/4)πABc
		return volume * math.pi / 4
	else
		return volume
	end
end

local useCrushingMass = {
	wall           = true,
	indestructable = true,
}

local bulkDepth = 1

local function getUnitBulk(unitDef)
	-- Even with lower mass/metal, people see "bigger" as "more solid". Ape brain:
	local volume = getUnitVolume(unitDef)

	-- Height contributes less bulk, but tall units don't benefit as much from ground deflection.
	-- Lower units, like Bulls, basically gain ground deflection on top of their unit deflection.
	local height = math.clamp(unitDef.height, 1, 30) -- So set a height cap.

	-- NB: Mass is absolutely useless. Do not use mass.
	local fromHealth = sqrt(unitDef.health) -- [1, 1000000] => [1, 1000] approx
	local fromMetal = sqrt(unitDef.metalCost) -- [0, 50000] => [0, 250] approx
	local fromVolume = sqrt(volume / height) -- [0, 20000] => [1, 1000] approx

	if useCrushingMass[unitDef.armorType] and unitDef.moveDef then
		fromMetal = max(fromMetal, sqrt(unitDef.moveDef.crushStrength))
	end

	local bulkiness = (fromHealth + fromMetal + fromVolume) + sqrt(fromHealth * fromMetal)
	bulkiness = math.clamp(bulkiness / minBulkReflect, 0, 1) -- Scaled vs. 100% terrain-like.
	bulkiness = bulkiness ^ 0.57 -- Curve bulks upward, toward 1, to be much more noticeable.

	if unitDef.customParams.decoyfor then
		local decoyDef = UnitDefNames[unitDef.customParams.decoyfor]
		if decoyDef then
			if bulkDepth + 1 > 4 then
				Spring.Echo("weapons_cluster", "bulkDepth exceeded", unitDef.name)
				return 0
			end
			bulkDepth = bulkDepth + 1
			local decoyBulk = unitBulks[decoyDef.id] or getUnitBulk(decoyDef)
			bulkDepth = bulkDepth - 1
			bulkiness = (bulkiness + decoyBulk) * 0.5 -- cheat slightly
		end
	end

	return bulkiness
end

for unitDefID, unitDef in pairs(UnitDefs) do
	local bulk = 0
	if not (unitDef.customParams.decoration or unitDef.customParams.virtualunit) then
		bulk = tonumber(unitDef.customParams.bulk_rating) or getUnitBulk(unitDef)
	end
	unitBulks[unitDefID] = bulk
end

local bulkMin = UnitDefs[minUnitBounces] and unitBulks[UnitDefs[minUnitBounces].id] or 0.1

for unitDefID in pairs(UnitDefs) do
	if unitBulks[unitDefID] < bulkMin then
		unitBulks[unitDefID] = nil
	end
end

local spawnCache  = {
	pos     = { 0, 0, 0 },
	speed   = { 0, 0, 0 },
	owner   = 0,
	ttl     = defaultSpawnTtl,
	gravity = mapGravity,
}

local directions = DirectionsUtil.Directions
local maxDataNum = 2
for _, data in pairs(clusterWeaponDefs) do
	if data.number > maxDataNum then maxDataNum = data.number end
end
DirectionsUtil.ProvisionDirections(maxDataNum)

--------------------------------------------------------------------------------
-- Functions -------------------------------------------------------------------

-- Treat water as the dominant term, with a max deflection, past a given depth.
local waterDepthDeflects = 1 / waterDepthCoef
local waterFullDeflection = 0.85 -- 1 - vertical response loss

---Water is generally incompressible so acts like solid terrain of lower density
-- when it takes hard impacts or impulses. We take a fast estimate of its added
-- bulk to the solid terrain below and shift the surface direction toward level.
---@param slope number in radians? in what? is this [0, 1]?
---@param elevation number in elmos, always negative
---@return number percentX
---@return number percentY
---@return number percentZ
---@return number depth
local function getWaterDeflection(slope, elevation)
	elevation = max(elevation * waterDepthCoef, waterDepthDeflects)
	local waterDeflectFraction = min(1, elevation / waterDepthDeflects)

	if slope == 1 and waterDeflectFraction == 1 then
		return 0, waterFullDeflection, 0, elevation
	else
		slope = slope * (1 - waterDeflectFraction)
		local dy = waterFullDeflection * (1 - slope)
		local dxz = 1 - slope
		return dxz, dy, dxz, elevation
	end
end

---Deflection from solid terrain and unit collider surfaces plus water by depth.
local function getSurfaceDeflection(x, y, z)
	local elevation = spGetGroundHeight(x, z)
	local separation = y - elevation
	local dx, dy, dz, slope = spGetGroundNormal(x, z, true)

	-- On sloped terrain, the nearest point on the surface is up the slope.
	if slope > 0.1 or slope * separation > 10 then
		local shiftXZ = separation * cos(slope) * sin(slope) / diag(dx, dz)
		local shiftX = x - dx * shiftXZ -- Next surface x, z
		local shiftZ = z - dz * shiftXZ
		elevation = max(elevation, spGetGroundHeight(shiftX, shiftZ))
		dx, dy, dz, slope = spGetGroundNormal(shiftX, shiftZ, true)
		separation = y - elevation
	end

	if elevation < 0 then
		local px, py, pz, depth = getWaterDeflection(slope, elevation)
		dx, dy, dz = dx * px, dy * py, dz * pz
		separation = y - depth
	end

	-- Terrain can have a concave contour, so we need this extra ~30%.
	-- Unit max bulk is 1.0 which is fine, since colliders are convex.
	separation = 1.3 / diag(max(1, separation))
	dx = dx * separation
	dy = dy * separation
	dz = dz * separation

	-- Additional deflection from units, from none to solid-terrain-like.
	local unitsNearby = spGetUnitsInSphere(x, y, z, maxUnitRadius)
	local bounce, unitX, unitY, unitZ, radius

	for _, unitID in ipairs(unitsNearby) do
		bounce = unitBulks[spGetUnitDefID(unitID)]
		if bounce then
			_,_,_,unitX,unitY,unitZ = spGetUnitPosition(unitID, true)
			radius = spGetUnitRadius(unitID)
			if unitY + radius > 0 then
				unitX, unitY, unitZ = x - unitX, y - unitY, z - unitZ
				separation = diag(unitX, unitY, unitZ) / radius
				-- Even assuming that the explosion is near to the collider,
				-- past some N x radius, we would not expect any deflection:
				if separation < 2 then
					bounce = bounce / max(1, separation)
					local theta_z = atan2(unitX, unitZ)
					local phi_y = atan2(unitY, diag(unitX, unitZ))
					local cosy = cos(phi_y)
					dx = dx + bounce * sin(theta_z) * cosy
					dy = dy + bounce * sin(phi_y)
					dz = dz + bounce * cos(theta_z) * cosy
				end
			end
		end
	end

	return dx, dy, dz
end

local function inheritMomentum(projectileID)
	local vx, vy, vz, vw = Spring.GetProjectileVelocity(projectileID)
	-- Apply major loss from scattering (~50%) and reduce hyperspeeds (1 is convenient).
	local scale = 0.5 / max(vw, 1)
	return vx * scale, vy * scale, vz * scale
end

local function spawnClusterProjectiles(data, x, y, z, attackerID, projectileID)
	local clusterDefID = data.weaponID
	local projectileCount = data.number
	local projectileSpeed = data.weaponSpeed
	local randomness = 1 / sqrt(projectileCount - 2) + 0.1

	local params = spawnCache
	params.owner = attackerID or -1
	params.ttl = data.weaponTtl
	local speed = params.speed
	local position = params.pos

	local deflectX, deflectY, deflectZ = getSurfaceDeflection(x, y, z)
	local inheritX, inheritY, inheritZ = inheritMomentum(projectileID)
	local startX = deflectX + inheritX
	local startY = deflectY + inheritY
	local startZ = deflectZ + inheritZ

	local directionVectors = directions[projectileCount]

	for i = 0, projectileCount - 1 do
		local velocityX = directionVectors[3 * i + 1] + startX
		local velocityY = directionVectors[3 * i + 2] + startY
		local velocityZ = directionVectors[3 * i + 3] + startZ
		local velocityW

		repeat
			velocityX = velocityX + (rand() - 0.5) * randomness * 2
			velocityY = velocityY + (rand() - 0.5) * randomness * 2
			velocityZ = velocityZ + (rand() - 0.5) * randomness * 2
			velocityW = diag(velocityX, velocityY, velocityZ)
		until velocityW ~= 0 -- prevent div-zero

		local randomization = (1 + rand() * randomness) / (1 + randomness)
		local normalization = (projectileSpeed / velocityW) * randomization

		velocityX = velocityX * normalization
		velocityY = velocityY * normalization
		velocityZ = velocityZ * normalization

		speed[1] = velocityX
		speed[2] = velocityY
		speed[3] = velocityZ

		position[1] = x + velocityX * gameSpeed / 2
		position[2] = y + velocityY * gameSpeed / 2
		position[3] = z + velocityZ * gameSpeed / 2

		spSpawnProjectile(clusterDefID, params)
	end
end

--------------------------------------------------------------------------------
-- Gadget callins --------------------------------------------------------------

function gadget:Initialize()
	if not next(clusterWeaponDefs) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "Removing gadget. No weapons found.")
		gadgetHandler:RemoveGadget(self)
		return
	end

	for weaponDefID in pairs(clusterWeaponDefs) do
		Script.SetWatchExplosion(weaponDefID, true)
	end
end

function gadget:Explosion(weaponDefID, x, y, z, attackerID, projectileID)
	local weaponData = clusterWeaponDefs[weaponDefID]
	if weaponData then
		spawnClusterProjectiles(weaponData, x, y, z, attackerID, projectileID)
	end
end
