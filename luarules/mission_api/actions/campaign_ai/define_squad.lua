local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function defineSquad(squadName, teamID, position, gatherRange, composition, attackRange)
	local squadID = GG["MissionAPI"].Modules.Squads.Define(squadName, teamID)
	if not squadID then
		return
	end

	local unitCounts = {}
	for unitDefName, count in pairs(composition) do
		unitCounts[UnitDefNames[unitDefName].id] = count
	end

	GG["CampaignAI"].DefineSquad(squadID, unitCounts, position.x, position.z, gatherRange, attackRange, teamID)
end

return {
	{
		type = "DefineSquad",
		parameters = {
			{ name = "squadName", required = true, type = ParameterTypes.SquadName },
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
			{ name = "position", required = true, type = ParameterTypes.Position },
			{ name = "gatherRange", required = true, type = ParameterTypes.Quantity }, -- elmos
			{ name = "composition", required = true, type = ParameterTypes.UnitDefCounts },
			{ name = "attackRange", required = false, type = ParameterTypes.Quantity }, -- elmos
		},
		actionFunction = defineSquad,
	},
}
