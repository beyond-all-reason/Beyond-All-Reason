-- Interactive view for the in-game keybind editor, hosted as the first tab of
-- the Keybind/Mouse Info panel. Immediate-mode, drawn live every frame.
--
-- Staging model: all edits mutate an in-memory working copy only; the engine's
-- real bindings are untouched until Save. Save applies the working copy
-- wholesale (unbindall + rebind) and persists; Discard reseeds from the
-- untouched engine, so discarded edits never took effect.

local keybindModel = VFS.Include("luaui/Include/keybind_model.lua")
local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")
local catalog = VFS.Include("luaui/configs/keybind_catalog.lua")
local Editbox = VFS.Include("luaui/Include/ui_editbox.lua")
local Dropdown = VFS.Include("luaui/Include/ui_dropdown.lua")

local view = {}

local floor = math.floor
local spGetMouseState = Spring.GetMouseState
local spGetModKeyState = Spring.GetModKeyState
local spSendCommands = Spring.SendCommands

local area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
local scale = 1
local rowHeight = 22
local listTop = 0
local barX1 = 0
local listRight = 0
local keyAreaX1 = 0
local footerH = 0

local rModalOk, rModalCancel, modalBox = {}, {}, {}
local rSave, rDiscard = {}, {}

local working -- display copy of the current bindings; edits mutate it, Save replays the deltas
local resolvedCatalog -- catalog with i18n labels resolved once (rebuilt on language change)
local L = {} -- editor UI strings, resolved once alongside the catalog
local rows = {} -- flat display list: { type=header|editable|info, ... }
local scroll = 0
local dragging = false
local dirty = false
local pendingOps = {}  -- ordered bind/unbind deltas to apply on Save
local pendingPreset    -- staged "reset to preset" target {label,file}, or nil
local confirmPreset
local capturing -- { action, oldRaw }
local lastClickTime, lastClickId

local resetOptions = {
	{ label = "Grid", file = keyConfig.keybindingPresets["Grid"] },
	{ label = "Legacy", file = keyConfig.keybindingPresets["Legacy"] },
}

local font
local RectRound, Scroller

local colorAction = "\255\210\210\205"
local colorKey = "\255\235\185\070"
local colorText = "\255\235\235\235"
local colorDim = "\255\160\160\160"
local colorHeader = "\255\255\200\130"

local searchBox, resetDropdown, menuToggle
local scrollFromY

local function inRect(r, x, y)
	return r.x1 and x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

local function listBottom()
	return dirty and (area.y1 + footerH) or area.y1
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

local function disp(raw)
	return keybindModel.displayKeyset(raw, working.layout)
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
			local label = Spring.I18N(item.label)
			g.items[#g.items + 1] = {
				action = item.action,
				actionLower = item.action and item.action:lower(),
				label = label,
				labelLower = label:lower(),
				keyText = item.keyLabel and Spring.I18N(item.keyLabel) or "",
			}
		end
		resolvedCatalog[#resolvedCatalog + 1] = g
	end

	L.other = Spring.I18N('ui.keybinds.editor.other')
	L.pressKey = Spring.I18N('ui.keybinds.editor.pressKey')
	L.unsaved = Spring.I18N('ui.keybinds.editor.unsaved')
	L.save = Spring.I18N('ui.keybinds.editor.save')
	L.discard = Spring.I18N('ui.keybinds.editor.discard')
	L.reset = Spring.I18N('ui.keybinds.editor.reset')
	L.cancel = Spring.I18N('ui.keybinds.editor.cancel')
	L.resetHint = Spring.I18N('ui.keybinds.editor.resetHint')
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
			if item.action then
				catalogActions[item.action] = true
			end
			if q == "" or categoryMatch or item.labelLower:find(q, 1, true)
				or (item.actionLower and item.actionLower:find(q, 1, true)) then
				groupRows[#groupRows + 1] = item
			end
		end

		if #groupRows > 0 then
			rows[#rows + 1] = { type = "header", text = group.title }
			for _, item in ipairs(groupRows) do
				if item.action then
					rows[#rows + 1] = { type = "editable", action = item.action, label = item.label }
				else
					rows[#rows + 1] = { type = "info", label = item.label, keyText = item.keyText }
				end
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

local function ensureControls()
	if searchBox then
		return
	end

	searchBox = Editbox.new({ placeholder = Spring.I18N('ui.keybinds.editor.search'), onChange = rebuildRows })
	resetDropdown = Dropdown.new({
		label = Spring.I18N('ui.keybinds.editor.resetToPreset'),
		options = resetOptions,
		onSelect = function(opt) confirmPreset = opt end,
	})
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
	pendingOps = {}
	pendingPreset = nil
	dirty = false
	rebuildRows()
end

function view.setArea(x1, y1, x2, y2, s)
	ensureControls()
	area.x1, area.y1, area.x2, area.y2 = x1, y1, x2, y2
	scale = s or 1
	rowHeight = floor(22 * scale)
	footerH = floor(36 * scale)

	local pad = floor(6 * scale)
	local gap = floor(8 * scale)
	local headerH = floor(34 * scale)
	local rowTop = area.y2 - floor(4 * scale)
	local rowBottom = area.y2 - headerH + floor(4 * scale)
	local resetW = floor(160 * scale)
	local btnFs = (rowTop - rowBottom) * 0.5

	resetDropdown:setRect(area.x2 - resetW, rowBottom, area.x2, rowTop, btnFs)
	searchBox:setRect(area.x1, rowBottom, area.x2 - resetW - gap, rowTop, btnFs)

	listTop = area.y2 - headerH - floor(4 * scale)
	listRight = area.x2 - floor(12 * scale) - pad
	barX1 = listRight + floor(4 * scale)
	keyAreaX1 = area.x1 + floor((listRight - area.x1) * 0.45)

	local boxW, boxH = floor(380 * scale), floor(150 * scale)
	local cx, cy = (area.x1 + area.x2) / 2, (area.y1 + area.y2) / 2
	modalBox = { x1 = cx - boxW / 2, y1 = cy - boxH / 2, x2 = cx + boxW / 2, y2 = cy + boxH / 2 }
	local bw, bh = floor(120 * scale), floor(32 * scale)
	rModalCancel = { x1 = modalBox.x2 - gap - bw, y1 = modalBox.y1 + gap, x2 = modalBox.x2 - gap, y2 = modalBox.y1 + gap + bh }
	rModalOk = { x1 = rModalCancel.x1 - gap - bw, y1 = modalBox.y1 + gap, x2 = rModalCancel.x1 - gap, y2 = modalBox.y1 + gap + bh }

	local fbw = floor(90 * scale)
	rSave = { x1 = area.x2 - pad - fbw, y1 = area.y1 + floor(4 * scale), x2 = area.x2 - pad, y2 = area.y1 + footerH - floor(4 * scale) }
	rDiscard = { x1 = rSave.x1 - gap - fbw, y1 = rSave.y1, x2 = rSave.x1 - gap, y2 = rSave.y2 }

	clampScroll()
end

function view.blur()
	if searchBox then searchBox:blur() end
	if resetDropdown then resetDropdown:close() end
	capturing = nil
	confirmPreset = nil
end

function view.setMenuToggle(fn)
	menuToggle = fn
end

-- True while the editor needs first crack at keypresses (search focus / key
-- capture), so the host can claim widgetHandler.textOwner and stop keys from
-- leaking to bound actions.
function view.wantsTextOwner()
	return (searchBox and searchBox:isFocused()) or capturing ~= nil
end

-- Edits update the working copy (for display) and record the bind/unbind delta.
-- Nothing touches the engine until Save replays the deltas. Recording deltas -
-- rather than unbind-all + rebind-everything on Save - leaves bindings we never
-- edited (chains, fakemeta, engine defaults) untouched.
local function rebindKeyset(action, oldRaw, newKeyset)
	local ks = working.byAction[action]
	if ks then
		for _, k in ipairs(ks) do
			if k.raw == oldRaw then
				k.raw = newKeyset
				k.display = disp(newKeyset)
				break
			end
		end
	end
	pendingOps[#pendingOps + 1] = { op = "unbind", keyset = oldRaw, action = action }
	pendingOps[#pendingOps + 1] = { op = "bind", keyset = newKeyset, action = action }
	dirty = true
	rebuildRows()
end

local function addKeyset(action, newKeyset)
	if not working.byAction[action] then
		working.byAction[action] = {}
	end
	local ks = working.byAction[action]
	ks[#ks + 1] = { raw = newKeyset, display = disp(newKeyset) }
	pendingOps[#pendingOps + 1] = { op = "bind", keyset = newKeyset, action = action }
	dirty = true
	rebuildRows()
end

local function removeKeyset(action, raw)
	local ks = working.byAction[action]
	if ks then
		for i = #ks, 1, -1 do
			if ks[i].raw == raw then
				table.remove(ks, i)
			end
		end
	end
	pendingOps[#pendingOps + 1] = { op = "unbind", keyset = raw, action = action }
	dirty = true
	rebuildRows()
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

local function stageReset(opt)
	-- Load the preset in the engine to capture its TRUE keyset (including the
	-- engine defaults the file itself doesn't list), snapshot it into the
	-- working copy, then revert - so the staged preview matches what Save will
	-- actually produce, and nothing stays applied.
	local currentFile = Spring.GetConfigString("KeybindingFile", "uikeys.txt")
	if not VFS.FileExists(currentFile) then
		currentFile = keyConfig.keybindingLayoutFiles[1] -- grid fallback, matches cmd_bar_hotkeys
	end
	spSendCommands("keyreload " .. opt.file)
	seedWorkingFromEngine()
	spSendCommands("keyreload " .. currentFile)

	pendingOps = {} -- a reset replaces any prior staged edits
	pendingPreset = opt
	dirty = true
	scroll = 0
	rebuildRows()
end

local function save()
	-- A staged reset is applied by loading the preset through the engine (faithful
	-- to its real keyset - chains, fakemeta, defaults), then replaying any edits
	-- made after the reset. A plain edit session just replays its deltas against
	-- the live bindings, leaving everything it never touched intact.
	if pendingPreset then
		Spring.SetConfigString("KeybindingFile", pendingPreset.file)
		spSendCommands("keyreload " .. pendingPreset.file)
		if menuToggle then
			menuToggle(pendingPreset.label)
		end
	end

	for _, o in ipairs(pendingOps) do
		spSendCommands(o.op .. " " .. o.keyset .. " " .. o.action)
	end

	spSendCommands("keysave uikeys.txt")
	Spring.SetConfigString("KeybindingFile", "uikeys.txt")

	pendingOps = {}
	pendingPreset = nil
	dirty = false

	if WG['bar_hotkeys'] and WG['bar_hotkeys'].reloadBindings then
		WG['bar_hotkeys'].reloadBindings()
	else
		view.refresh()
	end
end

local function discard()
	view.refresh()
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

local function drawButton(r, label, hovered, fs, tint)
	tint = tint or { 0, 0, 0 }
	RectRound(r.x1, r.y1, r.x2, r.y2, floor(3 * scale), 1, 1, 1, 1, { tint[1], tint[2], tint[3], hovered and 0.7 or 0.45 })
	font:Print(colorText .. label, (r.x1 + r.x2) / 2, (r.y1 + r.y2) / 2, fs, "cov")
end

local function drawRow(row, top, bottom, mx, my, fs, pad)
	local cyc = (top + bottom) * 0.5

	if row.type == "header" then
		RectRound(area.x1, bottom, listRight, top, 0, 0, 0, 0, 0, { 1, 1, 1, 0.05 }, { 1, 1, 1, 0.05 })
		font:Print(colorHeader .. row.text, area.x1 + pad, cyc, fs * 0.95, "ov")
		return
	end

	local capturingThis = capturing and capturing.action == row.action
	local hovered = mx >= area.x1 and mx <= listRight and my <= top and my > bottom
	if capturingThis then
		RectRound(area.x1, bottom, listRight, top, 0, 0, 0, 0, 0, { 0.9, 0.7, 0.2, 0.18 }, { 0.9, 0.7, 0.2, 0.18 })
	elseif hovered then
		RectRound(area.x1, bottom, listRight, top, 0, 0, 0, 0, 0, { 1, 1, 1, 0.06 }, { 1, 1, 1, 0.06 })
	end

	font:Print(colorAction .. fitText(row.label, keyAreaX1 - (area.x1 + pad) - pad, fs), area.x1 + pad, cyc, fs, "ov")

	if row.type == "info" then
		font:Print(colorDim .. row.keyText, listRight - pad, cyc, fs, "ovr")
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
	local chipLimit = listRight - addW - floor(8 * scale) -- reserve room so "+" always fits

	for _, ks in ipairs(working.byAction[row.action] or {}) do
		local tw = font:GetTextWidth(ks.display) * fs
		local removeZone = pad + glyphW
		local chipW = pad + tw + removeZone
		if cx + chipW > chipLimit then
			break
		end

		local removeX1 = cx + chipW - removeZone
		local overRemove = mx >= removeX1 and mx <= cx + chipW and my >= c1 and my <= c2
		local overBody = mx >= cx and mx < removeX1 and my >= c1 and my <= c2

		RectRound(cx, c1, cx + chipW, c2, floor(3 * scale), 1, 1, 1, 1, { 0, 0, 0, overBody and 0.5 or 0.35 })
		font:Print(colorKey .. ks.display, cx + pad, cyc, fs, "ov")
		font:Print((overRemove and "\255\235\090\090" or colorDim) .. "x", removeX1 + removeZone * 0.5, cyc, fs, "cov")

		cx = cx + chipW + floor(6 * scale)
	end

	local overAdd = mx >= cx and mx <= cx + addW and my >= c1 and my <= c2
	RectRound(cx, c1, cx + addW, c2, floor(3 * scale), 1, 1, 1, 1, { 0.2, 0.45, 0.25, overAdd and 0.6 or 0.4 })
	font:Print(colorText .. "+", (cx + cx + addW) * 0.5, cyc, fs, "cov")
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
	resetDropdown:draw()

	if dirty then
		local btnFs = (rSave.y2 - rSave.y1) * 0.45
		RectRound(area.x1, area.y1, area.x2, area.y1 + footerH, 0, 0, 0, 0, 0, { 0.1, 0.1, 0.1, 0.9 }, { 0.1, 0.1, 0.1, 0.9 })
		font:Begin()
		font:Print("\255\255\220\120" .. L.unsaved, area.x1 + pad, area.y1 + footerH * 0.5, btnFs, "ov")
		drawButton(rDiscard, L.discard, inRect(rDiscard, mx, my), btnFs, { 0.3, 0.1, 0.1 })
		drawButton(rSave, L.save, inRect(rSave, mx, my), btnFs, { 0.15, 0.35, 0.18 })
		font:End()
	end

	if confirmPreset then
		local btnFs = (rModalOk.y2 - rModalOk.y1) * 0.45
		RectRound(area.x1, area.y1, area.x2, area.y2, 0, 0, 0, 0, 0, { 0, 0, 0, 0.6 }, { 0, 0, 0, 0.6 })
		RectRound(modalBox.x1, modalBox.y1, modalBox.x2, modalBox.y2, floor(4 * scale), 1, 1, 1, 1, { 0.13, 0.13, 0.13, 0.97 })
		local mfs = 15 * scale
		local mcx = (modalBox.x1 + modalBox.x2) / 2
		font:Begin()
		font:Print(colorText .. Spring.I18N('ui.keybinds.editor.resetConfirm', { preset = confirmPreset.label }), mcx, modalBox.y2 - floor(46 * scale), mfs, "cov")
		font:Print(colorDim .. L.resetHint, mcx, modalBox.y2 - floor(74 * scale), mfs * 0.85, "cov")
		drawButton(rModalOk, L.reset, inRect(rModalOk, mx, my), btnFs, { 0.15, 0.3, 0.4 })
		drawButton(rModalCancel, L.cancel, inRect(rModalCancel, mx, my), btnFs)
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
	if confirmPreset or not (mx >= area.x1 and mx <= area.x2 and my >= listBottom() and my <= listTop) then
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

	if confirmPreset then
		if inRect(rModalOk, x, y) then
			stageReset(confirmPreset)
			confirmPreset = nil
		elseif inRect(rModalCancel, x, y) then
			confirmPreset = nil
		end
		return true
	end

	local ddWasOpen = resetDropdown:isOpen()
	if resetDropdown:mousePress(x, y) then
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

	if dirty then
		if inRect(rSave, x, y) then save() return true end
		if inRect(rDiscard, x, y) then discard() return true end
	end

	if x >= barX1 and x <= area.x2 and y >= listBottom() and y <= listTop then
		dragging = true
		scrollFromY(y)
		return true
	end

	if x >= area.x1 and x <= listRight and y >= area.y1 and y <= listTop then
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

	if confirmPreset then
		if key == 27 then confirmPreset = nil end
		return true
	end

	if resetDropdown and resetDropdown:isOpen() and key == 27 then
		resetDropdown:close()
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
