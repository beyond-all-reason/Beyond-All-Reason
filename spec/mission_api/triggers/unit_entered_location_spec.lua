local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local unitDefIDs, unitTeams, beingBuilt = {}, {}, {}
local unitsInArea = {} ---@type integer[]

-- unit_query captures these at its load.
local env = MissionSpecEnv.new({
	Spring = {
		GetUnitDefID = function(unitID)
			return unitDefIDs[unitID] or 1
		end,
		GetUnitTeam = function(unitID)
			return unitTeams[unitID] or 0
		end,
		GetUnitIsBeingBuilt = function(unitID)
			return beingBuilt[unitID] == true
		end,
	},
})

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes and .UnitQuery at load time,
-- and .AreaTracking inside its GameFrame handler.
Builders.MissionApi
	.new()
	:WithModule("AreaTracking", {
		GetUnitsInArea = function()
			return unitsInArea
		end,
	})
	:Install(env)

_G.UnitDefNames = { armpw = { id = 1 }, corfast = { id = 2 } } ---@diagnostic disable-line: global-in-non-module

local unitEnteredLocation = MissionSpecEnv.include(env, "luarules/mission_api/triggers/unit_entered_location.lua")
local onUnitsEnteredArea = unitEnteredLocation.callins.UnitsEnteredArea
local onGameFrame = unitEnteredLocation.callins.GameFrame

describe("mission_api.triggers.unit_entered_location", function()
	before_each(function()
		unitDefIDs, unitTeams, beingBuilt, unitsInArea = {}, {}, {}, {}
	end)

	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"
	local area = { x = 0, z = 0, radius = 100 }

	it("declares its type and parameters, requiring an area", function()
		assert.are.equal("UnitEnteredLocation", unitEnteredLocation.type)
		assert.are.equal("area", unitEnteredLocation.parameters[1].name)
		assert.is_true(unitEnteredLocation.parameters[1].required)
		local names = {}
		for _, parameter in ipairs(unitEnteredLocation.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.allNamedUnits)
		assert.are.same({ "unitName", "unitDefName" }, unitEnteredLocation.parameters.requiresOneOf)
	end)

	it("fires for a unit that entered the area", function()
		local context, fired = newContext()
		onUnitsEnteredArea(trigger({ area = area, unitDefName = "armpw" }), triggerID, context, { 100 })
		assert.are.equal(1, fired())
	end)

	it("fires once per unit entering together", function()
		local context, fired = newContext()
		onUnitsEnteredArea(trigger({ area = area, unitDefName = "armpw" }), triggerID, context, { 100, 101 })
		assert.are.equal(2, fired())
	end)

	it("checks every unit before activating, so an activation cannot change a later match", function()
		local t = trigger({ area = area, unitName = "scouts" })
		local context, fired = newContext()
		local activate = context.ActivateTrigger
		context.ActivateTrigger = function(...)
			context.DoesUnitMatch = function()
				return false
			end
			return activate(...)
		end
		onUnitsEnteredArea(t, triggerID, context, { 100, 101 })
		assert.are.equal(2, fired())
	end)

	it("does not fire for a unit the filters reject", function()
		local context, fired = newContext()
		context.DoesUnitMatch = function()
			return false
		end
		onUnitsEnteredArea(trigger({ area = area, unitName = "scouts" }), triggerID, context, { 100 })
		assert.are.equal(0, fired())
	end)

	it("does not read the area each frame without allNamedUnits", function()
		local context, fired = newContext()
		unitsInArea = { 100 }
		onGameFrame(trigger({ area = area, unitDefName = "armpw" }), triggerID, context)
		assert.are.equal(0, fired())
	end)

	describe("with allNamedUnits", function()
		local tracking = GG["MissionAPI"].Modules.Tracking

		before_each(function()
			for _, unitID in ipairs({ 100, 101, 102 }) do
				tracking.TrackUnit("squad", unitID)
			end
		end)

		after_each(function()
			tracking.UntrackUnitName("squad")
		end)

		local function squadTrigger(parameters)
			parameters = parameters or {}
			parameters.area = area
			parameters.unitName = "squad"
			parameters.allNamedUnits = true
			return trigger(parameters)
		end

		it("does not fire per unit on entry", function()
			local context, fired = newContext()
			onUnitsEnteredArea(squadTrigger(), triggerID, context, { 100 })
			assert.are.equal(0, fired())
		end)

		it("fires once, when the last of the named units gets inside, and not again while they stay", function()
			local t = squadTrigger()
			t.settings.repeating = true
			local context, fired = newContext()
			unitsInArea = { 100, 101 }
			onGameFrame(t, triggerID, context)
			assert.are.equal(0, fired())

			unitsInArea = { 100, 101, 102 }
			onGameFrame(t, triggerID, context)
			onGameFrame(t, triggerID, context)
			assert.are.equal(1, fired())
		end)

		it("fires again once one has left and they are all back", function()
			local t = squadTrigger()
			local context, fired = newContext()
			unitsInArea = { 100, 101, 102 }
			onGameFrame(t, triggerID, context)
			unitsInArea = { 100, 101 }
			onGameFrame(t, triggerID, context)
			unitsInArea = { 100, 101, 102 }
			onGameFrame(t, triggerID, context)
			assert.are.equal(2, fired())
		end)

		it("is not held up by other units in the area", function()
			local context, fired = newContext()
			unitsInArea = { 100, 200, 101, 102 }
			onGameFrame(squadTrigger(), triggerID, context)
			assert.are.equal(1, fired())
		end)

		it("stops waiting for a unit that died", function()
			local t = squadTrigger()
			local context, fired = newContext()
			unitsInArea = { 100, 101 }
			onGameFrame(t, triggerID, context)
			tracking.UntrackUnitID(102)
			onGameFrame(t, triggerID, context)
			assert.are.equal(1, fired())
		end)

		it("does not fire once every named unit is gone", function()
			tracking.UntrackUnitName("squad")
			local context, fired = newContext()
			onGameFrame(squadTrigger(), triggerID, context)
			assert.are.equal(0, fired())
		end)

		it("does not wait for a unit under construction", function()
			beingBuilt[102] = true
			local context, fired = newContext()
			unitsInArea = { 100, 101 }
			onGameFrame(squadTrigger(), triggerID, context)
			assert.are.equal(1, fired())
		end)

		it("with a teamID, does not wait for a unit on another team", function()
			unitTeams[102] = 1
			local context, fired = newContext()
			unitsInArea = { 100, 101 }
			onGameFrame(squadTrigger({ teamID = 0 }), triggerID, context)
			assert.are.equal(1, fired())
		end)

		it("with a unitDefName, does not wait for a unit of another def", function()
			unitDefIDs[102] = 2
			local context, fired = newContext()
			unitsInArea = { 100, 101 }
			onGameFrame(squadTrigger({ unitDefName = "armpw" }), triggerID, context)
			assert.are.equal(1, fired())
		end)

		it("fires when the trigger becomes valid while they are all inside", function()
			local t = squadTrigger()
			local context = newContext()
			unitsInArea = { 100, 101, 102 }
			local valid, fires = false, 0
			context.ActivateTrigger = function()
				if valid then
					fires = fires + 1
				end
				return valid
			end
			onGameFrame(t, triggerID, context)
			valid = true
			onGameFrame(t, triggerID, context)
			onGameFrame(t, triggerID, context)
			assert.are.equal(1, fires)
		end)

		it("latches each trigger on its own", function()
			local t = squadTrigger()
			local context, fired = newContext()
			unitsInArea = { 100, 101, 102 }
			onGameFrame(t, "first", context)
			onGameFrame(t, "second", context)
			assert.are.equal(2, fired())
		end)
	end)
end)
