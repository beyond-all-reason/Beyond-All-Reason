local PolygonLib = dofile("common/lib_polygon.lua")

describe("lib_polygon", function()

	describe("PointInPolygon", function()
		local square = {
			{0, 0},
			{100, 0},
			{100, 100},
			{0, 100},
		}

		it("returns true for a point inside a square", function()
			assert.is_true(PolygonLib.PointInPolygon(50, 50, square))
		end)

		it("returns false for a point outside a square", function()
			assert.is_false(PolygonLib.PointInPolygon(150, 50, square))
			assert.is_false(PolygonLib.PointInPolygon(50, 150, square))
			assert.is_false(PolygonLib.PointInPolygon(-10, 50, square))
			assert.is_false(PolygonLib.PointInPolygon(50, -10, square))
		end)

		it("returns true for a point near the center of a large polygon", function()
			-- rotated diamond shape
			local diamond = {
				{50, 0},
				{100, 50},
				{50, 100},
				{0, 50},
			}
			assert.is_true(PolygonLib.PointInPolygon(50, 50, diamond))
		end)

		it("returns false for a point in the corner outside a diamond", function()
			local diamond = {
				{50, 0},
				{100, 50},
				{50, 100},
				{0, 50},
			}
			assert.is_false(PolygonLib.PointInPolygon(5, 5, diamond))
			assert.is_false(PolygonLib.PointInPolygon(95, 5, diamond))
		end)

		it("handles a concave L-shaped polygon", function()
			-- L-shape: top-left quadrant missing
			local lShape = {
				{0, 0},
				{50, 0},
				{50, 50},
				{100, 50},
				{100, 100},
				{0, 100},
			}
			-- inside the bottom part
			assert.is_true(PolygonLib.PointInPolygon(75, 75, lShape))
			-- inside the left part
			assert.is_true(PolygonLib.PointInPolygon(25, 25, lShape))
			-- outside in the concave "notch" area (top-right quadrant)
			assert.is_false(PolygonLib.PointInPolygon(75, 25, lShape))
		end)

		it("returns false for degenerate inputs", function()
			assert.is_false(PolygonLib.PointInPolygon(50, 50, {}))
			assert.is_false(PolygonLib.PointInPolygon(50, 50, {{0, 0}}))
			assert.is_false(PolygonLib.PointInPolygon(50, 50, {{0, 0}, {100, 0}}))
		end)

		it("works with large map-scale coordinates", function()
			local bigBox = {
				{0, 0},
				{16384, 0},
				{16384, 3276},
				{0, 3276},
			}
			assert.is_true(PolygonLib.PointInPolygon(8192, 1638, bigBox))
			assert.is_false(PolygonLib.PointInPolygon(8192, 5000, bigBox))
		end)
	end)

	describe("PointInStartbox", function()
		it("returns true when point is inside any sub-polygon", function()
			local entry = {
				boxes = {
					{{0, 0}, {100, 0}, {100, 100}, {0, 100}},
					{{200, 200}, {300, 200}, {300, 300}, {200, 300}},
				}
			}
			assert.is_true(PolygonLib.PointInStartbox(50, 50, entry))
			assert.is_true(PolygonLib.PointInStartbox(250, 250, entry))
		end)

		it("returns false when point is outside all sub-polygons", function()
			local entry = {
				boxes = {
					{{0, 0}, {100, 0}, {100, 100}, {0, 100}},
					{{200, 200}, {300, 200}, {300, 300}, {200, 300}},
				}
			}
			assert.is_false(PolygonLib.PointInStartbox(150, 150, entry))
		end)

		it("returns false for nil or missing entry", function()
			assert.is_false(PolygonLib.PointInStartbox(50, 50, nil))
			assert.is_false(PolygonLib.PointInStartbox(50, 50, {}))
		end)
	end)

	describe("GetStartboxBounds", function()
		it("returns bounding box of a single polygon", function()
			local entry = {
				boxes = {
					{{10, 20}, {90, 20}, {90, 80}, {10, 80}},
				}
			}
			local xmin, zmin, xmax, zmax = PolygonLib.GetStartboxBounds(entry)
			assert.are.equal(10, xmin)
			assert.are.equal(20, zmin)
			assert.are.equal(90, xmax)
			assert.are.equal(80, zmax)
		end)

		it("returns combined bounding box of multiple sub-polygons", function()
			local entry = {
				boxes = {
					{{0, 0}, {50, 0}, {50, 50}, {0, 50}},
					{{200, 300}, {400, 300}, {400, 500}, {200, 500}},
				}
			}
			local xmin, zmin, xmax, zmax = PolygonLib.GetStartboxBounds(entry)
			assert.are.equal(0, xmin)
			assert.are.equal(0, zmin)
			assert.are.equal(400, xmax)
			assert.are.equal(500, zmax)
		end)

		it("returns zeros for nil or missing entry", function()
			local xmin, zmin, xmax, zmax = PolygonLib.GetStartboxBounds(nil)
			assert.are.equal(0, xmin)
			assert.are.equal(0, zmin)
			assert.are.equal(0, xmax)
			assert.are.equal(0, zmax)
		end)
	end)
end)
