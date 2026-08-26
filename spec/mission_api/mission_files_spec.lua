require("spec_helper")

local RegisterMissionApiModules = require("mission_api.spec_helper")

--- Loads the real mission test files and checks each condition uses the
--- threshold belonging to its type family. This catches a mission picking a type
--- from the wrong table, which validation would report at load time in-engine
--- but which is cheaper to find here.

local METRIC_TYPES = {
	ResourceIncome = true,
	ResourcePull = true,
	ResourceStored = true,
	UnitsOwned = true,
}

-- validation_test.lua exists to be invalid, so its fixtures are expected to
-- break these rules on purpose.
local INTENTIONALLY_INVALID = { validation_test = true }

-- Identity tables: a mission reading eventTypes.Foo gets back "Foo", so the
-- loaded data can be inspected without engine definitions.
local function identityTable()
	return setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	})
end

-- Condition descriptors read GG['MissionAPI'].Modules at load time. Registering
-- through the shared helper keeps this in step as descriptors take on new
-- module dependencies (detection levels, seismic contacts, and so on).
RegisterMissionApiModules()

--- The real condition descriptors, keyed by type name, so mission parameters can
--- be checked against the schemas they will actually be validated against
--- in-engine. Loaded before the identity tables below replace
--- ConditionDefinitions.
local declaredParameters = {}
for _, filePath in ipairs(VFS.DirList("luarules/mission_api/conditions/", "*.lua")) do
	local descriptor = VFS.Include(filePath)
	local declared = {}
	for _, parameter in ipairs(descriptor.parameters or {}) do
		declared[parameter.name] = true
	end
	declaredParameters[descriptor.type] = declared
end

GG["MissionAPI"].ConditionDefinitions = {
	Types = identityTable(),
	EventTypes = identityTable(),
	MetricTypes = identityTable(),
}
GG["MissionAPI"].ActionDefinitions = { Types = identityTable() }
_G.CMD = identityTable()
_G.GameCMD = identityTable()

local missions = {}
for _, filePath in ipairs(VFS.DirList("singleplayer/mission-api-tests/", "*.lua")) do
	local missionName = filePath:match("([^/]+)%.lua$")
	if not INTENTIONALLY_INVALID[missionName] then
		missions[missionName] = VFS.Include(filePath)
	end
end

--- Every trigger and objective across all missions, flattened.
local function allConditions()
	local conditions = {}
	for missionName, mission in pairs(missions) do
		for _, group in ipairs({ { "trigger", mission.Triggers }, { "objective", mission.Objectives } }) do
			for id, entry in pairs(group[2] or {}) do
				if type(entry) == "table" and type(entry.type) == "string" then
					conditions[#conditions + 1] = {
						where = missionName .. " " .. group[1] .. " " .. id .. " (" .. entry.type .. ")",
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
			if not condition.isMetric and (condition.entry.atLeast ~= nil or condition.entry.atMost ~= nil) then
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
			if count ~= nil and (type(count) ~= "number" or count < 1) then
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
				problems[#problems + 1] = condition.where .. ": quantity"
			end
			if condition.entry.amount ~= nil then
				problems[#problems + 1] = condition.where .. ": amount"
			end
		end
		table.sort(problems)
		assert.are.same({}, problems)
	end)

	it("only passes parameters its condition type declares", function()
		-- Catches parameters left behind by a rename, such as the TimeElapsed
		-- `gameFrame` that became `seconds`. In-engine these are load-time
		-- validation errors; this finds them without starting the game.
		local problems = {}
		for _, condition in ipairs(allConditions()) do
			local declared = declaredParameters[condition.entry.type]
			if declared then
				for parameterName in pairs(condition.entry.parameters or {}) do
					if type(parameterName) == "string" and not declared[parameterName] then
						problems[#problems + 1] = condition.where .. ": " .. parameterName
					end
				end
			end
		end
		table.sort(problems)
		assert.are.same({}, problems)
	end)

	it("knows the schema of every condition type the missions use", function()
		-- Guards the check above: an unknown type would silently skip it.
		local problems = {}
		for _, condition in ipairs(allConditions()) do
			if not declaredParameters[condition.entry.type] then
				problems[#problems + 1] = condition.where
			end
		end
		table.sort(problems)
		assert.are.same({}, problems)
	end)

	it("declares no key twice in a table constructor", function()
		-- Lua keeps the last value when a key repeats, with no error, so a
		-- duplicate is invisible to every check that inspects the loaded table.
		-- It has to be caught in the source text. Converting a condition that
		-- took both metal and energy into the single-value metric form produced
		-- exactly this: `resource` and `atLeast` each written twice, leaving the
		-- trigger silently checking only energy.
		local problems = {}

		for _, filePath in ipairs(VFS.DirList("singleplayer/mission-api-tests/", "*.lua")) do
			local missionName = filePath:match("([^/]+)%.lua$")
			local depth, seen = 0, {}

			local handle = io.open(filePath, "r")
			local lineNumber = 0
			for line in handle:lines() do
				lineNumber = lineNumber + 1
				if not line:match("^%s*%-%-") then
					local code = line:gsub("%-%-.*$", "")
					local key = code:match("^%s*([A-Za-z_][A-Za-z0-9_]*)%s*=")
					if key then
						seen[depth] = seen[depth] or {}
						if seen[depth][key] then
							problems[#problems + 1] = missionName
								.. ":"
								.. lineNumber
								.. ": duplicate key '"
								.. key
								.. "'"
						else
							seen[depth][key] = lineNumber
						end
					end
					for _ in code:gmatch("{") do
						depth = depth + 1
						seen[depth] = {}
					end
					for _ in code:gmatch("}") do
						seen[depth] = nil
						depth = math.max(0, depth - 1)
					end
				end
			end
			handle:close()
		end

		table.sort(problems)
		assert.are.same({}, problems)
	end)

	it("puts objective completion effects under onComplete", function()
		local problems = {}
		for missionName, mission in pairs(missions) do
			for id, objective in pairs(mission.Objectives or {}) do
				if type(objective) == "table" then
					if objective.nextStage ~= nil then
						problems[#problems + 1] = missionName .. " " .. id .. ": bare nextStage"
					end
					if objective.trigger ~= nil then
						problems[#problems + 1] = missionName .. " " .. id .. ": nested trigger"
					end
				end
			end
		end
		table.sort(problems)
		assert.are.same({}, problems)
	end)

end)
