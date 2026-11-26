---
--- Annotated reference for the condition format, and a runnable test mission.
--- The objective lifecycle (activate, fail, cancel, on* hooks) is covered by
--- stages_and_objectives_test.lua instead.
---
--- Concepts:
---   trigger    - type + parameters + settings + actions. Standalone automation.
---   objective  - type + parameters + textKey + nextStage + on* hooks. A goal for the player.
---   stage      - decides which objective IDs are currently active
---   action     - a thing the mission does
---
--- Condition types come in two disjoint families. Which family a type belongs to
--- is a property of the type itself, not of how you use it:
---
---   event   something happened. Tallied upwards.
---   metric  a value right now. Can go up or down.
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

local conditionTypes = GG['MissionAPI'].ConditionDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

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
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 3,
		},

		nextStage = 'secondStage',
		onCompleted = 'startSpawningBots',
	},

	buildBots = {
		textKey = "build_6_bots",

		-- Event type with a count: completes on the sixth matching occurrence, which
		-- is the last bot spawnNextBot produces.
		type = conditionTypes.UnitExists,
		parameters = {
			includeUnit = { unitDefName = 'corak', teamName = 'player' },
		},
		count = 6,

		-- nextStage moves on by itself; onCompleted names an Event trigger for
		-- anything else that should happen at the same moment.
		nextStage = 'thirdStage',
		onCompleted = 'buildBotsCompleted',
	},

	destroyBots = {
		textKey = "destroy_all_bots",

		-- Metric type: watches a value that can move in both directions, so the
		-- threshold needs a direction.
		type = conditionTypes.UnitsOwned,
		parameters = {
			unitName = 'bots',
			teamName = 'player',
		},
		atMost = 0,
	},
}

-- Triggers are standalone automation: when the condition is met, run the actions.
-- They are not involved in objective completion: `buildBots.nextStage` changes
-- the stage, so no separate ChangeStage trigger is needed.
local triggers = {

	-- Fired by the buildBots objective through its onCompleted hook.
	buildBotsCompleted = {
		type = conditionTypes.Event,
		actions = { 'spawnBotDestroyer' },
	},

	-- Fired by the wait3secs objective as secondStage begins: the first bot, and the
	-- countdown to the next one.
	startSpawningBots = {
		type = conditionTypes.Event,
		actions = { 'spawnBot', 'restartBotCountdown' },
	},

	-- TimeElapsed fires only once, so a bot every two seconds is a countdown that
	-- restarts itself each time it runs out.
	spawnNextBot = {
		type = conditionTypes.CountdownFinished,
		parameters = {
			countdownID = 'nextBot',
		},
		settings = {
			repeating = true,
			-- secondStage only: buildBots ends the stage at the sixth bot, and the
			-- countdown is then not restarted, which stops spawning. The turrets arrive
			-- with thirdStage and kill far faster than one bot per two seconds, so
			-- spawning past that point would have bots appearing after destroyBots had
			-- already reported them all destroyed.
			stages = { 'secondStage' },
		},
		actions = { 'spawnBot', 'restartBotCountdown' },
	},

	-- A metric type used by a trigger rather than an objective. Compare with the
	-- `destroyBots` objective above: same type, parameters and threshold. Both
	-- fire on the same edge; the objective completes and this announces it.
	botsWipedOut = {
		type = conditionTypes.UnitsOwned,
		parameters = {
			teamName = 'player',
			unitName = 'bots',
		},
		atMost = 0,
		settings = {
			stages = { 'thirdStage' },
		},
		actions = { 'messageBotsWipedOut' },
	},

	-- Triggers take `count` too.
	fourthBotBuilt = {
		type = conditionTypes.UnitExists,
		parameters = {
			includeUnit = { unitDefName = 'corak', teamName = 'player' },
		},
		count = 4,
		actions = { 'messageFourthBot' },
	},
}

local actions = {

	spawnBot = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corak', position = { x = 1800, z = 1800 }, teamName = 'player', unitName = 'bots',
					-- Hold position and hold fire: the bots are targets, not combatants,
					-- so the turrets always win and the mission always completes.
					orders = {
						{ CMD.MOVE_STATE, 0, {} },
						{ CMD.FIRE_STATE, 0, {} },
					},
				},
			},
		},
	},

	-- Not displayed: the player has no use for this timer, and a hidden countdown
	-- also runs for exactly the seconds given.
	restartBotCountdown = {
		type = actionTypes.AddCountdown,
		parameters = {
			countdownID = 'nextBot',
			seconds = 2,
			displayed = false,
		},
	},

	spawnBotDestroyer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				-- Explicit positions rather than quantity + spacing: the grid is laid out
				-- around the center, which pulled a turret to 208 elmos, inside corak's
				-- 215 range. At z = 2150 every turret is 350+ away but still inside
				-- armllt's 430, so they shoot and are not shot at.
				{ unitDefName = 'armllt', position = { x = 1700, z = 2150 }, teamName = 'enemy' },
				{ unitDefName = 'armllt', position = { x = 1800, z = 2150 }, teamName = 'enemy' },
				{ unitDefName = 'armllt', position = { x = 1900, z = 2150 }, teamName = 'enemy' },
				-- armllt costs 20 energy per shot and the enemy team produces none, so the
				-- turrets stop firing without this.
				{ unitDefName = 'armfus', position = { x = 1800, z = 2450 }, teamName = 'enemy' },
			},
		},
	},

	-- The two triggers below exist to demonstrate their condition shapes, so they
	-- only announce themselves rather than spawning more turrets.
	messageBotsWipedOut = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "All bots destroyed.",
		},
	},

	messageFourthBot = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "A fourth bot has appeared.",
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
