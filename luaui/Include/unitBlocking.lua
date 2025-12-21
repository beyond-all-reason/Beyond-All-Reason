--- Unit blocking utility functions for checking TeamRulesParams
--- Provides functions to query blocked unit definitions from team rules
local unitBlocking = {}

--- Gets blocked unit definitions from TeamRulesParams
---@param unitDefIDs? number[] Optional array of specific UnitDefIDs to check. If nil, checks all blocked units for the current team.
---@return table<number, table<string, boolean>> blockedUnits Table where keys are UnitDefIDs and values are tables of blocking reasons (reason -> true)
---@usage
---   -- Get all blocked units
---   local allBlocked = unitBlocking.getBlockedUnitDefs()
---   -- Get specific units' blocking status
---   local specificBlocked = unitBlocking.getBlockedUnitDefs({123, 456})
function unitBlocking.getBlockedUnitDefs(unitDefIDs)
	local myTeamID = Spring.GetMyTeamID()
	if not myTeamID then return {} end

	local teamRules = Spring.GetTeamRulesParams(myTeamID) or {}
	local blockedUnits = {}

	if unitDefIDs then
		for i, unitDefID in ipairs(unitDefIDs) do
			if type(unitDefID) ~= "number" then
				Spring.Log("unitBlocking", LOG.ERROR, "getBlockedUnitDefs: unitDefID at index " .. i .. " is not a number (got " .. type(unitDefID) .. ": " .. tostring(unitDefID) .. ")")
				return {}
			end
			if not UnitDefs[unitDefID] then
				Spring.Log("unitBlocking", LOG.ERROR, "getBlockedUnitDefs: unitDefID " .. unitDefID .. " does not exist in UnitDefs")
				return {}
			end
		end
		for _, unitDefID in ipairs(unitDefIDs) do
			local key = "unitdef_blocked_" .. unitDefID
			local value = teamRules[key]
			if value then
				blockedUnits[unitDefID] = {}
				for reason in value:gmatch("[^,]+") do
					blockedUnits[unitDefID][reason] = true
				end
			end
		end
	else
		for key, value in pairs(teamRules) do
			local unitDefIDStr = key:match("unitdef_blocked_(%d+)")
			if unitDefIDStr then
				local unitDefID = tonumber(unitDefIDStr)
				if unitDefID and UnitDefs[unitDefID] then
					blockedUnits[unitDefID] = {}
					for reason in value:gmatch("[^,]+") do
						blockedUnits[unitDefID][reason] = true
					end
				end
			end
		end
	end

	return blockedUnits
end

return unitBlocking
