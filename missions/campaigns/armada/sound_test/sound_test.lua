local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	spawnEye = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 0,
		},
		actions = { 'spawnEye' },
	},

	soundPosition = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
		},
		parameters = {
			seconds = 1,
			interval = 7,
		},
		actions = { 'playSoundPosition', 'messageSoundPosition' },
	},

	soundsQueued = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
		},
		parameters = {
			seconds = 3,
			interval = 7,
		},
		actions = { 'playVoiceQueued1', 'playVoiceQueued2', 'messageSoundsQueued' },
	},

	soundNotification = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
		},
		parameters = {
			seconds = 3,
			interval = 7,
		},
		actions = { 'playSoundNotificationFromUnitDetection', 'messageSoundNotification' },
	},

	playMusic = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'playMusic', 'messageMusicNotification' },
	},
}

local actions = {

	spawnEye = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armeyes', x = 1800, z = 1600, teamName = 'thePlayerTeam' },
			},
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

	playMusic = {
		type = actionTypes.PlayMusic,
		parameters = {
			soundfile = 'music/original/events/aprilfools/menu/Ryan Krause - Friend or Foe ( Bassfahrer Metal Cover).ogg',
		},
	},


	messageSoundsQueued = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Two voice sounds in succession",
		},
	},

	playSoundNotificationFromUnitDetection = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armsilo', x = 1900, z = 1800, teamName = 'theEnemyTeam' },
			},
		},
	},

	messageSoundNotification = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Nuke spotted, after the other two voices.",
		},
	},

	messageMusicNotification = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Playing Trigger Music Track.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
