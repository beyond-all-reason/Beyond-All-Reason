---
--- Test mission demonstrating Options, which a mission reads while it loads.
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes  = GG['MissionAPI'].ActionDefinitions.Types
local options      = GG['MissionAPI'].Options

local triggers = {
	intro = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 0,
		},
		actions = { 'messageIntro' },
	},

	victory = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 20,
		},
		actions = { 'victory' },
	},
}

local actions = {
	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = options.reinforcements
				and 'Options test: the reinforcements option is set, so three Pawns joined you.'
				or 'Options test: the reinforcements option is not set, so you are on your own.',
		},
	},
	victory = {
		type = actionTypes.Victory,
		parameters = {
			allyTeamIDs = { 0 },
		},
	},
}

local unitLoadout = {
	{ unitDefName = 'armck', x = 1780, z = 1850, facing = 'e', team = 0 },
}

if options.reinforcements then
	table.insert(unitLoadout, { unitDefName = 'armpw', x = 1850, z = 1800, facing = 'e', team = 0 })
	table.insert(unitLoadout, { unitDefName = 'armpw', x = 1850, z = 1850, facing = 'e', team = 0 })
	table.insert(unitLoadout, { unitDefName = 'armpw', x = 1850, z = 1900, facing = 'e', team = 0 })
end

return {
	Triggers    = triggers,
	Actions     = actions,
	UnitLoadout = unitLoadout,
}
