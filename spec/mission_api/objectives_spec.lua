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
		it("makes the stage current and activates the objectives it lists", function()
			install(
				mission()
					:WithStage("s1")
					:WithStage("s2", { objectives = { "listed" } })
					:WithObjective("listed", { active = false, completed = false })
					:WithObjective("unlisted", { active = false, completed = false })
					:WithCurrentStage("s1")
			)

			Objectives.ChangeStage("s2")

			assert.are.equal("s2", missionApi.CurrentStageID)
			assert.is_true(missionApi.Objectives.listed.active)
			assert.is_false(missionApi.Objectives.unlisted.active)
		end)

		it("takes every objective the left stage lists out of play, triggers included, and no other", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "unfinished", "finished" } })
					:WithStage("s2")
					:WithObjective("unfinished", { active = true, completed = false })
					:WithObjective("finished", { active = true, completed = true })
					:WithObjective("free", { active = true, completed = false })
					:WithObjectiveTrigger("unfinished", { settings = { active = true } })
					:WithCurrentStage("s1")
			)

			Objectives.ChangeStage("s2")

			assert.is_false(missionApi.Objectives.unfinished.active)
			assert.is_false(missionApi.Triggers.__objective_unfinished.settings.active)
			assert.is_false(missionApi.Objectives.finished.active)
			assert.is_true(missionApi.Objectives.free.active)
		end)

		it("cancels the unfinished objectives the left stage lists, and not the finished ones", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "unfinished", "finished" } })
					:WithStage("s2")
					:WithObjective("unfinished", { active = true, completed = false, onCanceled = "gone" })
					:WithObjective("finished", { active = true, completed = true, onCanceled = "kept" })
					:WithTrigger("gone", { type = T.Event })
					:WithTrigger("kept", { type = T.Event })
					:WithCurrentStage("s1")
			)

			Objectives.ChangeStage("s2")

			assert.is_true(missionApi.Objectives.unfinished.canceled)
			assert.is_nil(missionApi.Objectives.finished.canceled)
			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.gone, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("carries an objective listed by both stages over untouched", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "carried" } })
					:WithStage("s2", { objectives = { "carried" } })
					:WithObjective(
						"carried",
						{ active = true, completed = false, onActivated = "on", onCanceled = "off" }
					)
					:WithObjectiveTrigger("carried", { settings = { active = true } })
					:WithTrigger("on", { type = T.Event })
					:WithTrigger("off", { type = T.Event })
					:WithCurrentStage("s1")
			)

			Objectives.ChangeStage("s2")

			assert.is_true(missionApi.Objectives.carried.active)
			assert.is_true(missionApi.Triggers.__objective_carried.settings.active)
			assert.is_nil(missionApi.Objectives.carried.canceled)
			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("does nothing for a stage that does not exist", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithObjective("obj1", { active = true, completed = false })
					:WithCurrentStage("s1")
			)

			Objectives.ChangeStage("nowhere")

			assert.are.equal("s1", missionApi.CurrentStageID)
			assert.is_true(missionApi.Objectives.obj1.active)
			assert.is_nil(missionApi.Objectives.obj1.canceled)
		end)
	end)

	describe("ActivateStage", function()
		it("makes the stage current and activates every objective it lists", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "a", "b" } })
					:WithObjective("a", { active = false, completed = false })
					:WithObjective("b", { active = false, completed = false })
					:WithObjective("c", { active = false, completed = false })
			)

			Objectives.ActivateStage("s1")

			assert.are.equal("s1", missionApi.CurrentStageID)
			assert.is_true(missionApi.Objectives.a.active)
			assert.is_true(missionApi.Objectives.b.active)
			assert.is_false(missionApi.Objectives.c.active)
		end)

		it("activates the trigger each listed objective names in onActivated, once the stage is current", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "a", "b" } })
					:WithObjective("a", { active = false, completed = false, onActivated = "beganA" })
					:WithObjective("b", { active = false, completed = false, onActivated = "beganB" })
					:WithTrigger("beganA", { type = T.Event })
					:WithTrigger("beganB", { type = T.Event })
			)

			Objectives.ActivateStage("s1")

			assert.are.equal(2, #missionApi.calls.activateTrigger)
			assert.are.equal("s1", missionApi.calls.activateTrigger[1].stageID)
			assert.are.equal("s1", missionApi.calls.activateTrigger[2].stageID)
		end)

		it("does nothing for a stage that does not exist", function()
			install(mission():WithObjective("a", { active = false, completed = false }))

			Objectives.ActivateStage("nowhere")

			assert.is_nil(missionApi.CurrentStageID)
			assert.is_false(missionApi.Objectives.a.active)
		end)
	end)

	describe("ActivateObjective", function()
		it("flips the objective on and enables its synthesized trigger", function()
			install(
				mission()
					:WithObjective("obj1", { active = false, completed = false })
					:WithObjectiveTrigger("obj1", { settings = { active = false } })
			)

			Objectives.ActivateObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.active)
			assert.is_true(missionApi.Triggers.__objective_obj1.settings.active)
		end)

		it("flips on an objective that has no synthesized trigger", function()
			install(mission():WithObjective("obj1", { active = false, completed = false }))

			Objectives.ActivateObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.active)
		end)

		it("activates the trigger the objective names in onActivated", function()
			install(
				mission()
					:WithObjective("obj1", { active = false, completed = false, onActivated = "began" })
					:WithTrigger("began", { type = T.Event })
			)

			Objectives.ActivateObjective("obj1")

			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.began, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("clears the canceled mark", function()
			install(mission():WithObjective("obj1", { active = false, completed = false, canceled = true }))

			Objectives.ActivateObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.active)
			assert.is_false(missionApi.Objectives.obj1.canceled)
		end)

		it("is a no-op on an active objective", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false, onActivated = "began" })
					:WithTrigger("began", { type = T.Event })
			)

			Objectives.ActivateObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.active)
			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("is a no-op on a completed objective", function()
			install(
				mission()
					:WithObjective("obj1", { active = false, completed = true, onActivated = "began" })
					:WithObjectiveTrigger("obj1", { settings = { active = false } })
					:WithTrigger("began", { type = T.Event })
			)

			Objectives.ActivateObjective("obj1")

			assert.is_false(missionApi.Objectives.obj1.active)
			assert.is_false(missionApi.Triggers.__objective_obj1.settings.active)
			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("is denied for a listed objective while none of its stages is current", function()
			install(
				mission()
					:WithStage("s1")
					:WithStage("s2", { objectives = { "obj1" } })
					:WithObjective("obj1", { active = false, completed = false, onActivated = "began" })
					:WithObjectiveTrigger("obj1", { settings = { active = false } })
					:WithTrigger("began", { type = T.Event })
					:WithCurrentStage("s1")
			)

			Objectives.ActivateObjective("obj1")

			assert.is_false(missionApi.Objectives.obj1.active)
			assert.is_false(missionApi.Triggers.__objective_obj1.settings.active)
			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("is allowed for a listed objective while one of its stages is current", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2", { objectives = { "obj1" } })
					:WithObjective("obj1", { active = false, completed = false })
					:WithCurrentStage("s2")
			)

			Objectives.ActivateObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.active)
		end)

		it("is allowed from any stage for an objective listed in no stage", function()
			install(
				mission()
					:WithStage("s1")
					:WithObjective("obj1", { active = false, completed = false })
					:WithCurrentStage("s1")
			)

			Objectives.ActivateObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.active)
		end)
	end)

	describe("CancelObjective", function()
		it("marks the objective canceled and takes it out of play, unfinished", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false })
					:WithObjectiveTrigger("obj1", { settings = { active = true } })
			)

			Objectives.CancelObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.canceled)
			assert.is_false(missionApi.Objectives.obj1.active)
			assert.is_false(missionApi.Triggers.__objective_obj1.settings.active)
			assert.is_false(missionApi.Objectives.obj1.completed)
		end)

		it("activates the trigger the objective names in onCanceled", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false, onCanceled = "gone" })
					:WithTrigger("gone", { type = T.Event })
			)

			Objectives.CancelObjective("obj1")

			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.gone, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("is a no-op on a completed objective", function()
			install(mission():WithObjective("obj1", { active = false, completed = true }))

			Objectives.CancelObjective("obj1")

			assert.is_nil(missionApi.Objectives.obj1.canceled)
		end)

		it("is a no-op on a canceled objective", function()
			install(
				mission()
					:WithObjective("obj1", { active = false, completed = false, canceled = true, onCanceled = "gone" })
					:WithTrigger("gone", { type = T.Event })
			)

			Objectives.CancelObjective("obj1")

			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("leaves the gate unsatisfied until the objective is activated and completed", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1", "obj2" } })
					:WithStage("s2")
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2" })
					:WithObjective("obj2", { active = true, completed = true, nextStage = "s2" })
					:WithCurrentStage("s1")
			)

			Objectives.CancelObjective("obj1")
			assert.are.equal("s1", missionApi.CurrentStageID)

			Objectives.ActivateObjective("obj1")
			assert.is_false(missionApi.Objectives.obj1.canceled)

			Objectives.CompleteObjective("obj1")
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)
	end)

	describe("TryAdvanceStage", function()
		it("does nothing for an objective that is not completed", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2" })
					:WithCurrentStage("s1")
			)

			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)

			assert.are.equal("s1", missionApi.CurrentStageID)
		end)

		it("does nothing for an objective without a nextStage", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithObjective("obj1", { active = true, completed = true })
					:WithCurrentStage("s1")
			)

			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)

			assert.are.equal("s1", missionApi.CurrentStageID)
		end)

		it("does nothing when the current stage does not exist", function()
			install(
				mission()
					:WithStage("s2")
					:WithObjective("obj1", { active = true, completed = true, nextStage = "s2" })
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
					:WithObjective("obj1", { active = true, completed = true, nextStage = "s2" })
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
					:WithObjective("obj1", { active = true, completed = true, nextStage = "s2" })
					:WithObjective("obj2", { active = true, completed = false, nextStage = "s2" })
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
					:WithObjective("obj1", { active = true, completed = true, nextStage = "s2" })
					:WithObjective("obj2", { active = true, completed = false, nextStage = "s3" })
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
		it("counts an event for an inactive objective without evaluating completion", function()
			install(mission():WithObjective("obj1", { active = false, completed = false }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal(1, metadata._count)
			assert.is_nil(missionApi.Objectives.obj1.progress)
			assert.is_false(missionApi.Objectives.obj1.completed)
		end)

		it("ignores an event for another team", function()
			install(mission():WithObjective("obj1", { active = true, completed = false }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 1, "armwar", nil, 1, metadata)

			assert.is_nil(metadata._count)
			assert.is_nil(missionApi.Objectives.obj1.progress)
		end)

		it("ignores an event for another unitDefName", function()
			install(mission():WithObjective("obj1", { active = true, completed = false }))
			local metadata = { parameters = { teamID = 0, unitDefName = "corak" }, stages = {}, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.is_nil(metadata._count)
		end)

		it("ignores an event without the unitName it watches", function()
			install(mission():WithObjective("obj1", { active = true, completed = false }))
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
					:WithObjective("obj1", { active = true, completed = false })
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
					:WithObjective("obj1", { active = true, completed = false })
					:WithCurrentStage("objStage")
			)
			local metadata = { parameters = { teamID = 0 }, stages = { "objStage" }, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal(1, missionApi.Objectives.obj1.progress)
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("evaluates completion in any stage when the objective is listed in none", function()
			install(
				mission()
					:WithStage("s1")
					:WithObjective("obj1", { active = true, completed = false })
					:WithCurrentStage("s1")
			)
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("completes on the first event when there is no amount", function()
			install(mission():WithObjective("obj1", { active = true, completed = false }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = nil }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("completes when the count reaches the amount", function()
			install(mission():WithObjective("obj1", { active = true, completed = false }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 2 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_false(missionApi.Objectives.obj1.completed)

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("completes an amount = 0 objective when the count returns to zero", function()
			install(mission():WithObjective("obj1", { active = true, completed = false }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 0 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_false(missionApi.Objectives.obj1.completed)

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, -1, metadata)
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("freezes the objective's progress once completed", function()
			install(mission():WithObjective("obj1", { active = true, completed = true, progress = 3 }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 3, _count = 3 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, -1, metadata)

			assert.are.equal(3, missionApi.Objectives.obj1.progress)
		end)

		it("advances the stage through the gate on completion", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2" })
					:WithCurrentStage("s1")
			)
			local metadata = { parameters = { teamID = 0 }, stages = { "s1" }, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("activates the trigger named by onCompleted on completion", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false, onCompleted = "done" })
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
					:WithObjective("obj1", { active = true, completed = false, onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
			)
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 2 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)
		it("activates the trigger named by onProgress on progress that does not complete", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false, onProgress = "stepped" })
					:WithTrigger("stepped", { type = T.Event })
			)
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 2 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.stepped, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("does not activate the onProgress trigger while counting inactive", function()
			install(
				mission()
					:WithObjective("obj1", { active = false, completed = false, onProgress = "stepped" })
					:WithTrigger("stepped", { type = T.Event })
			)
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 2 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("activates the onCompleted trigger and not onProgress on the completing event", function()
			install(
				mission()
					:WithObjective(
						"obj1",
						{ active = true, completed = false, onProgress = "stepped", onCompleted = "done" }
					)
					:WithTrigger("stepped", { type = T.Event })
					:WithTrigger("done", { type = T.Event })
			)
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.done, missionApi.calls.activateTrigger[1].trigger)
		end)
	end)

	describe("FailObjective", function()
		it("completes the objective and marks it failed", function()
			install(mission():WithObjective("obj1", { active = true, completed = false }))

			Objectives.FailObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.completed)
			assert.is_true(missionApi.Objectives.obj1.failed)
		end)

		it("fails a canceled objective and clears the mark", function()
			install(mission():WithObjective("obj1", { active = false, completed = false, canceled = true }))

			Objectives.FailObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.failed)
			assert.is_false(missionApi.Objectives.obj1.canceled)
		end)

		it("is a no-op on a completed objective", function()
			install(mission():WithObjective("obj1", { active = true, completed = true }))

			Objectives.FailObjective("obj1")

			assert.is_nil(missionApi.Objectives.obj1.failed)
		end)

		it("does not mark a success as failed", function()
			install(mission():WithObjective("obj1", { active = true, completed = false }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.is_true(missionApi.Objectives.obj1.completed)
			assert.is_nil(missionApi.Objectives.obj1.failed)
		end)

		it("activates the trigger the objective names in onFailed", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false, onFailed = "failed" })
					:WithTrigger("failed", { type = T.Event })
			)

			Objectives.FailObjective("obj1")

			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.failed, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("leaves the trigger named in onCompleted alone", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false, onCompleted = "done" })
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
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2", onFailed = "failed" })
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
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2" })
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
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2", onFailed = "failed" })
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

	describe("CompleteObjective", function()
		it("completes the objective", function()
			install(mission():WithObjective("obj1", { active = true, completed = false }))

			Objectives.CompleteObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.completed)
			assert.is_nil(missionApi.Objectives.obj1.failed)
		end)

		it("completes a canceled objective and clears the mark", function()
			install(mission():WithObjective("obj1", { active = false, completed = false, canceled = true }))

			Objectives.CompleteObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.completed)
			assert.is_false(missionApi.Objectives.obj1.canceled)
		end)

		it("is a no-op on a completed objective", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = true, onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
			)

			Objectives.CompleteObjective("obj1")

			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("activates the trigger the objective names in onCompleted", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false, onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
					:WithTrigger("other", { type = T.Event })
			)

			Objectives.CompleteObjective("obj1")

			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.done, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("activates nothing when the objective names no trigger", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false })
					:WithTrigger("done", { type = T.Event })
			)

			Objectives.CompleteObjective("obj1")

			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("activates the trigger while the objective's stage is still current", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2", onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
					:WithCurrentStage("s1")
			)

			Objectives.CompleteObjective("obj1")

			assert.are.equal("s1", missionApi.calls.activateTrigger[1].stageID)
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("advances the stage through the gate when the trigger does not change it", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2", onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
					:WithCurrentStage("s1")
			)

			Objectives.CompleteObjective("obj1")

			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("lets a stage change from the trigger stand instead of running the gate", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithStage("s9")
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2", onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
					:WithCurrentStage("s1")
			)
			-- The trigger's actions, as the gadget would run them:
			missionApi.ActivateTrigger = function()
				Objectives.ChangeStage("s9")
			end

			Objectives.CompleteObjective("obj1")

			assert.are.equal("s9", missionApi.CurrentStageID)
		end)

		it("counts a change back into the same stage as a change", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2", onCompleted = "done" })
					:WithTrigger("done", { type = T.Event })
					:WithCurrentStage("s1")
			)
			missionApi.ActivateTrigger = function()
				Objectives.ChangeStage("s1")
			end

			Objectives.CompleteObjective("obj1")

			assert.are.equal("s1", missionApi.CurrentStageID)
		end)

		it("counts a stage change from a nested completion as a change", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1", "obj2" } })
					:WithStage("s2")
					:WithStage("s3")
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2", onCompleted = "done" })
					:WithObjective("obj2", { active = true, completed = false, nextStage = "s3" })
					:WithTrigger("done", { type = T.Event })
					:WithCurrentStage("s1")
			)
			-- obj1's trigger completes obj2, whose own gate moves the stage:
			missionApi.ActivateTrigger = function()
				Objectives.CompleteObjective("obj2")
			end

			Objectives.CompleteObjective("obj1")

			assert.are.equal("s3", missionApi.CurrentStageID)
		end)
	end)
	describe("UpdateObjective", function()
		it("adds one to the progress and activates the trigger named by onProgress", function()
			install(
				mission()
					:WithObjective(
						"obj1",
						{ active = true, completed = false, progress = 2, amount = 5, onProgress = "stepped" }
					)
					:WithTrigger("stepped", { type = T.Event })
			)

			Objectives.UpdateObjective("obj1")

			assert.are.equal(3, missionApi.Objectives.obj1.progress)
			assert.is_false(missionApi.Objectives.obj1.completed)
			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.stepped, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("completes the objective when the progress reaches the amount, without onProgress", function()
			local objective = { active = true, completed = false, progress = 4, amount = 5 }
			objective.onProgress = "stepped"
			objective.onCompleted = "done"
			install(
				mission()
					:WithObjective("obj1", objective)
					:WithTrigger("stepped", { type = T.Event })
					:WithTrigger("done", { type = T.Event })
			)

			Objectives.UpdateObjective("obj1")

			assert.are.equal(5, missionApi.Objectives.obj1.progress)
			assert.is_true(missionApi.Objectives.obj1.completed)
			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.done, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("completes the objective on the first update when there is no amount", function()
			install(mission():WithObjective("obj1", { active = true, completed = false }))

			Objectives.UpdateObjective("obj1")

			assert.are.equal(1, missionApi.Objectives.obj1.progress)
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("is a no-op on a completed objective", function()
			install(mission():WithObjective("obj1", { active = true, completed = true, progress = 0 }))

			Objectives.UpdateObjective("obj1")

			assert.are.equal(0, missionApi.Objectives.obj1.progress)
		end)

		it("is a no-op on an inactive objective", function()
			install(mission():WithObjective("obj1", { active = false, completed = false, progress = 0, amount = 2 }))

			Objectives.UpdateObjective("obj1")

			assert.are.equal(0, missionApi.Objectives.obj1.progress)
		end)
	end)

	describe("HideObjective and ShowObjective", function()
		it("flip hidden and nothing else", function()
			install(mission():WithObjective("obj1", { active = false, completed = false }))

			Objectives.HideObjective("obj1")
			assert.is_true(missionApi.Objectives.obj1.hidden)
			assert.is_false(missionApi.Objectives.obj1.active)

			Objectives.ShowObjective("obj1")
			assert.is_false(missionApi.Objectives.obj1.hidden)
			assert.is_false(missionApi.Objectives.obj1.active)
		end)
	end)
end)
