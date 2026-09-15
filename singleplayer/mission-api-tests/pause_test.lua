---
--- Pause and Unpause actions test mission.
---
--- The mission pauses the game twice. While paused, the pause screen must stay
--- hidden and pressing the pause key must not unpause for more than a moment.
--- Ordering the scout ends each scripted pause (orders still arrive while paused).
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	spawnScout = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'spawnScout', 'messageIntro' },
	},

	firstPause = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'pause', 'messagePaused' },
	},

	-- Fires while paused: commands are relayed and processed between frames.
	scoutOrdered = {
		type = triggerTypes.UnitOrdered,
		settings = {
			repeating = true,
			maxRepeats = 10,
		},
		parameters = {
			command = CMD.ANY,
			unitName = 'scout',
		},
		actions = { 'unpause', 'messageUnpaused' },
	},

	secondPause = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 10,
		},
		actions = { 'pause', 'messagePausedAgain' },
	},
}

local actions = {

	spawnScout = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armflea', x = 1800, z = 1600, team = 0, unitName = 'scout' },
			},
		},
	},

	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Pause test: the mission pauses at 5 s and again at 10 s. Order the flea to unpause.",
		},
	},

	pause = {
		type = actionTypes.Pause,
	},

	unpause = {
		type = actionTypes.Unpause,
	},

	messagePaused = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Paused by the mission: no pause screen, and your pause key must not unpause it. Order the flea to continue.",
		},
	},

	messagePausedAgain = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Paused by the mission again. Order the flea to continue.",
		},
	},

	messageUnpaused = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Unpaused by the mission.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
