require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The unit query is stubbed, so these check what the actions ask of it, not how it matches.
local queried, queryResult
local unitQuery = {
	MatchingUnits = function(unitName, unitDefName, teamID)
		queried[#queried + 1] = { unitName, unitDefName, teamID }
		return queryResult
	end,
}

-- Action files read GG['MissionAPI'].Modules.ParameterTypes and .UnitQuery at load time.
Builders.MissionApi.new():WithModule("UnitQuery", unitQuery):Install()

local actions = VFS.Include("luarules/mission_api/actions/units/set_attribute.lua")
local summarizeSchema = require("mission_api.schema_spec_helper")

local function actionOfType(actionType)
	for _, action in ipairs(actions) do
		if action.type == actionType then
			return action
		end
	end
end

describe("mission_api.actions.set_attribute", function()
	local calls

	local function record(name)
		return function(...)
			calls[#calls + 1] = { name, ... }
		end
	end

	before_each(function()
		calls, queried, queryResult = {}, {}, {}
		Builders.MissionApi.new():WithModule("UnitQuery", unitQuery):Install()
		_G.GG.UnitAttributes = { ---@diagnostic disable-line: global-in-non-module
			SetUnitDefAttribute = record("SetUnitDefAttribute"),
			SetUnitAttribute = record("SetUnitAttribute"),
		}
		_G.UnitDefNames = { armwar = { id = 7 }, armpw = { id = 8 } } ---@diagnostic disable-line: global-in-non-module
	end)

	after_each(function()
		_G.GG.UnitAttributes = nil ---@diagnostic disable-line: global-in-non-module
	end)

	describe("SetUnitDefAttribute", function()
		local action = actionOfType("SetUnitDefAttribute")

		it("declares its parameters", function()
			assert.are.same({
				type = "SetUnitDefAttribute",
				unitDefName = "UnitDefName!",
				teamID = "TeamID",
				attribute = "UnitAttribute!",
				value = "AttributeValue",
				source = "String",
			}, summarizeSchema(action))
		end)

		it("sets the def attribute under the mission's source", function()
			action.actionFunction("armpw", nil, "losRadius", 1200, nil)

			assert.are.same({ { "SetUnitDefAttribute", 8, "losRadius", 1200, "mission", nil } }, calls)
		end)

		it("passes a team through as the def-and-team scope", function()
			action.actionFunction("armpw", 1, "losRadius", 1200, nil)

			assert.are.same({ { "SetUnitDefAttribute", 8, "losRadius", 1200, "mission", 1 } }, calls)
		end)

		it("uses a named source", function()
			action.actionFunction("armpw", nil, "losRadius", 1200, "scouting")

			assert.are.same({ { "SetUnitDefAttribute", 8, "losRadius", 1200, "scouting", nil } }, calls)
		end)

		it("clears the source when there is no value", function()
			action.actionFunction("armpw", nil, "losRadius", nil, "scouting")

			assert.are.same({ { "SetUnitDefAttribute", 8, "losRadius", nil, "scouting", nil } }, calls)
		end)

		it("does nothing for a unitDefName that does not exist", function()
			action.actionFunction("noSuchDef", nil, "losRadius", 1200, nil)

			assert.are.same({}, calls)
		end)
	end)

	describe("SetUnitAttribute", function()
		local action = actionOfType("SetUnitAttribute")

		it("declares its parameters", function()
			assert.are.same({
				type = "SetUnitAttribute",
				unitName = "UnitName",
				unitDefName = "UnitDefName",
				teamID = "TeamID",
				attribute = "UnitAttribute!",
				value = "AttributeValue",
				source = "String",
				requiresOneOf = { "unitName", "unitDefName" },
			}, summarizeSchema(action))
		end)

		it("asks the unit query with its filters", function()
			action.actionFunction("bots", "armwar", 0, "stealth", true, nil)

			assert.are.same({ { "bots", "armwar", 0 } }, queried)
		end)

		it("sets the attribute on every unit the query matched", function()
			queryResult = { 11, 12 }

			action.actionFunction("bots", nil, nil, "stealth", true, nil)

			assert.are.same({
				{ "SetUnitAttribute", 11, "stealth", true, "mission" },
				{ "SetUnitAttribute", 12, "stealth", true, "mission" },
			}, calls)
		end)

		it("sets nothing when the query matched nothing", function()
			action.actionFunction("ghosts", nil, nil, "speed", 90, nil)

			assert.are.same({}, calls)
		end)

		it("clears a named source when there is no value", function()
			queryResult = { 11 }

			action.actionFunction(nil, "armwar", 0, "speed", nil, "boost")

			assert.are.same({ { "SetUnitAttribute", 11, "speed", nil, "boost" } }, calls)
		end)
	end)
end)
