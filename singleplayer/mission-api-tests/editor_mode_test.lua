---
--- Test mission for editorMode: nothing runs until /luarules editormode off.
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes  = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {
	missionStarted = {
		type = triggerTypes.MissionStarted,
		actions = { 'messageStarted' },
	},

	fiveSecondsIn = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'messageFiveSeconds' },
	},

	firstBuilt = {
		type = triggerTypes.TotalUnitsBuilt,
		parameters = {
			teamID = 0,
			quantity = 1,
		},
		actions = { 'messageFirstBuilt' },
	},
}

local actions = {
	messageStarted = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'Editor mode test: the mission is plugged in, and the constructor has just spawned.',
		},
	},
	messageFiveSeconds = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'Editor mode test: five seconds since the mission was plugged in.',
		},
	},
	messageFirstBuilt = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'Editor mode test: the first unit you built. The constructor did not count.',
		},
	},
}

local unitLoadout = {
	{ unitDefName = 'armck', x = 1780, z = 1850, facing = 'e', team = 0 },
}

return {
	Triggers    = triggers,
	Actions     = actions,
	UnitLoadout = unitLoadout,
}
