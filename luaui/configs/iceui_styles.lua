--------------------------------------------------------------------------------
-- IceUI - shared stylesheet
--------------------------------------------------------------------------------
-- The single "CSS" file for every IceUI menu. Each menu has its own section
-- (a named sub-table); a widget loads its own section, e.g.
--   local styleDef = VFS.Include("luaui/configs/iceui_styles.lua").ordermenu
--
-- Truly shared building blocks (colours, the tooltip, the hotkey badge, ...)
-- are defined ONCE as locals at the top and reused in each section -- so a
-- shared tweak is a one-line change, while per-menu values can still diverge.
--
-- Each section is a flat stylesheet: named styles resolved by IceUI.Style.
-- A style may `extends` another style IN THE SAME SECTION.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- shared building blocks
--------------------------------------------------------------------------------

-- shallow copy of a style table, with optional field overrides. Lets a menu
-- reuse a shared block but tweak a value, without metatables (Style.resolve
-- iterates with pairs(), which does not see __index).
local function variant(base, overrides)
	local t = {}
	for k, v in pairs(base) do t[k] = v end
	if overrides then
		for k, v in pairs(overrides) do t[k] = v end
	end
	return t
end

-- the outer frame of any menu
local mainContainer = {
	corner      = 3,
	border      = 1,
	borderColor = { 0.28, 0.32, 0.38 },
	gradient = {
		{ 0.12, 0.13, 0.14, 0.92 },
		{ 0.07, 0.08, 0.09, 0.92 },
	},
	padding = 4,
}

-- a region inside the main container
local subContainer = {
	corner      = 3,
	border      = 1,
	borderColor = { 0.24, 0.27, 0.32 },
	gradient = {
		{ 0.17, 0.19, 0.23, 0.85 },
		{ 0.12, 0.13, 0.16, 0.85 },
	},
	padding = 4,
}

-- shared defaults every button-ish style extends
local base = {
	corner      = 3,
	border      = 1,
	borderColor = { 0.42, 0.47, 0.55 },
	text        = { 0.90, 0.92, 0.95 },
	fontSize    = 11.5,
}

-- the floating tooltip box (identical for every menu)
local tooltip = {
	corner      = 4,
	border      = 1,
	borderColor = { 0.45, 0.50, 0.58 },
	gradient = {
		{ 0.16, 0.18, 0.22, 0.97 },
		{ 0.10, 0.11, 0.14, 0.97 },
	},
	padding    = { 14, 7 },          -- inset from box edge to text
	text       = { 0.88, 0.90, 0.94 },   -- body text colour
	titleText  = { 1.00, 0.84, 0.40 },   -- title line colour (amber)
	hotkeyText = { 0.55, 0.85, 1.00 },   -- hotkey colour (cyan)
	fontSize   = 14,
	titleSize  = 15,
	font       = 2,                 -- title font (Exo2-SemiBold)
	bodyFont   = 1,                 -- body font (Poppins-Regular)
	maxBodyW   = 340,               -- body text wraps to this width (px, unscaled)
}

-- small dark hotkey badge in a button's top-right corner.
-- Font numbers: 1 = Poppins-Regular, 2 = Exo2-SemiBold, 3 = monospace.
local hotkeyBadge = {
	corner      = 2,
	border      = 0,
	background  = { 0.05, 0.06, 0.08, 0.55 },
	text        = { 0.95, 0.96, 1.00 },
	fontSize    = 11,
	font        = 2,
	badgeSize   = 16,    -- box height (px, unscaled); width fits the text
	badgePad    = 0,     -- horizontal text padding (fallback for L and R)
	badgePadL   = 5,     -- left text padding  (overrides badgePad)
	badgePadR   = 2,     -- right text padding (overrides badgePad)
	badgeInset  = 0,     -- gap from the button's top-right corner
}

return {
	----------------------------------------------------------------------------
	-- COMMANDS MENU  (gui_iceui_ordermenu)
	----------------------------------------------------------------------------
	ordermenu = {
		-- Pure spacing numbers. The special row spans the full regular grid
		-- width, split evenly, so no special-button width is set here.
		metrics = {
			buttonGap = 3,    -- between buttons within a subcontainer
			subGap    = 5,    -- between subcontainers
			cellSize  = 48,   -- regular & state buttons: SQUARE side length
			actionH   = 44,   -- special-button height
			regCols   = 6,    -- columns in the regular grid
			margin    = 0,    -- gap from the screen edge to the main container
		},

		-- Hover/press highlight, animated in the shader (no VBO rebuild).
		hover = {
			fadeIn    = 0.08,   -- quick fade-in
			fadeOut   = 0.35,   -- slow, soft fade-out
			tint      = 0.20,   -- how much a hovered button lightens (0..1)
			pressTint = 0.75,   -- how much it darkens while pressed (0..1)
		},

		mainContainer = mainContainer,
		subContainer  = subContainer,
		base          = base,
		tooltip       = tooltip,
		hotkeyBadge   = hotkeyBadge,

		-- order cells
		cell = {
			extends  = "base",
			gradient = {
				{ 0.24, 0.27, 0.32, 1.0 },
				{ 0.15, 0.17, 0.21, 1.0 },
			},
			gloss = 0.08,
		},

		-- the active (currently selected) command -- bright cyan accent
		cellActive = {
			extends     = "cell",
			borderColor = { 0.35, 0.85, 1.00 },
			border      = 2,
			gradient = {
				{ 0.20, 0.34, 0.42, 1.0 },
				{ 0.13, 0.22, 0.30, 1.0 },
			},
			gloss = 0.16,
		},

		-- state toggle ON: green-tinted, lit border
		stateOn = {
			extends     = "cell",
			borderColor = { 0.40, 0.85, 0.45 },
			gradient = {
				{ 0.20, 0.34, 0.22, 1.0 },
				{ 0.13, 0.22, 0.15, 1.0 },
			},
		},

		-- state toggle OFF: red-tinted, dim
		stateOff = {
			extends     = "cell",
			borderColor = { 0.80, 0.40, 0.40 },
			gradient = {
				{ 0.30, 0.20, 0.20, 1.0 },
				{ 0.20, 0.14, 0.14, 1.0 },
			},
		},

		-- big special-command buttons (Self-Destruct, Cloak, D-Gun)
		action = {
			extends  = "base",
			corner   = 4,
			gradient = {
				{ 0.34, 0.24, 0.16, 1.0 },
				{ 0.22, 0.15, 0.10, 1.0 },
			},
			borderColor = { 0.70, 0.50, 0.30 },
			gloss    = 0.12,
			fontSize = 14,
		},
	},

	----------------------------------------------------------------------------
	-- BUILD MENU  (gui_iceui_buildmenu)
	----------------------------------------------------------------------------
	buildmenu = {
		metrics = {
			buttonGap = 2,    -- between build cells
			subGap    = 5,    -- between subcontainers
			cellSize  = 72,   -- build cell side (square) = buildpic size
			gridCols  = 5,    -- build grid columns
			gridRows  = 6,    -- build grid rows per page
			tabH      = 30,   -- category tab row height
			tabIcon   = 22,   -- category-tab group icon size
			topTabH   = 26,   -- top tab row height
			actionBarH = 26,  -- bottom action-bar row height (toggles + clear)
			margin     = 4,    -- screen edge -> main container
			groupIcon  = 28,   -- group icon size, top-left on a build cell
			stratIcon  = 18,   -- strategic (radar) icon size, bottom-left on a cell
			stratInset = 1.5,    -- gap from the cell's left/bottom edge to the strat icon
			corner	= 3,    -- all buttons: corner radius
		},

		hover = {
			fadeIn    = 0.08,
			fadeOut   = 0.35,
			tint      = 0.20,
			pressTint = 0.22,
		},

		-- the build menu uses a slightly roomier main padding
		mainContainer = variant(mainContainer, { padding = 5 }),
		subContainer  = subContainer,
		base          = base,
		tooltip       = tooltip,
		hotkeyBadge   = hotkeyBadge,

		-- category tabs (unselected / selected)
		tab = {
			extends  = "base",
			gradient = {
				{ 0.20, 0.22, 0.27, 1.0 },
				{ 0.13, 0.14, 0.18, 1.0 },
			},
			text     = { 0.70, 0.73, 0.78 },
			fontSize = 14,
		},
		tabActive = {
			extends     = "tab",
			borderColor = { 0.85, 0.65, 0.25 },
			border      = 2,
			gradient = {
				{ 0.34, 0.27, 0.13, 1.0 },
				{ 0.22, 0.17, 0.09, 1.0 },
			},
			text = { 1.00, 0.92, 0.70 },
		},

		-- top tabs (BUILD MENU / BLUEPRINTS)
		topTab = {
			extends  = "base",
			corner   = 3,
			border   = 0,
			gradient = {
				{ 0.15, 0.17, 0.20, 1.0 },
				{ 0.10, 0.11, 0.14, 1.0 },
			},
			text     = { 0.62, 0.65, 0.70 },
			fontSize = 14,
		},
		topTabActive = {
			extends  = "topTab",
			gradient = {
				{ 0.24, 0.27, 0.32, 1.0 },
				{ 0.16, 0.18, 0.22, 1.0 },
			},
			text = { 0.95, 0.96, 1.00 },
		},

		-- bottom action bar: factory toggles (Guard / Priority / Queue mode) and
		-- the Clear Queue button. Toggle OFF = dim neutral, ON = green + lit.
		barToggle = {
			extends  = "base",
			corner   = 3,
			gradient = {
				{ 0.20, 0.22, 0.27, 1.0 },
				{ 0.13, 0.14, 0.18, 1.0 },
			},
			text     = { 0.70, 0.73, 0.78 },
			fontSize = 12,
		},
		barToggleOn = {
			extends     = "barToggle",
			borderColor = { 0.40, 0.85, 0.45 },
			border      = 2,
			gradient = {
				{ 0.20, 0.34, 0.22, 1.0 },
				{ 0.13, 0.22, 0.15, 1.0 },
			},
			text = { 0.80, 1.00, 0.82 },
		},
		-- Clear Queue: a one-shot action button, amber-ish like ordermenu.action
		barAction = {
			extends  = "base",
			corner   = 3,
			gradient = {
				{ 0.34, 0.24, 0.16, 1.0 },
				{ 0.22, 0.15, 0.10, 1.0 },
			},
			borderColor = { 0.70, 0.50, 0.30 },
			text     = { 1.00, 0.90, 0.78 },
			fontSize = 12,
		},

		-- build cells
		cell = {
			extends  = "base",
			gradient = {
				{ 0.24, 0.27, 0.32, 1.0 },
				{ 0.15, 0.17, 0.21, 1.0 },
			},
			gloss = 0.08,
		},

		-- CLEAR QUEUE / NEXT PAGE / PREV PAGE
		actionBtn = {
			extends  = "base",
			corner   = 3,
			gradient = {
				{ 0.26, 0.28, 0.33, 1.0 },
				{ 0.17, 0.18, 0.22, 1.0 },
			},
			borderColor = { 0.45, 0.50, 0.58 },
			gloss    = 0.10,
			fontSize = 13,
		},

		-- queue-count badge: top-right corner of a build cell, shows how many
		-- of that unit are queued. Like hotkeyBadge but larger, own number
		-- colour. Left-click a cell adds to the queue, right-click removes.
		queueBadge = {
			corner      = 2,
			border      = 0,
			background  = { 0.05, 0.06, 0.08, 0.80 },
			text        = { 0.55, 1.00, 0.55 },   -- queue number colour (green)
			fontSize    = 15,
			font        = 2,
			badgeSize   = 22,    -- box height (px, unscaled)
			badgePad    = 0,
			badgePadL   = 5,
			badgePadR   = 5,
			badgeInset  = 0,
		},

		-- build-progress "clock": the dark pie overlay on the unit currently
		-- being built. {r,g,b,a} -- a is how dark the cover is.
		buildClock = { 0.04, 0.05, 0.06, 0.62 },
	},

	----------------------------------------------------------------------------
	-- INFO PANEL  (gui_iceui_info) -- selected-unit info, right of the orders
	----------------------------------------------------------------------------
	info = {
		metrics = {
			width      = 360,   -- panel width  (px, unscaled)
			height     = 172,   -- panel height (px, unscaled) -- matches orders
			padding    = 4,     -- inset from the panel edge to its content
			                    -- (keep equal to mainContainer.padding = 4)
			subGap     = 5,    -- between sub-regions
			subPad     = 8,     -- inner padding of the left subcontainers
			                    -- (text gets this much room from their edges)
			buildpic   = 96,    -- buildpic side length (square)
			stratIcon  = 22,    -- strategic icon size, bottom-left on the buildpic
			stratInset = 2,     -- strat icon gap from the buildpic edge
			barH       = 14,    -- health bar height
			margin     = 5,     -- gap to the order menu it docks beside
			                    -- (= the orders<->build vertical gap, subGap=5)

			-- multi-selection grid (>1 unit selected): one buildpic cell per
			-- unit TYPE, each with an "xN" count badge, above a totals line.
			gridGap     = 2,    -- gap between grid cells
			gridCell    = 46,   -- grid cell side length (square)
			gridStrat   = 14,   -- strat icon size on a grid cell
			countBadgeH = 16,   -- "xN" count-badge box height
			totalsH     = 20,   -- height of the totals text row under the grid
		},

		mainContainer = mainContainer,
		subContainer  = subContainer,
		base          = base,

		-- the unit buildpic frame (right side)
		picFrame = {
			corner      = 3,
			border      = 1,
			borderColor = { 0.42, 0.47, 0.55 },
			gradient = {
				{ 0.20, 0.22, 0.27, 1.0 },
				{ 0.12, 0.13, 0.16, 1.0 },
			},
		},

		-- multi-selection grid cell -- one buildpic per selected unit type
		gridCell = {
			extends  = "base",
			corner   = 3,
			gradient = {
				{ 0.24, 0.27, 0.32, 1.0 },
				{ 0.15, 0.17, 0.21, 1.0 },
			},
			gloss = 0.08,
		},

		-- count badge -- "N" of that unit type, top-left corner of a grid cell
		countBadge = {
			corner     = 2,
			border     = 0,
			background = { 0.05, 0.06, 0.08, 0.85 },
			text       = { 0.95, 0.96, 1.00 },
			fontSize   = 12,
			font       = 2,
			badgeSize  = 16,
			badgePad   = 0,
			badgePadL  = 4,
			badgePadR  = 4,
			badgeInset = 0,
			keepCase   = true,
		},

		-- health bar: a dark track with a coloured fill on top
		barTrack = {
			corner     = 2,
			border     = 0,
			background = { 0.05, 0.06, 0.08, 0.85 },
		},
		barFill = {
			corner     = 2,
			border     = 0,
			background = { 0.40, 0.85, 0.45, 1.0 },   -- green (recoloured live)
		},

		-- text colours / sizes (one sub-table -- Style.resolve only copies
		-- tables, so bare scalars must not sit at the section's top level).
		typo = {
			titleColor  = { 1.00, 0.92, 0.70 },   -- unit name
			titleSize   = 16,
			descColor   = { 0.70, 0.73, 0.78 },   -- description line
			descSize    = 13,
			labelColor  = { 0.62, 0.65, 0.70 },   -- stat labels (HP, etc.)
			labelSize   = 12,
			valueColor  = { 0.95, 0.96, 1.00 },   -- stat values
			valueSize   = 14,
			metalColor  = { 0.82, 0.84, 0.87 },   -- metal cost
			energyColor = { 1.00, 0.90, 0.25 },   -- energy cost
			countColor  = { 0.62, 0.65, 0.70 },   -- "N units selected" header
		},
	},
}
