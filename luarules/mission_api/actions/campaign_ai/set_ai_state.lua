local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function setAiState(state, teamID)
	GG["CampaignAI"].SetAiState(state, teamID)
end

return {
	{
		type = "SetAiState",
		parameters = {
			{ name = "state", required = true, type = ParameterTypes.String },
			{ name = "teamID", required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = setAiState,
	},
}
