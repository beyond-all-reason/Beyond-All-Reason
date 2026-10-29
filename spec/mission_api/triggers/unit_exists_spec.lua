local UnitDefsBuilder = VFS.Include("spec/builders/unit_defs_builder.lua")
local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local TriggerBuilder = VFS.Include("spec/builders/trigger_builder.lua")
local TriggerContextBuilder = VFS.Include("spec/builders/trigger_context_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and UnitDefs inside its handler.
MissionApiBuilder.new():Install()

local unitDefs = UnitDefsBuilder.new():WithUnitDefs({
	[1] = { name = "armpw" },
	[2] = { name = "corfast" },
})
env.UnitDefs = unitDefs:GetUnitDefsByID()

local unitExists = MissionSpecEnv.include(env, "luarules/mission_api/triggers/unit_exists.lua")
local onMetaUnitAdded = unitExists.callins.MetaUnitAdded

describe("mission_api.triggers.unit_exists", function()
	local function trigger(parameters)
		return TriggerBuilder.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = TriggerContextBuilder.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	it("declares its type and parameters, requiring unitDefName", function()
		assert.are.equal("UnitExists", unitExists.type)
		assert.are.equal("unitDefName", unitExists.parameters[1].name)
		assert.is_true(unitExists.parameters[1].required)
		assert.are.equal("teamID", unitExists.parameters[2].name)
		assert.is_falsy(unitExists.parameters[2].required)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		onMetaUnitAdded(trigger({ unitDefName = "corfast" }), triggerID, context, 100, 1, 0) -- unitDefID 1 = armpw
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		onMetaUnitAdded(trigger({ unitDefName = "armpw", teamID = 5 }), triggerID, context, 100, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching unit", function()
		local context, fired = newContext()
		onMetaUnitAdded(trigger({ unitDefName = "armpw", teamID = 0 }), triggerID, context, 100, 1, 0)
		assert.are.equal(1, fired())
	end)
end)
