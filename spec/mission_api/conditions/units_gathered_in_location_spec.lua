local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local TriggerBuilder = VFS.Include("spec/builders/trigger_builder.lua")
local TriggerContextBuilder = VFS.Include("spec/builders/trigger_context_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")
local summarizeSchema = require("mission_api.schema_spec_helper")

local unitTeams, beingBuilt = {}, {}
---@type table<integer, boolean?>
local dead = {}
local looks = 0

-- unit_query captures these at its load.
local env = MissionSpecEnv.new({
	Spring = {
		GetUnitTeam = function(unitID)
			if dead[unitID] then
				return nil
			end
			return unitTeams[unitID] or 0
		end,
		GetUnitIsBeingBuilt = function(unitID)
			looks = looks + 1
			return beingBuilt[unitID] == true
		end,
	},
})

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes and .UnitQuery at load.
MissionApiBuilder.new():Install(env)

local unitsGathered = MissionSpecEnv.include(env, "luarules/mission_api/conditions/units_gathered_in_location.lua")
local callins = unitsGathered.callins

describe("mission_api.conditions.units_gathered_in_location", function()
	local tracking = GG["MissionAPI"].Modules.Tracking
	local triggerID = "t"
	local area = { x = 0, z = 0, radius = 100 }
	local frameNumber = 0

	before_each(function()
		unitTeams, beingBuilt, looks, frameNumber = {}, {}, 0, 0
		dead = {}
		for _, unitID in ipairs({ 100, 101, 102 }) do
			tracking.TrackUnit("squad", unitID)
		end
	end)

	after_each(function()
		tracking.UntrackUnitName("squad")
	end)

	local function squadTrigger()
		return TriggerBuilder.new():WithParameters({ area = area, unitName = "squad", teamName = 0 }):Build()
	end

	local function newContext()
		local context = TriggerContextBuilder.new():Build()
		return context, context.timesFired
	end

	-- Refuses a trigger that fired and does not repeat, as the gadget's ActivateTrigger does.
	local function gatedContext()
		local context = newContext()
		local fires = 0
		context.ActivateTrigger = function(t)
			if t.triggered and not t.settings.repeating then
				return false
			end
			t.triggered = true
			fires = fires + 1
			return true
		end
		return context, function()
			return fires
		end
	end

	local function frame(t, context, id)
		frameNumber = frameNumber + 1
		callins.GameFrame(t, id or triggerID, context, frameNumber)
	end

	it("declares its type and parameters, all required", function()
		assert.are.same({
			type = "UnitsGatheredInLocation",
			area = "Area!",
			unitName = "UnitName!",
			teamName = "TeamName!",
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

	it("fires again for each new gathering when it repeats", function()
		local t = squadTrigger()
		t.settings.repeating = true
		local context, fired = gatedContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101, 102 })
		frame(t, context)
		for _ = 1, 2 do
			callins.UnitsLeftArea(t, triggerID, context, { 102 })
			frame(t, context)
			callins.UnitsEnteredArea(t, triggerID, context, { 102 })
			frame(t, context)
		end
		assert.are.equal(3, fired())
	end)

	it("fires once when it does not repeat, and stops looking at them", function()
		local t = squadTrigger()
		local context, fired = gatedContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101, 102 })
		frame(t, context)
		looks = 0
		callins.UnitsLeftArea(t, triggerID, context, { 102 })
		frame(t, context)
		callins.UnitsEnteredArea(t, triggerID, context, { 102 })
		for _ = 1, 30 do
			frame(t, context)
		end
		assert.are.equal(1, fired())
		assert.are.equal(0, looks)
	end)

	it("does not fire again when one of them dies inside", function()
		local t = squadTrigger()
		local context, fired = newContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101, 102 })
		frame(t, context)
		dead[102] = true
		callins.UnitDestroyed(t, triggerID, context, 102)
		tracking.UntrackUnitID(102)
		callins.UnitsLeftArea(t, triggerID, context, { 102 })
		frame(t, context)
		assert.are.equal(1, fired())
	end)

	it("does not fire again when another unit walks out", function()
		local t = squadTrigger()
		local context, fired = newContext()
		context.DoesUnitHaveName = function(unitID)
			return unitID ~= 200
		end
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101, 102, 200 })
		frame(t, context)
		callins.UnitsLeftArea(t, triggerID, context, { 200 })
		frame(t, context)
		assert.are.equal(1, fired())
	end)

	it("is not held up by other units in the area", function()
		local t = squadTrigger()
		local context, fired = newContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 200, 101, 102 })
		frame(t, context)
		assert.are.equal(1, fired())
	end)

	it("does not look at them once it fired, while they stay", function()
		local t = squadTrigger()
		local context = newContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101, 102 })
		frame(t, context)
		looks = 0
		callins.UnitsEnteredArea(t, triggerID, context, { 200 })
		frame(t, context)
		assert.are.equal(0, looks)
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

	it("counts one built inside the area once it is finished", function()
		beingBuilt = { [100] = true, [101] = true, [102] = true }
		local t = squadTrigger()
		local context, fired = newContext()
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101, 102 })
		frame(t, context)
		beingBuilt = {}
		frame(t, context)
		assert.are.equal(0, fired())

		callins.UnitFinished(t, triggerID, context, 102)
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

	it("asks a refused trigger again half a second later while they are all inside", function()
		local t = squadTrigger()
		local context = newContext()
		local valid, asks, fires = false, 0, 0
		context.ActivateTrigger = function()
			asks = asks + 1
			if valid then
				fires = fires + 1
			end
			return valid
		end
		callins.UnitsEnteredArea(t, triggerID, context, { 100, 101, 102 })
		frame(t, context)
		valid = true
		for _ = 1, 14 do
			frame(t, context)
		end
		assert.are.equal(1, asks)
		assert.are.equal(0, fires)

		frame(t, context)
		frame(t, context)
		assert.are.equal(2, asks)
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
