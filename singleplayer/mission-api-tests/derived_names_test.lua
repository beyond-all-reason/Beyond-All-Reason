local conditionTypes = GG['MissionAPI'].ConditionDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

-- The army is every unit of the player's team, except the commander, pawn 7, and the bot lab.
-- The lab builds one more pawn, which joins the army when it is finished. The army then marches
-- to the outpost, with the commander and pawn 7 alongside, and only army units count as arriving.
-- Once every member is there, the army is disbanded, and its count returns to zero.

local outpost = { x = 2600, z = 1800, radius = 250 }

local triggers = {

	raiseArmy = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'addArmy', 'buildPawn' },
	},

	-- The new pawn is a member before UnitFinished's triggers run, so this sees it.
	recruitFinished = {
		type = conditionTypes.ConstructionFinished,
		parameters = {
			unitName = 'army',
		},
		actions = { 'messageRecruitFinished', 'countDownToMarch' },
	},

	march = {
		type = conditionTypes.CountdownFinished,
		parameters = {
			countdownID = 'march',
		},
		actions = { 'marchArmy', 'marchCommander', 'marchPawn7' },
	},

	armyEnteredOutpost = {
		type = conditionTypes.UnitEnteredLocation,
		parameters = {
			unitName = 'army',
			area = outpost,
		},
		settings = {
			repeating = true,
		},
		actions = { 'messageArmyEnteredOutpost' },
	},

	commanderEnteredOutpost = {
		type = conditionTypes.UnitEnteredLocation,
		parameters = {
			unitName = 'commander',
			area = outpost,
		},
		actions = { 'messageCommanderEnteredOutpost' },
	},

	armyGathered = {
		type = conditionTypes.UnitsGatheredInLocation,
		parameters = {
			unitName = 'army',
			teamName = 'player',
			area = outpost,
		},
		actions = { 'messageArmyGathered', 'disbandArmy' },
	},

	-- Fires when the count returns to 0, which only the disbanding does here.
	armyDisbanded = {
		type = conditionTypes.UnitsOwned,
		parameters = {
			teamName = 'player',
			unitName = 'army',
		},
		atMost = 0,
		actions = { 'messageArmyDisbanded' },
	},

}

local actions = {

	addArmy = {
		type = actionTypes.AddDerivedUnitName,
		parameters = {
			unitName = 'army',
			filter = { teamName = 'player' },
			except = {
				{ unitName = 'commander' },
				{ unitName = 'pawn7' },
				{ unitDefName = 'armlab' },
			},
		},
	},

	buildPawn = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'lab',
			orders = {
				{ 'armpw', {} },
			},
		},
	},

	countDownToMarch = {
		type = actionTypes.AddCountdown,
		parameters = {
			countdownID = 'march',
			seconds = 3,
		},
	},

	marchArmy = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'army',
			orders = {
				{ CMD.MOVE, { outpost.x, 0, outpost.z } },
			},
		},
	},

	marchCommander = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'commander',
			orders = {
				{ CMD.MOVE, { outpost.x, 0, outpost.z } },
			},
		},
	},

	marchPawn7 = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'pawn7',
			orders = {
				{ CMD.MOVE, { outpost.x, 0, outpost.z } },
			},
		},
	},

	disbandArmy = {
		type = actionTypes.RemoveDerivedUnitName,
		parameters = {
			unitName = 'army',
		},
	},

	messageRecruitFinished = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "The lab finished a pawn, and it joined the army.",
		},
	},

	messageArmyEnteredOutpost = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "An army unit reached the outpost.",
		},
	},

	messageCommanderEnteredOutpost = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "The commander reached the outpost, and is not in the army count.",
		},
	},

	messageArmyGathered = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "The whole army is at the outpost, less the commander and pawn 7.",
		},
	},

	messageArmyDisbanded = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "The army is disbanded, and its count is back to zero.",
		},
	},

}

local unitLoadout = {
	{ unitDefName = 'armcom', position = { x = 1800, z = 2400 }, teamName = 'player', unitName = 'commander' },
	{ unitDefName = 'armpw',  position = { x = 1900, z = 2500 }, teamName = 'player', unitName = 'pawn7' },
	{ unitDefName = 'armpw',  position = { x = 2000, z = 2400 }, teamName = 'player', quantity = 2 },
	{ unitDefName = 'armck',  position = { x = 2000, z = 2550 }, teamName = 'player' },
	{ unitDefName = 'armlab', position = { x = 1700, z = 2100 }, orientation = 's', teamName = 'player', unitName = 'lab' },
}

return {
	Triggers = triggers,
	Actions = actions,
	UnitLoadout = unitLoadout,
}
