require("spec_helper")

--- Loads the real mission test files and checks each condition uses the
--- threshold belonging to its type family. This catches a mission picking a type
--- from the wrong table, which validation would report at load time in-engine
--- but which is cheaper to find here.

local METRIC_TYPES = {
	ResourceIncome = true,
	ResourcePull   = true,
	ResourceStored = true,
	UnitsOwned     = true,
}

-- validation_test.lua exists to be invalid, so its fixtures are expected to
-- break these rules on purpose.
local INTENTIONALLY_INVALID = { validation_test = true }

-- Identity tables: a mission reading eventTypes.Foo gets back "Foo", so the
-- loaded data can be inspected without engine definitions.
local function identityTable()
	return setmetatable({}, { __index = function(_, key) return key end })
end

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].ConditionDefinitions = {
	Types       = identityTable(),
	EventTypes  = identityTable(),
	MetricTypes = identityTable(),
}
GG['MissionAPI'].ActionDefinitions = { Types = identityTable() }
_G.CMD = identityTable()
_G.GameCMD = identityTable()

local missions = {}
for _, filePath in ipairs(VFS.DirList('singleplayer/mission-api-tests/', '*.lua')) do
	local missionName = filePath:match('([^/]+)%.lua$')
	if not INTENTIONALLY_INVALID[missionName] then
		missions[missionName] = VFS.Include(filePath)
	end
end

--- Every trigger and objective across all missions, flattened.
local function allConditions()
	local conditions = {}
	for missionName, mission in pairs(missions) do
		for _, group in ipairs({ { 'trigger', mission.Triggers }, { 'objective', mission.Objectives } }) do
			for id, entry in pairs(group[2] or {}) do
				if type(entry) == 'table' and type(entry.type) == 'string' then
					conditions[#conditions + 1] = {
						where = missionName .. ' ' .. group[1] .. ' ' .. id .. ' (' .. entry.type .. ')',
						entry = entry,
						isMetric = METRIC_TYPES[entry.type] or false,
					}
				end
			end
		end
	end
	return conditions
end

describe("mission test files", function()

	it("loads every mission", function()
		assert.is_true(next(missions) ~= nil)
		for missionName, mission in pairs(missions) do
			assert.is_table(mission, missionName .. " should return a table")
		end
	end)

	it("finds conditions to check", function()
		assert.is_true(#allConditions() > 0)
	end)

	it("gives every metric condition a bound", function()
		local problems = {}
		for _, condition in ipairs(allConditions()) do
			if condition.isMetric and condition.entry.atLeast == nil and condition.entry.atMost == nil then
				problems[#problems + 1] = condition.where
			end
		end
		table.sort(problems)
		assert.are.same({}, problems)
	end)

	it("never gives a metric condition a count", function()
		local problems = {}
		for _, condition in ipairs(allConditions()) do
			if condition.isMetric and condition.entry.count ~= nil then
				problems[#problems + 1] = condition.where
			end
		end
		table.sort(problems)
		assert.are.same({}, problems)
	end)

	it("never gives an event condition a bound", function()
		local problems = {}
		for _, condition in ipairs(allConditions()) do
			if not condition.isMetric
				and (condition.entry.atLeast ~= nil or condition.entry.atMost ~= nil) then
				problems[#problems + 1] = condition.where
			end
		end
		table.sort(problems)
		assert.are.same({}, problems)
	end)

	it("keeps every count at 1 or more", function()
		local problems = {}
		for _, condition in ipairs(allConditions()) do
			local count = condition.entry.count
			if count ~= nil and (type(count) ~= 'number' or count < 1) then
				problems[#problems + 1] = condition.where
			end
		end
		table.sort(problems)
		assert.are.same({}, problems)
	end)

	it("has no leftover quantity or amount fields", function()
		local problems = {}
		for _, condition in ipairs(allConditions()) do
			if condition.entry.quantity ~= nil then
				problems[#problems + 1] = condition.where .. ': quantity'
			end
			if condition.entry.amount ~= nil then
				problems[#problems + 1] = condition.where .. ': amount'
			end
		end
		table.sort(problems)
		assert.are.same({}, problems)
	end)

	it("puts objective completion effects under onComplete", function()
		local problems = {}
		for missionName, mission in pairs(missions) do
			for id, objective in pairs(mission.Objectives or {}) do
				if type(objective) == 'table' then
					if objective.nextStage ~= nil then
						problems[#problems + 1] = missionName .. ' ' .. id .. ': bare nextStage'
					end
					if objective.trigger ~= nil then
						problems[#problems + 1] = missionName .. ' ' .. id .. ': nested trigger'
					end
				end
			end
		end
		table.sort(problems)
		assert.are.same({}, problems)
	end)

end)
