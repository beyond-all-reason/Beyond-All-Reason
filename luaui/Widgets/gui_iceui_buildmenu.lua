local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Build menu (IceUI)",
		desc    = "Build/construction menu rebuilt on the IceUI-GL4 framework.",
		author  = "BAR team",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		-- below the FlowUI menus so it receives clicks on overlapping cells
		-- first (see gui_iceui_ordermenu for the same reasoning).
		layer   = -10,
		enabled = false,  -- enable from the widget list; disable the classic build menu to swap
	}
end

--------------------------------------------------------------------------------
-- IceUI build menu
--------------------------------------------------------------------------------
-- The construction menu, drawn through IceUI-GL4. Shows the units the current
-- selection can build, grouped into four category tabs, in a paged grid.
--
-- Data sourcing mirrors the classic gui_buildmenu:
--   * Spring.GetActiveCmdDescs() -> commands whose action starts "buildunit_"
--   * the unitDefID is -cmd.id
--   * a click issues the build order via Spring.SetActiveCommand
-- Category of each unit comes from configs/iceui_buildmenu_categories.lua.
--
-- Buildpics are drawn as engine textures ('#'..unitDefID) via the IceUI host's
-- texture phase -- no atlas, so no extra VRAM.
--
-- Steps still to come: paging (next/prev), the top BUILD MENU / BLUEPRINTS
-- tabs and CLEAR QUEUE button. The layout already reserves room for paging.
--------------------------------------------------------------------------------

local IceUI    = VFS.Include("luaui/Include/IceUI/iceui.lua", nil, VFS.RAW_FIRST)
local Layout   = IceUI.Layout
local styleDef = VFS.Include("luaui/configs/iceui_styles.lua", nil, VFS.RAW_FIRST).buildmenu
local catDef   = VFS.Include("luaui/configs/iceui_buildmenu_categories.lua", nil, VFS.RAW_FIRST)

--------------------------------------------------------------------------------
-- Spring API locals
--------------------------------------------------------------------------------

local spGetActiveCmdDescs  = Spring.GetActiveCmdDescs
local spGetCmdDescIndex    = Spring.GetCmdDescIndex
local spSetActiveCommand   = Spring.SetActiveCommand
local spGetModKeyState     = Spring.GetModKeyState
local spGetMouseState      = Spring.GetMouseState
local spGetViewGeometry    = Spring.GetViewGeometry
local spGetSelectedUnits   = Spring.GetSelectedUnits
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetSpectatingState = Spring.GetSpectatingState
local spGetUnitIsBuilding  = Spring.GetUnitIsBuilding
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitDefID       = Spring.GetUnitDefID
local spPlaySoundFile      = Spring.PlaySoundFile
local spI18N               = Spring.I18N

local mathFloor = math.floor
local mathCeil  = math.ceil

--------------------------------------------------------------------------------
-- unit data (costs, name) -- precomputed once
--------------------------------------------------------------------------------

local unitMetalCost  = {}
local unitEnergyCost = {}
local unitHumanName  = {}
local unitTooltip    = {}   -- unitDefID -> description text shown in the tooltip
local unitBuildpic   = {}   -- unitDefID -> "#"..unitDefID, built once (no per-frame string garbage)
local unitStratIcon  = {}   -- unitDefID -> ":l:icons/<file>" strategic icon, or nil

-- the strategic icon bitmap per icon-type name (gamedata/icontypes.lua)
local iconTypeBitmap = VFS.Include("gamedata/icontypes.lua")

for unitDefID, ud in pairs(UnitDefs) do
	unitMetalCost[unitDefID]  = ud.metalCost
	unitEnergyCost[unitDefID] = ud.energyCost
	unitHumanName[unitDefID]  = ud.translatedHumanName or ud.humanName or ud.name
	unitTooltip[unitDefID]    = ud.translatedTooltip or ud.tooltip
	unitBuildpic[unitDefID]   = "#" .. unitDefID
	-- strategic (radar/minimap) icon: iconType -> icontypes bitmap. ':l:' loads
	-- it as a plain file texture.
	local it = ud.iconType and iconTypeBitmap[ud.iconType]
	if it and it.bitmap then
		unitStratIcon[unitDefID] = ":l:" .. it.bitmap
	end
end

local categoryOf  = catDef.categoryOf
local groupIconOf = catDef.groupIconOf

--------------------------------------------------------------------------------
-- widget state
--------------------------------------------------------------------------------

local soundButton = 'LuaUI/Sounds/buildbar_waypoint.wav'

local panel                  -- IceUI Panel

-- buildable commands. Each entry: { cmdID, unitDefID }.
--   catCommands[c]  -- split per category (filtered views)
--   allCommands     -- every buildable command (the unfiltered view)
local catCommands = { {}, {}, {} ,{} }
local allCommands = {}
-- The active category FILTER. nil = no filter, show everything. The category
-- tabs are toggle filters: click selects, click again clears.
local activeCat   = nil
local currentPage = 1        -- current page within the shown command list
local pageCount   = 1

-- layout rects (recomputed by buildLayout)
local mainRect   = {}
local tabRects   = {}        -- one rect per category tab
local cellRects  = {}        -- build-cell rects for the current page
local actionRects = {}       -- bottom action bar: 4 rects (guard/prio/queue/clear)
local nextPageRect           -- the last grid cell, when it is the Next-page btn

-- per-cell command for the current page (parallel to cellRects)
local pageCommands = {}

-- reusable tables, mutated in place each call -- avoids allocating small
-- tables per frame (the profiler counts that as per-second garbage).
--   scratchIconRect  : the loose icon draws (group icons, tab icons)
--   scratchHoverColor: the hover-brighten {r,g,b,a} tint
local scratchIconRect  = { 0, 0, 0, 0 }
local scratchHoverColor = { 0, 0, 0, 1 }

local vsx, vsy   = spGetViewGeometry()
local uiScale    = Spring.GetConfigFloat("ui_scale", 1)
local isSpectating = spGetSpectatingState()

local needsRefresh = true    -- recompute buildable commands on next drawPhase
local registered   = false

--------------------------------------------------------------------------------
-- dirty / refresh control  (declared early so closures capture them)
--------------------------------------------------------------------------------

local function markDirty()
	if WG.IceUI and WG.IceUI.setDirty then
		WG.IceUI.setDirty()
	end
end

local refreshAt              -- os.clock time a throttled refresh is due, or nil
local REFRESH_DELAY = 0.1    -- min seconds between throttled refreshes

-- Request a command refresh.
--   immediate = true  : refresh on the very next drawPhase (selection / click)
--   immediate = false : throttled -- coalesce bursts of CommandsChanged events
--                       into one refresh every REFRESH_DELAY.
-- CommandsChanged fires constantly during play; an un-throttled rebuild per
-- event rebuilt the shared base VBO every frame (measured as base=16-32us).
local function requestRefresh(immediate)
	if immediate then
		needsRefresh = true
		refreshAt = nil
		markDirty()
	elseif not needsRefresh and not refreshAt then
		refreshAt = os.clock() + REFRESH_DELAY
	end
end

--------------------------------------------------------------------------------
-- category labels
--------------------------------------------------------------------------------

-- Short label overrides for the category tabs. The i18n name is used unless
-- a short form is given here (e.g. "Economy" -> "ECO" so the tab stays compact).
-- Tab labels are upper-cased automatically by panel:label.
local categoryShortLabel = {
	econ = "Eco",
}

local categoryLabel = {}
for i, key in ipairs(catDef.categoryKeys) do
	categoryLabel[i] = categoryShortLabel[key]
		or spI18N("ui.buildMenu.category_" .. key) or key
end
-- hotkeys shown on the category tabs (Z X C V, matching the classic menu)
local categoryHotkey = { "Z", "X", "C", "V" }
-- group icon shown on each category tab (Eco/Combat/Utility/Build)
local categoryIcon = {
	"LuaUI/Images/groupicons/energy.png",
	"LuaUI/Images/groupicons/weapon.png",
	"LuaUI/Images/groupicons/util.png",
	"LuaUI/Images/groupicons/builder.png",
}

--------------------------------------------------------------------------------
-- command refresh
--------------------------------------------------------------------------------

-- The three factory ICON_MODE toggle commands the bottom action bar exposes,
-- when a unit with them is selected. Each entry: { cmdID, on }. nil otherwise.
local toggleCmds = { guard = nil, priority = nil, queueMode = nil }

-- maps a command action -> the toggleCmds key it fills
local TOGGLE_ACTIONS = {
	factoryguard     = "guard",
	priority         = "priority",
	factoryqueuemode = "queueMode",
}

-- The factory "Stop Production" command (action "stopproduction"), when a
-- factory is selected. Clearing the queue = issuing this command -- the engine
-- gadget cmd_factory_stop_production does the full clear (incl. WAIT handling).
-- Holds the cmdID, or nil. This is what "Clear Queue" triggers.
local stopProductionCmdID = nil

-- Rebuild catCommands + allCommands from the active command descriptions.
local function refreshCommands()
	needsRefresh = false

	for c = 1, 4 do
		local list = catCommands[c]
		for i = #list, 1, -1 do list[i] = nil end
	end
	for i = #allCommands, 1, -1 do allCommands[i] = nil end
	toggleCmds.guard, toggleCmds.priority, toggleCmds.queueMode = nil, nil, nil
	stopProductionCmdID = nil

	for _, cmd in ipairs(spGetActiveCmdDescs()) do
		if type(cmd) == "table" and not cmd.disabled and cmd.action then
			if cmd.action:find("buildunit_", 1, true) == 1 then
				local unitDefID = -cmd.id
				local cat = categoryOf[unitDefID] or catDef.CAT_UTILITY
				-- params[1] = how many of this unit are queued (factories);
				-- nil/0 for a builder with no queue. CommandsChanged triggers a
				-- refresh whenever the queue changes, so this stays current.
				local queued = cmd.params and tonumber(cmd.params[1]) or 0
				local entry = { cmdID = cmd.id, unitDefID = unitDefID,
				                queued = queued }
				catCommands[cat][#catCommands[cat] + 1] = entry
				allCommands[#allCommands + 1] = entry
			elseif cmd.action == "stopproduction" then
				stopProductionCmdID = cmd.id   -- the Clear Queue command
			else
				-- the bottom-bar ICON_MODE toggles -- params[1] = 0 off / 1 on
				local key = TOGGLE_ACTIONS[cmd.action]
				if key then
					toggleCmds[key] = {
						cmdID = cmd.id,
						on    = (cmd.params and tonumber(cmd.params[1]) or 0) == 1,
					}
				end
			end
		end
	end
end

-- The command list currently shown: the active category, or all when no
-- filter is selected.
local function shownCommands()
	if activeCat then
		return catCommands[activeCat]
	end
	return allCommands
end

--------------------------------------------------------------------------------
-- layout
--------------------------------------------------------------------------------

local sp = {}   -- scaled spacing values, refreshed from the stylesheet

local function refreshSpacing()
	uiScale = Spring.GetConfigFloat("ui_scale", 1)
	local function scaled(v) return mathFloor((v or 0) * uiScale + 0.5) end

	local m       = panel:style("metrics")
	local mainSty = panel:style("mainContainer")
	local subSty  = panel:style("subContainer")

	sp.buttonGap = scaled(m.buttonGap)
	sp.subGap    = scaled(m.subGap)
	sp.cellSize  = scaled(m.cellSize)
	sp.gridCols  = m.gridCols or 5
	sp.gridRows  = m.gridRows or 6
	sp.tabH      = scaled(m.tabH)
	sp.tabIcon   = scaled(m.tabIcon)
	sp.actionBarH = scaled(m.actionBarH)
	sp.margin     = scaled(m.margin)
	sp.groupIcon  = scaled(m.groupIcon)
	sp.stratIcon  = scaled(m.stratIcon or 0)
	sp.stratInset = scaled(m.stratInset or 0)

	local ml, mb, mr, mt = IceUI.Style.padding(mainSty)
	sp.mainPadL, sp.mainPadB = scaled(ml), scaled(mb)
	sp.mainPadR, sp.mainPadT = scaled(mr), scaled(mt)

	local sl, sb, sr, st = IceUI.Style.padding(subSty)
	sp.subPadL, sp.subPadB = scaled(sl), scaled(sb)
	sp.subPadR, sp.subPadT = scaled(sr), scaled(st)
end

-- Total grid cells = columns x rows.
local function gridCells()
	return sp.gridCols * sp.gridRows
end

-- Units shown per page. When everything fits, the whole grid is units. When
-- more pages are needed, the LAST cell (bottom-right) becomes the Next-page
-- button, so a page holds one unit fewer.
local function unitsPerPage(total)
	local cells = gridCells()
	if total <= cells then
		return cells
	end
	return cells - 1
end

-- Compute mainRect + tab rects + cell rects for the current page.
-- Layout, top to bottom: category tab row, build grid, bottom action bar.
-- There is NO paging row -- when more pages exist, the last grid cell is the
-- Next-page button.
local function buildLayout()
	vsx, vsy = spGetViewGeometry()
	if not panel then return end
	refreshSpacing()

	local cmds = shownCommands()
	local n    = #cmds
	local perPage = unitsPerPage(n)
	pageCount  = math.max(1, mathCeil(n / perPage))
	if currentPage > pageCount then currentPage = pageCount end

	-- ---- sizes ----
	local cols, rows = sp.gridCols, sp.gridRows
	local gridW = cols * sp.cellSize + (cols - 1) * sp.buttonGap
	local gridH = rows * sp.cellSize + (rows - 1) * sp.buttonGap

	-- subcontainer = content + sub padding
	local subPadW = sp.subPadL + sp.subPadR
	local subPadH = sp.subPadB + sp.subPadT

	local innerW = gridW + subPadW
	-- stacked: category tab row, grid, bottom action bar. FIXED height -- the
	-- grid always reserves gridRows rows. There is no paging row: when more
	-- pages exist the last grid cell becomes the Next-page button.
	local hasPaging = pageCount > 1
	local innerH = sp.tabH + sp.subGap + (gridH + subPadH)
		+ sp.subGap + sp.actionBarH

	local mainW = innerW + sp.mainPadL + sp.mainPadR
	local mainH = innerH + sp.mainPadB + sp.mainPadT

	-- position: bottom-left, docked directly on top of the IceUI order menu.
	-- Its top edge becomes our bottom edge. If the order menu is not showing,
	-- fall back to the screen edge.
	local ox = sp.margin
	local oy = sp.margin
	local omRect = WG.IceUIOrderMenu and WG.IceUIOrderMenu.rect
	if omRect and omRect[4] then
		ox = omRect[1]            -- align left edges
		oy = omRect[4] + sp.subGap  -- sit just above the order menu
	end
	mainRect = { ox, oy, ox + mainW, oy + mainH }

	local content = Layout.inset(mainRect,
		sp.mainPadL, sp.mainPadB, sp.mainPadR, sp.mainPadT)

	-- category tab row (top)
	local tabTop    = content[4]
	local tabBottom = tabTop - sp.tabH
	local tabRow = { content[1], tabBottom, content[3], tabTop }
	tabRects = Layout.row(tabRow, { 1, 1, 1, 1 }, sp.buttonGap)

	-- build grid (below the tabs)
	local gridTop = tabBottom - sp.subGap
	local gridLeft = content[1] + sp.subPadL
	local gridInnerTop = gridTop - sp.subPadT
	local cells = gridCells()
	cellRects = {}
	for i = 1, cells do
		local c = (i - 1) % cols
		local r = mathFloor((i - 1) / cols)
		local x = gridLeft + c * (sp.cellSize + sp.buttonGap)
		local y = gridInnerTop - r * (sp.cellSize + sp.buttonGap)
		cellRects[i] = { x, y - sp.cellSize, x + sp.cellSize, y }
	end

	-- Next-page button: the LAST grid cell, shown whenever there is more than
	-- one page -- INCLUDING the last page, where it wraps back to page 1.
	nextPageRect = hasPaging and cellRects[cells] or nil

	-- bottom action bar: 4 buttons (Factory guard / Priority / Queue mode /
	-- Clear Queue), split evenly across the content width.
	local barTop    = gridTop - subPadH - gridH - sp.subGap
	local barBottom = barTop - sp.actionBarH
	actionRects = Layout.row(
		{ content[1], barBottom, content[3], barTop }, { 1, 1, 1, 1 },
		sp.buttonGap)

	-- which commands land on the current page. When this is not the last page,
	-- the final cell is reserved for the Next-page button, so it holds one
	-- unit fewer (unitsPerPage). cmds beyond perPage spill to the next page.
	for i = #pageCommands, 1, -1 do pageCommands[i] = nil end
	local base = (currentPage - 1) * perPage
	for i = 1, perPage do
		pageCommands[i] = cmds[base + i]   -- may be nil for empty cells
	end
end

--------------------------------------------------------------------------------
-- drawing
--------------------------------------------------------------------------------

local hoveredCmd      -- the build command under the cursor (for the tooltip)

-- metal / energy cost icons (drawn in the tooltip cost row)
local METAL_ICON  = "luaui/images/metal.png"
local ENERGY_ICON = "luaui/images/energy.png"
local METAL_COLOR  = { 0.82, 0.84, 0.87 }   -- light grey
local ENERGY_COLOR = { 1.00, 0.90, 0.25 }   -- yellow

-- Build the tooltip spec for a build command: unit name + description + a
-- metal/energy cost row with icons.
-- Tooltip specs are immutable per unitDefID, so build each one ONCE and cache
-- it. overlayBuildPhase runs every frame while hovering -- without the cache it
-- would allocate the spec tables per frame.
local tooltipSpecCache = {}

local function buildTooltipSpec(entry)
	if not entry then return nil end
	local uDefID = entry.unitDefID
	local spec = tooltipSpecCache[uDefID]
	if not spec then
		spec = {
			title = unitHumanName[uDefID] or "?",
			text  = unitTooltip[uDefID],          -- unit description line(s)
			costs = {
				{ icon = METAL_ICON,  value = unitMetalCost[uDefID]  or 0,
				  color = METAL_COLOR },
				{ icon = ENERGY_ICON, value = unitEnergyCost[uDefID] or 0,
				  color = ENERGY_COLOR },
			},
		}
		tooltipSpecCache[uDefID] = spec
	end
	return spec
end

local function anythingToShow()
	for c = 1, 4 do
		if #catCommands[c] > 0 then return true end
	end
	return false
end

-- The queue-count badge rect for a build cell: a box in the cell's top-right
-- corner, sized to the count text. Shared by drawPhase (text) and texturePhase
-- (the box), so both place it identically. `out` is an optional rect table to
-- fill in place (texturePhase passes one to avoid per-frame allocation).
local function queueBadgeRect(cell, countStr, out)
	local qb = panel:style("queueBadge")
	local h  = mathFloor((qb.badgeSize or 22) * uiScale + 0.5)
	local padL = (qb.badgePadL or qb.badgePad or 5) * uiScale
	local padR = (qb.badgePadR or qb.badgePad or 5) * uiScale
	local getFont = WG['fonts'] and WG['fonts'].getFont
	local font = getFont and getFont(qb.font or 2)
	local textW = font and (font:GetTextWidth(countStr) * (qb.fontSize or 15)) or 8
	local w = textW + padL + padR
	-- top-right corner of the cell
	out = out or {}
	out[1], out[2], out[3], out[4] = cell[3] - w, cell[4] - h, cell[3], cell[4]
	return out
end

-- Reusable rect for the queue-badge box drawn every frame in texturePhase.
local scratchBadgeRect = { 0, 0, 0, 0 }

-- Draw the queue-badge box (texturePhase): a solid rect on top of the buildpic.
-- The count text is queued separately by drawPhase (drawn in the text phase).
local function drawQueueBadge(cell, count)
	local qb = panel:style("queueBadge")
	local br = queueBadgeRect(cell, tostring(count), scratchBadgeRect)
	WG.IceUI.drawRect(br, qb.background)
end

-- Draw a build cell's loose icon overlays into rect `r` for command `entry`:
--   * group icon       -- top-left corner
--   * strategic icon   -- bottom-left corner (the radar/minimap icon)
--   * queue-badge box  -- top-right corner
-- Used both by the cached texture phase and -- when the cell is hovered -- by
-- the live phase, so the hover-zoom buildpic does not hide them.
local function drawCellOverlays(r, entry, gsize)
	local uDefID = entry.unitDefID
	local sr = scratchIconRect

	-- group icon, top-left
	local gi = groupIconOf[uDefID]
	if gi and gsize > 0 then
		sr[1], sr[2], sr[3], sr[4] = r[1], r[4] - gsize, r[1] + gsize, r[4]
		WG.IceUI.drawTexture(sr, gi)
	end

	-- strategic (radar) icon, bottom-left, inset from the cell edge
	local si = unitStratIcon[uDefID]
	local ssize = sp.stratIcon
	if si and ssize and ssize > 0 then
		local inset = sp.stratInset or 0
		sr[1] = r[1] + inset
		sr[2] = r[2] + inset
		sr[3] = r[1] + inset + ssize
		sr[4] = r[2] + inset + ssize
		WG.IceUI.drawTexture(sr, si)
	end

	-- queue-count badge box, top-right
	if entry.queued and entry.queued > 0 then
		drawQueueBadge(r, entry.queued)
	end
end

local function drawPhase()
	if needsRefresh then
		refreshCommands()
		buildLayout()
	end

	local mx, my, lmb = spGetMouseState()
	panel:begin(mx, my, lmb)

	if not anythingToShow() or not mainRect[1] then
		panel:finish()
		return
	end

	-- main container
	panel:box("mainContainer", mainRect)

	-- category tabs. The label is centred in the whole tab; the group icon
	-- is drawn separately in texturePhase, pinned to the top-left corner.
	for i = 1, 4 do
		panel:tab("cat" .. i, "tab", "tabActive", tabRects[i],
			categoryLabel[i], i == activeCat,
			{ hotkey = categoryHotkey[i] })
	end

	-- build grid cells (only where there is a command). The buildpic itself is
	-- drawn in texturePhase via the engine '#'..unitDefID texture (plain, sharp).
	for i = 1, #cellRects do
		local entry = pageCommands[i]
		if entry then
			panel:button("cell" .. i, "cell", cellRects[i], nil, {})
			-- queue-count label: drawn in the text phase, on top of the badge
			-- box (which texturePhase draws over the buildpic). The badge box
			-- itself is in texturePhase -- see drawQueueBadge.
			if entry.queued and entry.queued > 0 then
				local qb = panel:style("queueBadge")
				local br = queueBadgeRect(cellRects[i], tostring(entry.queued))
				panel:label(tostring(entry.queued), br, {
					color = qb.text, size = qb.fontSize, font = qb.font,
					noFit = true,
				})
			end
		end
	end

	-- Next-page button: occupies the last grid cell when there is a next page.
	-- Shows the page counter so it doubles as a page indicator.
	if nextPageRect then
		panel:button("nextPage", "actionBtn", nextPageRect,
			"NEXT\n" .. currentPage .. " / " .. pageCount, {})
	end

	-- bottom action bar: 3 factory toggles + Clear Queue. Toggles only show
	-- when a unit exposes them; an absent toggle gets a dim disabled-looking
	-- button. Clear Queue is always shown.
	local gc = toggleCmds.guard
	panel:tab("abGuard", "barToggle", "barToggleOn", actionRects[1],
		gc and (gc.on and "GUARD: ON" or "GUARD: OFF") or "GUARD",
		gc ~= nil and gc.on, {})

	local pc = toggleCmds.priority
	panel:tab("abPrio", "barToggle", "barToggleOn", actionRects[2],
		pc and (pc.on and "PRIORITY: HIGH" or "PRIORITY: LOW") or "PRIORITY",
		pc ~= nil and pc.on, {})

	local qc = toggleCmds.queueMode
	panel:tab("abQueue", "barToggle", "barToggleOn", actionRects[3],
		qc and (qc.on and "QUEUE: QUOTA" or "QUEUE: NORMAL") or "QUEUE MODE",
		qc ~= nil and qc.on, {})

	panel:button("abClear", "barAction", actionRects[4], "CLEAR QUEUE", {})

	panel:finish()
end

-- Build progress per unitDefID: { unitDefID = progress 0..1 } for the units
-- the current selection is building right now. Recomputed each frame in
-- texturePhase (the progress animates continuously).
local buildProgress = {}

-- Refresh buildProgress from the selected builders' current build targets.
local function refreshBuildProgress()
	for k in pairs(buildProgress) do buildProgress[k] = nil end
	local sel = spGetSelectedUnits()
	for i = 1, #sel do
		local target = spGetUnitIsBuilding(sel[i])
		if target then
			local tDefID = spGetUnitDefID(target)
			if tDefID then
				local _, prog = spGetUnitIsBeingBuilt(target)
				if prog then
					-- keep the furthest-along target if several build the same
					local cur = buildProgress[tDefID]
					if not cur or prog > cur then
						buildProgress[tDefID] = prog
					end
				end
			end
		end
	end
end

-- CACHED engine-texture phase: the STATIC textured content -- every cell's
-- buildpic, group icon and queue-badge box, plus the category-tab icons. The
-- host renders this ONCE into an offscreen texture on a rebuild and blits that
-- single texture every frame (see registerDraw's texturesCached). ~30 buildpics
-- + ~30 icons would otherwise be ~350 GL calls EVERY frame.
--
-- Buildpics use the engine '#'..unitDefID texture through the LOD-bias shader
-- (sharp=true) so they stay crisp at any cell size.
local function texturesCachedPhase()
	if not mainRect[1] or not anythingToShow() then return end
	local gsize = sp.groupIcon
	local sr = scratchIconRect
	for i = 1, #cellRects do
		local entry = pageCommands[i]
		if entry then
			local r = cellRects[i]

			-- buildpic, sharp (LOD-bias shader)
			WG.IceUI.drawTexture(r, unitBuildpic[entry.unitDefID],
				nil, nil, nil, true)

			-- group icon + queue-badge box (the count TEXT is in the instanced
			-- text layer -- see drawPhase -- which rebuilds on the same frames).
			drawCellOverlays(r, entry, gsize)
		end
	end

	-- category-tab group icons: pinned to the tab's top-left corner.
	local isize = sp.tabIcon
	if isize > 0 then
		for i = 1, 4 do
			local tr = tabRects[i]
			local ic = categoryIcon[i]
			if tr and ic then
				sr[1], sr[2], sr[3], sr[4] = tr[1], tr[4] - isize, tr[1] + isize, tr[4]
				WG.IceUI.drawTexture(sr, ic)
			end
		end
	end
end

-- The consumer's bounding rect for the cached texture. The host renders
-- texturesCachedPhase into a texture sized to this rect. nil when hidden.
local function textureRect()
	if not mainRect[1] or not anythingToShow() then return nil end
	return mainRect
end

-- Hover-zoom UV fraction at full hover. This is a UV-zoom (the sampled UV range
-- shrinks), so the image enlarges WITHIN the cell rect and stays clipped to it
-- -- it never spills past the cell edge.
local HOVER_ZOOM = 0.14

-- How strong the additive brighten pass is at full hover (lightens the
-- hovered buildpic). gl.Color > 1 is clamped, so brighten = a 2nd additive pass.
local HOVER_BRIGHTEN = 0.22

-- Hover-zoom-in speed, in fade-units per second: the zoom eases toward full
-- over 1/SPEED seconds. Lower = slower/longer. There is no zoom-OUT animation
-- -- leaving a cell (or moving to another) drops the zoom instantly, so a new
-- cell always zooms in fresh from 0 with no wait.
local HOVER_ZOOM_SPEED_IN = 4.0    -- ~0.25s to zoom in

-- Ease-out exponent applied to the linear zoomFade -> a fast start that softly
-- decelerates into the final zoom. 2 = quadratic, 3 = cubic (stronger), higher
-- = even more pronounced. 1 = linear (no easing).
local HOVER_ZOOM_EASE = 3

-- Ease-out curve: t in 0..1 -> eased 0..1. 1 - (1-t)^n, decelerating.
local function easeOut(t)
	local inv = 1 - t
	return 1 - inv ^ HOVER_ZOOM_EASE
end

-- Hover-zoom state. zoomFade eases 0->1 on the hovered cell; switching cells
-- resets it to 0 so the new cell zooms in from scratch.
local zoomFade      = 0
local zoomCellRect  = nil
local zoomCellEntry = nil

-- LIVE engine-texture phase: drawn every frame ON TOP of the cached texture.
-- Only the things that animate go here -- the hovered cell's buildpic redrawn
-- zoomed + brightened, and the build-progress clock. One extra buildpic draw,
-- not 30 -- like FlowUI's separate hover draw.
local function texturePhase()
	if not mainRect[1] or not anythingToShow() then return end
	refreshBuildProgress()

	-- hover zoom: redraw the zoom's cell buildpic, zoomed IN within the same
	-- cell rect (UV-zoom -> clipped to the cell, no spill) and brightened.
	-- zoomCellRect/zoomFade are eased in widget:Update on their own (slower)
	-- timing -- the zoom keeps animating on a cell the cursor already left, so
	-- mouse-out fades out instead of snapping. The group icon + queue badge are
	-- redrawn on top afterwards (the cached texture has them baked in).
	if zoomFade > 0.001 and zoomCellRect and zoomCellEntry then
		local r   = zoomCellRect
		local tex = unitBuildpic[zoomCellEntry.unitDefID]
		-- zoomFade is linear; ease it out so the zoom decelerates near the end
		local eased = easeOut(zoomFade)
		local zoom  = HOVER_ZOOM * eased

		-- zoomed buildpic, still inside the cell rect (UV-zoom)
		WG.IceUI.drawTexture(r, tex, nil, zoom, nil, true)

		-- brighten: a 2nd additive pass with a faded grey
		local g = HOVER_BRIGHTEN * eased
		scratchHoverColor[1] = g
		scratchHoverColor[2] = g
		scratchHoverColor[3] = g
		WG.IceUI.drawTexture(r, tex, scratchHoverColor, zoom, true, true)

		-- group icon + queue badge, on top of the zoomed/brightened buildpic
		drawCellOverlays(r, zoomCellEntry, sp.groupIcon)
	end

	-- build clock: dark cover over each unit being built. Drawn LAST so it sits
	-- on top of everything, including the hover-zoom buildpic.
	local clockColor = panel:style("buildClock")
	for i = 1, #cellRects do
		local entry = pageCommands[i]
		if entry then
			local prog = buildProgress[entry.unitDefID]
			if prog then
				WG.IceUI.drawPie(cellRects[i], prog, clockColor)
			end
		end
	end
end

-- Base text phase: draw the menu's queued labels (tab text, paging buttons).
local function textPhase()
	if panel then
		panel:drawText()
	end
end

-- Overlay build phase: tooltip for the hovered build cell.
local function overlayBuildPhase()
	if panel then
		panel:buildTooltip(buildTooltipSpec(hoveredCmd))
	end
end

local function overlayTextPhase()
	if panel then
		panel:drawOverlayText()
	end
end

--------------------------------------------------------------------------------
-- input
--------------------------------------------------------------------------------

-- Issue the build order for `entry` with mouse `button`.
local function clickBuild(entry, button)
	if not entry then return end
	if soundButton then
		spPlaySoundFile(soundButton, 0.6, 'ui')
	end
	local descIndex = spGetCmdDescIndex(entry.cmdID)
	if descIndex then
		spSetActiveCommand(descIndex, button, true, false, spGetModKeyState())
	end
end

-- Cycle an ICON_MODE toggle command (Factory guard / Priority / Queue mode).
-- `tc` is a toggleCmds entry { cmdID, on }; SetActiveCommand on its descIndex
-- cycles the state, exactly like clicking a state toggle in the order menu.
local function clickToggle(tc)
	if not tc then return end
	if soundButton then
		spPlaySoundFile(soundButton, 0.6, 'ui')
	end
	local descIndex = spGetCmdDescIndex(tc.cmdID)
	if descIndex then
		spSetActiveCommand(descIndex, 1, true, false, spGetModKeyState())
	end
	requestRefresh(true)   -- reflect the new state right away
end

-- Clear the build queue of every selected factory. Issues the engine's
-- "Stop Production" command (same as the order-menu button / its hotkey) --
-- the cmd_factory_stop_production gadget does the full clear, incl. the WAIT
-- handling. SetActiveCommand + a left-click issues it on the whole selection.
local function clearQueue()
	if not stopProductionCmdID then return end
	if soundButton then
		spPlaySoundFile(soundButton, 0.6, 'ui')
	end
	local descIndex = spGetCmdDescIndex(stopProductionCmdID)
	if descIndex then
		spSetActiveCommand(descIndex, 1, true, false, spGetModKeyState())
	end
	requestRefresh(true)
end

-- Toggle the category filter `c`. The tabs are toggle filters: clicking the
-- active category again clears the filter (back to showing everything). Only
-- one filter can be active at a time. Always resets to page 1.
local function toggleCategory(c)
	if c == activeCat then
		activeCat = nil           -- click the active filter again -> show all
	else
		activeCat = c
	end
	currentPage = 1
	requestRefresh(true)   -- user click -> instant
end

local function changePage(delta)
	local p = currentPage + delta
	if p < 1 then p = pageCount elseif p > pageCount then p = 1 end
	if p ~= currentPage then
		currentPage = p
		requestRefresh(true)   -- user click -> instant
	end
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() or not anythingToShow() or not mainRect[1] then
		return false
	end
	if not Layout.hit(mainRect, x, y) then
		return false
	end

	-- bottom action bar: 3 toggles + Clear Queue
	if actionRects[1] then
		if Layout.hit(actionRects[1], x, y) then
			clickToggle(toggleCmds.guard);     return true
		elseif Layout.hit(actionRects[2], x, y) then
			clickToggle(toggleCmds.priority);  return true
		elseif Layout.hit(actionRects[3], x, y) then
			clickToggle(toggleCmds.queueMode); return true
		elseif Layout.hit(actionRects[4], x, y) then
			clearQueue();                      return true
		end
	end

	-- category filter tabs (toggle: click again to clear)
	for i = 1, 4 do
		if tabRects[i] and Layout.hit(tabRects[i], x, y) then
			toggleCategory(i)
			return true
		end
	end

	-- Next-page button (the last grid cell, when there is a next page).
	-- Checked before the build cells -- it occupies a grid cell rect.
	if nextPageRect and Layout.hit(nextPageRect, x, y) then
		changePage(1)
		return true
	end

	-- build cells
	for i = 1, #cellRects do
		if pageCommands[i] and Layout.hit(cellRects[i], x, y) then
			clickBuild(pageCommands[i], button)
			return true
		end
	end

	return true  -- consume clicks anywhere on the panel
end

--------------------------------------------------------------------------------
-- callins
--------------------------------------------------------------------------------

local function tryRegister()
	if registered or not WG.IceUI then
		return
	end
	WG.IceUI.registerDraw("iceui_buildmenu", {
		draw           = drawPhase,
		text           = textPhase,
		texturesCached = texturesCachedPhase,  -- buildpics: cached into a texture
		textureRect    = textureRect,
		textures       = texturePhase,         -- live: clock + hover zoom
		overlayBuild   = overlayBuildPhase,
		overlayText    = overlayTextPhase,
	})

	if WG.IceUI.setHover then
		local h = panel:style("hover")
		WG.IceUI.setHover("iceui_buildmenu", nil, false, {
			fadeIn    = h.fadeIn,
			fadeOut   = h.fadeOut,
			tint      = h.tint,
			pressTint = h.pressTint,
		})
	end
	registered = true
end

function widget:Initialize()
	panel = IceUI.newPanel(styleDef)
	refreshCommands()
	buildLayout()
	tryRegister()
end

function widget:Shutdown()
	if WG.IceUI then
		WG.IceUI.unregisterDraw("iceui_buildmenu")
	end
end

function widget:ViewResize()
	buildLayout()
	markDirty()
end

-- Last order-menu dock anchor we laid out against (left, top); detects when
-- the order menu resizes/moves so we can re-dock.
local lastDockX, lastDockY

function widget:Update(dt)
	if not registered then
		tryRegister()
	end

	-- promote a due throttled refresh into a real one
	if refreshAt and os.clock() >= refreshAt then
		refreshAt = nil
		needsRefresh = true
		markDirty()
	end

	-- While a refresh is pending, keep asking for a rebuild every frame so a
	-- missed/raced markDirty can never leave the menu stuck blank. needsRefresh
	-- is cleared by refreshCommands inside drawPhase (which runs on a rebuild).
	if needsRefresh then
		markDirty()
	end

	-- re-dock if the order menu (which we sit on top of) moved or resized
	local omRect = WG.IceUIOrderMenu and WG.IceUIOrderMenu.rect
	local dx = omRect and omRect[1] or nil
	local dy = omRect and omRect[4] or nil
	if dx ~= lastDockX or dy ~= lastDockY then
		lastDockX, lastDockY = dx, dy
		buildLayout()
		markDirty()
	end

	-- hover tracking: report the hovered element (build cell, category tab or
	-- paging button) to the host for the highlight, and remember the command
	-- for the tooltip.
	if mainRect[1] and WG.IceUI and WG.IceUI.setHover then
		local mx, my, lmb = spGetMouseState()
		local rect, cmd
		local cellRect, cellEntry   -- hovered build cell, for the hover zoom

		-- build cells (also yield the command, for the tooltip + hover zoom)
		for i = 1, #cellRects do
			if pageCommands[i] and Layout.hit(cellRects[i], mx, my) then
				rect, cmd = cellRects[i], pageCommands[i]
				cellRect, cellEntry = cellRects[i], pageCommands[i]
				break
			end
		end
		-- bottom action bar (3 toggles + Clear Queue)
		if not rect and actionRects[1] then
			for i = 1, 4 do
				if Layout.hit(actionRects[i], mx, my) then
					rect = actionRects[i]
					break
				end
			end
		end
		-- category tabs
		if not rect then
			for i = 1, 4 do
				if tabRects[i] and Layout.hit(tabRects[i], mx, my) then
					rect = tabRects[i]
					break
				end
			end
		end
		-- Next-page button (the last grid cell, when there is a next page)
		if not rect and nextPageRect and Layout.hit(nextPageRect, mx, my) then
			rect = nextPageRect
		end

		hoveredCmd = cmd                 -- for the tooltip
		WG.IceUI.setHover("iceui_buildmenu", rect, rect ~= nil and lmb)

		-- Hover-zoom: zoom-IN only, no zoom-out animation. While the cursor sits
		-- on a build cell, zoomFade eases 0->1. Moving to a different cell (or
		-- off the menu) snaps zoomFade to 0 and adopts the new cell, so it
		-- always zooms in fresh -- no waiting for a previous zoom to fade out.
		if cellRect and cellRect == zoomCellRect then
			zoomFade = math.min(1, zoomFade + (dt or 0) * HOVER_ZOOM_SPEED_IN)
		else
			zoomFade      = 0           -- new cell / no cell: restart the zoom
			zoomCellRect  = cellRect
			zoomCellEntry = cellEntry
		end
	end
end

-- Selection changed: the whole buildable set changes -> refresh immediately.
function widget:SelectionChanged(sel)
	requestRefresh(true)
end

-- CommandsChanged fires constantly during play -> throttle, coalesce bursts.
function widget:CommandsChanged()
	requestRefresh(false)
end

function widget:PlayerChanged()
	isSpectating = spGetSpectatingState()
end
