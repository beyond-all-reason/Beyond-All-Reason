function gadget:GetInfo()
	return {
		name = "ReverseMovementHandler",
		desc = "Sets reverse speeds/angles/distances",
		author = "[Fx]Doo",
		date = "27 of July 2017",
		layer = 0,
		enabled = true
	}
end


if (gadgetHandler:IsSyncedCode()) then
	local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
	local cmdCtrl = CMD.OPT_CTRL
	local reverseUnit = {}
	local refreshList = {}

	local unitRspeed = {}
	local unitSpeed = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.rSpeed > 0 then
			unitRspeed[unitDefID] = unitDef.rSpeed
			unitSpeed[unitDefID] = unitDef.speed
		end
	end

	function gadget:UnitCreated(unitID)
		local unitDefID = Spring.GetUnitDefID(unitID)
		if unitRspeed[unitDefID] then
			reverseUnit[unitID] = unitDefID
			refreshList[unitID] = unitDefID
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxSpeed", unitSpeed[unitDefID])
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseSpeed", 0)
		end
	end

	function gadget:UnitDestroyed(unitID) -- Erase killed units from table
		reverseUnit[unitID] = nil
		refreshList[unitID] = nil
	end

	function gadget:Initialize()
		for ct, unitID in pairs(Spring.GetAllUnits()) do
			gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
		end
	end

	function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		if reverseUnit[unitID] then
			refreshList[unitID] = unitDefID
		end
	end

	function gadget:UnitIdle(unitID, unitDefID)
		if reverseUnit[unitID] then
			refreshList[unitID] = unitDefID
		end
	end

	function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
		if reverseUnit[unitID] then
			refreshList[unitID] = unitDefID
		end
	end

	function gadget:GameFrame(f)
		for unitID, unitDefID in pairs(refreshList) do
			local cmdID, cmdOptions = spGetUnitCurrentCommand(unitID, 1)
			if cmdID and (cmdOptions / cmdCtrl) % 2 == 1 then
				Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxSpeed", unitRspeed[unitDefID])
				Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseSpeed", unitRspeed[unitDefID])
			else
				Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxSpeed", unitSpeed[unitDefID])
				Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseSpeed", 0)
			end
			refreshList[unitID] = nil
		end
	end
end