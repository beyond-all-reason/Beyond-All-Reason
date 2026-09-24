local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "AirPlantParents",
		desc = "Adds options to air plants, makes building aircraft neutral",
		author = "TheFatController",
		date = "15 Dec 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local EditUnitCmdDesc = Spring.EditUnitCmdDesc
local FindUnitCmdDesc = Spring.FindUnitCmdDesc
local InsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local GiveOrderToUnit = Spring.GiveOrderToUnit
local SetUnitNeutral = Spring.SetUnitNeutral
local CMD_IDLEMODE = CMD.IDLEMODE
local CMD_LAND_AT = GameCMD.LAND_AT

local isAirplant = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.airfactory then
		isAirplant[unitDefID] = true
	end
end

local plantList = {}
local buildingUnits = {}

local landCmd = {
	id = CMD_LAND_AT,
	name = "apLandAt",
	action = "aplandat",
	type = CMDTYPE.ICON_MODE,
	tooltip = "setting for Aircraft leaving the plant",
	params = { "1", " Fly ", "Land" },
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
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if buildingUnits[unitID] then
		SetUnitNeutral(unitID, false)
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_LAND_AT)
end

function gadget:AllowCommand(
	unitID,
	unitDefID,
	teamID,
	cmdID,
	cmdParams,
	cmdOptions,
	cmdTag,
	playerID,
	fromSynced,
	fromLua
)
	if isAirplant[unitDefID] and plantList[unitID] then
		local cmdDescID = FindUnitCmdDesc(unitID, CMD_LAND_AT)
		landCmd.params[1] = cmdParams[1]
		EditUnitCmdDesc(unitID, cmdDescID, landCmd)
		plantList[unitID] = cmdParams[1]
		return false
	end
	return true
end
