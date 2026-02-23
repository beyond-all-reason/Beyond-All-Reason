local Types = VFS.Include('luarules/mission_api/parameter_types.lua').Types

local triggerTypes = {
	-- Time
	TimeElapsed          = 100, --

	-- Units
	UnitExists           = 200, --
	UnitNotExists        = 201, --
	UnitKilled           = 202, --
	UnitCaptured         = 203, --
	UnitResurrected      = 204,
	UnitEnteredLocation  = 205,
	UnitLeftLocation     = 206,
	UnitDwellLocation    = 207,
	UnitSpotted          = 208,
	UnitUnspotted        = 209,
	ConstructionStarted  = 210, --
	ConstructionFinished = 211, --

	-- Features
	FeatureNotExists     = 300,
	FeatureReclaimed     = 301,
	FeatureDestroyed     = 302,

	-- Resources
	ResourceStored       = 400,
	ResourceProduction   = 401,

	-- Statistics
	TotalUnitsLost       = 500,
	TotalUnitsBuilt      = 501,
	TotalUnitsKilled     = 502,
	TotalUnitsCaptured   = 503,

	-- Team
	TeamDestroyed        = 601, --

	-- Mission Control
	Victory              = 700,
	Defeat               = 701,
}

--============================================================--

local settings = {
	prerequisites = Types.Table,
	repeating = Types.Boolean,
	maxRepeats = Types.Number,
	difficulties = Types.Table,
	coop = Types.Boolean,
	active = Types.Boolean,
}

--============================================================--

local parameters = {
	-- Time
	[triggerTypes.TimeElapsed] = {
		[1] = {
			name = 'gameFrame',
			required = true,
			type = Types.Number,
		},
		[2] = {
			name = 'interval',
			required = false,
			type = Types.Number,
		},
	},

	-- Units
	[triggerTypes.UnitExists] = {
		[1] = {
			name = 'unitDefID',
			required = true,
			type = Types.Number,
		},
		[2] = {
			name = 'teamID',
			required = false,
			type = Types.Number,
		},
		[3] = {
			name = 'quantity',
			required = false,
			type = Types.Number,
		},
	},
	[triggerTypes.UnitNotExists] = {
		[1] = {
			name = 'unit',
			required = true,
			type = Types.String,
		},
	},
	[triggerTypes.UnitKilled] = {
		[1] = {
			name = 'unit',
			required = true,
			type = Types.String
		},
	},
	[triggerTypes.UnitCaptured] = {
		[1] = {
			name = 'unit',
			required = true,
			type = Types.String
		},
	},
	[triggerTypes.UnitResurrected] = {  },
	[triggerTypes.UnitEnteredLocation] = {
		[1] = {
			name = 'unit',
			required = true,
			type = Types.String
		},
		[2] = {
			name = 'position',
			required = true,
			type = Types.Table,
		},
		[3] = {
			name = 'width',
			required = true,
			type = Types.Number,
		},
		[4] = {
			name = 'height',
			required = false,
			type = Types.Number,
		},
	},
	[triggerTypes.UnitLeftLocation] = {  },
	[triggerTypes.UnitDwellLocation] = {  },
	[triggerTypes.UnitSpotted] = {  },
	[triggerTypes.UnitUnspotted] = {  },
	[triggerTypes.ConstructionStarted] = {
		[1] = {
			name = 'unit',
			required = true,
			type = Types.String,
		},
	 },
	[triggerTypes.ConstructionFinished] = {
		[1] = {
			name = 'unit',
			required = true,
			type = Types.String,
		},
	 },

	-- Features
	[triggerTypes.FeatureNotExists] = {  },
	[triggerTypes.FeatureReclaimed] = {  },
	[triggerTypes.FeatureDestroyed] = {  },

	-- Resources
	[triggerTypes.ResourceStored] = {  },
	[triggerTypes.ResourceProduction] = {  },

	-- Statistics
	[triggerTypes.TotalUnitsLost] = {  },
	[triggerTypes.TotalUnitsBuilt] = {  },
	[triggerTypes.TotalUnitsKilled] = {  },
	[triggerTypes.TotalUnitsCaptured] = {  },

	-- Team
	[triggerTypes.TeamDestroyed] = {
		[1] = {
			name = 'teamID',
			required = true,
			type = Types.Number,
		},
	 },

	-- Win Condition
	[triggerTypes.Victory] = {  },
	[triggerTypes.Defeat] = {  },
}

--============================================================--

return {
	Types = triggerTypes,
	Settings = settings,
	Parameters = parameters,
}
