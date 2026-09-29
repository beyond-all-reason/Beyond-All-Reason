-- Enable/Disable AI's direct control over its units
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local tracking = GG['MissionAPI'].Modules.Tracking
local trackedUnitIDs = GG["MissionAPI"].trackedUnitIDs

local function setUnitsControlEnabled(unitTrackName, isEnabled, teamID)
	if tracking.IsUnitNameUntracked(unitTrackName) then return end

	local unitIDs = {}
	for id in pairs(trackedUnitIDs[unitTrackName]) do
		table.insert(unitIDs, id)
	end

	GG["CampaignAI"].SetUnitsCtrlEnabled(unitIDs, isEnabled, teamID)
end

return {
	{
		type = 'SetUnitsControlEnabled',
		parameters = {
			{ name = 'unitTrackName', required = true, type = ParameterTypes.UnitName },
			{ name = 'isEnabled', required = true, type = ParameterTypes.Boolean },
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = setUnitsControlEnabled,
	}
}
