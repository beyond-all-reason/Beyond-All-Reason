local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Four cells of the AI's 64 elmo grid, and a square that shares one of them.
local SQUARE = { 0, 0, 128, 0, 128, 128, 0, 128 }
local SHARING_SQUARE = { 64, 64, 200, 64, 200, 200, 64, 200 }
local FAR_SQUARE = { 640, 640, 768, 640, 768, 768, 640, 768 }

describe("mission_api.ai_regions", function()
	local regions ---@type table

	before_each(function()
		regions = MissionSpecEnv.include(env, "luarules/mission_api/ai_regions.lua")
	end)

	it("gives each region of a team an ID of its own, from 1", function()
		assert.are.equal(1, regions.Define("first", 3, SQUARE))
		assert.are.equal(2, regions.Define("second", 3, FAR_SQUARE))
	end)

	it("counts each team's regions from 1", function()
		regions.Define("first", 3, SQUARE)
		assert.are.equal(1, regions.Define("second", 4, FAR_SQUARE))
	end)

	it("refuses a name while a region of that name is live", function()
		regions.Define("first", 3, SQUARE)
		assert.is_nil(regions.Define("first", 3, FAR_SQUARE))
	end)

	it("refuses a region that shares a grid cell with a live region of its team", function()
		regions.Define("first", 3, SQUARE)
		assert.is_nil(regions.Define("second", 3, SHARING_SQUARE))
	end)

	it("lets regions of different teams share a grid cell", function()
		regions.Define("first", 3, SQUARE)
		assert.are.equal(1, regions.Define("second", 4, SHARING_SQUARE))
	end)

	it("refuses a region that holds no cell centre", function()
		assert.is_nil(regions.Define("tiny", 3, { 40, 40, 60, 40, 60, 60, 40, 60 }))
	end)

	it("takes a region whose only cell centre lies in a concave corner's reach", function()
		-- An L: the cell at column 1, row 1 has its centre at 96, 96, outside the L.
		local L_SHAPE = { 0, 0, 128, 0, 128, 64, 64, 64, 64, 128, 0, 128 }
		regions.Define("corner", 3, L_SHAPE)
		assert.are.equal(2, regions.Define("inside the corner", 3, { 64, 64, 128, 64, 128, 128, 64, 128 }))
	end)

	it("gets a live region's name by its team and ID", function()
		local regionID = regions.Define("first", 3, SQUARE)
		assert.are.equal("first", regions.GetName(3, regionID))
		assert.is_nil(regions.GetName(4, regionID))
	end)

	it("forgets a cleared region's name", function()
		local regionID = regions.Define("first", 3, SQUARE)
		regions.Clear("first")
		assert.is_nil(regions.GetName(3, regionID))
	end)

	it("clears a region, returning its ID and team", function()
		local regionID = regions.Define("first", 3, SQUARE)
		assert.are.same({ regionID, 3 }, { regions.Clear("first") })
	end)

	it("clears a region only once", function()
		regions.Define("first", 3, SQUARE)
		regions.Clear("first")
		assert.is_nil(regions.Clear("first"))
	end)

	it("frees a cleared region's cells and name, under a new ID", function()
		local regionID = regions.Define("first", 3, SQUARE)
		regions.Clear("first")
		assert.are.equal(regionID + 1, regions.Define("first", 3, SHARING_SQUARE))
	end)
end)
