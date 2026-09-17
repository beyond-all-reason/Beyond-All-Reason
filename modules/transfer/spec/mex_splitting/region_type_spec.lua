local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local Enums = VFS.Include("modules/regions/enums.lua")

local square = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }

---@param fields table
---@return Region
local function mex(fields)
	fields.type = Enums.Types.MexRegion
	return fields
end

describe("the mex region type", function()
	it("is transfer's, drawn as a polygon only", function()
		local order, byKey = Regions.Types()
		assert.are.same({ "mex_region", "start" }, order)
		assert.are.same({ "polygon" }, byKey.mex_region.geometries)
		assert.are.equal("transfer", byKey.mex_region.module)
		assert.are.same(
			{ "a mex region cannot be a point" },
			Regions.Check(Enums.Types.MexRegion, mex({ team = 1, group = "g", vertices = { { x = 1, z = 1 } } }), {})
		)
	end)

	it("needs its team and group before its first vertex; a name is optional", function()
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, mex({ team = 1, group = "g" }), {}, true))
		assert.are.same(
			{ "a mex region needs a team", "a mex region needs a group" },
			Regions.Check(Enums.Types.MexRegion, mex({}), {}, true)
		)
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, mex({ team = 1, group = "g", vertices = square }), {}))
	end)

	it("is called after its group when it carries no name, numbered once siblings in the team share one", function()
		local names = Regions.Names(Enums.Types.MexRegion, {
			mex({ team = 1, group = "anti" }),
			mex({ team = 1, group = "tech" }),
			mex({ team = 1, group = "tech" }),
			mex({ team = 2, group = "tech" }),
			mex({ team = 1, group = "tech", name = "given" }),
			mex({ team = 1 }),
		})
		assert.are.same({ "anti", "tech_1", "tech_2", "tech", "given", "mex_region" }, {
			names[1].name,
			names[2].name,
			names[3].name,
			names[4].name,
			names[5].name,
			names[6].name,
		})
		assert.is_false(names[5].derived)
	end)

	it("judges a derived name like a given one: unique within its team", function()
		local souths = { mex({ name = "anti", team = 2, group = "x" }) }
		assert.are.same({}, Regions.Check(Enums.Types.MexRegion, mex({ team = 1, group = "anti" }), souths, true))
		assert.are.same(
			{ "a mex region with name anti already exists" },
			Regions.Check(Enums.Types.MexRegion, mex({ team = 2, group = "anti" }), souths, true)
		)
	end)

	it("may share ground with a sibling: coverage is its rule, not disjointness", function()
		local a = mex({ name = "a", team = 1, group = "g", vertices = square })
		local b = mex({
			name = "b",
			team = 1,
			group = "g",
			vertices = { { x = 50, z = 50 }, { x = 150, z = 50 }, { x = 150, z = 150 } },
		})
		assert.are.same({}, Regions.CheckSet(Enums.Types.MexRegion, { a, b }))
	end)
end)
