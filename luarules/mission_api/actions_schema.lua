local Types = VFS.Include('luarules/mission_api/parameter_types.lua').Types

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
	NameUnits	       = 405,       --
	UnnameUnits	       = 406,       --

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
			type = Types.TriggerID
		},
	},

	[actionTypes.DisableTrigger] = {
		[1] = {
			name = 'triggerID',
			required = true,
			type = Types.TriggerID
		},
	},

	-- Orders
	[actionTypes.IssueOrders] = {
		[1] = {
			name = 'unitNameRequired',
			required = true,
			type = Types.String
		},
		[2] = {
			name = 'orders',
			required = true,
			type = Types.Orders
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
			name = 'unitNameToGive',
			required = false,
			type = Types.String,
		},
		[2] = {
			name = 'unitDefName',
			required = true,
			type = Types.UnitDefName
		},
		[3] = {
			name = 'teamID',
			required = true,
			type = Types.TeamID
		},
		[4] = {
			name = 'position',
			required = true,
			type = Types.Position
		},
		[5] = {
			name = 'quantity',
			required = false,
			type = Types.Number,		},
		[6] = {
			name = 'facing',
			required = false,
			type = Types.Facing
		},
		[7] = {
			name = 'construction',
			required = false,
			type = Types.Boolean
		}
	},

	[actionTypes.DespawnUnits] = {
		[1] = {
			name = 'unitNameRequired',
			required = true,
			type = Types.String,
		},
		[2] = {
			name = 'selfDestruct',
			required = false,
			type = Types.Boolean,
		},
		[3] = {
			-- when true, selfDestruct param has no effect
			name = 'reclaimed',
			required = false,
			type = Types.Boolean,
		},
	},
	[actionTypes.SpawnWeapons] = {},
	[actionTypes.SpawnEffects] = {},
	[actionTypes.TransferUnits] = {
		[1] = {
			name = 'unitNameRequired',
			required = true,
			type = Types.String
		},
		[2] = {
			name = 'newTeam',
			required = true,
			type = Types.TeamID
		},
		[3] = {
			-- can only transfer to other allyTeam if given=false
			name = 'given',
			required = false,
			type = Types.Boolean
		}
	},
	[actionTypes.NameUnits] = {
		[1] = {
			name = 'unitNameToGive',
			required = true,
			type = Types.String
		},
		[2] = {
			name = 'teamID',
			required = false,
			type = Types.Number
		},
		[3] = {
			name = 'unitDefName',
			required = false,
			type = Types.String
		},
		[4] = {
			-- Examples:
			-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
			-- Circle: { x = 0, z = 0, radius = 123 }
			name = 'area',
			required = false,
			type = Types.Area
		},
		requiresOneOf = { 'teamID', 'unitDefName', 'area' }
	},
	[actionTypes.UnnameUnits] = {
		[1] = {
			name = 'unitNameRequired',
			required = true,
			type = Types.String
		}
	},

	-- SFX
	[actionTypes.SpawnExplosion] = {
		[1] = {
			name = 'position',
			required = true,
			type = Types.Position
		},
		[2] = {
			name = 'direction',
			required = true,
			type = Types.Position
		},
		[3] = {
			name = 'params',
			required = true,
			type = Types.Table
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
			type = Types.String,
		}
	},

	-- Win Condition
	[actionTypes.Victory] = {
		[1] = {
			name = 'allyTeamIDs',
			required = true,
			type = Types.AllyTeamIDs
		}
	},
	[actionTypes.Defeat] = {
		[1] = {
			name = 'allyTeamIDs',
			required = true,
			type = Types.AllyTeamIDs
		}
	},

	-- Custom
	[actionTypes.Custom] = {
		[1] = {
			name = 'function',
			required = true,
			type = Types.Function,
		},
	},
}

--============================================================--

return {
	Types = actionTypes,
	Parameters = parameters
}
