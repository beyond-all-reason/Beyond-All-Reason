VFS.Include('luarules/mission_api/validation.lua')

local actionTypes = {
	-- Triggers
	EnableTrigger      = 100,       --
	DisableTrigger     = 101,       --

	-- Orders
	IssueOrders        = 200,       --
	AllowCommands      = 201,
	RestrictCommands   = 202,

	-- Build Options
	AlterBuildlist     = 300,
	EnableBuildOption  = 301,
	DisableBuildOption = 302,

	-- Units
	SpawnUnits         = 400,       --
	DespawnUnits       = 401,       --
	TransferUnits      = 404,       --

	-- SFX
	SpawnExplosion     = 500,       --
	SpawnWeapons       = 501,
	SpawnEffects       = 502,

	-- Map
	RevealLOS          = 600,
	UnrevealLOS        = 601,
	AlterMapZones      = 602,

	-- Media
	ControlCamera      = 700,
	Pause              = 701,
	Unpause            = 702,
	PlayMedia          = 703,
	SendMessage        = 704,

	-- Win Condition
	Victory            = 800,
	Defeat             = 801,

	-- Custom
	Custom             = 900,       --
}

--============================================================--

local parameters = {
	-- Triggers
	[actionTypes.EnableTrigger] = {
		[1] = {
			name = 'triggerID',
			required = true,
			type = Types.triggerID
		},
	},

	[actionTypes.DisableTrigger] = {
		[1] = {
			name = 'triggerID',
			required = true,
			type = Types.triggerID
		},
	},

	-- Orders
	[actionTypes.IssueOrders] = {
		[1] = {
			name = 'name',
			required = true,
			type = Types.string
		},
		[2] = {
			name = 'orders',
			required = true,
			type = Types.table
		}
	},
	[actionTypes.AllowCommands] = {},
	[actionTypes.RestrictCommands] = {},

	-- Build Options
	[actionTypes.AlterBuildlist] = {},
	[actionTypes.EnableBuildOption] = {},
	[actionTypes.DisableBuildOption] = {},

	-- Units
	[actionTypes.SpawnUnits] = {
		[1] = {
			name = 'name',
			required = false,
			type = Types.string,
		},
		[2] = {
			name = 'unitDefName',
			required = true,
			type = Types.unitDefName
		},
		[3] = {
			name = 'teamID',
			required = true,
			type = Types.teamID
		},
		[4] = {
			name = 'position',
			required = true,
			type = Types.position
		},
		[5] = {
			name = 'quantity',
			required = false,
			type = Types.number,		},
		[6] = {
			name = 'facing',
			required = false,
			type = Types.facing
		},
		[7] = {
			name = 'construction',
			required = false,
			type = Types.boolean
		}
	},

	[actionTypes.DespawnUnits] = {
		[1] = {
			name = 'name',
			required = true,
			type = Types.string,
		},
		[2] = {
			name = 'selfDestruct',
			required = false,
			type = Types.boolean,
		},
		[3] = {
			name = 'reclaimed',
			required = false,
			type = Types.boolean,
		},
	},
	[actionTypes.SpawnWeapons] = {},
	[actionTypes.SpawnEffects] = {},
	[actionTypes.TransferUnits] = {
		[1] = {
			name = 'name',
			required = true,
			type = Types.string
		},
		[2] = {
			name = 'newTeam',
			required = true,
			type = Types.teamID
		},
		[3] = {
			-- can only transfer to other allyTeam if given=false
			name = 'given',
			required = false,
			type = Types.boolean
		}
	},

	-- SFX
	[actionTypes.SpawnExplosion] = {
		[1] = {
			name = 'position',
			required = true,
			type = Types.position
		},
		[2] = {
			name = 'direction',
			required = true,
			type = Types.position
		},
		[3] = {
			name = 'params',
			required = true,
			type = Types.table
		}
	},

	-- Map
	[actionTypes.RevealLOS] = {},
	[actionTypes.UnrevealLOS] = {},
	[actionTypes.AlterMapZones] = {},

	-- Media
	[actionTypes.ControlCamera] = {},
	[actionTypes.Pause] = {},
	[actionTypes.Unpause] = {},
	[actionTypes.PlayMedia] = {},

	[actionTypes.SendMessage] = {
		[1] = {
			name = 'message',
			required = true,
			type = Types.string,
		}
	},

	-- Win Condition
	[actionTypes.Victory] = {
		[1] = {
			name = 'allyTeamIDs',
			required = true,
			type = Types.allyTeamIDs
		}
	},
	[actionTypes.Defeat] = {
		[1] = {
			name = 'allyTeamIDs',
			required = true,
			type = Types.allyTeamIDs
		}
	},

	-- Custom
	[actionTypes.Custom] = {
		[1] = {
			name = 'function',
			required = true,
			type = Types.customFunction,
		},
	},
}

--============================================================--

return {
	Types = actionTypes,
	Parameters = parameters
}
