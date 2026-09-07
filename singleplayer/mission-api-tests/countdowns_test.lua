---
--- Test mission demonstrating the countdown actions and triggers.
---
--- Countdowns tick down once per second, and a new countdown is held through
--- its first tick, so a countdown added at 1s takes its first tick at 3s.
--- SetTime restarts a countdown, so it is held through its next tick again.
---
--- Expected timeline:
---    1s: 'alpha' (5s), 'doomed' (20s), 'held' (10s) and 'adjusted' (30s) are added
---    3s: 'held' is paused, at 9 seconds remaining
---    4s: 'doomed' is cancelled; its CountdownFinished message must never appear
---    4s: 'adjusted' is set to 10 seconds (held again through the 5s tick)
---    5s: message: alpha reached 2 seconds remaining
---    6s: 'held' is unpaused; 'adjusted' gets 5 seconds added (14 remaining)
---    7s: objective 'surviveAlpha' completes ('alpha' finished)
---    7s: message: held reached 8 seconds remaining
---    8s: 'adjusted' has 9 seconds removed (3 remaining)
---   10s: message: adjusted reached 1 second remaining
---   11s: message: adjusted finished (its 30s end here only if all three adjustments applied)
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
		actions = { 'addAlpha', 'addDoomed', 'addHeld', 'addAdjusted' },
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

	setAdjusted = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 4,
		},
		actions = { 'setAdjusted' },
	},

	addAdjustedTime = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 6,
		},
		actions = { 'addAdjustedTime' },
	},

	removeAdjustedTime = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 8,
		},
		actions = { 'removeAdjustedTime' },
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

	adjustedReached = {
		type = triggerTypes.CountdownReached,
		parameters = {
			countdownID = 'adjusted',
			timeRemaining = 1,
		},
		actions = { 'messageAdjustedReached' },
	},

	adjustedFinished = {
		type = triggerTypes.CountdownFinished,
		parameters = {
			countdownID = 'adjusted',
		},
		actions = { 'messageAdjustedFinished' },
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

	addAdjusted = {
		type = actionTypes.AddCountdown,
		parameters = {
			countdownID = 'adjusted',
			seconds = 30,
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

	setAdjusted = {
		type = actionTypes.SetTime,
		parameters = {
			countdownID = 'adjusted',
			seconds = 10,
		},
	},

	addAdjustedTime = {
		type = actionTypes.AddTime,
		parameters = {
			countdownID = 'adjusted',
			seconds = 5,
		},
	},

	removeAdjustedTime = {
		type = actionTypes.RemoveTime,
		parameters = {
			countdownID = 'adjusted',
			seconds = 9,
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

	messageAdjustedReached = {
		type = actionTypes.SendMessage,
		parameters = {
			message = '[Countdowns test] adjusted reached 1 second remaining (expected at 10s)',
		},
	},

	messageAdjustedFinished = {
		type = actionTypes.SendMessage,
		parameters = {
			message = '[Countdowns test] adjusted finished (expected at 11s: set to 10 at 4s, +5 at 6s, -9 at 8s)',
		},
	},
}

return {
	Objectives = objectives,
	Triggers = triggers,
	Actions = actions,
}
