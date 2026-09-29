-- Enable/Disable AI's direct control over its units
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local tracking = GG['MissionAPI'].Modules.Tracking
local trackedUnitIDs = GG["MissionAPI"].trackedUnitIDs

local function collectUnitIDs(unitName)
	if tracking.IsUnitNameUntracked(unitName) then
		return false
	end

	local unitIDs = {}
	for id in pairs(trackedUnitIDs[unitName]) do
		table.insert(unitIDs, id)
	end
	return unitIDs
end

local function enableUnitsControl(unitName, teamID)
	local unitIDs = collectUnitIDs(unitName)
	if not unitIDs then return end
	GG["CampaignAI"].SetUnitsCtrlEnabled(unitIDs, true, teamID)
end

local function disableUnitsControl(unitName, teamID)
	local unitIDs = collectUnitIDs(unitName)
	if not unitIDs then return end
	GG["CampaignAI"].SetUnitsCtrlEnabled(unitIDs, false, teamID)
end

return {
	{
		type = 'EnableUnitsControl',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = enableUnitsControl,
	},
	{
		type = 'DisableUnitsControl',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = disableUnitsControl,
	}
}
