require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/objectives/update_objective.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.update_objective", function()
	local missionApi

	local function install(objective)
		missionApi = Builders.MissionApi.new():WithObjective("obj1", objective):Install()
	end

	it("declares its type and parameters", function()
		assert.are.same({
			type = "UpdateObjective",
			objectiveID = "ObjectiveID!",
		}, summarizeSchema(action))
	end)

	it("is a no-op when the objective is already completed", function()
		install({ completed = true, progress = 0 })

		action.actionFunction("obj1")

		assert.are.equal(0, missionApi.Objectives.obj1.progress)
		assert.are.equal(0, #missionApi.calls.completeObjective)
		assert.are.equal(0, #missionApi.calls.echoObjectiveUpdate)
	end)

	it("adds one to the progress and echoes while below the amount", function()
		install({ completed = false, progress = 2, amount = 5 })

		action.actionFunction("obj1")

		assert.are.equal(3, missionApi.Objectives.obj1.progress)
		assert.are.equal(0, #missionApi.calls.completeObjective)
		assert.are.equal(1, #missionApi.calls.echoObjectiveUpdate)
		assert.are.equal("obj1", missionApi.calls.echoObjectiveUpdate[1].objectiveID)
	end)

	it("completes the objective when the progress reaches the amount", function()
		install({ completed = false, progress = 4, amount = 5 })

		action.actionFunction("obj1")

		assert.are.equal(5, missionApi.Objectives.obj1.progress)
		assert.are.equal(1, #missionApi.calls.completeObjective)
		assert.are.equal("obj1", missionApi.calls.completeObjective[1].objectiveID)
	end)

	it("completes the objective on the first update when there is no amount", function()
		install({ completed = false })

		action.actionFunction("obj1")

		assert.are.equal(1, missionApi.Objectives.obj1.progress)
		assert.are.equal(1, #missionApi.calls.completeObjective)
	end)
end)
