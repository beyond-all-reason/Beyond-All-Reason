-- common/vertex_height.lua against a stand-in for the engine's ground lookup: the same clamp to
-- mapSize - 1 and the same two-triangle interpolation as rts/Map/Ground.cpp.
local SQ, MX, MZ = 8, 4, 3 -- squares: a 4x3-square map, 5x4 vertices

local function engineLookup(grid)
	local maxX, maxZ = MX * SQ - 1, MZ * SQ - 1
	return function(x, z)
		x = math.max(0, math.min(x, maxX)) / SQ
		z = math.max(0, math.min(z, maxZ)) / SQ
		local ix, iz = math.floor(x), math.floor(z)
		local dx, dz = x - ix, z - iz
		local h00 = grid[iz][ix]
		local h10 = grid[iz][ix + 1]
		local h01 = grid[iz + 1][ix]
		if dx + dz < 1 then
			return h00 + dx * (h10 - h00) + dz * (h01 - h00)
		end
		local h11 = grid[iz + 1][ix + 1]
		return h11 + (1 - dx) * (h01 - h11) + (1 - dz) * (h10 - h11)
	end
end

describe("vertex_height", function()
	local grid, vertexHeight, lookup
	before_each(function()
		_G.Game = { squareSize = SQ, mapSizeX = MX * SQ, mapSizeZ = MZ * SQ }
		math.randomseed(7)
		grid = {}
		for iz = 0, MZ do
			grid[iz] = {}
			for ix = 0, MX do
				grid[iz][ix] = math.random() * 400 - 100
			end
		end
		lookup = engineLookup(grid)
		vertexHeight = dofile("common/vertex_height.lua")(lookup)
	end)
	after_each(function()
		_G.Game = nil
	end)

	it("plain lookups miss the far edge (the bug this fixes)", function()
		assert.is_true(math.abs(lookup(MX * SQ, 0) - grid[0][MX]) > 1e-3)
	end)

	it("returns every vertex exactly, far column, far row and corner included", function()
		for iz = 0, MZ do
			for ix = 0, MX do
				local h = vertexHeight(ix * SQ, iz * SQ)
				assert.is_true(
					math.abs(h - grid[iz][ix]) < 1e-6,
					string.format("vertex %d,%d: %f vs %f", ix, iz, h, grid[iz][ix])
				)
			end
		end
	end)
end)
