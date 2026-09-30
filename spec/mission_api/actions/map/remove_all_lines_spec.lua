require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/map/remove_all_lines.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.remove_all_lines", function()
	---@type table
	local calls

	before_each(function()
		calls = {}
		Builders.MissionApi
			.new()
			:WithModule("MapLines", {
				RemoveAllLines = function(...)
					calls[#calls + 1] = { ... }
				end,
			})
			:Install()
	end)

	it("declares its type and parameters", function()
		assert.are.same({ type = "RemoveAllLines" }, summarizeSchema(action))
	end)

	it("removes all lines", function()
		action.actionFunction()
		assert.are.equal(1, #calls)
	end)
end)
