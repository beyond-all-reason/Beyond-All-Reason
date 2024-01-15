--============================================================--

-- Action Types

--============================================================--

local actionTypes = {
	-- Triggers
	EnableTrigger               = 100, --
	DisableTrigger              = 101, --

	-- Orders
	IssueOrders                 = 200, --
	AllowCommands               = 201,
	RestrictCommands            = 202,

	-- Build Options
	AlterBuildlist              = 300,
	EnableBuildOption           = 301,
	DisableBuildOption          = 302,

	-- Units
	SpawnUnits                  = 400, --
	SpawnConstruction           = 401,
	DespawnUnits                = 402, --
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

-- Action Parameters

--============================================================--

local parameters = {
	-- Triggers
	[actionTypes.EnableTrigger] = {
		[1] = {
			name = 'triggerID',
			required = true,
			type = 'string',
		},
	 },

	[actionTypes.DisableTrigger] = {
		[1] = {
			name = 'triggerID',
			required = true,
			type = 'string',
		},
	 },

	 -- Orders
	[actionTypes.IssueOrders] = { 
		[1] = {
			name = 'unit',
			required = true,
			type = 'unit'
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
			name = 'unitDef',
			required = true,
			type = 'unitDef',
		},
		[3] = {
			name = 'quantity',
			required = false,
			type = 'number',
		},
		[4] = {
			name = 'position',
			required = true,
			type = 'vec3'
		},
		[5] = {
			name = 'facing',
			required = false,
			type = 'direction'
		}
	},

	[actionTypes.SpawnConstruction] = { },
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