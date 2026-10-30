local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load, and Spring inside its handler.
Builders.MissionApi.new():Install()

local unitLeftLocation = MissionSpecEnv.include(env, "luarules/mission_api/conditions/unit_left_location.lua")
local onUnitsLeftArea = unitLeftLocation.callins.UnitsLeftArea

describe("mission_api.conditions.unit_left_location", function()
	before_each(function()
		env.Spring.GetUnitIsDead = function()
			return false
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

	it("declares its type and parameters, requiring an area", function()
		assert.are.equal("UnitLeftLocation", unitLeftLocation.type)
		assert.are.equal("area", unitLeftLocation.parameters[1].name)
		assert.is_true(unitLeftLocation.parameters[1].required)
		local names = {}
		for _, parameter in ipairs(unitLeftLocation.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.are.same({ "unitName", "unitDefName" }, unitLeftLocation.parameters.requiresOneOf)
	end)

	it("fires for a unit that left the area", function()
		local context, fired = newContext()
		onUnitsLeftArea(trigger({ area = area, unitDefName = "armpw" }), triggerID, context, { 100 })
		assert.are.equal(1, fired())
	end)

	it("fires once per unit leaving together", function()
		local context, fired = newContext()
		onUnitsLeftArea(trigger({ area = area, unitDefName = "armpw" }), triggerID, context, { 100, 101 })
		assert.are.equal(2, fired())
	end)

	it("does not fire for a unit that was destroyed in the area", function()
		env.Spring.GetUnitIsDead = function()
			return nil
		end
		local context, fired = newContext()
		onUnitsLeftArea(trigger({ area = area, unitDefName = "armpw" }), triggerID, context, { 100 })
		assert.are.equal(0, fired())
	end)

	it("does not fire for a unit the filters reject", function()
		local context, fired = newContext()
		context.DoesUnitMatch = function()
			return false
		end
		onUnitsLeftArea(trigger({ area = area, unitName = "scouts" }), triggerID, context, { 100 })
		assert.are.equal(0, fired())
	end)
end)
