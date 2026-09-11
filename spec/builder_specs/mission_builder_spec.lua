require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

describe("MissionBuilder", function()
	it("builds an empty mission with empty sections", function()
		local mission = Builders.Mission.new():Build()

		assert.are.same({}, mission.Stages)
		assert.are.same({}, mission.Objectives)
		assert.are.same({}, mission.Triggers)
		assert.are.same({}, mission.Actions)
		assert.are.same({}, mission.UnitLoadout)
		assert.are.same({}, mission.FeatureLoadout)
		assert.is_nil(mission.InitialStage)
	end)

	it("builds the mission sections", function()
		local mission = Builders.Mission
			.new()
			:WithObjective("obj1", { textKey = "kill" })
			:WithStage("stage1", { objectives = { "obj1" } })
			:WithInitialStage("stage1")
			:WithTrigger("trig1", { type = "TimeElapsed" })
			:WithAction("act1", { type = "Victory" })
			:Build()

		assert.are.same({ textKey = "kill" }, mission.Objectives.obj1)
		assert.are.same({ objectives = { "obj1" } }, mission.Stages.stage1)
		assert.are.equal("stage1", mission.InitialStage)
		assert.are.same({ type = "TimeElapsed" }, mission.Triggers.trig1)
		assert.are.same({ type = "Victory" }, mission.Actions.act1)
	end)

	it("defaults a stage to an empty objectives table", function()
		local mission = Builders.Mission.new():WithStage("stage1"):Build()

		assert.are.same({ objectives = {} }, mission.Stages.stage1)
	end)

	it("sets the stage and makes it the initial one", function()
		local mission = Builders.Mission.new():WithInitialStageDefinition("stage1", { objectives = { "obj1" } }):Build()

		assert.are.equal("stage1", mission.InitialStage)
		assert.are.same({ objectives = { "obj1" } }, mission.Stages.stage1)
	end)

	it("builds the loadouts", function()
		local mission = Builders.Mission
			.new()
			:WithUnitLoadout({ { unitDefName = "armcom" } })
			:WithFeatureLoadout({ { featureDefName = "tree" } })
			:Build()

		assert.are.same({ { unitDefName = "armcom" } }, mission.UnitLoadout)
		assert.are.same({ { featureDefName = "tree" } }, mission.FeatureLoadout)
	end)

	-- Missions that declare a field incorrectly are the ones validation must report on.
	it("sets a top level field to any value", function()
		local mission = Builders.Mission.new():WithField("Triggers", "notATable"):Build()

		assert.are.equal("notATable", mission.Triggers)
	end)

	it("builds a new table each time, so missions do not share state", function()
		local builder = Builders.Mission.new()
		local first = builder:Build()
		builder:WithTrigger("trig1", {})
		local second = builder:Build()

		assert.are_not.equal(first, second)
		assert.is_nil(first.Triggers.trig1)
		assert.is_not_nil(second.Triggers.trig1)
	end)
end)
