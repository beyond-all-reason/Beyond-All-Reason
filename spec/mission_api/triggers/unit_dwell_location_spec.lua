local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load, and Spring inside its handlers.
Builders.MissionApi.new():Install()

local unitDwellLocation = MissionSpecEnv.include(env, "luarules/mission_api/triggers/unit_dwell_location.lua")
local onUnitsEnteredArea = unitDwellLocation.callins.UnitsEnteredArea
local onUnitsLeftArea = unitDwellLocation.callins.UnitsLeftArea
local onGameFrame = unitDwellLocation.callins.GameFrame

describe("mission_api.triggers.unit_dwell_location", function()
	before_each(function()
		env.Spring.GetGameFrame = function()
			return 10
		end
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

	it("declares its type and parameters, requiring an area and duration", function()
		assert.are.equal("UnitDwellLocation", unitDwellLocation.type)
		local names, required = {}, {}
		for _, parameter in ipairs(unitDwellLocation.parameters) do
			names[parameter.name] = true
			if parameter.required then
				required[parameter.name] = true
			end
		end
		assert.are.same({ area = true, duration = true }, required)
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamName)
		assert.are.same({ "unitName", "unitDefName" }, unitDwellLocation.parameters.requiresOneOf)
	end)

	it("does not fire before the unit has dwelt for the full duration", function()
		local t = trigger({ area = area, duration = 3, unitDefName = "armpw" })
		local context, fired = newContext()
		onUnitsEnteredArea(t, triggerID, context, { 100 }) -- enters on frame 10
		onGameFrame(t, triggerID, context, 11)
		onGameFrame(t, triggerID, context, 12)
		assert.are.equal(0, fired())
	end)

	it("fires once the unit has dwelt for the full duration", function()
		local t = trigger({ area = area, duration = 2, unitDefName = "armpw" })
		local context, fired = newContext()
		onUnitsEnteredArea(t, triggerID, context, { 100 }) -- enters on frame 10
		onGameFrame(t, triggerID, context, 11)
		onGameFrame(t, triggerID, context, 12)
		assert.are.equal(1, fired())
	end)

	it("does not fire again for the same dwell once activated", function()
		local t = trigger({ area = area, duration = 1, unitDefName = "armpw" })
		local context, fired = newContext()
		onUnitsEnteredArea(t, triggerID, context, { 100 })
		onGameFrame(t, triggerID, context, 11) -- fires here
		onGameFrame(t, triggerID, context, 12)
		onGameFrame(t, triggerID, context, 13)
		assert.are.equal(1, fired())
	end)

	it("restarts the dwell for a unit that leaves and re-enters", function()
		local t = trigger({ area = area, duration = 2, unitDefName = "armpw" })
		local context, fired = newContext()
		onUnitsEnteredArea(t, triggerID, context, { 100 }) -- enters on frame 10
		onGameFrame(t, triggerID, context, 11)
		onUnitsLeftArea(t, triggerID, context, { 100 })
		env.Spring.GetGameFrame = function()
			return 12
		end
		onUnitsEnteredArea(t, triggerID, context, { 100 }) -- re-enters on frame 12
		onGameFrame(t, triggerID, context, 13)
		assert.are.equal(0, fired())
		onGameFrame(t, triggerID, context, 14)
		assert.are.equal(1, fired())
	end)

	it("does not start a dwell for a unit the filters reject", function()
		local t = trigger({ area = area, duration = 1, unitName = "scouts" })
		local context, fired = newContext()
		context.DoesUnitMatch = function()
			return false
		end
		onUnitsEnteredArea(t, triggerID, context, { 100 })
		onGameFrame(t, triggerID, context, 11)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a unit that lost its name while dwelling", function()
		local t = trigger({ area = area, duration = 1, unitName = "scouts" })
		local context, fired = newContext()
		onUnitsEnteredArea(t, triggerID, context, { 100 })
		context.DoesUnitHaveName = function()
			return false
		end
		onGameFrame(t, triggerID, context, 11)
		assert.are.equal(0, fired())
	end)

	it("tracks multiple units independently", function()
		local t = trigger({ area = area, duration = 1, unitDefName = "armpw" })
		local context, fired = newContext()
		onUnitsEnteredArea(t, triggerID, context, { 100, 101 })
		onGameFrame(t, triggerID, context, 11)
		assert.are.equal(2, fired())
	end)

	it("fires a duration of 0 on the frame after entering", function()
		local t = trigger({ area = area, duration = 0, unitDefName = "armpw" })
		local context, fired = newContext()
		onUnitsEnteredArea(t, triggerID, context, { 100 })
		onGameFrame(t, triggerID, context, 10)
		assert.are.equal(0, fired())
		onGameFrame(t, triggerID, context, 11)
		assert.are.equal(1, fired())
	end)
end)
