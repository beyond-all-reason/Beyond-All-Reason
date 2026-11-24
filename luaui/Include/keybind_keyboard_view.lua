-- The keyboard page of the keybind editor as FlowUI draws it: functions over the model's keybind_keyboard.

local keyConfig = require("luaui/configs/keyboard_layouts")
local text = require("luaui/Include/keybind_text")

local floor = math.floor
local max = math.max
local min = math.min
local glColor = gl.Color
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glBlending = gl.Blending

local View = {}

-- The font and the FlowUI entry points, which do not exist at include time.
---@type table
local font
---@type function
local UiKey
---@type function?
local UiButton
---@type function?
local Highlight

-- The order the engine writes them, which is the order a layer caption reads.
local modifierNames = {}
for i, name in ipairs(keyConfig.modifierOrder) do
	modifierNames[i] = name:lower()
end

----------------------------------------------------------------
-- Colours and sizes
----------------------------------------------------------------

local colorText = "\255\235\235\235"
local colorDim = "\255\160\160\160"
local colorKey = "\255\235\185\070"

local look = {
	-- Bound, nothing on this layer, modifier at rest, modifier showing, and found by search.
	bound = { 0.22, 0.22, 0.22, 1 },
	unbound = { 0.16, 0.16, 0.16, 1 },
	modifier = { 0.28, 0.28, 0.28, 1 },
	modifierActive = { 0.8, 0.8, 0.78, 1 },
	hit = { 0.5, 0.4, 0.16, 1 },
	-- A key the search did not find sinks into the panel so the found ones stand out.
	missOpacity = 0.4,
	-- Text on a dark cap, and on the light cap of an active modifier.
	name = "\255\200\200\200",
	nameOnLight = "\255\40\40\40",
	shifted = "\255\125\125\125",
	shiftedOnLight = "\255\110\110\110",
	labelOnLight = "\255\30\30\30",
	-- The Shift half of a paired order, which does what the key does without Shift.
	paired = "\255\150\150\150",
	more = colorKey,
	iconAlpha = 0.85,
	pairedIconAlpha = 0.45,
	caption = colorText,
	captionMods = colorKey,
	hint = colorDim,
	-- The view toggle: a button like the header's, pressed while the number pad is showing.
	buttonFill = { 0.18, 0.18, 0.18, 1 },
	buttonFillActive = { 0.33, 0.33, 0.33, 1 },
	buttonFillHover = { 0.4, 0.4, 0.4, 1 },
	buttonText = colorText,
	buttonHoverOpacity = 0.25,
	white = { 1, 1, 1 },
	-- The font is shared with every other widget, some of which set an outline of their own.
	outline = { 0, 0, 0, 0.4 },
}

-- Each fill becomes a darker bottom and itself on top, the shape the other buttons take.
look.gradients = setmetatable({}, {
	__index = function(self, fill)
		local pair = {
			{ fill[1] * 0.55, fill[2] * 0.55, fill[3] * 0.55, fill[4] or 1 },
			{ fill[1], fill[2], fill[3], fill[4] or 1 },
		}
		self[fill] = pair

		return pair
	end,
})

-- So a key action reads as the kind of thing it is at a glance.
local categoryColors = {
	["categories.selection"] = "\255\150\205\255",
	["categories.orders"] = colorText,
	["categories.queues"] = "\255\255\190\120",
	["categories.unitStates"] = "\255\170\230\150",
	["categories.controlGroups"] = "\255\120\190\255",
	["categories.buildHotkeys"] = "\255\255\225\120",
	["categories.gridMenu"] = "\255\255\225\120",
	["categories.blueprints"] = "\255\200\170\255",
	["categories.camera"] = "\255\255\215\130",
	["categories.mapViews"] = "\255\150\230\220",
	["categories.interfaceDisplay"] = "\255\220\220\220",
	["categories.drawing"] = "\255\255\170\200",
	["categories.sound"] = "\255\190\200\230",
	["categories.gameControl"] = "\255\255\150\150",
}

-- Called again on a resize: a new font measures differently, so what was measured is redone.
function View.init(kb, f)
	font = f
	UiKey = WG.FlowUI.Draw.Key
	UiButton = WG.FlowUI.Draw.Button
	Highlight = WG.FlowUI.Draw.SelectHighlight
	kb.layoutGen = kb.layoutGen + 1
end

----------------------------------------------------------------
-- Drawing
----------------------------------------------------------------

-- Smaller when the name is wider than the face. Measured once per name and size.
local function nameSize(kb, key, room)
	if key.nameFsGen == kb.layoutGen and key.nameFsLabel == key.label and key.nameFsRoom == room then
		return key.nameFsFit
	end
	local size = kb.nameFs
	local width = font:GetTextWidth(key.label) * size
	if width > room and width > 0 then
		size = max(floor(size * 0.6), floor(size * room / width))
	end
	key.nameFsFit, key.nameFsGen, key.nameFsLabel, key.nameFsRoom = size, kb.layoutGen, key.label, room

	return size
end

-- Kept until the bindings or the geometry change.
local function faceLines(kb, key, layer, faceW, maxLines)
	-- Asked for before the cache is read: a placement this is stale for rebuilds the show table.
	local first = kb:faceEntry(key, layer)
	local show = key.show[layer]
	if show.lines and show.linesGen == kb.layoutGen and show.linesMax == maxLines then
		return show.lines, show.first
	end
	local lines = {}
	if first then
		local info = kb:infoOf(first)
		local label = info.label or first.action
		local fs = kb.labelFs
		local wrapped = text.wrap(font, label, faceW, fs)
		if #wrapped > maxLines then
			-- The last line that fits takes the rest of the label, shortened to the face.
			local rest = {}
			for i = maxLines, #wrapped do
				rest[#rest + 1] = wrapped[i]
			end
			wrapped[maxLines] = table.concat(rest, " ")
			for i = #wrapped, maxLines + 1, -1 do
				wrapped[i] = nil
			end
		end
		for i, line in ipairs(wrapped) do
			lines[i] = text.fit(font, line, faceW, fs)
		end
	end
	show.lines, show.first, show.linesGen, show.linesMax = lines, first, kb.layoutGen, maxLines

	return lines, first
end

-- The caption's hint, wrapped to the room left of the caption once per size, language and placement.
local hint = {}
local function hintFor(kb, width)
	local L = kb.L
	if
		hint.lines
		and hint.width == width
		and hint.gen == kb.gen
		and hint.layoutGen == kb.layoutGen
		and hint.text == L.hint
	then
		return hint.lines
	end
	local lines = text.wrap(font, L.hint or "", width, kb.hintFs)
	if kb.unplaced > 0 then
		local note = BAR.I18N("ui.keybinds.keyboard.notShown", { n = kb.unplaced })
		for _, line in ipairs(text.wrap(font, note, width, kb.hintFs)) do
			lines[#lines + 1] = line
		end
	end
	for i = 4, #lines do
		lines[i] = nil
	end
	for i, line in ipairs(lines) do
		lines[i] = text.fit(font, line, width, kb.hintFs)
	end
	hint.lines, hint.width, hint.gen, hint.layoutGen, hint.text = lines, width, kb.gen, kb.layoutGen, L.hint

	return lines
end

-- Called inside the host display list, so all of it has to be geometry and text.
function View.draw(kb, hoverIdx)
	if not font or not UiKey or not kb.unit then
		return
	end
	local mods = kb:activeMods()
	local layer = kb:layer()
	local unit, pad, cs = kb.unit, kb.pad, kb.cs
	local padY = kb.padY
	local searching = not kb.query.empty
	local nameLineH = floor(kb.nameFs * 1.12)
	local lineH = floor(kb.labelFs * 1.1)
	local prints = {}
	local function print(str, x, y, size, opts)
		prints[#prints + 1] = { str, x, y, size, opts }
	end

	-- Caps and pictures first, words after, in one font batch.
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	for _, i in ipairs(kb.shown) do
		local key = kb.keys[i] --[[@as table]]
		local entries = kb:entries(key, layer)
		local active = key.mod and mods[key.mod]
		local hit = searching and kb:matches(key, entries)
		local fill = (active and look.modifierActive)
			or (hit and look.hit)
			or (key.mod and look.modifier)
			or (entries[1] and look.bound)
			or look.unbound
		local opacity = (searching and not hit and not active) and look.missOpacity or 1
		local fx1, fy1, fx2, fy2 = UiKey(key.x1, key.y1, key.x2, key.y2, cs, fill, active, hoverIdx == i, opacity)
		local light = active
		local faceW = fx2 - fx1 - pad * 2
		-- Dark text on a light cap takes none, an outline there being a dark ring round dark letters.
		local oLeft, oCentre, oRight = "o", "co", "ro"
		if light then
			oLeft, oCentre, oRight = "", "c", "r"
		end

		-- The symbol Shift makes of it sits beside, dimmer.
		local nameFs = nameSize(kb, key, faceW)
		local nameTop = fy2 - padY
		local nameY = text.baseline(font, nameTop - nameLineH, nameTop, nameFs)
		print((light and look.nameOnLight or look.name) .. key.label, fx1 + pad, nameY, nameFs, oLeft)
		if key.shiftedLabel then
			local nameW = floor(font:GetTextWidth(key.label) * nameFs)
			print(
				(light and look.shiftedOnLight or look.shifted) .. key.shiftedLabel,
				fx1 + pad + nameW + floor(pad * 0.8),
				nameY,
				nameFs,
				oLeft
			)
		end

		-- The last line may reach into the bottom padding; a label seldom has a descender there.
		local bandTop = nameTop - nameLineH
		local bandBottom = fy1 + floor(padY * 0.5)
		local maxLines = min(3, max(1, floor((bandTop - bandBottom) / lineH)))
		local lines, first = faceLines(kb, key, layer, faceW, maxLines)
		-- The count of further actions sits left of the picture when there is one.
		local cornerX = fx2 - pad
		if first then
			local info = kb:infoOf(first)
			local color = light and look.labelOnLight
				or (first.paired and look.paired)
				or categoryColors[info.category or ""]
				or colorText
			local n = #lines
			local blockTop = floor((bandTop + bandBottom + n * lineH) * 0.5)
			local cx = floor((fx1 + fx2) * 0.5)
			for li = 1, n do
				local top = blockTop - (li - 1) * lineH
				local ly = text.baseline(font, top - lineH, top, kb.labelFs)
				print(color .. lines[li], cx, ly, kb.labelFs, oCentre)
			end

			if info.icon and kb.iconSize > 0 then
				local s = kb.iconSize
				local iy2 = fy2 - padY
				glColor(1, 1, 1, (first.paired and look.pairedIconAlpha or look.iconAlpha) * opacity)
				glTexture(info.icon)
				glTexRect(cornerX - s, iy2 - s, cornerX, iy2)
				glTexture(false)
				glColor(1, 1, 1, 1)
				cornerX = cornerX - s - floor(pad * 0.6)
			end
		end
		if #entries > 1 then
			local count = (light and look.nameOnLight or look.more) .. "+" .. (#entries - 1)
			print(count, cornerX, nameY, kb.moreFs, oRight)
		end
	end

	-- Which layer this is, how to work the page, and the view toggle.
	local frame = kb.frames.main
	local rowTop, rowBottom = frame.oy, frame.oy - unit
	local caption
	local held = {}
	for _, name in ipairs(modifierNames) do
		if mods[name] then
			held[#held + 1] = name:sub(1, 1):upper() .. name:sub(2)
		end
	end
	if #held > 0 then
		caption = look.captionMods .. BAR.I18N("ui.keybinds.keyboard.layer", { mods = table.concat(held, " + ") })
	else
		caption = look.caption .. (kb.L.layerBase or "")
	end
	local captionX = frame.ox + floor(unit * 7.5)
	print(caption, captionX, text.baseline(font, rowBottom, rowTop, kb.titleFs), kb.titleFs, "co")

	local hintW = floor(unit * 5.5) - pad
	local hintLines = hintFor(kb, hintW)
	local hintLineH = floor(kb.hintFs * 1.25)
	local blockTop = floor((rowTop + rowBottom + #hintLines * hintLineH) * 0.5)
	for li, line in ipairs(hintLines) do
		local top = blockTop - (li - 1) * hintLineH
		local y = text.baseline(font, top - hintLineH, top, kb.hintFs)
		print(look.hint .. line, frame.ox + pad, y, kb.hintFs, "o")
	end

	local b = kb.button
	if b and UiButton then
		local overButton = hoverIdx == -1
		local fill = (kb.view == "numpad" and (overButton and look.buttonFillHover or look.buttonFillActive))
			or look.buttonFill
		local pair = look.gradients[fill]
		UiButton(b[1], b[2], b[3], b[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, pair[1], pair[2])
		if overButton and kb.view ~= "numpad" and Highlight then
			Highlight(b[1], b[2], b[3], b[4], floor(cs * 0.5), look.buttonHoverOpacity, look.white)
		end
		print(
			kb.L.numpad and (look.buttonText .. kb.L.numpad) or "",
			floor((b[1] + b[3]) * 0.5),
			text.baseline(font, b[2], b[4], kb.buttonFs),
			kb.buttonFs,
			"co"
		)
	end

	font:Begin()
	font:SetOutlineColor(look.outline)
	for _, p in ipairs(prints) do
		font:Print(p[1], p[2], p[3], p[4], p[5])
	end
	font:End()
end

return View
