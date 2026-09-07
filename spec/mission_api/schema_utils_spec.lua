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

	describe("SwapNameSuffixForID", function()
		it("turns a Name suffix into ID", function()
			assert.are.equal("teamID", schemaUtils.SwapNameSuffixForID("teamName"))
			assert.are.equal("owningTeamID", schemaUtils.SwapNameSuffixForID("owningTeamName"))
			assert.are.equal("sensorAllyTeamID", schemaUtils.SwapNameSuffixForID("sensorAllyTeamName"))
		end)

		it("turns a plural Names suffix into IDs", function()
			assert.are.equal("allyTeamIDs", schemaUtils.SwapNameSuffixForID("allyTeamNames"))
		end)
	end)

	describe("AssignValueKeys", function()
		local function parameterNamed(triggerType, parameterName)
			for _, parameter in ipairs(triggerDefinitions.Parameters[triggerType]) do
				if parameter.name == parameterName then
					return parameter
				end
			end
		end

		-- LoadTriggerDefinitions assigns them, so the real definitions already carry these.
		it("resolves team parameters on the real trigger definitions", function()
			assert.are.equal("owningTeamID", parameterNamed(triggerTypes.UnitDetected, "owningTeamName").valueKey)
			assert.are.equal(
				"sensorAllyTeamID",
				parameterNamed(triggerTypes.UnitDetected, "sensorAllyTeamName").valueKey
			)
		end)

		-- unitDefName and unitName end in "Name" too, so only the type may decide what gets resolved.
		it("keeps the authored name for parameters of other types", function()
			assert.are.equal("unitDefName", parameterNamed(triggerTypes.UnitDetected, "unitDefName").valueKey)
			assert.are.equal("unitName", parameterNamed(triggerTypes.UnitDetected, "unitName").valueKey)
		end)

		it("assigns a value key to every parameter, so readers never need a fallback", function()
			for _, parameters in pairs(triggerDefinitions.Parameters) do
				for _, parameter in ipairs(parameters) do
					assert.is_string(parameter.valueKey)
				end
			end
		end)
	end)
end)
