---
--- Covers the trigger gadget's metric evaluation and event counting.
--- `evaluateMetric` and `activateTrigger` are file locals, handed out through
--- the dependency table the gadget injects into the statistics module. Stubbing
--- that module out captures the real functions and lets them be called directly.
---
--- The behaviour under test is that a condition reports progress only when it is
--- actually eligible to fire. A condition outside the current stage still has
--- its value or tally tracked, so earlier play still counts once the stage
--- arrives, but it must not report progress to the player before then.
---

local MissionSpecEnv = require("mission_api.spec_helper")

local STATISTICS_PATH = "luarules/mission_api/statistics.lua"

local evaluateMetric, activateTrigger

local function installMissionApi(currentStageID)
	GG["MissionAPI"] = {
		Difficulty = 0,
		CurrentStageID = currentStageID,
		Triggers = {},
		Objectives = {},
		trackedUnitNames = {},
		ConditionDefinitions = {
			Types = {},
			Callins = {},
			Kinds = {},
		},
		Modules = {
			SeismicContacts = { UpdateInterval = 30 },
			UnitQuery = { DoesUnitMatch = function() end },
			AreaTracking = { TrackUnitsInArea = function() end },
			DetectionLevels = {},
			Batch = VFS.Include("luarules/mission_api/batch.lua"),
			Stages = {
				GetCurrentStageID = function()
					return GG["MissionAPI"].CurrentStageID
				end,
			},
			Tracking = {
				DoesUnitHaveName = function()
					return false
				end,
				UntrackUnitID = function() end,
				DoesFeatureHaveName = function()
					return false
				end,
				UntrackFeatureID = function() end,
			},
		},
	}
end

local function loadGadget()
	local env = MissionSpecEnv.new({
		-- The gadget removes itself outside a mission.
		Spring = {
			GetGameRulesParam = function(name)
				return name == "inMission"
			end,
		},
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			RemoveGadget = function() end,
			RemoveCallIn = function() end,
			UpdateCallIn = function() end,
		},
		includes = {
			-- The real dispatcher needs loaded action definitions, and no action fires here.
			["luarules/mission_api/actions_dispatcher.lua"] = { Invoke = function() end },
			-- Hand back a statistics stub whose Init keeps the injected evaluateMetric.
			[STATISTICS_PATH] = {
				Init = function(dependencies)
					evaluateMetric = dependencies.evaluateMetric
					activateTrigger = dependencies.activateTrigger
				end,
				Increment = function() end,
				Decrement = function() end,
			},
		},
	})

	-- The gadget defines itself onto the env's `gadget` as a side effect.
	MissionSpecEnv.include(env, "luarules/gadgets/api_missions_triggers.lua")
	env.gadget:Initialize()
end

--- A metric condition record shaped the way objectives_loader builds them.
local function metricTrigger(stages, reported)
	return {
		type = "UnitsOwned",
		parameters = {},
		atMost = 0,
		triggered = false,
		repeatCount = 0,
		settings = { active = true, stages = stages, prerequisites = {} },
		onProgress = function(value)
			reported[#reported + 1] = value
		end,
	}
end

describe("mission_api trigger gadget metric evaluation", function()
	before_each(function()
		installMissionApi("secondStage")
		loadGadget()
	end)

	it("exposes evaluateMetric through the statistics injection", function()
		assert.is_function(evaluateMetric)
	end)

	it("reports progress for a metric in the current stage", function()
		local reported = {}
		evaluateMetric(metricTrigger({ "secondStage" }, reported), 4)

		assert.are.same({ 4 }, reported)
	end)

	it("reports progress for a metric with no stage restriction", function()
		local reported = {}
		evaluateMetric(metricTrigger({}, reported), 7)

		assert.are.same({ 7 }, reported)
	end)

	-- An objective listed only under a later stage would otherwise announce its
	-- progress from the first frame, before the player can act on it.
	it("stays quiet for a metric belonging to another stage", function()
		local reported = {}
		evaluateMetric(metricTrigger({ "thirdStage" }, reported), 4)

		assert.are.same({}, reported)
	end)

	it("still tracks the value while out of stage, so the edge is not lost", function()
		local reported = {}
		local trigger = metricTrigger({ "thirdStage" }, reported)

		evaluateMetric(trigger, 4)

		assert.are.equal(4, trigger.lastValue)
		assert.is_false(trigger.metricSatisfied)
	end)
end)

--- An event condition record with a `count`, shaped the way the loaders build them.
local function eventTrigger(stages, count, reported, fired)
	return {
		type = "TotalUnitsKilled",
		parameters = {},
		count = count,
		occurrences = 0,
		triggered = false,
		repeatCount = 0,
		settings = { active = true, stages = stages, prerequisites = {} },
		onProgress = function(occurrences)
			reported[#reported + 1] = occurrences
		end,
		onActivate = function()
			fired[#fired + 1] = true
		end,
	}
end

describe("mission_api trigger gadget event counting", function()
	before_each(function()
		installMissionApi("secondStage")
		loadGadget()
	end)

	it("reports each occurrence and fires on the count", function()
		local reported, fired = {}, {}
		local trigger = eventTrigger({ "secondStage" }, 3, reported, fired)

		activateTrigger(trigger)
		activateTrigger(trigger)
		activateTrigger(trigger)

		assert.are.same({ 1, 2 }, reported)
		assert.are.equal(1, #fired)
	end)

	it("counts occurrences while out of stage, without reporting or firing", function()
		local reported, fired = {}, {}
		local trigger = eventTrigger({ "thirdStage" }, 3, reported, fired)

		activateTrigger(trigger)
		activateTrigger(trigger)
		activateTrigger(trigger)

		assert.are.equal(3, trigger.occurrences)
		assert.are.same({}, reported)
		assert.are.same({}, fired)
	end)

	-- Kills made before the stage opened still count towards its objective, as
	-- statistics conditions always have.
	it("fires on the next occurrence once its stage arrives with the count already met", function()
		local reported, fired = {}, {}
		local trigger = eventTrigger({ "thirdStage" }, 3, reported, fired)

		activateTrigger(trigger)
		activateTrigger(trigger)
		activateTrigger(trigger)
		GG["MissionAPI"].CurrentStageID = "thirdStage"
		activateTrigger(trigger)

		assert.are.equal(1, #fired)
	end)
end)

describe("mission_api trigger gadget metric samples within one batch", function()
	local batch

	before_each(function()
		installMissionApi(nil)
		loadGadget()
		batch = GG["MissionAPI"].Modules.Batch
	end)

	local function satisfiedRepeatingTrigger()
		return {
			type = "UnitsOwned",
			parameters = {},
			actions = {},
			atLeast = 5,
			triggered = true,
			repeatCount = 1,
			metricSatisfied = true,
			lastValue = 7,
			settings = { active = true, repeating = true, stages = {}, prerequisites = {} },
		}
	end

	it("does not fire again for a value that leaves its range and comes back before the batch ends", function()
		local trigger = satisfiedRepeatingTrigger()

		batch.Start()
		GG["MissionAPI"].EvaluateMetric(trigger, 3)
		GG["MissionAPI"].EvaluateMetric(trigger, 7)
		batch.End()

		assert.are.equal(1, trigger.repeatCount)
	end)

	it("fires on each batch's net value, for every sequence of samples", function()
		local IN_RANGE, OUT_OF_RANGE = 7, 3
		local MAX_SAMPLES_PER_BATCH, MAX_BATCHES = 4, 3

		-- Every sequence of in- and out-of-range samples, one to MAX_SAMPLES_PER_BATCH long.
		local batchSamples = {}
		local function addBatchSamples(samples)
			if #samples > 0 then
				batchSamples[#batchSamples + 1] = samples
			end
			if #samples < MAX_SAMPLES_PER_BATCH then
				for _, value in ipairs({ IN_RANGE, OUT_OF_RANGE }) do
					local longer = { unpack(samples) }
					longer[#longer + 1] = value
					addBatchSamples(longer)
				end
			end
		end
		addBatchSamples({})

		local caseCount, failures = 0, {}

		local function runCase(batches, startsSatisfied, repeating)
			caseCount = caseCount + 1
			local trigger = {
				type = "UnitsOwned",
				parameters = {},
				actions = {},
				atLeast = 5,
				triggered = startsSatisfied,
				repeatCount = startsSatisfied and 1 or 0,
				metricSatisfied = startsSatisfied,
				lastValue = startsSatisfied and IN_RANGE or OUT_OF_RANGE,
				settings = { active = true, repeating = repeating, stages = {}, prerequisites = {} },
			}

			-- The specification: fire when the net value enters the range, re-arm when it leaves.
			local netValueInRange, expectedRepeatCount = startsSatisfied, trigger.repeatCount
			for batchIndex, samples in ipairs(batches) do
				batch.Start()
				for _, value in ipairs(samples) do
					GG["MissionAPI"].EvaluateMetric(trigger, value)
				end
				batch.End()

				local inRange = samples[#samples] >= trigger.atLeast
				if inRange and not netValueInRange and (repeating or expectedRepeatCount == 0) then
					expectedRepeatCount = expectedRepeatCount + 1
				end
				netValueInRange = inRange

				if trigger.repeatCount ~= expectedRepeatCount then
					local described = {}
					for i = 1, batchIndex do
						described[i] = "{" .. table.concat(batches[i], ",") .. "}"
					end
					failures[#failures + 1] = string.format(
						"start %s, %s, batches %s: fired %d times, expected %d",
						startsSatisfied and "satisfied" or "unsatisfied",
						repeating and "repeating" or "once",
						table.concat(described, " "),
						trigger.repeatCount,
						expectedRepeatCount
					)
					break
				end
			end

			-- Leaves the trigger out of range, so the gadget's list of refused triggers drops it on its next recheck.
			batch.Start()
			GG["MissionAPI"].EvaluateMetric(trigger, OUT_OF_RANGE)
			batch.End()
		end

		local function runBatches(batches, startsSatisfied, repeating)
			if #batches > 0 then
				runCase(batches, startsSatisfied, repeating)
			end
			if #batches < MAX_BATCHES then
				for _, samples in ipairs(batchSamples) do
					local longer = { unpack(batches) }
					longer[#longer + 1] = samples
					runBatches(longer, startsSatisfied, repeating)
				end
			end
		end

		for _, startsSatisfied in ipairs({ true, false }) do
			for _, repeating in ipairs({ true, false }) do
				runBatches({}, startsSatisfied, repeating)
			end
		end

		print(string.format("\n%d cases, %d failures", caseCount, #failures))
		for i = 1, math.min(#failures, 12) do
			print(failures[i])
		end
		assert.are.equal(0, #failures)
	end)
end)
