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

VFS.Include('luarules/configs/customcmds.h.lua')

if not gadgetHandler:IsSyncedCode() then
	return
end

local manualLaunchUnits = {}
for unitDefId, unitDef in pairs(UnitDefs) do
	local decoyFor = unitDef.customParams.decoyfor
	unitDef = decoyFor and UnitDefNames[decoyFor] or unitDef

	if unitDef.canManualFire and not unitDef.customParams.iscommander then
		manualLaunchUnits[unitDefId] = true
	end
end

local launchCommand = {
	id = CMD_MANUAL_LAUNCH,
	action = "manuallaunch",
	cursor = 'cursorattack',
	type = CMDTYPE.ICON_UNIT_OR_MAP,
}

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD.INSERT and cmdParams[2] == CMD_MANUAL_LAUNCH then
		cmdParams[2] = CMD.MANUALFIRE
		Spring.GiveOrderToUnit(unitID, CMD.INSERT, cmdParams, cmdOptions.coded)
		return false
	elseif cmdID == CMD_MANUAL_LAUNCH then
		Spring.GiveOrderToUnit(unitID, CMD.MANUALFIRE, cmdParams, cmdOptions.coded)
		return false
	end

	return true
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	if manualLaunchUnits[unitDefID] then
		local manualFireCommand = Spring.FindUnitCmdDesc(unitID, CMD.MANUALFIRE)
		Spring.RemoveUnitCmdDesc(unitID, manualFireCommand)
		Spring.InsertUnitCmdDesc(unitID, launchCommand)
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterCMDID(CMD_MANUAL_LAUNCH)
	gadgetHandler:RegisterAllowCommand(CMD.INSERT)
	gadgetHandler:RegisterAllowCommand(CMD_MANUAL_LAUNCH)
end
