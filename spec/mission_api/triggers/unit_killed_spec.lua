require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and UnitDefs inside its handler.
Builders.MissionApi.new():Install()

local unitDefs = Builders.UnitDefs.new():WithUnitDefs({
	[1] = { name = "armpw" },
	[2] = { name = "corfast" },
})
_G.UnitDefs = unitDefs:GetUnitDefsByID()

local unitKilled = VFS.Include("luarules/mission_api/triggers/unit_killed.lua")
local onUnitDestroyed = unitKilled.callins.UnitDestroyed

describe("mission_api.triggers.unit_killed", function()
	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	it("declares its type and parameters", function()
		assert.are.equal("UnitKilled", unitKilled.type)
		local names = {}
		for _, parameter in ipairs(unitKilled.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.are.same({ "unitName", "unitDefName" }, unitKilled.parameters.requiresOneOf)
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		onUnitDestroyed(trigger({ unitName = "engineers" }), triggerID, context, 100, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		onUnitDestroyed(trigger({ unitDefName = "corfast" }), triggerID, context, 100, 1, 0) -- unitDefID 1 = armpw
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		onUnitDestroyed(trigger({ unitDefName = "armpw", teamID = 5 }), triggerID, context, 100, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching kill", function()
		local context, fired = newContext()
		onUnitDestroyed(trigger({ unitDefName = "armpw", teamID = 0 }), triggerID, context, 100, 1, 0)
		assert.are.equal(1, fired())
	end)
end)
