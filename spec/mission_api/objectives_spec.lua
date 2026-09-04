require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")
local RegisterMissionApiModules = require("mission_api.spec_helper")

-- The real trigger definitions, so the observer index sees the real schema.
-- (Trigger files read GG['MissionAPI'].Modules at include time.)
Builders.MissionApi.new():Install()
RegisterMissionApiModules()
local triggerDefinitions = VFS.Include("luarules/mission_api/triggers_loader.lua").LoadTriggerDefinitions()
local T = triggerDefinitions.Types

local Objectives = VFS.Include("luarules/mission_api/objectives.lua")
local ObjectivesLoader = VFS.Include("luarules/mission_api/objectives_loader.lua")

describe("mission_api.objectives", function()
	local missionApi

	-- A mission to build up with the mock's With* methods.
	local function mission()
		return Builders.MissionApi.new():WithTriggerDefinitions(triggerDefinitions)
	end

	-- Installs the mission and indexes its triggers, as loadMission does.
	local function install(builder)
		missionApi = builder:Install()
		missionApi.ObjectiveObservers = ObjectivesLoader.ProcessObjectiveObservers(missionApi.Triggers)
	end

	-- A trigger of one of the objective types, watching one objective.
	local function observer(triggerType, objectiveID)
		return { type = triggerType, parameters = { objectiveID = objectiveID } }
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

		it("deactivates the objectives the left stage lists, triggers included, and no other", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "leaving", "staying" } })
					:WithStage("s2", { objectives = { "staying" } })
					:WithObjective("leaving", { active = true, completed = false })
					:WithObjective("staying", { active = true, completed = false })
					:WithObjective("free", { active = true, completed = false })
					:WithObjectiveTrigger("leaving", { settings = { active = true } })
					:WithCurrentStage("s1")
			)

			Objectives.ChangeStage("s2")

			assert.is_false(missionApi.Objectives.leaving.active)
			assert.is_false(missionApi.Triggers.__objective_leaving.settings.active)
			assert.is_true(missionApi.Objectives.staying.active)
			assert.is_true(missionApi.Objectives.free.active)
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

		it("is a no-op on a completed objective", function()
			install(
				mission()
					:WithObjective("obj1", { active = false, completed = true })
					:WithObjectiveTrigger("obj1", { settings = { active = false } })
			)

			Objectives.ActivateObjective("obj1")

			assert.is_false(missionApi.Objectives.obj1.active)
			assert.is_false(missionApi.Triggers.__objective_obj1.settings.active)
		end)

		it("is denied for a listed objective while none of its stages is current", function()
			install(
				mission()
					:WithStage("s1")
					:WithStage("s2", { objectives = { "obj1" } })
					:WithObjective("obj1", { active = false, completed = false })
					:WithObjectiveTrigger("obj1", { settings = { active = false } })
					:WithCurrentStage("s1")
			)

			Objectives.ActivateObjective("obj1")

			assert.is_false(missionApi.Objectives.obj1.active)
			assert.is_false(missionApi.Triggers.__objective_obj1.settings.active)
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

	describe("DeactivateObjective", function()
		it("flips the objective off and disables its synthesized trigger", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false })
					:WithObjectiveTrigger("obj1", { settings = { active = true } })
			)

			Objectives.DeactivateObjective("obj1")

			assert.is_false(missionApi.Objectives.obj1.active)
			assert.is_false(missionApi.Triggers.__objective_obj1.settings.active)
		end)

		it("takes an objective listed in no stage back out of play", function()
			install(
				mission()
					:WithStage("s1")
					:WithObjective("obj1", { active = false, completed = false })
					:WithCurrentStage("s1")
			)

			Objectives.ActivateObjective("obj1")
			Objectives.DeactivateObjective("obj1")

			assert.is_false(missionApi.Objectives.obj1.active)
		end)

		it("is allowed for a listed objective while its stage is current", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithObjective("obj1", { active = true, completed = false })
					:WithCurrentStage("s1")
			)

			Objectives.DeactivateObjective("obj1")

			assert.is_false(missionApi.Objectives.obj1.active)
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

		it("activates the ObjectiveCompleted triggers watching the objective on completion", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false })
					:WithTrigger("watch", observer(T.ObjectiveCompleted, "obj1"))
			)
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 1 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.watch, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("does not activate ObjectiveCompleted triggers before completion", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false })
					:WithTrigger("watch", observer(T.ObjectiveCompleted, "obj1"))
			)
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 2 }

			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)

			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)
	end)

	describe("CompleteObjective", function()
		it("completes the objective", function()
			install(mission():WithObjective("obj1", { active = true, completed = false }))

			Objectives.CompleteObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.completed)
			assert.is_nil(missionApi.Objectives.obj1.failed)
		end)

		it("is a no-op on a completed objective", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = true })
					:WithTrigger("watch", observer(T.ObjectiveCompleted, "obj1"))
			)

			Objectives.CompleteObjective("obj1")

			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("activates every ObjectiveCompleted trigger watching the objective", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false })
					:WithTrigger("watchA", observer(T.ObjectiveCompleted, "obj1"))
					:WithTrigger("watchB", observer(T.ObjectiveCompleted, "obj1"))
			)

			Objectives.CompleteObjective("obj1")

			assert.are.equal(2, #missionApi.calls.activateTrigger)
		end)

		it("leaves triggers watching another objective alone", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false })
					:WithObjective("obj2", { active = true, completed = false })
					:WithTrigger("watch", observer(T.ObjectiveCompleted, "obj2"))
			)

			Objectives.CompleteObjective("obj1")

			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("leaves triggers of another type alone", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false })
					:WithTrigger("timer", { type = T.TimeElapsed, parameters = { objectiveID = "obj1" } })
			)

			Objectives.CompleteObjective("obj1")

			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("activates the triggers while the objective's stage is still current", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2" })
					:WithTrigger("watch", observer(T.ObjectiveCompleted, "obj1"))
					:WithCurrentStage("s1")
			)

			Objectives.CompleteObjective("obj1")

			assert.are.equal("s1", missionApi.calls.activateTrigger[1].stageID)
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("advances the stage through the gate when no trigger changes it", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2" })
					:WithTrigger("watch", observer(T.ObjectiveCompleted, "obj1"))
					:WithCurrentStage("s1")
			)

			Objectives.CompleteObjective("obj1")

			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("lets a stage change from a trigger stand instead of running the gate", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithStage("s9")
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2" })
					:WithTrigger("watch", observer(T.ObjectiveCompleted, "obj1"))
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
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2" })
					:WithTrigger("watch", observer(T.ObjectiveCompleted, "obj1"))
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
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2" })
					:WithObjective("obj2", { active = true, completed = false, nextStage = "s3" })
					:WithTrigger("watch", observer(T.ObjectiveCompleted, "obj1"))
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

	describe("FailObjective", function()
		it("completes the objective and marks it failed", function()
			install(mission():WithObjective("obj1", { active = true, completed = false }))

			Objectives.FailObjective("obj1")

			assert.is_true(missionApi.Objectives.obj1.completed)
			assert.is_true(missionApi.Objectives.obj1.failed)
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

		it("activates the ObjectiveFailed triggers watching the objective", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false })
					:WithTrigger("watch", observer(T.ObjectiveFailed, "obj1"))
			)

			Objectives.FailObjective("obj1")

			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.watch, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("leaves ObjectiveCompleted triggers alone", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false })
					:WithTrigger("watch", observer(T.ObjectiveCompleted, "obj1"))
			)

			Objectives.FailObjective("obj1")

			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("activates the triggers while the objective's stage is still current", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2" })
					:WithTrigger("watch", observer(T.ObjectiveFailed, "obj1"))
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

		it("lets a stage change from a trigger stand instead of running the gate", function()
			install(
				mission()
					:WithStage("s1", { objectives = { "obj1" } })
					:WithStage("s2")
					:WithStage("s9")
					:WithObjective("obj1", { active = true, completed = false, nextStage = "s2" })
					:WithTrigger("watch", observer(T.ObjectiveFailed, "obj1"))
					:WithCurrentStage("s1")
			)
			missionApi.ActivateTrigger = function()
				Objectives.ChangeStage("s9")
			end

			Objectives.FailObjective("obj1")

			assert.are.equal("s9", missionApi.CurrentStageID)
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

		it("is a no-op on a completed objective", function()
			install(mission():WithObjective("obj1", { active = false, completed = true }))

			Objectives.CancelObjective("obj1")

			assert.is_nil(missionApi.Objectives.obj1.canceled)
		end)

		it("activates the ObjectiveCanceled triggers watching the objective and no other", function()
			install(
				mission()
					:WithObjective("obj1", { active = true, completed = false })
					:WithTrigger("watch", observer(T.ObjectiveCanceled, "obj1"))
					:WithTrigger("other", observer(T.ObjectiveCompleted, "obj1"))
			)

			Objectives.CancelObjective("obj1")

			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.watch, missionApi.calls.activateTrigger[1].trigger)
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
