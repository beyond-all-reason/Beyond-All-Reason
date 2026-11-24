---
--- Test mission demonstrating AreaCleared: three guards and a tower die in turn, and the
--- triggers fire only when the last of them is gone.
---

local conditionTypes = GG['MissionAPI'].ConditionDefinitions.Types
local actionTypes  = GG['MissionAPI'].ActionDefinitions.Types

local outpost = { x = 1000, z = 1000, radius = 300 }

local triggers = {
	killGuards = {
		type = conditionTypes.TimeElapsed,
		parameters = { seconds = 5 },
		actions = { 'killGuards' },
	},

	killTower = {
		type = conditionTypes.TimeElapsed,
		parameters = { seconds = 10 },
		actions = { 'killTower' },
	},

	outpostClearedOfTeam = {
		type = conditionTypes.AreaCleared,
		parameters = { area = outpost, teamName = 'enemy' },
		actions = { 'messageTeam' },
	},

	outpostClearedOfAlliance = {
		type = conditionTypes.AreaCleared,
		parameters = { area = outpost, allianceName = 'enemies' },
		actions = { 'messageAlliance' },
	},

	-- Nobody of theirs was ever here, so this never fires.
	emptyAreaCleared = {
		type = conditionTypes.AreaCleared,
		parameters = { area = { x = 3000, z = 3000, radius = 100 }, teamName = 'enemy' },
		actions = { 'messageEmpty' },
	},
}

local actions = {
	killGuards = {
		type = actionTypes.DestroyUnits,
		parameters = { unitName = 'guards' },
	},
	killTower = {
		type = actionTypes.DestroyUnits,
		parameters = { unitName = 'tower' },
	},
	messageTeam = {
		type = actionTypes.SendMessage,
		parameters = { messageKey = 'AreaCleared test: the outpost is cleared of the enemy team (expected at 10 seconds).' },
	},
	messageAlliance = {
		type = actionTypes.SendMessage,
		parameters = { messageKey = 'AreaCleared test: the outpost is cleared of the enemy alliance (expected at 10 seconds).' },
	},
	messageEmpty = {
		type = actionTypes.SendMessage,
		parameters = { messageKey = 'AreaCleared test: the empty area fired, which is wrong.' },
	},
}

local unitLoadout = {
	{ unitDefName = 'armcom', position = { x = 2000, z = 2000 }, teamName = 'player' },
	-- The player's own unit inside the outpost does not hold the triggers back.
	{ unitDefName = 'armpw', position = { x = 1100, z = 1000 }, teamName = 'player' },
	{ unitDefName = 'corak', position = { x = 950, z = 1000 }, teamName = 'enemy', unitName = 'guards', quantity = 3 },
	{ unitDefName = 'armllt', position = { x = 1000, z = 900 }, teamName = 'enemy', unitName = 'tower' },
}

return {
	Triggers    = triggers,
	Actions     = actions,
	UnitLoadout = unitLoadout,
}
