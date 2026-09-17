local Hull = VFS.Include("modules/transfer/mex_splitting/hull.lua") ---@type MexRegionsHull
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry

describe("the ring around picked metal spots", function()
	it("is nothing for no spots, and a square around one or two", function()
		assert.is_nil(Hull.Around({}, 50))
		local ring = Hull.Around({ { x = 100, z = 100 } }, 50)
		assert.are.equal(4, #ring)
		assert.is_true(Geometry.Contains(100, 100, ring))
		local two = Hull.Around({ { x = 100, z = 100 }, { x = 300, z = 100 } }, 50)
		assert.is_true(Geometry.Contains(100, 100, two) and Geometry.Contains(300, 100, two))
	end)

	it("is the padded hull of three or more, containing every spot, with straight corners pruned", function()
		local spots = {
			{ x = 0, z = 0 },
			{ x = 200, z = 0 },
			{ x = 100, z = 0 },
			{ x = 200, z = 200 },
			{ x = 0, z = 200 },
			{ x = 100, z = 100 },
		}
		local ring = Hull.Around(spots, 30)
		assert.are.equal(4, #ring, "the midpoint of an edge and the interior spot are not corners")
		for _, s in ipairs(spots) do
			assert.is_true(Geometry.Contains(s.x, s.z, ring))
		end
	end)
end)
