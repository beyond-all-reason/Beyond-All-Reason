require("spec_helper")
local Builders = VFS.Include("spec/builders/index.lua")
Builders.MissionApi.new():Install()
local actions = VFS.Include("luarules/mission_api/actions/objectives/update_objective.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")
-- The action only forwards to Modules.Objectives.Update. Completion, progress
-- and stage advancement live in the objectives module so that both condition
-- kinds share one engine; those semantics are covered by
-- spec/mission_api/objectives_spec.lua rather than through the action.
describe("mission_api.actions.update_objective", function()
	local missionApi
	before_each(function()
		missionApi = Builders.MissionApi.new():WithObjective("obj1", { completed = false }):Install()
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
		it("forwards the objectiveID to Objectives.Update", function()
			action.actionFunction("obj1", nil, nil)
			assert.are.equal(1, #missionApi.calls.updateObjective)
			assert.are.equal("obj1", missionApi.calls.updateObjective[1].objectiveID)
		end)
		it("forwards completed and textKey unchanged", function()
			action.actionFunction("obj1", true, "ui.objective.updated")
			local call = missionApi.calls.updateObjective[1]
			assert.is_true(call.completed)
			assert.are.equal("ui.objective.updated", call.textKey)
		end)
		-- false and nil mean different things to Update, so the action must not
		-- collapse them.
		it("forwards a false completed rather than dropping it", function()
			action.actionFunction("obj1", false, nil)
			assert.is_false(missionApi.calls.updateObjective[1].completed)
		end)
	end)
end)
