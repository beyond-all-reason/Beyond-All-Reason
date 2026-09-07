require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and UnitDefs / Spring.GetUnitDefID inside its handler.
Builders.MissionApi.new():Install()

local unitDefs = Builders.UnitDefs.new():WithUnitDefs({
	[1] = { name = "armpw" },
	[2] = { name = "corfast" },
})
_G.UnitDefs = unitDefs:GetUnitDefsByID()

local unitLeftLocation = VFS.Include("luarules/mission_api/triggers/unit_left_location.lua")
local onGameFrame = unitLeftLocation.callins.GameFrame

describe("mission_api.triggers.unit_left_location", function()
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

	it("does not fire while the unit stays in the area", function()
		local context, fired = newContext({ 100 })
		onGameFrame(trigger({ area = area, unitDefName = "armpw" }), triggerID, context)
		assert.are.equal(0, fired())
	end)

	it("fires once when a tracked unit leaves the area", function()
		local t = trigger({ area = area, unitDefName = "armpw" })
		local context, fired = newContext({ 100 })
		onGameFrame(t, triggerID, context) -- establishes the unit as present
		context.GetUnitsInArea = function()
			return {}
		end
		onGameFrame(t, triggerID, context)
		assert.are.equal(1, fired())
	end)

	it("does not fire again after the unit has left", function()
		local t = trigger({ area = area, unitDefName = "armpw" })
		local context, fired = newContext({ 100 })
		onGameFrame(t, triggerID, context)
		context.GetUnitsInArea = function()
			return {}
		end
		onGameFrame(t, triggerID, context)
		onGameFrame(t, triggerID, context)
		assert.are.equal(1, fired())
	end)

	it("fires again if the unit re-enters and leaves again", function()
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
		context.GetUnitsInArea = function()
			return {}
		end
		onGameFrame(t, triggerID, context)
		assert.are.equal(2, fired())
	end)

	it("filters by unitName", function()
		local t = trigger({ area = area, unitName = "scouts" })
		local context, fired = newContext({ 100 })
		context.DoesUnitHaveName = function()
			return false
		end
		onGameFrame(t, triggerID, context)
		context.GetUnitsInArea = function()
			return {}
		end
		onGameFrame(t, triggerID, context)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local t = trigger({ area = area, unitDefName = "corfast" }) -- unitDefID 1 = armpw
		local context, fired = newContext({ 100 })
		onGameFrame(t, triggerID, context)
		context.GetUnitsInArea = function()
			return {}
		end
		onGameFrame(t, triggerID, context)
		assert.are.equal(0, fired())
	end)
end)
