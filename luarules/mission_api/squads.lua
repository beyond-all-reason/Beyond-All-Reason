---
--- The campaign AI's squads, by the name a mission gives them. A team's AI knows a squad by its ID only.
---

---@class MissionSquad
---@field squadName string
---@field squadID integer
---@field teamID integer

local squadsByName = {} ---@type table<string, MissionSquad?>
local squadCounts = {} ---@type table<integer, integer?> by teamID

---@return integer? squadID nil while a squad of that name is live
local function defineSquad(squadName, teamID)
	if squadsByName[squadName] then
		Spring.Log("squads.lua", LOG.WARNING, "[Mission API] Squad is already defined: " .. squadName)
		return nil
	end

	local squadID = (squadCounts[teamID] or 0) + 1
	squadCounts[teamID] = squadID
	squadsByName[squadName] = { squadName = squadName, squadID = squadID, teamID = teamID }

	return squadID
end

return {
	Define = defineSquad,
}
