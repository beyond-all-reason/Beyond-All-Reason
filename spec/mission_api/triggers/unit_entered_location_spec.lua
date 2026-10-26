local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local unitDefIDs, unitTeams, beingBuilt = {}, {}, {}

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
-- and UnitDefs / Spring.GetUnitDefID inside its handler.
Builders.MissionApi.new():Install(env)

local unitDefs = Builders.UnitDefs.new():WithUnitDefs({
	[1] = { name = "armpw" },
	[2] = { name = "corfast" },
})
_G.UnitDefs = unitDefs:GetUnitDefsByID()
_G.UnitDefNames = { armpw = { id = 1 }, corfast = { id = 2 } } ---@diagnostic disable-line: global-in-non-module

local unitEnteredLocation = MissionSpecEnv.include(env, "luarules/mission_api/triggers/unit_entered_location.lua")
local onGameFrame = unitEnteredLocation.callins.GameFrame

describe("mission_api.triggers.unit_entered_location", function()
	before_each(function()
		unitDefIDs, unitTeams, beingBuilt = {}, {}, {}
	end)

	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext(unitsInArea)
		local context = Builders.TriggerContext.new():WithUnitsInArea(unitsInArea):Build()
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

	it("fires once for a unit newly present in the area", function()
		local context, fired = newContext({ 100 })
		onGameFrame(trigger({ area = area, unitDefName = "armpw" }), triggerID, context)
		assert.are.equal(1, fired())
	end)

	it("does not fire again for a unit that stays in the area", function()
		local t = trigger({ area = area, unitDefName = "armpw" })
		local context, fired = newContext({ 100 })
		onGameFrame(t, triggerID, context)
		onGameFrame(t, triggerID, context)
		assert.are.equal(1, fired())
	end)

	it("fires again if the unit leaves and re-enters", function()
		local t = trigger({ area = area, unitDefName = "armpw" })
		local context, fired = newContext({ 100 })
		onGameFrame(t, triggerID, context)
		context.GetUnitsInArea = function()
			return {}
		end
		onGameFrame(t, triggerID, context)
		context.GetUnitsInArea = function()
			return { 100 }
		end
		onGameFrame(t, triggerID, context)
		assert.are.equal(2, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext({ 100 })
		context.DoesUnitHaveName = function()
			return false
		end
		onGameFrame(trigger({ area = area, unitName = "scouts" }), triggerID, context)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext({ 100 })
		onGameFrame(trigger({ area = area, unitDefName = "corfast" }), triggerID, context) -- unitDefID 1 = armpw
		assert.are.equal(0, fired())
	end)

	it("fires once per unit for multiple units entering together", function()
		local context, fired = newContext({ 100, 101 })
		onGameFrame(trigger({ area = area, unitDefName = "armpw" }), triggerID, context)
		assert.are.equal(2, fired())
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

		local function setUnitsInArea(context, unitIDs)
			context.GetUnitsInArea = function()
				return unitIDs
			end
		end

		it("fires once, when the last of the named units gets inside, and not again while they stay", function()
			local t = squadTrigger()
			t.settings.repeating = true
			local context, fired = newContext({ 100, 101 })
			onGameFrame(t, triggerID, context)
			assert.are.equal(0, fired())

			setUnitsInArea(context, { 100, 101, 102 })
			onGameFrame(t, triggerID, context)
			onGameFrame(t, triggerID, context)
			assert.are.equal(1, fired())
		end)

		it("fires again once one has left and they are all back", function()
			local t = squadTrigger()
			local context, fired = newContext({ 100, 101, 102 })
			onGameFrame(t, triggerID, context)
			setUnitsInArea(context, { 100, 101 })
			onGameFrame(t, triggerID, context)
			setUnitsInArea(context, { 100, 101, 102 })
			onGameFrame(t, triggerID, context)
			assert.are.equal(2, fired())
		end)

		it("is not held up by other units in the area", function()
			local context, fired = newContext({ 100, 200, 101, 102 })
			onGameFrame(squadTrigger(), triggerID, context)
			assert.are.equal(1, fired())
		end)

		it("stops waiting for a unit that died", function()
			local t = squadTrigger()
			local context, fired = newContext({ 100, 101 })
			onGameFrame(t, triggerID, context)
			tracking.UntrackUnitID(102)
			onGameFrame(t, triggerID, context)
			assert.are.equal(1, fired())
		end)

		it("does not fire once every named unit is gone", function()
			tracking.UntrackUnitName("squad")
			local context, fired = newContext({})
			onGameFrame(squadTrigger(), triggerID, context)
			assert.are.equal(0, fired())
		end)

		it("does not wait for a unit under construction", function()
			beingBuilt[102] = true
			local context, fired = newContext({ 100, 101 })
			onGameFrame(squadTrigger(), triggerID, context)
			assert.are.equal(1, fired())
		end)

		it("with a teamID, does not wait for a unit on another team", function()
			unitTeams[102] = 1
			local context, fired = newContext({ 100, 101 })
			onGameFrame(squadTrigger({ teamID = 0 }), triggerID, context)
			assert.are.equal(1, fired())
		end)

		it("with a unitDefName, does not wait for a unit of another def", function()
			unitDefIDs[102] = 2
			local context, fired = newContext({ 100, 101 })
			onGameFrame(squadTrigger({ unitDefName = "armpw" }), triggerID, context)
			assert.are.equal(1, fired())
		end)

		it("fires when the trigger becomes valid while they are all inside", function()
			local t = squadTrigger()
			local context = newContext({ 100, 101, 102 })
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
			local context, fired = newContext({ 100, 101, 102 })
			onGameFrame(t, "first", context)
			onGameFrame(t, "second", context)
			assert.are.equal(2, fired())
		end)
	end)
end)
