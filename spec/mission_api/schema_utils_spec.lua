local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- mirror eager module loading in api_missions.lua; the trigger files read
-- GG['MissionAPI'].Modules.ParameterTypes at load time.
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = MissionSpecEnv.include(env, "luarules/mission_api/parameter_types.lua")
MissionSpecEnv.registerModules(env)

local triggerDefinitions = MissionSpecEnv.include(env, "luarules/mission_api/conditions_loader.lua")
	.LoadConditionDefinitions()
local parameterTypes = MissionSpecEnv.include(env, "luarules/mission_api/parameter_types.lua")
local schemaUtils = MissionSpecEnv.include(env, "luarules/mission_api/schema_utils.lua")

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

	describe("GetParameterNamesWithType", function()
		it("returns every parameter of the given type, per trigger type", function()
			local result =
				schemaUtils.GetParameterNamesWithType(triggerDefinitions.Parameters, parameterTypes.Types.UnitName)

			-- A trigger can name several units at once, e.g. a passenger and its transport.
			table.sort(result[triggerTypes.TransportLoaded])
			assert.are.same({ "passengerName", "transportName" }, result[triggerTypes.TransportLoaded])
			assert.are.same({ "unitName" }, result[triggerTypes.UnitKilled])
		end)

		it("omits trigger types without a parameter of that type", function()
			local result =
				schemaUtils.GetParameterNamesWithType(triggerDefinitions.Parameters, parameterTypes.Types.UnitName)

			assert.is_nil(result[triggerTypes.TimeElapsed])
		end)

		it("returns an empty table when no types have the given parameter type", function()
			local result = schemaUtils.GetParameterNamesWithType(triggerDefinitions.Parameters, "NonExistentType")
			assert.are.same({}, result)
		end)
	end)
end)
