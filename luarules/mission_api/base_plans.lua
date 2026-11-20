---
--- The campaign AI's base plans, by the name a mission gives them. A team's AI knows a base plan by its ID only.
---

---@class MissionBasePlan
---@field basePlanID integer
---@field teamID integer

local basePlans = {} ---@type table<string, MissionBasePlan?>
local basePlanCounts = {} ---@type table<integer, integer?> by teamID

--- A plan starts with the first structure a mission adds under its name.
---@return integer? basePlanID nil for the name of another team's plan
local function getOrStartBasePlan(basePlanName, teamID)
	local basePlan = basePlans[basePlanName]
	if not basePlan then
		-- An ID is never used twice, so a cancelled plan's builds in progress cannot end up in a later plan.
		local basePlanID = (basePlanCounts[teamID] or 0) + 1
		basePlanCounts[teamID] = basePlanID
		basePlan = { basePlanID = basePlanID, teamID = teamID }
		basePlans[basePlanName] = basePlan
	elseif basePlan.teamID ~= teamID then
		local message = "[Mission API] Base plan belongs to another team: " .. basePlanName
		Spring.Log("base_plans.lua", LOG.WARNING, message)
		return nil
	end

	return basePlan.basePlanID
end

---@return integer? basePlanID nil for a base plan that is not live
---@return integer? teamID
local function cancelBasePlan(basePlanName)
	local basePlan = basePlans[basePlanName]
	if basePlan then
		basePlans[basePlanName] = nil
		return basePlan.basePlanID, basePlan.teamID
	end
end

return {
	GetOrStart = getOrStartBasePlan,
	Cancel = cancelBasePlan,
}
