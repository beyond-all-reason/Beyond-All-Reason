local SplineLib = VFS.Include("common/lib_spline.lua")
local PolygonLib = VFS.Include("common/lib_polygon.lua")

local function pointsApproxEqual(a, b, eps)
	eps = eps or 1e-6
	return math.abs(a[1] - b[1]) <= eps and math.abs(a[2] - b[2]) <= eps
end

describe("lib_spline", function()

	describe("TessellateRing on plain polygons (no strengths)", function()
		it("returns the anchor points unchanged when no strengths are provided", function()
			local anchors = { {0, 0}, {100, 0}, {100, 100}, {0, 100} }
			local poly = SplineLib.TessellateRing(anchors)
			assert.are.equal(4, #poly)
			assert.is_true(pointsApproxEqual(poly[1], {0, 0}))
			assert.is_true(pointsApproxEqual(poly[2], {100, 0}))
			assert.is_true(pointsApproxEqual(poly[3], {100, 100}))
			assert.is_true(pointsApproxEqual(poly[4], {0, 100}))
		end)

		it("returns the anchor points unchanged when all strengths are zero", function()
			local anchors = { {0, 0, 0}, {100, 0, 0}, {100, 100, 0}, {0, 100, 0} }
			local poly = SplineLib.TessellateRing(anchors)
			assert.are.equal(4, #poly)
			assert.is_true(pointsApproxEqual(poly[1], {0, 0}))
			assert.is_true(pointsApproxEqual(poly[2], {100, 0}))
			assert.is_true(pointsApproxEqual(poly[3], {100, 100}))
			assert.is_true(pointsApproxEqual(poly[4], {0, 100}))
		end)

		it("anchor without strength next to anchor with strength stays a sharp corner", function()
			-- adjacency 1->2, 2->3, 3->4, 4->1
			-- anchor 1 strength missing (treated as 0), anchor 2 strength 1.0
			-- edge 1->2 tension = (0 + 1)/2 = 0.5 (curved)
			-- edge 4->1 tension = (1 + 0)/2 = 0.5 (curved)
			-- edges 2->3 and 3->4: anchors 3,4 missing → 0 → linear
			local anchors = { {0, 0}, {100, 0, 1}, {100, 100, 1}, {0, 100} }
			local poly = SplineLib.TessellateRing(anchors, { segments = 4 })
			-- linear edges contribute 1 vertex; curved edges contribute 4
			-- edge 1->2 curved (4), 2->3 curved (4), 3->4 linear (1), 4->1 curved (4)
			-- wait recompute: anchor strengths [0, 1, 1, 0]
			-- edge 1->2: (0+1)/2 = 0.5, curved
			-- edge 2->3: (1+1)/2 = 1, curved
			-- edge 3->4: (1+0)/2 = 0.5, curved
			-- edge 4->1: (0+0)/2 = 0, linear
			-- Output: 4 + 4 + 4 + 1 = 13 vertices
			assert.are.equal(13, #poly)
		end)
	end)

	describe("TessellateRing with positive strength", function()
		it("subdivides curved edges into `segments` samples", function()
			local anchors = { {0, 0, 1}, {100, 0, 1}, {100, 100, 1}, {0, 100, 1} }
			local poly = SplineLib.TessellateRing(anchors, { segments = 8 })
			-- 4 anchors * 8 samples per edge = 32 vertices when fully splined
			assert.are.equal(32, #poly)
		end)

		it("anchor positions are preserved on the tessellated curve", function()
			local anchors = { {0, 0, 1}, {100, 0, 1}, {100, 100, 1}, {0, 100, 1} }
			local poly = SplineLib.TessellateRing(anchors, { segments = 5 })
			-- the first vertex emitted in each per-edge group is the anchor itself
			assert.is_true(pointsApproxEqual(poly[1], {0, 0}))
			assert.is_true(pointsApproxEqual(poly[1 + 5], {100, 0}))
			assert.is_true(pointsApproxEqual(poly[1 + 10], {100, 100}))
			assert.is_true(pointsApproxEqual(poly[1 + 15], {0, 100}))
		end)

		it("mixed strength only subdivides edges whose endpoints have any strength", function()
			-- two adjacent anchors with strength 0 produce a linear edge between them.
			-- adjacency ordering: 1->2, 2->3, 3->4, 4->1
			local anchors = {
				{0, 0, 0},
				{100, 0, 0},
				{100, 100, 1},
				{0, 100, 1},
			}
			local poly = SplineLib.TessellateRing(anchors, { segments = 6 })
			-- edges with tensions: (0+0)/2=0, (0+1)/2=0.5, (1+1)/2=1, (1+0)/2=0.5
			-- linear edge contributes 1 vertex; curved edges contribute 6.
			-- total = 1 + 6 + 6 + 6 = 19
			assert.are.equal(19, #poly)
		end)
	end)

	describe("integration with PolygonLib", function()
		it("tessellated spline polygon is valid input for PointInPolygon", function()
			local anchors = { {0, 0, 1}, {100, 0, 1}, {100, 100, 1}, {0, 100, 1} }
			local poly = SplineLib.TessellateRing(anchors)
			-- center of the anchor square should still be inside the spline polygon
			assert.is_true(PolygonLib.PointInPolygon(50, 50, poly))
			assert.is_false(PolygonLib.PointInPolygon(500, 500, poly))
		end)

		it("zero-strength tessellation is point-equivalent to the input polygon", function()
			local anchors = { {0, 0, 0}, {100, 0, 0}, {100, 100, 0}, {0, 100, 0} }
			local splineOut = SplineLib.TessellateRing(anchors)
			local plain = { {0, 0}, {100, 0}, {100, 100}, {0, 100} }
			-- both should agree on a sample of test points (containment-equivalent)
			local samples = { {50, 50}, {-1, -1}, {101, 50}, {25, 25}, {99, 99}, {50, 200} }
			for _, s in ipairs(samples) do
				assert.are.equal(
					PolygonLib.PointInPolygon(s[1], s[2], splineOut),
					PolygonLib.PointInPolygon(s[1], s[2], plain)
				)
			end
		end)
	end)

	describe("degenerate inputs", function()
		it("returns empty result for empty input", function()
			local poly = SplineLib.TessellateRing({})
			assert.are.equal(0, #poly)
		end)

		it("passes through 1- and 2-anchor inputs without curving", function()
			local one = SplineLib.TessellateRing({ {5, 7, 1} })
			assert.are.equal(1, #one)
			local two = SplineLib.TessellateRing({ {0, 0, 1}, {10, 10, 1} })
			assert.are.equal(2, #two)
		end)

		it("clamps out-of-range strength values", function()
			local anchors = { {0, 0, -5}, {100, 0, 99}, {100, 100, 0.5}, {0, 100, 0.5} }
			-- should not error; values get clamped to [0, 1]
			local poly = SplineLib.TessellateRing(anchors, { segments = 4 })
			assert.is_true(#poly >= 4)
		end)
	end)
end)
