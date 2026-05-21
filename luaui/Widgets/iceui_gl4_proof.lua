local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "IceUI-GL4 Proof",
		desc    = "Proof-of-concept for the IceUI-GL4 framework (core + styles + layout). Draws a styled panel top-left.",
		author  = "BAR team",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = false,  -- test widget: enable manually from the widget list (F11)
	}
end

--------------------------------------------------------------------------------
-- IceUI-GL4 proof-of-concept
--------------------------------------------------------------------------------
-- Exercises the whole IceUI-GL4 stack:
--   * a stylesheet with inheritance (extends) and hover/pressed states
--   * the layout engine (grid + weighted row)
--   * the Panel API for hit-testing, hover/press and text
--
-- Draws a panel near the top-left: a title strip, a 4x2 grid of buttons, and
-- a row of 3 wider buttons underneath. Buttons light up on hover, darken on
-- press, and echo to console on click. If that all works, the framework is
-- sound and we can rebuild the real commands menu on it.
--------------------------------------------------------------------------------

local IceUI = VFS.Include("luaui/Include/IceUI/iceui.lua", nil, VFS.RAW_FIRST)
local Layout = IceUI.Layout

--------------------------------------------------------------------------------
-- stylesheet  (this is the "CSS" -- pure data, easy to retheme)
--------------------------------------------------------------------------------

local stylesheet = {
	-- a shared base every panel element inherits from
	base = {
		corner      = 6,
		border      = 1,
		borderColor = { 0.45, 0.52, 0.62 },
	},

	panel = {
		extends     = "base",
		corner      = 9,
		gradient    = {
			{ 0.13, 0.15, 0.18, 0.92 },   -- top
			{ 0.07, 0.08, 0.10, 0.92 },   -- bottom
		},
		borderColor = { 0.35, 0.40, 0.48 },
		padding     = 12,
	},

	titleStrip = {
		corner     = 2,
		background = { 0.30, 0.75, 1.00, 0.9 },
		border     = 0,
	},

	button = {
		extends  = "base",
		gradient = {
			{ 0.26, 0.30, 0.36, 1.0 },
			{ 0.16, 0.19, 0.23, 1.0 },
		},
		gloss    = 0.10,
		text     = { 0.90, 0.92, 0.95 },
		fontSize = 13,
		states   = {
			hover   = { borderColor = { 0.55, 0.80, 1.00 } },
			pressed = { gloss = 0.0 },
		},
	},

	-- a brighter "primary" button, inherits button + its states
	primary = {
		extends  = "button",
		gradient = {
			{ 0.20, 0.42, 0.30, 1.0 },
			{ 0.12, 0.26, 0.18, 1.0 },
		},
	},
}

--------------------------------------------------------------------------------

local panel        -- IceUI Panel
local panelRect    -- {l,b,r,t}
local stripRect    -- title strip rect
local gridCells    -- list of rects
local rowCells     -- list of rects

local function buildLayout()
	local vsx, vsy = Spring.GetViewGeometry()

	local panelW = 380
	local panelH = 210
	local left   = 40
	local top    = vsy - 40
	panelRect = { left, top - panelH, left + panelW, top }

	-- inner content area after panel padding
	local pl, pb, pr, pt = IceUI.Style.padding(panel:style("panel"))
	local content = Layout.inset(panelRect, pl, pb, pr, pt)

	-- split content vertically: title strip, grid, row
	local rows = Layout.column(content, { 0.8, 3, 1.2 }, 8)
	stripRect = rows[1]
	gridCells = Layout.grid(rows[2], 4, 2, 6)
	rowCells  = Layout.row(rows[3], { 1, 1, 1 }, 8)
end

function widget:Initialize()
	if not WG.IceUI then
		Spring.Echo("[IceUI-GL4 Proof] WG.IceUI not available -- enable the IceUI-GL4 widget")
		widgetHandler:RemoveWidget()
		return
	end
	panel = IceUI.newPanel(stylesheet)
	buildLayout()
	WG.IceUI.registerDraw("iceui_proof", {
		draw = function() widget:draw() end,     -- draw phase: queue rects
		text = function() panel:drawText() end,  -- text phase: draw labels
	})
end

function widget:Shutdown()
	if WG.IceUI then
		WG.IceUI.unregisterDraw("iceui_proof")
	end
end

function widget:ViewResize()
	buildLayout()
end

-- Queue all proof elements for this frame.
function widget:draw()
	local mx, my, lmb = Spring.GetMouseState()

	panel:begin(mx, my, lmb)

	-- panel background + title strip
	panel:box("panel", panelRect)
	panel:box("titleStrip", stripRect)

	-- 4x2 grid of buttons
	for i = 1, #gridCells do
		local hovered, clicked = panel:button(
			"grid" .. i, "button", gridCells[i], "Btn " .. i)
		if clicked then
			Spring.Echo("[IceUI-GL4 Proof] grid button " .. i .. " clicked")
		end
	end

	-- row of 3 primary buttons
	local rowLabels = { "Alpha", "Bravo", "Charlie" }
	for i = 1, #rowCells do
		local hovered, clicked = panel:button(
			"row" .. i, "primary", rowCells[i], rowLabels[i])
		if clicked then
			Spring.Echo("[IceUI-GL4 Proof] row button '" .. rowLabels[i] .. "' clicked")
		end
	end

	panel:finish()
end
