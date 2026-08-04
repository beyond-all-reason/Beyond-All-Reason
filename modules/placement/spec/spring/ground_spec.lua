
local Ground = VFS.Include("modules/placement/spring/ground.lua")

local function permissiveChecks()
	return {
		MapEdgeCheck = function()
			return true
		end,
		LandOrSeaCheck = function()
			return "land"
		end,
		FlatAreaCheck = function()
			return true
		end,
		OccupancyCheck = function()
			return true
		end,
	}
end

local savedHeight
local function stubHeight(h)
	savedHeight = Spring.GetGroundHeight
	Spring.GetGroundHeight = function()
		return h or 100
	end
end

describe("what makes a spot usable", function()
	before_each(function()
		stubHeight(100)
	end)
	after_each(function()
		Spring.GetGroundHeight = savedHeight
	end)

	it("answers with the ground height, so a caller never has to guess it", function()
		stubHeight(237)
		local ground = Ground.New({ positionChecks = permissiveChecks() })
		local ok, y = ground.Usable(500, 500, { footprint = 64 })
		assert.is_true(ok)
		assert.are.equal(237, y)
	end)

	it("refuses ground that is the wrong surface, and says so", function()
		local checks = permissiveChecks()
		checks.LandOrSeaCheck = function()
			return "sea"
		end
		local ground = Ground.New({ positionChecks = checks })
		local tally = ground.NewTally()
		assert.is_false(ground.Usable(0, 0, { footprint = 64, surface = "land" }, tally))
		assert.are.equal(1, tally.wrongSurface)
		assert.are.equal(0, tally.steep)
	end)

	it("refuses ground that is half in the water for land AND for sea", function()
		local checks = permissiveChecks()
		checks.LandOrSeaCheck = function()
			return "mixed"
		end
		local ground = Ground.New({ positionChecks = checks })
		assert.is_false(ground.Usable(0, 0, { footprint = 64, surface = "land" }))
		assert.is_false(ground.Usable(0, 0, { footprint = 64, surface = "sea" }))
	end)

	it('"solid" takes land or sea, but never the shoreline between them', function()
		local checks = permissiveChecks()
		local ground = Ground.New({ positionChecks = checks })
		for _, surface in ipairs({ "land", "sea" }) do
			checks.LandOrSeaCheck = function()
				return surface
			end
			assert.is_true(
				ground.Usable(0, 0, { footprint = 64, surface = "solid" }),
				surface .. " should satisfy solid"
			)
		end
		for _, surface in ipairs({ "mixed", "death" }) do
			checks.LandOrSeaCheck = function()
				return surface
			end
			assert.is_false(
				ground.Usable(0, 0, { footprint = 64, surface = "solid" }),
				surface .. " must not satisfy solid"
			)
		end
	end)

	it("takes any surface when the caller does not care", function()
		local checks = permissiveChecks()
		checks.LandOrSeaCheck = function()
			return "mixed"
		end
		local ground = Ground.New({ positionChecks = checks })
		assert.is_true(ground.Usable(0, 0, { footprint = 64, surface = "any" }))
	end)

	it("only measures flatness when the caller asked for it", function()
		local asked = 0
		local checks = permissiveChecks()
		checks.FlatAreaCheck = function()
			asked = asked + 1
			return false
		end
		local ground = Ground.New({ positionChecks = checks })
		assert.is_true(ground.Usable(0, 0, { footprint = 64 }))
		assert.are.equal(0, asked)
		assert.is_false(ground.Usable(0, 0, { footprint = 64, flatness = 20 }))
		assert.are.equal(1, asked)
	end)

	it("defaults clearance to the footprint, not to something roomier", function()
		local seen
		local checks = permissiveChecks()
		checks.OccupancyCheck = function(_x, _y, _z, r)
			seen = r
			return true
		end
		local ground = Ground.New({ positionChecks = checks })
		ground.Usable(0, 0, { footprint = 96 })
		assert.are.equal(96, seen)
		ground.Usable(0, 0, { footprint = 96, clearance = 200 })
		assert.are.equal(200, seen)
	end)

	it("stops at the first refusal, so a cheap test never runs an expensive one", function()
		local occupancy = 0
		local checks = permissiveChecks()
		checks.MapEdgeCheck = function()
			return false
		end
		checks.OccupancyCheck = function()
			occupancy = occupancy + 1
			return true
		end
		local ground = Ground.New({ positionChecks = checks })
		assert.is_false(ground.Usable(0, 0, { footprint = 64 }))
		assert.are.equal(0, occupancy)
	end)

	it("explains a failed area by what refused it, not by a guess", function()
		local ground = Ground.New({ positionChecks = permissiveChecks() })
		local tally = ground.NewTally()
		tally.tried, tally.steep, tally.occupied = 40, 31, 9
		local why = ground.Explain(tally)
		assert.is_truthy(why:find("31 too steep", 1, true))
		assert.is_truthy(why:find("9 too close", 1, true))
	end)

	it("says so plainly when nothing was even attempted", function()
		local ground = Ground.New({ positionChecks = permissiveChecks() })
		assert.are.equal("nowhere was tried", ground.Explain(ground.NewTally()))
	end)
end)
