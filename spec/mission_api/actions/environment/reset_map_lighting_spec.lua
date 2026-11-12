GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local actions = VFS.Include("luarules/mission_api/actions/environment/reset_map_lighting.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.reset_map_lighting", function()
	local calls

	before_each(function()
		calls = {}
		GG.MapLighting = {
			Reset = function(duration)
				calls[#calls + 1] = { duration }
			end,
		}
	end)

	after_each(function()
		GG.MapLighting = nil
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "ResetMapLighting",
			transitionDuration = "Quantity",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("passes the transition duration, or none", function()
			action.actionFunction(2)
			action.actionFunction()

			assert.are.same({ { 2 }, {} }, calls)
		end)
	end)
end)
