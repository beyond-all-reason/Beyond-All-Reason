---
--- Unit type limit test mission.
---
--- SetUnitTypeLimit caps how many units of a type a team may have at once, finished or under
--- construction. Queue three Light Laser Towers with the construction bot: the option greys out
--- at two and the third is refused; a second bot can still help build a placed tower. Destroy
--- one tower and the option comes back. At 60 s RemoveUnitTypeLimit takes the cap away.
---

local triggerTypes = GG["MissionAPI"].TriggerDefinitions.Types
local actionTypes = GG["MissionAPI"].ActionDefinitions.Types

local triggers = {

	setup = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { "spawnBuilders", "limitTowers", "messageIntro" },
	},

	lift = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 60,
		},
		actions = { "unlimitTowers", "messageLift" },
	},
}

local actions = {

	spawnBuilders = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = "armck", x = 1800, z = 1600, teamName = "player" },
				{ unitDefName = "armck", x = 1850, z = 1600, teamName = "player" },
			},
		},
	},

	limitTowers = {
		type = actionTypes.SetUnitTypeLimit,
		parameters = {
			unitDefName = "armllt",
			teamName = "player",
			limit = 2,
		},
	},

	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Unit type limit test: at most 2 Light Laser Towers. Queue three; the third is refused once two stand or are being built. The second bot can still help.",
		},
	},

	unlimitTowers = {
		type = actionTypes.RemoveUnitTypeLimit,
		parameters = {
			unitDefName = "armllt",
			teamName = "player",
		},
	},

	messageLift = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "The tower limit is gone: build as many as you like.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
