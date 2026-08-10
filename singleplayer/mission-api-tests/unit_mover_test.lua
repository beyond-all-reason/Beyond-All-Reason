local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {
    spawnTanks = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 3,
		},
		actions = { 'spawnTanks' },
	},

    teleportTanksWithoutSetDirection = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'teleportTanksWithoutSetDirection1' },
	},

    teleportTanksWithSetDirection1 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 10,
		},
		actions = { 'teleportTanksWithSetDirection1' },
	},

    teleportTanksWithSetDirection2 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 15,
		},
		actions = { 'teleportTanksWithSetDirection2' },
	},

    teleportTanksWithSetDirection3 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 20,
		},
		actions = { 'teleportTanksWithSetDirection3' },
	},

    teleportTanksWithoutSetDirection2 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 25,
		},
		actions = { 'teleportTanksWithoutSetDirection1' },
	},

    rotateTanksTowardsCenterOfTheGroup = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 30,
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