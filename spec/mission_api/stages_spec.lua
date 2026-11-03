local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

local stages = MissionSpecEnv.include(env, "luarules/mission_api/stages.lua")
local stagesLoader = MissionSpecEnv.include(env, "luarules/mission_api/stages_loader.lua")

-- Changing stage hands the objectives it enters and leaves to the objectives
-- module; what happens to them there is covered by objectives_spec.
local function objectivesModuleStub()
	return {
		ActivateObjective = function() end,
		CancelObjective = function() end,
		SetObjectiveActive = function() end,
	}
end

describe("mission_api.stages", function()

	before_each(function()
		GG["MissionAPI"] = {
			Modules = { Objectives = objectivesModuleStub() },
			Objectives = { a = {}, b = {}, c = {} },
		}
		GG["MissionAPI"].Stages = {
			first = { objectives = { "a", "b" } },
			second = { objectives = { "c" } },
			third = { objectives = {} },
		}
		GG["MissionAPI"].CurrentStageID = "first"
	end)

	describe("ChangeStage", function()
		it("sets the current stage", function()
			stages.ChangeStage("second")
			assert.are.equal("second", GG["MissionAPI"].CurrentStageID)
		end)

		it("is reflected by GetCurrentStageID", function()
			stages.ChangeStage("third")
			assert.are.equal("third", stages.GetCurrentStageID())
		end)
	end)

	describe("SetInitialStage", function()
		it("sets the current stage without announcing", function()
			stages.SetInitialStage("second")
			assert.are.equal("second", stages.GetCurrentStageID())
		end)
	end)

	describe("GetStage", function()
		it("returns the stage data", function()
			assert.are.same({ objectives = { "a", "b" } }, stages.GetStage("first"))
		end)

		it("returns nil for an unknown stage", function()
			assert.is_nil(stages.GetStage("nope"))
		end)
	end)

	describe("GetObjectiveIDs", function()
		it("defaults to the current stage", function()
			assert.are.same({ "a", "b" }, stages.GetObjectiveIDs())
		end)

		it("accepts an explicit stage", function()
			assert.are.same({ "c" }, stages.GetObjectiveIDs("second"))
		end)

		it("returns an empty list for an unknown stage", function()
			assert.are.same({}, stages.GetObjectiveIDs("nope"))
		end)
	end)
end)

describe("mission_api.stages_loader", function()

	describe("ProcessRawStages", function()
		it("returns the stages unchanged", function()
			local raw = { first = { objectives = { "a" } } }
			assert.are.same(raw, stagesLoader.ProcessRawStages(raw))
		end)

		-- api_missions defaults a missing Stages section to {} before calling this.
		it("returns an empty table when there are no stages", function()
			assert.are.same({}, stagesLoader.ProcessRawStages({}))
		end)
	end)
end)
