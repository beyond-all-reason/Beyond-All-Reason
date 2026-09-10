local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

-- An enemy attacks a named tank, which fires the trigger on the first hit and again on each hit
-- while repeating. An allied pawn self-destructs beside the tank first: the blast is a real weapon
-- with no attacker and no projectile, so nobody to blame, and must not fire the trigger. The enemy
-- spawns out of engagement range so that it cannot open fire before the self-destruct.

local triggers = {

	spawnScene = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'spawnTarget', 'spawnAlly', 'spawnEnemy' },
	},

	-- Split off the spawn, since an order does not take on the frame its target unit is spawned.
	allySelfDestructs = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 3,
		},
		actions = { 'selfDestructAlly' },
	},

	enemyAttacks = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 6,
		},
		actions = { 'orderEnemyAttack' },
	},

	-- Never fires before the enemy attacks: the self-destruct is allied, environmental damage.
	targetAttacked = {
		type = triggerTypes.UnitAttacked,
		parameters = {
			unitName = 'target',
		},
		actions = { 'messageTargetAttacked' },
	},

	tankAttackedRepeatedly = {
		type = triggerTypes.UnitAttacked,
		parameters = {
			unitDefName = 'armstump',
			teamID = 0,
		},
		settings = {
			repeating = true,
			maxRepeats = 3,
		},
		actions = { 'messageTankHit' },
	},

	-- Never fires: the tank belongs to team 0.
	wrongTeamAttacked = {
		type = triggerTypes.UnitAttacked,
		parameters = {
			unitDefName = 'armstump',
			teamID = 1,
		},
		actions = { 'messageWrongTeam' },
	},

}

local actions = {

	spawnTarget = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armstump', x = 2400, z = 2400, team = 0, unitName = 'target' },
			},
		},
	},

	spawnAlly = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armpw', x = 2440, z = 2400, team = 0, unitName = 'ally' },
			},
		},
	},

	spawnEnemy = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corak', x = 3300, z = 2400, team = 1, unitName = 'enemy' },
			},
		},
	},

	selfDestructAlly = {
		type = actionTypes.SelfDestructUnits,
		parameters = {
			unitName = 'ally',
		},
	},

	orderEnemyAttack = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'enemy',
			orders = {
				{ CMD.ATTACK, { unitName = 'target' } },
			},
		},
	},

	messageTargetAttacked = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The target was attacked!",
		},
	},

	messageTankHit = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "A tank on team 0 took a hit!",
		},
	},

	messageWrongTeam = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "BUG: an attack on team 0 counted for team 1!",
		},
	},

}

return {
	Triggers = triggers,
	Actions = actions,
}
