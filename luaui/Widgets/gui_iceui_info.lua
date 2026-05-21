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

local spGetSelectedUnits      = Spring.GetSelectedUnits
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetUnitDefID          = Spring.GetUnitDefID
local spGetUnitHealth         = Spring.GetUnitHealth
local spGetMouseState         = Spring.GetMouseState
local spGetViewGeometry       = Spring.GetViewGeometry

local mathFloor = math.floor
local mathMax   = math.max
local mathMin   = math.min

--------------------------------------------------------------------------------
-- static unit data -- precomputed once
--------------------------------------------------------------------------------

local unitName      = {}   -- unitDefID -> display name
local unitDesc      = {}   -- unitDefID -> description / tooltip text
local unitMetal     = {}   -- unitDefID -> metal cost
local unitEnergy    = {}   -- unitDefID -> energy cost
local unitMaxHP     = {}   -- unitDefID -> max health
local unitBuildpic  = {}   -- unitDefID -> "#"..unitDefID engine texture
local unitStratIcon = {}   -- unitDefID -> ":l:icons/<file>" strategic icon, or nil

local iconTypeBitmap = VFS.Include("gamedata/icontypes.lua")

for unitDefID, ud in pairs(UnitDefs) do
	unitName[unitDefID]     = ud.translatedHumanName or ud.humanName or ud.name
	unitDesc[unitDefID]     = ud.translatedTooltip or ud.tooltip or ""
	unitMetal[unitDefID]    = ud.metalCost or 0
	unitEnergy[unitDefID]   = ud.energyCost or 0
	unitMaxHP[unitDefID]    = ud.health or 0
	unitBuildpic[unitDefID] = "#" .. unitDefID
	local it = ud.iconType and iconTypeBitmap[ud.iconType]
	if it and it.bitmap then
		unitStratIcon[unitDefID] = ":l:" .. it.bitmap
	end
end

--------------------------------------------------------------------------------
-- widget state
--------------------------------------------------------------------------------

local panel                  -- IceUI Panel

local vsx, vsy   = spGetViewGeometry()
local uiScale    = Spring.GetConfigFloat("ui_scale", 1)

local registered   = false
local needsRefresh = true    -- recompute the shown unit on the next drawPhase

-- the unit currently shown (or nil for none)
local shownUnitID    = nil
local shownUnitDefID = nil

-- layout rects (recomputed by buildLayout)
local mainRect   = {}
-- the three subcontainers
local statBox    = {}        -- left-top  : name + desc + health
local costBox    = {}        -- left-bot  : metal / energy
local picRect    = {}        -- right     : buildpic frame
-- content rects inside the subcontainers
local nameRect   = {}        -- unit name line
local descRect   = {}        -- description line
local barRect    = {}        -- health bar
local hpRect     = {}        -- "HP" value line
local costRect   = {}        -- metal / energy cost line

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
end

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------

local function markDirty()
	if WG.IceUI and WG.IceUI.setDirty then
		WG.IceUI.setDirty()
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

-- True if the info panel has a unit to show.
local function anythingToShow()
	return shownUnitDefID ~= nil
end

--------------------------------------------------------------------------------
-- data
--------------------------------------------------------------------------------

-- Pick the unit to display: the single selected unit, or the first of a
-- homogeneous selection. nil when nothing useful can be shown.
local function refreshShownUnit()
	needsRefresh = false
	shownUnitID, shownUnitDefID = nil, nil

	local sel = spGetSelectedUnits()
	local n = #sel
	if n == 0 then return end

	-- show the first unit; for a mixed selection still show the first one
	local uID = sel[1]
	local uDefID = spGetUnitDefID(uID)
	if uDefID and UnitDefs[uDefID] then
		shownUnitID    = uID
		shownUnitDefID = uDefID
	end
end

--------------------------------------------------------------------------------
-- layout
--------------------------------------------------------------------------------

-- Compute mainRect (docked right of the order menu) + the sub-rects.
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

	-- ---- three subcontainers ----
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
	panel:label("HP " .. groupedNumber(hp) .. " / " .. groupedNumber(maxHP),
		hpRect, {
			color = typo.valueColor, size = typo.labelSize,
			font = 2, align = "vo",
		})

	-- metal / energy cost line
	panel:label("Metal " .. groupedNumber(unitMetal[uDefID]), costRect, {
		color = typo.metalColor, size = typo.labelSize,
		font = 2, align = "vo",
	})
	-- energy after the metal text -- a second label, indented to mid-column
	local midX = (costRect[1] + costRect[3]) * 0.5
	panel:label("Energy " .. groupedNumber(unitEnergy[uDefID]),
		{ midX, costRect[2], costRect[3], costRect[4] }, {
			color = typo.energyColor, size = typo.labelSize,
			font = 2, align = "vo",
		})

	panel:finish()
end

-- texture phase: the buildpic, strat icon and the live health-bar fill
local function texturePhase()
	if not mainRect[1] or not anythingToShow() then return end
	local uDefID = shownUnitDefID

	-- buildpic, sharp (LOD-bias shader), inset 1px inside the frame border
	local r = scratchRect
	r[1], r[2], r[3], r[4] = picRect[1] + 1, picRect[2] + 1,
	                         picRect[3] - 1, picRect[4] - 1
	WG.IceUI.drawTexture(r, unitBuildpic[uDefID], nil, nil, nil, true)

	-- strategic icon, bottom-left of the buildpic
	local si = unitStratIcon[uDefID]
	if si and sp.stratIcon > 0 then
		local inset = sp.stratInset
		r[1] = picRect[1] + inset
		r[2] = picRect[2] + inset
		r[3] = picRect[1] + inset + sp.stratIcon
		r[4] = picRect[2] + inset + sp.stratIcon
		WG.IceUI.drawTexture(r, si)
	end

	-- live health-bar fill on top of the track
	if shownUnitID and barRect[1] then
		local cur, maxHP = spGetUnitHealth(shownUnitID)
		if cur and maxHP and maxHP > 0 then
			local frac = mathMax(0, mathMin(1, cur / maxHP))
			local cr, cg, cb = healthColor(frac)
			-- inset 1px so the fill sits inside the track
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
		draw     = drawPhase,
		text     = textPhase,
		textures = texturePhase,
	})
	registered = true
end

function widget:Initialize()
	panel = IceUI.newPanel(styleDef)
	refreshSpacing()
	refreshShownUnit()
	buildLayout()
	tryRegister()
end

function widget:Shutdown()
	if WG.IceUI then
		WG.IceUI.unregisterDraw("iceui_info")
	end
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

function widget:Update(dt)
	if not registered then
		tryRegister()
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

	-- HP number: rebuild the cached text only when the displayed HP changed,
	-- and at most every HP_REFRESH seconds (the live health BAR is unaffected).
	local now = os.clock()
	if now >= hpNextCheck then
		hpNextCheck = now + HP_REFRESH
		if shownUnitID then
			local cur = spGetUnitHealth(shownUnitID)
			local hp = cur and mathFloor(cur + 0.5) or nil
			if hp ~= lastShownHP then
				lastShownHP = hp
				markDirty()
			end
		elseif lastShownHP ~= nil then
			lastShownHP = nil
		end
	end
end

function widget:SelectionChanged(sel)
	requestRefresh()
end
