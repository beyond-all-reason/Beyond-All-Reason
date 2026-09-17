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
		local problems =
			Regions.CheckSet(Enums.Types.Start, { area(1, 0, 0, 100), area(2, 50, 50, 100), area(3, 500, 500, 100) })
		assert.are.same({
			{ index = 1, name = "1", message = "overlaps start 2" },
			{ index = 2, name = "2", message = "overlaps start 1" },
		}, problems)
		assert.are.equal("1: overlaps start 2", Regions.ProblemLine(problems[1]))
	end)

	it("may touch along an edge, and a start that is a point overlaps nothing", function()
		local point = { type = Enums.Types.Start, team = 3, vertices = { { x = 50, z = 50 } } }
		assert.are.same({}, Regions.CheckSet(Enums.Types.Start, { area(1, 0, 0, 100), area(2, 100, 0, 100), point }))
	end)
end)
