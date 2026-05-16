---
--- Start the mission and look for validation errors in the log.
---

local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {

	triggerMissingTypeAndActions = {},

	triggerWithInvalidTypeAndNoActions = {
		type = 'invalidType',
	},

	triggerWithInvalidActionID = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 100000000,
		},
		actions = { 'invalidActionID' },
	},

	triggerWithInvalidTypesInSettings = {
		type = triggerTypes.TimeElapsed,
		settings = {
			prerequisites = { 'invalidTriggerID' },
			repeating = 0,
			maxRepeats = true,
			difficulties = 0,
			coop = 0,
			active = 0,
		},
		parameters = {
			gameFrame = 100000000,
		},
		actions = { 'actionMissingType' },
	},

	triggerWithInvalidAllyTeamID = {
		type = triggerTypes.UnitSpotted,
		parameters = {
			spottingAllyTeamID = 777,
		},
		actions = { 'actionMissingType' },
	},

	triggerWithInvalidAreaType = {
		type = triggerTypes.FeatureCreated,
		parameters = {
			area = 'notATable',
		},
		actions = { 'actionMissingType' },
	},

	triggerWithInvalidResourceIncomeSourcesType = {
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			metal = 10,
			sources = 'notATable',
		},
		actions = { 'actionMissingType' },
	},

	triggerWithInvalidResourceIncomeSources = {
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			metal = 10,
			sources = { 'invalidSource1', false, 123 },
		},
		actions = { 'actionMissingType' },
	},
}

local actions = {

	actionMissingType = {},

	actionWithInvalidType = {
		type = 'invalidType',
	},

	actionWithInvalidTriggerID = {
		type = actionTypes.EnableTrigger,
		parameters = {
			triggerID = 'invalidTriggerID',
		},
	},

	actionMissingParameters = {
		type = actionTypes.EnableTrigger,
	},

	actionMissingRequiredParameter = {
		type = actionTypes.EnableTrigger,
		parameters = { },
	},

	actionWithInvalidUnitLoadoutEntries = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'invalidUnitDefName', x = 1800, z = 1600, team = 6, facing = 'invalidFacing' }, -- invalid unitDefName, invalid team, invalid facing
				{ unitDefName = 'armcom', x = 1800, z = 1600, team = 0, facing = 4 },                           -- invalid facing type (number > 3)
				{ unitDefName = 'armcom', x = 1800, z = 1600, team = 0, facing = true },                        -- invalid facing type (boolean)
				{ unitDefName = 'armcom', x = 1800, z = 1600, team = 0, quantity = 'notANumber' },              -- invalid quantity type
				{ unitDefName = 'armcom', x = 1800, z = 1600, team = 0, spacing = 'notANumber' },               -- invalid spacing type
				{ unitDefName = 'armcom', x = 1800, z = 1600, team = 0, construction = 'notABoolean' },         -- invalid construction type
				{ unitDefName = 'armcom', x = 1800, z = 1600, team = 0, neutral = 'notABoolean' },              -- invalid neutral type
				{ unitDefName = 'armcom', x = 1800, z = 1600, team = 0, orders = 'notATable' },                 -- invalid orders type
				{ unitDefName = 'armcom', x = 1800, z = 1600, team = 0, unitName = 'unusedUnitName' },          -- unitName that is never referenced – should produce an "unreferenced" warning
			},
		},
	},

	actionWithInvalidAllyTeamID = {
		type = actionTypes.Defeat,
		parameters = {
			allyTeamIDs = { 777 },
		},
	},

	actionWithNoAllyTeamIDs = {
		type = actionTypes.Defeat,
		parameters = {
			allyTeamIDs = { },
		},
	},

	actionWithInvalidTeamIDAndUnknownUnitName = {
		type = actionTypes.TransferUnits,
		parameters = {
			unitName = 'unknownUnitName',
			newTeam = 777,
		},
	},

	actionWithInvalidOrders = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'validName',
			orders = {
				{ CMD.MOVE, { 1850, 0, 1500 }, { 'shift' } },            -- valid order
				{},                                                      -- empty order
				{ CMD.MOVE },                                            -- missing parameters
				{ CMD.MOVE, { 0, 0 } },                                  -- missing a parameter
				{ 99999, { 0, 0, 0 }, {} },                              -- invalid command ID
				{ nil, { 0, 0, 0 }, {} },                                -- missing command ID
				{ CMD.MOVE, {}, {} },                                    -- missing parameters
				{ CMD.MOVE, 'notATable', {} },                           -- invalid parameters type
				{ CMD.MOVE, { 'invalidX', 0, 1800 }, {} },               -- invalid position
				{ CMD.MOVE, { 1850, 0, 1800 }, { 'invalidOption' } },    -- invalid option
				{ CMD.MOVE, { 1850, 0, 1800 }, { 'shift', 123 } },       -- invalid option type
				{ CMD.MOVE, { 1850, 0, 1800 }, 'notATable' },            -- invalid options type
				{ CMD.CLOAK, 'notANumber' },                             -- invalid parameters type
				{ CMD.RECLAIM, { unitName = 'unknownUnitName' } },       -- unknown unit name in parameters
				{ CMD.RECLAIM, { featureName = 'unknownFeatureName' } }, -- unknown feature name in parameters
				{ 'armllt' },                                            -- valid build order
				{ 'invalidUnitDefName' },                                -- invalid unitDefName
				{ 'armllt', { 1850, 0, 1800, 4 } },                      -- invalid facing
				{ 'armllt', { 1850, 0 } },                               -- missing a parameter
				{ 'armllt', { 1850, 0, 'nonNumber' } },                  -- invalid parameter type
			},
		},
	},

	actionWithNoOrders = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'validName',
			orders = {},
		},
	},

	actionMissing1of3requiredParamsAndUnusedUnitName = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'unusedUnitName',
		},
	},

	actionWithAreaWithInvalidFieldInRectangle = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'validName',
			area = { x1 = 0, z1 = 0, x2 = 0, invalidField = 0 },
		},
	},

	actionWithAreaWithInvalidFieldTypeInRectangle = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'validName',
			area = { x1 = 0, z1 = 0, x2 = 0, z2 = 'invalidType' },
		},
	},

	actionWithAreaWithMissingParmInRectangle = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'validName',
			area = { x1 = 0, z1 = 0, x2 = 0 },
		},
	},

	actionWithAreaWithInvalidFieldInCircle = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'validName',
			area = { x = 0, z = 0, invalidField = 100 },
		},
	},

	actionWithAreaWithInvalidFieldTypeInCircle = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'validName',
			area = { x = 0, z = 0, radius = 'invalidType' },
		},
	},

	actionWithAreaWithMissingParmInCircle = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'validName',
			area = { x = 0, radius = 100},
		},
	},

	actionWithAreaRectangleWithInverseDimensions = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'validName',
			area = { x1 = 10, z1 = 10, x2 = 1, z2 = 1 },
		},
	},

	actionWithInvalidFeatureLoadoutEntries = {
		type = actionTypes.CreateFeatures,
		parameters = {
			featureLoadout = {
				{ featureDefName = 'invalidFeatureDefName', x = 1800, z = 1600, facing = 'invalidFacing', featureName = 'unusedFeatureName' }, -- invalid name, invalid facing
			},
		},
	},

	actionWithUnknownFeatureName = {
		type = actionTypes.DestroyFeatures,
		parameters = {
			featureName = 'unknownFeatureName',
		},
	},

	actionWithJustOneInvalidPosition = {
		type = actionTypes.DrawLines,
		parameters = {
			positions = {
				{ x = 1800, invalidField = 2100 }
			},
		},
	},

	actionWithUnusedMarkerName = {
		type = actionTypes.AddMarker,
		parameters = {
			position = { x = 1900, z = 2200 },
			name = 'unusedMarkerName',
		},
	},

	actionWithInvalidMarkerName = {
		type = actionTypes.EraseMarker,
		parameters = {
			name = 'unknownMarkerName',
		},
	},

	actionWithInvalidWeaponDefName = {
		type = actionTypes.SpawnExplosion,
		parameters = {
			weaponDefName = 'invalidWeaponDefName',
			position = { x = 1500, z = 2200 },
		},
	},

	actionWithNonExistentSoundfile = {
		type = actionTypes.PlaySound,
		parameters = {
			soundfile = 'nonExistentSoundfile',
		},
	},

	actionWithNonWavSoundfile = {
		type = actionTypes.PlaySound,
		parameters = {
			soundfile = 'README.md',
		},
	},

	-- Valid SpawnUnits - 'spawnedCom' is referenced in actionReferencingSpawnedUnitName.
	actionSpawnUnitsValid = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armcom', x = 2000, z = 2000, facing = 'n', team = 0, unitName = 'spawnedCom' },
			},
		},
	},

	-- Valid CreateFeatures - 'spawnedWreck' is referenced in actionReferencingSpawnedFeatureName.
	actionCreateFeaturesValid = {
		type = actionTypes.CreateFeatures,
		parameters = {
			featureLoadout = {
				{ featureDefName = 'corak_dead', x = 2100, z = 2000, facing = 's', featureName = 'spawnedWreck' },
			},
		},
	},

	actionReferencingSpawnedUnitName = {
		type = actionTypes.DespawnUnits,
		parameters = {
			unitName = 'spawnedCom',
		},
	},

	actionReferencingSpawnedFeatureName = {
		type = actionTypes.DestroyFeatures,
		parameters = {
			featureName = 'spawnedWreck',
		},
	},

	actionSpawnUnitsWithInvalidLoadout = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'invalidUnit', x = 100, z = 100, facing = 'n', team = 0 },
				{ unitDefName = 'armcom',      x = 100, z = 100, facing = 'n' }, -- missing 'team'
				{ unitDefName = 'armcom', x = 100, z = 100, facing = 'n', team = 0,
				  orders = {}, -- empty orders table
				},
			},
		},
	},

	actionCreateFeaturesWithInvalidLoadout = {
		type = actionTypes.CreateFeatures,
		parameters = {
			featureLoadout = {
				{ featureDefName = 'corcom_dead', x = 100, z = 100, facing = 'invalidFacing' },
			},
		},
	},

	-- This valid action references a featureName that only exists in FeatureLoadout;
	actionReferencingLoadoutFeatureName = {
		type = actionTypes.DestroyFeatures,
		parameters = {
			featureName = 'loadoutWreck',
		},
	},

	-- This valid action references a unitName that only exists in UnitLoadout;
	actionReferencingLoadoutUnitName = {
		type = actionTypes.DespawnUnits,
		parameters = {
			unitName = 'loadoutCom',
		},
	},
}

local unitLoadout = {
	-- #1: valid entry (unitName is referenced by 'actionReferencingLoadoutUnitName')
	{ unitDefName = 'armcom', x = 1200, z = 800, facing = 'e', team = 0, unitName = 'loadoutCom' },

	-- #2: invalid unitDefName
	{ unitDefName = 'invalidUnit', x = 1200, z = 800, facing = 'n', team = 0 },

	-- #3: missing required field 'z'
	{ unitDefName = 'armcom', x = 1200, facing = 'n', team = 0 },

	-- #4: missing required field 'team'
	{ unitDefName = 'armcom', x = 1200, z = 800, facing = 'n' },

	-- #5: invalid facing value
	{ unitDefName = 'armcom', x = 1200, z = 800, facing = 'q', team = 0 },

	-- #6: invalid type for 'neutral'
	{ unitDefName = 'armcom', x = 1200, z = 800, facing = 's', team = 0, neutral = 1 },

	-- #7: unitName that is never referenced – should produce an "unreferenced" warning
	{ unitDefName = 'armcom', x = 1300, z = 900, facing = 's', team = 0, unitName = 'unusedLoadoutUnitName' },

	-- #8: valid entry with orders (move, then queued patrol)
	{ unitDefName = 'armcom', x = 1400, z = 900, facing = 'n', team = 0,
	  orders = {
	    { CMD.MOVE,   { 1500, 0, 900 },  {}         },  -- valid move
	    { CMD.PATROL, { 1400, 0, 900 },  { 'shift' } }, -- valid queued patrol
	  },
	},

	-- #9: orders table is empty – should produce an "Orders table is empty" error
	{ unitDefName = 'armcom', x = 1500, z = 900, facing = 'n', team = 0,
	  orders = {},
	},
}

local featureLoadout = {
	-- #1: valid entry (featureName is referenced by 'actionReferencingLoadoutFeatureName')
	{ featureDefName = 'corcom_dead', x = 2000, z = 1500, facing = 's', featureName = 'loadoutWreck' },

	-- #2: invalid featureDefName
	{ featureDefName = 'invalidFeature', x = 2000, z = 1500, facing = 's' },

	-- #3: missing required field 'x'
	{ featureDefName = 'corcom_dead', z = 1500, facing = 's' },

	-- #4: invalid facing value
	{ featureDefName = 'corcom_dead', x = 2000, z = 1500, facing = 'invalidFacing' },

	-- #5: invalid type for 'featureName'
	{ featureDefName = 'corcom_dead', x = 2000, z = 1500, facing = 's', featureName = 42 },

	-- #6: featureName that is never referenced – should produce an "unreferenced" warning
	{ featureDefName = 'corcom_dead', x = 2200, z = 1500, facing = 's', featureName = 'unusedLoadoutFeatureName' },
}

return {
	Triggers       = triggers,
	Actions        = actions,
	UnitLoadout    = unitLoadout,
	FeatureLoadout = featureLoadout,
}
