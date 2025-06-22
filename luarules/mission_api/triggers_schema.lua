--============================================================--

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

local parameters = {
	-- Time
	[triggerTypes.TimeElapsed] = {
		[1] = {
			name = 'gameFrame',
			required = true,
			type = 'number',
		},
		[2] = {
			name = 'interval',
			required = false,
			type = 'number',
		},
	},
	
	-- Units
	[triggerTypes.UnitExists] = { 
		[1] = {
			name = 'unitDefID',
			required = true,
			type = 'number',
		},
		[2] = {
			name = 'teamID',
			required = false,
			type = 'number',
		},
		[3] = {
			name = 'quantity',
			required = false,
			type = 'number',
		},
	},
	[triggerTypes.UnitNotExists] = { 
		[1] = {
			name = 'unit',
			required = true,
			type = 'string',
		},
	},
	[triggerTypes.UnitKilled] = { 
		[1] = {
			name = 'unit',
			required = true,
			type = 'string'
		},
	},
	[triggerTypes.UnitCaptured] = { 
		[1] = {
			name = 'unit',
			required = true,
			type = 'string'
		},
	},
	[triggerTypes.UnitResurrected] = {  },
	[triggerTypes.UnitEnteredLocation] = { 
		[1] = {
			name = 'unit',
			required = true,
			type = 'string'
		},
		[2] = {
			name = 'position',
			required = true,
			type = 'Vec2',
		},
		[3] = {
			name = 'width',
			required = true,
			type = 'number',
		},
		[4] = {
			name = 'height',
			required = false,
			type = 'number',
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
			type = 'string',
		},
	 },
	[triggerTypes.ConstructionFinished] = { 
		[1] = {
			name = 'unit',
			required = true,
			type = 'string',
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
			type = 'number',
		},
	 },

	-- Win Condition
	[triggerTypes.Victory] = {  },
	[triggerTypes.Defeat] = {  },
}

--============================================================--

return {
	Types = triggerTypes,
	Parameters = parameters,
}

--============================================================--