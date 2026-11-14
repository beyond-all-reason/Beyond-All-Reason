---
--- Test mission demonstrating RaiseEvent: two triggers share one Event trigger's actions.
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes  = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {
	firstCall = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 3 },
		actions = { 'raiseReinforcements' },
	},

	secondCall = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 10 },
		actions = { 'raiseReinforcements' },
	},

	reinforcementsArrive = {
		type = triggerTypes.Event,
		settings = { repeating = true },
		actions = { 'spawnReinforcements', 'messageReinforcements' },
	},
}

local actions = {
	raiseReinforcements = {
		type = actionTypes.RaiseEvent,
		parameters = { triggerID = 'reinforcementsArrive' },
	},
	spawnReinforcements = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armpw', position = { x = 1850, z = 1850 }, orientation = 'e', teamName = 'player', quantity = 3 },
			},
		},
	},
	messageReinforcements = {
		type = actionTypes.SendMessage,
		parameters = { messageKey = 'RaiseEvent test: three Pawns arrive, at 3 and at 10 seconds.' },
	},
}

local unitLoadout = {
	{ unitDefName = 'armck', position = { x = 1780, z = 1850 }, orientation = 'e', teamName = 'player' },
}

return {
	Triggers    = triggers,
	Actions     = actions,
	UnitLoadout = unitLoadout,
}
