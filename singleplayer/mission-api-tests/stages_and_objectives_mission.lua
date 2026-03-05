local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local initialStage = 'initial'
local stages = {

	initial = {
		title = "Initial stage", -- Displayed in the UI
		objectives = {
			camWait = {
				text = "Wait for camera movement to finish.", -- Displayed in the UI along with countdown
				timer = 210, -- Complete objective after 210 game frames
			},
		},
		nextStage = 'buildBots', -- Transition to this stage when all objectives are complete
	},

	buildBots = {
		title = "Build some bots",
		objectives = {
			buildPawns = {
				text = "Build 5 pawns.", -- Display "3/5" progress next to text
				unitName = 'the-bots', -- Units to count for this objective
				amount = 5, -- Complete objective when 5 units have been built
			},
		},
		nextStage = "destroyEnemies",
	},

	destroyEnemies = {
		title = "Choose an enemy to destroy",
		objectives = {
			destroyArmada = {
				text = "Destroy the Armada base.",
				unitName = 'armada-base-units',
				amount = 0, -- Complete objective when all units with the name 'armada-base-units' are destroyed
				nextStage = "cortexVictory", -- Transition when this objective is complete
			},
			destroyCortex = {
				text = "Destroy the Cortex base.",
				unitName = 'cortex-base-units',
				amount = 0,
				nextStage = "armadaVictory",
			},
		},
	},
}

local triggers = {

	nameArmadaBase = {
		type = triggerTypes.NameUnits,
		parameters = {
			gameFrame = 1,
		},
		actions = { 'nameArmadaBase' },
	},

	nameCortexBase = {
		type = triggerTypes.NameUnits,
		parameters = {
			gameFrame = 1,
		},
		actions = { 'nameCortexBase' },
	},

	nameCons = {
		type = triggerTypes.UnitExists,
		settings = {
			repeating = true,
			stages = { 'buildBots' }, -- only trigger in these stages
		},
		parameters = {
			unitNameToGive = 'the-bots',
			unitDefName = 'armpw',
			teamID = 0,
		},
	},
}

local actions = {

	nameArmadaBase = {
		type = actionTypes.NameUnits,
		parameters = {
			unitNameToGive = 'armada-base-units',
			teamID = 1,
			unitDefName = 'armlab',
		},
	},

	nameCortexBase = {
		type = actionTypes.NameUnits,
		parameters = {
			unitNameToGive = 'cortex-base-units',
			teamID = 2,
			unitDefName = 'corlab',
		},
	},

	stageBuildBots = {
		type = actionTypes.SetStage,
		parameters = {
			stage = 'buildBots',
		},
	},

	-- There'll also be actions for updating objectives
}

return {
	initialStage = initialStage,
	Stages = stages,
	Triggers = triggers,
	Actions = actions,
}
