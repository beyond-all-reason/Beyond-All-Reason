local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local getMatchingUnits = GG['MissionAPI'].Modules.UnitQuery.GetMatchingUnits

local markerParameters = {
	{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
	{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
	{ name = 'teamName',    required = false, type = ParameterTypes.TeamName },
	{ name = 'markerType',  required = false, type = ParameterTypes.String },
	requiresOneOf = { 'unitName', 'unitDefName' },
}

local function addUnitMarker(unitName, unitDefName, teamID, markerType)
	local unitMarkers = GG['MissionAPI'].Modules.UnitMarkers
	for _, unitID in ipairs(getMatchingUnits(unitName, unitDefName, teamID)) do
		unitMarkers.AddUnitMarker(unitID, markerType)
	end
end

local function removeUnitMarker(unitName, unitDefName, teamID, markerType)
	local unitMarkers = GG['MissionAPI'].Modules.UnitMarkers
	for _, unitID in ipairs(getMatchingUnits(unitName, unitDefName, teamID)) do
		unitMarkers.RemoveUnitMarker(unitID, markerType)
	end
end

return {
	{
		type = 'AddUnitMarker',
		parameters = markerParameters,
		actionFunction = addUnitMarker,
	},
	{
		type = 'RemoveUnitMarker',
		parameters = markerParameters,
		actionFunction = removeUnitMarker,
	}
}
