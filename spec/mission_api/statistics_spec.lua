require("spec_helper")

local statistics = VFS.Include("luarules/mission_api/statistics.lua")

describe("mission_api.statistics", function()
	-- TotalUnits* are cumulative tallies, so they are events; UnitsOwned is a
	-- level that moves both ways, so it is a metric. The engine routes them
	-- differently: events report each occurrence, metrics report their value.
	local EVENT_TYPE = 1
	local METRIC_TYPE = 2

	local conditionKinds = { [EVENT_TYPE] = "event", [METRIC_TYPE] = "metric" }

	local triggers -- triggerID -> trigger
	local activated -- ordered list of activated triggers
	local measured -- ordered list of { trigger, value } handed to EvaluateMetric

	-- Fakes injected in place of the gadget's trigger core:
	local function processTriggersOfType(triggerType, func)
		for triggerID, trigger in pairs(triggers) do
			if trigger.type == triggerType then
				func(trigger, triggerID)
			end
		end
	end

	local function activateTrigger(trigger)
		activated[#activated + 1] = trigger
		trigger.triggered = true
		trigger.repeatCount = trigger.repeatCount + 1
		return true
	end

	local function evaluateMetric(trigger, value)
		measured[#measured + 1] = { trigger = trigger, value = value }
		return true
	end

	local function makeTrigger(triggerType, parameters)
		return { type = triggerType, parameters = parameters, triggered = false, repeatCount = 0 }
	end

	before_each(function()
		triggers = {}
		activated = {}
		measured = {}
		GG["MissionAPI"] = {}
		statistics.Init({
			processTriggersOfType = processTriggersOfType,
			activateTrigger = activateTrigger,
			evaluateMetric = evaluateMetric,
			conditionKinds = conditionKinds,
		})
	end)

	-- Note: statisticsTriggerCounts is module-private and persists for the whole
	-- run, so each test uses a unique triggerID to stay isolated.

	describe("event conditions (TotalUnits*)", function()

		it("reports every matching occurrence, leaving `count` to the caller", function()
			triggers.eventEach = makeTrigger(EVENT_TYPE, { teamID = 0 })

			statistics.Increment(EVENT_TYPE, 0, "armwar", {})
			statistics.Increment(EVENT_TYPE, 0, "armwar", {})
			statistics.Increment(EVENT_TYPE, 0, "armwar", {})

			assert.are.equal(3, #activated)
		end)

		it("does not report decrements, since a tally only rises", function()
			triggers.eventDown = makeTrigger(EVENT_TYPE, { teamID = 0 })

			statistics.Decrement(EVENT_TYPE, 0, "armwar", {})

			assert.are.equal(0, #activated)
		end)

		it("never routes an event through EvaluateMetric", function()
			triggers.eventNotMetric = makeTrigger(EVENT_TYPE, { teamID = 0 })

			statistics.Increment(EVENT_TYPE, 0, "armwar", {})

			assert.are.equal(0, #measured)
		end)
	end)

	describe("metric conditions (UnitsOwned)", function()

		it("reports the running value on increment", function()
			triggers.metricUp = makeTrigger(METRIC_TYPE, { teamID = 0 })

			statistics.Increment(METRIC_TYPE, 0, "armwar", {})
			statistics.Increment(METRIC_TYPE, 0, "armwar", {})

			assert.are.equal(2, #measured)
			assert.are.equal(1, measured[1].value)
			assert.are.equal(2, measured[2].value)
		end)

		it("reports the running value on decrement, because a level moves both ways", function()
			triggers.metricDown = makeTrigger(METRIC_TYPE, { teamID = 0 })

			statistics.Increment(METRIC_TYPE, 0, "armwar", {})
			statistics.Decrement(METRIC_TYPE, 0, "armwar", {})

			assert.are.equal(2, #measured)
			assert.are.equal(1, measured[1].value)
			assert.are.equal(0, measured[2].value)
		end)

		it("never routes a metric through ActivateTrigger directly", function()
			triggers.metricNotEvent = makeTrigger(METRIC_TYPE, { teamID = 0 })

			statistics.Increment(METRIC_TYPE, 0, "armwar", {})
			statistics.Decrement(METRIC_TYPE, 0, "armwar", {})

			assert.are.equal(0, #activated)
		end)
	end)

	describe("filters", function()

		it("filters by teamID", function()
			triggers.filterTeam = makeTrigger(EVENT_TYPE, { teamID = 0 })

			statistics.Increment(EVENT_TYPE, 1, "armwar", {})
			assert.are.equal(0, #activated)

			statistics.Increment(EVENT_TYPE, 0, "armwar", {})
			assert.are.equal(1, #activated)
		end)

		it("filters by unitDefName", function()
			triggers.filterDef = makeTrigger(EVENT_TYPE, { teamID = 0, unitDefName = "armwar" })

			statistics.Increment(EVENT_TYPE, 0, "corak", {})
			assert.are.equal(0, #activated)

			statistics.Increment(EVENT_TYPE, 0, "armwar", {})
			assert.are.equal(1, #activated)
		end)

		it("filters by unitName", function()
			triggers.filterName = makeTrigger(EVENT_TYPE, { teamID = 0, unitName = "bots" })

			statistics.Increment(EVENT_TYPE, 0, "armwar", { others = true })
			assert.are.equal(0, #activated)

			statistics.Increment(EVENT_TYPE, 0, "armwar", { bots = true })
			assert.are.equal(1, #activated)
		end)

		it("applies filters to metrics too", function()
			triggers.filterMetric = makeTrigger(METRIC_TYPE, { teamID = 0, unitDefName = "armwar" })

			statistics.Increment(METRIC_TYPE, 0, "corak", {})
			assert.are.equal(0, #measured)

			statistics.Increment(METRIC_TYPE, 0, "armwar", {})
			assert.are.equal(1, #measured)
		end)
	end)

end)
