-- The keyboard page of the keybind editor: a full-size keyboard drawn key by key, each cap
-- carrying the action it fires on the layer shown. A layer is a set of modifiers. Clicking
-- Shift, Ctrl, Alt or Meta on the drawn keyboard toggles that modifier into the layer, and
-- holding the real one shows it for as long as it is held, so the page reads like the
-- keyboard it stands for. Two views share the page: the main block, and the arrows,
-- navigation keys and number pad, with the modifiers beside them so the layers still work.
-- It is an overview rather than an editor: a click on a bound key hands that key to the
-- list page, which is where bindings are changed.
--
-- Bindings come in as the editor's working keymap, so staged edits show here before they
-- are saved. Each is placed on the key that starts it (a chain lands on its first tap) under
-- the modifiers it names. Any+ bindings fire whatever is held, so they sit on every layer,
-- after the bindings that name that layer exactly - the order the engine tries them in.
--
-- The face of a key shows one action, and it is the one a player thinks of the key as
-- doing: the first by catalog order, not by bind order. The engine walks a key's actions
-- in bind order until one takes it, and the presets lean on that to put a special case
-- ahead of the general one - the Grid preset binds "stopproduction" ahead of "stop" on G,
-- and the spectator's "specteam" ahead of "group select" on the digits. Catalog order puts
-- the general action first, which is what the key is for. The tooltip lists them all.

local keybindModel = VFS.Include("luaui/Include/keybind_model.lua")
local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")
local Search = VFS.Include("luaui/Include/search.lua")
local text = VFS.Include("luaui/Include/keybind_text.lua")

local floor = math.floor
local max = math.max
local min = math.min
local isInRect = math.isInRect
local glColor = gl.Color
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glBlending = gl.Blending

---@class KeybindKeyboard
---@field keys table[] Every drawn key, in definition order; `id` is its index
---@field shown integer[] The keys placed in the current view
---@field view string "main" or "numpad"
---@field toggled table<string, boolean?> Modifiers toggled on the drawn keyboard
---@field held table<string, boolean?> Modifiers held on the real one
---@field layoutName string? The keyboard layout the names were resolved for
---@field tokenIndex table<string, integer>? Canonical key token -> key index
---@field query table The search, from Search.query
---@field queryTokens string[]
---@field queryGen integer
---@field filter table? The key the list is filtered to: `id` and `layer`
---@field filterGen integer
---@field gen integer Bumped by every placement
---@field layoutGen integer Bumped by every resize
---@field unplaced integer Bindings on keys neither view draws
---@field L table<string, string> The page's strings
---@field area table
---@field scale number
---@field font table?
---@field UiKey function?
---@field UiButton function?
---@field Highlight function?
---@field infoFor function?
---@field shiftPair table<string, boolean>
---@field hintLines string[]?
---@field hintWidth number?
---@field unit number?
---@field frames table<string, table> Per view: the origin the keys are placed from
---@field button table? The view toggle's rect
---@field cs number
---@field pad number
---@field padY number
---@field nameFs number
---@field labelFs number
---@field moreFs number
---@field iconSize number
---@field hintFs number
---@field titleFs number
---@field buttonFs number
local M = {}
M.__index = M

----------------------------------------------------------------
-- The keyboard
----------------------------------------------------------------

-- Every key the page can draw, once, with where it sits in each view that shows it: `main`
-- and `numpad` give `x` from the view's left edge and `y` from the top in key units, `w`
-- and `h` in units when not one. A view is as many units wide as `viewCols` says, and the
-- page is `ROWS` tall: the caption row on top, then the keys spaced the way they are on the
-- keyboard itself - the function row under the caption, the main block half a unit lower.
--
-- Named keys carry the engine's names for them: `scan` for the scancode names (sc_<name>)
-- and `code` for the keycode ones, every spelling the engine accepts. A character key
-- carries the qwerty character of its position instead. Its scancode name is that character
-- (or the engine's word for a punctuation key, `word`), and the player's keyboard layout
-- decides both the character printed on it and the keycode that lands there. `shifted` is
-- the symbol the US layout prints above a punctuation key, shown when the layout leaves
-- that key as it is. `mod` marks a modifier key, which toggles its layer when clicked; the
-- modifiers sit in both views, so a layer can be toggled from either.
local ROWS = 7.5
local viewCols = { main = 15, numpad = 10 }
-- How large the text on the keys reads, over the base shares of the key set in setArea.
local KEY_TEXT_SCALE = 1.2
local viewOrder = { "main", "numpad" }

local up, down, left, right = "\226\134\145", "\226\134\147", "\226\134\144", "\226\134\146"

local keyDefs = {
	{ main = { x = 14, y = 0 }, numpad = { x = 4.5, y = 1 }, name = "Pause", scan = { "pause" }, code = { "pause" } },

	{ main = { x = 0, y = 1 }, name = "Esc", scan = { "esc", "escape" }, code = { "esc", "escape" } },
	{ main = { x = 2, y = 1 }, name = "F1", scan = { "f1" }, code = { "f1" } },
	{ main = { x = 3, y = 1 }, name = "F2", scan = { "f2" }, code = { "f2" } },
	{ main = { x = 4, y = 1 }, name = "F3", scan = { "f3" }, code = { "f3" } },
	{ main = { x = 5, y = 1 }, name = "F4", scan = { "f4" }, code = { "f4" } },
	{ main = { x = 6.5, y = 1 }, name = "F5", scan = { "f5" }, code = { "f5" } },
	{ main = { x = 7.5, y = 1 }, name = "F6", scan = { "f6" }, code = { "f6" } },
	{ main = { x = 8.5, y = 1 }, name = "F7", scan = { "f7" }, code = { "f7" } },
	{ main = { x = 9.5, y = 1 }, name = "F8", scan = { "f8" }, code = { "f8" } },
	{ main = { x = 11, y = 1 }, name = "F9", scan = { "f9" }, code = { "f9" } },
	{ main = { x = 12, y = 1 }, name = "F10", scan = { "f10" }, code = { "f10" } },
	{ main = { x = 13, y = 1 }, name = "F11", scan = { "f11" }, code = { "f11" } },
	{ main = { x = 14, y = 1 }, name = "F12", scan = { "f12" }, code = { "f12" } },

	{
		main = { x = 0, y = 2.5 },
		char = "`",
		word = "backquote",
		shifted = "~",
		scan = { "`" },
		code = { "~", "tilde", "backquote" },
	},
	{ main = { x = 1, y = 2.5 }, char = "1" },
	{ main = { x = 2, y = 2.5 }, char = "2" },
	{ main = { x = 3, y = 2.5 }, char = "3" },
	{ main = { x = 4, y = 2.5 }, char = "4" },
	{ main = { x = 5, y = 2.5 }, char = "5" },
	{ main = { x = 6, y = 2.5 }, char = "6" },
	{ main = { x = 7, y = 2.5 }, char = "7" },
	{ main = { x = 8, y = 2.5 }, char = "8" },
	{ main = { x = 9, y = 2.5 }, char = "9" },
	{ main = { x = 10, y = 2.5 }, char = "0" },
	{ main = { x = 11, y = 2.5 }, char = "-", word = "minus", shifted = "_", scan = { "-" } },
	{ main = { x = 12, y = 2.5 }, char = "=", word = "equals", shifted = "+", scan = { "=" } },
	{ main = { x = 13, y = 2.5, w = 2 }, name = "Backspace", scan = { "backspace" }, code = { "backspace" } },

	{ main = { x = 0, y = 3.5, w = 1.5 }, name = "Tab", scan = { "tab" }, code = { "tab" } },
	{ main = { x = 1.5, y = 3.5 }, char = "Q" },
	{ main = { x = 2.5, y = 3.5 }, char = "W" },
	{ main = { x = 3.5, y = 3.5 }, char = "E" },
	{ main = { x = 4.5, y = 3.5 }, char = "R" },
	{ main = { x = 5.5, y = 3.5 }, char = "T" },
	{ main = { x = 6.5, y = 3.5 }, char = "Y" },
	{ main = { x = 7.5, y = 3.5 }, char = "U" },
	{ main = { x = 8.5, y = 3.5 }, char = "I" },
	{ main = { x = 9.5, y = 3.5 }, char = "O" },
	{ main = { x = 10.5, y = 3.5 }, char = "P" },
	{ main = { x = 11.5, y = 3.5 }, char = "[", word = "leftbracket", shifted = "{", scan = { "[" } },
	{ main = { x = 12.5, y = 3.5 }, char = "]", word = "rightbracket", shifted = "}", scan = { "]" } },
	{
		main = { x = 13.5, y = 3.5, w = 1.5 },
		char = "\\",
		word = "backslash",
		shifted = "|",
		scan = { "\\" },
		code = { "backslash" },
	},

	{ main = { x = 0, y = 4.5, w = 1.75 }, name = "Caps Lock", code = { "capslock" } },
	{ main = { x = 1.75, y = 4.5 }, char = "A" },
	{ main = { x = 2.75, y = 4.5 }, char = "S" },
	{ main = { x = 3.75, y = 4.5 }, char = "D" },
	{ main = { x = 4.75, y = 4.5 }, char = "F" },
	{ main = { x = 5.75, y = 4.5 }, char = "G" },
	{ main = { x = 6.75, y = 4.5 }, char = "H" },
	{ main = { x = 7.75, y = 4.5 }, char = "J" },
	{ main = { x = 8.75, y = 4.5 }, char = "K" },
	{ main = { x = 9.75, y = 4.5 }, char = "L" },
	{ main = { x = 10.75, y = 4.5 }, char = ";", word = "semicolon", shifted = ":", scan = { ";" } },
	{ main = { x = 11.75, y = 4.5 }, char = "'", word = "apostrophe", shifted = '"', scan = { "'" } },
	{ main = { x = 12.75, y = 4.5, w = 2.25 }, name = "Enter", scan = { "return" }, code = { "return", "enter" } },

	{
		main = { x = 0, y = 5.5, w = 2.25 },
		numpad = { x = 0, y = 2.5, w = 2 },
		name = "Shift",
		mod = "shift",
		scan = { "shift" },
		code = { "shift" },
	},
	{ main = { x = 2.25, y = 5.5 }, char = "Z" },
	{ main = { x = 3.25, y = 5.5 }, char = "X" },
	{ main = { x = 4.25, y = 5.5 }, char = "C" },
	{ main = { x = 5.25, y = 5.5 }, char = "V" },
	{ main = { x = 6.25, y = 5.5 }, char = "B" },
	{ main = { x = 7.25, y = 5.5 }, char = "N" },
	{ main = { x = 8.25, y = 5.5 }, char = "M" },
	{ main = { x = 9.25, y = 5.5 }, char = ",", word = "comma", shifted = "<", scan = {} },
	{ main = { x = 10.25, y = 5.5 }, char = ".", word = "period", shifted = ">", scan = { "." } },
	{ main = { x = 11.25, y = 5.5 }, char = "/", word = "slash", shifted = "?", scan = { "/" } },
	{ main = { x = 12.25, y = 5.5, w = 2.75 }, name = "Shift", mod = "shift", code = { "rshift" } },

	{
		main = { x = 0, y = 6.5, w = 1.25 },
		numpad = { x = 0, y = 3.5, w = 2 },
		name = "Ctrl",
		mod = "ctrl",
		scan = { "ctrl" },
		code = { "ctrl" },
	},
	{
		main = { x = 1.25, y = 6.5, w = 1.25 },
		numpad = { x = 0, y = 5.5, w = 2 },
		name = "Meta",
		mod = "meta",
		scan = { "meta" },
		code = { "meta" },
	},
	{
		main = { x = 2.5, y = 6.5, w = 1.25 },
		numpad = { x = 0, y = 4.5, w = 2 },
		name = "Alt",
		mod = "alt",
		scan = { "alt" },
		code = { "alt" },
	},
	{ main = { x = 3.75, y = 6.5, w = 6.25 }, name = "Space", scan = { "space" }, code = { "space" } },
	{ main = { x = 10, y = 6.5, w = 1.25 }, name = "Alt", mod = "alt", code = { "ralt" } },
	{ main = { x = 13.75, y = 6.5, w = 1.25 }, name = "Ctrl", mod = "ctrl", code = { "rctrl" } },

	-- The navigation keys, the arrows and the number pad, laid out as they sit to the right of
	-- the main block, with the modifiers in a column to their left.
	{
		numpad = { x = 2.5, y = 1 },
		name = "Print",
		scan = { "printscreen", "print" },
		code = { "printscreen", "print" },
	},
	-- Printed the way a keycap prints them, the full names being wider than a key.
	{ numpad = { x = 3.5, y = 1 }, name = "ScrLk", code = { "scrollock" } },
	{ numpad = { x = 2.5, y = 2.5 }, name = "Insert", scan = { "insert" }, code = { "insert" } },
	{ numpad = { x = 3.5, y = 2.5 }, name = "Home", scan = { "home" }, code = { "home" } },
	{ numpad = { x = 4.5, y = 2.5 }, name = "PgUp", scan = { "pageup" }, code = { "pageup" } },
	{ numpad = { x = 2.5, y = 3.5 }, name = "Delete", scan = { "delete" }, code = { "delete" } },
	{ numpad = { x = 3.5, y = 3.5 }, name = "End", scan = { "end" }, code = { "end" } },
	{ numpad = { x = 4.5, y = 3.5 }, name = "PgDn", scan = { "pagedown" }, code = { "pagedown" } },
	{ numpad = { x = 3.5, y = 5.5 }, name = up, scan = { "up" }, code = { "up" } },
	{ numpad = { x = 2.5, y = 6.5 }, name = left, scan = { "left" }, code = { "left" } },
	{ numpad = { x = 3.5, y = 6.5 }, name = down, scan = { "down" }, code = { "down" } },
	{ numpad = { x = 4.5, y = 6.5 }, name = right, scan = { "right" }, code = { "right" } },

	{ numpad = { x = 6, y = 2.5 }, name = "NumLk", code = { "numlock" } },
	{ numpad = { x = 7, y = 2.5 }, name = "/", scan = { "numpad/" }, code = { "numpad/" } },
	{ numpad = { x = 8, y = 2.5 }, name = "*", scan = { "numpad*" }, code = { "numpad*" } },
	{ numpad = { x = 9, y = 2.5 }, name = "-", scan = { "numpad-" }, code = { "numpad-" } },
	{ numpad = { x = 6, y = 3.5 }, name = "7", scan = { "numpad7" }, code = { "numpad7" } },
	{ numpad = { x = 7, y = 3.5 }, name = "8", scan = { "numpad8" }, code = { "numpad8" } },
	{ numpad = { x = 8, y = 3.5 }, name = "9", scan = { "numpad9" }, code = { "numpad9" } },
	{ numpad = { x = 9, y = 3.5, h = 2 }, name = "+", scan = { "numpad+" }, code = { "numpad+" } },
	{ numpad = { x = 6, y = 4.5 }, name = "4", scan = { "numpad4" }, code = { "numpad4" } },
	{ numpad = { x = 7, y = 4.5 }, name = "5", scan = { "numpad5" }, code = { "numpad5" } },
	{ numpad = { x = 8, y = 4.5 }, name = "6", scan = { "numpad6" }, code = { "numpad6" } },
	{ numpad = { x = 6, y = 5.5 }, name = "1", scan = { "numpad1" }, code = { "numpad1" } },
	{ numpad = { x = 7, y = 5.5 }, name = "2", scan = { "numpad2" }, code = { "numpad2" } },
	{ numpad = { x = 8, y = 5.5 }, name = "3", scan = { "numpad3" }, code = { "numpad3" } },
	{ numpad = { x = 9, y = 5.5, h = 2 }, name = "Enter", scan = { "numpad_enter" }, code = { "numpad_enter" } },
	{ numpad = { x = 6, y = 6.5, w = 2 }, name = "0", scan = { "numpad0" }, code = { "numpad0" } },
	{ numpad = { x = 8, y = 6.5 }, name = ".", scan = { "numpad." }, code = { "numpad." } },
}

-- Modifier names in the order the engine writes them, which is the order a layer's caption
-- and its key read them in.
local modifierNames = {}
for i, name in ipairs(keyConfig.modifierOrder) do
	modifierNames[i] = name:lower()
end

-- A layer's key: the modifiers it holds, in that order, joined with "+". No modifiers is "".
local function layerKeyOf(mods)
	local parts = {}
	for _, name in ipairs(modifierNames) do
		if mods[name] then
			parts[#parts + 1] = name
		end
	end

	return table.concat(parts, "+")
end

----------------------------------------------------------------
-- Colours and sizes
----------------------------------------------------------------

local colorText = "\255\235\235\235"
local colorDim = "\255\160\160\160"
local colorKey = "\255\235\185\070"

local look = {
	-- Caps: a bound key, one with nothing on this layer, a modifier at rest, a modifier
	-- whose layer is showing, and a key the search found or the list is filtered to.
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
	-- The outline every string here is drawn with, set on every batch: the font is shared with
	-- every other widget, some of which set an outline of their own and leave it, and text
	-- baked into a display list keeps whatever outline was set last. The editor's value.
	outline = { 0, 0, 0, 0.4 },
}

-- FlowUI's Button gradients from a bottom stop to a top one; each fill becomes a darker
-- bottom and itself on top, the shape the editor's other buttons take. Derived once per fill.
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

-- Label colours by catalog category, so a key's action reads as the kind of thing it is at a
-- glance: groups in blue, camera in gold, build in yellow. Anything unlisted prints plain.
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

----------------------------------------------------------------
-- Construction
----------------------------------------------------------------

function M.new()
	local self = setmetatable({}, M) ---@type KeybindKeyboard
	self.keys = {}
	for i, def in ipairs(keyDefs) do
		---@type table<string, any>
		local key = {}
		for k, v in pairs(def) do
			key[k] = v
		end
		key.id = i
		key.rects = {}
		key.layers = {}
		key.any = {}
		key.show = {}
		self.keys[i] = key
	end
	self.shown = {}
	self.view = "main"
	-- Modifiers toggled on the drawn keyboard, and those held on the real one.
	self.toggled = {}
	self.held = {}
	self.layoutName = nil
	self.query = Search.query(nil)
	self.queryTokens = {}
	self.queryGen = 0
	self.filter = nil
	self.filterGen = 0
	self.gen = 0
	self.layoutGen = 0
	self.unplaced = 0
	self.L = {}
	self.area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
	self.frames = {}
	self.scale = 1

	return self
end

-- Picks up the font and the FlowUI entry points, which do not exist at include time. Called
-- again on a resize: the font handler hands out new objects then.
function M:init(font)
	self.font = font
	self.UiKey = WG.FlowUI.Draw.Key
	self.UiButton = WG.FlowUI.Draw.Button
	self.Highlight = WG.FlowUI.Draw.SelectHighlight
	self.layoutGen = self.layoutGen + 1
end

-- Re-reads the page's own strings. Modifier and key names are read from the layout on the
-- next placement, since they change with the keyboard layout rather than the language.
function M:refreshStrings()
	local L = self.L
	L.layerBase = BAR.I18N("ui.keybinds.keyboard.layerBase")
	L.layer = BAR.I18N("ui.keybinds.keyboard.layer")
	L.hint = BAR.I18N("ui.keybinds.keyboard.hint")
	L.notShown = BAR.I18N("ui.keybinds.keyboard.notShown")
	L.unbound = BAR.I18N("ui.keybinds.keyboard.unbound")
	L.anyModifier = BAR.I18N("ui.keybinds.keyboard.anyModifier")
	L.paired = BAR.I18N("ui.keybinds.keyboard.paired")
	L.clickKey = BAR.I18N("ui.keybinds.keyboard.clickKey")
	L.clickModifier = BAR.I18N("ui.keybinds.keyboard.clickModifier")
	L.clickModifierOff = BAR.I18N("ui.keybinds.keyboard.clickModifierOff")
	L.numpad = BAR.I18N("ui.keybinds.keyboard.numpad")
	L.numpadTooltip = BAR.I18N("ui.keybinds.keyboard.numpadTooltip")
	L.numpadText = look.buttonText .. L.numpad
	self.hintLines = nil
end

----------------------------------------------------------------
-- Geometry
----------------------------------------------------------------

-- Lays both views out inside the rect: as large as the main view's fifteen units fit across
-- and seven and a half units fit down, each view centred in whatever is left over. The
-- caption row and the view toggle keep to the main view's frame, so they stay put when the
-- view changes. Every edge and size is a whole pixel.
function M:setArea(x1, y1, x2, y2, scale, titleFs)
	local a = self.area
	a.x1, a.y1, a.x2, a.y2 = x1, y1, x2, y2
	self.scale = scale or 1

	local unit = floor(min((x2 - x1) / viewCols.main, (y2 - y1) / ROWS))
	self.unit = unit
	self.titleFs = max(titleFs or 0, floor(unit * 0.22))
	-- Half the gap between two keys goes on each side of every key, so a wide key and two
	-- narrow ones fill the same span.
	local half = max(1, floor(unit * 0.045))
	local oy = floor(y2 - (y2 - y1 - unit * ROWS) * 0.5)
	for _, view in ipairs(viewOrder) do
		self.frames[view] = { ox = floor(x1 + (x2 - x1 - unit * viewCols[view]) * 0.5), oy = oy }
	end
	self.cs = max(2, floor(unit * 0.09))
	self.pad = max(2, floor(unit * 0.07))
	-- Tighter than the sides: the face's height is what three lines of a label under the key's
	-- name have to share.
	self.padY = max(2, floor(unit * 0.045))
	-- The key's name reads first, its action smaller under it, and the count of further
	-- actions smaller still: each a share of the key in whole pixels, scaled by KEY_TEXT_SCALE.
	self.nameFs = max(9, floor(floor(unit * 0.14) * KEY_TEXT_SCALE + 0.5))
	self.labelFs = max(8, floor(floor(unit * 0.125) * KEY_TEXT_SCALE + 0.5))
	self.moreFs = max(8, floor(floor(unit * 0.11) * KEY_TEXT_SCALE + 0.5))
	self.iconSize = floor(unit * 0.24)
	-- The hint is a sentence read at a glance, so it prints larger than a key's label; two or
	-- three lines of it fit the caption row.
	self.hintFs = max(9, floor(unit * 0.17))
	self.buttonFs = max(8, floor(unit * 0.15))

	for _, key in ipairs(self.keys) do
		for _, view in ipairs(viewOrder) do
			local at = key[view]
			if at then
				local ox = self.frames[view].ox
				key.rects[view] = {
					ox + floor(at.x * unit) + half,
					oy - floor((at.y + (at.h or 1)) * unit) + half,
					ox + floor((at.x + (at.w or 1)) * unit) - half,
					oy - floor(at.y * unit) - half,
				}
			end
		end
	end

	-- The toggle, at the right of the caption row, clear of the Pause key at the row's end.
	local main = self.frames.main
	local bw, bh = floor(unit * 2.2), floor(unit * 0.5)
	local bx2 = main.ox + floor(unit * 13.75)
	local by1 = floor(oy - unit * 0.5 - bh * 0.5)
	self.button = { bx2 - bw, by1, bx2, by1 + bh }

	self:applyView()
	self.layoutGen = self.layoutGen + 1
	self.hintLines = nil
end

-- Which keys the current view draws, and where. A key not in the view has no rect, so the
-- hit test and the drawing skip it.
function M:applyView()
	self.shown = {}
	for i, key in ipairs(self.keys) do
		local r = key.rects[self.view]
		if r then
			key.x1, key.y1, key.x2, key.y2 = r[1], r[2], r[3], r[4]
			self.shown[#self.shown + 1] = i
		else
			key.x1, key.y1, key.x2, key.y2 = nil, nil, nil, nil
		end
	end
end

function M:setView(view)
	if not viewCols[view] or view == self.view then
		return
	end
	self.view = view
	self:applyView()
	self.layoutGen = self.layoutGen + 1
end

----------------------------------------------------------------
-- Names and placement
----------------------------------------------------------------

-- What the cap prints and the engine names the key by, for the player's keyboard layout.
-- Each key gets the canonical tokens (as keybind_model spells them: "sc:q", "kc:a") that
-- land on it, and the index from token to key that placement looks bindings up in.
---@return table<string, integer> index
function M:applyLayout(layoutName)
	self.layoutName = layoutName
	local positional = keyConfig.scanToCode[layoutName] or keyConfig.scanToCode.qwerty
	local index = {}
	self.tokenIndex = index

	local function claim(token, i)
		-- First come first served: a layout that puts one character on two keys is broken,
		-- and the drawn keyboard can only show it once.
		if index[token] == nil then
			index[token] = i
		end
	end

	for i, key in ipairs(self.keys) do
		local tokens = {}
		if key.char then
			local upper = key.char:upper()
			local produced = positional[upper] or upper
			-- The engine's scancode name for the position, and the keycode of whatever the
			-- layout puts there. Punctuation carries the engine's word for it as well.
			tokens[#tokens + 1] = "sc:" .. key.char:lower()
			if key.word then
				tokens[#tokens + 1] = "sc:" .. key.word
			end
			tokens[#tokens + 1] = "kc:" .. produced:lower()
			-- The engine's other spellings of a keycode only hold while the key still makes
			-- the character they spell.
			if key.code and produced == upper then
				for _, name in ipairs(key.code) do
					tokens[#tokens + 1] = "kc:" .. name
				end
			end
			key.label = keyConfig.sanitizeKey("sc_" .. (key.word or key.char), layoutName)
			key.shiftedLabel = (produced == upper) and key.shifted or nil
			-- What the list's chips print for the key.
			key.searchName = key.label
		else
			for _, name in ipairs(key.scan or {}) do
				tokens[#tokens + 1] = "sc:" .. name
			end
			for _, name in ipairs(key.code or {}) do
				tokens[#tokens + 1] = "kc:" .. name
			end
			key.label = key.name
			key.shiftedLabel = nil
			local spelled = (key.scan and key.scan[1] and ("sc_" .. key.scan[1])) or (key.code and key.code[1]) or ""
			key.searchName = keyConfig.sanitizeKey(spelled, layoutName)
		end
		key.tokens = tokens
		for _, token in ipairs(tokens) do
			claim(token, i)
		end
		key.lower = key.label:lower()
	end

	return index
end

-- Places every binding on its key. `infoFor(action)` answers with the action's label,
-- description, icon, category and catalog rank; `hidden` names the actions the catalog
-- keeps off every surface; `shiftPair` the actions bound twice, bare and with Shift.
function M:place(binds, hidden, layoutName, shiftPair, infoFor)
	if not self.tokenIndex or layoutName ~= self.layoutName then
		self:applyLayout(layoutName)
	end
	local index = self.tokenIndex or {}
	self.infoFor = infoFor
	self.shiftPair = shiftPair or {}
	self.gen = self.gen + 1
	self.unplaced = 0
	self.hintLines = nil

	for _, key in ipairs(self.keys) do
		key.layers = {}
		key.any = {}
		key.show = {}
	end

	local seen = {}
	for _, b in ipairs(binds or {}) do
		if not (hidden and hidden[b.action]) then
			local elems = keybindModel.splitChain(b.keyset)
			local mods, keyToken = keybindModel.splitElement(keybindModel.canonicalKeyset(elems[1] or b.keyset))
			-- Nil for a key the keyboard does not draw: keys[0] is nothing.
			local idx = (keyToken and index[keyToken]) or 0
			local key = self.keys[idx] --[[@as table?]]
			if key then
				local list, layer
				if mods.any then
					list = key.any
					layer = "any"
				else
					layer = layerKeyOf(mods)
					list = key.layers[layer]
					if not list then
						list = {}
						key.layers[layer] = list
					end
				end
				-- The same action on the same key and layer twice is one entry: a keymap can
				-- say it twice, and the face has one slot.
				local dup = idx .. "|" .. layer .. "|" .. b.action
				if not seen[dup] then
					seen[dup] = true
					list[#list + 1] = {
						action = b.action,
						raw = b.keyset,
						chain = #elems > 1,
						any = mods.any or false,
					}
				end
			else
				self.unplaced = self.unplaced + 1
			end
		end
	end
end

-- The action's card, asked of the host and kept on the entry.
function M:infoOf(entry)
	if not entry.info then
		entry.info = (self.infoFor and self.infoFor(entry.action)) or { label = entry.action, rank = math.huge }
	end

	return entry.info
end

-- What a key shows on a layer: the bindings naming exactly those modifiers, then the Any+
-- ones, each block in catalog order. Kept per layer until the bindings change.
function M:entries(key, layer)
	local show = key.show[layer]
	if show and show.gen == self.gen then
		return show.entries
	end

	local entries = {}
	local function take(list)
		local sorted = {}
		for i, e in ipairs(list) do
			sorted[i] = e
		end
		table.sort(sorted, function(a, b)
			local ra, rb = self:infoOf(a).rank or math.huge, self:infoOf(b).rank or math.huge
			if ra ~= rb then
				return ra < rb
			end
			return a.action < b.action
		end)
		for _, e in ipairs(sorted) do
			entries[#entries + 1] = e
		end
	end
	take(key.layers[layer] or {})
	take(key.any)

	-- A paired order's Shift half does what the bare key does; on a layer holding Shift it is
	-- marked, so the layer reads as what Shift adds rather than everything Shift keeps.
	local bare
	if layer:find("shift", 1, true) then
		local without = layer:gsub("%+?shift", "")
		bare = key.layers[without] or {}
	end
	for _, e in ipairs(entries) do
		e.paired = false
		if bare and self.shiftPair[e.action] then
			for _, b in ipairs(bare) do
				if b.action == e.action then
					e.paired = true
					break
				end
			end
		end
	end

	key.show[layer] = { gen = self.gen, entries = entries }

	return entries
end

----------------------------------------------------------------
-- Layers, search, filter and hit testing
----------------------------------------------------------------

-- The modifiers in effect: toggled on the drawn keyboard or held on the real one.
function M:activeMods()
	local mods = {}
	for _, name in ipairs(modifierNames) do
		mods[name] = self.toggled[name] or self.held[name] or false
	end

	return mods
end

function M:layer()
	return layerKeyOf(self:activeMods())
end

function M:toggle(mod)
	self.toggled[mod] = not self.toggled[mod] or nil
end

function M:setHeld(alt, ctrl, meta, shift)
	local h = self.held
	h.alt, h.ctrl, h.meta, h.shift = alt or nil, ctrl or nil, meta or nil, shift or nil
end

-- The search box's text. A key is found by its own name, or by an action it shows on the
-- layer; the rest sink. Key names are whole words, as the list's key search takes them, so
-- "f1" does not light F11.
function M:setQuery(str)
	local query = Search.query(str)
	if query.text == self.query.text then
		return
	end
	self.query = query
	self.queryTokens = {}
	for token in query.text:gmatch("[^%s%+]+") do
		self.queryTokens[#self.queryTokens + 1] = token
	end
	self.queryGen = self.queryGen + 1
end

-- The key the list is filtered to, lit here and nowhere else: `id` names the key and `layer`
-- the modifiers it was clicked under. Nil clears it.
function M:setFilter(filter)
	self.filter = filter
	self.filterGen = self.filterGen + 1
end

function M:matches(key, entries)
	local query = self.query
	if query.empty then
		return nil
	end
	for _, token in ipairs(self.queryTokens) do
		if token == key.lower or (key.mod and token == key.mod) then
			return true
		end
	end
	for _, e in ipairs(entries) do
		local info = self:infoOf(e)
		if Search.matches(query, (info.label or ""):lower()) or Search.matches(query, e.action:lower()) then
			return true
		end
	end

	return false
end

-- The key under the point, by index; -1 for the view toggle; nil for neither.
function M:hitTest(x, y)
	local b = self.button
	if b and isInRect(x, y, b[1], b[2], b[3], b[4]) then
		return -1
	end
	for _, i in ipairs(self.shown) do
		local key = self.keys[i] --[[@as table]]
		if isInRect(x, y, key.x1, key.y1, key.x2, key.y2) then
			return i
		end
	end

	return nil
end

-- Everything the baked picture is painted from, beyond what the host already tracks.
function M:signature(hoverIdx)
	return (hoverIdx or 0)
		.. "|"
		.. self:layer()
		.. "|"
		.. self.queryGen
		.. "|"
		.. self.gen
		.. "|"
		.. self.layoutGen
		.. "|"
		.. self.view
		.. "|"
		.. self.filterGen
end

-- A click: the toggle swaps the view; a modifier toggles its layer; a bound key is handed
-- back with the layer it was clicked under, for the list to filter to. Nothing else answers.
function M:mousePress(x, y, button)
	if button ~= 1 then
		return nil
	end
	local idx = self:hitTest(x, y)
	if idx == -1 then
		self:setView(self.view == "main" and "numpad" or "main")

		return "view", self.view
	end
	local key = idx and self.keys[idx] or nil
	if not key then
		return nil
	end
	if key.mod then
		self:toggle(key.mod)

		return "modifier", key.mod
	end
	local layer = self:layer()
	if #self:entries(key, layer) == 0 then
		return nil
	end

	return "key", key, layer
end

-- The key with the layer's modifiers in front, the way a chip prints it.
function M:keysetName(key, layer)
	local parts = {}
	local mods = layer and {} or self:activeMods()
	if layer then
		for name in layer:gmatch("[^+]+") do
			mods[name] = true
		end
	end
	for _, name in ipairs(modifierNames) do
		if mods[name] then
			parts[#parts + 1] = name:sub(1, 1):upper() .. name:sub(2)
		end
	end
	parts[#parts + 1] = key.searchName or key.label

	return table.concat(parts, " + ")
end

----------------------------------------------------------------
-- Tooltips
----------------------------------------------------------------

-- What the tooltip is about, so the host rebuilds its text only when that changes.
function M:tooltip(idx)
	if idx == -1 then
		return "kb|button|" .. self.view, self.L.numpad
	end
	local key = self.keys[idx]
	if not key then
		return nil
	end
	local layer = self:layer()

	return "kb|" .. idx .. "|" .. layer .. "|" .. self.gen, self:keysetName(key)
end

-- The tooltip's lines: every action on the key for this layer, in the order the face ranks
-- them, each with what it does; then what a click here does.
function M:tooltipLines(idx)
	local L = self.L
	if idx == -1 then
		return { colorDim .. L.numpadTooltip }
	end
	local key = self.keys[idx]
	if not key then
		return {}
	end
	local lines = {}
	if key.mod then
		local tipKey = self.toggled[key.mod] and "ui.keybinds.keyboard.clickModifierOff"
			or "ui.keybinds.keyboard.clickModifier"
		lines[#lines + 1] = colorDim .. BAR.I18N(tipKey, { mod = key.label })
	end
	local entries = self:entries(key, self:layer())
	for _, e in ipairs(entries) do
		local info = self:infoOf(e)
		local line = (e.paired and look.paired or colorText) .. (info.label or e.action)
		if e.chain then
			line = line .. "  " .. colorKey .. keybindModel.displayKeyset(e.raw, self.layoutName)
		end
		if e.any then
			line = line .. "  " .. colorDim .. L.anyModifier
		elseif e.paired then
			line = line .. "  " .. colorDim .. L.paired
		end
		lines[#lines + 1] = line
		if info.description then
			lines[#lines + 1] = colorDim .. info.description
		end
	end
	if #entries == 0 and not key.mod then
		lines[#lines + 1] = colorDim .. L.unbound
	end
	if #entries > 0 and not key.mod then
		lines[#lines + 1] = colorDim .. L.clickKey
	end

	return lines
end

----------------------------------------------------------------
-- Drawing
----------------------------------------------------------------

-- The size a key's name prints at: the page's, unless the name is wider than the face at
-- that size, then as much smaller as makes it fit. Measured once per name, room and layout.
function M:nameSize(key, room)
	if key.nameFsGen == self.layoutGen and key.nameFsLabel == key.label and key.nameFsRoom == room then
		return key.nameFsFit
	end
	local size = self.nameFs
	local width = self.font:GetTextWidth(key.label) * size
	if width > room and width > 0 then
		size = max(floor(size * 0.6), floor(size * room / width))
	end
	key.nameFsFit, key.nameFsGen, key.nameFsLabel, key.nameFsRoom = size, self.layoutGen, key.label, room

	return size
end

-- The label a key wears on a layer, wrapped and fitted to its face, kept until the bindings
-- or the geometry change.
function M:faceLines(key, layer, entries, faceW, maxLines)
	local show = key.show[layer]
	if show.lines and show.linesGen == self.layoutGen and show.linesMax == maxLines then
		return show.lines, show.first
	end
	local first = entries[1]
	local lines = {}
	if first then
		local info = self:infoOf(first)
		local label = info.label or first.action
		local fs = self.labelFs
		local wrapped = text.wrap(self.font, label, faceW, fs)
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
			lines[i] = text.fit(self.font, line, faceW, fs)
		end
	end
	show.lines, show.first, show.linesGen, show.linesMax = lines, first, self.layoutGen, maxLines

	return lines, first
end

-- The caption's hint, wrapped to the room left of the caption once, per size and language.
function M:hintFor(width)
	if self.hintLines and self.hintWidth == width then
		return self.hintLines
	end
	local lines = text.wrap(self.font, self.L.hint or "", width, self.hintFs)
	if self.unplaced > 0 then
		local note = BAR.I18N("ui.keybinds.keyboard.notShown", { n = self.unplaced })
		for _, line in ipairs(text.wrap(self.font, note, width, self.hintFs)) do
			lines[#lines + 1] = line
		end
	end
	for i = 4, #lines do
		lines[i] = nil
	end
	for i, line in ipairs(lines) do
		lines[i] = text.fit(self.font, line, width, self.hintFs)
	end
	self.hintLines, self.hintWidth = lines, width

	return lines
end

-- Paints the page: the caption row with the view toggle, then every key of the view with
-- its picture and words. Called inside the host's display list, so all of it bakes and
-- replays until the signature moves.
function M:draw(hoverIdx)
	local font = self.font
	local UiKey = self.UiKey
	if not font or not UiKey or not self.unit then
		return
	end
	local mods = self:activeMods()
	local layer = layerKeyOf(mods)
	local unit, pad, cs = self.unit, self.pad, self.cs
	local padY = self.padY
	local searching = not self.query.empty
	local filter = self.filter
	local nameLineH = floor(self.nameFs * 1.12)
	local lineH = floor(self.labelFs * 1.1)
	local prints = {}
	local function print(str, x, y, size, opts)
		prints[#prints + 1] = { str, x, y, size, opts }
	end

	-- Caps and pictures first, words after, in one font batch.
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	for _, i in ipairs(self.shown) do
		local key = self.keys[i] --[[@as table]]
		local entries = self:entries(key, layer)
		local active = key.mod and mods[key.mod]
		local filtered = filter and filter.id == key.id and filter.layer == layer
		local hit = (searching and self:matches(key, entries)) or filtered
		local fill = (active and look.modifierActive)
			or (hit and look.hit)
			or (key.mod and look.modifier)
			or (entries[1] and look.bound)
			or look.unbound
		local opacity = (searching and not hit and not active) and look.missOpacity or 1
		local fx1, fy1, fx2, fy2 = UiKey(key.x1, key.y1, key.x2, key.y2, cs, fill, active, hoverIdx == i, opacity)
		local light = active
		local faceW = fx2 - fx1 - pad * 2
		-- Text on a dark cap carries the panel's dark outline; dark text on a light cap does
		-- not, an outline there being a dark ring round dark letters.
		local oLeft, oCentre, oRight = "o", "co", "ro"
		if light then
			oLeft, oCentre, oRight = "", "c", "r"
		end

		-- The key's own name, top left, at the page's name size or smaller for the odd name too
		-- long for its key; the symbol Shift makes of it beside, dimmer.
		local nameFs = self:nameSize(key, faceW)
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

		-- The room under the name: the first action's words, as many lines as fit, centred. The
		-- last line may reach into the bottom padding; a label seldom has a descender there.
		local bandTop = nameTop - nameLineH
		local bandBottom = fy1 + floor(padY * 0.5)
		local maxLines = min(3, max(1, floor((bandTop - bandBottom) / lineH)))
		local lines, first = self:faceLines(key, layer, entries, faceW, maxLines)
		-- The top right corner: the action's picture, and how many more actions the tooltip
		-- lists, which sits left of the picture when there is one.
		local cornerX = fx2 - pad
		if first then
			local info = self:infoOf(first)
			local color = light and look.labelOnLight
				or (first.paired and look.paired)
				or categoryColors[info.category or ""]
				or colorText
			local n = #lines
			local blockTop = floor((bandTop + bandBottom + n * lineH) * 0.5)
			local cx = floor((fx1 + fx2) * 0.5)
			for li = 1, n do
				local top = blockTop - (li - 1) * lineH
				local ly = text.baseline(font, top - lineH, top, self.labelFs)
				print(color .. lines[li], cx, ly, self.labelFs, oCentre)
			end

			if info.icon and self.iconSize > 0 then
				local s = self.iconSize
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
			print(count, cornerX, nameY, self.moreFs, oRight)
		end
	end

	-- The caption row: which layer this is, centred over the keyboard; how to work the page,
	-- in the room to the left of it; and the view toggle at its right.
	local frame = self.frames.main
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
		caption = look.caption .. (self.L.layerBase or "")
	end
	local captionX = frame.ox + floor(unit * 7.5)
	print(caption, captionX, text.baseline(font, rowBottom, rowTop, self.titleFs), self.titleFs, "co")

	local hintW = floor(unit * 5.5) - pad
	local hintLines = self:hintFor(hintW)
	local hintLineH = floor(self.hintFs * 1.25)
	local blockTop = floor((rowTop + rowBottom + #hintLines * hintLineH) * 0.5)
	for li, line in ipairs(hintLines) do
		local top = blockTop - (li - 1) * hintLineH
		local y = text.baseline(font, top - hintLineH, top, self.hintFs)
		print(look.hint .. line, frame.ox + pad, y, self.hintFs, "o")
	end

	local b = self.button
	if b and self.UiButton then
		local overButton = hoverIdx == -1
		local fill = (self.view == "numpad" and (overButton and look.buttonFillHover or look.buttonFillActive))
			or look.buttonFill
		local pair = look.gradients[fill]
		self.UiButton(b[1], b[2], b[3], b[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, pair[1], pair[2])
		if overButton and self.view ~= "numpad" and self.Highlight then
			self.Highlight(b[1], b[2], b[3], b[4], floor(cs * 0.5), look.buttonHoverOpacity, look.white)
		end
		print(
			self.L.numpadText or "",
			floor((b[1] + b[3]) * 0.5),
			text.baseline(font, b[2], b[4], self.buttonFs),
			self.buttonFs,
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

return M
