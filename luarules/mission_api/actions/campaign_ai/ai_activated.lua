-- Enable/Disable events processing of campaign AI
local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types
local teams = GG["MissionAPI"].Teams

local function activateAI(teamName)
	GG["CampaignAI"].SetAiActive(true, teams[teamName])
end

local function deactivateAI(teamName)
	GG["CampaignAI"].SetAiActive(false, teams[teamName])
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
