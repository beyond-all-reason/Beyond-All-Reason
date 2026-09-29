require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/map/remove_line.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.remove_line", function()
	local missionApi, eraseCalls

	before_each(function()
		missionApi = Builders.MissionApi
			.new()
			:WithLine("wall", { { x = 1, y = 0, z = 1 }, { x = 2, y = 0, z = 2 } })
			:WithLine("fence", { { x = 7, y = 0, z = 7 } })
			:Install()
		_G.Spring = Builders.Spring.new():Build()
		eraseCalls = Spring.calls.markerErasePosition
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "RemoveLine",
			lineName = "String!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("erases at the start of every segment of the named line", function()
			action.actionFunction("wall")
			assert.are.equal(2, #eraseCalls)
			assert.are.equal(1, eraseCalls[1].x)
			assert.are.equal(2, eraseCalls[2].x)
		end)

		it("forgets the line and leaves the others", function()
			action.actionFunction("wall")
			assert.is_nil(missionApi.lineNames.wall)
			assert.is_not_nil(missionApi.lineNames.fence)
		end)

		it("is a no-op for an unknown line name", function()
			action.actionFunction("nothing")
			assert.are.equal(0, #eraseCalls)
		end)
	end)
end)
