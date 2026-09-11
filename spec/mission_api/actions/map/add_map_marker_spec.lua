require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/map/add_map_marker.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local missionApi = GG["MissionAPI"]

describe("mission_api.actions.add_map_marker", function()

	before_each(function()
		Builders.MissionApi.new():Install()
		_G.Spring = Builders.Spring.new():Build()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "AddMapMarker",
			markerID = "String!",
			position = "Position!",
			markerType = "String",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("calls Spring.MarkerAddPoint with the given position", function()
			action.actionFunction("beacon", { x = 10, y = 20, z = 30 }, nil)
			assert.are.equal(1, #Spring.calls.markerAddPoint)
			assert.are.equal(10, Spring.calls.markerAddPoint[1].x)
			assert.are.equal(20, Spring.calls.markerAddPoint[1].y)
			assert.are.equal(30, Spring.calls.markerAddPoint[1].z)
		end)

		it("stores the position in markerNames under the marker ID", function()
			local position = { x = 1, y = 2, z = 3 }
			action.actionFunction("beacon", position, nil)
			assert.are.same(position, missionApi.markerNames["beacon"])
		end)

		it("places the marker whatever the marker type says", function()
			action.actionFunction("beacon", { x = 0, y = 0, z = 0 }, "terrain")
			assert.are.equal(1, #Spring.calls.markerAddPoint)
			assert.are.same({ x = 0, y = 0, z = 0 }, missionApi.markerNames["beacon"])
		end)

		it("passes false as the local flag to MarkerAddPoint", function()
			action.actionFunction("beacon", { x = 0, y = 0, z = 0 }, nil)
			assert.is_false(Spring.calls.markerAddPoint[1].local_)
		end)
	end)

end)
