local validation = VFS.Include('luarules/mission_api/validation.lua')
local triggerSchema = VFS.Include('luarules/mission_api/triggers_schema.lua')
local actionSchema = VFS.Include('luarules/mission_api/actions_schema.lua')

describe("mission_api.validation.ValidateReferences", function()
	local originalSpringLog
	local loggedMessages

	before_each(function()
		loggedMessages = {}
		originalSpringLog = Spring.Log
		Spring.Log = function(_, _, message)
			loggedMessages[#loggedMessages + 1] = message
		end

		GG['MissionAPI'] = {
			TriggerTypes = triggerSchema.Types,
			ActionTypes = actionSchema.Types,
			Triggers = {},
			Actions = {},
		}
	end)

	after_each(function()
		Spring.Log = originalSpringLog
		GG['MissionAPI'] = nil
	end)

	it("treats statistics trigger unitName parameters as valid references", function()
		local triggerTypes = GG['MissionAPI'].TriggerTypes
		local actionTypes = GG['MissionAPI'].ActionTypes

		GG['MissionAPI'].Triggers = {
			totalUnitsKilledNamedReached = {
				type = triggerTypes.TotalUnitsKilled,
				parameters = {
					teamID = 0,
					quantity = 1,
					unitName = 'enemyBot',
				},
			},
			totalUnitsLostAliasReached = {
				type = triggerTypes.TotalUnitsLost,
				parameters = {
					teamID = 0,
					quantity = 1,
					unitName = 'friendlyAce',
				},
			},
			totalUnitsCapturedNamedReached = {
				type = triggerTypes.TotalUnitsCaptured,
				parameters = {
					teamID = 0,
					quantity = 1,
					unitName = 'capturePrize',
				},
			},
		}

		GG['MissionAPI'].Actions = {
			spawnEnemyBot = {
				type = actionTypes.SpawnUnits,
				parameters = {
					unitName = 'enemyBot',
				},
			},
			nameFriendlyBotAlias = {
				type = actionTypes.NameUnits,
				parameters = {
					unitName = 'friendlyAce',
				},
			},
			nameCaptureTargetAlias = {
				type = actionTypes.NameUnits,
				parameters = {
					unitName = 'capturePrize',
				},
			},
		}

		validation.ValidateReferences()

		assert.are.same({}, loggedMessages)
	end)

	it("still reports truly unreferenced created unit names", function()
		local actionTypes = GG['MissionAPI'].ActionTypes

		GG['MissionAPI'].Actions = {
			spawnUnusedUnit = {
				type = actionTypes.SpawnUnits,
				parameters = {
					unitName = 'unusedUnitName',
				},
			},
		}

		validation.ValidateReferences()

		assert.is_true(table.any(loggedMessages, function(message)
			return message:find("Unit name 'unusedUnitName' created, but not referenced", 1, true) ~= nil
		end))
	end)
end)
