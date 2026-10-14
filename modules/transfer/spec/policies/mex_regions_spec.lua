local Regions = require("modules/regions/api")

local square = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }

local made = 0

---@param fields table
---@return Region
local function mex(fields)
	made = made + 1
	fields.id = fields.id or ("r" .. made)
	return Regions.New(Regions.Enums.Types.MexRegion, fields)
end

describe("what transfer says a mex region is: named, covered, described", function()
	it("is called after its group when it carries no name, numbered once siblings share the group", function()
		local names = Regions.Names(Regions.Enums.Types.MexRegion, {
			mex({ team = 1, group = "anti" }),
			mex({ team = 1, group = "tech" }),
			mex({ team = 1, group = "tech" }),
			mex({ team = 2, group = "tech" }),
			mex({ team = 1, group = "tech", name = "given" }),
			mex({ team = 1 }),
		})
		local given = {}
		for i, named in ipairs(names) do
			given[i] = named.name
		end
		assert.are.same({ "anti", "tech_1", "tech_2", "tech_3", "given", "mex_region" }, given)
		assert.is_false(names[5].derived)
	end)

	it("says where the first uncovered metal spot is, so an editor can take the map maker there", function()
		local a = mex({ name = "a", team = 1, group = "g", vertices = square })
		local problems = Regions.CheckSet(Regions.Enums.Types.MexRegion, { a }, {
			spots = { { x = 50, z = 50 }, { x = 700, z = 300 }, { x = 900, z = 900 } },
		})
		assert.are.same({ { message = "2 metal spots in no mex region", at = { x = 700, z = 300 } } }, problems)
	end)

	it("may share ground with a sibling: coverage is its rule, not disjointness", function()
		local a = mex({ name = "a", team = 1, group = "g", vertices = square })
		local b = mex({
			name = "b",
			team = 1,
			group = "g",
			vertices = { { x = 50, z = 50 }, { x = 150, z = 50 }, { x = 150, z = 150 } },
		})
		assert.are.same({}, Regions.CheckSet(Regions.Enums.Types.MexRegion, { a, b }))
	end)
end)

---@return MexRegion
local function mexA()
	return Regions.New(Regions.Enums.Types.MexRegion, {
		id = "a",
		name = "a",
		team = 1,
		group = "g",
		vertices = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } },
	}) --[[@as MexRegion]]
end

describe("what mex splitting says about a region", function()
	it(
		"is the region's team and group, the metal spots inside and their worth when the map's spots are given",
		function()
			local d = Regions.Describe(mexA(), {
				spots = {
					{ x = 10, z = 10, worth = 2000 },
					{ x = 20, z = 20, worth = 1500 },
					{ x = 500, z = 500, worth = 9 },
				},
			})
			assert.are.equal(1, d.team)
			assert.are.equal("g", d.group)
			assert.are.equal(2, d.spots)
			assert.are.equal(3.5, d.worth)
		end
	)

	it("is bound to a start the map has, when the map says how many it has", function()
		local regions =
			{ mex({ team = 1, group = "g", vertices = square }), mex({ team = 4, group = "g", vertices = square }) }
		local problems = Regions.CheckSet(Regions.Enums.Types.MexRegion, regions, { starts = 4 })
		assert.are.equal(1, #problems)
		assert.are.equal(regions[2], problems[1].region)
		assert.are.equal("bound to start 4; the map's starts are 0 to 3", problems[1].message)
		assert.are.same({}, Regions.CheckSet(Regions.Enums.Types.MexRegion, regions, {}))
	end)

	it("knows no spots when the map's are not given", function()
		local d = Regions.Describe(mexA(), {})
		assert.is_nil(d.spots)
		assert.are.equal("g", d.group)
	end)
end)
