local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function setProductionEnabled(unitName, teamID, isEnabled)
	local trackedUnitIDs = GG["MissionAPI"].trackedUnitIDs[unitName]
	if not trackedUnitIDs then
		return
	end

	-- Sorted, so the message does not depend on the order pairs walks the units in.
	local unitIDs = table.keys(trackedUnitIDs)
	table.sort(unitIDs)
	GG["CampaignAI"].SetProductionEnabled(unitIDs, isEnabled, teamID)
end

local function enableProduction(unitName, teamID)
	setProductionEnabled(unitName, teamID, true)
end

local function disableProduction(unitName, teamID)
	setProductionEnabled(unitName, teamID, false)
end

return {
	{
		type = "EnableProduction",
		parameters = {
			{ name = "unitName", required = true, type = ParameterTypes.UnitName },
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
		},
		actionFunction = enableProduction,
	},
	{
		type = "DisableProduction",
		parameters = {
			{ name = "unitName", required = true, type = ParameterTypes.UnitName },
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
		},
		actionFunction = disableProduction,
	},
}
