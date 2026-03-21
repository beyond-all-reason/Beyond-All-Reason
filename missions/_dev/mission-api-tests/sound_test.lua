local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {

	spawnEye = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1,
		},
		actions = { 'spawnEye' },
	},

	soundPosition = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
		},
		parameters = {
			gameFrame = 30,
			interval = 210,
		},
		actions = { 'playSoundPosition', 'messageSoundPosition' },
	},

	soundsQueued = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
		},
		parameters = {
			gameFrame = 90,
			interval = 210,
		},
		actions = { 'playVoiceQueued1', 'playVoiceQueued2', 'messageSoundsQueued' },
	},

	soundNotification = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
		},
		parameters = {
			gameFrame = 90,
			interval = 210,
		},
		actions = { 'playSoundNotification', 'messageSoundNotification' },
	},
}

local actions = {

	spawnEye = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'armeyes',
			teamID = 0,
			position = { x = 1800, z = 1600 },
		},
	},

	playSoundPosition = {
		type = actionTypes.PlaySound,
		parameters = {
			soundfile = 'sounds/weapons-mult/mgun12.wav',
			volume = 3.5,
			position = { x = 1800, z = 1600 },
		},
	},

	messageSoundPosition = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Play sound at (1800, 1600)",
		},
	},

	playVoiceQueued1 = {
		type = actionTypes.PlaySound,
		parameters = {
			soundfile = 'sounds/voice/en/cephis/UnitReady/BehemothIsReady2.wav',
			enqueue = true,
		},
	},

	playVoiceQueued2 = {
		type = actionTypes.PlaySound,
		parameters = {
			soundfile = 'sounds/voice/en/winter/EnemyCommanderDied.wav',
			enqueue = true,
		},
	},

	messageSoundsQueued = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Two voice sounds in succession",
		},
	},

	playSoundNotification = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'armsilo',
			teamID = 1,
			position = { x = 1900, z = 1800 },
		},
	},

	messageSoundNotification = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Nuke spotted, after the other two voices.",
		},
	},
}

return {
	LobbyData = lobbyData,
	StartScript = startScript,
	Triggers = triggers,
	Actions = actions,
}
