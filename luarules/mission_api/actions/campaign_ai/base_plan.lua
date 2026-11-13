local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function addToBasePlan(basePlanName, teamID, unitDefName, position, rebuild)
	if not UnitDefNames[unitDefName].isImmobile then
		local message = "[Mission API] Base plan needs a structure, not " .. unitDefName .. ": " .. basePlanName
		Spring.Log("base_plan.lua", LOG.WARNING, message)
		return
	end

	local basePlanID = GG["MissionAPI"].Modules.BasePlans.GetOrStart(basePlanName, teamID)
	if basePlanID then
		local unitDefID = UnitDefNames[unitDefName].id
		GG["CampaignAI"].AddToBasePlan(basePlanID, unitDefID, position.x, position.z, rebuild or false, teamID)
	end
end

local function cancelBasePlan(basePlanName)
	local basePlanID, teamID = GG["MissionAPI"].Modules.BasePlans.Cancel(basePlanName)
	if basePlanID then
		GG["CampaignAI"].CancelBasePlan(basePlanID, teamID)
	end
end

return {
	{
		type = "AddToBasePlan",
		parameters = {
			{ name = "basePlanName", required = true, type = ParameterTypes.BasePlanName },
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
			{ name = "unitDefName", required = true, type = ParameterTypes.UnitDefName },
			{ name = "position", required = true, type = ParameterTypes.Position },
			{ name = "rebuild", required = false, type = ParameterTypes.Boolean }, -- whenever it is destroyed
		},
		actionFunction = addToBasePlan,
	},
	{
		type = "CancelBasePlan",
		parameters = {
			{ name = "basePlanName", required = true, type = ParameterTypes.BasePlanName },
		},
		actionFunction = cancelBasePlan,
	},
}
