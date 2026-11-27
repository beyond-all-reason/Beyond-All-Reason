local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types
local enums = GG["MissionAPI"].Modules.ParameterTypes.Enums

local function setSquadTask(squadName, task, position, attackRange)
	local squadID, teamID = GG["MissionAPI"].Modules.Squads.GetAssembled(squadName)
	if not squadID then
		return
	end

	task = enums[ParameterTypes.SquadTask][task]
	GG["CampaignAI"].SetSquadTask(squadID, task, position.x, position.z, attackRange, teamID)
end

return {
	{
		type = "SetSquadTask",
		parameters = {
			{ name = "squadName", required = true, type = ParameterTypes.SquadName },
			{ name = "task", required = true, type = ParameterTypes.SquadTask },
			{ name = "position", required = true, type = ParameterTypes.Position },
			{ name = "attackRange", required = false, type = ParameterTypes.Quantity }, -- elmos
		},
		actionFunction = setSquadTask,
	},
}
