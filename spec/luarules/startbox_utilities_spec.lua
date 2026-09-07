-- Arrangement resolution and the whole-map fill for allyteams the arrangement does not
-- reach. Modoptions are base64 of raw JSON here, with the zlib step stubbed out.

local base64 = VFS.Include("common/luaUtilities/base64.lua")

local MODULE_PATH = "luarules/gadgets/include/startbox_utilities.lua"
local MAP_SIZE_X, MAP_SIZE_Z = 4096, 4096
local GAIA_TEAM_ID = 99
local GAIA_ALLY_TEAM_ID = 50

local function rect(x1, z1, x2, z2)
	return string.format('{"poly":[{"x":%d,"y":%d},{"x":%d,"y":%d}]}', x1, z1, x2, z2)
end

local function arrangement(...)
	return '{"startboxes":[' .. table.concat({ ... }, ",") .. "]}"
end

local function set(pairsByTeamCount)
	local parts = {}
	for _, pair in ipairs(pairsByTeamCount) do
		parts[#parts + 1] = string.format('"%s":%s', pair[1], pair[2])
	end

	return "{" .. table.concat(parts, ",") .. "}"
end

-- Slices of a 200x200 arrangement space, one per team, so every box is real and none of
-- them covers the map.
local function evenArrangement(numBoxes)
	local boxes = {}
	local width = math.floor(200 / numBoxes)
	for i = 1, numBoxes do
		boxes[i] = rect((i - 1) * width, 0, ((i - 1) * width) + 10, 200)
	end

	return arrangement(unpack(boxes))
end

local savedSpring, savedGame, savedJson, savedZlib

local function setUpGame(numAllyTeams, modoptions)
	local allyTeamList = {}
	for i = 1, numAllyTeams do
		allyTeamList[i] = i - 1
	end
	allyTeamList[numAllyTeams + 1] = GAIA_ALLY_TEAM_ID

	Spring.GetAllyTeamList = function()
		return allyTeamList
	end
	Spring.GetGaiaTeamID = function()
		return GAIA_TEAM_ID
	end
	Spring.GetTeamAllyTeamID = function(teamID)
		if teamID == GAIA_TEAM_ID then
			return GAIA_ALLY_TEAM_ID
		end

		return teamID
	end
	Spring.GetAllyTeamStartBox = function()
		return 0, 0, MAP_SIZE_X, MAP_SIZE_Z
	end
	Spring.GetModOptions = function()
		local encoded = {}
		for key, json in pairs(modoptions or {}) do
			encoded[key] = base64.Encode(json)
		end

		return encoded
	end
end

describe("startbox_utilities", function()
	before_each(function()
		savedSpring = {
			GetAllyTeamList = Spring.GetAllyTeamList,
			GetGaiaTeamID = Spring.GetGaiaTeamID,
			GetTeamAllyTeamID = Spring.GetTeamAllyTeamID,
			GetAllyTeamStartBox = Spring.GetAllyTeamStartBox,
			GetModOptions = Spring.GetModOptions,
		}
		savedGame = { mapSizeX = Game.mapSizeX, mapSizeZ = Game.mapSizeZ }
		savedJson = _G.Json
		savedZlib = VFS.ZlibDecompress

		Game.mapSizeX, Game.mapSizeZ = MAP_SIZE_X, MAP_SIZE_Z
		_G.Json = VFS.Include("common/luaUtilities/json.lua")
		VFS.ZlibDecompress = function(data)
			return data
		end
	end)

	after_each(function()
		for key, value in pairs(savedSpring) do
			Spring[key] = value
		end
		Game.mapSizeX, Game.mapSizeZ = savedGame.mapSizeX, savedGame.mapSizeZ
		_G.Json = savedJson
		VFS.ZlibDecompress = savedZlib
	end)

	describe("an arrangement that covers every allyteam", function()
		it("gives every allyteam its own box", function()
			setUpGame(5, { mapmetadata_startboxes_set = set({ { "5", evenArrangement(5) } }) })

			local config, source, explicit = VFS.Include(MODULE_PATH).ParseBoxes()

			assert.are.equal("modoption_set", source)
			assert.is_true(explicit)
			for allyTeamID = 0, 4 do
				assert.is_not_nil(config[allyTeamID])
				assert.is_nil(config[allyTeamID].wholeMap)
			end
		end)
	end)

	describe("an arrangement smaller than the allyteam count", function()
		local config, lib

		before_each(function()
			setUpGame(5, {
				mapmetadata_startboxes_set = set({
					{ "2", evenArrangement(2) },
					{ "3", evenArrangement(3) },
					{ "4", evenArrangement(4) },
				}),
			})
			lib = VFS.Include(MODULE_PATH)
			config = lib.ParseBoxes()
		end)

		it("leaves the arranged allyteams alone", function()
			for allyTeamID = 0, 3 do
				assert.is_nil(config[allyTeamID].wholeMap)
			end
		end)

		it("gives the unarranged allyteam the whole map", function()
			local entry = config[4]

			assert.is_true(entry.wholeMap)
			assert.are.equal(1, #entry.boxes)

			local xmin, zmin, xmax, zmax = lib.GetBounds(4)
			assert.are.equal(0, xmin)
			assert.are.equal(0, zmin)
			assert.are.equal(MAP_SIZE_X, xmax)
			assert.are.equal(MAP_SIZE_Z - 1, zmax)
		end)

		it("counts a whole-map box as no box at all", function()
			assert.is_true(lib.HasStartbox(0))
			assert.is_false(lib.HasStartbox(4))
		end)

		it("puts nowhere out of bounds for the unarranged allyteam", function()
			assert.is_true(lib.IsInside(4, 10, 10))
			assert.is_true(lib.IsInside(4, MAP_SIZE_X - 10, MAP_SIZE_Z - 10))
			assert.is_false(lib.IsInside(0, MAP_SIZE_X - 10, MAP_SIZE_Z - 10))
		end)

		it("skips the gaia allyteam", function()
			assert.is_nil(config[GAIA_ALLY_TEAM_ID])
		end)
	end)

	describe("no arrangement at all", function()
		it("keeps the hardcoded fallback to two boxes", function()
			setUpGame(5, {})

			local config, source, explicit = VFS.Include(MODULE_PATH).ParseBoxes()

			assert.are.equal("fallback", source)
			assert.is_false(explicit)
			assert.is_not_nil(config[0])
			assert.is_not_nil(config[1])
			assert.is_nil(config[2])
		end)
	end)
end)
