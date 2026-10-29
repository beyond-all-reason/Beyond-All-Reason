---
--- Map lighting actions test mission: SetMapLighting, SetMapTimeOfDay, SetMapSkybox, ResetMapLighting.
---
--- Each step is announced in chat. Grass, trees and the map edge must dim along with the ground and units.
--- lighting_test_skybox.dds is a 32 px cubemap with a coloured side per direction and a white square on each,
--- written by a short script (uncompressed BGRA DDS, DDSCAPS2_CUBEMAP, full mip chain).
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local SKYBOX = 'singleplayer/mission-api-tests/lighting_test_skybox.dds'

local function at(seconds, actions)
	return {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = seconds,
		},
		actions = actions,
	}
end

local function message(text)
	return {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = text,
		},
	}
end

local triggers = {
	spawn = at(1, { 'spawnUnits', 'messageIntro' }),
	dim = at(3, { 'dimWarm', 'messageDim' }),
	sun = at(8, { 'lowSunEast', 'messageSun' }),
	absolute = at(12, { 'blueLight', 'messageAbsolute' }),
	reset = at(16, { 'resetQuick', 'messageReset' }),
	evening = at(20, { 'evening', 'messageEvening' }),
	midnight = at(27, { 'midnight', 'messageMidnight' }),
	cycle = at(34, { 'dayCycle', 'messageCycle' }),
	skybox = at(84, { 'skybox', 'messageSkybox' }),
	skyboxTurned = at(90, { 'skyboxTurned', 'messageSkyboxTurned' }),
	resetAll = at(95, { 'resetSlow', 'messageResetAll' }),
	done = at(100, { 'messageDone' }),
}

local actions = {
	spawnUnits = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armpw', x = 1800, z = 1600, team = 0 },
				{ unitDefName = 'armpw', x = 1840, z = 1600, team = 0 },
				{ unitDefName = 'armpw', x = 1880, z = 1600, team = 0 },
				{ unitDefName = 'armllt', x = 1840, z = 1680, team = 0 },
			},
		},
	},

	dimWarm = {
		type = actionTypes.SetMapLighting,
		parameters = {
			brightness = 0.6,
			tint = { r = 1, g = 0.8, b = 0.6 },
			transitionDuration = 3,
		},
	},

	lowSunEast = {
		type = actionTypes.SetMapLighting,
		parameters = {
			sunAzimuth = 90,
			sunElevation = 15,
			transitionDuration = 2,
		},
	},

	blueLight = {
		type = actionTypes.SetMapLighting,
		parameters = {
			groundDiffuseColor = { r = 0.3, g = 0.4, b = 1 },
			unitDiffuseColor = { r = 0.3, g = 0.4, b = 1 },
			groundShadowDensity = 1,
			unitShadowDensity = 1,
		},
	},

	resetQuick = {
		type = actionTypes.ResetMapLighting,
		parameters = {
			transitionDuration = 2,
		},
	},

	evening = {
		type = actionTypes.SetMapTimeOfDay,
		parameters = {
			hour = 18,
			transitionDuration = 4,
		},
	},

	midnight = {
		type = actionTypes.SetMapTimeOfDay,
		parameters = {
			hour = 0,
			transitionDuration = 4,
		},
	},

	dayCycle = {
		type = actionTypes.SetMapTimeOfDay,
		parameters = {
			hour = 5,
			dayLength = 48,
		},
	},

	skybox = {
		type = actionTypes.SetMapSkybox,
		parameters = {
			texture = SKYBOX,
			rotation = 0,
		},
	},

	skyboxTurned = {
		type = actionTypes.SetMapSkybox,
		parameters = {
			texture = SKYBOX,
			rotation = 90,
		},
	},

	resetSlow = {
		type = actionTypes.ResetMapLighting,
		parameters = {
			transitionDuration = 3,
		},
	},

	messageIntro = message("Lighting test: lighting changes follow every few seconds; watch the units at the start."),
	messageDim = message("SetMapLighting: 60% brightness with a warm tint, over 3 s."),
	messageSun = message("SetMapLighting: low sun in the east (azimuth 90, elevation 15), over 2 s. Long shadows."),
	messageAbsolute = message("SetMapLighting: blue diffuse light and full shadows, at once."),
	messageReset = message("ResetMapLighting: back to the map's lighting over 2 s."),
	messageEvening = message("SetMapTimeOfDay 18:00 over 4 s: dimmer light in the map's own colours, the sun low and swung away from noon."),
	messageMidnight = message("SetMapTimeOfDay 0:00 over 4 s: past sunset into a dim light from the other side of the sky."),
	messageCycle = message("SetMapTimeOfDay 5:00 with a 48 s day: one full day. Pause the game: the sun must stop."),
	messageSkybox = message("SetMapSkybox: test cubemap, a different colour per side."),
	messageSkyboxTurned = message("SetMapSkybox: same cubemap turned by 90 degrees."),
	messageResetAll = message("ResetMapLighting over 3 s: the map's lighting and noon. The cubemap stays: this map has a procedural sky."),
	messageDone = message("Lighting test done."),
}

return {
	Triggers = triggers,
	Actions = actions,
}
