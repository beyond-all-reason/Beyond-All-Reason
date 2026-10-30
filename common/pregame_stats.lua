-- BAR previews are real engine units. Correct their counters at the read boundary,
-- including historical samples, without changing the engine/replay statistics.
local getHistory = Spring.GetTeamStatsHistory
local getParam = Spring.GetTeamRulesParam

return function(teamID, ...)
	local history = getHistory(teamID, ...)
	if type(history) ~= "table" then
		return history
	end
	local produced = getParam(teamID, "pregameUnitsProduced") or 0
	local died = getParam(teamID, "pregameUnitsDied") or 0
	for _, sample in ipairs(history) do
		-- All previews are removed before the first snapshot. Clamp while pregame
		-- cleanup is in flight, or for an initial empty snapshot in an old replay.
		sample.unitsProduced = math.max(0, sample.unitsProduced - produced)
		sample.unitsDied = math.max(0, sample.unitsDied - died)
	end
	return history
end
