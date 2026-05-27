local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Info panel (IceUI)",
		desc    = "Selected-unit info panel rebuilt on the IceUI-GL4 framework.",
		author  = "BAR team",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		-- below the FlowUI menus, like the other IceUI widgets
		layer   = -10,
		enabled = false,  -- enable from the widget list
	}
end

--------------------------------------------------------------------------------
-- IceUI info panel
--------------------------------------------------------------------------------
-- The selected-unit info view, drawn through IceUI-GL4. Docks to the RIGHT of
-- the IceUI commands menu (WG.IceUIOrderMenu.rect). v1 scope: unit name +
-- description + buildpic (with strategic icon) + a live health bar + the
-- metal/energy cost. Mirrors the single-unit part of the classic gui_info.
--
-- Static unit data (name, description, costs, maxHealth, buildpic, strat icon)
-- is precomputed once. Live data (current health) is read every frame.
--------------------------------------------------------------------------------

local IceUI    = VFS.Include("luaui/Include/IceUI/iceui.lua", nil, VFS.RAW_FIRST)
local Layout   = IceUI.Layout
local styleDef = VFS.Include("luaui/configs/iceui_styles.lua", nil, VFS.RAW_FIRST).info
local typo     = styleDef.typo   -- text colours / sizes

--------------------------------------------------------------------------------
-- Spring API locals
--------------------------------------------------------------------------------

local spGetSelectedUnits        = Spring.GetSelectedUnits
local spGetSelectedUnitsCount   = Spring.GetSelectedUnitsCount
local spGetSelectedUnitsCounts  = Spring.GetSelectedUnitsCounts
local spGetUnitDefID            = Spring.GetUnitDefID
local spGetUnitHealth           = Spring.GetUnitHealth
local spGetUnitResources        = Spring.GetUnitResources
local spGetMouseState           = Spring.GetMouseState
local spGetViewGeometry         = Spring.GetViewGeometry
local spTraceScreenRay          = Spring.TraceScreenRay
local spIsGUIHidden             = Spring.IsGUIHidden

local mathFloor = math.floor
local mathMax   = math.max
local mathMin   = math.min
local mathCeil  = math.ceil

--------------------------------------------------------------------------------
-- static unit data -- precomputed once
--------------------------------------------------------------------------------

local unitName      = {}   -- unitDefID -> display name
local unitDesc      = {}   -- unitDefID -> description / tooltip text
local unitMetal     = {}   -- unitDefID -> metal cost
local unitEnergy    = {}   -- unitDefID -> energy cost
local unitMaxHP     = {}   -- unitDefID -> max health
local unitBuildSpd  = {}   -- unitDefID -> build speed (builders only), or 0
local unitBuildpic  = {}   -- unitDefID -> "#"..unitDefID engine texture
local unitStratIcon = {}   -- unitDefID -> ":l:icons/<file>" strategic icon, or nil

local iconTypeBitmap = VFS.Include("gamedata/icontypes.lua")

for unitDefID, ud in pairs(UnitDefs) do
	unitName[unitDefID]     = ud.translatedHumanName or ud.humanName or ud.name
	unitDesc[unitDefID]     = ud.translatedTooltip or ud.tooltip or ""
	unitMetal[unitDefID]    = ud.metalCost or 0
	unitEnergy[unitDefID]   = ud.energyCost or 0
	unitMaxHP[unitDefID]    = ud.health or 0
	unitBuildSpd[unitDefID] = (ud.buildSpeed and ud.buildSpeed > 0) and ud.buildSpeed or 0
	unitBuildpic[unitDefID] = "#" .. unitDefID
	local it = ud.iconType and iconTypeBitmap[ud.iconType]
	if it and it.bitmap then
		unitStratIcon[unitDefID] = ":l:" .. it.bitmap
	end
end

-- stat-row icons (engine ":l:" texture paths). The dedicated metal/energy cost
-- icons are used for EVERY metal/energy readout in the info card -- both the
-- per-unit costs and the multi-selection income rows.
local ICON_HEALTH     = ":l:LuaUI/Images/iceui/health.png"
local ICON_METALCOST  = ":l:LuaUI/Images/iceui/metal-cost.png"
local ICON_ENERGYCOST = ":l:LuaUI/Images/iceui/energy-cost.png"
local ICON_BUILD      = ":l:LuaUI/Images/iceui/buildpower.png"
local ICON_DPS        = ":l:LuaUI/Images/iceui/dps.png"   -- reserved for DPS line

--------------------------------------------------------------------------------
-- widget state
--------------------------------------------------------------------------------

local panel                  -- IceUI Panel

local vsx, vsy   = spGetViewGeometry()
local uiScale    = Spring.GetConfigFloat("ui_scale", 1)

local registered   = false
local needsRefresh = true    -- recompute the shown unit on the next drawPhase

-- The panel runs in one of two modes:
--   "single" -- one unit (hover or a 1-unit selection): name/desc/HP/cost+pic
--   "multi"  -- >1 unit selected: a grid of buildpics (one per type, "xN"
--               badge) plus a totals line. Hover always forces "single".
local mode = "single"

-- single mode: the unit currently shown (or nil for none)
local shownUnitID    = nil
local shownUnitDefID = nil

-- the unit currently under the cursor (or nil). Hover takes priority over the
-- selection: while a unit is hovered the panel shows it (single mode); on no
-- hover it falls back to the selection. Refreshed every frame in :Update; a
-- *change* of the hovered unit triggers a panel refresh (an unchanged hover
-- does not, so a steady hover costs nothing).
local hoverUnitID = nil

-- multi mode: one entry per distinct selected unit TYPE.
local selCells     = {}   -- ordered list: index -> unitDefID
local selCounts    = {}   -- unitDefID -> how many of that type are selected
local selTotalN    = 0    -- total units selected
local selTotalM    = 0    -- summed metal cost of the whole selection
local selTotalE    = 0    -- summed energy cost of the whole selection

-- layout rects (recomputed by buildLayout)
local mainRect   = {}
-- single mode -- the three subcontainers
local statBox    = {}        -- left-top  : name + desc + health
local costBox    = {}        -- left-bot  : metal / energy
local picRect    = {}        -- right     : buildpic frame
-- single mode -- content rects inside the subcontainers
local nameRect   = {}        -- unit name line
local descRect   = {}        -- description line
local barRect    = {}        -- health bar
local hpRect     = {}        -- "HP" value line
local costRect   = {}        -- metal / energy cost line

-- multi mode -- left stat column, right buildpic grid, bottom totals row
local multiStatBox  = {}     -- left  : the stat lines column
local multiGridBox  = {}     -- right : the buildpic grid container
local multiCostBox  = {}     -- bottom-spanning : COST totals row
-- multi mode -- content: one rect per stat line, and the grid cell rects
local multiHdrRect  = {}     -- "N UNITS" header line
local multiHpRect   = {}     -- total HP line
local multiMxRect   = {}     -- metal income line
local multiExRect   = {}     -- energy income line
local multiBpRect   = {}     -- build-power line
local multiCostRect = {}     -- COST metal / energy line
local gridCellRects = {}     -- index -> {x1,y1,x2,y2}, parallel to selCells
local gridCols      = 0      -- columns the grid was laid out with

-- resolved (scaled) spacing -- filled by refreshSpacing
local sp = {}

local function scaled(v)
	return mathFloor((v or 0) * uiScale + 0.5)
end

local function refreshSpacing()
	local m = styleDef.metrics or {}
	sp.width      = scaled(m.width)
	sp.height     = scaled(m.height)
	sp.padding    = scaled(m.padding or m.subGap)
	sp.subGap     = scaled(m.subGap)
	sp.subPad     = scaled(m.subPad or 0)
	sp.buildpic   = scaled(m.buildpic)
	sp.stratIcon  = scaled(m.stratIcon)
	sp.stratInset = scaled(m.stratInset or 0)
	sp.barH       = scaled(m.barH)
	sp.margin     = scaled(m.margin)
	-- multi-selection grid metrics
	sp.gridGap     = scaled(m.gridGap or 2)
	sp.gridCell    = scaled(m.gridCell or 46)
	sp.gridStrat   = scaled(m.gridStrat or 14)
	sp.countBadgeH = scaled(m.countBadgeH or 16)
	sp.totalsH     = scaled(m.totalsH or 20)
end

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------

-- Full rebuild: base VBO + the cached buildpic FBO. Use when the textured
-- content or layout changed (selection, resize, re-dock).
local function markDirty()
	if WG.IceUI and WG.IceUI.setDirty then
		WG.IceUI.setDirty()
	end
end

-- Text-only rebuild: re-runs drawPhase + the text layer, but does NOT
-- re-render the buildpic FBO. Use for the live HP / income numbers, which
-- tick several times a second -- re-rendering the FBO that often wastes time
-- and the R2T pass disturbs GL state enough to flicker the text. Falls back to
-- the full markDirty on an older host without setDirtyTextOnly.
local function markDirtyTextOnly()
	if WG.IceUI and WG.IceUI.setDirtyTextOnly then
		WG.IceUI.setDirtyTextOnly()
	else
		markDirty()
	end
end

local function requestRefresh()
	needsRefresh = true
	markDirty()
end

-- Format a resource number with thin spaces: 26000 -> "26 000".
local function groupedNumber(n)
	n = mathFloor((n or 0) + 0.5)
	if n >= 1000 then
		return groupedNumber(mathFloor(n / 1000)) .. " " ..
			string.format("%03d", n % 1000)
	end
	return tostring(n)
end

-- Format a net income rate with an explicit sign: 540 -> "+540", -25 -> "-25".
-- Values are rounded; small magnitudes keep one decimal so a trickle still
-- reads as non-zero.
local function incomeNumber(n)
	n = n or 0
	local sign = n >= 0 and "+" or "-"
	local a = math.abs(n)
	if a < 10 and a > 0 then
		return sign .. string.format("%.1f", a)
	end
	return sign .. groupedNumber(a)
end

-- True if the info panel has anything to show: a single unit, or a non-empty
-- multi-selection.
local function anythingToShow()
	if mode == "multi" then
		return selCells[1] ~= nil
	end
	return shownUnitDefID ~= nil
end

--------------------------------------------------------------------------------
-- data
--------------------------------------------------------------------------------

-- Max units scanned for the live income totals -- spGetUnitResources per unit
-- is not free, so a huge selection is sampled and the result scaled up (the
-- classic gui_info does the same). HP and cost totals scan every unit (cheap).
local MULTI_INCOME_SAMPLE = 50

-- Build the multi-selection data: one cell per distinct unit TYPE, the per-type
-- counts, and the HP / income / build-power / cost totals. Called only when
-- mode == "multi". selCells is rebuilt in place (no per-call garbage).
local function refreshMultiData()
	for i = #selCells, 1, -1 do selCells[i] = nil end
	for k in pairs(selCounts) do selCounts[k] = nil end
	selTotalN, selTotalM, selTotalE = 0, 0, 0

	-- {unitDefID -> count}; one entry per distinct type in the selection
	local counts = spGetSelectedUnitsCounts()
	local n = 0
	for uDefID, c in pairs(counts) do
		-- the counts table can carry a non-numeric "n" key on some engines
		if type(uDefID) == "number" and UnitDefs[uDefID] then
			n = n + 1
			selCells[n]      = uDefID
			selCounts[uDefID] = c
			selTotalN = selTotalN + c
			selTotalM = selTotalM + (unitMetal[uDefID]  or 0) * c
			selTotalE = selTotalE + (unitEnergy[uDefID] or 0) * c
		end
	end
	-- stable order: heaviest-count types first, then by unitDefID
	table.sort(selCells, function(a, b)
		local ca, cb = selCounts[a], selCounts[b]
		if ca ~= cb then return ca > cb end
		return a < b
	end)
end

-- Pick what the panel shows. Priority:
--   1. hover  -> single mode, the unit under the cursor
--   2. >1 unit selected -> multi mode (grid + totals)
--   3. 1 unit selected  -> single mode
-- Sets `mode` and the data the active mode needs.
local function refreshShownUnit()
	needsRefresh = false
	shownUnitID, shownUnitDefID = nil, nil

	-- hover wins: show whatever the cursor is over, even with a selection
	if hoverUnitID then
		local uDefID = spGetUnitDefID(hoverUnitID)
		if uDefID and UnitDefs[uDefID] then
			mode           = "single"
			shownUnitID    = hoverUnitID
			shownUnitDefID = uDefID
			return
		end
	end

	local count = spGetSelectedUnitsCount()
	if count == 0 then
		mode = "single"
		return
	end

	if count > 1 then
		mode = "multi"
		refreshMultiData()
		return
	end

	-- exactly one selected unit -> single mode
	mode = "single"
	local sel = spGetSelectedUnits()
	local uID = sel[1]
	local uDefID = uID and spGetUnitDefID(uID)
	if uDefID and UnitDefs[uDefID] then
		shownUnitID    = uID
		shownUnitDefID = uDefID
	end
end

-- Live multi-selection totals that change frame-to-frame: summed current HP
-- and net metal / energy income. Returned, not cached on a rebuild, because
-- HP and income drift continuously. Scans every selected unit for HP (cheap)
-- and samples up to MULTI_INCOME_SAMPLE units for income (scaled up after).
local function multiLiveTotals()
	local sel = spGetSelectedUnits()
	local n = #sel

	local totalHP = 0
	for i = 1, n do
		local cur = spGetUnitHealth(sel[i])
		if cur then totalHP = totalHP + cur end
	end

	local sample = mathMin(MULTI_INCOME_SAMPLE, n)
	local mMake, mUse, eMake, eUse = 0, 0, 0, 0
	for i = 1, sample do
		local mm, mu, em, eu = spGetUnitResources(sel[i])
		if mm then
			mMake, mUse = mMake + mm, mUse + mu
			eMake, eUse = eMake + em, eUse + eu
		end
	end
	if sample > 0 and sample < n then
		local scale = n / sample
		mMake, mUse = mMake * scale, mUse * scale
		eMake, eUse = eMake * scale, eUse * scale
	end

	return totalHP, mMake - mUse, eMake - eUse
end

-- Static (rebuild-time) multi totals: summed build power of all selected
-- builders. Build speed is constant per unit type, so this needs no live scan.
local function multiBuildPower()
	local bp = 0
	for i = 1, #selCells do
		local uDefID = selCells[i]
		bp = bp + (unitBuildSpd[uDefID] or 0) * (selCounts[uDefID] or 0)
	end
	return bp
end

--------------------------------------------------------------------------------
-- layout
--------------------------------------------------------------------------------

-- Single-unit layout: the two left subcontainers + the buildpic frame, and
-- the content rects inside them. `inner` is the padded main-container area.
local function buildSingleLayout(inner)
	-- right: buildpic frame, a square top-aligned to the inner area
	local picSize = mathMin(sp.buildpic, inner[4] - inner[2])
	picRect[1] = inner[3] - picSize
	picRect[2] = inner[4] - picSize
	picRect[3] = inner[3]
	picRect[4] = inner[4]

	-- the left column (everything left of the buildpic), split into two boxes
	local colLeft  = inner[1]
	local colRight = picRect[1] - sp.subGap
	local colTop   = inner[4]
	local colBot   = inner[2]

	-- cost box (left-bottom): one text line tall, plus its own padding
	local hpH      = scaled(typo.valueSize or 14) + 4
	local costBoxH = hpH + sp.subPad * 2
	costBox[1], costBox[2] = colLeft, colBot
	costBox[3], costBox[4] = colRight, colBot + costBoxH

	-- stat box (left-top): the rest, above the cost box (subGap between them)
	statBox[1], statBox[2] = colLeft, costBox[4] + sp.subGap
	statBox[3], statBox[4] = colRight, colTop

	-- ---- content rects inside the subcontainers (inset by subPad) ----
	local statIn = Layout.inset(statBox, sp.subPad, sp.subPad,
	                                     sp.subPad, sp.subPad)
	local costIn = Layout.inset(costBox, sp.subPad, sp.subPad,
	                                     sp.subPad, sp.subPad)

	-- stat box: name (top), description, health bar, HP value
	local nameH = scaled(typo.titleSize or 16) + 4
	local descH = scaled(typo.descSize  or 12) + 2

	nameRect[1], nameRect[2] = statIn[1], statIn[4] - nameH
	nameRect[3], nameRect[4] = statIn[3], statIn[4]

	descRect[1], descRect[2] = statIn[1], nameRect[2] - descH
	descRect[3], descRect[4] = statIn[3], nameRect[2]

	-- HP value line at the bottom of the stat box
	hpRect[1], hpRect[2] = statIn[1], statIn[2]
	hpRect[3], hpRect[4] = statIn[3], statIn[2] + hpH

	-- health bar between the description and the HP value
	barRect[1], barRect[2] = statIn[1], hpRect[4] + sp.subPad
	barRect[3], barRect[4] = statIn[3], hpRect[4] + sp.subPad + sp.barH

	-- cost box: the metal / energy line
	costRect[1], costRect[2] = costIn[1], costIn[2]
	costRect[3], costRect[4] = costIn[3], costIn[4]
end

-- Multi-selection layout. Three regions in the padded `inner` area:
--   * a bottom-spanning COST totals row
--   * above it, split left/right: a stat-line column and a buildpic grid.
-- The grid sizes its cells to fit every selected type in <= 2 rows, growing
-- the row count only if a type would not otherwise fit.
local function buildMultiLayout(inner)
	-- bottom: the COST totals row spans the full inner width
	multiCostBox[1], multiCostBox[2] = inner[1], inner[2]
	multiCostBox[3], multiCostBox[4] = inner[3], inner[2] + sp.totalsH

	-- the area above the COST row, split into the stat column (left) and the
	-- buildpic grid (right). The grid takes ~55% of the width.
	local upTop = inner[4]
	local upBot = multiCostBox[4] + sp.subGap
	local gridW = mathFloor((inner[3] - inner[1]) * 0.55)

	multiStatBox[1], multiStatBox[2] = inner[1], upBot
	multiStatBox[3], multiStatBox[4] = inner[3] - gridW - sp.subGap, upTop

	multiGridBox[1], multiGridBox[2] = inner[3] - gridW, upBot
	multiGridBox[3], multiGridBox[4] = inner[3], upTop

	-- ---- stat column: five stacked text lines (header + 4 stats) ----
	local statIn = Layout.inset(multiStatBox, sp.subPad, sp.subPad,
	                                          sp.subPad, sp.subPad)
	local lineH = mathFloor((statIn[4] - statIn[2]) / 5)
	local function lineRect(r, idx)   -- idx 0 = top
		r[1], r[3] = statIn[1], statIn[3]
		r[4] = statIn[4] - lineH * idx
		r[2] = r[4] - lineH
	end
	lineRect(multiHdrRect, 0)
	lineRect(multiHpRect,  1)
	lineRect(multiMxRect,  2)
	lineRect(multiExRect,  3)
	lineRect(multiBpRect,  4)

	-- COST totals content rect (inset a touch from the row edges)
	multiCostRect[1] = multiCostBox[1] + sp.subPad
	multiCostRect[2] = multiCostBox[2]
	multiCostRect[3] = multiCostBox[3] - sp.subPad
	multiCostRect[4] = multiCostBox[4]

	-- ---- buildpic grid: fit all cells in as few rows as possible ----
	local gridIn = Layout.inset(multiGridBox, sp.subPad, sp.subPad,
	                                          sp.subPad, sp.subPad)
	local gw = gridIn[3] - gridIn[1]
	local gh = gridIn[4] - gridIn[2]
	local nCells = #selCells

	for i = #gridCellRects, 1, -1 do gridCellRects[i] = nil end
	gridCols = 0
	if nCells == 0 then return end

	-- pick a row count (start at 2) so cells stay square-ish and fit the box
	local gap  = sp.gridGap
	local rows = 2
	local cols, cell
	while true do
		cols = mathCeil(nCells / rows)
		local cw = (gw - gap * (cols - 1)) / cols
		local ch = (gh - gap * (rows - 1)) / rows
		cell = mathFloor(mathMin(cw, ch))
		-- enough vertical room for one more row? then a bigger cell is possible
		if cell >= (gh - gap * rows) / (rows + 1) or rows >= 8 then
			break
		end
		rows = rows + 1
	end
	cell = mathMax(cell, 8)
	gridCols = cols

	-- lay cells left-to-right, top-to-bottom, anchored to the grid's top-left
	for i = 1, nCells do
		local col = (i - 1) % cols
		local row = mathFloor((i - 1) / cols)
		local x1  = gridIn[1] + col * (cell + gap)
		local y2  = gridIn[4] - row * (cell + gap)
		gridCellRects[i] = { x1, y2 - cell, x1 + cell, y2 }
	end
end

-- Compute mainRect (docked right of the order menu) + the mode's sub-rects.
local function buildLayout()
	if not anythingToShow() then
		mainRect[1] = nil
		return
	end

	-- dock: sit to the RIGHT of the IceUI commands menu, bottom-aligned to it.
	-- Fall back to the screen's bottom-left if the order menu is not present.
	local omRect = WG.IceUIOrderMenu and WG.IceUIOrderMenu.rect
	local left, bottom
	if omRect and omRect[1] then
		left   = omRect[3] + sp.margin
		bottom = omRect[2]
	else
		left   = 0
		bottom = 0
	end

	mainRect[1] = left
	mainRect[2] = bottom
	mainRect[3] = left + sp.width
	mainRect[4] = bottom + sp.height

	-- main container padding (inset from the panel edge to its content) --
	-- styleDef.metrics.padding, kept equal to mainContainer.padding elsewhere
	local pad = sp.padding
	local inner = Layout.inset(mainRect, pad, pad, pad, pad)

	if mode == "multi" then
		buildMultiLayout(inner)
	else
		buildSingleLayout(inner)
	end
end

--------------------------------------------------------------------------------
-- drawing
--------------------------------------------------------------------------------

-- reusable tables for texturePhase, mutated in place each frame -- a fresh
-- table per frame here is per-second garbage the profiler flags.
local scratchRect     = { 0, 0, 0, 0 }   -- health-bar fill + strat icon rect
local scratchBarColor = { 0, 0, 0, 1 }   -- health-bar fill colour

-- Health-bar fill colour: green -> yellow -> red as health drops.
local function healthColor(frac)
	frac = mathMax(0, mathMin(1, frac))
	if frac > 0.5 then
		-- green..yellow
		local t = (frac - 0.5) * 2
		return 1 - t * 0.6, 0.85, 0.25
	else
		-- yellow..red
		local t = frac * 2
		return 0.90, 0.20 + t * 0.65, 0.20
	end
end

-- Pixel size of the stat-row icon: a square pinned to the line's left edge.
-- The text after it is indented past the icon (see ICON_TEXT_GAP).
local STAT_ICON_FRAC = 0.78   -- icon side as a fraction of the line height
local ICON_TEXT_GAP  = 4      -- px between the icon and its text

-- Draw one stat line's TEXT: a value at `rect`, indented past the icon slot on
-- the left. The icon itself is drawn in the texture phase. `valueColor` colours
-- the value; the (optional) trailing `unit` is dim.
-- noFit: these are LIVE numbers whose string length changes tick to tick (e.g.
-- "+540" -> "+1040"); auto-fit would re-measure and shrink the font as the
-- length crosses the column width, making the text jump. A fixed size is
-- correct -- the column is sized for the values.
local function multiStatLabel(rect, value, valueColor, unit)
	local lineH  = rect[4] - rect[2]
	local indent = mathFloor(lineH * STAT_ICON_FRAC) + ICON_TEXT_GAP
	local str = value
	if unit then str = str .. "  " .. unit end
	panel:label(str, rect, {
		color = valueColor, size = typo.labelSize,
		font = 2, align = "vo", insetL = indent, keepCase = true, noFit = true,
	})
end

-- Draw an icon-prefixed value inside `rect` starting at `x` (so two readouts
-- can share one line). Returns nothing; the icon is drawn in the texture phase
-- -- this only queues the text, indented past the icon slot. noFit: see
-- multiStatLabel -- these are live numbers, a fixed size avoids font jumping.
local function iconValueLabel(rect, x, value, valueColor)
	local lineH  = rect[4] - rect[2]
	local indent = mathFloor(lineH * STAT_ICON_FRAC) + ICON_TEXT_GAP
	panel:label(value, { x, rect[2], rect[3], rect[4] }, {
		color = valueColor, size = typo.labelSize,
		font = 2, align = "vo", insetL = indent, keepCase = true, noFit = true,
	})
end

-- Single-unit draw: name, description, health bar, HP value, costs + buildpic.
local function drawSingle()
	local uDefID = shownUnitDefID

	-- main container, the two left subcontainers, and the buildpic frame
	panel:box("mainContainer", mainRect)
	panel:box("subContainer", statBox)
	panel:box("subContainer", costBox)
	panel:box("picFrame", picRect)

	-- unit name (title), left-aligned
	panel:label(unitName[uDefID] or "?", nameRect, {
		color = typo.titleColor, size = typo.titleSize,
		font = 2, align = "vo",
	})

	-- description line, left-aligned (auto-fits to the column width)
	local desc = unitDesc[uDefID]
	if desc and desc ~= "" then
		panel:label(desc, descRect, {
			color = typo.descColor, size = typo.descSize,
			font = 1, align = "vo", keepCase = true,
		})
	end

	-- health bar: a dark track; the live fill is drawn in texturePhase
	panel:box("barTrack", barRect)

	-- HP value line
	local maxHP = unitMaxHP[uDefID] or 0
	local hp = maxHP
	if shownUnitID then
		local cur = spGetUnitHealth(shownUnitID)
		if cur then hp = cur end
	end
	-- noFit: the HP number changes every tick -- a fixed size avoids the font
	-- jumping when the string length crosses the line width.
	panel:label("HP " .. groupedNumber(hp) .. " / " .. groupedNumber(maxHP),
		hpRect, {
			color = typo.valueColor, size = typo.labelSize,
			font = 2, align = "vo", noFit = true,
		})

	-- metal / energy cost line: an icon + the value for each, split L/R.
	-- The cost icons themselves are drawn in texturesCachedPhase.
	local midX = (costRect[1] + costRect[3]) * 0.5
	iconValueLabel(costRect, costRect[1], groupedNumber(unitMetal[uDefID]),
		typo.metalColor)
	iconValueLabel(costRect, midX, groupedNumber(unitEnergy[uDefID]),
		typo.energyColor)
end

-- Multi-selection draw: the stat column (header + 4 stat lines), the COST
-- totals row, and the buildpic grid cells + their count badges. Buildpics and
-- stat icons are drawn in texturePhase; this queues only boxes + text.
local function drawMulti()
	panel:box("mainContainer", mainRect)
	panel:box("subContainer", multiStatBox)
	panel:box("subContainer", multiGridBox)
	panel:box("subContainer", multiCostBox)

	-- header: "N UNITS"
	panel:label(selTotalN .. " UNITS", multiHdrRect, {
		color = typo.countColor, size = typo.descSize,
		font = 2, align = "vo",
	})

	-- live totals (HP + income) -- read every frame; the cached text is only
	-- rebuilt on the throttled refresh in widget:Update (see lastShownHP).
	local totalHP, mInc, eInc = multiLiveTotals()
	multiStatLabel(multiHpRect, groupedNumber(totalHP), typo.valueColor)
	multiStatLabel(multiMxRect, incomeNumber(mInc), typo.metalColor,  "/s")
	multiStatLabel(multiExRect, incomeNumber(eInc), typo.energyColor, "/s")
	multiStatLabel(multiBpRect, groupedNumber(multiBuildPower()), typo.valueColor)

	-- COST totals row: a metal icon + total, then an energy icon + total.
	-- The cost icons are drawn in texturesCachedPhase.
	local costMid = (multiCostRect[1] + multiCostRect[3]) * 0.5
	iconValueLabel(multiCostRect, multiCostRect[1], groupedNumber(selTotalM),
		typo.metalColor)
	iconValueLabel(multiCostRect, costMid, groupedNumber(selTotalE),
		typo.energyColor)

	-- grid: a framed cell per unit type + a count badge in the top-left corner
	-- (matches the classic info panel). The buildpic itself is a texture,
	-- drawn in texturePhase.
	for i = 1, #gridCellRects do
		local r = gridCellRects[i]
		panel:box("gridCell", r)
		local cnt = selCounts[selCells[i]] or 0
		if cnt > 1 then
			panel:_cornerBadge(r, tostring(cnt), "countBadge", "tl")
		end
	end
end

-- draw phase: queue the panel's rectangles (runs only on a rebuild)
local function drawPhase()
	if needsRefresh then
		refreshShownUnit()
		buildLayout()
	end

	local mx, my, lmb = spGetMouseState()
	panel:begin(mx, my, lmb)

	if not anythingToShow() or not mainRect[1] then
		panel:finish()
		return
	end

	if mode == "multi" then
		drawMulti()
	else
		drawSingle()
	end

	panel:finish()
end

-- Draw a stat-row icon: a square pinned to x `atX` (default: the line's left
-- edge), vertically centred on `lineRect`, sized to match the indent the label
-- helpers reserve for it. Lets two icons share one line (metal + energy cost).
local function drawStatIcon(lineRect, texture, atX)
	local lineH = lineRect[4] - lineRect[2]
	local isize = mathFloor(lineH * STAT_ICON_FRAC)
	local x = atX or lineRect[1]
	local r = scratchRect
	local cy = (lineRect[2] + lineRect[4]) * 0.5
	r[1] = x
	r[2] = mathFloor(cy - isize * 0.5)
	r[3] = x + isize
	r[4] = r[2] + isize
	WG.IceUI.drawTexture(r, texture)
end

-- The STATIC textured content -- buildpics, strat icons and (multi) stat-row
-- icons. The host renders this ONCE into an offscreen FBO texture (at 2x for
-- sharpness) on a rebuild, then blits that single texture every frame -- the
-- same trick the build menu uses. ~30 loose buildpic draws become one TexRect,
-- and the 2x supersample makes a small buildpic crisp instead of soft.
-- Buildpics use `sharp=true` (LOD-bias shader).
local function texturesCachedPhase()
	if not mainRect[1] or not anythingToShow() then return end

	local r = scratchRect

	if mode == "multi" then
		-- stat-row icons, left of the HP / metal / energy / build-power lines.
		-- HP/income/build use the plain group/stat icons; the COST row uses the
		-- dedicated cost icons (metal-cost / energy-cost).
		if multiHpRect[1] then drawStatIcon(multiHpRect, ICON_HEALTH) end
		if multiMxRect[1] then drawStatIcon(multiMxRect, ICON_METALCOST)  end
		if multiExRect[1] then drawStatIcon(multiExRect, ICON_ENERGYCOST) end
		if multiBpRect[1] then drawStatIcon(multiBpRect, ICON_BUILD)  end
		if multiCostRect[1] then
			local costMid = (multiCostRect[1] + multiCostRect[3]) * 0.5
			drawStatIcon(multiCostRect, ICON_METALCOST, multiCostRect[1])
			drawStatIcon(multiCostRect, ICON_ENERGYCOST, costMid)
		end

		-- buildpic per grid cell, sharp, inset 1px inside the cell's border
		local strat = sp.gridStrat
		for i = 1, #gridCellRects do
			local cr = gridCellRects[i]
			local uDefID = selCells[i]
			r[1], r[2], r[3], r[4] = cr[1] + 1, cr[2] + 1, cr[3] - 1, cr[4] - 1
			WG.IceUI.drawTexture(r, unitBuildpic[uDefID], nil, nil, nil, true)

			-- strat icon, bottom-right of the cell (count badge is top-left)
			local si = unitStratIcon[uDefID]
			if si and strat > 0 then
				r[3] = cr[3] - 1
				r[4] = cr[2] + 1 + strat
				r[1] = r[3] - strat
				r[2] = cr[2] + 1
				WG.IceUI.drawTexture(r, si)
			end
		end
	else
		-- single mode: the one buildpic + its strat icon
		local uDefID = shownUnitDefID
		if not uDefID then return end
		r[1], r[2], r[3], r[4] = picRect[1] + 1, picRect[2] + 1,
		                         picRect[3] - 1, picRect[4] - 1
		WG.IceUI.drawTexture(r, unitBuildpic[uDefID], nil, nil, nil, true)

		local si = unitStratIcon[uDefID]
		if si and sp.stratIcon > 0 then
			local inset = sp.stratInset
			r[1] = picRect[1] + inset
			r[2] = picRect[2] + inset
			r[3] = picRect[1] + inset + sp.stratIcon
			r[4] = picRect[2] + inset + sp.stratIcon
			WG.IceUI.drawTexture(r, si)
		end

		-- metal / energy cost icons on the cost line (text drawn in drawSingle)
		if costRect[1] then
			local midX = (costRect[1] + costRect[3]) * 0.5
			drawStatIcon(costRect, ICON_METALCOST, costRect[1])
			drawStatIcon(costRect, ICON_ENERGYCOST, midX)
		end
	end
end

-- The consumer's bounding rect for the cached texture -- the host renders
-- texturesCachedPhase into an FBO sized to this. nil when hidden.
local function textureRect()
	if not mainRect[1] or not anythingToShow() then return nil end
	return mainRect
end

-- LIVE textured content drawn every frame ON TOP of the cached texture. Only
-- the single-unit health-bar fill animates; the multi panel has nothing live.
local function texturePhase()
	if not mainRect[1] or not anythingToShow() then return end
	if mode == "multi" then return end

	-- single mode: live health-bar fill on top of the track
	if shownUnitID and barRect[1] then
		local cur, maxHP = spGetUnitHealth(shownUnitID)
		if cur and maxHP and maxHP > 0 then
			local frac = mathMax(0, mathMin(1, cur / maxHP))
			local cr, cg, cb = healthColor(frac)
			-- inset 1px so the fill sits inside the track
			local r = scratchRect
			local x1 = barRect[1] + 1
			local y1 = barRect[2] + 1
			local y2 = barRect[4] - 1
			local x2 = x1 + (barRect[3] - barRect[1] - 2) * frac
			r[1], r[2], r[3], r[4] = x1, y1, x2, y2
			scratchBarColor[1] = cr
			scratchBarColor[2] = cg
			scratchBarColor[3] = cb
			WG.IceUI.drawRect(r, scratchBarColor)
		end
	end
end

-- text phase: draw the queued labels
local function textPhase()
	if panel then
		panel:drawText()
	end
end

--------------------------------------------------------------------------------
-- callins
--------------------------------------------------------------------------------

local function tryRegister()
	if registered or not WG.IceUI then
		return
	end
	WG.IceUI.registerDraw("iceui_info", {
		draw           = drawPhase,
		text           = textPhase,
		texturesCached = texturesCachedPhase,  -- buildpics: cached into an FBO
		textureRect    = textureRect,
		textures       = texturePhase,         -- live: the health-bar fill
	})
	registered = true
end

function widget:Initialize()
	panel = IceUI.newPanel(styleDef)
	refreshSpacing()
	refreshShownUnit()
	buildLayout()
	tryRegister()

	-- this panel replaces the engine's hover/selection tooltip, so suppress it
	-- (the plain "Pos / Terrain type / Speeds" text) -- same as the classic
	-- gui_info. SetDrawSelectionInfo(false) also hides the engine's selected-
	-- units counter. Both are restored in :Shutdown.
	Spring.SetDrawSelectionInfo(false)
	Spring.SendCommands("tooltip 0")
end

function widget:Shutdown()
	if WG.IceUI then
		WG.IceUI.unregisterDraw("iceui_info")
	end

	-- restore the engine tooltip + selection counter. NOTE: if the classic
	-- gui_info is also enabled it keeps its own "tooltip 0" -- harmless, it
	-- re-asserts the same state; whichever info widget shuts down last wins,
	-- and gui_info re-applies "tooltip 0" every Initialize anyway.
	Spring.SetDrawSelectionInfo(true)
	Spring.SendCommands("tooltip 1")
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	uiScale  = Spring.GetConfigFloat("ui_scale", 1)
	refreshSpacing()
	buildLayout()
	markDirty()
end

-- last order-menu dock anchor we laid out against; detects when it moves
local lastDockX, lastDockY
-- last HP value baked into the (cached) text; a change forces a rebuild so the
-- HP NUMBER stays current. The health BAR fill is live every frame anyway.
-- The check is THROTTLED (HP_REFRESH s) -- in combat HP changes every frame,
-- and an un-throttled rebuild per HP point rebuilt the whole base VBO + re-ran
-- drawPhase (its opts tables + string concats) every frame = lots of garbage.
local lastShownHP
local hpNextCheck   = 0
local HP_REFRESH    = 0.15   -- seconds between HP-number rebuilds (~6/sec)

-- Refresh hoverUnitID from a screen-ray at the cursor. Returns true when the
-- hovered unit CHANGED (so the caller can request a panel rebuild). Cheap: a
-- single TraceScreenRay, no allocation. Skipped while the GUI is hidden.
local function refreshHover()
	local newHover
	if not spIsGUIHidden() then
		local mx, my = spGetMouseState()
		local hType, hData = spTraceScreenRay(mx, my)
		if hType == 'unit' then
			newHover = hData
		end
	end
	if newHover ~= hoverUnitID then
		hoverUnitID = newHover
		return true
	end
	return false
end

function widget:Update(dt)
	if not registered then
		tryRegister()
	end

	-- hover: if the unit under the cursor changed, rebuild so the panel shows
	-- it (or falls back to the selection when the cursor leaves a unit)
	if refreshHover() then
		requestRefresh()
	end

	-- self-heal: while a refresh is pending keep asking for a rebuild
	if needsRefresh then
		markDirty()
	end

	-- re-dock if the order menu (which we sit beside) moved or resized
	local omRect = WG.IceUIOrderMenu and WG.IceUIOrderMenu.rect
	local dx = omRect and omRect[3] or nil
	local dy = omRect and omRect[2] or nil
	if dx ~= lastDockX or dy ~= lastDockY then
		lastDockX, lastDockY = dx, dy
		buildLayout()
		markDirty()
	end

	-- Live-value refresh, throttled to HP_REFRESH seconds:
	--   single mode -- rebuild the cached text only when the HP NUMBER changed
	--                  (the health BAR fill is live every frame regardless).
	--   multi mode  -- the HP / income totals drift continuously, so just
	--                  rebuild on every tick while a multi-selection is shown.
	-- Both use markDirtyTextOnly: only the NUMBERS change, the buildpics do
	-- not, so the cached buildpic FBO must NOT be re-rendered here (doing so
	-- several times a second flickers the text -- the R2T pass disturbs GL).
	local now = os.clock()
	if now >= hpNextCheck then
		hpNextCheck = now + HP_REFRESH
		if mode == "multi" then
			if anythingToShow() then
				markDirtyTextOnly()
			end
		elseif shownUnitID then
			local cur = spGetUnitHealth(shownUnitID)
			local hp = cur and mathFloor(cur + 0.5) or nil
			if hp ~= lastShownHP then
				lastShownHP = hp
				markDirtyTextOnly()
			end
		elseif lastShownHP ~= nil then
			lastShownHP = nil
		end
	end
end

function widget:SelectionChanged(sel)
	requestRefresh()
end
