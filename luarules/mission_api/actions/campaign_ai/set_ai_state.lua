local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types
local enums = GG["MissionAPI"].Modules.ParameterTypes.Enums

local function setAiState(state, teamName)
	local teams = GG["MissionAPI"].Teams
	GG["CampaignAI"].SetAiState(enums[ParameterTypes.AiState][state], teams[teamName])
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
