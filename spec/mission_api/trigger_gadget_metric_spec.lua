require("spec_helper")

---
--- Covers the trigger gadget's metric evaluation, which nothing else reaches:
--- `evaluateMetric` is a file local, so the only handle on it is the dependency
--- table the gadget injects into the statistics module. Stubbing that module out
--- captures the real function and lets it be called directly.
---
--- The behaviour under test is that a metric reports progress only when it is
--- actually eligible to fire. An objective outside the current stage still has
--- its running value tracked, so it fires the moment the stage arrives, but it
--- must not report progress to the player before then.
---

local STATISTICS_PATH = "luarules/mission_api/statistics.lua"

local evaluateMetric

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
			ActionsDispatcher = { Invoke = function() end },
			SeismicContacts = { UpdateInterval = 30 },
			DetectionLevels = {},
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
	local realInclude = VFS.Include

	-- Hand back a statistics stub whose Init keeps the injected evaluateMetric.
	VFS.Include = function(path, ...)
		if path == STATISTICS_PATH then
			return {
				Init = function(dependencies)
					evaluateMetric = dependencies.evaluateMetric
				end,
				Increment = function() end,
				Decrement = function() end,
			}
		end
		return realInclude(path, ...)
	end

	_G.gadget = {}
	_G.gadgetHandler = {
		IsSyncedCode = function()
			return true
		end,
		RemoveGadget = function() end,
		RemoveCallIn = function() end,
		UpdateCallIn = function() end,
	}

	-- The gadget defines itself onto the global `gadget` as a side effect, so it
	-- has to run rather than come from the include cache.
	local chunk = assert(loadfile("luarules/gadgets/api_missions_triggers.lua"))
	chunk()
	_G.gadget:Initialize()

	VFS.Include = realInclude
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
