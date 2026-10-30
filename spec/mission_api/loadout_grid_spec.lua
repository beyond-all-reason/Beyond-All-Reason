local MissionSpecEnv = require("mission_api.spec_helper")

-- Pos2BuildPos stand-in offset, so a spec can tell its result was used.
local SNAP_OFFSET = 8

-- Sizes in map squares, twice the footprint a unitdef file gives.
local unitDefNames = {
	bot = { id = 1, xsize = 4, zsize = 4, isImmobile = false },
	lab = { id = 2, xsize = 12, zsize = 12, isImmobile = true },
	storage = { id = 3, xsize = 6, zsize = 6, isImmobile = true },
	wall = { id = 4, xsize = 6, zsize = 4, isImmobile = true },
}

---@type table<integer, table>
local created
---@type table<integer, table>
local snapped

local env = MissionSpecEnv.new({
	Game = { squareSize = 8, footprintScale = 2 },
	UnitDefNames = unitDefNames,
	Spring = {
		GetGroundHeight = function()
			return 0
		end,
		GetHeadingFromFacing = function(facing)
			return facing * 16384
		end,
		GetFacingFromHeading = function(heading)
			return math.floor(heading / 16384 + 0.5) % 4
		end,
		Pos2BuildPos = function(unitDefID, x, y, z, facing)
			snapped[#snapped + 1] = { unitDefID = unitDefID, x = x, z = z, facing = facing }
			return x + SNAP_OFFSET, y, z + SNAP_OFFSET
		end,
		CreateUnit = function(unitDefName, x, _, z, facing, team)
			created[#created + 1] = { unitDefName = unitDefName, x = x, z = z, facing = facing, team = team }
			return #created
		end,
		GiveOrderArrayToUnit = function() end,
	},
})
env.BAR = { Utilities = MissionSpecEnv.include(env, "common/springUtilities/facingFunctions.lua") }

GG["MissionAPI"] = {
	trackedUnitIDs = {},
	trackedUnitNames = {},
	trackedFeatureIDs = {},
	trackedFeatureNames = {},
}
local modules = MissionSpecEnv.registerModules(env)
modules.Tracking = MissionSpecEnv.include(env, "luarules/mission_api/tracking.lua")

local loadout = MissionSpecEnv.include(env, "luarules/mission_api/loadout.lua")

local function spawn(entry)
	entry.team = 0
	loadout.SpawnUnitLoadout({ entry })
end

local function sortedPositions(records)
	local xs, zs = {}, {}
	for _, record in ipairs(records) do
		xs[record.x] = true
		zs[record.z] = true
	end
	xs, zs = table.keys(xs), table.keys(zs)
	table.sort(xs)
	table.sort(zs)
	return xs, zs
end

describe("mission_api.loadout grid", function()
	before_each(function()
		created, snapped = {}, {}
	end)

	it("spawns a mobile unit exactly on its point, off the build grid", function()
		spawn({ unitDefName = "bot", x = 1001, z = 1003 })

		assert.are.equal(0, #snapped)
		assert.are.equal(1, #created)
		assert.are.equal(1001, created[1].x)
		assert.are.equal(1003, created[1].z)
	end)

	it("centers a larger quantity on the point", function()
		spawn({ unitDefName = "bot", x = 1000, z = 1000, quantity = 4 })

		local xs, zs = sortedPositions(created)
		assert.are.equal(4, #created)
		assert.are.same({ 984, 1016 }, xs)
		assert.are.same({ 984, 1016 }, zs)
	end)

	-- A bot steps 32 elmos, and a quantity short of a square fills fewer columns.
	for _, case in ipairs({
		{ quantity = 2, xs = { 1000 }, zs = { 984, 1016 } },
		{ quantity = 3, xs = { 984, 1016 }, zs = { 984, 1016 } },
		{ quantity = 5, xs = { 984, 1016 }, zs = { 968, 1000, 1032 } },
		{ quantity = 8, xs = { 968, 1000, 1032 }, zs = { 968, 1000, 1032 } },
	}) do
		it(("centers the columns %d units fill on the point"):format(case.quantity), function()
			spawn({ unitDefName = "bot", x = 1000, z = 1000, quantity = case.quantity })

			local xs, zs = sortedPositions(created)
			assert.are.equal(case.quantity, #created)
			assert.are.same(case.xs, xs)
			assert.are.same(case.zs, zs)
		end)
	end

	it("spawns nothing for a quantity of 0", function()
		spawn({ unitDefName = "bot", x = 1000, z = 1000, quantity = 0 })

		assert.are.equal(0, #created)
	end)

	it("creates a building where Pos2BuildPos puts it", function()
		spawn({ unitDefName = "lab", x = 2050, z = 2070 })

		assert.are.same({ { unitDefID = 2, x = 2050, z = 2070, facing = 0 } }, snapped)
		assert.are.equal(2050 + SNAP_OFFSET, created[1].x)
		assert.are.equal(2070 + SNAP_OFFSET, created[1].z)
	end)

	it("gives Pos2BuildPos the entry's facing", function()
		spawn({ unitDefName = "wall", x = 2048, z = 2048, facing = "east" })

		assert.are.equal(1, snapped[1].facing)
	end)

	it("rounds a building's cells up to whole build grid cells", function()
		-- 48 elmos of footprint plus 4 of spacing take four grid cells of 16.
		spawn({ unitDefName = "storage", x = 2048, z = 2048, quantity = 4, spacing = 4 })

		local xs, zs = sortedPositions(snapped)
		assert.are.equal(4, #created)
		assert.are.same({ 2016, 2080 }, xs)
		assert.are.same({ 2016, 2080 }, zs)
	end)
end)
