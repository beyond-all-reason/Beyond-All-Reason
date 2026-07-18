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

local working
local resolvedCatalog
local L = {}
local rows = {}
local scroll = 0
local dragging = false
local editable = false -- true only on Custom (uikeys.txt)
local capturing
local captureAny = false -- pending capture binds with the Any+ (match-any-modifier) qualifier
local captureAnyRect -- clickable rect of the Any checkbox while capturing
local pendingReset
local edited = false
local lastClickTime, lastClickId

local font
local RectRound, Scroller, UiButton, UiElement, Highlight

local colorAction = "\255\210\210\205"
local colorKey = "\255\235\185\070"
local colorText = "\255\235\235\235"
local colorDim = "\255\160\160\160"
local colorHeader = "\255\255\200\130"

local searchBox, presetDropdown, resetDropdown, menuToggle
local switchPreset, scrollFromY, resetToPreset

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

local resetOptions = {}
for i = 1, #presetOptions do
	if presetOptions[i].file ~= "uikeys.txt" then
		resetOptions[#resetOptions + 1] = presetOptions[i]
	end
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

-- Resolve i18n labels once (search rebuilds rows per keystroke); redone on refresh.
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
	L.anyMod = Spring.I18N('ui.keybinds.editor.anyMod')
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
				-- Claim every bound action under this prefix, listed by raw id.
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

local function reseed()
	seedWorkingFromEngine()
	rebuildRows()
end

local function persistEdits()
	if not edited then
		return false
	end
	edited = false
	spSendCommands("keysave uikeys.txt")
	return true
end

switchPreset = function(opt)
	-- Non-destructive KeybindingFile switch; first pick of Custom seeds uikeys.txt.
	persistEdits()

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

-- Reset Custom to a clean copy of a shipped preset: load that preset live, dump it
-- over uikeys.txt, then reload as Custom. Discards pending Custom edits by design.
resetToPreset = function(opt)
	edited = false
	Spring.SetConfigString("KeybindingFile", opt.file)
	if WG['bar_hotkeys'] and WG['bar_hotkeys'].reloadBindings then
		WG['bar_hotkeys'].reloadBindings()
	end
	spSendCommands("keysave uikeys.txt")
	Spring.SetConfigString("KeybindingFile", "uikeys.txt")
	if WG['bar_hotkeys'] and WG['bar_hotkeys'].reloadBindings then
		WG['bar_hotkeys'].reloadBindings()
	end
	Spring.Echo("Keybind custom reset from preset: " .. opt.label)
	view.refresh()
end

local function ensureControls()
	if searchBox then
		return
	end

	searchBox = Editbox.new({ placeholder = Spring.I18N('ui.keybinds.editor.search'), onChange = rebuildRows })
	presetDropdown = Dropdown.new({ options = presetOptions, onSelect = switchPreset })
	resetDropdown = Dropdown.new({ options = resetOptions, placeholder = Spring.I18N('ui.keybinds.editor.reset'), onSelect = function(opt) pendingReset = opt end })
end

local function layoutHeader()
	if not presetDropdown then
		return
	end

	local gap = floor(8 * scale)
	local headerH = floor(34 * scale)
	local rowTop = area.y2 - floor(4 * scale)
	local rowBottom = area.y2 - headerH + floor(4 * scale)
	local presetW = floor(160 * scale)
	local btnFs = (rowTop - rowBottom) * 0.5

	presetDropdown:setRect(area.x2 - presetW, rowBottom, area.x2, rowTop, btnFs)

	local searchRight = area.x2 - presetW - gap
	if editable then
		local resetW = floor(150 * scale)
		resetDropdown:setRect(searchRight - resetW, rowBottom, searchRight, rowTop, btnFs)
		searchRight = searchRight - resetW - gap
	end
	searchBox:setRect(area.x1, rowBottom, searchRight, rowTop, btnFs)
end

-- Confirm-modal box + button rects, recomputed so draw and mousePress agree.
local function confirmGeometry()
	local w = floor(360 * scale)
	local h = floor(104 * scale)
	local cx = (area.x1 + area.x2) * 0.5
	local cy = (area.y1 + area.y2) * 0.5
	local bx1, bx2 = floor(cx - w * 0.5), floor(cx + w * 0.5)
	local by1, by2 = floor(cy - h * 0.5), floor(cy + h * 0.5)
	local bw = floor(120 * scale)
	local bh = floor(28 * scale)
	local pad = floor(16 * scale)
	local btnY1 = by1 + pad
	local cancel = { bx1 + pad, btnY1, bx1 + pad + bw, btnY1 + bh }
	local ok = { bx2 - pad - bw, btnY1, bx2 - pad, btnY1 + bh }
	return bx1, by1, bx2, by2, ok, cancel
end

function view.init()
	font = WG['fonts'].getFont()
	RectRound = WG.FlowUI.Draw.RectRound
	Scroller = WG.FlowUI.Draw.Scroller
	UiButton = WG.FlowUI.Draw.Button
	UiElement = WG.FlowUI.Draw.Element
	Highlight = WG.FlowUI.Draw.SelectHighlight
	ensureControls()
end

function view.refresh()
	ensureControls()
	seedWorkingFromEngine()
	resolvedCatalog = nil
	editable = Spring.GetConfigString("KeybindingFile", keyConfig.keybindingLayoutFiles[1]) == "uikeys.txt"
	presetDropdown:setSelected(currentPresetIndex())
	if not editable then
		resetDropdown:close()
	end
	layoutHeader()
	rebuildRows()
end

function view.setArea(x1, y1, x2, y2, s)
	ensureControls()
	area.x1, area.y1, area.x2, area.y2 = x1, y1, x2, y2
	scale = s or 1
	rowHeight = floor(22 * scale)
	hintH = floor(24 * scale)

	local pad = floor(6 * scale)
	local headerH = floor(34 * scale)

	layoutHeader()

	listTop = area.y2 - headerH - floor(4 * scale)
	listRight = area.x2 - floor(12 * scale) - pad
	barX1 = listRight + floor(4 * scale)
	keyAreaX1 = area.x1 + floor((listRight - area.x1) * 0.45)

	clampScroll()
end

function view.blur()
	-- Flush edits and reload once on the way out, not per keystroke.
	if persistEdits() and WG['bar_hotkeys'] and WG['bar_hotkeys'].reloadBindings then
		WG['bar_hotkeys'].reloadBindings()
	end
	if searchBox then
		searchBox:setText("") -- clear the filter so the list is unfiltered on reopen
		searchBox:blur()
	end
	if presetDropdown then presetDropdown:close() end
	if resetDropdown then resetDropdown:close() end
	capturing = nil
	pendingReset = nil
end

function view.setMenuToggle(fn)
	menuToggle = fn
end

function view.isCapturing()
	return capturing ~= nil
end

-- True while the editor needs keys first (search, capture, open dropdown), so the
-- host claims textOwner and keys don't leak to bound actions.
function view.wantsTextOwner()
	return (searchBox and searchBox:isFocused()) or capturing ~= nil
		or (presetDropdown and presetDropdown:isOpen())
		or (resetDropdown and resetDropdown:isOpen())
		or pendingReset ~= nil
end

-- Edits apply live (bind/unbind); the uikeys.txt write + reload defer to persistEdits
-- (panel close / preset switch) to avoid per-keystroke console spam.

-- Compared by displayed key, not raw, so a scancode capture of a key already bound
-- in keysym form (Enter vs "return") dedupes. exceptRaw skips the keyset being rebound.
local function actionHasKeyset(action, newKeyset, exceptRaw)
	local ks = working.byAction[action]
	if not ks then
		return false
	end
	local d = keybindModel.displayKeyset(newKeyset, working.layout)
	for _, k in ipairs(ks) do
		if k.raw ~= exceptRaw and k.display == d then
			return true
		end
	end
	return false
end

local function rebindKeyset(action, oldRaw, newKeyset)
	spSendCommands("unbind " .. oldRaw .. " " .. action)
	if not actionHasKeyset(action, newKeyset, oldRaw) then
		spSendCommands("bind " .. newKeyset .. " " .. action)
	end
	edited = true
	reseed()
end

local function addKeyset(action, newKeyset)
	if actionHasKeyset(action, newKeyset) then
		return
	end
	spSendCommands("bind " .. newKeyset .. " " .. action)
	edited = true
	reseed()
end

local function removeKeyset(action, raw)
	spSendCommands("unbind " .. raw .. " " .. action)
	edited = true
	reseed()
end

-- One key can drive several actions (e.g. backspace = mutesound + edit_backspace),
-- so add the binding without disturbing others on the same keyset.
local function commitCapture(keyset)
	local c = capturing
	capturing = nil

	if c.oldRaw then
		rebindKeyset(c.action, c.oldRaw, keyset)
	else
		addKeyset(c.action, keyset)
	end
end

local function rawHasAny(raw)
	return raw ~= nil and raw:find("[Aa][Nn][Yy]%+") ~= nil
end

local function modPrefix()
	local alt, ctrl, _, shift = spGetModKeyState()
	local prefix = ""
	if alt then prefix = prefix .. "Alt+" end
	if ctrl then prefix = prefix .. "Ctrl+" end
	if shift then prefix = prefix .. "Shift+" end

	return prefix
end

local function keysetFromPress(scanCode)
	local sym = scanCode and Spring.GetScanSymbol and Spring.GetScanSymbol(scanCode)
	if not sym or sym == "" then
		return nil
	end
	if sym:find("ctrl") or sym:find("alt") or sym:find("shift") or sym:find("meta") or sym:find("gui") then
		return nil
	end

	return (captureAny and "Any+" or modPrefix()) .. sym
end

-- Side buttons bind as ordinary "mouseN" keysets; only button >= 4 reaches here.
local function mouseKeysetFromButton(button)
	return (captureAny and "Any+" or modPrefix()) .. "mouse" .. button
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

		-- Any-modifier checkbox, right-aligned; toggled by mouse click (keypresses are
		-- captured as the binding, so it can't be keyboard-toggled).
		local boxS = floor(fs)
		local gap2 = floor(4 * scale)
		local bx2 = listRight - pad
		local bx1 = bx2 - boxS
		local labelX = bx1 - gap2 - font:GetTextWidth(L.anyMod) * fs
		local by1 = cyc - boxS * 0.5
		local by2 = cyc + boxS * 0.5
		RectRound(bx1, by1, bx2, by2, floor(2 * scale), 1, 1, 1, 1,
			captureAny and { 0.9, 0.7, 0.2, 0.95 } or { 1, 1, 1, 0.12 })
		font:Print(colorText .. L.anyMod, labelX, cyc, fs, "ov")
		captureAnyRect = { labelX, by1, bx2, by2 }
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
		-- Read-only chips reserve matching padding so the bg isn't flush against text.
		local rightGap = editable and (pad + glyphW) or pad
		local chipW = pad + tw + rightGap
		if cx + chipW > chipLimit then
			break
		end

		if editable then
			local removeX1 = cx + chipW - rightGap
			local overRemove = mx >= removeX1 and mx <= cx + chipW and my >= c1 and my <= c2
			local overBody = mx >= cx and mx < removeX1 and my >= c1 and my <= c2
			RectRound(cx, c1, cx + chipW, c2, floor(3 * scale), 1, 1, 1, 1, { 0, 0, 0, overBody and 0.5 or 0.35 })
			font:Print(colorKey .. ks.display, cx + pad, cyc, fs, "ov")
			font:Print((overRemove and "\255\235\090\090" or colorDim) .. "x", removeX1 + rightGap * 0.5, cyc, fs, "cov")
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
	if editable then
		resetDropdown:draw()
	end

	if not editable then
		font:Begin()
		font:Print(colorDim .. L.customOnly, (area.x1 + area.x2) * 0.5, area.y1 + hintH * 0.5, fs, "cov")
		font:End()
	end

	if pendingReset then
		local bx1, by1, bx2, by2, ok, cancel = confirmGeometry()
		local cs = floor(6 * scale)

		RectRound(area.x1, area.y1, area.x2, area.y2, 0, 0, 0, 0, 0, { 0, 0, 0, 0.55 })
		UiElement(bx1, by1, bx2, by2, 1, 1, 1, 1, 1, 1, 1, 1, WG.FlowUI.clampedOpacity)
		UiButton(cancel[1], cancel[2], cancel[3], cancel[4])
		UiButton(ok[1], ok[2], ok[3], ok[4])
		if mx >= cancel[1] and mx <= cancel[3] and my >= cancel[2] and my <= cancel[4] then
			Highlight(cancel[1], cancel[2], cancel[3], cancel[4], cs, 1, { 1, 1, 1 })
		end
		if mx >= ok[1] and mx <= ok[3] and my >= ok[2] and my <= ok[4] then
			Highlight(ok[1], ok[2], ok[3], ok[4], cs, 1, { 1, 1, 1 })
		end

		local cx = (bx1 + bx2) * 0.5
		local tfs = floor(rowHeight * 0.6)
		local sfs = floor(rowHeight * 0.5)
		font:Begin()
		font:Print(colorText .. "Reset keybinds to " .. pendingReset.label .. "?", cx, by2 - floor(26 * scale), tfs, "cov")
		font:Print(colorDim .. "Overwrites your current custom binds.", cx, by2 - floor(48 * scale), sfs, "cov")
		font:Print(colorText .. "Cancel", (cancel[1] + cancel[3]) * 0.5, (cancel[2] + cancel[4]) * 0.5, sfs, "cov")
		font:Print(colorText .. "Reset", (ok[1] + ok[3]) * 0.5, (ok[2] + ok[4]) * 0.5, sfs, "cov")
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

-- Which zone of an editable row a click hit; mirrors drawRow's chip layout.
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
		captureAny = false
	elseif kind == "rebind" then
		local id = action .. "|" .. tostring(raw)
		local now = Spring.GetTimer and Spring.GetTimer()
		if now and lastClickId == id and lastClickTime and Spring.DiffTimers(now, lastClickTime) < 0.4 then
			capturing = { action = action, oldRaw = raw }
			captureAny = rawHasAny(raw)
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

	if pendingReset then
		if button == 1 then
			local bx1, by1, bx2, by2, ok, cancel = confirmGeometry()
			if x >= ok[1] and x <= ok[3] and y >= ok[2] and y <= ok[4] then
				local opt = pendingReset
				pendingReset = nil
				resetToPreset(opt)
			elseif (x >= cancel[1] and x <= cancel[3] and y >= cancel[2] and y <= cancel[4])
				or x < bx1 or x > bx2 or y < by1 or y > by2 then
				pendingReset = nil
			end
		end
		return true
	end

	-- While capturing, only side buttons (mouse4+) bind: mouse1 is engine-rejected,
	-- mouse2/mouse3 are reserved for camera/order UX. Left click cancels.
	if capturing then
		if button == 1 and captureAnyRect
			and x >= captureAnyRect[1] and x <= captureAnyRect[3]
			and y >= captureAnyRect[2] and y <= captureAnyRect[4] then
			captureAny = not captureAny
			return true
		end
		if button >= 4 then
			commitCapture(mouseKeysetFromButton(button))
		elseif button == 1 then
			capturing = nil
		end
		return true
	end

	if button ~= 1 then
		return true
	end

	local ddWasOpen = presetDropdown:isOpen()
	if presetDropdown:mousePress(x, y) then
		resetDropdown:close()
		searchBox:blur()
		capturing = nil
		return true
	end
	if ddWasOpen then
		return true
	end

	if editable then
		local rdWasOpen = resetDropdown:isOpen()
		if resetDropdown:mousePress(x, y) then
			presetDropdown:close()
			searchBox:blur()
			capturing = nil
			return true
		end
		if rdWasOpen then
			return true
		end
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
	if pendingReset then
		if key == 27 then
			pendingReset = nil
		elseif key == 13 then
			local opt = pendingReset
			pendingReset = nil
			resetToPreset(opt)
		end
		return true
	end

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

	if resetDropdown and resetDropdown:isOpen() then
		if key == 27 then resetDropdown:close() end
		return true
	end

	if searchBox and searchBox:isFocused() then
		return searchBox:keyPress(key)
	end

	return false
end

-- Fallback for engine keys whose press never reaches LuaUI (cameraflip, volume):
-- capture on release. Modifiers are read at release, so a held combo is ambiguous.
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
