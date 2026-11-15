---
--- Unit color test mission, for team 'player' of the mission API test start script.
---
--- Two Pawns stand at the start: 'hero' in orange from the loadout, 'grunt' in the team's color.
--- At 5 s the grunt turns green and the hero goes back to the team's color.
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	swapColors = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'paintGrunt', 'clearHero', 'messageSwapped' },
	},
}

local actions = {

	paintGrunt = {
		type = actionTypes.SetUnitColor,
		parameters = {
			unitName = 'grunt',
			color = { r = 0, g = 1, b = 0.5 },
		},
	},

	clearHero = {
		type = actionTypes.ClearUnitColor,
		parameters = {
			unitName = 'hero',
		},
	},

	messageSwapped = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Unit color test: the grunt is green now, the hero has the team's color back.",
		},
	},
}

local unitLoadout = {
	{ unitDefName = 'armpw', position = { x = 1800, z = 1600 }, teamName = 'player', unitName = 'hero', color = { r = 1, g = 0.5, b = 0 } },
	{ unitDefName = 'armpw', position = { x = 1900, z = 1600 }, teamName = 'player', unitName = 'grunt' },
}

return {
	Triggers = triggers,
	Actions = actions,
	UnitLoadout = unitLoadout,
}
