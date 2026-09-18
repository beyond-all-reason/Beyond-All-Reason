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
		for _, teamIDOfAllyTeam in ipairs(Spring.GetTeamList(allyTeamID)) do
			table.append(units, Spring.GetTeamUnitsByDefs(teamIDOfAllyTeam, unitDefID))
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

return {
	MatchingUnits = matchingUnits,
	UnitsWithDef = unitsWithDef,
	UnitsWithName = unitsWithName,
}
