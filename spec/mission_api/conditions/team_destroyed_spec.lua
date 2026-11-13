local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local TriggerBuilder = VFS.Include("spec/builders/trigger_builder.lua")
local ConditionContextBuilder = VFS.Include("spec/builders/condition_context_builder.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local teamDestroyed = VFS.Include("luarules/mission_api/conditions/team_destroyed.lua")
local onTeamDied = teamDestroyed.callins.TeamDied

describe("mission_api.conditions.team_destroyed", function()
	local function trigger(parameters)
		return TriggerBuilder.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = ConditionContextBuilder.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	it("declares its type and required teamName parameter", function()
		assert.are.equal("TeamDestroyed", teamDestroyed.type)
		assert.are.equal("teamName", teamDestroyed.parameters[1].name)
		assert.is_true(teamDestroyed.parameters[1].required)
	end)

	it("fires when the matching team dies", function()
		local context, fired = newContext()
		onTeamDied(trigger({ teamName = 5 }), triggerID, context, 5)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a different team", function()
		local context, fired = newContext()
		onTeamDied(trigger({ teamName = 5 }), triggerID, context, 6)
		assert.are.equal(0, fired())
	end)
end)
