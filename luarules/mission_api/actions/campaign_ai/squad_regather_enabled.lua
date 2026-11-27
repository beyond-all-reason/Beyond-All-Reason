local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function setSquadRegatherEnabled(squadName, regathers)
	local squadID, teamID = GG["MissionAPI"].Modules.Squads.SetRegathers(squadName, regathers)
	if squadID then
		GG["CampaignAI"].SetSquadRegather(squadID, regathers, teamID)
	end
end

local function enableSquadRegather(squadName)
	setSquadRegatherEnabled(squadName, true)
end

local function disableSquadRegather(squadName)
	setSquadRegatherEnabled(squadName, false)
end

return {
	{
		type = "EnableSquadRegather",
		parameters = {
			{ name = "squadName", required = true, type = ParameterTypes.SquadName },
		},
		actionFunction = enableSquadRegather,
	},
	{
		type = "DisableSquadRegather",
		parameters = {
			{ name = "squadName", required = true, type = ParameterTypes.SquadName },
		},
		actionFunction = disableSquadRegather,
	},
}
