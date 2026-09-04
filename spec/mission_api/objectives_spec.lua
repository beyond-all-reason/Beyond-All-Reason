require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")
local RegisterMissionApiModules = require("mission_api.spec_helper")

-- The real trigger definitions, so the observer index sees the real schema.
-- (Trigger files read GG['MissionAPI'].Modules at include time.)
Builders.MissionApi.new():Install()
RegisterMissionApiModules()
local triggerDefinitions = VFS.Include("luarules/mission_api/triggers_loader.lua").LoadTriggerDefinitions()
local TRIGGER_TYPES = triggerDefinitions.Types

local Objectives = VFS.Include("luarules/mission_api/objectives.lua")
local ObjectivesLoader = VFS.Include("luarules/mission_api/objectives_loader.lua")

describe("mission_api.objectives", function()
	local missionApi

	-- Installs the mock and indexes its triggers the way loadMission does.
	local function install(builder)
		missionApi = builder:WithTriggerDefinitions(triggerDefinitions):Install()
		missionApi.ObjectiveObservers = ObjectivesLoader.ProcessObjectiveObservers(missionApi.Triggers)
	end

	-- One stage listing the given objectives, entered as the current stage.
	local function stagedBuilder(stageID, objectives)
		local builder = Builders.MissionApi.new():WithCurrentStage(stageID)
		local objectiveIDs = {}
		for objectiveID, objective in pairs(objectives) do
			builder:WithObjective(objectiveID, objective)
			objectiveIDs[#objectiveIDs + 1] = objectiveID
		end
		return builder:WithStage(stageID, { objectives = objectiveIDs })
	end

	local function observer(objectiveID, triggerType)
		return {
			type = triggerType or TRIGGER_TYPES.ObjectiveCompleted,
			parameters = { objectiveID = objectiveID },
		}
	end

	local function completedObjective(nextStage)
		return { completed = true, nextStage = nextStage }
	end

	before_each(function()
		install(Builders.MissionApi.new())
	end)

	describe("ChangeStage", function()
		it("sets the current stage ID", function()
			Objectives.ChangeStage("stage2")
			assert.are.equal("stage2", missionApi.CurrentStageID)
		end)

		it("activates the objectives the new stage lists", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("listed", { completed = false, active = false })
					:WithObjective("unlisted", { completed = false, active = false })
					:WithStage("s2", { objectives = { "listed" } })
			)
			Objectives.ChangeStage("s2")
			assert.is_true(missionApi.Objectives.listed.active)
			assert.is_false(missionApi.Objectives.unlisted.active)
		end)
	end)

	describe("ActivateObjective", function()
		it("flips the objective on", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, active = false }))
			Objectives.ActivateObjective("obj1")
			assert.is_true(missionApi.Objectives.obj1.active)
		end)

		it("enables the objective's synthesized trigger", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false, active = false })
					:WithTrigger("__objective_obj1", { settings = { active = false } })
			)
			missionApi.ObjectiveTriggers.obj1 = "__objective_obj1"
			Objectives.ActivateObjective("obj1")
			assert.is_true(missionApi.Triggers.__objective_obj1.settings.active)
		end)

		it("is a no-op on a completed objective", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = true, active = false })
					:WithTrigger("__objective_obj1", { settings = { active = false } })
			)
			missionApi.ObjectiveTriggers.obj1 = "__objective_obj1"
			Objectives.ActivateObjective("obj1")
			assert.is_false(missionApi.Objectives.obj1.active)
			assert.is_false(missionApi.Triggers.__objective_obj1.settings.active)
		end)
	end)

	describe("ActivateStage", function()
		it("activates every objective the stage lists and no other", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("a", { completed = false, active = false })
					:WithObjective("b", { completed = false, active = false })
					:WithObjective("c", { completed = false, active = false })
					:WithStage("s1", { objectives = { "a", "b" } })
			)
			Objectives.ActivateStage("s1")
			assert.is_true(missionApi.Objectives.a.active)
			assert.is_true(missionApi.Objectives.b.active)
			assert.is_false(missionApi.Objectives.c.active)
		end)

		it("does nothing for an unknown stage", function()
			install(Builders.MissionApi.new():WithObjective("a", { completed = false, active = false }))
			Objectives.ActivateStage("nowhere")
			assert.is_false(missionApi.Objectives.a.active)
		end)
	end)

	describe("TryAdvanceStage", function()
		it("does nothing for an objective that is not completed", function()
			install(stagedBuilder("s1", { obj1 = { completed = false, active = true, nextStage = "s2" } }))
			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)
			assert.are.equal("s1", missionApi.CurrentStageID)
		end)

		it("does nothing for an objective without a nextStage", function()
			install(stagedBuilder("s1", { obj1 = completedObjective(nil) }))
			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)
			assert.are.equal("s1", missionApi.CurrentStageID)
		end)

		it("does nothing when the current stage is unknown", function()
			install(
				Builders.MissionApi.new():WithObjective("obj1", completedObjective("s2")):WithCurrentStage("nowhere")
			)
			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)
			assert.are.equal("nowhere", missionApi.CurrentStageID)
		end)

		it("advances when the objective is the only one in the stage with its nextStage", function()
			install(stagedBuilder("s1", { obj1 = completedObjective("s2") }))
			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("waits for every objective in the stage sharing the nextStage", function()
			install(stagedBuilder("s1", {
				obj1 = completedObjective("s2"),
				obj2 = { completed = false, active = true, nextStage = "s2" },
			}))
			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)
			assert.are.equal("s1", missionApi.CurrentStageID)

			missionApi.Objectives.obj2.completed = true
			Objectives.TryAdvanceStage(missionApi.Objectives.obj2)
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("ignores objectives in the stage with a different nextStage", function()
			install(stagedBuilder("s1", {
				obj1 = completedObjective("s2"),
				obj2 = { completed = false, active = true, nextStage = "s3" },
			}))
			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)
	end)

	describe("UpdateObjectiveProgress", function()
		local function managed(parameters, stages, amount)
			return { parameters = parameters, stages = stages or {}, amount = amount }
		end

		it("counts events for an inactive objective without evaluating completion", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, active = false }))
			local metadata = managed({ teamID = 0 }, {}, 1)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.are.equal(1, metadata._count)
			assert.is_nil(missionApi.Objectives.obj1.progress)
			assert.is_false(missionApi.Objectives.obj1.completed)
		end)

		it("ignores events for another team", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, active = true }))
			local metadata = managed({ teamID = 0 }, {}, 1)
			Objectives.UpdateObjectiveProgress("obj1", 1, "armwar", nil, 1, metadata)
			assert.is_nil(metadata._count)
			assert.is_nil(missionApi.Objectives.obj1.progress)
		end)

		it("ignores events for another unitDefName", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, active = true }))
			local metadata = managed({ teamID = 0, unitDefName = "corak" }, {}, 1)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_nil(metadata._count)
		end)

		it("ignores events without a matching unitName", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, active = true }))
			local metadata = managed({ teamID = 0, unitName = "bots" }, {}, 1)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", {}, 1, metadata)
			assert.is_nil(metadata._count)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", { bots = true }, 1, metadata)
			assert.are.equal(1, metadata._count)
		end)

		it("counts events outside the objective's stages without evaluating completion", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false, active = true })
					:WithCurrentStage("otherStage")
			)
			local metadata = managed({ teamID = 0 }, { "objStage" }, 1)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.are.equal(1, metadata._count)
			assert.is_nil(missionApi.Objectives.obj1.progress)
			assert.is_false(missionApi.Objectives.obj1.completed)
		end)

		it("evaluates completion in the objective's own stage", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false, active = true })
					:WithCurrentStage("objStage")
			)
			local metadata = managed({ teamID = 0 }, { "objStage" }, 1)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.are.equal(1, missionApi.Objectives.obj1.progress)
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("evaluates completion in any stage when the objective has no stages", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false, active = true })
					:WithCurrentStage("anywhere")
			)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, managed({ teamID = 0 }, {}, 1))
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("completes on the first event when amount is nil", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, active = true }))
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, managed({ teamID = 0 }, {}, nil))
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("completes when the count reaches the amount", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, active = true }))
			local metadata = managed({ teamID = 0 }, {}, 2)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_false(missionApi.Objectives.obj1.completed)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("completes an amount = 0 objective when the count returns to zero", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, active = true }))
			local metadata = managed({ teamID = 0 }, {}, 0)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_false(missionApi.Objectives.obj1.completed)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, -1, metadata)
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("freezes the objective's progress once completed", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = true, progress = 3 }))
			local metadata = managed({ teamID = 0 }, {}, 3)
			metadata._count = 3
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, -1, metadata)
			assert.are.equal(3, missionApi.Objectives.obj1.progress)
		end)

		it("advances the stage through the gate on completion", function()
			install(stagedBuilder("s1", { obj1 = { completed = false, active = true, nextStage = "s2" } }))
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, managed({ teamID = 0 }, {}, 1))
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("activates the ObjectiveCompleted triggers naming the objective on completion", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false, active = true })
					:WithTrigger("watch", observer("obj1"))
			)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, managed({ teamID = 0 }, {}, 1))
			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.watch, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("does not activate ObjectiveCompleted triggers before completion", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false, active = true })
					:WithTrigger("watch", observer("obj1"))
			)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, managed({ teamID = 0 }, {}, 2))
			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)
	end)

	describe("OnObjectiveCompleted", function()
		it("activates every ObjectiveCompleted trigger naming the objective", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", completedObjective(nil))
					:WithTrigger("watchA", observer("obj1"))
					:WithTrigger("watchB", observer("obj1"))
			)
			Objectives.OnObjectiveCompleted("obj1", missionApi.Objectives.obj1)
			assert.are.equal(2, #missionApi.calls.activateTrigger)
		end)

		it("leaves triggers naming another objective alone", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", completedObjective(nil))
					:WithObjective("obj2", { completed = false, active = true })
					:WithTrigger("watch", observer("obj2"))
			)
			Objectives.OnObjectiveCompleted("obj1", missionApi.Objectives.obj1)
			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("leaves triggers of another type alone", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", completedObjective(nil))
					:WithTrigger("timer", { type = TRIGGER_TYPES.TimeElapsed, parameters = { objectiveID = "obj1" } })
			)
			Objectives.OnObjectiveCompleted("obj1", missionApi.Objectives.obj1)
			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("activates the triggers while the objective's stage is still current", function()
			install(stagedBuilder("s1", { obj1 = completedObjective("s2") }):WithTrigger("watch", observer("obj1")))
			Objectives.OnObjectiveCompleted("obj1", missionApi.Objectives.obj1)
			assert.are.equal("s1", missionApi.calls.activateTrigger[1].stageID)
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("advances the stage through the gate when no trigger changes it", function()
			install(stagedBuilder("s1", { obj1 = completedObjective("s2") }):WithTrigger("watch", observer("obj1")))
			Objectives.OnObjectiveCompleted("obj1", missionApi.Objectives.obj1)
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("lets a stage change from a trigger stand instead of running the gate", function()
			install(
				stagedBuilder("s1", { obj1 = completedObjective("s2") })
					:WithStage("s9", { objectives = {} })
					:WithTrigger("watch", observer("obj1"))
			)
			missionApi.ActivateTrigger = function()
				Objectives.ChangeStage("s9")
			end
			Objectives.OnObjectiveCompleted("obj1", missionApi.Objectives.obj1)
			assert.are.equal("s9", missionApi.CurrentStageID)
		end)

		it("counts a change back into the same stage as a change", function()
			install(stagedBuilder("s1", { obj1 = completedObjective("s2") }):WithTrigger("watch", observer("obj1")))
			missionApi.ActivateTrigger = function()
				Objectives.ChangeStage("s1")
			end
			Objectives.OnObjectiveCompleted("obj1", missionApi.Objectives.obj1)
			assert.are.equal("s1", missionApi.CurrentStageID)
		end)

		it("counts a stage change from a nested completion as a change", function()
			install(
				stagedBuilder("s1", { obj1 = completedObjective("s2"), obj2 = completedObjective("s3") })
					:WithStage("s3", { objectives = {} })
					:WithTrigger("watch", observer("obj1"))
			)
			missionApi.ActivateTrigger = function()
				Objectives.OnObjectiveCompleted("obj2", missionApi.Objectives.obj2)
			end
			Objectives.OnObjectiveCompleted("obj1", missionApi.Objectives.obj1)
			assert.are.equal("s3", missionApi.CurrentStageID)
		end)
	end)

	describe("FailObjective", function()
		it("completes the objective and marks it failed", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, active = true }))
			Objectives.FailObjective("obj1")
			assert.is_true(missionApi.Objectives.obj1.completed)
			assert.is_true(missionApi.Objectives.obj1.failed)
		end)

		it("is a no-op on a completed objective", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = true }))
			Objectives.FailObjective("obj1")
			assert.is_nil(missionApi.Objectives.obj1.failed)
		end)

		it("does not mark a success as failed", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, active = true }))
			local metadata = { parameters = { teamID = 0 }, stages = {}, amount = 1 }
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_true(missionApi.Objectives.obj1.completed)
			assert.is_nil(missionApi.Objectives.obj1.failed)
		end)

		it("activates the ObjectiveFailed triggers naming the objective", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false, active = true })
					:WithTrigger("watch", observer("obj1", TRIGGER_TYPES.ObjectiveFailed))
			)
			Objectives.FailObjective("obj1")
			assert.are.equal(1, #missionApi.calls.activateTrigger)
			assert.are.equal(missionApi.Triggers.watch, missionApi.calls.activateTrigger[1].trigger)
		end)

		it("leaves ObjectiveCompleted triggers alone", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false, active = true })
					:WithTrigger("watch", observer("obj1", TRIGGER_TYPES.ObjectiveCompleted))
			)
			Objectives.FailObjective("obj1")
			assert.are.equal(0, #missionApi.calls.activateTrigger)
		end)

		it("activates the triggers while the objective's stage is still current", function()
			install(
				stagedBuilder("s1", { obj1 = { completed = false, active = true, nextStage = "s2" } }):WithTrigger(
					"watch",
					observer("obj1", TRIGGER_TYPES.ObjectiveFailed)
				)
			)
			Objectives.FailObjective("obj1")
			assert.are.equal("s1", missionApi.calls.activateTrigger[1].stageID)
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("advances the stage through the gate, so a failure cannot softlock it", function()
			install(stagedBuilder("s1", { obj1 = { completed = false, active = true, nextStage = "s2" } }))
			Objectives.FailObjective("obj1")
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("lets a stage change from a trigger stand instead of running the gate", function()
			install(
				stagedBuilder("s1", { obj1 = { completed = false, active = true, nextStage = "s2" } })
					:WithStage("s9", { objectives = {} })
					:WithTrigger("watch", observer("obj1", TRIGGER_TYPES.ObjectiveFailed))
			)
			missionApi.ActivateTrigger = function()
				Objectives.ChangeStage("s9")
			end
			Objectives.FailObjective("obj1")
			assert.are.equal("s9", missionApi.CurrentStageID)
		end)
	end)
end)
