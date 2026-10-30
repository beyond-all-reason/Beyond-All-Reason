local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load.
Builders.MissionApi.new():Install()

local unitEnteredLocation = MissionSpecEnv.include(env, "luarules/mission_api/conditions/unit_entered_location.lua")
local onUnitsEnteredArea = unitEnteredLocation.callins.UnitsEnteredArea

describe("mission_api.conditions.unit_entered_location", function()
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
end)
