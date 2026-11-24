---
--- Utility module for finding the units matching a mission's filter params.
---

local tracking = GG["MissionAPI"].Modules.Tracking
local trackedUnitIDs = GG["MissionAPI"].trackedUnitIDs

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetTeamAllyTeamID = Spring.GetTeamAllyTeamID

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
local function getMatchingUnits(unitName, unitDefName, teamID)
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
local function isUnitMatch(unitID, unitName, unitDefName)
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

---Returns whether the unit meets every criterion of the unit filter,
---then the unit's def, team, and alliance for the next filter to reuse.
---@param unitID UnitID
---@param unitFilter table
---@param unitDefID UnitDefID?
---@param teamID TeamID?
---@param allyTeamID AllyTeamID?
---@return boolean matches
---@return UnitDefID? unitDefID
---@return TeamID? teamID
---@return AllyTeamID? allyTeamID
local function getUnitFilterMatch(unitID, unitFilter, unitDefID, teamID, allyTeamID)
	local filterTeamID = unitFilter.teamName
	if filterTeamID ~= nil then
		teamID = teamID or spGetUnitTeam(unitID)
		if teamID ~= filterTeamID then
			return false, unitDefID, teamID, allyTeamID
		end
	end
	local filterAllyTeamID = unitFilter.allianceName
	if filterAllyTeamID ~= nil then
		if allyTeamID == nil then
			if teamID ~= nil then
				allyTeamID = spGetTeamAllyTeamID(teamID)
			else
				allyTeamID = spGetUnitAllyTeam(unitID)
			end
		end
		if allyTeamID ~= filterAllyTeamID then
			return false, unitDefID, teamID, allyTeamID
		end
	end
	local unitDefIDs = unitFilter.unitDefName
	if unitDefIDs ~= nil then
		unitDefID = unitDefID or spGetUnitDefID(unitID)
		if not unitDefIDs[unitDefID] then
			return false, unitDefID, teamID, allyTeamID
		end
	end
	local unitName = unitFilter.unitName
	return unitName == nil or tracking.DoesUnitHaveName(unitID, unitName), unitDefID, teamID, allyTeamID
end

---Returns whether the unit matches a condition's `includeUnit` and none of its `excludeUnit` filters.
---The unit's def, team, and alliance are each looked up at most once.
---@param unitID UnitID
---@param parameters table the condition's parameters
---@param unitDefID UnitDefID? the unit's def, when the caller has it
---@param teamID TeamID? the unit's team, when the caller has it
---@return boolean
local function isUnitIncluded(unitID, parameters, unitDefID, teamID)
	local matches, allyTeamID
	local includeUnit = parameters.includeUnit
	if includeUnit ~= nil then
		matches, unitDefID, teamID, allyTeamID = getUnitFilterMatch(unitID, includeUnit, unitDefID, teamID, nil)
		if not matches then
			return false
		end
	end
	local excludeUnit = parameters.excludeUnit
	if excludeUnit ~= nil then
		for i = 1, #excludeUnit do
			matches, unitDefID, teamID, allyTeamID =
				getUnitFilterMatch(unitID, excludeUnit[i], unitDefID, teamID, allyTeamID)
			if matches then
				return false
			end
		end
	end
	return true
end

---The units of a unit filter's team, its alliance, or every team, of its unit defs if it gives them.
---@param unitFilter table
---@return UnitID[]
local function getUnitsOfFilterTeams(unitFilter)
	local teamIDs
	if unitFilter.teamName ~= nil then
		teamIDs = { unitFilter.teamName }
	elseif unitFilter.allianceName ~= nil then
		teamIDs = Spring.GetTeamList(unitFilter.allianceName)
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

---The units a condition's `includeUnit` matches, less those its `excludeUnit` filters match.
---@param parameters table the condition's parameters, with an `includeUnit`
---@return UnitID[]
local function getIncludedUnits(parameters)
	local includeUnit = parameters.includeUnit
	local units
	if includeUnit.unitName ~= nil then
		units = {}
		for _, unitID in ipairs(unitsWithName(includeUnit.unitName)) do
			if getUnitFilterMatch(unitID, includeUnit) then
				units[#units + 1] = unitID
			end
		end
	else
		units = getUnitsOfFilterTeams(includeUnit)
	end
	if parameters.excludeUnit == nil then
		return units
	end

	local matched = {}
	for _, unitID in ipairs(units) do
		if isUnitIncluded(unitID, parameters) then
			matched[#matched + 1] = unitID
		end
	end
	return matched
end

return {
	GetMatchingUnits = getMatchingUnits,
	GetIncludedUnits = getIncludedUnits,
	IsUnitMatch = isUnitMatch,
	IsUnitIncluded = isUnitIncluded,
}
