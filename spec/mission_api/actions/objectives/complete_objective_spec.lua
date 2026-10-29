local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")

MissionApiBuilder.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/objectives/complete_objective.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.complete_objective", function()
	local missionApi

	before_each(function()
		missionApi = MissionApiBuilder.new():WithObjective("obj1", { active = true, completed = false }):Install()
	end)

	it("declares its type and parameters", function()
		assert.are.same({ type = "CompleteObjective", objectiveID = "ObjectiveID!" }, summarizeSchema(action))
	end)

	it("delegates to CompleteObjective", function()
		action.actionFunction("obj1")

		assert.are.equal(1, #missionApi.calls.completeObjective)
		assert.are.equal("obj1", missionApi.calls.completeObjective[1].objectiveID)
	end)
end)
