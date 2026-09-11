require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/map/clear_all_markers.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.clear_all_markers", function()

	local missionApi, sendCommandsCalls

	before_each(function()
		missionApi = Builders.MissionApi
			.new()
			:WithMarker("a", { x = 1, y = 0, z = 1 })
			:WithMarker("b", { x = 2, y = 0, z = 2 })
			:Install()
		_G.Spring = Builders.Spring.new():Build()
		sendCommandsCalls = Spring.calls.sendCommands
	end)

	it("declares its type and parameters", function()
		assert.are.same({ type = "ClearAllMarkers" }, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("resets markerNames to an empty table", function()
			action.actionFunction()
			assert.are.same({}, missionApi.markerNames)
		end)

		it("calls Spring.SendCommands('clearmapmarks')", function()
			action.actionFunction()
			assert.are.equal(1, #sendCommandsCalls)
			assert.are.equal("clearmapmarks", sendCommandsCalls[1])
		end)
	end)

end)
