local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local matchingUnits = GG['MissionAPI'].Modules.UnitQuery.MatchingUnits

local markerParameters = {
	{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
	{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
	{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
	{ name = 'markerType',  required = false, type = ParameterTypes.String },
	requiresOneOf = { 'unitName', 'unitDefName' },
}

local function addUnitMarker(unitName, unitDefName, teamID, markerType)
	local unitMarkers = GG['MissionAPI'].Modules.UnitMarkers
	for _, unitID in ipairs(matchingUnits(unitName, unitDefName, teamID)) do
		unitMarkers.AddUnitMarker(unitID, markerType)
	end
end

local function removeUnitMarker(unitName, unitDefName, teamID, markerType)
	local unitMarkers = GG['MissionAPI'].Modules.UnitMarkers
	for _, unitID in ipairs(matchingUnits(unitName, unitDefName, teamID)) do
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
