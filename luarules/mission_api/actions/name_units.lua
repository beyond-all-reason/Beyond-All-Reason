local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

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

	local unitsInArea = {}
	if area and area.x1 and area.z1 and area.x2 and area.z2 then
		unitsInArea = Spring.GetUnitsInRectangle(area.x1, area.z1, area.x2, area.z2, teamID)
	elseif area and area.x and area.z and area.radius then
		unitsInArea = Spring.GetUnitsInCylinder(area.x, area.z, area.radius, teamID)
	end

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
	type = 'NameUnits',
	parameters = {
		{ name = 'unitName', required = true, type = Types.UnitName },
		{ name = 'teamID', required = false, type = Types.Number },
		{ name = 'unitDefName', required = false, type = Types.String },
		{ name = 'area', required = false, type = Types.Area },
		requiresOneOf = { 'teamID', 'unitDefName', 'area' },
	},
	actionFunction = nameUnits,
}
