local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local unitLoadout = {
	{ unitDefName = 'armpw', unitName = 'scout', x = 1700, z = 2200, team = 0 },
	{ unitDefName = 'armwar', unitName = 'brawler', x = 1800, z = 2200, team = 0 },
}

local triggers = {
	markScout = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 2,
		},
		actions = { 'markScout', 'messageMarkScout' },
	},

	markTwice = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'markScoutAgain', 'messageMarkTwice' },
	},

	markTeam = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 8,
		},
		actions = { 'markTeam', 'messageMarkTeam' },
	},

	removeOneType = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 11,
		},
		actions = { 'removeObjectiveMarkers', 'messageRemoveOneType' },
	},

	removeAll = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 14,
		},
		actions = { 'removeEveryMarker', 'messageRemoveAll' },
	},

	killBrawler = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 17,
		},
		actions = { 'markBrawler', 'killBrawler', 'messageKillBrawler' },
	},
}

local actions = {
	markScout = {
		type = actionTypes.AddUnitMarker,
		parameters = {
			unitName = 'scout',
			markerType = 'objective',
		},
	},

	messageMarkScout = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'One point on the scout.',
		},
	},

	markScoutAgain = {
		type = actionTypes.AddUnitMarker,
		parameters = {
			unitName = 'scout',
			markerType = 'alert',
		},
	},

	messageMarkTwice = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'The scout now carries two markers, drawn as two points in the same place.',
		},
	},

	markTeam = {
		type = actionTypes.AddUnitMarker,
		parameters = {
			teamID = 0,
			unitDefName = 'armwar',
			markerType = 'objective',
		},
	},

	messageMarkTeam = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'The brawler is marked by team and definition; the scout is not.',
		},
	},

	removeObjectiveMarkers = {
		type = actionTypes.RemoveUnitMarker,
		parameters = {
			unitName = 'scout',
			markerType = 'objective',
		},
	},

	messageRemoveOneType = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The scout's objective marker is gone and its alert marker stays.",
		},
	},

	removeEveryMarker = {
		type = actionTypes.RemoveUnitMarker,
		parameters = {
			unitName = 'scout',
		},
	},

	messageRemoveAll = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'The scout carries nothing now.',
		},
	},

	markBrawler = {
		type = actionTypes.AddUnitMarker,
		parameters = {
			unitName = 'brawler',
			markerType = 'alert',
		},
	},

	killBrawler = {
		type = actionTypes.DestroyUnits,
		parameters = {
			unitName = 'brawler',
		},
	},

	messageKillBrawler = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'The brawler dies, which takes its markers with it.',
		},
	},
}

return {
	UnitLoadout = unitLoadout,
	Triggers = triggers,
	Actions = actions,
}
