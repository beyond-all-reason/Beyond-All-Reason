function gadget:GetInfo()
   return {
      name = "Air Transports fix",
      desc = "always unloads its load + better height-unloading at steeper cliffs",
      author = "Floris and BD",
      date = "2015",
      license = "",
      layer = 0,
      enabled = true,
   }
end


if (gadgetHandler:IsSyncedCode()) then


else
	-- add a move cmd in front each air-trans load/unload cmd, because else the trans wont respect smoothmesh
	function gadget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdOpts, cmdParams)
		if not Spring.GetSpectatingState() and teamID == Spring.GetLocalTeamID() and unitID and cmdID and (cmdID==CMD.UNLOAD_UNIT or cmdID==CMD.UNLOAD_UNITS or cmdID==CMD.LOAD_UNIT or cmdID==CMD.LOAD_UNITS) and  UnitDefs[unitDefID].canFly then
			if	((cmdID==CMD.UNLOAD_UNIT or cmdID==CMD.UNLOAD_UNITS) and #Spring.GetUnitIsTransporting(unitID) > 0) then
				local queuePos = 0
				if #cmdParams == 1 then
					--target is unitid
					cmdParams =  Spring.GetUnitPosition(unitID)
				end
				if math.bit_and(cmdOpts,CMD.OPT_SHIFT) ~= 0 then
					queuePos = Spring.GetUnitCommands(unitID,0)-1
				end
				CallAsTeam( Spring.GetLocalTeamID(),Spring.GiveOrderToUnit,unitID, CMD.INSERT, {queuePos, CMD.MOVE, (CMD.OPT_SHIFT + CMD.OPT_INTERNAL), cmdParams[1], cmdParams[2], cmdParams[3]}, {"alt"})
			end
		end
	end
end
