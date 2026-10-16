---
--- Camera actions test mission.
---
--- Saves the camera and locks input, then flies in from outside the map, orbits the hero tank,
--- follows the raiders, shakes, restores the saved camera and plays a last sequence that hands
--- the camera back where it ends. Each step is announced in the chat.
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	spawn = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'spawnUnits', 'raidersMove', 'messageIntro' },
	},

	saveAndLock = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 2,
		},
		actions = { 'saveCamera', 'lockInput' },
	},

	flyIn = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 3,
		},
		actions = { 'messageFlyIn', 'flyIn' },
	},

	orbit = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 15,
		},
		actions = { 'messageOrbit', 'orbitHero' },
	},

	follow = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 25,
		},
		actions = { 'messageFollow', 'followRaiders' },
	},

	shake = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 30,
		},
		actions = { 'messageShake', 'shake', 'nuke' },
	},

	restore = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 36,
		},
		actions = { 'messageRestore', 'restoreCamera' },
	},

	release = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 45,
		},
		actions = { 'messageRelease', 'releaseSequence' },
	},

	unlock = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 52,
		},
		actions = { 'unlockInput', 'messageDone' },
	},
}

local actions = {

	spawnUnits = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armstump', x = 1800, z = 1600, team = 0, unitName = 'hero' },
				{ unitDefName = 'armpw', x = 1900, z = 1700, team = 0, unitName = 'raiders' },
				{ unitDefName = 'armpw', x = 1950, z = 1750, team = 0, unitName = 'raiders' },
				{ unitDefName = 'armpw', x = 1850, z = 1750, team = 0, unitName = 'raiders' },
			},
		},
	},

	raidersMove = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'raiders',
			orders = {
				{ CMD.MOVE, { 1500, 0, 1400 } },
			},
		},
	},

	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Camera test: the camera is saved at 2 s and you are locked out until 52 s. Esc still opens the quit dialog.",
		},
	},

	saveCamera = {
		type = actionTypes.SaveCamera,
		parameters = {
			slot = 'playerView',
		},
	},

	lockInput = {
		type = actionTypes.LockPlayerInput,
		parameters = {},
	},

	messageFlyIn = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "3 s: cut to a vantage point beyond the map edge, then a spline fly-in that keeps looking at the hero tank.",
		},
	},

	flyIn = {
		type = actionTypes.PlayCameraSequence,
		parameters = {
			keyframes = {
				{ position = { x = -400, y = 900, z = 1600 }, lookAtUnitName = 'hero', duration = 0 },
				{
					position = { x = 900, y = 500, z = 900 },
					lookAtUnitName = 'hero',
					duration = 5,
					path = 'spline',
				},
				{
					position = { x = 1500, y = 220, z = 1350 },
					lookAtUnitName = 'hero',
					duration = 4,
					hold = 2,
					path = 'spline',
					fov = 55,
				},
			},
			onEnd = 'hold',
		},
	},

	messageOrbit = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "15 s: half an orbit around the hero.",
		},
	},

	orbitHero = {
		type = actionTypes.OrbitCamera,
		parameters = {
			unitName = 'hero',
			distance = 500,
			pitch = 40,
			degrees = 180,
			duration = 8,
			transitionDuration = 1.5,
			onEnd = 'hold',
		},
	},

	messageFollow = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "25 s: following the raiders until the camera is restored.",
		},
	},

	followRaiders = {
		type = actionTypes.FollowCamera,
		parameters = {
			unitName = 'raiders',
			distance = 450,
			pitch = 50,
			yaw = 225,
			transitionDuration = 2,
		},
	},

	messageShake = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "30 s: a scripted shake, and a nuke far away for the regular explosion shake.",
		},
	},

	shake = {
		type = actionTypes.ShakeCamera,
		parameters = {
			magnitude = 25,
			duration = 3,
			rampUp = 0.3,
			falloff = 1.5,
			rotationMagnitude = 1.5,
		},
	},

	nuke = {
		type = actionTypes.SpawnExplosion,
		parameters = {
			weaponDefName = 'armsilo_nuclear_missile',
			position = { x = 3200, z = 3200 },
		},
	},

	messageRestore = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "36 s: blending back to the camera saved at 2 s.",
		},
	},

	restoreCamera = {
		type = actionTypes.RestoreCamera,
		parameters = {
			slot = 'playerView',
			duration = 2,
		},
	},

	messageRelease = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "45 s: the eye flies one spline while the focus sweeps another across the base plateau; the camera is then handed back where it ends.",
		},
	},

	-- The camera and the point it looks at each follow their own spline.
	releaseSequence = {
		type = actionTypes.PlayCameraSequence,
		parameters = {
			keyframes = {
				{ position = { x = 2200, y = 300, z = 2200 }, lookAtPosition = { x = 1800, z = 1600 }, duration = 0 },
				{
					position = { x = 1900, y = 420, z = 2500 },
					lookAtPosition = { x = 2050, z = 1450 },
					duration = 3,
					path = 'spline',
				},
				{
					position = { x = 1400, y = 250, z = 2100 },
					lookAtPosition = { x = 1600, z = 1850 },
					roll = 8,
					duration = 3,
					path = 'spline',
					easing = 'inOutCubic',
				},
			},
		},
	},

	unlockInput = {
		type = actionTypes.UnlockPlayerInput,
		parameters = {},
	},

	messageDone = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "52 s: unlocked. Camera test done.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
