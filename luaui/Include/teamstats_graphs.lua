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

-- The legend bar's looks: a block is a button, the picked one lit and framed warm. The
-- chart of the grid under the cursor is framed the same way, more faintly.
local PLATE = { 1, 1, 1, 0.05 }
local PICKED_FRAME = { 1, 0.78, 0.51, 0.85 }
local HOVER_FRAME = { 1, 0.78, 0.51, 0.5 }
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
		-- The units picked in the legend bar, by key; none is every team alike. With the
		-- Selected only switch they are the chart, without it they stand out on it. Starts
		-- on the viewer's own team, when they have one.
		---@type table<string, boolean>
		selected = {},
		selectionSet = false,
		-- The axes of the profile wheel, as the last build read them.
		---@type table[]
		profileAxes = {},
		-- The page's own grouping, kept apart from the table's: a chart of ally teams and
		-- a table of ally teams are different questions, and picking a single player on the
		-- chart should not flatten the table.
		grouped = true,
		hover = { stat = 0, legend = 0, block = 0, kind = 0, group = 0 },
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
		-- it and the one under the cursor. One chart per page is the single chart view.
		perPage = 9,
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

	local chart = Graph.new({
		kind = "line",
		legend = false,
		xUnit = "frames",
		lineWidth = 2,
		includeZero = true,
		look = { plotFill = { 0, 0, 0, 0.16 } },
	})
	page.chart = chart

	local function grouped()
		return page.grouped and not ctx.isFFA
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
		local on = 0
		for _, kind in ipairs(kinds) do
			if not page.milestoneOff[kind] then
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
		if group.key == "composition" and ctx.gadgetOn() then
			list[#list + 1] = { key = "composition", label = ctx.i18n("ui.teamStats.graph.composition") }
		elseif group.key == "all" then
			-- Every team's shape at a glance, and when things happened to them, before the
			-- stats they are made of.
			list[#list + 1] = { key = "profile", label = ctx.i18n("ui.teamStats.graph.profile") }
			if ctx.gadgetOn() then
				list[#list + 1] = { key = "timeline", label = ctx.i18n("ui.teamStats.graph.timeline") }
			end
		end
		for i = 1, #group.columns do
			local column = ctx.COLUMNS[group.columns[i]]
			if ctx.gadgetOn() or not (column.gadget or column.liveOnly) then
				list[#list + 1] = { key = column.key, label = ctx.columnTitle(column), column = column }
			end
		end
		page.statList = list
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
	-- card spans listY1..listY2 when given, so it lines up with the sidebar's beside it.
	function page.setLayout(x1, y1, x2, y2, s, listY1, listY2)
		page.scale = s
		-- Kept so the page can lay itself out again when the list comes or goes without the
		-- panel having a reason to.
		page.layoutArgs = { x1, y1, x2, y2, s, listY1, listY2 }
		page.listWas = page.listShown()
		local gap = mathFloor(12 * s)
		local listW = page.listShown() and mathFloor(200 * s) or -gap
		local barH = ctx.metrics.rowHeight + mathFloor(8 * s)
		page.rects = {
			list = { x1, listY1 or y1, x1 + mathMax(0, listW), listY2 or y2 },
			bar = { x1 + listW + gap, y2 - barH, x2, y2 },
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

	-- The grouping switch belongs with the teams it groups: the page draws it at the end of
	-- the legend bar rather than among the settings.
	---@type fun(): table?
	local groupToggleRect

	-- Where the grouping switch sits on the bar, for whoever needs to point at it.
	function page.groupToggle()
		return groupToggleRect()
	end

	-- The room the grouping switch and its caption take at the end of the bar, which the
	-- team blocks leave free.
	local function groupReserve()
		if ctx.isFFA then
			return 0
		end
		local font = ctx.font()
		local label = ctx.L.switch and ctx.L.switch.groupByTeam or ""
		local labelW = font and mathFloor(font:GetTextWidth(label) * ctx.metrics.catFs) or mathFloor(90 * page.scale)
		return labelW + mathFloor(38 * page.scale) + ctx.metrics.sidePad + ctx.metrics.rowPad * 2
	end

	function groupToggleRect()
		local r = page.rects
		if not r or ctx.isFFA then
			return nil
		end
		local togW = mathFloor(38 * page.scale)
		local togH = mathFloor(ctx.metrics.rowHeight * 0.52)
		local cy = mathFloor((r.bar[2] + r.bar[4]) * 0.5)
		local x2 = r.bar[3] - ctx.metrics.sidePad
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

		local units = {}
		local byKey = {}
		for _, ally in ipairs(allies) do
			if grouped() then
				local first = ally.teams[1]
				local members = {}
				local isLocal = false
				for _, team in ipairs(ally.teams) do
					members[#members + 1] = team.id
					isLocal = isLocal or team.isLocal == true
				end
				local unit = {
					key = "ally" .. ally.id,
					name = ctx.i18n("ui.teamStats.team", { number = ally.id + 1 }),
					color = first and { first.accent[1], first.accent[2], first.accent[3] } or { 0.8, 0.8, 0.8 },
					members = members,
					teams = ally.teams,
					isLocal = isLocal,
				}
				units[#units + 1] = unit
				byKey[unit.key] = unit
			else
				for _, team in ipairs(ally.teams) do
					local unit = {
						key = "team" .. team.id,
						name = team.name,
						color = { team.accent[1], team.accent[2], team.accent[3] },
						members = { team.id },
						teams = { team },
						isLocal = team.isLocal,
						quiet = team.dead or team.gone,
					}
					units[#units + 1] = unit
					byKey[unit.key] = unit
				end
			end
		end
		page.units = units
		page.unitByKey = byKey

		-- The selection and the hidden set carried over to these units: once the grouping
		-- switch turned, an ally team stands for its players, and players stand for their
		-- ally team - when any of them was selected, or all of them were hidden.
		local function carried(set, whole)
			local out = {}
			for _, unit in ipairs(units) do
				local count = 0
				for _, team in ipairs(unit.teams) do
					if set[unit.key] or set["team" .. team.id] or set["ally" .. team.allyID] then
						count = count + 1
					end
				end
				if count > 0 and (not whole or count == #unit.teams) then
					out[unit.key] = true
				end
			end
			return out
		end
		page.selected = carried(page.selected, false)
		page.hidden = carried(page.hidden, true)
		-- The first selection is the viewer's own unit; a cleared one stays cleared.
		if not page.selectionSet then
			page.selectionSet = true
			for _, unit in ipairs(units) do
				if unit.isLocal then
					page.selected[unit.key] = true
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
		-- Whoever is playing gets their own team a press away, beside All.
		---@type table?
		local mine = nil
		for _, unit in ipairs(page.units) do
			if unit.isLocal then
				mine = unit
			end
		end
		if mine then
			local me = { me = true, unit = mine, label = ctx.i18n("ui.teamStats.graph.you"), members = {} }
			me.labelW = widthOf(me.label)
			blocks[#blocks + 1] = me
		end
		local seen = {}
		for _, unit in ipairs(page.units) do
			for _, team in ipairs(unit.teams) do
				local block = seen[team.allyID]
				if not block then
					block = {
						ally = team.allyID,
						label = ctx.i18n("ui.teamStats.team", { number = team.allyID + 1 }),
						members = {},
						unit = grouped() and unit or nil,
					}
					seen[team.allyID] = block
					blocks[#blocks + 1] = block
				end
				block.members[#block.members + 1] = { team = team, unit = unit }
			end
		end
		local count, labelW = 0, 0
		local teamBlocks = 0
		for i = 1, #blocks do
			local b = blocks[i]
			if not b.all and not b.me then
				count = count + #b.members
				b.labelW = widthOf(b.label)
				labelW = labelW + b.labelW + pad
				teamBlocks = teamBlocks + 1
			end
		end
		-- The All button always keeps its caption; the team blocks share what is left once
		-- the grouping switch at the end of the bar has its room.
		local fixed = all.labelW + pad * 3 + (blocks[2] and blocks[2].me and blocks[2].labelW + r.square + pad * 3 or 0)
		local avail = r.bar[3] - r.bar[1] - pad * 2 - fixed - groupReserve()
		local gaps = pad * mathMax(0, teamBlocks - 1) + pad * teamBlocks
		local square = r.square
		local withLabels = count * square + gaps + labelW <= avail
		if not withLabels then
			square = mathMax(4, mathMin(square, mathFloor((avail - gaps) / mathMax(1, count))))
		end
		local items = {}
		local x = r.bar[1] + pad
		local cy = mathFloor((r.bar[2] + r.bar[4]) * 0.5)
		local y1 = cy - mathFloor(square * 0.5)
		local y2 = y1 + square
		local half = mathFloor(pad * 0.5)
		for _, b in ipairs(blocks) do
			-- The plate runs from the caption to the last square, with half a pad of air.
			b.x1 = x - half
			if b.all or b.me then
				b.labelX = x
				x = x + b.labelW
				if b.me then
					-- Your own colour beside the caption, the same square the teams get.
					x = x + half
					b.swatch = { x, y1, x + square, y2 }
					x = x + square
				end
			else
				if withLabels then
					b.labelX = x
					x = x + b.labelW + pad
				end
				for _, m in ipairs(b.members) do
					items[#items + 1] =
						{ unit = m.unit, team = m.team, block = b, x1 = x, y1 = y1, x2 = x + square, y2 = y2 }
					x = x + square
				end
			end
			b.x2 = x + half
			x = x + pad + pad
		end
		page.barBlocks = blocks
		page.barItems = items
		page.barLabels = withLabels
		page.barY1, page.barY2 = y1, y2
		page.gen = page.gen + 1
	end

	-- The units not hidden from the chart.
	local function shownUnits()
		local list = {}
		for _, u in ipairs(page.units) do
			if not page.hidden[u.key] then
				list[#list + 1] = u
			end
		end
		return list
	end

	-- The selected units among the shown.
	local function pickedUnits()
		local list = {}
		for _, u in ipairs(page.units) do
			if page.selected[u.key] and not page.hidden[u.key] then
				list[#list + 1] = u
			end
		end
		return list
	end

	-- Whether a rate means anything for what the page is showing: only a running total,
	-- and only while that chart is the one open.
	function page.rateShown()
		if page.gridded() then
			return false
		end
		local column = ctx.COLUMNS[page.zoom or page.stat]
		return column ~= nil and column.rate == true
	end

	-- Whether the picked stat is drawn over game time: the profile and the composition
	-- answer differently, and the panel asks before it lays the switches out.
	function page.overTime()
		return page.stat ~= "profile"
	end

	-- Whether the milestones switch means anything: the timeline is made of them.
	function page.milestonesOwn()
		return page.stat == "timeline"
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
	local function kindFits(kind, column)
		if page.milestoneOff[kind] then
			return false
		end
		local groups = MILESTONE_GROUPS[kind]
		if not groups or groups.always then
			return true
		end
		-- A chart that is not one column's (the composition, the profile) takes them all.
		return column == nil or groups[column.group] == true
	end

	local function milestoneMarkers(list, indexByKey, always, column)
		local markers = {}
		local live = ctx.live()
		if not live or not (always or ctx.filters.milestones) then
			return markers
		end
		for _, unit in ipairs(list) do
			-- One set of rows per unit: its lane is its own.
			local taken = {}
			for _, team in ipairs(unit.teams) do
				local teamLive = live[team.id]
				for _, m in ipairs(teamLive and teamLive.milestones or {}) do
					-- Kinds switched off in the milestone settings never make a marker.
					if kindFits(m.key, column) then
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
	-- hidden units are left out; with Selected only on and a selection, only the selected
	-- are plotted, otherwise every shown unit is, the selected ones lit and on top and the
	-- rest faded; the milestones are the selection's, every plotted unit's when nothing is
	-- selected. A composition is one whole, so it is the selection's summed (every shown
	-- team's without one). Share of team plots the players of the plotted ally teams as
	-- shares of their total.
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
	local function lineSeries(column, plotted, perMinute)
		local series = {}
		---@type table<integer, boolean>
		local lifted = {}
		for _, u in ipairs(plotted) do
			series[#series + 1] = {
				name = u.name,
				color = u.color,
				points = pointsOf(u.members, column.key, perMinute, column.clamp),
				width = 2,
			}
			lifted[#series] = page.selected[u.key]
		end
		return series, lifted
	end

	-- What a chart of one stat is made of: the same rules for the big chart and for every
	-- small one in the grid. `small` leaves out what a little chart has no room for.
	-- Returns whether it came out empty.
	local function fillChart(target, statKey, small)
		local column = ctx.COLUMNS[statKey]
		local isGrouped = grouped()
		local perMinute = ctx.filters.perMinute and column and column.rate or false
		local shown = shownUnits()
		local picked = pickedUnits()
		local anyPicked = #picked > 0
		local plotted = shown
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
				lifted[#series] = page.selected[u.key]
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
			markers = milestoneMarkers(plotted, indexByKey, true, nil)
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
			for _, u in ipairs(plotted) do
				series[#series + 1] = { name = u.name, color = u.color, values = profileValues(u), width = 2 }
				lifted[#series] = page.selected[u.key]
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
			markers = milestoneMarkers(of, nil, false, nil)
		elseif column and ctx.filters.shareOfTeam and isGrouped and column.fmt == "si" then
			kind = "stacked"
			for _, u in ipairs(plotted) do
				for _, team in ipairs(u.teams) do
					series[#series + 1] = {
						name = team.name,
						color = { team.accent[1], team.accent[2], team.accent[3] },
						points = pointsOf({ team.id }, column.key, perMinute),
					}
					lifted[#series] = page.selected[u.key]
				end
			end
			title = ctx.columnTitle(column)
				.. " \194\183 "
				.. ctx.L.switch.shareOfTeam
				.. " \194\183 "
				.. namesOf(plotted)
			markers = milestoneMarkers(marked, nil, false, column)
		elseif column then
			local indexByKey = {}
			series, lifted = lineSeries(column, plotted, perMinute)
			for i, u in ipairs(plotted) do
				indexByKey[u.key] = i
			end
			title = ctx.columnTitle(column)
			if perMinute then
				title = title .. ctx.L.perMinuteSuffix
			end
			if column.fmt == "percent" then
				yFormat = percentFormat
			end
			markers = milestoneMarkers(marked, indexByKey, false, column)
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
			chartOf:configure({ font = ctx.font(), fontSize = fs, title = entry.label })
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
			page.setLayout(args[1], args[2], args[3], args[4], args[5], args[6], args[7])
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
			return #picked == 1 and picked[1] == b.unit
		end
		if #b.members == 0 then
			return false
		end
		for _, m in ipairs(b.members) do
			if not page.selected[m.unit.key] or page.hidden[m.unit.key] then
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
			-- caption, which stands for the whole ally team.
			if i == page.hover.block and not lit and (isGrouped or b.all or page.hover.legend == 0) then
				Highlight(b.x1, py1, b.x2, py2, cs, look.rowHoverOpacity, look.white)
			end
			if b.labelX then
				ctx.queueText((lit and colors.selected or colors.dim) .. b.label, b.labelX, cy, fs, "ov")
			end
			if b.swatch and b.unit then
				local c = b.unit.color
				Color(c[1], c[2], c[3], (lit or i == page.hover.block) and 1 or 0.85)
				Rect(b.swatch[1], b.swatch[2], b.swatch[3], b.swatch[4])
			end
		end
		for i, item in ipairs(page.barItems) do
			local c = item.team.accent
			local key = item.unit.key
			local hovered = i == page.hover.legend or (isGrouped and item.block == page.barBlocks[page.hover.block])
			if page.hidden[key] then
				Color(c[1], c[2], c[3], hovered and 0.22 or 0.12)
				Rect(item.x1, item.y1, item.x2, item.y2)
				frame(item.x1, item.y1, item.x2, item.y2, 1, { c[1], c[2], c[3], 0.55 })
			else
				local alpha = (anyPicked and not page.selected[key]) and 0.3 or 0.9
				Color(c[1], c[2], c[3], hovered and alpha + 0.1 or alpha)
				Rect(item.x1, item.y1, item.x2, item.y2)
			end
		end
		-- The grouping switch at the end of the bar, captioned like a settings row.
		local tog = groupToggleRect()
		if tog then
			local label = ctx.L.switch.groupByTeam
			local hovered = page.hover.group == 1
			ctx.queueText(
				(page.grouped and colors.selected or colors.dim) .. label,
				tog[1] - metrics.rowPad,
				cy,
				fs,
				"rov"
			)
			ctx.draw.Toggle(tog[1], tog[2], tog[3], tog[4], page.grouped, hovered)
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
				local key = item.unit.key
				local on = page.selected[key] and not page.hidden[key] and not item.block.lit
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
		Color(1, 1, 1, 1)

		if page.empty and not page.gridded() then
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
			local on = not page.milestoneOff[kind]
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
				mini.chart:setHover(hit)
				mini.chart:draw()
			end
			page.drawKinds()
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
					ctx.look.rowHoverOpacity,
					ctx.look.white
				)
				ctx.draw.Color(1, 1, 1, 1)
			end
			return
		end
		local hit = inside and chart:hitTest(mx, my) or nil
		-- One chart fills the page: no small one answers for the tooltip any more.
		page.chartHit, page.miniHit = hit, nil
		chart:setHover(hit)
		chart:draw()
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
		page.hover.stat, page.hover.legend, page.hover.block, page.hover.kind, page.hover.group = 0, 0, 0, 0, 0
		local tog = groupToggleRect()
		if tog and mx >= tog[3] - groupReserve() and mx <= tog[3] and my >= tog[2] and my <= tog[4] then
			page.hover.group = 1
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
		if page.listShown() and mx >= r.list[1] and mx <= r.list[3] then
			for i = 1, #page.statList do
				local _, y1, _, y2 = statRect(i)
				if my > y1 and my <= y2 and not page.statList[i].divider then
					page.hover.stat = i
				end
			end
		elseif my >= r.bar[2] and my <= r.bar[4] then
			for i, b in ipairs(page.barBlocks) do
				if mx >= b.x1 and mx < b.x2 then
					page.hover.block = i
				end
			end
			for i, item in ipairs(page.barItems) do
				if mx >= item.x1 and mx < item.x2 and my >= item.y1 and my <= item.y2 then
					page.hover.legend = i
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
			.. page.hover.group
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
				page.milestoneOff[row.key] = not page.milestoneOff[row.key] or nil
				changed()
				return true
			end
			-- A press anywhere else puts the card away.
			page.kindsOpen = false
			changed()
			return true
		end
		if page.hover.stat > 0 then
			local entry = page.statList[page.hover.stat]
			---@cast entry -?
			if button ~= 3 and entry.back then
				-- Back to the grid the chart was opened from.
				page.zoom = nil
				changed()
			elseif button ~= 3 then
				page.stat = entry.key
				-- The list is how a stat is opened, whatever the grid is showing.
				page.zoom = entry.key
				changed()
			end
			return true
		end
		if button ~= 3 and page.miniHit then
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
		if page.hover.group == 1 and button ~= 3 then
			page.setGrouped(not page.grouped)
			changed()
			return true
		end
		local block = page.hover.block > 0 and page.barBlocks[page.hover.block] or nil
		if block and block.me and button ~= 3 then
			-- Your own team alone, whatever was picked before.
			page.selected = { [block.unit.key] = true }
			page.hidden[block.unit.key] = nil
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
				allHidden = allHidden and page.hidden[u.key] == true
				allSelected = allSelected and page.selected[u.key] == true and not page.hidden[u.key]
			end
			local _, ctrl = Spring.GetModKeyState()
			if button == 3 then
				for _, u in ipairs(targets) do
					page.hidden[u.key] = not allHidden or nil
					if not allHidden then
						page.selected[u.key] = nil
					end
				end
			else
				if ctrl then
					page.selected = {}
				end
				for _, u in ipairs(targets) do
					local on = ctrl or not allSelected
					page.selected[u.key] = on or nil
					if on then
						page.hidden[u.key] = nil
					end
				end
			end
			changed()
			return true
		end
		return block ~= nil
	end

	-- What the units under the cursor are to the chart right now, and what the mouse does
	-- to them: a line on their state (selected, not, hidden, and what that means with
	-- the switches as they are), one on their milestones when those are on the chart,
	-- then the controls.
	local function barHint(targets)
		local L = "ui.teamStats.graph."
		local allHidden, allSelected, someSelected = true, true, false
		for _, u in ipairs(targets) do
			local on = page.selected[u.key] == true and not page.hidden[u.key]
			allHidden = allHidden and page.hidden[u.key] == true
			allSelected = allSelected and on
			someSelected = someSelected or on
		end
		local composition = page.stat == "composition"
		local anyPicked = #pickedUnits() > 0
		local state
		if allHidden then
			state = "hidden"
		elseif allSelected then
			state = composition and "counted" or "lit"
		elseif someSelected then
			state = "some"
		elseif anyPicked then
			state = composition and "notCounted" or "faded"
		else
			state = composition and "allCounted" or "alike"
		end
		local group = #targets > 1
		local lines = { ctx.colors.title .. ctx.i18n(L .. "state." .. state) }
		if ctx.filters.milestones and not allHidden and (allSelected or not anyPicked) then
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
			return hovered.cfg.title, hovered:describe(page.chartHit)
		end
		if page.hover.stat > 0 then
			local entry = page.statList[page.hover.stat]
			---@cast entry -?
			if entry.back then
				return entry.label, ctx.i18n("ui.teamStats.graph.overviewDesc")
			end
			if entry.column then
				return entry.label, ctx.L.desc[entry.key]
			end
			-- The charts that are not a column of the table explain themselves by key.
			return entry.label, ctx.i18n("ui.teamStats.graph." .. entry.key .. "Desc")
		end
		if page.hover.group == 1 then
			return ctx.L.switch.groupByTeam, ctx.L.switchDesc.groupByTeam
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
				if ctx.filters.milestones then
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
		}
	end

	function page.setConfig(data)
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
