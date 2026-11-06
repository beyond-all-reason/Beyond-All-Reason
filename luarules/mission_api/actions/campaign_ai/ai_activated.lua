-- Enable/Disable events processing of campaign AI
local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function activateAI(teamID)
	GG["CampaignAI"].SetAiActive(true, teamID)
end

local function deactivateAI(teamID)
	GG["CampaignAI"].SetAiActive(false, teamID)
end

return {
	{
		type = "ActivateAI",
		parameters = {
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
		},
		actionFunction = activateAI,
	},
	{
		type = "DeactivateAI",
		parameters = {
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
		},
		actionFunction = deactivateAI,
	},
}
