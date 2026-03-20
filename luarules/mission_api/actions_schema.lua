local Types = VFS.Include('luarules/mission_api/parameter_types.lua').Types

local actionTypes = {
	-- Triggers
	EnableTrigger      = 100,
	DisableTrigger     = 101,

	-- Orders
	IssueOrders        = 200,
	AllowCommands      = 201,
	RestrictCommands   = 202,

	-- Build Options
	AlterBuildlist     = 300,
	EnableBuildOption  = 301,
	DisableBuildOption = 302,

	-- Units
	SpawnUnits         = 400,
	DespawnUnits       = 401,
	TransferUnits      = 404,
	NameUnits	       = 405,
	UnnameUnits	       = 406,

	-- SFX
	SpawnExplosion     = 500,
	SpawnWeapon        = 501, -- maybe this should be renamed to SpawnProjectile to match the Spring function?
	SpawnEffect        = 502,

	-- Map
	RevealLOS          = 600,
	UnrevealLOS        = 601,
	AlterMapZones      = 602,

	-- Media
	ControlCamera      = 700,
	Pause              = 701,
	Unpause            = 702,
	PlaySound          = 703,
	SendMessage        = 704,
	AddMarker          = 705,
	EraseMarker        = 706,
	DrawLines          = 707,
	ClearAllMarkers    = 708,

	-- Win Condition
	Victory            = 800,
	Defeat             = 801,

	-- Custom
	Custom             = 900,
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
			name = 'unitName',
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
			name = 'unitName',
			required = false,
			type = Types.String,
		},
		[2] = {
			name = 'unitDefName',
			required = true,
			type = Types.UnitDefName
		},
		[3] = {
			name = 'teamName',
			required = true,
			type = Types.TeamName
		},
		[4] = {
			name = 'position',
			required = true,
			type = Types.Position
		},
		[5] = {
			name = 'quantity',
			required = false,
			type = Types.Number,
		},
		[6] = {
			name = 'facing',
			required = false,
			type = Types.Facing
		},
		[7] = {
			name = 'construction',
			required = false,
			type = Types.Boolean
		},
		[8] = {
			name = 'spacing',
			required = false,
			type = Types.Number
		}
	},

	[actionTypes.DespawnUnits] = {
		[1] = {
			name = 'unitName',
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
	[actionTypes.TransferUnits] = {
		[1] = {
			name = 'unitName',
			required = true,
			type = Types.String
		},
		[2] = {
			name = 'newTeam',
			required = true,
			type = Types.TeamID
		},
	},
	[actionTypes.NameUnits] = {
		[1] = {
			name = 'unitName',
			required = true,
			type = Types.String
		},
		[2] = {
			name = 'teamID',
			required = false,
			type = Types.TeamID
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
			name = 'unitName',
			required = true,
			type = Types.String
		}
	},

	-- SFX
	[actionTypes.SpawnExplosion] = {
		[1] = {
			name = 'weaponDefName',
			required = true,
			type = Types.WeaponDefName,
		},
		[2] = {
			-- position on a unit?
			name = 'position',
			required = true,
			type = Types.Position,
		},
		[3] = {
			name = 'direction',
			required = false,
			type = Types.Position,
		},
	},
	[actionTypes.SpawnWeapon] = { }, -- nukes will need an owner unit for the voice alert
	[actionTypes.SpawnEffect] = { },

	-- Map
	[actionTypes.RevealLOS] = {},
	[actionTypes.UnrevealLOS] = {},
	[actionTypes.AlterMapZones] = {},

	-- Media
	[actionTypes.ControlCamera] = {},
	[actionTypes.Pause] = {},
	[actionTypes.Unpause] = {},
	[actionTypes.PlaySound] = {
		[1] = {
			-- file path from repo root
			name = 'soundfile',
			required = true,
			type = Types.SoundFile,
		},
		[2] = {
			name = 'volume',
			required = false,
			type = Types.Number,
		},
		[3] = {
			name = 'position',
			required = false,
			type = Types.Position,
		},
		[4] = {
			-- whether to play in sequence with other enqueued sounds, or to play immediately
			name = 'enqueue',
			required = false,
			type = Types.Boolean,
		},
	},

	[actionTypes.SendMessage] = {
		[1] = {
			name = 'message',
			required = true,
			type = Types.String,
		}
	},
	[actionTypes.AddMarker] = {
		[1] = {
			name = 'position',
			required = true,
			type = Types.Position,
		},
		[2] = {
			name = 'label',
			required = false,
			type = Types.String,
		},
		[3] = {
			name = 'name',
			required = false,
			type = Types.String,
		}
	},
	[actionTypes.EraseMarker] = {
		[1] = {
			name = 'name',
			required = true,
			type = Types.String,
		},
	},
	[actionTypes.DrawLines] = {
		[1] = {
			name = 'positions',
			required = true,
			type = Types.Positions
		},
	},
	[actionTypes.ClearAllMarkers] = { },

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
