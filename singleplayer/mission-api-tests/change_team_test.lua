---
--- ChangeTeam action test mission, for teams 'player' and 'enemy' of the mission API test start script.
---
--- The mission moves the player to team 'enemy' at 5 s. Ordering the enemy constructor proves the
--- player controls that team, and moves the player back to team 'player'.
--- Giving team 'enemy' an AI in the start script must log a validation warning for 'changeToPlayer'.
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	spawnConstructors = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'spawnConstructors', 'messageIntro' },
	},

	switchToEnemy = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'changeToEnemy', 'messageOnEnemy' },
	},

	enemyConstructorOrdered = {
		type = triggerTypes.UnitOrdered,
		parameters = {
			command = CMD.ANY,
			unitName = 'enemyConstructor',
		},
		actions = { 'changeToPlayer', 'messageOnPlayer' },
	},
}

local actions = {

	spawnConstructors = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armck', x = 1800, z = 1600, team = 0 },
				{ unitDefName = 'corck', x = 2000, z = 1600, team = 1, unitName = 'enemyConstructor' },
			},
		},
	},

	changeToEnemy = {
		type = actionTypes.ChangeTeam,
		parameters = {
			oldTeam = 'player',
			newTeam = 'enemy',
		},
	},

	changeToPlayer = {
		type = actionTypes.ChangeTeam,
		parameters = {
			oldTeam = 'enemy',
			newTeam = 'player',
		},
	},

	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "ChangeTeam test: at 5 s the mission moves you to the enemy team.",
		},
	},

	messageOnEnemy = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "You are on the enemy team now. Order the enemy constructor to move back.",
		},
	},

	messageOnPlayer = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "You are back on the player team, and control the Armada constructor again.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
