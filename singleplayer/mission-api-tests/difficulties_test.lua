-- Difficulty-dependent parameters: every difficulties table resolves to the value for
-- GG['MissionAPI'].Difficulty, else the nearest specified difficulty below it, else the lowest
-- specified one. While no difficulty source is wired up, the default is the lowest difficulty
-- (Story): Story entries win where authored, everything else resolves to its lowest specified
-- value, and the Medium/Hard-gated trigger never fires.

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local stages = {
	main = { objectives = { 'surviveWaves' } },
}

local objectives = {
	surviveWaves = {
		textKey = 'survive',
		amount = {
			difficulties = { Easy = 2, Medium = 3, Hard = 4 },
		},
		trigger = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = {
					difficulties = { Easy = 30, Hard = 20 },
				},
				interval = {
					difficulties = { Easy = 30, Hard = 20 },
				},
			},
		},
	},
}

local triggers = {
	announceDifficulty = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'announceDifficulty' },
	},

	spawnWave = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = {
				difficulties = { Easy = 15, Hard = 8 },
			},
		},
		actions = { 'spawnWave', 'announceWave' },
	},

	hardOnly = {
		type = triggerTypes.TimeElapsed,
		settings = {
			difficulties = { 'Medium', 'Hard' },
		},
		parameters = {
			seconds = 5,
		},
		actions = { 'announceHardOnly' },
	},

	clearWave = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = {
				difficulties = { Easy = 25, Hard = 14 },
			},
		},
		actions = { 'clearWave' },
	},
}

local actions = {
	announceDifficulty = {
		type = actionTypes.SendMessage,
		parameters = {
			message = {
				difficulties = {
					Story = 'Resolved the Story message.',
					Easy = 'Resolved the Easy message.',
					Medium = 'Resolved the Medium message.',
					Hard = 'Resolved the Hard message.',
				},
			},
		},
	},

	spawnWave = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				difficulties = {
					Easy = {
						{ unitDefName = 'armpw', x = 1800, z = 1600, facing = 's', team = 0, unitName = 'wave', quantity = 2, spacing = 32 },
					},
					Hard = {
						{ unitDefName = 'armpw', x = 1800, z = 1600, facing = 's', team = 0, unitName = 'wave', quantity = 8, spacing = 32 },
					},
				},
			},
		},
	},

	announceWave = {
		type = actionTypes.SendMessage,
		parameters = {
			message = {
				difficulties = {
					Easy = 'Wave spawned: 2 Pawns (Easy).',
					Hard = 'Wave spawned: 8 Pawns (Hard).',
				},
			},
		},
	},

	announceHardOnly = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'This trigger is gated to Medium and Hard.',
		},
	},

	clearWave = {
		type = actionTypes.DestroyUnits,
		parameters = {
			unitName = 'wave',
		},
	},
}

return {
	InitialStage = 'main',
	Stages = stages,
	Objectives = objectives,
	Triggers = triggers,
	Actions = actions,
}
