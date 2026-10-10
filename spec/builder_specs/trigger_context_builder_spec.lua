require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

describe("TriggerContextBuilder", function()
	describe("defaults", function()
		it("answers name and ownership questions in the affirmative", function()
			local context = Builders.TriggerContext.new():Build()

			assert.is_true(context.DoesUnitHaveName(1, "bots"))
			assert.is_true(context.DoesFeatureHaveName(1, "wreck"))
			assert.is_true(context.IsBuildFrameOwner(1, nil, nil))
			assert.is_true(context.IsFeatureInArea(1, {}))
			assert.is_false(context.InFactory(1))
		end)

		it("treats every unit as having been under construction", function()
			assert.is_true(Builders.TriggerContext.new():Build().WasUnderConstruction[100])
		end)

		it("exposes the shared state tables the handlers write into", function()
			local context = Builders.TriggerContext.new():Build()

			assert.are.same({}, context.PreviousUnitsInAreas)
			assert.are.same({}, context.ConstructionState)
			assert.are.same({}, context.DwellingUnitsInAreas)
		end)

		it("reports no units in an area and no reclaim income", function()
			local context = Builders.TriggerContext.new():Build()

			assert.are.same({}, context.GetUnitsInArea({}))
			assert.is_nil(context.GetReclaimIncomeSnapshot(0))
		end)
	end)

	describe("ActivateTrigger", function()
		it("counts and records activations", function()
			local context = Builders.TriggerContext.new():Build()
			local trigger = Builders.Trigger.new():Build()

			assert.is_true(context.ActivateTrigger(trigger))

			assert.are.equal(1, context.timesFired())
			assert.are.equal(trigger, context.calls.activateTrigger[1].trigger)
		end)
	end)

	describe("construction claims", function()
		it("claims a buildee once per trigger", function()
			local context = Builders.TriggerContext.new():Build()

			assert.is_falsy(context.HasConstructionStarted(100, "t"))

			context.ClaimConstructionStart(100, "t")

			assert.is_true(context.HasConstructionStarted(100, "t"))
			assert.is_falsy(context.HasConstructionStarted(100, "other"))
			assert.is_falsy(context.HasConstructionStarted(101, "t"))
		end)
	end)

	describe("overrides", function()
		it("reports a build frame inside a factory", function()
			assert.is_true(Builders.TriggerContext.new():WithInFactory(true):Build().InFactory(100))
		end)

		it("takes a function, for an answer that varies by buildee", function()
			local context = Builders.TriggerContext
				.new()
				:WithInFactory(function(buildeeID)
					return buildeeID == 100
				end)
				:Build()

			assert.is_true(context.InFactory(100))
			assert.is_false(context.InFactory(101))
		end)

		it("returns the units seeded in the area", function()
			local context = Builders.TriggerContext.new():WithUnitsInArea({ 100, 101 }):Build()

			assert.are.same({ 100, 101 }, context.GetUnitsInArea({}))
		end)
	end)

	it("gives each built context its own state", function()
		local first = Builders.TriggerContext.new():Build()
		local second = Builders.TriggerContext.new():Build()

		first.ActivateTrigger(Builders.Trigger.new():Build())

		assert.are.equal(1, first.timesFired())
		assert.are.equal(0, second.timesFired())
	end)
end)
