local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Order menu (IceUI)",
		desc    = "Commands/orders menu rebuilt on the IceUI-GL4 framework. Replaces the classic Order menu.",
		author  = "BAR team",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		-- Negative layer: the widgethandler dispatches MousePress in ascending
		-- layer order (lower = first), and the first widget to return true wins
		-- the click. FlowUI menus (buildmenu/gridmenu) sit at layer 0, so this
		-- menu must be below them to receive clicks on overlapping buttons first.
		layer   = -10,
		enabled = false,  -- enable from the widget list; disable the classic "Order menu" to swap
	}
end

--------------------------------------------------------------------------------
-- IceUI commands menu
--------------------------------------------------------------------------------
-- A drop-in replacement for gui_ordermenu.lua, drawn through IceUI-GL4.
--
-- Command sourcing and click handling mirror the classic widget so behaviour
-- stays identical:
--   * Spring.GetActiveCmdDescs() -> filter hidden -> 3 groups
--     (state toggles, WAIT, normal orders)
--   * left/right click -> Spring.SetActiveCommand(); state cmds cycle
--   * hotkeys resolved via action_hotkeys + keyboard_layouts
--
-- What is NEW is purely the look: the layout + stylesheet
-- (configs/iceui_ordermenu_styles.lua) render the dark, accented design.
-- No render-to-texture: IceUI draws the whole menu in one instanced call.
--
-- Icons are not drawn yet (text-only first pass); the IceUI core needs
-- texture-atlas support before order icons can be added.
--------------------------------------------------------------------------------

local IceUI    = VFS.Include("luaui/Include/IceUI/iceui.lua", nil, VFS.RAW_FIRST)
local Layout   = IceUI.Layout
local styleDef = VFS.Include("luaui/configs/iceui_styles.lua", nil, VFS.RAW_FIRST).ordermenu
local iconMap  = VFS.Include("luaui/configs/iceui_ordermenu_icons.lua", nil, VFS.RAW_FIRST)
local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")

--------------------------------------------------------------------------------
-- Spring API locals
--------------------------------------------------------------------------------

local spGetActiveCmdDescs   = Spring.GetActiveCmdDescs
local spGetActiveCommand    = Spring.GetActiveCommand
local spGetCmdDescIndex     = Spring.GetCmdDescIndex
local spSetActiveCommand    = Spring.SetActiveCommand
local spGetModKeyState      = Spring.GetModKeyState
local spGetMouseState       = Spring.GetMouseState
local spGetViewGeometry     = Spring.GetViewGeometry
local spGetSelectedUnits    = Spring.GetSelectedUnits
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitCommands     = Spring.GetUnitCommands
local spGetFactoryCommands  = Spring.GetFactoryCommands
local spFindUnitCmdDesc     = Spring.FindUnitCmdDesc
local spValidUnitID         = Spring.ValidUnitID
local spGetSpectatingState  = Spring.GetSpectatingState
local spGetGameFrame        = Spring.GetGameFrame
local spPlaySoundFile       = Spring.PlaySoundFile
local spI18N                = Spring.I18N

local mathFloor = math.floor

--------------------------------------------------------------------------------
-- command filtering (mirrors gui_ordermenu.lua)
--------------------------------------------------------------------------------

local CMDTYPE_ICON_MODE     = CMDTYPE.ICON_MODE
local CMDTYPE_ICON_BUILDING = CMDTYPE.ICON_BUILDING
local CANCEL_TARGET_CMD_ID  = 34924

-- Commands hidden from the menu entirely. Note: unlike classic gui_ordermenu,
-- SELFD is NOT hidden here -- it goes into the special-commands block.
local hiddenCommands = {
	[CMD.LOAD_ONTO]        = true,
	[CMD.GATHERWAIT]       = true,
	[CMD.SQUADWAIT]        = true,
	[CMD.DEATHWAIT]        = true,
	[CMD.TIMEWAIT]         = true,
	[CMD.AUTOREPAIRLEVEL]  = true,
	[39812]                = true, -- raw move
	[34922]                = true, -- set unit target (no ground)
}

local hiddenCommandTypes = {
	[CMDTYPE.CUSTOM] = true,
	[CMDTYPE.PREV]   = true,
	[CMDTYPE.NEXT]   = true,
}

-- Commands hidden by their action name (widget commands have no fixed cmdID).
local hiddenCommandActions = {
	blueprint_place  = true,  -- Place Blueprint      -- belongs in the build menu
	factoryqueuemode = true,  -- factory queue/quota  -- moved to the build menu
	factoryguard     = true,  -- factory guard        -- moved to the build menu
	priority         = true,  -- builder priority     -- moved to the build menu
	stopproduction   = true,  -- Clear Queue          -- moved to the build menu
}

-- Block 2: "special commands" -- big, prominent buttons. The engine has no
-- category for this, so we classify by cmdID / action name explicitly.
-- Extend this set to move more commands into the special block.
local specialCommandIDs = {
	[CMD.SELFD]      = true,
	[CMD.MANUALFIRE] = true,   -- D-Gun
}
-- Cloak (wantcloak) is an ICON_MODE command, so it is NOT listed here -- it
-- falls naturally into the state-toggles block.
local specialCommandActions = {
	stockpile = true,          -- missile/nuke stockpile
	areamex   = true,          -- Area Mex
}

local function isSpecialCommand(cmd)
	return specialCommandIDs[cmd.id] or specialCommandActions[cmd.action] or false
end

local isStateCommand = {}     -- cmdID -> true for ICON_MODE commands

local isFactory = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory then
		isFactory[unitDefID] = true
	end
end

--------------------------------------------------------------------------------
-- widget state
--------------------------------------------------------------------------------

local soundButton = 'LuaUI/Sounds/buildbar_waypoint.wav'

local panel                  -- IceUI Panel

-- The menu is one main container holding three subcontainers. Each block holds
-- a command list, a parallel button-rect list, and its own subcontainer rect.
--   block 1  regular  : the normal order grid (Move, Stop, Patrol, ...)
--   block 2  special  : big prominent buttons (Self-Destruct, Cloak, D-Gun)
--   block 3  states   : ICON_MODE state toggles (Fire-at-will, Repeat, ...)
local regular  = { commands = {}, rects = {}, sub = {} }
local special  = { commands = {}, rects = {}, sub = {} }
local states   = { commands = {}, rects = {}, sub = {} }
local blocks   = { regular, special, states }

local mainRect = {}          -- the outer (main) container rect
local activeCommand          -- name of the currently active command

local vsx, vsy     = spGetViewGeometry()
local uiScale      = Spring.GetConfigFloat("ui_scale", 1)

local isSpectating = spGetSpectatingState()
local disableInput = false

local actionHotkeys
local currentLayout
local hotkeyCache  = {}      -- action -> sanitized hotkey string
local translationCache = {}

local needsRefresh = true    -- recompute commands on the next drawPhase
local refreshAt              -- os.clock time a throttled refresh is due, or nil
local REFRESH_DELAY = 0.1    -- min seconds between throttled refreshes

--------------------------------------------------------------------------------
-- dirty / refresh control
--------------------------------------------------------------------------------
-- Declared up here so every function below can close over them (a `local
-- function` captures upvalues at definition time -- a later local would be a
-- different variable).

-- Tell the IceUI host the menu must be rebuilt this frame. Without this the
-- host keeps drawing the cached VBO and visual changes never show.
local function markDirty()
	if WG.IceUI and WG.IceUI.setDirty then
		WG.IceUI.setDirty()
	end
end

-- Request a command refresh.
--   immediate = true  : refresh on the very next drawPhase (selection / click)
--   immediate = false : throttled -- coalesce bursts of CommandsChanged /
--                       UnitCommand events into one refresh every REFRESH_DELAY.
-- The throttle keeps the menu cheap during play: those engine events fire
-- constantly, and an un-throttled rebuild per event was a big frame-cost.
-- Both paths mark the host dirty -- a bare `needsRefresh = true` would never
-- trigger a rebuild on its own.
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
-- helpers
--------------------------------------------------------------------------------

-- Translate `key`. Spring.I18N returns the key itself when it is not found;
-- in that case return nil so callers can fall back to something readable.
local function getTranslation(key)
	local v = translationCache[key]
	if v == nil then
		v = spI18N(key)
		if v == key then v = false end   -- false = "not translated"
		translationCache[key] = v
	end
	return v or nil
end

local function getHotkey(action)
	local h = hotkeyCache[action]
	if h == nil then
		h = keyConfig.sanitizeKey(actionHotkeys[action], currentLayout) or ""
		hotkeyCache[action] = h
	end
	return h
end

-- The selected state index of an ICON_MODE command, as a number.
-- cmd.params entries come from the engine as strings, so coerce explicitly.
local function stateIndex(cmd)
	return cmd.params and tonumber(cmd.params[1])
end

-- The label text for a command cell. State commands show their current state.
-- Falls back to the engine-supplied cmd.name when no translation exists
-- (e.g. Self-Destruct has no ui.orderMenu key).
local function commandText(cmd)
	if isStateCommand[cmd.id] then
		local idx = stateIndex(cmd)
		if idx then
			-- engine returns the selected index 2 less than the actual param
			-- index; matches gui_ordermenu.lua's cmd.params[idx + 2]
			local stateName = cmd.params[idx + 2]
			if stateName then
				return getTranslation('ui.orderMenu.' .. stateName) or stateName
			end
		end
		return '?'
	end
	return getTranslation('ui.orderMenu.' .. cmd.action)
		or cmd.name
		or cmd.action
		or '?'
end

-- For a state command, is the current state considered "on"?
-- Convention: state index 0 is the off/first state. Good enough for the
-- two-state toggles (Fire-at-will/Hold-fire, Repeat on/off, etc.).
local function stateIsOn(cmd)
	local idx = stateIndex(cmd)
	return idx ~= nil and idx > 0
end

--------------------------------------------------------------------------------
-- command refresh
--------------------------------------------------------------------------------

-- Sort the active command descriptions into the three blocks.
local function refreshCommands()
	needsRefresh = false

	-- clear the three command lists
	for _, b in ipairs(blocks) do
		for i = #b.commands, 1, -1 do b.commands[i] = nil end
	end

	local waitCmd
	for _, cmd in ipairs(spGetActiveCmdDescs()) do
		if type(cmd) == "table" then
			if cmd.type == CMDTYPE_ICON_MODE then
				isStateCommand[cmd.id] = true
			end
			local hidden = hiddenCommands[cmd.id]
				or hiddenCommandTypes[cmd.type]
				or (cmd.action and hiddenCommandActions[cmd.action])
				or cmd.disabled
				or cmd.action == nil
			if not hidden then
				if cmd.type == CMDTYPE_ICON_BUILDING
						or (cmd.action and cmd.action:find('buildunit_', 1, true) == 1) then
					-- build commands belong to the build menu, skip
				elseif isSpecialCommand(cmd) then
					special.commands[#special.commands + 1] = cmd
				elseif isStateCommand[cmd.id] then
					states.commands[#states.commands + 1] = cmd
				elseif cmd.id == CMD.WAIT then
					waitCmd = cmd        -- WAIT joins regular, placed first
				else
					regular.commands[#regular.commands + 1] = cmd
				end
			end
		end
	end

	-- WAIT leads the regular block (it is a normal order, just special-cased)
	if waitCmd then
		table.insert(regular.commands, 1, waitCmd)
	end
end

--------------------------------------------------------------------------------
-- layout
--------------------------------------------------------------------------------

-- Number of rows needed for `n` cells at `cols` columns wide.
local function rowsFor(n, cols)
	if n <= 0 then return 0 end
	return mathFloor((n + cols - 1) / cols)
end

-- All spacing values, read from the stylesheet and scaled by ui_scale.
-- One source of truth: every container/button gap comes from here.
local sp = {}

local function refreshSpacing()
	uiScale = Spring.GetConfigFloat("ui_scale", 1)
	local function scaled(v) return mathFloor((v or 0) * uiScale + 0.5) end

	local m       = panel:style("metrics")
	local mainSty = panel:style("mainContainer")
	local subSty  = panel:style("subContainer")

	sp.buttonGap = scaled(m.buttonGap)   -- between buttons in a subcontainer
	sp.subGap    = scaled(m.subGap)      -- between subcontainers
	sp.cellSize  = scaled(m.cellSize)    -- regular & state buttons: SQUARE side
	sp.actionH   = scaled(m.actionH)     -- special-button height
	sp.margin    = scaled(m.margin)      -- screen edge -> main container
	sp.regCols   = m.regCols or 6        -- columns in the regular grid
	-- sp.actionW is NOT read from the stylesheet: it is derived in buildLayout
	-- so the special row always matches the regular grid's full width.

	-- container paddings resolved per axis (Style.padding supports a number,
	-- a {h,v} pair, a {l,b,r,t} table, or paddingX/paddingY fields).
	local ml, mb, mr, mt = IceUI.Style.padding(mainSty)
	sp.mainPadL, sp.mainPadB = scaled(ml), scaled(mb)
	sp.mainPadR, sp.mainPadT = scaled(mr), scaled(mt)

	local sl, sb, sr, st = IceUI.Style.padding(subSty)
	sp.subPadL, sp.subPadB = scaled(sl), scaled(sb)
	sp.subPadR, sp.subPadT = scaled(sr), scaled(st)
end

-- Inner button area of a grid: w x h of `cols` x `rows` cells + button gaps.
local function gridExtent(cols, rows, cellW, cellH)
	local w = cols * cellW + (cols - 1) * sp.buttonGap
	local h = rows * cellH + (rows - 1) * sp.buttonGap
	return w, h
end

-- Lay a grid of `count` buttons into `block`, anchored to the top-left of the
-- block's subcontainer (inset by the subcontainer padding). Buttons keep a
-- FIXED cellW x cellH size, so they never stretch when the subcontainer is
-- wider than its grid (e.g. when a column is widened to match a neighbour).
local function layoutButtons(block, cols, count, cellW, cellH)
	for i = #block.rects, 1, -1 do block.rects[i] = nil end
	if count <= 0 then return end
	local inner = Layout.inset(block.sub,
		sp.subPadL, sp.subPadB, sp.subPadR, sp.subPadT)
	local left, top = inner[1], inner[4]
	for i = 1, count do
		local c = (i - 1) % cols
		local r = mathFloor((i - 1) / cols)
		local x = left + c * (cellW + sp.buttonGap)
		local y = top  - r * (cellH + sp.buttonGap)
		block.rects[i] = { x, y - cellH, x + cellW, y }
	end
end

-- Compute the whole nested layout:
--   mainContainer  (padding from the mainContainer style, per axis)
--     left column  : regular subcontainer (top) + special subcontainer (below)
--     states subcontainer (right)
-- Subcontainers are sized from their button grids + the subContainer padding,
-- so the paddings stay consistent across all subcontainers by construction.
local function buildLayout()
	vsx, vsy = spGetViewGeometry()
	if not panel then return end
	refreshSpacing()

	local nReg = #regular.commands
	local nSpc = #special.commands
	local nSta = #states.commands

	mainRect = {}
	for _, b in ipairs(blocks) do
		b.sub = {}
		for i = #b.rects, 1, -1 do b.rects[i] = nil end
	end
	if nReg + nSpc + nSta == 0 then
		return
	end

	local regCols   = sp.regCols   -- regular grid column count (from stylesheet)
	local stateCols = 2            -- states grid 2 wide (like the screenshot)

	-- subcontainer padding totals per axis (left+right, bottom+top)
	local subPadW = sp.subPadL + sp.subPadR
	local subPadH = sp.subPadB + sp.subPadT

	-- ---- subcontainer sizes (button grid + sub padding) ----
	-- regular & state buttons are SQUARE (cellSize x cellSize)
	local regRows = rowsFor(nReg, regCols)
	local regGW, regGH = gridExtent(regCols, regRows, sp.cellSize, sp.cellSize)
	local regSubW = regGW + subPadW
	local regSubH = regGH + subPadH

	-- special buttons: the special row spans the SAME inner width as the
	-- regular grid, split evenly among the specials. So actionW is derived,
	-- not a fixed value -- the row always matches the regular grid's width.
	local hasSpecial = nSpc > 0
	local actionW = sp.cellSize   -- fallback when there is no regular grid
	if hasSpecial and nReg > 0 then
		actionW = mathFloor((regGW - (nSpc - 1) * sp.buttonGap) / nSpc + 0.5)
	end
	local spcGW, spcGH = gridExtent(nSpc, 1, actionW, sp.actionH)
	local spcSubW = spcGW + subPadW
	local spcSubH = spcGH + subPadH

	local hasStates = nSta > 0
	local staRows = rowsFor(nSta, stateCols)
	local staGW, staGH = gridExtent(stateCols, staRows, sp.cellSize, sp.cellSize)
	local staSubW = staGW + subPadW
	local staSubH = staGH + subPadH

	-- ---- left column = regular over special, same width ----
	local leftW = regSubW
	if hasSpecial and spcSubW > leftW then leftW = spcSubW end
	local leftH = regSubH + (hasSpecial and (sp.subGap + spcSubH) or 0)

	-- ---- main container size: left column + (states) inside main padding ----
	local innerW = leftW + (hasStates and (sp.subGap + staSubW) or 0)
	local innerH = leftH
	if hasStates and staSubH > innerH then innerH = staSubH end

	local mainW = innerW + sp.mainPadL + sp.mainPadR
	local mainH = innerH + sp.mainPadB + sp.mainPadT

	local ox, oy = sp.margin, sp.margin
	mainRect = { ox, oy, ox + mainW, oy + mainH }

	-- publish the menu rect so other IceUI widgets (the build menu) can dock
	-- against it. Kept current every layout.
	WG.IceUIOrderMenu = WG.IceUIOrderMenu or {}
	WG.IceUIOrderMenu.rect = mainRect

	-- inner content area of the main container (after main padding)
	local content = Layout.inset(mainRect,
		sp.mainPadL, sp.mainPadB, sp.mainPadR, sp.mainPadT)

	-- left column subcontainers, top-aligned within the content area.
	-- regular buttons are square (cellSize x cellSize).
	local colTop = content[4]
	regular.sub = { content[1], colTop - regSubH, content[1] + leftW, colTop }
	layoutButtons(regular, regCols, nReg, sp.cellSize, sp.cellSize)

	if hasSpecial then
		local spcTop = regular.sub[2] - sp.subGap
		special.sub = { content[1], spcTop - spcSubH, content[1] + leftW, spcTop }
		layoutButtons(special, nSpc, nSpc, actionW, sp.actionH)
	end

	-- states subcontainer to the right; state buttons are square too.
	if hasStates then
		local sx = content[1] + leftW + sp.subGap
		states.sub = { sx, content[4] - staSubH, sx + staSubW, content[4] }
		layoutButtons(states, stateCols, nSta, sp.cellSize, sp.cellSize)
	end
end

--------------------------------------------------------------------------------
-- drawing
--------------------------------------------------------------------------------

-- Style name for a regular-block command cell.
local function regularStyle(cmd)
	if activeCommand and cmd.action == activeCommand then
		return "cellActive"
	end
	return "cell"
end

-- Style name for a state-toggle cell (block 3).
local function stateStyle(cmd)
	return stateIsOn(cmd) and "stateOn" or "stateOff"
end

-- The atlas UV rect for a command's icon, or nil if it has no mapped/available
-- icon. A command with no icon falls back to its text label.
local function commandIcon(cmd)
	local file = iconMap[cmd.action]
	if not file or not WG.IceUI or not WG.IceUI.getIconUV then
		return nil
	end
	return WG.IceUI.getIconUV(file)
end

-- Build the IceUI tooltip spec (title + hotkey + body) for a command, or nil
-- if there is nothing useful to show.
local function commandTooltip(cmd)
	local title = commandText(cmd)
	local body  = getTranslation('ui.orderMenu.' .. cmd.action .. '_tooltip')
	local hotkey = getHotkey(cmd.action)
	if not title and not body then
		return nil
	end
	return { title = title, hotkey = hotkey, text = body }
end

-- Draw one block's buttons. `keyPrefix` keeps button ids unique across blocks.
-- `styleFn` maps a command to its style name. Buttons with a mapped icon show
-- the icon; the rest show their text label. The tooltip is NOT requested here
-- -- it is built every frame in overlayBuildPhase (this runs only on rebuild).
local function drawBlock(block, keyPrefix, styleFn)
	for i = 1, #block.commands do
		local cmd  = block.commands[i]
		local rect = block.rects[i]
		if rect then
			local icon   = commandIcon(cmd)
			local hotkey = getHotkey(cmd.action)
			panel:button(keyPrefix .. i, styleFn(cmd), rect,
				commandText(cmd), { icon = icon, hotkey = hotkey })
		end
	end
end

local function anythingToShow()
	return #regular.commands + #special.commands + #states.commands > 0
end

local function specialStyle()
	return "action"
end

-- Tracks whether the menu currently claims an occluder rect, so we only
-- call into WG.IceUI.setOccluder when the visible/hidden state changes.
local occluderActive = false

-- Keep the tooltip-occluder in sync with the menu's visibility: claim
-- mainRect while the menu shows, release it when it is hidden, so FlowUI
-- tooltips don't bleed through the panel.
local function updateOccluder(visible)
	if not WG.IceUI or not WG.IceUI.setOccluder then return end
	if visible then
		WG.IceUI.setOccluder("ordermenu", { mainRect })
		occluderActive = true
	elseif occluderActive then
		WG.IceUI.setOccluder("ordermenu", nil)
		occluderActive = false
	end
end

-- The command currently under the cursor (for the tooltip). MUST be declared
-- before overlayBuildPhase: a `local function` captures upvalues at definition
-- time, so a later `local` would be a different variable (Lua scope rule).
local hoveredCmd

local function drawPhase()
	-- Refresh the command data HERE, right before queuing, so the geometry is
	-- always current. Doing this in a separate widget:DrawScreen raced the
	-- host (which draws first) and could queue stale/empty content.
	if needsRefresh then
		refreshCommands()
		buildLayout()
	end

	-- Always begin the frame, even with nothing to show: panel:begin() clears
	-- the queued-text buffer. Skipping it would leave last frame's labels to be
	-- drawn by textPhase() after the units are deselected.
	local mx, my, lmb = spGetMouseState()
	panel:begin(mx, my, lmb)

	if not anythingToShow() or not mainRect[1] then
		updateOccluder(false)
		panel:finish()
		return
	end

	updateOccluder(true)

	-- main container, then the three subcontainers inside it
	panel:box("mainContainer", mainRect)
	if regular.sub[1] then panel:box("subContainer", regular.sub) end
	if special.sub[1] then panel:box("subContainer", special.sub) end
	if states.sub[1]  then panel:box("subContainer", states.sub)  end

	-- the buttons inside each subcontainer
	drawBlock(regular, "reg", regularStyle)
	drawBlock(special, "spc", specialStyle)
	drawBlock(states,  "sta", stateStyle)

	panel:finish()
end

local function textPhase()
	if panel then
		panel:drawText()
	end
end

-- Overlay build phase: runs EVERY frame (not cached). Builds the tooltip for
-- the currently hovered command and queues its box into the overlay layer.
-- The tooltip is informational, so it shows even when input is disabled
-- (spectating) -- disableInput only blocks issuing commands, not tooltips.
local function overlayBuildPhase()
	if not panel then return end
	if hoveredCmd then
		panel:buildTooltip(commandTooltip(hoveredCmd))
	else
		panel:buildTooltip(nil)
	end
end

-- Overlay text phase: draw the tooltip text on top of everything.
local function overlayTextPhase()
	if panel then
		panel:drawOverlayText()
	end
end

--------------------------------------------------------------------------------
-- input
--------------------------------------------------------------------------------

-- Issue `cmd` with mouse `button` (1 = left, 3 = right).
local function clickCommand(cmd, button)
	if not cmd or disableInput then return end

	if soundButton then
		spPlaySoundFile(soundButton, 0.6, 'ui')
	end

	local descIndex = cmd.id and spGetCmdDescIndex(cmd.id)
	if descIndex then
		spSetActiveCommand(descIndex, button, true, false, spGetModKeyState())
	end
	-- refresh immediately: clicking a state toggle must show its new
	-- state/colour right away. requestRefresh(true) also marks the host
	-- dirty -- a bare `needsRefresh = true` would never trigger a rebuild.
	requestRefresh(true)
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() or not anythingToShow() or not mainRect[1] then
		return false
	end
	if not Layout.hit(mainRect, x, y) then
		return false
	end

	-- find the hit button across all three blocks
	for _, block in ipairs(blocks) do
		for i = 1, #block.rects do
			if block.rects[i] and Layout.hit(block.rects[i], x, y) then
				clickCommand(block.commands[i], button)
				return true
			end
		end
	end

	return true  -- consume clicks anywhere on the main container
end

--------------------------------------------------------------------------------
-- callins
--------------------------------------------------------------------------------

local function reloadBindings()
	currentLayout = Spring.GetConfigString("KeyboardLayout", "qwerty")
	actionHotkeys = VFS.Include("luaui/Include/action_hotkeys.lua")
	hotkeyCache   = {}
end

-- Registered with WG.IceUI once the host is available. Set false until then;
-- widget:Update keeps retrying so widget load order doesn't matter.
local registered = false

local function tryRegister()
	if registered or not WG.IceUI then
		return
	end
	WG.IceUI.registerDraw("iceui_ordermenu", {
		draw         = drawPhase,
		text         = textPhase,
		overlayBuild = overlayBuildPhase,
		overlayText  = overlayTextPhase,
	})

	-- push the hover fade timing from the stylesheet to the host (once)
	if WG.IceUI.setHover then
		local h = panel:style("hover")
		WG.IceUI.setHover("iceui_ordermenu", nil, false, {
			fadeIn    = h.fadeIn,
			fadeOut   = h.fadeOut,
			tint      = h.tint,
			pressTint = h.pressTint,
		})
	end

	registered = true
end

function widget:Initialize()
	reloadBindings()
	panel = IceUI.newPanel(styleDef)

	refreshCommands()
	buildLayout()

	-- WG.IceUI may not exist yet if the IceUI-GL4 host loads after us;
	-- tryRegister() also runs from Update until it succeeds.
	tryRegister()
end

function widget:Shutdown()
	if WG.IceUI then
		WG.IceUI.unregisterDraw("iceui_ordermenu")
		updateOccluder(false)   -- release the tooltip occluder
	end
end

-- The rect AND command of the cell under (x,y), or nil,nil. Used both to tell
-- the host which element to highlight and to build the tooltip.
local function cellAt(x, y)
	for bi = 1, #blocks do
		local block = blocks[bi]
		for i = 1, #block.rects do
			local r = block.rects[i]
			if r and Layout.hit(r, x, y) then
				return r, block.commands[i]
			end
		end
	end
	return nil, nil
end

function widget:ViewResize()
	buildLayout()
	markDirty()   -- geometry changed -> rebuild the cached VBO
end

function widget:Update(dt)
	if not registered then
		tryRegister()  -- handle the IceUI-GL4 host loading after us
	end

	disableInput = isSpectating and not Spring.IsGodModeEnabled()

	-- promote a due throttled refresh into a real one
	if refreshAt and os.clock() >= refreshAt then
		refreshAt = nil
		needsRefresh = true
	end

	-- While a refresh is still pending, keep asking the host to rebuild EVERY
	-- frame -- not just once. needsRefresh is only cleared by refreshCommands
	-- (inside drawPhase, which runs on a rebuild), so this self-heals if a
	-- markDirty was ever missed or raced: the menu can never get stuck blank.
	if needsRefresh then
		markDirty()
	end

	-- active command tracking: a change restyles the active cell -> rebuild
	local newActive = select(4, spGetActiveCommand())
	if newActive ~= activeCommand then
		activeCommand = newActive
		requestRefresh(true)
	end

	-- hover tracking: report the hovered cell to the host. The hover highlight
	-- + its fade animation are a shader uniform, so this NEVER rebuilds the
	-- VBO -- moving the mouse over the menu is essentially free.
	-- The cursor position maps directly to the hovered cell: no element under
	-- the cursor means no hover. The cross-fade (slow fade-out) smooths over
	-- the 1-2 frames spent crossing the thin seams between buttons, so no
	-- seam-bridging hack is needed.
	if mainRect[1] and WG.IceUI and WG.IceUI.setHover then
		local mx, my, lmb = spGetMouseState()
		local rect, cmd = cellAt(mx, my)
		hoveredCmd = cmd            -- the command for the tooltip (nil if none)
		WG.IceUI.setHover("iceui_ordermenu", rect, rect ~= nil and lmb)
	end
end

-- Selection changed: the whole command set changes -> refresh immediately.
function widget:SelectionChanged(sel)
	requestRefresh(true)
end

-- CommandsChanged fires constantly during play; throttle it so bursts
-- collapse into one refresh instead of a rebuild per event.
function widget:CommandsChanged()
	requestRefresh(false)
end

-- A unit (de)activating a state command -- throttled, same reason.
function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID)
	if isStateCommand[cmdID] or cmdID == CMD.WAIT then
		requestRefresh(false)
	end
end

-- NOTE: no widget:DrawScreen. The command refresh + layout happen inside
-- drawPhase (the host draw callback), so the data is always current when it
-- is queued -- a separate DrawScreen would race the host, which draws first.

function widget:PlayerChanged()
	isSpectating = spGetSpectatingState()
end

function widget:LanguageChanged()
	translationCache = {}
end
