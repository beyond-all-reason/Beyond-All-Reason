local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry

describe("region geometry", function()
	local square = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }

	it("measures a polygon and finds its middle", function()
		assert.are.equal(10000, Geometry.Area(square))
		local x, z = Geometry.Centroid(square)
		assert.are.equal(50, x)
		assert.are.equal(50, z)
		assert.are.equal(0, Geometry.Area({ { x = 0, z = 0 }, { x = 1, z = 1 } }))
	end)

	it("knows when two polygons share ground", function()
		local shifted = { { x = 50, z = 50 }, { x = 150, z = 50 }, { x = 150, z = 150 }, { x = 50, z = 150 } }
		local apart = { { x = 200, z = 200 }, { x = 300, z = 200 }, { x = 300, z = 300 }, { x = 200, z = 300 } }
		local crossing = { { x = 40, z = -20 }, { x = 60, z = -20 }, { x = 60, z = 120 }, { x = 40, z = 120 } }
		assert.is_true(Geometry.Overlaps(square, shifted))
		assert.is_false(Geometry.Overlaps(square, apart))
		assert.is_true(Geometry.Overlaps(square, crossing), "no vertex inside, but the edges cross")
	end)

	it("lets neighbours touch: a shared edge or corner is not shared ground", function()
		local east = { { x = 100, z = 0 }, { x = 200, z = 0 }, { x = 200, z = 100 }, { x = 100, z = 100 } }
		local corner = { { x = 100, z = 100 }, { x = 200, z = 100 }, { x = 200, z = 200 }, { x = 100, z = 200 } }
		local alongside = { { x = 100, z = 25 }, { x = 200, z = 25 }, { x = 200, z = 75 }, { x = 100, z = 75 } }
		assert.is_false(Geometry.Overlaps(square, east))
		assert.is_false(Geometry.Overlaps(east, square))
		assert.is_false(Geometry.Overlaps(square, corner))
		assert.is_false(Geometry.Overlaps(square, alongside), "a shorter edge along a longer one")
		assert.is_true(Geometry.Overlaps(square, square), "the same ring twice")
		local within = { { x = 0, z = 0 }, { x = 50, z = 0 }, { x = 50, z = 50 }, { x = 0, z = 50 } }
		assert.is_true(Geometry.Overlaps(square, within), "sharing a corner and two edges, but inside")
		assert.is_true(Geometry.OnBoundary(100, 50, square))
		assert.is_false(Geometry.OnBoundary(99, 50, square))
	end)

	it("tells a point from a polygon by the ring alone", function()
		assert.are.equal("point", Geometry.Of({ { x = 1, z = 1 } }))
		assert.are.equal("polygon", Geometry.Of(square))
		assert.is_nil(Geometry.Of({ { x = 0, z = 0 }, { x = 1, z = 1 } }))
		assert.is_nil(Geometry.Of({}))
		local x, z = Geometry.Centroid({ { x = 7, z = 9 } })
		assert.are.same({ 7, 9 }, { x, z })
	end)

	it("knows what is inside, concave corners included", function()
		assert.is_true(Geometry.Contains(50, 50, square))
		assert.is_false(Geometry.Contains(150, 50, square))
		local ell = {
			{ x = 0, z = 0 },
			{ x = 100, z = 0 },
			{ x = 100, z = 50 },
			{ x = 50, z = 50 },
			{ x = 50, z = 100 },
			{ x = 0, z = 100 },
		}
		assert.is_true(Geometry.Contains(25, 75, ell))
		assert.is_false(Geometry.Contains(75, 75, ell))
	end)
end)
