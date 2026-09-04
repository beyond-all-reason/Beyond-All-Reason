require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/objectives/deactivate_objective.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.deactivate_objective", function()
	local missionApi

	before_each(function()
		missionApi = Builders.MissionApi.new():WithObjective("obj1", { completed = false, active = true }):Install()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "DeactivateObjective",
			objectiveID = "ObjectiveID!",
		}, summarizeSchema(action))
	end)

	it("delegates to DeactivateObjective", function()
		action.actionFunction("obj1")
		assert.are.equal(1, #missionApi.calls.deactivateObjective)
		assert.are.equal("obj1", missionApi.calls.deactivateObjective[1].objectiveID)
	end)

	it("echoes the objective", function() -- temp
		action.actionFunction("obj1")
		assert.are.equal(1, #missionApi.calls.echoObjectiveUpdate)
		assert.are.equal("obj1", missionApi.calls.echoObjectiveUpdate[1].objectiveID)
		assert.are.equal(missionApi.Objectives.obj1, missionApi.calls.echoObjectiveUpdate[1].objective)
	end)
end)
