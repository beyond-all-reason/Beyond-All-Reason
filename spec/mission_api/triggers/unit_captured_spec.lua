require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and UnitDefs inside its handler.
Builders.MissionApi.new():Install()

local unitDefs = Builders.UnitDefs.new():WithUnitDefs({
	[1] = { name = "armpw" },
	[2] = { name = "corfast" },
})
_G.UnitDefs = unitDefs:GetUnitDefsByID()

local unitCaptured = VFS.Include("luarules/mission_api/triggers/unit_captured.lua")
local onUnitTaken = unitCaptured.callins.UnitTaken

describe("mission_api.triggers.unit_captured", function()
	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	it("declares its type and parameters", function()
		assert.are.equal("UnitCaptured", unitCaptured.type)
		local names = {}
		for _, parameter in ipairs(unitCaptured.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.oldTeamID)
		assert.is_true(names.newTeamID)
		assert.are.same({ "unitName", "unitDefName" }, unitCaptured.parameters.requiresOneOf)
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		onUnitTaken(trigger({ unitName = "engineers" }), triggerID, context, 100, 1, 0, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		onUnitTaken(trigger({ unitDefName = "corfast" }), triggerID, context, 100, 1, 0, 1) -- unitDefID 1 = armpw
		assert.are.equal(0, fired())
	end)

	it("filters by oldTeamID", function()
		local context, fired = newContext()
		onUnitTaken(trigger({ unitDefName = "armpw", oldTeamID = 5 }), triggerID, context, 100, 1, 0, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by newTeamID", function()
		local context, fired = newContext()
		onUnitTaken(trigger({ unitDefName = "armpw", newTeamID = 5 }), triggerID, context, 100, 1, 0, 1)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching capture", function()
		local context, fired = newContext()
		onUnitTaken(trigger({ unitDefName = "armpw", oldTeamID = 0, newTeamID = 1 }), triggerID, context, 100, 1, 0, 1)
		assert.are.equal(1, fired())
	end)
end)
