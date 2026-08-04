local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {
    spawnTanks = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 90,
		},
		actions = { 'spawnTanks' },
	},

    teleportTanksWithoutSetDirection = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 150,
		},
		actions = { 'teleportTanksWithoutSetDirection1' },
	},

    teleportTanksWithSetDirection1 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 300,
		},
		actions = { 'teleportTanksWithSetDirection1' },
	},

    teleportTanksWithSetDirection2 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 450,
		},
		actions = { 'teleportTanksWithSetDirection2' },
	},

    teleportTanksWithSetDirection3 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 600,
		},
		actions = { 'teleportTanksWithSetDirection3' },
	},

    teleportTanksWithoutSetDirection2 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 750,
		},
		actions = { 'teleportTanksWithoutSetDirection1' },
	},

    rotateTanksTowardsCenterOfTheGroup = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 900,
		},
		actions = { 'rotateTanksTowardsCenterOfTheGroup' },
	},
}

local actions = {

    spawnTanks = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{
					unitDefName = 'armstump',
					x = 2300,
					z = 1900,
					team = 0,
					unitName = 'tanks',
					quantity = 10
				},
			},
		},
	},

    teleportTanksWithoutSetDirection1 = {
        type = actionTypes.MoveUnits,
		parameters = {
            unitName = "tanks",
            position = {
				x = 2500,
				z = 2000,
			},
            randomRadius = 300,
		},
    },

    teleportTanksWithSetDirection1 = {
        type = actionTypes.MoveUnits,
		parameters = {
            unitName = "tanks",
			position = {
				x = 2500,
				z = 2000,
			},
			direction = {
				x = 3000,
				z = 3000,
			},
            randomRadius = 300,
		},
    },

    teleportTanksWithSetDirection2 = {
        type = actionTypes.MoveUnits,
		parameters = {
            unitName = "tanks",
			position = {
				x = 2500,
				z = 2000,
			},
			direction = {
				x = 1000,
				z = 1000,
			},
            randomRadius = 300,
		},
    },

    teleportTanksWithSetDirection3 = {
        type = actionTypes.MoveUnits,
		parameters = {
            unitName = "tanks",
			position = {
				x = 2500,
				z = 2000,
			},
			direction = {
				x = 2500,
				z = 2000,
			},
            randomRadius = 300,
		},
    },

    rotateTanksTowardsCenterOfTheGroup = {
		type = actionTypes.RotateUnits,
		parameters = {
            unitName = "tanks",
			direction = {
				x = 2500,
				z = 2000,
			},
		},
	},

}

return {
	Triggers = triggers,
	Actions = actions,
}