---@diagnostic disable: undefined-field, need-check-nil, call-non-callable

describe("role_cycle", function()
	-- The role-cycle helper is embedded in the startpos tool widget. Load the
	-- widget into a sandbox that provides the minimal globals it needs, then
	-- exercise it through its normal Initialize / Shutdown lifecycle and the
	-- public WG.StartPosTool API.
	local env = setmetatable({
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
		},
		Game = setmetatable({
			mapSizeX = 10000,
			mapSizeZ = 10000,
		}, { __index = _G.Game }),
		Spring = setmetatable({
			GetModOptions = function()
				return { startpos_max_slope = 1 }
			end,
			GetGroundNormal = function()
				return 0, 1, 0, 0
			end,
			GetGroundHeight = function()
				return 0
			end,
		}, { __index = _G.Spring }),
	}, { __index = _G })

	VFS.Include("luaui/Widgets/cmd_startpos_tool.lua", env)

	local tool

	before_each(function()
		env.widget:Initialize()
		tool = env.WG.StartPosTool
		tool.clearAllPositions()
		tool.addPosition(100, 100, 1, 1)
	end)

	after_each(function()
		env.widget:Shutdown()
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
end)
