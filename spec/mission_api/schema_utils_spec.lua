local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- mirror eager module loading in api_missions.lua; the trigger files read
-- GG['MissionAPI'].Modules.ParameterTypes at load time.
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = MissionSpecEnv.include(env, "luarules/mission_api/parameter_types.lua")
MissionSpecEnv.registerModules(env)

local conditionDefinitions = MissionSpecEnv.include(env, "luarules/mission_api/conditions_loader.lua")
	.LoadConditionDefinitions()
local parameterTypes = MissionSpecEnv.include(env, "luarules/mission_api/parameter_types.lua")
local schemaUtils = MissionSpecEnv.include(env, "luarules/mission_api/schema_utils.lua")

local conditionTypes = conditionDefinitions.Types

describe("mission_api.schema_utils", function()
	describe("GetTypesWithParameterType", function()
		it("returns all condition types that have a Quantity parameter", function()
			local result =
				schemaUtils.GetTypesWithParameterType(conditionDefinitions.Parameters, parameterTypes.Types.Quantity)
			assert.is_true(result[conditionTypes.UnitsOwned])
			assert.is_true(result[conditionTypes.TotalUnitsBuilt])
			assert.is_true(result[conditionTypes.TotalUnitsLost])
			assert.is_true(result[conditionTypes.TotalUnitsKilled])
			assert.is_true(result[conditionTypes.TotalUnitsCaptured])
		end)

		it("does not include condition types that lack a Quantity parameter", function()
			local result =
				schemaUtils.GetTypesWithParameterType(conditionDefinitions.Parameters, parameterTypes.Types.Quantity)
			assert.is_nil(result[conditionTypes.TimeElapsed])
			assert.is_nil(result[conditionTypes.UnitKilled])
		end)

		it("returns an empty table when no types have the given parameter type", function()
			local result = schemaUtils.GetTypesWithParameterType(conditionDefinitions.Parameters, "NonExistentType")
			assert.are.same({}, result)
		end)
	end)

	describe("GetParameterNamesWithType", function()
		it("returns every parameter of the given type, per condition type", function()
			local result =
				schemaUtils.GetParameterNamesWithType(conditionDefinitions.Parameters, parameterTypes.Types.UnitName)

			-- A trigger can name several units at once, e.g. a passenger and its transport.
			table.sort(result[conditionTypes.TransportLoaded])
			assert.are.same({ "passengerName", "transportName" }, result[conditionTypes.TransportLoaded])
			assert.are.same({ "unitName" }, result[conditionTypes.UnitKilled])
		end)

		it("omits condition types without a parameter of that type", function()
			local result =
				schemaUtils.GetParameterNamesWithType(conditionDefinitions.Parameters, parameterTypes.Types.UnitName)

			assert.is_nil(result[conditionTypes.TimeElapsed])
		end)

		it("returns an empty table when no types have the given parameter type", function()
			local result = schemaUtils.GetParameterNamesWithType(conditionDefinitions.Parameters, "NonExistentType")
			assert.are.same({}, result)
		end)
	end)

	describe("CollateSchemas", function()
		it("includes the settings every trigger shares", function()
			GG["MissionAPI"].ConditionDefinitions = conditionDefinitions
			GG["MissionAPI"].ActionDefinitions = { Types = {}, Parameters = {} }

			local schemas = schemaUtils.CollateSchemas()

			assert.are.same(
				MissionSpecEnv.include(env, "luarules/mission_api/triggers_schema.lua").Settings,
				schemas.triggerSettings
			)
			assert.is_not_nil(schemas.conditions.UnitKilled)
		end)
	end)
end)
