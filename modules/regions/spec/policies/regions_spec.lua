local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local Contract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract
local Enums = VFS.Include("modules/regions/enums.lua")

local square = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }
local far = { { x = 500, z = 500 }, { x = 600, z = 500 }, { x = 600, z = 600 } }

---@param fields table
---@return Region
local function start(fields)
	fields.type = Enums.Types.Start
	return fields
end

describe("the region types", function()
	it("come by key, each saying what it may be drawn as and who contributed it", function()
		local order, byKey = Regions.Types()
		assert.is_true(table.contains(order, "start"))
		assert.are.same({ "point", "polygon" }, byKey.start.geometries)
		assert.are.equal("start", byKey.start.module)
	end)
end)

describe("a region's name", function()
	it("is what the map gave it, or what its type's owner calls it, numbered once siblings share it", function()
		local names = Regions.Names(Enums.Types.Start, {
			start({ team = 1 }),
			start({ team = 2, name = "N" }),
			start({}),
			start({}),
		})
		assert.are.same({ name = "1", derived = true }, names[1], "a start is called after its team")
		assert.are.same({ name = "N", derived = false }, names[2])
		assert.are.same({ name = "start_1", derived = true }, names[3], "no team, so the type's label, numbered")
		assert.are.same({ name = "start_2", derived = true }, names[4])
	end)
end)

describe("checking a region", function()
	it("passes a whole polygon or a point with its required fields", function()
		assert.are.same({}, Regions.Check(Enums.Types.Start, start({ team = 1, vertices = square }), {}))
		assert.are.same({}, Regions.Check(Enums.Types.Start, start({ team = 1, vertices = { { x = 5, z = 5 } } }), {}))
	end)

	it("collects every problem rather than stopping at the first", function()
		local problems =
			Regions.Check(Enums.Types.Start, start({ vertices = { { x = 0, z = 0 }, { x = 1, z = 1 } } }), {})
		assert.are.same({ "two vertices make neither a point nor a polygon", "a start needs a team" }, problems)
		assert.are.same(
			{ "a region is a point or a polygon" },
			Regions.Check(Enums.Types.Start, start({ team = 1 }), {})
		)
	end)

	it("refuses a value a sibling already has where the type says it is unique", function()
		assert.are.same(
			{ "a start with team 1 already exists" },
			Regions.Check(
				Enums.Types.Start,
				start({ team = 1, vertices = square }),
				{ start({ team = 1, vertices = far }) }
			)
		)
		assert.are.same(
			{ "Team must be a number" },
			Regions.Check(Enums.Types.Start, start({ team = "north", vertices = square }), {})
		)
	end)

	it("checks only the fields when the region has no shape yet", function()
		assert.are.same({}, Regions.Check(Enums.Types.Start, start({ team = 1 }), {}, true))
		assert.are.same({ "a start needs a team" }, Regions.Check(Enums.Types.Start, start({}), {}, true))
	end)
end)

describe("a set of regions", function()
	it("is checked region by region, every problem naming its region", function()
		local problems = Regions.CheckSet(Enums.Types.Start, {
			start({ team = 1, vertices = square }),
			start({ team = 1, name = "twin", vertices = far }),
			start({ team = 2, vertices = { { x = 900, z = 900 } } }),
		})
		assert.are.same({
			{ index = 1, name = "1", message = "a start with team 1 already exists" },
			{ index = 2, name = "twin", message = "a start with team 1 already exists" },
		}, problems)
		assert.are.equal("1: a start with team 1 already exists", Regions.ProblemLine(problems[1]))
		assert.are.equal("about the set", Regions.ProblemLine({ message = "about the set" }))
	end)
end)

describe("a region's facts", function()
	it("come from the geometry alone when the asker knows nothing else", function()
		local facts = Regions.Facts(start({ team = 1, vertices = square }), {})
		assert.are.equal(10000, facts[Contract.Facts.Area])
		assert.are.same({ x = 50, z = 50 }, facts[Contract.Facts.Centre])
		assert.is_nil(facts[Contract.Facts.MetalSpots])
		assert.is_nil(facts[Contract.Facts.NearestStart])
	end)

	it("count the metal under the region and find the nearest start", function()
		local facts = Regions.Facts(start({ team = 1, vertices = square }), {
			spots = { { x = 10, z = 10, worth = 2 }, { x = 20, z = 20, worth = 1.5 }, { x = 500, z = 500, worth = 9 } },
			starts = { { allyTeam = 1, x = 1000, z = 1000 }, { allyTeam = 2, x = 60, z = 60 } },
		})
		assert.are.same({ count = 2, worth = 3.5 }, facts[Contract.Facts.MetalSpots])
		assert.are.equal(2, facts[Contract.Facts.NearestStart].allyTeam)
		local lines = Regions.FactLines(facts)
		assert.are.equal("Metal spots", lines[3][1])
	end)

	it("a point has no area and is its own centre", function()
		local facts = Regions.Facts(start({ team = 1, vertices = { { x = 7, z = 9 } } }), {})
		assert.are.equal(0, facts[Contract.Facts.Area])
		assert.are.same({ x = 7, z = 9 }, facts[Contract.Facts.Centre])
	end)
end)
