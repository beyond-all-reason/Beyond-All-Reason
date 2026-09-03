require("spec_helper")

local RegisterMissionApiModules = require("mission_api.spec_helper")

-- mirror eager module loading in api_missions.lua; the trigger files read
-- GG['MissionAPI'].Modules.ParameterTypes at load time.
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
RegisterMissionApiModules()

local triggerDefinitions = VFS.Include("luarules/mission_api/triggers_loader.lua").LoadTriggerDefinitions()
local parameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
local schemaUtils = VFS.Include("luarules/mission_api/schema_utils.lua")

local triggerTypes = triggerDefinitions.Types

describe("mission_api.schema_utils", function()
	describe("GetTypesWithParameterType", function()
		it("returns all trigger types that have a Quantity parameter", function()
			local result =
				schemaUtils.GetTypesWithParameterType(triggerDefinitions.Parameters, parameterTypes.Types.Quantity)
			assert.is_true(result[triggerTypes.UnitsOwned])
			assert.is_true(result[triggerTypes.TotalUnitsBuilt])
			assert.is_true(result[triggerTypes.TotalUnitsLost])
			assert.is_true(result[triggerTypes.TotalUnitsKilled])
			assert.is_true(result[triggerTypes.TotalUnitsCaptured])
		end)

		it("does not include trigger types that lack a Quantity parameter", function()
			local result =
				schemaUtils.GetTypesWithParameterType(triggerDefinitions.Parameters, parameterTypes.Types.Quantity)
			assert.is_nil(result[triggerTypes.TimeElapsed])
			assert.is_nil(result[triggerTypes.UnitKilled])
		end)

		it("returns an empty table when no types have the given parameter type", function()
			local result = schemaUtils.GetTypesWithParameterType(triggerDefinitions.Parameters, "NonExistentType")
			assert.are.same({}, result)
		end)
	end)

	describe("GetNamesWithParameterType", function()
		it("returns the parameter name per trigger type that has the parameter type", function()
			local result =
				schemaUtils.GetNamesWithParameterType(triggerDefinitions.Parameters, parameterTypes.Types.ObjectiveID)
			assert.are.equal("objectiveID", result[triggerTypes.ObjectiveCompleted])
			assert.are.equal(
				"quantity",
				schemaUtils.GetNamesWithParameterType(triggerDefinitions.Parameters, parameterTypes.Types.Quantity)[triggerTypes.UnitsOwned]
			)
		end)

		it("does not include trigger types that lack the parameter type", function()
			local result =
				schemaUtils.GetNamesWithParameterType(triggerDefinitions.Parameters, parameterTypes.Types.ObjectiveID)
			assert.is_nil(result[triggerTypes.TimeElapsed])
			assert.is_nil(result[triggerTypes.UnitsOwned])
		end)

		it("returns an empty table when no types have the given parameter type", function()
			local result = schemaUtils.GetNamesWithParameterType(triggerDefinitions.Parameters, "NonExistentType")
			assert.are.same({}, result)
		end)
	end)
end)
