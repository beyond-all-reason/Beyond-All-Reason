--============================================================--

-- Types

--============================================================--

local actionTypes = {
	-- Triggers
	EnableTrigger               = 100,
	DisableTrigger              = 101,

	-- Orders
	IssueOrdersId               = 200,
	IssueOrdersName             = 201,
	AllowCommands               = 202,
	RestrictCommands            = 203,

	-- Build Options
	AlterBuildlist              = 300,
	EnableBuildOption           = 301,
	DisableBuildOption          = 302,

	-- Units
	SpawnUnits                  = 400,
	SpawnConstruction           = 401,
	DespawnUnits                = 402,
	SpawnWeapons                = 403,
	SpawnEffects                = 404,
	TransferUnits               = 405,

	-- Map
	RevealLOS                   = 500,
	UnrevealLOS                 = 501,
	AlterMapZones               = 502,

	-- Media
	ControlCamera               = 600,
	Pause                       = 601,
	Unpause                     = 602,
	PlayMedia                   = 603,
	SendMessage                 = 604,

	-- Win Condition
	Victory                     = 700,
	Defeat                      = 701,
}

--============================================================--

-- Params

--============================================================--

local parameters = {
	-- Triggers
	[actionTypes.EnableTrigger] = {
		[1] = {
			name = 'triggerId',
			required = true,
			type = 'string',
		},
	 },

	[actionTypes.DisableTrigger] = {
		[1] = {
			name = 'triggerId',
			required = true,
			type = 'string',
		},
	 },

	 -- Orders
	[actionTypes.IssueOrdersId] = { 
		[1] = {
			name = 'unitId',
			required = true,
			type = 'string'
		},
		[2] = {
			name = 'orders',
			required = true,
			type = 'table'
		}
	 },
	[actionTypes.AllowCommands] = {  },
	[actionTypes.RestrictCommands] = {  },

	-- Build Options
	[actionTypes.AlterBuildlist] = {  },
	[actionTypes.EnableBuildOption] = {  },
	[actionTypes.DisableBuildOption] = {  },

	-- Units
	[actionTypes.SpawnUnits] = {
		[1] = {
			name = 'name',
			required = false,
			type = 'string',
		},
		[2] = {
			name = 'unitDefName',
			required = true,
			type = 'string',
		},
		[3] = {
			name = 'quantity',
			required = false,
			type = 'number',
		},
		[4] = {
			name = 'x',
			required = true,
			type = 'number',
		},
		[5] = {
			name = 'y',
			required = false,
			type = 'number',
		},
		[6] = {
			name = 'z',
			required = true,
			type = 'number',
		},
	},

	[actionTypes.SpawnConstruction] = {  },
	[actionTypes.DespawnUnits] = {
		[1] = {
			name = 'name',
			required = true,
			type = 'string',
		},
	 },
	[actionTypes.SpawnWeapons] = {  },
	[actionTypes.SpawnEffects] = {  },
	[actionTypes.TransferUnits] = {  },

	-- Map
	[actionTypes.RevealLOS] = {  },
	[actionTypes.UnrevealLOS] = {  },
	[actionTypes.AlterMapZones] = {  },


	-- Media
	[actionTypes.ControlCamera] = {  },
	[actionTypes.Pause] = {  },
	[actionTypes.Unpause] = {  },
	[actionTypes.PlayMedia] = {  },

	[actionTypes.SendMessage] = {
		[1] = {
			name = 'message',
			required = true,
			type = 'string',
		}
	},

	-- Win Condition
	[actionTypes.Victory] = {  },
	[actionTypes.Defeat] = {  },
}

--============================================================--

return {
	Types = actionTypes,
	Parameters = parameters
}

--============================================================--