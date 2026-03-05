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
			allyTeamID = 777,
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

	actionWithInvalidTeamIDAndInvalidUnitDefNameAndInvalidPositionAndInvalidFacing = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'invalidUnitDefName',
			teamID = 6,
			position = { x = 1800, invalidField = 1600 },
			facing = 'invalidFacing',
		},
	},

	actionWithInvalidFacingNumber = {
		type = actionTypes.SpawnUnits,
		parameters = {
			teamID = 0,
			position = { x = 1800, z = 1600 },
			facing = 4,
		},
	},

	actionWithInvalidFacingType = {
		type = actionTypes.SpawnUnits,
		parameters = {
			teamID = 0,
			position = { x = 1800, z = 1600 },
			facing = true,
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
				{ CMD.MOVE, { 1850, 0, 1500 }, { 'shift' } },         -- valid order
				{},                                                   -- empty order
				{ CMD.MOVE },                                         -- missing parameters
				{ CMD.MOVE, { 0, 0 } },                               -- missing a parameter
				{ 99999, { 0, 0, 0 }, {} },                           -- invalid command ID
				{ nil, { 0, 0, 0 }, {} },                             -- missing command ID
				{ CMD.MOVE, {}, {} },                                 -- missing parameters
				{ CMD.MOVE, 'notATable', {} },                        -- invalid parameters type
				{ CMD.MOVE, { 'invalidX', 0, 1800 }, {} },            -- invalid position
				{ CMD.MOVE, { 1850, 0, 1800 }, { 'invalidOption' } }, -- invalid option
				{ CMD.MOVE, { 1850, 0, 1800 }, { 'shift', 123 } },    -- invalid option type
				{ CMD.MOVE, { 1850, 0, 1800 }, 'notATable' },         -- invalid options type
				{ CMD.CLOAK, 'notANumber' },                          -- invalid parameters type
				{ 'armllt' },                                         -- valid build order
				{ 'invalidUnitDefName' },                             -- invalid unitDefName
				{ 'armllt', { 1850, 0, 1800, 4 } },                   -- invalid facing
				{ 'armllt', { 1850, 0 } },                            -- missing a parameter
				{ 'armllt', { 1850, 0, 'nonNumber' } },               -- invalid parameter type
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

	actionWithInvalidFeatureDefNameAndInvalidFacingAndUnusedFeatureName = {
		type = actionTypes.CreateFeature,
		parameters = {
			featureDefName = 'invalidFeatureDefName',
			position = { x = 1800, z = 1600 },
			featureName = 'unusedFeatureName',
			facing = 'invalidFacing',
		},
	},

	actionWithUnknownFeatureName = {
		type = actionTypes.DestroyFeature,
		parameters = {
			featureName = 'unknownFeatureName',
		},
	},

	-- Valid SpawnLoadout - both names are referenced in the following 2 actions.
	actionSpawnLoadoutValid = {
		type = actionTypes.SpawnLoadout,
		parameters = {
			unitLoadout = {
				{ name = 'armcom', x = 2000, z = 2000, facing = 'n', team = 0, unitName = 'spawnedCom' },
			},
			featureLoadout = {
				{ name = 'corak_dead', x = 2100, z = 2000, facing = 's', resurrectAs = 'corcom', featureName = 'spawnedWreck' },
			},
		},
	},

	actionReferencingSpawnLoadoutUnitName = {
		type = actionTypes.DespawnUnits,
		parameters = {
			unitName = 'spawnedCom',
		},
	},

	actionReferencingSpawnLoadoutFeatureName = {
		type = actionTypes.DestroyFeature,
		parameters = {
			featureName = 'spawnedWreck',
		},
	},

	actionSpawnLoadoutWithInvalidEntries = {
		type = actionTypes.SpawnLoadout,
		parameters = {
			unitLoadout = {
				{ name = 'invalidUnit', x = 100, z = 100, facing = 'n', team = 0 },
				{ name = 'armcom',      x = 100, z = 100, facing = 'n' }, -- missing 'team'
			},
			featureLoadout = {
				{ name = 'corcom_dead', x = 100, z = 100, facing = 'invalidFacing' },
				{ name = 'corcom_dead', x = 100, z = 100, facing = 's', resurrectAs = 'invalidUnit' },
			},
		},
	},

	-- This valid action references a featureName that only exists in FeatureLoadout;
	actionReferencingLoadoutFeatureName = {
		type = actionTypes.DestroyFeature,
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
	{ name = 'armcom', x = 1200, z = 800, facing = 'e', team = 0, unitName = 'loadoutCom' },

	-- #2: invalid unitDefName
	{ name = 'invalidUnit', x = 1200, z = 800, facing = 'n', team = 0 },

	-- #3: missing required field 'z'
	{ name = 'armcom', x = 1200, facing = 'n', team = 0 },

	-- #4: missing required field 'team'
	{ name = 'armcom', x = 1200, z = 800, facing = 'n' },

	-- #5: invalid facing value
	{ name = 'armcom', x = 1200, z = 800, facing = 'q', team = 0 },

	-- #6: invalid type for 'neutral'
	{ name = 'armcom', x = 1200, z = 800, facing = 's', team = 0, neutral = 1 },

	-- #7: unitName that is never referenced – should produce an "unreferenced" warning
	{ name = 'armcom', x = 1300, z = 900, facing = 's', team = 0, unitName = 'unusedLoadoutUnitName' },
}

local featureLoadout = {
	-- #1: valid entry (featureName is referenced by 'actionReferencingLoadoutFeatureName')
	{ name = 'corcom_dead', x = 2000, z = 1500, facing = 's', resurrectAs = 'corcom', featureName = 'loadoutWreck' },

	-- #2: invalid featureDefName
	{ name = 'invalidFeature', x = 2000, z = 1500, facing = 's' },

	-- #3: missing required field 'x'
	{ name = 'corcom_dead', z = 1500, facing = 's' },

	-- #4: invalid facing value
	{ name = 'corcom_dead', x = 2000, z = 1500, facing = 'invalidFacing' },

	-- #5: invalid resurrectAs
	{ name = 'corcom_dead', x = 2000, z = 1500, facing = 's', resurrectAs = 'invalidUnit' },

	-- #6: invalid type for 'featureName'
	{ name = 'corcom_dead', x = 2000, z = 1500, facing = 's', featureName = 42 },

	-- #7: featureName that is never referenced – should produce an "unreferenced" warning
	{ name = 'corcom_dead', x = 2200, z = 1500, facing = 's', featureName = 'unusedLoadoutFeatureName' },
}

return {
	Triggers       = triggers,
	Actions        = actions,
	UnitLoadout    = unitLoadout,
	FeatureLoadout = featureLoadout,
}
