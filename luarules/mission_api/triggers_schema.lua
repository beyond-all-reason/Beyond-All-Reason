local Types = VFS.Include('luarules/mission_api/parameter_types.lua').Types

local triggerTypes = {
	-- Time
	TimeElapsed          = 100,

	-- Units
	UnitExists           = 200,
	UnitNotExists        = 201,
	UnitKilled           = 202,
	UnitCaptured         = 203,
	UnitResurrected      = 204,
	UnitEnteredLocation  = 205,
	UnitLeftLocation     = 206,
	UnitDwellLocation    = 207,
	UnitSpotted          = 208,
	UnitUnspotted        = 209,
	ConstructionStarted  = 210,
	ConstructionFinished = 211,

	-- Features
	FeatureCreated       = 300,
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
	UnitsOwned           = 504,

	-- Team
	TeamDestroyed        = 601,

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
			name = 'unitDefName',
			required = true,
			type = Types.UnitDefName,
		},
		[2] = {
			name = 'teamName',
			required = false,
			type = Types.TeamName,
		},
		[3] = {
			name = 'quantity',
			required = false,
			type = Types.Number,
		},
	},
	[triggerTypes.UnitNotExists] = {
		[1] = {
			name = 'unitName',
			required = false,
			type = Types.UnitName,
		},
		[2] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName
		},
		[3] = {
			name = 'teamName',
			required = false,
			type = Types.TeamName
		},
		requiresOneOf = { 'unitName', 'unitDefName' }
	},
	[triggerTypes.UnitKilled] = {
		[1] = {
			name = 'unitName',
			required = false,
			type = Types.UnitName,
		},
		[2] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName
		},
		[3] = {
			name = 'teamName',
			required = false,
			type = Types.TeamName
		},
		requiresOneOf = { 'unitName', 'unitDefName' }
	},
	[triggerTypes.UnitCaptured] = {
		[1] = {
			name = 'unitName',
			required = false,
			type = Types.UnitName,
		},
		[2] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName
		},
		[3] = {
			name = 'oldTeamName',
			required = false,
			type = Types.TeamName
		},
		[4] = {
			name = 'newTeamName',
			required = false,
			type = Types.TeamName
		},
		requiresOneOf = { 'unitName', 'unitDefName' }
	},
	[triggerTypes.UnitResurrected] = {
		[1] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName
		},
		[2] = {
			name = 'teamName',
			required = false,
			type = Types.TeamName
		},
		[3] = {
			name = 'featureName',
			required = false,
			type = Types.FeatureName,
		},
		requiresOneOf = { 'featureName', 'unitDefName' }
	},
	[triggerTypes.UnitEnteredLocation] = {
		[1] = {
			-- Examples:
			-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
			-- Circle: { x = 0, z = 0, radius = 123 }
			name = 'area',
			required = true,
			type = Types.Area
		},
		[2] = {
			name = 'unitName',
			required = false,
			type = Types.UnitName
		},
		[3] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName
		},
		[4] = {
			name = 'teamName',
			required = false,
			type = Types.TeamName
		},
		requiresOneOf = { 'unitName', 'unitDefName' }
	},
	[triggerTypes.UnitLeftLocation] = {
		[1] = {
			-- Examples:
			-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
			-- Circle: { x = 0, z = 0, radius = 123 }
			name = 'area',
			required = true,
			type = Types.Area
		},
		[2] = {
			name = 'unitName',
			required = false,
			type = Types.UnitName
		},
		[3] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName
		},
		[4] = {
			name = 'teamName',
			required = false,
			type = Types.TeamName
		},
		requiresOneOf = { 'unitName', 'unitDefName' }
	},
	[triggerTypes.UnitDwellLocation] = {
		[1] = {
			-- Examples:
			-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
			-- Circle: { x = 0, z = 0, radius = 123 }
			name = 'area',
			required = true,
			type = Types.Area
		},
		[2] = {
			-- Dwell time in game frames
			name = 'duration',
			required = true,
			type = Types.Number
		},
		[3] = {
			name = 'unitName',
			required = false,
			type = Types.UnitName
		},
		[4] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName
		},
		[5] = {
			name = 'teamName',
			required = false,
			type = Types.TeamName
		},
		requiresOneOf = { 'unitName', 'unitDefName' }
	},
	[triggerTypes.UnitSpotted] = {
		[1] = {
			name = 'unitName',
			required = false,
			type = Types.UnitName
		},
		[2] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName
		},
		[3] = {
			name = 'owningTeamName',
			required = false,
			type = Types.TeamName
		},
		[4] = {
			name = 'spottingAllyTeamName',
			required = false,
			type = Types.AllyTeamName
		},
		requiresOneOf = { 'unitName', 'unitDefName' }
	},
	[triggerTypes.UnitUnspotted] = {
		[1] = {
			name = 'unitName',
			required = false,
			type = Types.UnitName
		},
		[2] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName
		},
		[3] = {
			name = 'owningTeamName',
			required = false,
			type = Types.TeamName
		},
		[4] = {
			name = 'spottingAllyTeamName',
			required = false,
			type = Types.AllyTeamName
		},
		requiresOneOf = { 'unitName', 'unitDefName' }
	},
	[triggerTypes.ConstructionStarted] = {
		[1] = {
			name = 'unitDefName',
			required = true,
			type = Types.UnitDefName
		},
		[2] = {
			name = 'teamName',
			required = false,
			type = Types.TeamName
		},
	 },
	[triggerTypes.ConstructionFinished] = {
		[1] = {
			name = 'unitName',
			required = false,
			type = Types.UnitName
		},
		[2] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName
		},
		[3] = {
			name = 'teamName',
			required = false,
			type = Types.TeamName
		},
	 },

	-- Features
	[triggerTypes.FeatureCreated] = {
		[1] = {
			name = 'featureDefName',
			required = false,
			type = Types.FeatureDefName,
		},
		[2] = {
			name = 'area',
			required = false,
			type = Types.Area,
		},
		requiresOneOf = { 'featureDefName', 'area' }
	},
	[triggerTypes.FeatureReclaimed] = {
		[1] = {
			name = 'featureName',
			required = false,
			type = Types.FeatureName,
		},
		[2] = {
			name = 'featureDefName',
			required = false,
			type = Types.FeatureDefName,
		},
		[3] = {
			name = 'teamName',
			required = false,
			type = Types.TeamName,
		},
		[4] = {
			name = 'area',
			required = false,
			type = Types.Area,
		},
		requiresOneOf = { 'featureName', 'featureDefName', 'teamName', 'area' }
	},
	[triggerTypes.FeatureDestroyed] = {
		[1] = {
			name = 'featureName',
			required = false,
			type = Types.FeatureName,
		},
		[2] = {
			name = 'featureDefName',
			required = false,
			type = Types.FeatureDefName,
		},
		[3] = {
			name = 'allyTeamName',
			required = false,
			type = Types.AllyTeamName,
		},
		[4] = {
			name = 'area',
			required = false,
			type = Types.Area,
		},
		requiresOneOf = { 'featureName', 'featureDefName', 'allyTeamName', 'area' }
	},

	-- Resources
	[triggerTypes.ResourceStored] = {  },
	[triggerTypes.ResourceProduction] = {  },

	-- Statistics
	[triggerTypes.TotalUnitsLost] = {
		[1] = {
			name = 'teamName',
			required = true,
			type = Types.TeamName,
		},
		[2] = {
			name = 'quantity',
			required = true,
			type = Types.Number,
		},
		[3] = {
			name = 'unitName',
			required = false,
			type = Types.UnitName,
		},
		[4] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName,
		},
	},
	[triggerTypes.TotalUnitsBuilt] = {
		[1] = {
			name = 'teamName',
			required = true,
			type = Types.TeamName,
		},
		[2] = {
			name = 'quantity',
			required = true,
			type = Types.Number,
		},
		[3] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName,
		},
	},
	[triggerTypes.TotalUnitsKilled] = {
		[1] = {
			name = 'teamName',
			required = true,
			type = Types.TeamName,
		},
		[2] = {
			name = 'quantity',
			required = true,
			type = Types.Number,
		},
		[3] = {
			name = 'unitName',
			required = false,
			type = Types.UnitName,
		},
		[4] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName,
		},
	},
	[triggerTypes.TotalUnitsCaptured] = {
		[1] = {
			name = 'teamName',
			required = true,
			type = Types.TeamName,
		},
		[2] = {
			name = 'quantity',
			required = true,
			type = Types.Number,
		},
		[3] = {
			name = 'unitName',
			required = false,
			type = Types.UnitName,
		},
		[4] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName,
		},
	},
	[triggerTypes.UnitsOwned] = {
		[1] = {
			name = 'teamName',
			required = true,
			type = Types.TeamName,
		},
		[2] = {
			name = 'quantity',
			required = true,
			type = Types.Number,
		},
		[3] = {
			name = 'unitName',
			required = false,
			type = Types.UnitName,
		},
		[4] = {
			name = 'unitDefName',
			required = false,
			type = Types.UnitDefName,
		},
	},

	-- Team
	[triggerTypes.TeamDestroyed] = {
		[1] = {
			name = 'teamName',
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
