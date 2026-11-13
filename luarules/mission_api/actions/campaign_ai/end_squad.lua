local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function cancelSquad(squadName)
	local squadID, teamID = GG["MissionAPI"].Modules.Squads.Cancel(squadName)
	if squadID then
		GG["CampaignAI"].CancelSquad(squadID, teamID)
	end
end

local function disbandSquad(squadName)
	local squadID, teamID = GG["MissionAPI"].Modules.Squads.Get(squadName)
	if squadID then
		GG["CampaignAI"].DisbandSquad(squadID, teamID)
	end
end

return {
	{
		type = "CancelSquad",
		parameters = {
			{ name = "squadName", required = true, type = ParameterTypes.SquadName },
		},
		actionFunction = cancelSquad,
	},
	{
		type = "DisbandSquad",
		parameters = {
			{ name = "squadName", required = true, type = ParameterTypes.SquadName },
		},
		actionFunction = disbandSquad,
	},
}
