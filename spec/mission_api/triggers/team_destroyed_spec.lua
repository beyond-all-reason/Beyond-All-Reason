require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local teamDestroyed = VFS.Include("luarules/mission_api/triggers/team_destroyed.lua")
local onTeamDied = teamDestroyed.callins.TeamDied

describe("mission_api.triggers.team_destroyed", function()
	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	it("declares its type and required teamID parameter", function()
		assert.are.equal("TeamDestroyed", teamDestroyed.type)
		assert.are.equal("teamID", teamDestroyed.parameters[1].name)
		assert.is_true(teamDestroyed.parameters[1].required)
	end)

	it("fires when the matching team dies", function()
		local context, fired = newContext()
		onTeamDied(trigger({ teamID = 5 }), triggerID, context, 5)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a different team", function()
		local context, fired = newContext()
		onTeamDied(trigger({ teamID = 5 }), triggerID, context, 6)
		assert.are.equal(0, fired())
	end)
end)
