local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/units/add_derived_unit_name.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.add_derived_unit_name", function()
	it("declares its type and parameters", function()
		assert.are.same({
			type = "AddDerivedUnitName",
			unitName = "UnitName!",
			filter = "UnitFilter!",
			except = "UnitFilters",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("adds the derived name with its rule", function()
			local calls = {}
			MissionApiBuilder.new()
				:WithModule("DerivedNames", {
					AddDerivedUnitName = function(unitName, filter, except)
						calls[#calls + 1] = { unitName = unitName, filter = filter, except = except }
					end,
				})
				:Install()

			action.actionFunction("army", { teamName = 0 }, { { unitName = "commander" } })

			assert.are.same(
				{ { unitName = "army", filter = { teamName = 0 }, except = { { unitName = "commander" } } } },
				calls
			)
		end)
	end)
end)
