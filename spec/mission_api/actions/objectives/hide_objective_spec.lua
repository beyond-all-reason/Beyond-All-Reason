require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/objectives/hide_objective.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.hide_objective", function()
	local missionApi

	before_each(function()
		missionApi = Builders.MissionApi.new():WithObjective("obj1", { active = true, completed = false }):Install()
	end)

	it("declares its type and parameters", function()
		assert.are.same({ type = "HideObjective", objectiveID = "ObjectiveID!" }, summarizeSchema(action))
	end)

	it("delegates to HideObjective", function()
		action.actionFunction("obj1")

		assert.are.equal(1, #missionApi.calls.hideObjective)
		assert.are.equal("obj1", missionApi.calls.hideObjective[1].objectiveID)
	end)
end)
