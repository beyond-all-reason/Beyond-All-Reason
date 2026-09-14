require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/map/remove_all_map_markers.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.remove_all_map_markers", function()

	local missionApi, eraseCalls, sendCommandsCalls

	before_each(function()
		missionApi = Builders.MissionApi
			.new()
			:WithMarker("a", { x = 1, y = 0, z = 1 })
			:WithMarker("b", { x = 2, y = 0, z = 2 })
			:Install()
		_G.Spring = Builders.Spring.new():Build()
		eraseCalls = Spring.calls.markerErasePosition
		sendCommandsCalls = Spring.calls.sendCommands
	end)

	it("declares its type and parameters", function()
		assert.are.same({ type = "RemoveAllMapMarkers" }, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("resets markerNames to an empty table", function()
			action.actionFunction()
			assert.are.same({}, missionApi.markerNames)
		end)

		it("erases every marker it holds, at its stored position", function()
			action.actionFunction()
			assert.are.equal(2, #eraseCalls)
			local erased = {}
			for _, call in ipairs(eraseCalls) do
				erased[call.x .. "," .. call.z] = true
			end
			assert.are.same({ ["1,1"] = true, ["2,2"] = true }, erased)
		end)

		it("erases nothing when it holds no markers", function()
			missionApi = Builders.MissionApi.new():Install()
			action.actionFunction()
			assert.are.equal(0, #eraseCalls)
		end)

		it("leaves marks it did not place, sending no clearmapmarks", function()
			action.actionFunction()
			assert.are.equal(0, #sendCommandsCalls)
		end)
	end)

end)
