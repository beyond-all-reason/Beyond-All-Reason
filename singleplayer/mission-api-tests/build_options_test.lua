---
--- Build option actions test mission.
---
--- Disable/EnableBuildOption grey an option out (team-wide, or for one builder type).
--- Remove/AddBuildOption take an option out of, or put one into, a builder type's menu.
--- Select the construction bot and the bot lab to watch the menus change every 5 seconds;
--- the greyed-out options must also refuse build orders given by hotkey.
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	setup = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'spawnBuilders', 'messageIntro' },
	},

	disableSolar = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'disableSolar', 'messageDisableSolar' },
	},

	disableWindForBot = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 10,
		},
		actions = { 'enableSolar', 'disableWindForBot', 'messageDisableWindForBot' },
	},

	removeOptions = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 15,
		},
		actions = { 'enableWindForBot', 'removeMexFromBot', 'removePeeweeFromLab', 'messageRemoveOptions' },
	},

	addOptions = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 20,
		},
		actions = { 'addMexToBot', 'addFavToLab', 'messageAddOptions' },
	},
}

local actions = {

	spawnBuilders = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armck', x = 1800, z = 1600, team = 0, unitName = 'bot' },
				{ unitDefName = 'armlab', x = 2000, z = 1800, team = 0, unitName = 'lab' },
			},
		},
	},

	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Build options test: select the construction bot and the bot lab; their menus change every 5 s.",
		},
	},

	-- Team-wide: greyed out for the commander and the construction bot alike.
	disableSolar = {
		type = actionTypes.DisableBuildOption,
		parameters = {
			builtDefName ='armsolar',
			teamID = 0,
		},
	},

	enableSolar = {
		type = actionTypes.EnableBuildOption,
		parameters = {
			builtDefName ='armsolar',
			teamID = 0,
		},
	},

	messageDisableSolar = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Solar collector disabled for the whole team: greyed out for every builder.",
		},
	},

	-- Per builder type: only the construction bot loses the wind turbine, the commander keeps it.
	disableWindForBot = {
		type = actionTypes.DisableBuildOption,
		parameters = {
			builtDefName ='armwin',
			builderDefName ='armck',
			teamID = 0,
		},
	},

	enableWindForBot = {
		type = actionTypes.EnableBuildOption,
		parameters = {
			builtDefName ='armwin',
			builderDefName ='armck',
			teamID = 0,
		},
	},

	messageDisableWindForBot = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Solar re-enabled. Wind turbine disabled for the construction bot only: the commander can still build it.",
		},
	},

	removeMexFromBot = {
		type = actionTypes.RemoveBuildOption,
		parameters = {
			builtDefName ='armmex',
			builderDefName ='armck',
		},
	},

	removePeeweeFromLab = {
		type = actionTypes.RemoveBuildOption,
		parameters = {
			builtDefName ='armpw',
			builderDefName ='armlab',
		},
	},

	messageRemoveOptions = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Wind re-enabled. Metal extractor removed from the construction bot, Pawn removed from the bot lab: gone from their menus.",
		},
	},

	addMexToBot = {
		type = actionTypes.AddBuildOption,
		parameters = {
			builtDefName ='armmex',
			builderDefName ='armck',
			buildMenuPosition = 1,
		},
	},

	addFavToLab = {
		type = actionTypes.AddBuildOption,
		parameters = {
			builtDefName ='armfav',
			builderDefName ='armlab',
			buildMenuPosition = 1,
		},
	},

	messageAddOptions = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Metal extractor back on the construction bot; the bot lab can now build the Rover. New units of both types get the same options.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
