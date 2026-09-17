local Layout = VFS.Include("modules/regions/lib/layout.lua") ---@type RegionLayout
local Types = VFS.Include("modules/regions/types.lua")

local byKey = Types.byKey

describe("a region layout", function()
	it("scales the startbox space onto the map and expands two corners into a rect", function()
		local regions = assert(Layout.Parse({
			regions = { start = { { team = 1, poly = { { x = 0, y = 0 }, { x = 100, y = 200 } } } } },
		}, byKey.start, 4000, 2000))
		assert.are.equal(1, #regions)
		local region = regions[1]
		assert.are.equal("start", region.type)
		assert.are.equal(1, region.team)
		assert.is_nil(region.name)
		assert.are.same(
			{ { x = 0, z = 0 }, { x = 2000, z = 0 }, { x = 2000, z = 2000 }, { x = 0, z = 2000 } },
			region.vertices
		)
	end)

	it("keeps a polygon's vertices, coerces fields to their kind, and reads a point", function()
		local regions = assert(Layout.Parse({
			regions = {
				start = {
					{ name = 7, team = "2", poly = { { x = 0, y = 0 }, { x = 200, y = 0 }, { x = 100, y = 200 } } },
				},
			},
		}, byKey.start, 200, 200))
		assert.are.same({ { x = 0, z = 0 }, { x = 200, z = 0 }, { x = 100, z = 200 } }, regions[1].vertices)
		assert.are.equal(2, regions[1].team)
		assert.are.equal("7", regions[1].name)
		local starts =
			assert(Layout.Parse({ regions = { start = { { team = 1, x = 50, y = 100 } } } }, byKey.start, 400, 400))
		assert.are.same({ { x = 100, z = 200 } }, starts[1].vertices, "a point is a ring of one")
	end)

	it("refuses what it cannot read, naming the entry", function()
		local _, reason = Layout.Parse(
			{ regions = { start = { { name = "a", team = 1, poly = { { x = 1, y = 1 } } } } } },
			byKey.start,
			200,
			200
		)
		assert.matches("a needs a poly", reason)
		_, reason = Layout.Parse({ regions = { start = { { team = 1 } } } }, byKey.start, 200, 200)
		assert.matches("start 1 has no shape", reason)
		_, reason = Layout.Parse({ regions = { other = {} } }, byKey.start, 200, 200)
		assert.matches("lists no start", reason)
		---@diagnostic disable-next-line: param-type-mismatch
		_, reason = Layout.Parse("nonsense", byKey.start, 200, 200)
		assert.matches("a layout is", reason)
	end)

	it("exports every type under its key with the fields its type declares, and reads them back", function()
		local layout = Layout.Export({
			{
				type = "start",
				team = 2,
				name = "",
				stray = "dropped",
				tags = { "x" },
				vertices = { { x = 0, z = 0 }, { x = 200, z = 0 }, { x = 0, z = 200 } },
			},
			{ type = "start", team = 1, vertices = { { x = 100, z = 50 } } },
			{ type = "nobody_knows", vertices = {} },
		}, byKey, 200, 200)
		assert.are.same(
			{ team = 2, tags = { "x" }, poly = { { x = 0, y = 0 }, { x = 200, y = 0 }, { x = 0, y = 200 } } },
			layout.regions.start[1]
		)
		assert.are.same({ team = 1, x = 100, y = 50 }, layout.regions.start[2])
		assert.is_nil(layout.regions.nobody_knows)
		local back = assert(Layout.Parse(layout, byKey.start, 200, 200))
		assert.are.equal(2, back[1].team)
		assert.are.same({ "x" }, back[1].tags)
	end)

	it("carries a region's id out and back, and assigns none of its own", function()
		local layout = Layout.Export({
			{ type = "start", id = "abc", team = 1, vertices = { { x = 100, z = 50 } } },
			{ type = "start", team = 2, vertices = { { x = 10, z = 50 } } },
		}, byKey, 200, 200)
		assert.are.equal("abc", layout.regions.start[1].id)
		assert.is_nil(layout.regions.start[2].id)
		local back = assert(Layout.Parse(layout, byKey.start, 200, 200))
		assert.are.equal("abc", back[1].id)
		assert.is_nil(back[2].id)
	end)
end)
