local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types
local enums = GG["MissionAPI"].Modules.ParameterTypes.Enums

local function setAiState(state, teamID)
	GG["CampaignAI"].SetAiState(enums[ParameterTypes.AiState][state], teamID)
end

return {
	{
		type = "SetAiState",
		parameters = {
			{ name = "state", required = true, type = ParameterTypes.AiState },
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
		},
		actionFunction = setAiState,
	},
}
