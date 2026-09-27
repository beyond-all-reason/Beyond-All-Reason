-- The shared unit placer's layout (refactor plan, U1): pure, so every rule is checked here
-- rather than by dragging in game.
local Layout = VFS.Include("luaui/Include/unit_placer/layout.lua")

local function xs(spots)
	local out = {}
	for index, spot in ipairs(spots) do
		out[index] = spot.x
	end
	return out
end

describe("unit_placer.layout", function()
	describe("snapAxis", function()
		it("centres an odd number of build squares on a cell and an even one on a line", function()
			-- 2x2 squares = 16 elmos = one build square (odd): a cell centre, 8 off the grid.
			assert.are.equal(104, Layout.snapAxis(100, 16))
			-- 4x4 squares = 32 elmos = two build squares (even): on a grid line.
			assert.are.equal(96, Layout.snapAxis(100, 32))
		end)
	end)

	describe("footprint", function()
		it("swaps the axes for an east or west facing", function()
			assert.are.same({ 16, 32 }, { Layout.footprint(2, 4, 0) })
			assert.are.same({ 32, 16 }, { Layout.footprint(2, 4, 1) })
			assert.are.same({ 16, 32 }, { Layout.footprint(2, 4, 2) })
		end)
	end)

	describe("positions", function()
		local bot = { xsize = 2, zsize = 2 }

		local function spec(extra)
			local out = { xsize = bot.xsize, zsize = bot.zsize }
			for k, v in pairs(extra or {}) do
				out[k] = v
			end
			return out
		end

		it("places one unit, snapped, for SINGLE and for an unknown mode", function()
			local spots = Layout.positions(spec({ mode = "SINGLE" }), 100, 100)
			assert.are.same({ { x = 104, z = 104, facing = 0 } }, spots)
			assert.are.same(spots, Layout.positions(spec({ mode = "SPIRAL" }), 100, 100))
		end)

		it("counts a LINE the engine's way: a drag a little over two footprints gives three", function()
			local spots = Layout.positions(spec({ mode = "LINE" }), 8, 8, 48, 8)
			assert.are.same({ 8, 24, 40 }, xs(spots))
		end)

		it("keeps a SNAPLINE on the dominant axis while a LINE follows the slope", function()
			local line = Layout.positions(spec({ mode = "LINE", snap = false }), 0, 0, 64, 32)
			local snapline = Layout.positions(spec({ mode = "SNAPLINE", snap = false }), 0, 0, 64, 32)
			assert.are_not.equal(0, line[#line].z)
			for _, spot in ipairs(snapline) do
				assert.are.equal(0, spot.z)
			end
		end)

		it("fills a GRID row by row, alternating direction as a builder walks it", function()
			local spots = Layout.positions(spec({ mode = "GRID" }), 8, 8, 40, 24)
			assert.are.equal(6, #spots)
			assert.are.same({ 8, 24, 40, 40, 24, 8 }, xs(spots))
		end)

		it("puts a BOX on its edge only, every cell once", function()
			local spots = Layout.positions(spec({ mode = "BOX" }), 8, 8, 40, 40)
			assert.are.equal(8, #spots, "a 3x3 box is its 8 edge cells")
			local seen = {}
			for _, spot in ipairs(spots) do
				local key = spot.x .. ":" .. spot.z
				assert.is_nil(seen[key])
				seen[key] = true
			end
			assert.is_nil(seen["24:24"], "and not the middle")
		end)

		it("widens the step by the spacing, on both sides of the footprint", function()
			local spots = Layout.positions(spec({ mode = "SNAPLINE", spacing = 1, snap = false }), 0, 0, 100, 0)
			assert.are.equal(32, spots[2].x - spots[1].x)
		end)

		it("steps by the turned footprint for an east facing", function()
			local wide = { xsize = 2, zsize = 4, mode = "SNAPLINE", snap = false }
			local south = Layout.positions(wide, 0, 0, 200, 0)
			wide.facing = 1
			local east = Layout.positions(wide, 0, 0, 200, 0)
			assert.are.equal(16, south[2].x - south[1].x)
			assert.are.equal(32, east[2].x - east[1].x)
			assert.are.equal(1, east[1].facing)
		end)

		it("leaves positions where the drag put them when snapping is off", function()
			local spots = Layout.positions(spec({ snap = false }), 101, 99)
			assert.are.same({ x = 101, z = 99, facing = 0 }, spots[1])
		end)

		it("turns the layout about the drag start without losing the drag's reach", function()
			local turned = Layout.positions(
				{ xsize = 2, zsize = 4, mode = "LINE", angle = math.pi / 4, snap = false },
				0,
				0,
				100,
				100
			)
			assert.is_true(#turned >= 3)
			for _, spot in ipairs(turned) do
				assert.is_true(math.abs(spot.x - spot.z) <= 1, "every unit on the diagonal the drag drew")
			end
		end)

		it("keeps every unit on the map", function()
			local spots = Layout.positions(spec({ mode = "SNAPLINE", mapX = 64, mapZ = 64 }), 8, 8, 200, 8)
			for _, spot in ipairs(spots) do
				assert.is_true(spot.x <= 64)
			end
		end)
	end)

	describe("groups (a paste or a blueprint)", function()
		it("turns an offset the way a facing turns: south to east", function()
			assert.are.same({ 10, 0 }, { Layout.turnOffset(0, 10, 1) })
			assert.are.same({ 0, -10 }, { Layout.turnOffset(0, 10, 2) })
			assert.are.same({ 0, 10 }, { Layout.turnOffset(0, 10, 4) })
		end)

		it("measures offsets from the middle of the units' bounds", function()
			local offsets, cx, cz = Layout.centreOffsets({ { x = 100, z = 100 }, { x = 200, z = 140 } })
			assert.are.same({ 150, 120 }, { cx, cz })
			assert.are.same({ { dx = -50, dz = -20 }, { dx = 50, dz = 20 } }, offsets)
		end)

		it("drops every unit at its offset from the point, snapped for its own footprint", function()
			local units = {
				{ dx = -32, dz = 0, facing = 0, xsize = 2, zsize = 2 },
				{ dx = 32, dz = 0, facing = 0, xsize = 4, zsize = 4 },
			}
			local spots = Layout.groupPositions(units, 1000, 1000, 0, true)
			assert.are.same(
				{ x = 968, z = 1000, facing = 0, index = 1 },
				{ x = spots[1].x, z = spots[1].z, facing = spots[1].facing, index = spots[1].index }
			)
			assert.are.equal(Layout.snapAxis(1032, 32), spots[2].x)
		end)

		it("turns the whole group: offsets and facings together", function()
			local units = { { dx = 0, dz = 48, facing = 0, xsize = 2, zsize = 2 } }
			local spots = Layout.groupPositions(units, 1000, 1000, 1, false)
			assert.are.same({ 1048, 1000, 1 }, { spots[1].x, spots[1].z, spots[1].facing })
		end)
	end)

	it("cycles the modes and wraps", function()
		assert.are.equal("LINE", Layout.nextMode("SINGLE"))
		assert.are.equal("SINGLE", Layout.nextMode("BOX"))
		assert.are.equal("SINGLE", Layout.nextMode("nonsense"))
	end)

	it("turns a facing into the rotation a ghost is drawn with", function()
		assert.are.equal(0, Layout.facingRotation(0))
		assert.are.equal(math.pi / 2, Layout.facingRotation(1), "east, as the Blueprint API draws it")
	end)
end)
