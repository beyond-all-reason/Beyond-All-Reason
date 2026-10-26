local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

-- currently the engine cannot move an AI to another team.
local function changeTeam(oldTeamID, newTeamID)
	for _, playerID in ipairs(Spring.GetPlayerList(oldTeamID) or {}) do
		Spring.AssignPlayerToTeam(playerID, newTeamID)
	end
end

return {
	{
		type = "ChangeTeam",
		parameters = {
			{ name = "oldTeamName", required = true, type = ParameterTypes.TeamName, internal = "oldTeamID" },
			{ name = "newTeamName", required = true, type = ParameterTypes.TeamName, internal = "newTeamID" },
		},
		actionFunction = changeTeam,
	},
}
