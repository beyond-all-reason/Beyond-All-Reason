local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")
local summarizeSchema = require("mission_api.schema_spec_helper")

local unitTeams, beingBuilt = {}, {}
local looks = 0

-- unit_query captures these at its load.
local env = MissionSpecEnv.new({
	Spring = {
		GetUnitTeam = function(unitID)
			return unitTeams[unitID] or 0
		end,
		GetUnitIsBeingBuilt = function(unitID)
			looks = looks + 1
			return beingBuilt[unitID] == true
		end,
	},
})

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes and .UnitQuery at load.
Builders.MissionApi.new():Install(env)

local unitsGathered = MissionSpecEnv.include(env, "luarules/mission_api/triggers/units_gathered_in_location.lua")
local callins = unitsGathered.callins

describe("mission_api.triggers.units_gathered_in_location", function()
	local tracking = GG["MissionAPI"].Modules.Tracking
	local triggerID = "t"
	local area = { x = 0, z = 0, radius = 100 }

	before_each(function()
		unitTeams, beingBuilt, looks = {}, {}, 0
		for _, unitID in ipairs({ 100, 101, 102 }) do
			tracking.TrackUnit("squad", unitID)
		end
	end)

	after_each(function()
		tracking.UntrackUnitName("squad")
	end)

	local function squadTrigger()
		return Builders.Trigger.new():WithParameters({ area = area, unitName = "squad", teamID = 0 }):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local function frame(t, context, id)
		callins.GameFrame(t, id or triggerID, context)
	end

	it("declares its type and parameters, all required", function()
		assert.are.same({
			type = "UnitsGatheredInLocation",
			area = "Area!",
			unitName = "UnitName!",
			teamID = "TeamID!",
		}, summarizeSchema(unitsGathered))
	end)

	it("fires once, when the last of them gets inside, and not again while they stay", function()
		local t = squadTrigger()
		t.settings.repeating = true
		local context, fired = newContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101 })
		frame(t, context)
		assert.are.equal(0, fired())

		callins.UnitsEnteredArea(t, triggerID, context, { 102 })
		frame(t, context)
		frame(t, context)
		assert.are.equal(1, fired())
	end)

	it("fires again once one has left and they are all back", function()
		local t = squadTrigger()
		local context, fired = newContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101, 102 })
		frame(t, context)
		callins.UnitsLeftArea(t, triggerID, context, { 102 })
		frame(t, context)
		callins.UnitsEnteredArea(t, triggerID, context, { 102 })
		frame(t, context)
		assert.are.equal(2, fired())
	end)

	it("is not held up by other units in the area", function()
		local t = squadTrigger()
		local context, fired = newContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 200, 101, 102 })
		frame(t, context)
		assert.are.equal(1, fired())
	end)

	it("does not look at them on a frame after nothing changed", function()
		local t = squadTrigger()
		local context = newContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101 })
		frame(t, context)
		looks = 0
		frame(t, context)
		context.DoesUnitHaveName = function()
			return false
		end
		callins.UnitDestroyed(t, triggerID, context, 300)
		frame(t, context)
		assert.are.equal(0, looks)
	end)

	it("stops waiting for one that died outside", function()
		local t = squadTrigger()
		local context, fired = newContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101 })
		frame(t, context)
		callins.UnitDestroyed(t, triggerID, context, 102)
		tracking.UntrackUnitID(102)
		frame(t, context)
		assert.are.equal(1, fired())
	end)

	it("stops waiting for one that was captured or given away outside", function()
		local t = squadTrigger()
		local context, fired = newContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101 })
		frame(t, context)
		unitTeams[102] = 1
		callins.UnitGiven(t, triggerID, context, 102, 1, 1, 0)
		frame(t, context)
		assert.are.equal(1, fired())
	end)

	it("does not wait for one still being built", function()
		beingBuilt[102] = true
		local t = squadTrigger()
		local context, fired = newContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101 })
		frame(t, context)
		assert.are.equal(1, fired())
	end)

	it("does not fire once every one of them is gone", function()
		local t = squadTrigger()
		local context, fired = newContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 200 })
		tracking.UntrackUnitName("squad")
		frame(t, context)
		assert.are.equal(0, fired())
	end)

	it("fires when the trigger becomes valid while they are all inside", function()
		local t = squadTrigger()
		local context = newContext()
		local valid, fires = false, 0
		context.ActivateTrigger = function()
			if valid then
				fires = fires + 1
			end
			return valid
		end
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101, 102 })
		frame(t, context)
		valid = true
		frame(t, context)
		frame(t, context)
		assert.are.equal(1, fires)
	end)

	it("keeps each trigger to itself", function()
		local t = squadTrigger()
		local context, fired = newContext()
		callins.UnitsEnteredArea(t, "first", context, { 100, 101, 102 })
		callins.UnitsEnteredArea(t, "second", context, { 100, 101 })
		frame(t, context, "first")
		frame(t, context, "second")
		assert.are.equal(1, fired())
	end)
end)
