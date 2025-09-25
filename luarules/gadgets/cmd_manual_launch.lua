local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name 	= "Manual launch command",
		desc	= "Replaces manual fire command with a distinct Launch command for manually fired missiles",
		date	= "December 2021",
		layer	= 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local reissueOrder = Game.CustomCommands.ReissueOrder

local CMD_MANUALFIRE = CMD.MANUALFIRE
local launchCommand = {
	id = GameCMD.MANUAL_LAUNCH,
	action = "manuallaunch",
	cursor = 'cursorattack',
	type = CMDTYPE.ICON_UNIT_OR_MAP,
}

local manualLaunchUnits = {}
for unitDefId, unitDef in pairs(UnitDefs) do
	local decoyFor = unitDef.customParams.decoyfor
	unitDef = decoyFor and UnitDefNames[decoyFor] or unitDef

	if unitDef.canManualFire and not unitDef.customParams.iscommander then
		manualLaunchUnits[unitDefId] = true
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
	reissueOrder(unitID, CMD_MANUALFIRE, cmdParams, cmdOptions, cmdTag, fromInsert)
	return false
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	if manualLaunchUnits[unitDefID] then
		local manualFireCommand = Spring.FindUnitCmdDesc(unitID, CMD.MANUALFIRE)
		Spring.RemoveUnitCmdDesc(unitID, manualFireCommand)
		Spring.InsertUnitCmdDesc(unitID, launchCommand)
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterCMDID(GameCMD.MANUAL_LAUNCH)
	gadgetHandler:RegisterAllowCommand(GameCMD.MANUAL_LAUNCH)
end
