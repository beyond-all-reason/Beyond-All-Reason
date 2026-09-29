require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/map/remove_all_lines.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.remove_all_lines", function()
	local missionApi, eraseCalls

	before_each(function()
		missionApi = Builders.MissionApi
			.new()
			:WithLine("wall", { { x = 1, y = 0, z = 1 }, { x = 2, y = 0, z = 2 } })
			:WithLine("fence", { { x = 5, y = 0, z = 5 } })
			:Install()
		_G.Spring = Builders.Spring.new():Build()
		eraseCalls = Spring.calls.markerErasePosition
	end)

	it("declares its type and parameters", function()
		assert.are.same({ type = "RemoveAllLines" }, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("erases every line", function()
			action.actionFunction()
			local erased = {}
			for _, call in ipairs(eraseCalls) do
				erased[call.x] = true
			end
			assert.are.same({ [1] = true, [2] = true, [5] = true }, erased)
		end)

		it("forgets every line", function()
			action.actionFunction()
			assert.are.same({}, missionApi.lineNames)
		end)

		it("does not touch markers", function()
			missionApi.markerNames.flag = { x = 9, y = 0, z = 9 }
			action.actionFunction()
			assert.is_not_nil(missionApi.markerNames.flag)
		end)
	end)
end)
