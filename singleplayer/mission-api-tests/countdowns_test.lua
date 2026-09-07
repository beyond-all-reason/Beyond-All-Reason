---
--- Test mission demonstrating the countdown actions and triggers.
---
--- Countdowns tick down once per second, and a new countdown is held through
--- its first tick, so a countdown added at 1s takes its first tick at 3s.
---
--- Expected timeline:
---    1s: 'alpha' (5s), 'doomed' (20s) and 'held' (10s) are added
---    3s: 'held' is paused, at 9 seconds remaining
---    4s: 'doomed' is cancelled; its CountdownFinished message must never appear
---    5s: message: alpha reached 2 seconds remaining
---    7s: objective 'surviveAlpha' completes ('alpha' finished)
---    7s: message: held reached 8 seconds remaining (ticking again after unpause at 6s)
---   15s: message: held finished (3 seconds later than it would have without the pause)
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local objectives = {

	surviveAlpha = {
		textKey = 'survive_alpha_countdown',
		trigger = {
			type = triggerTypes.CountdownFinished,
			parameters = {
				countdownID = 'alpha',
			},
		},
	},
}

local triggers = {

	addCountdowns = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'addAlpha', 'addDoomed', 'addHeld' },
	},

	pauseHeld = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 3,
		},
		actions = { 'pauseHeld' },
	},

	cancelDoomed = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 4,
		},
		actions = { 'cancelDoomed' },
	},

	unpauseHeld = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 6,
		},
		actions = { 'unpauseHeld' },
	},

	alphaReached = {
		type = triggerTypes.CountdownReached,
		parameters = {
			countdownID = 'alpha',
			timeRemaining = 2,
		},
		actions = { 'messageAlphaReached' },
	},

	heldReached = {
		type = triggerTypes.CountdownReached,
		parameters = {
			countdownID = 'held',
			timeRemaining = 8,
		},
		actions = { 'messageHeldReached' },
	},

	heldFinished = {
		type = triggerTypes.CountdownFinished,
		parameters = {
			countdownID = 'held',
		},
		actions = { 'messageHeldFinished' },
	},

	doomedFinished = {
		type = triggerTypes.CountdownFinished,
		parameters = {
			countdownID = 'doomed',
		},
		actions = { 'messageDoomedFinished' },
	},
}

local actions = {

	addAlpha = {
		type = actionTypes.AddCountdown,
		parameters = {
			countdownID = 'alpha',
			seconds = 5,
		},
	},

	addDoomed = {
		type = actionTypes.AddCountdown,
		parameters = {
			countdownID = 'doomed',
			seconds = 20,
		},
	},

	addHeld = {
		type = actionTypes.AddCountdown,
		parameters = {
			countdownID = 'held',
			seconds = 10,
		},
	},

	pauseHeld = {
		type = actionTypes.PauseCountdown,
		parameters = {
			countdownID = 'held',
		},
	},

	cancelDoomed = {
		type = actionTypes.CancelCountdown,
		parameters = {
			countdownID = 'doomed',
		},
	},

	unpauseHeld = {
		type = actionTypes.UnpauseCountdown,
		parameters = {
			countdownID = 'held',
		},
	},

	messageAlphaReached = {
		type = actionTypes.SendMessage,
		parameters = {
			message = '[Countdowns test] alpha reached 2 seconds remaining (expected at 5s)',
		},
	},

	messageHeldReached = {
		type = actionTypes.SendMessage,
		parameters = {
			message = '[Countdowns test] held reached 8 seconds remaining (expected at 7s)',
		},
	},

	messageHeldFinished = {
		type = actionTypes.SendMessage,
		parameters = {
			message = '[Countdowns test] held finished (expected at 15s)',
		},
	},

	messageDoomedFinished = {
		type = actionTypes.SendMessage,
		parameters = {
			message = '[Countdowns test] THIS MUST NEVER APPEAR - doomed was cancelled',
		},
	},
}

return {
	Objectives = objectives,
	Triggers = triggers,
	Actions = actions,
}
