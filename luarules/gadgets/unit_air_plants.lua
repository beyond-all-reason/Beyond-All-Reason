local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "AirPlantParents",
		desc = "Adds options to air plants, makes building aircraft neutral",
		author = "TheFatController",
		date = "15 Dec 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local EditUnitCmdDesc = SpringSynced.EditUnitCmdDesc
local FindUnitCmdDesc = SpringShared.FindUnitCmdDesc
local InsertUnitCmdDesc = SpringSynced.InsertUnitCmdDesc
local GiveOrderToUnit = SpringSynced.GiveOrderToUnit
local SetUnitNeutral = SpringSynced.SetUnitNeutral
local CMD_IDLEMODE = CMD.IDLEMODE
local CMD_LAND_AT = GameCMD.LAND_AT

local isAirplantNames = {
	corap = true,
	coraap = true,
	corplat = true,
	corapt3 = true,

	armap = true,
	armaap = true,
	armplat = true,
	armapt3 = true,

	legap = true,
	legaap = true,
	legapt3 = true,
	legsplab = true,
}
local isAirplantNamesCopy = table.copy(isAirplantNames)
for name,v in pairs(isAirplantNamesCopy) do
	isAirplantNames[name..'_scav'] = true
end
-- convert unitname -> unitDefID
local isAirplant = {}
for unitName, params in pairs(isAirplantNames) do
	if UnitDefNames[unitName] then
		isAirplant[UnitDefNames[unitName].id] = params
	end
end

local plantList = {}
local buildingUnits = {}
local unitsToDeneutralize = {}

local landCmd = {
	id = CMD_LAND_AT,
	name = "apLandAt",
	action = "apLandAt",
	type = CMDTYPE.ICON_MODE,
	tooltip = "setting for Aircraft leaving the plant",
	params = { '1', ' Fly ', 'Land' }
}

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if isAirplant[unitDefID] then
		landCmd.params[1] = 1
		plantList[unitID] = 1
		InsertUnitCmdDesc(unitID, 500, landCmd)
	elseif plantList[builderID] then
		GiveOrderToUnit(unitID, CMD_IDLEMODE, plantList[builderID], 0)
		SetUnitNeutral(unitID, true)
		buildingUnits[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	plantList[unitID] = nil
	buildingUnits[unitID] = nil
	unitsToDeneutralize[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if buildingUnits[unitID] then
		-- Delaying SetUnitNeutral to GameFrame to avoid /nocost race conditions
		unitsToDeneutralize[unitID] = true
		buildingUnits[unitID] = nil
	end
end

function gadget:GameFrame(frame)
	if next(unitsToDeneutralize) then
		for unitID in pairs(unitsToDeneutralize) do
			SetUnitNeutral(unitID, false)
		end
		unitsToDeneutralize = {}
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_LAND_AT)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if isAirplant[unitDefID] and plantList[unitID] then
		local cmdDescID = FindUnitCmdDesc(unitID, CMD_LAND_AT)
		landCmd.params[1] = cmdParams[1]
		EditUnitCmdDesc(unitID, cmdDescID, landCmd)
		plantList[unitID] = cmdParams[1]
		return false
	end
	return true
end