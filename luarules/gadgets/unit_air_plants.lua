function gadget:GetInfo()
	return {
		name = "AirPlantParents",
		desc = "Adds options to air plants, makes building aircraft neutral",
		author = "TheFatController",
		date = "15 Dec 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
	return
end

local EditUnitCmdDesc = Spring.EditUnitCmdDesc
local FindUnitCmdDesc = Spring.FindUnitCmdDesc
local InsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local GiveOrderToUnit = Spring.GiveOrderToUnit
local SetUnitNeutral = Spring.SetUnitNeutral
local CMD_AUTOREPAIRLEVEL = CMD.AUTOREPAIRLEVEL
local CMD_IDLEMODE = CMD.IDLEMODE

local isAirplane = {}
local isAirplant = {
	[UnitDefNames.corap.id] = true,
	[UnitDefNames.coraap.id] = true,
	[UnitDefNames.corplat.id] = true,
	[UnitDefNames.armap.id] = true,
	[UnitDefNames.armaap.id] = true,
	[UnitDefNames.armplat.id] = true
}
for udid, ud in pairs(UnitDefs) do
	for id, v in pairs(isAirplant) do
		if string.find(ud.name, UnitDefs[id].name) then
			isAirplant[udid] = v
		end
	end
	if ud.canFly then
		isAirplane[udid] = true
	end
end

local plantList = {}
local buildingUnits = {}

local landCmd = {
	id = 34569,
	name = "apLandAt",
	action = "apLandAt",
	type = CMDTYPE.ICON_MODE,
	tooltip = "setting for Aircraft leaving the plant",
	params = { '1', ' Fly ', 'Land' }
}

local airCmd = {
	id = 34570,
	name = "apAirRepair",
	action = "apAirRepair",
	type = CMDTYPE.ICON_MODE,
	tooltip = "return to base and land on air repair pad below this health percentage",
	params = { '1', 'LandAt 0', 'LandAt 30', 'LandAt 50', 'LandAt 80' }
	--params  = { '1', 'LandAt 30', 'LandAt 50', 'LandAt 70'}			-- NOTE: this works for airlabs, but air units still have the old values somehow
}

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if isAirplant[unitDefID] then
		InsertUnitCmdDesc(unitID, 500, landCmd)
		InsertUnitCmdDesc(unitID, 500, airCmd)
		plantList[unitID] = { landAt = 0, repairAt = 1 }
	elseif plantList[builderID] then
		GiveOrderToUnit(unitID, CMD_AUTOREPAIRLEVEL, { plantList[builderID].repairAt }, 0)
		GiveOrderToUnit(unitID, CMD_IDLEMODE, { 0,}, 0)
		SetUnitNeutral(unitID, true)
		buildingUnits[unitID] = true
	end
	if isAirplane[unitDefID] then
		GiveOrderToUnit(unitID, CMD_IDLEMODE, {0,}, 0)
		--EditUnitCmdDesc(unitID, CMD_AUTOREPAIRLEVEL, airCmd)		-- I tried different variations, didnt work
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	plantList[unitID] = nil
	buildingUnits[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if buildingUnits[unitID] then
		SetUnitNeutral(unitID, false)
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if isAirplant[unitDefID] then
		if (cmdID == 34569) then
			local cmdDescID = FindUnitCmdDesc(unitID, 34569)
			landCmd.params[1] = cmdParams[1]
			EditUnitCmdDesc(unitID, cmdDescID, landCmd)
			plantList[unitID].landAt = cmdParams[1]
			landCmd.params[1] = 1
			return false
		elseif (cmdID == 34570) then
			local cmdDescID = FindUnitCmdDesc(unitID, 34570)
			airCmd.params[1] = cmdParams[1]
			EditUnitCmdDesc(unitID, cmdDescID, airCmd)
			plantList[unitID].repairAt = cmdParams[1]
			airCmd.params[1] = 1
			return false
		end
	end
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
