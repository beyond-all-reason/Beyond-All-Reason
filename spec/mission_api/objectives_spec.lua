require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")
local RegisterMissionApiModules = require("mission_api.spec_helper")

-- The real trigger definitions, so event triggers carry the real Event type.
-- (Trigger files read GG['MissionAPI'].Modules at include time.)
Builders.MissionApi.new():Install()
RegisterMissionApiModules()
local triggerDefinitions = VFS.Include("luarules/mission_api/triggers_loader.lua").LoadTriggerDefinitions()
local T = triggerDefinitions.Types

local Objectives = VFS.Include("luarules/mission_api/objectives.lua")

describe("mission_api.objectives", function()
	local missionApi

	-- A mission to build up with the mock's With* methods.
	local function mission()
		return Builders.MissionApi.new():WithTriggerDefinitions(triggerDefinitions)
	end

	local function install(builder)
		missionApi = builder:Install()
	end

	before_each(function()
		install(mission())
	end)

	describe("ChangeStage", function()
		it("sets the current stage ID", function()
			Objectives.ChangeStage("stage2")

			assert.are.equal("stage2", missionApi.CurrentStageID)
		end)
	end)

	describe("TryAdvanceStage", function()
		it("does nothing for an objective that is not completed", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { completed = false, nextStage = "s2" })
					:WithCurrentStage("s1")
			)

			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)

			assert.are.equal("s1", missionApi.CurrentStageID)
		end)

		it("does nothing for an objective without a nextStage", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithObjective("obj1", { completed = true })
					:WithCurrentStage("s1")
			)

			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)

			assert.are.equal("s1", missionApi.CurrentStageID)
		end)

		it("does nothing when the current stage does not exist", function()
			install(
				mission()
					:WithStage("s2")
					:WithObjective("obj1", { completed = true, nextStage = "s2" })
					:WithCurrentStage("nowhere")
			)

			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)

			assert.are.equal("nowhere", missionApi.CurrentStageID)
		end)

		it("advances when the objective is the only one in the stage with its nextStage", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { completed = true, nextStage = "s2" })
					:WithCurrentStage("s1")
			)

			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)

			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("waits for every objective in the stage sharing the nextStage", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1", "obj2" } })
					:WithStage("s2")
					:WithObjective("obj1", { completed = true, nextStage = "s2" })
					:WithObjective("obj2", { completed = false, nextStage = "s2" })
					:WithCurrentStage("s1")
			)

			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)
			assert.are.equal("s1", missionApi.CurrentStageID)

			missionApi.Objectives.obj2.completed = true
			Objectives.TryAdvanceStage(missionApi.Objectives.obj2)
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("ignores objectives in the stage with a different nextStage", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1", "obj2" } })
					:WithStage("s2")
					:WithStage("s3")
					:WithObjective("obj1", { completed = true, nextStage = "s2" })
					:WithObjective("obj2", { completed = false, nextStage = "s3" })
					:WithCurrentStage("s1")
			)

			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)

			assert.are.equal("s2", missionApi.CurrentStageID)
		end)
	end)

	-- Called by statistics.lua as (objectiveID, eventTeamID, eventUnitDefName,
	-- eventUnitNames, direction, metadata); the metadata is what objectives_loader
	-- records for a managed objective: the trigger's parameters, the stages that
	-- list the objective, and the amount to reach.
	describe("UpdateObjectiveProgress", function()
		it("ignores an event for another team", function()
			install(mission():WithObjective("obj1", { completed = false }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 1, "armwar", nil, 1, metadata)

			assert.is_nil(metadata._count)
			assert.is_nil(missionApi.Objectives.obj1.progress)
		end)

		it("ignores an event for another unitDefName", function()
			install(mission():WithObjective("obj1", { completed = false }))
			local metadata = { parameters = { teamID = 0, unitDefName = "corak" }, stages = {}, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.is_nil(metadata._count)
		end)

		it("ignores an event without the unitName it watches", function()
			install(mission():WithObjective("obj1", { completed = false }))
			local metadata = { parameters = { teamID = 0, unitName = "bots" }, stages = {}, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", {}, 1, metadata)
			assert.is_nil(metadata._count)

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", { bots = true }, 1, metadata)
			assert.are.equal(1, metadata._count)
		end)

		it("counts an event outside the objective's stages without evaluating completion", function()
			install(
				mission()
					:WithStage("objStage", { objectives = { "obj1" } })
					:WithStage("otherStage")
					:WithObjective("obj1", { completed = false })
					:WithCurrentStage("otherStage")
			)
			local metadata = { parameters = { teamID = 0 }, stages = { "objStage" }, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal(1, metadata._count)
			assert.is_nil(missionApi.Objectives.obj1.progress)
			assert.is_false(missionApi.Objectives.obj1.completed)
		end)

		it("evaluates completion in one of the objective's stages", function()
			install(
				mission()
					:WithStage("objStage", { objectives = { "obj1" } })
					:WithObjective("obj1", { completed = false })
					:WithCurrentStage("objStage")
			)
			local metadata = { parameters = { teamID = 0 }, stages = { "objStage" }, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal(1, missionApi.Objectives.obj1.progress)
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("evaluates completion in any stage when the objective is listed in none", function()
			install(mission():WithStage("s1"):WithObjective("obj1", { completed = false }):WithCurrentStage("s1"))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("completes on the first event when there is no amount", function()
			install(mission():WithObjective("obj1", { completed = false }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = nil }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("completes when the count reaches the amount", function()
			install(mission():WithObjective("obj1", { completed = false }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 2 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_false(missionApi.Objectives.obj1.completed)

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("completes an amount = 0 objective when the count returns to zero", function()
			install(mission():WithObjective("obj1", { completed = false }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 0 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_false(missionApi.Objectives.obj1.completed)

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, -1, metadata)
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("freezes the objective's progress once completed", function()
			install(mission():WithObjective("obj1", { completed = true, progress = 3 }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 3, _count = 3 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, -1, metadata)

			assert.are.equal(3, missionApi.Objectives.obj1.progress)
		end)

		it("advances the stage through the gate on completion", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { completed = false, nextStage = "s2" })
					:WithCurrentStage("s1")
			)
			local metadata = { parameters = { teamID = 0 }, stages = { "s1" }, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("activates the trigger named by onCompleted on completion", function()
			install(
				mission()
					:WithObjective("obj1", { completed = false, onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
			)
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.done, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("activates nothing before completion", function()
			install(
				mission()
					:WithObjective("obj1", { completed = false, onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
			)
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 2 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)
	end)

	describe("FailObjective", function()
		it("completes the objective and marks it failed", function()
			install(mission():WithObjective("obj1", { completed = false }))

			Objectives.FailObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.completed)
			assert.is_true(missionApi.Objectives.obj1.failed)
		end)

		it("is a no-op on a completed objective", function()
			install(mission():WithObjective("obj1", { completed = true }))

			Objectives.FailObjective("obj1")

			assert.is_nil(missionApi.Objectives.obj1.failed)
		end)

		it("does not mark a success as failed", function()
			install(mission():WithObjective("obj1", { completed = false }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.is_true(missionApi.Objectives.obj1.completed)
			assert.is_nil(missionApi.Objectives.obj1.failed)
		end)

		it("activates the trigger the objective names in onFailed", function()
			install(
				mission()
					:WithObjective("obj1", { completed = false, onFailed = "failed" })
					:WithTrigger("failed", { type = T.Event })
			)

			Objectives.FailObjective("obj1")

			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.failed, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("leaves the trigger named in onCompleted alone", function()
			install(
				mission()
					:WithObjective("obj1", { completed = false, onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
			)

			Objectives.FailObjective("obj1")

			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("activates the trigger while the objective's stage is still current", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { completed = false, nextStage = "s2", onFailed = "failed" })
					:WithTrigger("failed", { type = T.Event })
					:WithCurrentStage("s1")
			)

			Objectives.FailObjective("obj1")

			assert.are.equal("s1", missionApi.calls.activateTrigger[1].stageID)
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("advances the stage through the gate, so a failure cannot softlock it", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { completed = false, nextStage = "s2" })
					:WithCurrentStage("s1")
			)

			Objectives.FailObjective("obj1")

			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("lets a stage change from the trigger stand instead of running the gate", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithStage("s9")
					:WithObjective("obj1", { completed = false, nextStage = "s2", onFailed = "failed" })
					:WithTrigger("failed", { type = T.Event })
					:WithCurrentStage("s1")
			)
			missionApi.ActivateTrigger = function()
				Objectives.ChangeStage("s9")
			end

			Objectives.FailObjective("obj1")

			assert.are.equal("s9", missionApi.CurrentStageID)
		end)
	end)

	describe("OnObjectiveCompleted", function()
		it("activates the trigger the objective names in onCompleted", function()
			install(
				mission()
					:WithObjective("obj1", { completed = true, onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
					:WithTrigger("other", { type = T.Event })
			)

			Objectives.OnObjectiveCompleted(missionApi.Objectives.obj1)

			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.done, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("activates nothing when the objective names no trigger", function()
			install(mission():WithObjective("obj1", { completed = true }):WithTrigger("done", { type = T.Event }))

			Objectives.OnObjectiveCompleted(missionApi.Objectives.obj1)

			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("activates the trigger while the objective's stage is still current", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { completed = true, nextStage = "s2", onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
					:WithCurrentStage("s1")
			)

			Objectives.OnObjectiveCompleted(missionApi.Objectives.obj1)

			assert.are.equal("s1", missionApi.calls.activateTrigger[1].stageID)
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("advances the stage through the gate when the trigger does not change it", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { completed = true, nextStage = "s2", onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
					:WithCurrentStage("s1")
			)

			Objectives.OnObjectiveCompleted(missionApi.Objectives.obj1)

			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("lets a stage change from the trigger stand instead of running the gate", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithStage("s9")
					:WithObjective("obj1", { completed = true, nextStage = "s2", onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
					:WithCurrentStage("s1")
			)
			-- The trigger's actions, as the gadget would run them:
			missionApi.ActivateTrigger = function()
				Objectives.ChangeStage("s9")
			end

			Objectives.OnObjectiveCompleted(missionApi.Objectives.obj1)

			assert.are.equal("s9", missionApi.CurrentStageID)
		end)

		it("counts a change back into the same stage as a change", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { completed = true, nextStage = "s2", onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
					:WithCurrentStage("s1")
			)
			missionApi.ActivateTrigger = function()
				Objectives.ChangeStage("s1")
			end

			Objectives.OnObjectiveCompleted(missionApi.Objectives.obj1)

			assert.are.equal("s1", missionApi.CurrentStageID)
		end)

		it("counts a stage change from a nested completion as a change", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1", "obj2" } })
					:WithStage("s2")
					:WithStage("s3")
					:WithObjective("obj1", { completed = true, nextStage = "s2", onCompleted = "done" })
					:WithObjective("obj2", { completed = true, nextStage = "s3" })
					:WithTrigger("done", { type = T.Event })
					:WithCurrentStage("s1")
			)
			-- obj1's trigger completes obj2, whose own gate moves the stage:
			missionApi.ActivateTrigger = function()
				Objectives.OnObjectiveCompleted(missionApi.Objectives.obj2)
			end

			Objectives.OnObjectiveCompleted(missionApi.Objectives.obj1)

			assert.are.equal("s3", missionApi.CurrentStageID)
		end)
	end)
end)
