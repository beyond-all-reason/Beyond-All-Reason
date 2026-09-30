require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/map/remove_line.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.remove_line", function()
	---@type table
	local calls

	before_each(function()
		calls = {}
		Builders.MissionApi
			.new()
			:WithModule("MapLines", {
				RemoveLine = function(...)
					calls[#calls + 1] = { ... }
				end,
			})
			:Install()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "RemoveLine",
			lineName = "String!",
		}, summarizeSchema(action))
	end)

	it("removes the named line", function()
		action.actionFunction("wall")
		assert.are.same({ { "wall" } }, calls)
	end)
end)
