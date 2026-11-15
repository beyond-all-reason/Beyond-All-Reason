-- SPDX-License-Identifier: GPL-2.0-or-later
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Map regions",
		desc = "Map region isolation for multi-region maps",
		author = "gajop",
		license = "GNU GPL, v2 or later",
		layer = -1000,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local mapRegions = VFS.Include("common/map_regions.lua")
if not mapRegions then
	return false
end

if
	not (
		Engine.FeatureSupport
		and Engine.FeatureSupport.mapRegionViews
		and Engine.FeatureSupport.sensorRegions
		and Engine.FeatureSupport.mapDamageRegions
	)
then
	function gadget:GameFrame(f)
		if f == 1 then
			Spring.Echo("Map regions require engine mapRegionViews, sensorRegions, and mapDamageRegions support.")
			Spring.GameOver({})
		end
	end
	return
end

-- Configurable by the map: the separating strip takes over this typemap index for the whole map.
local BARRIER_TERRAIN_TYPE = mapRegions.barrierTerrainType or 255
local BARRIER_HARDNESS = 1000000
local CONTAINMENT_INSET = 24

local regions = mapRegions.regions
local Region = mapRegions.Region

-- Region of every unit ID seen, kept after death so shields still filter projectiles of a dead owner.
-- Only Lua state: after a LuaRules reload, ShieldPreDamaged lets through projectiles whose owner died
-- before the reload. Unit and feature damage are unaffected, the engine passes no attacker for dead units.
local unitRegion = {}
local activeUnitRegions = {}

local unitCanFly = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitCanFly[unitDefID] = unitDef.canFly
end

local function SpawnRegion(x, z)
	local regionID = Region(x, z)
	if regionID then
		return regionID
	end
	-- Units created in a separating strip still need an owner for commands,
	-- damage and the ordinary containment pass. Ties follow manifest order.
	local best, bestDistance
	for i, r in ipairs(regions) do
		local dx = x - math.max(r.x0 + 1, math.min(x, r.x1 - 1))
		local dz = z - math.max(r.z0 + 1, math.min(z, r.z1 - 1))
		local distance = dx * dx + dz * dz
		if not bestDistance or distance < bestDistance then
			best, bestDistance = i, distance
		end
	end
	return best
end

local function ValidUnit(unitID)
	return unitID and Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID)
end

local function GetUnitRegion(unitID)
	local regionID = unitRegion[unitID]
	if regionID then
		return regionID
	end
	local x, _, z = Spring.GetUnitPosition(unitID)
	return Region(x, z)
end

local function SetUnitRegion(unitID, regionID)
	unitRegion[unitID] = regionID
	activeUnitRegions[unitID] = regionID
	Spring.SetUnitRulesParam(unitID, "map_region", regionID, { allied = true, inlos = true })
	for _, cargoID in ipairs(Spring.GetUnitIsTransporting(unitID) or {}) do
		SetUnitRegion(cargoID, regionID)
	end
end

-- Commands whose parameters are neither world positions nor unit/feature IDs.
-- Other command IDs are classified by their command description type the first time they are seen.
local commandIsNonSpatial = {
	[CMD.ONOFF] = true,
	[CMD.FIRE_STATE] = true,
	[CMD.MOVE_STATE] = true,
	[CMD.REPEAT] = true,
	[CMD.CLOAK] = true,
	[CMD.STOCKPILE] = true,
	[CMD.TRAJECTORY] = true,
	[CMD.IDLEMODE] = true,
	[CMD.AUTOREPAIRLEVEL] = true,
	[CMD.REMOVE] = true,
	[CMD.TIMEWAIT] = true,
	[CMD.SQUADWAIT] = true,
	[CMD.GATHERWAIT] = true,
	[GameCMD.FACTORY_GUARD] = true,
	[GameCMD.STOP_PRODUCTION] = true,
	[GameCMD.QUOTA_BUILD_TOGGLE] = true,
	[GameCMD.SELL_UNIT] = true,
	[GameCMD.CARRIER_SPAWN_ONOFF] = true,
	[GameCMD.MORPH] = true,
	[GameCMD.USER_FIRESTATE] = true,
	[GameCMD.UNIT_CANCEL_TARGET] = true,
	[GameCMD.LAND_AT] = true,
	[GameCMD.PRIORITY] = true,
	[GameCMD.WANT_CLOAK] = true,
	[GameCMD.HOUND_WEAPON_TOGGLE] = true,
	[GameCMD.SMART_TOGGLE] = true,
}

local nonSpatialCmdTypes = {
	[CMDTYPE.ICON] = true,
	[CMDTYPE.ICON_MODE] = true,
	[CMDTYPE.NUMBER] = true,
}

-- Commands whose single parameter is a unit or feature ID. Other commands are added from their
-- command description type the first time a unit that has the description is seen.
local commandTargetsEntity = {
	[CMD.ATTACK] = true,
	[CMD.GUARD] = true,
	[CMD.REPAIR] = true,
	[CMD.RECLAIM] = true,
	[CMD.RESURRECT] = true,
	[CMD.CAPTURE] = true,
	[CMD.LOAD_UNITS] = true,
	[CMD.LOAD_ONTO] = true,
	[CMD.MANUALFIRE] = true,
}

local entityTargetCmdTypes = {
	[CMDTYPE.ICON_UNIT] = true,
	[CMDTYPE.ICON_UNIT_OR_MAP] = true,
	[CMDTYPE.ICON_UNIT_OR_AREA] = true,
	[CMDTYPE.ICON_UNIT_FEATURE_OR_AREA] = true,
	[CMDTYPE.ICON_UNIT_OR_RECTANGLE] = true,
}

-- Returns whether the command's parameters are neither positions nor unit/feature IDs, and
-- whether a single parameter is a unit or feature ID.
local function ClassifyCommand(unitID, cmdID)
	local cached = commandIsNonSpatial[cmdID]
	if cached ~= nil then
		return cached, commandTargetsEntity[cmdID] == true
	end
	-- Build orders carry a position.
	if cmdID < 0 then
		return false, false
	end
	-- A command ID has one description type for every unit, so the first unit that has it decides.
	-- Without a description the type is unknown and nothing is cached, another unit may have it:
	-- positions are still checked, but a single parameter is only read as a unit or feature ID
	-- for the commands known to take one.
	local cmdDescID = Spring.FindUnitCmdDesc(unitID, cmdID)
	---@diagnostic disable-next-line: redundant-parameter
	local cmdDesc = cmdDescID and Spring.GetUnitCmdDescs(unitID, cmdDescID, cmdDescID) ---@type CommandDescription[]?
	local cmdType = cmdDesc and cmdDesc[1] and cmdDesc[1].type
	if cmdType == nil then
		return false, commandTargetsEntity[cmdID] == true
	end
	local nonSpatial = nonSpatialCmdTypes[cmdType] == true
	commandIsNonSpatial[cmdID] = nonSpatial
	commandTargetsEntity[cmdID] = commandTargetsEntity[cmdID] or entityTargetCmdTypes[cmdType] == true
	return nonSpatial, commandTargetsEntity[cmdID]
end

local function GetCommandRegion(unitID, cmdID, cmdParams)
	local count = #cmdParams
	if count ~= 1 and count ~= 3 and count ~= 4 and count ~= 6 then
		return nil, false
	end
	local nonSpatial, targetsEntity = ClassifyCommand(unitID, cmdID)
	if nonSpatial then
		return nil, false
	end

	if count == 3 or count == 4 then
		return Region(cmdParams[1], cmdParams[3]), true
	end
	if count == 6 then
		local r1, r2 = Region(cmdParams[1], cmdParams[3]), Region(cmdParams[4], cmdParams[6])
		return (r1 == r2 and r1) or nil, true
	end
	if not targetsEntity then
		return nil, false
	end

	local targetID = cmdParams[1]
	if targetID >= Game.maxUnits then
		---@type FeatureID
		local featureID = math.floor(targetID - Game.maxUnits)
		if Spring.ValidFeatureID(featureID) then
			local x, _, z = Spring.GetFeaturePosition(featureID)
			return Region(x, z), true
		end
	elseif ValidUnit(targetID) then
		return GetUnitRegion(targetID), true
	end
	return nil, false
end

local function DamageAllowed(targetRegion, attackerID)
	local sourceRegion = attackerID and GetUnitRegion(attackerID)
	if sourceRegion and targetRegion and sourceRegion ~= targetRegion then
		return false
	end
	return true
end

-- Set when the engine refuses the map's regions. The map is then not isolated, so the
-- regions are not advertised and the game ends at frame 1, as without engine support.
local rejectedBy

local function Reject(what)
	rejectedBy = rejectedBy or what
	Spring.Log(gadget:GetInfo().name, LOG.ERROR, "The engine rejected the map's " .. what .. " regions")
end

-- Sensor and crater regions, the barrier terrain and the building mask are engine state that survives
-- a LuaRules reload, and the engine refuses new sensor regions once the game is running.
local function ConfigureEngineRegions()
	local rectangles = {}
	for i, r in ipairs(regions) do
		rectangles[i] = { r.x0, r.z0, r.x1, r.z1 }
	end
	if not Spring.SetSensorRegions(rectangles) then
		Reject("sensor")
	end
	if not Spring.SetMapDamageRegions(rectangles) then
		Reject("crater")
	end
	if rejectedBy then
		return
	end

	---@diagnostic disable-next-line: redundant-parameter
	Spring.SetTerrainTypeData(BARRIER_TERRAIN_TYPE, 0, 0, 0, 0, BARRIER_HARDNESS, false, "Region barrier")
	for x = 0, Game.mapSizeX - 8, 8 do
		for z = 0, Game.mapSizeZ - 8, 8 do
			if not Region(x + 4, z + 4) then
				Spring.SetMapSquareTerrainType(x, z, BARRIER_TERRAIN_TYPE)
				if x % 16 == 0 and z % 16 == 0 then
					Spring.SetSquareBuildingMask(math.floor(x / 16), math.floor(z / 16), 0)
				end
			end
		end
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.ANY)
	assert(
		Game.mapSizeX == mapRegions.size[1] and Game.mapSizeZ == mapRegions.size[2],
		"Map region manifest and physical map disagree"
	)
	if Spring.GetGameFrame() <= 0 then
		ConfigureEngineRegions()
	end
	if rejectedBy then
		return
	end

	Spring.SetGameRulesParam("map_regions", #regions)
	for i, r in ipairs(regions) do
		for _, k in ipairs({ "x0", "z0", "x1", "z1" }) do
			Spring.SetGameRulesParam("map_region_" .. i .. "_" .. k, r[k])
		end
	end

	GG.MapRegions = {
		mapRegions = mapRegions,
		unitRegion = unitRegion,
		Region = Region,
		UnitRegion = GetUnitRegion,
		SetUnitRegion = SetUnitRegion,
		DamageAllowed = DamageAllowed,
	}

	-- After a LuaRules reload, units keep the region recorded in their rules param.
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local regionID = Spring.GetUnitRulesParam(unitID, "map_region")
		if type(regionID) ~= "number" or not regions[regionID] then
			local x, _, z = Spring.GetUnitPosition(unitID)
			regionID = SpawnRegion(x, z)
		end
		SetUnitRegion(unitID, regionID)
	end
end

function gadget:UnitCreated(unitID, _unitDefID, _unitTeam)
	local x, _, z = Spring.GetUnitPosition(unitID)
	SetUnitRegion(unitID, SpawnRegion(x, z))
end

function gadget:UnitDestroyed(unitID)
	-- Keep the last owner region for late shield hits, but stop scanning
	-- destroyed units in the periodic containment and surface-damage checks.
	activeUnitRegions[unitID] = nil
end

function gadget:AllowCommand(unitID, _unitDefID, _unitTeam, cmdID, cmdParams, _cmdOptions)
	local destination, isSpatial = GetCommandRegion(unitID, cmdID, cmdParams)
	if isSpatial and (not destination or (unitRegion[unitID] and destination ~= unitRegion[unitID])) then
		return false
	end
	return true
end

function gadget:UnitPreDamaged(
	unitID,
	_unitDefID,
	_unitTeam,
	damage,
	_paralyzer,
	_weaponDefID,
	_projectileID,
	attackerID,
	_attackerDefID,
	_attackerTeam
)
	if not DamageAllowed(GetUnitRegion(unitID), attackerID) then
		return 0, 0
	end
	return damage, 1
end

function gadget:FeaturePreDamaged(
	featureID,
	_featureDefID,
	_featureTeam,
	damage,
	_weaponDefID,
	_projectileID,
	attackerID,
	_attackerDefID,
	_attackerTeam
)
	local fx, _, fz = Spring.GetFeaturePosition(featureID)
	if not DamageAllowed(Region(fx, fz), attackerID) then
		return 0, 0
	end
	return damage, 1
end

function gadget:ShieldPreDamaged(
	_proID,
	proOwnerID,
	_shieldEmitterWeaponNum,
	shieldCarrierUnitID,
	_bounceProjectile,
	_beamEmitterWeaponNum,
	beamEmitterUnitID
)
	local attackerID = (beamEmitterUnitID and beamEmitterUnitID >= 0 and beamEmitterUnitID) or proOwnerID
	if not DamageAllowed(GetUnitRegion(shieldCarrierUnitID), attackerID) then
		return true
	end
	return false
end

function gadget:GameFrame(f)
	if rejectedBy then
		if f == 1 then
			Spring.Echo(
				"Map regions: the engine rejected the map's " .. rejectedBy .. " regions, so the map cannot be played."
			)
			Spring.GameOver({})
		end
		return
	end
	if f % 15 == 0 then
		for unitID, regionID in pairs(activeUnitRegions) do
			if ValidUnit(unitID) and not Spring.GetUnitTransporter(unitID) then
				local x, y, z = Spring.GetUnitPosition(unitID)
				local isAir = unitCanFly[Spring.GetUnitDefID(unitID)]
				local r = isAir and mapRegions.objectBounds[regionID] or regions[regionID]
				if
					x
					and y
					and z
					and (
						(isAir and not mapRegions.ContainsObject(regionID, x, z))
						or (not isAir and Region(x, z) ~= regionID)
					)
				then
					local tx = math.max(r.x0 + CONTAINMENT_INSET, math.min(r.x1 - CONTAINMENT_INSET, x))
					local tz = math.max(r.z0 + CONTAINMENT_INSET, math.min(r.z1 - CONTAINMENT_INSET, z))
					if isAir then
						Spring.SetUnitPosition(unitID, tx, y, tz)
					else
						Spring.SetUnitPosition(unitID, tx, tz)
					end
					Spring.SetUnitVelocity(unitID, 0, 0, 0)
				end
			end
		end
	end

	if f % 30 == 0 then
		for unitID, regionID in pairs(activeUnitRegions) do
			local r = regions[regionID]
			if r.surface and r.surface.damage and ValidUnit(unitID) then
				local _, y, _ = Spring.GetUnitPosition(unitID)
				if y < r.surface.height + 2 and not Spring.GetUnitTransporter(unitID) then
					Spring.AddUnitDamage(unitID, r.surface.damage)
				end
			end
		end
	end
end

function gadget:Shutdown()
	GG.MapRegions = nil
end
