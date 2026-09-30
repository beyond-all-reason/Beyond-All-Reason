require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local mapLines = VFS.Include("luarules/mission_api/map_lines.lua")

describe("mission_api.map_lines", function()
	---@type table, table, table
	local missionApi, addCalls, eraseCalls

	before_each(function()
		missionApi = Builders.MissionApi.new():Install()
		_G.Spring = Builders.Spring.new():Build() ---@diagnostic disable-line: global-in-non-module
		addCalls = Spring.calls.markerAddLine
		eraseCalls = Spring.calls.markerErasePosition
	end)

	describe("DrawLine", function()
		it("draws a line between two positions", function()
			mapLines.DrawLine("a", { { x = 0, y = 10, z = 0 }, { x = 5, y = 10, z = 5 } })
			assert.are.equal(1, #addCalls)
			assert.are.equal(0, addCalls[1].x1)
			assert.are.equal(5, addCalls[1].x2)
			assert.are.equal(5, addCalls[1].z2)
		end)

		it("draws N-1 lines for N positions, joining consecutive positions in order", function()
			mapLines.DrawLine("a", {
				{ x = 10, y = 0, z = 10 },
				{ x = 20, y = 0, z = 20 },
				{ x = 30, y = 0, z = 30 },
			})
			assert.are.equal(2, #addCalls)
			assert.are.equal(10, addCalls[1].x1)
			assert.are.equal(20, addCalls[1].x2)
			assert.are.equal(20, addCalls[2].x1)
			assert.are.equal(30, addCalls[2].x2)
		end)

		it("draws no lines for a single position", function()
			mapLines.DrawLine("a", { { x = 0, y = 0, z = 0 } })
			assert.are.equal(0, #addCalls)
		end)

		it("keeps the line under its name, as the start of each segment", function()
			mapLines.DrawLine("wall", { { x = 1, y = 0, z = 1 }, { x = 2, y = 0, z = 2 }, { x = 3, y = 0, z = 3 } })
			assert.are.same({ { x = 1, y = 0, z = 1 }, { x = 2, y = 0, z = 2 } }, missionApi.lineNames.wall)
		end)

		it("erases the previous line when a name is drawn again", function()
			missionApi.lineNames.wall = { { x = 9, y = 0, z = 9 } }
			mapLines.DrawLine("wall", { { x = 1, y = 0, z = 1 }, { x = 2, y = 0, z = 2 } })
			assert.are.equal(1, #eraseCalls)
			assert.are.equal(9, eraseCalls[1].x)
			assert.are.same({ { x = 1, y = 0, z = 1 } }, missionApi.lineNames.wall)
		end)
	end)

	describe("RemoveLine", function()
		before_each(function()
			missionApi.lineNames.wall = { { x = 1, y = 0, z = 1 }, { x = 2, y = 0, z = 2 } }
			missionApi.lineNames.fence = { { x = 7, y = 0, z = 7 } }
		end)

		it("erases at the start of every segment of the named line", function()
			mapLines.RemoveLine("wall")
			assert.are.equal(2, #eraseCalls)
			assert.are.equal(1, eraseCalls[1].x)
			assert.are.equal(2, eraseCalls[2].x)
		end)

		it("forgets the line and leaves the others", function()
			mapLines.RemoveLine("wall")
			assert.is_nil(missionApi.lineNames.wall)
			assert.is_not_nil(missionApi.lineNames.fence)
		end)

		it("does nothing for an unknown line name", function()
			mapLines.RemoveLine("nothing")
			assert.are.equal(0, #eraseCalls)
		end)
	end)

	describe("RemoveAllLines", function()
		before_each(function()
			missionApi.lineNames.wall = { { x = 1, y = 0, z = 1 }, { x = 2, y = 0, z = 2 } }
			missionApi.lineNames.fence = { { x = 7, y = 0, z = 7 } }
		end)

		it("erases every line", function()
			mapLines.RemoveAllLines()
			local erased = {}
			for _, call in ipairs(eraseCalls) do
				erased[call.x] = true
			end
			assert.are.same({ [1] = true, [2] = true, [7] = true }, erased)
		end)

		it("forgets every line", function()
			mapLines.RemoveAllLines()
			assert.is_nil(next(missionApi.lineNames))
		end)

		it("does not touch markers", function()
			missionApi.markerNames.flag = { x = 9, y = 0, z = 9 }
			mapLines.RemoveAllLines()
			assert.is_not_nil(missionApi.markerNames.flag)
		end)
	end)
end)
