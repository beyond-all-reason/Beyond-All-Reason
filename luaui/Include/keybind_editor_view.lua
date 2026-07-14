-- Interactive view for the in-game keybind editor, hosted as the first tab of
-- the Keybind/Mouse Info panel. Immediate-mode, drawn live every frame.
--
-- Preset picker mirrors Settings: switching is a non-destructive KeybindingFile
-- change (seeding uikeys.txt from the current binds the first time Custom is
-- picked), applied live. Rebinding is only allowed on Custom, and each edit
-- applies and saves to uikeys.txt immediately - no staging.

local keybindModel = VFS.Include("luaui/Include/keybind_model.lua")
local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")
local catalog = VFS.Include("luaui/configs/keybind_catalog.lua")
local Editbox = VFS.Include("luaui/Include/keybind_editbox.lua")
local Dropdown = VFS.Include("luaui/Include/keybind_dropdown.lua")

local view = {}

local floor = math.floor
local spGetMouseState = Spring.GetMouseState
local spGetModKeyState = Spring.GetModKeyState
local spSendCommands = Spring.SendCommands

local area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
local scale = 1
local rowHeight = 22
local hintH = 0
local listTop = 0
local barX1 = 0
local listRight = 0
local keyAreaX1 = 0

local working -- display copy of the bindings, reseeded from the engine after every edit
local resolvedCatalog -- catalog with i18n labels resolved once (rebuilt on language change)
local L = {} -- editor UI strings, resolved once alongside the catalog
local rows = {} -- flat display list: { type=header|editable|info, ... }
local scroll = 0
local dragging = false
local editable = false -- true only while the active preset is Custom (uikeys.txt)
local capturing -- { action, oldRaw }
local edited = false -- Custom edits applied live but not yet written to uikeys.txt
local lastClickTime, lastClickId

local font
local RectRound, Scroller

local colorAction = "\255\210\210\205"
local colorKey = "\255\235\185\070"
local colorText = "\255\235\235\235"
local colorDim = "\255\160\160\160"
local colorHeader = "\255\255\200\130"

local searchBox, presetDropdown, menuToggle
local switchPreset, scrollFromY

-- "Grid (60% Keyboard)" -> "Grid 60%" so the long names fit the picker.
local function shortPresetLabel(name)
	return (name:gsub(" %(60%% Keyboard%)", " 60%%"))
end

local presetOptions = {}
for i = 1, #keyConfig.keybindingLayouts do
	presetOptions[i] = {
		label = shortPresetLabel(keyConfig.keybindingLayouts[i]),
		file = keyConfig.keybindingLayoutFiles[i],
	}
end

local function currentPresetIndex()
	local file = Spring.GetConfigString("KeybindingFile", keyConfig.keybindingLayoutFiles[1])
	for i = 1, #presetOptions do
		if presetOptions[i].file == file then
			return i
		end
	end
	return 1
end

local function listBottom()
	return editable and area.y1 or (area.y1 + hintH)
end

local function visibleRows()
	return math.max(1, floor((listTop - listBottom()) / rowHeight))
end

local function maxScroll()
	return math.max(0, #rows - visibleRows())
end

local function clampScroll()
	if scroll < 0 then scroll = 0 end
	if scroll > maxScroll() then scroll = maxScroll() end
end

-- Resolve the catalog's i18n labels (and their lowercased search forms) once, so
-- searching - which rebuilds rows on every keystroke - never re-runs Spring.I18N.
-- Rebuilt via view.refresh(), which the host's LanguageChanged callin already calls.
local function buildResolvedCatalog()
	resolvedCatalog = {}
	for _, group in ipairs(catalog) do
		local title = Spring.I18N(group.category)
		local g = { title = title, titleLower = title:lower(), items = {} }
		for _, item in ipairs(group.items) do
			if item.prefix then
				g.items[#g.items + 1] = { prefix = item.prefix }
			else
				local label = Spring.I18N(item.label)
				g.items[#g.items + 1] = {
					action = item.action,
					actionLower = item.action and item.action:lower(),
					label = label,
					labelLower = label:lower(),
					keyText = item.keyLabel and Spring.I18N(item.keyLabel) or "",
				}
			end
		end
		resolvedCatalog[#resolvedCatalog + 1] = g
	end

	L.other = Spring.I18N('ui.keybinds.editor.other')
	L.pressKey = Spring.I18N('ui.keybinds.editor.pressKey')
	L.customOnly = Spring.I18N('ui.keybinds.editor.customOnly')
end

local function rebuildRows()
	if not resolvedCatalog then
		buildResolvedCatalog()
	end

	rows = {}
	local q = searchBox and searchBox:getText():lower() or ""
	local catalogActions = {}

	for _, group in ipairs(resolvedCatalog) do
		local categoryMatch = q ~= "" and group.titleLower:find(q, 1, true)
		local groupRows = {}
		for _, item in ipairs(group.items) do
			if item.prefix then
				-- Claim every bound action under this prefix (numbered families like
				-- "group set N") and list it by raw id, so they need no catalog entry
				-- per number.
				local matched = {}
				for action in pairs(working.byAction) do
					if action:sub(1, #item.prefix) == item.prefix then
						catalogActions[action] = true
						if q == "" or categoryMatch or action:lower():find(q, 1, true) then
							matched[#matched + 1] = action
						end
					end
				end
				table.sort(matched)
				for i = 1, #matched do
					groupRows[#groupRows + 1] = { type = "editable", action = matched[i], label = matched[i] }
				end
			else
				if item.action then
					catalogActions[item.action] = true
				end
				if q == "" or categoryMatch or item.labelLower:find(q, 1, true)
					or (item.actionLower and item.actionLower:find(q, 1, true)) then
					if item.action then
						groupRows[#groupRows + 1] = { type = "editable", action = item.action, label = item.label }
					else
						groupRows[#groupRows + 1] = { type = "info", label = item.label, keyText = item.keyText }
					end
				end
			end
		end

		if #groupRows > 0 then
			rows[#rows + 1] = { type = "header", text = group.title }
			for i = 1, #groupRows do
				rows[#rows + 1] = groupRows[i]
			end
		end
	end

	local otherMatch = q ~= "" and ("other"):find(q, 1, true)
	local others = {}
	for action in pairs(working.byAction) do
		if not catalogActions[action] and (q == "" or otherMatch or action:lower():find(q, 1, true)) then
			others[#others + 1] = action
		end
	end

	if #others > 0 then
		table.sort(others)
		rows[#rows + 1] = { type = "header", text = L.other }
		for _, action in ipairs(others) do
			rows[#rows + 1] = { type = "editable", action = action, label = action }
		end
	end

	clampScroll()
end

local function seedWorkingFromEngine()
	local model = keybindModel.build()
	working = { byAction = {}, layout = model.layout }
	for _, entry in ipairs(model.actions) do
		local copy = {}
		for _, k in ipairs(entry.keysets) do
			copy[#copy + 1] = { raw = k.raw, display = k.display }
		end
		working.byAction[entry.action] = copy
	end
end

-- Re-read the live bindings into this view (no disk write, no reload, no console
-- output) - used after each live edit.
local function reseed()
	seedWorkingFromEngine()
	rebuildRows()
end

-- Write pending Custom edits to uikeys.txt once; returns whether anything was written.
local function persistEdits()
	if not edited then
		return false
	end
	edited = false
	spSendCommands("keysave uikeys.txt")
	return true
end

switchPreset = function(opt)
	-- Mirror Settings: a non-destructive KeybindingFile switch. The first time
	-- Custom is chosen we seed uikeys.txt from the current binds (keysave), same
	-- as the Settings picker. reloadBindings re-reads the file into the engine
	-- and refreshes this view plus the other keybind-aware widgets.
	persistEdits() -- flush any live Custom edits before leaving

	local fromLabel = presetOptions[currentPresetIndex()].label
	local file = opt.file
	if file == "uikeys.txt" and not VFS.FileExists(file) then
		spSendCommands("keysave " .. file)
	end
	Spring.SetConfigString("KeybindingFile", file)
	if fromLabel ~= opt.label then
		Spring.Echo("Keybind preset: " .. fromLabel .. " -> " .. opt.label)
	end
	if menuToggle then
		menuToggle(opt.label)
	end
	if WG['bar_hotkeys'] and WG['bar_hotkeys'].reloadBindings then
		WG['bar_hotkeys'].reloadBindings()
	else
		view.refresh()
	end
end

local function ensureControls()
	if searchBox then
		return
	end

	searchBox = Editbox.new({ placeholder = Spring.I18N('ui.keybinds.editor.search'), onChange = rebuildRows })
	presetDropdown = Dropdown.new({ options = presetOptions, onSelect = switchPreset })
end

function view.init()
	font = WG['fonts'].getFont()
	RectRound = WG.FlowUI.Draw.RectRound
	Scroller = WG.FlowUI.Draw.Scroller
	ensureControls()
end

function view.refresh()
	ensureControls()
	seedWorkingFromEngine()
	resolvedCatalog = nil -- re-resolve labels (covers language change via the host's LanguageChanged)
	editable = Spring.GetConfigString("KeybindingFile", keyConfig.keybindingLayoutFiles[1]) == "uikeys.txt"
	presetDropdown:setSelected(currentPresetIndex())
	rebuildRows()
end

function view.setArea(x1, y1, x2, y2, s)
	ensureControls()
	area.x1, area.y1, area.x2, area.y2 = x1, y1, x2, y2
	scale = s or 1
	rowHeight = floor(22 * scale)
	hintH = floor(24 * scale)

	local pad = floor(6 * scale)
	local gap = floor(8 * scale)
	local headerH = floor(34 * scale)
	local rowTop = area.y2 - floor(4 * scale)
	local rowBottom = area.y2 - headerH + floor(4 * scale)
	local presetW = floor(160 * scale)
	local btnFs = (rowTop - rowBottom) * 0.5

	presetDropdown:setRect(area.x2 - presetW, rowBottom, area.x2, rowTop, btnFs)
	searchBox:setRect(area.x1, rowBottom, area.x2 - presetW - gap, rowTop, btnFs)

	listTop = area.y2 - headerH - floor(4 * scale)
	listRight = area.x2 - floor(12 * scale) - pad
	barX1 = listRight + floor(4 * scale)
	keyAreaX1 = area.x1 + floor((listRight - area.x1) * 0.45)

	clampScroll()
end

function view.blur()
	-- Persist accumulated edits and refresh the other keybind-aware widgets once,
	-- on the way out, instead of per keystroke.
	if persistEdits() and WG['bar_hotkeys'] and WG['bar_hotkeys'].reloadBindings then
		WG['bar_hotkeys'].reloadBindings()
	end
	if searchBox then searchBox:blur() end
	if presetDropdown then presetDropdown:close() end
	capturing = nil
end

function view.setMenuToggle(fn)
	menuToggle = fn
end

function view.isCapturing()
	return capturing ~= nil
end

-- True while the editor needs first crack at keypresses (search focus, key
-- capture, or an open dropdown), so the host can claim widgetHandler.textOwner
-- and stop keys from leaking to bound actions.
function view.wantsTextOwner()
	return (searchBox and searchBox:isFocused()) or capturing ~= nil
		or (presetDropdown and presetDropdown:isOpen())
end

-- Edits apply to the engine live (bind/unbind); the write to uikeys.txt and the
-- widget reload are deferred to persistEdits (panel close / preset switch), since
-- doing them per keystroke floods the console with keysave/keyreload output.
local function rebindKeyset(action, oldRaw, newKeyset)
	spSendCommands("unbind " .. oldRaw .. " " .. action)
	spSendCommands("bind " .. newKeyset .. " " .. action)
	edited = true
	reseed()
end

local function addKeyset(action, newKeyset)
	spSendCommands("bind " .. newKeyset .. " " .. action)
	edited = true
	reseed()
end

local function removeKeyset(action, raw)
	spSendCommands("unbind " .. raw .. " " .. action)
	edited = true
	reseed()
end

-- The engine allows one key to drive several actions (BAR relies on it for
-- context-dependent stacks, e.g. backspace = mutesound + edit_backspace), so a
-- new binding is added without disturbing other actions on the same keyset.
local function commitCapture(keyset)
	local c = capturing
	capturing = nil

	if c.oldRaw then
		rebindKeyset(c.action, c.oldRaw, keyset)
	else
		addKeyset(c.action, keyset)
	end
end

local function keysetFromPress(scanCode)
	local sym = scanCode and Spring.GetScanSymbol and Spring.GetScanSymbol(scanCode)
	if not sym or sym == "" then
		return nil
	end
	if sym:find("ctrl") or sym:find("alt") or sym:find("shift") or sym:find("meta") or sym:find("gui") then
		return nil
	end

	local alt, ctrl, _, shift = spGetModKeyState()
	local prefix = ""
	if alt then prefix = prefix .. "Alt+" end
	if ctrl then prefix = prefix .. "Ctrl+" end
	if shift then prefix = prefix .. "Shift+" end

	return prefix .. sym
end

local function fitText(text, maxWidth, size)
	if maxWidth <= 0 or font:GetTextWidth(text) * size <= maxWidth then
		return text
	end
	while #text > 1 and font:GetTextWidth(text .. "..") * size > maxWidth do
		text = text:sub(1, #text - 1)
	end
	return text .. ".."
end

local function drawRow(row, top, bottom, mx, my, fs, pad)
	local cyc = (top + bottom) * 0.5

	if row.type == "header" then
		RectRound(area.x1, bottom, listRight, top, 0, 0, 0, 0, 0, { 1, 1, 1, 0.05 }, { 1, 1, 1, 0.05 })
		font:Print(colorHeader .. row.text, area.x1 + pad, cyc, fs * 0.95, "ov")
		return
	end

	local capturingThis = capturing and capturing.action == row.action
	local hovered = editable and mx >= area.x1 and mx <= listRight and my <= top and my > bottom
	if capturingThis then
		RectRound(area.x1, bottom, listRight, top, 0, 0, 0, 0, 0, { 0.9, 0.7, 0.2, 0.18 }, { 0.9, 0.7, 0.2, 0.18 })
	elseif hovered then
		RectRound(area.x1, bottom, listRight, top, 0, 0, 0, 0, 0, { 1, 1, 1, 0.06 }, { 1, 1, 1, 0.06 })
	end

	font:Print(colorAction .. fitText(row.label, keyAreaX1 - (area.x1 + pad) - pad, fs), area.x1 + pad, cyc, fs, "ov")

	if row.type == "info" then
		font:Print(colorDim .. row.keyText, keyAreaX1, cyc, fs, "ov")
		return
	end

	if capturingThis then
		font:Print("\255\255\230\120" .. L.pressKey, keyAreaX1, cyc, fs, "ov")
		return
	end

	local c1, c2 = bottom + floor(3 * scale), top - floor(3 * scale)
	local cx = keyAreaX1
	local glyphW = floor(fs * 0.9)
	local addW = floor(fs + pad * 2)
	-- When editable, reserve room on the right so "+" always fits.
	local chipLimit = editable and (listRight - addW - floor(8 * scale)) or listRight

	for _, ks in ipairs(working.byAction[row.action] or {}) do
		local tw = font:GetTextWidth(ks.display) * fs
		local removeZone = editable and (pad + glyphW) or 0
		local chipW = pad + tw + removeZone
		if cx + chipW > chipLimit then
			break
		end

		if editable then
			local removeX1 = cx + chipW - removeZone
			local overRemove = mx >= removeX1 and mx <= cx + chipW and my >= c1 and my <= c2
			local overBody = mx >= cx and mx < removeX1 and my >= c1 and my <= c2
			RectRound(cx, c1, cx + chipW, c2, floor(3 * scale), 1, 1, 1, 1, { 0, 0, 0, overBody and 0.5 or 0.35 })
			font:Print(colorKey .. ks.display, cx + pad, cyc, fs, "ov")
			font:Print((overRemove and "\255\235\090\090" or colorDim) .. "x", removeX1 + removeZone * 0.5, cyc, fs, "cov")
		else
			RectRound(cx, c1, cx + chipW, c2, floor(3 * scale), 1, 1, 1, 1, { 0, 0, 0, 0.25 })
			font:Print(colorKey .. ks.display, cx + pad, cyc, fs, "ov")
		end

		cx = cx + chipW + floor(6 * scale)
	end

	if editable then
		local overAdd = mx >= cx and mx <= cx + addW and my >= c1 and my <= c2
		RectRound(cx, c1, cx + addW, c2, floor(3 * scale), 1, 1, 1, 1, { 0.2, 0.45, 0.25, overAdd and 0.6 or 0.4 })
		font:Print(colorText .. "+", (cx + cx + addW) * 0.5, cyc, fs, "cov")
	end
end

function view.draw()
	if not font then view.init() end
	if not working then view.refresh() end

	local mx, my, lmb = spGetMouseState()
	if dragging then
		if lmb then scrollFromY(my) else dragging = false end
	end

	local rowCount = visibleRows()
	local fs = rowHeight * 0.55
	local pad = floor(6 * scale)
	local lb = listBottom()

	font:Begin()
	for r = 1, rowCount do
		local row = rows[scroll + r]
		if not row then break end
		local top = listTop - (r - 1) * rowHeight
		drawRow(row, top, top - rowHeight, mx, my, fs, pad)
	end
	font:End()

	Scroller(barX1, lb, area.x2, listTop, #rows * rowHeight, scroll * rowHeight)

	searchBox:draw()
	presetDropdown:draw()

	if not editable then
		font:Begin()
		font:Print(colorDim .. L.customOnly, (area.x1 + area.x2) * 0.5, area.y1 + hintH * 0.5, fs, "cov")
		font:End()
	end
end

scrollFromY = function(y)
	local lb = listBottom()
	local f = (listTop - y) / math.max(1, listTop - lb)
	if f < 0 then f = 0 elseif f > 1 then f = 1 end
	scroll = floor(f * maxScroll() + 0.5)
	clampScroll()
end

function view.mouseWheel(up, value)
	local mx, my = spGetMouseState()
	if not (mx >= area.x1 and mx <= area.x2 and my >= listBottom() and my <= listTop) then
		return false
	end
	scroll = scroll + (up and -3 or 3)
	clampScroll()
	return true
end

-- Resolve which zone of an editable row a click hit. Mirrors drawRow's chip
-- layout (kept in sync) so we hit-test on demand instead of storing per-frame
-- rects. Returns kind ("rebind"/"remove"/"add") and the keyset, or nil.
local function hitTestRow(rowAction, x)
	local pad = floor(6 * scale)
	local fs = rowHeight * 0.55
	local glyphW = floor(fs * 0.9)
	local addW = floor(fs + pad * 2)
	local chipLimit = listRight - addW - floor(8 * scale)
	local cx = keyAreaX1

	for _, ks in ipairs(working.byAction[rowAction] or {}) do
		local chipW = pad + font:GetTextWidth(ks.display) * fs + pad + glyphW
		if cx + chipW > chipLimit then
			break
		end
		local removeX1 = cx + chipW - pad - glyphW
		if x >= cx and x < removeX1 then
			return "rebind", ks.raw
		elseif x >= removeX1 and x <= cx + chipW then
			return "remove", ks.raw
		end
		cx = cx + chipW + floor(6 * scale)
	end

	if x >= cx and x <= cx + addW then
		return "add"
	end
end

local function handleZone(kind, action, raw)
	if kind == "remove" then
		removeKeyset(action, raw)
	elseif kind == "add" then
		capturing = { action = action }
	elseif kind == "rebind" then
		local id = action .. "|" .. tostring(raw)
		local now = Spring.GetTimer and Spring.GetTimer()
		if now and lastClickId == id and lastClickTime and Spring.DiffTimers(now, lastClickTime) < 0.4 then
			capturing = { action = action, oldRaw = raw }
			lastClickTime = nil
		else
			lastClickId = id
			lastClickTime = now
		end
	end
end

function view.mousePress(x, y, button)
	if not (x >= area.x1 and x <= area.x2 and y >= area.y1 and y <= area.y2) then
		return false
	end

	-- Only the left button interacts; right/middle over the panel do nothing.
	if button ~= 1 then
		return true
	end

	local ddWasOpen = presetDropdown:isOpen()
	if presetDropdown:mousePress(x, y) then
		searchBox:blur()
		capturing = nil
		return true
	end
	if ddWasOpen then
		return true
	end

	if searchBox:mousePress(x, y) then
		capturing = nil
		return true
	end
	searchBox:blur()

	if x >= barX1 and x <= area.x2 and y >= listBottom() and y <= listTop then
		dragging = true
		scrollFromY(y)
		return true
	end

	-- Rows are editable only while on Custom; otherwise they are a read-only view.
	if editable and x >= area.x1 and x <= listRight and y >= listBottom() and y <= listTop then
		local r = floor((listTop - y) / rowHeight) + 1
		local row = rows[scroll + r]
		if row and row.type == "editable" then
			local kind, raw = hitTestRow(row.action, x)
			if kind then
				handleZone(kind, row.action, raw)
			end
		end
		return true
	end

	return true
end

function view.textInput(char)
	if searchBox and searchBox:isFocused() then
		return searchBox:textInput(char)
	end
	return false
end

function view.keyPress(key, scanCode)
	if capturing then
		if key == 27 then
			capturing = nil
		else
			local keyset = keysetFromPress(scanCode)
			if keyset then
				commitCapture(keyset)
			end
		end
		return true
	end

	if presetDropdown and presetDropdown:isOpen() then
		if key == 27 then presetDropdown:close() end
		return true
	end

	if searchBox and searchBox:isFocused() then
		return searchBox:keyPress(key)
	end

	return false
end

-- Fallback for engine keys whose press never reaches LuaUI (cameraflip, volume,
-- unit commands): capture on release. Only fires while still capturing - a normal
-- key already captured on its press. Modifiers are read at release time, so this
-- path records the combo only if the modifier is still held when the key is
-- released; that ambiguity is inherent (we never saw the press).
function view.keyRelease(key, scanCode)
	if not capturing then
		return false
	end

	local keyset = keysetFromPress(scanCode)
	if keyset then
		commitCapture(keyset)
	end

	return true
end

return view
