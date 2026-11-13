---
--- The campaign AI's squads, by the name a mission gives them. A team's AI knows a squad by its ID only.
---

---@class MissionSquad
---@field squadName string
---@field squadID integer
---@field teamID integer
---@field isAssembled boolean

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

	local squad = { squadName = squadName, squadID = squadID, teamID = teamID, isAssembled = false }
	squadsByName[squadName] = squad
	table.ensureTable(squadsByID, teamID)[squadID] = squad

	return squadID
end

---@return string? squadName nil for a squad that is not live
local function assembleSquad(teamID, squadID)
	local squad = squadsByID[teamID] and squadsByID[teamID][squadID]
	if squad then
		squad.isAssembled = true
		return squad.squadName
	end
end

---@return string? squadName nil for a squad that is not live
local function endSquad(teamID, squadID)
	local squad = squadsByID[teamID] and squadsByID[teamID][squadID]
	if squad then
		squadsByName[squad.squadName] = nil
		squadsByID[teamID][squadID] = nil
		return squad.squadName
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

return {
	Define = defineSquad,
	Assemble = assembleSquad,
	End = endSquad,
	GetAssembled = getAssembledSquad,
}
