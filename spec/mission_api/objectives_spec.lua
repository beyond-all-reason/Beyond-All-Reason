require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local Objectives = VFS.Include("luarules/mission_api/objectives.lua")

-- Stand-in trigger type IDs, as triggers_loader would assign them.
local TRIGGER_TYPES = { ObjectiveCompleted = 101, ObjectiveFailed = 102 }

local activatedTriggers = {}

-- Mirrors processTriggersOfType in api_missions_triggers.lua.
local function processTriggersOfType(triggerType, func)
	for triggerID, trigger in pairs(GG["MissionAPI"].Triggers) do
		if trigger.type == triggerType then
			func(trigger, triggerID)
		end
	end
end

local function activateTrigger(trigger)
	activatedTriggers[#activatedTriggers + 1] = trigger
end

Objectives.Init({ processTriggersOfType = processTriggersOfType, activateTrigger = activateTrigger })

describe("mission_api.objectives", function()
	local missionApi

	local function install(builder)
		missionApi = builder:WithTriggerDefinitions({ Types = TRIGGER_TYPES }):Install()
	end

	before_each(function()
		for i = #activatedTriggers, 1, -1 do
			activatedTriggers[i] = nil
		end
		install(Builders.MissionApi.new())
	end)

	describe("ChangeStage", function()
		it("sets the current stage ID", function()
			Objectives.ChangeStage("stage2")
			assert.are.equal("stage2", missionApi.CurrentStageID)
		end)
	end)

	describe("SetObjectiveCompleted", function()
		it("sets completed", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false }))
			Objectives.SetObjectiveCompleted("obj1", true)
			assert.is_true(missionApi.Objectives["obj1"].completed)
		end)

		it("is a no-op on a completed objective", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = true }))
			Objectives.SetObjectiveCompleted("obj1", false)
			assert.is_true(missionApi.Objectives["obj1"].completed)
		end)
	end)

	describe("IncrementObjectiveProgress", function()
		it("adds one occurrence to the count", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, amount = 5 }))
			Objectives.IncrementObjectiveProgress("obj1")
			assert.are.equal(1, missionApi.Objectives["obj1"].progress)
		end)

		it("does not complete below the amount", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, progress = 1, amount = 5 }))
			Objectives.IncrementObjectiveProgress("obj1")
			assert.is_false(missionApi.Objectives["obj1"].completed)
		end)

		it("completes when the count reaches the amount", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, progress = 4, amount = 5 }))
			Objectives.IncrementObjectiveProgress("obj1")
			assert.is_true(missionApi.Objectives["obj1"].completed)
		end)

		it("completes on the first occurrence when amount is nil", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false }))
			Objectives.IncrementObjectiveProgress("obj1")
			assert.is_true(missionApi.Objectives["obj1"].completed)
		end)

		it("freezes the count once completed", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = true, progress = 5, amount = 5 }))
			Objectives.IncrementObjectiveProgress("obj1")
			assert.are.equal(5, missionApi.Objectives["obj1"].progress)
		end)
	end)

	describe("UpdateObjectiveProgress", function()
		it("ignores events for another team", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, amount = 1 }))
			local metadata = { parameters = { teamID = 0 }, stages = {} }
			Objectives.UpdateObjectiveProgress("obj1", 1, "armwar", nil, 1, metadata)
			assert.is_nil(missionApi.Objectives["obj1"].progress)
		end)

		it("ignores events for another unitDefName", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, amount = 1 }))
			local metadata = { parameters = { teamID = 0, unitDefName = "corak" }, stages = {} }
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_nil(missionApi.Objectives["obj1"].progress)
		end)

		it("ignores events without a matching unitName", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, amount = 1 }))
			local metadata = { parameters = { teamID = 0, unitName = "bots" }, stages = {} }
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", {}, 1, metadata)
			assert.is_nil(missionApi.Objectives["obj1"].progress)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", { bots = true }, 1, metadata)
			assert.are.equal(1, missionApi.Objectives["obj1"].progress)
		end)

		it("accrues the count out of stage without evaluating completion", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false, amount = 1 })
					:WithCurrentStage("otherStage")
			)
			local metadata = { parameters = { teamID = 0 }, stages = { "objStage" } }
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.are.equal(1, missionApi.Objectives["obj1"].progress)
			assert.is_false(missionApi.Objectives["obj1"].completed)
		end)

		it("evaluates completion in the objective's own stage", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false, amount = 1 })
					:WithCurrentStage("objStage")
			)
			local metadata = { parameters = { teamID = 0 }, stages = { "objStage" } }
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_true(missionApi.Objectives["obj1"].completed)
		end)

		it("evaluates completion in any stage when the objective has no stages", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false, amount = 1 })
					:WithCurrentStage("anywhere")
			)
			local metadata = { parameters = { teamID = 0 }, stages = {} }
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_true(missionApi.Objectives["obj1"].completed)
		end)

		it("completes an amount = 0 objective when the count returns to zero", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false, amount = 0 }))
			local metadata = { parameters = { teamID = 0 }, stages = {} }
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, 1, metadata)
			assert.is_false(missionApi.Objectives["obj1"].completed)
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, -1, metadata)
			assert.is_true(missionApi.Objectives["obj1"].completed)
		end)

		it("freezes the count once completed", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = true, progress = 3, amount = 3 }))
			local metadata = { parameters = { teamID = 0 }, stages = {} }
			Objectives.UpdateObjectiveProgress("obj1", 0, "armwar", nil, -1, metadata)
			assert.are.equal(3, missionApi.Objectives["obj1"].progress)
		end)
	end)

	describe("observer triggers", function()
		it("activates the ObjectiveCompleted trigger naming the completed objective", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false }):WithTrigger("observer", {
				type = TRIGGER_TYPES.ObjectiveCompleted,
				parameters = { objectiveID = "obj1" },
			}))
			Objectives.SetObjectiveCompleted("obj1", true)
			assert.are.equal(1, #activatedTriggers)
		end)

		it("does not activate ObjectiveCompleted triggers naming another objective", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false })
					:WithObjective("obj2", { completed = false })
					:WithTrigger("observer", {
						type = TRIGGER_TYPES.ObjectiveCompleted,
						parameters = { objectiveID = "obj2" },
					})
			)
			Objectives.SetObjectiveCompleted("obj1", true)
			assert.are.equal(0, #activatedTriggers)
		end)

		it("activates ObjectiveCompleted triggers from progress-driven completion", function()
			install(
				Builders.MissionApi
					.new()
					:WithObjective("obj1", { completed = false, progress = 2, amount = 3 })
					:WithTrigger("observer", {
						type = TRIGGER_TYPES.ObjectiveCompleted,
						parameters = { objectiveID = "obj1" },
					})
			)
			Objectives.IncrementObjectiveProgress("obj1")
			assert.are.equal(1, #activatedTriggers)
		end)

		it("activates the ObjectiveFailed trigger naming the failed objective", function()
			install(Builders.MissionApi.new():WithObjective("obj1", { completed = false }):WithTrigger("observer", {
				type = TRIGGER_TYPES.ObjectiveFailed,
				parameters = { objectiveID = "obj1" },
			}))
			Objectives.NotifyObjectiveFailed("obj2")
			assert.are.equal(0, #activatedTriggers)
			Objectives.NotifyObjectiveFailed("obj1")
			assert.are.equal(1, #activatedTriggers)
		end)
	end)

end)
