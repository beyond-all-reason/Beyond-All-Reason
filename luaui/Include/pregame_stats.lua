-- Pregame proxies are created and removed before the first engine statistics
-- snapshot. Their cumulative offsets apply to all samples, not to real units.
local originalGetTeamStatsHistory = Spring.GetTeamStatsHistory

Spring.GetTeamStatsHistory = function(teamID, ...)
	-- Forward the exact argument list: one argument returns a count, whereas
	-- an explicit nil index still requests a history table from the engine.
	local history = originalGetTeamStatsHistory(teamID, ...)
	if type(history) ~= "table" then
		return history
	end

	local produced = Spring.GetTeamRulesParam(teamID, "pregameUnitsProduced") or 0
	local died = Spring.GetTeamRulesParam(teamID, "pregameUnitsDied") or 0
	for _, sample in ipairs(history) do
		sample.unitsProduced = sample.unitsProduced + produced
		sample.unitsDied = sample.unitsDied + died
	end
	return history
end
