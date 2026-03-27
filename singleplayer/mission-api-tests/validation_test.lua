---
--- Start the mission and look for validation errors in the log.
---

local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local objectives = {
	objectiveWithEmptyText = {
		text = "",
	},
}

local initialStage = 'invalidStage'
local stages = {
	stageWithNoTitleAndInvalidObjectiveID = {
		objectives = { 'invalidObjectiveID' },
	},
}

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
			name = 'invalidMarkerName',
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

	actionWithInvalidStageID = {
		type = actionTypes.ChangeStage,
		parameters = {
			stageID = 'invalidStageID',
		},
	},

	actionWithInvalidObjectiveID = {
		type = actionTypes.UpdateObjective,
		parameters = {
			objectiveID = 'invalidObjectiveID',
			completed = true,
		},
	}
}

return {
	Objectives = objectives,
	InitialStage = initialStage,
	Stages = stages,
	Triggers = triggers,
	Actions = actions,
}
