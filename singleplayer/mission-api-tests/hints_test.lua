---
--- Test mission for ShowHint and HideHint: a hint, one that replaces it and times out, one filled
--- from messageData, then one hidden by HideHint.
---

local triggerTypes = GG["MissionAPI"].TriggerDefinitions.Types
local actionTypes = GG["MissionAPI"].ActionDefinitions.Types

local triggers = {
	showBuildSolar = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 1 },
		actions = { "hintSolar" },
	},
	replaceWithTimedMex = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 4 },
		actions = { "hintMex" },
	},
	showFromData = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 8 },
		actions = { "hintMetalAmount" },
	},
	showUntilHidden = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 10 },
		actions = { "hintLast" },
	},
	hideLastHint = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 13 },
		actions = { "hideHint" },
	},
}

local actions = {
	hintSolar = {
		type = actionTypes.ShowHint,
		parameters = { messageKey = "Build a Solar Collector with your commander." },
	},
	hintMex = {
		type = actionTypes.ShowHint,
		parameters = {
			messageKey = "Now a Metal Extractor on a metal spot. This one goes after 3 seconds.",
			seconds = 3,
		},
	},
	hintMetalAmount = {
		type = actionTypes.ShowHint,
		parameters = { messageKey = "ui.playersList.chat.needMetalAmount", messageData = { amount = 300 } },
	},
	hintLast = {
		type = actionTypes.ShowHint,
		parameters = { messageKey = "This hint stays until HideHint." },
	},
	hideHint = {
		type = actionTypes.HideHint,
	},
}

local unitLoadout = {
	{ unitDefName = "armcom", position = { x = 1800, z = 1800 }, orientation = "s", teamName = "player" },
}

return {
	Triggers = triggers,
	Actions = actions,
	UnitLoadout = unitLoadout,
}
