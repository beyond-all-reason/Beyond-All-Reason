-- Interactive view for the in-game keybind editor, the first tab of the Keybind/Mouse Info
-- panel, on keybind_editor_model. Immediate-mode in shape, but the body is baked into a display
-- list and replayed until something it was painted from changes.

local keybindModel = require("luaui/Include/keybind_model")
local model = require("luaui/Include/keybind_editor_model")

local BuilderView = require("luaui/Include/keybind_select_builder_view")
local KeyboardView = require("luaui/Include/keybind_keyboard_view")

local text = require("luaui/Include/keybind_text")

local view = {}

local floor = math.floor
local spGetMouseState = Spring.GetMouseState
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local isInRect = math.isInRect
local glColor = gl.Color
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glBlending = gl.Blending

local area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
local scale = 1
local rowHeight = 22
-- Sizes derived from the scale, in one table.
local metrics = {
	-- Category entries run taller than keybind rows and in their own, larger, font.
	catRowHeight = 28,
	rowFs = 12,
	rowPad = 6,
	sidePad = 12,
	catInset = 4,
	-- Chips sit inside their row by this much, top and bottom.
	chipInset = 3,
	-- The cursor picture in front of an order's name, square.
	cursorIcon = 19,
	-- A category heading stands taller than the bindings under it and is set larger, so it
	-- reads as a divider rather than another row.
	headerRowHeight = 32,
	headerFs = 14,
	catFs = 13,
	-- The line along the bottom of a heading and of the selected category.
	underlineH = 2,
	-- Matches the inset the header and footer use vertically, so a button clears all three edges
	-- equally.
	edgeInset = 4,
	-- Clearance between the bottom of the list band and the footer, so the scrollbar does
	-- not run down into the buttons.
	footerGap = 8,
	-- Clearance between the right edge of the rows and the scrollbar beside them.
	listGap = 12,
	-- How far the category card rises above the first entry in it.
	cardLip = 5,
	-- The panel title: its baseline below the top edge, and its size.
	titleY = 17,
	titleFs = 20,
	-- The caption in front of the preset picker, placed by layoutHeader: its left edge, its
	-- baseline and its size.
	presetLabelX = 0,
	presetLabelY = 0,
	presetLabelFs = 13,
	-- The line in the footer saying where staged edits will go: its left edge, its baseline
	-- and its size.
	noticeX = 0,
	noticeY = 0,
	noticeFs = 12,
	-- How far the category column starts below the keybind rows beside it, to leave the
	-- title room to breathe.
	sidebarDrop = 8,
	-- Corner radii, taken from FlowUI's so the panel rounds like the rest of the UI.
	csSmall = 2,
	csButton = 3,
	csPanel = 4,
}
-- Bumped by setArea. A cached row layout carries the value it was built against and is
-- measured again when it moves, without every row being walked at resize.
local layoutGen = 0
local listTop = 0
local barX1 = 0
local listX1 = 0
local sidebarW = 0
local listRight = 0
local L = model.L
-- The grid menu's size and action ids, which never change.
local gridRows, gridCols = model.gridRows, model.gridCols
local gridKeyActions, gridCategoryActions = model.gridKeyActions, model.gridCategoryActions

local scroll = 0

local hover = {
	sb = 0,
	row = 0,
	-- Named for whatever is under the cursor once it moves, not the empty string it starts at.
	---@type string
	zone = "",
	idx = 0,
	gk = "",
	ga = 0,
	gb = 0,
	btn = "",
	bar = 0,
	cat = 0,
	catThumbHovered = false,
	kb = 0,
}

-- The panel backdrop goes in guishader world set, which blurs the map and leaves the UI
-- alone. A popup has to blur UI, so it goes in the screen set - but widgetHandler walks
-- DrawScreen in reverse layer order, so ours would be blurred along with what it covers.
-- insertRenderDlist replays it after the blur, the way gui_options keeps its list crisp.
local shade = { owner = nil, rects = {}, lists = {} }

-- Only touched when the rect actually moves: every insert marks the stencil dirty, so
-- doing it per frame has it rebuilt per frame.
function shade.rect(name, x1, y1, x2, y2)
	if not WG.guishader then
		return
	end
	local was = shade.rects[name]
	if x1 then
		if not (was and was[1] == x1 and was[2] == y1 and was[3] == x2 and was[4] == y2) then
			WG.guishader.InsertScreenRect(x1, y1, x2, y2, "keybindeditor_" .. name, shade.owner)
			shade.rects[name] = { x1, y1, x2, y2 }
		end
	elseif was then
		WG.guishader.RemoveScreenRect("keybindeditor_" .. name)
		shade.rects[name] = nil
	end
end

function shade.drop(name)
	local list = shade.lists[name]
	if list then
		if WG.guishader then
			WG.guishader.removeRenderDlist(list)
		end
		gl.DeleteList(list)
		shade.lists[name] = nil
	end
end

-- Rebuilt per frame: a modal carries a blinking caret and the picker lights the option
-- under the cursor, so there is nothing static to hold on to.
function shade.float(name, fn)
	if not (WG.guishader and WG.guishader.insertRenderDlist) then
		-- No blur will be drawn over it, so there is nothing to hand over.
		fn()
		return
	end
	shade.drop(name)
	shade.lists[name] = gl.CreateList(fn)
	WG.guishader.insertRenderDlist(shade.lists[name])
end

function shade.clear()
	for name in pairs(shade.rects) do
		if WG.guishader then
			WG.guishader.RemoveScreenRect("keybindeditor_" .. name)
		end
		shade.rects[name] = nil
	end
	for name in pairs(shade.lists) do
		shade.drop(name)
	end
end

---@type table
local font
---@type function
local RectRound
---@type function
local UiElement
---@type function
local Highlight
---@type function
local UiButton
---@type function
local UiUnitFrame

local colorAction = "\255\210\210\205"
local colorKey = "\255\235\185\070"
local colorText = "\255\235\235\235"
local colorDim = "\255\160\160\160"
-- A button that cannot be pressed: dimmer than the dim used for ordinary secondary text,
-- since here it has to read as unavailable rather than merely quiet.
local colorFaded = "\255\115\115\115"
local colorHeader = "\255\255\200\130"
local colorDanger = "\255\235\090\090"
-- SelectHighlight defaults to 0.35 and the rest of the UI stays near it. At 1 the
-- overlay is opaque and swallows the label under it.
local hoverOpacity = 0.25
local buttonFill = { 0.18, 0.18, 0.18, 1 }
-- Matching stops because Draw.Button gradients color1 -> color2, and the white hover
-- overlay washes a tinted button out to grey, so these brighten instead.
local dangerFill = { 0.46, 0.10, 0.10, 1 }
local dangerFillHover = { 0.66, 0.14, 0.14, 1 }
-- With nothing staged there is nothing to discard or save, so both buttons sink into the
-- panel rather than sitting on it.
local dangerFillMuted = { 0.17, 0.12, 0.12, 0.45 }
local confirmFill = { 0.17, 0.38, 0.21, 1 }
local confirmFillHover = { 0.24, 0.52, 0.29, 1 }
local confirmFillMuted = { 0.12, 0.17, 0.13, 0.45 }
local pillFill = { 0.22, 0.22, 0.22, 1 }
local sheenTop = { 1, 1, 1, 0.05 }
-- Fills and captions the list is painted with, in one table as metrics above.
local look = {
	chipFill = { 0, 0, 0, 0.35 },
	chipFillHover = { 0, 0, 0, 0.45 },
	-- A chip that answered a search by key, warmed in the gold its key is printed in, so it stands
	-- out from the rest of the row without reading as hovered.
	chipFillHit = { 0.92, 0.72, 0.27, 0.3 },
	-- A chip whose key another listed action also answers to: reddened, and its tooltip says which.
	chipFillConflict = { 0.62, 0.16, 0.12, 0.4 },
	-- An amber border with the row own dark inside it, so it reads as a note about the row
	-- rather than one more of its keys.
	ghostBorder = { 1, 0.78, 0.51, 0.3 },
	ghostBorderHover = { 1, 0.78, 0.51, 0.7 },
	ghostInner = { 0.09, 0.09, 0.09, 1 },
	ghostKeys = "\255\200\165\110",
	-- Shared by every unchanged row that asks: no keys at all, and nothing to copy.
	noRaws = {},
	-- The import preview: the box the clipboard's lines scroll in, the band under a line that
	-- will be dropped, and each kind of line in its own colour.
	previewFill = { 0, 0, 0, 0.35 },
	previewGutter = { 1, 1, 1, 0.05 },
	previewErrorFill = { 0.62, 0.16, 0.12, 0.28 },
	previewColours = { bind = colorText, directive = colorDim, comment = colorFaded, error = colorDanger },
	addFill = { 0.2, 0.45, 0.25, 0.4 },
	-- A tinted element brightens its own fill instead of taking the white overlay, which would
	-- wash the green out to grey.
	addFillHover = { 0.32, 0.74, 0.4, 0.6 },
	selectedFill = { 1, 1, 1, 0.13 },
	-- The font is shared with every other widget, some of which set an outline and leave it set,
	-- and text baked into a display list keeps whatever was set last.
	outline = { 0, 0, 0, 0.4 },
	-- Lifted above the resting grey, and further under the cursor, since a tinted face takes no
	-- hover overlay.
	toggleFill = { 0.33, 0.33, 0.33, 1 },
	toggleFillHover = { 0.4, 0.4, 0.4, 1 },
	-- The category column sits on its own darker card, so it reads apart from the list.
	sidebarFill = { 0, 0, 0, 0.24 },
	sidebarFillTop = { 0, 0, 0, 0.16 },
	white = { 1, 1, 1 },
	-- Rows, categories and grid cells hover with the same FlowUI highlight the settings
	-- list uses, at the strength it gives a plain row.
	rowHoverOpacity = 0.14,
	-- A thin bar fading upward out of the bottom edge, in the hue of the text above it.
	headerLine = { 1, 0.78, 0.51, 0.4 },
	headerLineFade = { 1, 0.78, 0.51, 0 },
	-- Border strength for a tile that is only being shown, not offered. FlowUI's own
	-- default for a live one is 0.1.
	idleBorder = 0.02,
	removeHot = colorDanger .. "x",
	removeCold = colorDim .. "x",
	plusText = colorText .. "+",
	-- The glyph goes to full white with it, the way a chip's key does under the cursor.
	plusTextHover = "\255\255\255\255" .. "+",
	arrow = colorKey .. string.char(226, 128, 186),
	-- How strongly those pictures draw. At full strength they outshout the names beside them.
	cursorAlpha = 0.85,
}

-- Left to its defaults FlowUI Button fades black up to near-transparent white, which washes a
-- tinted button out to grey. Derived once per fill, since the pair is passed every draw.
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

-- `tipLocked` is the text shown while the active preset is a default and Edit is greyed out,
-- which is the one place saying why.
local headerButtons = {
	{
		id = "duplicate",
		icon = "LuaUI/Images/keybinds/duplicate.png",
		tooltipId = "keybind_duplicate",
		tip = "duplicateTooltip",
	},
	{
		id = "edit",
		icon = "LuaUI/Images/keybinds/edit.png",
		tooltipId = "keybind_edit",
		tip = "editTooltip",
		tipLocked = "editLockedTooltip",
	},
	{
		id = "export",
		icon = "LuaUI/Images/keybinds/export.png",
		tooltipId = "keybind_export",
		tip = "exportTooltip",
	},
	{
		id = "import",
		icon = "LuaUI/Images/keybinds/import.png",
		tooltipId = "keybind_import",
		tip = "importTooltip",
	},
	{ id = "keyboard", tooltipId = "keybind_keyboard", tip = "keyboardTooltip", toggle = true, gap = 2 },
}

-- Discarding is destructive and saving is not, so the two footer buttons are coloured for
-- what they do rather than left to read alike.
local footerButtons = {
	{ id = "reset", fill = dangerFill, fillHover = dangerFillHover, fillMuted = dangerFillMuted },
	{ id = "save", fill = confirmFill, fillHover = confirmFillHover, fillMuted = confirmFillMuted },
}

local buttonSets = { headerButtons, footerButtons }

-- Panel state in one table, with the functions only this state needs hanging off it.
local state = {
	headerH = 0,
	footerH = 0,
	layoutPending = false,
	tooltipsRegistered = false,
	---@type string
	page = "list",
	---@type table?
	rowDrag = nil,
}

model.selectionBuilder:setLook(BuilderView.look)

----------------------------------------------------------------
-- Scrolling
----------------------------------------------------------------

local function listBottom()
	return area.y1 + state.footerH + metrics.footerGap
end

-- A category heading is taller than the bindings under it, so a row position is a sum of what
-- is above it rather than its index times one height.
local rowMetrics = { gen = -1, rows = -1, totalH = 0 }

local function rowHeightOf(row)
	return row.type == "header" and metrics.headerRowHeight or rowHeight
end

local function ensureRowMetrics()
	if rowMetrics.gen == layoutGen and rowMetrics.rows == model.rowsGen then
		return
	end

	local off = 0
	for i = 1, #model.rows do
		local row = model.rows[i]
		row.off = off
		off = off + rowHeightOf(row)
	end
	rowMetrics.totalH = off
	rowMetrics.gen, rowMetrics.rows = layoutGen, model.rowsGen
end

-- Pixels of content above the first painted row.
local function scrollOffset()
	ensureRowMetrics()
	local first = model.rows[scroll + 1]

	return first and first.off or 0
end

-- Furthest offset that still fills the band. Walked from the end, so it does not depend on
-- where the list is scrolled to now.
local function maxScroll()
	ensureRowMetrics()
	local band = listTop - listBottom()
	local used = 0
	local i = #model.rows
	while i > 0 do
		local h = rowHeightOf(model.rows[i])
		if used + h > band then
			break
		end
		used = used + h
		i = i - 1
	end

	return i
end

-- Every hover test, click and the panel signature go through this, so none can disagree with
-- what was drawn.
local function rowAt(y)
	ensureRowMetrics()
	local lb = listBottom()
	if y > listTop or y <= lb then
		return nil
	end

	local base = scrollOffset()
	for i = scroll + 1, #model.rows do
		local top = listTop - (model.rows[i].off - base)
		local bottom = top - rowHeightOf(model.rows[i])
		if bottom < lb then
			break
		end
		-- Half-open on the shared edge: rows stack, so one row's top is the next one's
		-- bottom and a closed test would put the cursor in both.
		if y <= top and y > bottom then
			return i - scroll, top, bottom
		end
	end

	return nil
end

local function clampScroll()
	if scroll < 0 then
		scroll = 0
	end
	if scroll > maxScroll() then
		scroll = maxScroll()
	end
end

-- Everything that draws, scrolls or hit-tests rows reads listTop, so the band moves as one.
function state.applyListTop()
	if not metrics.listTopBase then
		return
	end
	listTop = metrics.listTopBase - (state.compareBand() and metrics.compareBandH or 0)
end

-- Whether the comparison picker's band is up: the Changed section, on the list page.
function state.compareBand()
	return state.page == "list" and model.selectedCategory == model.changedKey and not model.gridGroup
end

-- Places the comparison strip and the picker at its right end, once the band is placed. The
-- strip's rect and the caption's place are kept in metrics for the draw.
function state.layoutCompare()
	local dd = model.compareDropdown
	if not (dd and metrics.listTopBase and metrics.compareStripH) then
		return
	end
	local y2 = metrics.listTopBase - floor(2 * scale)
	local y1 = y2 - metrics.compareStripH
	metrics.compareY1, metrics.compareY2 = y1, y2
	local inset = floor(4 * scale)
	local w = floor(280 * scale)
	local x2 = listRight - metrics.rowPad
	dd:setRect(x2 - w, y1 + inset, x2, y2 - inset, floor((y2 - y1 - inset * 2) * 0.5))
	-- The caption sits right against the picker, as the header's "Preset" does.
	metrics.compareCaptionX = x2 - w - floor(8 * scale)
	metrics.compareFs = floor((y2 - y1 - inset * 2) * 0.5)
end

----------------------------------------------------------------
-- Layout and geometry
----------------------------------------------------------------

-- Layout can run before view.init has a font, so that case falls back to a width and asks
-- draw to lay out again once the font is there.
local function labelWidth(label, size, pad)
	if not font then
		state.layoutPending = true

		return floor(110 * scale)
	end

	return floor(font:GetTextWidth(label) * size) + pad * 2
end

-- Header and footer rects, placed right to left from the panel edge.
local function layoutHeader()
	state.headerH = floor(34 * scale)
	state.footerH = floor(34 * scale)

	if not (model.searchBox and model.presetDropdown) then
		return
	end

	state.layoutPending = false
	state.presetsGen = model.presetsGen

	local gap = floor(8 * scale)
	local buttonGap = floor(4 * scale)
	local rowTop = area.y2 - floor(4 * scale)
	local rowBottom = area.y2 - state.headerH + floor(4 * scale)
	-- Room for the longest shipped name beside its Default tag.
	local presetW = floor(240 * scale)
	local btnFs = floor((rowTop - rowBottom) * 0.5)
	local bfs = floor(rowHeight * 0.55)

	-- Right to left: the clipboard buttons, the edit dialog opener, duplicate, the picker they
	-- act on, then the picker's caption. Icon buttons are square; captioned ones fit their word.
	local iconW = rowTop - rowBottom
	local bx2 = area.x2 - metrics.edgeInset
	for i = #headerButtons, 1, -1 do
		local b = headerButtons[i]
		local w = iconW
		if not b.icon then
			local label = L[b.id] or b.id
			w = labelWidth(label, bfs, floor(10 * scale))
			if font then
				b.textOn = colorText .. label
				b.textOff = colorFaded .. label
			end
		end
		b.rect = { bx2 - w, rowBottom, bx2, rowTop }
		bx2 = floor(bx2 - w - buttonGap * (b.gap or 1))
	end
	local pickerX1 = bx2 - presetW
	metrics.presetLabelX = pickerX1 - gap - labelWidth(L.preset or "", btnFs, 0)
	metrics.presetLabelFs = btnFs
	if font then
		-- The baseline the picker and the search field print their own text on.
		metrics.presetLabelY = text.baseline(font, rowBottom, rowTop, btnFs)
	end

	model.presetDropdown:setRect(pickerX1, rowBottom, pickerX1 + presetW, rowTop, btnFs)
	-- Twice the gap on this side, so the caption reads as the picker's and not the field's.
	model.searchBox:setRect(listX1, rowBottom, metrics.presetLabelX - gap * 2, rowTop, btnFs)

	local fTop = area.y1 + state.footerH - floor(4 * scale)
	local fBottom = area.y1 + floor(4 * scale)
	local fFs = floor((fTop - fBottom) * 0.5)
	local fPad = floor(14 * scale)
	local x2 = area.x2 - metrics.edgeInset
	-- A default cannot take the edits, so its Save is worded for where they go instead.
	local own = model.activeIsOwn()
	for i = #footerButtons, 1, -1 do
		local b = footerButtons[i]
		local label = (b.id == "save" and not own and L.saveAsNew) or L[b.id] or b.id
		local w = labelWidth(label, fFs, fPad)
		b.rect = { x2 - w, fBottom, x2, fTop }
		x2 = x2 - w - gap
		-- Both states of the caption, fitted and coloured here so the draw only picks one.
		if font then
			local fitted = text.fit(font, label, w - metrics.rowPad * 2, bfs)
			b.textOn = colorText .. fitted
			b.textOff = colorFaded .. fitted
		end
	end

	-- The footer notice gets what the buttons leave: from the list's left edge to a double gap
	-- short of the first button. Each wording is fitted here, so the bake only picks one.
	metrics.noticeX = listX1
	metrics.noticeFs = floor(rowHeight * 0.5)
	if font then
		local nfs = metrics.noticeFs
		local noticeW = x2 - gap - listX1
		metrics.noticeY = text.baseline(font, fBottom, fTop, nfs)
		L.noticeDefaultText = colorDim .. text.fit(font, L.noticeDefault or "", noticeW, nfs)
		L.noticeDefaultUnsavedText = colorHeader .. text.fit(font, L.noticeDefaultUnsaved or "", noticeW, nfs)
		L.noticeUnsavedText = colorHeader .. text.fit(font, L.noticeUnsaved or "", noticeW, nfs)
	end

	-- New rects, so the tooltip areas have to be handed over again.
	state.tooltipsRegistered = false
end

-- Derived in one place so draw and mousePress agree.
local function dialogGeometry()
	local preview = model.dialog and model.dialog.preview
	local w = floor(((preview or (model.dialog and model.dialog.wide)) and 620 or 315) * scale)
	local h = floor((preview and 420 or 150) * scale)
	local messageLines, messageStep
	if model.dialog and model.dialog.message and font then
		messageStep = floor(rowHeight * 0.75)
		messageLines = text.wrap(font, model.dialog.message, w - floor(32 * scale), floor(rowHeight * 0.5))
		h = h + math.max(0, #messageLines - 1) * messageStep
	end
	local cx = (area.x1 + area.x2) * 0.5
	local cy = (area.y1 + area.y2) * 0.5
	local bx1, bx2 = floor(cx - w * 0.5), floor(cx + w * 0.5)
	local by1, by2 = floor(cy - h * 0.5), floor(cy + h * 0.5)
	local bh = floor(28 * scale)
	local pad = floor(16 * scale)
	local btnY1 = by1 + pad
	local bfs = floor(bh * 0.5)
	local bpad = floor(14 * scale)

	local okW = labelWidth(model.dialog and model.acceptLabelFor(model.dialog) or L.save, bfs, bpad)
	local ok, cancel
	if model.dialog and model.dialog.info then
		ok = { floor(cx - okW * 0.5), btnY1, floor(cx + okW * 0.5), btnY1 + bh }
	else
		local cancelW = labelWidth(L.cancel, bfs, bpad)
		cancel = { bx1 + pad, btnY1, bx1 + pad + cancelW, btnY1 + bh }
		ok = { bx2 - pad - okW, btnY1, bx2 - pad, btnY1 + bh }
	end

	local midW = labelWidth(model.dialog and model.dialog.middle and model.dialog.middle.label or L.discard, bfs, bpad)
	local midX = (bx1 + bx2) * 0.5
	local discard = { floor(midX - midW * 0.5), btnY1, floor(midX + midW * 0.5), btnY1 + bh }
	local fieldY1 = btnY1 + bh + floor(20 * scale)
	local field = { bx1 + pad, fieldY1, bx2 - pad, fieldY1 + floor(26 * scale) }

	-- The preview box, from above the field to under the summary line beneath the title.
	local box
	if preview then
		box = { bx1 + pad, field[4] + floor(14 * scale), bx2 - pad, by2 - floor(66 * scale) }
	end

	local choice
	if model.dialog and model.dialog.choice then
		local fh = field[4] - field[2]
		local sh = floor(fh * 0.7)
		local sy1 = field[2] + floor((fh - sh) * 0.5)
		local sx2 = field[1] + floor(sh * 1.8)
		local labelX = sx2 + floor(8 * scale)
		local labelW = font and floor(font:GetTextWidth(model.dialog.choice.label) * floor(rowHeight * 0.5)) or 0
		choice = {
			switch = { field[1], sy1, sx2, sy1 + sh },
			hit = { field[1], field[2], labelX + labelW, field[4] },
			labelX = labelX,
			label = model.dialog.choice.label,
			on = model.dialog.choice.on,
			locked = model.dialog.choice.locked == true,
			fieldless = model.dialog.nameless == true,
			hint = model.dialog.nameless and model.dialog.hint or nil,
		}
		field[1] = labelX + labelW + pad
	end

	return bx1, by1, bx2, by2, ok, cancel, field, discard, messageLines, messageStep, box, choice
end

-- Capture-modal geometry, derived in one place so draw and mousePress agree.
local function captureGeometry()
	local w = floor(420 * scale)
	local h = floor(200 * scale)
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

-- A no-op until the font exists, and the sidebar asks again once it does.
local function fitCategories()
	if not font then
		return
	end

	local labelW = (state.columnW or sidebarW) - metrics.sidePad * 2
	-- Fitted at the size they are actually drawn at, so a label is not shortened for a
	-- size the column never uses.
	for _, c in ipairs(model.categories) do
		local count = c.count and c.count > 0 and tostring(c.count) or nil
		local reserve = count and (floor(font:GetTextWidth(count) * metrics.catFs) + metrics.sidePad) or 0
		local fitted = text.fit(font, c.label, labelW - reserve, metrics.catFs)
		c.textSel = colorAction .. fitted
		c.textDim = colorDim .. fitted
		c.textHeader = colorHeader .. fitted
		c.textCount = count and (colorDanger .. count) or nil
	end
end

----------------------------------------------------------------
-- Panel lifecycle
----------------------------------------------------------------

-- Picks up the font and the FlowUI entry points, which do not exist at include time.
function view.init()
	font = WG["fonts"].getFont()
	RectRound = WG.FlowUI.Draw.RectRound
	state.listScroller = WG.FlowUI.Scroller.new(state.listMeasure)
	state.catScroller = WG.FlowUI.Scroller.new(state.catMeasure)
	UiElement = WG.FlowUI.Draw.Element
	Highlight = WG.FlowUI.Draw.SelectHighlight
	UiButton = WG.FlowUI.Draw.Button
	UiUnitFrame = WG.FlowUI.Draw.UnitFrame
	KeyboardView.init(model.keyboard, font)
	model.ensureControls()
end

-- `wx1..wy2` is the window the area sits inside; without it a modal can only dim as far as
-- the area goes, leaving the panel own border lit.
function view.setArea(x1, y1, x2, y2, s, wx1, wy1, wx2, wy2)
	model.ensureControls()
	area.x1, area.y1, area.x2, area.y2 = x1, y1, x2, y2
	metrics.winX1, metrics.winY1 = wx1 or x1, wy1 or y1
	metrics.winX2, metrics.winY2 = wx2 or x2, wy2 or y2
	scale = s or 1
	rowHeight = floor(24 * scale)
	metrics.catRowHeight = floor(29 * scale)
	metrics.catBarW = WG.FlowUI.Scroller.width(scale)
	-- Whole pixels throughout: a size or a corner landing on a fraction puts glyph and
	-- rectangle edges between pixels, which the renderer then blends across both.
	metrics.rowFs = floor(rowHeight * 0.55)
	metrics.headerRowHeight = floor(rowHeight * 1.35)
	-- The heading was set at 0.95 of a row's size; 13% up from there.
	metrics.headerFs = floor(metrics.rowFs * 0.95 * 1.13)
	metrics.catFs = floor(metrics.catRowHeight * 0.55 * 0.85)
	metrics.underlineH = math.max(1, floor(2 * scale))
	metrics.rowPad = floor(6 * scale)
	metrics.sidePad = floor(12 * scale)
	metrics.catInset = floor(4 * scale)
	metrics.chipInset = floor(3 * scale)
	metrics.cursorIcon = floor(rowHeight * 0.8)
	-- Set before layoutHeader below, which places the header and footer buttons against it.
	metrics.edgeInset = floor(4 * scale)
	metrics.footerGap = floor(8 * scale)
	metrics.listGap = floor(12 * scale)
	metrics.cardLip = floor(5 * scale)
	metrics.titleY = floor(17 * scale)
	metrics.sidebarDrop = floor(8 * scale)
	metrics.titleFs = floor(rowHeight * 0.85)

	-- Rounded like the settings panel's inner elements, which take a share of this too.
	local corner = WG.FlowUI.elementCorner
	metrics.csPanel = floor(corner)
	metrics.csButton = floor(corner * 0.8)
	metrics.csSmall = floor(corner * 0.66)

	sidebarW = floor(240 * scale)
	listX1 = area.x1 + sidebarW + floor(12 * scale)

	layoutHeader()

	listTop = area.y2 - state.headerH - floor(4 * scale)
	metrics.listTopBase = listTop
	-- The strip the Changed section puts its comparison picker in, above its rows, and the
	-- room it takes from them: the strip plus a gap, so it stands apart from the first heading.
	metrics.compareStripH = floor(rowHeight * 1.45)
	metrics.compareBandH = metrics.compareStripH + floor(rowHeight * 0.5)
	-- The gap matches the one the bar keeps from the panel edge on its other side, so it sits in
	-- a channel rather than hugging the rows.
	local barW = WG.FlowUI.Scroller.width(scale)
	barX1 = area.x2 - metrics.edgeInset - barW
	listRight = barX1 - metrics.listGap
	metrics.keyAreaX1 = listX1 + floor((listRight - listX1) * 0.45)

	-- The keyboard page takes the whole band the column and the list share, inset from the
	-- panel's sides like the column's own text.
	model.keyboard:setArea(
		area.x1 + metrics.sidePad,
		listBottom(),
		area.x2 - metrics.sidePad,
		metrics.listTopBase,
		scale,
		metrics.titleFs
	)
	model.selectionBuilder:setArea(
		area.x1,
		area.y1,
		area.x2,
		area.y2,
		scale,
		metrics.winX1,
		metrics.winY1,
		metrics.winX2,
		metrics.winY2
	)
	state.applyListTop()
	state.layoutCompare()

	-- Shortened here rather than in the draw loop: the column width and the font size are
	-- both settled by now, and this runs on a resize where the loop runs every frame.
	fitCategories()

	layoutGen = layoutGen + 1
	clampScroll()
end

-- Re-reads the engine and rebuilds everything shown from it.
function view.refresh()
	model.refresh()
end

-- Panel closing: drop focus, tooltips and any open modal.
function view.blur()
	if WG["tooltip"] then
		for _, b in ipairs(headerButtons) do
			WG["tooltip"].RemoveTooltip(b.tooltipId)
		end
	end
	state.tooltipsRegistered = false
	state.tipKey = nil
	state.rowDrag = nil
	if state.panelList then
		gl.DeleteList(state.panelList)
		state.panelList = nil
		state.panelSig = nil
	end

	-- Or the blur outlives the panel: guishader keeps drawing a rect nobody owns any more.
	shade.clear()

	model.blur()
end

-- The host widget, handed over so guishader can drop this panel's blur rects with it when
-- the widget goes away. Optional: with no owner the rects are simply always allowed.
function view.setOwner(w)
	shade.owner = w
end

-- Which page the body shows: "keyboard" for the overview, anything else for the list. The
-- host's action takes it as a word, so a key can open the panel straight onto the keyboard.
function view.setPage(page)
	state.setPage(page == "keyboard" and "keyboard" or "list")
end

-- Host hook, called with the page whenever it changes, so the host can size the panel to it.
function view.setPageHook(fn)
	state.pageHook = fn
end

----------------------------------------------------------------
-- Chip layout and text batching
----------------------------------------------------------------

-- Fits a chip to its box, shrinking to a readable floor before it truncates.
local function chipMetrics(display, fs, pad, rightGap, chipArea)
	local tw = font:GetTextWidth(display) * fs
	if pad + tw + rightGap <= chipArea then
		return display, fs, floor(pad + tw + rightGap)
	end

	-- Keep inner positive, since a tiny share can drive it negative and the fit would then
	-- return the string whole instead of truncating.
	local inner = math.max(floor(fs), chipArea - pad - rightGap)
	local chipFs = math.max(floor(fs * 0.75), floor(fs * inner / math.max(1, tw)))
	local disp = text.fit(font, display, inner, chipFs)

	return disp, chipFs, floor(pad + font:GetTextWidth(disp) * chipFs + rightGap)
end

-- Chain tokens over two lines at most; the second truncates rather than a third appearing.
local function wrapChainTwoLines(tokens, sep, maxW, fs)
	local line1, i = "", 1
	while i <= #tokens do
		local cand = (line1 == "") and tokens[i] or (line1 .. sep .. tokens[i])
		if line1 ~= "" and font:GetTextWidth(cand) * fs > maxW then
			break
		end
		line1, i = cand, i + 1
	end

	if i > #tokens then
		return { line1 }
	end

	local rest = {}
	for j = i, #tokens do
		rest[#rest + 1] = tokens[j]
	end
	local line2 = table.concat(rest, sep)
	if font:GetTextWidth(line2) * fs > maxW then
		line2 = text.fit(font, line2, maxW, fs)
	end

	return { line1 .. sep, line2 }
end

-- Shares a row's width across its chips so every one stays clickable when they overflow.
local function layoutRowChips(action, fs, pad, rightGap, chipArea, gap)
	local groups = model.rowChipGroups(action)
	local n = #groups
	local mets = {}
	if n == 0 then
		return mets, metrics.keyAreaX1
	end

	local total = 0
	for i = 1, n do
		local disp, cfs, w = chipMetrics(groups[i].display, fs, pad, rightGap, chipArea)
		mets[i] = { group = groups[i], disp = disp, fs = cfs, w = w }
		total = total + w + (i > 1 and gap or 0)
	end

	if total > chipArea then
		local share = floor((chipArea - (n - 1) * gap) / n)
		for i = 1, n do
			local disp, cfs, w = chipMetrics(groups[i].display, fs, pad, rightGap, share)
			mets[i] = { group = groups[i], disp = disp, fs = cfs, w = w }
		end
	end

	local cx = metrics.keyAreaX1
	for i = 1, n do
		mets[i].x = cx
		mets[i].removeX1 = cx + mets[i].w - rightGap
		cx = cx + mets[i].w + gap
	end

	return mets, cx
end

-- Drawing and hit testing take it from here rather than each deriving the same constants, so
-- the click zones cannot drift from what was painted.
local function rowChipBand(action, fs, pad, reserve)
	local gap = floor(6 * scale)
	local rightGap = pad + floor(fs * 0.9)
	local addW = floor(fs + pad * 2)
	-- Room reserved on the right so "+" always fits, and whatever the caller wants after it.
	local chipArea = listRight - addW - floor(8 * scale) - metrics.keyAreaX1 - (reserve or 0)
	local mets, cx = layoutRowChips(action, fs, pad, rightGap, chipArea, gap)

	return mets, cx, addW, rightGap
end

-- Built on first use and kept on the row; a geometry change bumps layoutGen so a row laid out
-- against the old widths is measured again.
local function rowLayout(row)
	local lay = row.layout
	if lay and lay.gen == layoutGen then
		return lay
	end

	lay = { gen = layoutGen }
	if row.type == "header" then
		lay.text = colorHeader .. row.text
		if row.add then
			lay.addW = floor(font:GetTextWidth(row.add) * metrics.headerFs)
			lay.addX = listRight - metrics.rowPad - lay.addW
			lay.addText = colorAction .. row.add
			lay.addTextHover = colorHeader .. row.add
		end
	elseif row.type == "note" then
		lay.text = colorDim .. text.fit(font, row.text, listRight - listX1 - metrics.rowPad * 4, metrics.rowFs)

	elseif row.type == "link" then
		lay.text = colorAction .. row.label
		lay.arrow = look.arrow
		lay.arrowX = listX1
			+ metrics.rowPad * 5
			+ floor(font:GetTextWidth(row.label) * metrics.rowFs)
			+ metrics.rowPad * 2
	else
		-- The cursor column, when the row's group has one, comes out of the name's room.
		local indent = row.cursorColumn and (metrics.cursorIcon + metrics.rowPad) or 0
		lay.textX = listX1 + metrics.rowPad + indent
		lay.icon = row.cursor
		lay.iconX = listX1 + metrics.rowPad
		local labelW = metrics.keyAreaX1 - lay.textX - metrics.rowPad
		local fitted = text.fit(font, row.label, labelW, metrics.rowFs)
		lay.text = colorAction .. fitted
		lay.textHover = (row.editSelection or row.custom) and colorHeader .. fitted or nil

		-- The key the base preset had, when the row's differs: a hollow chip after the row's
		-- own, which the chips make room for. Paired halves read as one key, as the chips do.
		local change = row.change
		if change then
			local keys = model.changeKeys(row)
			lay.ghostFs = floor(metrics.rowFs * 0.9)
			keys = text.fit(font, keys, floor((listRight - metrics.keyAreaX1) * 0.3), lay.ghostFs)
			lay.ghostKeys = keys
			-- The caption is the same string twice with the keys marked off, so the colour split
			-- lands on the keys wherever a translation puts them.
			local caption = BAR.I18N("ui.keybinds.editor.revertChip", { keys = "\1" })
			local before, after = caption:match("^(.-)\1(.*)$")
			before, after = before or caption, after or ""
			lay.ghostText = colorFaded .. before .. look.ghostKeys .. keys .. colorFaded .. after
			lay.ghostTextHover = colorDim .. before .. colorHeader .. keys .. colorDim .. after
			lay.ghostW = floor(font:GetTextWidth(before .. keys .. after) * lay.ghostFs) + metrics.rowPad * 2
			-- Against the list's right edge, clear of the row's own keys and "+".
			lay.ghostX = listRight - metrics.rowPad - lay.ghostW
		end

		local reserve = lay.ghostW and (lay.ghostW + metrics.rowPad * 2) or 0
		local mets, cx, addW, rightGap = rowChipBand(row.action, metrics.rowFs, metrics.rowPad, reserve)
		for i = 1, #mets do
			local m = mets[i]
			m.textKey = colorKey .. m.disp
			m.textHover = colorText .. m.disp
			m.removeCx = floor(m.removeX1 + rightGap * 0.5)
			-- On a row found by key, the chip that answered is lit, so it reads why the row is here.
			m.hit = row.hitKeys ~= nil and keybindModel.holdsKeys(m.group.display, row.hitKeys)
			-- What else the chip's key drives, for its tooltip; reddened only for sharing of the
			-- player's own making.
			m.others = model.conflictsOf(row.action, m.group.raws)
			m.clash = false
			for _, o in ipairs(m.others or look.noRaws) do
				if not o.shipped then
					m.clash = true
				end
			end
		end
		lay.mets = mets
		lay.cx = cx
		lay.addW = addW
		-- A paired action holds one key as two binds, so once it has one there is no second to add:
		-- capturing again rewrites the pair, and "+" would read as "add another".
		lay.showAdd = not (model.catalogShiftPair[row.action] and #mets > 0)
	end
	row.layout = lay

	return lay
end

-- y is checked against the chip band when given, so hover matches what is painted; a click
-- passes nil and takes the whole row height.
local function rowZone(lay, x, y, c1, c2)
	if y and (y < c1 or y > c2) then
		return nil
	end

	local mets = lay.mets
	for i = 1, #mets do
		local m = mets[i]
		if x >= m.x and x < m.removeX1 then
			return "rebind", i
		elseif x >= m.removeX1 and x <= m.x + m.w then
			return "remove", i
		end
	end

	if lay.showAdd and x >= lay.cx and x <= lay.cx + lay.addW then
		return "add"
	end

	if lay.ghostW and x >= lay.ghostX and x <= lay.ghostX + lay.ghostW then
		return "revert"
	end

	return nil
end

-- Geometry drawn between font:Begin and font:End interleaves with the batched glyphs and
-- makes both flicker, so shapes queue here and flush once. Held flat and refilled in place:
-- a table per string per frame is hundreds of allocations a second.
local pendingText = {}
local pendingCount = 0

local function queueText(str, x, y, size, opts)
	local at = pendingCount * 5
	pendingText[at + 1] = str
	pendingText[at + 2] = x
	pendingText[at + 3] = y
	pendingText[at + 4] = size
	pendingText[at + 5] = opts
	pendingCount = pendingCount + 1
end

local function flushText()
	if pendingCount == 0 then
		return
	end

	font:Begin()
	font:SetOutlineColor(look.outline)
	for i = 0, pendingCount - 1 do
		local at = i * 5
		font:Print(
			pendingText[at + 1],
			pendingText[at + 2],
			pendingText[at + 3],
			pendingText[at + 4],
			pendingText[at + 5]
		)
	end
	font:End()

	pendingCount = 0
end

----------------------------------------------------------------
-- Drawing
----------------------------------------------------------------

-- The category column starts below where the keybind rows do, so the title is not crowded.
function state.sidebarCardTop()
	-- Off the band's fixed top, not the rows' own: the Changed section lowers the rows for its
	-- comparison picker, and the column beside them must not move with it.
	return (metrics.listTopBase or listTop) - metrics.sidebarDrop
end

function state.addBindRect()
	local top = state.sidebarCardTop()

	return area.x1 + metrics.catInset, top - metrics.catRowHeight, area.x1 + sidebarW - metrics.catInset, top
end

local function sidebarTop()
	return state.sidebarCardTop() - metrics.catRowHeight - metrics.catInset * 2
end

-- The column has no footer of its own below it - that band only runs under the list - so
-- entries use the card's whole height rather than stopping level with the list's footer.
function state.sidebarBottom()
	return area.y1 + metrics.catInset
end

-- `i` is the entry place in `categories`, not on screen: the two differ by however far the
-- column is scrolled.
local function categoryRect(i)
	local top = sidebarTop() - (i - 1 - hover.cat) * metrics.catRowHeight
	-- The right edge gives way to the bar when there is one, or an entry hover plate disappears
	-- beneath it rather than stopping beside it.
	local right = area.x1 + sidebarW
	if #model.categories > math.max(1, floor((sidebarTop() - state.sidebarBottom()) / metrics.catRowHeight)) then
		right = right - metrics.catInset - metrics.catBarW - metrics.catInset
	end
	if right - area.x1 ~= state.columnW then
		state.columnW = right - area.x1
		model.refit = true
	end

	return area.x1, top - metrics.catRowHeight, right, top
end

-- Answers how far it can be scrolled at all, so nought means everything fits; passing 0
-- just clamps.
local function catScrolled(delta)
	local page = math.max(1, floor((sidebarTop() - state.sidebarBottom()) / metrics.catRowHeight))
	local most = math.max(0, #model.categories - page)
	local n = hover.cat + delta
	hover.cat = (n < 0 and 0) or (n > most and most) or n

	return most
end

-- Over the entries rather than the whole card: a bar running past the last row reads as dead
-- space, and its thumb then says more fits than does. Nil while every entry fits.
function state.catBar()
	if catScrolled(0) == 0 then
		return nil
	end

	local rowH = metrics.catRowHeight
	local page = math.max(1, floor((sidebarTop() - state.sidebarBottom()) / rowH))
	local bx2 = area.x1 + sidebarW - metrics.catInset

	return { bx2 - metrics.catBarW, sidebarTop() - page * rowH, bx2, sidebarTop() }
end

function state.catMeasure()
	local rowH = metrics.catRowHeight
	local most = catScrolled(0)

	return #model.categories * rowH, hover.cat * rowH, most
end

-- The category entry under x,y, or nil. Half-open on the shared edge, like the rows, so
-- one point never lands in two entries.
local function sidebarIndexAt(x, y)
	local top = sidebarTop()
	if x < area.x1 or x > area.x1 + sidebarW or y > top or y <= state.sidebarBottom() then
		return nil
	end

	local i = floor((top - y) / metrics.catRowHeight) + 1 + hover.cat
	if not model.categories[i] then
		return nil
	end

	local _, y1 = categoryRect(i)
	if y1 < state.sidebarBottom() then
		return nil
	end

	return i
end

-- Sized to roughly what the menu occupies in game - 0.2125 of screen width over four columns
-- - rather than stretched.
local function gridGeometry()
	-- The heading here is the list's heading, so it takes the taller heading row rather
	-- than an ordinary one.
	local headH = metrics.headerRowHeight
	local top = listTop - headH - floor(8 * scale)
	local bottom = listBottom() + floor(8 * scale)
	local strip = floor(rowHeight * 1.2)
	local gap = floor(4 * scale)
	local blockGap = floor(28 * scale)

	local availH = (top - bottom) - (strip + gap) * 2
	local availW = (listRight - listX1) - blockGap
	local cell = math.min(floor(availH / gridRows), floor(availW / (gridCols * 2)), floor(100 * scale))
	if cell < 1 then
		cell = 1
	end

	local blockW = cell * gridCols
	local blockH = cell * gridRows + (strip + gap) * 2
	-- Pinned to the top left of the list band, like the rows it replaces, rather than
	-- floating in the middle of it.
	local x1 = listX1
	local stripY = top - blockH
	local gridBottom = stripY + strip + gap

	return x1, x1 + blockW + blockGap, gridBottom, cell, strip, gap, stripY, gridBottom + cell * gridRows + gap, headH
end

-- Cell rect for a grid position. Row 1 is the bottom row, so it is laid out upward.
local function gridCellRect(row, col, x1, gridBottom, cell)
	local cx = x1 + (col - 1) * cell
	local cy = gridBottom + (row - 1) * cell

	return cx, cy, cx + cell, cy + cell
end

-- Through FlowUI Button so these carry the same border, gloss and corner as the rest.
local function drawButtonFace(r, base)
	local pair = look.gradients[base]

	UiButton(r[1], r[2], r[3], r[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, pair[1], pair[2])
end

-- Shared, so the grid view heading is the same object as the list one rather than a second
-- that has to be kept looking like it.
local function drawHeaderBand(top, bottom, caption)
	RectRound(listX1, bottom, listRight, top - metrics.csSmall, metrics.csSmall, 1, 1, 0, 0, sheenTop, sheenTop)
	-- Underline: a thin bar fading up out of the bottom edge, so the heading closes off the
	-- block above it rather than floating in the middle of the list.
	RectRound(
		listX1,
		bottom,
		listRight,
		bottom + metrics.underlineH,
		0,
		0,
		0,
		0,
		0,
		look.headerLine,
		look.headerLineFade
	)
	queueText(caption, listX1 + metrics.rowPad, floor((top + bottom) * 0.5), metrics.headerFs, "ov")
end

-- The category column: its own card under the title, then one entry per category, with
-- hoverIdx the entry under the cursor.
local function drawSidebar(hoverIdx)
	-- Derived from the column's top rather than measured from the panel top, so the card keeps
	-- its lip above what it holds wherever the column starts.
	RectRound(
		area.x1,
		area.y1,
		area.x1 + sidebarW,
		state.sidebarCardTop() + metrics.cardLip,
		metrics.csPanel,
		1,
		1,
		1,
		1,
		look.sidebarFill,
		look.sidebarFillTop
	)
	queueText(colorText .. L.title, area.x1 + metrics.sidePad, area.y2 - metrics.titleY, metrics.titleFs, "ov")

	local ax1, ay1, ax2, ay2 = state.addBindRect()
	drawButtonFace({ ax1, ay1, ax2, ay2 }, hover.btn == "addBind" and confirmFillHover or confirmFill)
	queueText(
		colorText .. L.addBind,
		floor((ax1 + ax2) * 0.5),
		floor((ay1 + ay2) * 0.5),
		floor(rowHeight * 0.55),
		"cov"
	)

	local catBar = state.catBar()
	if catBar then
		state.catScroller:setRect(catBar[1], catBar[2], catBar[3], catBar[4])
		state.catScroller:draw(hover.catThumbHovered)
	end

	-- Laid out before the font existed, so the labels are still waiting to be fitted; or one of
	-- them changed since, which is the Changed entry's count.
	if model.refit or (model.categories[1] and not model.categories[1].textDim) then
		model.refit = false
		fitCategories()
	end

	local lb = state.sidebarBottom()
	for i, c in ipairs(model.categories) do
		local x1, y1, x2, y2 = categoryRect(i)
		if i > hover.cat and y1 >= lb then
			local ty = floor((y1 + y2) * 0.5)
			if c.header then
				RectRound(
					x1 + metrics.catInset,
					y1,
					x2 - metrics.catInset,
					y1 + metrics.underlineH,
					0,
					0,
					0,
					0,
					0,
					look.headerLine,
					look.headerLineFade
				)
				queueText(c.textHeader or c.label, x1 + metrics.sidePad, ty, metrics.catFs, "ov")
			else
				local selected = model.selectedCategory == c.key
				if selected then
					local sx1, sx2 = x1 + metrics.catInset, x2 - metrics.catInset
					RectRound(sx1, y1, sx2, y2, metrics.csSmall, 1, 1, 1, 1, look.selectedFill)
				elseif i == hoverIdx then
					Highlight(
						x1 + metrics.catInset,
						y1,
						x2 - metrics.catInset,
						y2,
						metrics.csSmall,
						look.rowHoverOpacity,
						look.white
					)
				end
				queueText(
					(selected and c.textSel or c.textDim) or c.label,
					x1 + metrics.sidePad,
					ty,
					metrics.catFs,
					"ov"
				)
				if c.textCount then
					queueText(c.textCount, x2 - metrics.sidePad, ty, metrics.catFs, "rov")
				end
			end
		end
	end
end

-- Label left, key right, sized like a category button. Used for every pill in this view.
local function drawGridPill(x1, y1, x2, y2, label, key, fs, pad, hovered, dim, clash)
	-- The cells above carry a unit tile frame, so these need the raised button face to not read
	-- as more of the same.
	local pair = look.gradients[pillFill]
	UiButton(x1, y1, x2, y2, 1, 1, 1, 1, 1, 1, 1, 1, nil, pair[1], pair[2])
	if clash then
		RectRound(x1, y1, x2, y2, metrics.csButton, 1, 1, 1, 1, look.chipFillConflict, look.chipFillConflict)
	end
	if hovered and not dim then
		Highlight(x1, y1, x2, y2, metrics.csButton, hoverOpacity, look.white)
	end
	-- With no key bound the label takes the whole button, which is why an unbound category reads
	-- as a plain centred caption.
	local keyW = floor(font:GetTextWidth(key) * fs)
	local lx1 = x1 + pad * 2
	local lx2 = x2 - pad * 2 - (keyW > 0 and keyW + pad * 2 or 0)
	local ty = floor((y1 + y2) * 0.5)
	queueText(
		(dim and colorDim or colorAction) .. text.fit(font, label, lx2 - lx1, fs),
		floor((lx1 + lx2) * 0.5),
		ty,
		fs,
		"cov"
	)
	queueText((dim and colorDim or colorKey) .. key, x2 - pad * 2, ty, fs, "rov")
end

-- Sized to its own label and key, so a longer translation widens it rather than being
-- clipped.
local function gridCycleRect(x1, bsize)
	local fs = floor(bsize * 0.45)
	local pad = floor(3 * scale)
	-- Inset to match the cells below, which sit a pad in from the block edge.
	local cx1 = x1 + pad
	local need = floor(
		(font:GetTextWidth(model.gridGroup.cycleLabel) + font:GetTextWidth(model.gridKeyText("gridmenu_cycle_builder")))
			* fs
	) + pad * 10

	return cx1, cx1 + math.max(need, floor(bsize * 2))
end

-- Hover, the baked signature and clicks all read this, so the three cannot disagree. Back is
-- left out: gui_gridmenu hardcodes its key, so there is nothing to rebind.
local function gridZone(x, y)
	local x1, x2, gridBottom, cell, strip, _, stripY, builderY = gridGeometry()
	local pad = floor(3 * scale)

	for row = 1, gridRows do
		for col = 1, gridCols do
			local cx1, cy1, cx2, cy2 = gridCellRect(row, col, x1, gridBottom, cell)
			if isInRect(x, y, cx1 + pad, cy1 + pad, cx2 - pad, cy2 - pad) then
				return "cell", row, col
			end
		end
	end

	if y >= stripY and y <= stripY + strip then
		for c = 1, gridCols do
			local cx1 = x1 + (c - 1) * cell
			if x >= cx1 + pad and x <= cx1 + cell - pad then
				return "category", c
			end
		end

		local third = floor(cell * gridCols / 3)
		if x >= x2 + gridCols * cell - third and x <= x2 + gridCols * cell - pad then
			return "next"
		end
	end

	local ccx1, ccx2 = gridCycleRect(x1, strip)
	if isInRect(x, y, ccx1, builderY, ccx2, builderY + strip) then
		return "cycle"
	end

	return nil
end

-- Cells stay empty: what fills them in game comes from the selected builder, which the editor
-- has no notion of.
local function drawGridMenu(zone, zoneA, zoneB)
	local x1, x2, gridBottom, cell, strip, _, stripY, builderY, headH = gridGeometry()
	local pad = floor(3 * scale)
	local keyFs = floor(cell * 0.2)
	local stripFs = floor(strip * 0.45)

	-- The same heading the list puts above a category, drawn by the same code.
	drawHeaderBand(listTop, listTop - headH, colorHeader .. model.gridGroup.title)

	-- The corner is derived once and shared with the fill under it; left to itself the frame
	-- would derive its own and the two would not line up.
	local cellInner = cell - pad * 2
	local frameCs = math.max(1, floor(cellInner * 0.024))

	for pass = 1, 2 do
		local gx = (pass == 1) and x1 or x2
		for row = 1, gridRows do
			for col = 1, gridCols do
				local cx1, cy1, cx2, cy2 = gridCellRect(row, col, gx, gridBottom, cell)
				-- Solid enough to read against the panel on its own, so the cells need no
				-- container or outline behind them.
				RectRound(cx1 + pad, cy1 + pad, cx2 - pad, cy2 - pad, frameCs, 1, 1, 1, 1, pillFill, pillFill)
				-- Only the first grid carries the build keys; the second is the category view,
				-- whose cells hold the same bindings and would just repeat them.
				if pass == 1 then
					if model.clashing[gridKeyActions[row][col]] then
						local red = look.chipFillConflict
						RectRound(cx1 + pad, cy1 + pad, cx2 - pad, cy2 - pad, frameCs, 1, 1, 1, 1, red, red)
					end
					-- Under the frame, so the hover lifts the tile without softening its edge.
					if zone == "cell" and zoneA == row and zoneB == col then
						Highlight(cx1 + pad, cy1 + pad, cx2 - pad, cy2 - pad, frameCs, look.rowHoverOpacity, look.white)
					end
					queueText(
						colorKey .. model.gridKeyText(gridKeyActions[row][col]),
						cx2 - pad * 3,
						cy2 - pad * 2 - keyFs,
						keyFs,
						"ro"
					)
				end
				-- Last, so the border and shine sit over the fill and the hover. The second grid binds
				-- nothing, so its frames are faint: a full-strength frame invites a click.
				local border = (pass == 1) and nil or look.idleBorder
				UiUnitFrame(cx1 + pad, cy1 + pad, cx2 - pad, cy2 - pad, frameCs, 1, 1, 1, 1, nil, border)
			end
		end
	end

	for c = 1, gridCols do
		local cx1 = x1 + (c - 1) * cell
		drawGridPill(
			cx1 + pad,
			stripY,
			cx1 + cell - pad,
			stripY + strip,
			model.gridGroup.categoryLabels[c] or "",
			model.gridKeyText(gridCategoryActions[c]),
			stripFs,
			pad,
			zone == "category" and zoneA == c,
			false,
			model.clashing[gridCategoryActions[c]]
		)
	end

	-- Second grid is the view after a category is picked: Back on the left, Next page on
	-- the right, matching how gui_gridmenu splits that strip into thirds.
	local third = floor(cell * gridCols / 3)
	drawGridPill(
		x2 + pad,
		stripY,
		x2 + third,
		stripY + strip,
		L.gridBack,
		keybindModel.displayKeyset("shift", model.working.layout),
		stripFs,
		pad,
		false,
		true
	)
	drawGridPill(
		x2 + gridCols * cell - third,
		stripY,
		x2 + gridCols * cell - pad,
		stripY + strip,
		L.gridNextPage,
		model.gridKeyText("gridmenu_next_page"),
		stripFs,
		pad,
		zone == "next",
		false,
		model.clashing.gridmenu_next_page
	)

	local ccx1, ccx2 = gridCycleRect(x1, strip)
	drawGridPill(
		ccx1,
		builderY,
		ccx2,
		builderY + strip,
		model.gridGroup.cycleLabel,
		model.gridKeyText("gridmenu_cycle_builder"),
		stripFs,
		pad,
		zone == "cycle",
		false,
		model.clashing.gridmenu_cycle_builder
	)
end

-- Routes a click in the grid view to the action that cell or button binds.
local function gridPress(x, y)
	model.pressGrid(gridZone(x, y))

	return true
end

-- One list row. hovered says the cursor is on it; zone and zoneIdx are then which chip
-- or button of it, in rowZone's terms.
local function drawRow(row, top, bottom, hovered, zone, zoneIdx)
	local cyc = floor((top + bottom) * 0.5)
	local lay = rowLayout(row)
	local fs = metrics.rowFs

	if row.type == "header" then
		drawHeaderBand(top, bottom, lay.text)
		if lay.addText then
			queueText(zone == "add" and lay.addTextHover or lay.addText, lay.addX, cyc, metrics.headerFs, "ov")
		end

		return
	end

	-- A note explains an empty section; it is neither lit nor clicked.
	if row.type == "note" then
		queueText(lay.text, listX1 + metrics.rowPad * 2, cyc, fs, "ov")
		return
	end

	if hovered then
		Highlight(listX1, bottom, listRight, top, metrics.csSmall, look.rowHoverOpacity, look.white)
	end

	-- Indented and followed by an arrow, to read as a way through rather than a binding.
	if row.type == "link" then
		queueText(lay.text, listX1 + metrics.rowPad * 5, cyc, fs, "ov")
		queueText(lay.arrow, lay.arrowX, cyc, fs, "ov")
		return
	end

	-- Blending is set rather than assumed: whatever drew before can leave one that shows the
	-- picture transparent surround as a solid square.
	if lay.icon then
		local s = metrics.cursorIcon
		local iy = floor((top + bottom - s) * 0.5)
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		glColor(1, 1, 1, look.cursorAlpha)
		glTexture(lay.icon)
		glTexRect(lay.iconX, iy, lay.iconX + s, iy + s)
		glTexture(false)
		glColor(1, 1, 1, 1)
	end
	queueText(zone == "label" and lay.textHover or lay.text, lay.textX, cyc, fs, "ov")

	local c1, c2 = bottom + metrics.chipInset, top - metrics.chipInset
	local mets = lay.mets
	for i = 1, #mets do
		local m = mets[i]
		local overBody = zone == "rebind" and zoneIdx == i
		local overRemove = zone == "remove" and zoneIdx == i
		local chipFill = (overBody and look.chipFillHover)
			or (m.hit and look.chipFillHit)
			or (m.clash and look.chipFillConflict)
			or look.chipFill
		RectRound(m.x, c1, m.x + m.w, c2, metrics.csSmall, 1, 1, 1, 1, chipFill)
		queueText(overBody and m.textHover or m.textKey, m.x + metrics.rowPad, cyc, m.fs, "ov")
		queueText(overRemove and look.removeHot or look.removeCold, m.removeCx, cyc, fs, "cov")
	end

	if lay.showAdd then
		local cx = lay.cx
		local overAdd = zone == "add"
		RectRound(cx, c1, cx + lay.addW, c2, metrics.csSmall, 1, 1, 1, 1, overAdd and look.addFillHover or look.addFill)
		queueText(overAdd and look.plusTextHover or look.plusText, floor(cx + lay.addW * 0.5), cyc, fs, "cov")
	end

	-- The base preset's key, as a hollow chip: a border with the row's own dark inside it.
	if lay.ghostW then
		local gx, over = lay.ghostX, zone == "revert"
		RectRound(
			gx,
			c1,
			gx + lay.ghostW,
			c2,
			metrics.csSmall,
			1,
			1,
			1,
			1,
			over and look.ghostBorderHover or look.ghostBorder
		)
		RectRound(gx + 1, c1 + 1, gx + lay.ghostW - 1, c2 - 1, metrics.csSmall, 1, 1, 1, 1, look.ghostInner)
		queueText(over and lay.ghostTextHover or lay.ghostText, gx + metrics.rowPad, cyc, lay.ghostFs, "ov")
	end
end

-- Split out of view.draw: each modal is self-contained, and one function holding every
-- draw path ran past the 60-upvalue ceiling.
local function drawCaptureModal(mx, my)
	local bx1, by1, bx2, by2, ok, cancel = captureGeometry()
	local cs = metrics.csButton
	local cx = floor((bx1 + bx2) * 0.5)

	-- The whole window, not the inset area inside it: a modal that leaves the panel's own
	-- border lit does not read as covering it.
	RectRound(
		metrics.winX1,
		metrics.winY1,
		metrics.winX2,
		metrics.winY2,
		metrics.csPanel,
		1,
		1,
		1,
		1,
		{ 0, 0, 0, 0.55 }
	)
	UiElement(bx1, by1, bx2, by2, 1, 1, 1, 1, 1, 1, 1, 1, WG.FlowUI.clampedOpacity)

	local tfs = floor(rowHeight * 0.6)
	local sfs = floor(rowHeight * 0.5)
	local bigfs = floor(rowHeight * 0.95)
	-- A capture opened on an existing binding still shows it, but a held modifier previews over
	-- the top, and letting go puts the original back.
	local heldRaw = model.modPrefix()
	local held = heldRaw ~= "" and keybindModel.displayKeyset(heldRaw, model.working.layout) or ""
	-- What the big line in the middle shows: the keyset formed so far, which includes the
	-- one the modal opened on. Whether that is worth committing is a separate question.
	local hasChain = #model.capturing.elems > 0 and not (model.capturing.seeded and held ~= "")
	local canAccept = model.captureCanAccept()

	drawButtonFace(cancel, buttonFill)
	if isInRect(mx, my, cancel[1], cancel[2], cancel[3], cancel[4]) then
		Highlight(cancel[1], cancel[2], cancel[3], cancel[4], cs, hoverOpacity, look.white)
	end
	-- Absent until there is a change to accept, rather than present and dead: a greyed button
	-- invites a click that does nothing.
	if canAccept then
		local overOk = isInRect(mx, my, ok[1], ok[2], ok[3], ok[4])
		drawButtonFace(ok, overOk and confirmFillHover or confirmFill)
	end

	local chainStr
	if hasChain then
		chainStr = keybindModel.displayKeyset(model.chainRaw(), model.working.layout)
	elseif held ~= "" then
		chainStr = held .. "_"
	else
		chainStr = L.pressKey
	end
	local hasContent = hasChain or held ~= ""

	-- Shrink toward a readable floor, then wrap to a second line, then ellipsize.
	local chainMaxW = (bx2 - bx1) - floor(32 * scale)
	local minFs = floor(rowHeight * 0.5)
	local chainLines, chainFs = { chainStr }, bigfs
	if hasChain then
		local naturalW = font:GetTextWidth(chainStr) * bigfs
		if naturalW <= chainMaxW then
			chainLines, chainFs = { chainStr }, bigfs
		elseif floor(bigfs * chainMaxW / naturalW) >= minFs then
			chainLines, chainFs = { chainStr }, floor(bigfs * chainMaxW / naturalW)
		else
			local tokens = {}
			for _, e in ipairs(model.capturing.elems) do
				tokens[#tokens + 1] = keybindModel.displayKeyset(model.elemRaw(e), model.working.layout)
			end
			chainLines, chainFs = wrapChainTwoLines(tokens, keybindModel.chainSep, chainMaxW, minFs), minFs
		end
	else
		local w = font:GetTextWidth(chainStr) * bigfs
		if w > chainMaxW then
			chainFs = math.max(minFs, floor(bigfs * chainMaxW / w))
		end
	end

	-- Bar draining over the chain window: time left to extend before it resets. The
	-- track is always drawn so the modal does not gain a row the moment a key lands.
	local barW = floor((bx2 - bx1) * 0.5)
	local barX = floor(cx - barW * 0.5)
	local barY = by1 + floor(88 * scale)
	local barH = floor(4 * scale)
	RectRound(barX, barY, barX + barW, barY + barH, floor(2 * scale), 1, 1, 1, 1, { 1, 1, 1, 0.1 })
	if hasChain and model.capturing.lastPress then
		local frac = 1 - (spDiffTimers(spGetTimer(), model.capturing.lastPress) * 1000) / model.capturing.timeout
		if frac < 0 then
			frac = 0
		end
		if frac > 0 then
			RectRound(
				barX,
				barY,
				barX + floor(barW * frac),
				barY + barH,
				floor(2 * scale),
				1,
				1,
				1,
				1,
				{ 0.9, 0.7, 0.2, 0.9 }
			)
		end
	end

	local chainCy = by1 + floor(122 * scale)
	local lineStep = floor(chainFs * 1.15)

	-- Other actions already on the keyset being formed, named under it before it is accepted.
	local clash
	if canAccept then
		local raws = model.capturing.pair and model.shiftPairRaws(model.capturing.elems) or { model.chainRaw() }
		local others = model.conflictsOf(model.capturing.action, raws)
		if others then
			local names = {}
			for i = 1, #others do
				names[i] = model.labels[others[i].action] or others[i].action
			end
			local line = BAR.I18N("ui.keybinds.editor.conflictCapture", { actions = table.concat(names, ", ") })
			clash = colorHeader .. text.fit(font, line, chainMaxW, sfs)
		end
	end

	font:Begin()
	font:SetOutlineColor(look.outline)
	if clash then
		font:Print(clash, cx, by1 + floor(64 * scale), sfs, "cov")
	end
	font:Print(
		colorText .. text.fit(font, model.capturing.label or model.capturing.action, chainMaxW, tfs),
		cx,
		by2 - floor(26 * scale),
		tfs,
		"cov"
	)
	for li = 1, #chainLines do
		local ly = floor(chainCy + (#chainLines - 1) * lineStep * 0.5 - (li - 1) * lineStep)
		font:Print((hasContent and colorKey or colorDim) .. chainLines[li], cx, ly, chainFs, "cov")
	end
	font:Print(
		colorText .. L.cancel,
		floor((cancel[1] + cancel[3]) * 0.5),
		floor((cancel[2] + cancel[4]) * 0.5),
		sfs,
		"cov"
	)
	if canAccept then
		font:Print(colorText .. L.accept, floor((ok[1] + ok[3]) * 0.5), floor((ok[2] + ok[4]) * 0.5), sfs, "cov")
	end
	font:End()
end

-- Shared by the drawing and the bar hit test so a press lands on what was painted. The rect
-- is nil while every line fits.
function state.previewGeometry(pv, x1, y1, x2, y2)
	local lineH = floor(rowHeight * 0.66)
	local pad = floor(6 * scale)
	local barW = WG.FlowUI.Scroller.width(scale)
	local visible = math.max(1, floor((y2 - y1 - pad * 2) / lineH))
	local most = math.max(0, #pv.lines - visible)
	local bar = most > 0 and { x2 - pad - barW, y1 + pad, x2 - pad, y2 - pad } or nil

	return lineH, pad, visible, most, bar
end

-- The bar that scrolls the import's lines, made with the first draw or press.
local function previewBar(pv)
	if not pv.scroller then
		pv.lineH, pv.most = pv.lineH or 1, pv.most or 0
		pv.scroller = WG.FlowUI.Scroller.new(function()
			return #pv.lines * pv.lineH, pv.scroll * pv.lineH, pv.most
		end)
	end

	return pv.scroller
end

-- Fitted to the box once per width and face.
function state.drawPreview(pv, x1, y1, x2, y2, mx, my)
	local mono = WG.fonts.getFont(3) or font
	local fs = floor(rowHeight * 0.5)
	local lineH, pad, visible, most, bar = state.previewGeometry(pv, x1, y1, x2, y2)
	pv.visible = visible
	local scroller = previewBar(pv)

	pv.lineH, pv.most = lineH, most
	if bar then
		scroller:setRect(bar[1], bar[2], bar[3], bar[4])
	end
	local _, _, lmb = spGetMouseState()
	pv.scroll = scroller:drag(my, lmb) or pv.scroll
	if pv.scroll > most then
		pv.scroll = most
	end
	if pv.scroll < 0 then
		pv.scroll = 0
	end

	RectRound(x1, y1, x2, y2, metrics.csSmall, 1, 1, 1, 1, look.previewFill)
	-- The gutter: wide enough for the last line's number, set off from the lines by its own
	-- shade, rounded with the box on its outer corners.
	local gutterW = floor(mono:GetTextWidth(tostring(#pv.lines)) * fs) + pad * 2
	RectRound(x1, y1, x1 + gutterW, y2, metrics.csSmall, 1, 0, 0, 1, look.previewGutter)

	local textX1 = x1 + gutterW + pad
	local textX2 = bar and (bar[1] - pad) or (x2 - pad)
	if pv.fitW ~= textX2 - textX1 or pv.fitFont ~= mono then
		pv.fitW, pv.fitFont = textX2 - textX1, mono
		for i, line in ipairs(pv.lines) do
			local fitted = text.fit(mono, line.text, pv.fitW, fs)
			-- A binding reads as the chips do: its key in gold, its action in the row colour.
			local keyset, action = fitted:match("^%s*bind%s+(%S+)%s+(.*)$")
			if line.kind == "bind" and keyset then
				line.shown = colorFaded .. "bind " .. colorKey .. keyset .. " " .. colorAction .. action
			else
				line.shown = look.previewColours[line.kind] .. fitted
			end
			line.num = (line.kind == "error" and colorDanger or colorFaded) .. i
		end
	end

	local last = math.min(#pv.lines, pv.scroll + visible)
	for i = pv.scroll + 1, last do
		if pv.lines[i].kind == "error" then
			local top = y2 - pad - (i - pv.scroll - 1) * lineH
			RectRound(x1 + gutterW, top - lineH, textX2 + pad, top, 0, 1, 1, 1, 1, look.previewErrorFill)
		end
	end
	if bar then
		scroller:draw(scroller:isOverThumb(mx, my))
	end

	mono:Begin()
	mono:SetOutlineColor(look.outline)
	for i = pv.scroll + 1, last do
		local line = pv.lines[i]
		local cy = floor(y2 - pad - (i - pv.scroll - 0.5) * lineH)
		mono:Print(line.num, x1 + gutterW - pad, cy, fs, "rov")
		mono:Print(line.shown, textX1, cy, fs, "ov")
	end
	mono:End()
end

local function drawProfileDialog(mx, my)
	local bx1, by1, bx2, by2, ok, cancel, field, discard, messageLines, messageStep, box, choice = dialogGeometry()
	local cs = metrics.csButton
	local cx = floor((bx1 + bx2) * 0.5)
	local tfs = floor(rowHeight * 0.6)
	local sfs = floor(rowHeight * 0.5)

	-- The whole window, not the inset area inside it: a modal that leaves the panel's own
	-- border lit does not read as covering it.
	RectRound(
		metrics.winX1,
		metrics.winY1,
		metrics.winX2,
		metrics.winY2,
		metrics.csPanel,
		1,
		1,
		1,
		1,
		{ 0, 0, 0, 0.55 }
	)
	UiElement(bx1, by1, bx2, by2, 1, 1, 1, 1, 1, 1, 1, 1, WG.FlowUI.clampedOpacity)

	-- Anything whose accept saves is green, anything destructive is red, wherever it
	-- appears; a tinted button brightens on hover instead of taking the white overlay.
	local _, blocked = model.dialogName()
	local acceptSaves = not blocked and (model.dialog.save or (not model.dialog.message and not model.dialog.danger))
	local buttons = {
		{ r = ok, danger = not blocked and model.dialog.danger, confirm = acceptSaves, inert = blocked },
	}
	if cancel then
		buttons[#buttons + 1] = { r = cancel }
	end
	if model.dialog.middle then
		buttons[#buttons + 1] = { r = discard, danger = model.dialog.middle.danger }
	end
	for _, b in ipairs(buttons) do
		local r = b.r
		local hovered = isInRect(mx, my, r[1], r[2], r[3], r[4])
		local base = (b.danger and dangerFill) or (b.confirm and confirmFill)
		local lift = (b.danger and dangerFillHover) or (b.confirm and confirmFillHover)
		local fill = base and (hovered and lift or base)
		drawButtonFace(r, fill or buttonFill)
		if not fill and hovered and not b.inert then
			Highlight(r[1], r[2], r[3], r[4], cs, hoverOpacity, { 1, 1, 1 })
		end
	end

	-- Its own geometry and text, ahead of the dialog's own batch of text.
	if box then
		state.drawPreview(model.dialog.preview, box[1], box[2], box[3], box[4], mx, my)
	end
	if choice then
		local sw, hit = choice.switch, choice.hit
		WG.FlowUI.Draw.Toggle(
			sw[1],
			sw[2],
			sw[3],
			sw[4],
			choice.on and 1 or 0,
			not choice.locked and isInRect(mx, my, hit[1], hit[2], hit[3], hit[4])
		)
	end

	font:Begin()
	font:SetOutlineColor(look.outline)
	font:Print(
		colorText .. text.fit(font, model.dialog.title, bx2 - bx1 - floor(32 * scale), tfs),
		cx,
		by2 - floor(26 * scale),
		tfs,
		"cov"
	)
	if box then
		font:Print(
			text.fit(font, model.dialog.preview.summary, bx2 - bx1 - floor(32 * scale), sfs),
			cx,
			by2 - floor(48 * scale),
			sfs,
			"cov"
		)
	end
	if model.dialog.middle then
		font:Print(
			colorText .. model.dialog.middle.label,
			floor((discard[1] + discard[3]) * 0.5),
			floor((discard[2] + discard[4]) * 0.5),
			sfs,
			"cov"
		)
	end
	if messageLines then
		-- Centred between the title and the buttons: a message dialog has no field, and a
		-- message sitting where the field would be reads as pushed down against the buttons.
		local titleBottom = by2 - floor(26 * scale) - floor(tfs * 0.5)
		local top = floor((titleBottom + ok[4]) * 0.5 + (#messageLines - 1) * messageStep * 0.5)
		for i = 1, #messageLines do
			font:Print(
				colorDim .. text.fit(font, messageLines[i], bx2 - bx1 - floor(32 * scale), sfs),
				cx,
				top - (i - 1) * messageStep,
				sfs,
				"cov"
			)
		end
	end
	if cancel then
		font:Print(
			colorText .. L.cancel,
			floor((cancel[1] + cancel[3]) * 0.5),
			floor((cancel[2] + cancel[4]) * 0.5),
			sfs,
			"cov"
		)
	end
	font:Print(
		(blocked and colorDim or colorText) .. model.acceptLabelFor(model.dialog),
		floor((ok[1] + ok[3]) * 0.5),
		floor((ok[2] + ok[4]) * 0.5),
		sfs,
		"cov"
	)
	local fieldCy = floor((field[2] + field[4]) * 0.5)
	if choice then
		font:Print((choice.locked and colorDim or colorText) .. choice.label, choice.labelX, fieldCy, sfs, "ov")
		if choice.hint then
			font:Print(colorDim .. text.fit(font, choice.hint, field[3] - field[1], sfs), field[1], fieldCy, sfs, "ov")
		end
	end
	font:End()

	if choice and choice.fieldless then
		return
	end

	if not model.dialog.message then
		model.nameBox:setRect(field[1], field[2], field[3], field[4], sfs)
		model.nameBox:draw()
	end
end

-- Header and footer buttons, with hotId the one under the cursor.
local function drawButtons(hotId)
	local bfs = floor(rowHeight * 0.55)
	for _, set in ipairs(buttonSets) do
		for _, b in ipairs(set) do
			local r = b.rect
			if r then
				local enabled = model.buttonEnabled(b.id)
				local hovered = enabled and hotId == b.id
				-- A tinted button loses its colour under the usual white hover overlay, so it
				-- brightens its own fill instead.
				local fill = b.fill and ((not enabled and b.fillMuted) or (hovered and b.fillHover) or b.fill)
				-- The page toggle sits pressed while its page is showing.
				if b.toggle and state.page == "keyboard" then
					fill = hovered and look.toggleFillHover or look.toggleFill
				end
				drawButtonFace(r, fill or buttonFill)

				-- A tinted button would lose its colour under the overlay, so it brightens its own fill.
				if hovered and not fill then
					Highlight(r[1], r[2], r[3], r[4], metrics.csButton, hoverOpacity, look.white)
				end

				if b.icon then
					-- Square inset so the 64x64 art keeps its aspect inside a wider button. The
					-- icon brightens with the face, so the whole button reads as one control.
					local inset = floor((r[4] - r[2]) * 0.22)
					local side = (r[4] - r[2]) - inset * 2
					local ix = floor((r[1] + r[3] - side) * 0.5)
					local iy = r[2] + inset
					local shade = (not enabled and 0.4) or (hovered and 1 or 0.82)
					-- Set explicitly: the icons are white-on-transparent, and whatever drew
					-- before could leave a blend mode that renders them as solid squares.
					glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
					glColor(shade, shade, shade, 1)
					glTexture(b.icon)
					glTexRect(ix, iy, ix + side, iy + side)
					glTexture(false)
					glColor(1, 1, 1, 1)
				else
					queueText(
						(enabled and b.textOn or b.textOff) or L[b.id],
						floor((r[1] + r[3]) * 0.5),
						floor((r[2] + r[4]) * 0.5),
						bfs,
						"cov"
					)
				end
			end
		end
	end
end

-- The list's bar draws by pixels, as headings are taller than rows, and scrolls by rows.
function state.listMeasure()
	local position = scrollOffset()

	return rowMetrics.totalH, position, maxScroll()
end

-- Reads the hover state and answers a signature of everything the baked panel is painted
-- from. Same signature, same picture, so the display list is replayed as it is.
local function panelSignature(mx, my)
	local h = hover
	local keyboardPage = state.page == "keyboard"
	h.sb = (not keyboardPage and sidebarIndexAt(mx, my)) or 0
	h.row, h.zone, h.idx = 0, "", 0
	h.gk, h.ga, h.gb = "", 0, 0
	h.btn = ""
	h.bar = 0
	h.kb = 0

	-- Over the thumb itself, which lights it. The track either side is not part of this:
	-- only the thumb is something to take hold of.
	if not keyboardPage and state.listScroller:isOverThumb(mx, my) then
		h.bar = 1
	end
	local catBar = state.catBar()
	h.catThumbHovered = false
	if catBar and not keyboardPage then
		h.catThumbHovered = state.catScroller:isOverThumb(mx, my)
		if isInRect(mx, my, catBar[1], catBar[2], catBar[3], catBar[4]) then
			h.sb = 0
		end
	end

	if keyboardPage then
		h.kb = model.keyboard:hitTest(mx, my) or 0
	elseif model.gridGroup then
		if isInRect(mx, my, listX1, listBottom(), area.x2, listTop) then
			local kind, a, b = gridZone(mx, my)
			h.gk, h.ga, h.gb = kind or "", a or 0, b or 0
		end
	elseif mx >= listX1 and mx <= listRight then
		local r, top, bottom = rowAt(my)
		local row = r and model.rows[scroll + r]
		if row then
			h.row = r
			if row.type == "editable" then
				local c1, c2 = bottom + metrics.chipInset, top - metrics.chipInset
				local zone, idx = rowZone(rowLayout(row), mx, my, c1, c2)
				h.zone, h.idx = zone or "", idx or 0
				if not zone and (row.editSelection or row.custom) and mx < metrics.keyAreaX1 then
					h.zone = "label"
				end
			elseif row.type == "header" and row.add and mx >= rowLayout(row).addX - metrics.rowPad then
				h.zone = "add"
			end
		end
	end

	for _, set in ipairs(buttonSets) do
		for _, b in ipairs(set) do
			local r = b.rect
			if r and isInRect(mx, my, r[1], r[2], r[3], r[4]) then
				h.btn = b.id
			end
		end
	end
	if not keyboardPage and isInRect(mx, my, state.addBindRect()) then
		h.btn = "addBind"
	end

	-- What the buttons read their enabled state from, alongside the hover and the list.
	return h.sb
		.. "|"
		.. h.row
		.. "|"
		.. h.zone
		.. "|"
		.. h.idx
		.. "|"
		.. h.gk
		.. "|"
		.. h.ga
		.. "|"
		.. h.gb
		.. "|"
		.. h.btn
		.. "|"
		.. scroll
		.. "|"
		.. model.rowsGen
		.. "|"
		.. layoutGen
		.. "|"
		.. (model.dirty and 1 or 0)
		.. "|"
		.. (model.activeIsOwn() and 1 or 0)
		.. "|"
		.. h.bar
		.. "|"
		.. h.cat
		.. "|"
		.. (state.listScroller:isDragging() and 1 or 0)
		.. "|"
		.. (h.catThumbHovered and 1 or 0)
		.. "|"
		.. (state.catScroller:isDragging() and 1 or 0)
		.. "|"
		.. (state.rowDrag and state.rowDrag.moved and state.rowDrag.at or 0)
		.. "|"
		.. state.page
		.. "|"
		.. (keyboardPage and model.keyboard:signature(h.kb) or "")
end

-- Shows the list or the keyboard. The tooltip is forgotten with the page: the same cursor
-- position means something else on the other one.
function state.setPage(page)
	if state.page == page then
		return
	end
	state.page = page
	state.tipKey = nil
	hover.kb = 0
	-- The rows' band depends on the page: the comparison band only shows on the list.
	state.applyListTop()
	-- The host sizes the panel to the page.
	if state.pageHook then
		state.pageHook(page)
	end
end

-- The keyboard page's body: the panel title where the list page puts it, then the keyboard.
function state.drawKeyboardPage(hoverIdx)
	model.ensureKeyboard()
	queueText(colorText .. L.title, area.x1 + metrics.sidePad, area.y2 - metrics.titleY, metrics.titleFs, "ov")
	KeyboardView.draw(model.keyboard, hoverIdx)
end

-- Compiled into the panel display list, so an idle frame replays it for one call instead of
-- a few hundred draws.
local function drawPanel()
	local h = hover
	if state.page == "keyboard" then
		state.drawKeyboardPage(h.kb)
	else
		drawSidebar(h.sb)
	end

	if state.page == "keyboard" then
		flushText()
	elseif model.gridGroup then
		drawGridMenu(h.gk, h.ga, h.gb)
		flushText()
	else
		-- A dark strip rather than a heading, so it reads as a control and not as a second title.
		if state.compareBand() and metrics.compareY1 then
			local y1, y2 = metrics.compareY1, metrics.compareY2
			RectRound(listX1, y1, listRight, y2, metrics.csSmall, 1, 1, 1, 1, look.previewFill)
			local inset = floor(4 * scale)
			queueText(
				colorDim .. (L.compareWith or ""),
				metrics.compareCaptionX,
				text.baseline(font, y1 + inset, y2 - inset, metrics.compareFs),
				metrics.compareFs,
				"ro"
			)
		end
		-- Whole rows only: the band can end mid-row, and a row painted across the footer
		-- would be clipped by nothing.
		local base = scrollOffset()
		local lb = listBottom()
		for r = 1, #model.rows - scroll do
			local row = model.rows[scroll + r]
			if not row then
				break
			end
			local top = listTop - (row.off - base)
			local bottom = top - rowHeightOf(row)
			if bottom < lb then
				break
			end
			local hovered = h.row == r
			local drag = state.rowDrag
			if drag and drag.moved and drag.at == scroll + r then
				RectRound(listX1, bottom, listRight, top, metrics.csSmall, 1, 1, 1, 1, look.selectedFill)
			end
			drawRow(row, top, bottom, hovered, hovered and h.zone or "", h.idx)
		end
		flushText()

		state.listScroller:setRect(barX1, lb, area.x2 - metrics.edgeInset, listTop)
		state.listScroller:draw(h.bar == 1)
	end

	-- The picker's caption. Nothing about it changes between layouts, so it bakes with the
	-- body rather than printing live beside the picker it names.
	-- Dim, so the preset name in the picker beside it stays the thing that is read.
	queueText(colorDim .. L.preset, metrics.presetLabelX, metrics.presetLabelY, metrics.presetLabelFs, "o")

	-- Where staged edits go. On a default it shows before anything is staged, too: that is
	-- when a player is working out whether editing it is safe.
	local own = model.activeIsOwn()
	local notice = (model.dirty and (own and L.noticeUnsavedText or L.noticeDefaultUnsavedText))
		or (not own and L.noticeDefaultText)
	if notice then
		queueText(notice, metrics.noticeX, metrics.noticeY, metrics.noticeFs, "o")
	end

	drawButtons(h.btn)
	flushText()
end

-- The tooltip widget owns the hover delay and only draws once the cursor settles; it
-- keeps the area table, so this is redone whenever layoutHeader makes new rects.
local function registerTooltips()
	local own = model.activeIsOwn()
	for _, b in ipairs(headerButtons) do
		if b.rect then
			WG["tooltip"].AddTooltip(b.tooltipId, b.rect, L[(not own and b.tipLocked) or b.tip], nil, L[b.id])
		end
	end
	state.tooltipsRegistered = true
end

-- Built once per thing hovered and shown every frame after, the tooltip widget showing only
-- what it was told this frame.
function state.showTooltips(mx, my)
	local tip = WG["tooltip"]
	if not tip or model.dialog or model.capturing or model.selectionBuilder:isOpen() then
		return
	end

	local key, title, content
	-- The preset picker's options, and the comparison picker's while its band is up: both
	-- name presets, so both get the preset's description.
	local pick = model.presetDropdown:optionAt(mx, my)
	local pickOptions, pickSelected = model.presetOptions, model.presetDropdown.selected
	if not pick and state.compareBand() then
		pick = model.compareDropdown:optionAt(mx, my)
		pickOptions, pickSelected = model.compareDropdown.options, model.compareDropdown.selected
	end
	if pick then
		local opt = pick > 0 and pickOptions[pick] or pickOptions[pickSelected]
		if opt and opt.name then
			key = "preset|" .. opt.name
			title = opt.name
			if key ~= state.tipKey then
				content = model.presetTip(opt.name)
			end
		end
	elseif state.page ~= "list" then
		-- The keyboard page: the key under the cursor, on the layer showing, or the view toggle.
		if hover.kb ~= 0 then
			model.ensureKeyboard()
			key, title = model.keyboard:tooltip(hover.kb)
			if key and key ~= state.tipKey then
				content = model.keyboard:tooltipContent(hover.kb)
			end
		end
	elseif hover.sb > 0 and model.categories[hover.sb] and model.categories[hover.sb].key == model.changedKey then
		key = "changed|" .. tostring(model.base and model.base.name)
		title = model.categories[hover.sb].label
		if key ~= state.tipKey then
			content = model.changedTip()
		end
	elseif hover.row > 0 then
		local row = model.rows[scroll + hover.row]
		if row and row.type == "editable" then
			key = "row|"
				.. row.action
				.. "|"
				.. hover.zone
				.. "|"
				.. hover.idx
				.. "|"
				.. model.rowsGen
				.. "|"
				.. layoutGen
			title = row.label
			if key ~= state.tipKey then
				local m = hover.idx > 0 and rowLayout(row).mets[hover.idx]
				content, title = model.rowTip(row, hover.zone, m and m.group)
			end
		end
	end

	if not key then
		state.tipKey = nil

		return
	end
	if key ~= state.tipKey then
		state.tipKey, state.tipTitle = key, title
		state.tipContent = model.wrapTip(content, font, (tip.getFontsize and tip.getFontsize() or 12) * 90)
	end
	if state.tipContent then
		tip.ShowTooltip("keybindeditor", state.tipContent, nil, nil, state.tipTitle)
	end
end

-- The header controls and the modals draw live; the body is replayed until panelSignature
-- says something moved. Defined here rather than beside `shade`: it reads popup geometry.
function shade.update()
	if model.capturing then
		local bx1, by1, bx2, by2 = captureGeometry()
		shade.rect("capture", bx1, by1, bx2, by2)
	else
		shade.rect("capture")
	end

	if model.dialog then
		local bx1, by1, bx2, by2 = dialogGeometry()
		shade.rect("dialog", bx1, by1, bx2, by2)
	else
		shade.rect("dialog")
	end

	if model.selectionBuilder:isOpen() then
		shade.rect("selection", model.selectionBuilder:rect())
	else
		shade.rect("selection")
	end

	-- The list the picker drops, which stands clear of the control and over the rows.
	local opts = model.presetDropdown and model.presetDropdown:isOpen() and model.presetDropdown.optRects
	if opts and opts[1] then
		shade.rect("picker", opts[1].x1, opts[#opts].y1, opts[1].x2, opts[1].y2)
	else
		shade.rect("picker")
	end

	local compare = model.compareDropdown
	local copts = compare and state.compareBand() and compare:isOpen() and compare.optRects
	if copts and copts[1] then
		shade.rect("compare", copts[1].x1, copts[#copts].y1, copts[1].x2, copts[1].y2)
	else
		shade.rect("compare")
	end
end
function view.draw()
	if not font then
		view.init()
	end
	if not model.working then
		view.refresh()
	end
	if select(2, model.widgetActions.manifests()) ~= model.manifestsVersion then
		model.reloadCatalog()
	end
	if state.layoutPending or state.presetsGen ~= model.presetsGen then
		layoutHeader()
	end

	-- Widgets on lower layers draw first and leave blending, colour and depth wherever they
	-- finished, which changes how everything below composites from one frame to the next.
	glTexture(false)
	glColor(1, 1, 1, 1)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(false)

	local rawMx, rawMy, lmb = spGetMouseState()
	local step = state.listScroller:drag(rawMy, lmb)
	if step then
		scroll = step
		clampScroll()
	end
	local catStep = state.catScroller:drag(rawMy, lmb)
	if catStep then
		catScrolled(catStep - hover.cat)
	end
	if state.rowDrag then
		state.dragRow(rawMy, lmb)
	end

	-- Prevent the hover over preset options and modals from also being detected by the
	-- regular rows, sidebar and buttons sitting underneath them.
	local mx, my = rawMx, rawMy
	if
		model.dialog
		or model.capturing
		or model.presetDropdown:isOpen()
		or model.compareDropdown:isOpen()
		or model.selectionBuilder:isOpen()
		or (state.rowDrag and state.rowDrag.moved)
	then
		mx, my = -1, -1
	end

	-- The keyboard page shows the layer of whatever is held on the real keyboard, for as long
	-- as it is held; the signature below carries the layer, so the picture follows.
	if state.page == "keyboard" then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		model.keyboard:setHeld(alt, ctrl, meta, shift)
	end

	local sig = panelSignature(mx, my)
	if sig ~= state.panelSig then
		if state.panelList then
			gl.DeleteList(state.panelList)
		end
		state.panelList = gl.CreateList(drawPanel)
		state.panelSig = sig
	end
	gl.CallList(state.panelList)

	model.searchBox:draw()

	-- The comparison picker, live like the preset picker: its list opens over the rows.
	if state.compareBand() then
		if model.compareDropdown:isOpen() then
			shade.float("compare", function()
				model.compareDropdown:draw()
			end)
		else
			shade.drop("compare")
			model.compareDropdown:draw()
		end
	else
		shade.drop("compare")
	end

	if not state.tooltipsRegistered and WG["tooltip"] then
		registerTooltips()
	end

	-- Each of these covers UI rather than map, so it takes the blur with it and is drawn
	-- back on top of it. See `shade` for why that is two steps and not one.
	if model.presetDropdown:isOpen() then
		shade.float("picker", function()
			model.presetDropdown:draw()
		end)
	else
		shade.drop("picker")
		model.presetDropdown:draw()
	end

	-- Real cursor: these are the overlay, so the hover is theirs to detect.
	if model.capturing then
		shade.float("capture", function()
			drawCaptureModal(rawMx, rawMy)
		end)
	else
		shade.drop("capture")
	end

	if model.dialog then
		shade.float("dialog", function()
			drawProfileDialog(rawMx, rawMy)
		end)
	else
		shade.drop("dialog")
	end

	if model.selectionBuilder:isOpen() then
		shade.float("selection", function()
			BuilderView.draw(model.selectionBuilder, rawMx, rawMy)
		end)
	else
		shade.drop("selection")
	end

	-- After they have laid themselves out, so the blur behind one is the right size on
	-- the frame it appears rather than the one after.
	shade.update()

	state.showTooltips(rawMx, rawMy)
end

-- The row a dragged one would land on: the nearest whole one painted when the cursor is off the band.
function state.rowNear(y)
	local lb = listBottom()
	local r = rowAt(math.max(math.min(y, listTop), lb + 1))
	if r then
		return scroll + r
	end

	local base, last = scrollOffset(), scroll + 1
	for i = scroll + 1, #model.rows do
		if listTop - (model.rows[i].off - base) - rowHeightOf(model.rows[i]) < lb then
			break
		end
		last = i
	end

	return last
end

-- A held row follows the cursor within its own block. Past either end of the band the list
-- scrolls under it, faster the further out the cursor is.
function state.dragRow(y, held)
	local d = state.rowDrag
	if not d then
		return
	end

	if not held then
		state.rowDrag = nil
		if d.moved then
			model.stageRowOrder(d.reorder)
		else
			d.click()
		end

		return
	end

	-- A rebuild under the drag leaves nothing for it to hold.
	local holding = model.rows[d.at]
	if not (holding and holding.action == d.action and holding.reorder == d.reorder) then
		state.rowDrag = nil

		return
	end

	if not d.moved then
		if math.abs(y - d.y0) < floor(4 * scale) then
			return
		end
		d.moved, d.carry, d.timer = true, 0, spGetTimer()
	end

	local now = spGetTimer()
	local dt = spDiffTimers(now, d.timer)
	d.timer = now
	local lb = listBottom()
	local past = (y > listTop and y - listTop) or (y < lb and y - lb) or 0
	if past == 0 then
		d.carry = 0
	else
		d.carry = d.carry + dt * (6 + 12 * math.abs(past) / rowHeight)
		while d.carry >= 1 do
			d.carry = d.carry - 1
			scroll = scroll + (past > 0 and -1 or 1)
		end
		clampScroll()
	end

	local first, last = model.reorderSpan(d.at)
	local to = state.rowNear(y)
	if to < first then
		to = first
	elseif to > last then
		to = last
	end
	if to ~= d.at then
		model.moveRow(d.at, to)
		d.at = to
	end
end

----------------------------------------------------------------
-- Input
----------------------------------------------------------------

-- Scrolls the list; a modal swallows the wheel instead, the import preview scrolling its
-- own lines with it.
function view.mouseWheel(up, value)
	if model.selectionBuilder:isOpen() then
		model.selectionBuilder:mouseWheel(up)

		return
	end
	if model.dialog then
		local pv = model.dialog.preview
		if pv then
			local mx, my = spGetMouseState()
			local _, _, _, _, _, _, _, _, _, _, box = dialogGeometry()
			if box and isInRect(mx, my, box[1], box[2], box[3], box[4]) then
				-- Clamped at the top here and at the bottom by the draw, which knows how many
				-- lines the box holds.
				pv.scroll = math.max(0, pv.scroll + (up and -3 or 3))
			end
		end

		return
	end
	if model.capturing or model.gridGroup or state.page == "keyboard" then
		return
	end

	local mx, my = spGetMouseState()
	-- Over the column it scrolls the column, over anything else the list. A wheel that
	-- moved the list while the cursor was on the categories would read as broken.
	if mx <= area.x1 + sidebarW and my > state.sidebarBottom() and my <= sidebarTop() then
		catScrolled(up and -1 or 1)
	elseif my >= listBottom() and my <= listTop then
		-- Ctrl moves three notches at once, Shift a whole page - the rows the band holds from where
		-- the list is now, since headings are taller than the bindings under them.
		local _, ctrl, _, shift = Spring.GetModKeyState()
		local step = ctrl and 9 or 3
		if shift then
			ensureRowMetrics()
			local band, used = listTop - listBottom(), 0
			step = 0
			for i = scroll + 1, #model.rows do
				used = used + rowHeightOf(model.rows[i])
				if used > band then
					break
				end
				step = step + 1
			end
			step = math.max(1, step)
		end
		scroll = scroll + (up and -step or step)
		clampScroll()
	end
end

-- Which zone of an editable row a click hit, through the same layout drawRow painted.
local function hitTestRow(row, x)
	local lay = rowLayout(row)
	local zone, i = rowZone(lay, x)
	if i then
		return zone, lay.mets[i].group.raws
	end

	return zone
end

-- Returns true when the click landed in the column, selected or not, so it never falls
-- through to the list behind it.
local function sidebarPress(x, y)
	if isInRect(x, y, state.addBindRect()) then
		model.addBind()

		return true
	end
	if x < area.x1 or x > area.x1 + sidebarW or y < state.sidebarBottom() or y > sidebarTop() then
		return false
	end

	local i = sidebarIndexAt(x, y)
	local c = i and model.categories[i]
	if c and not c.header and model.selectedCategory ~= c.key then
		model.selectCategory(c.key)
	end

	return true
end

-- Routes a click to whichever layer is on top: modal, dropdown, sidebar, then the list.
function view.mousePress(x, y, button)
	if not isInRect(x, y, area.x1, area.y1, area.x2, area.y2) then
		return false
	end

	if model.dialog then
		if button == 1 then
			local bx1, by1, bx2, by2, ok, cancel, _, discard, _, _, box, choice = dialogGeometry()
			if isInRect(x, y, ok[1], ok[2], ok[3], ok[4]) then
				model.acceptDialog()
			elseif model.dialog.middle and isInRect(x, y, discard[1], discard[2], discard[3], discard[4]) then
				model.middleDialog()
			elseif
				(cancel ~= nil and isInRect(x, y, cancel[1], cancel[2], cancel[3], cancel[4]))
				or x < bx1
				or x > bx2
				or y < by1
				or y > by2
			then
				model.cancelDialog()
			elseif box and isInRect(x, y, box[1], box[2], box[3], box[4]) then
				local pv = model.dialog.preview
				local _, _, _, _, bar = state.previewGeometry(pv, box[1], box[2], box[3], box[4])
				if bar and isInRect(x, y, bar[1], bar[2], bar[3], bar[4]) then
					pv.scroll = previewBar(pv):press(y) or pv.scroll
				end
			elseif choice and isInRect(x, y, choice.hit[1], choice.hit[2], choice.hit[3], choice.hit[4]) then
				if not choice.locked then
					model.dialog.choice.set(not model.dialog.choice.on)
				end
			elseif not model.dialog.message and not model.dialog.nameless then
				model.nameBox:mousePress(x, y)
			end
		end

		return true
	end

	local builder = model.selectionBuilder
	if builder:isOpen() then
		if button == 1 and not BuilderView.pressBar(builder, x, y) then
			builder:mousePress(x, y)
		end

		return true
	end

	-- In the modal, mouse1 drives its controls; only side buttons (mouse4+) bind.
	if model.capturing then
		local bx1, by1, bx2, by2, ok, cancel = captureGeometry()
		if button == 1 then
			-- Only while Accept is actually on screen; where it would be is otherwise just
			-- part of the modal and swallows the click.
			if model.captureCanAccept() and isInRect(x, y, ok[1], ok[2], ok[3], ok[4]) then
				model.commitCapture(model.chainRaw())
			elseif
				(isInRect(x, y, cancel[1], cancel[2], cancel[3], cancel[4]))
				or x < bx1
				or x > bx2
				or y < by1
				or y > by2
			then
				model.capturing = nil
			end
		elseif button >= 4 then
			model.appendChain({ sym = "mouse" .. button, mods = model.modPrefix() })
		end
		return true
	end

	if button ~= 1 then
		return true
	end

	-- The open list draws over the header and footer, so it gets the click before they do.
	-- Closed, this only claims its own toggle and everything below still sees the press.
	local ddWasOpen = model.presetDropdown:isOpen()
	if model.presetDropdown:mousePress(x, y) then
		model.searchBox:blur()
		model.capturing = nil

		return true
	end
	if ddWasOpen then
		return true
	end

	-- The comparison picker likewise, while its band is up.
	if state.compareBand() then
		local wasOpen = model.compareDropdown:isOpen()
		if model.compareDropdown:mousePress(x, y) then
			model.searchBox:blur()

			return true
		end
		if wasOpen then
			return true
		end
	end

	for _, set in ipairs(buttonSets) do
		for _, b in ipairs(set) do
			local r = b.rect
			if r and isInRect(x, y, r[1], r[2], r[3], r[4]) then
				model.searchBox:blur()
				model.presetDropdown:close()
				if b.id == "keyboard" then
					state.setPage(state.page == "keyboard" and "list" or "keyboard")
				else
					model.pressButton(b.id)
				end

				return true
			end
		end
	end

	if model.searchBox:mousePress(x, y) then
		model.capturing = nil
		return true
	end
	model.searchBox:blur()

	-- A bound key goes to the list page filtered to that key on that layer.
	if state.page == "keyboard" then
		model.ensureKeyboard()
		local kind, key, layer = model.keyboard:mousePress(x, y, button)
		if kind == "key" then
			state.setPage("list")
			model.showKey(key, layer)
		end

		return true
	end

	-- Ahead of the entries, which reach under the bar and would take the press as a pick.
	local catBar = state.catBar()
	if catBar and isInRect(x, y, catBar[1], catBar[2], catBar[3], catBar[4]) then
		local step = state.catScroller:press(y)
		if step then
			catScrolled(step - hover.cat)
		end

		return true
	end

	if sidebarPress(x, y) then
		return true
	end

	if not model.gridGroup and isInRect(x, y, barX1, listBottom(), area.x2, listTop) then
		local step = state.listScroller:press(y)
		if step then
			scroll = step
			clampScroll()
		end

		return true
	end

	if model.gridGroup and isInRect(x, y, listX1, listBottom(), area.x2, listTop) then
		return gridPress(x, y)
	end

	if isInRect(x, y, listX1, listBottom(), listRight, listTop) then
		-- Through the same lookup the drawing uses, so the band's last partial row - which
		-- is never painted - cannot be clicked either.
		local r = rowAt(y)
		local row = r and model.rows[scroll + r]
		if row and row.type == "editable" then
			local kind, raw = hitTestRow(row, x)
			if kind then
				model.handleZone(kind, row.action, row.label, raw)
			elseif (row.editSelection or row.custom) and x < metrics.keyAreaX1 then
				local function click()
					model.pressLabel(row)
				end
				-- Held rather than clicked until the button comes up, since moving first is a drag.
				if row.reorder then
					state.rowDrag =
						{ at = scroll + r, action = row.action, reorder = row.reorder, y0 = y, click = click }
				else
					click()
				end
			end
		elseif row and row.type == "header" and row.add and x >= rowLayout(row).addX - metrics.rowPad then
			model.openSelectionBuilder()
		elseif row and row.type == "link" then
			model.selectCategory(row.category)
		end
		return true
	end

	return true
end

-- The model's news, answered in this window's terms.
local told = model.view
told.rowsChanged = function()
	-- The Changed section lowers the rows for its picker; any other section has them back.
	state.applyListTop()
	state.layoutCompare()
	clampScroll()
end
told.scrollToTop = function()
	scroll = 0
end
told.layout = layoutHeader

-- What the host reaches through this view.
view.model = model
view.confirmClose = model.guardDirty
view.hasStagedEdits = function()
	return model.dirty
end
view.applyProfile = model.applyProfile
view.textInput = model.textInput
view.keyPress = model.keyPress
view.keyRelease = model.keyRelease

return view
