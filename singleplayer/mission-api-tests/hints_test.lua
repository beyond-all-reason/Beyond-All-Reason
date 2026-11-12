---
--- Test mission for ShowHint and HideHint: a hint, one that replaces it and times out, then one
--- hidden by HideHint.
---

local triggerTypes = GG["MissionAPI"].TriggerDefinitions.Types
local actionTypes = GG["MissionAPI"].ActionDefinitions.Types

local triggers = {
	first = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 1 },
		actions = { "hintSolar" },
	},
	second = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 4 },
		actions = { "hintMex" },
	},
	third = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 9 },
		actions = { "hintLast" },
	},
	hide = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 12 },
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
