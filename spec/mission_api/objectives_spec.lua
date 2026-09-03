require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local Objectives = VFS.Include("luarules/mission_api/objectives.lua")

-- Stand-in trigger type IDs, as triggers_loader would assign them.
local TRIGGER_TYPES = { ObjectiveCompleted = 101, TimeElapsed = 102 }

describe("mission_api.objectives", function()
	local missionApi

	local function install(builder)
		missionApi = builder:WithTriggerDefinitions({ Types = TRIGGER_TYPES }):Install()
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

	local function observer(objectiveID)
		return { type = TRIGGER_TYPES.ObjectiveCompleted, parameters = { objectiveID = objectiveID } }
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
	end)

	describe("TryAdvanceStage", function()
		it("does nothing for an objective that is not completed", function()
			install(stagedBuilder("s1", { obj1 = { completed = false, nextStage = "s2" } }))
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
				obj2 = { completed = false, nextStage = "s2" },
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
				obj2 = { completed = false, nextStage = "s3" },
			}))
			Objectives.TryAdvanceStage(missionApi.Objectives.obj1)
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)
	end)

	describe("UpdateObjectiveProgress", function()
		local function managed(parameters, stages, amount)
			return { parameters = parameters, stages = stages or {}, amount = amount }
		end

		it("ignores events for another team", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false }))
			local metadata = managed({ teamID = 0 }, {}, 1)
			Objectives.UpdateObjectiveProgress("obj1", 1, "armwar", nil, 1, metadata)
			assert.is_nil(metadata._count)
			assert.is_nil(missionApi.Objectives.obj1.progress)
		end)

		it("ignores events for another unitDefName", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false }))
			local metadata = managed({ teamID = 0, unitDefName = "corak" }, {}, 1)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_nil(metadata._count)
		end)

		it("ignores events without a matching unitName", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false }))
			local metadata = managed({ teamID = 0, unitName = "bots" }, {}, 1)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", {}, 1, metadata)
			assert.is_nil(metadata._count)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", { bots = true }, 1, metadata)
			assert.are.equal(1, metadata._count)
		end)

		it("counts events outside the objective's stages without evaluating completion", function()
			install(
				Builders.MissionApi.new():WithObjective("obj1", { completed = false }):WithCurrentStage("otherStage")
			)
			local metadata = managed({ teamID = 0 }, { "objStage" }, 1)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.are.equal(1, metadata._count)
			assert.is_nil(missionApi.Objectives.obj1.progress)
			assert.is_false(missionApi.Objectives.obj1.completed)
		end)

		it("evaluates completion in the objective's own stage", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false }):WithCurrentStage("objStage"))
			local metadata = managed({ teamID = 0 }, { "objStage" }, 1)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.are.equal(1, missionApi.Objectives.obj1.progress)
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("evaluates completion in any stage when the objective has no stages", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false }):WithCurrentStage("anywhere"))
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, managed({ teamID = 0 }, {}, 1))
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("completes on the first event when amount is nil", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false }))
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, managed({ teamID = 0 }, {}, nil))
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("completes when the count reaches the amount", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false }))
			local metadata = managed({ teamID = 0 }, {}, 2)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_false(missionApi.Objectives.obj1.completed)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_true(missionApi.Objectives.obj1.completed)
		end)

		it("completes an amount = 0 objective when the count returns to zero", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false }))
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
			install(stagedBuilder("s1", { obj1 = { completed = false, nextStage = "s2" } }))
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, managed({ teamID = 0 }, {}, 1))
			assert.are.equal("s2", missionApi.CurrentStageID)
		end)

		it("activates the ObjectiveCompleted triggers naming the objective on completion", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false })
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
					:WithObjective("obj1", { completed = false })
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
					:WithObjective("obj2", { completed = false })
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
end)
