---
--- Annotated reference for the condition format. This format is implemented, so
--- this file is runnable; stages_and_objectives_test.lua is the same mission
--- without the commentary.
---
--- Concepts:
---   trigger    - type + parameters + settings + actions. Standalone automation.
---   objective  - type + parameters + textKey + onComplete. A goal for the player.
---   stage      - decides which objective IDs are currently active
---   action     - a thing the mission does
---   onComplete - what happens when an objective completes: stage change, actions
---
--- Condition types come in two disjoint families. Which family a type belongs to
--- is a property of the type itself, not of how you use it:
---
---   eventTypes.*   something happened. Tallied upwards.
---   metricTypes.*  a value right now. Can go up or down.
---
--- The family decides how you write the threshold, and it is the same whether a
--- trigger or an objective is doing the watching:
---
---                 event                    metric
---   trigger       count = 3                atLeast = 5  /  atMost = 0
---   objective     count = 3                atLeast = 5  /  atMost = 0
---
--- `count` defaults to 1. `atLeast` and `atMost` may be combined to give a range.
---
--- Compared to the current format:
---   `amount`   is gone. It meant "repeat the trigger N times" for event types
---              but "the statistic must reach N" for metric types.
---   `quantity` is gone from condition schemas. A metric type only says *what*
---              it measures; the threshold says *when this usage cares*, so it
---              belongs to the trigger/objective. (The `quantity` in a
---              unitLoadout is unrelated and keeps its name.)
---   Neither had a direction, so "reach zero" had to be smuggled in as the magic
---              value 0. `atMost = 0` says it outright.
---

local conditions = GG['MissionAPI'].ConditionDefinitions
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

-- Two filtered views over one canonical condition registry, so there is a single
-- source of truth internally. Picking from the right one tells you which
-- threshold to write.
local eventTypes = conditions.EventTypes
local metricTypes = conditions.MetricTypes

local initialStage = 'firstStage'

-- Stages decide which objective IDs are currently visible/active.
local stages = {
	firstStage = {
		objectives = { 'wait3secs' }
	},
	secondStage = {
		objectives = { 'buildBots' }
	},
	thirdStage = {
		objectives = { 'buildBots', 'destroyBots' }
	}
}

local objectives = {

	wait3secs = {
		textKey = "wait_3_seconds",

		-- Event type, no count: completes on the first occurrence.
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 3,
		},

		-- Completion effects belong to the objective, not to a hidden generated action.
		onComplete = {
			nextStage = 'secondStage',
		},
	},

	buildBots = {
		textKey = "build_3_bots",

		-- Event type with a count: completes on the third matching occurrence.
		type = eventTypes.ConstructionFinished,
		parameters = {
			unitDefName = 'corak',
			teamID = 0,
		},
		count = 3,

		-- onComplete carries both the stage transition and any actions to run.
		-- In the current format this needed a separate trigger + ChangeStage action.
		onComplete = {
			nextStage = 'thirdStage',
			actions = { 'spawnBotDestroyer' },
		},
	},

	destroyBots = {
		textKey = "destroy_all_bots",

		-- Metric type: watches a value that can move in both directions, so the
		-- threshold needs a direction. Replaces `amount = 0`.
		type = metricTypes.UnitsOwned,
		parameters = {
			unitName = 'bots',
			teamID = 0,
		},
		atMost = 0,
	},
}

-- Triggers are standalone automation: when the condition holds, run the actions.
-- They are not involved in objective completion — the old `changeStage3` trigger
-- is gone, since `buildBots.onComplete` now covers it.
local triggers = {

	spawnBots = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 0,
			interval = 2,
		},
		settings = {
			repeating = true,
			stages = { 'secondStage', 'thirdStage' },
			maxRepeats = 5,
		},
		actions = { 'spawnBot' },
	},

	-- A metric type used by a trigger rather than an objective. Compare with the
	-- `destroyBots` objective above: same type, parameters and threshold. Both
	-- fire on the same edge; the objective completes and this sends reinforcements.
	botsWipedOut = {
		type = metricTypes.UnitsOwned,
		parameters = {
			teamID = 0,
			unitName = 'bots',
		},
		atMost = 0,
		settings = {
			stages = { 'thirdStage' },
		},
		actions = { 'spawnBotDestroyer' },
	},

	-- Triggers take `count` too, so "on the 4th one" no longer needs to be
	-- expressed as a repeat stride.
	fourthBotBuilt = {
		type = eventTypes.ConstructionFinished,
		parameters = {
			unitDefName = 'corak',
			teamID = 0,
		},
		count = 4,
		actions = { 'spawnBotDestroyer' },
	},
}

local actions = {

	spawnBot = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corak', x = 1800, z = 1800, team = 0, unitName = 'bots' },
			},
		},
	},

	spawnBotDestroyer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armllt', x = 1800, z = 2100, team = 1, quantity = 3 },
			},
		},
	},
}

return {
	InitialStage = initialStage,
	Stages = stages,
	Objectives = objectives,
	Triggers = triggers,
	Actions = actions,
}
