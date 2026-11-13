local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local TriggerBuilder = VFS.Include("spec/builders/trigger_builder.lua")
local TriggerContextBuilder = VFS.Include("spec/builders/trigger_context_builder.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local squadAssembled = VFS.Include("luarules/mission_api/triggers/squad_assembled.lua")
local onSquadAssembled = squadAssembled.callins.SquadAssembled
local summarizeSchema = require("mission_api.schema_spec_helper")

local TEAM_ID = 3

describe("mission_api.triggers.squad_assembled", function()
	local function trigger(parameters)
		return TriggerBuilder.new():WithParameters(parameters):Build()
	end

	it("declares its type and parameters", function()
		assert.are.same({
			type = "SquadAssembled",
			squadName = "SquadName",
			teamName = "TeamName",
			requiresOneOf = { "squadName", "teamName" },
		}, summarizeSchema(squadAssembled))
	end)

	it("fires when its squad assembles", function()
		local context = TriggerContextBuilder.new():Build()
		onSquadAssembled(trigger({ squadName = "raiders" }), "t", context, "raiders", TEAM_ID)
		assert.are.equal(1, context.timesFired())
	end)

	it("ignores other squads assembling", function()
		local context = TriggerContextBuilder.new():Build()
		onSquadAssembled(trigger({ squadName = "raiders" }), "t", context, "guards", TEAM_ID)
		assert.are.equal(0, context.timesFired())
	end)

	it("fires for any squad of its team", function()
		local context = TriggerContextBuilder.new():Build()
		onSquadAssembled(trigger({ teamName = TEAM_ID }), "t", context, "guards", TEAM_ID)
		assert.are.equal(1, context.timesFired())
	end)

	it("ignores the squads of other teams", function()
		local context = TriggerContextBuilder.new():Build()
		onSquadAssembled(trigger({ teamName = TEAM_ID }), "t", context, "guards", TEAM_ID + 1)
		assert.are.equal(0, context.timesFired())
	end)
end)
