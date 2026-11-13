local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function setSquadRepeatEnabled(squadName, isRepeating)
	local squadID, teamID = GG["MissionAPI"].Modules.Squads.SetRepeating(squadName, isRepeating)
	if squadID then
		GG["CampaignAI"].SetSquadRepeat(squadID, isRepeating, teamID)
	end
end

local function enableSquadRepeat(squadName)
	setSquadRepeatEnabled(squadName, true)
end

local function disableSquadRepeat(squadName)
	setSquadRepeatEnabled(squadName, false)
end

return {
	{
		type = "EnableSquadRepeat",
		parameters = {
			{ name = "squadName", required = true, type = ParameterTypes.SquadName },
		},
		actionFunction = enableSquadRepeat,
	},
	{
		type = "DisableSquadRepeat",
		parameters = {
			{ name = "squadName", required = true, type = ParameterTypes.SquadName },
		},
		actionFunction = disableSquadRepeat,
	},
}
