---
--- LockPlayerInput and UnlockPlayerInput actions test mission.
---
--- At 3 s the player is locked out: the interface disappears but for the menu buttons, keys
--- do nothing but Esc (which opens the quit dialog), the wheel, edge scrolling and clicks
--- move nothing and order nothing. At 20 s everything comes back.
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	intro = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'messageIntro' },
	},

	lock = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 3,
		},
		actions = { 'lock', 'messageLocked' },
	},

	unlock = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 20,
		},
		actions = { 'unlock', 'messageUnlocked' },
	},
}

local actions = {

	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Input lock test: at 3 s the mission locks you out until 20 s. Only Esc and the menu buttons should work.",
		},
	},

	lock = {
		type = actionTypes.LockPlayerInput,
		parameters = {},
	},

	messageLocked = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Locked: try keys, the wheel, edge scrolling and clicking units. Esc opens the quit dialog.",
		},
	},

	unlock = {
		type = actionTypes.UnlockPlayerInput,
		parameters = {},
	},

	messageUnlocked = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Unlocked: the interface and the controls are back.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
