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

	describe("arrange (units S6)", function()
		local function centre(offsets)
			local sx, sz = 0, 0
			for _, o in ipairs(offsets) do
				sx, sz = sx + o.dx, sz + o.dz
			end
			return sx / #offsets, sz / #offsets
		end
		local function distinct(offsets)
			local seen = {}
			for _, o in ipairs(offsets) do
				local key = o.dx .. ":" .. o.dz
				if seen[key] then
					return false
				end
				seen[key] = true
			end
			return true
		end

		it("stands a LINE abreast across the facing, centred", function()
			local south = Layout.arrange(3, "LINE", 32, 0)
			assert.are.same({ -32, 0, 32 }, { south[1].dx, south[2].dx, south[3].dx })
			assert.are.equal(0, south[2].dz)
			local east = Layout.arrange(3, "LINE", 32, 1)
			assert.are.same({ -32, 0, 32 }, { east[1].dz, east[2].dz, east[3].dz })
		end)

		it("makes a GRID as square as the count allows, one spot each, centred", function()
			local six = Layout.arrange(6, "GRID", 32, 0)
			assert.are.equal(6, #six)
			assert.is_true(distinct(six))
			local cx, cz = centre(six)
			assert.is_true(math.abs(cx) < 1e-9 and math.abs(cz) < 16)
		end)

		it("spreads a BOX round a ring, and falls back to a GRID under four", function()
			local eight = Layout.arrange(8, "BOX", 32, 0)
			assert.are.equal(8, #eight)
			assert.is_true(distinct(eight))
			for _, o in ipairs(eight) do
				assert.is_true(math.abs(o.dx) == 32 or math.abs(o.dz) == 32, "on the ring")
			end
			assert.are.same(Layout.arrange(3, "GRID", 32, 0), Layout.arrange(3, "BOX", 32, 0))
		end)

		it("gives nothing for nothing", function()
			assert.are.same({}, Layout.arrange(0, "GRID", 32, 0))
		end)
	end)

	it("faces the nearer cardinal toward a point", function()
		assert.are.equal(1, Layout.facingToward(0, 0, 100, 10))
		assert.are.equal(3, Layout.facingToward(0, 0, -100, 10))
		assert.are.equal(0, Layout.facingToward(0, 0, 10, 100))
		assert.are.equal(2, Layout.facingToward(0, 0, 10, -100))
	end)

	describe("reform (a selection as a formation)", function()
		local function bots(facing)
			return {
				{ x = 1000, z = 1000, facing = facing or 0, xsize = 2, zsize = 2 },
				{ x = 1200, z = 1100, facing = 2, xsize = 2, zsize = 2 },
				{ x = 900, z = 1300, facing = 3, xsize = 2, zsize = 2 },
			}
		end

		it("stands a LINE abreast round the same centre, one cell apart", function()
			local spots = Layout.reform(bots(), "LINE")
			assert.are.equal(3, #spots)
			-- Cell: a 16 elmo footprint plus a build square = 32; the centre is (1050, 1150).
			local xsList, zsSeen = {}, {}
			for index = 1, 3 do
				xsList[#xsList + 1] = spots[index].x
				zsSeen[spots[index].z] = true
			end
			table.sort(xsList)
			assert.are.same({ 1016, 1048, 1080 }, xsList)
			assert.are.same({ [1144] = true }, zsSeen)
		end)

		it("turns every unit to the first one's facing", function()
			local spots = Layout.reform(bots(1), "GRID")
			for index = 1, 3 do
				assert.are.equal(1, spots[index].facing)
			end
		end)

		it("gives each slot the nearest unit, so the group does not cross itself", function()
			local units = {
				{ x = 0, z = 0, facing = 0, xsize = 2, zsize = 2 },
				{ x = 400, z = 0, facing = 0, xsize = 2, zsize = 2 },
			}
			local spots = Layout.reform(units, "LINE")
			assert.is_true(spots[1].x < spots[2].x, "the western unit stays west")
		end)

		it("makes a BOX of under four a GRID", function()
			assert.are.same(Layout.reform(bots(), "GRID"), Layout.reform(bots(), "BOX"))
		end)

		it("snaps each unit for its own footprint", function()
			local units = {
				{ x = 100, z = 100, facing = 0, xsize = 2, zsize = 2 },
				{ x = 300, z = 100, facing = 0, xsize = 4, zsize = 4 },
			}
			local spots = Layout.reform(units, "LINE")
			assert.are.equal(Layout.snapAxis(spots[2].x, 32), spots[2].x)
			assert.are.equal(8, spots[1].x % 16, "a one build square footprint sits on a cell centre")
			assert.are.equal(0, spots[2].x % 16, "a two build square footprint sits on a grid line")
		end)

		it("gives nothing for nothing", function()
			assert.are.same({}, Layout.reform({}, "GRID"))
		end)
	end)

	describe("space (tighter / looser)", function()
		local units = {
			{ x = 1000, z = 1000, facing = 0, xsize = 2, zsize = 2 },
			{ x = 1128, z = 1000, facing = 0, xsize = 2, zsize = 2 },
		}

		it("pushes units away from the centre for a factor over one", function()
			local spots = Layout.space(units, 4 / 3)
			assert.is_true(spots[2].x - spots[1].x > 128)
			assert.are.equal(spots[1].z, spots[2].z)
		end)

		it("pulls units toward the centre for a factor under one", function()
			local spots = Layout.space(units, 0.75)
			assert.is_true(spots[2].x - spots[1].x < 128)
		end)

		it("refuses to tighten past the largest footprint", function()
			local close = {
				{ x = 1000, z = 1000, facing = 0, xsize = 4, zsize = 4 },
				{ x = 1032, z = 1000, facing = 0, xsize = 4, zsize = 4 },
			}
			assert.is_nil(Layout.space(close, 0.75))
		end)

		it("moves a tight squad of small units at least one step", function()
			-- Offsets of one or two build squares: a plain x4/3 snapped back onto the same spots.
			local trio = {
				{ x = 3136, z = 3104, facing = 0, xsize = 2, zsize = 2 },
				{ x = 3120, z = 3056, facing = 0, xsize = 2, zsize = 2 },
				{ x = 3168, z = 3056, facing = 0, xsize = 2, zsize = 2 },
			}
			local spots = Layout.space(trio, 4 / 3)
			local moved = 0
			for index, spot in ipairs(spots) do
				if spot.x ~= trio[index].x or spot.z ~= trio[index].z then
					moved = moved + 1
				end
			end
			assert.are.equal(3, moved)
		end)

		it("snaps every spot to the build grid", function()
			local spots = Layout.space(units, 4 / 3)
			for _, spot in ipairs(spots) do
				assert.are.equal(8, spot.x % 16)
				assert.are.equal(8, spot.z % 16)
			end
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
