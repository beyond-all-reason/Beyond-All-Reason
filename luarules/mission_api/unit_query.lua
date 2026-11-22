---
--- Utility module for finding the units matching a mission's filter params.
---

local tracking = GG["MissionAPI"].Modules.Tracking
local trackedUnitIDs = GG["MissionAPI"].trackedUnitIDs

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam

---@param unitName string
---@return UnitID[]
local function unitsWithName(unitName)
	if tracking.IsUnitNameUntracked(unitName) then
		return {}
	end

	local units = {}
	for unitID in pairs(trackedUnitIDs[unitName]) do
		units[#units + 1] = unitID
	end
	return units
end

---@param unitDefID UnitDefID
---@param teamID TeamID? Every team, when absent.
---@return UnitID[]
local function unitsWithDef(unitDefID, teamID)
	if teamID then
		return Spring.GetTeamUnitsByDefs(teamID, unitDefID)
	end

	local units = {}
	for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		for _, alliedTeam in ipairs(Spring.GetTeamList(allyTeamID)) do
			table.append(units, Spring.GetTeamUnitsByDefs(alliedTeam, unitDefID))
		end
	end
	return units
end

---The units satisfying every filter given. A team on its own names no units.
---@param unitName string?
---@param unitDefName string?
---@param teamID TeamID?
---@return UnitID[]
local function matchingUnits(unitName, unitDefName, teamID)
	local unitDef = unitDefName and UnitDefNames[unitDefName] ---@as table
	local unitDefID = unitDef and unitDef.id ---@as UnitDefID?

	if not unitName then
		return unitDefID and unitsWithDef(unitDefID, teamID) or {}
	end

	if unitDefName and not unitDefID then
		return {}
	end

	local matched = {}
	for _, unitID in ipairs(unitsWithName(unitName)) do
		if
			(not unitDefID or spGetUnitDefID(unitID) == unitDefID)
			and (not teamID or spGetUnitTeam(unitID) == teamID)
		then
			matched[#matched + 1] = unitID
		end
	end
	return matched
end

---@param unitID UnitID
---@param unitName string?
---@param unitDefName string?
---@return boolean
local function doesUnitMatch(unitID, unitName, unitDefName)
	if unitName and not tracking.DoesUnitHaveName(unitID, unitName) then
		return false
	end
	if unitDefName then
		local unitDef = UnitDefNames[unitDefName]
		if not unitDef or spGetUnitDefID(unitID) ~= unitDef.id then
			return false
		end
	end
	return true
end

---Returns whether every fact the unit filter gives is true of the unit.
---@param unitID UnitID
---@param unitFilter table
---@param unitDefID UnitDefID? the unit's def, when the caller has it
---@param teamID TeamID? the unit's team, when the caller has it
---@return boolean
local function doesUnitMatchFilter(unitID, unitFilter, unitDefID, teamID)
	local filterTeamID = unitFilter.teamName
	if filterTeamID ~= nil and (teamID or spGetUnitTeam(unitID)) ~= filterTeamID then
		return false
	end
	local unitDefIDs = unitFilter.unitDefName
	if unitDefIDs ~= nil and not unitDefIDs[unitDefID or spGetUnitDefID(unitID)] then
		return false
	end
	local unitName = unitFilter.unitName
	return unitName == nil or tracking.DoesUnitHaveName(unitID, unitName)
end

---Returns whether the unit matches a condition's `filter` and none of its `exclude` filters.
---@param unitID UnitID
---@param parameters table the condition's parameters
---@param unitDefID UnitDefID? the unit's def, when the caller has it
---@param teamID TeamID? the unit's team, when the caller has it
---@return boolean
local function doesUnitMatchCondition(unitID, parameters, unitDefID, teamID)
	local filter = parameters.filter
	if filter ~= nil and not doesUnitMatchFilter(unitID, filter, unitDefID, teamID) then
		return false
	end
	local exclude = parameters.exclude
	if exclude ~= nil then
		for i = 1, #exclude do
			if doesUnitMatchFilter(unitID, exclude[i], unitDefID, teamID) then
				return false
			end
		end
	end
	return true
end

---The units of a unit filter's team, or of every team, of its unit defs if it gives them.
---@param unitFilter table
---@return UnitID[]
local function unitsOfFilterTeams(unitFilter)
	local teamIDs
	if unitFilter.teamName ~= nil then
		teamIDs = { unitFilter.teamName }
	else
		teamIDs = Spring.GetTeamList()
	end

	local unitDefIDs
	if unitFilter.unitDefName ~= nil then
		unitDefIDs = table.keys(unitFilter.unitDefName)
	end

	local units = {}
	for _, teamID in ipairs(teamIDs) do
		if unitDefIDs then
			table.append(units, Spring.GetTeamUnitsByDefs(teamID, unitDefIDs))
		else
			table.append(units, Spring.GetTeamUnits(teamID))
		end
	end
	return units
end

---The units a condition's `filter` matches, less those its `exclude` filters match.
---@param parameters table the condition's parameters, with a `filter`
---@return UnitID[]
local function unitsMatchingCondition(parameters)
	local filter = parameters.filter
	local units
	if filter.unitName ~= nil then
		units = {}
		for _, unitID in ipairs(unitsWithName(filter.unitName)) do
			if doesUnitMatchFilter(unitID, filter) then
				units[#units + 1] = unitID
			end
		end
	else
		units = unitsOfFilterTeams(filter)
	end
	if parameters.exclude == nil then
		return units
	end

	local matched = {}
	for _, unitID in ipairs(units) do
		if doesUnitMatchCondition(unitID, parameters) then
			matched[#matched + 1] = unitID
		end
	end
	return matched
end

return {
	MatchingUnits = matchingUnits,
	UnitsMatchingCondition = unitsMatchingCondition,
	DoesUnitMatch = doesUnitMatch,
	DoesUnitMatchFilter = doesUnitMatchFilter,
	DoesUnitMatchCondition = doesUnitMatchCondition,
}
