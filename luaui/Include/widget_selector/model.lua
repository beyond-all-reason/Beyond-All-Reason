-- The widget selector without its window: what the widgets are, how they are grouped, filtered and ordered, the
-- sets and favourites, what a widget has saved, what each control says and does. Nothing here draws or knows about
-- pixels.
--
-- A window includes this once per widget and:
--   sets the hooks (confirm, searchText, onSetsChanged, onCategoriesBuilt, onContentChanged) and model.font,
--   lays out and draws model.rows, model.categories, model.switches and model.buttons,
--   fills model.hover from the cursor, for model.showTooltip,
--   passes the callins on: syncProfiling, finishClear, contentMoved, holdKeyboard, heldAtFocus, and the saved config.
local Search = require("luaui/Include/search")
local text = require("luaui/Include/keybind_text")
-- Wrapping every callin to time it is global and does not nest, so one thing owns it and
-- everything else reads what it measured. Subscribing is what puts the wrappers in, so
-- nothing is paid for until the column is switched on.
local profiling = require("luaui/Include/widget_profiling")

local mathFloor = math.floor
local mathMax = math.max

local spEcho = Spring.Echo
local spSendCommands = Spring.SendCommands
local math_isInRect = math.isInRect

local colorDim = "\255\160\160\160"

local look = {}

---@class WidgetSelectorModel
---@field font any
---@field entries table[]
---@field categories table[]
---@field rows table[]
---@field buttons table[]
---@field confirm fun(title: string, message: string, accept: function, danger: boolean?, field: boolean?, initial: string?)
---@field searchText fun(): string?
---@field onSetsChanged fun()
---@field onCategoriesBuilt fun()
---@field onContentChanged fun()
local model = {
	look = look,
	hover = { sb = 0, row = 0, sw = 0, tog = 0, bar = 0, clr = 0, dat = 0, star = 0, btn = "", dlg = "" },
	-- every widget the panel can show, by name, and what the column and the list show of them
	entries = {},
	entryByName = {},
	categories = {},
	rows = {},
	rowsGen = 0,
	localWidgetCount = 0,
	-- the action buttons along the bottom, rebuilt with the language
	buttons = {},
	-- names a window keeps off the list besides its own (what it takes the place of)
	-- Kept off the list. A window cannot list itself when toggling it off would take the list with it.
	hidden = { [widget:GetInfo().name] = true },
}

-- The colour each prefix group is marked with: a small square ahead of its label in the
-- column, and the same square ahead of the name on every row, so a list showing more than
-- one group says which group each widget is in. The hues are spread round the wheel at a
-- like lightness, and kept off the green, amber and red the row states are marked in.
look.groups = {
	interface = { 0.38, 0.62, 0.96, 1 },
	commands = { 0.96, 0.6, 0.24, 1 },
	units = { 0.3, 0.8, 0.68, 1 },
	camera = { 0.7, 0.52, 0.96, 1 },
	graphics = { 0.95, 0.5, 0.74, 1 },
	sound = { 0.92, 0.84, 0.36, 1 },
	map = { 0.62, 0.78, 0.3, 1 },
	minimap = { 0.36, 0.82, 0.94, 1 },
	api = { 0.74, 0.58, 0.44, 1 },
	debug = { 0.9, 0.4, 0.42, 1 },
	other = { 0.6, 0.6, 0.62, 1 },
}
-- The same colours as text colour codes, keyed by group, for naming a widget in a tooltip in the
-- colour of the group it is in. A component of 0 would end the string, so none goes below 1.
look.groupText = setmetatable({}, {
	__index = function(self, group)
		local c = look.groups[group] or look.groups.other
		local code = "\255"
		for i = 1, 3 do
			code = code .. string.char(mathMax(1, mathFloor(c[i] * 255 + 0.5)))
		end
		self[group] = code

		return code
	end,
})
-- A category the search found nothing in. It stays in the column, so the column does not
-- jump about under the typing, but it reads quieter than the ones holding matches.
look.emptyText = "\255\95\95\95"
-- The row tooltip's colours. Every line there is a label and what it labels, and one grey for both
-- made the lines a block to read through: the labels step back and the values come forward. The
-- names of other widgets get a colour of their own, being what a reader follows from one tooltip to
-- the next, and widgets that never check for what they use are in the warning colour, since those
-- are the ones that would break.
look.tip = {
	label = "\255\140\140\140",
	value = "\255\225\225\225",
	name = "\255\175\205\240",
	warn = "\255\235\195\125",
	-- Titles are left uncoloured, so the tooltip draws them in the green every tooltip heads with;
	-- a button that throws something away heads its tooltip in red instead, as its face is.
	danger = "\255\255\125\125",
}

-- The tags at the end of a row: whose file the widget is, and which UI it draws
-- through. One table rather than one local each - this chunk is at Lua's 200.
local tagColors = {
	islocal = "\255\130\175\230",
	isrml = "\255\200\150\235",
	iserror = "\255\255\120\120",
	-- The same, once the widget runs again: it still raised something, it is just not what is
	-- wrong with it now. Still red, so the tag reads as an error at a glance; softer, so the
	-- widgets actually broken stand out from the ones that recovered.
	iserrorSoft = "\255\220\150\150",
}

-- How the two cost columns read. Quiet while a widget is cheap and warm once it is not,
-- on the thresholds the profiler overlay marks a widget red at; `sample` is the widest
-- each column ever prints and what its width is measured from.
--
-- One table rather than eight locals, for the same reason `metrics` and `look` are
-- tables: this chunk is at Lua's ceiling of 200.
-- The colours gui_gameinfo lists source in, so stored settings read the same way there
-- and here. A kind with no entry falls back to plain text.
local codeColors = {
	comment = "\255\125\140\155",
	keyword = "\255\198\146\234",
	string = "\255\180\215\140",
	number = "\255\240\165\125",
	call = "\255\130\170\245",
	op = "\255\135\185\205",
	-- Commas, dots and brackets are most of any source; tinting them like the arithmetic
	-- turns the highlighting into noise, so they stay close to the plain text.
	punct = "\255\140\148\156",
	name = "\255\205\205\205",
}

local cost = {
	cool = "\255\140\140\140",
	warm = "\255\225\195\130",
	hot = "\255\255\150\110",
	cpuWarn = 0.5,
	cpuHot = 2,
	memWarn = 20,
	memHot = 100,
	sampleCpu = "99.9%",
	sampleMem = "9999k",
}

-- Filename prefixes, spelled out. Everything the game ships carries one; a widget with a
-- prefix that is not here - which is most of what a player writes - falls into Other, so
-- this list stays a curation of the game's own rather than a catch-all that grows a
-- category out of every typo.
local GROUPS = {

	gui = "interface",
	cmd = "commands",
	unit = "units",
	gfx = "graphics",
	camera = "camera",
	snd = "sound",
	map = "map",
	minimap = "minimap",
	api = "api",
	dbg = "debug",
}
-- The column's order, which is by what a player is most likely to be looking for rather
-- than by how many widgets each holds.
local GROUP_ORDER = {
	"interface",
	"commands",
	"units",
	"camera",
	"graphics",
	"sound",
	"map",
	"minimap",
	"api",
	"debug",
}
local OTHER = "other"

-- Which column a widget belongs in, from the prefix on its filename.
local function groupOf(data)
	local base = data.basename or ""
	local prefix = base:match("^(%a+)_")

	return (prefix and GROUPS[prefix]) or OTHER
end

-- The widgets a player has starred, and everything the star is drawn from. A category of
-- its own like the prefix groups, but chosen rather than read off a filename: what someone
-- reaches for often, kept a click away however the rest of the list is filtered.
--
-- Starring says nothing about whether a widget runs. It is a bookmark, not a switch, so
-- it survives the widget being turned off, a set being loaded over it, and a reload.
--
-- One table rather than a local each, and the draw and the toggle hang off it below the
-- way `sweep` and `sortBy` hang their functions off theirs: this chunk is at Lua's 200.
local fav = {
	-- name -> true. The category key the column and the row filter go by is the string
	-- below, alongside "changed" and "local", which are views of the list in the same way.
	names = {},
	key = "favorite",
	-- Dark enough that a column of unstarred rows reads as empty slots rather than as a
	-- column of icons, and it warms towards the starred colour under the cursor so the
	-- click says what it would do before it is made.
	off = { 0.4, 0.4, 0.42, 1 },
	offHover = { 0.85, 0.76, 0.4, 1 },
	on = { 1, 0.81, 0.24, 1 },
	-- Brighter but no paler: the row under a hovered star is lit too, and a wash of white
	-- gold on a lit row reads as the star stepping back rather than forward.
	onHover = { 1, 0.9, 0.4, 1 },
	-- How the star is drawn at rest and under the cursor: how much bigger it is, how far
	-- past it the soft pass under it reaches, how many bands that pass is built from, and
	-- what each band carries.
	--
	-- The size is what carries the model.hover. A star that is already yellow has hardly anywhere
	-- brighter to go - there is no headroom in the colour, and what there is competes with
	-- the row's own highlight - whereas a fifth again of the size reads at a glance whatever
	-- is behind it. The wider, stronger glow that comes with it is the rest of the signal.
	--
	-- The band at rest is not a hover cue at all: it is there to take the staircase off a
	-- shape made almost entirely of diagonal edges at this size.
	rest = { size = 1, spread = 0.16, bands = 1, alpha = 0.3 },
	lit = { size = 1.22, spread = 0.34, bands = 2, alpha = 0.28 },
}

-- The star as a triangle fan about its own centre: five outer points and five inner ones
-- on a unit circle, the last repeating the first to close the fan. Every point of a star
-- can be seen from its centre, so a fan draws it whole without tessellating anything.
-- Worked out here rather than written down as twenty-two numbers nobody could check.
function fav.shape(inner)
	local points = {}
	for i = 0, 10 do
		-- From straight up, a tenth of a turn at a time, alternating the two radii.
		local a = math.pi * (0.5 + i * 0.2)
		local r = (i % 2 == 0) and 1 or inner
		points[#points + 1] = math.cos(a) * r
		points[#points + 1] = math.sin(a) * r
	end

	return points
end

fav.points = fav.shape(0.47)

function fav.toggle(name)
	fav.names[name] = (not fav.names[name]) or nil
end

local L = {}
model.L = L
model.GROUPS, model.OTHER = GROUPS, OTHER
model.fav = fav
model.tagColors, model.codeColors, model.cost = tagColors, codeColors, cost

-- The header switches, right to left from the panel's edge. Each carries the rects it
-- was last laid out with, so adding one is an entry here rather than another pair of
-- locals threaded through the layout, the draw, the hover test and the press.
local switches = {
	{ key = "enabledOnly" },
	-- Beside it, the other switch that narrows the list rather than ordering it.
	{ key = "errorsOnly" },
	{ key = "byOrder" },
	{ key = "profiler" },
	-- Only offered while the column it orders by is showing. `sub` is what keeps it out
	-- of the header the rest of the time.
	{ key = "byLoad", sub = "profiler" },
}

model.switches = switches

local allowuserwidgets = true
-- What the header switches are set to, keyed the way they name themselves so a switch is
-- one entry in the list above and one field here.
--
-- `enabledOnly` keeps anything the config says
-- to load, whether or not it is running. `byOrder` sorts by where each widget sits in the
-- handler's list rather than by name, which is the only way the load order can be seen.
-- `errorsOnly` keeps the widgets that have raised an error this session - the rows tagged
-- error. Remembered like the rest, though the log it goes by starts again with every reload,
-- so it can come back to a shorter list than it left.
-- The switches, and one field that is not a switch. A reload tears every widget down and
-- builds it again, so a panel that does not say it was open comes back closed - which
-- reads as the button having switched the panel off rather than reloaded the UI.
-- `reopen` carries that across, and has two states rather than one because the panel
-- that asks and the panel that answers are different panels: `"asked"` is set on this
-- side of the reload and must survive every Update until the settings are taken, and
-- `"restore"` is what the fresh panel reads back and opens on, once. One flag with two
-- readings rather than two flags, and here rather than in a local of its own, because
-- this chunk is at Lua's ceiling of 200 - and because this is the table the saved
-- settings round-trip.
-- `profiler` starts on rather than off: what a widget costs is the thing this panel is
-- most often opened to find out, and a column nobody knows is there is a column nobody
-- switches on. It is the one switch here that is not free - see where it is restored.
local filters = { enabledOnly = false, errorsOnly = false, byOrder = false, profiler = true, byLoad = false }
model.filters = filters

-- Named sets of widgets. A set is the list of widgets that were enabled when it was
-- saved; applying one switches on everything in it and switches off everything else, so
-- a set describes a whole state rather than a patch to the current one.
--
-- Kept as an array so the picker's order is the order they were made in, which is stable
-- across sessions in a way that a hash's iteration order is not.
model.sets = {}
-- The set showing in the picker. Choosing one only picks it: loading, saving over and
-- deleting are each their own button, so picking a set to delete does not load it on the
-- way past.
---@type string?
model.pickedSet = nil

local rebuildRows

-- Which of the three states a widget is in: 1 running, 0.5 enabled but not running, 0
-- off. The same numbers FlowUI's switch takes, so the control in front of a row says the
-- state without translating it.
local function stateOf(name, data)
	if data.active then
		return 1
	end
	local order = widgetHandler.orderList[name]
	if order and order >= 1 then
		return 0.5
	end

	return 0
end

-- The rolling check for anything that changed behind the panel's back, and where it has
-- got to. One table rather than four locals, for the same reason `metrics` and `cost` are
-- tables: this chunk is at Lua's ceiling of 200. `moved` is filled in further down, once
-- there is a row layout for it to read.
-- `dirty` is set whenever this panel asks the handler for something. Those changes do
-- not have to be discovered by looking: the panel already knows it asked, and the answer
-- lands once the queued operation has run, which is before the next Update.
local sweep = { at = 1, order = 1, slice = 16, dirty = false, now = {}, was = {}, errorCount = 0 }

-- `now` and `was` are the other half of the same job: what the baked panel is painted
-- from this frame against what it was painted from last frame. Filled in place and never
-- replaced, so deciding whether to repaint costs nothing to collect either.

-- Whether the handler is holding anything this widget saved. An empty table is nothing
-- to clear: a widget with a GetConfigData that returns `{}` would otherwise offer a
-- button that does nothing.
function sweep.hasConfig(name)
	local d = widgetHandler.configData[name]

	return type(d) == "table" and next(d) ~= nil
end

-- What the widgets share with each other through WG, as barwidgets read it out of their sources
-- when they loaded: which widget provides a key, which widgets use it, and whether they check it
-- is there first. A table rather than a local per function, for the reason `sweep` is one. The
-- reading is a static one, so everything said with it says "uses" rather than "requires".
local deps = {}

-- Rebuilt with the entries: key -> the names of the widgets that assign it, sorted, so a key two
-- widgets both provide reads the same way every time.
function deps.rebuild()
	local providers = {}
	for name, data in pairs(widgetHandler.knownWidgets) do
		if data.deps then
			for key in pairs(data.deps.provides) do
				local list = providers[key]
				if not list then
					list = {}
					providers[key] = list
				end
				list[#list + 1] = name
			end
		end
	end
	for _, list in pairs(providers) do
		table.sort(list)
	end
	deps.providers = providers
end

function deps.keys(set)
	local out = {}
	for key in pairs(set) do
		out[#out + 1] = key
	end
	table.sort(out)

	return out
end

-- The running widget providing a key, if one is: nil when nothing known provides it at all, false
-- when something does and none of them is running.
function deps.provider(key)
	local list = deps.providers and deps.providers[key]
	if not list then
		return nil
	end
	local known = widgetHandler.knownWidgets
	for i = 1, #list do
		if known[list[i]] and known[list[i]].active then
			return list[i]
		end
	end

	return false
end

-- The running widgets that use a key `name` provides, and those of them that never check it is
-- there. With `sole`, only keys no other running widget provides as well: what switching `name`
-- off would actually take away from them.
function deps.users(name, sole)
	local known = widgetHandler.knownWidgets
	local own = known[name] and known[name].deps
	local users, unchecked = {}, {}
	if not (own and deps.providers) then
		return users, unchecked
	end
	local keys = {}
	for key in pairs(own.provides) do
		local alone = true
		if sole then
			for _, other in ipairs(deps.providers[key] or {}) do
				if other ~= name and known[other] and known[other].active then
					alone = false
				end
			end
		end
		if alone then
			keys[#keys + 1] = key
		end
	end
	if #keys == 0 then
		return users, unchecked
	end
	for other, data in pairs(known) do
		if other ~= name and data.active and data.deps then
			local uses, blind = false, false
			for i = 1, #keys do
				if data.deps.uses[keys[i]] then
					uses = true
					blind = blind or not data.deps.guards[keys[i]]
				end
			end
			if uses then
				users[#users + 1] = other
				if blind then
					unchecked[#unchecked + 1] = other
				end
			end
		end
	end
	table.sort(users)
	table.sort(unchecked)

	return users, unchecked
end

-- A widget's name in the colour of the group it is in, the one its square carries in the list.
function deps.colored(name)
	local data = widgetHandler.knownWidgets[name]

	return look.groupText[data and groupOf(data) or OTHER] .. name
end

-- A list of names cut to `limit`, with a count of the rest.
function deps.names(list, limit, sep)
	local shown = {}
	for i = 1, math.min(#list, limit) do
		shown[i] = list[i]
	end

	-- Given a colour for the separators, the entries carry colours of their own.
	sep = sep or ""

	return table.concat(shown, sep .. ", ") .. (#list > limit and (sep .. "  +" .. (#list - limit)) or "")
end

-- The dependency lines of a row's tooltip, each ending in a newline, or "". What the widget uses,
-- by the widget providing it, with anything switched off marked - red where the widget never
-- checks for it, quiet where it does. And, for a widget others use, how many running ones do.
function deps.tooltip(row, maxWidth)
	local own = row.data.deps
	if not (own and deps.providers) then
		return ""
	end
	local tip = look.tip
	local out = ""

	local names, state = {}, {}
	for _, key in ipairs(deps.keys(own.uses)) do
		local running = deps.provider(key)
		if running ~= nil then
			local shown = running or deps.providers[key][1]
			if shown ~= row.name then
				if not state[shown] then
					names[#names + 1] = shown
					state[shown] = "on"
				end
				if running == false then
					state[shown] = (state[shown] == "blind" or not own.guards[key]) and "blind" or "off"
				end
			end
		end
	end
	if #names > 0 then
		-- What is off first: that is what the line is there to say.
		local rank = { blind = 1, off = 2, on = 3 }
		table.sort(names, function(a, b)
			if rank[state[a]] ~= rank[state[b]] then
				return rank[state[a]] < rank[state[b]]
			end

			return a < b
		end)
		local parts = {}
		-- Each name in its group's colour; what is off says so after it, red where the widget
		-- never checks for it, quiet where it does.
		for i, name in ipairs(names) do
			if state[name] == "blind" then
				parts[i] = deps.colored(name) .. tagColors.iserror .. " (" .. L.depsOff .. ")"
			elseif state[name] == "off" then
				parts[i] = deps.colored(name) .. "\255\130\130\130" .. " (" .. L.depsOff .. ")"
			else
				parts[i] = deps.colored(name)
			end
		end
		local line = tip.label .. L.depsUses .. ":  " .. deps.names(parts, 8, tip.label)
		out = out .. text.carryColors(model.font:WrapText(line, maxWidth)) .. "\n"
	end

	local users, unchecked = deps.users(row.name, false)
	if #users > 0 then
		-- The ones that never check first, since those are the ones that would break.
		local blind = {}
		for _, name in ipairs(unchecked) do
			blind[name] = true
		end
		table.sort(users, function(a, b)
			if (blind[a] or false) ~= (blind[b] or false) then
				return blind[a] == true
			end

			return a < b
		end)
		local line = tip.label
			.. L.depsUsedBy
			.. ":  "
			.. tip.value
			.. #users
			.. tip.label
			.. " "
			.. (#users == 1 and L.depsRunningOne or L.depsRunning)
		if #unchecked > 0 then
			line = line .. " (" .. tip.warn .. #unchecked .. " " .. L.depsUnchecked .. tip.label .. ")"
		end
		local parts = {}
		-- In their groups' colours too, so the ones that never check are marked after the name.
		for i, name in ipairs(users) do
			parts[i] = deps.colored(name) .. (blind[name] and (tip.warn .. " !") or "")
		end
		line = line .. " - " .. deps.names(parts, 3, tip.label)
		out = out .. text.carryColors(model.font:WrapText(line, maxWidth)) .. "\n"
	end

	return out
end

-- For a widget that has raised errors: the things it uses that are switched off, where that is a
-- likely reason - it never checks the key is there, or one of its errors names the key.
function deps.causes(row)
	local own = row.data.deps
	if not (own and row.errors and deps.providers) then
		return ""
	end
	local out = ""
	for _, key in ipairs(deps.keys(own.uses)) do
		if deps.provider(key) == false then
			local named = false
			for _, e in ipairs(row.errors.entries) do
				local message = tostring(e.message)
				named = named
					or string.find(message, "'" .. key .. "'", 1, true) ~= nil
					or string.find(message, "WG." .. key, 1, true) ~= nil
			end
			if named or not own.guards[key] then
				local what, provider = "WG." .. key, deps.providers[key][1]
				-- Looked up with both values in hand: i18n fills placeholders at lookup. The gsubs
				-- cover the fallback, which comes back untouched.
				local text = BAR.I18N(
					"ui.widgetselector.depscause",
					{ key = what, provider = provider, default = L.depsCauseFallback }
				)
				text = string.gsub(text, "%%{key}", function()
					return what
				end)
				text = string.gsub(text, "%%{provider}", function()
					return provider
				end)
				out = out .. tagColors.iserrorSoft .. text .. "\n"
			end
		end
	end

	return out
end

-- What the switch-off warning says: how many running widgets use what `name` provides without
-- checking, and which.
function deps.warning(name, unchecked)
	local count = #unchecked
	local text = BAR.I18N(
		"ui.widgetselector." .. (count == 1 and "depswarnone" or "depswarn"),
		{ name = name, count = count, default = count == 1 and L.depsWarnOneFallback or L.depsWarnFallback }
	)
	text = string.gsub(text, "%%{name}", function()
		return name
	end)
	text = string.gsub(text, "%%{count}", function()
		return tostring(count)
	end)

	return text .. "  " .. deps.names(unchecked, 6)
end

-- What barwidgets has kept of a widget's errors this session, if there are any. Keyed by
-- file, since most of the ways loading can fail happen before a widget has a name.
function sweep.errors(data)
	local logs = widgetHandler.errorLog
	local log = logs and data.basename and logs[data.basename]

	return (log and log.entries[1]) and log or nil
end

-- One line of description, with the newlines a multi-line one carries turned into spaces:
-- this sits on the row beside the name, and the tooltip is where the whole thing lives.
local function oneLine(str)
	if not str or str == "" then
		return ""
	end
	str = string.gsub(str, "%s+", " ")

	return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
end

-- Walks what the handler knows and builds the rows from it. Called when the handler says
-- its list changed, which covers a widget being toggled, loaded or removed.
-- Walks what the handler knows and builds the rows from it. Called when the handler says
-- its list changed, which covers a widget being toggled, loaded or removed.
local function buildEntries()
	-- The handler's error count as these rows see it. contentMoved rebuilds when it moves.
	sweep.errorCount = widgetHandler.errorCount or 0
	-- Who provides what, for the tooltip lines and the switch-off warning.
	deps.rebuild()
	model.entries = {}
	model.entryByName = {}
	model.localWidgetCount = 0

	-- Where each running widget sits in the handler's list. That index is the load order:
	-- SaveConfigData writes it out as orderList[name], and it is the order the call-ins
	-- run in. A widget that is not running has no place in it.
	local order, layer = {}, {}
	for i = 1, #widgetHandler.widgets do
		local w = widgetHandler.widgets[i]
		if w.whInfo then
			order[w.whInfo.name] = i
			layer[w.whInfo.name] = w.whInfo.layer
		end
	end

	for name, data in pairs(widgetHandler.knownWidgets) do
		-- The def exporter is a build tool rather than something to switch on in a game.
		if name ~= "Write customparam.__def to files" and not data.hidden and not model.hidden[name] then
			local desc = oneLine(data.desc)
			local log = sweep.errors(data)
			model.entries[#model.entries + 1] = {
				name = name,
				data = data,
				group = groupOf(data),
				state = stateOf(name, data),
				hasConfig = sweep.hasConfig(name),
				order = order[name],
				layer = layer[name],
				desc = desc,
				isLocal = not data.fromZip,
				-- Whether it draws through RmlUi, which barwidgets reads out of the source at load:
				-- where the file sits does not answer it, since a player's own RmlUi widget can live
				-- anywhere. Worth saying on the row, and said alongside `local` rather than instead
				-- of it - a widget can be both.
				isRml = data.rml == true or (data.filename or ""):find("RmlWidgets", 1, true) ~= nil,
				-- Switched to something other than what it ships as. `enabled` is what the GetInfo
				-- block asked for, which barwidgets keeps for every widget it has ever seen.
				changed = (stateOf(name, data) > 0) ~= (data.enabled == true),
				-- Everything it has raised this session. Until barwidgets kept these the panel could
				-- say a widget was asked for and is not running, and nothing about why: the reason
				-- was in infolog.txt and nowhere else.
				errors = log,
				-- And the error that is why it is not running, while it is not. A widget running
				-- again says nothing about whatever stopped it last time.
				stoppedBy = log and log.stopped and not data.active and log.stopped.message or nil,
				-- Lowercased once here rather than per keystroke: a search walks every one of
				-- these on every letter typed.
				searchName = string.lower(name),
				searchDesc = string.lower(desc),
				searchFile = string.lower(data.basename or ""),
				searchAuthor = string.lower(data.author or ""),
			}
			model.entryByName[name] = model.entries[#model.entries]
			if not data.fromZip then
				model.localWidgetCount = model.localWidgetCount + 1
			end
		end
	end
end

-- The column: All, then the game's own prefixes in a fixed order, then Other. A category
-- with nothing in it is left out rather than shown empty.
--
-- The counts follow the switches that narrow the list, so each one says what clicking it
-- would show. They do not follow the search: that is transient, and a column of numbers
-- flickering on every letter typed is noise rather than information.
local function buildCategories()
	local counts, active, total, on = {}, {}, 0, 0
	local changed, changedOn = 0, 0
	local mine, mineOn = 0, 0
	local rml, rmlOn = 0, 0
	local starred, starredOn = 0, 0
	for i = 1, #model.entries do
		local e = model.entries[i]
		-- The loop covers every index, so this cannot be nil.
		---@cast e -?
		if (not filters.enabledOnly or e.state > 0) and (not filters.errorsOnly or e.errors) then
			counts[e.group] = (counts[e.group] or 0) + 1
			total = total + 1
			if e.data.active then
				active[e.group] = (active[e.group] or 0) + 1
				on = on + 1
			end
			if e.changed then
				changed = changed + 1
				if e.data.active then
					changedOn = changedOn + 1
				end
			end
			if e.isLocal then
				mine = mine + 1
				if e.data.active then
					mineOn = mineOn + 1
				end
			end
			if e.isRml then
				rml = rml + 1
				if e.data.active then
					rmlOn = rmlOn + 1
				end
			end
			if fav.names[e.name] then
				starred = starred + 1
				if e.data.active then
					starredOn = starredOn + 1
				end
			end
		end
	end

	model.categories = { { key = nil, label = L.all, count = total, active = on } }
	-- The starred ones, at the head of the column under All: whatever someone stars is what
	-- they open this panel for, so it is the shortest way back to it. Like the two views
	-- below it, it cuts across the prefix groups rather than being one of them - and like
	-- them it is left out entirely while there is nothing in it.
	if starred > 0 then
		model.categories[#model.categories + 1] =
			{ key = fav.key, label = L.favorites, count = starred, active = starredOn }
	end
	-- Everything switched to something other than what it ships as: what this game has
	-- been customised into, which is the question the panel is usually opened with. It
	-- sits at the head of the column rather than as a sixth header switch, which is more
	-- than the header holds at 1280 - and it is a view of the whole list rather than a
	-- filter on one part of it, so it belongs with All.
	if changed > 0 then
		model.categories[#model.categories + 1] =
			{ key = "changed", label = L.changed, count = changed, active = changedOn }
	end
	-- The player's own files, which was a header switch until the column turned out to be
	-- the better home for it: it is a view of the whole list like the two above it, and
	-- the header had no room to spare.
	if mine > 0 then
		model.categories[#model.categories + 1] = { key = "local", label = L.mine, count = mine, active = mineOn }
	end
	-- The widgets that build their interface through RmlUi rather than drawing it the way
	-- the rest of the list does. The same kind of view as Your own, and matched the same way
	-- the tag on the row is: whether the source uses the API, not where the file sits, since
	-- a player's own can live anywhere. It carries no colour for the same reason Your own
	-- does not - an RmlUi widget still has a prefix, and the colour ahead of it on the row
	-- is its group's.
	if rml > 0 then
		model.categories[#model.categories + 1] = { key = "rml", label = L.rmlui, count = rml, active = rmlOn }
	end
	for _, g in ipairs(GROUP_ORDER) do
		if counts[g] then
			model.categories[#model.categories + 1] =
				{ key = g, label = L[g] or g, count = counts[g], active = active[g] or 0 }
		end
	end
	if counts[OTHER] then
		model.categories[#model.categories + 1] =
			{ key = OTHER, label = L.other, count = counts[OTHER], active = active[OTHER] or 0 }
	end

	-- Fewer categories than before can leave the column scrolled past its own end.
	model.onCategoriesBuilt()

	-- A category the filter emptied cannot stay selected, or the list shows nothing with
	-- no way back to it.
	if model.selectedCategory then
		local found
		for _, c in ipairs(model.categories) do
			if c.key == model.selectedCategory then
				found = true
			end
		end
		if not found then
			model.selectedCategory = nil
		end
	end
end

local function buildContent()
	buildEntries()
	buildCategories()
end

-- By where they load, when the switch asks for it: what runs first is what draws first
-- and gets the call-ins first, and reading it off the list is the only way to see it.
-- Anything not running has no place in that order, so it follows, alphabetically.
-- The orderings the list can be in. One table rather than four locals: this chunk is at
-- Lua's ceiling of 200, and they belong together anyway.
local sortBy = {}

function sortBy.order(a, b)
	if a.order and b.order then
		return a.order < b.order
	end
	if a.order or b.order then
		return a.order ~= nil
	end

	return a.name < b.name
end

-- Mod widgets first and then the player's own, each alphabetical, with the profiler on
-- top: it is the one a player opens this panel to reach in a hurry.
function sortBy.name(a, b)
	if a.name == "Widget Profiler" then
		return true
	elseif b.name == "Widget Profiler" then
		return false
	end
	if a.isLocal ~= b.isLocal then
		return b.isLocal
	end

	return a.name < b.name
end

-- Heaviest first, on exactly the figure the row shows. Ordering on some other average of
-- the same widget puts a row reading 0.4% above one reading 2.0%, and a list a reader
-- cannot check is worse than no order at all. What keeps it from reshuffling under the
-- cursor is the hold in Update, not a slower number.
--
-- Anything not running has nothing measured and sorts to the bottom.
function sortBy.cost(a, b)
	local sa = profiling.stats[a.name]
	local sb = profiling.stats[b.name]
	if sa and sb then
		if sa.load ~= sb.load then
			return sa.load > sb.load
		end
		return a.name < b.name
	end
	if sa or sb then
		return sa ~= nil
	end

	return a.name < b.name
end

function sortBy.pick()
	if filters.byLoad and filters.profiler then
		return sortBy.cost
	end

	return filters.byOrder and sortBy.order or sortBy.name
end

-- The rows the list shows: what the column, the search box and the filter switches left.
-- A search ranks what it finds, so the closest answer is at the top; with no search the
-- authored order stands, since a list that reshuffles as it is read loses the reader.
rebuildRows = function()
	model.rows = {}
	model.rowsGen = model.rowsGen + 1

	local query = Search.query(model.searchText())
	-- Filled once and rewritten per widget rather than allocated for each of them.
	local primary, secondary = { "" }, { "", "", "" }
	local scored = not query.empty and {} or nil
	-- While something is typed, the column counts what each category would show with it, so its
	-- numbers say where the matches are rather than how much there is in all. That takes scoring
	-- every widget the switches leave, not only the selected category's. The categories stay
	-- put, empty or not, so the column does not jump about under the typing.
	local found
	if scored then
		found = {}
		for _, c in ipairs(model.categories) do
			c.found, c.foundOn = 0, 0
			if c.key then
				found[c.key] = c
			end
		end
	end
	local function add(c, on)
		if c then
			c.found = c.found + 1
			if on then
				c.foundOn = c.foundOn + 1
			end
		end
	end

	for i = 1, #model.entries do
		local e = model.entries[i]
		-- The loop covers every index, so this cannot be nil.
		---@cast e -?
		if (not filters.enabledOnly or e.state > 0) and (not filters.errorsOnly or e.errors) then
			-- `favorite`, `changed`, `local` and `rml` are views of the whole list rather than
			-- filename prefixes, so each is matched on what it means instead of on the group.
			local inView = not model.selectedCategory
				or (model.selectedCategory == fav.key and fav.names[e.name])
				or (model.selectedCategory == "changed" and e.changed)
				or (model.selectedCategory == "local" and e.isLocal)
				or (model.selectedCategory == "rml" and e.isRml)
				or e.group == model.selectedCategory
			if not scored then
				if inView then
					model.rows[#model.rows + 1] = e
				end
			else
				primary[1] = e.searchName
				secondary[1], secondary[2], secondary[3] = e.searchDesc, e.searchFile, e.searchAuthor
				-- Named by its name alone: a widget found only through its description or author
				-- is a guess, and a list of guesses is worse than a short list.
				local score = Search.score(query, primary, secondary)
				if score > 0 then
					if inView then
						scored[#scored + 1] = { e = e, score = score }
					end
					local on = e.data.active
					-- Only ever reached with something typed, which is what filled it above.
					---@cast found -?
					add(model.categories[1], on)
					add(found[e.group], on)
					add(fav.names[e.name] and found[fav.key], on)
					add(e.changed and found.changed, on)
					add(e.isLocal and found["local"], on)
					add(e.isRml and found.rml, on)
				end
			end
		end
	end

	-- What the column prints for each category: what is on out of what there is - the count of
	-- enabled widgets is the thing worth knowing at a glance, the total is what says how much
	-- there is to look through - or, while something is typed, the same of what it finds. Only
	-- redone where the numbers moved.
	for _, c in ipairs(model.categories) do
		local n, on = c.count, c.active
		if found then
			n, on = c.found, c.foundOn
		end
		if c.shown ~= n or c.shownOn ~= on then
			c.shown, c.shownOn = n, on
			c.empty = n == 0
			c.countText = (c.empty and look.emptyText or colorDim) .. on .. "/" .. n
		end
	end

	if scored then
		table.sort(scored, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end

			return sortBy.pick()(a.e, b.e)
		end)
		for i = 1, #scored do
			model.rows[i] = scored[i].e
		end
	else
		table.sort(model.rows, sortBy.pick())
	end
end

model.rebuildRows = rebuildRows
model.buildCategories = buildCategories
model.deps = deps
model.sweep = sweep

-- What is switched on right now, as a set. Anything the config says to load counts,
-- running or not: a widget that failed to load this session is still part of what the
-- player asked for, and dropping it here would quietly lose it from the set.
local function currentSet()
	local names = {}
	for i = 1, #model.entries do
		local e = model.entries[i]
		-- The loop covers every index, so this cannot be nil.
		---@cast e -?
		if e.state > 0 then
			names[e.name] = true
		end
	end

	return names
end

local function findSet(name)
	for i = 1, #model.sets do
		if model.sets[i].name == name then
			return model.sets[i], i
		end
	end
end

-- Switches the widgets to match the set: everything in it on, everything else off. Both
-- halves matter - a set that only turned things on would drift further from what it
-- described every time it was applied.
local function applySet(name)
	local set = findSet(name)
	if not set then
		return
	end

	for i = 1, #model.entries do
		local e = model.entries[i]
		-- The loop covers every index, so this cannot be nil.
		---@cast e -?
		local want = set.widgets[e.name] == true
		if want and e.state == 0 then
			widgetHandler:EnableWidget(e.name)
			sweep.dirty = true
		elseif not want and e.state > 0 then
			widgetHandler:DisableWidget(e.name)
			sweep.dirty = true
		end
	end
end

-- Saves what is on now under a name, replacing a set of that name if there is one.
local function saveSet(name)
	name = name and name:gsub("^%s*(.-)%s*$", "%1") or ""
	if name == "" then
		return
	end

	local set = findSet(name)
	if set then
		set.widgets = currentSet()
	else
		model.sets[#model.sets + 1] = { name = name, widgets = currentSet() }
	end
	model.pickedSet = name
	widgetHandler:SaveConfigData()
	model.onSetsChanged()
end

local function deleteSet(name)
	local _, i = findSet(name)
	if not i then
		return
	end
	table.remove(model.sets, i)
	if model.pickedSet == name then
		model.pickedSet = nil
	end
	widgetHandler:SaveConfigData()
	model.onSetsChanged()
end

local function reloadLuaUI()
	-- Before the command, not after: the handler's Shutdown asks every widget for its
	-- settings on the way out, and that is what carries this across.
	filters.reopen = "asked"
	spSendCommands("luarules reloadluaui")
end

local function toggleUserWidgets()
	if widgetHandler.allowUserWidgets then
		widgetHandler.__allowUserWidgets = false
		spEcho("Disallowed user widgets, reloading...")
	else
		widgetHandler.__allowUserWidgets = true
		spEcho("Allowed user widgets, reloading...")
	end
	reloadLuaUI()
end

-- Back to the set of widgets the game enables by default, keeping what each of them has
-- saved.
--
-- Not `luaui reset`: there is no such command - ConfigureLayout has no branch for it and
-- never had, so this button has quietly done nothing since long before this panel was
-- rewritten. The handler drops the load order on the way out instead, the same way
-- Factory defaults drops the whole config.
local function resetLuaUI()
	widgetHandler.__blankOutOrder = true
	reloadLuaUI()
end

local function factoryReset()
	widgetHandler.__blankOutConfig = true
	reloadLuaUI()
end
-- Waiting on the handler to actually let go of a widget. Enable and Disable are queued
-- and run after the callin that asked has returned, so the clear cannot happen on the
-- click itself; Update picks this up on the next frame, by which time the widget is gone.
local pendingClear

-- Drops what the handler has saved under a widget's name.
--
-- A running widget hands its settings back the instant it is removed, and SaveConfigData
-- asks every running widget for them again, so clearing one on the spot writes itself
-- straight back. The only way it sticks is with the widget already gone: switch it off,
-- drop the entry, switch it on, and it loads with nothing to read.
local function clearConfigData(name)
	local known = widgetHandler.knownWidgets[name]
	if known and known.active then
		widgetHandler:DisableWidget(name)
		sweep.dirty = true
		pendingClear = { name = name, restart = true }

		return
	end

	widgetHandler.configData[name] = nil
	widgetHandler:SaveConfigData()
	model.refreshContent()
end

model.applySet, model.saveSet, model.deleteSet = applySet, saveSet, deleteSet
model.factoryReset, model.toggleUserWidgets = factoryReset, toggleUserWidgets
model.clearConfigData = clearConfigData

-- What the wrapper's OwnText/DisownText do, against the real handler's own field.
local function ownText()
	if widgetHandler.textOwner then
		return widgetHandler.textOwner == widget
	end
	widgetHandler.textOwner = widget

	return true
end

local function disownText()
	if widgetHandler.textOwner == widget then
		widgetHandler.textOwner = nil
	end
end

-- What a widget has actually saved, shown as the Lua it is stored as.
--
-- The same lexer gui_gameinfo lists tweakdefs through, so stored settings read the way
-- source does everywhere else in the UI. The line breaks are this file's own: the formatter
-- breaks on statements and blocks, and a table constructor is neither, so a config of any
-- size would come back as one very long line. Each line is handed to it separately for the
-- colours, which is all that is wanted from it here.
--
-- One table rather than a function and half a dozen state locals, for the reason every
-- other table in this file is one: the chunk is at Lua's ceiling of 200.
-- `indentChars` is how far one level of nesting steps in, in characters: the listing is
-- drawn in a monospaced face, so everything about its layout is arithmetic on that.
-- `previewLines` and `previewChars` are how much of it the Show data button's tooltip shows.
local dataView =
	{ scroll = 0, lines = {}, rows = {}, rect = {}, close = {}, indentChars = 4, previewLines = 15, previewChars = 72 }

-- The same lexer gui_gameinfo lists tweakdefs through. Optional, and kept on the table
-- rather than in a local of its own: a /luaui reload runs without a file that was added
-- since the game started, and a viewer without colours beats a panel that will not load.
do
	local ok, mod = pcall(VFS.Include, "luaui/Include/lua_source.lua")
	dataView.source = ok and mod or nil
end

-- Strings before numbers and each in order, so the same settings read the same way twice.
function dataView.keys(t)
	local out = {}
	for k in pairs(t) do
		out[#out + 1] = k
	end
	table.sort(out, function(a, b)
		local ta, tb = type(a), type(b)
		if ta ~= tb then
			return ta == "string"
		end
		if ta == "string" or ta == "number" then
			return a < b
		end

		return tostring(a) < tostring(b)
	end)

	return out
end

-- A key as it would be written: a plain name bare, anything else in brackets.
function dataView.key(k)
	if type(k) == "string" and string.find(k, "^[%a_][%w_]*$") then
		return k
	end
	if type(k) == "string" then
		return "[" .. dataView.quote(k) .. "]"
	end

	return "[" .. tostring(k) .. "]"
end

-- A string as it would be written, on one line.
--
-- Not string.format("%q"): that escapes a newline as a backslash followed by a real one,
-- which is valid Lua but ends the line here - and a setting holding a few lines of text
-- then draws all of them on top of each other.
function dataView.quote(v)
	local out = string.gsub(v, '[\\"]', "\\%0")
	out = string.gsub(out, "\n", "\\n")
	out = string.gsub(out, "\r", "\\r")
	out = string.gsub(out, "\t", "\\t")
	-- Anything else unprintable goes by its number, the way Lua writes it.
	out = string.gsub(out, "%c", function(c)
		return string.format("\\%d", string.byte(c))
	end)

	return '"' .. out .. '"'
end
function dataView.value(v)
	local t = type(v)
	if t == "string" then
		return dataView.quote(v)
	end
	if t == "number" or t == "boolean" then
		return tostring(v)
	end

	-- A function or a userdata cannot be written back out, so it is said rather than shown.
	return "<" .. t .. ">"
end

-- Appends one line, lexed for its colours. Anything the lexer cannot read is kept as plain
-- text: this is a viewer, and half a reading beats an error.
function dataView.emit(depth, text)
	local parts
	if dataView.source then
		local ok, lines = pcall(dataView.source.format, text)
		if ok and lines[1] then
			parts = lines[1].parts
		end
	end
	dataView.lines[#dataView.lines + 1] = { depth = depth, parts = parts or { { s = text, k = "name" } } }
end

function dataView.write(value, depth, prefix)
	if type(value) ~= "table" then
		dataView.emit(depth, prefix .. dataView.value(value) .. ",")

		return
	end
	if not next(value) then
		dataView.emit(depth, prefix .. "{},")

		return
	end
	dataView.emit(depth, prefix .. "{")
	for _, k in ipairs(dataView.keys(value)) do
		dataView.write(value[k], depth + 1, dataView.key(k) .. " = ")
	end
	dataView.emit(depth, "},")
end

-- What a widget has saved, as the listing's lines - none with nothing saved - written as the chunk
-- it is stored as, so what is on screen is what is on disk. Built in dataView.lines, where emit
-- writes, and handed back with what was there put back: the Show data tooltip reads it while the
-- window is shut, and must leave nothing behind in it.
function dataView.listing(name)
	local keep = dataView.lines
	dataView.lines = {}
	local data = widgetHandler.configData[name]
	if type(data) == "table" then
		dataView.emit(0, "return {")
		for _, k in ipairs(dataView.keys(data)) do
			dataView.write(data[k], 1, dataView.key(k) .. " = ")
		end
		dataView.emit(0, "}")
	end
	local lines = dataView.lines
	dataView.lines = keep

	return lines
end

function dataView.open(name)
	dataView.name = name
	dataView.scroll = 0
	dataView.rows = {}
	-- The flow is keyed on the width and the widget; the settings themselves can have
	-- changed under both, so opening always flows again.
	dataView.wrappedFor = nil
	dataView.lines = dataView.listing(name)
end

-- The Show data button's tooltip: what the widget has saved, as the first lines of the listing the
-- button opens, in its colours. A tooltip is one line after another in a proportional face, so
-- nesting is shown with spaces rather than lined up, and a long line is cut rather than flowed - the
-- window is there for reading all of it.
function dataView.preview(name, maxWidth)
	local lines = dataView.listing(name)
	local out = text.carryColors("\255\255\255\255" .. model.font:WrapText(L.showdataDesc, maxWidth)) .. "\n"
	for i = 1, math.min(#lines, dataView.previewLines) do
		local line = lines[i]
		local row, room = "", dataView.previewChars
		for j, part in ipairs(line.parts) do
			local piece = part.s
			if #piece > room then
				-- Cut between characters, not inside one: a saved string can hold anything.
				local cut = room
				while
					cut > 0
					and (string.byte(piece, cut + 1) or 0) >= 128
					and (string.byte(piece, cut + 1) or 0) < 192
				do
					cut = cut - 1
				end
				piece = string.sub(piece, 1, cut) .. ".."
			end
			-- The colour ahead of the indent, so the line says its colour before anything is on it.
			row = row
				.. (codeColors[part.k] or codeColors.name)
				.. (j == 1 and string.rep(" ", line.depth * 3) or "")
				.. piece
			room = room - #part.s
			if room <= 0 then
				break
			end
		end
		out = out .. row .. "\n"
	end
	if #lines > dataView.previewLines then
		out = out .. look.tip.label .. "+" .. (#lines - dataView.previewLines) .. " " .. L.errorsMore .. "\n"
	end

	-- Without the last line break, which a tooltip would draw as an empty line under the rest.
	return (string.gsub(out, "\n$", ""))
end

function dataView.shut()
	dataView.name = nil
	dataView.lines = {}
end

-- Flows the stored lines into the width there is, keeping each token's kind so a line that
-- had to be broken is still coloured. A wrapped line carries on one indent further in, so
-- it reads as a continuation rather than as the next setting.
function dataView.wrap()
	local flowed = {}
	dataView.rows = flowed

	for _, line in ipairs(dataView.lines) do
		local indent = line.depth * dataView.indentChars
		local room = mathMax(8, dataView.chars - indent)
		local parts, used = {}, 0

		local function flush(depth)
			flowed[#flowed + 1] = { indent = depth, parts = parts }
			parts, used = {}, 0
		end

		for _, part in ipairs(line.parts) do
			local text = part.s
			while text ~= "" do
				local left = room - used
				if #text <= left then
					parts[#parts + 1] = { s = text, k = part.k }
					used = used + #text
					break
				end
				-- Break at the last space that fits, so words survive; if there is no space
				-- to break at - a long string or path - it is cut where the room runs out,
				-- which is still better than running off the edge.
				local cut = left
				for i = left, 1, -1 do
					if string.sub(text, i, i) == " " then
						cut = i
						break
					end
				end
				if cut < 1 or (used == 0 and cut < 1) then
					cut = left
				end
				if cut > 0 then
					parts[#parts + 1] = { s = string.sub(text, 1, cut), k = part.k }
				end
				text = string.sub(text, cut + 1)
				flush(indent)
				-- Continuations sit one step further in, and get that step back in room.
				indent = line.depth * dataView.indentChars + dataView.indentChars
				room = mathMax(8, dataView.chars - indent)
			end
		end
		if #parts > 0 then
			flush(indent)
		end
	end
end

function dataView.maxScroll()
	local over = #(dataView.rows or {}) - dataView.page

	return over > 0 and over or 0
end

function dataView.setScroll(v)
	local max = dataView.maxScroll()
	dataView.scroll = (v < 0 and 0) or (v > max and max) or v
end

model.dataView = dataView

-- Turns the measurement on and off with the column that shows it. Subscribing is what puts
-- the wrappers into every widget's callins, so a player who never opens this column never
-- pays for it; unsubscribing takes them out again, unless the profiler widget is also up.
local function applyProfiling()
	if filters.profiler then
		-- A third as often as the profiler panel asks for. The sweep that turns the raw
		-- counters into averages walks every widget and all of its callins, and a column being
		-- glanced at down a list does not need it ten times a second - three is still quicker
		-- than anyone reads a number, and the figures are smoothed over two seconds anyway, so
		-- nothing is lost between samples. With the profiler panel up as well its faster rate
		-- wins and both are satisfied.
		profiling.subscribe(widget, 0.3)
	else
		profiling.unsubscribe(widget)
		-- Nothing left to order by, so the sub-switch goes with it rather than sitting on
		-- with a list it can no longer arrange.
		filters.byLoad = false
	end
end

model.applyProfiling = applyProfiling

function model.buttonAction(id)
	if id == "reload" then
		reloadLuaUI()

	elseif id == "userwidgets" then
		-- No confirmation. Nothing is thrown away either way, the same button puts it
		-- straight back, and the panel returns after the reload; the wording that used to
		-- be the question is still on the tooltip, where it is read before the press.
		toggleUserWidgets()
	elseif id == "reset" then
		model.confirm(L.reset, L.resetWarn, resetLuaUI, true)
	elseif id == "factory" then
		model.confirm(L.factoryDefaults, L.factoryWarn, factoryReset, true)
	end
end

-- Has anything been switched on or off since the rows were built?
--
-- Asking is what it takes. The handler queues Toggle, Enable and Disable and runs them
-- once the callin that asked has returned, so the state cannot be read back on the click
-- itself; and a widget can be switched from somewhere else entirely - the settings panel,
-- a /luaui command, one erroring out on load - which nothing here would otherwise hear
-- about. `knownChanged` does not cover it: the handler raises that only when a widget it
-- has never seen registers.
--
-- Asking about all three hundred of them every frame, though, made this panel one of the
-- most expensive widgets in the game while it was open - it was ninety per cent of what
-- the panel cost. So the sweep is spread. The rows actually on screen are checked every
-- frame, because those are the ones being looked at and a click has to show in the row it
-- landed on; the rest of the list and the load order are swept a slice at a time, which
-- finds a widget switched from somewhere else within about a fifth of a second instead of
-- within a frame. Nothing this panel does itself waits on that - `dirty` answers those
-- outright - and doubling the slice to halve that wait costs a third more for a delay
-- nobody can see.
-- Nobody can see the difference, and it is several times cheaper.
function sweep.moved(e)
	return e.state ~= stateOf(e.name, e.data) or e.hasConfig ~= sweep.hasConfig(e.name)
end

function model.contentMoved(first, page)
	-- Anything this panel asked for, first and without looking for it.
	if sweep.dirty then
		sweep.dirty = false

		return true
	end

	-- Then an error raised anywhere since the rows were built. One that does not stop its
	-- widget changes nothing the sweep below looks at, and still gives a row a button. The
	-- handler keeps one count for all of them, so noticing is a comparison a frame rather
	-- than a look at every row's log - and a row off screen hears of it as soon as one on it.
	if (widgetHandler.errorCount or 0) ~= sweep.errorCount then
		return true
	end

	-- Then what is on screen, which is what is being looked at.
	for i = 1, page do
		local e = model.rows[first + i]
		if not e then
			break
		end
		if sweep.moved(e) then
			return true
		end
	end

	-- Then a slice of the whole list, carrying on from where the last frame stopped.
	local n = #model.entries
	if n > 0 then
		for _ = 1, (sweep.slice < n and sweep.slice or n) do
			if sweep.at > n then
				sweep.at = 1
			end
			local e = model.entries[sweep.at]
			sweep.at = sweep.at + 1
			if e and sweep.moved(e) then
				return true
			end
		end
	end

	-- And the load order, which moves without any state changing: raising or lowering a
	-- widget only shifts it within the handler's list, and that is queued like the rest.
	local live = widgetHandler.widgets
	local m = #live
	if m > 0 then
		for _ = 1, (sweep.slice < m and sweep.slice or m) do
			if sweep.order > m then
				sweep.order = 1
			end
			local w = live[sweep.order]
			local e = w and w.whInfo and model.entryByName[w.whInfo.name]
			if e and e.order ~= sweep.order then
				return true
			end
			sweep.order = sweep.order + 1
		end
	end

	return false
end

function model.refreshContent()
	buildContent()
	-- The picker follows: a set can be saved or forgotten between one build and the next.
	model.onSetsChanged()
	rebuildRows()
	model.onContentChanged()
end

function model.loadLabels()
	local function tr(key, fallback)
		return BAR.I18N("ui.widgetselector." .. key, { default = fallback })
	end

	L.title = tr("title", "Widget Selector")
	L.all = tr("category.all", "All")
	L.favorites = tr("category.favorite", "Favorites")
	L.interface = tr("category.interface", "Interface")
	L.commands = tr("category.commands", "Commands")
	L.units = tr("category.units", "Units")
	L.graphics = tr("category.graphics", "Graphics")
	L.camera = tr("category.camera", "Camera")
	L.sound = tr("category.sound", "Sound")
	L.map = tr("category.map", "Map")
	L.minimap = tr("category.minimap", "Minimap")
	L.api = tr("category.api", "API")
	L.debug = tr("category.debug", "Debug")
	L.other = tr("category.other", "Other")

	L.search = tr("search", "Search...")
	L.mine = tr("category.local", "Your own")
	L.rmlui = tr("category.rml", "RmlUi")
	L.enabledOnly = tr("enabledonly", "Enabled only")
	L.errorsOnly = tr("errorsonly", "Errors only")
	L.byOrder = tr("byorder", "By load order")
	L.sets = tr("sets", "Widget sets")
	L.noSet = tr("noset", "No set")
	L.loadset = tr("loadset", "Load")
	L.saveset = tr("saveset", "Save")
	L.deleteset = tr("deleteset", "Delete")
	L.save = L.saveset
	L.saveSetTitle = tr("savesettitle", "Save widget set")
	L.saveSetWarn = tr(
		"savesetwarn",
		"Remembers which widgets are switched on right now under this name. Saving over a name you already have replaces it."
	)
	L.deleteSetTitle = tr("deletesettitle", "Delete widget set")
	L.deleteSetWarn = tr("deletesetwarn", "Forgets this set. The widgets it switched on stay as they are.")
	L.factoryDefaults = tr("factorydefaults", "Factory defaults")
	L.islocal = tr("islocal", "local")
	L.stateOn = tr("state.on", "Running")
	L.statePending = tr("state.pending", "Enabled, but not running")
	L.stateOff = tr("state.off", "Off")
	L.file = tr("file", "File")
	L.author = tr("author", "Author")

	L.cancel = tr("cancel", "Cancel")
	L.confirm = tr("confirm", "Confirm")
	L.reload = tr("button_reloadluaui", "Reload LuaUI")
	L.disallowUser = tr("button_disallowuserwidgets", "Disallow User Widgets")
	L.allowUser = tr("button_allowuserwidgets", "Allow User Widgets")
	L.reset = tr("button_resetluaui", "Reset LuaUI")

	L.factoryWarn = tr(
		"factorydefaultswarn",
		"This throws away every interface setting you have: which widgets are on, their positions, and anything you have configured in them. LuaUI reloads immediately. It cannot be undone."
	)
	L.disallowUserWarn = tr(
		"disallowuserwarn",
		"Stops loading widgets from your own LuaUI folder, leaving only the ones the game ships. LuaUI reloads immediately."
	)
	L.allowUserWarn = tr(
		"allowuserwarn",
		"Loads widgets from your own LuaUI folder again alongside the ones the game ships. LuaUI reloads immediately."
	)
	L.resetWarn = tr(
		"resetwarn",
		"Puts every widget back to the set the game enables by default. Widgets you added stay on disk. LuaUI reloads immediately."
	)
	-- Said plainly, because raise and lower do not move a widget by one place: they send
	-- it to the front or the back of the band of widgets sharing its layer, and it can
	-- never leave that band.
	L.order = tr("order", "Load order")
	L.changed = tr("category.changed", "Changed")
	L.isrml = tr("isrml", "rml")
	L.iserror = tr("iserror", "error")
	L.total = tr("total", "total")
	L.defaultOn = tr("defaulton", "default enabled")
	L.defaultOff = tr("defaultoff", "default disabled")
	L.profiler = tr("profiler", "Cost")
	L.byLoad = tr("byload", "By cost")
	L.cleardata = tr("cleardata", "Reset")
	L.starAdd = tr("staradd", "Add to favorites")
	L.starRemove = tr("starremove", "Remove from favorites")
	L.starDesc = tr(
		"stardesc",
		"Collects this widget under Favorites at the top of the column, so it is one click away whatever else the list is showing. It is a bookmark and nothing more: it does not switch the widget on, and it is remembered between games."
	)
	L.showdata = tr("showdata", "Show data")
	L.showdataDesc =
		tr("showdatadesc", "Everything this widget has saved, the way it is stored. Click to read all of it.")
	L.errorsLoading = tr("errorsloading", "while loading")
	L.errorsMemory = tr("errorsmemory", "memory limit")
	L.errorsMore = tr("errorsmore", "more")
	L.depsUses = tr("depsuses", "Uses")
	L.depsUsedBy = tr("depsusedby", "Used by")
	L.depsOff = tr("depsoff", "off")
	L.depsRunningOne = tr("depsrunningone", "running widget")
	L.depsRunning = tr("depsrunning", "running widgets")
	L.depsUnchecked = tr("depsunchecked", "never check it is there")
	-- Fallbacks only: these carry placeholders, which i18n fills in at lookup, so they are looked
	-- up where the values are known.
	L.depsWarnFallback =
		"%{count} running widgets use what %{name} provides without checking it is there, so switching it off will most likely break them:"
	L.depsWarnOneFallback =
		"A running widget uses what %{name} provides without checking it is there, so switching it off will most likely break it:"
	L.depsCauseFallback = "%{key} comes from %{provider}, which is off"
	L.close = tr("close", "Close")
	L.cleardataTitle = tr("cleardatatitle", "Clear saved settings")
	-- The fallbacks only. These two carry the widget's name, and i18n fills a %{...} in
	-- as the string is looked up - so looking one up here, with no name to hand, would
	-- bake tostring(nil) into the sentence and every use of it would read "everything nil
	-- has saved". clearDataWarning does the lookup instead, once it has a name.
	L.cleardataWarnFallback =
		"Throws away everything %{name} has saved - its options, its window position, whatever it remembers - and it starts again from its defaults. Nothing else in the list is touched."
	L.cleardataRestartWarnFallback =
		"Throws away everything %{name} has saved - its options, its window position, whatever it remembers. It is running, so it is switched off and on again to start from its defaults. Nothing else in the list is touched."
	L.layer = tr("layer", "Layer")

	-- What every control on the panel does, keyed the way the control names itself. The
	-- destructive ones point at the wording their own confirmation uses, so what the
	-- tooltip promises and what the dialog asks cannot drift apart.
	L.desc = {
		-- The column. What a full-word category actually collects is the one thing its label
		-- deliberately does not say.
		all = tr("alldesc", "Every widget the game knows about, whether it is running or not."),
		favorites = tr(
			"favoritedesc",
			"The widgets you have starred. Click the star ahead of any widget's name to put it here, and click it again to take it out. Nothing else about the widget changes."
		),
		changed = tr(
			"changeddesc",
			"Every widget switched to something other than what it ships as - on when it ships off, or off when it ships on. What this game has been customised into, and exactly what Factory defaults would undo."
		),
		-- The fallback only: see where it is used. Fetching it here would fill the
		-- placeholder in with nothing.
		prefix = "Widgets whose file begins with %{prefix}.",
		other = tr("otherdesc", "Widgets whose file begins with something this panel has no category for."),
		counts = tr("countsdesc", "The count reads how many are running out of how many there are."),
		mine = tr(
			"localdesc",
			"The widgets in your own LuaUI folder rather than the ones the game ships. They carry a local tag on the row too."
		),
		rmlui = tr(
			"rmldesc",
			"The widgets that build their interface with RmlUi, laid out from markup and style sheets, rather than drawing it themselves. Found by what their source uses rather than where the file sits, so your own count too. They carry an rml tag on the row as well."
		),
		enabledOnly = tr(
			"enabledonlydesc",
			"Show only the widgets the config says to load - running or not - so what is off stays out of the way."
		),
		errorsOnly = tr(
			"errorsonlydesc",
			"Show only the widgets that have raised an error this session - the ones tagged error - whether an error stopped them or they are running again."
		),
		byOrder = tr(
			"byorderdesc",
			"Order the list the way the widgets load, which is the order their call-ins run in. Anything not running has no place in that order and follows at the end."
		),
		profiler = tr(
			"profilerdesc",
			"Show what each widget costs: processor time as a share of the frame, and memory allocated per second. Measuring it means timing every call-in of every widget, so this is only paid for while it is switched on."
		),
		byLoad = tr(
			"byloaddesc",
			"Order the list by what each widget costs, heaviest first. The order stands still while the cursor is over the list, so nothing slides out from under a click, and catches up when the cursor leaves."
		),
		reload = tr(
			"reloaddesc",
			"Loads every widget again from disk, keeping what is switched on. The quickest way to pick up a widget you have just edited."
		),
		reset = L.resetWarn,
		factory = L.factoryWarn,
		loadset = tr(
			"loadsetdesc",
			"Switches on every widget in the chosen set and switches off everything else, so the list ends up exactly as the set describes it."
		),
		saveset = L.saveSetWarn,
		deleteset = L.deleteSetWarn,
	}
end

-- What clearing this widget would do, in the words the confirmation uses. Looked up
-- with the name rather than taken from L: see the fallbacks above. The gsub covers the
-- other path, where the key is missing entirely and i18n hands the fallback back
-- untouched rather than interpolating it.
function model.clearDataWarning(name, running)
	local text = BAR.I18N(
		"ui.widgetselector." .. (running and "cleardatarestartwarn" or "cleardatawarn"),
		{ name = name, default = running and L.cleardataRestartWarnFallback or L.cleardataWarnFallback }
	)

	return (text:gsub("%%{name}", name))
end

function model.buildButtons()
	model.buttons = {
		{ id = "reload", label = L.reload },
		{
			id = "userwidgets",
			label = widgetHandler.allowUserWidgets and L.disallowUser or L.allowUser,
			-- Red while they are allowed, because the press takes them away; green while
			-- they are not, because the press brings them back.
			danger = widgetHandler.allowUserWidgets,
			good = not widgetHandler.allowUserWidgets,
		},
		{ id = "reset", label = L.reset, danger = true },
		{ id = "factory", label = L.factoryDefaults, danger = true },
	}
	if not allowuserwidgets then
		-- By id, not by position: the list has lost a button before now and the index
		-- went stale with it, which took out the wrong one.
		for i, b in ipairs(model.buttons) do
			if b.id == "userwidgets" then
				table.remove(model.buttons, i)
				break
			end
		end
	end
end

-- What the cursor is over, said in words: a switch or button over the panel, or failing
-- that the row under it. One function rather than two, and its own rather than a block
-- inside DrawScreen, where an early return would quietly skip whatever is added after it.
-- What the last tooltip was built from, and what it came out as. gui_tooltip wants the
-- strings on every frame the tooltip is up, and building them again each time is a wrapped,
-- substituted string per frame for a reading nobody changed - and gui_tooltip throws its
-- own display list away whenever the text it is handed differs.
--
-- Compared field by field rather than through a key, since building a key would be the very
-- string this is avoiding.
local tipCache = {}

function tipCache.same(a, b, c, d)
	return tipCache.title ~= nil and tipCache.a == a and tipCache.b == b and tipCache.c == c and tipCache.d == d
end

function tipCache.keep(a, b, c, d, title, text)
	tipCache.a, tipCache.b, tipCache.c, tipCache.d, tipCache.title, tipCache.text = a, b, c, d, title, text
end

function model.showTooltip(row)
	local caption, body, danger

	if model.hover.sb > 0 and model.categories[model.hover.sb] then
		local c = model.categories[model.hover.sb]
		-- The index came from the column itself, and the line above checked it is still there.
		---@cast c -?
		caption = c.label
		if c.key == nil then
			body = L.desc.all
		elseif c.key == fav.key then
			body = L.desc.favorites
		elseif c.key == "changed" then
			body = L.desc.changed
		elseif c.key == "local" then
			body = L.desc.mine
		elseif c.key == "rml" then
			body = L.desc.rmlui
		else
			-- Which filename prefix this one collects. The full-word label deliberately does
			-- not say it, and it is the one thing about a category worth knowing.
			local prefix
			for p, g in pairs(GROUPS) do
				if g == c.key then
					prefix = p
				end
			end
			if prefix then
				-- Looked up here with the prefix in hand rather than taken from L: i18n fills a
				-- %{...} in as the string is looked up, and looking it up without one bakes the
				-- word nil into the sentence. The gsub covers the other path, where the key is
				-- missing and the fallback is handed back untouched.
				body = BAR.I18N("ui.widgetselector.prefixdesc", { prefix = prefix .. "_", default = L.desc.prefix })
				body = (body:gsub("%%{prefix}", prefix .. "_"))
			else
				body = L.desc.other
			end
		end
		-- A category with nothing to say shows nothing rather than taking the panel down with
		-- it: the tooltip is not worth a crash.
		if body then
			body = body .. "\n" .. L.desc.counts
		end
	elseif model.hover.tog > 0 and switches[model.hover.tog] and switches[model.hover.tog].draw then
		local sw = switches[model.hover.tog]
		caption, body = sw.label, L.desc[sw.key]
	elseif model.hover.btn ~= "" then
		-- The user-widgets button says two different things depending on which way it is
		-- pointing, so its wording is picked here rather than baked into the table.
		if model.hover.btn == "userwidgets" then
			caption = widgetHandler.allowUserWidgets and L.disallowUser or L.allowUser
			body = widgetHandler.allowUserWidgets and L.disallowUserWarn or L.allowUserWarn
			danger = widgetHandler.allowUserWidgets
		else
			body = L.desc[model.hover.btn]
			for _, b in ipairs(model.buttons) do
				if b.id == model.hover.btn then
					caption, danger = b.label, b.danger
				end
			end
			caption = caption or L[model.hover.btn]
		end
	end

	if caption and body then
		if not tipCache.same("control", caption, body, danger or false) then
			tipCache.keep(
				"control",
				caption,
				body,
				danger or false,
				(danger and look.tip.danger or "") .. caption .. "\n",
				"\255\255\255\255"
					.. string.gsub(
						model.font:WrapText(body, WG.tooltip.getFontsize() * 90),
						"[\n]",
						"\n\255\255\255\255"
					)
			)
		end
		WG.tooltip.ShowTooltip("widgetselector", tipCache.text, nil, nil, tipCache.title)

		return
	end

	-- Nothing over the panel, so whatever row is under the cursor has it; with no row
	-- either, nothing is being pointed at that has anything to say.
	if not row then
		return
	end

	local maxWidth = WG.tooltip.getFontsize() * 90

	-- The row's two buttons come first, ahead of the row's own held tooltip below. That one is kept for
	-- the row alone, and moving along the row onto a button does not change the row - so over the
	-- buttons it went on showing the row's details.
	-- Over the star, what the star does, headed with what this particular click would do to
	-- this particular row: the mark is small and says nothing in words, and the difference
	-- between adding and removing is the whole of what a reader wants confirmed first.
	if model.hover.star == 1 then
		local starred = fav.names[row.name] ~= nil
		if not tipCache.same("star", row.name, starred, false) then
			tipCache.keep(
				"star",
				row.name,
				starred,
				false,
				(starred and L.starRemove or L.starAdd) .. "\n",
				"\255\255\255\255"
					.. string.gsub(model.font:WrapText(L.starDesc, maxWidth), "[\n]", "\n\255\255\255\255")
			)
		end
		WG.tooltip.ShowTooltip("widgetselector", tipCache.text, nil, nil, tipCache.title)

		return
	end
	-- Over the clear button the tooltip is about the button, not the widget: the row's
	-- details are what the rest of the row already answers, and a button that throws
	-- settings away should say so before it is pressed rather than only after. Word for
	-- word what the confirmation asks, so nothing new turns up at the last step.
	if model.hover.clr == 1 then
		if not tipCache.same("clear", row.name, row.state, false) then
			local warn = model.clearDataWarning(row.name, row.state == 1)
			tipCache.keep(
				"clear",
				row.name,
				row.state,
				false,
				look.tip.danger .. L.cleardataTitle .. "\n",
				"\255\255\255\255" .. string.gsub(model.font:WrapText(warn, maxWidth), "[\n]", "\n\255\255\255\255")
			)
		end
		WG.tooltip.ShowTooltip("widgetselector", tipCache.text, nil, nil, tipCache.title)

		return
	end
	-- Over Show data, what the widget has saved: the head of the listing the button opens, so a glance
	-- answers what a click would, and a click is only needed for the rest. Held until what is saved
	-- changes, which is when the handler stores a new table for the widget.
	if model.hover.dat == 1 then
		local data = widgetHandler.configData[row.name]
		if not tipCache.same("data", row.name, data, false) then
			tipCache.keep("data", row.name, data, false, L.showdata .. "\n", dataView.preview(row.name, maxWidth))
		end
		WG.tooltip.ShowTooltip("widgetselector", tipCache.text, nil, nil, tipCache.title)

		return
	end

	-- Everything below builds two strings with a wrap and a substitution in them, and none
	-- of what they are built from moves while the cursor rests on one row. Held until the
	-- row, its state or its place in the order changes. Keyed on the row itself rather than
	-- its name: a new error rebuilds the rows, and a tooltip held by name would go on showing
	-- the errors it was built with.
	-- With the breakdown showing, the reading changes once per sample rather than never,
	-- so the sample counter joins what the cache is keyed on.
	local gen = filters.profiler and profiling.gen or 0
	if tipCache.same("row", row, row.state, (row.order or 0) + gen * 100000) then
		WG.tooltip.ShowTooltip("widgetselector", tipCache.text, nil, nil, tipCache.title)

		return
	end

	local d = row.data
	-- The same three states the row is painted in, said in words: green is running,
	-- amber is enabled but not running, red is off.
	local stateColor, stateWord = "\255\255\160\160", L.stateOff
	if row.state == 1 then
		stateColor, stateWord = "\255\130\255\160", L.stateOn
	elseif row.state == 0.5 then
		stateColor, stateWord = "\255\255\240\160", L.statePending
	end
	-- Said on the state line rather than a line of its own: what matters about the shipped
	-- default is how it sits against the state now, and "Off  (on by default)" is that whole
	-- story in one reading.
	stateWord = stateWord .. "  \255\140\140\140(" .. (d.enabled and L.defaultOn or L.defaultOff) .. ")"

	local title = stateColor .. row.name .. "\n"

	local tip = stateColor .. stateWord .. "\n"
	-- Straight after the state, because for a widget that has raised errors they are the
	-- thing worth reading. Newest first and at most three, each the message before where it
	-- happened, with Lua's [string "LuaUI/Widgets/x.lua"] cut down to the file name - the path
	-- is on the File line below, and a glance wants the line number. The one that stopped the
	-- widget is in the tag's red; any others, or all of them once it runs again, quieter.
	if row.errors then
		local errorEntries = row.errors.entries
		local shown = 0
		for i = #errorEntries, 1, -1 do
			if shown == 3 then
				tip = tip .. "\255\150\150\150+" .. i .. " " .. L.errorsMore .. "\n"
				break
			end
			shown = shown + 1
			local e = errorEntries[i]
			-- The loop covers every index, so this cannot be nil.
			---@cast e -?
			local msg = string.match(tostring(e.message), "^[^\n]*")
			msg = string.gsub(msg, '%[string "([^"]*)"%]', function(path)
				return string.match(path, "([^/]+)$") or path
			end)
			-- `memory`: barwidgets turned it off for the memory it used, not for an error.
			local where = e.memory and L.errorsMemory or e.callin and (e.callin .. "()") or L.errorsLoading
			if e.count > 1 then
				where = where .. ", x" .. e.count
			end
			local color = (row.stoppedBy and e == row.errors.stopped) and tagColors.iserror or tagColors.iserrorSoft
			tip = tip
				.. color
				.. string.gsub(model.font:WrapText(L.iserror .. ":  " .. msg, maxWidth), "[\n]", "\n" .. color)
				.. "\255\140\140\140  ("
				.. where
				.. ")\n"
		end
		tip = tip .. deps.causes(row)
	end
	if d.desc and d.desc ~= "" then
		tip = tip
			.. "\255\255\255\255"
			.. string.gsub(model.font:WrapText(d.desc, maxWidth), "[\n]", "\n\255\255\255\255")
			.. "\n"
	end
	local label, value = look.tip.label, look.tip.value
	if d.author and d.author ~= "" then
		tip = tip .. label .. L.author .. ":  " .. value .. d.author .. "\n"
	end
	if row.order then
		tip = tip
			.. label
			.. L.order
			.. ":  "
			.. value
			.. row.order
			.. label
			.. "   ("
			.. L.layer
			.. " "
			.. value
			.. tostring(row.layer)
			.. label
			.. ")\n"
	end
	tip = tip
		.. label
		.. L.file
		.. ":  "
		.. value
		.. (d.basename or "")
		.. (row.isLocal and (label .. "   (" .. tagColors.islocal .. L.islocal .. label .. ")") or "")
		.. "\n"
		.. deps.tooltip(row, maxWidth)
	-- With the cost column on, what the widget is spending it on, broken down the way the
	-- profiler breaks it down: time, allocations, callin. A tooltip is one string in a
	-- proportional face, so the columns are padded to a fixed number of characters rather
	-- than measured - digits are the same width in most faces, which is what carries it.
	if filters.profiler then
		local detail = profiling.callins(row.name)
		if detail then
			local list = {}
			local sumT, sumS = 0, 0
			for cname, c in pairs(detail) do
				sumT = sumT + c[1]
				sumS = sumS + c[2]
				-- A callin that costs nothing either way is noise; its cost still counts towards
				-- the total, so that stays honest.
				if c[1] >= 0.003 or c[2] >= 0.1 then
					list[#list + 1] = { name = cname, t = c[1], s = c[2] }
				end
			end
			table.sort(list, function(x, y)
				return x.t > y.t
			end)

			-- The heading sits at the head of its column rather than right-aligned with the
			-- figures under it: a heading shorter than the numbers below would otherwise float
			-- off to the right of them, which is what a reader sees as the column being indented.
			tip = tip .. "\n" .. "\255\160\255\160" .. string.format("%-7s %-13s %s", "time", "allocs", "callin")
			for i = 1, #list do
				local e = list[i]
				tip = tip .. "\n\255\175\175\175" .. string.format("%6.2f%% %9.1fkB/s %s", e.t, e.s, e.name)
			end
			tip = tip .. "\n\255\160\255\160" .. string.format("%6.2f%% %9.1fkB/s %s", sumT, sumS, L.total)
		end
	end

	tipCache.keep("row", row, row.state, (row.order or 0) + gen * 100000, title, tip)
	WG.tooltip.ShowTooltip("widgetselector", tipCache.text, nil, nil, tipCache.title)
end

model.tipCache = tipCache

-- A header switch pressed.
function model.toggleFilter(key)
	local filters = model.filters
	filters[key] = not filters[key]
	-- Two ways of ordering the same list, so switching one on takes the other off
	-- rather than leaving the header claiming both.
	if key == "byLoad" and filters.byLoad then
		filters.byOrder = false
	elseif key == "byOrder" and filters.byOrder then
		filters.byLoad = false
	end
	applyProfiling()
end

-- A click on a row, not on any of its buttons: the left button switches it, the other two move it in the order.
function model.clickRow(overRow, button)
	if button == 1 then
		-- Switching off a widget that running widgets use without checking it is there asks
		-- first: they will most likely break, and nothing on the row says so.
		local name = overRow.name
		local unchecked = {}
		if overRow.data.active then
			local _
			_, unchecked = deps.users(name, true)
		end
		if #unchecked > 0 then
			model.confirm(name, deps.warning(name, unchecked), function()
				widgetHandler:ToggleWidget(name)
				sweep.dirty = true
			end, true)
		else
			widgetHandler:ToggleWidget(name)
			sweep.dirty = true
		end
	else
		local w = widgetHandler:FindWidget(overRow.name)
		if w then
			if button == 2 then
				widgetHandler:LowerWidget(w)
				sweep.dirty = true
			else
				widgetHandler:RaiseWidget(w)
				sweep.dirty = true
			end
			widgetHandler:SaveConfigData()
		end
	end
end

-- Kept up whether or not the panel is open. The column may have been switched on by the config, before there was a
-- handler far enough along to wrap: anything that leaves the two disagreeing is settled here.
function model.syncProfiling()
	if model.filters.profiler ~= profiling.subscribes(widget) then
		applyProfiling()
	end
end

function model.finishClear()
	-- The disable asked for on the click has run by now, so the widget has already handed
	-- its settings back and this is the one moment they can be dropped for good.
	if pendingClear then
		local p = pendingClear
		pendingClear = nil
		widgetHandler.configData[p.name] = nil
		if p.restart then
			widgetHandler:EnableWidget(p.name)
			sweep.dirty = true
		end
		widgetHandler:SaveConfigData()
		model.refreshContent()
	end
end

-- Input ownership, taken once when the search field takes focus and given back when it
-- loses it. `widgetHandler:OwnText()` is not available here: it is built onto the
-- per-widget wrapper barwidgets hands out, and this widget asks for the real handler
-- (handler = true), which carries the textOwner field itself and none of the sugar.
local ownsInput = false
local fieldHasInput = false
local textInputStarted = false
local heldAtFocus = {}

-- While a window's field or dialog wants the keyboard (Update, each frame).
function model.holdKeyboard(wantsInput)
	if wantsInput then
		if not fieldHasInput then
			fieldHasInput = true
			heldAtFocus = Spring.GetPressedKeys and Spring.GetPressedKeys() or {}
			ownsInput = ownText()

			-- Chat has to be asked to let go, and toggling its input flag is the only public
			-- way to make it cancel. The flag goes straight back because gui_chat persists it.
			if not ownsInput and WG.chat and WG.chat.isInputActive and WG.chat.isInputActive() then
				WG.chat.setHandleInput(false)
				WG.chat.setHandleInput(true)
				ownsInput = ownText()
			end
		elseif not ownsInput then
			ownsInput = ownText()
		end

		if ownsInput and not textInputStarted then
			textInputStarted = true
			if Spring.SDLStartTextInput then
				Spring.SDLStartTextInput()
			end
		end
	elseif fieldHasInput then
		fieldHasInput = false
		if ownsInput then
			ownsInput = false
			disownText()
		end
		if textInputStarted then
			textInputStarted = false
			if Spring.SDLStopTextInput then
				Spring.SDLStopTextInput()
			end
		end
	end
end

-- A key held when the field took the keyboard: its release is not the field's to swallow. Once per key.
function model.heldAtFocus(key)
	if heldAtFocus[key] then
		heldAtFocus[key] = nil

		return true
	end

	return false
end

function model.getConfigData()
	return {
		enabledOnly = filters.enabledOnly,
		errorsOnly = filters.errorsOnly,
		byOrder = filters.byOrder,
		profiler = filters.profiler,
		byLoad = filters.byLoad,
		category = model.selectedCategory,
		sets = model.sets,
		pickedSet = model.pickedSet,
		favorites = fav.names,
		-- Only written while it is set, so it is not a line in everyone's config saying no.
		reopen = filters.reopen ~= nil or nil,
	}
end

function model.setConfigData(data)
	if type(data) ~= "table" then
		return
	end
	-- Rebuilt rather than taken as read: this comes off disk, and a malformed entry here
	-- would otherwise reach the picker and the apply.
	model.sets = {}
	if type(data.sets) == "table" then
		for _, saved in ipairs(data.sets) do
			if type(saved) == "table" and type(saved.name) == "string" and type(saved.widgets) == "table" then
				local names = {}
				for name in pairs(saved.widgets) do
					if type(name) == "string" then
						names[name] = true
					end
				end
				model.sets[#model.sets + 1] = { name = saved.name, widgets = names }
			end
		end
	end
	model.pickedSet = type(data.pickedSet) == "string" and data.pickedSet or nil
	-- Taken name by name rather than as read, for the same reason the sets above are: this
	-- comes off disk. A name for a widget that is no longer installed is kept rather than
	-- dropped - it costs a string, and it means a widget put back is still starred.
	fav.names = {}
	if type(data.favorites) == "table" then
		for name in pairs(data.favorites) do
			if type(name) == "string" then
				fav.names[name] = true
			end
		end
	end
	filters.enabledOnly = data.enabledOnly == true
	filters.errorsOnly = data.errorsOnly == true
	filters.byOrder = data.byOrder == true
	-- Restored like the rest of the switches. It is not free - the column costs every
	-- widget in the game a wrapper round every callin for as long as it is on - but a
	-- switch that quietly forgets itself every session is worse than one that costs
	-- something, and the switch says plainly what it does. Acting on it waits for the
	-- first Update: this runs while the handler is still loading widgets, which is no
	-- time to start wrapping their callins.
	--
	-- The odd one out in this block: read as on unless it was saved off, rather than off
	-- unless it was saved on. That is what makes the default above stand for someone who
	-- has never touched the switch, while still letting anyone who switched it off keep it
	-- off - GetConfigData writes the field either way, so only a config that has never seen
	-- this panel is missing it.
	filters.profiler = data.profiler ~= false
	filters.byLoad = filters.profiler and data.byLoad == true
	model.selectedCategory = type(data.category) == "string" and data.category or nil
	filters.reopen = data.reopen == true and "restore" or nil
end

return model
