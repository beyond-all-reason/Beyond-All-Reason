require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/map/draw_lines.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.draw_lines", function()
	local missionApi

	before_each(function()
		missionApi = Builders.MissionApi.new():Install()
		_G.Spring = Builders.Spring.new():Build()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "DrawLines",
			positions = "Positions!",
			lineName = "String!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("draws a single line between two positions", function()
			local positions = {
				{ x = 0, y = 10, z = 0 },
				{ x = 5, y = 10, z = 5 },
			}
			action.actionFunction(positions, "a")
			assert.are.equal(1, #Spring.calls.markerAddLine)
			local l = Spring.calls.markerAddLine[1]
			assert.are.equal(0, l.x1)
			assert.are.equal(5, l.x2)
			assert.are.equal(5, l.z2)
		end)

		it("draws N-1 lines for N positions", function()
			local positions = {
				{ x = 0, y = 0, z = 0 },
				{ x = 1, y = 0, z = 0 },
				{ x = 2, y = 0, z = 0 },
				{ x = 3, y = 0, z = 0 },
			}
			action.actionFunction(positions, "a")
			assert.are.equal(3, #Spring.calls.markerAddLine)
		end)

		it("connects consecutive positions in order", function()
			local positions = {
				{ x = 10, y = 0, z = 10 },
				{ x = 20, y = 0, z = 20 },
				{ x = 30, y = 0, z = 30 },
			}
			action.actionFunction(positions, "a")
			assert.are.equal(10, Spring.calls.markerAddLine[1].x1)
			assert.are.equal(20, Spring.calls.markerAddLine[1].x2)
			assert.are.equal(20, Spring.calls.markerAddLine[2].x1)
			assert.are.equal(30, Spring.calls.markerAddLine[2].x2)
		end)

		it("draws no lines for a single position", function()
			action.actionFunction({ { x = 0, y = 0, z = 0 } }, "a")
			assert.are.equal(0, #Spring.calls.markerAddLine)
		end)

		it("keeps a named line under its name, as the start of each segment", function()
			action.actionFunction({ { x = 1, y = 0, z = 1 }, { x = 2, y = 0, z = 2 }, { x = 3, y = 0, z = 3 } }, "wall")
			assert.are.same({ { x = 1, y = 0, z = 1 }, { x = 2, y = 0, z = 2 } }, missionApi.lineNames.wall)
		end)

		it("erases the previous line when a name is drawn again", function()
			missionApi.lineNames.wall = { { x = 9, y = 0, z = 9 } }
			action.actionFunction({ { x = 1, y = 0, z = 1 }, { x = 2, y = 0, z = 2 } }, "wall")
			assert.are.equal(1, #Spring.calls.markerErasePosition)
			assert.are.equal(9, Spring.calls.markerErasePosition[1].x)
			assert.are.same({ { x = 1, y = 0, z = 1 } }, missionApi.lineNames.wall)
		end)
	end)

end)
