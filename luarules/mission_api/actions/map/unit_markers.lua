local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function matchingUnits(unitName, unitDefName, teamID)
	local unitDef = unitDefName and UnitDefNames[unitDefName] ---@as table
	local unitDefID = unitDef and unitDef.id ---@as UnitDefID?

	local candidates
	if unitName then
		local tracking = GG['MissionAPI'].Modules.Tracking
		if tracking.IsUnitNameUntracked(unitName) then
			return {}
		end
		candidates = {}
		for unitID in pairs(GG['MissionAPI'].trackedUnitIDs[unitName]) do
			candidates[#candidates + 1] = unitID
		end
	elseif teamID then
		candidates = unitDefID and Spring.GetTeamUnitsByDefs(teamID, unitDefID) or Spring.GetTeamUnits(teamID)
	elseif unitDefID then
		candidates = {}
		for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
			for _, teamIDOfAllyTeam in ipairs(Spring.GetTeamList(allyTeamID)) do
				table.append(candidates, Spring.GetTeamUnitsByDefs(teamIDOfAllyTeam, unitDefID))
			end
		end
	else
		return {}
	end

	local matched = {}
	for _, unitID in ipairs(candidates) do
		local matchesDef = not unitDefID or Spring.GetUnitDefID(unitID) == unitDefID
		local matchesTeam = not teamID or Spring.GetUnitTeam(unitID) == teamID
		if matchesDef and matchesTeam then
			matched[#matched + 1] = unitID
		end
	end
	return matched
end

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
