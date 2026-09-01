require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and UnitDefs / Spring.GetUnitDefID inside its handler.
Builders.MissionApi.new():Install()

local unitDefs = Builders.UnitDefs.new():WithUnitDefs({
	[1] = { name = "armpw" },
	[2] = { name = "corfast" },
})
_G.UnitDefs = unitDefs:GetUnitDefsByID()

local unitEnteredLocation = VFS.Include("luarules/mission_api/triggers/unit_entered_location.lua")
local onGameFrame = unitEnteredLocation.callins.GameFrame

describe("mission_api.triggers.unit_entered_location", function()
	before_each(function()
		Spring.GetUnitDefID = function()
			return 1
		end
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
end)
