-- Interactive view for the in-game keybind editor, hosted as the first tab of
-- the Keybind/Mouse Info panel. Immediate-mode in shape, but the panel body is baked
-- into a display list and replayed until something it was painted from changes.
--
-- The picker lists the shipped presets, tagged as defaults, then the player's own. Edits
-- are staged in the working model and touch neither the engine nor disk until Save, which
-- is also where a default forks: it cannot take the edits, so saving makes a new preset of
-- them, and the footer says so before anything is saved. Unsaved work is marked with a "*"
-- on the preset's name and guarded on the way out.

local keybindModel = VFS.Include("luaui/Include/keybind_model.lua")
local keybindConfig = VFS.Include("luaui/Include/keybind_config.lua")
local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")

-- Shape and rules are documented in common/configs/keybinds.README.md; this is the
-- contract Chobby and the lobby read too, so it is data rather than Lua.
local catalog = keybindConfig.load("common/configs/keybind_catalog.json") or {}
local Editbox = VFS.Include("luaui/Include/keybind_editbox.lua")
local Dropdown = VFS.Include("luaui/Include/keybind_dropdown.lua")
local Search = VFS.Include("luaui/Include/search.lua")
local profiles = VFS.Include("luaui/Include/keybind_profiles.lua")

local KEYSYMS = VFS.Include("luaui/Include/keybind_keysyms.lua")
local text = VFS.Include("luaui/Include/keybind_text.lua")

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

-- The engine loads this one file; a profile is applied by writing it here.
local customKeysFile = profiles.activeFile

local area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
local scale = 1
local rowHeight = 22
-- Sizes derived from the scale, in one table: this chunk is close to Lua's limit of
-- 200 locals, so they share a slot rather than each taking one.
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
	-- Everything that sits against the panel's right edge - the header icons, the footer
	-- buttons and the scrollbar - is held off it by this much, matching the inset the
	-- header and footer already use vertically, so a button clears all three edges equally.
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
local categories = {}
-- Selection is held as the catalog's i18n key, never its translated title, so a language
-- change cannot strand it against titles that have all moved.
---@type string?
local selectedCategory
-- Stands in for the generated Other bucket when no catalog category is titled the same.
-- A table cannot collide with a catalog key, which is always a string.
local generatedOtherKey = {}
local otherCategoryKey = generatedOtherKey
-- Set while a category asks to be drawn as the grid menu instead of a row list.
---@type table?
local gridGroup
local listRight = 0

---@type table
local working
---@type table
local resolvedCatalog
-- Grouped chips per action. Derived purely from working.byAction, and every path that
-- changes that rebuilds the rows, so rebuildRows is where it gets dropped.
local chipGroups = {}
local catalogAny, catalogAnyPrefixes, catalogShiftPair = {}, {}, {}
local L = {}
local rows = {}
-- Bumped by rebuildRows, so the baked panel knows the list behind it changed.
local rowsGen = 0
local scroll = 0

-- What the cursor is over, in the terms the panel paints hover with. Refilled in place
-- each frame rather than allocated.
-- `grab` is where the scrollbar's thumb was taken hold of, as the distance from the cursor
-- to its top edge, so the thumb follows the cursor instead of jumping its middle to the
-- press. It rides here rather than in a local of its own: this chunk is at Lua's ceiling of
-- 200 locals, which is why the sizes above share `metrics` too.
-- `kb` is the key under the cursor on the keyboard page.
local hover = {
	sb = 0,
	row = 0,
	zone = "",
	idx = 0,
	gk = "",
	ga = 0,
	gb = 0,
	btn = "",
	bar = 0,
	grab = 0,
	cat = 0,
	drag = false,
	kb = 0,
}
local dirty = false

-- Blur behind whatever floats over the panel, and the floating content drawn back on top
-- of it.
--
-- The panel's own backdrop is registered with InsertDlist, which is the *world* set: it
-- blurs the map behind the panel and leaves the UI alone. A popup has to blur UI - the
-- rows and buttons it covers - so it goes into the screen set instead.
--
-- That set is drawn by gfx_guishader, which copies the screen as it stands and blurs it
-- inside those rects. widgetHandler walks DrawScreen in reverse layer order, so this
-- panel (-99990) draws well before guishader (-990000) and a popup of ours inside one of
-- those rects would be blurred along with what it covers. Handing the drawing to
-- insertRenderDlist gets it replayed after the blur, which is how gui_options keeps its
-- select list crisp.
--
-- One table rather than a handful of locals, and for the same reason as `hover` above:
-- this chunk is at Lua's ceiling of 200.
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
---@type table?
local capturing

---@type table
local font
---@type function
local RectRound
---@type table
local Scroller
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
-- With nothing staged there is nothing to discard or save, so both footer buttons drop
-- most of their colour and go part transparent, sinking into the panel instead of sitting
-- on it as a slightly darker version of the live button.
local dangerFillMuted = { 0.17, 0.12, 0.12, 0.45 }
local confirmFill = { 0.17, 0.38, 0.21, 1 }
local confirmFillHover = { 0.24, 0.52, 0.29, 1 }
local confirmFillMuted = { 0.12, 0.17, 0.13, 0.45 }
local pillFill = { 0.22, 0.22, 0.22, 1 }
local sheenTop = { 1, 1, 1, 0.05 }
-- Fills and captions the list is painted with, in one table for the same reason as
-- metrics above.
local look = {
	chipFill = { 0, 0, 0, 0.35 },
	chipFillHover = { 0, 0, 0, 0.45 },
	-- A chip that answered a search by key, warmed in the gold its key is printed in, so it stands
	-- out from the rest of the row without reading as hovered.
	chipFillHit = { 0.92, 0.72, 0.27, 0.3 },
	-- A chip whose key another listed action also answers to: reddened, and its tooltip says which.
	chipFillConflict = { 0.62, 0.16, 0.12, 0.4 },
	-- The key a row had in the preset it was forked from, against the row's right edge as a
	-- hollow chip: an amber border - the hue the headings and the unsaved notice use - with the
	-- row's own dark inside it and a "default:" caption, so it reads as a note about the row
	-- rather than one more of its keys. Clicking it puts that key back.
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
	-- Lit rather than nudged: hovering used to lift the alpha alone, which on a green this
	-- soft was hard to tell from resting. A tinted element brightens its own fill instead
	-- of taking the white overlay, which would wash the green out to grey.
	addFillHover = { 0.32, 0.74, 0.4, 0.6 },
	selectedFill = { 1, 1, 1, 0.13 },
	-- The outline every string the panel prints is drawn with, set on every batch rather than
	-- once: the font is shared with every other widget, some of which set an outline of their
	-- own and leave it set, and text baked into a display list keeps whatever outline was set
	-- last. The settings panel's value, which this panel is styled after.
	outline = { 0, 0, 0, 0.4 },
	-- The keyboard page's toggle in the header, pressed while that page is showing: lifted
	-- above the resting button grey, and further under the cursor, since a tinted face takes
	-- no hover overlay.
	toggleFill = { 0.33, 0.33, 0.33, 1 },
	toggleFillHover = { 0.4, 0.4, 0.4, 1 },
	-- The category column sits on its own darker card, so it reads apart from the list.
	sidebarFill = { 0, 0, 0, 0.24 },
	sidebarFillTop = { 0, 0, 0, 0.16 },
	white = { 1, 1, 1 },
	-- Rows, categories and grid cells hover with the same FlowUI highlight the settings
	-- list uses, at the strength it gives a plain row.
	rowHoverOpacity = 0.14,
	-- Underlines are drawn as a thin bar that fades upward out of the bottom edge, each in
	-- the hue of the text above it: warm under a category heading, plain under the selected
	-- category in the column.
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
	-- The cursor an order shows in game, by the command at the front of its action, so its row
	-- carries the picture a player already knows the order by. File stems in anims/: the engine's
	-- own pairing (MouseHandler.cpp), and the cursors BAR's custom commands declare, which borrow
	-- the attack one. An order with no cursor of its own, like stop or cloak, has no entry.
	cursors = {
		move = "move",
		attack = "attack",
		areaattack = "attack",
		manuallaunch = "attack",
		manualfire = "dgun",
		settarget = "settarget",
		settargetnoground = "settarget",
		fight = "fight",
		patrol = "patrol",
		guard = "defend",
		repair = "repair",
		reclaim = "reclamate",
		resurrect = "revive",
		restore = "restore",
		capture = "capture",
		loadunits = "pickup",
		unloadunits = "unload",
		wait = "wait",
		gatherwait = "gather",
		selfd = "selfd",
	},
	-- How strongly those pictures draw. At full strength they outshout the names beside them.
	cursorAlpha = 0.85,
}

-- FlowUI's Button gradients from a bottom stop to a top one. Left to its defaults it
-- fades black up to near-transparent white, which washes a tinted button out to grey, so
-- each fill becomes a darker bottom and itself on top - the same shape gui_pregameui
-- gives its ready button. Derived once per fill and kept, since the pair is passed every
-- draw and a table per button per frame is what the rest of this file avoids.
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

-- The first frame of a cursor, looked up once per cursor. The 48 px set is the nearest to a
-- row's height. Most cursors number their frames from 0 and a few from 1; false when there is
-- neither, and the row goes without a picture.
look.cursorTextures = setmetatable({}, {
	__index = function(self, stem)
		local base = "anims/icexuick_100/cursor" .. stem
		local path = (VFS.FileExists(base .. "_0.png") and base .. "_0.png")
			or (VFS.FileExists(base .. "_1.png") and base .. "_1.png")
			or false
		self[stem] = path

		return path
	end,
})

---@type table
local searchBox
---@type table
local presetDropdown
---@type table
local nameBox
---@type function?
local menuToggle
local switchToPreset, scrollFromY

---@type table?
local dialog

-- `tip` names the tooltip's text in L, and `tipLocked` the text shown instead while the
-- active preset is a default. That is when Edit is greyed out, and its tooltip is then the
-- one place saying why.
-- The two with icons act on the active preset; the two with captions carry presets in and out
-- through the clipboard. The last is the page toggle, set apart by a wider gap: it swaps the
-- list for the keyboard overview and back, and sits pressed while the keyboard is showing.
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
	{ id = "export", tooltipId = "keybind_export", tip = "exportTooltip" },
	{ id = "import", tooltipId = "keybind_import", tip = "importTooltip" },
	{ id = "keyboard", tooltipId = "keybind_keyboard", tip = "keyboardTooltip", toggle = true, gap = 2 },
}

-- Discarding is destructive and saving is not, so the two footer buttons are coloured for
-- what they do rather than left to read alike.
local footerButtons = {
	{ id = "reset", fill = dangerFill, fillHover = dangerFillHover, fillMuted = dangerFillMuted },
	{ id = "save", fill = confirmFill, fillHover = confirmFillHover, fillMuted = confirmFillMuted },
}

local buttonSets = { headerButtons, footerButtons }

-- Panel state that is neither a size nor a colour, in one table: this chunk is at Lua's
-- ceiling of 200 locals, and the functions that only this state needs hang off it too, the
-- way `shade` does.
--   headerH/footerH: the header and footer bands, shared by the layout and by every
--     geometry derived from it.
--   layoutPending: the layout ran before the font existed and has to run again.
--   tooltipsRegistered: header tooltips are registered once per layout rather than per
--     frame, since registering with a value throws the tooltip's cached text away each time.
--   panelList/panelSig: the panel below the header controls, baked once and replayed until
--     something it was painted from changes.
--   hidden: the catalog's hidden actions. They share keys with listed ones on purpose, so
--     they are no conflict.
--   labels: each action's listed name, for naming it where another action's key clashes.
--   base: the shipped preset the active one is measured against, with its keysets by
--     action; nil when the active preset has no known origin.
--   changedKey/changedCount: the column entry listing the rows that differ from the base,
--     and how many there are, which its label says.
--   refit: the column's labels changed and have to be fitted again before they are drawn.
--   undo/snapshot: the staged keymap as it stood before each edit, and as it stands now,
--     which the next edit files. batching/batchEdited: one gesture making several edits
--     files one snapshot for the lot.
--   tipKey/tipTitle/tipText: the tooltip last built, kept until the cursor is on something
--     else, since building one wraps text.
--   page: "list" or "keyboard", the page the body shows. keyboard is the keyboard page
--     itself, and keyboardGen the rowsGen its bindings were placed from, so it is placed
--     again only once the staged keymap has changed. keyInfo: each action's card for it,
--     built from the catalog on first use and dropped with the catalog.
local state = {
	headerH = 0,
	footerH = 0,
	layoutPending = false,
	tooltipsRegistered = false,
	hidden = {},
	labels = {},
	changedKey = {},
	changedCount = -1,
	refit = false,
	undo = {},
	batching = false,
	batchEdited = false,
	---@type string
	page = "list",
	keyboard = VFS.Include("luaui/Include/keybind_keyboard.lua").new(),
	keyboardGen = -1,
}

-- A copy of the staged keymap, for putting back. Binds and keysets are copied rather than
-- shared: the edits rewrite entries in place.
function state.snapshotOf()
	local binds, byAction = {}, {}
	for i, b in ipairs(working.binds) do
		binds[i] = { keyset = b.keyset, action = b.action }
	end
	for action, ks in pairs(working.byAction) do
		local copy = {}
		for i, k in ipairs(ks) do
			copy[i] = { raw = k.raw, display = k.display }
		end
		byAction[action] = copy
	end

	return { binds = binds, byAction = byAction }
end

----------------------------------------------------------------
-- Profiles and the picker
----------------------------------------------------------------

local presetOptions = {}

-- Picker contents: the shipped presets, tagged as defaults, then the player's own, which the
-- open list sets apart with a rule. Staged edits mark whichever one is active with a "*", a
-- default included: the edits are real and unsaved either way, and where they will be saved
-- is for the footer to say, beside the button that saves them.
local function buildPresetOptions()
	local active = profiles.activeName()

	presetOptions = {}
	for _, b in ipairs(profiles.builtins) do
		local label = (dirty and b.name == active) and (b.name .. " *") or b.name
		presetOptions[#presetOptions + 1] = { label = label, name = b.name, tag = L.defaultTag, group = "default" }
	end
	for _, name in ipairs(profiles.list()) do
		local label = (dirty and name == active) and (name .. " *") or name
		presetOptions[#presetOptions + 1] = { label = label, name = name, group = "own" }
	end

	return presetOptions
end

-- Shipped profiles can be copied but not renamed or deleted.
local function activeIsOwn()
	return profiles.get(profiles.activeName()) ~= nil
end

-- Single source for whether a button is live, so it cannot draw enabled and do nothing.
local function buttonEnabled(id)
	if id == "save" or id == "reset" then
		return dirty
	end
	if id == "edit" then
		return activeIsOwn()
	end

	return true
end

local function currentPresetIndex()
	local name = profiles.activeName()
	for i = 1, #presetOptions do
		if presetOptions[i].name == name then
			return i
		end
	end

	return 1
end

----------------------------------------------------------------
-- Scrolling
----------------------------------------------------------------

local function listBottom()
	return area.y1 + state.footerH + metrics.footerGap
end

-- Whole rows the band can paint.
-- A category heading is taller than the bindings under it, so a row's position is a sum of
-- what is above it rather than its index times one height. The running total is stamped
-- onto the rows, which rebuildRows replaces wholesale, and redone when the layout moves.
local rowMetrics = { gen = -1, rows = -1, totalH = 0 }

local function rowHeightOf(row)
	return row.type == "header" and metrics.headerRowHeight or rowHeight
end

local function ensureRowMetrics()
	if rowMetrics.gen == layoutGen and rowMetrics.rows == rowsGen then
		return
	end

	local off = 0
	for i = 1, #rows do
		local row = rows[i]
		row.off = off
		off = off + rowHeightOf(row)
	end
	rowMetrics.totalH = off
	rowMetrics.gen, rowMetrics.rows = layoutGen, rowsGen
end

-- Pixels of content above the first painted row.
local function scrollOffset()
	ensureRowMetrics()
	local first = rows[scroll + 1]

	return first and first.off or 0
end

-- Furthest offset that still fills the band. Walked from the end, so it does not depend on
-- where the list is scrolled to now.
local function maxScroll()
	ensureRowMetrics()
	local band = listTop - listBottom()
	local used = 0
	local i = #rows
	while i > 0 do
		local h = rowHeightOf(rows[i])
		if used + h > band then
			break
		end
		used = used + h
		i = i - 1
	end

	return i
end

-- The painted row under y, as its offset from the first painted one, plus the edges it was
-- painted with. Every hover test, click and the panel signature go through this, so none of
-- them can disagree with what was drawn. nil when y is outside the band or past the last
-- whole row the band can hold.
local function rowAt(y)
	ensureRowMetrics()
	local lb = listBottom()
	if y > listTop or y <= lb then
		return nil
	end

	local base = scrollOffset()
	for i = scroll + 1, #rows do
		local top = listTop - (rows[i].off - base)
		local bottom = top - rowHeightOf(rows[i])
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

----------------------------------------------------------------
-- Catalog and the row list
----------------------------------------------------------------

-- Whether a label wants the prefix argument placed inside it. Probed rather than declared,
-- because a label shared with the command card names the thing rather than a numbered
-- variant of it, and then the argument goes on the end instead.
local labelPlacesArg = {}
local function prefixRowLabel(key, arg, row, col)
	local places = labelPlacesArg[key]
	if places == nil then
		places = BAR.I18N(key, { n = "", row = "", col = "" }):find("", 1, true) ~= nil
		labelPlacesArg[key] = places
	end

	if places then
		return BAR.I18N(key, { n = arg, row = row, col = col })
	end

	return BAR.I18N(key) .. " " .. arg
end

-- Resolve i18n labels once (search rebuilds rows per keystroke); redone on refresh.
local function buildResolvedCatalog()
	labelPlacesArg = {}
	resolvedCatalog = {}
	catalogAny, catalogAnyPrefixes, catalogShiftPair = {}, {}, {}
	state.hidden, state.labels = {}, {}

	-- What an action does, for its tooltip: the catalog's own key when it names one, else the
	-- command card's tooltip for a row labelled off the card, else the engine's description of
	-- the command - a string of its own, the heading of a structured one, or a gadget's. Asked
	-- for with an empty default, so a missing key is silent and reads as none.
	local function describe(item)
		local command = (item.action or item.prefix or ""):match("^%S+")
		-- Appended one by one: a nil in a table constructor ends what ipairs walks.
		local keys = {}
		if item.description then
			keys[#keys + 1] = item.description
		end
		if item.label and item.label:sub(1, 9) == "commands." then
			keys[#keys + 1] = item.label .. "_tooltip"
		end
		if command then
			keys[#keys + 1] = "cmd." .. command
			keys[#keys + 1] = "cmd." .. command .. "._description"
			keys[#keys + 1] = "cmd.luarules." .. command
		end
		for _, key in ipairs(keys) do
			local found = BAR.I18N(key, { default = "" })
			-- The engine command descriptions were filled in in bulk, and the few commands that
			-- had none got a stand-in reading "<chat command description: Select>" rather than
			-- being left out. Shown, that is what a row says it does.
			local placeholder = type(found) == "string" and found:match("^%b<>$") ~= nil
			if type(found) == "string" and found ~= "" and found ~= key and not placeholder then
				return found
			end
		end

		return nil
	end

	for _, group in ipairs(catalog) do
		if group.hidden then
			resolvedCatalog[#resolvedCatalog + 1] = { hidden = group.hidden, title = "", titleLower = "", items = {} }
			for _, h in ipairs(group.hidden) do
				state.hidden[h] = true
			end
		else
			local title = BAR.I18N(group.category)
			local g = {
				category = group.category,
				layout = group.layout,
				title = title,
				titleLower = title:lower(),
				items = {},
			}
			for _, item in ipairs(group.items) do
				if item.prefix then
					if item.alwaysModifier == "any" then
						catalogAnyPrefixes[#catalogAnyPrefixes + 1] = item.prefix
					end
					g.items[#g.items + 1] = {
						prefix = item.prefix,
						label = item.label,
						unit = item.unit,
						members = item.members,
						membersFrom = item.membersFrom,
						description = describe(item),
						icon = (item.icon and VFS.FileExists(item.icon) and item.icon) or nil,
					}
				else
					if item.action then
						if item.alwaysModifier == "any" then
							catalogAny[item.action] = true
						elseif item.alwaysModifier == "shift" then
							catalogShiftPair[item.action] = true
						end
					end
					local label = BAR.I18N(item.label)
					local stem = item.action and look.cursors[item.action:match("^%S+")]
					local cursor = stem and look.cursorTextures[stem] or nil
					g.items[#g.items + 1] = {
						action = item.action,
						actionLower = item.action and item.action:lower(),
						label = label,
						labelLower = label:lower(),
						cursor = cursor,
						-- The picture a key shows for the action: the catalog's own where it names
						-- one, else the cursor an order is already known by.
						icon = (item.icon and VFS.FileExists(item.icon) and item.icon) or cursor,
						description = describe(item),
					}
					if item.action then
						state.labels[item.action] = label
					end
					-- One picture in a group gives every row in it the column, so the names line up.
					g.hasCursors = g.hasCursors or cursor ~= nil
				end
			end
			if g.layout == "grid" then
				-- Pulled off the same catalog entries the list would have used, so the grid and
				-- the flat form name things identically.
				g.categoryLabels = {}
				for _, it in ipairs(group.items) do
					local n = it.action and it.action:match("^gridmenu_category%s+(%d+)$")
					if n then
						g.categoryLabels[tonumber(n)] = BAR.I18N(it.label)
					end
					if it.prefix == "gridmenu_key" and it.label then
						local key = it.label
						g.cellLabel = function(row, col)
							return BAR.I18N(key, { n = row .. " " .. col, row = row, col = col })
						end
					end
				end
				g.cellLabel = g.cellLabel or function(row, col)
					return row .. " " .. col
				end
				for _, it in ipairs(group.items) do
					if it.action == "gridmenu_cycle_builder" and it.label then
						g.cycleLabel = BAR.I18N(it.label)
					end
				end
				g.cycleLabel = g.cycleLabel or "gridmenu_cycle_builder"
			end
			resolvedCatalog[#resolvedCatalog + 1] = g
		end
	end

	L.other = BAR.I18N("categories.other")
	L.otherLower = L.other:lower()
	L.title = BAR.I18N("ui.keybinds.title")
	L.titleText = colorText .. L.title
	L.allCategories = BAR.I18N("ui.keybinds.editor.allCategories")
	L.gridNextPage = BAR.I18N("actions.gridMenu.nextPage")
	-- gui_gridmenu hardcodes both the caption and the key on this button, so it is not
	-- bindable and there is no i18n key to read.
	-- Shared with gui_gridmenu, which draws the button this mirrors.
	L.gridBack = BAR.I18N("ui.buildMenu.back")

	categories = { { label = L.allCategories } }
	otherCategoryKey = generatedOtherKey
	local seen = {}
	for _, g in ipairs(resolvedCatalog) do
		-- Keyed like the row filter below, not by title: two categories that translate to
		-- the same words are still separate, and one has to not vanish from the column.
		if not g.hidden and not seen[g.category] then
			seen[g.category] = true
			categories[#categories + 1] = { label = g.title, key = g.category }
			-- A catalog category of the same name takes the leftovers, matching the row
			-- order below, rather than a second column entry appearing beside it.
			if g.title == L.other then
				otherCategoryKey = g.category
			end
		end
	end
	if otherCategoryKey == generatedOtherKey then
		categories[#categories + 1] = { label = L.other, key = otherCategoryKey }
	end
	-- A fresh column has no Changed entry, whatever the count was: forgotten here so the next
	-- rebuild of the rows puts it back. Every keyreload comes through here, so without this
	-- the entry went missing until a preset switch happened to move the count.
	state.changedCount = -1
	L.pressKey = BAR.I18N("ui.keybinds.editor.pressKey")
	L.preset = BAR.I18N("ui.keybinds.editor.preset")
	-- Dim, so the preset name in the picker beside it stays the thing that is read.
	L.presetText = colorDim .. L.preset
	L.defaultTag = BAR.I18N("ui.keybinds.editor.defaultTag")
	L.newProfile = BAR.I18N("ui.keybinds.editor.newProfile")
	L.duplicate = BAR.I18N("ui.keybinds.editor.duplicate")
	L.duplicateTooltip = BAR.I18N("ui.keybinds.editor.duplicateTooltip")
	L.edit = BAR.I18N("ui.keybinds.editor.edit")
	L.editTooltip = BAR.I18N("ui.keybinds.editor.editTooltip")
	L.editLockedTooltip = BAR.I18N("ui.keybinds.editor.editLockedTooltip")
	L.saveAsNew = BAR.I18N("ui.keybinds.editor.saveAsNew")
	L.noticeDefault = BAR.I18N("ui.keybinds.editor.noticeDefault")
	L.noticeDefaultUnsaved = BAR.I18N("ui.keybinds.editor.noticeDefaultUnsaved")
	L.noticeUnsaved = BAR.I18N("ui.keybinds.editor.noticeUnsaved")
	L.changed = BAR.I18N("ui.keybinds.editor.changed")
	L.boundToAny = BAR.I18N("ui.keybinds.editor.boundToAny")
	L.changedUnknown = BAR.I18N("ui.keybinds.editor.changedUnknown")
	L.changedNoneTooltip = BAR.I18N("ui.keybinds.editor.changedNoneTooltip")
	L.compareWith = BAR.I18N("ui.keybinds.editor.compareWith")
	L.compareNone = BAR.I18N("ui.keybinds.editor.compareNone")
	L.compareNoneHint = BAR.I18N("ui.keybinds.editor.compareNoneHint")
	L.conflictOrder = BAR.I18N("ui.keybinds.editor.conflictOrder")
	L.conflictShipped = BAR.I18N("ui.keybinds.editor.conflictShipped")
	L.revertNone = BAR.I18N("ui.keybinds.editor.revertNone")
	L.presetDefault = BAR.I18N("ui.keybinds.editor.presetDefault")
	L.presetOwn = BAR.I18N("ui.keybinds.editor.presetOwn")
	L.export = BAR.I18N("ui.keybinds.editor.export")
	L.exportTooltip = BAR.I18N("ui.keybinds.editor.exportTooltip")
	L.import = BAR.I18N("ui.keybinds.editor.import")
	L.importTooltip = BAR.I18N("ui.keybinds.editor.importTooltip")
	L.keyboard = BAR.I18N("ui.keybinds.editor.keyboard")
	L.keyboardTooltip = BAR.I18N("ui.keybinds.editor.keyboardTooltip")
	-- The keyboard page's cards are built from this catalog, so they go with it.
	state.keyInfo = nil
	state.keyboard:refreshStrings()
	L.importTitle = BAR.I18N("ui.keybinds.editor.importTitle")
	L.importEmpty = BAR.I18N("ui.keybinds.editor.importEmpty")
	L.importNone = BAR.I18N("ui.keybinds.editor.importNone")
	L.ok = BAR.I18N("ui.keybinds.editor.ok")
	L.editTitle = BAR.I18N("ui.keybinds.editor.editTitle")
	L.delete = BAR.I18N("ui.keybinds.editor.delete")
	L.duplicateTitle = BAR.I18N("ui.keybinds.editor.duplicateTitle")
	L.save = BAR.I18N("ui.keybinds.editor.save")
	L.reset = BAR.I18N("ui.keybinds.editor.reset")
	L.resetConfirm = BAR.I18N("ui.keybinds.editor.resetConfirm")
	L.saveTitle = BAR.I18N("ui.keybinds.editor.saveTitle")
	L.discard = BAR.I18N("ui.keybinds.editor.discard")
	L.unsavedTitle = BAR.I18N("ui.keybinds.editor.unsavedTitle")
	L.unsavedMessage = BAR.I18N("ui.keybinds.editor.unsavedMessage")
	L.applyFailedTitle = BAR.I18N("ui.keybinds.editor.applyFailedTitle")
	L.accept = BAR.I18N("ui.keybinds.editor.accept")
	L.cancel = BAR.I18N("ui.keybinds.editor.cancel")
end

-- The modifier names a search can name, off the same list the chips are printed from.
local modifierKey = {}
for _, name in ipairs(keyConfig.modifierOrder) do
	modifierKey[name:lower()] = true
end

-- A keyset's canonical form, kept on the keyset record against the raw it came from: the
-- change and conflict checks below run for every row on every rebuild.
local function canonOf(k)
	if k.canonFor ~= k.raw then
		k.canon, k.canonFor = keybindModel.canonicalKeyset(k.raw), k.raw
	end

	return k.canon
end

-- How an action's keys differ from the preset the active one is measured against: nil when
-- they match, or there is nothing to measure against; else the base's raws for the action,
-- which may be none at all. Compared as sets of canonical keysets, so spelling and order do
-- not count as a change.
local function rowChange(action)
	local base = state.base
	if not base then
		return nil
	end

	local theirs = base.byAction[action]
	local seen, n = {}, 0
	for _, k in ipairs(working.byAction[action] or look.noRaws) do
		local c = canonOf(k)
		if not seen[c] then
			seen[c] = true
			n = n + 1
			if not (theirs and theirs.set[c]) then
				return theirs and theirs.raws or look.noRaws
			end
		end
	end
	if (theirs and theirs.n or 0) ~= n then
		return theirs and theirs.raws or look.noRaws
	end

	return nil
end

-- The other listed actions these keysets drive, in bind order, each flagged when the engine
-- tries it before this action, and when the game itself ships the two on one key - sharing
-- by design, which is no clash of the player's making. Nil when there are none. Hidden
-- actions are left out: one sharing a key with a listed action is how the catalog says the
-- two belong together.
local function conflictsOf(action, raws)
	local byKeyset = working.byKeyset
	if not byKeyset then
		return nil
	end

	local out, seen
	for _, raw in ipairs(raws) do
		-- Any holder at all: for a key being captured this action is not among them yet.
		local list = byKeyset[keybindModel.canonicalKeyset(raw)]
		if list then
			local mine
			for i = 1, #list do
				if list[i] == action then
					mine = i
					break
				end
			end
			for i = 1, #list do
				local other = list[i]
				if other ~= action and not state.hidden[other] and not (seen and seen[other]) then
					seen = seen or {}
					seen[other] = true
					out = out or {}
					local pair = (action < other) and (action .. "\n" .. other) or (other .. "\n" .. action)
					out[#out + 1] = {
						action = other,
						before = mine ~= nil and i < mine,
						shipped = state.shippedPairs ~= nil and state.shippedPairs[pair] == true,
					}
				end
			end
		end
	end

	return out
end

-- Rebuilds the display list from the catalog and the staged binds, honouring both the
-- search box and the category column.
local function rebuildRows()
	chipGroups = {}
	rowsGen = rowsGen + 1
	if not resolvedCatalog then
		buildResolvedCatalog()
	end
	-- The keyboard page searches by the same text, lighting the keys it finds.
	state.keyboard:setQuery(searchBox and searchBox:getText())
	-- The Changed section lowers the rows for its picker; any other section has them back.
	state.applyListTop()
	state.layoutCompare()

	rows = {}

	-- A grid category replaces the list outright: its keys only make sense laid out the
	-- way the grid menu itself draws them, so there are no rows to build.
	gridGroup = nil
	if selectedCategory then
		for _, group in ipairs(resolvedCatalog) do
			if group.category == selectedCategory and group.layout == "grid" then
				gridGroup = group
			end
		end
	end
	if gridGroup then
		clampScroll()

		return
	end
	local query = Search.query(searchBox and searchBox:getText())

	-- Which actions share each keyset, in bind order, so a chip can say what else its key
	-- drives and a capture can warn before a key is taken. Rebuilt with the rows, which every
	-- edit rebuilds.
	local byKeyset = {}
	for _, b in ipairs(working.binds) do
		local c = keybindModel.canonicalKeyset(b.keyset)
		local list = byKeyset[c]
		if not list then
			list = {}
			byKeyset[c] = list
		end
		local listed = false
		for i = 1, #list do
			if list[i] == b.action then
				listed = true
				break
			end
		end
		if not listed then
			list[#list + 1] = b.action
		end
	end
	working.byKeyset = byKeyset

	-- The column's Changed entry keeps only rows that differ from the base preset. How many
	-- there are is counted whatever is shown, since its label says so.
	local changedOnly = selectedCategory == state.changedKey
	local changedCount = 0

	-- A query can name keys as well as words. An action matches by key when one of its chips holds
	-- every key the query names, modifiers included and in any order, so "ctrl+q", "ctrl q" and
	-- "q ctrl" all find what Ctrl+Q does. Whole keys only, as the chips print them: "f1" does not
	-- find F11, and a paired action's hidden Shift half does not answer to "shift".
	local wantKeys = {}
	-- The same keys with the modifiers dropped. An Any+ binding fires whatever is held, so it
	-- answers a query naming modifiers even though its chip prints the bare key and holds none
	-- of them; without this it is missing from the one search that should find it.
	local wantPlain, namedMods = {}, false
	for key in query.text:gmatch("[^%s%+]+") do
		wantKeys[#wantKeys + 1] = key
		if modifierKey[key] then
			namedMods = true
		else
			wantPlain[#wantPlain + 1] = key
		end
	end
	-- How the action answers the query: "exact" when a chip holds every key named, "any" when it
	-- only holds the keys and carries Any+ for the modifiers, false when neither.
	local function boundToQuery(action)
		if not (wantKeys[1] and action) then
			return false
		end
		local any = false
		local pair = catalogShiftPair[action]
		for _, k in ipairs(working.byAction[action] or {}) do
			-- The chip's text, which for a paired action is not the keyset's own. Kept on the keyset
			-- against the raw it came from, since this runs for every row on every keystroke.
			local shown = k.display
			if pair then
				if k.unshiftedFor ~= k.raw then
					k.unshifted, k.unshiftedFor = keybindModel.displayWithoutShift(k.raw, working.layout), k.raw
				end
				shown = k.unshifted
			end
			if keybindModel.holdsKeys(shown, wantKeys) then
				return "exact"
			end
			if namedMods and wantPlain[1] then
				local mods = keybindModel.splitElement(canonOf(k))
				if mods.any and keybindModel.holdsKeys(shown, wantPlain) then
					any = true
				end
			end
		end

		return any and "any" or false
	end
	-- Whether an action is listed by key: by the keys the search text names, within the
	-- category shown.
	local function keyHit(action, _, inCategory)
		return inCategory and boundToQuery(action)
	end
	-- Rows found by key are listed ahead of everything found by name, under a heading of their
	-- own, and only there. Gathered as they are met, so they keep the catalog's order.
	local keyRows = {}
	local catalogActions = {}
	local otherGroupEnd

	-- Claim hidden actions up front so they never surface, as a row or under Other.
	-- Exact ids only (not prefixes), so a future action can't be hidden by coincidence.
	for _, group in ipairs(resolvedCatalog) do
		if group.hidden then
			for _, h in ipairs(group.hidden) do
				catalogActions[h] = true
			end
		end
	end

	for _, group in ipairs(resolvedCatalog) do
		-- Non-selected groups are still walked: they have to claim their actions or the
		-- leftovers below would sweep them all into Other.
		local inCategory = not selectedCategory or changedOnly or group.category == selectedCategory
		-- A group whose own title matches keeps every row under it, so searching for a
		-- category's name shows the category rather than emptying it.
		local categoryMatch = Search.claims(query, group.titleLower)
		local groupRows = {}
		local keyLink
		for _, item in ipairs(group.items) do
			-- An empty prefix would claim every bound action, so treat it as no prefix.
			if item.prefix and item.prefix ~= "" then
				-- A family whose members are the player's is named a source rather than listed,
				-- and read here rather than with the rest of the catalog, so a profile made a
				-- moment ago gets its row without waiting for a refresh.
				local members = item.members
				if item.membersFrom == "profiles" then
					-- Switching to the one already on is a key that can only do nothing, so it is
					-- not offered. One already bound is still found from the keymap below, which
					-- is what leaves a stale self-binding somewhere to remove it.
					local active = profiles.activeName()
					members = {}
					for _, builtin in ipairs(profiles.builtins) do
						if builtin.name ~= active then
							members[#members + 1] = builtin.name
						end
					end
					for _, own in ipairs(profiles.list()) do
						if own ~= active then
							members[#members + 1] = own
						end
					end
				end

				-- A declared member is a row whether or not it is bound, so unbinding the last
				-- key of "group select 3" leaves the row there to bind again. Families the
				-- catalog cannot enumerate (buildunit_ is per unit) list no members and are
				-- still discovered from what is bound.
				local matched = {}
				for _, member in ipairs(members or {}) do
					local action = item.prefix .. member
					-- Skipped when an explicit entry already covers it, or a family whose
					-- members are also listed individually renders each of them twice.
					if not catalogActions[action] then
						catalogActions[action] = true
						matched[#matched + 1] = action
					end
				end

				local found = {}
				for action in pairs(working.byAction) do
					if not catalogActions[action] and action:sub(1, #item.prefix) == item.prefix then
						catalogActions[action] = true
						found[#found + 1] = action
					end
				end
				table.sort(found)
				for i = 1, #found do
					matched[#matched + 1] = found[i]
				end
				for i = 1, #matched do
					local action = matched[i]
					local arg = action:sub(#item.prefix + 1)
					if item.unit then
						local def = UnitDefNames[arg]
						if def then
							arg = def.translatedHumanName or arg
						else
							-- Factions gated behind modoptions (Legion, scavengers) aren't in
							-- UnitDefNames, but their names live in the units i18n regardless.
							local key = "units.names." .. arg
							local name = BAR.I18N(key)
							if name ~= key then
								arg = name
							end
						end
					end
					local row, col = arg:match("^%s*(%S+)%s+(%S+)")
					local label = item.label and prefixRowLabel(item.label, arg, row, col) or action
					state.labels[action] = label
					local change = rowChange(action)
					if change then
						changedCount = changedCount + 1
					end
					local byKey = keyHit(action, label, inCategory)
					if
						(change or not changedOnly)
						and (
							byKey
							or categoryMatch
							or Search.matches(query, action:lower())
							or Search.matches(query, label:lower())
						)
					then
						local entry = {
							type = "editable",
							action = action,
							label = label,
							description = item.description,
							change = change,
							queryAny = byKey == "any",
						}
						if not byKey then
							groupRows[#groupRows + 1] = entry
						elseif group.layout == "grid" then
							keyLink = group
						else
							keyRows[#keyRows + 1] = entry
						end
					end
				end
			-- Skip an action a hidden entry or an earlier prefix already claimed, so a
			-- hide stays authoritative and entry order can't produce a duplicate row.
			elseif not (item.action and catalogActions[item.action]) then
				if item.action then
					catalogActions[item.action] = true
				end
				local change = rowChange(item.action)
				if change then
					changedCount = changedCount + 1
				end
				local byKey = keyHit(item.action, item.label, inCategory)
				if
					(change or not changedOnly)
					and (
						byKey
						or categoryMatch
						or Search.matches(query, item.labelLower)
						or Search.matches(query, item.actionLower)
					)
				then
					local entry = {
						type = "editable",
						action = item.action,
						label = item.label,
						cursor = item.cursor,
						cursorColumn = group.hasCursors,
						description = item.description,
						change = change,
						queryAny = byKey == "any",
					}
					if not byKey then
						groupRows[#groupRows + 1] = entry
					elseif group.layout == "grid" then
						keyLink = group
					else
						keyRows[#keyRows + 1] = entry
					end
				end
			end
		end

		-- A grid category's keys only read laid out, so a key found among them points at that view.
		if keyLink then
			keyRows[#keyRows + 1] = { type = "link", label = group.title, category = group.category }
		end

		if inCategory and #groupRows > 0 then
			rows[#rows + 1] = { type = "header", text = group.title }
			if group.layout == "grid" then
				-- Its keys only read laid out, so the list points at that view rather than
				-- repeating them flat. Still driven by the rows a search matched, so hunting
				-- for one of them surfaces the way in.
				rows[#rows + 1] = { type = "link", label = L.edit, category = group.category }
			else
				for i = 1, #groupRows do
					rows[#rows + 1] = groupRows[i]
				end
			end
			if group.title == L.other then
				otherGroupEnd = #rows
			end
		end
	end

	local otherMatch = Search.claims(query, L.otherLower)
	local others, otherKeyed = {}, {}
	local inOther = not selectedCategory or changedOnly or selectedCategory == otherCategoryKey
	for action in pairs(working.byAction) do
		if not catalogActions[action] then
			local change = rowChange(action)
			if change then
				changedCount = changedCount + 1
			end
			if changedOnly and not change then
				-- Not what the column entry asked for.
			elseif keyHit(action, action, inOther) then
				otherKeyed[#otherKeyed + 1] = action
			elseif otherMatch or Search.matches(query, action:lower()) then
				others[#others + 1] = action
			end
		end
	end
	-- Leftovers found by key join the other key rows, in a steady order.
	table.sort(otherKeyed)
	for _, action in ipairs(otherKeyed) do
		keyRows[#keyRows + 1] = {
			type = "editable",
			action = action,
			label = action,
			change = rowChange(action),
			queryAny = boundToQuery(action) == "any",
		}
	end

	if #others > 0 and inOther then
		table.sort(others)

		-- A catalog category can be titled the same as this generated one; when it is,
		-- the leftovers join it after its own items instead of repeating the header.
		local tail = {}
		if otherGroupEnd then
			for i = otherGroupEnd + 1, #rows do
				tail[#tail + 1] = rows[i]
				rows[i] = nil
			end
		else
			rows[#rows + 1] = { type = "header", text = L.other }
		end

		for _, action in ipairs(others) do
			rows[#rows + 1] = { type = "editable", action = action, label = action, change = rowChange(action) }
		end
		for i = 1, #tail do
			rows[#rows + 1] = tail[i]
		end
	end

	-- The key rows go on top, under a heading that names the keys the way a chip would. One
	-- cursor among them gives them all the column, as it does within a category.
	if #keyRows > 0 then
		-- Modifiers ahead of the key, as a chip prints them, whatever order they were typed in.
		local modifierAt = { ctrl = 1, alt = 2, meta = 3, shift = 4 }
		local keys, column = {}, false
		for i = 1, #wantKeys do
			keys[i] = { name = wantKeys[i]:upper(), at = (modifierAt[wantKeys[i]] or 5) * 100 + i }
		end
		table.sort(keys, function(a, b)
			return a.at < b.at
		end)
		for i = 1, #keys do
			keys[i] = keys[i].name
		end
		for i = 1, #keyRows do
			column = column or keyRows[i].cursor ~= nil
		end
		local ordered = {
			{
				type = "header",
				text = BAR.I18N("ui.keybinds.editor.boundTo", { keys = table.concat(keys, " + ") }),
			},
		}
		-- What answers only through Any+ is set apart: it does fire on the keys searched for, but
		-- its chip reads as the bare key, and side by side with the exact bindings that reads as a
		-- mistake.
		local anyRows = {}
		for i = 1, #keyRows do
			keyRows[i].cursorColumn = column
			keyRows[i].hitKeys = wantKeys
			if keyRows[i].queryAny then
				anyRows[#anyRows + 1] = keyRows[i]
			else
				ordered[#ordered + 1] = keyRows[i]
			end
		end
		if #anyRows > 0 then
			ordered[#ordered + 1] = { type = "header", text = L.boundToAny }
			for i = 1, #anyRows do
				ordered[#ordered + 1] = anyRows[i]
			end
		end
		for i = 1, #rows do
			ordered[#ordered + 1] = rows[i]
		end
		rows = ordered
	end

	-- The column's Changed entry comes and goes with the count, and says it. Taking the entry
	-- away from under the selection sends the column back to everything, which is a different
	-- list from the one just built: built again, once, with the selection gone.
	if state.changedCount ~= changedCount then
		state.changedCount = changedCount
		state.syncChangedEntry()
		if changedOnly and selectedCategory ~= state.changedKey then
			return rebuildRows()
		end
	end

	-- The Changed section with nothing to list says why: no preset is being compared with,
	-- or nothing differs from the one that is.
	if changedOnly and #rows == 0 then
		if not state.base then
			rows[1] = { type = "note", text = L.compareNoneHint }
		else
			rows[1] = {
				type = "note",
				text = BAR.I18N("ui.keybinds.editor.changedNothing", { name = state.base.name }),
			}
		end
	end

	clampScroll()
end

-- Where the rows start: the band's top, or a picker's band lower when the Changed section
-- is showing. Everything that draws, scrolls or hit-tests rows reads listTop, so the whole
-- band moves as one.
function state.applyListTop()
	if not metrics.listTopBase then
		return
	end
	listTop = metrics.listTopBase - (state.compareBand() and metrics.compareBandH or 0)
end

-- Whether the comparison picker's band is up: the Changed section, on the list page.
function state.compareBand()
	return state.page == "list" and selectedCategory == state.changedKey and not gridGroup
end

-- Places the comparison strip and the picker at its right end, once the band is placed. The
-- strip's rect and the caption's place are kept in metrics for the draw.
function state.layoutCompare()
	local dd = state.compareDropdown
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

-- The picker's options: none, then every other preset, the shipped ones tagged as defaults
-- and ruled off from the player's own. Selected: whatever the active preset is compared
-- with now.
function state.compareOptions()
	local active = profiles.activeName()
	local options = { { label = L.compareNone or "None", none = true } }
	for _, b in ipairs(profiles.builtins) do
		if b.name ~= active then
			options[#options + 1] = { label = b.name, name = b.name, tag = L.defaultTag, group = "default" }
		end
	end
	-- The store lists its profiles by name.
	for _, name in ipairs(profiles.list()) do
		if name ~= active then
			options[#options + 1] = { label = name, name = name, group = "own" }
		end
	end
	local selected = 1
	local base = state.base and state.base.name
	for i, o in ipairs(options) do
		if o.name and o.name == base then
			selected = i
		end
	end

	return options, selected
end

function state.refreshCompare()
	local dd = state.compareDropdown
	if not dd then
		return
	end
	local options, selected = state.compareOptions()
	dd:setOptions(options)
	dd:setSelected(selected)
	state.layoutCompare()
end

-- The player picked what to compare the active preset with. Recorded on the preset, so it
-- holds across sessions; "none" is a choice too, and stays one.
function state.pickBase(option)
	if not activeIsOwn() then
		return
	end
	profiles.setBase(profiles.activeName(), option and option.name or nil)
	state.refreshBase()
	rebuildRows()
end

----------------------------------------------------------------
-- Staging
----------------------------------------------------------------

-- Staged-edits flag, read by the picker marker and the footer buttons alike.
local function setDirty(value)
	dirty = value
end

-- Re-reading the engine replaces whatever was staged, so the flag describing those edits
-- goes with them. Without that a language or layout change leaves the flag armed over
-- bindings it no longer describes, and Save writes the engine's keymap back as an edit.
local function seedWorkingFromEngine()
	local model = keybindModel.build()
	working = { byAction = {}, layout = model.layout, binds = model.binds }
	for _, entry in ipairs(model.actions) do
		local copy = {}
		for _, k in ipairs(entry.keysets) do
			copy[#copy + 1] = { raw = k.raw, display = k.display }
		end
		working.byAction[entry.action] = copy
	end

	setDirty(false)
	-- A fresh keymap has nothing to take back; what comes after is measured from here.
	state.undo = {}
	state.snapshot = state.snapshotOf()
end

-- Detached copy of the staged binds, for handing to the store.
local function stagedBinds()
	local out = {}
	for i, b in ipairs(working.binds) do
		out[i] = { keyset = b.keyset, action = b.action }
	end

	return out
end

-- Nothing in the editor rebinds the meta key, so a profile made from another one keeps
-- whatever that had; dropping it would silently change the new profile's modifiers.
local function activeFakeMeta()
	local name = profiles.activeName()
	local source = profiles.get(name) or profiles.isBuiltin(name)

	return source and source.fakeMeta or nil
end

-- Which build menu a profile implies. Only the shipped ones imply anything: a profile of
-- the player's own leaves the menu alone, so the settings toggle stays theirs to set.
-- Read from the binds rather than the name, since the grid menu is inert without its
-- gridmenu_* keys and the build menu is what buildunit_* hotkeys drive.
local function wantsGridMenu(name)
	local source = profiles.isBuiltin(name)
	if not source then
		return nil
	end

	local buildunit = false
	for _, b in ipairs(source.binds or {}) do
		local action = b.action:lower()
		if action:find("gridmenu_", 1, true) == 1 then
			return true
		elseif action:find("buildunit_", 1, true) == 1 then
			buildunit = true
		end
	end

	if buildunit then
		return false
	end

	return nil
end

-- Points the engine at a profile and brings the rest of the UI in line with it.
local function applyActiveProfile(name, fromName)
	Spring.SetConfigString("KeybindingFile", customKeysFile)
	if fromName and fromName ~= name then
		Spring.Echo("Keybind profile: " .. fromName .. " -> " .. name)
	end
	if menuToggle then
		menuToggle(wantsGridMenu(name))
	end

	if WG["bar_hotkeys"] and WG["bar_hotkeys"].reloadBindings then
		WG["bar_hotkeys"].reloadBindings()
	else
		view.refresh()
	end
end

-- The shipped preset the active one is measured against, and its keysets by action, redone
-- when the active preset's origin changes. The column's Changed entry comes and goes with it:
-- a preset with no known origin has nothing to have changed from.
function state.refreshBase()
	-- Which pairs of actions the game itself puts on one key, in any shipped preset. Built
	-- once, the shipped presets not changing.
	if not state.shippedPairs then
		local shipped = {}
		for _, b in ipairs(profiles.builtins) do
			local byKeyset = {}
			for _, bind in ipairs(b.binds or {}) do
				local c = keybindModel.canonicalKeyset(bind.keyset)
				local list = byKeyset[c]
				if not list then
					list = {}
					byKeyset[c] = list
				end
				local listed = false
				for i = 1, #list do
					if list[i] == bind.action then
						listed = true
					end
				end
				if not listed then
					list[#list + 1] = bind.action
				end
			end
			for _, list in pairs(byKeyset) do
				for i = 1, #list do
					for j = i + 1, #list do
						local a, o = list[i], list[j]
						shipped[(a < o) and (a .. "\n" .. o) or (o .. "\n" .. a)] = true
					end
				end
			end
		end
		state.shippedPairs = shipped
	end

	local base = profiles.baseOf(profiles.activeName())
	local wanted = base and base.name or nil
	if (state.base and state.base.name) ~= wanted then
		if base then
			local byAction = {}
			for _, b in ipairs(base.binds or {}) do
				local entry = byAction[b.action]
				if not entry then
					entry = { set = {}, n = 0, raws = {} }
					byAction[b.action] = entry
				end
				local c = keybindModel.canonicalKeyset(b.keyset)
				if not entry.set[c] then
					entry.set[c] = true
					entry.n = entry.n + 1
					entry.raws[#entry.raws + 1] = b.keyset
				end
			end
			state.base = { name = wanted, byAction = byAction }
		else
			state.base = nil
		end
		state.changedCount = -1
	end
	state.syncChangedEntry()
	state.refreshCompare()
end

-- The column's Changed entry: there for every preset of the player's own, with the count of
-- rows differing from the compared preset in its label, or a question mark while nothing is
-- being compared with. A shipped preset is measured against itself, so it only has the entry
-- while staged edits differ from it: a "Changed (0)" on a default is noise. With the entry
-- gone from under the selection, the column falls back to everything.
function state.syncChangedEntry()
	local listed = categories[2] ~= nil and categories[2].key == state.changedKey
	if activeIsOwn() or (state.base and state.changedCount > 0) then
		local label = L.changedUnknown or "?"
		if state.base then
			label = BAR.I18N("ui.keybinds.editor.changedCount", { n = math.max(0, state.changedCount) })
		end
		if not listed then
			table.insert(categories, 2, { label = label, key = state.changedKey })
			state.refit = true
		elseif categories[2].label ~= label then
			categories[2].label = label
			state.refit = true
		end
	elseif listed then
		table.remove(categories, 2)
		if selectedCategory == state.changedKey then
			selectedCategory = nil
		end
		state.refit = true
	end
end

local function refreshPicker()
	buildPresetOptions()
	presetDropdown:setOptions(presetOptions)
	presetDropdown:setSelected(currentPresetIndex())
	state.refreshBase()
	-- Whether the active preset is a default settles the Save button's wording, and so its
	-- width, and what the header tooltips say. Laid out again on the next draw, once, however
	-- many times this runs before it.
	state.layoutPending = true
end

-- Files the keymap as it stood before the edit just made, then takes the one it stands at
-- now, for the edit after.
function state.pushUndo()
	state.undo[#state.undo + 1] = state.snapshot
	state.snapshot = state.snapshotOf()
end

-- Staging changes the picker too: the active profile picks up the unsaved marker. A gesture
-- that stages several edits files one snapshot for the lot, once it is done.
local function markStaged()
	if state.batching then
		state.batchEdited = true
	else
		state.pushUndo()
	end
	setDirty(true)
	refreshPicker()
	rebuildRows()
end

-- Ctrl+Z: the last edit taken back. With none left the keymap is what was loaded, so there
-- is nothing unsaved either. Answers whether there was anything to take back.
function state.undoEdit()
	local snap = table.remove(state.undo)
	if not snap then
		return false
	end

	working.binds, working.byAction = snap.binds, snap.byAction
	-- Copied again: the restored tables are live now, and the next edit rewrites them.
	state.snapshot = state.snapshotOf()
	setDirty(#state.undo > 0)
	refreshPicker()
	rebuildRows()

	return true
end

-- Staged edits live only in `working`, so throwing them away means re-reading the engine.
-- Clearing the flag on its own would leave the edits on screen and still saveable.
local function discardStaged()
	seedWorkingFromEngine()
	refreshPicker()
	rebuildRows()
end

----------------------------------------------------------------
-- Dialogs
----------------------------------------------------------------

-- Raises a modal, taking focus off the search box.
local function openDialog(d)
	-- Replacing a live modal outright would drop the rollback its cancel was holding, which
	-- is how the picker ends up naming a profile that was never switched to. Run it first,
	-- with the slot already empty so the cancel cannot clobber the incoming dialog.
	local previous = dialog
	dialog = nil
	if previous and previous.cancel then
		previous.cancel()
	end

	-- A modal draws over the capture and takes its keys, so leaving one running behind would
	-- drop the player back into it on cancel, seeded from bindings the modal may have changed.
	capturing = nil

	dialog = d
	searchBox:blur()
	if not d.message then
		nameBox:setText(d.initial or "")
		nameBox:focus()
	end
end

-- Drops the modal, handing it back so the caller can act on it.
local function closeDialog()
	local d = dialog
	dialog = nil
	nameBox:blur()

	return d
end

local function cancelDialog()
	local d = closeDialog()
	if d and d.cancel then
		d.cancel()
	end
end

-- The optional third button: "Discard" when leaving unsaved edits, "Delete" when
-- editing a profile.
local function middleDialog()
	local d = closeDialog()
	if d and d.middle then
		d.middle.action()
	end
end

-- A name already in use would be renumbered on the way into the store, handing back a
-- profile nobody asked for.
local function dialogName()
	if not dialog or dialog.message then
		return "", false
	end

	local name = nameBox:getText():gsub("^%s+", ""):gsub("%s+$", "")
	local taken = name ~= dialog.allow and (profiles.get(name) ~= nil or profiles.isBuiltin(name) ~= nil)

	-- A dialog can be blocked outright, like an import with nothing to import.
	return name, name == "" or taken or dialog.blocked == true
end

-- Confirmation path; only a dialog with a name field has text to read.
local function acceptDialog()
	local name, blocked = dialogName()
	if blocked then
		return
	end

	local d = closeDialog()
	if not d then
		return
	end

	d.accept(name)
end

----------------------------------------------------------------
-- Profile commands
----------------------------------------------------------------

-- Makes a profile the live one, leaving its stored binds alone. Answers whether it took.
-- A keymap that never reached disk must not clear the staged flag: the reload below would
-- load whatever file is still there and the player would watch their edits revert.
-- offPanel marks a caller the player is not looking at, a bound key with the editor
-- closed, where a modal would sit unseen and then surface attributed to whatever they did
-- next; that failure goes to the console instead.
local function selectProfile(name, fromName, offPanel)
	if not profiles.materialize(name) then
		if offPanel then
			Spring.Echo("Keybind profile: could not apply " .. name)
		else
			openDialog({
				title = L.applyFailedTitle,
				message = BAR.I18N("ui.keybinds.editor.applyFailedMessage", { name = name }),
				accept = function() end,
			})
		end

		return false
	end

	profiles.setActive(name)
	setDirty(false)
	-- What was staged is now the preset's own, or gone with the switch: nothing to take back.
	state.undo = {}
	state.snapshot = state.snapshotOf()
	refreshPicker()
	applyActiveProfile(name, fromName)

	return true
end

-- Commit point: the staged keymap reaches the engine and the store together. Answers
-- whether it landed, so a caller that closes the panel on the way out does not do so over
-- a save that failed.
local function applyStaged(name, fromName)
	local profile = profiles.get(name)
	if not profile then
		return selectProfile(name, fromName)
	end

	-- The store has to hold the new binds before materialize can write them out, so a failed
	-- apply is undone rather than avoided. Left as-is, disk would keep edits the editor still
	-- reports as unsaved, and Reset would appear to discard something already persisted.
	local previous = profile.binds
	profile.binds = stagedBinds()
	profiles.save()

	if selectProfile(name, fromName) then
		return true
	end

	profile.binds = previous
	profiles.save()

	return false
end

-- Saving over a shipped profile is a fork: it asks for a name and writes a new one.
local function startSave(andThen, onCancel)
	local name = profiles.activeName()
	if profiles.get(name) then
		if applyStaged(name) and andThen then
			andThen()
		end

		return
	end

	openDialog({
		title = L.saveTitle,
		initial = profiles.uniqueName(L.newProfile),
		accept = function(newName)
			-- Forked from the default on screen, which the new preset records as its origin.
			local created = profiles.create(newName, stagedBinds(), activeFakeMeta(), name)
			if applyStaged(created, name) and andThen then
				andThen()
			end
		end,
		cancel = onCancel,
	})
end

-- Staged edits are not in the engine yet, so anything that would replace them asks
-- first. Returns whether it could go ahead immediately.
local function guardDirty(proceed, onCancel)
	if not dirty then
		proceed()

		return true
	end

	openDialog({
		title = L.unsavedTitle,
		message = L.unsavedMessage,
		-- Worded like the footer's Save, which this stands in for.
		acceptLabel = activeIsOwn() and L.save or L.saveAsNew,
		save = true,
		accept = function()
			startSave(proceed, onCancel)
		end,
		middle = {
			label = L.discard,
			danger = true,
			action = function()
				discardStaged()
				proceed()
			end,
		},
		cancel = onCancel,
	})

	return false
end

switchToPreset = function(opt)
	-- Already what is on screen, staged edits and all, so picking it again is not a switch:
	-- it would only ask about edits the player has not tried to leave.
	if opt.name == profiles.activeName() then
		return
	end

	guardDirty(function()
		-- The picker committed the new name before the guard ran, so a switch that does not
		-- happen has to put the selection back.
		if not selectProfile(opt.name, profiles.activeName()) then
			refreshPicker()
		end
	end, refreshPicker)
end

-- Throws staged edits away, back to the active profile as last saved.
local function startReset()
	openDialog({
		title = L.reset,
		message = L.resetConfirm,
		-- Named for what it does. Without this it falls back to the generic "Accept", which
		-- says nothing about the edits being thrown away, and coloured for it.
		acceptLabel = L.discard,
		danger = true,
		accept = function()
			discardStaged()
		end,
	})
end

local function startDuplicate()
	local from = profiles.activeName()
	openDialog({
		title = L.duplicateTitle,
		initial = profiles.uniqueName(from),
		accept = function(name)
			-- Copies what is on screen rather than what was last saved, so pending
			-- edits come along instead of being silently dropped. The copy descends from
			-- whatever the original did.
			local base = profiles.baseOf(from)
			applyStaged(profiles.create(name, stagedBinds(), activeFakeMeta(), base and base.name), from)
		end,
	})
end

-- Export copies the preset on screen, staged edits included, to the clipboard as the text the
-- engine loads; Import reads such text back as a new preset of the player's own.
local function startClipboard(exporting)
	if exporting then
		local name = profiles.activeName()
		Spring.SetClipboard(profiles.exportText({ name = name, binds = stagedBinds(), fakeMeta = activeFakeMeta() }))
		openDialog({
			title = L.export,
			message = BAR.I18N("ui.keybinds.editor.exportDone", { name = name }),
			info = true,
			acceptLabel = L.ok,
			accept = function() end,
		})

		return
	end

	local clip = Spring.GetClipboard()
	if type(clip) ~= "string" or clip:match("^%s*$") then
		openDialog({ title = L.import, message = L.importEmpty, info = true, acceptLabel = L.ok, accept = function() end })

		return
	end

	-- What the reader will take, line by line, shown before it is taken: the lines it will
	-- drop in red, and a count of each above them. With nothing readable the dialog still
	-- opens, so the player can see why, but cannot be accepted.
	local lines, count, errors = profiles.classifyBindFile(clip)
	local binds, fakeMeta, stamped = profiles.parseBindFile(clip)
	local summary = binds and (colorText .. BAR.I18N("ui.keybinds.editor.importSummary", { n = count }))
		or (colorDanger .. L.importNone)
	if errors > 0 then
		summary = summary .. colorDim .. ", " .. colorHeader .. BAR.I18N("ui.keybinds.editor.importErrors", { n = errors })
	end
	local function open()
		openDialog({
			title = L.importTitle,
			initial = profiles.uniqueName(stamped or L.newProfile),
			preview = { lines = lines, summary = summary, scroll = 0 },
			blocked = binds == nil,
			acceptLabel = L.import,
			accept = function(newName)
				-- Named like a copy is, then made live: importing is switching to it.
				selectProfile(profiles.create(newName, binds, fakeMeta), profiles.activeName())
			end,
		})
	end

	-- Importing replaces what is on screen, so staged edits are asked about first - but not
	-- over a preview that cannot be accepted anyway.
	if binds then
		guardDirty(open)
	else
		open()
	end
end

-- Renaming and deleting share one dialog: the name field commits a rename, the
-- middle button deletes. Deleting asks again, since it cannot be undone.
local function startEdit()
	local name = profiles.activeName()

	-- One keymap's binds and its index by action, with the switch to one profile pointed at
	-- another. The staged keymap and everything undo can put back move with the rename too,
	-- or a save writes back a key that switches to a profile no longer there.
	local function retargetSwitch(set, from, to)
		local keysets = set and set.byAction[from]
		if not keysets then
			return
		end

		for _, bind in ipairs(set.binds) do
			if bind.action == from then
				bind.action = to
			end
		end
		set.byAction[from] = nil
		set.byAction[to] = keysets
	end

	openDialog({
		title = L.editTitle,
		initial = name,
		allow = name,
		accept = function(newName)
			-- The store renumbers a name already taken, so follow what it settled on.
			local from = profiles.switchAction(name)
			local settled = profiles.rename(name, newName)
			local to = profiles.switchAction(settled)
			retargetSwitch(working, from, to)
			retargetSwitch(state.snapshot, from, to)
			for _, snap in ipairs(state.undo) do
				retargetSwitch(snap, from, to)
			end

			-- The rename moved the store's copy of the binding, so the file has to be written
			-- again or the next launch finds a keymap matching no profile and adopts it as a
			-- separate one. Reloading it is the part staged edits cannot take, so with edits
			-- pending only the file is written and the engine catches up on Save.
			if dirty then
				profiles.materialize(settled)
				refreshPicker()
				rebuildRows()
			else
				selectProfile(settled, nil)
			end
		end,
		middle = {
			label = L.delete,
			danger = true,
			action = function()
				openDialog({
					title = L.delete,
					message = BAR.I18N("ui.keybinds.editor.deleteConfirm", { name = name }),
					acceptLabel = L.delete,
					danger = true,
					accept = function()
						-- Re-seeded rather than just unflagged: clearing the flag alone would
						-- leave the deleted profile's edits on screen with Save greyed out.
						discardStaged()
						profiles.delete(name)

						-- Whatever the store fell back to has to be made live; the deleted profile
						-- is still what the engine has loaded. Selected rather than committed: the
						-- staged keymap belongs to the profile just deleted.
						selectProfile(profiles.activeName(), name)
					end,
				})
			end,
		},
	})
end

----------------------------------------------------------------
-- Layout and geometry
----------------------------------------------------------------

-- Builds the controls on first use, the font not existing at include time.
local function ensureControls()
	if searchBox and presetDropdown then
		return
	end

	-- Each control prints live, every frame, on the shared font, so each pins the panel's
	-- outline for itself.
	searchBox = Editbox.new({
		placeholder = BAR.I18N("ui.keybinds.editor.search"),
		clearable = true,
		onChange = rebuildRows,
		outline = look.outline,
	})
	presetDropdown = Dropdown.new({
		options = presetOptions,
		onSelect = switchToPreset,
		markSelected = true,
		outline = look.outline,
	})
	nameBox = Editbox.new({ maxChars = 40, outline = look.outline })
	-- The Changed section's picker of what to compare the active preset with.
	state.compareDropdown = Dropdown.new({
		options = {},
		onSelect = state.pickBase,
		markSelected = true,
		outline = look.outline,
	})
end

-- Buttons size to their own label so a longer translation is not clipped and a short
-- one is not padded out. Layout can run before view.init has a font, so that case
-- falls back to a width and asks draw to lay out again once the font is there.
local function labelWidth(label, size, pad)
	if not font then
		state.layoutPending = true

		return floor(110 * scale)
	end

	return floor(font:GetTextWidth(label) * size) + pad * 2
end

-- Accept wording, needed by the geometry as well as the drawing.
local function acceptLabelFor(d)
	return d.acceptLabel or (d.message and L.accept or L.save)
end

-- Header and footer rects, placed right to left from the panel edge.
local function layoutHeader()
	state.headerH = floor(34 * scale)
	state.footerH = floor(34 * scale)

	if not (searchBox and presetDropdown) then
		return
	end

	state.layoutPending = false

	local gap = floor(8 * scale)
	local rowTop = area.y2 - floor(4 * scale)
	local rowBottom = area.y2 - state.headerH + floor(4 * scale)
	-- Room for the longest shipped name beside its Default tag.
	local presetW = floor(280 * scale)
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
		bx2 = floor(bx2 - w - gap * (b.gap or 1))
	end
	local pickerX1 = bx2 - presetW
	metrics.presetLabelX = pickerX1 - gap - labelWidth(L.preset or "", btnFs, 0)
	metrics.presetLabelFs = btnFs
	if font then
		-- The baseline the picker and the search field print their own text on.
		metrics.presetLabelY = text.baseline(font, rowBottom, rowTop, btnFs)
	end

	presetDropdown:setRect(pickerX1, rowBottom, pickerX1 + presetW, rowTop, btnFs)
	-- Twice the gap on this side, so the caption reads as the picker's and not the field's.
	searchBox:setRect(listX1, rowBottom, metrics.presetLabelX - gap * 2, rowTop, btnFs)

	local fTop = area.y1 + state.footerH - floor(4 * scale)
	local fBottom = area.y1 + floor(4 * scale)
	local fFs = floor((fTop - fBottom) * 0.5)
	local fPad = floor(14 * scale)
	local x2 = area.x2 - metrics.edgeInset
	-- A default cannot take the edits, so its Save is worded for where they go instead.
	local own = activeIsOwn()
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

-- Profile-modal geometry, derived in one place so draw and mousePress agree.
-- A dialog with a preview is wider and taller, the preview taking the room above the name
-- field; an information dialog has one button, OK, in the middle, and no Cancel.
local function dialogGeometry()
	local preview = dialog and dialog.preview
	local w = floor((preview and 620 or 315) * scale)
	local h = floor((preview and 420 or 150) * scale)
	local messageLines, messageStep
	if dialog and dialog.message and font then
		messageStep = floor(rowHeight * 0.75)
		messageLines = text.wrap(font, dialog.message, w - floor(32 * scale), floor(rowHeight * 0.5))
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

	local okW = labelWidth(dialog and acceptLabelFor(dialog) or L.save, bfs, bpad)
	local ok, cancel
	if dialog and dialog.info then
		ok = { floor(cx - okW * 0.5), btnY1, floor(cx + okW * 0.5), btnY1 + bh }
	else
		local cancelW = labelWidth(L.cancel, bfs, bpad)
		cancel = { bx1 + pad, btnY1, bx1 + pad + cancelW, btnY1 + bh }
		ok = { bx2 - pad - okW, btnY1, bx2 - pad, btnY1 + bh }
	end

	local midW = labelWidth(dialog and dialog.middle and dialog.middle.label or L.discard, bfs, bpad)
	local midX = (bx1 + bx2) * 0.5
	local discard = { floor(midX - midW * 0.5), btnY1, floor(midX + midW * 0.5), btnY1 + bh }
	local fieldY1 = btnY1 + bh + floor(20 * scale)
	local field = { bx1 + pad, fieldY1, bx2 - pad, fieldY1 + floor(26 * scale) }

	-- The preview box, from above the field to under the summary line beneath the title.
	local box
	if preview then
		box = { bx1 + pad, field[4] + floor(14 * scale), bx2 - pad, by2 - floor(66 * scale) }
	end

	return bx1, by1, bx2, by2, ok, cancel, field, discard, messageLines, messageStep, box
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

-- Category labels, shortened to the column and carrying their colour codes, so the
-- sidebar draws them as they are. Redone when the column resizes or the catalog is
-- rebuilt; a no-op until the font exists, and the sidebar asks again once it does.
local function fitCategories()
	if not font then
		return
	end

	local labelW = sidebarW - metrics.sidePad * 2
	-- Fitted at the size they are actually drawn at, so a label is not shortened for a
	-- size the column never uses.
	for _, c in ipairs(categories) do
		local fitted = text.fit(font, c.label, labelW, metrics.catFs)
		c.textSel = colorAction .. fitted
		c.textDim = colorDim .. fitted
	end
end

----------------------------------------------------------------
-- Panel lifecycle
----------------------------------------------------------------

-- Picks up the font and the FlowUI entry points, which do not exist at include time.
function view.init()
	font = WG["fonts"].getFont()
	RectRound = WG.FlowUI.Draw.RectRound
	Scroller = WG.FlowUI.Draw.Scroller
	UiElement = WG.FlowUI.Draw.Element
	Highlight = WG.FlowUI.Draw.SelectHighlight
	UiButton = WG.FlowUI.Draw.Button
	UiUnitFrame = WG.FlowUI.Draw.UnitFrame
	state.keyboard:init(font)
	ensureControls()
end

-- Re-reads the engine and rebuilds everything shown from it.
function view.refresh()
	ensureControls()
	seedWorkingFromEngine()
	resolvedCatalog = nil
	-- Ahead of the picker, which labels its "new profile" entry from L.
	buildResolvedCatalog()
	fitCategories()
	refreshPicker()
	layoutHeader()
	rebuildRows()
end

-- Takes the panel rect from the host; every band and column is derived from it.
-- `wx1..wy2` is the window the area sits inside; without it a modal can only dim as far
-- as the area goes, leaving the panel's own border lit. Kept in `metrics` rather than a
-- local of its own, this chunk being at Lua's ceiling of 200.
function view.setArea(x1, y1, x2, y2, s, wx1, wy1, wx2, wy2)
	ensureControls()
	area.x1, area.y1, area.x2, area.y2 = x1, y1, x2, y2
	metrics.winX1, metrics.winY1 = wx1 or x1, wy1 or y1
	metrics.winX2, metrics.winY2 = wx2 or x2, wy2 or y2
	scale = s or 1
	rowHeight = floor(24 * scale)
	metrics.catRowHeight = floor(29 * scale)
	metrics.catBarW = math.max(3, floor(6 * scale))
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
	-- The scrollbar owns a column of its own: its right edge lines up with the buttons
	-- above it, and the list stops a clear gap short of it rather than running up against
	-- it. That gap matches the one the bar keeps from the panel edge on its other side, so
	-- the bar sits in a channel rather than hugging the rows.
	local barW = floor(14 * scale)
	barX1 = area.x2 - metrics.edgeInset - barW
	listRight = barX1 - metrics.listGap
	metrics.keyAreaX1 = listX1 + floor((listRight - listX1) * 0.45)

	-- The keyboard page takes the whole band the column and the list share, inset from the
	-- panel's sides like the column's own text.
	state.keyboard:setArea(
		area.x1 + metrics.sidePad,
		listBottom(),
		area.x2 - metrics.sidePad,
		metrics.listTopBase,
		scale,
		metrics.titleFs
	)
	state.applyListTop()
	state.layoutCompare()

	-- Shortened here rather than in the draw loop: the column width and the font size are
	-- both settled by now, and this runs on a resize where the loop runs every frame.
	fitCategories()

	layoutGen = layoutGen + 1
	clampScroll()
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
	if state.panelList then
		gl.DeleteList(state.panelList)
		state.panelList = nil
		state.panelSig = nil
	end
	if searchBox then
		searchBox:blur()
	end
	if presetDropdown then
		presetDropdown:close()
	end
	if state.compareDropdown then
		state.compareDropdown:close()
	end
	if nameBox then
		nameBox:blur()
	end
	capturing = nil
	-- The search is a view of the moment; the panel opens on the whole list next time. Clicking
	-- a key on the keyboard page narrows through the same box, so this is what keeps that from
	-- outliving the visit that asked for it.
	if searchBox and searchBox:getText() ~= "" then
		searchBox:setText("")
		scroll = 0
	end

	-- Or the blur outlives the panel: guishader keeps drawing a rect nobody owns any more.
	shade.clear()

	-- Through cancel rather than dropped: a live modal is holding a rollback, and the picker
	-- names a profile that was never switched to until that runs.
	cancelDialog()
end

-- The host calls this before closing; false means a dialog is now asking what to do
-- with staged edits and the close should not happen yet.
function view.confirmClose(proceed)
	return guardDirty(proceed)
end

-- The host widget, handed over so guishader can drop this panel's blur rects with it when
-- the widget goes away. Optional: with no owner the rects are simply always allowed.
function view.setOwner(w)
	shade.owner = w
end
-- Host hook for the bindable per-profile actions. Answers whether the profile was there to
-- switch to, so a key naming one the player has since deleted falls through to whatever else
-- is on it rather than being swallowed.
function view.applyProfile(name)
	if not name or not (profiles.get(name) or profiles.isBuiltin(name)) then
		return false
	end

	local from = profiles.activeName()
	if name == from then
		return true
	end

	-- Switching drops whatever is staged. Every other way of doing that asks first, and this
	-- one can arrive from the console or another widget while the panel is open, so it
	-- declines rather than discarding edits the player never answered for.
	if dirty then
		Spring.Echo("Keybind profile: save or discard your keybind changes before switching to " .. name)

		return false
	end

	return selectProfile(name, from, true)
end

-- Host hook for swapping the build menu when a profile implies one.
function view.setMenuToggle(fn)
	menuToggle = fn
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
-- Editing keysets
----------------------------------------------------------------

-- Whether the action already carries this binding. Compared canonically rather than by
-- the printed label: the label drops Any+ and resolves scancodes through the layout, so it
-- reports two bindings the engine resolves differently as the same one. exceptRaw skips
-- the keyset being rebound.
local function actionHasKeyset(action, newKeyset, exceptRaw)
	local ks = working.byAction[action]
	if not ks then
		return false
	end
	local c = keybindModel.canonicalKeyset(newKeyset)
	for _, k in ipairs(ks) do
		if k.raw ~= exceptRaw and keybindModel.canonicalKeyset(k.raw) == c then
			return true
		end
	end
	return false
end

-- The bind list is kept in engine order because two actions on one keyset are tried
-- in bind order; edits touch it in place rather than rebuilding it.
local function stageAdd(action, raw)
	working.binds[#working.binds + 1] = { keyset = raw, action = action }

	local ks = working.byAction[action]
	if not ks then
		ks = {}
		working.byAction[action] = ks
	end
	ks[#ks + 1] = { raw = raw, display = keybindModel.displayKeyset(raw, working.layout) }
end

local function stageRemove(action, raw)
	for i = #working.binds, 1, -1 do
		local b = working.binds[i]
		if b.action == action and b.keyset == raw then
			table.remove(working.binds, i)
			break
		end
	end

	local ks = working.byAction[action] or {}
	for i = #ks, 1, -1 do
		if ks[i].raw == raw then
			table.remove(ks, i)
			break
		end
	end
	-- The entry stays when its last keyset goes. Rows the catalog does not name are derived
	-- from this table, so dropping it takes the row with it and there is nothing left to
	-- click to bind the action again.
end

-- Rewrite a binding where it sits. Two actions on one keyset are tried in bind order,
-- so re-adding at the end would hand the other one priority.
local function stageReplace(action, oldRaw, newRaw)
	local entry
	for _, b in ipairs(working.binds) do
		if b.action == action and b.keyset == oldRaw then
			entry = b
			break
		end
	end

	if not entry then
		return false
	end

	entry.keyset = newRaw

	for _, k in ipairs(working.byAction[action] or {}) do
		if k.raw == oldRaw then
			k.raw = newRaw
			k.display = keybindModel.displayKeyset(newRaw, working.layout)
			break
		end
	end

	return true
end

-- The grid menu answers its category keys whether or not Shift is held, which the engine
-- can only express as two binds. Deriving both from one capture keeps a rebind from
-- leaving the halves on different keys.
-- Built from the captured elements rather than the joined keyset, so Shift lands after any
-- other modifiers the way the engine writes them: Ctrl+K pairs as Ctrl+K and Ctrl+Shift+K.
-- Shift qualifies the first tap only; later taps in a chain are the same in both halves.
local function shiftPairRaws(elems)
	local bare, shifted = {}, {}
	for i = 1, #elems do
		local e = elems[i]
		bare[i] = e.mods .. e.sym
		shifted[i] = (i == 1) and (e.mods .. "Shift+" .. e.sym) or bare[i]
	end

	return { table.concat(bare, ","), table.concat(shifted, ",") }
end

-- Rewrite every keyset an action carries, reusing the slots it already holds so the
-- rewrite does not disturb bind order. Answers whether anything actually changed.
local function stageSetKeysets(action, raws)
	local ks = working.byAction[action] or {}
	local existing = {}
	for i = 1, #ks do
		existing[i] = ks[i].raw
	end

	-- Compared as a set: these are all the same action, so which keyset sits in which slot
	-- carries no meaning, and a positional check would call a reordered pair a change and
	-- then rewrite the slots into the order they already had.
	if #existing == #raws then
		local wanted = {}
		for i = 1, #raws do
			wanted[raws[i]] = (wanted[raws[i]] or 0) + 1
		end
		for i = 1, #existing do
			wanted[existing[i]] = (wanted[existing[i]] or 0) - 1
		end

		local same = true
		for _, count in pairs(wanted) do
			if count ~= 0 then
				same = false
				break
			end
		end

		if same then
			return false
		end
	end

	local shared = (#existing < #raws) and #existing or #raws
	for i = 1, shared do
		stageReplace(action, existing[i], raws[i])
	end
	for i = shared + 1, #existing do
		stageRemove(action, existing[i])
	end
	for i = shared + 1, #raws do
		stageAdd(action, raws[i])
	end

	return true
end

-- Edit entry point: move a binding, and mark the profile staged.
local function rebindKeyset(action, oldRaw, newKeyset)
	-- Accepting the capture unchanged is not an edit. Staging it would arm Save, mark the
	-- preset unsaved, and raise the unsaved-changes guard over nothing.
	if newKeyset == oldRaw then
		return
	end

	if actionHasKeyset(action, newKeyset, oldRaw) then
		stageRemove(action, oldRaw)
	elseif not stageReplace(action, oldRaw, newKeyset) then
		stageRemove(action, oldRaw)
		stageAdd(action, newKeyset)
	end

	markStaged()
end

-- Edit entry point: extra binding for an action, and mark the profile staged.
local function addKeyset(action, newKeyset)
	if actionHasKeyset(action, newKeyset) then
		return
	end

	stageAdd(action, newKeyset)
	markStaged()
end

-- Edit entry point: drop a binding, and mark the profile staged.
local function removeKeyset(action, raw)
	-- Exactly the keyset asked for. A chip hands over every raw it stands for, so a paired
	-- action loses its pair and nothing else; clearing the action outright would take any
	-- other key it happens to carry with it.
	stageRemove(action, raw)
	markStaged()
end

-- Puts the base preset's keys back on an action: what clicking the ghost chip does.
function state.revert(action)
	local change = rowChange(action)
	if not change then
		return
	end

	local raws = {}
	for i = 1, #change do
		raws[i] = change[i]
	end
	if stageSetKeysets(action, raws) then
		markStaged()
	end
end

-- One key can drive several actions (e.g. backspace = mutesound + edit_backspace),
-- so add the binding without disturbing others on the same keyset.
local function commitCapture(keyset)
	---@type table
	local c = capturing

	-- Left open rather than closed on a key the action already carries. Closing with nothing
	-- changed is indistinguishable from the editor having dropped the press.
	if not c.oldRaw and not catalogShiftPair[c.action] and actionHasKeyset(c.action, keyset) then
		return
	end

	capturing = nil

	-- One gesture, however many edits it comes to below, files one snapshot to take back.
	state.batching, state.batchEdited = true, false
	if catalogShiftPair[c.action] then
		if stageSetKeysets(c.action, shiftPairRaws(c.elems)) then
			markStaged()
		end
	elseif c.oldRaw then
		rebindKeyset(c.action, c.oldRaw, keyset)
		-- One chip stood for every binding that read as the same key, so they all move to
		-- the new one. Collapsing them costs nothing: they were interchangeable already.
		-- Skip the one the rebind already landed on, or this undoes it and leaves the
		-- action bound to nothing.
		if keyset ~= c.oldRaw then
			for i = 2, #(c.oldRaws or {}) do
				if c.oldRaws[i] ~= keyset then
					removeKeyset(c.action, c.oldRaws[i])
				end
			end
		end
	else
		addKeyset(c.action, keyset)
	end
	state.batching = false
	if state.batchEdited then
		state.pushUndo()
	end
end

----------------------------------------------------------------
-- Modifiers and key capture
----------------------------------------------------------------

local function rawHasAny(raw)
	return raw ~= nil and raw:find("[Aa][Nn][Yy]%+") ~= nil
end

-- Nothing lets a player choose this, so a rebind infers it: the catalog's alwaysModifier
-- flag first, then whatever the action is bound with today. The engine's own stateful
-- commands (CKeyBindings::statefulCommands - drawinmap, the move* family) carry the flag in
-- the catalog rather than a list here, so one place states it and every surface can read it.
local function actionUsesAny(action, oldRaw)
	if catalogAny[action] then
		return true
	end

	for _, prefix in ipairs(catalogAnyPrefixes) do
		if action:sub(1, #prefix) == prefix then
			return true
		end
	end

	-- Rebinding one keyset keeps that keyset's own qualifier: another keyset of the same
	-- action carrying Any+ says nothing about this one, and inheriting it would silently
	-- drop the modifiers the player just pressed.
	if oldRaw then
		return rawHasAny(oldRaw)
	end

	-- Actions the catalog does not list still reach the editor under Other, so fall back
	-- to what they are bound with today.
	for _, k in ipairs(working.byAction[action] or {}) do
		if rawHasAny(k.raw) then
			return true
		end
	end

	return false
end

-- A press within the timeout extends the sequence; a slower one starts over.
local function appendChain(el)
	local c = capturing
	if not c then
		return
	end

	-- The first real press replaces what the modal opened showing.
	if c.seeded then
		c.seeded = false
		c.elems = {}
	end

	local now = spGetTimer()
	if #c.elems == 0 then
		c.elems[1] = el
	elseif c.lastPress and spDiffTimers(now, c.lastPress) * 1000 <= c.timeout then
		c.elems[#c.elems + 1] = el
	else
		c.elems = { el }
	end

	c.lastPress = now
end

-- Derived from the one canonical list so a modifier added there is understood here too.
-- modPrefix below emits in the same order, reading the state Spring returns positionally.
local modNames = {}
for i, name in ipairs(keyConfig.modifierOrder) do
	modNames[i] = name .. "+"
end

-- Strip modifiers by name so a "+"-key (e.g. numpad+) survives; the Any+ qualifier is
-- carried on the capture rather than in the element.
local function parseElem(raw)
	raw = raw:gsub("[Aa][Nn][Yy]%+", "")
	local mods = ""
	local stripped = true
	while stripped do
		stripped = false
		for _, m in ipairs(modNames) do
			if raw:sub(1, #m):lower() == m:lower() then
				mods = mods .. raw:sub(1, #m)
				raw = raw:sub(#m + 1)
				stripped = true
			end
		end
	end

	return { sym = raw, mods = mods }
end

local function startCapture(action, label, oldRaws)
	-- The grid page rebinds one keyset by name; a row chip hands over every binding it
	-- stands for, the first of which is the one being edited.
	if type(oldRaws) == "string" then
		oldRaws = { oldRaws }
	end
	local oldRaw = oldRaws and oldRaws[1] or nil

	-- Rebinding seeds the modal with the current binding; the first press clears it.
	local pair = catalogShiftPair[action]
	local elems = {}
	if oldRaw then
		for _, part in ipairs(keybindModel.splitChain(oldRaw)) do
			local elem = parseElem(part)
			if pair then
				elem.mods = (elem.mods:gsub("[Ss][Hh][Ii][Ff][Tt]%+", ""))
			end
			elems[#elems + 1] = elem
		end
	end

	local fakeMeta = activeFakeMeta()

	capturing = {
		action = action,
		label = label,
		oldRaw = oldRaw,
		oldRaws = oldRaws,
		pair = pair,
		elems = elems,
		-- Showing the existing binding rather than anything the player has pressed.
		seeded = #elems > 0,
		pressed = {},
		lastPress = nil,
		-- Matches the engine's KeyChainTimeout default; BAR ships a tighter 333ms.
		timeout = 750,
		any = actionUsesAny(action, oldRaw),
		fakeMetaCode = fakeMeta and Spring.GetKeyCode(fakeMeta) or nil,
	}
end

local function modPrefix()
	-- An action that ignores modifiers can only ever produce Any+<key>, never a
	-- contradictory Any+Shift+<key>, so held modifiers are dropped outright.
	if capturing and capturing.any then
		return ""
	end

	-- Not localised like its neighbours: this chunk is at Lua's ceiling of 200 locals and
	-- a slot is worth more elsewhere. It runs on a key press, not on a frame.
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	local prefix = ""
	if alt then
		prefix = prefix .. "Alt+"
	end
	if ctrl then
		prefix = prefix .. "Ctrl+"
	end
	if meta then
		prefix = prefix .. "Meta+"
	end
	-- A paired action answers held or not held, so Shift is not a modifier the player picks
	-- for it: holding it must read as the bare key and get its partner written behind.
	if shift and not (capturing and capturing.pair) then
		prefix = prefix .. "Shift+"
	end

	return prefix
end

-- Whether the capture is holding something worth committing. The Accept button is shown
-- only when this is true and acts only when this is true, so a button that is not on screen
-- cannot be clicked. Seeded means the modal is still showing the binding it was opened on
-- and nothing has been pressed yet: accepting that would rewrite a keyset to itself, so
-- there is nothing to offer and the way out is Cancel.
local function captureCanAccept()
	local c = capturing

	return c ~= nil and #c.elems > 0 and not c.seeded
end

-- Scancode to keyset symbol, refusing modifier keys and the stand-in Meta key so they
-- cannot bind alone; the latter is held down while the player picks what goes with it.
local function pressSym(key, scanCode)
	if capturing and key == capturing.fakeMetaCode then
		return nil
	end

	-- Not localised like its neighbours: this chunk is at Lua's ceiling of 200 locals and
	-- a slot is worth more elsewhere. It runs on a key press, not on a frame.
	local sym = scanCode and Spring.GetScanSymbol(scanCode)
	if not sym or sym == "" then
		return nil
	end
	if sym:find("ctrl") or sym:find("alt") or sym:find("shift") or sym:find("meta") or sym:find("gui") then
		return nil
	end

	return sym
end

-- Any+ replaces the held modifiers, so toggling the checkbox re-derives each element.
local function elemRaw(e)
	return ((capturing and capturing.any) and "Any+" or e.mods) .. e.sym
end

-- The captured sequence as one engine keyset string.
local function chainRaw()
	local parts = {}
	for i = 1, #capturing.elems do
		parts[i] = elemRaw(capturing.elems[i])
	end

	return table.concat(parts, ",")
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

-- One chip per distinct label rather than per binding. The Any+ qualifier is deliberately
-- never shown, so an action carrying both a plain and an Any+ binding of the same key
-- reads as that key twice; the chip stands for every binding behind it.
local function rowChipGroups(action)
	local cached = chipGroups[action]
	if cached then
		return cached
	end

	-- A paired action's two halves are one binding, so they read as one chip showing the bare
	-- key. Grouping on the Shift-stripped form is what puts them together; the chip carries
	-- both raws, so removing it takes the pair and rebinding moves the pair.
	local pair = catalogShiftPair[action]
	local groups, byDisplay = {}, {}
	for _, k in ipairs(working.byAction[action] or {}) do
		local shown = pair and keybindModel.displayWithoutShift(k.raw, working.layout) or k.display

		local group = byDisplay[shown]
		if not group then
			group = { display = shown, raws = {} }
			byDisplay[shown] = group
			groups[#groups + 1] = group
		end
		group.raws[#group.raws + 1] = k.raw
	end

	chipGroups[action] = groups

	return groups
end

-- Shares a row's width across its chips so every one stays clickable when they overflow.
local function layoutRowChips(action, fs, pad, rightGap, chipArea, gap)
	local groups = rowChipGroups(action)
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

-- The chip band for a row: where each chip sits, where "+" starts after them, and the widths
-- both callers need. Drawing and hit testing take it from here rather than each deriving the
-- same eight constants, so the click zones cannot drift from what was painted.
local function rowChipBand(action, fs, pad, reserve)
	local gap = floor(6 * scale)
	local rightGap = pad + floor(fs * 0.9)
	local addW = floor(fs + pad * 2)
	-- Room reserved on the right so "+" always fits, and whatever the caller wants after it.
	local chipArea = listRight - addW - floor(8 * scale) - metrics.keyAreaX1 - (reserve or 0)
	local mets, cx = layoutRowChips(action, fs, pad, rightGap, chipArea, gap)

	return mets, cx, addW, rightGap
end

-- Everything drawRow needs that does not move with the mouse: the fitted label and the
-- chip band, each string already carrying its colour code. Built on first use and kept on
-- the row, which rebuildRows replaces outright; a geometry change bumps layoutGen so a
-- row laid out against the old widths is measured again.
local function rowLayout(row)
	local lay = row.layout
	if lay and lay.gen == layoutGen then
		return lay
	end

	lay = { gen = layoutGen }
	if row.type == "header" then
		lay.text = colorHeader .. row.text
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
		lay.text = colorAction .. text.fit(font, row.label, labelW, metrics.rowFs)

		-- The key the base preset had, when the row's differs: a hollow chip after the row's
		-- own, which the chips make room for. Paired halves read as one key, as the chips do.
		local change = row.change
		if change then
			local shown, seen = {}, {}
			local pair = catalogShiftPair[row.action]
			for _, raw in ipairs(change) do
				local disp = pair and keybindModel.displayWithoutShift(raw, working.layout)
					or keybindModel.displayKeyset(raw, working.layout)
				if not seen[disp] then
					seen[disp] = true
					shown[#shown + 1] = disp
				end
			end
			local keys = #shown > 0 and table.concat(shown, ", ") or L.revertNone
			-- Kept whole for the chip's own tooltip, which has room the chip itself does not.
			lay.ghostKeysFull = keys
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
			m.others = conflictsOf(row.action, m.group.raws)
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
		-- A paired action holds one key expressed as two binds, so once it has one there is
		-- no second to add: capturing again rewrites the pair, and "+" would read as "add
		-- another" while silently replacing it. With nothing bound it is the only way in.
		lay.showAdd = not (catalogShiftPair[row.action] and #mets > 0)
	end
	row.layout = lay

	return lay
end

-- Which zone of an editable row sits under x: a chip body, its remove mark, or "+", with
-- the chip's index. y is checked against the chip band when given, so hover matches what
-- is painted; a click passes nil and takes the whole row height.
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

-- Geometry drawn between font:Begin and font:End interleaves with the font's batched
-- glyphs and makes both flicker. The list alternates shapes and text row by row, so it
-- queues here and flushes once all the shapes are down; the modals draw every shape
-- before any text and so print directly. Held flat and refilled in place, since a table
-- per string per frame is hundreds of allocations a second.
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

-- Rows are laid out from the top of the list band down, so the column lines up with the
-- keybind rows beside it.
-- The category column starts below where the keybind rows do, so the title above it is not
-- crowded by the first entry. Everything in the column measures from here.
local function sidebarTop()
	-- Off the band's fixed top, not the rows' own: the Changed section lowers the rows for its
	-- comparison picker, and the column beside them must not move with it.
	return (metrics.listTopBase or listTop) - metrics.sidebarDrop
end

-- `i` is the entry's place in `categories`, not its place on screen: the two differ by
-- however far the column is scrolled. That offset rides in `hover` for the same reason
-- `grab` does - this chunk is at Lua's ceiling of 200 locals.
local function categoryRect(i)
	local top = sidebarTop() - (i - 1 - hover.cat) * metrics.catRowHeight
	-- The right edge gives way to the bar when there is one. Without that an entry runs
	-- under it and its hover plate disappears beneath the bar rather than stopping beside
	-- it. The page count is worked out inline: this chunk is at Lua's 200.
	local right = area.x1 + sidebarW
	if #categories > math.max(1, floor((sidebarTop() - listBottom()) / metrics.catRowHeight)) then
		right = right - metrics.catInset - metrics.catBarW - metrics.catInset
	end

	return area.x1, top - metrics.catRowHeight, right, top
end

-- Scrolls the category column by `delta` entries and answers how far it can be scrolled
-- at all, so nought means everything fits. One function rather than the usual three,
-- this chunk being at the local ceiling; passing 0 just clamps.
local function catScrolled(delta)
	local page = math.max(1, floor((sidebarTop() - listBottom()) / metrics.catRowHeight))
	local most = math.max(0, #categories - page)
	local n = hover.cat + delta
	hover.cat = (n < 0 and 0) or (n > most and most) or n

	return most
end

-- The category entry under x,y, or nil. Half-open on the shared edge, like the rows, so
-- one point never lands in two entries.
local function sidebarIndexAt(x, y)
	local top = sidebarTop()
	if x < area.x1 or x > area.x1 + sidebarW or y > top or y <= listBottom() then
		return nil
	end

	local i = floor((top - y) / metrics.catRowHeight) + 1 + hover.cat
	if not categories[i] then
		return nil
	end

	local _, y1 = categoryRect(i)
	if y1 < listBottom() then
		return nil
	end

	return i
end

-- The grid menu is 3x4 with row 1 along the bottom, matching the keyboard rows it is
-- bound to (ZXCV under ASDF under QWER) and the order gui_gridmenu draws them in.
local gridRows, gridCols = 3, 4

-- The ids never change, so they are built once rather than concatenated per cell per frame.
local gridKeyActions, gridCategoryActions = {}, {}
for row = 1, gridRows do
	gridKeyActions[row] = {}
	for col = 1, gridCols do
		gridKeyActions[row][col] = "gridmenu_key " .. row .. " " .. col
	end
end
for c = 1, gridCols do
	gridCategoryActions[c] = "gridmenu_category " .. c
end

-- Two grids side by side: the build grid as it opens, and the same grid once a category
-- is picked, which is where Back and Next page live. Sized to roughly what the menu
-- occupies in game - 0.2125 of screen width over four columns - rather than stretched.
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

-- Through FlowUI's Button so these carry the same border, gloss and corner as every other
-- button in the UI. It serves a repeated draw from a display-list cache; the cached form
-- was checked against the immediate one and is identical, so a button does not change as
-- the cache takes over.
local function drawButtonFace(r, base)
	local pair = look.gradients[base]

	UiButton(r[1], r[2], r[3], r[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, pair[1], pair[2])
end

-- The band a category heading sits on: the sheen, the line closing it off underneath, and
-- the caption. Shared, so the grid view's heading is the same object as the list's rather
-- than a second one that has to be kept looking like it.
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
	-- Derived from the first category rather than measured from the panel top, so the card
	-- keeps its lip above the entries wherever the column starts.
	RectRound(
		area.x1,
		area.y1,
		area.x1 + sidebarW,
		sidebarTop() + metrics.cardLip,
		metrics.csPanel,
		1,
		1,
		1,
		1,
		look.sidebarFill,
		look.sidebarFillTop
	)
	queueText(L.titleText, area.x1 + metrics.sidePad, area.y2 - metrics.titleY, metrics.titleFs, "ov")

	-- A bar of its own, and a slim one: the column is narrow and this only shows up when
	-- there are more categories than the card has room for.
	if catScrolled(0) > 0 then
		local bx2 = area.x1 + sidebarW - metrics.catInset
		Scroller(
			bx2 - metrics.catBarW,
			-- Over the entries rather than the whole card: the last row rarely lands exactly on
			-- the bottom, and a bar running past it reads as dead space at the foot of the column
			-- - and its thumb then says more fits than does.
			sidebarTop()
				- math.max(1, floor((sidebarTop() - listBottom()) / metrics.catRowHeight)) * metrics.catRowHeight,
			bx2,
			sidebarTop(),
			#categories * metrics.catRowHeight,
			hover.cat * metrics.catRowHeight
		)
	end

	-- Laid out before the font existed, so the labels are still waiting to be fitted; or one of
	-- them changed since, which is the Changed entry's count.
	if state.refit or (categories[1] and not categories[1].textDim) then
		state.refit = false
		fitCategories()
	end

	local lb = listBottom()
	for i = hover.cat + 1, #categories do
		local c = categories[i]
		local x1, y1, x2, y2 = categoryRect(i)
		if y1 >= lb then
			local selected = selectedCategory == c.key
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
			local ty = floor((y1 + y2) * 0.5)
			queueText((selected and c.textSel or c.textDim) or c.label, x1 + metrics.sidePad, ty, metrics.catFs, "ov")
		end
	end
end

-- Label left, key right, sized like a category button. Used for every pill in this view.
local function drawGridPill(x1, y1, x2, y2, label, key, fs, pad, hovered, dim)
	-- Through FlowUI's Button, the way gui_gridmenu draws these same category and page
	-- buttons: the cells above them are unit slots and carry a tile frame, so these need
	-- the raised button face to not read as more of the same.
	local pair = look.gradients[pillFill]
	UiButton(x1, y1, x2, y2, 1, 1, 1, 1, 1, 1, 1, 1, nil, pair[1], pair[2])
	if hovered and not dim then
		Highlight(x1, y1, x2, y2, metrics.csButton, hoverOpacity, look.white)
	end
	-- Key is right aligned and gets only the width it needs; the label is centred in
	-- whatever is left over. With no key bound that is the whole button, which is why an
	-- unbound category reads as a plain centred caption rather than one pushed to the left.
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

-- The raw keyset a grid action carries, for seeding a rebind. nil when it has none.
local function gridKeyRaw(action)
	local ks = working.byAction[action]

	return ks and ks[1] and ks[1].raw or nil
end

-- The key a grid action currently carries, blank when it has none.
local function gridKeyText(action)
	local ks = working.byAction[action]

	return ks and ks[1] and ks[1].display or ""
end

-- Sized to its own label and key, so a longer translation widens it rather than being
-- clipped.
local function gridCycleRect(x1, bsize)
	local fs = floor(bsize * 0.45)
	local pad = floor(3 * scale)
	-- Inset to match the cells below, which sit a pad in from the block edge.
	local cx1 = x1 + pad
	local need = floor(
		(font:GetTextWidth(gridGroup.cycleLabel) + font:GetTextWidth(gridKeyText("gridmenu_cycle_builder"))) * fs
	) + pad * 10

	return cx1, cx1 + math.max(need, floor(bsize * 2))
end

-- Which grid element sits under x,y: a build cell (row, col), a category pill (index),
-- Next page or the cycle-builder pill. Hover, the baked panel's signature and clicks all
-- read it, so the three cannot disagree. Back is left out on purpose: gui_gridmenu
-- hardcodes its key, so there is nothing to rebind and nothing to light up.
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

-- Draws the grid menu as it sits on screen. Cells stay empty: what fills them in game
-- comes from the selected builder, which the editor has no notion of. zone (with its
-- two arguments) is what gridZone found under the cursor, and is what lights up.
local function drawGridMenu(zone, zoneA, zoneB)
	local x1, x2, gridBottom, cell, strip, _, stripY, builderY, headH = gridGeometry()
	local pad = floor(3 * scale)
	local keyFs = floor(cell * 0.2)
	local stripFs = floor(strip * 0.45)

	-- The same heading the list puts above a category, drawn by the same code.
	drawHeaderBand(listTop, listTop - headH, colorHeader .. gridGroup.title)

	-- These stand in for the build menu's unit tiles, so they take the same frame FlowUI
	-- puts around a unit picture, minus the picture. Every cell is the same size, so the
	-- corner is derived once and shared with the fill under it; left to itself the frame
	-- would derive its own and the two would not quite line up.
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
					-- Under the frame, so the hover lifts the tile without softening its edge.
					if zone == "cell" and zoneA == row and zoneB == col then
						Highlight(cx1 + pad, cy1 + pad, cx2 - pad, cy2 - pad, frameCs, look.rowHoverOpacity, look.white)
					end
					queueText(
						colorKey .. gridKeyText(gridKeyActions[row][col]),
						cx2 - pad * 3,
						cy2 - pad * 2 - keyFs,
						keyFs,
						"ro"
					)
				end
				-- Last, so the border and shine sit over the fill and the hover rather than
				-- under them. Plain: a group icon would name a group these cells do not have.
				-- The second grid is the same keys seen from the category view and binds
				-- nothing, so its frames are drawn faint: it is there to show the layout, not
				-- to be clicked, and a full-strength frame invites the click.
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
			gridGroup.categoryLabels[c] or "",
			gridKeyText(gridCategoryActions[c]),
			stripFs,
			pad,
			zone == "category" and zoneA == c
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
		keybindModel.displayKeyset("shift", working.layout),
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
		gridKeyText("gridmenu_next_page"),
		stripFs,
		pad,
		zone == "next"
	)

	local ccx1, ccx2 = gridCycleRect(x1, strip)
	drawGridPill(
		ccx1,
		builderY,
		ccx2,
		builderY + strip,
		gridGroup.cycleLabel,
		gridKeyText("gridmenu_cycle_builder"),
		stripFs,
		pad,
		zone == "cycle"
	)
end

-- Routes a click in the grid view to the action that cell or button binds.
local function gridPress(x, y)
	local zone, a, b = gridZone(x, y)

	if zone == "cell" then
		local action = gridKeyActions[a][b]
		startCapture(action, gridGroup.cellLabel(a, b), gridKeyRaw(action))
	elseif zone == "category" then
		local action = gridCategoryActions[a]
		startCapture(action, gridGroup.categoryLabels[a], gridKeyRaw(action))
	elseif zone == "next" then
		startCapture("gridmenu_next_page", L.gridNextPage, gridKeyRaw("gridmenu_next_page"))
	elseif zone == "cycle" then
		startCapture("gridmenu_cycle_builder", gridGroup.cycleLabel, gridKeyRaw("gridmenu_cycle_builder"))
	end

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

	-- The order's cursor: geometry, so it goes down ahead of the queued text. Blending is set
	-- rather than assumed, as for the header icons, since whatever drew before can leave one
	-- that shows the picture's transparent surround as a solid square.
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
	queueText(lay.text, lay.textX, cyc, fs, "ov")

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
		RectRound(gx, c1, gx + lay.ghostW, c2, metrics.csSmall, 1, 1, 1, 1, over and look.ghostBorderHover or look.ghostBorder)
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
	-- Preview held modifiers while forming the first element, through the same formatter a
	-- finished keyset uses so the two do not render differently. A capture opened on an
	-- existing binding still shows it, but a held modifier previews over the top - the player
	-- is part-way through a replacement - and letting go puts the original back.
	local heldRaw = modPrefix()
	local held = heldRaw ~= "" and keybindModel.displayKeyset(heldRaw, working.layout) or ""
	-- What the big line in the middle shows: the keyset formed so far, which includes the
	-- one the modal opened on. Whether that is worth committing is a separate question.
	local hasChain = #capturing.elems > 0 and not (capturing.seeded and held ~= "")
	local canAccept = captureCanAccept()

	drawButtonFace(cancel, buttonFill)
	if isInRect(mx, my, cancel[1], cancel[2], cancel[3], cancel[4]) then
		Highlight(cancel[1], cancel[2], cancel[3], cancel[4], cs, hoverOpacity, look.white)
	end
	-- Absent until there is a change to accept, rather than present and dead: a greyed
	-- button invites a click that does nothing. Green like the other commits, and
	-- brightening its own fill on hover, which the white overlay would wash out.
	if canAccept then
		local overOk = isInRect(mx, my, ok[1], ok[2], ok[3], ok[4])
		drawButtonFace(ok, overOk and confirmFillHover or confirmFill)
	end

	local chainStr
	if hasChain then
		chainStr = keybindModel.displayKeyset(chainRaw(), working.layout)
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
			for _, e in ipairs(capturing.elems) do
				tokens[#tokens + 1] = keybindModel.displayKeyset(elemRaw(e), working.layout)
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
	if hasChain and capturing.lastPress then
		local frac = 1 - (spDiffTimers(spGetTimer(), capturing.lastPress) * 1000) / capturing.timeout
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
		local raws = capturing.pair and shiftPairRaws(capturing.elems) or { chainRaw() }
		local others = conflictsOf(capturing.action, raws)
		if others then
			local names = {}
			for i = 1, #others do
				names[i] = state.labels[others[i].action] or others[i].action
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
		colorText .. text.fit(font, capturing.label or capturing.action, chainMaxW, tfs),
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

-- The import preview's sizes, shared by the drawing and the bar's hit test so a press lands on
-- what was painted: the line pitch, the inset, how many lines the box holds, how far it can
-- scroll, and the bar's rect - nil while every line fits.
function state.previewGeometry(pv, x1, y1, x2, y2)
	local lineH = floor(rowHeight * 0.66)
	local pad = floor(6 * scale)
	local barW = floor(10 * scale)
	local visible = math.max(1, floor((y2 - y1 - pad * 2) / lineH))
	local most = math.max(0, #pv.lines - visible)
	local bar = most > 0 and { x2 - pad - barW, y1 + pad, x2 - pad, y2 - pad } or nil

	return lineH, pad, visible, most, bar
end

-- Scrolls the preview so the thumb's top sits where the cursor has dragged it, the offset
-- taken at the grab keeping it relative - as the list's own bar does.
function state.previewScrollFromY(pv, bar, lineH, most, y)
	local _, _, trackTop, travel =
		WG.FlowUI.Draw.ScrollerGeometry(bar[1], bar[2], bar[3], bar[4], #pv.lines * lineH, pv.scroll * lineH)
	if not travel or travel <= 0 then
		return
	end

	local f = (trackTop - (y - pv.grab)) / travel
	if f < 0 then
		f = 0
	elseif f > 1 then
		f = 1
	end
	pv.scroll = floor(f * most + 0.5)
end

-- The import preview: the clipboard's lines in a box, in the monospaced face source gets,
-- numbered down a gutter of their own, each in the colour of what the reader makes of it, the
-- ones it will drop on a red band. Scrolled by the wheel or by the bar, whose thumb can be
-- taken hold of. The lines are fitted to the box once per width and face.
function state.drawPreview(pv, x1, y1, x2, y2, mx, my)
	local mono = WG.fonts.getFont(3) or font
	local fs = floor(rowHeight * 0.5)
	local lineH, pad, visible, most, bar = state.previewGeometry(pv, x1, y1, x2, y2)
	pv.visible = visible

	-- A drag in progress follows the cursor and ends with the button.
	if pv.drag then
		local _, _, lmb = spGetMouseState()
		if lmb and bar then
			state.previewScrollFromY(pv, bar, lineH, most, my)
		else
			pv.drag = false
		end
	end
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
		local content, pos = #pv.lines * lineH, pv.scroll * lineH
		local top, thumbH = WG.FlowUI.Draw.ScrollerGeometry(bar[1], bar[2], bar[3], bar[4], content, pos)
		local onThumb = top ~= nil and isInRect(mx, my, bar[1], top - thumbH, bar[3], top)
		Scroller(bar[1], bar[2], bar[3], bar[4], content, pos, onThumb, pv.drag)
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
	local bx1, by1, bx2, by2, ok, cancel, field, discard, messageLines, messageStep, box = dialogGeometry()
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
	local _, blocked = dialogName()
	local acceptSaves = not blocked and (dialog.save or (not dialog.message and not dialog.danger))
	local buttons = {
		{ r = ok, danger = not blocked and dialog.danger, confirm = acceptSaves, inert = blocked },
	}
	if cancel then
		buttons[#buttons + 1] = { r = cancel }
	end
	if dialog.middle then
		buttons[#buttons + 1] = { r = discard, danger = dialog.middle.danger }
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
		state.drawPreview(dialog.preview, box[1], box[2], box[3], box[4], mx, my)
	end

	font:Begin()
	font:SetOutlineColor(look.outline)
	font:Print(
		colorText .. text.fit(font, dialog.title, bx2 - bx1 - floor(32 * scale), tfs),
		cx,
		by2 - floor(26 * scale),
		tfs,
		"cov"
	)
	if box then
		font:Print(
			text.fit(font, dialog.preview.summary, bx2 - bx1 - floor(32 * scale), sfs),
			cx,
			by2 - floor(48 * scale),
			sfs,
			"cov"
		)
	end
	if dialog.middle then
		font:Print(
			colorText .. dialog.middle.label,
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
		(blocked and colorDim or colorText) .. acceptLabelFor(dialog),
		floor((ok[1] + ok[3]) * 0.5),
		floor((ok[2] + ok[4]) * 0.5),
		sfs,
		"cov"
	)
	font:End()

	if not dialog.message then
		nameBox:setRect(field[1], field[2], field[3], field[4], sfs)
		nameBox:draw()
	end
end

-- Header and footer buttons, with hotId the one under the cursor.
local function drawButtons(hotId)
	local bfs = floor(rowHeight * 0.55)
	for _, set in ipairs(buttonSets) do
		for _, b in ipairs(set) do
			local r = b.rect
			if r then
				local enabled = buttonEnabled(b.id)
				local hovered = enabled and hotId == b.id
				-- A tinted button loses its colour under the usual white hover overlay, so it
				-- brightens its own fill instead.
				local fill = b.fill and ((not enabled and b.fillMuted) or (hovered and b.fillHover) or b.fill)
				-- The page toggle sits pressed while its page is showing.
				if b.toggle and state.page == "keyboard" then
					fill = hovered and look.toggleFillHover or look.toggleFill
				end
				drawButtonFace(r, fill or buttonFill)

				-- The face lights under the cursor the way a row or the search field does. A
				-- tinted button is the exception: it would lose its colour under the overlay, so
				-- it brightens its own fill above instead.
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

-- The thumb, where it is now. Nil when the list fits and no bar is drawn. Reached through
-- WG rather than a local of its own, this chunk being at the 200-local ceiling; it is only
-- asked for on a press or a hover test, so the lookup costs nothing that matters.
local function scrollerThumb()
	return WG.FlowUI.Draw.ScrollerGeometry(
		barX1,
		listBottom(),
		area.x2 - metrics.edgeInset,
		listTop,
		rowMetrics.totalH,
		scrollOffset()
	)
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
	if not keyboardPage and mx >= barX1 and mx <= area.x2 - metrics.edgeInset then
		local top, height = scrollerThumb()
		if top and my <= top and my >= top - height then
			h.bar = 1
		end
	end

	if keyboardPage then
		h.kb = state.keyboard:hitTest(mx, my) or 0
	elseif gridGroup then
		if isInRect(mx, my, listX1, listBottom(), area.x2, listTop) then
			local kind, a, b = gridZone(mx, my)
			h.gk, h.ga, h.gb = kind or "", a or 0, b or 0
		end
	elseif mx >= listX1 and mx <= listRight then
		local r, top, bottom = rowAt(my)
		local row = r and rows[scroll + r]
		if row then
			h.row = r
			if row.type == "editable" then
				local c1, c2 = bottom + metrics.chipInset, top - metrics.chipInset
				local zone, idx = rowZone(rowLayout(row), mx, my, c1, c2)
				h.zone, h.idx = zone or "", idx or 0
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
		.. rowsGen
		.. "|"
		.. layoutGen
		.. "|"
		.. (dirty and 1 or 0)
		.. "|"
		.. (activeIsOwn() and 1 or 0)
		.. "|"
		.. h.bar
		.. "|"
		.. h.cat
		.. "|"
		.. (hover.drag and 1 or 0)
		.. "|"
		.. state.page
		.. "|"
		.. (keyboardPage and state.keyboard:signature(h.kb) or "")
end

-- The card the keyboard page shows for an action: its label, what it does, its picture, its
-- category and where the catalog ranks it. Built from the resolved catalog on first use and
-- dropped with it; an action under a prefix family takes the family's card with the label the
-- list gave its row, and one the catalog never lists is its own id under Other.
function state.keyInfoFor(action)
	local info = state.keyInfo
	if not info then
		info = { byAction = {}, prefixes = {} }
		state.keyInfo = info
		for gi, g in ipairs(resolvedCatalog or {}) do
			if not g.hidden then
				for ii, item in ipairs(g.items) do
					local rank = gi * 1000 + ii
					if item.prefix then
						info.prefixes[#info.prefixes + 1] = {
							prefix = item.prefix,
							description = item.description,
							icon = item.icon,
							category = g.category,
							rank = rank,
						}
					elseif item.action then
						info.byAction[item.action] = {
							label = item.label,
							description = item.description,
							icon = item.icon,
							category = g.category,
							rank = rank,
						}
					end
				end
			end
		end
	end

	local card = info.byAction[action]
	if card then
		return card
	end
	local best
	for _, p in ipairs(info.prefixes) do
		if p.prefix ~= "" and action:sub(1, #p.prefix) == p.prefix and (not best or #p.prefix > #best.prefix) then
			best = p
		end
	end
	card = {
		label = state.labels[action] or action,
		description = best and best.description,
		icon = best and best.icon,
		category = (best and best.category) or "categories.other",
		rank = (best and best.rank) or math.huge,
	}
	info.byAction[action] = card

	return card
end

-- Places the staged keymap on the keyboard, once per change to it.
function state.ensureKeyboard()
	if state.keyboardGen ~= rowsGen then
		state.keyboardGen = rowsGen
		state.keyboard:place(working.binds, state.hidden, working.layout, catalogShiftPair, state.keyInfoFor)
	end
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
	state.ensureKeyboard()
	queueText(L.titleText, area.x1 + metrics.sidePad, area.y2 - metrics.titleY, metrics.titleFs, "ov")
	state.keyboard:draw(hoverIdx)
end

-- Everything under the header controls and above the modals: the sidebar, the list or
-- grid, the scroller and the buttons. Compiled into the panel display list, so an idle
-- frame replays it for one call instead of a few hundred draws.
local function drawPanel()
	local h = hover
	if state.page == "keyboard" then
		state.drawKeyboardPage(h.kb)
	else
		drawSidebar(h.sb)
	end

	if state.page == "keyboard" then
		flushText()
	elseif gridGroup then
		drawGridMenu(h.gk, h.ga, h.gb)
		flushText()
	else
		-- The Changed section's comparison strip, above its rows: a dark strip rather than a
		-- heading, so it reads as a control and not as a second title over the first heading,
		-- with a dim caption against the picker, which draws live over the strip's right end
		-- since its list can open.
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
		for r = 1, #rows - scroll do
			local row = rows[scroll + r]
			if not row then
				break
			end
			local top = listTop - (row.off - base)
			local bottom = top - rowHeightOf(row)
			if bottom < lb then
				break
			end
			local hovered = h.row == r
			drawRow(row, top, bottom, hovered, hovered and h.zone or "", h.idx)
		end
		flushText()

		Scroller(barX1, lb, area.x2 - metrics.edgeInset, listTop, rowMetrics.totalH, base, h.bar == 1, hover.drag)
	end

	-- The picker's caption. Nothing about it changes between layouts, so it bakes with the
	-- body rather than printing live beside the picker it names.
	queueText(L.presetText, metrics.presetLabelX, metrics.presetLabelY, metrics.presetLabelFs, "o")

	-- Where staged edits go. On a default it shows before anything is staged, too: that is
	-- when a player is working out whether editing it is safe.
	local own = activeIsOwn()
	local notice = (dirty and (own and L.noticeUnsavedText or L.noticeDefaultUnsavedText))
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
	local own = activeIsOwn()
	for _, b in ipairs(headerButtons) do
		if b.rect then
			WG["tooltip"].AddTooltip(b.tooltipId, b.rect, L[(not own and b.tipLocked) or b.tip], nil, L[b.id])
		end
	end
	state.tooltipsRegistered = true
end

-- What the cursor is over, said in a tooltip: a preset's description in the picker, what the
-- column's Changed entry lists, and on a row the action's description, the other actions its
-- hovered key drives, and the key the base preset had. Built once per thing hovered and shown
-- every frame after, the tooltip widget showing only what it was told this frame.
function state.showTooltips(mx, my)
	local tip = WG["tooltip"]
	if not tip or dialog or capturing then
		return
	end

	local key, title, lines
	-- The preset picker's options, and the comparison picker's while its band is up: both
	-- name presets, so both get the preset's description.
	local pick = presetDropdown:optionAt(mx, my)
	local pickOptions, pickSelected = presetOptions, presetDropdown.selected
	if not pick and state.compareBand() then
		pick = state.compareDropdown:optionAt(mx, my)
		pickOptions, pickSelected = state.compareDropdown.options, state.compareDropdown.selected
	end
	if pick then
		local opt = pick > 0 and pickOptions[pick] or pickOptions[pickSelected]
		if opt and not opt.name then
			opt = nil
		end
		if opt then
			key = "preset|" .. opt.name
			title = opt.name
			if key ~= state.tipKey then
				lines = {}
				local builtin = profiles.isBuiltin(opt.name)
				if builtin then
					if builtin.description then
						lines[#lines + 1] = colorText .. BAR.I18N(builtin.description)
					end
					lines[#lines + 1] = colorDim .. L.presetDefault
				else
					local base = profiles.baseOf(opt.name)
					lines[#lines + 1] = colorDim
						.. (base and BAR.I18N("ui.keybinds.editor.presetBasedOn", { name = base.name }) or L.presetOwn)
				end
			end
		end
	elseif state.page ~= "list" then
		-- The keyboard page: the key under the cursor, on the layer showing, or the view toggle.
		if hover.kb ~= 0 then
			state.ensureKeyboard()
			key, title = state.keyboard:tooltip(hover.kb)
			if key and key ~= state.tipKey then
				lines = state.keyboard:tooltipLines(hover.kb)
			end
		end
	elseif hover.sb > 0 and categories[hover.sb] and categories[hover.sb].key == state.changedKey then
		key = "changed|" .. tostring(state.base and state.base.name)
		title = categories[hover.sb].label
		if key ~= state.tipKey then
			if state.base then
				lines = { colorText .. BAR.I18N("ui.keybinds.editor.changedTooltip", { name = state.base.name }) }
			else
				lines = { colorDim .. L.changedNoneTooltip }
			end
		end
	elseif hover.row > 0 then
		local row = rows[scroll + hover.row]
		if row and row.type == "editable" then
			key = "row|" .. row.action .. "|" .. hover.zone .. "|" .. hover.idx .. "|" .. rowsGen .. "|" .. layoutGen
			title = row.label
			if key ~= state.tipKey then
				local lay = rowLayout(row)
				lines = {}
				-- The chip is a control of its own, so it says what clicking it does and nothing
				-- else. Leading with the row, which describes something the click does not do,
				-- buries the one line that belongs to what is under the cursor.
				if hover.zone == "revert" and row.change and state.base then
					title = nil
					lines[1] = colorText .. BAR.I18N("ui.keybinds.editor.revertTooltip", { keys = lay.ghostKeysFull })
				else
					if row.description then
						lines[#lines + 1] = colorText .. row.description
					end
					local m = hover.idx > 0 and lay.mets[hover.idx]
					if m and m.others then
						local names = {}
						for i, o in ipairs(m.others) do
							local name = state.labels[o.action] or o.action
							names[i] = o.before and BAR.I18N("ui.keybinds.editor.conflictFirst", { action = name })
								or name
						end
						-- A warning when the sharing is the player's; a note when the game ships it so.
						lines[#lines + 1] = (m.clash and colorDanger or colorDim)
							.. BAR.I18N(
								"ui.keybinds.editor.conflict",
								{ keys = m.group.display, actions = table.concat(names, ", ") }
							)
						lines[#lines + 1] = colorDim .. (m.clash and L.conflictOrder or L.conflictShipped)
					end
					if row.change and state.base then
						if #row.change > 0 then
							lines[#lines + 1] = colorHeader
								.. BAR.I18N(
									"ui.keybinds.editor.defaultIn",
									{ name = state.base.name, keys = lay.ghostKeys }
								)
						else
							lines[#lines + 1] = colorHeader
								.. BAR.I18N("ui.keybinds.editor.defaultNone", { name = state.base.name })
						end
					end
				end
			end
		end
	end

	if not key then
		state.tipKey = nil

		return
	end
	if key ~= state.tipKey then
		state.tipKey, state.tipTitle = key, title
		if lines and #lines > 0 then
			local body = table.concat(lines, "\n")
			if font.WrapText then
				body = font:WrapText(body, (tip.getFontsize and tip.getFontsize() or 12) * 90)
			end
			state.tipText = text.carryColors(body)
		else
			state.tipText = nil
		end
	end
	if state.tipText then
		tip.ShowTooltip("keybindeditor", state.tipText, nil, nil, state.tipTitle)
	end
end

-- Paints the whole panel. The header controls and the modals draw live; the body is
-- replayed from its display list until panelSignature says something in it moved.
-- Which of the popups is up, and where. Defined down here rather than beside the rest of
-- `shade`: it reads the popup state and geometry, none of which exists that far up.
function shade.update()
	if capturing then
		local bx1, by1, bx2, by2 = captureGeometry()
		shade.rect("capture", bx1, by1, bx2, by2)
	else
		shade.rect("capture")
	end

	if dialog then
		local bx1, by1, bx2, by2 = dialogGeometry()
		shade.rect("dialog", bx1, by1, bx2, by2)
	else
		shade.rect("dialog")
	end

	-- The list the picker drops, which stands clear of the control and over the rows.
	local opts = presetDropdown and presetDropdown:isOpen() and presetDropdown.optRects
	if opts and opts[1] then
		shade.rect("picker", opts[1].x1, opts[#opts].y1, opts[1].x2, opts[1].y2)
	else
		shade.rect("picker")
	end

	local compare = state.compareDropdown
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
	if not working then
		view.refresh()
	end
	if state.layoutPending then
		layoutHeader()
	end

	-- Pinned rather than assumed: widgets on lower layers draw first and leave blending,
	-- colour and depth wherever they finished, which changes how everything below
	-- composites from one frame to the next.
	glTexture(false)
	glColor(1, 1, 1, 1)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(false)

	local rawMx, rawMy, lmb = spGetMouseState()
	if hover.drag then
		if lmb then
			scrollFromY(rawMy)
		else
			hover.drag = false
		end
	end

	-- Prevent the hover over preset options and modals from also being detected by the
	-- regular rows, sidebar and buttons sitting underneath them.
	local mx, my = rawMx, rawMy
	if dialog or capturing or presetDropdown:isOpen() or state.compareDropdown:isOpen() then
		mx, my = -1, -1
	end

	-- The keyboard page shows the layer of whatever is held on the real keyboard, for as long
	-- as it is held; the signature below carries the layer, so the picture follows.
	if state.page == "keyboard" then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		state.keyboard:setHeld(alt, ctrl, meta, shift)
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

	searchBox:draw()

	-- The comparison picker, live like the preset picker: its list opens over the rows.
	if state.compareBand() then
		if state.compareDropdown:isOpen() then
			shade.float("compare", function()
				state.compareDropdown:draw()
			end)
		else
			shade.drop("compare")
			state.compareDropdown:draw()
		end
	else
		shade.drop("compare")
	end

	if not state.tooltipsRegistered and WG["tooltip"] then
		registerTooltips()
	end

	-- Each of these covers UI rather than map, so it takes the blur with it and is drawn
	-- back on top of it. See `shade` for why that is two steps and not one.
	if presetDropdown:isOpen() then
		shade.float("picker", function()
			presetDropdown:draw()
		end)
	else
		shade.drop("picker")
		presetDropdown:draw()
	end

	-- Real cursor: these are the overlay, so the hover is theirs to detect.
	if capturing then
		shade.float("capture", function()
			drawCaptureModal(rawMx, rawMy)
		end)
	else
		shade.drop("capture")
	end

	if dialog then
		shade.float("dialog", function()
			drawProfileDialog(rawMx, rawMy)
		end)
	else
		shade.drop("dialog")
	end

	-- After they have laid themselves out, so the blur behind one is the right size on
	-- the frame it appears rather than the one after.
	shade.update()

	state.showTooltips(rawMx, rawMy)
end

-- Scrolls so the thumb's top sits where the cursor has dragged it. The offset taken at
-- the grab is what keeps this relative: the thumb moves with the cursor rather than
-- centring itself on it, so taking hold of it does not shift the list before the drag.
scrollFromY = function(y)
	local _, _, trackTop, travel = scrollerThumb()
	if not travel or travel <= 0 then
		return
	end

	local f = (trackTop - (y - hover.grab)) / travel
	if f < 0 then
		f = 0
	elseif f > 1 then
		f = 1
	end
	scroll = floor(f * maxScroll() + 0.5)
	clampScroll()
end

----------------------------------------------------------------
-- Input
----------------------------------------------------------------

-- Scrolls the list; a modal swallows the wheel instead, the import preview scrolling its
-- own lines with it.
function view.mouseWheel(up, value)
	if dialog then
		local pv = dialog.preview
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
	if capturing or gridGroup or state.page == "keyboard" then
		return
	end

	local mx, my = spGetMouseState()
	-- Over the column it scrolls the column, over anything else the list. A wheel that
	-- moved the list while the cursor was on the categories would read as broken.
	if mx <= area.x1 + sidebarW and my > listBottom() and my <= sidebarTop() then
		catScrolled(up and -1 or 1)
	elseif my >= listBottom() and my <= listTop then
		-- The chat history's modifiers: Ctrl moves three notches' worth at once, Shift a whole
		-- page - the rows the band holds from where the list is now, since headings are taller
		-- than the bindings under them.
		local _, ctrl, _, shift = Spring.GetModKeyState()
		local step = ctrl and 9 or 3
		if shift then
			ensureRowMetrics()
			local band, used = listTop - listBottom(), 0
			step = 0
			for i = scroll + 1, #rows do
				used = used + rowHeightOf(rows[i])
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
	if x < area.x1 or x > area.x1 + sidebarW or y < listBottom() or y > sidebarTop() then
		return false
	end

	local i = sidebarIndexAt(x, y)
	local c = i and categories[i]
	if c and selectedCategory ~= c.key then
		selectedCategory = c.key
		scroll = 0
		rebuildRows()
	end

	return true
end

-- Routes a click on a keybind row to the edit it implies.
local function handleZone(kind, action, label, raws)
	if kind == "remove" then
		-- One chip, one snapshot to take back, however many binds it stood for.
		state.batching, state.batchEdited = true, false
		for _, raw in ipairs(raws) do
			removeKeyset(action, raw)
		end
		state.batching = false
		if state.batchEdited then
			state.pushUndo()
		end
	elseif kind == "revert" then
		state.revert(action)
	elseif kind == "add" then
		startCapture(action, label)
	elseif kind == "rebind" then
		startCapture(action, label, raws)
	end
end

-- Routes a click to whichever layer is on top: modal, dropdown, sidebar, then the list.
function view.mousePress(x, y, button)
	if not isInRect(x, y, area.x1, area.y1, area.x2, area.y2) then
		return false
	end

	if dialog then
		if button == 1 then
			local bx1, by1, bx2, by2, ok, cancel, field, discard, _, _, box = dialogGeometry()
			if isInRect(x, y, ok[1], ok[2], ok[3], ok[4]) then
				acceptDialog()
			elseif dialog.middle and isInRect(x, y, discard[1], discard[2], discard[3], discard[4]) then
				middleDialog()
			elseif
				(cancel ~= nil and isInRect(x, y, cancel[1], cancel[2], cancel[3], cancel[4]))
				or x < bx1
				or x > bx2
				or y < by1
				or y > by2
			then
				cancelDialog()
			elseif box and isInRect(x, y, box[1], box[2], box[3], box[4]) then
				-- Taking hold of the preview's bar: on the thumb a grab that keeps the lines put,
				-- on the track a jump to the cursor and then a drag from the thumb's middle.
				local pv = dialog.preview
				local lineH, _, _, most, bar = state.previewGeometry(pv, box[1], box[2], box[3], box[4])
				if bar and isInRect(x, y, bar[1], bar[2], bar[3], bar[4]) then
					local top, thumbH = WG.FlowUI.Draw.ScrollerGeometry(
						bar[1],
						bar[2],
						bar[3],
						bar[4],
						#pv.lines * lineH,
						pv.scroll * lineH
					)
					if top then
						pv.drag = true
						if y <= top and y >= top - thumbH then
							pv.grab = y - top
						else
							pv.grab = -floor(thumbH * 0.5)
							state.previewScrollFromY(pv, bar, lineH, most, y)
						end
					end
				end
			elseif not dialog.message then
				nameBox:mousePress(x, y)
			end
		end

		return true
	end

	-- In the modal, mouse1 drives its controls; only side buttons (mouse4+) bind.
	if capturing then
		local bx1, by1, bx2, by2, ok, cancel = captureGeometry()
		if button == 1 then
			-- Only while Accept is actually on screen; where it would be is otherwise just
			-- part of the modal and swallows the click.
			if captureCanAccept() and isInRect(x, y, ok[1], ok[2], ok[3], ok[4]) then
				commitCapture(chainRaw())
			elseif
				(isInRect(x, y, cancel[1], cancel[2], cancel[3], cancel[4]))
				or x < bx1
				or x > bx2
				or y < by1
				or y > by2
			then
				capturing = nil
			end
		elseif button >= 4 then
			appendChain({ sym = "mouse" .. button, mods = modPrefix() })
		end
		return true
	end

	if button ~= 1 then
		return true
	end

	-- The open list draws over the header and footer, so it gets the click before they do.
	-- Closed, this only claims its own toggle and everything below still sees the press.
	local ddWasOpen = presetDropdown:isOpen()
	if presetDropdown:mousePress(x, y) then
		searchBox:blur()
		capturing = nil

		return true
	end
	if ddWasOpen then
		return true
	end

	-- The comparison picker likewise, while its band is up.
	if state.compareBand() then
		local wasOpen = state.compareDropdown:isOpen()
		if state.compareDropdown:mousePress(x, y) then
			searchBox:blur()

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
				searchBox:blur()
				presetDropdown:close()
				if buttonEnabled(b.id) then
					if b.id == "save" then
						startSave()
					elseif b.id == "reset" then
						startReset()
					elseif b.id == "duplicate" then
						startDuplicate()
					elseif b.id == "edit" then
						startEdit()
					elseif b.id == "export" then
						startClipboard(true)
					elseif b.id == "import" then
						startClipboard(false)
					elseif b.id == "keyboard" then
						state.setPage(state.page == "keyboard" and "list" or "keyboard")
					end
				end

				return true
			end
		end
	end

	if searchBox:mousePress(x, y) then
		capturing = nil
		return true
	end
	searchBox:blur()

	-- The keyboard page: a modifier toggles its layer, the toggle swaps the view, and a bound
	-- key goes to the list page filtered to that key on that layer, which lists everything on
	-- it with its bindings to hand.
	if state.page == "keyboard" then
		state.ensureKeyboard()
		local kind, key, layer = state.keyboard:mousePress(x, y, button)
		if kind == "key" then
			-- Handed to the search box rather than filtered behind the scenes. It finds what a
			-- key holds already, and it does it somewhere the player can see what is narrowing
			-- the list and clear it. The keyset is spelled the way they would have typed it.
			state.setPage("list")
			selectedCategory = nil
			scroll = 0
			if searchBox then
				searchBox:setText(state.keyboard:keysetName(key, layer))
			end
		end

		return true
	end

	if sidebarPress(x, y) then
		return true
	end

	if not gridGroup and isInRect(x, y, barX1, listBottom(), area.x2, listTop) then
		-- Taking hold of the bar. On the thumb that is a grab and the list stays put; on the
		-- track either side the thumb jumps to the cursor first and is then dragged from its
		-- middle, which is what a press on bare track is asking for. Inline because this chunk
		-- is at Lua's ceiling of 200 locals and a function of its own would need a slot.
		local top, height = scrollerThumb()
		if top then
			hover.drag = true
			if y <= top and y >= top - height then
				hover.grab = y - top
			else
				hover.grab = -floor(height * 0.5)
				scrollFromY(y)
			end
		end

		return true
	end

	if gridGroup and isInRect(x, y, listX1, listBottom(), area.x2, listTop) then
		return gridPress(x, y)
	end

	if isInRect(x, y, listX1, listBottom(), listRight, listTop) then
		-- Through the same lookup the drawing uses, so the band's last partial row - which
		-- is never painted - cannot be clicked either.
		local r = rowAt(y)
		local row = r and rows[scroll + r]
		if row and row.type == "editable" then
			local kind, raw = hitTestRow(row, x)
			if kind then
				handleZone(kind, row.action, row.label, raw)
			end
		elseif row and row.type == "link" then
			selectedCategory = row.category
			scroll = 0
			rebuildRows()
		end
		return true
	end

	return true
end

function view.textInput(char)
	if dialog then
		return not dialog.message and nameBox:textInput(char)
	end
	if searchBox and searchBox:isFocused() then
		return searchBox:textInput(char)
	end

	return false
end

-- Keys, offered to the modal, the capture, the dropdown and the search box in that order.
function view.keyPress(key, scanCode)
	if dialog then
		if key == KEYSYMS.ESCAPE then
			cancelDialog()
		elseif key == KEYSYMS.RETURN then
			acceptDialog()
		elseif not dialog.message then
			-- Focus is dropped by the editbox on Escape/Return, which are handled above.
			nameBox:keyPress(key)
		end

		return true
	end

	if capturing then
		if key == 27 then
			capturing = nil
		else
			-- Skip auto-repeat; only the initial press adds an element (release clears pressed).
			local sym = pressSym(key, scanCode)
			if sym and not capturing.pressed[scanCode] then
				capturing.pressed[scanCode] = true
				appendChain({ sym = sym, mods = modPrefix() })
			end
		end
		return true
	end

	if presetDropdown and presetDropdown:isOpen() then
		if key == 27 then
			presetDropdown:close()
		end
		return true
	end
	if state.compareDropdown and state.compareDropdown:isOpen() then
		if key == 27 then
			state.compareDropdown:close()
		end
		return true
	end

	-- A grid category replaces the list outright, and picking another category in the
	-- column is otherwise the only way back out of it. Escape is the other way, and it
	-- has to come before the panel closes: leaving a view is what the key is for.
	if gridGroup and key == 27 then
		selectedCategory = nil
		scroll = 0
		rebuildRows()

		return true
	end

	-- Ctrl+Z takes the last edit back. Below the capture and the dropdown, which take every
	-- key while they are up; above the search field, which has no use for it.
	if key == KEYSYMS.Z then
		local _, ctrl = Spring.GetModKeyState()
		if ctrl then
			state.undoEdit()

			return true
		end
	end

	-- Escape empties the search before it closes the panel: the list being read is the one
	-- the search made, and the first Escape is asking for that back. With nothing left to
	-- clear it goes unclaimed, and the widget above closes the panel on it.
	if key == KEYSYMS.ESCAPE then
		if searchBox and searchBox:getText() ~= "" then
			-- Focus stays, so the next thing typed starts a new search.
			searchBox:setText("")

			return true
		end
		if searchBox then
			searchBox:blur()
		end

		return false
	end

	if searchBox and searchBox:isFocused() then
		return searchBox:keyPress(key)
	end

	return false
end

-- Only a capture cares about releases, to know a held key has gone.
function view.keyRelease(key, scanCode)
	if capturing then
		capturing.pressed[scanCode] = nil
	end
end

return view
