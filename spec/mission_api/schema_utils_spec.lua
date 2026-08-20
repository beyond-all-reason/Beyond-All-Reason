require("spec_helper")

-- mirror eager module loading in api_missions.lua; the trigger files read
-- GG['MissionAPI'].Modules.ParameterTypes at load time.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

local triggerDefinitions = VFS.Include('luarules/mission_api/triggers_loader.lua').LoadTriggerDefinitions()
local parameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
local schemaUtils    = VFS.Include('luarules/mission_api/schema_utils.lua')

local triggerTypes = triggerDefinitions.Types

describe("mission_api.schema_utils", function()
	describe("GetTypesWithParameterType", function()
		it("returns all trigger types that have a Quantity parameter", function()
			local result = schemaUtils.GetTypesWithParameterType(triggerDefinitions.Parameters, parameterTypes.Types.Quantity)
			assert.is_true(result[triggerTypes.UnitsOwned])
			assert.is_true(result[triggerTypes.TotalUnitsBuilt])
			assert.is_true(result[triggerTypes.TotalUnitsLost])
			assert.is_true(result[triggerTypes.TotalUnitsKilled])
			assert.is_true(result[triggerTypes.TotalUnitsCaptured])
		end)

		it("does not include trigger types that lack a Quantity parameter", function()
			local result = schemaUtils.GetTypesWithParameterType(triggerDefinitions.Parameters, parameterTypes.Types.Quantity)
			assert.is_nil(result[triggerTypes.TimeElapsed])
			assert.is_nil(result[triggerTypes.UnitKilled])
		end)

		it("returns an empty table when no types have the given parameter type", function()
			local result = schemaUtils.GetTypesWithParameterType(triggerDefinitions.Parameters, 'NonExistentType')
			assert.are.same({}, result)
		end)
	end)
end)
