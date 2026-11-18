local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/units/remove_derived_unit_name.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.remove_derived_unit_name", function()
	it("declares its type and parameters", function()
		assert.are.same({
			type = "RemoveDerivedUnitName",
			unitName = "UnitName!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("removes the derived name", function()
			local calls = {}
			MissionApiBuilder.new()
				:WithModule("DerivedNames", {
					RemoveDerivedUnitName = function(unitName)
						calls[#calls + 1] = { unitName = unitName }
					end,
				})
				:Install()

			action.actionFunction("army")

			assert.are.same({ { unitName = "army" } }, calls)
		end)
	end)
end)
