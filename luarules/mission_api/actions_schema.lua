local actionTypes = {
	EnableTrigger = 1,
	DisableTrigger = 2,
	IssueOrders = 3,
	AllowCommands = 4,
	RestrictCommands = 5,
	AlterBuildlist = 6,
	EnableBuildOption = 7,
	DisableBuildOption = 8,
	SpawnUnits = 9,
	SpawnConstruction = 10,
	DespawnUnits = 11,
	SpawnWeapons = 12,
	SpawnEffects = 13,
	RevealLOS = 14,
	UnrevealLOS = 15,
	AlterMapZones = 16,
	TransferUnits = 17,
	ControlCamera = 18,
	Pause = 19,
	Unpause = 20,
	PlayMedia = 21,
	SendMessage = 22,
	Victory = 23,
	Defeat = 24,
}

local parameters = {
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

	[actionTypes.IssueOrders] = {  },
	[actionTypes.AllowCommands] = {  },
	[actionTypes.RestrictCommands] = {  },
	[actionTypes.AlterBuildlist] = {  },
	[actionTypes.EnableBuildOption] = {  },
	[actionTypes.DisableBuildOption] = {  },

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
	[actionTypes.RevealLOS] = {  },
	[actionTypes.UnrevealLOS] = {  },
	[actionTypes.AlterMapZones] = {  },
	[actionTypes.TransferUnits] = {  },
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

	[actionTypes.Victory] = {  },
	[actionTypes.Defeat] = {  },
}

return {
	Types = actionTypes,
	Parameters = parameters
}