local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

MissionSpecEnv.registerModules(env)
local conditionDefinitions = MissionSpecEnv.include(env, "luarules/mission_api/conditions_loader.lua")
	.LoadConditionDefinitions()
GG["MissionAPI"] = nil

local objectivesLoader = MissionSpecEnv.include(env, "luarules/mission_api/objectives_loader.lua")
local types = conditionDefinitions.Types

--- Condition records built here are not seen by the Mission API validation, which
--- only reads the raw mission data, so they are covered by this spec instead.
describe("mission_api.objectives_loader", function()
	local completed, reported

	before_each(function()
		completed, reported = {}, {}
		GG["MissionAPI"] = {
			ConditionDefinitions = conditionDefinitions,
			ObjectiveTriggers = {},
			ObjectiveStages = {},
			Modules = {
				Objectives = {
					CompleteObjective = function(objectiveID)
						completed[#completed + 1] = objectiveID
					end,
					ReportProgress = function(objectiveID, progress)
						reported[#reported + 1] = { objectiveID, progress }
					end,
				},
			},
		}
	end)

	after_each(function()
		GG["MissionAPI"] = nil
	end)

	local function load(rawObjectives, stages)
		local rawTriggers = {}
		local result = objectivesLoader.ProcessRawObjectives(rawObjectives, rawTriggers, {}, stages or {})
		return result, rawTriggers
	end

	describe("condition records", function()
		it("contributes a record per objective and remembers its trigger ID", function()
			local _, rawTriggers = load({
				alpha = { textKey = "a", type = types.TimeElapsed, parameters = { gameFrame = 3 } },
			})

			assert.is_not_nil(rawTriggers.__objective_alpha)
			assert.are.equal("__objective_alpha", GG["MissionAPI"].ObjectiveTriggers.alpha)
		end)

		it("copies the condition and its threshold onto the record", function()
			local _, rawTriggers = load({
				alpha = { textKey = "a", type = types.UnitKilled, parameters = { teamID = 0 }, count = 3 },
			})
			local record = rawTriggers.__objective_alpha

			assert.are.equal(types.UnitKilled, record.type)
			assert.are.same({ teamID = 0 }, record.parameters)
			assert.are.equal(3, record.count)
		end)

		it("carries metric bounds onto the record", function()
			local _, rawTriggers = load({
				alpha = { textKey = "a", type = types.UnitsOwned, parameters = {}, atMost = 0 },
			})

			assert.are.equal(0, rawTriggers.__objective_alpha.atMost)
		end)

		it("defaults parameters to an empty table", function()
			local _, rawTriggers = load({ alpha = { textKey = "a", type = types.TimeElapsed } })

			assert.are.same({}, rawTriggers.__objective_alpha.parameters)
		end)

		it("starts inactive and is never repeating, so completion stays latched", function()
			local _, rawTriggers = load({ alpha = { textKey = "a", type = types.TimeElapsed } })
			local settings = rawTriggers.__objective_alpha.settings

			assert.is_false(settings.active)
			assert.is_nil(settings.repeating)
		end)

		it("completes and reports progress through the objectives module instead of running actions", function()
			local _, rawTriggers = load({ alpha = { textKey = "a", type = types.TimeElapsed } })
			local record = rawTriggers.__objective_alpha

			record.onActivate()
			record.onProgress(2)

			assert.is_nil(record.actions)
			assert.are.same({ "alpha" }, completed)
			assert.are.same({ { "alpha", 2 } }, reported)
		end)

		it("restricts the record to the stages its objective appears in", function()
			local _, rawTriggers = load(
				{ alpha = { textKey = "a", type = types.TimeElapsed } },
				{ first = { objectives = { "alpha" } }, second = { objectives = { "alpha" } } }
			)
			local stages = rawTriggers.__objective_alpha.settings.stages
			table.sort(stages)

			assert.are.same({ "first", "second" }, stages)
			assert.are.same(stages, GG["MissionAPI"].ObjectiveStages.alpha)
		end)

		it("builds nothing for an objective without a condition type", function()
			local _, rawTriggers = load({ alpha = { textKey = "a" } })

			assert.is_nil(rawTriggers.__objective_alpha)
			assert.is_nil(GG["MissionAPI"].ObjectiveTriggers.alpha)
		end)
	end)

	describe("runtime state", function()
		it("starts every objective inactive, incomplete and without progress", function()
			local result = load({ alpha = { textKey = "a", type = types.UnitKilled, count = 4 } })

			assert.is_false(result.alpha.active)
			assert.is_false(result.alpha.completed)
			assert.are.equal(0, result.alpha.progress)
			assert.are.equal(4, result.alpha.target)
		end)

		it("targets the metric bound when there is no count", function()
			local result = load({
				a = { textKey = "a", type = types.UnitsOwned, atLeast = 9 },
				b = { textKey = "b", type = types.UnitsOwned, atMost = 0 },
			})

			assert.are.equal(9, result.a.target)
			assert.are.equal(0, result.b.target)
		end)

		it("targets a single occurrence for an event or action-driven objective without a count", function()
			-- Otherwise completing it would report a nil target.
			local result = load({ event = { textKey = "a", type = types.UnitKilled }, manual = { textKey = "b" } })

			assert.are.equal(1, result.event.target)
			assert.are.equal(1, result.manual.target)
		end)
	end)

	describe("ApplyThresholds", function()
		it("copies resolved thresholds onto the record and recomputes the target", function()
			local objectives, rawTriggers = load({ alpha = { textKey = "a", type = types.UnitKilled, count = 2 } })
			objectives.alpha.count = 5

			objectivesLoader.ApplyThresholds("alpha", objectives.alpha, rawTriggers)

			assert.are.equal(5, rawTriggers.__objective_alpha.count)
			assert.are.equal(5, objectives.alpha.target)
		end)

		it("only recomputes the target for an objective without a record", function()
			local objectives, rawTriggers = load({ manual = { textKey = "a", count = 2 } })
			objectives.manual.count = 3

			objectivesLoader.ApplyThresholds("manual", objectives.manual, rawTriggers)

			assert.are.equal(3, objectives.manual.target)
		end)
	end)
end)
