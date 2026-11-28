local action = {}

function action.available(fromTeam, targetTeam, spectator)
	if spectator or fromTeam == targetTeam or not Spring.AreTeamsAllied(fromTeam, targetTeam) then
		return false
	end
	local _, _, dead, isAI = Spring.GetTeamInfo(targetTeam, false)
	local luaAI = Spring.GetTeamLuaAI(targetTeam)
	return not dead
		and not isAI
		and (not luaAI or luaAI == "")
		and (Spring.GetTeamRulesParam(fromTeam, "givebackUnits" .. targetTeam) or 0) > 0
		and (Spring.GetTeamRulesParam(targetTeam, "numActivePlayers") or 0) > 0
end

function action.run(fromTeam, targetTeam, spectator)
	if not action.available(fromTeam, targetTeam, spectator) then
		return false
	end
	Spring.SendCommands("luarules giveback " .. targetTeam)
	return true
end

return action
