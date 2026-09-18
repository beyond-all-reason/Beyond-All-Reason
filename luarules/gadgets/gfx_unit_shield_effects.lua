local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Shield Effects",
		desc = "Draws variable shields for shielded units",
		author = "ivand, GoogleFrog",
		date = "2019",
		license = "GNU GPL, v2 or later",
		layer = 1500, -- Call ShieldPreDamaged after gadgets which change whether interception occurs
		enabled = true,
	}
end

-----------------------------------------------------------------
-- Global consts
-----------------------------------------------------------------

local GAMESPEED = Game.gameSpeed
local SHIELDARMORID = 4
local SHIELDARMORIDALT = 0
local SHIELDONRULESPARAMINDEX = 531313 -- not a string due to perfmaxxing

-----------------------------------------------------------------
-- Vector math functions (used for hit impact calculations)
-----------------------------------------------------------------

local sqrt = math.sqrt
local function Norm(x, y, z)
	return sqrt(x * x + y * y + z * z)
end

local function DotProduct(x1, y1, z1, x2, y2, z2)
	return x1 * x2 + y1 * y2 + z1 * z2
end

-- Spherical linear interpolation for impact points
local ALMOST_ONE = 0.999
local function GetSLerpedPoint(x1, y1, z1, x2, y2, z2, w1, w2)
	local dotP = DotProduct(x1, y1, z1, x2, y2, z2)

	if dotP >= ALMOST_ONE then
		return x1, y1, z1
	end

	local A = math.acos(dotP)
	local sinA = math.sin(A)

	-- Safeguard against division by zero
	if sinA == 0 or (w1 + w2) == 0 then
		return x1, y1, z1
	end

	local w = 1.0 - (w1 / (w1 + w2))

	local x = (math.sin((1.0 - w) * A) * x1 + math.sin(w * A) * x2) / sinA
	local y = (math.sin((1.0 - w) * A) * y1 + math.sin(w * A) * y2) / sinA
	local z = (math.sin((1.0 - w) * A) * z1 + math.sin(w * A) * z2) / sinA

	return x, y, z
end

-----------------------------------------------------------------
-- Synced part of gadget
-----------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then
	local spSetUnitRulesParam = Spring.SetUnitRulesParam
	local SendToUnsynced = SendToUnsynced
	local INLOS_ACCESS = { inlos = true }
	local gameFrame = 0

	function gadget:GameFrame(n)
		gameFrame = n
	end

	local unitBeamWeapons = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		local weapons = unitDef.weapons
		local hasbeamweapon = false
		for i = 1, #weapons do
			local weaponDefID = weapons[i].weaponDef
			if WeaponDefs[weaponDefID].type == "LightningCannon" or WeaponDefs[weaponDefID].type == "BeamLaser" then
				hasbeamweapon = true
			end
		end
		if hasbeamweapon then
			unitBeamWeapons[unitDefID] = {}
			for i = 1, #weapons do
				unitBeamWeapons[unitDefID][i] = weapons[i].weaponDef
			end
		end
	end
	local weaponType = {}
	local weaponDamages = {}
	local weaponBeamtime = {}
	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		weaponType[weaponDefID] = weaponDef.type
		weaponDamages[weaponDefID] = {
			[SHIELDARMORIDALT] = weaponDef.damages[SHIELDARMORIDALT],
			[SHIELDARMORID] = weaponDef.damages[SHIELDARMORID],
		}
		weaponBeamtime[weaponDefID] = weaponDef.beamtime
	end

	function gadget:ShieldPreDamaged(
		proID,
		proOwnerID,
		shieldEmitterWeaponNum,
		shieldCarrierUnitID,
		bounceProjectile,
		beamEmitterWeaponNum,
		beamEmitterUnitID,
		startX,
		startY,
		startZ,
		hitX,
		hitY,
		hitZ
	)
		local dmgMod = 1
		local weaponDefID
		if proID and proID ~= -1 then
			weaponDefID = Spring.GetProjectileDefID(proID)
		elseif beamEmitterUnitID then -- hitscan weapons
			local uDefID = Spring.GetUnitDefID(beamEmitterUnitID)
			if unitBeamWeapons[uDefID] and unitBeamWeapons[uDefID][beamEmitterWeaponNum] then
				weaponDefID = unitBeamWeapons[uDefID][beamEmitterWeaponNum]
				if weaponType[weaponDefID] ~= "LightningCannon" then
					dmgMod = 1 / (weaponBeamtime[weaponDefID] * GAMESPEED)
				end
			end
		end

		if weaponDefID then
			local dmg = weaponDamages[weaponDefID][SHIELDARMORID]
			if dmg <= 0.1 then --some stupidity here: llt has 0.0001 dmg in weaponDamages[weaponDefID][SHIELDARMORID]
				dmg = weaponDamages[weaponDefID][SHIELDARMORIDALT]
			end

			local x, y, z = Spring.GetUnitPosition(shieldCarrierUnitID)
			local dx, dy, dz
			local onlyMove = false
			if bounceProjectile then
				onlyMove = ((hitX == 0) and (hitY == 0) and (hitZ == 0)) --don't apply as additional damage
				dx, dy, dz = startX - x, startY - y, startZ - z
			else
				dx, dy, dz = hitX - x, hitY - y, hitZ - z
			end
			-- We are reasonably fast, about 1us up to here
			SendToUnsynced(
				"AddShieldHitDataHandler",
				gameFrame,
				shieldCarrierUnitID,
				dmg * dmgMod,
				dx,
				dy,
				dz,
				onlyMove
			)
		end

		spSetUnitRulesParam(shieldCarrierUnitID, "shieldHitFrame", gameFrame, INLOS_ACCESS)
		return false
	end

	return
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetMyAllyTeamID = Spring.GetLocalAllyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetUnitPosition = Spring.GetUnitPosition
local spIsSphereInView = Spring.IsSphereInView
local spGetUnitRotation = Spring.GetUnitRotation
local spGetUnitShieldState = Spring.GetUnitShieldState
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetCameraPosition = Spring.GetCameraPosition

local floor = math.floor
local ceil = math.ceil
local huge = math.huge

local tracyZoneBeginN = (tracy and tracy.ZoneBeginN) or function() end
local tracyZoneEnd = (tracy and tracy.ZoneEnd) or function() end

local IterableMap = VFS.Include("LuaRules/Gadgets/Include/IterableMap.lua")

-----------------------------------------------------------------
-- Shield rendering constants
-----------------------------------------------------------------

local MAX_POINTS = 24 -- max impact points per shield
local LOS_UPDATE_PERIOD = 10
local HIT_UPDATE_PERIOD = 2
local STUNNED_CHECK_PERIOD = 40 -- draw frames between stunned polls

-- Fade-in/out when shield turns on or depletes (in 1/SHIELD_FADE_FRAMES per draw frame)
local SHIELD_FADE_FRAMES = 120
local SHIELD_FADE_STEP = 1.0 / SHIELD_FADE_FRAMES
local SHIELD_FADE_EPSILON = 0.001

-- Overlap dimming: when shields stack, each additional overlapping shield
-- multiplies opacity by OVERLAP_FALLOFF. Shields that sit *behind* another
-- (relative to the camera) dim a bit more so the front shield stays readable.
-- Tune higher (closer to 1.0) for less aggressive dimming.
local OVERLAP_FALLOFF = 0.93 -- per overlapping neighbour, front shield
local OVERLAP_FALLOFF_BEHIND = 0.9 -- per neighbour that is in front of this one
local OVERLAP_MIN_SCALE = 0.6 -- absolute floor so shields never fully vanish
local OVERLAP_LERP_RATE = 0.18 -- per-frame smoothing toward target scalar

-- Overlap targets are recomputed for 1/OVERLAP_UPDATE_DIVISOR of the visible
-- shields each draw frame (the lerp above still runs every frame).
local OVERLAP_UPDATE_DIVISOR = 2

-- Spatial hashes used by the overlap pass, one per shield size class so that
-- a few huge shields don't force a coarse grid onto the many small ones. The
-- cell size follows the largest radius seen in that class (2 x radius, so a
-- shield only needs to look at its 3x3 neighbourhood); the search range is
-- always derived exactly from the radii, the cell size is only a heuristic.
local OVERLAP_KEY_MUL = 8192
local OVERLAP_CELL_MIN = { small = 256, large = 1024 }
local OVERLAP_CELL_MAX = 4096

-- Instanced rendering layout (must match ShieldSphereColorGL4.vert.glsl)
local INSTANCE_STRIDE = 20 -- floats per instance: 5 x vec4
local INSTANCE_CAPACITY_INITIAL = 256 -- instances per geometry size, grows on demand
local IMPACT_SSBO_BINDING = 6
local IMPACT_ELEMENT_FLOATS = 16 -- one SSBO element = 4 x vec4 (engine quirk, see CreateImpactBuffer)
local IMPACT_CAPACITY_INITIAL = 512 -- elements (4 impact points each), grows on demand
local GEOMETRY_SUBDIVISIONS = { small = 4, large = 5 }

local VIS_STRIDE = 6 -- visible-shield scratch layout: unitID, unitData, x, y, z, radius

-----------------------------------------------------------------
-- Shield rendering state
-----------------------------------------------------------------

local shieldUnitDefs
local highEnoughQuality = true
local hitUpdateNeeded = false
local myAllyTeamID = spGetMyAllyTeamID()
local shieldUnits = IterableMap.New()

-- Rendering state
local shieldShader
local geometry = {} -- size name -> { vertexVBO, vertexCount, instanceVBO, vao, capacity, data, count }
local impactSSBO
local impactCapacity = 0 -- in SSBO elements
local impactData = {} -- flat float scratch, reused every frame
local impactFloatCount = 0
local canOutline
local checkStunnedTime = 0

-- Per-frame scratch, reused to avoid allocations
local visScratch = {}
local visCount = 0
local overlapPhase = 0

local function NewOverlapGrid(sizeName)
	return {
		cells = {}, -- cell key -> { [0] = count, [1..count] = visible-shield index }
		usedKeys = {},
		usedCount = 0,
		maxRadius = 0, -- largest radius inserted this frame
		cellInv = 1 / OVERLAP_CELL_MIN[sizeName],
		cellMin = OVERLAP_CELL_MIN[sizeName],
	}
end

local overlapGrids = { small = NewOverlapGrid("small"), large = NewOverlapGrid("large") }
local overlapGridList = { overlapGrids.small, overlapGrids.large }

local function UpdateVisibility(unitID, unitData, fullview, forceUpdate)
	-- A shield should render if the player can actually perceive any part of it:
	-- spectator fullview, own allyteam, direct LoS / AirLoS on the unit itself,
	-- or LoS / AirLoS on a point on the shield surface (so partial visibility
	-- of a large shield reveals the whole sphere).
	local unitVisible = fullview
		or (myAllyTeamID == unitData.allyTeamID)
		or Spring.IsUnitInLos(unitID, myAllyTeamID)
		or Spring.IsUnitInAirLos(unitID, myAllyTeamID)

	if not unitVisible then
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		if ux then
			local r = unitData.radius or 0
			-- Sample 8 cardinal/diagonal points on the shield's horizontal
			-- equator plus top/bottom. Cheap and good enough to catch
			-- partial coverage without doing per-vertex visibility.
			local samples = unitData.search
			if samples then
				local cy = uy + (unitData.shieldPos and unitData.shieldPos[2] or 0)
				for i = 1, #samples do
					local sx = ux + samples[i][1]
					local sz = uz + samples[i][2]
					if
						Spring.IsPosInLos(sx, cy, sz, myAllyTeamID)
						or Spring.IsPosInAirLos(sx, cy, sz, myAllyTeamID)
					then
						unitVisible = true
						break
					end
				end
			end
			if not unitVisible and r > 0 then
				-- Also check top and bottom of the shield sphere
				if
					Spring.IsPosInLos(ux, uy + r, uz, myAllyTeamID)
					or Spring.IsPosInAirLos(ux, uy + r, uz, myAllyTeamID)
					or Spring.IsPosInLos(ux, uy - r, uz, myAllyTeamID)
					or Spring.IsPosInAirLos(ux, uy - r, uz, myAllyTeamID)
				then
					unitVisible = true
				end
			end
		end
	end

	local unitIsActive = Spring.GetUnitIsActive(unitID)
	if unitIsActive ~= unitData.isActive then
		forceUpdate = true
		unitData.isActive = unitIsActive
	end

	-- The shield-on rules param is gated by inlos, so for enemies it is only
	-- readable when we have direct LoS. Use it to suppress rendering when we
	-- can see the unit but its shield is currently disabled.
	local shieldEnabled = Spring.GetUnitRulesParam(unitID, SHIELDONRULESPARAMINDEX)
	if unitVisible and shieldEnabled == 0 then
		unitVisible = false
	end

	if unitVisible == unitData.unitVisible and not forceUpdate then
		return
	end
	unitData.unitVisible = unitVisible

	if unitData.shieldInfo then
		unitData.shieldInfo.visibleToMyAllyTeam = unitIsActive and unitVisible
	end
end

-- Teams run by the Scavengers AI; shields they own get the purple palette.
local scavengerTeams = {}
for _, teamID in ipairs(Spring.GetTeamList()) do
	local luaAI = Spring.GetTeamLuaAI(teamID)
	if luaAI and string.find(luaAI, "Scavenger", 1, true) then
		scavengerTeams[teamID] = true
	end
end

-- Selects the normal or scavenger colours for a unit from its owning team.
local function ApplyTeamPalette(unitData, teamID)
	local info = unitData.shieldInfo
	local config = shieldUnitDefs[unitData.unitDefID].config
	if scavengerTeams[teamID] then
		info.scavenger = true
		info.colormap1 = config.scavColormap1
		info.colormap2 = config.scavColormap2
	else
		info.scavenger = false
		info.colormap1 = config.colormap1
		info.colormap2 = config.colormap2
	end
end

local function AddUnit(unitID, unitDefID)
	local def = shieldUnitDefs[unitDefID]
	if not def then
		return
	end

	-- Validate shield capacity
	if not def.shieldCapacity or def.shieldCapacity <= 0 then
		Spring.Echo("Warning: Shield unit " .. unitDefID .. " has invalid capacity: " .. tostring(def.shieldCapacity))
		return
	end

	local shieldInfo = table.copy(def.config)
	shieldInfo.unit = unitID
	shieldInfo.shieldCapacity = def.shieldCapacity
	shieldInfo.visibleToMyAllyTeam = false
	shieldInfo.stunned = false
	shieldInfo.fadeAlpha = 0.0
	shieldInfo.overlapScale = 1.0
	shieldInfo.overlapTarget = 1.0

	local unitData = {
		unitDefID = unitDefID,
		search = def.search,
		capacity = def.shieldCapacity,
		radius = def.shieldRadius,
		shieldInfo = shieldInfo,
		allyTeamID = Spring.GetUnitAllyTeam(unitID),
		immobile = def.immobile, -- buildings never rotate: yaw is fetched once
		yaw = nil,
	}

	if highEnoughQuality then
		unitData.shieldPos = def.shieldPos
		unitData.hitData = {}
		unitData.needsUpdate = false
	end

	ApplyTeamPalette(unitData, Spring.GetUnitTeam(unitID))

	IterableMap.Add(shieldUnits, unitID, unitData)

	local _, fullview = spGetSpectatingState()
	UpdateVisibility(unitID, unitData, fullview, true)
end

local function RemoveUnit(unitID)
	IterableMap.Remove(shieldUnits, unitID)
end

local AOE_MAX = math.pi / 8.0 -- ~0.4

local LOG10 = math.log(10)

local BIASLOG = 2.5
local LOGMUL = AOE_MAX / BIASLOG

local function CalcAoE(dmg, capacity)
	-- Safeguard against invalid inputs that could produce NaN
	if capacity <= 0 or dmg <= 0 then
		return 0
	end

	local ratio = dmg / capacity

	-- Safeguard against log of very small or invalid values
	if ratio <= 0 then
		return 0
	end

	local aoe = (BIASLOG + math.log(ratio) / LOG10) * LOGMUL
	return (aoe > 0 and aoe or 0)
end

local AOE_SAME_SPOT = AOE_MAX / 3 -- ~0.13, angle threshold in radians.
local AOE_SAME_SPOT_COS = math.cos(AOE_SAME_SPOT) -- about 0.99

-- Pre-hoisted sort comparator to avoid closure allocation every 2 frames
local hitDataSortFunc = function(a, b)
	return (((a and b) and a.dmg > b.dmg) or false)
end

--x, y, z here are normalized vectors
local function DoAddShieldHitData(unitData, hitFrame, dmg, x, y, z, onlyMove)
	local hitData = unitData.hitData

	local found = false

	for _, hitInfo in ipairs(hitData) do
		if hitInfo then
			local dist = hitInfo.x * x + hitInfo.y * y + hitInfo.z * z -- take dot product of normed vectors to get the cosine of their angle
			-- AoE radius in radians

			if dist >= AOE_SAME_SPOT_COS then
				found = true

				if onlyMove then -- usually true when we are bouncing a projectile
					hitInfo.dmg = dmg
				else -- this is not a bounced projectile
					hitInfo.x, hitInfo.y, hitInfo.z =
						GetSLerpedPoint(x, y, z, hitInfo.x, hitInfo.y, hitInfo.z, dmg, hitInfo.dmg)
					hitInfo.dmg = dmg + hitInfo.dmg
				end

				hitInfo.aoe = CalcAoE(hitInfo.dmg, unitData.capacity)

				break
			end
		end
	end

	if not found then
		local aoe = CalcAoE(dmg, unitData.capacity)
		hitData[#hitData + 1] = {
			hitFrame = hitFrame,
			dmg = dmg,
			aoe = aoe,
			x = x,
			y = y,
			z = z,
		}
	end
	hitUpdateNeeded = true
	unitData.needsUpdate = true
end

local DECAY_FACTOR = 0.2
local MIN_DAMAGE = 3

---A single recent impact on a unit's shield.
---@class ShieldHit
---@field hitFrame integer Game frame the damage was last accumulated.
---@field dmg number Decaying damage value driving the effect's brightness.
---@field aoe number Radius of the visual ripple.
---@field x number
---@field y number
---@field z number

---Returns the decaying list of recent impacts on a unit's shield.
---@param unitID UnitID
---@return ShieldHit[]? hits `nil` when the unit has no shield or has not been hit.
local function GetShieldHitPositions(unitID)
	local unitData = IterableMap.Get(shieldUnits, unitID)
	return (((unitData and unitData.hitData) and unitData.hitData) or nil)
end

local function ProcessHitTable(unitData, gameFrame)
	unitData.needsUpdate = false
	local hitData = unitData.hitData

	--apply decay over time first
	for i = #hitData, 1, -1 do
		local hitInfo = hitData[i]
		if hitInfo then
			local mult = math.exp(-DECAY_FACTOR * (gameFrame - hitInfo.hitFrame))
			hitInfo.dmg = hitInfo.dmg * mult
			hitInfo.hitFrame = gameFrame

			hitInfo.aoe = CalcAoE(hitInfo.dmg, unitData.capacity)

			if hitInfo.dmg <= MIN_DAMAGE then
				table.remove(hitData, i)
				hitInfo = nil
			else
				unitData.needsUpdate = true
			end
		end
	end
	if unitData.needsUpdate then
		hitUpdateNeeded = true
		table.sort(hitData, hitDataSortFunc)
	end
	return unitData.needsUpdate
end

local function AddShieldHitData(_, hitFrame, unitID, dmg, dx, dy, dz, onlyMove)
	local unitData = IterableMap.Get(shieldUnits, unitID)
	if unitData and unitData.hitData then
		local rdx, rdy, rdz = dx - unitData.shieldPos[1], dy - unitData.shieldPos[2], dz - unitData.shieldPos[3]
		local norm = Norm(rdx, rdy, rdz)
		if math.abs(norm - unitData.radius) <= unitData.radius * 0.05 then
			rdx, rdy, rdz = rdx / norm, rdy / norm, rdz / norm
			DoAddShieldHitData(unitData, hitFrame, dmg, rdx, rdy, rdz, onlyMove)
		end
	end
end

-----------------------------------------------------------------
-- Geometry generation functions
-----------------------------------------------------------------

-- Builds a subdivided icosahedron as a flat triangle list (x, y, z per vertex)
-- on the unit sphere. Returns the float table and the vertex count.
local function BuildIcosahedronVertices(subd)
	local sqrt = math.sqrt

	local function normalize(vertex)
		local r = sqrt(vertex[1] * vertex[1] + vertex[2] * vertex[2] + vertex[3] * vertex[3])
		vertex[1], vertex[2], vertex[3] = vertex[1] / r, vertex[2] / r, vertex[3] / r
		return vertex
	end

	local function midpoint(pt1, pt2)
		return { (pt1[1] + pt2[1]) / 2, (pt1[2] + pt2[2]) / 2, (pt1[3] + pt2[3]) / 2 }
	end

	local function subdivide(pt1, pt2, pt3)
		local pt12 = normalize(midpoint(pt1, pt2))
		local pt13 = normalize(midpoint(pt1, pt3))
		local pt23 = normalize(midpoint(pt2, pt3))

		-- CCW order, starting from leftmost
		return {
			{ pt12, pt13, pt1 },
			{ pt2, pt23, pt12 },
			{ pt12, pt23, pt13 },
			{ pt23, pt3, pt13 },
		}
	end

	--------------------------------------------

	local X = 1
	local Z = (1 + sqrt(5)) / 2

	local vertexes0 = {
		{ -X, 0.0, Z },
		{ X, 0.0, Z },
		{ -X, 0.0, -Z },
		{ X, 0.0, -Z },
		{ 0.0, Z, X },
		{ 0.0, Z, -X },
		{ 0.0, -Z, X },
		{ 0.0, -Z, -X },
		{ Z, X, 0.0 },
		{ -Z, X, 0.0 },
		{ Z, -X, 0.0 },
		{ -Z, -X, 0.0 },
	}

	for i = 1, #vertexes0 do
		normalize(vertexes0[i])
	end

	local fi0 = {
		{ 1, 5, 2 },
		{ 1, 10, 5 },
		{ 10, 6, 5 },
		{ 5, 6, 9 },
		{ 5, 9, 2 },
		{ 9, 11, 2 },
		{ 9, 4, 11 },
		{ 6, 4, 9 },
		{ 6, 3, 4 },
		{ 3, 8, 4 },
		{ 8, 11, 4 },
		{ 8, 7, 11 },
		{ 8, 12, 7 },
		{ 12, 1, 7 },
		{ 1, 2, 7 },
		{ 7, 2, 11 },
		{ 10, 1, 12 },
		{ 10, 12, 3 },
		{ 10, 3, 6 },
		{ 8, 3, 12 },
	}

	local faces = {}
	for i = 1, #fi0 do
		faces[i] = { vertexes0[fi0[i][1]], vertexes0[fi0[i][2]], vertexes0[fi0[i][3]] }
	end

	subd = subd or 1

	for _ = 2, subd do
		local newfaces = {}
		for fii = 1, #faces do
			local newsub = subdivide(faces[fii][1], faces[fii][2], faces[fii][3])
			for k = 1, #newsub do
				newfaces[#newfaces + 1] = newsub[k]
			end
		end
		faces = newfaces
	end

	local verts = {}
	local n = 0
	for i = 1, #faces do
		local face = faces[i]
		-- The base icosahedron is wound clockwise seen from outside; emit each
		-- triangle reversed so the outside is the GL front face (CCW), which the
		-- fragment shader relies on to tell the near hemisphere from the far one.
		for k = 3, 1, -1 do
			local v = face[k]
			verts[n + 1] = v[1]
			verts[n + 2] = v[2]
			verts[n + 3] = v[3]
			n = n + 3
		end
	end

	return verts, #faces * 3
end

-----------------------------------------------------------------
-- Shield configuration
-----------------------------------------------------------------

-- Lua limitations only allow to send 24 bits. Should be enough :)
local function EncodeBitmaskField(bitmask, option, position)
	return math.bit_or(bitmask, ((option and 1) or 0) * math.floor(2 ^ position))
end

local function EncodeEffects(config, outline)
	local effects = 0
	effects = EncodeBitmaskField(effects, config.terrainOutline and outline, 1)
	effects = EncodeBitmaskField(effects, config.unitsOutline and outline, 2)
	effects = EncodeBitmaskField(effects, config.impactAnimation, 3)
	effects = EncodeBitmaskField(effects, config.impactChrommaticAberrations, 4)
	effects = EncodeBitmaskField(effects, config.impactHexSwirl, 5)
	effects = EncodeBitmaskField(effects, config.bandedNoise, 6)
	effects = EncodeBitmaskField(effects, config.impactScaleWithDistance, 7)
	effects = EncodeBitmaskField(effects, config.impactRipples, 8)
	effects = EncodeBitmaskField(effects, config.vertexWobble, 9)
	return effects
end

local function LoadShieldConfig()
	local ShieldSphereBase = {
		colormap1 = { { 0.99, 0.99, 0.90, 0.002 }, { 0.6, 0.30, 0.09, 0.0 } },
		colormap2 = { { 0.7, 0.7, 0.7, 0.001 }, { 0.05, 0.03, 0.0, 0.0 } },
		terrainOutline = true,
		unitsOutline = true,
		impactAnimation = true,
		impactChrommaticAberrations = false,
		impactHexSwirl = false,
		impactScaleWithDistance = true,
		impactRipples = true,
		vertexWobble = true,
		bandedNoise = true,
	}

	local SEARCH_SMALL = {
		{ 0, 0 },
		{ 1, 0 },
		{ -1, 0 },
		{ 0, 1 },
		{ 0, -1 },
	}

	local SEARCH_MULT = 1
	local SEARCH_BASE = 16
	local DIAG = 1 / math.sqrt(2)

	local SEARCH_LARGE = {
		{ 0, 0 },
		{ 1, 0 },
		{ -1, 0 },
		{ 0, 1 },
		{ 0, -1 },
		{ DIAG, DIAG },
		{ -DIAG, DIAG },
		{ DIAG, -DIAG },
		{ -DIAG, -DIAG },
	}
	local searchSizes = {}

	local configTable = {}
	for unitDefID = 1, #UnitDefs do
		local ud = UnitDefs[unitDefID]

		if ud.customParams.shield_radius then
			local radius = tonumber(ud.customParams.shield_radius)
			if not searchSizes[radius] then
				local searchType = (radius > 250 and SEARCH_LARGE) or SEARCH_SMALL
				local search = {}
				for i = 1, #searchType do
					search[i] = {
						SEARCH_MULT * (radius + SEARCH_BASE) * searchType[i][1],
						SEARCH_MULT * (radius + SEARCH_BASE) * searchType[i][2],
					}
				end
				searchSizes[radius] = search
			end

			local myShield = table.copy(ShieldSphereBase)
			if radius > 250 then
				myShield.shieldSize = "large"
				myShield.margin = 0.35
			else
				myShield.shieldSize = "small"
				myShield.margin = 0.2
			end
			myShield.radius = radius
			myShield.pos = {
				0,
				tonumber(ud.customParams.shield_emit_height) or 0,
				tonumber(ud.customParams.shield_emit_offset) or 0,
			}

			local strengthMult = tonumber(ud.customParams.shield_color_mult)
			if strengthMult then
				myShield.colormap1[1][4] = strengthMult * myShield.colormap1[1][4]
				myShield.colormap1[2][4] = strengthMult * myShield.colormap1[2][4]
			end

			-- Scavenger-owned shields get the faction's purple tint (chosen per unit
			-- from the owning team, see ApplyTeamPalette): full-charge body colours
			-- turn purple (alphas kept), the depleted orange stays so the low-charge
			-- warning still reads; the shader picks a purple rim too.
			local c1 = myShield.colormap1
			local c2 = myShield.colormap2
			myShield.scavColormap1 = { { 0.80, 0.40, 1.00, c1[1][4] }, { c1[2][1], c1[2][2], c1[2][3], c1[2][4] } }
			myShield.scavColormap2 = { { 0.60, 0.30, 0.80, c2[1][4] }, { c2[2][1], c2[2][2], c2[2][3], c2[2][4] } }

			-- Effects bitmask is static per unitdef; precompute both outline variants
			myShield.effectsOutline = EncodeEffects(myShield, true)
			myShield.effectsNoOutline = EncodeEffects(myShield, false)

			configTable[unitDefID] = {
				config = myShield,
				search = searchSizes[radius],
				shieldCapacity = tonumber(ud.customParams.shield_power),
				shieldPos = myShield.pos,
				shieldRadius = radius,
				immobile = ud.isImmobile,
			}
		end
	end

	return configTable
end

-----------------------------------------------------------------
-- GL4 resources
-----------------------------------------------------------------

local function CreateInstanceBuffers(geo, capacity)
	if geo.vao then
		geo.vao:Delete()
		geo.vao = nil
	end
	if geo.instanceVBO then
		geo.instanceVBO:Delete()
		geo.instanceVBO = nil
	end

	local instanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not instanceVBO then
		return false
	end
	instanceVBO:Define(capacity, {
		{ id = 1, name = "instPosRadius", size = 4 },
		{ id = 2, name = "instRotMargin", size = 4 },
		{ id = 3, name = "instColor1", size = 4 },
		{ id = 4, name = "instColor2", size = 4 },
		{ id = 5, name = "instParams", size = 4 },
	})

	local vao = gl.GetVAO()
	if not vao then
		instanceVBO:Delete()
		return false
	end
	vao:AttachVertexBuffer(geo.vertexVBO)
	vao:AttachInstanceBuffer(instanceVBO)

	geo.instanceVBO = instanceVBO
	geo.vao = vao
	geo.capacity = capacity
	return true
end

local function CreateImpactBuffer(capacity)
	if impactSSBO then
		impactSSBO:Delete()
		impactSSBO = nil
	end
	impactSSBO = gl.GetVBO(GL.SHADER_STORAGE_BUFFER, true)
	if not impactSSBO then
		return false
	end
	-- For SSBOs the engine's attribute unit is vec4 and size = 4 means one
	-- element of 4 x vec4 (64 bytes); uploads must cover whole elements.
	impactSSBO:Define(capacity, { { id = 0, name = "impacts", size = 4 } })
	impactCapacity = capacity
	return true
end

local function FinalizeRendering()
	if shieldShader then
		shieldShader:Finalize()
		shieldShader = nil
	end

	for _, geo in pairs(geometry) do
		if geo.vao then
			geo.vao:Delete()
		end
		if geo.instanceVBO then
			geo.instanceVBO:Delete()
		end
		if geo.vertexVBO then
			geo.vertexVBO:Delete()
		end
	end
	geometry = {}

	if impactSSBO then
		impactSSBO:Delete()
		impactSSBO = nil
	end
	impactCapacity = 0
end

local function InitializeRendering()
	local LuaShader = gl.LuaShader

	local vertPath = "shaders/ShieldSphereColorGL4.vert.glsl"
	local fragPath = "shaders/ShieldSphereColorGL4.frag.glsl"
	if not VFS.FileExists(vertPath) or not VFS.FileExists(fragPath) then
		Spring.Echo("Shield shader error: " .. vertPath .. " / " .. fragPath .. " not found!")
		return false
	end

	local vsSrc = VFS.LoadFile(vertPath)
	local fsSrc = VFS.LoadFile(fragPath)
	if not vsSrc or not fsSrc then
		Spring.Echo("Shield shader error: Failed to load shader files!")
		return false
	end

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("###DEPTH_CLIP01###", (Platform.glSupportClipSpaceControl and "1" or "0"))
	fsSrc = fsSrc:gsub("###IMPACT_SSBO_BINDING###", tostring(IMPACT_SSBO_BINDING))

	shieldShader = LuaShader({
		vertex = vsSrc,
		fragment = fsSrc,
		uniformInt = {
			mapDepthTex = 0,
			modelsDepthTex = 1,
		},
	}, "ShieldSphereColorGL4")

	if not shieldShader:Initialize() then
		Spring.Echo("Shield shader failed to compile!")
		shieldShader = nil
		return false
	end

	for sizeName, subd in pairs(GEOMETRY_SUBDIVISIONS) do
		local verts, vertexCount = BuildIcosahedronVertices(subd)
		local vertexVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
		if not vertexVBO then
			FinalizeRendering()
			return false
		end
		vertexVBO:Define(vertexCount, { { id = 0, name = "vertexPos", size = 3 } })
		vertexVBO:Upload(verts)

		local geo = {
			vertexVBO = vertexVBO,
			vertexCount = vertexCount,
			data = {},
			count = 0,
		}
		geometry[sizeName] = geo
		if not CreateInstanceBuffers(geo, INSTANCE_CAPACITY_INITIAL) then
			FinalizeRendering()
			return false
		end
	end

	if not CreateImpactBuffer(IMPACT_CAPACITY_INITIAL) then
		FinalizeRendering()
		return false
	end

	return true
end

-----------------------------------------------------------------
-- Shield rendering
-----------------------------------------------------------------

-- Pass 1: fade shields in/out and collect those in view into visScratch and
-- the overlap spatial hash.
local function CollectVisibleShields()
	checkStunnedTime = checkStunnedTime + 1
	local checkStunned = false
	if checkStunnedTime >= STUNNED_CHECK_PERIOD then
		checkStunned = true
		checkStunnedTime = 0
	end

	visCount = 0

	-- Size the grids from the previous frame's radii (cell size is only a
	-- performance heuristic, correctness never depends on it)
	for g = 1, #overlapGridList do
		local grid = overlapGridList[g]
		local cell = 2 * grid.maxRadius
		if cell < grid.cellMin then
			cell = grid.cellMin
		elseif cell > OVERLAP_CELL_MAX then
			cell = OVERLAP_CELL_MAX
		end
		grid.cellInv = 1 / cell
		grid.maxRadius = 0
	end

	-- Iterate the IterableMap storage directly: no iterator closure, no
	-- per-element function call.
	local keyByIndex = shieldUnits.keyByIndex
	local dataByKey = shieldUnits.dataByKey
	for i = 1, shieldUnits.indexMax do
		local unitID = keyByIndex[i]
		local unitData = dataByKey[unitID]
		local info = unitData.shieldInfo
		if info then
			if checkStunned then
				info.stunned = spGetUnitIsStunned(unitID)
			end

			-- Fade target: 1 if shield should be shown, 0 otherwise. Lerp every frame.
			local fadeTarget = ((not info.stunned) and info.visibleToMyAllyTeam) and 1.0 or 0.0
			local fa = info.fadeAlpha
			if fa < fadeTarget then
				fa = fa + SHIELD_FADE_STEP
				if fa > fadeTarget then
					fa = fadeTarget
				end
			elseif fa > fadeTarget then
				fa = fa - SHIELD_FADE_STEP
				if fa < fadeTarget then
					fa = fadeTarget
				end
			end
			info.fadeAlpha = fa

			if fa > SHIELD_FADE_EPSILON then
				local radius = info.radius
				local posx, posy, posz = spGetUnitPosition(unitID)

				if posx and spIsSphereInView(posx, posy, posz, radius * 1.2) then
					local vi = visCount * VIS_STRIDE
					visScratch[vi + 1] = unitID
					visScratch[vi + 2] = unitData
					visScratch[vi + 3] = posx
					visScratch[vi + 4] = posy
					visScratch[vi + 5] = posz
					visScratch[vi + 6] = radius
					visCount = visCount + 1

					-- Register in the overlap spatial hash of this size class
					local grid = overlapGrids[info.shieldSize]
					if radius > grid.maxRadius then
						grid.maxRadius = radius
					end
					local cellInv = grid.cellInv
					local key = floor(posx * cellInv) * OVERLAP_KEY_MUL + floor(posz * cellInv)
					local cells = grid.cells
					local cell = cells[key]
					if not cell then
						cell = { [0] = 0 }
						cells[key] = cell
					end
					local c = cell[0]
					if c == 0 then
						local usedCount = grid.usedCount + 1
						grid.usedCount = usedCount
						grid.usedKeys[usedCount] = key
					end
					cell[c + 1] = visCount
					cell[0] = c + 1
				end
			end
		end
	end
end

-- Counts overlapping neighbours of visible shield i, distinguishing those in
-- front (camera-side) from those behind, and returns the target opacity
-- scalar. Only nearby spatial-hash cells are visited and the search stops as
-- soon as the floor is reached, so dense clusters stay cheap.
local function ComputeOverlapTarget(i, ax, ay, az, ar, camx, camy, camz)
	local dxA, dyA, dzA = ax - camx, ay - camy, az - camz
	local camDistA = dxA * dxA + dyA * dyA + dzA * dzA

	local target = 1.0
	for g = 1, #overlapGridList do
		local grid = overlapGridList[g]
		if grid.usedCount > 0 then
			local cells = grid.cells
			local cellInv = grid.cellInv
			local range = ceil((ar + grid.maxRadius) * cellInv)
			local cxi = floor(ax * cellInv)
			local czi = floor(az * cellInv)

			for gx = cxi - range, cxi + range do
				local keyBase = gx * OVERLAP_KEY_MUL
				for gz = czi - range, czi + range do
					local cell = cells[keyBase + gz]
					if cell then
						for k = 1, cell[0] do
							local j = cell[k]
							if j ~= i then
								local vj = (j - 1) * VIS_STRIDE
								local bx, by, bz, br =
									visScratch[vj + 3], visScratch[vj + 4], visScratch[vj + 5], visScratch[vj + 6]
								local ddx, ddy, ddz = ax - bx, ay - by, az - bz
								local sumR = ar + br
								if ddx * ddx + ddy * ddy + ddz * ddz < sumR * sumR then
									local dxB, dyB, dzB = bx - camx, by - camy, bz - camz
									if camDistA > dxB * dxB + dyB * dyB + dzB * dzB then
										-- A is behind B: dim more aggressively
										target = target * OVERLAP_FALLOFF_BEHIND
									else
										target = target * OVERLAP_FALLOFF
									end
									if target <= OVERLAP_MIN_SCALE then
										return OVERLAP_MIN_SCALE
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return target
end

-- Pass 2: refresh the overlap target of a slice of the visible shields, then
-- smoothly lerp every shield's stored opacity scalar toward its target so
-- dimming doesn't pop as units enter/leave clusters.
local function UpdateOverlapScales()
	local camx, camy, camz = spGetCameraPosition()
	camx = camx or 0
	camy = camy or 0
	camz = camz or 0

	overlapPhase = (overlapPhase + 1) % OVERLAP_UPDATE_DIVISOR

	for i = 1, visCount do
		local vi = (i - 1) * VIS_STRIDE
		local info = visScratch[vi + 2].shieldInfo
		if (i % OVERLAP_UPDATE_DIVISOR) == overlapPhase then
			info.overlapTarget = ComputeOverlapTarget(
				i,
				visScratch[vi + 3],
				visScratch[vi + 4],
				visScratch[vi + 5],
				visScratch[vi + 6],
				camx,
				camy,
				camz
			)
		end
		local cur = info.overlapScale
		info.overlapScale = cur + (info.overlapTarget - cur) * OVERLAP_LERP_RATE
	end

	-- Reset the spatial hashes for the next frame (cell tables are kept)
	for g = 1, #overlapGridList do
		local grid = overlapGridList[g]
		local cells = grid.cells
		local usedKeys = grid.usedKeys
		for k = 1, grid.usedCount do
			cells[usedKeys[k]][0] = 0
		end
		grid.usedCount = 0
	end
end

-- Pass 3: write per-shield instance attributes and the packed impact list.
-- Returns whether any drawn shield wants the terrain / unit depth outline.
local function BuildInstanceData()
	local geoSmall = geometry.small
	local geoLarge = geometry.large
	geoSmall.count = 0
	geoLarge.count = 0
	impactFloatCount = 0
	local impactVec4Count = 0

	local haveTerrainOutline = false
	local haveUnitsOutline = false

	for i = 1, visCount do
		local vi = (i - 1) * VIS_STRIDE
		local unitID = visScratch[vi + 1]
		local unitData = visScratch[vi + 2]
		local info = unitData.shieldInfo
		local pos = info.pos
		local posx = visScratch[vi + 3] + pos[1]
		local posy = visScratch[vi + 4] + pos[2]
		local posz = visScratch[vi + 5] + pos[3]

		-- Only yaw is used by the shader; immobile units keep their first value
		local yaw = unitData.yaw
		if not yaw or not unitData.immobile then
			local _, y = spGetUnitRotation(unitID)
			yaw = y or 0
			unitData.yaw = yaw
		end

		local fadeAlpha = info.fadeAlpha

		-- Charge fraction drives the colour lerp
		local _, charge = spGetUnitShieldState(unitID)
		local frac = 1.0
		if charge then
			frac = charge / info.shieldCapacity
			if frac ~= frac then -- NaN
				frac = 0
			elseif frac > 1 then
				frac = 1
			elseif frac < 0 then
				frac = 0
			end
		end
		local fracinv = 1.0 - frac
		local c1full, c1empty = info.colormap1[1], info.colormap1[2]
		local c2full, c2empty = info.colormap2[1], info.colormap2[2]

		local effects
		if canOutline then
			effects = info.effectsOutline
			haveTerrainOutline = haveTerrainOutline or info.terrainOutline
			haveUnitsOutline = haveUnitsOutline or info.unitsOutline
		else
			effects = info.effectsNoOutline
		end

		-- Impact points: append to the shared list, reference by base index
		local impactBase = 0
		local impactCount = 0
		if highEnoughQuality and info.impactAnimation then
			local hitData = unitData.hitData
			local n = hitData and #hitData or 0
			if n > 0 then
				if n > MAX_POINTS then
					n = MAX_POINTS
				end
				impactBase = impactVec4Count
				impactCount = n
				local f = impactFloatCount
				for j = 1, n do
					local hit = hitData[j]
					local aoe = hit.aoe
					if aoe ~= aoe or aoe == huge or aoe == -huge then
						aoe = 0
					end
					impactData[f + 1] = hit.x
					impactData[f + 2] = hit.y
					impactData[f + 3] = hit.z
					impactData[f + 4] = aoe
					f = f + 4
				end
				impactFloatCount = f
				impactVec4Count = impactVec4Count + n
			end
		end

		local geo = (info.shieldSize == "large") and geoLarge or geoSmall
		local data = geo.data
		local o = geo.count * INSTANCE_STRIDE
		geo.count = geo.count + 1

		data[o + 1] = posx
		data[o + 2] = posy
		data[o + 3] = posz
		data[o + 4] = info.radius

		data[o + 5] = yaw
		data[o + 6] = info.margin
		data[o + 7] = fadeAlpha
		data[o + 8] = info.overlapScale

		data[o + 9] = frac * c1full[1] + fracinv * c1empty[1]
		data[o + 10] = frac * c1full[2] + fracinv * c1empty[2]
		data[o + 11] = frac * c1full[3] + fracinv * c1empty[3]
		data[o + 12] = (frac * c1full[4] + fracinv * c1empty[4]) * fadeAlpha

		data[o + 13] = frac * c2full[1] + fracinv * c2empty[1]
		data[o + 14] = frac * c2full[2] + fracinv * c2empty[2]
		data[o + 15] = frac * c2full[3] + fracinv * c2empty[3]
		data[o + 16] = (frac * c2full[4] + fracinv * c2empty[4]) * fadeAlpha

		data[o + 17] = effects
		data[o + 18] = impactBase
		data[o + 19] = impactCount
		data[o + 20] = info.scavenger and 1 or 0 -- flags: 1 = scavenger palette
	end

	return haveTerrainOutline, haveUnitsOutline
end

local function UploadInstanceData()
	for _, geo in pairs(geometry) do
		local count = geo.count
		if count > 0 then
			if count > geo.capacity then
				local capacity = geo.capacity
				while capacity < count do
					capacity = capacity * 2
				end
				if not CreateInstanceBuffers(geo, capacity) then
					geo.count = 0
				end
			end
			if geo.count > 0 then
				geo.instanceVBO:Upload(geo.data, -1, 0, 1, count * INSTANCE_STRIDE)
			end
		end
	end

	if impactFloatCount > 0 then
		-- Pad to whole SSBO elements (see CreateImpactBuffer)
		local padded = ceil(impactFloatCount / IMPACT_ELEMENT_FLOATS) * IMPACT_ELEMENT_FLOATS
		for f = impactFloatCount + 1, padded do
			impactData[f] = 0
		end
		local elements = padded / IMPACT_ELEMENT_FLOATS
		if elements > impactCapacity then
			local capacity = impactCapacity
			while capacity < elements do
				capacity = capacity * 2
			end
			if not CreateImpactBuffer(capacity) then
				impactFloatCount = 0
				return
			end
		end
		impactSSBO:Upload(impactData, -1, 0, 1, padded)
	end
end

local function DrawShields(haveTerrainOutline, haveUnitsOutline)
	gl.Blending("alpha")
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)

	if haveTerrainOutline then
		gl.Texture(0, "$map_gbuffer_zvaltex")
	end

	if haveUnitsOutline then
		gl.Texture(1, "$model_gbuffer_zvaltex")
	end

	local haveImpacts = impactFloatCount > 0
	if haveImpacts then
		impactSSBO:BindBufferRange(IMPACT_SSBO_BINDING)
	end

	shieldShader:Activate()
	for _, geo in pairs(geometry) do
		if geo.count > 0 then
			geo.vao:DrawArrays(GL.TRIANGLES, geo.vertexCount, 0, geo.count)
		end
	end
	shieldShader:Deactivate()

	if haveImpacts then
		impactSSBO:UnbindBufferRange(IMPACT_SSBO_BINDING)
	end

	if haveTerrainOutline then
		gl.Texture(0, false)
	end

	if haveUnitsOutline then
		gl.Texture(1, false)
	end

	gl.DepthTest(false)
	gl.DepthMask(false)
end

function gadget:DrawWorld()
	if not shieldShader then
		return
	end

	tracyZoneBeginN("Shield:Collect")
	CollectVisibleShields()
	tracyZoneEnd()

	if visCount == 0 then
		return
	end

	canOutline = gl.LuaShader.isDeferredShadingEnabled and gl.LuaShader.GetAdvShadingActive()

	tracyZoneBeginN("Shield:Overlap")
	UpdateOverlapScales()
	tracyZoneEnd()

	tracyZoneBeginN("Shield:Build")
	local haveTerrainOutline, haveUnitsOutline = BuildInstanceData()
	tracyZoneEnd()

	tracyZoneBeginN("Shield:Upload")
	UploadInstanceData()
	tracyZoneEnd()

	tracyZoneBeginN("Shield:Draw")
	DrawShields(haveTerrainOutline, haveUnitsOutline)
	tracyZoneEnd()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	RemoveUnit(unitID)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if shieldUnitDefs[unitDefID] then
		AddUnit(unitID, unitDefID)
	end
end

local function UnitChangedTeam(unitID, newTeam)
	local unitData = IterableMap.Get(shieldUnits, unitID)
	if unitData then
		unitData.allyTeamID = Spring.GetUnitAllyTeam(unitID)
		ApplyTeamPalette(unitData, newTeam)
	end
end

function gadget:UnitTaken(unitID, unitDefID, newTeam, oldTeam)
	UnitChangedTeam(unitID, newTeam)
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	UnitChangedTeam(unitID, newTeam)
end

function gadget:PlayerChanged()
	myAllyTeamID = spGetMyAllyTeamID()
end

function gadget:GameFrame(n)
	if highEnoughQuality and hitUpdateNeeded and (n % HIT_UPDATE_PERIOD == 0) then
		hitUpdateNeeded = false
		for unitID, unitData in IterableMap.Iterator(shieldUnits) do
			if unitData and unitData.hitData then
				local phtRes = ProcessHitTable(unitData, n)
				hitUpdateNeeded = hitUpdateNeeded or phtRes
			end
		end
	end

	if n % LOS_UPDATE_PERIOD == 0 then
		local _, fullview = spGetSpectatingState()
		for unitID, unitData in IterableMap.Iterator(shieldUnits) do
			UpdateVisibility(unitID, unitData, fullview)
		end
	end
end

function gadget:Initialize(n)
	if Platform.glHaveGL4 ~= true then
		Spring.Echo("Shield gadget: GL4 not supported by this GPU/driver, disabling shield rendering")
		gadgetHandler:RemoveGadget(self)
		return
	end

	-- Load shield configuration
	shieldUnitDefs = LoadShieldConfig()

	-- Initialize shader and geometry
	if not InitializeRendering() then
		Spring.Echo("Shield gadget: Failed to initialize rendering, disabling")
		gadgetHandler:RemoveGadget(self)
		return
	end

	if highEnoughQuality then
		gadgetHandler:AddSyncAction("AddShieldHitDataHandler", AddShieldHitData)
		GG.GetShieldHitPositions = GetShieldHitPositions
	end

	-- Add existing units
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		if unitDefID and unitTeam then
			gadget:UnitFinished(unitID, unitDefID, unitTeam)
		end
	end
end

function gadget:Shutdown()
	if highEnoughQuality then
		gadgetHandler:RemoveSyncAction("AddShieldHitDataHandler", AddShieldHitData)
		GG.GetShieldHitPositions = nil
	end

	-- Cleanup GL resources
	FinalizeRendering()

	-- Remove all units
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		RemoveUnit(unitID)
	end
end
