GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local actions = VFS.Include("luarules/mission_api/actions/environment/set_map_skybox.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.set_map_skybox", function()
	local calls

	before_each(function()
		calls = {}
		GG.MapLighting = {
			SetSkybox = function(texture, rotation)
				calls[#calls + 1] = { texture, rotation }
			end,
		}
	end)

	after_each(function()
		GG.MapLighting = nil
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "SetMapSkybox",
			texture = "SkyboxFile!",
			rotation = "Number",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("passes the texture and the rotation", function()
			action.actionFunction("maps/sky.dds", 90)
			action.actionFunction("maps/sky.dds")

			assert.are.same({ { "maps/sky.dds", 90 }, { "maps/sky.dds", nil } }, calls)
		end)
	end)
end)
