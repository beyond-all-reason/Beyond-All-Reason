local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function nameUnits(unitName, teamID, unitDefName, area)
	local tracking = GG['MissionAPI'].Modules.Tracking
	local hasFilterOtherThanTeamID = unitDefName or area

	local allUnitsOfTeam = {}
	if not hasFilterOtherThanTeamID then
		allUnitsOfTeam = Spring.GetTeamUnits(teamID)
	end

	local unitsFromDef = {}
	if unitDefName and UnitDefNames[unitDefName] then
		local unitDefID = UnitDefNames[unitDefName].id
		if teamID then
			unitsFromDef = Spring.GetTeamUnitsByDefs(teamID, unitDefID)
		else
			for _, allyTeamID in pairs(Spring.GetAllyTeamList()) do
				for _, teamIDForAllyTeam in pairs(Spring.GetTeamList(allyTeamID)) do
					table.append(unitsFromDef, Spring.GetTeamUnitsByDefs(teamIDForAllyTeam, unitDefID))
				end
			end
		end
	end

	local unitsInArea = area and GG['MissionAPI'].Modules.AreaTracking.GetUnitsInArea(area, teamID) or {}

	local unitsToName = {}
	if hasFilterOtherThanTeamID then
		unitsToName = table.valueIntersection(
			unpack(table.filterArray({ unitsFromDef, unitsInArea }, function(tbl) return not table.isEmpty(tbl) end))
		)
	else
		unitsToName = allUnitsOfTeam
	end

	local trackUnit = tracking.TrackUnit
	for _, unitID in pairs(unitsToName) do
		trackUnit(unitName, unitID)
	end
end

return {
	{
		type = 'NameUnits',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'teamName', required = false, type = ParameterTypes.TeamName },
			{ name = 'unitDefName', required = false, type = ParameterTypes.String },
			{ name = 'area', required = false, type = ParameterTypes.Area },
			requiresOneOf = { 'teamName', 'unitDefName', 'area' },
		},
		actionFunction = nameUnits,
	}
}
