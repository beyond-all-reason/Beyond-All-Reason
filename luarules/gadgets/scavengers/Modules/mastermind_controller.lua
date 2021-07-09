local targetUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/prioritytargets.lua")
MastermindPriorityTargets = {}


function MasterMindTargetListTargetSpotted(unitID, unitTeam, unitEnteredTeam, unitDefID)
	MastermindKnownTarget = false
	if targetUnitList.PriorityTargetsID[unitDefID] then
		if #MastermindPriorityTargets == 0 then
			table.insert(MastermindPriorityTargets,unitID)
		else
			for y = 1,#MastermindPriorityTargets do
				if MastermindPriorityTargets[y] == unitID then
					MastermindKnownTarget = true
					break
				end
			end
			if MastermindKnownTarget == false then
				table.insert(MastermindPriorityTargets,unitID)
			end
		end
	end

	MastermindKnownTarget = nil
end

function MasterMindTargetListTargetGone(unitID, unitTeam, unitEnteredTeam, unitDefID)
	MastermindKnownTarget = false
	if #MastermindPriorityTargets == 0 or MastermindKnownTarget then
		-- do nothing
	elseif targetUnitList.PriorityTargetsID[unitDefID] then
		for y = 1, #MastermindPriorityTargets do
			if MastermindPriorityTargets[y] == unitID then
				MastermindKnownTarget = true
				table.remove(MastermindPriorityTargets,y)
				break
			end
		end
	end

	MastermindKnownTarget = nil
end





function MasterMindLandTargetsListUpdate(n)

end

function MasterMindSeaTargetsListUpdate(n)

end

function MasterMindAirTargetsListUpdate(n)

end

function MasterMindAmphibiousTargetsListUpdate(n)

end