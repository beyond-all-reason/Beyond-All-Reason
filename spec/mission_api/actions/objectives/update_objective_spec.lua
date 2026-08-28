require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/objectives/update_objective.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local missionApi = GG["MissionAPI"]

local function resetObjective(id, data)
	Builders.MissionApi.new():WithObjective(id, data):Install()
end

describe("mission_api.actions.update_objective", function()

	before_each(function()
		Builders.MissionApi.new():Install()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "UpdateObjective",
			objectiveID = "ObjectiveID!",
			completed = "Boolean",
			textKey = "String",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("is a no-op when the objective is already completed", function()
			resetObjective("obj1", { completed = true, progress = 0 })
			action.actionFunction("obj1", true, "newKey")
			assert.are.equal(0, #missionApi.calls.setObjectiveCompleted)
			assert.are.equal(0, #missionApi.calls.incrementObjectiveProgress)
			assert.are.equal(0, #missionApi.calls.echoObjectiveUpdate)
		end)

		it("delegates completed=true to SetObjectiveCompleted", function()
			resetObjective("obj1", { completed = false })
			action.actionFunction("obj1", true, nil)
			assert.are.equal(1, #missionApi.calls.setObjectiveCompleted)
			assert.are.equal("obj1", missionApi.calls.setObjectiveCompleted[1].objectiveID)
			assert.is_true(missionApi.calls.setObjectiveCompleted[1].completed)
		end)

		it("delegates completed=false to SetObjectiveCompleted", function()
			resetObjective("obj1", { completed = false })
			action.actionFunction("obj1", false, nil)
			assert.are.equal(1, #missionApi.calls.setObjectiveCompleted)
			assert.is_false(missionApi.calls.setObjectiveCompleted[1].completed)
		end)

		it("updates the textKey when provided", function()
			resetObjective("obj1", { completed = false })
			action.actionFunction("obj1", nil, "ui.objective.updated")
			assert.are.equal("ui.objective.updated", missionApi.Objectives["obj1"].textKey)
		end)

		it("echoes without progressing on a textKey-only update", function()
			resetObjective("obj1", { completed = false })
			action.actionFunction("obj1", nil, "ui.objective.updated")
			assert.are.equal(1, #missionApi.calls.echoObjectiveUpdate)
			assert.are.equal("obj1", missionApi.calls.echoObjectiveUpdate[1].objectiveID)
			assert.are.equal(0, #missionApi.calls.incrementObjectiveProgress)
			assert.are.equal(0, #missionApi.calls.setObjectiveCompleted)
		end)

		it("delegates to IncrementObjectiveProgress when no completed or textKey is given", function()
			resetObjective("obj1", { completed = false, progress = 2, amount = 5 })
			action.actionFunction("obj1", nil, nil)
			assert.are.equal(1, #missionApi.calls.incrementObjectiveProgress)
			assert.are.equal("obj1", missionApi.calls.incrementObjectiveProgress[1].objectiveID)
			assert.are.equal(0, #missionApi.calls.setObjectiveCompleted)
		end)

		it("applies both textKey and completed when both are given", function()
			resetObjective("obj1", { completed = false })
			action.actionFunction("obj1", true, "newKey")
			assert.are.equal("newKey", missionApi.Objectives["obj1"].textKey)
			assert.are.equal(1, #missionApi.calls.setObjectiveCompleted)
			assert.are.equal(0, #missionApi.calls.incrementObjectiveProgress)
		end)
	end)

end)
