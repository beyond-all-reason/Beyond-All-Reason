function gadget:GetInfo()
	return {
		name 	= "Manual launch command",
		desc	= "Adds a distinct Launch command for manually fired missiles",
		date	= "December 2021",
		layer	= 0,
		enabled = true,
	}
end

VFS.Include('luarules/configs/customcmds.h.lua')

if gadgetHandler:IsSyncedCode() then
	----------------
	--   SYNCED   --
	----------------
	local manualLaunchUnits = {}
	for unitDefId, unitDef in pairs(UnitDefs) do
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

	function gadget:CommandFallback(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
		if cmdID == CMD_MANUAL_LAUNCH then
			Spring.GiveOrderToUnit(unitID, CMD.MANUALFIRE, cmdParams, cmdOptions)
		end
	end

	-- function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- 	if cmdID == CMD.MANUALFIRE then
	-- 		return manualLaunchUnits[unitDefID]
	-- 	end
	-- end

	function gadget:UnitCreated(unitID, unitDefID, teamID)
		if manualLaunchUnits[unitDefID] then
			local manualFireCommand = Spring.FindUnitCmdDesc(unitID, CMD.DGUN)
			-- Spring.RemoveUnitCmdDesc(unitID, manualFireCommand)
			Spring.InsertUnitCmdDesc(unitID, launchCommand)
		end
	end

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_MANUAL_LAUNCH)
	end

else
	------------------
	--   UNSYNCED   --
	------------------
	function gadget:Initialize()
		Spring.SetCustomCommandDrawData(CMD_MANUAL_LAUNCH, CMDTYPE.ICON_UNIT_OR_MAP, { 1, 0, 0, .8 }, false)
	end

end