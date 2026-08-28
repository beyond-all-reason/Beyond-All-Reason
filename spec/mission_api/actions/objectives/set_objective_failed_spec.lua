require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/objectives/set_objective_failed.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local missionApi = GG["MissionAPI"]

describe("mission_api.actions.set_objective_failed", function()

	before_each(function()
		Builders.MissionApi.new():Install()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "SetObjectiveFailed",
			objectiveID = "ObjectiveID!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("delegates to SetObjectiveFailed", function()
			Builders.MissionApi.new():WithObjective("obj1", { completed = false }):Install()
			action.actionFunction("obj1")
			assert.are.equal(1, #missionApi.calls.setObjectiveFailed)
			assert.are.equal("obj1", missionApi.calls.setObjectiveFailed[1].objectiveID)
		end)

		it("does not touch the completion path", function()
			Builders.MissionApi.new():WithObjective("obj1", { completed = false }):Install()
			action.actionFunction("obj1")
			assert.are.equal(0, #missionApi.calls.setObjectiveCompleted)
		end)
	end)
end)
