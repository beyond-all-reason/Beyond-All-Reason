---@diagnostic disable: undefined-field, need-check-nil, call-non-callable
-- A start position's role, set in the regions tool: held by regions on the position, and exported as the map's start
-- position suggestions, which the suggestions widget reads back.
local Regions = require("modules/regions/api")
local Support = require("spec/luaui/Widgets/support/regions_tool")

describe("role_cycle", function()
	local tool

	before_each(function()
		Regions.Clear()
		local R
		R, tool = Support.Tool()
		R.setType("start")
		tool.clearAllPositions()
		tool.addPosition(100, 100, 0, 1)
	end)

	local presets = { "front", "air", "tech" }

	it("starts from the first preset when role is nil", function()
		assert.equals("front", tool.cyclePositionRole(1, 1, presets))
	end)

	it("advances through each preset in order", function()
		assert.equals("front", tool.cyclePositionRole(1, 1, presets))
		assert.equals("air", tool.cyclePositionRole(1, 1, presets))
		assert.equals("tech", tool.cyclePositionRole(1, 1, presets))
	end)

	it("rolls over to nil after the last preset", function()
		tool.cyclePositionRole(1, 1, presets)
		tool.cyclePositionRole(1, 1, presets)
		assert.equals("tech", tool.cyclePositionRole(1, 1, presets))
		assert.is_nil(tool.cyclePositionRole(1, 1, presets))
	end)

	it("returns to the first preset after nil", function()
		for _ = 1, #presets do
			tool.cyclePositionRole(1, 1, presets)
		end
		assert.is_nil(tool.cyclePositionRole(1, 1, presets))
		assert.equals("front", tool.cyclePositionRole(1, 1, presets))
	end)

	it("starts from the first preset if the current role is unknown in the provided presets", function()
		tool.cyclePositionRole(1, 1, { "front" })
		assert.equals("air", tool.cyclePositionRole(1, 1, { "air", "tech" }))
	end)

	it("cycles backward through presets", function()
		tool.cyclePositionRole(1, 1, presets) -- front
		tool.cyclePositionRole(1, 1, presets) -- air
		tool.cyclePositionRole(1, 1, presets) -- tech
		assert.equals("air", tool.cyclePositionRole(1, -1, presets))
		assert.equals("front", tool.cyclePositionRole(1, -1, presets))
	end)

	it("clears the role when cycling backward past the first preset", function()
		tool.cyclePositionRole(1, 1, presets) -- front
		assert.is_nil(tool.cyclePositionRole(1, -1, presets))
	end)

	it("returns to the last preset after clearing role backward", function()
		tool.cyclePositionRole(1, 1, presets) -- front
		assert.is_nil(tool.cyclePositionRole(1, -1, presets))
		assert.equals("tech", tool.cyclePositionRole(1, -1, presets))
	end)

	it("starts from the last preset when cycling backward with no role", function()
		assert.equals("tech", tool.cyclePositionRole(1, -1, presets))
	end)

	it("is the start's: regions holds it on the position, and a position placed after keeps its own", function()
		tool.cyclePositionRole(1, 1, presets)
		tool.addPosition(300, 300, 0, 2)
		local start = assert(Regions.All("start")[1]) --[[@as table]]
		assert.are.same({ { x = 100, z = 100, role = "front" }, { x = 300, z = 300 } }, start.positions)
	end)
end)

describe("startbox_encode", function()
	it("encodes a simple box through the shared pipeline", function()
		Regions.Clear()
		local R, tool = Support.Tool()
		R.setType("start")
		assert.is_true(Support.Create(R, Support.Square(100)))
		local value, count = tool.encodeStartboxes()
		assert.is_not_nil(value)
		assert.equals(1, count)
	end)
end)

describe("startpos_suggestions_roundtrip", function()
	-- Reuse the role-cycle helper to set roles, then verify the exported suggestions
	-- data survives the full round-trip through the suggestions widget's loader.
	local presets = { "front", "air", "tech" }

	local tool

	before_each(function()
		Regions.Clear()
		local R
		R, tool = Support.Tool()
		R.setType("start")
		tool.clearAllPositions()
	end)

	local function makeSuggestionsEnv(encoded)
		local gaiaTeamID = 999
		return setmetatable({
			widget = {},
			WG = {},
			GL = {
				LINE_LOOP = 1,
				LINE_STRIP = 2,
				LINES = 3,
				TRIANGLE_FAN = 4,
				TRIANGLE_STRIP = 5,
				TRIANGLES = 6,
				SRC_ALPHA = 7,
				ONE = 8,
				ONE_MINUS_SRC_ALPHA = 9,
			},
			gl = {
				Color = function() end,
				LineWidth = function() end,
				DrawGroundCircle = function() end,
				PushMatrix = function() end,
				PopMatrix = function() end,
				Translate = function() end,
				Billboard = function() end,
				Text = function() end,
				BeginEnd = function() end,
				Vertex = function() end,
				Texture = function() end,
				TexRect = function() end,
				Blending = function() end,
				DepthTest = function() end,
				CreateList = function() end,
				CallList = function() end,
				DeleteList = function() end,
				GetTextWidth = function() end,
				LoadFont = function()
					return {
						SetTextColor = function() end,
						Print = function() end,
						SetOutlineColor = function() end,
					}
				end,
				DeleteFont = function() end,
			},
			Game = setmetatable({
				mapSizeX = 10000,
				mapSizeZ = 10000,
			}, { __index = _G.Game }),
			Spring = setmetatable({
				GetModOptions = function()
					return { mapmetadata_startpos = encoded }
				end,
				GetAllyTeamList = function()
					return { 1, 2 }
				end,
				GetTeamList = function()
					return { 1, 2 }
				end,
				GetGaiaTeamID = function()
					return gaiaTeamID
				end,
				GetViewGeometry = function()
					return 1024, 768
				end,
				GetConfigString = function(_, default)
					return default
				end,
				GetGroundHeight = function()
					return 0
				end,
				GetTeamInfo = function(teamID, bool)
					return teamID, 0, false, false, "", teamID
				end,
				SetLogSectionFilterLevel = function() end,
			}, { __index = _G.Spring }),
			widgetHandler = { RemoveWidget = function() end },
		}, { __index = _G })
	end

	it("round-trips positions and roles through the suggestions data format", function()
		-- Place 4 positions across 2 ally teams x 2 slots and assign roles via the
		-- role-cycle helper, mirroring how a player would use the tool.
		tool.addPosition(100, 100, 0, 1)
		assert.equals("front", tool.cyclePositionRole(1, 1, presets))
		tool.addPosition(300, 300, 0, 2)
		assert.equals("front", tool.cyclePositionRole(2, 1, presets))
		assert.equals("air", tool.cyclePositionRole(2, 1, presets))
		tool.addPosition(500, 500, 1, 1)
		assert.equals("front", tool.cyclePositionRole(3, 1, presets))
		assert.equals("air", tool.cyclePositionRole(3, 1, presets))
		assert.equals("tech", tool.cyclePositionRole(3, 1, presets))
		tool.addPosition(700, 700, 1, 2)
		-- position 4 is left without a role

		local data = tool.buildSuggestionsData()
		assert.is_not_nil(data)

		-- Encode exactly as the tool does for the bSet modoption payload.
		local encoded = tool.encodeBSetValue(data)
		assert.is_not_nil(encoded)

		-- Sandbox for the suggestions widget, with Spring reporting the same team
		-- topology the tool just exported so the widget selects this config.
		local suggestionsEnv = makeSuggestionsEnv(encoded)
		local mapSuggestionsWidget = VFS.Include("luaui/Widgets/map_start_position_suggestions.lua", suggestionsEnv)
		suggestionsEnv.widget:Initialize()

		local positions = mapSuggestionsWidget.getStartPositions()
		assert.is_not_nil(positions)
		assert.equals(2, #positions)

		-- Ally team 1: two positions, both with roles.
		local side1 = positions[1]
		assert.equals(2, #side1)
		assert.same({ name = "P1", spawnPoint = { x = 100, z = 100 }, baseCenter = nil, role = "front" }, side1[1])
		assert.same({ name = "P2", spawnPoint = { x = 300, z = 300 }, baseCenter = nil, role = "air" }, side1[2])

		-- Ally team 2: one with a role, one without.
		local side2 = positions[2]
		assert.equals(2, #side2)
		assert.same({ name = "P3", spawnPoint = { x = 500, z = 500 }, baseCenter = nil, role = "tech" }, side2[1])
		assert.same({ name = "P4", spawnPoint = { x = 700, z = 700 }, baseCenter = nil, role = nil }, side2[2])
	end)
end)
