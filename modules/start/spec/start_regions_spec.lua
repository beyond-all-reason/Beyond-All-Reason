local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local Enums = VFS.Include("modules/regions/enums.lua")

---@param team integer
---@param x number
---@param z number
---@param size number
---@return Region
local function area(team, x, z, size)
	return {
		type = Enums.Types.Start,
		team = team,
		vertices = {
			{ x = x, z = z },
			{ x = x + size, z = z },
			{ x = x + size, z = z + size },
			{ x = x, z = z + size },
		},
	}
end

describe("a map's starts, as a set", function()
	it("never have two areas sharing ground, and each problem is the region's own", function()
		local regions = { area(1, 0, 0, 100), area(2, 50, 50, 100), area(3, 500, 500, 100) }
		local problems = Regions.CheckSet(Enums.Types.Start, regions)
		assert.are.same({
			{ region = regions[1], name = "1", message = "overlaps start 2" },
			{ region = regions[2], name = "2", message = "overlaps start 1" },
		}, problems)
		assert.are.equal("1: overlaps start 2", Regions.ProblemLine(problems[1]))
	end)

	it("may touch along an edge, and a start that is a point overlaps nothing", function()
		local point = { type = Enums.Types.Start, team = 3, vertices = { { x = 50, z = 50 } } }
		assert.are.same({}, Regions.CheckSet(Enums.Types.Start, { area(1, 0, 0, 100), area(2, 100, 0, 100), point }))
	end)
end)

describe("what start says about a region", function()
	it("names the start inside the region, or else the nearest to its centre, when env.starts is given", function()
		local region = area(1, 0, 0, 100)
		assert.are.same(
			{ "Start", "ally team 2 starts inside" },
			Regions.Describe(region, {
				starts = { { allyTeam = 1, x = 1000, z = 1000 }, { allyTeam = 2, x = 60, z = 60 } },
			})[3]
		)
		assert.are.same(
			{ "Nearest start", "ally team 2, 250 elmos from the centre" },
			Regions.Describe(region, {
				starts = { { allyTeam = 1, x = 1000, z = 1000 }, { allyTeam = 2, x = 50, z = 300 } },
			})[3]
		)
	end)

	it("adds nothing when env.starts is nil", function()
		assert.are.equal(2, #Regions.Describe(area(1, 0, 0, 100), {}))
	end)
end)
