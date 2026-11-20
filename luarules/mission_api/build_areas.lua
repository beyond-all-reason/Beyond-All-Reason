---
--- The campaign AI's build areas, by the name a mission gives them. A team's AI knows a build area by its ID only.
---

local buildAreaIDs = {} ---@type table<string, integer?>
local buildAreaCounts = {} ---@type table<integer, integer?> by teamID

---@return integer? buildAreaID nil for a name that is taken
local function defineBuildArea(buildAreaName, teamID)
	if buildAreaIDs[buildAreaName] then
		Spring.Log("build_areas.lua", LOG.WARNING, "[Mission API] Build area is already defined: " .. buildAreaName)
		return nil
	end

	-- 0 is the AI's ID for every build area.
	local buildAreaID = (buildAreaCounts[teamID] or 0) + 1
	buildAreaCounts[teamID] = buildAreaID
	buildAreaIDs[buildAreaName] = buildAreaID

	return buildAreaID
end

return {
	Define = defineBuildArea,
}
