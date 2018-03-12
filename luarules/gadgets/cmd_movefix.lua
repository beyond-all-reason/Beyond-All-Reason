if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
  return {
	name 	= "Move commands fix",
	desc	= "Blocks move commands if not reachable",
	author	= "Doo",
	date	= "2018",
	license	= "GNU GPL, v2 or later",
	layer	= 0,
	enabled = false,
  }
end
attempt = {}

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)

	if (cmdID == CMD.MOVE or cmdID == CMD.RAWMOVE) and UnitDefs[unitDefID].canFly == false then
		-- if UnitDefs[unitDefID].moveDef and UnitDefs[unitDefID].moveDef.name and string.find(UnitDefs[unitDefID].moveDef.name, "boat") then -- unquote if you want this for ships only
			if #cmdParams == 6 then
				if Spring.TestMoveOrder(unitDefID, cmdParams[4],cmdParams[5],cmdParams[6],0,0,0,true,false,false) then
				return true
				else
				return false
				end
			elseif #cmdParams == 3 then
				if Spring.TestMoveOrder(unitDefID, cmdParams[1],cmdParams[2],cmdParams[3],0,0,0,true,false,false) and not (cmdParams[3] >= 95 and cmdParams[3] <= 97) then
					return true
				elseif cmdOptions["coded"] ~= 0 and not (cmdParams[3] >= 95 and cmdParams[3] <= 97) then
				FindClosestPoint(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
				return false
				else
				return false
				end
			end
		end
	-- end -- unquote if you want this for ships only
	return true
end

function FindClosestPoint(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if not attempt[unitID] then attempt[unitID] = 1 end
	if attempt[unitID] <= 128 then
	local px, py, pz = Spring.GetUnitPosition(unitID)
	if #cmdParams == 6 then
		cmdParams[4] = cmdParams[4] - (cmdParams[4] - px)/128
		cmdParams[5] = cmdParams[5] - (cmdParams[5] - py)/128
		cmdParams[6] = cmdParams[5] - (cmdParams[6] - pz)/128
		if Spring.TestMoveOrder(unitDefID, cmdParams[4],cmdParams[5],cmdParams[6],0,0,0,true,false,false) then
			return Spring.GiveOrderToUnit(unitID, cmdID, cmdParams, cmdOptions)
		else
			FindClosestPoint(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
			return false
		end
	elseif #cmdParams == 3 then
		cmdParams[1] = cmdParams[1] - (cmdParams[1] - px)/128
		cmdParams[2] = cmdParams[2] - (cmdParams[2] - py)/128
		cmdParams[3] = cmdParams[3] - (cmdParams[3] - pz)/128
		if Spring.TestMoveOrder(unitDefID, cmdParams[1],cmdParams[2],cmdParams[3],0,0,0,true,false,false) then
			return Spring.GiveOrderToUnit(unitID, cmdID, cmdParams, cmdOptions)
		else
			FindClosestPoint(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
			return false
		end
	end
		attempt[unitID] = attempt[unitID] + 1
	else
		attempt[unitID] = nil
	end

end


