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

-- Action files capture the attributes API when they load, so the recorder goes in first.
local calls = {}
local function record(name)
	return function(...)
		calls[#calls + 1] = { name, ... }
	end
end
_G.GG.UnitAttributes = { ---@diagnostic disable-line: global-in-non-module
	SetUnitDefAttribute = record("SetUnitDefAttribute"),
	SetUnitAttribute = record("SetUnitAttribute"),
	SetUnitDefModifier = record("SetUnitDefModifier"),
	SetUnitModifier = record("SetUnitModifier"),
	SetUnitDefWeaponAttribute = record("SetUnitDefWeaponAttribute"),
	SetUnitWeaponAttribute = record("SetUnitWeaponAttribute"),
	SetUnitDefWeaponModifier = record("SetUnitDefWeaponModifier"),
	SetUnitWeaponModifier = record("SetUnitWeaponModifier"),
	WEAPON_DEATH = -1,
	WEAPON_SELFD = -2,
}

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
	before_each(function()
		calls, queried, queryResult = {}, {}, {}
		Builders.MissionApi.new():WithModule("UnitQuery", unitQuery):Install()
		_G.UnitDefNames = { armwar = { id = 7 }, armpw = { id = 8 } } ---@diagnostic disable-line: global-in-non-module
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

	describe("SetUnitDefModifier", function()
		local action = actionOfType("SetUnitDefModifier")

		it("declares its parameters", function()
			assert.are.same({
				type = "SetUnitDefModifier",
				unitDefName = "UnitDefName!",
				teamID = "TeamID",
				attribute = "UnitAttribute!",
				multiplier = "AttributeMultiplier",
				source = "String",
			}, summarizeSchema(action))
		end)

		it("scales the def attribute under the mission's source, for one team", function()
			action.actionFunction("armpw", 1, "losRadius", 0.5, nil)

			assert.are.same({ { "SetUnitDefModifier", 8, "losRadius", 0.5, "mission", 1 } }, calls)
		end)

		it("clears the source when there is no multiplier", function()
			action.actionFunction("armpw", nil, "losRadius", nil, "fog")

			assert.are.same({ { "SetUnitDefModifier", 8, "losRadius", nil, "fog", nil } }, calls)
		end)
	end)

	describe("SetUnitModifier", function()
		local action = actionOfType("SetUnitModifier")

		it("declares its parameters", function()
			assert.are.same({
				type = "SetUnitModifier",
				unitName = "UnitName",
				unitDefName = "UnitDefName",
				teamID = "TeamID",
				attribute = "UnitAttribute!",
				multiplier = "AttributeMultiplier",
				source = "String",
				requiresOneOf = { "unitName", "unitDefName" },
			}, summarizeSchema(action))
		end)

		it("scales every unit the query matched", function()
			queryResult = { 11, 12 }

			action.actionFunction("bots", nil, nil, "speed", 1.5, "haste")

			assert.are.same({
				{ "SetUnitModifier", 11, "speed", 1.5, "haste" },
				{ "SetUnitModifier", 12, "speed", 1.5, "haste" },
			}, calls)
			assert.are.same({ { "bots" } }, queried)
		end)
	end)

	describe("SetUnitDefWeaponAttribute", function()
		local action = actionOfType("SetUnitDefWeaponAttribute")

		it("declares its parameters", function()
			assert.are.same({
				type = "SetUnitDefWeaponAttribute",
				unitDefName = "UnitDefName!",
				teamID = "TeamID",
				weapon = "UnitWeapon",
				attribute = "WeaponAttribute!",
				value = "AttributeValue",
				source = "String",
			}, summarizeSchema(action))
		end)

		it("sets one weapon of the def", function()
			action.actionFunction("armpw", nil, 1, "maxWeaponRange", 600, nil)

			assert.are.same({ { "SetUnitDefWeaponAttribute", 8, 1, "maxWeaponRange", 600, "mission", nil } }, calls)
		end)

		it("sets every weapon when none is named", function()
			action.actionFunction("armpw", 0, nil, "reloadTime", 2, nil)

			assert.are.same({ { "SetUnitDefWeaponAttribute", 8, nil, "reloadTime", 2, "mission", 0 } }, calls)
		end)
	end)

	describe("SetUnitWeaponAttribute", function()
		local action = actionOfType("SetUnitWeaponAttribute")

		it("declares its parameters", function()
			assert.are.same({
				type = "SetUnitWeaponAttribute",
				unitName = "UnitName",
				unitDefName = "UnitDefName",
				teamID = "TeamID",
				weapon = "UnitWeapon",
				attribute = "WeaponAttribute!",
				value = "AttributeValue",
				source = "String",
				requiresOneOf = { "unitName", "unitDefName" },
			}, summarizeSchema(action))
		end)

		it("sets the weapon on every unit the query matched", function()
			queryResult = { 11, 12 }

			action.actionFunction("bots", nil, nil, 2, "maxWeaponRange", 500, nil)

			assert.are.same({
				{ "SetUnitWeaponAttribute", 11, 2, "maxWeaponRange", 500, "mission" },
				{ "SetUnitWeaponAttribute", 12, 2, "maxWeaponRange", 500, "mission" },
			}, calls)
		end)
	end)

	describe("SetUnitDefWeaponModifier", function()
		local action = actionOfType("SetUnitDefWeaponModifier")

		it("declares its parameters", function()
			assert.are.same({
				type = "SetUnitDefWeaponModifier",
				unitDefName = "UnitDefName!",
				teamID = "TeamID",
				weapon = "UnitWeapon",
				attribute = "WeaponAttribute!",
				multiplier = "AttributeMultiplier",
				source = "String",
			}, summarizeSchema(action))
		end)

		it("names the death explosion as the engine does", function()
			action.actionFunction("armpw", nil, "explode", "damage", 3, nil)

			assert.are.same({ { "SetUnitDefWeaponModifier", 8, -1, "damage", 3, "mission", nil } }, calls)
		end)

		it("names the self-destruct explosion as the engine does", function()
			action.actionFunction("armpw", nil, "selfDestruct", "cratering", 0.5, nil)

			assert.are.same({ { "SetUnitDefWeaponModifier", 8, -2, "cratering", 0.5, "mission", nil } }, calls)
		end)
	end)

	describe("SetUnitWeaponModifier", function()
		local action = actionOfType("SetUnitWeaponModifier")

		it("declares its parameters", function()
			assert.are.same({
				type = "SetUnitWeaponModifier",
				unitName = "UnitName",
				unitDefName = "UnitDefName",
				teamID = "TeamID",
				weapon = "UnitWeapon",
				attribute = "WeaponAttribute!",
				multiplier = "AttributeMultiplier",
				source = "String",
				requiresOneOf = { "unitName", "unitDefName" },
			}, summarizeSchema(action))
		end)

		it("clears a named source on every unit the query matched", function()
			queryResult = { 11 }

			action.actionFunction("tank", nil, nil, nil, "damage", nil, "overcharge")

			assert.are.same({ { "SetUnitWeaponModifier", 11, nil, "damage", nil, "overcharge" } }, calls)
		end)
	end)
end)
