--- Test mission for ShowHint and HideHint.

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
	hideLastHint = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 11 },
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
		parameters = { messageKey = "Now a Metal Extractor. This one goes after 3 seconds.", seconds = 3 },
	},
	hintMetalAmount = {
		type = actionTypes.ShowHint,
		parameters = { messageKey = "ui.playersList.chat.needMetalAmount", messageData = { amount = 300 } },
	},
	hideHint = {
		type = actionTypes.HideHint,
	},
}

return {
	Triggers = triggers,
	Actions = actions,
	UnitLoadout = {
		{ unitDefName = "armcom", position = { x = 1800, z = 1800 }, orientation = "s", teamName = "player" },
	},
}
