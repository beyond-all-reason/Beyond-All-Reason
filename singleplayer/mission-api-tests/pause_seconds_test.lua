--- Holds 5 s at 10 s and 3 s at 16 s, then plays on; the infolog times show each hold.
--- At 15 s an Unpause ends a 2 s pause at once, and its timer must not cut the 16 s hold short.
--- At 20 s an 8 s hold: order the flea to end it early.

local triggerTypes = GG["MissionAPI"].TriggerDefinitions.Types
local actionTypes = GG["MissionAPI"].ActionDefinitions.Types

local triggers = {

	spawnScout = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { "spawnScout", "messageIntro" },
	},

	hold = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 10,
		},
		actions = { "holdThenPlayOn", "messageHeld" },
	},

	playedOn = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 10.1,
		},
		actions = { "messagePlayedOn" },
	},

	unpausedEarly = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 15,
		},
		actions = { "stalePauseTimer", "unpause", "messageUnpausedEarly" },
	},

	laterHold = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 16,
		},
		actions = { "holdAfterStaleTimer", "messageLaterHeld" },
	},

	laterPlayedOn = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 16.1,
		},
		actions = { "messageLaterPlayedOn" },
	},

	longHold = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 20,
		},
		actions = { "longHoldEndedByOrder", "messageLongHeld" },
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
			unitName = "scout",
		},
		actions = { "unpause" },
	},

	longPlayedOn = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 20.1,
		},
		actions = { "messageLongPlayedOn" },
	},
}

local actions = {

	spawnScout = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = "armflea", position = { x = 1800, z = 1600 }, teamName = "player", unitName = "scout" },
			},
		},
	},

	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Pause with seconds test: holds at 10 s (5 s), 16 s (3 s) and 20 s (8 s, order the flea to end it).",
		},
	},

	holdThenPlayOn = {
		type = actionTypes.Pause,
		parameters = {
			seconds = 5,
		},
	},

	stalePauseTimer = {
		type = actionTypes.Pause,
		parameters = {
			seconds = 2,
		},
	},

	holdAfterStaleTimer = {
		type = actionTypes.Pause,
		parameters = {
			seconds = 3,
		},
	},

	longHoldEndedByOrder = {
		type = actionTypes.Pause,
		parameters = {
			seconds = 8,
		},
	},

	unpause = {
		type = actionTypes.Unpause,
	},

	messageHeld = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Held for 5 s: no pause screen.",
		},
	},

	messagePlayedOn = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Played on.",
		},
	},

	messageUnpausedEarly = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "A 2 s pause ended at once by Unpause.",
		},
	},

	messageLaterHeld = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Held for 3 s: the old 2 s timer must not end it.",
		},
	},

	messageLaterPlayedOn = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Played on after 3 s.",
		},
	},

	messageLongHeld = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Held for 8 s: order the flea to end it early.",
		},
	},

	messageLongPlayedOn = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Played on after the 8 s pause.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
