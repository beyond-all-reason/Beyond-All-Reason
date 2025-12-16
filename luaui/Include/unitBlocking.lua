--- Unit blocking utility functions for checking TeamRulesParams
--- Provides functions to query blocked unit definitions from team rules
local unitBlocking = {}

--- Gets blocked unit definitions from TeamRulesParams
---@param unitDefIDs? number[] Optional array of specific UnitDefIDs to check. If nil, checks all blocked units for the current team.
---@return table<number, table<string, boolean>> blockedUnits Table where keys are UnitDefIDs and values are tables of blocking reasons (reason -> true)
---@usage
---   -- Get all blocked units
---   local allBlocked = unitBlocking.getAllBlockedUnitDefs()
---   -- Get specific units' blocking status
---   local specificBlocked = unitBlocking.getAllBlockedUnitDefs({123, 456})
function unitBlocking.getAllBlockedUnitDefs(unitDefIDs)
	local myTeamID = Spring.GetMyTeamID()
	if not myTeamID then return {} end

	local teamRules = Spring.GetTeamRulesParams(myTeamID) or {}
	local blockedUnits = {}

	if unitDefIDs then
		-- Validate specific UnitDefIDs
		for i, unitDefID in ipairs(unitDefIDs) do
			if type(unitDefID) ~= "number" then
				Spring.Log("unitBlocking", LOG.ERROR, "getAllBlockedUnitDefs: unitDefID at index " .. i .. " is not a number (got " .. type(unitDefID) .. ": " .. tostring(unitDefID) .. ")")
				return {}
			end
			if not UnitDefs[unitDefID] then
				Spring.Log("unitBlocking", LOG.ERROR, "getAllBlockedUnitDefs: unitDefID " .. unitDefID .. " does not exist in UnitDefs")
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
			if key:find("^unitdef_blocked_") then
				local unitDefIDStr = key:sub(16) -- Remove "unitdef_blocked_" prefix
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
