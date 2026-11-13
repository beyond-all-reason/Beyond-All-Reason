---
--- The campaign AI's squads, by the name a mission gives them. A team's AI knows a squad by its ID only.
---

---@class MissionSquad
---@field squadName string
---@field squadID integer
---@field teamID integer
---@field isAssembled boolean
---@field isRepeating boolean

local squadsByName = {} ---@type table<string, MissionSquad?>
local squadsByID = {} ---@type table<integer, table<integer, MissionSquad?>> by teamID, then squadID
local squadCounts = {} ---@type table<integer, integer?> by teamID

---@return integer? squadID nil while a squad of that name is live
local function defineSquad(squadName, teamID)
	if squadsByName[squadName] then
		Spring.Log("squads.lua", LOG.WARNING, "[Mission API] Squad is already defined: " .. squadName)
		return nil
	end

	-- An ID is never used twice, so a late signal about an ended squad cannot reach a later squad of its name.
	local squadID = (squadCounts[teamID] or 0) + 1
	squadCounts[teamID] = squadID

	local squad =
		{ squadName = squadName, squadID = squadID, teamID = teamID, isAssembled = false, isRepeating = false }
	squadsByName[squadName] = squad
	table.ensureTable(squadsByID, teamID)[squadID] = squad

	return squadID
end

---@param squad MissionSquad
local function removeSquad(squad)
	squadsByName[squad.squadName] = nil
	squadsByID[squad.teamID][squad.squadID] = nil
end

---@return MissionSquad? squad nil for a squad that is not live
local function findSquad(teamID, squadID)
	return squadsByID[teamID] and squadsByID[teamID][squadID]
end

---@return string? squadName nil for a squad that is not live
local function getSquadName(teamID, squadID)
	local squad = findSquad(teamID, squadID)
	return squad and squad.squadName
end

---@return string? squadName nil for a squad that is not live
local function assembleSquad(teamID, squadID)
	local squad = findSquad(teamID, squadID)
	if squad then
		squad.isAssembled = true
		return squad.squadName
	end
end

--- The AI recruits a repeating squad again under its ID, so that squad stays, gathering.
---@return string? squadName nil for a squad that is not live
local function endSquad(teamID, squadID)
	local squad = findSquad(teamID, squadID)
	if not squad then
		return
	end

	if squad.isRepeating then
		squad.isAssembled = false
	else
		removeSquad(squad)
	end

	return squad.squadName
end

---@return integer? squadID nil for a squad that is not live
---@return integer? teamID
---@return boolean? isAssembled
local function getSquad(squadName)
	local squad = squadsByName[squadName]
	if squad then
		return squad.squadID, squad.teamID, squad.isAssembled
	end
end

---@return integer? squadID nil for a squad that is not live
---@return integer? teamID
local function setSquadRepeating(squadName, isRepeating)
	local squad = squadsByName[squadName]
	if squad then
		squad.isRepeating = isRepeating
		return squad.squadID, squad.teamID
	end
end

--- The AI takes a task only for a squad that has its units.
---@return integer? squadID nil for a squad that is not assembled
---@return integer? teamID
local function getAssembledSquad(squadName)
	local squad = squadsByName[squadName]
	if not squad then
		return
	end

	if not squad.isAssembled then
		Spring.Log("squads.lua", LOG.WARNING, "[Mission API] Squad is still gathering: " .. squadName)
		return
	end

	return squad.squadID, squad.teamID
end

--- Forgets the squad at once, so the AI's signal that it removed the squad finds none to end.
---@return integer? squadID nil for a squad that is not live
---@return integer? teamID
local function cancelSquad(squadName)
	local squad = squadsByName[squadName]
	if squad then
		removeSquad(squad)
		return squad.squadID, squad.teamID
	end
end

return {
	Define = defineSquad,
	Assemble = assembleSquad,
	End = endSquad,
	Get = getSquad,
	GetName = getSquadName,
	GetAssembled = getAssembledSquad,
	SetRepeating = setSquadRepeating,
	Cancel = cancelSquad,
}
