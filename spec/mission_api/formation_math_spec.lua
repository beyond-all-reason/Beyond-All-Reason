local Formation = VFS.Include("luarules/mission_api/formation_math.lua")

local function near(expected, actual)
	return math.abs(expected - actual) < 1e-6
end

local function totalCost(starts, targets)
	local total = 0.0
	for i = 1, #starts do
		local dx, dz = starts[i].x - targets[i].x, starts[i].z - targets[i].z
		total = total + dx * dx + dz * dz
	end
	return total
end

-- The cheapest assignment, by trying every permutation.
local function cheapestCost(starts, spots)
	local best, used, chosen = math.huge, {}, {}
	local function walk(i)
		if i > #starts then
			best = math.min(best, totalCost(starts, chosen))
			return
		end
		for j = 1, #spots do
			if not used[j] then
				used[j], chosen[i] = true, spots[j]
				walk(i + 1)
				used[j] = false
			end
		end
	end
	walk(1)
	return best
end

describe("mission_api.formation_math", function()
	describe("AroundPoint", function()
		it("keeps the shape around the destination without a turn", function()
			local starts = { { x = 0, z = 0 }, { x = 40, z = 0 }, { x = 20, z = 30 } }
			local targets = Formation.AroundPoint(starts, { x = 1000, z = 500 }, 0)
			local center = Formation.Center(targets)
			assert.is_true(near(1000, center.x) and near(500, center.z))
			for i = 2, 3 do
				assert.is_true(near(starts[i].x - starts[1].x, targets[i].x - targets[1].x))
				assert.is_true(near(starts[i].z - starts[1].z, targets[i].z - targets[1].z))
			end
		end)

	end)

	describe("AlongLine", function()
		it("spaces the units evenly along a bent line, both ends included", function()
			local starts = {}
			for i = 1, 5 do
				starts[i] = { x = 0, z = -100 * i }
			end
			local line = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 } }
			local spots = {}
			for _, target in ipairs(Formation.AlongLine(starts, line)) do
				spots[target.x .. "," .. target.z] = true
			end
			for _, expected in ipairs({ "0,0", "50,0", "100,0", "100,50", "100,100" }) do
				assert.is_true(spots[expected], expected)
			end
		end)

		it("puts a single unit in the middle of the line", function()
			local targets = Formation.AlongLine({ { x = 0, z = 0 } }, { { x = 0, z = 0 }, { x = 200, z = 0 } })
			assert.is_true(near(100, targets[1].x) and near(0, targets[1].z))
		end)

		it("matches the units to the line at the lowest total cost", function()
			local starts = {
				{ x = 300, z = 40 },
				{ x = 20, z = -60 },
				{ x = 170, z = 10 },
				{ x = 90, z = 120 },
				{ x = 240, z = -30 },
			}
			local line = { { x = 0, z = 500 }, { x = 400, z = 500 } }
			local targets = Formation.AlongLine(starts, line)
			local spots = {}
			for i = 0, 4 do
				spots[#spots + 1] = { x = i * 100, z = 500 }
			end
			assert.is_true(near(cheapestCost(starts, spots), totalCost(starts, targets)))
		end)

		it("gives every spot to one unit in a group too large for the exact matching", function()
			local starts = {}
			for i = 1, 60 do
				starts[i] = { x = (i * 37) % 500, z = (i * 53) % 300 }
			end
			local targets = Formation.AlongLine(starts, { { x = 0, z = 1000 }, { x = 5900, z = 1000 } })
			local taken = {}
			for _, target in ipairs(targets) do
				assert.is_nil(taken[target.x])
				taken[target.x] = true
			end
			assert.are.equal(60, #targets)
		end)
	end)

	describe("headings", function()
		it("averages headings across the wrap", function()
			assert.is_true(near(0, Formation.MeanHeading({ 0.1, -0.1 })))
			assert.is_true(near(math.pi, math.abs(Formation.MeanHeading({ math.pi - 0.1, -math.pi + 0.1 }))))
		end)

		it("has no mean for headings that cancel out", function()
			assert.is_nil(Formation.MeanHeading({ 0, math.pi }))
		end)
	end)
end)
