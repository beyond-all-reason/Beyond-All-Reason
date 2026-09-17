-- The Graphs page of the team stats panel: one chart of the picked stat over the game,
-- the teams as its series, with a stat list beside it and a legend bar above it that
-- highlights or hides a team. The panel owns the frame, the sidebar and the switches
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

-- The legend bar's looks: a block is a button, the picked one lit and framed warm.
local PLATE = { 1, 1, 1, 0.05 }
local PICKED_FRAME = { 1, 0.78, 0.51, 0.85 }

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
		open = false,
		stat = "damageDealt",
		---@type table<string, boolean>
		hidden = {},
		-- The highlighted unit's key; nil is every team alike. Starts on the viewer's own
		-- team, when they have one.
		---@type string?
		highlight = nil,
		highlightSet = false,
		hover = { stat = 0, legend = 0, block = 0 },
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
		-- highlight, the hidden set, the bar's layout. Part of the panel's bake signature.
		gen = 0,
		---@type table?
		rects = nil,
		---@type table?
		chartHit = nil,
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
		return ctx.filters.groupByTeam and not ctx.isFFA
	end

	----------------------------------------------------------------
	-- The stat list
	----------------------------------------------------------------

	-- The stats of the sidebar's group, the composition chart first in its group. The
	-- gadget's columns, and the ones only it keeps a history of, only while it is there.
	function page.rebuildStatList()
		local group = ctx.groupByKey[ctx.selectedGroup()] or ctx.GROUPS[1]
		local list = {}
		if group.key == "composition" and ctx.gadgetOn() then
			list[#list + 1] = { key = "composition", label = ctx.i18n("ui.teamStats.graph.composition") }
		end
		for i = 1, #group.columns do
			local column = ctx.COLUMNS[group.columns[i]]
			if ctx.gadgetOn() or not (column.gadget or column.liveOnly) then
				list[#list + 1] = { key = column.key, label = ctx.columnTitle(column), column = column }
			end
		end
		page.statList = list
		local found = false
		for i = 1, #list do
			if list[i].key == page.stat then
				found = true
			end
		end
		if not found and list[1] then
			page.stat = list[1].key
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
	-- list down the left, the legend bar along the top, the chart in the rest.
	function page.setLayout(x1, y1, x2, y2, s)
		page.scale = s
		local listW = mathFloor(200 * s)
		local gap = mathFloor(12 * s)
		local barH = ctx.metrics.rowHeight + mathFloor(8 * s)
		page.rects = {
			list = { x1, y1, x1 + listW, y2 },
			bar = { x1 + listW + gap, y2 - barH, x2, y2 },
			chart = { x1 + listW + gap, y1, x2, y2 - barH - mathFloor(4 * s) },
			rowH = ctx.metrics.rowHeight,
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

	function page.setFont(font, fontSize)
		chart:configure({ font = font, fontSize = fontSize })
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
		-- The first highlight, and one that stopped standing for anything (the grouping
		-- switch turned), is the viewer's own unit; a cleared one stays cleared.
		if not page.highlightSet or (page.highlight and not byKey[page.highlight]) then
			page.highlightSet = true
			page.highlight = nil
			for _, unit in ipairs(units) do
				if unit.isLocal then
					page.highlight = unit.key
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
		for i = 2, #blocks do
			local b = blocks[i]
			count = count + #b.members
			b.labelW = widthOf(b.label)
			labelW = labelW + b.labelW + pad
		end
		local teamBlocks = #blocks - 1
		-- The All button always keeps its caption; the team blocks share the rest.
		local avail = r.bar[3] - r.bar[1] - pad * 2 - (all.labelW + pad * 3)
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
		for _, unit in ipairs(page.units) do
			unit.barX1, unit.barX2 = nil, nil
		end
		local half = mathFloor(pad * 0.5)
		for _, b in ipairs(blocks) do
			-- The plate runs from the caption to the last square, with half a pad of air.
			b.x1 = x - half
			if b.all then
				b.labelX = x
				x = x + b.labelW
			else
				if withLabels then
					b.labelX = x
					x = x + b.labelW + pad
				end
				for _, m in ipairs(b.members) do
					items[#items + 1] = { unit = m.unit, team = m.team, x1 = x, y1 = y1, x2 = x + square, y2 = y2 }
					m.unit.barX1 = mathMin(m.unit.barX1 or x, x)
					m.unit.barX2 = mathMax(m.unit.barX2 or x + square, x + square)
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

	-- The milestones of these units as pictures on the chart, each framed in its unit's
	-- colour, on the unit's series where `indexByKey` names one, else in the lane.
	local function milestoneMarkers(list, indexByKey)
		local markers = {}
		local live = ctx.live()
		if not live or not ctx.filters.milestones then
			return markers
		end
		for _, unit in ipairs(list) do
			for _, teamID in ipairs(unit.members) do
				local team = live[teamID]
				for _, m in ipairs(team and team.milestones or {}) do
					local ud = m.unitDefID and UnitDefs[m.unitDefID] or nil
					---@cast ud table?
					local label = ctx.L.milestone[m.key] or m.key
					if ud then
						label = label .. " (" .. (ud.translatedHumanName or ud.name) .. ")"
					end
					markers[#markers + 1] = {
						x = m.frame,
						texture = ud and ("#" .. m.unitDefID) or nil,
						text = Graph.frameLabel(m.frame) .. "  " .. label,
						series = indexByKey and indexByKey[unit.key] or nil,
						frame = unit.color,
					}
				end
			end
		end
		return markers
	end

	-- The chart's series from the pick and the switches: the teams' runs of the stat as
	-- lines, the highlighted one lifted and its milestones on it (every team's when none
	-- is highlighted); or a composition as bands, the highlighted team's or everyone's
	-- together; or, with the share switch on, the highlighted ally team's members as
	-- shares of it, or every team as a share of the whole when none is highlighted.
	function page.build()
		rebuildSamples()
		page.rebuildUnits()
		local column = ctx.COLUMNS[page.stat]
		local isGrouped = grouped()
		local perMinute = ctx.filters.perMinute and column and column.rate or false
		local focus = page.highlight and page.unitByKey[page.highlight] or nil
		local shown = shownUnits()
		local series, markers = {}, {}
		local kind = "line"
		local title
		local yFormat = nil
		local highlightIndex = nil
		local ownLegend = false
		local all = ctx.i18n("ui.teamStats.graph.all")

		if page.stat == "composition" then
			kind = "stacked"
			ownLegend = true
			local members = {}
			for _, u in ipairs(focus and { focus } or shown) do
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
			title = ctx.i18n("ui.teamStats.graph.composition") .. " \194\183 " .. (focus and focus.name or all)
			markers = milestoneMarkers(focus and { focus } or shown, nil)
		elseif column and ctx.filters.shareOfTeam and isGrouped and column.fmt == "si" then
			kind = "stacked"
			if focus then
				for _, team in ipairs(focus.teams) do
					series[#series + 1] = {
						name = team.name,
						color = { team.accent[1], team.accent[2], team.accent[3] },
						points = pointsOf({ team.id }, column.key, perMinute),
					}
				end
			else
				for _, u in ipairs(shown) do
					series[#series + 1] = {
						name = u.name,
						color = u.color,
						points = pointsOf(u.members, column.key, perMinute),
					}
				end
			end
			title = ctx.columnTitle(column)
				.. " \194\183 "
				.. ctx.L.switch.shareOfTeam
				.. " \194\183 "
				.. (focus and focus.name or all)
			markers = milestoneMarkers(focus and { focus } or shown, nil)
		elseif column then
			local indexByKey = {}
			for _, u in ipairs(shown) do
				series[#series + 1] = {
					name = u.name,
					color = u.color,
					points = pointsOf(u.members, column.key, perMinute, column.clamp),
					width = 2,
				}
				indexByKey[u.key] = #series
				if u.key == page.highlight then
					highlightIndex = #series
				end
			end
			title = ctx.columnTitle(column)
			if perMinute then
				title = title .. ctx.L.perMinuteSuffix
			end
			if column.fmt == "percent" then
				yFormat = percentFormat
			end
			markers = milestoneMarkers(focus and { focus } or shown, indexByKey)
		end

		page.empty = true
		for _, s in ipairs(series) do
			if #s.points > 0 then
				page.empty = false
			end
		end
		-- The bands of the composition chart are named by the chart itself; teams are
		-- named by the legend bar. The axis format is set straight: a nil handed to
		-- configure would leave the last one.
		chart.cfg.yFormat = yFormat
		chart:configure({ kind = kind, title = title, legend = ownLegend, bandLabels = ownLegend })
		chart:setSeries(series)
		chart:setMarkers(markers)
		chart:setHighlight(kind == "line" and highlightIndex or nil)
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

	-- Whether a block of the bar is the picked one: All with no highlight, an ally
	-- team's when the grouping switch makes the block the unit.
	local function blockLit(b)
		if b.all then
			return page.highlight == nil
		end
		return grouped() and b.unit ~= nil and b.unit.key == page.highlight
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
		for i, entry in ipairs(page.statList) do
			local x1, y1, x2, y2 = statRect(i)
			local selected = entry.key == page.stat
			if selected then
				RectRound(x1 + metrics.catInset, y1, x2 - metrics.catInset, y2, cs, 1, 1, 1, 1, look.selectedFill)
			elseif i == page.hover.stat then
				Highlight(x1 + metrics.catInset, y1, x2 - metrics.catInset, y2, cs, look.rowHoverOpacity, look.white)
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

		-- The legend bar: a plate per block like a button, lit when it is the picked one
		-- or hovered, then its caption and squares; the picked one framed warm.
		local isGrouped = grouped()
		local cy = mathFloor((r.bar[2] + r.bar[4]) * 0.5)
		local py1, py2 = r.bar[2] + r.inset, r.bar[4] - r.inset
		local fw = r.frame
		for i, b in ipairs(page.barBlocks) do
			local lit = blockLit(b)
			RectRound(b.x1, py1, b.x2, py2, cs, 1, 1, 1, 1, lit and look.selectedFill or PLATE)
			if lit then
				-- A frame that follows the plate's corners.
				ctx.draw.RectRoundOutline(b.x1, py1, b.x2, py2, cs, fw, 1, 1, 1, 1, PICKED_FRAME, PICKED_FRAME)
			end
			if i == page.hover.block and not lit then
				Highlight(b.x1, py1, b.x2, py2, cs, look.rowHoverOpacity, look.white)
			end
			if b.labelX then
				ctx.queueText((lit and colors.selected or colors.dim) .. b.label, b.labelX, cy, fs, "ov")
			end
		end
		for i, item in ipairs(page.barItems) do
			local c = item.team.accent
			local hidden = page.hidden[item.unit.key]
			local alpha = hidden and 0.22 or (i == page.hover.legend and 1 or 0.9)
			Color(c[1], c[2], c[3], alpha)
			Rect(item.x1, item.y1, item.x2, item.y2)
		end
		if not isGrouped then
			for _, unit in ipairs(page.units) do
				if unit.key == page.highlight and unit.barX1 then
					frame(unit.barX1 - fw, page.barY1 - fw, unit.barX2 + fw, page.barY2 + fw, fw, PICKED_FRAME)
				end
			end
		end
		Color(1, 1, 1, 1)

		if page.empty then
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

	-- The chart itself, after the panel's list: its own list plus the hover overlay.
	function page.drawChart(mx, my)
		if page.dirty then
			page.build()
		end
		local r = page.rects
		local hit = nil
		if r and mx >= r.chart[1] and mx <= r.chart[3] and my >= r.chart[2] and my <= r.chart[4] then
			hit = chart:hitTest(mx, my)
		end
		page.chartHit = hit
		chart:setHover(hit)
		chart:draw()
	end

	----------------------------------------------------------------
	-- The cursor
	----------------------------------------------------------------

	-- Which list entry, legend square or legend block the cursor is over, for the
	-- panel's bake signature.
	function page.hoverAt(mx, my)
		page.hover.stat, page.hover.legend, page.hover.block = 0, 0, 0
		local r = page.rects
		if not r then
			return "0|0|0|0"
		end
		if mx >= r.list[1] and mx <= r.list[3] then
			for i = 1, #page.statList do
				local _, y1, _, y2 = statRect(i)
				if my > y1 and my <= y2 then
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
		return page.hover.stat .. "|" .. page.hover.legend .. "|" .. page.hover.block .. "|" .. page.gen
	end

	-- The unit under the cursor in the bar: a square's, or the block's ally team when
	-- the grouping switch makes the block the unit.
	local function unitUnderCursor()
		if page.hover.legend > 0 then
			local item = page.barItems[page.hover.legend]
			---@cast item -?
			return item.unit
		end
		if page.hover.block > 0 then
			local b = page.barBlocks[page.hover.block]
			---@cast b -?
			return b.unit
		end
		return nil
	end

	local function changed()
		page.dirty = true
		page.gen = page.gen + 1
		ctx.playSound()
	end

	-- A press: picks a stat; on the bar, highlights the unit under the cursor, or hides
	-- it with the right button; All clears the highlight.
	function page.mousePress(x, y, button)
		page.hoverAt(x, y)
		if page.hover.stat > 0 then
			local entry = page.statList[page.hover.stat]
			---@cast entry -?
			if button ~= 3 and entry.key ~= page.stat then
				page.stat = entry.key
				changed()
			end
			return true
		end
		local block = page.hover.block > 0 and page.barBlocks[page.hover.block] or nil
		if block and block.all then
			if button ~= 3 and page.highlight ~= nil then
				page.highlight = nil
				changed()
			end
			return true
		end
		local unit = unitUnderCursor()
		if unit then
			if button == 3 then
				page.hidden[unit.key] = not page.hidden[unit.key] or nil
			elseif page.highlight == unit.key then
				page.highlight = nil
			else
				page.highlight = unit.key
			end
			changed()
			return true
		end
		return block ~= nil
	end

	-- The tooltip for the cursor: the chart's description, a stat's explanation, or the
	-- team under the cursor in the bar and how the bar works.
	function page.tooltip()
		if page.chartHit then
			return chart.cfg.title, chart:describe(page.chartHit)
		end
		if page.hover.stat > 0 then
			local entry = page.statList[page.hover.stat]
			---@cast entry -?
			if entry.column then
				return entry.label, ctx.L.desc[entry.key]
			end
			return entry.label, ctx.i18n("ui.teamStats.graph.compositionDesc")
		end
		if page.hover.legend > 0 then
			local item = page.barItems[page.hover.legend]
			---@cast item -?
			local title = item.team.name
			if item.unit.name ~= item.team.name then
				title = item.team.name .. " \194\183 " .. item.unit.name
			end
			return title, ctx.i18n("ui.teamStats.graph.legendHint")
		end
		if page.hover.block > 0 then
			local b = page.barBlocks[page.hover.block]
			---@cast b -?
			if b.all then
				return b.label, ctx.i18n("ui.teamStats.graph.allHint")
			end
			return b.label,
				b.unit and ctx.i18n("ui.teamStats.graph.legendHint") or ctx.i18n("ui.teamStats.graph.blockHint")
		end
		return nil
	end

	----------------------------------------------------------------
	-- Housekeeping
	----------------------------------------------------------------

	function page.getConfig()
		return { graphStat = page.stat }
	end

	function page.setConfig(data)
		if type(data.graphStat) == "string" then
			page.stat = data.graphStat
		end
	end

	-- The switches and the sidebar change what the chart is made of.
	function page.invalidate()
		page.dirty = true
	end

	function page.destroy()
		chart:destroy()
	end

	return page
end

return M
