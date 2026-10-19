local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

-- currently the engine cannot move an AI to another team.
local function changeTeam(oldTeamName, newTeamName)
	local teams = GG["MissionAPI"].Teams
	local oldTeamID, newTeamID = teams[oldTeamName], teams[newTeamName]

	local _, _, _, hasAI = Spring.GetTeamInfo(oldTeamID, false)
	---@cast hasAI +boolean
	if hasAI then
		Spring.Log(
			"change_team.lua",
			LOG.WARNING,
			"[Mission API] ChangeTeam moves players only, the AI of team '" .. oldTeamName .. "' stays"
		)
	end

	for _, playerID in ipairs(Spring.GetPlayerList(oldTeamID) or {}) do
		Spring.AssignPlayerToTeam(playerID, newTeamID)
	end
end

return {
	{
		type = "ChangeTeam",
		parameters = {
			{ name = "oldTeam", required = true, type = ParameterTypes.TeamName },
			{ name = "newTeam", required = true, type = ParameterTypes.TeamName },
		},
		actionFunction = changeTeam,
	},
}
