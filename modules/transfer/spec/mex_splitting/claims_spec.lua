local Claims = VFS.Include("modules/transfer/mex_splitting/claims.lua") ---@type MexRegionsClaimsLib
local Records = VFS.Include("modules/transfer/mex_splitting/records.lua") ---@type MexRegionsRecords
local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local RegionEnums = VFS.Include("modules/regions/enums.lua")
local Shared = VFS.Include("modules/transfer/mex_splitting/shared.lua") ---@type MexRegionsShared

---@param id string|nil the layout's id; defaults to name@team, the fixtures' convention
local function rect(team, group, x1, y1, x2, y2, name, id)
	return {
		id = id or ((name or group) .. "@" .. tostring(team)),
		name = name,
		team = team,
		group = group,
		poly = { { x = x1, y = y1 }, { x = x2, y = y2 } },
	}
end

---@return MexRegion[]
local function parse(entries)
	local regions, reason = Regions.ParseLayout(
		{ regions = { [RegionEnums.Types.MexRegion] = entries } },
		RegionEnums.Types.MexRegion,
		200,
		200
	)
	assert(regions, reason)
	return Records.From(regions)
end

describe("a mex region record", function()
	it("is named by the map or after its group, and keeps the id the layout carries", function()
		local regions = parse({
			rect(1, "anti", 0, 0, 20, 20),
			rect(1, "tech", 20, 0, 40, 20, nil, "t1"),
			rect(1, "tech", 40, 0, 60, 20, nil, "t2"),
			rect(2, "tech", 180, 180, 200, 200, "far"),
		})
		assert.are.same(
			{ "anti", "tech_1", "tech_2", "far" },
			{ regions[1].name, regions[2].name, regions[3].name, regions[4].name }
		)
		assert.are.same(
			{ "anti@1", "t1", "t2", "far@2" },
			{ regions[1].id, regions[2].id, regions[3].id, regions[4].id }
		)
	end)
end)

describe("the deal's steps", function()
	local regions = parse({
		rect(1, "g", 0, 0, 20, 20, "near"),
		rect(2, "g", 180, 180, 200, 200, "far"),
		rect(1, "g", 90, 90, 110, 110, "mid"),
	})

	it("rank every region from where each team starts, nearest first", function()
		local views = Claims.Rank({
			{ teamID = 0, allyTeam = 1, x = 0, z = 0 },
			{ teamID = 1, allyTeam = 2, x = 200, z = 200 },
		}, regions)
		assert.are.equal(2, #views)
		local names = {}
		for i, ranked in ipairs(views[1].regions) do
			names[i] = ranked.region.name
		end
		assert.are.same({ "near", "mid", "far" }, names)
		assert.are.equal("far", views[2].regions[1].region.name)
		assert.are.equal(1, views[2].team.teamID)
		assert.is_true(views[1].regions[1].distance < views[1].regions[2].distance)
	end)

	it("place each spot in the region that covers it", function()
		local byRegion = Claims.SpotsIn(regions, { { x = 5, z = 5 }, { x = 100, z = 100 }, { x = 150, z = 150 } })
		assert.are.same({ Shared.SpotKey(5, 5) }, byRegion["near@1"])
		assert.are.same({ Shared.SpotKey(100, 100) }, byRegion["mid@1"])
		assert.is_nil(byRegion["far@2"])
	end)

	it("list each team's holdings in layout order", function()
		assert.are.same(
			{ [0] = { "near@1", "mid@1" }, [1] = { "far@2" } },
			Claims.Holdings(regions, { ["near@1"] = 0, ["far@2"] = 1, ["mid@1"] = 0 })
		)
	end)

	it("find nothing wrong with a layout its type accepts, and name what the set check refuses", function()
		assert.are.same({}, Claims.Problems(regions, { { x = 5, z = 5 } }))
		assert.are.same({ "1 metal spot in no mex region" }, Claims.Problems(regions, { { x = 150, z = 150 } }))
		local unteamed = parse({
			rect(1, "a", 0, 0, 40, 40),
			{ id = "b", group = "b", poly = { { x = 60, y = 60 }, { x = 80, y = 80 } } },
		})
		assert.are.same({ "b: a mex region needs a team" }, Claims.Problems(unteamed, {}))
	end)
end)
