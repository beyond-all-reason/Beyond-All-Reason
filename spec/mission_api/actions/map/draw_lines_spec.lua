require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/map/draw_lines.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.draw_lines", function()
	---@type table
	local calls

	before_each(function()
		calls = {}
		Builders.MissionApi
			.new()
			:WithModule("MapLines", {
				DrawLine = function(...)
					calls[#calls + 1] = { ... }
				end,
			})
			:Install()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "DrawLines",
			positions = "Positions!",
			lineName = "String!",
		}, summarizeSchema(action))
	end)

	it("draws the positions under the line name", function()
		local positions = { { x = 0, y = 0, z = 0 }, { x = 1, y = 0, z = 1 } }
		action.actionFunction(positions, "wall")
		assert.are.equal(1, #calls)
		assert.are.equal("wall", calls[1][1])
		assert.are.equal(positions, calls[1][2])
	end)
end)
