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
			{ name = "teamID", required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = activateAI,
	},
	{
		type = "DeactivateAI",
		parameters = {
			{ name = "teamID", required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = deactivateAI,
	},
}
