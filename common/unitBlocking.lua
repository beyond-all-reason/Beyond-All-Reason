--- Reads the build blocks api_build_blocking.lua publishes as team rules params
--- ("unitdef_blocked_<unitDefID>", "builder_blocked_<builderUnitDefID>_<unitDefID>" = comma-separated reasons).
local unitBlocking = {}

---@param value string|number
---@return table<string, boolean>
local function parseReasons(value)
	local reasons = {}
	for _, reason in ipairs(string.split(tostring(value), ",")) do
		reasons[reason] = true
	end
	return reasons
end

--- Gets blocked unit definitions from TeamRulesParams
---@param teamID TeamID
---@param unitDefIDs? UnitDefID[] If `nil`, checks all blocked units of the team.
---@return table<number, table<string, boolean>> blockedUnits Table where keys are UnitDefIDs and values are tables of blocking reasons (reason -> true)
---@usage
---   -- Get all blocked units
---   local allBlocked = unitBlocking.getBlockedUnitDefs(teamID)
---   -- Get specific units' blocking status
---   local specificBlocked = unitBlocking.getBlockedUnitDefs(teamID, {123, 456})
function unitBlocking.getBlockedUnitDefs(teamID, unitDefIDs)
	local teamRules = Spring.GetTeamRulesParams(teamID) or {}
	local blockedUnits = {}

	if unitDefIDs then
		for i, unitDefID in ipairs(unitDefIDs) do
			if type(unitDefID) ~= "number" then
				Spring.Log(
					"unitBlocking",
					LOG.ERROR,
					"getBlockedUnitDefs: unitDefID at index "
						.. i
						.. " is not a number (got "
						.. type(unitDefID)
						.. ": "
						.. tostring(unitDefID)
						.. ")"
				)
				return {}
			end
			if not UnitDefs[unitDefID] then
				Spring.Log(
					"unitBlocking",
					LOG.ERROR,
					"getBlockedUnitDefs: unitDefID " .. unitDefID .. " does not exist in UnitDefs"
				)
				return {}
			end
		end
		for _, unitDefID in ipairs(unitDefIDs) do
			local key = "unitdef_blocked_" .. unitDefID
			local value = teamRules[key]
			if value then
				blockedUnits[unitDefID] = parseReasons(value)
			end
		end
	else
		for key, value in pairs(teamRules) do
			local unitDefIDStr = key:match("unitdef_blocked_(%d+)")
			if unitDefIDStr then
				local unitDefID = tonumber(unitDefIDStr)
				if unitDefID and UnitDefs[unitDefID] then
					blockedUnits[unitDefID] = parseReasons(value)
				end
			end
		end
	end

	return blockedUnits
end

--- Gets unit definitions blocked for one builder unit type only from TeamRulesParams
---@param teamID TeamID
---@return table<number, table<number, table<string, boolean>>> blockedUnits builder UnitDefID -> UnitDefID -> reasons
function unitBlocking.getBuilderBlockedUnitDefs(teamID)
	local teamRules = Spring.GetTeamRulesParams(teamID) or {}
	local blockedUnits = {}

	for key, value in pairs(teamRules) do
		local builderDefIDStr, unitDefIDStr = key:match("^builder_blocked_(%d+)_(%d+)$")
		if builderDefIDStr then
			local builderDefID = tonumber(builderDefIDStr)
			local unitDefID = tonumber(unitDefIDStr)
			if builderDefID and unitDefID and UnitDefs[builderDefID] and UnitDefs[unitDefID] then
				table.ensureTable(blockedUnits, builderDefID)[unitDefID] = parseReasons(value)
			end
		end
	end

	return blockedUnits
end

return unitBlocking
