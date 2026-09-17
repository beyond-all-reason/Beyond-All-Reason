local Placement = VFS.Include("modules/start/lib/placement.lua") ---@type StartPlacement

describe("start placement", function()
	it("lays a count of positions around a circle, clamped to the map", function()
		local pts = Placement.Shape(100, 100, { shape = "circle", radius = 200, count = 4, rotation = 0 }, 1000, 1000)
		assert.are.equal(4, #pts)
		assert.are.same({ x = 300, z = 100 }, pts[1])
		assert.are.equal(0, pts[3].x, "the point past the west edge is clamped")
	end)

	it("takes a polygon's vertices first and then its edge midpoints", function()
		local pts = Placement.Shape(500, 500, { shape = "square", radius = 100, count = 6, rotation = 0 }, 1000, 1000)
		assert.are.equal(6, #pts)
		assert.are.same({ x = 600, z = 500 }, pts[1])
		assert.is_true(math.abs(pts[2].x - 550) < 1e-6 and math.abs(pts[2].z - 550) < 1e-6, "a midpoint")
	end)

	it("scatters random positions inside the circle", function()
		local seq = { 0.25, 0.5, 0.75, 1 - 1e-9 }
		local i = 0
		local pts = Placement.Random(500, 500, { shape = "circle", radius = 100, count = 2 }, 1000, 1000, function()
			i = i + 1
			return seq[i]
		end)
		assert.are.equal(2, #pts)
		for _, p in ipairs(pts) do
			assert.is_true((p.x - 500) ^ 2 + (p.z - 500) ^ 2 <= 100 * 100 + 1e-6)
		end
	end)

	it("deals slots round robin or sequentially", function()
		assert.are.same({ 1, 1 }, { Placement.SlotFor(1, 2, 2, "roundrobin") })
		assert.are.same({ 2, 1 }, { Placement.SlotFor(2, 2, 2, "roundrobin") })
		assert.are.same({ 1, 2 }, { Placement.SlotFor(3, 2, 2, "roundrobin") })
		assert.are.same({ 1, 2 }, { Placement.SlotFor(2, 2, 2, "sequential") })
		assert.are.same({ 2, 1 }, { Placement.SlotFor(3, 2, 2, "sequential") })
	end)

	it(
		"takes the commander's slope tolerance from the modoption, else the tightest commander movedef, else a default",
		function()
			local defs = {
				{ name = "armcom", customParams = { iscommander = 1 }, moveDef = { maxSlope = 0.4 } },
				{ name = "corcom", customParams = {}, moveDef = { maxSlope = 0.3 } },
				{ name = "armpw", customParams = {}, moveDef = { maxSlope = 0.1 } },
			}
			assert.are.equal(0.3, Placement.CommanderMaxSlope(defs, {}))
			assert.are.equal(0.9, Placement.CommanderMaxSlope(defs, { startpos_max_slope = "0.9" }))
			assert.are.equal(0.5, Placement.CommanderMaxSlope({}, nil))
		end
	)
end)
