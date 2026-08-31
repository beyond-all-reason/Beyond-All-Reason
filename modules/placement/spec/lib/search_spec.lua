
local Search = VFS.Include("modules/placement/lib/search.lua")

describe("placement search order", function()
	it("starts at the point the caller actually asked for", function()
		local ring = Search.Ring(0, 64)
		assert.are.same({ { dx = 0, dz = 0 } }, ring)
	end)

	it("a ring is a shell, so no point is offered twice", function()
		local seen = {}
		for r = 0, 3 do
			for _, o in ipairs(Search.Ring(r, 64)) do
				local key = o.dx .. "," .. o.dz
				assert.is_nil(seen[key], "offered twice: " .. key)
				seen[key] = true
			end
		end
		local count = 0
		for _ in pairs(seen) do
			count = count + 1
		end
		assert.are.equal(49, count)
	end)

	it("offers nearer candidates before further ones inside a ring", function()
		local ring = Search.Ring(2, 100)
		local previous = -1
		for _, o in ipairs(ring) do
			local d = o.dx * o.dx + o.dz * o.dz
			assert.is_true(d >= previous, "ring is not sorted nearest-first")
			previous = d
		end
		assert.are.equal(200 * 200, ring[1].dx * ring[1].dx + ring[1].dz * ring[1].dz)
	end)

	it("is deterministic: the same request gives byte-identical order", function()
		local a = Search.Ring(3, 64)
		local b = Search.Ring(3, 64)
		assert.are.same(a, b)
	end)

	it("uses integer-exact offsets, so there is no float to disagree about", function()
		for _, o in ipairs(Search.Ring(3, 64)) do
			assert.are.equal(0, o.dx % 1)
			assert.are.equal(0, o.dz % 1)
		end
	end)

	it("takes the requested point when it is acceptable, and looks no further", function()
		local tries = 0
		local x, z, tried = Search.Outward(1000, 2000, { radius = 500, step = 64 }, function()
			tries = tries + 1
			return true
		end)
		assert.are.equal(1000, x)
		assert.are.equal(2000, z)
		assert.are.equal(1, tries)
		assert.are.equal(1, tried)
	end)

	it("returns the NEAREST acceptable spot, not merely an acceptable one", function()
		local wanted = { x = 1000 + 128, z = 2000 }
		local x, z = Search.Outward(1000, 2000, { radius = 400, step = 64 }, function(cx, cz)
			return cx == wanted.x and cz == wanted.z
		end)
		assert.are.equal(wanted.x, x)
		assert.are.equal(wanted.z, z)
	end)

	it("never offers a candidate beyond the radius it was given", function()
		local worst = 0
		Search.Outward(0, 0, { radius = 300, step = 64 }, function(cx, cz)
			worst = math.max(worst, cx * cx + cz * cz)
			return false
		end)
		assert.is_true(worst <= 300 * 300, "offered a spot outside the requested radius: " .. math.sqrt(worst))
	end)

	it("gives up rather than stalling when nothing is acceptable", function()
		local x, z, tried = Search.Outward(0, 0, { radius = 100000, step = 8, limit = 250 }, function()
			return false
		end)
		assert.is_nil(x)
		assert.is_nil(z)
		assert.are.equal(250, tried, "the work ceiling is what stops a whole-map search costing a frame")
	end)

	it("reports how hard it looked, so a caller can say so", function()
		local _, _, tried = Search.Outward(0, 0, { radius = 128, step = 64 }, function()
			return false
		end)
		assert.is_true(tried > 1)
	end)

	it("Rings covers the radius asked for and no more", function()
		assert.are.equal(0, Search.Rings(0, 64))
		assert.are.equal(1, Search.Rings(64, 64))
		assert.are.equal(2, Search.Rings(65, 64))
	end)
end)
