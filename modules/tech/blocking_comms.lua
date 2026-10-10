local TechBlockingComms = {}

---@param teamId integer
---@param springRepo Spring the engine, or a spec's stand-in
---@return TechBlockingContext?
function TechBlockingComms.fromTeamRules(teamId, springRepo)
	local rawLevel = springRepo.GetTeamRulesParam(teamId, "tech_level")
	if not rawLevel then
		return nil
	end
	local rawPoints = springRepo.GetTeamRulesParam(teamId, "tech_points")
	local rawT2 = springRepo.GetTeamRulesParam(teamId, "tech_t2_threshold")
	local rawT3 = springRepo.GetTeamRulesParam(teamId, "tech_t3_threshold")
	local level = tonumber(rawLevel or 1) or 1
	return {
		level = level,
		points = tonumber(rawPoints or 0) or 0,
		t2Threshold = tonumber(rawT2 or 0) or 0,
		t3Threshold = tonumber(rawT3 or 0) or 0,
		nextLevel = level < 2 and 2 or 3,
		nextThreshold = level < 2 and (tonumber(rawT2 or 0) or 0) or (tonumber(rawT3 or 0) or 0),
	}
end

return TechBlockingComms
