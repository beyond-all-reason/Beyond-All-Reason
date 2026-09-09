local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

-- The mission gives the player a wind generator, which UnitReceived sees only when asked to see
-- mission actions, and has the player capture another, which UnitCaptured sees the same way.
-- A decoy commander captures a third one, which UnitReceived never sees.
-- The start script needs a second team for the units the player receives.

local triggers = {

	spawnScene = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'spawnGift', 'spawnSpoils', 'spawnPrize', 'spawnDecoy' },
	},

	-- Split off the spawn, since an order does not take on the frame its target unit is spawned.
	giveAndCapture = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 3,
		},
		actions = { 'transferGift', 'transferSpoils', 'orderDecoyCapture' },
	},

	giftReceived = {
		type = triggerTypes.UnitReceived,
		parameters = {
			unitName = 'gift',
			oldTeamID = 1,
			newTeamID = 0,
			ignoreMissionActions = false,
		},
		actions = { 'messageGiftReceived' },
	},

	-- Never fires: mission transfers are ignored unless asked for.
	giftReceivedByDefault = {
		type = triggerTypes.UnitReceived,
		parameters = {
			unitName = 'gift',
		},
		actions = { 'messageGiftReceivedByDefault' },
	},

	-- Never fires: a mission gift is not a capture, however it passes the sharing rules.
	giftCaptured = {
		type = triggerTypes.UnitCaptured,
		parameters = {
			unitName = 'gift',
			ignoreMissionActions = false,
		},
		actions = { 'messageGiftCaptured' },
	},

	spoilsCaptured = {
		type = triggerTypes.UnitCaptured,
		parameters = {
			unitName = 'spoils',
			ignoreMissionActions = false,
		},
		actions = { 'messageSpoilsCaptured' },
	},

	-- Never fires: a mission capture is not a gift.
	spoilsReceived = {
		type = triggerTypes.UnitReceived,
		parameters = {
			unitName = 'spoils',
			ignoreMissionActions = false,
		},
		actions = { 'messageSpoilsReceived' },
	},

	prizeCaptured = {
		type = triggerTypes.UnitCaptured,
		parameters = {
			unitName = 'prize',
		},
		actions = { 'messagePrizeCaptured' },
	},

	-- Never fires: captures belong to UnitCaptured.
	prizeReceived = {
		type = triggerTypes.UnitReceived,
		parameters = {
			unitName = 'prize',
		},
		actions = { 'messagePrizeReceived' },
	},

	-- Fires for a wind generator shared by a player, which nothing in this mission does on its own.
	windShared = {
		type = triggerTypes.UnitReceived,
		parameters = {
			unitDefName = 'armwin',
			newTeamID = 0,
		},
		actions = { 'messageWindShared' },
	},

}

local actions = {

	spawnGift = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armwin', x = 2400, z = 2400, team = 1, unitName = 'gift' },
			},
		},
	},

	spawnSpoils = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armwin', x = 2600, z = 2400, team = 1, unitName = 'spoils' },
			},
		},
	},

	spawnPrize = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armwin', x = 1600, z = 2800, team = 1, unitName = 'prize' },
			},
		},
	},

	spawnDecoy = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armdecom', x = 1750, z = 2800, team = 0, unitName = 'decoy', orders = { { CMD.FIRE_STATE, CMD.FIRESTATE_HOLDFIRE } } },
			},
		},
	},

	transferGift = {
		type = actionTypes.TransferUnits,
		parameters = {
			unitName = 'gift',
			newTeam = 0,
		},
	},

	transferSpoils = {
		type = actionTypes.TransferUnits,
		parameters = {
			unitName = 'spoils',
			newTeam = 0,
			captured = true,
		},
	},

	orderDecoyCapture = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'decoy',
			orders = {
				{ CMD.CAPTURE, { unitName = 'prize' } },
			},
		},
	},

	messageGiftReceived = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The mission gave the player a wind generator!",
		},
	},

	messageGiftReceivedByDefault = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "BUG: a mission transfer fired with ignoreMissionActions unset!",
		},
	},

	messageGiftCaptured = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "BUG: a mission gift counted as a capture!",
		},
	},

	messageSpoilsCaptured = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The mission had the player capture a wind generator!",
		},
	},

	messageSpoilsReceived = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "BUG: a mission capture counted as a received unit!",
		},
	},

	messagePrizeCaptured = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The decoy captured the prize!",
		},
	},

	messagePrizeReceived = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "BUG: a capture counted as a received unit!",
		},
	},

	messageWindShared = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "A wind generator was shared to the player!",
		},
	},

}

return {
	Triggers = triggers,
	Actions = actions,
}
