-- SPDX-License-Identifier: GPL-2.0-or-later
function gadget:GetInfo()
	return {
		name = "Map regions",
		desc = "Map region isolation for multi-region maps",
		author = "Codex",
		license = "GPL v2 or later",
		layer = -1000,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local mapRegions = VFS.Include("luarules/Utilities/map_regions.lua")
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

local regions = mapRegions.regions
local Region = mapRegions.Region
local unitRegion = {}

local function ValidUnit(unitID)
	return unitID and Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID)
end

local function GetUnitRegion(unitID)
	if unitRegion[unitID] then
		return unitRegion[unitID]
	end
	local x, _, z = Spring.GetUnitPosition(unitID)
	return Region(x, z)
end

local function SetUnitRegion(unitID, regionID)
	unitRegion[unitID] = regionID
	Spring.SetUnitRulesParam(unitID, "map_region", regionID, { allied = true, inlos = true })
	for _, cargoID in ipairs(Spring.GetUnitIsTransporting(unitID) or {}) do
		SetUnitRegion(cargoID, regionID)
	end
end

-- Commands whose parameters are neither world positions nor unit/feature IDs.
local nonSpatialCommands = {
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

local function IsNonSpatialCommand(unitID, cmdID)
	if cmdID >= 0 and nonSpatialCommands[cmdID] then
		return true
	end
	if unitID and cmdID >= 0 then
		local cmdDescID = Spring.FindUnitCmdDesc(unitID, cmdID)
		if cmdDescID then
			---@diagnostic disable-next-line: redundant-parameter
			local cmdDesc = Spring.GetUnitCmdDescs(unitID, cmdDescID, cmdDescID) ---@type CommandDescription[]?
			local cmdType = cmdDesc and cmdDesc[1] and cmdDesc[1].type
			if cmdType and nonSpatialCmdTypes[cmdType] then
				return true
			end
		end
	end
	return false
end

local function GetCommandRegion(unitID, cmdID, cmdParams)
	if IsNonSpatialCommand(unitID, cmdID) then
		return nil, false
	end
	if cmdID == GameCMD.UNIT_SET_TARGET_RECTANGLE and #cmdParams >= 4 then
		local r1, r2 = Region(cmdParams[1], cmdParams[2]), Region(cmdParams[3], cmdParams[4])
		return (r1 == r2 and r1) or nil, true
	end
	local count = #cmdParams
	if count == 3 or count == 4 then
		return Region(cmdParams[1], cmdParams[3]), true
	end
	if count == 6 then
		local r1, r2 = Region(cmdParams[1], cmdParams[3]), Region(cmdParams[4], cmdParams[6])
		return (r1 == r2 and r1) or nil, true
	end
	if count == 1 then
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

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.ANY)
	assert(
		Game.mapSizeX == mapRegions.size[1] and Game.mapSizeZ == mapRegions.size[2],
		"Map region manifest and physical map disagree"
	)
	local sensorRegions = {}
	for i, r in ipairs(regions) do
		sensorRegions[i] = { r.x0, r.z0, r.x1, r.z1 }
	end
	assert(
		Spring.SetSensorRegions(sensorRegions),
		"Sensor regions must align to the engine sensor grid and be configured before simulation starts"
	)
	assert(Spring.SetMapDamageRegions(sensorRegions), "Crater regions must be configured before simulation starts")

	Spring.SetGameRulesParam("map_regions", #regions)
	for i, r in ipairs(regions) do
		for _, k in ipairs({ "x0", "z0", "x1", "z1" }) do
			Spring.SetGameRulesParam("map_region_" .. i .. "_" .. k, r[k])
		end
	end

	---@diagnostic disable-next-line: redundant-parameter
	Spring.SetTerrainTypeData(255, 0, 0, 0, 0, 1000000, false, "Region barrier")
	for x = 0, Game.mapSizeX - 8, 8 do
		for z = 0, Game.mapSizeZ - 8, 8 do
			if not Region(x + 4, z + 4) then
				Spring.SetMapSquareTerrainType(x, z, 255)
				if x % 16 == 0 and z % 16 == 0 then
					Spring.SetSquareBuildingMask(math.floor(x / 16), math.floor(z / 16), 0)
				end
			end
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
end

function gadget:UnitCreated(unitID, _unitDefID, _unitTeam)
	local x, _, z = Spring.GetUnitPosition(unitID)
	SetUnitRegion(unitID, Region(x, z))
end

function gadget:AllowCommand(unitID, _unitDefID, _unitTeam, cmdID, cmdParams, _cmdOptions)
	local actualCmdID, actualParams = cmdID, cmdParams
	if cmdID == CMD.INSERT then
		if #cmdParams < 3 then
			return false
		end
		actualCmdID = cmdParams[2]
		actualParams = {}
		for i = 4, #cmdParams do
			actualParams[#actualParams + 1] = cmdParams[i]
		end
	end
	local destination, isSpatial = GetCommandRegion(unitID, actualCmdID, actualParams)
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
	if f % 15 == 0 then
		for unitID, regionID in pairs(unitRegion) do
			if ValidUnit(unitID) and not Spring.GetUnitTransporter(unitID) then
				local x, y, z = Spring.GetUnitPosition(unitID)
				local unitDefID = Spring.GetUnitDefID(unitID)
				local isAir = unitDefID and UnitDefs[unitDefID] and UnitDefs[unitDefID].canFly
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
					local tx = math.max(r.x0 + 24, math.min(r.x1 - 24, x))
					local tz = math.max(r.z0 + 24, math.min(r.z1 - 24, z))
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
		for unitID, regionID in pairs(unitRegion) do
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
