-- The Graphs page of the team stats panel: one chart of the picked stat over the game,
-- the teams as its series, with a stat list beside it and a legend bar above it that
-- selects or hides teams. The panel owns the frame, the sidebar and the switches
-- and hands this page the room between them; the page keeps the histories it plots (the
-- engine's own team statistics and the team stats gadget's, through WG.teamStats) and
-- rebuilds the chart when either grows or the pick changes.
--
-- The panel gives `ctx`: its column and label tables, the derive step that turns a
-- sample's counters into every column's value, its look, metrics and colours, the
-- FlowUI and gl draw calls and its text queue, and readers for what changes at runtime
-- (the ally teams read into the table, the gadget's last hand-over, the switches, the
-- group picked in the sidebar). See gui_teamstats.lua for the fields.

local Graph = VFS.Include("luaui/Include/graph.lua")
local Custom = VFS.Include("luaui/Include/teamstats_custom.lua")
local Editbox = VFS.Include("luaui/Include/keybind_editbox.lua")
local KEYSYMS = VFS.Include("luaui/Include/keybind_keysyms.lua")

local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathHuge = math.huge
local mathAbs = math.abs
local tableSort = table.sort

-- The composition bands: one colour per bucket, in the composition view's column order.
-- Softer than any team colour, so the bands are not read as teams.
local BUCKET_COLORS = {
	{ 0.86, 0.56, 0.48 },
	{ 0.68, 0.8, 0.9 },
	{ 0.5, 0.62, 0.8 },
	{ 0.72, 0.72, 0.7 },
	{ 0.7, 0.62, 0.84 },
	{ 0.86, 0.8, 0.54 },
	{ 0.62, 0.8, 0.62 },
	{ 0.52, 0.78, 0.76 },
	{ 0.82, 0.68, 0.76 },
}

-- Which kinds of milestone belong on a chart of which column group, so a chart is not
-- littered with moments that say nothing about it. `always` goes on every chart: the end of
-- a team explains the end of all of its lines.
local MILESTONE_GROUPS = {
	tech2 = { units = true, value = true, metal = true, energy = true, industry = true },
	tech3 = { units = true, value = true, metal = true, energy = true, industry = true },
	nuke = { damage = true, value = true, traded = true, energy = true },
	antinuke = { damage = true, value = true, energy = true },
	lrpc = { damage = true, value = true, traded = true },
	firstKill = { damage = true, units = true, traded = true },
	firstLoss = { damage = true, units = true, traded = true, value = true },
	commanderLost = { commanders = true, damage = true, units = true, value = true, metal = true, energy = true },
	teamDied = { always = true },
}

-- The grids a page can be split into, in the order the setting cycles through them.
local PAGES = {
	{ n = 9, cols = 3, rows = 3 },
	{ n = 12, cols = 4, rows = 3 },
	{ n = 16, cols = 4, rows = 4 },
}

-- The team profile's axes, in the order they go round the wheel from the top.
local PROFILE_AXES = {
	{ key = "damageDealt" },
	{ key = "unitsProduced" },
	{ key = "metalProduced" },
	{ key = "energyProduced" },
	{ key = "unitValue", gadget = true },
	{ key = "actionsPerMinute", gadget = true },
}

-- The legend bar's looks: a block is a button, the picked one lit and framed warm; the
-- squares under the cursor are framed white, over a pick's frame, so a press's target
-- stands out whatever state it is in.
local PLATE = { 1, 1, 1, 0.05 }
local PICKED_FRAME = { 1, 0.78, 0.51, 0.85 }
local HOVER_FRAME = { 1, 1, 1, 0.85 }
local HOVER_FADE = { 1, 0.78, 0.51, 0 }

-- A percentage for an axis or a tooltip: whole, a prefix past a million, infinity as
-- its sign.
local function percentFormat(v)
	if v == mathHuge then
		return "\226\136\158"
	elseif v == -mathHuge then
		return "-\226\136\158"
	end
	if math.abs(v) >= 1e6 and string.formatSI then
		return string.formatSI(v) .. "%"
	end
	return string.format("%.0f%%", v)
end

local M = {}

function M.new(ctx)
	---@type table<string, any>
	local page = {
		open = true,
		stat = "damageDealt",
		-- Units right-clicked off the chart, by key.
		---@type table<string, boolean>
		hidden = {},
		-- The players picked in the legend bar, by "team<id>" key, however it groups them;
		-- none is every team alike. They stand out on the chart, or with Hide unselected on
		-- they are all it shows. Starts on the viewer's own team, when they have one and
		-- Hide unselected is off.
		---@type table<string, boolean>
		selected = {},
		selectionSet = false,
		-- The viewer's team as the last build saw it: a spectator can switch it.
		---@type table?
		viewer = nil,
		-- Whether the units not picked are left off the charts rather than faded behind.
		hideUnselected = false,
		-- The axes of the profile wheel, as the last build read them.
		---@type table[]
		profileAxes = {},
		-- The page's own grouping, kept apart from the table's: a chart of ally teams and
		-- a table of ally teams are different questions, and picking a single player on the
		-- chart should not flatten the table.
		grouped = true,
		hover = { stat = 0, legend = 0, block = 0, kind = 0, filter = 0, addTo = 0 },
		-- A card of actions over everything, taking the next press: what a custom category,
		-- a custom graph or the Add to... button offers.
		---@type table?
		menu = nil,
		-- A category being named, in a field over its sidebar entry.
		---@type table?
		naming = nil,
		-- A press on a graph of the player's own, until it is let go: { key, graph, x, y,
		-- moving } - a click opens the graph, a drag moves it.
		---@type table?
		drag = nil,
		-- Per team: the engine's history entries taken at the period, derived, and how
		-- many of the engine's list they are; the live newest entry is left out so the
		-- chart changes once a period, not every second.
		---@type table<integer, { used: integer, entries: table[] }>
		engine = {},
		-- Per team: the gadget's samples as a run per key.
		---@type table<integer, { frames: number[], values: table<string, number[]> }>
		gadget = {},
		lastPeriod = -1,
		-- Bumped when either history grows; the sample tables are rebuilt against it.
		version = 0,
		samplesVersion = -1,
		---@type table<integer, table<number, table>>
		samples = {},
		-- Whether any team has a sample at all: tells a chart that waits for the first
		-- ones from a stat that has nothing to plot.
		anySamples = false,
		dirty = true,
		---@type table[]
		statList = {},
		-- The stat list's entries by key: a custom category's graph is listed under a key of
		-- its own, with the stat it shows and the settings it keeps.
		---@type table<string, table>
		entryByKey = {},
		---@type table[]
		units = {},
		---@type table<string, table>
		unitByKey = {},
		-- The legend bar: the All button, then a block per ally team, and the squares in
		-- the blocks as hit targets.
		---@type table[]
		barBlocks = {},
		---@type table[]
		barItems = {},
		barLabels = true,
		-- Bumped whenever what the panel bakes for the page changes: the pick, the
		-- selection, the hidden set, the bar's layout. Part of the panel's bake signature.
		gen = 0,
		---@type table?
		rects = nil,
		---@type table?
		chartHit = nil,
		-- The grid: how many charts a page holds, which row it starts at, the charts on
		-- it and the one under the cursor.
		perPage = 12,
		scroll = 0,
		maxScroll = 0,
		---@type table[]
		miniCharts = {},
		---@type table?
		miniHit = nil,
		-- A chart opened from the grid, by stat key: it takes the whole page until it is
		-- closed again.
		---@type string?
		zoom = nil,
		-- The group the stat list was built for; another one shows its own charts.
		---@type string?
		group = nil,
		-- Where the card of milestone kinds is anchored: the settings row that opens it.
		---@type table?
		kindsAnchor = nil,
		-- The kinds of milestone left off the charts, by key, and whether the card that
		-- picks them is open.
		---@type table<string, boolean>
		milestoneOff = {},
		kindsOpen = false,
		---@type table[]
		kindRects = {},
		empty = true,
		scale = 1,
	}

	-- The player's own categories, kept at the front of the panel's groups.
	page.custom = Custom.new(ctx)

	local chart = Graph.new({
		kind = "line",
		legend = false,
		xUnit = "frames",
		lineWidth = 2,
		includeZero = true,
		look = { plotFill = { 0, 0, 0, 0.16 } },
	})
	page.chart = chart

	-- The custom category's graph open on its own, if one is: its settings are the page's
	-- while it is.
	function page.openGraph()
		local entry = page.zoom and page.entryByKey[page.zoom]
		return entry and entry.graph or nil
	end

	-- Ally teams as the units of the legend bar, in a game where a side has more than one
	-- player to group: the switch's grouping, or the open custom graph's own.
	local function grouped()
		local graph = page.openGraph()
		local on = page.grouped
		if graph then
			on = graph.grouped
		end
		return on and not ctx.soloTeams
	end

	-- The settings a chart is drawn with: a custom category's graph keeps its own, every
	-- other chart takes the switches'.
	local function settingsOf(key)
		local entry = key and page.entryByKey[key]
		if entry and entry.graph then
			return entry.graph
		end
		return {
			grouped = page.grouped,
			share = ctx.filters.shareOfTotal,
			milestones = ctx.filters.milestones,
			off = page.milestoneOff,
		}
	end

	-- The stat a chart shows, whatever its entry is called.
	local function statOf(key)
		local entry = key and page.entryByKey[key]
		return entry and entry.stat or key
	end

	-- The kinds of milestone left off the chart being set: the open custom graph's own, the
	-- page's otherwise.
	local function kindsOff()
		local graph = page.openGraph()
		return graph and graph.off or page.milestoneOff
	end

	-- Picks and hides are kept per player - "team<id>" - whichever way the bar groups them,
	-- so a graph drawn per player keeps a pick of one player through a page grouped by
	-- ally team, and back. A whole ally team's key is still read: "ally<id>" is all of its
	-- players.
	local function teamIn(set, team)
		return set["team" .. team.id] == true or set["ally" .. team.allyID] == true
	end

	-- Whether a unit is picked or hidden, whichever way it is grouped: a player goes with
	-- its own key or its ally team's; an ally team is picked with any of its players and
	-- hidden with all of them.
	local function isPicked(u)
		for _, team in ipairs(u.teams) do
			if teamIn(page.selected, team) then
				return true
			end
		end
		return false
	end

	local function isHidden(u)
		for _, team in ipairs(u.teams) do
			if not teamIn(page.hidden, team) then
				return false
			end
		end
		return #u.teams > 0
	end

	-- Every player of a unit picked: what makes a press on it take the pick back out.
	local function allPicked(u)
		for _, team in ipairs(u.teams) do
			if not teamIn(page.selected, team) then
				return false
			end
		end
		return #u.teams > 0
	end

	-- Picks or unpicks - hides or shows - every player a unit stands for. A whole ally
	-- team's key is taken apart into its players first, so one of them can go on its own.
	local function setTeams(set, u, on)
		for _, team in ipairs(u.teams) do
			local allyKey = "ally" .. team.allyID
			if set[allyKey] then
				set[allyKey] = nil
				local ally = page.unitByKey and page.unitByKey[allyKey]
				for _, id in ipairs(ally and ally.members or {}) do
					set["team" .. id] = true
				end
			end
			set["team" .. team.id] = on or nil
		end
	end
	page.isPicked, page.isHidden, page.allPicked = isPicked, isHidden, allPicked

	-- The units a chart of these settings is drawn with: ally teams or players.
	local function unitsFor(settings)
		local list = (settings.grouped and not ctx.soloTeams) and page.allyUnits or page.playerUnits
		return list or page.units
	end

	-- The Group by team switch while the page is open, from the panel.
	function page.setGrouped(state)
		if page.grouped ~= state then
			page.grouped = state
			page.dirty = true
			page.gen = page.gen + 1
			page.rebuildUnits()
		end
	end

	----------------------------------------------------------------
	-- The stat list
	----------------------------------------------------------------

	-- The stats of the sidebar's group, the composition chart first in its group. The
	-- gadget's columns, and the ones only it keeps a history of, only while it is there.
	-- The kinds of milestone, in the order the panel names them.
	local function milestoneKinds()
		return ctx.L.milestoneOrder or {}
	end

	-- What a settings row with a value says, and what pressing it does. The panel asks
	-- rather than knowing, so a new setting only needs adding here.
	function page.settingValue(key)
		if key == "perPage" then
			return page.perPage
		end
		local kinds = milestoneKinds()
		local off = kindsOff()
		local on = 0
		for _, kind in ipairs(kinds) do
			if not off[kind] then
				on = on + 1
			end
		end
		return on .. "/" .. #kinds
	end

	-- The card put away from outside: Escape, or the panel closing.
	function page.closeKinds()
		if page.kindsOpen then
			page.kindsOpen = false
			page.dirty = true
			page.gen = page.gen + 1
		end
	end

	function page.settingPress(key, back)
		if key == "perPage" then
			page.cyclePerPage(back)
			return
		end
		-- The card of kinds opens over the charts and closes on the next press.
		page.kindsOpen = not page.kindsOpen
		page.dirty = true
		page.gen = page.gen + 1
	end

	-- Whether the stat list is shown beside the charts: a grid says what each chart is in
	-- its own title, so the list would only take room from it.
	function page.listShown()
		return not page.gridded()
	end

	function page.rebuildStatList()
		local group = ctx.groupByKey[ctx.selectedGroup()] or ctx.GROUPS[1]
		if page.group ~= group.key then
			-- A group of its own charts: the page shows them rather than staying on the one
			-- that was open in the group before.
			page.group, page.zoom, page.scroll = group.key, nil, 0
		end
		local list = {}
		do
			-- The way back to the grid, kept apart from the stats by a rule.
			list[#list + 1] = { key = "overview", label = ctx.i18n("ui.teamStats.graph.overview"), back = true }
			list[#list + 1] = { divider = true }
		end
		if group.custom then
			-- A custom category's graphs in its order, each under a key of its own: one stat
			-- can be in it twice, drawn two ways. What needs the gadget waits for it.
			for _, graph in ipairs(group.graphs) do
				local column = ctx.COLUMNS[graph.stat]
				local needsGadget = column and (column.gadget or column.liveOnly)
					or graph.stat == "timeline"
					or graph.stat == "composition"
				if ctx.gadgetOn() or not needsGadget then
					local label = column and ctx.columnTitle(column) or ctx.i18n("ui.teamStats.graph." .. graph.stat)
					-- Only an amount has a total to take a part of: a ratio or a level added
					-- with the switch on is still drawn as it is.
					if column and graph.share and column.fmt == "si" then
						label = label .. " \194\183 " .. ctx.L.switch.shareOfTotal
					end
					list[#list + 1] = {
						key = "g" .. graph.id,
						stat = graph.stat,
						label = label,
						column = column,
						graph = graph,
					}
				end
			end
		else
			if group.key == "composition" and ctx.gadgetOn() then
				list[#list + 1] = { key = "composition", label = ctx.i18n("ui.teamStats.graph.composition") }
			end
			for i = 1, #group.columns do
				local column = ctx.COLUMNS[group.columns[i]]
				if ctx.gadgetOn() or not (column.gadget or column.liveOnly) then
					list[#list + 1] = { key = column.key, label = ctx.columnTitle(column), column = column }
				end
			end
		end
		page.statList = list
		page.entryByKey = {}
		for _, entry in ipairs(list) do
			if entry.key then
				page.entryByKey[entry.key] = entry
			end
		end
		local found = false
		---@type table?
		local first = nil
		for i = 1, #list do
			if list[i].key == page.stat then
				found = true
			end
			if not first and list[i].key and not list[i].back and not list[i].divider then
				first = list[i]
			end
		end
		if not found and first then
			page.stat = first.key
		end
		page.dirty = true
		page.gen = page.gen + 1
	end

	----------------------------------------------------------------
	-- Layout
	----------------------------------------------------------------

	---@type fun()
	local layoutBar

	-- The room the panel hands over, bottom-left to top-right, and the scale: the stat
	-- list down the left, the legend bar along the top, the chart in the rest. The list's
	-- card spans listY1..listY2 when given, so it lines up with the sidebar's beside it;
	-- the bar runs to barX2 when given, past the charts' right edge.
	function page.setLayout(x1, y1, x2, y2, s, listY1, listY2, barX2)
		page.scale = s
		-- Kept so the page can lay itself out again when the list comes or goes without the
		-- panel having a reason to.
		page.layoutArgs = { x1, y1, x2, y2, s, listY1, listY2, barX2 }
		page.listWas = page.listShown()
		local gap = mathFloor(12 * s)
		local listW = page.listShown() and mathFloor(200 * s) or -gap
		local barH = ctx.metrics.rowHeight + mathFloor(8 * s)
		page.rects = {
			list = { x1, listY1 or y1, x1 + mathMax(0, listW), listY2 or y2 },
			-- The bar keeps its place whether the stat list shows or not: the list's card
			-- starts below it.
			bar = { x1, y2 - barH, barX2 or x2, y2 },
			chart = { x1 + listW + gap, y1, x2, y2 - barH - mathFloor(4 * s) },
			-- The sidebar's entry height, so the two lists run level.
			rowH = ctx.metrics.catRowHeight,
			-- A legend square, the block plate's inset from the bar, and the frame around
			-- the picked block.
			square = ctx.metrics.rowHeight - mathFloor(8 * s),
			inset = mathFloor(2 * s),
			frame = mathMax(2, mathFloor(s)),
		}
		local c = page.rects.chart
		---@cast c [number, number, number, number]
		chart:setBounds(c[1], c[2], c[3] - c[1], c[4] - c[2])
		page.rebuildStatList()
		layoutBar()
	end

	-- Where the card of kinds hangs: the rect of the settings row that opens it.
	function page.setKindsAnchor(rect)
		page.kindsAnchor = rect
	end

	-- Whether leaving the unpicked teams off can show anything a highlight does not: not
	-- with two players, where picking one of them already says all there is to say.
	function page.filterOffered()
		local players = 0
		for _, u in ipairs(page.units) do
			players = players + #u.members
		end
		return players > 2
	end

	-- Whether the charts are the picked units alone right now: the switch is on, it means
	-- something in this game, and something is picked.
	local function filtering()
		if not (page.hideUnselected and page.filterOffered()) then
			return false
		end
		for _, u in ipairs(page.units) do
			if isPicked(u) and not isHidden(u) then
				return true
			end
		end
		return false
	end

	-- The switch that leaves the unpicked teams off belongs with the picking: the page draws
	-- it at the end of the legend bar.
	---@type fun(): table?
	local filterToggleRect

	-- Where that switch sits on the bar, for whoever needs to point at it.
	function page.filterToggle()
		return filterToggleRect()
	end

	-- The room the switch and its caption take at the end of the bar, which the team
	-- blocks leave free.
	local function filterReserve()
		if not page.filterOffered() then
			return 0
		end
		local font = ctx.font()
		local label = ctx.i18n("ui.teamStats.graph.hideUnselected")
		local labelW = font and mathFloor(font:GetTextWidth(label) * ctx.metrics.catFs) or mathFloor(90 * page.scale)
		return labelW + mathFloor(38 * page.scale) + ctx.metrics.sidePad + ctx.metrics.rowPad * 2
	end

	function filterToggleRect()
		local r = page.rects
		if not r or not page.filterOffered() then
			return nil
		end
		local togW = mathFloor(38 * page.scale)
		local togH = mathFloor(ctx.metrics.rowHeight * 0.52)
		local cy = mathFloor((r.bar[2] + r.bar[4]) * 0.5)
		local x2 = r.bar[3]
		return { x2 - togW, cy - mathFloor(togH * 0.5), x2, cy - mathFloor(togH * 0.5) + togH }
	end

	function page.setFont(font, fontSize)
		chart:configure({ font = font, fontSize = fontSize })
		page.dirty = true
	end

	local function statRect(i)
		local r = page.rects.list
		local top = r[4] - ctx.metrics.cardLip - (i - 1) * page.rects.rowH
		return r[1], top - page.rects.rowH, r[3], top
	end

	----------------------------------------------------------------
	-- Histories
	----------------------------------------------------------------

	-- Reads what grew since the last time: the engine's entries past the ones held, all
	-- but the live newest, and asks the gadget for the samples past the ones held once
	-- per period. Called by the panel every second while the page is open.
	function page.refresh()
		local grew = false
		local frame = ctx.frame()
		local hub = ctx.hub()
		local period = mathFloor(frame / 450)
		local ask = hub ~= nil and period ~= page.lastPeriod
		for _, ally in ipairs(ctx.allies()) do
			for _, team in ipairs(ally.teams) do
				local teamID = team.id
				local count = ctx.history(teamID)
				local e = page.engine[teamID]
				if not e then
					e = { used = 0, entries = {} }
					page.engine[teamID] = e
				end
				if count and count - 1 > e.used then
					-- Both indices: without the second the engine gives one entry.
					local entries = ctx.history(teamID, e.used + 1, count)
					if entries then
						-- The newest is live; the ones before it are the period's.
						for i = 1, #entries - 1 do
							local entry = entries[i]
							ctx.derive(entry)
							e.entries[#e.entries + 1] = entry
						end
						e.used = e.used + mathMax(0, #entries - 1)
						grew = true
					end
				end
				if ask then
					local g = page.gadget[teamID]
					hub.requestHistory(teamID, (g and #g.frames or 0) + 1)
				end
			end
		end
		if ask then
			page.lastPeriod = period
		end
		if grew then
			page.version = page.version + 1
			page.dirty = true
		end
	end

	-- The gadget's answer, through the panel's subscription.
	function page.receiveHistory(teamID, h)
		if not h or not h.frames or #h.frames == 0 then
			return
		end
		local g = page.gadget[teamID]
		if not g or h.from == 1 then
			g = { frames = {}, values = {} }
			page.gadget[teamID] = g
		elseif h.from ~= #g.frames + 1 then
			-- Out of step with what is held: start over from what came.
			return
		end
		for i = 1, #h.frames do
			g.frames[#g.frames + 1] = h.frames[i]
		end
		for key, run in pairs(h.values) do
			local held = g.values[key]
			if not held then
				held = {}
				g.values[key] = held
			end
			for i = 1, #run do
				held[#held + 1] = run[i]
			end
		end
		page.version = page.version + 1
		page.dirty = true
	end

	-- A team's samples by frame: the engine's entry at that frame with the gadget's
	-- values added to it, or the gadget's alone, so any column can be read off once
	-- derived.
	local function samplesOf(teamID)
		local byFrame = {}
		local e = page.engine[teamID]
		if e then
			for i = 1, #e.entries do
				local entry = e.entries[i]
				local t = {}
				for k, v in pairs(entry) do
					if type(v) == "number" then
						t[k] = v
					end
				end
				byFrame[entry.frame] = t
			end
		end
		local g = page.gadget[teamID]
		if g then
			for i = 1, #g.frames do
				local f = g.frames[i]
				local t = byFrame[f]
				if not t then
					t = {}
					byFrame[f] = t
				end
				for key, run in pairs(g.values) do
					t[key] = run[i]
				end
			end
		end
		return byFrame
	end

	local function rebuildSamples()
		if page.samplesVersion == page.version then
			return
		end
		page.samples = {}
		page.anySamples = false
		for _, ally in ipairs(ctx.allies()) do
			for _, team in ipairs(ally.teams) do
				local samples = samplesOf(team.id)
				page.samples[team.id] = samples
				if next(samples) then
					page.anySamples = true
				end
			end
		end
		page.samplesVersion = page.version
	end

	-- The members' samples summed frame by frame and derived: the value of `key` at
	-- every frame, as { { frame, value }, ... } in frame order. Per minute turns a
	-- running total into the rate between two samples. A clamp bounds the value for the
	-- plot, the point keeping what it really was for the tooltip.
	local function pointsOf(members, key, perMinute, clamp)
		local sums = {}
		for _, teamID in ipairs(members) do
			local samples = page.samples[teamID]
			if samples then
				for frame, t in pairs(samples) do
					local sum = sums[frame]
					if not sum then
						sum = {}
						sums[frame] = sum
					end
					for k, v in pairs(t) do
						sum[k] = (sum[k] or 0) + v
					end
				end
			end
		end
		local frames = {}
		for frame in pairs(sums) do
			frames[#frames + 1] = frame
		end
		tableSort(frames)
		local points = {}
		---@type number?, number
		local previous, previousFrame = nil, 0
		for i = 1, #frames do
			local frame = frames[i]
			local t = sums[frame]
			ctx.derive(t)
			local v = t[key]
			if v and v == v then
				local raw = v
				if clamp then
					v = mathMax(clamp[1], mathMin(clamp[2], v))
				end
				if v ~= mathHuge and v ~= -mathHuge then
					if perMinute then
						if previous then
							local minutes = (frame - previousFrame) / 1800
							points[#points + 1] = { frame, minutes > 0 and (v - previous) / minutes or 0 }
						end
						previous, previousFrame = v, frame
					else
						points[#points + 1] = { frame, v, raw ~= v and raw or nil }
					end
				end
			end
		end
		return points
	end

	----------------------------------------------------------------
	-- Trend lines for the table's cells
	----------------------------------------------------------------

	-- The table draws a small line of each cell's history behind its number. The rows it
	-- wants them for are handed over whenever it rebuilds them ({ key, members } each);
	-- a column's lines are then built for every row at once, so they share one range and
	-- can be read against each other, and kept until a history grows or the rows change.
	---@type { sig: string, rows: table[], version: integer, lines: table<string, table> }
	local trend = { sig = "", rows = {}, version = -1, lines = {} }

	function page.setTrendRows(list)
		local parts = {}
		for _, row in ipairs(list) do
			parts[#parts + 1] = row.key .. "=" .. table.concat(row.members, ".")
		end
		local sig = table.concat(parts, "|")
		if sig ~= trend.sig then
			trend.sig, trend.rows, trend.lines = sig, list, {}
		end
	end

	-- Every row's run of one column, normalised into the unit square: x is the game time
	-- across every row's samples, y the value against the range the rows share (a running
	-- total measured from zero, anything else from its own floor).
	local function trendLines(key, perMinute)
		if trend.version ~= page.version then
			trend.version, trend.lines = page.version, {}
		end
		local cacheKey = key .. (perMinute and "/m" or "")
		local held = trend.lines[cacheKey]
		if held then
			return held
		end
		rebuildSamples()
		local column = ctx.COLUMNS[key]
		local runs = {}
		local xMin, xMax = mathHuge, -mathHuge
		local yMin, yMax = mathHuge, -mathHuge
		for _, row in ipairs(trend.rows) do
			local points = pointsOf(row.members, key, perMinute, column and column.clamp)
			if #points > 1 then
				runs[row.key] = points
				for _, p in ipairs(points) do
					xMin, xMax = mathMin(xMin, p[1]), mathMax(xMax, p[1])
					yMin, yMax = mathMin(yMin, p[2]), mathMax(yMax, p[2])
				end
			end
		end
		local lines = {}
		if xMax > xMin then
			-- A running total is read against zero; a rate or a level against its own floor.
			local lo = (column and column.fmt == "si" and not perMinute) and mathMin(0, yMin) or yMin
			local span = yMax - lo
			for rowKey, points in pairs(runs) do
				local line = {}
				for _, p in ipairs(points) do
					line[#line + 1] = (p[1] - xMin) / (xMax - xMin)
					line[#line + 1] = span > 0 and (p[2] - lo) / span or 0.5
				end
				lines[rowKey] = line
			end
		end
		trend.lines[cacheKey] = lines
		return lines
	end

	-- One cell's line, drawn into the rect the table gives it. Called from the panel's
	-- bake, so the run is walked once per rebuild, not once per frame.
	function page.drawTrend(rowKey, key, perMinute, x1, y1, x2, y2, color, width)
		local line = trendLines(key, perMinute)[rowKey]
		if not line or #line < 4 then
			return false
		end
		local w, h = x2 - x1, y2 - y1
		if w <= 2 or h <= 2 then
			return false
		end
		if gl.Smoothing then
			gl.Smoothing(false, true, false)
		end
		gl.LineWidth(width or 1)
		gl.Color(color[1], color[2], color[3], color[4] or 0.5)
		gl.BeginEnd(GL.LINE_STRIP, function()
			for i = 1, #line, 2 do
				gl.Vertex(x1 + line[i] * w, y1 + line[i + 1] * h)
			end
		end)
		gl.LineWidth(1)
		if gl.Smoothing then
			gl.Smoothing(false, false, false)
		end
		gl.Color(1, 1, 1, 1)
		return true
	end

	----------------------------------------------------------------
	-- Series and the legend bar
	----------------------------------------------------------------

	-- What a series stands for: an ally team with the grouping switch on, a team without.
	-- In a fixed order, ally teams by id and teams by id, the way the player list has
	-- them, whatever the table is sorted by.
	function page.rebuildUnits()
		local allies = {}
		for _, ally in ipairs(ctx.allies()) do
			local teams = {}
			for _, team in ipairs(ally.teams) do
				teams[#teams + 1] = team
			end
			tableSort(teams, function(a, b)
				return a.id < b.id
			end)
			allies[#allies + 1] = { id = ally.id, teams = teams }
		end
		tableSort(allies, function(a, b)
			return a.id < b.id
		end)

		-- Both ways every time: the bar groups one way, and a custom graph may be drawn the
		-- other.
		local allyUnits, playerUnits = {}, {}
		local byKey = {}
		for _, ally in ipairs(allies) do
			local first = ally.teams[1]
			local members = {}
			local isLocal = false
			for _, team in ipairs(ally.teams) do
				members[#members + 1] = team.id
				isLocal = isLocal or team.isLocal == true
			end
			local unit = {
				key = "ally" .. ally.id,
				allyID = ally.id,
				name = ctx.i18n("ui.teamStats.team", { number = ally.id + 1 }),
				color = first and { first.accent[1], first.accent[2], first.accent[3] } or { 0.8, 0.8, 0.8 },
				members = members,
				teams = ally.teams,
				isLocal = isLocal,
			}
			allyUnits[#allyUnits + 1] = unit
			byKey[unit.key] = unit
			for _, team in ipairs(ally.teams) do
				local player = {
					key = "team" .. team.id,
					allyID = ally.id,
					teamID = team.id,
					name = team.name,
					color = { team.accent[1], team.accent[2], team.accent[3] },
					members = { team.id },
					teams = { team },
					isLocal = team.isLocal,
					quiet = team.dead or team.gone,
				}
				playerUnits[#playerUnits + 1] = player
				byKey[player.key] = player
			end
		end
		page.allyUnits, page.playerUnits = allyUnits, playerUnits
		local units = grouped() and allyUnits or playerUnits
		page.units = units
		page.unitByKey = byKey

		-- The selection and the hidden set, player by player: a whole ally team's key is
		-- taken apart into its players, which loses nothing whichever way the bar or a graph
		-- groups them. A player no longer listed drops out.
		local function perPlayer(set)
			local out = {}
			for key in pairs(set) do
				local unit = byKey[key]
				for _, team in ipairs(unit and unit.teams or {}) do
					out["team" .. team.id] = true
				end
			end
			return out
		end
		page.selected = perPlayer(page.selected)
		page.hidden = perPlayer(page.hidden)
		-- A spectator switching the team they watch: a selection that was that team alone,
		-- or its whole ally team, goes with them as the first selection did; one they picked
		-- themselves stays.
		---@type table?
		local viewer = nil
		for _, ally in ipairs(allies) do
			for _, team in ipairs(ally.teams) do
				if team.isLocal then
					viewer = team
				end
			end
		end
		local was = page.viewer
		if was and viewer and was.id ~= viewer.id then
			local function teamsOf(allyID)
				local keys = {}
				local unit = byKey["ally" .. allyID]
				for _, team in ipairs(unit and unit.teams or {}) do
					keys["team" .. team.id] = true
				end
				return keys
			end
			---@return boolean
			local function exactly(keys)
				local n, want = 0, 0
				for key in pairs(page.selected) do
					if not keys[key] then
						return false
					end
					n = n + 1
				end
				for _ in pairs(keys) do
					want = want + 1
				end
				return n > 0 and n == want
			end
			local wasTeam = exactly({ ["team" .. was.id] = true })
			local wasAlly = exactly(teamsOf(was.allyID))
			if wasAlly and (grouped() or not wasTeam) then
				page.selected = teamsOf(viewer.allyID)
			elseif wasTeam then
				page.selected = { ["team" .. viewer.id] = true }
			end
		end
		page.viewer = viewer and { id = viewer.id, allyID = viewer.allyID } or nil
		-- The first selection is the viewer's own unit - unless Hide unselected is on, when
		-- every chart would open on them alone in every game; a cleared one stays cleared.
		if not page.selectionSet then
			page.selectionSet = true
			if not page.hideUnselected then
				for _, unit in ipairs(units) do
					if unit.isLocal then
						setTeams(page.selected, unit, true)
					end
				end
			end
		end
		layoutBar()
	end

	-- The legend bar: the All button first, then a button per ally team, its caption and
	-- its members as squares of their colour side by side. Captions stay while the whole
	-- row fits; squares shrink when even that does not. With the grouping switch on the
	-- whole button is the ally team; off, each square is its player and the caption is
	-- only a caption.
	layoutBar = function()
		local r = page.rects
		if not r then
			return
		end
		local pad = ctx.metrics.sidePad
		local fs = ctx.metrics.catFs
		local font = ctx.font()
		local function widthOf(label)
			return font and mathFloor(font:GetTextWidth(label) * fs) or #label * fs * 0.55
		end
		local all = { all = true, label = ctx.i18n("ui.teamStats.graph.all"), members = {} }
		all.labelW = widthOf(all.label)
		---@type table[]
		local blocks = { all }
		-- Whoever is playing gets their own team a press away, beside All - unless every
		-- side is one player, when their own block already carries their name.
		---@type table?
		local mine = nil
		for _, unit in ipairs(page.units) do
			if unit.isLocal and not ctx.soloTeams then
				mine = unit
			end
		end
		if mine then
			local me = { me = true, unit = mine, label = ctx.i18n("ui.teamStats.graph.you"), members = {} }
			me.labelW = widthOf(me.label)
			blocks[#blocks + 1] = me
		end
		local youLabel = ctx.i18n("ui.teamStats.graph.you")
		local seen = {}
		for _, unit in ipairs(page.units) do
			for _, team in ipairs(unit.teams) do
				local block = seen[team.allyID]
				if not block then
					-- A side of one is named after its player, and the viewer's own - playing
					-- or watching it - is "You".
					local label = ctx.i18n("ui.teamStats.team", { number = team.allyID + 1 })
					if ctx.soloTeams then
						label = team.isLocal and youLabel or team.name
					end
					block = {
						ally = team.allyID,
						label = label,
						members = {},
						unit = grouped() and unit or nil,
					}
					-- The caption when the name does not fit: a team's number; in a game of
					-- sides of one only the viewer's "You" is kept.
					if not ctx.soloTeams then
						block.short = tostring(team.allyID + 1)
					elseif team.isLocal then
						block.short = youLabel
					end
					seen[team.allyID] = block
					blocks[#blocks + 1] = block
				end
				block.members[#block.members + 1] = { team = team, unit = unit }
			end
		end
		local count, labelW, shortW = 0, 0, 0
		local teamBlocks = 0
		for i = 1, #blocks do
			local b = blocks[i]
			if not b.all and not b.me then
				count = count + #b.members
				b.labelW = widthOf(b.label)
				labelW = labelW + b.labelW + pad
				if b.short then
					b.shortW = widthOf(b.short)
					shortW = shortW + b.shortW + pad
				end
				teamBlocks = teamBlocks + 1
			end
		end
		-- The All button always keeps its caption; the team blocks share what is left once
		-- the switch at the end of the bar has its room.
		local fixed = all.labelW + pad * 3 + (blocks[2] and blocks[2].me and blocks[2].labelW + r.square + pad * 3 or 0)
		local avail = r.bar[3] - r.bar[1] - pad * 2 - fixed - filterReserve()
		local square = r.square
		-- What a crowded bar gives up, in turn: first the room between the teams, then the
		-- names - a team keeps its number, the viewer in a free-for-all their "You", as long
		-- as the squares keep half their width beside it - then every caption. The squares
		-- keep their height and give up width to what is left, so the row never runs into
		-- the switch at its end.
		local fullSep, minSep = pad * 2, mathMax(4, mathFloor(pad * 0.5))
		local function sepFor(captionW, width)
			return (avail - count * width - captionW) / mathMax(1, teamBlocks)
		end
		---@type string?, number
		local captions, captionW = "full", labelW
		if sepFor(labelW, square) < minSep then
			if shortW > 0 and sepFor(shortW, mathMax(4, mathFloor(square * 0.5))) >= minSep then
				captions, captionW = "short", shortW
			else
				captions, captionW = nil, 0
			end
		end
		---@type number
		local sep = mathMax(minSep, mathMin(fullSep, mathFloor(sepFor(captionW, square))))
		---@type number
		local width = square
		if count * width + teamBlocks * sep + captionW > avail then
			width = mathMax(2, mathFloor((avail - teamBlocks * sep - captionW) / mathMax(1, count)))
		end
		local items = {}
		local x = r.bar[1] + pad
		local cy = mathFloor((r.bar[2] + r.bar[4]) * 0.5)
		local y1 = cy - mathFloor(square * 0.5)
		local y2 = y1 + square
		local half = mathFloor(pad * 0.5)
		-- A team's plate reaches a little past its squares, and stops short of the next.
		local margin = mathMax(1, mathMin(half, mathFloor(sep * 0.5) - 1))
		for _, b in ipairs(blocks) do
			local fixedBlock = b.all or b.me
			local air = fixedBlock and half or margin
			b.x1 = x - air
			if fixedBlock then
				b.labelX = x
				x = x + b.labelW
				if b.me then
					-- Your own colour beside the caption, the same square the teams get.
					x = x + half
					b.swatch = { x, y1, x + square, y2 }
					x = x + square
				end
			else
				local caption = captions == "full" and b.label or (captions == "short" and b.short or nil)
				if caption then
					b.labelX = x
					b.caption = caption
					x = x + (captions == "full" and b.labelW or b.shortW) + pad
				end
				for _, member in ipairs(b.members) do
					items[#items + 1] =
						{ unit = member.unit, team = member.team, block = b, x1 = x, y1 = y1, x2 = x + width, y2 = y2 }
					x = x + width
				end
			end
			b.x2 = x + air
			x = x + (fixedBlock and pad * 2 or sep)
		end
		-- A press between two plates goes to the nearer one: the gaps are split between them,
		-- so there is nowhere along the row that picks nothing.
		for i = 1, #blocks do
			local b = blocks[i]
			local before, after = blocks[i - 1], blocks[i + 1]
			b.hx1 = before and mathFloor((before.x2 + b.x1) * 0.5) or b.x1
			b.hx2 = after and mathFloor((b.x2 + after.x1) * 0.5) or b.x2
		end
		page.barBlocks = blocks
		page.barItems = items
		page.barLabels = captions ~= nil
		page.barShort = captions == "short"
		page.barY1, page.barY2 = y1, y2
		page.gen = page.gen + 1
	end

	-- The units not hidden from the chart, of the bar's or of the list given.
	local function shownUnits(of)
		---@type table[]
		local list = {}
		for _, u in ipairs(of or page.units) do
			if not isHidden(u) then
				list[#list + 1] = u
			end
		end
		return list
	end

	-- The selected units among the shown.
	local function pickedUnits(of)
		---@type table[]
		local list = {}
		for _, u in ipairs(of or page.units) do
			if isPicked(u) and not isHidden(u) then
				list[#list + 1] = u
			end
		end
		return list
	end

	-- Whether % of total has anything to share out: two units or more on the charts. One
	-- team picked with Hide unselected on would be all of its own total.
	-- An open chart of a ratio or a level - or one that is not a column's - has no total to
	-- take a part of either.
	function page.shareApplies()
		local key = page.zoom or page.stat
		if page.zoom then
			local column = ctx.COLUMNS[statOf(key)]
			if not (column and column.fmt == "si") then
				return false
			end
		end
		local units = unitsFor(settingsOf(key))
		local plotted = filtering() and pickedUnits(units) or shownUnits(units)
		return #plotted > 1
	end

	-- Whether the picked stat is drawn over game time: the profile and the composition
	-- answer differently, and the panel asks before it lays the switches out.
	function page.overTime()
		return statOf(page.stat) ~= "profile"
	end

	-- Whether the milestones switch means anything: the timeline is made of them.
	function page.milestonesOwn()
		return statOf(page.stat) == "timeline"
	end

	-- The units a chart is about, named for its title: every team, one by name, or how many.
	local function namesOf(list)
		if #list == #page.units then
			return ctx.i18n("ui.teamStats.graph.all")
		elseif #list == 1 then
			return list[1].name
		end
		return ctx.i18n(grouped() and "ui.teamStats.graph.teams" or "ui.teamStats.graph.players", { count = #list })
	end

	-- The milestones of these units' players as pictures on the chart, each framed in its
	-- player's colour, on the unit's series where `indexByKey` names one, else in the lane.
	-- The hover text says whose it was, in their colour, then when and what.
	-- Where a timeline's lanes sit, and how close two pictures may be in x before one has
	-- to move out of the other's way. Filled in while the timeline is built.
	---@type table<string, number>
	local lanes = {}
	local timelineGap = 0

	-- The rows a lane's pictures take, alternating above and below its line so the team
	-- keeps its height: the first free row whose last picture is far enough behind.
	local LANE_ROWS = { 0, 0.24, -0.24, 0.12, -0.12, 0.36, -0.36 }

	-- Whether a kind of milestone says anything about the column being charted.
	local function kindFits(kind, column, off)
		if off[kind] then
			return false
		end
		local groups = MILESTONE_GROUPS[kind]
		if not groups or groups.always then
			return true
		end
		-- A chart that is not one column's (the composition, the profile) takes them all.
		return column == nil or groups[column.group] == true
	end

	local function milestoneMarkers(list, indexByKey, always, column, settings)
		local markers = {}
		local live = ctx.live()
		if not live or not (always or settings.milestones) then
			return markers
		end
		for _, unit in ipairs(list) do
			-- One set of rows per unit: its lane is its own.
			local taken = {}
			for _, team in ipairs(unit.teams) do
				local teamLive = live[team.id]
				for _, m in ipairs(teamLive and teamLive.milestones or {}) do
					-- Kinds switched off in the milestone settings never make a marker.
					if kindFits(m.key, column, settings.off) then
						local ud = m.unitDefID and UnitDefs[m.unitDefID] or nil
						---@cast ud table?
						local label = ctx.L.milestone[m.key] or m.key
						if ud then
							label = label .. " (" .. (ud.translatedHumanName or ud.name) .. ")"
						end
						local whose = (team.nameColor or "") .. team.name
						local what = ctx.colors.title .. Graph.frameLabel(m.frame) .. "  " .. label
						local lane = lanes[unit.key]
						local y = nil
						if lane then
							-- The first row of the lane this one is clear of.
							local row = 1
							while row < #LANE_ROWS and (taken[row] or -mathHuge) > m.frame - timelineGap do
								row = row + 1
							end
							taken[row] = m.frame
							y = lane + (LANE_ROWS[row] or 0)
						end
						markers[#markers + 1] = {
							x = m.frame,
							y = y,
							texture = ud and ("#" .. m.unitDefID) or nil,
							text = whose .. "\n" .. what,
							series = indexByKey and indexByKey[unit.key] or nil,
							frame = { team.accent[1], team.accent[2], team.accent[3] },
						}
					end
				end
			end
		end
		return markers
	end

	-- What a unit is worth on each profile axis right now: its teams' current stats added
	-- up, the way the table's band totals are.
	-- The chart's series from the pick and the switches. The same rules for every kind:
	-- hidden units are left out; with Hide unselected on and a selection, only the selected
	-- are plotted, otherwise every shown unit is, the selected ones lit and on top and the
	-- rest faded; the milestones are the selection's, every plotted unit's when nothing is
	-- selected. A composition is one whole, so it is the selection's summed (every shown
	-- team's without one). % of total stacks every plotted unit into one whole - ally
	-- teams against each other while grouped, players otherwise - when there are two or more
	-- to share it.
	local function profileValues(unit)
		local values = {}
		for ai, axis in ipairs(page.profileAxes) do
			local sum = 0
			for _, team in ipairs(unit.teams) do
				local v = team.stats and team.stats[axis.key]
				if v and v == v then
					sum = sum + v
				end
			end
			values[ai] = sum
		end
		return values
	end

	-- The charts a grid page draws, kept and reconfigured rather than made and freed
	-- every time the page is scrolled or the grid resized.
	---@type table[]
	local pool = {}

	-- A line per plotted unit of one column, and which of them the selection lifts.
	local function lineSeries(column, plotted)
		local series = {}
		---@type table<integer, boolean>
		local lifted = {}
		for _, u in ipairs(plotted) do
			series[#series + 1] = {
				name = u.name,
				color = u.color,
				points = pointsOf(u.members, column.key, false, column.clamp),
				width = 2,
			}
			lifted[#series] = isPicked(u)
		end
		return series, lifted
	end

	-- What a chart of one stat is made of: the same rules for the big chart and for every
	-- small one in the grid. `small` leaves out what a little chart has no room for.
	-- Returns whether it came out empty.
	local function fillChart(target, key, small)
		local statKey, settings = statOf(key), settingsOf(key)
		local column = ctx.COLUMNS[statKey]
		local units = unitsFor(settings)
		local shown = shownUnits(units)
		local picked = pickedUnits(units)
		local anyPicked = #picked > 0
		-- Hide unselected leaves the rest off; otherwise the pick only stands out.
		---@type table[]
		local plotted = filtering() and picked or shown
		-- Something stands out only while the selection is not everything plotted.
		local lifts = anyPicked and #picked < #plotted
		local marked = anyPicked and picked or plotted
		local series, markers = {}, {}
		local kind = "line"
		local title
		local yFormat = nil
		---@type table<integer, boolean>
		local lifted = {}
		local ownLegend = false

		lanes, timelineGap = {}, 0
		target.cfg.valueBands = nil
		if statKey == "timeline" then
			-- A lane per team, drawn from the first frame to now, with its milestones on
			-- it: what happened to whom, and when. Every team gets the same height, and
			-- pictures that fall close together are stacked into the room around the line
			-- rather than piled on one spot.
			local n = #plotted
			local frame = mathMax(1, ctx.frame())
			local indexByKey = {}
			for i, u in ipairs(plotted) do
				local lane = n - i + 1
				series[#series + 1] = {
					name = u.name,
					color = u.color,
					points = { { 0, lane }, { frame, lane } },
					width = 2,
				}
				indexByKey[u.key] = #series
				lanes[u.key] = lane
				lifted[#series] = isPicked(u)
			end
			-- A faint band of the team's colour behind each lane.
			local bands = {}
			for i, u in ipairs(plotted) do
				local lane = n - i + 1
				bands[#bands + 1] = {
					-- A little short of the next lane, so there is a gap between the teams.
					from = lane - 0.42,
					to = lane + 0.42,
					color = { u.color[1], u.color[2], u.color[3], 0.1 },
				}
			end
			target.cfg.valueBands = bands
			-- How far apart two pictures have to be in game frames not to overlap, from the
			-- room the chart has for the whole game.
			local plotW = page.rects and (page.rects.chart[3] - page.rects.chart[1]) * 0.8 or 600
			timelineGap = frame / mathMax(1, plotW / mathMax(8, mathFloor(ctx.metrics.rowFs * 2.6)))
			-- The lanes are named down the axis, and there is a clear row above and below.
			target.cfg.yMin, target.cfg.yMax, target.cfg.gridLines = 0, n + 1, n + 1
			yFormat = function(v)
				if small then
					-- No room beside a small chart: the bands say whose lane is whose.
					return ""
				end
				local u = plotted[n - mathFloor(v + 0.5) + 1]
				return u and u.name or ""
			end
			markers = milestoneMarkers(plotted, indexByKey, true, nil, settings)
			title = ctx.i18n("ui.teamStats.graph.timeline")
		elseif statKey == "profile" then
			kind = "radar"
			ownLegend = true
			local axes = {}
			for _, axis in ipairs(PROFILE_AXES) do
				if ctx.gadgetOn() or not axis.gadget then
					-- The full caption: three axes are called "produced" on their own.
					axes[#axes + 1] = { key = axis.key, label = ctx.columnTitle(ctx.COLUMNS[axis.key]) }
				end
			end
			page.profileAxes = axes
			-- Every axis is measured against the best shown team, drawn or not: a wheel of
			-- one team measured against itself would be full on every axis.
			for _, u in ipairs(shown) do
				for ai, v in ipairs(profileValues(u)) do
					axes[ai].max = mathMax(axes[ai].max or 0, v)
				end
			end
			for _, axis in ipairs(axes) do
				if not axis.max or axis.max <= 0 then
					axis.max = nil
				end
			end
			for _, u in ipairs(plotted) do
				series[#series + 1] = { name = u.name, color = u.color, values = profileValues(u), width = 2 }
				lifted[#series] = isPicked(u)
			end
			-- The axis names need room; a small wheel is read by its shape.
			target:configure({ radar = { axes = axes, rings = 4, fill = true, labels = not small } })
			title = ctx.i18n("ui.teamStats.graph.profile")
		elseif statKey == "composition" then
			kind = "stacked"
			ownLegend = true
			local of = anyPicked and picked or shown
			local members = {}
			for _, u in ipairs(of) do
				for _, teamID in ipairs(u.members) do
					members[#members + 1] = teamID
				end
			end
			local group = ctx.groupByKey.composition
			local bi = 0
			for i = 1, #group.columns do
				local c = ctx.COLUMNS[group.columns[i]]
				-- The buckets, not the total that heads the view.
				if c.count and c.group == "value" then
					bi = bi + 1
					series[#series + 1] = {
						name = ctx.L.full[c.key],
						color = BUCKET_COLORS[bi] or { 0.8, 0.8, 0.8 },
						points = pointsOf(members, c.key, false),
					}
				end
			end
			lifts = false
			title = ctx.i18n("ui.teamStats.graph.composition") .. " \194\183 " .. namesOf(of)
			markers = milestoneMarkers(of, nil, false, nil, settings)
		elseif column and settings.share and column.fmt == "si" and #plotted > 1 then
			-- Everything on the chart as one whole, each unit its share of it: ally teams
			-- against each other while grouped, players otherwise. One unit alone would be
			-- all of it, so it keeps its line.
			kind = "stacked"
			for _, u in ipairs(plotted) do
				series[#series + 1] = {
					name = u.name,
					color = u.color,
					points = pointsOf(u.members, column.key, false),
				}
				lifted[#series] = isPicked(u)
			end
			title = ctx.columnTitle(column) .. " \194\183 " .. ctx.L.switch.shareOfTotal
			markers = milestoneMarkers(marked, nil, false, column, settings)
		elseif column then
			local indexByKey = {}
			series, lifted = lineSeries(column, plotted)
			for i, u in ipairs(plotted) do
				indexByKey[u.key] = i
			end
			title = ctx.columnTitle(column)
			-- % of total set with one team or player on the chart, all of its own total: the
			-- line stays, and the title still says what is set, faded, rather than dropping it.
			if settings.share and column.fmt == "si" then
				title = title .. ctx.colors.faded .. " \194\183 " .. ctx.L.switch.shareOfTotal
			end
			if column.fmt == "percent" then
				yFormat = percentFormat
			end
			markers = milestoneMarkers(marked, indexByKey, false, column, settings)
		end

		local empty = true
		for _, s in ipairs(series) do
			-- A run over time carries points; the profile's wheel carries a value per axis.
			if #(s.points or s.values or {}) > 0 then
				empty = false
			end
		end
		-- The bands of the composition chart are named by the chart itself; teams are
		-- named by the legend bar. The axis format is set straight: a nil handed to
		-- configure would leave the last one.
		if statKey ~= "timeline" then
			target.cfg.yMin, target.cfg.yMax, target.cfg.gridLines = nil, nil, small and 2 or 4
		end
		-- Every chart over time runs from the start of the game, whenever its own samples
		-- begin, so they can be read against each other.
		target.cfg.xMin = 0
		target.cfg.yFormat = yFormat
		target:configure({
			kind = kind,
			title = title,
			legend = ownLegend and not small,
			bandLabels = ownLegend and not small,
			xTicks = small and 2 or 5,
		})
		target:setSeries(series)
		target:setMarkers((small and statKey ~= "timeline") and {} or markers)
		target:setHighlight(lifts and lifted or nil)
		return empty
	end

	-- Whether the page is showing a grid of charts rather than one: more than one per page
	-- and none opened on its own.
	function page.gridded()
		return page.zoom == nil
	end

	-- The next grid in the list, or the one before it, wrapping round either way; the
	-- scroll goes back to the top.
	function page.cyclePerPage(back)
		local at = 1
		for i, spec in ipairs(PAGES) do
			if spec.n == page.perPage then
				at = i
			end
		end
		local step = back and -1 or 1
		local next_ = PAGES[(at - 1 + step) % #PAGES + 1]
		---@cast next_ -?
		page.perPage = next_.n
		page.scroll, page.zoom = 0, nil
		page.dirty = true
		page.gen = page.gen + 1
	end

	local function pageSpec()
		for _, spec in ipairs(PAGES) do
			if spec.n == page.perPage then
				return spec
			end
		end
		return PAGES[1]
	end

	-- The grid's cells, left to right and top to bottom over the chart's room.
	local function gridCells(spec)
		local r = page.rects
		---@type [number, number, number, number][]
		local cells = {}
		if not r then
			return cells
		end
		local x1, y1, x2, y2 = r.chart[1], r.chart[2], r.chart[3], r.chart[4]
		local gap = mathFloor(8 * page.scale)
		local w = mathFloor(((x2 - x1) - gap * (spec.cols - 1)) / spec.cols)
		local h = mathFloor(((y2 - y1) - gap * (spec.rows - 1)) / spec.rows)
		for i = 1, spec.cols * spec.rows do
			local col = (i - 1) % spec.cols
			local row = mathFloor((i - 1) / spec.cols)
			local cx = x1 + col * (w + gap)
			local cy = y2 - (row + 1) * h - row * gap
			cells[i] = { cx, cy, cx + w, cy + h }
		end
		return cells
	end

	-- The charts of the page the grid is scrolled to, built into the pool.
	function page.buildGrid()
		local spec = pageSpec()
		---@type table[]
		local list = {}
		for _, entry in ipairs(page.statList) do
			if entry.key and not entry.back and not entry.divider then
				list[#list + 1] = entry
			end
		end
		local cells = gridCells(spec)
		local rows = math.ceil(#list / spec.cols)
		page.maxScroll = mathMax(0, rows - spec.rows)
		page.scroll = mathMax(0, mathMin(page.scroll, page.maxScroll))
		local first = page.scroll * spec.cols + 1
		local last = mathMin(#list, first + spec.cols * spec.rows - 1)
		local fs = mathMax(8, mathFloor(ctx.metrics.rowFs * (spec.cols > 3 and 0.8 or 0.9)))
		page.miniCharts = {}
		for i = first, last do
			local entry = list[i]
			---@cast entry -?
			local slot = i - first + 1
			local cell = cells[slot]
			---@cast cell -?
			local chartOf = pool[slot]
			if not chartOf then
				chartOf = Graph.new({
					kind = "line",
					legend = false,
					xUnit = "frames",
					lineWidth = 2,
					includeZero = true,
					look = { plotFill = { 0, 0, 0, 0.16 } },
				})
				pool[slot] = chartOf
			end
			fillChart(chartOf, entry.key, true)
			-- A column's chart says itself whether its % of total is on it; the others take
			-- their short name from the list.
			local setup = { font = ctx.font(), fontSize = fs }
			if not ctx.COLUMNS[statOf(entry.key)] then
				setup.title = entry.label
			end
			chartOf:configure(setup)
			chartOf:setBounds(cell[1], cell[2], cell[3] - cell[1], cell[4] - cell[2])
			page.miniCharts[slot] = { chart = chartOf, key = entry.key, rect = cell, index = i }
		end
		page.first, page.last = first, last
	end

	function page.scrollExtent()
		local spec = pageSpec()
		local r = page.rects
		if not page.gridded() or not r or page.maxScroll <= 0 then
			return 0, 0, 0
		end
		local rowH = (r.chart[4] - r.chart[2]) / spec.rows
		return (page.maxScroll + spec.rows) * rowH, page.scroll * rowH, rowH
	end

	-- The bar dragged to an offset in pixels: the nearest row of the grid.
	function page.setScrollPixels(offset)
		local _, _, rowH = page.scrollExtent()
		if rowH <= 0 then
			return
		end
		local to = mathMax(0, mathMin(page.maxScroll, mathFloor(offset / rowH + 0.5)))
		if to ~= page.scroll then
			page.scroll = to
			page.dirty = true
			page.gen = page.gen + 1
		end
	end

	function page.build()
		-- The list takes room from the charts, so opening or closing one lays the page out
		-- again before anything is drawn.
		local args = page.layoutArgs
		if args and page.listWas ~= page.listShown() then
			page.setLayout(args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8])
		end
		rebuildSamples()
		page.rebuildUnits()
		if page.gridded() then
			page.buildGrid()
			page.empty = #page.statList == 0
		else
			page.empty = fillChart(chart, page.zoom or page.stat)
		end
		page.dirty = false
	end

	----------------------------------------------------------------
	-- Drawing
	----------------------------------------------------------------

	-- Four whole-pixel bars around a rect.
	local function frame(x1, y1, x2, y2, w, color)
		local Color, Rect = ctx.draw.Color, ctx.draw.Rect
		Color(color[1], color[2], color[3], color[4])
		Rect(x1, y1, x2, y1 + w)
		Rect(x1, y2 - w, x2, y2)
		Rect(x1, y1, x1 + w, y2)
		Rect(x2 - w, y1, x2, y2)
	end

	-- Whether a block of the bar is lit: All while nothing is selected; an ally team's
	-- while it is selected, or every one of its players is.
	local function blockLit(b)
		if b.all then
			return #pickedUnits() == 0
		end
		if b.me then
			local picked = pickedUnits()
			return #picked == 1 and picked[1] == b.unit and allPicked(b.unit)
		end
		if #b.members == 0 then
			return false
		end
		for _, m in ipairs(b.members) do
			if not teamIn(page.selected, m.team) or teamIn(page.hidden, m.team) then
				return false
			end
		end
		return true
	end

	-- What is baked into the panel's list: the stat list on a card like the sidebar's,
	-- and the legend bar.
	function page.drawPanel()
		local r = page.rects
		if not r then
			return
		end
		local look, colors, metrics = ctx.look, ctx.colors, ctx.metrics
		local RectRound, Highlight, Color, Rect = ctx.draw.RectRound, ctx.draw.Highlight, ctx.draw.Color, ctx.draw.Rect
		local fs = metrics.catFs
		local cs = metrics.csSmall

		-- The card and its stats, while the page is showing one chart; a grid names its
		-- charts itself and takes the room instead.
		if page.listShown() then
			RectRound(
				r.list[1],
				r.list[2],
				r.list[3],
				r.list[4],
				metrics.csPanel,
				1,
				1,
				1,
				1,
				look.sidebarFill,
				look.sidebarFillTop
			)
		end
		for i, entry in ipairs(page.listShown() and page.statList or {}) do
			local x1, y1, x2, y2 = statRect(i)
			if entry.divider then
				local y = mathFloor((y1 + y2) * 0.5)
				RectRound(x1 + metrics.sidePad, y, x2 - metrics.sidePad, y + 1, 0, 0, 0, 0, 0, look.rule)
			else
				-- The way back to the grid is never the pick; it is where the pick came from.
				local selected = not entry.back and entry.key == (page.zoom or page.stat)
				if selected then
					RectRound(x1 + metrics.catInset, y1, x2 - metrics.catInset, y2, cs, 1, 1, 1, 1, look.selectedFill)
				elseif i == page.hover.stat then
					Highlight(
						x1 + metrics.catInset,
						y1,
						x2 - metrics.catInset,
						y2,
						cs,
						look.rowHoverOpacity,
						look.white
					)
				end
				local label = ctx.text.fit(ctx.font(), entry.label, x2 - x1 - metrics.sidePad * 2, fs)
				ctx.queueText(
					(selected and colors.selected or colors.dim) .. label,
					x1 + metrics.sidePad,
					mathFloor((y1 + y2) * 0.5),
					fs,
					"ov"
				)
			end
		end

		-- The legend bar: a plate per block like a button, lit and framed warm when it is
		-- selected as a whole, then its caption and squares. A selected square stands at
		-- full strength inside a warm frame (neighbours share one), the others fade while
		-- anything is selected, and a hidden one is only an outline.
		local isGrouped = grouped()
		local anyPicked = #pickedUnits() > 0
		local dropping = filtering()
		local cy = mathFloor((r.bar[2] + r.bar[4]) * 0.5)
		local py1, py2 = r.bar[2] + r.inset, r.bar[4] - r.inset
		local fw = r.frame
		for i, b in ipairs(page.barBlocks) do
			local lit = blockLit(b)
			b.lit = lit
			RectRound(b.x1, py1, b.x2, py2, cs, 1, 1, 1, 1, lit and look.selectedFill or PLATE)
			if lit then
				-- A frame that follows the plate's corners.
				ctx.draw.RectRoundOutline(b.x1, py1, b.x2, py2, cs, fw, 1, 1, 1, 1, PICKED_FRAME, PICKED_FRAME)
			end
			-- Without the grouping a square is its player, so the plate lights only for its
			-- caption, which stands for the whole ally team. A lit plate lights further.
			if i == page.hover.block and (isGrouped or b.all or page.hover.legend == 0) then
				Highlight(b.x1, py1, b.x2, py2, cs, look.barHoverOpacity, look.white)
			end
			if b.labelX then
				ctx.queueText((lit and colors.selected or colors.dim) .. (b.caption or b.label), b.labelX, cy, fs, "ov")
			end
			if b.swatch and b.unit then
				local c = b.unit.color
				Color(c[1], c[2], c[3], (lit or i == page.hover.block) and 1 or 0.85)
				Rect(b.swatch[1], b.swatch[2], b.swatch[3], b.swatch[4])
			end
		end
		-- What a press would act on: the square under the cursor, or every square of the
		-- block while grouped or on its caption.
		local hoverBlock = page.barBlocks[page.hover.block]
		for i, item in ipairs(page.barItems) do
			local c = item.team.accent
			local picked, hidden = isPicked(item.unit), isHidden(item.unit)
			local hovered = i == page.hover.legend
				or (hoverBlock ~= nil and item.block == hoverBlock and (isGrouped or page.hover.legend == 0))
			item.hovered = hovered
			-- Hidden, or left off by Hide unselected: either way not on the chart.
			if hidden or (dropping and not picked) then
				Color(c[1], c[2], c[3], hovered and 0.4 or 0.12)
				Rect(item.x1, item.y1, item.x2, item.y2)
				frame(item.x1, item.y1, item.x2, item.y2, 1, { c[1], c[2], c[3], 0.55 })
			else
				local alpha = (anyPicked and not picked) and 0.3 or 0.9
				Color(c[1], c[2], c[3], hovered and 1 or alpha)
				Rect(item.x1, item.y1, item.x2, item.y2)
			end
		end
		-- Hide unselected at the end of the bar, captioned like a settings row.
		local tog = filterToggleRect()
		if tog then
			local label = ctx.i18n("ui.teamStats.graph.hideUnselected")
			local hovered = page.hover.filter == 1
			ctx.queueText(
				(page.hideUnselected and colors.selected or colors.dim) .. label,
				tog[1] - metrics.rowPad,
				cy,
				fs,
				"rov"
			)
			ctx.draw.Toggle(tog[1], tog[2], tog[3], tog[4], page.hideUnselected, hovered)
		end

		if not isGrouped then
			---@type table?, table?
			local first, last = nil, nil
			local function frameRun()
				if first and last then
					frame(first.x1 - fw, page.barY1 - fw, last.x2 + fw, page.barY2 + fw, fw, PICKED_FRAME)
				end
				first, last = nil, nil
			end
			for _, item in ipairs(page.barItems) do
				local on = isPicked(item.unit) and not isHidden(item.unit) and not item.block.lit
				if on and first and first.block == item.block then
					last = item
				else
					frameRun()
					if on then
						first, last = item, item
					end
				end
			end
			frameRun()
		end
		-- The squares a press would act on, framed white round each run of them in a block,
		-- over a pick's warm frame; the You button's swatch the same.
		do
			---@type table?, table?
			local first, last = nil, nil
			local function frameRun()
				if first and last then
					frame(first.x1 - fw, page.barY1 - fw, last.x2 + fw, page.barY2 + fw, fw, HOVER_FRAME)
				end
				first, last = nil, nil
			end
			for _, item in ipairs(page.barItems) do
				if item.hovered and first and first.block == item.block then
					last = item
				else
					frameRun()
					if item.hovered then
						first, last = item, item
					end
				end
			end
			frameRun()
			local b = hoverBlock
			if b and b.swatch then
				frame(b.swatch[1] - fw, b.swatch[2] - fw, b.swatch[3] + fw, b.swatch[4] + fw, fw, HOVER_FRAME)
			end
		end
		Color(1, 1, 1, 1)

		local group = ctx.groupByKey[ctx.selectedGroup()]
		if group and group.custom and #group.graphs == 0 then
			-- A category of the player's own with nothing in it yet: how to fill it.
			local c = r.chart
			ctx.queueText(
				colors.dim .. ctx.i18n("ui.teamStats.custom.empty"),
				mathFloor((c[1] + c[3]) * 0.5),
				mathFloor((c[2] + c[4]) * 0.5),
				fs,
				"ovc"
			)
		elseif page.empty and not page.gridded() then
			local c = r.chart
			local key = page.anySamples and "ui.teamStats.graph.noData" or "ui.teamStats.graph.waiting"
			ctx.queueText(
				colors.dim .. ctx.i18n(key),
				mathFloor((c[1] + c[3]) * 0.5),
				mathFloor((c[2] + c[4]) * 0.5),
				fs,
				"ovc"
			)
		end
	end

	-- The card that picks which kinds of milestone go on the charts: a row per kind with a
	-- mark for the ones that are on, over the top left of the charts' room.
	function page.drawKinds()
		page.kindRects = {}
		if not page.kindsOpen or not page.rects then
			return
		end
		local look, metrics, colors = ctx.look, ctx.metrics, ctx.colors
		local RectRound, Highlight = ctx.draw.RectRound, ctx.draw.Highlight
		local kinds = milestoneKinds()
		-- The card is drawn after the charts rather than into the panel's baked list, so
		-- its text is printed here rather than queued for a batch that has been and gone.
		local texts = {}
		local fs = metrics.catFs
		local rowH = metrics.catRowHeight
		local w = mathFloor(240 * page.scale)
		-- Beside the settings row that opens it, on a backdrop solid enough to read over
		-- whatever it covers; it is drawn after the charts, so nothing lies over it.
		local anchor = page.kindsAnchor
		local gap = mathFloor(6 * page.scale)
		local x1 = anchor and anchor[3] + gap or page.rects.chart[1] + gap
		local h = rowH * (#kinds + 1) + metrics.cardLip * 2
		local y1 = anchor and mathMin(anchor[2], page.rects.chart[4] - h) or page.rects.chart[2]
		y1 = mathMax(y1, page.rects.chart[2])
		local y2 = y1 + h
		RectRound(x1, y1, x1 + w, y2, metrics.csPanel, 1, 1, 1, 1, look.cardFill, look.cardFillTop)
		texts[#texts + 1] = {
			colors.title .. ctx.i18n("ui.teamStats.switch.milestoneKinds"),
			x1 + metrics.sidePad,
			y2 - metrics.cardLip - mathFloor(rowH * 0.5),
		}
		for i, kind in ipairs(kinds) do
			local top = y2 - metrics.cardLip - i * rowH
			local rect = { x1, top - rowH, x1 + w, top }
			page.kindRects[i] = { key = kind, rect = rect }
			local on = not kindsOff()[kind]
			if i == page.hover.kind then
				Highlight(
					rect[1] + metrics.catInset,
					rect[2],
					rect[3] - metrics.catInset,
					rect[4],
					metrics.csSmall,
					look.rowHoverOpacity,
					look.white
				)
			end
			local cy = mathFloor((rect[2] + rect[4]) * 0.5)
			texts[#texts + 1] = {
				(on and colors.selected or colors.faded) .. (ctx.L.milestone[kind] or kind),
				rect[1] + metrics.sidePad,
				cy,
			}
			-- The same switch the settings rows use, so it reads as one.
			local togW = mathFloor(38 * page.scale)
			local togH = mathFloor(rowH * 0.52)
			local tx = rect[3] - metrics.sidePad - togW
			ctx.draw.Toggle(
				tx,
				cy - mathFloor(togH * 0.5),
				tx + togW,
				cy - mathFloor(togH * 0.5) + togH,
				on,
				i == page.hover.kind
			)
		end
		-- One batch, with the outline pinned: the font is shared with every other widget.
		local font = ctx.font()
		if font then
			font:Begin()
			font:SetOutlineColor(look.outline or { 0, 0, 0, 0.4 })
			for _, t in ipairs(texts) do
				font:Print(t[1], t[2], t[3], fs, "ov")
			end
			font:End()
		end
	end

	----------------------------------------------------------------
	-- Custom categories: Add to..., the card of actions, naming
	----------------------------------------------------------------

	-- Text drawn after the panel's list is printed in a batch of its own, with the outline
	-- pinned: the font is shared with every other widget.
	local function printTexts(texts, fs)
		local font = ctx.font()
		if font then
			font:Begin()
			font:SetOutlineColor(ctx.look.outline or { 0, 0, 0, 0.4 })
			for _, t in ipairs(texts) do
				font:Print(t[1], t[2], t[3], fs, t[4] or "ov")
			end
			font:End()
		end
	end

	-- Add to...: in the open graph's top right corner, level with its title.
	function page.addToRect()
		local r = page.rects
		if not r or not page.zoom then
			return nil
		end
		local fs = ctx.metrics.catFs
		local font = ctx.font()
		local label = ctx.i18n("ui.teamStats.custom.addTo")
		local w = (font and mathFloor(font:GetTextWidth(label) * fs) or #label * fs * 0.55) + ctx.metrics.sidePad * 2
		local h = mathFloor(ctx.metrics.rowHeight * 0.8)
		return { r.chart[3] - w, r.chart[4] - h, r.chart[3], r.chart[4] }, label
	end

	function page.drawAddTo()
		local rect, label = page.addToRect()
		if not rect then
			return
		end
		local look, metrics = ctx.look, ctx.metrics
		ctx.draw.RectRound(rect[1], rect[2], rect[3], rect[4], metrics.csSmall, 1, 1, 1, 1, PLATE)
		if page.hover.addTo == 1 or page.menu and page.menu.from == "addTo" then
			ctx.draw.Highlight(rect[1], rect[2], rect[3], rect[4], metrics.csSmall, look.rowHoverOpacity, look.white)
		end
		ctx.draw.Color(1, 1, 1, 1)
		printTexts({
			{
				ctx.colors.title .. label,
				mathFloor((rect[1] + rect[3]) * 0.5),
				mathFloor((rect[2] + rect[4]) * 0.5),
				"ovc",
			},
		}, metrics.catFs)
	end

	function page.menuOpen()
		return page.menu ~= nil
	end

	function page.closeMenu()
		if page.menu then
			page.menu = nil
			page.gen = page.gen + 1
		end
	end

	local function openMenu(rows, anchor, title, from)
		page.menu = { rows = rows, anchor = anchor, title = title, from = from, rects = {} }
		page.gen = page.gen + 1
	end

	-- Right-click on one of the player's categories in the sidebar: named, moved, deleted -
	-- the overview put back as it shipped instead.
	function page.openCategoryMenu(key, anchor)
		local custom = page.custom
		local category = custom.byKey(key)
		if not category then
			return
		end
		local at = 1
		for i, c in ipairs(custom.list) do
			if c == category then
				at = i
			end
		end
		local L = "ui.teamStats.custom."
		local rows = {
			{
				label = ctx.i18n(L .. "rename"),
				act = function()
					page.startNaming(key)
				end,
			},
			{
				label = ctx.i18n(L .. "moveUp"),
				disabled = at == 1,
				act = function()
					custom.move(key, -1)
					ctx.categoriesChanged()
				end,
			},
			{
				label = ctx.i18n(L .. "moveDown"),
				disabled = at == #custom.list,
				act = function()
					custom.move(key, 1)
					ctx.categoriesChanged()
				end,
			},
		}
		if category.shipped then
			rows[#rows + 1] = {
				label = ctx.i18n(L .. "reset"),
				confirm = ctx.i18n(L .. "resetConfirm"),
				act = function()
					custom.reset(key)
					page.zoom = nil
					ctx.categoriesChanged()
				end,
			}
		else
			rows[#rows + 1] = {
				label = ctx.i18n(L .. "delete"),
				confirm = ctx.i18n(L .. "deleteConfirm"),
				act = function()
					custom.delete(key)
					if ctx.selectedGroup() == key then
						ctx.selectGroup(custom.SHIPPED_KEY)
					end
					ctx.categoriesChanged()
				end,
			}
		end
		openMenu(rows, anchor, category.label, "category")
	end

	-- Right-click on a graph of a custom category, in its stat list or on its page of charts.
	function page.openGraphMenu(entry, anchor)
		local custom = page.custom
		local graph = entry.graph
		local _, category = custom.graphById(graph.id)
		if not category then
			return
		end
		local at = 1
		for i, g in ipairs(category.graphs) do
			if g == graph then
				at = i
			end
		end
		local L = "ui.teamStats.custom."
		openMenu({
			{
				label = ctx.i18n(L .. "moveUp"),
				disabled = at == 1,
				act = function()
					custom.moveGraph(graph.id, -1)
					ctx.categoriesChanged()
				end,
			},
			{
				label = ctx.i18n(L .. "moveDown"),
				disabled = at == #category.graphs,
				act = function()
					custom.moveGraph(graph.id, 1)
					ctx.categoriesChanged()
				end,
			},
			{
				label = ctx.i18n(L .. "remove"),
				act = function()
					custom.removeGraph(graph.id)
					if page.zoom == entry.key then
						page.zoom = nil
					end
					ctx.categoriesChanged()
				end,
			},
		}, anchor, entry.label, "graph")
	end

	-- Add to...: every category of the player's own - ticked when it has this stat already -
	-- and a new one, named as soon as it is made. The graph goes in with the settings it is
	-- drawn with right now.
	function page.openAddMenu()
		local rect = page.addToRect()
		if not rect or not page.zoom then
			return
		end
		local custom = page.custom
		local stat, settings = statOf(page.zoom), settingsOf(page.zoom)
		local rows = {}
		for _, category in ipairs(custom.list) do
			local has = false
			for _, g in ipairs(category.graphs) do
				has = has or g.stat == stat
			end
			rows[#rows + 1] = {
				label = category.label,
				check = has,
				act = function()
					custom.add(category.key, stat, settings)
					ctx.categoriesChanged()
				end,
			}
		end
		rows[#rows + 1] = {
			label = ctx.i18n("ui.teamStats.custom.newCategory"),
			act = function()
				local category = custom.create()
				custom.add(category.key, stat, settings)
				ctx.categoriesChanged()
				page.startNaming(category.key)
			end,
		}
		openMenu(rows, rect, ctx.i18n("ui.teamStats.custom.addTo"), "addTo")
	end

	-- The card: beside what opened it - under the Add to... button, flush with its right
	-- edge - on the screen, drawn over everything. A row under the cursor lights up; a
	-- greyed one does nothing; one that asks to be sure says so on the first press and acts
	-- on the second.
	function page.drawMenu(mx, my)
		local menu = page.menu
		if not menu then
			return
		end
		local look, metrics, colors = ctx.look, ctx.metrics, ctx.colors
		local fs, rowH = metrics.catFs, metrics.catRowHeight
		local font = ctx.font()
		local pad = metrics.sidePad
		local tick = mathFloor(fs * 1.2)
		---@type number
		local w = mathFloor(180 * page.scale)
		for _, row in ipairs(menu.rows) do
			local label = row.armed and row.confirm or row.label
			local tw = font and mathFloor(font:GetTextWidth(label) * fs) or #label * fs * 0.55
			w = mathMax(w, tw + pad * 2 + tick)
		end
		local titleRows = menu.title and 1 or 0
		local h = rowH * (#menu.rows + titleRows) + metrics.cardLip * 2
		local a = menu.anchor
		local gap = mathFloor(6 * page.scale)
		local vsx = Spring.GetViewGeometry()
		---@type number, number
		local x1, y2
		if menu.from == "addTo" then
			x1, y2 = mathMax(0, a[3] - w), a[2] - gap
		else
			x1, y2 = a[3] + gap, a[4]
			if x1 + w > vsx then
				x1 = a[1] - gap - w
			end
		end
		local y1 = y2 - h
		if y1 < 0 then
			y1, y2 = 0, h
		end
		ctx.draw.RectRound(x1, y1, x1 + w, y2, metrics.csPanel, 1, 1, 1, 1, look.cardFill, look.cardFillTop)
		local texts = {}
		local top = y2 - metrics.cardLip
		if menu.title then
			texts[#texts + 1] = { colors.title .. menu.title, x1 + pad, top - mathFloor(rowH * 0.5) }
			top = top - rowH
		end
		menu.rects = {}
		for i, row in ipairs(menu.rows) do
			local rect = { x1, top - rowH, x1 + w, top }
			menu.rects[i] = rect
			local over = mx and mx >= rect[1] and mx <= rect[3] and my >= rect[2] and my <= rect[4]
			if over and not row.disabled then
				ctx.draw.Highlight(
					rect[1] + metrics.catInset,
					rect[2],
					rect[3] - metrics.catInset,
					rect[4],
					metrics.csSmall,
					look.rowHoverOpacity,
					look.white
				)
			end
			local color = row.disabled and colors.faded or (row.armed and colors.bad or colors.dim)
			if over and not row.disabled and not row.armed then
				color = colors.selected
			end
			local label = row.armed and row.confirm or row.label
			local cy = mathFloor((rect[2] + rect[4]) * 0.5)
			if row.check then
				texts[#texts + 1] = { colors.selected .. "\226\128\162", x1 + pad, cy }
			end
			texts[#texts + 1] = { color .. label, x1 + pad + tick, cy }
			top = top - rowH
		end
		ctx.draw.Color(1, 1, 1, 1)
		printTexts(texts, fs)
	end

	-- While the card is open it takes every press: a row does its thing, anywhere else only
	-- puts the card away.
	function page.menuPress(x, y, button)
		local menu = page.menu
		if not menu then
			return false
		end
		for i, rect in ipairs(menu.rects) do
			if x >= rect[1] and x <= rect[3] and y >= rect[2] and y <= rect[4] and button ~= 3 then
				local row = menu.rows[i]
				---@cast row -?
				if row.disabled then
					return true
				end
				if row.confirm and not row.armed then
					row.armed = true
					page.gen = page.gen + 1
					ctx.playSound()
					return true
				end
				page.closeMenu()
				row.act()
				ctx.playSound()
				return true
			end
		end
		page.closeMenu()
		return true
	end

	-- Naming a category: a field over its sidebar entry, the name so far picked so typing
	-- replaces it. Enter keeps what was typed, Escape the name it had.
	function page.startNaming(key)
		local category = page.custom.byKey(key)
		if not category then
			return
		end
		local box = Editbox.new({ text = category.label, maxChars = 32, outline = ctx.look.outline })
		box:focus()
		box.selAnchor = 0
		page.naming = { key = key, box = box, was = category.label }
		ctx.textInput(true)
		page.gen = page.gen + 1
	end

	-- A name left as it was is not kept as typed: an unnamed category keeps the name it is
	-- given in the player's language. Emptied, it gets that name back.
	function page.stopNaming(keep)
		local naming = page.naming
		if not naming then
			return
		end
		page.naming = nil
		local text = naming.box:getText()
		if keep and text ~= naming.was then
			page.custom.rename(naming.key, text)
		end
		ctx.textInput(false)
		ctx.categoriesChanged()
	end

	function page.namingKey(key)
		local naming = page.naming
		if not naming then
			return false
		end
		if key == KEYSYMS.RETURN or key == KEYSYMS.KP_ENTER then
			page.stopNaming(true)
		elseif key == KEYSYMS.ESCAPE then
			page.stopNaming(false)
		else
			naming.box:keyPress(key)
		end
		return true
	end

	function page.namingText(char)
		return page.naming ~= nil and page.naming.box:textInput(char)
	end

	-- The field, where the panel says the entry is.
	function page.drawNaming(x1, y1, x2, y2)
		local naming = page.naming
		if not naming then
			return
		end
		naming.box:setRect(x1, y1, x2, y2, ctx.metrics.catFs, ctx.metrics.sidePad)
		naming.box:draw()
	end

	----------------------------------------------------------------
	-- Custom categories: a graph dragged to another place
	----------------------------------------------------------------

	-- How far a press on a graph of the player's own travels before it is a drag rather
	-- than a click, which opens the graph when it is let go.
	local function dragThreshold()
		return mathMax(4, mathFloor(6 * page.scale))
	end

	function page.dragging()
		return page.drag ~= nil
	end

	function page.dragMoving()
		return page.drag ~= nil and page.drag.moving == true
	end

	-- The graphs a drag can land among, in order, each where it is shown: the grid's
	-- charts, or the stat list's rows while one is open.
	local function dropSlots()
		---@type table[]
		local slots = {}
		if page.gridded() then
			for _, mini in ipairs(page.miniCharts or {}) do
				local entry = page.entryByKey[mini.key]
				if entry and entry.graph then
					slots[#slots + 1] = { graph = entry.graph, rect = mini.rect }
				end
			end
		elseif page.listShown() and page.rects then
			for i, entry in ipairs(page.statList) do
				if entry.graph then
					local x1, y1, x2, y2 = statRect(i)
					slots[#slots + 1] = { graph = entry.graph, rect = { x1, y1, x2, y2 } }
				end
			end
		end
		return slots
	end

	-- Where the dragged graph lands if let go at x,y: in front of the nearest graph or
	-- after it, by the half of it the cursor is over. Answers the graph it goes in front of
	-- (none: the end) and the line that marks the place; nothing where it is already, or
	-- off the charts.
	---@return { before: table?, line: number[] }?
	local function dropTarget(x, y)
		local drag, r = page.drag, page.rects
		if not drag or not r then
			return nil
		end
		local grid = page.gridded()
		local area = grid and r.chart or r.list
		if x < area[1] or x > area[3] or y < area[2] or y > area[4] then
			return nil
		end
		---@type table?
		local near = nil
		local nearest = mathHuge
		for _, slot in ipairs(dropSlots()) do
			local rc = slot.rect
			---@type number, number
			local dx, dy = mathMax(rc[1] - x, 0, x - rc[3]), mathMax(rc[2] - y, 0, y - rc[4])
			if dx * dx + dy * dy < nearest then
				near, nearest = slot, dx * dx + dy * dy
			end
		end
		local _, category = page.custom.graphById(drag.graph.id)
		if not near or not category then
			return nil
		end
		local rc = near.rect
		local after
		if grid then
			after = x > (rc[1] + rc[3]) * 0.5
		else
			-- Down the list is after: y grows upwards.
			after = y < (rc[2] + rc[4]) * 0.5
		end
		local graphs = category.graphs
		local from, at = 1, 1
		for i, graph in ipairs(graphs) do
			if graph == drag.graph then
				from = i
			end
			if graph == near.graph then
				at = after and i + 1 or i
			end
		end
		if at == from or at == from + 1 then
			return nil
		end
		-- In the gap beside the chart, or across the row's edge.
		local w = mathMax(2, mathFloor(3 * page.scale))
		if grid then
			local gap = mathFloor(8 * page.scale)
			local lx = mathFloor((after and rc[3] + gap * 0.5 or rc[1] - gap * 0.5) - w * 0.5)
			return { before = graphs[at], line = { lx, rc[2], lx + w, rc[4] } }
		end
		local ly = mathFloor((after and rc[2] or rc[4]) - w * 0.5)
		local inset = ctx.metrics.catInset
		return { before = graphs[at], line = { rc[1] + inset, ly, rc[3] - inset, ly + w } }
	end

	-- Every frame of a press on a graph of the player's own: a drag once it has travelled;
	-- held at the grid's top or bottom edge, the grid scrolls a row at a time. A press let
	-- go where the panel never heard of it is dropped.
	function page.dragUpdate(mx, my, held)
		local drag = page.drag
		if not drag then
			return
		end
		if not held then
			page.drag = nil
			page.gen = page.gen + 1
			return
		end
		if not drag.moving then
			if mathMax(mathAbs(mx - drag.x), mathAbs(my - drag.y)) <= dragThreshold() then
				return
			end
			drag.moving = true
			page.gen = page.gen + 1
		end
		local r = page.rects
		if not (r and page.gridded() and page.maxScroll > 0) then
			return
		end
		local c = r.chart
		local edge = mathFloor(24 * page.scale)
		local over = mx >= c[1] and mx <= c[3]
		local up = over and my > c[4] - edge and page.scroll > 0
		local down = over and my < c[2] + edge and page.scroll < page.maxScroll
		if not (up or down) then
			drag.edgeSince = nil
			return
		end
		local now = Spring.GetTimer()
		if not drag.edgeSince then
			drag.edgeSince = now
		elseif Spring.DiffTimers(now, drag.edgeSince) > 0.4 then
			drag.edgeSince = now
			page.wheel(up)
		end
	end

	-- The drag over the charts: the graph's own place shaded, a line where it would land,
	-- and its name beside the cursor.
	function page.drawDrag(mx, my)
		local drag = page.drag
		if not (drag and drag.moving) then
			return
		end
		local metrics, look = ctx.metrics, ctx.look
		for _, slot in ipairs(dropSlots()) do
			if slot.graph == drag.graph then
				local rc = slot.rect
				ctx.draw.RectRound(rc[1], rc[2], rc[3], rc[4], metrics.csSmall, 1, 1, 1, 1, look.dragShade)
			end
		end
		local target = dropTarget(mx, my)
		if target then
			local l = target.line
			ctx.draw.RectRound(l[1], l[2], l[3], l[4], 0, 0, 0, 0, 0, look.dropLine)
		end
		local entry = page.entryByKey[drag.key]
		if entry then
			local fs, pad = metrics.catFs, metrics.sidePad
			local font = ctx.font()
			local w = (font and mathFloor(font:GetTextWidth(entry.label) * fs) or #entry.label * fs * 0.55) + pad * 2
			local h = mathFloor(metrics.catRowHeight * 0.9)
			local x1 = mathFloor(mx + 14 * page.scale)
			if x1 + w > Spring.GetViewGeometry() then
				x1 = mathFloor(mx - 14 * page.scale - w)
			end
			local y2 = mathFloor(my - 6 * page.scale)
			ctx.draw.RectRound(x1, y2 - h, x1 + w, y2, metrics.csSmall, 1, 1, 1, 1, look.cardFill, look.cardFillTop)
			ctx.draw.Color(1, 1, 1, 1)
			printTexts({ { ctx.colors.title .. entry.label, x1 + pad, mathFloor(y2 - h * 0.5) } }, fs)
		end
	end

	-- The charts, after the panel's list: the grid of the page, or the one chart a pick or
	-- a zoom opened, each with its own hover overlay. The chart under the cursor is framed
	-- and answers the tooltip.
	function page.drawChart(mx, my)
		if page.dirty then
			page.build()
		end
		local r = page.rects
		local inside = r and mx >= r.chart[1] and mx <= r.chart[3] and my >= r.chart[2] and my <= r.chart[4]
		-- The card of kinds lies over the charts: what is under it is not under the cursor.
		if page.hover.kind > 0 then
			inside = false
		end
		if page.gridded() then
			page.chartHit, page.miniHit = nil, nil
			for _, mini in ipairs(page.miniCharts or {}) do
				local over = inside
					and mx >= mini.rect[1]
					and mx <= mini.rect[3]
					and my >= mini.rect[2]
					and my <= mini.rect[4]
				local hit = over and mini.chart:hitTest(mx, my) or nil
				if over then
					page.miniHit = mini
					page.chartHit = hit
				end
				-- Drawn without its hover: the one under the cursor gets it last, over the
				-- charts beside it and over the light that marks it.
				mini.chart:setHover(nil)
				mini.chart:draw()
				mini.chart:setHover(hit)
			end
			-- The one under the cursor is marked, so it is clear what a press would open: a
			-- rounded outline that fades inwards rather than a hard box.
			---@type table?
			local mini = page.miniHit
			if mini then
				ctx.draw.Highlight(
					mini.rect[1],
					mini.rect[2],
					mini.rect[3],
					mini.rect[4],
					ctx.metrics.csPanel,
					ctx.look.chartHoverOpacity,
					ctx.look.white
				)
				ctx.draw.Color(1, 1, 1, 1)
				mini.chart:drawOverlay()
			end
			page.drawKinds()
			return
		end
		-- The button in the chart's corner is not the chart.
		if page.hover.addTo == 1 then
			inside = false
		end
		local hit = inside and chart:hitTest(mx, my) or nil
		-- One chart fills the page: no small one answers for the tooltip any more.
		page.chartHit, page.miniHit = hit, nil
		chart:setHover(hit)
		chart:draw()
		page.drawAddTo()
		page.drawKinds()
	end

	-- The wheel over the charts moves the grid a row at a time. Answers whether it took it.
	function page.wheel(up)
		if not page.gridded() or page.maxScroll <= 0 then
			return false
		end
		local to = mathMax(0, mathMin(page.maxScroll, page.scroll + (up and -1 or 1)))
		if to == page.scroll then
			return false
		end
		page.scroll = to
		page.dirty = true
		page.gen = page.gen + 1
		return true
	end

	----------------------------------------------------------------
	-- The cursor
	----------------------------------------------------------------

	-- Which list entry, legend square or legend block the cursor is over, for the
	-- panel's bake signature.
	function page.hoverAt(mx, my)
		page.hover.stat, page.hover.legend, page.hover.block, page.hover.kind, page.hover.filter = 0, 0, 0, 0, 0
		page.hover.addTo = 0
		local add = page.addToRect()
		if add and mx >= add[1] and mx <= add[3] and my >= add[2] and my <= add[4] then
			page.hover.addTo = 1
		end
		local tog = filterToggleRect()
		if tog and mx >= tog[3] - filterReserve() and mx <= tog[3] and my >= tog[2] and my <= tog[4] then
			page.hover.filter = 1
		end
		for i, row in ipairs(page.kindRects) do
			local r2 = row.rect
			if mx >= r2[1] and mx <= r2[3] and my >= r2[2] and my <= r2[4] then
				page.hover.kind = i
			end
		end
		local r = page.rects
		if not r then
			return "0|0|0|0"
		end
		-- The bar runs above the stat list, so it is asked first.
		if my >= r.bar[2] and my <= r.bar[4] then
			for i, b in ipairs(page.barBlocks) do
				if mx >= b.hx1 and mx < b.hx2 then
					page.hover.block = i
				end
			end
			for i, item in ipairs(page.barItems) do
				if mx >= item.x1 and mx < item.x2 and my >= item.y1 and my <= item.y2 then
					page.hover.legend = i
				end
			end
		elseif page.listShown() and mx >= r.list[1] and mx <= r.list[3] then
			for i = 1, #page.statList do
				local _, y1, _, y2 = statRect(i)
				if my > y1 and my <= y2 and not page.statList[i].divider then
					page.hover.stat = i
				end
			end
		end
		return page.hover.stat
			.. "|"
			.. page.hover.legend
			.. "|"
			.. page.hover.block
			.. "|"
			.. page.hover.kind
			.. "|"
			.. page.hover.filter
			.. "|"
			.. page.hover.addTo
			.. "|"
			.. page.gen
	end

	-- The units a press in the bar acts on: a square's; with the grouping switch on the
	-- block's ally team, off it the caption's players, all of them.
	local function unitsUnderCursor()
		if page.hover.legend > 0 then
			local item = page.barItems[page.hover.legend]
			---@cast item -?
			return { item.unit }
		end
		if page.hover.block > 0 then
			local b = page.barBlocks[page.hover.block]
			---@cast b -?
			if b.unit then
				return { b.unit }
			elseif not b.all and not b.me then
				local list = {}
				for _, m in ipairs(b.members) do
					list[#list + 1] = m.unit
				end
				return list
			end
		end
		return nil
	end

	local function changed()
		page.dirty = true
		page.gen = page.gen + 1
		ctx.playSound()
	end

	-- A press: picks a stat. On the bar a click adds the units under the cursor to the
	-- selection, or takes them out when they all were in it; Ctrl+click makes them the
	-- whole selection; right-click hides them, or shows them again when they all were
	-- hidden. All clears the selection and shows every team again.
	function page.mousePress(x, y, button)
		page.hoverAt(x, y)
		if page.kindsOpen then
			local row = page.kindRects[page.hover.kind]
			if row and button ~= 3 then
				local off = kindsOff()
				off[row.key] = not off[row.key] or nil
				changed()
				return true
			end
			-- A press anywhere else puts the card away.
			page.kindsOpen = false
			changed()
			return true
		end
		-- Add to... on the open graph, before the press on the chart that closes it.
		if page.hover.addTo == 1 and button ~= 3 then
			page.openAddMenu()
			return true
		end
		if page.hover.stat > 0 then
			local entry = page.statList[page.hover.stat]
			---@cast entry -?
			-- A custom category's graph is moved or removed from its right-click card.
			if button == 3 and entry.graph then
				local x1, y1, x2, y2 = statRect(page.hover.stat)
				page.openGraphMenu(entry, { x1, y1, x2, y2 })
				return true
			end
			if button ~= 3 and entry.back then
				-- Back to the grid the chart was opened from.
				page.zoom = nil
				changed()
			elseif button == 1 and entry.graph then
				-- One of the player's own: opened when let go, moved when dragged.
				page.drag = { key = entry.key, graph = entry.graph, x = x, y = y }
			elseif button ~= 3 then
				page.stat = entry.key
				-- The list is how a stat is opened, whatever the grid is showing.
				page.zoom = entry.key
				changed()
			end
			return true
		end
		if button == 3 and page.miniHit then
			local entry = page.entryByKey[page.miniHit.key]
			if entry and entry.graph then
				page.openGraphMenu(entry, page.miniHit.rect)
				return true
			end
		end
		if button ~= 3 and page.miniHit then
			local entry = page.entryByKey[page.miniHit.key]
			if button == 1 and entry and entry.graph then
				page.drag = { key = entry.key, graph = entry.graph, x = x, y = y }
				return true
			end
			-- The grid answered what it is for; this one opens on its own.
			page.stat = page.miniHit.key
			page.zoom = page.miniHit.key
			changed()
			return true
		end
		if button ~= 3 and page.zoom and page.rects then
			local c = page.rects.chart
			if x >= c[1] and x <= c[3] and y >= c[2] and y <= c[4] then
				-- And a press on the opened chart goes back to the grid.
				page.zoom = nil
				changed()
				return true
			end
		end
		if page.hover.filter == 1 and button ~= 3 then
			page.hideUnselected = not page.hideUnselected
			changed()
			return true
		end
		local block = page.hover.block > 0 and page.barBlocks[page.hover.block] or nil
		if block and block.me and button ~= 3 then
			-- Your own team alone, whatever was picked before.
			page.selected = {}
			setTeams(page.selected, block.unit, true)
			setTeams(page.hidden, block.unit, false)
			changed()
			return true
		end
		if block and block.all then
			if button ~= 3 and (next(page.selected) or next(page.hidden)) then
				page.selected, page.hidden = {}, {}
				changed()
			end
			return true
		end
		local targets = unitsUnderCursor()
		if targets then
			local allHidden, allSelected = true, true
			for _, u in ipairs(targets) do
				allHidden = allHidden and isHidden(u)
				allSelected = allSelected and allPicked(u) and not isHidden(u)
			end
			local _, ctrl = Spring.GetModKeyState()
			if button == 3 then
				for _, u in ipairs(targets) do
					setTeams(page.hidden, u, not allHidden)
					if not allHidden then
						setTeams(page.selected, u, false)
					end
				end
			else
				if ctrl then
					page.selected = {}
				end
				for _, u in ipairs(targets) do
					local on = ctrl or not allSelected
					setTeams(page.selected, u, on)
					if on then
						setTeams(page.hidden, u, false)
					end
				end
			end
			changed()
			return true
		end
		return block ~= nil
	end

	-- The press on a graph of the player's own, let go: travelled, the graph lands where the
	-- line showed; not, it was a click, and the graph opens.
	function page.mouseRelease(x, y)
		local drag = page.drag
		if not drag then
			return false
		end
		if drag.moving or mathMax(mathAbs(x - drag.x), mathAbs(y - drag.y)) > dragThreshold() then
			local target = dropTarget(x, y)
			page.drag = nil
			page.gen = page.gen + 1
			if target then
				page.custom.placeGraph(drag.graph.id, target.before and target.before.id)
				ctx.categoriesChanged()
				ctx.playSound()
			end
			return true
		end
		page.drag = nil
		page.stat = drag.key
		page.zoom = drag.key
		changed()
		return true
	end

	-- What the units under the cursor are to the chart right now, and what the mouse does
	-- to them: a line on their state (selected, not, hidden, and what that means with
	-- the switches as they are), one on their milestones when those are on the chart,
	-- then the controls.
	local function barHint(targets)
		local L = "ui.teamStats.graph."
		local allHidden, allSelected, someSelected = true, true, false
		for _, u in ipairs(targets) do
			local shownU = not isHidden(u)
			allHidden = allHidden and not shownU
			allSelected = allSelected and allPicked(u) and shownU
			-- An ally team with only some of its players picked is some of it.
			someSelected = someSelected or (isPicked(u) and shownU)
		end
		local composition = statOf(page.stat) == "composition"
		local anyPicked = #pickedUnits() > 0
		local dropping = filtering()
		local state
		if allHidden then
			state = "hidden"
		elseif allSelected then
			state = composition and "counted" or (dropping and "only" or "lit")
		elseif someSelected then
			state = "some"
		elseif anyPicked then
			state = composition and "notCounted" or (dropping and "left" or "faded")
		else
			state = composition and "allCounted" or "alike"
		end
		local group = #targets > 1
		local lines = { ctx.colors.title .. ctx.i18n(L .. "state." .. state) }
		if settingsOf(page.zoom or page.stat).milestones and not allHidden and (allSelected or not anyPicked) then
			local key = group and "milestonesGroup" or "milestones"
			lines[#lines + 1] = ctx.colors.title .. ctx.i18n(L .. "state." .. key)
		end
		local suffix = group and "Group" or ""
		for _, control in ipairs({ "click", "ctrlClick", "rightClick" }) do
			lines[#lines + 1] = ctx.colors.dim .. ctx.i18n(L .. "control." .. control .. suffix)
		end
		return table.concat(lines, "\n")
	end

	-- The tooltip for the cursor: the chart's description, a stat's explanation, or the
	-- units under the cursor in the bar and how the bar works.
	function page.tooltip()
		local kindRow = page.kindRects[page.hover.kind]
		if kindRow then
			return ctx.L.milestone[kindRow.key] or kindRow.key, ctx.i18n("ui.teamStats.graph.kindHint")
		end
		if page.chartHit then
			local hovered = page.miniHit and page.miniHit.chart or chart
			local desc = hovered:describe(page.chartHit)
			-- Its % of total faded in the title: why it keeps its line.
			local key = page.miniHit and page.miniHit.key or page.zoom or page.stat
			local column = ctx.COLUMNS[statOf(key)]
			local idle = settingsOf(key).share and column and column.fmt == "si" and hovered.cfg.kind ~= "stacked"
			if idle and page.chartHit.kind ~= "marker" then
				desc = (desc or "") .. "\n" .. ctx.colors.dim .. ctx.i18n("ui.teamStats.graph.shareOne")
			end
			return hovered.cfg.title, desc
		end
		if page.hover.stat > 0 then
			local entry = page.statList[page.hover.stat]
			---@cast entry -?
			if entry.back then
				return entry.label, ctx.i18n("ui.teamStats.graph.overviewDesc")
			end
			-- Explained by what it shows: a custom category's graph is keyed as itself, and
			-- says it can be moved or removed.
			local stat = entry.stat or entry.key
			local desc = entry.column and ctx.L.desc[stat] or ctx.i18n("ui.teamStats.graph." .. stat .. "Desc")
			if entry.graph then
				desc = desc .. "\n" .. ctx.colors.dim .. ctx.i18n("ui.teamStats.custom.graphHint")
			end
			return entry.label, desc
		end
		if page.hover.filter == 1 then
			return ctx.i18n("ui.teamStats.graph.hideUnselected"), ctx.i18n("ui.teamStats.graph.hideUnselectedDesc")
		end
		if page.hover.addTo == 1 then
			return ctx.i18n("ui.teamStats.custom.addTo"), ctx.i18n("ui.teamStats.custom.addToDesc")
		end
		if page.hover.legend > 0 then
			local item = page.barItems[page.hover.legend]
			---@cast item -?
			local title = (item.team.nameColor or "") .. item.team.name
			if item.unit.name ~= item.team.name then
				title = title .. ctx.colors.title .. " \194\183 " .. item.unit.name
			end
			return title, barHint({ item.unit })
		end
		if page.hover.block > 0 then
			local b = page.barBlocks[page.hover.block]
			---@cast b -?
			if b.me then
				return b.label, ctx.i18n("ui.teamStats.graph.youHint")
			end
			if b.all then
				local tip = ctx.i18n("ui.teamStats.graph.allHint")
				if settingsOf(page.zoom or page.stat).milestones then
					tip = tip .. "\n" .. ctx.i18n("ui.teamStats.graph.allMilestones")
				end
				return b.label, tip
			end
			local targets = unitsUnderCursor()
			---@cast targets -?
			return b.label, barHint(targets)
		end
		return nil
	end

	----------------------------------------------------------------
	-- Housekeeping
	----------------------------------------------------------------

	function page.getConfig()
		local off = {}
		for kind, on in pairs(page.milestoneOff) do
			if on then
				off[#off + 1] = kind
			end
		end
		return {
			graphStat = page.stat,
			graphsOpen = page.open,
			graphGroupByTeam = page.grouped,
			graphPerPage = page.perPage,
			graphMilestonesOff = off,
			graphHideUnselected = page.hideUnselected,
			customCategories = page.custom.getConfig(),
		}
	end

	function page.setConfig(data)
		page.custom.setConfig(data.customCategories)
		if type(data.graphStat) == "string" then
			page.stat = data.graphStat
		end
		if type(data.graphMilestonesOff) == "table" then
			page.milestoneOff = {}
			for _, kind in ipairs(data.graphMilestonesOff) do
				page.milestoneOff[kind] = true
			end
		end
		if data.graphsOpen ~= nil then
			page.open = data.graphsOpen == true
		end
		if data.graphGroupByTeam ~= nil then
			page.grouped = data.graphGroupByTeam == true
		end
		if data.graphHideUnselected ~= nil then
			page.hideUnselected = data.graphHideUnselected == true
		end
		for _, spec in ipairs(PAGES) do
			if spec.n == data.graphPerPage then
				page.perPage = spec.n
			end
		end
	end

	-- The switches and the sidebar change what the chart is made of.
	function page.invalidate()
		page.dirty = true
	end

	function page.destroy()
		chart:destroy()
		for _, chartOf in ipairs(pool) do
			chartOf:destroy()
		end
	end

	return page
end

return M
