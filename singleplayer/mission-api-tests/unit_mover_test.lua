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

    teleportTanksWithoutSetDirection2 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 20,
		},
		actions = { 'teleportTanksWithoutSetDirection1' },
	},

	teleportTanksWithSetAngle1 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 25,
		},
		actions = { 'teleportTanksWithSetAngle1' },
	},

	teleportTanksWithSetAngle2 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 27,
		},
		actions = { 'teleportTanksWithSetAngle2' },
	},

	teleportTanksWithSetAngle3 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 29,
		},
		actions = { 'teleportTanksWithSetAngle3' },
	},

	teleportTanksWithSetAngle4 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 31,
		},
		actions = { 'teleportTanksWithSetAngle4' },
	},

	teleportTanksWithSetAngle5 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 33,
		},
		actions = { 'teleportTanksWithSetAngle5' },
	},

	teleportTanksWithSetAngle6 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 35,
		},
		actions = { 'teleportTanksWithSetAngle6' },
	},

	teleportTanksWithSetAngle7 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 37,
		},
		actions = { 'teleportTanksWithSetAngle7' },
	},

	teleportTanksWithSetAngle8 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 39,
		},
		actions = { 'teleportTanksWithSetAngle8' },
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
					quantity = 1
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
		},
    },

	teleportTanksWithSetAngle1 = {
        type = actionTypes.MoveUnits,
		parameters = {
            unitName = "tanks",
			position = {
				x = 3000,
				z = 3000,
			},
			direction = {
				angle = 0,
			},
		},
    },

	teleportTanksWithSetAngle2 = {
        type = actionTypes.MoveUnits,
		parameters = {
            unitName = "tanks",
			position = {
				x = 3000,
				z = 3000,
			},
			direction = {
				angle = 90,
			},
		},
    },

	teleportTanksWithSetAngle3 = {
        type = actionTypes.MoveUnits,
		parameters = {
            unitName = "tanks",
			position = {
				x = 3000,
				z = 3000,
			},
			direction = {
				angle = 180,
			},
		},
    },

	teleportTanksWithSetAngle4 = {
        type = actionTypes.MoveUnits,
		parameters = {
            unitName = "tanks",
			position = {
				x = 3000,
				z = 3000,
			},
			direction = {
				angle = 270,
			},
		},
    },

	teleportTanksWithSetAngle5 = {
        type = actionTypes.MoveUnits,
		parameters = {
            unitName = "tanks",
			position = {
				x = 3000,
				z = 3000,
			},
			direction = {
				angle = 360,
			},
		},
    },

	teleportTanksWithSetAngle6 = {
        type = actionTypes.MoveUnits,
		parameters = {
            unitName = "tanks",
			position = {
				x = 3000,
				z = 3000,
			},
			direction = {
				angle = 450,
			},
		},
    },

	teleportTanksWithSetAngle7 = {
        type = actionTypes.MoveUnits,
		parameters = {
            unitName = "tanks",
			position = {
				x = 3000,
				z = 3000,
			},
			direction = {
				angle = -90,
			},
		},
    },

	teleportTanksWithSetAngle8 = {
        type = actionTypes.MoveUnits,
		parameters = {
            unitName = "tanks",
			position = {
				x = 3000,
				z = 3000,
				y = 3000,
			},
			direction = {
				angle = -90,
			},
		},
    },
}

return {
	Triggers = triggers,
	Actions = actions,
}
