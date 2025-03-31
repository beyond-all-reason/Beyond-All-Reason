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

local defaultSpawnTtl = 5					-- detonate projectiles after time = ttl, by default

-- General settings ------------------------------------------------------------

local minSpawnNumber = 3					-- minimum number of spawned projectiles
local maxSpawnNumber = 24					-- protect game performance against stupid ideas
local minUnitBounces = "armpw"				-- smallest unit (name) that bounces projectiles at all
local minBulkReflect = 64000				-- smallest unit bulk that causes reflection as if terrain

-- CustomParams setup ----------------------------------------------------------
--
	-- weapon = {
	-- 	type := "Cannon" | "EMGCannon"
	-- 	customparams = {
	-- 		cluster_def    := <string> | nil (see defaults)
	-- 		cluster_number := <number> | nil (see defaults)
	-- 	},
	-- },
    --
    -- <cluster_def> = {
	-- 	weaponvelocity := <number> -- Will be ignored in favor of range if possible.
	-- 	range          := <number> -- Preferred over and replaces weaponvelocity.
	-- }

--------------------------------------------------------------------------------
-- Localize --------------------------------------------------------------------

local DirectionsUtil = VFS.Include("LuaRules/Gadgets/Include/DirectionsUtil.lua")

local max   = math.max
local min   = math.min
local rand  = math.random
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
local maxUnitRadius = 0

for _, unitDef in pairs(UnitDefs) do
	maxUnitRadius = max(maxUnitRadius, unitDef.radius)
end

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

defaultSpawnTtl = defaultSpawnTtl * gameSpeed

local spawnableTypes = {
	Cannon          = true  ,
	EMGCannon       = true  ,
}

local clusterWeaponDefs = {}

for unitDefName, unitDef in pairs(UnitDefNames) do
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

local unitBulks = {} -- How sturdy the unit is. Projectiles scatter less with lower bulk values.

for unitDefID, unitDef in pairs(UnitDefs) do
	local bulkiness = (
		unitDef.health ^ 0.5 +                               -- HP is log2-ish but that feels too tryhard
		unitDef.metalCost ^ 0.5 *                            -- Steel (metal) is heavier than feathers (energy)
		unitDef.xsize * unitDef.zsize * unitDef.radius ^ 0.5 -- We see 'bigger' as 'more solid' not 'less dense'
	) / minBulkReflect                                       -- Scaled against some large-ish bulk rating

	if unitDef.armorType == Game.armorTypes.wall or unitDef.armorType == Game.armorTypes.indestructable then
		bulkiness = bulkiness * 2
	elseif unitDef.customParams.neutral_when_closed then
		bulkiness = bulkiness * 1.5
	end

	unitBulks[unitDefID] = min(bulkiness, 1) ^ 0.39 -- Scale bulks to [0,1] and curve them upward towards 1.
end

local bulkMin = unitBulks[UnitDefNames[minUnitBounces].id] or 0.1
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

local function getSurfaceDeflection(x, y, z)
	-- Deflection from deep water, shallow water, and solid terrain.
	local elevation = spGetGroundHeight(x, z)
	local separation
	local dx, dy, dz
	local slope

	separation = y - elevation
	dx, dy, dz, slope = spGetGroundNormal(x, z, true)

	if slope > 0.1 or slope * separation > 10 then
		separation = separation * cos(slope)
		local shift = separation * sin(slope) / sqrt(dx*dx + dz*dz)
		local shiftX = x - dx * shift -- Next surface x, z
		local shiftZ = z - dz * shift
		elevation = max(elevation, spGetGroundHeight(shiftX, shiftZ))
		separation = y - elevation
		dx, dy, dz = spGetGroundNormal(shiftX, shiftZ, true)
	end

	separation = 1.3 / sqrt(max(1, separation))
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
			radius         = spGetUnitRadius(unitID)
			if unitY + radius > 0 then
				unitX, unitY, unitZ = x - unitX, y - unitY, z - unitZ
				separation = sqrt(unitX*unitX + unitY*unitY + unitZ*unitZ) / radius
				if separation < 1.24 then
					bounce = bounce / max(1, separation)
					local theta_z = atan2(unitX, unitZ)
					local phi_y = atan2(unitY, sqrt(unitX*unitX + unitZ*unitZ))
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

local function spawnClusterProjectiles(data, attackerID, x, y, z)
	local clusterDefID = data.weaponID
	local projectileCount = data.number
	local projectileSpeed = data.weaponSpeed

	spawnCache.owner = attackerID or -1
	spawnCache.ttl = data.weaponTtl
	local speed = spawnCache.speed
	local position = spawnCache.pos

	local directionVectors = directions[projectileCount]
	local deflectX, deflectY, deflectZ = getSurfaceDeflection(x, y, z)
	local randomness = 1 / sqrt(projectileCount - 2)

	for i = 0, projectileCount - 1 do
		local velocityX = directionVectors[3 * i + 1] + deflectX
		local velocityY = directionVectors[3 * i + 2] + deflectY
		local velocityZ = directionVectors[3 * i + 3] + deflectZ

		velocityX = velocityX + (rand() - 0.5) * randomness * 2
		velocityY = velocityY + (rand() - 0.5) * randomness * 2
		velocityZ = velocityZ + (rand() - 0.5) * randomness * 2

		-- Higher projectile counts will have less variation in projectile speed.
		local normalization = (1 + rand() * randomness) / (1 + randomness)
		normalization = normalization * projectileSpeed / sqrt(velocityX*velocityX + velocityY*velocityY + velocityZ*velocityZ)
		velocityX = velocityX * normalization
		velocityY = velocityY * normalization
		velocityZ = velocityZ * normalization

		speed[1] = velocityX
		speed[2] = velocityY
		speed[3] = velocityZ

		position[1] = x + velocityX * gameSpeed / 2
		position[2] = y + velocityY * gameSpeed / 2
		position[3] = z + velocityZ * gameSpeed / 2

		spSpawnProjectile(clusterDefID, spawnCache)
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
		spawnClusterProjectiles(weaponData, attackerID, x, y, z)
	end
end
