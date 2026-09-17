-- Charts for widgets: line graphs, 100% stacked areas and radar charts. The picture is
-- baked into a display list and only the hover overlay is drawn each frame, so a chart
-- costs a list call while nothing changes.
--
--   local Graph = VFS.Include("luaui/Include/graph.lua")
--   local chart = Graph.new({
--       kind = "line",                         -- "line" | "stacked" | "radar"
--       x = 100, y = 100, width = 600, height = 300,   -- bottom-left corner, screen pixels
--       font = WG.fonts.getFont(), fontSize = 12,
--       title = "Metal income",
--       xs = { 0, 450, 900, ... },              -- one x per sample, shared by the series
--       series = {
--           { name = "Floris", color = { 0.4, 0.7, 1 }, values = { 12, 15, 30, ... } },
--           { name = "Nemo", color = { 1, 0.5, 0.3 }, points = { { 0, 3 }, { 450, 8 } } },
--       },
--       xFormat = function(x) return ... end,   -- axis labels and tooltips
--       yFormat = function(y) return ... end,
--       smooth = true,                          -- monotone cubic between samples, no overshoot
--       markers = {                             -- unit pictures on the chart, with a text for hover
--           { x = 3000, texture = "#143", text = "1:40 First factory (Bot Lab)", series = 1 },
--           { x = 3000, texture = "#143", text = "...", y = 2.2 },  -- or at a value of its own
--       },
--   })
--   chart:draw()                              -- in DrawScreen
--   local hit = chart:hitTest(mx, my)          -- nil, or what is under the cursor
--   chart:setHover(hit)                        -- what the overlay marks
--   WG.tooltip.ShowTooltip("mychart", chart:describe(hit))
--
-- Everything in the constructor can be changed later through chart:configure({ ... }),
-- chart:setSeries(list), chart:setMarkers(list), chart:setBounds(x, y, w, h) and
-- chart:setHighlight(seriesIndex, or { [seriesIndex] = true, ... } for several); each
-- marks the picture for a rebuild on the next draw.
-- chart:destroy() frees the list. Radar charts take `radar = { axes = { { key = "speed",
-- label = "Speed", max = 100 }, ... }, rings = 4 }` and series with `values` keyed by axis
-- (an array in axis order, or a table by axis key). A stacked chart turns every sample
-- into shares of that sample's total, so the y axis is 0 to 100%.

---@class Graph
---@field cfg table<string, any>
---@field series table[]
---@field markers table[]
---@field highlight integer|table<integer, boolean>|nil
---@field highlightKey any
---@field hover table?
---@field list integer?
---@field dirty boolean
---@field pending table[]
---@field pendingCount integer
---@field xs number[]
---@field prepared table[]
---@field plot table<string, number>
---@field area table<string, number>
---@field placed table[]
---@field markerRow table<integer, integer>
---@field markerSize number
---@field markerLaneRows integer
---@field yMin number
---@field yMax number
---@field yStep number
---@field xMin number
---@field xMax number
---@field sx fun(x: number): number
---@field sy fun(y: number): number
---@field xFormatter fun(v: number): string
---@field yFormatter fun(v: number): string
---@field radar table<string, number>
---@field axes table[]
---@field axisMax fun(ai: integer): number
---@field axisPoint fun(ai: integer, share: number): number, number
local Graph = {}
Graph.__index = Graph

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glColor = gl.Color
local glTexture = gl.Texture
local glTexCoord = gl.TexCoord
local glLineWidth = gl.LineWidth
-- Anti-aliased lines; absent in an offline stub.
---@type function?
local glSmoothing = gl.Smoothing
local GL_LINES = GL.LINES
local GL_LINE_STRIP = GL.LINE_STRIP
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local GL_QUADS = GL.QUADS

local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathAbs = math.abs
local mathHuge = math.huge
local mathSqrt = math.sqrt
local mathCos = math.cos
local mathSin = math.sin
local mathPi = math.pi
local mathLog10 = math.log10
local stringFormat = string.format
local stringChar = string.char

----------------------------------------------------------------
-- Defaults
----------------------------------------------------------------

---@type table<string, any>
local DEFAULTS = {
	kind = "line",
	x = 0,
	y = 0,
	width = 300,
	height = 150,
	fontSize = 12,
	-- Room between the frame and what is drawn inside it, in pixels; scales with the font.
	pad = nil,
	title = nil,
	-- The values along x, one per sample, shared by every series that gives `values`. Left
	-- out, samples are numbered from 1.
	xs = nil,
	xFormat = nil,
	yFormat = nil,
	-- Stacked: each band named inside it at its right end, where it is thick enough.
	bandLabels = false,
	-- Bands of colour laid across the plot between two values, under everything else:
	-- { { from = 0.5, to = 1.5, color = { r, g, b, a } }, ... }.
	valueBands = nil,
	-- The y axis: fixed ends, or found from the data (a line chart always shows zero).
	yMin = nil,
	yMax = nil,
	includeZero = true,
	gridLines = 4,
	xTicks = 5,
	-- "frames" makes the x axis a game clock: ticks on whole seconds and minutes, labels
	-- as m:ss. `xStep` fixes the tick step in x units instead.
	xUnit = nil,
	xStep = nil,
	-- Curves through the samples rather than corners at them. Steps between two samples
	-- come from the pixel distance when left nil.
	smooth = false,
	smoothSteps = nil,
	lineWidth = 2,
	-- A faint fill under each line.
	fill = false,
	legend = true,
	-- Markers: pictures with a hover text, at an x, on a series or in a lane above the plot.
	-- The picture is zoomed in by this share of its edges (nil: a subtle share that grows
	-- as the picture shrinks), its corners cut off by this much (nil: a small cut that
	-- grows with the picture, like the unit pictures elsewhere), and framed this thick.
	markerSize = nil,
	markerZoom = nil,
	markerCorner = nil,
	markerFrameWidth = 2,
	-- The lane of markers above the plot never takes more than this share of the chart's
	-- height: pictures shrink (down to `markerMinSize`) until the rows they need fit, and
	-- the rows past that wrap back into the lane, where the hovered one is drawn on top.
	markerLaneShare = 0.4,
	markerMinSize = 14,
	-- How much larger the hovered picture is drawn.
	markerHoverScale = 1.2,
	radar = {
		rings = 4,
		axes = nil,
		fill = true,
		-- The axes are named around the wheel; off for a chart too small to read them.
		labels = true,
	},
	look = {
		-- A backdrop under the whole chart, for one drawn straight over the world rather
		-- than inside a panel. nil for none.
		background = nil,
		plotFill = { 0, 0, 0, 0.14 },
		grid = { 1, 1, 1, 0.07 },
		axis = { 1, 1, 1, 0.22 },
		text = "\255\195\195\195",
		title = "\255\235\235\235",
		outline = { 0, 0, 0, 0.4 },
		crosshair = { 1, 1, 1, 0.22 },
		hoverDot = { 1, 1, 1, 0.9 },
		-- The other series step back to this share of their colour when one is highlighted.
		dimAlpha = 0.22,
		areaAlpha = 0.6,
		fillAlpha = 0.16,
		markerFrame = { 1, 1, 1, 0.35 },
		markerTick = { 1, 1, 1, 0.22 },
		radarFillAlpha = 0.22,
	},
}

local function copyInto(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			copyInto(dst[k], v)
		elseif type(v) == "table" then
			local t = {}
			copyInto(t, v)
			dst[k] = t
		else
			dst[k] = v
		end
	end
	return dst
end

----------------------------------------------------------------
-- Numbers
----------------------------------------------------------------

local function isFinite(v)
	return type(v) == "number" and v == v and v ~= mathHuge and v ~= -mathHuge
end

-- A round step for about `count` divisions of `range`: 1, 2 or 5 times a power of ten.
local function niceStep(range, count)
	if range <= 0 or count < 1 then
		return 1
	end
	local raw = range / count
	local mag = 10 ^ mathFloor(mathLog10(raw))
	local norm = raw / mag
	local step
	if norm < 1.5 then
		step = 1
	elseif norm < 3 then
		step = 2
	elseif norm < 7 then
		step = 5
	else
		step = 10
	end
	return step * mag
end
Graph.niceStep = niceStep

local function defaultFormat(v)
	if not isFinite(v) then
		return "-"
	end
	if string.formatSI and mathAbs(v) >= 1000 then
		return string.formatSI(v)
	end
	if mathAbs(v) < 10 and v ~= mathFloor(v) then
		return stringFormat("%.1f", v)
	end
	return stringFormat("%d", mathFloor(v + 0.5))
end

-- A frame count as a game clock: m:ss, and h:mm:ss past the hour.
local function frameLabel(frames)
	if not isFinite(frames) then
		return "-"
	end
	local seconds = mathFloor(frames / 30 + 0.5)
	local h = mathFloor(seconds / 3600)
	local m = mathFloor(seconds / 60) % 60
	local s = seconds % 60
	if h > 0 then
		return stringFormat("%d:%02d:%02d", h, m, s)
	end
	return stringFormat("%d:%02d", m, s)
end
Graph.frameLabel = frameLabel

local function colorCode(c)
	return stringChar(
		255,
		mathMax(1, mathFloor(c[1] * 255)),
		mathMax(1, mathFloor(c[2] * 255)),
		mathMax(1, mathFloor(c[3] * 255))
	)
end

-- Monotone cubic interpolation (Fritsch-Carlson): a curve through the samples that never
-- overshoots them, so a value that never went above 10 is never drawn above 10.
local function monotoneSlopes(xs, ys)
	local n = #xs
	---@type table<integer, number>
	local m = {}
	if n < 2 then
		m[1] = 0
		return m
	end
	---@type table<integer, number>
	local d = {}
	for i = 1, n - 1 do
		local dx = xs[i + 1] - xs[i]
		d[i] = dx > 0 and (ys[i + 1] - ys[i]) / dx or 0
	end
	m[1] = d[1]
	m[n] = d[n - 1]
	for i = 2, n - 1 do
		if d[i - 1] * d[i] <= 0 then
			m[i] = 0
		else
			m[i] = (d[i - 1] + d[i]) * 0.5
		end
	end
	for i = 1, n - 1 do
		if d[i] == 0 then
			m[i] = 0
			m[i + 1] = 0
		else
			local a = m[i] / d[i]
			local b = m[i + 1] / d[i]
			local s = a * a + b * b
			if s > 9 then
				local t = 3 / mathSqrt(s)
				m[i] = t * a * d[i]
				m[i + 1] = t * b * d[i]
			end
		end
	end
	return m
end

-- The y at `x` between samples i and i + 1, from the slopes.
local function hermite(xs, ys, m, i, x)
	local x1, x2 = xs[i], xs[i + 1]
	local h = x2 - x1
	if h <= 0 then
		return ys[i]
	end
	local t = (x - x1) / h
	local t2 = t * t
	local t3 = t2 * t
	local h00 = 2 * t3 - 3 * t2 + 1
	local h10 = t3 - 2 * t2 + t
	local h01 = -2 * t3 + 3 * t2
	local h11 = t3 - t2
	return h00 * ys[i] + h10 * h * m[i] + h01 * ys[i + 1] + h11 * h * m[i + 1]
end

----------------------------------------------------------------
-- Construction
----------------------------------------------------------------

function Graph.new(cfg)
	local self = setmetatable({}, Graph)
	---@cast self Graph
	self.cfg = copyInto({}, DEFAULTS)
	if cfg then
		copyInto(self.cfg, cfg)
	end
	self.series = self.cfg.series or {}
	self.markers = self.cfg.markers or {}
	self.cfg.series = nil
	self.cfg.markers = nil
	self.highlight = nil
	self.hover = nil
	self.list = nil
	self.dirty = true
	self.pending = {}
	self.pendingCount = 0
	self.placed = {}
	self.xs = {}
	self.prepared = {}
	return self
end

function Graph:configure(cfg)
	copyInto(self.cfg, cfg)
	if cfg.series then
		self.series = cfg.series
		self.cfg.series = nil
	end
	if cfg.markers then
		self.markers = cfg.markers
		self.cfg.markers = nil
	end
	self.dirty = true
end

function Graph:setSeries(series)
	self.series = series or {}
	self.dirty = true
end

function Graph:setMarkers(markers)
	self.markers = markers or {}
	self.dirty = true
end

function Graph:setBounds(x, y, width, height)
	local c = self.cfg
	if c.x ~= x or c.y ~= y or c.width ~= width or c.height ~= height then
		c.x, c.y, c.width, c.height = x, y, width, height
		self.dirty = true
	end
end

-- A highlight as a value that compares equal for the same series, set or not.
local function highlightKey(highlight)
	if type(highlight) ~= "table" then
		return highlight
	end
	local keys = {}
	for si, on in pairs(highlight) do
		if on then
			keys[#keys + 1] = si
		end
	end
	table.sort(keys)
	return "set:" .. table.concat(keys, ",")
end

-- The series drawn in front, the others stepped back: one index, or a set of them
-- ({ [index] = true }). nil for none.
function Graph:setHighlight(highlight)
	local key = highlightKey(highlight)
	if self.highlightKey ~= key then
		self.highlight = highlight
		self.highlightKey = key
		self.dirty = true
	end
end

-- What the overlay marks: a hit from hitTest, or nil.
function Graph:setHover(hit)
	self.hover = hit
end

function Graph:destroy()
	if self.list then
		glDeleteList(self.list)
		self.list = nil
	end
end

----------------------------------------------------------------
-- Text, queued while the list is built and printed in one batch
----------------------------------------------------------------

function Graph:text(str, x, y, opts, size)
	local n = self.pendingCount + 1
	self.pendingCount = n
	self.pending[n] = { str, x, y, size or self.cfg.fontSize, opts or "o" }
end

function Graph:flushText()
	local font = self.cfg.font
	if not font or self.pendingCount == 0 then
		self.pendingCount = 0
		return
	end
	font:Begin()
	-- The font is shared with every widget; pinned so a bake does not freeze in whatever
	-- outline the last one set.
	font:SetOutlineColor(self.cfg.look.outline)
	for i = 1, self.pendingCount do
		local p = self.pending[i]
		---@cast p -?
		font:Print(p[1], p[2], p[3], p[4], p[5])
		self.pending[i] = nil
	end
	font:End()
	self.pendingCount = 0
end

function Graph:textWidth(str, size)
	local font = self.cfg.font
	if not font then
		return #str * (size or self.cfg.fontSize) * 0.55
	end
	return font:GetTextWidth(str) * (size or self.cfg.fontSize)
end

----------------------------------------------------------------
-- Preparing the data: samples, ranges and the mapping to pixels
----------------------------------------------------------------

-- Reads every series into xs/ys arrays over one shared x list. A series giving `points`
-- is read as is; one giving `values` takes its x from cfg.xs or the sample number. A
-- value that is not a number is a gap.
function Graph:prepareSamples()
	local cfg = self.cfg
	local xs = {}
	local shared = cfg.xs
	local n = 0
	for _, s in ipairs(self.series) do
		if s.values then
			n = mathMax(n, #s.values)
		end
	end
	if shared then
		for i = 1, mathMax(n, #shared) do
			xs[i] = shared[i] or i
		end
	else
		for i = 1, n do
			xs[i] = i
		end
	end
	-- Series with their own points are sampled onto the shared list as well, and add
	-- their x values to it, so the hover column means the same for all.
	local extra = {}
	for _, s in ipairs(self.series) do
		if s.points and not s.values then
			for _, p in ipairs(s.points) do
				extra[p[1]] = true
			end
		end
	end
	local seen = {}
	for i = 1, #xs do
		seen[xs[i]] = true
	end
	for x in pairs(extra) do
		if not seen[x] then
			xs[#xs + 1] = x
			seen[x] = true
		end
	end
	table.sort(xs)

	local prepared = {}
	for si, s in ipairs(self.series) do
		local ys = {}
		if s.values then
			for i = 1, #xs do
				local v = s.values[i]
				ys[i] = isFinite(v) and v or nil
			end
		end
		---@type table?
		local raw = nil
		if not s.values then
			local byX = {}
			local rawByX = {}
			for _, p in ipairs(s.points or {}) do
				if isFinite(p[2]) then
					byX[p[1]] = p[2]
					-- A third value is what the point really is, when the plotted one was
					-- bounded: the tooltip says that one.
					if p[3] ~= nil then
						rawByX[p[1]] = p[3]
						raw = raw or {}
					end
				end
			end
			for i = 1, #xs do
				ys[i] = byX[xs[i]]
				if raw then
					raw[i] = rawByX[xs[i]]
				end
			end
		end
		prepared[si] = {
			index = si,
			source = s,
			name = s.name or ("Series " .. si),
			color = s.color or { 0.8, 0.8, 0.8 },
			ys = ys,
			raw = raw,
			width = s.width or cfg.lineWidth,
			smooth = s.smooth,
		}
	end
	self.xs = xs
	self.prepared = prepared
end

-- The rectangle the curves are drawn in: the frame less the axis labels, the legend, the
-- title and the marker lane.
function Graph:layout()
	local cfg = self.cfg
	local fs = cfg.fontSize
	local pad = cfg.pad or mathFloor(fs * 0.5)
	local left = cfg.x + pad
	local right = cfg.x + cfg.width - pad
	local bottom = cfg.y + pad
	local top = cfg.y + cfg.height - pad
	-- The title row is tall enough for the topmost axis label to stay clear of it. Whole
	-- pixels throughout, so edges and glyphs do not land between two.
	if cfg.title then
		top = mathFloor(top - fs * 1.9)
	end
	if cfg.legend and #self.series > 0 and cfg.kind ~= "radar" then
		top = mathFloor(top - fs * 1.7)
	end
	self.plot = { left = left, right = right, bottom = bottom, top = top, pad = pad }
end

-- The y range and the pixel mappings, for a line or a stacked chart.
function Graph:prepareLine()
	local cfg = self.cfg
	local plot = self.plot
	local fs = cfg.fontSize
	local xs = self.xs
	local stacked = cfg.kind == "stacked"

	-- Stacked: every sample's values become shares of the sample's total.
	if stacked then
		for i = 1, #xs do
			local total = 0
			for _, p in ipairs(self.prepared) do
				total = total + (p.ys[i] or 0)
			end
			for _, p in ipairs(self.prepared) do
				p.shares = p.shares or {}
				p.shares[i] = total > 0 and (p.ys[i] or 0) / total * 100 or 0
			end
		end
	end

	local yMin, yMax = mathHuge, -mathHuge
	if stacked then
		yMin, yMax = 0, 100
	else
		for _, p in ipairs(self.prepared) do
			for i = 1, #xs do
				local v = p.ys[i]
				if v then
					yMin = mathMin(yMin, v)
					yMax = mathMax(yMax, v)
				end
			end
		end
		if yMin == mathHuge then
			yMin, yMax = 0, 1
		end
		if cfg.includeZero then
			yMin = mathMin(yMin, 0)
			yMax = mathMax(yMax, 0)
		end
		if cfg.yMin then
			yMin = cfg.yMin
		end
		if cfg.yMax then
			yMax = cfg.yMax
		end
		if yMax <= yMin then
			yMax = yMin + 1
		end
		-- Round the top up to the grid, so the topmost line is labelled.
		local step = niceStep(yMax - yMin, cfg.gridLines)
		if not cfg.yMax then
			yMax = math.ceil(yMax / step - 1e-9) * step
		end
		if not cfg.yMin then
			yMin = mathFloor(yMin / step + 1e-9) * step
		end
	end
	self.yMin, self.yMax = yMin, yMax

	-- The y labels decide the left inset.
	local yFormat = cfg.yFormat
		or (stacked and function(v)
			return stringFormat("%d%%", mathFloor(v + 0.5))
		end)
		or defaultFormat
	self.yFormatter = yFormat
	local step = stacked and 25 or niceStep(yMax - yMin, cfg.gridLines)
	self.yStep = step
	local labelW = 0
	local v = yMin
	while v <= yMax + step * 0.001 do
		labelW = mathMax(labelW, self:textWidth(yFormat(v), fs))
		v = v + step
	end
	local left = mathFloor(plot.left + labelW + fs * 0.6)
	local bottom = mathFloor(plot.bottom + fs * 1.5)
	local right = plot.right

	local xMin, xMax = xs[1] or 0, xs[#xs] or 1
	if xMax <= xMin then
		xMax = xMin + 1
	end
	self.xMin, self.xMax = xMin, xMax
	local xScale = (right - left) / (xMax - xMin)
	self.sx = function(x)
		return left + (x - xMin) * xScale
	end
	-- The lane above the plot takes as many rows as the markers need, up to the share of
	-- the chart it may have; past that the pictures shrink, and past the smallest they
	-- wrap back into the lane and overlap, the hovered one drawn on top of the rest.
	local size = cfg.markerSize or mathFloor(fs * 2.6)
	-- Never more than a share of the chart itself, so the same marker is small on a small
	-- chart and readable on a large one.
	size = mathMax(6, mathMin(size, mathFloor((plot.top - bottom) * 0.22), mathFloor((right - left) * 0.18)))
	local laneMax = mathMax(0, (plot.top - bottom) * cfg.markerLaneShare)
	local minSize = mathMin(size, cfg.markerMinSize)
	local rows = self:markerRows(size)
	while rows > 0 and rows * size > laneMax and size > minSize do
		size = mathMax(minSize, mathFloor(size * 0.8))
		rows = self:markerRows(size)
	end
	if rows * size > laneMax then
		rows = mathMax(1, mathFloor(laneMax / size))
	end
	self.markerSize, self.markerLaneRows = size, rows
	local top = plot.top - (rows > 0 and (rows * size + mathFloor(fs * 0.4)) or 0)
	self.area = { left = left, right = right, bottom = bottom, top = top }
	local yScale = (top - bottom) / (yMax - yMin)
	self.sy = function(y)
		return bottom + (y - yMin) * yScale
	end
	if cfg.xUnit == "frames" then
		self.xFormatter = cfg.xFormat or frameLabel
	else
		self.xFormatter = cfg.xFormat or defaultFormat
	end
end

-- The lane above the plot: every marker without a series takes the first row of it in
-- which no earlier marker sits too close in x, rows stacking upwards. Returns the rows
-- needed at this picture size; each marker's row is kept for placeMarkers. Needs the x
-- mapping.
function Graph:markerRows(size)
	local rows = {}
	local count = 0
	self.markerRow = {}
	for mi, m in ipairs(self.markers) do
		if not m.series and isFinite(m.x) then
			local px = self.sx(m.x)
			local row = 1
			while true do
				local taken = false
				for _, other in ipairs(rows[row] or {}) do
					if mathAbs(other - px) < size then
						taken = true
					end
				end
				if not taken then
					break
				end
				row = row + 1
			end
			rows[row] = rows[row] or {}
			table.insert(rows[row], px)
			self.markerRow[mi] = row
			count = mathMax(count, row)
		end
	end
	return count
end

-- Where each marker goes: on its series' value at its x, or in its row of the lane.
function Graph:placeMarkers()
	local cfg = self.cfg
	local size = self.markerSize or cfg.markerSize or mathFloor(cfg.fontSize * 2.6)
	local area = self.area
	self.placed = {}
	for mi, m in ipairs(self.markers) do
		if isFinite(m.x) then
			local px = self.sx(m.x)
			if px >= area.left - size and px <= area.right + size then
				local py
				local onSeries = m.series and self.prepared[m.series]
				if m.y then
					-- A marker that names its own value sits there, wherever its series runs.
					py = self.sy(m.y)
					onSeries = true
				elseif onSeries then
					local i = self:nearestIndex(m.x)
					local v = cfg.kind == "stacked" and self:stackTop(m.series, i) or onSeries.ys[i]
					py = self.sy(v or self.yMin)
				else
					-- Rows past what the lane holds wrap back into it: those pictures
					-- overlap, and hovering one lifts it.
					local row = self.markerRow[mi] or 1
					local lane = mathMax(1, self.markerLaneRows or 1)
					row = (row - 1) % lane + 1
					py = area.top + mathFloor(cfg.fontSize * 0.4) + size * 0.5 + (row - 1) * size
				end
				local half = size * 0.5
				-- The picture stays inside the plot's width, so one at the first sample does
				-- not sit on the axis labels; its tick still points at the true x.
				local cx = mathMin(mathMax(px, area.left + half), area.right - half)
				-- And out of the way of the ones already placed: a run of milestones close
				-- together climbs away from the line instead of piling on one spot.
				if onSeries then
					local step = size * 0.9
					local tries = 0
					local up = true
					local base = py
					while tries < 12 do
						local clash = false
						for _, other in ipairs(self.placed) do
							if mathAbs(other.cx - cx) < size and mathAbs(other.py - py) < step * 0.9 then
								clash = true
								break
							end
						end
						if not clash then
							break
						end
						tries = tries + 1
						py = base + (up and 1 or -1) * mathFloor((tries + 1) / 2) * step
						up = not up
					end
					py = mathMin(mathMax(py, area.bottom + half), area.top - half)
				end
				self.placed[#self.placed + 1] = {
					marker = m,
					x1 = mathFloor(cx - half),
					y1 = mathFloor(py - half),
					x2 = mathFloor(cx + half),
					y2 = mathFloor(py + half),
					px = px,
					py = py,
					cx = cx,
					onSeries = onSeries ~= nil,
				}
			end
		end
	end
end

function Graph:nearestIndex(x)
	local xs = self.xs
	local best, bestD = 1, mathHuge
	for i = 1, #xs do
		local d = mathAbs(xs[i] - x)
		if d < bestD then
			best, bestD = i, d
		end
	end
	return best
end

-- The top of a stacked series at sample i: its share and every share under it.
function Graph:stackTop(si, i)
	local top = 0
	for k = 1, si do
		local p = self.prepared[k]
		---@cast p -?
		top = top + (p.shares[i] or 0)
	end
	return top
end

----------------------------------------------------------------
-- Drawing a line or stacked chart into the list
----------------------------------------------------------------

-- Whether a series is drawn at full strength: every one while nothing is highlighted.
local function isLit(self, si)
	local highlight = self.highlight
	if highlight == nil then
		return true
	elseif type(highlight) == "table" then
		return highlight[si] == true
	end
	return highlight == si
end

-- Whether a series is lifted above the rest: lit while something is highlighted.
local function isLifted(self, si)
	return self.highlight ~= nil and isLit(self, si)
end

local function alphaOf(self, si, base)
	if isLit(self, si) then
		return base
	end
	return base * self.cfg.look.dimAlpha
end

-- The series in drawing order: the stepped back ones first, so the highlighted ones lie
-- on top of them. Each one knows its own index (`index`, set when it was prepared), which
-- is what the alpha and the width are read off.
local function drawOrder(self)
	local order, lit = {}, {}
	for si, p in ipairs(self.prepared) do
		local list = isLit(self, si) and lit or order
		list[#list + 1] = p
	end
	for _, p in ipairs(lit) do
		order[#order + 1] = p
	end
	return order
end

-- The points of a curve in pixels: the samples, or the smoothed run through them. A gap
-- (a sample with no value) ends one run and starts the next.
function Graph:curveRuns(ys, smooth)
	local xs = self.xs
	local cfg = self.cfg
	local runs = {}
	local run = {}
	local rxs, rys = {}, {}
	local function flush()
		if #rxs > 0 then
			if smooth and #rxs > 2 then
				local m = monotoneSlopes(rxs, rys)
				local steps = cfg.smoothSteps
				if not steps then
					local px = (self.sx(rxs[#rxs]) - self.sx(rxs[1])) / mathMax(1, #rxs - 1)
					steps = mathMax(1, mathMin(10, mathFloor(px / 3)))
				end
				for i = 1, #rxs - 1 do
					for k = 0, steps - 1 do
						local x = rxs[i] + (rxs[i + 1] - rxs[i]) * k / steps
						run[#run + 1] = { x, hermite(rxs, rys, m, i, x) }
					end
				end
				run[#run + 1] = { rxs[#rxs], rys[#rys] }
			else
				for i = 1, #rxs do
					run[#run + 1] = { rxs[i], rys[i] }
				end
			end
			runs[#runs + 1] = run
		end
		run, rxs, rys = {}, {}, {}
	end
	for i = 1, #xs do
		local y = ys[i]
		if y then
			rxs[#rxs + 1] = xs[i]
			rys[#rys + 1] = y
		else
			flush()
		end
	end
	flush()
	return runs
end

-- Whole seconds, minutes and hours make the ticks of a time axis, at the coarsest step
-- that still gives about cfg.xTicks of them.
local TIME_STEPS = { 150, 300, 450, 900, 1800, 3600, 9000, 18000, 27000, 54000, 108000, 216000 }

function Graph:xTickStep()
	local cfg = self.cfg
	if cfg.xStep then
		return cfg.xStep
	end
	local range = self.xMax - self.xMin
	if cfg.xUnit == "frames" then
		for _, step in ipairs(TIME_STEPS) do
			if range / step <= cfg.xTicks then
				return step
			end
		end
		return TIME_STEPS[#TIME_STEPS]
	end
	return niceStep(range, cfg.xTicks)
end

function Graph:drawGrid()
	local cfg = self.cfg
	local look = cfg.look
	local area = self.area
	local fs = cfg.fontSize

	glColor(look.plotFill)
	glBeginEnd(GL_QUADS, function()
		glVertex(area.left, area.bottom)
		glVertex(area.right, area.bottom)
		glVertex(area.right, area.top)
		glVertex(area.left, area.top)
	end)

	-- The bands a chart lays across its plot, under its grid.
	for _, band in ipairs(cfg.valueBands or {}) do
		local c = band.color
		local y1, y2 = self.sy(mathMax(self.yMin, band.from)), self.sy(mathMin(self.yMax, band.to))
		if y2 > y1 then
			glColor(c[1], c[2], c[3], c[4] or 0.1)
			glBeginEnd(GL_QUADS, function()
				glVertex(area.left, y1)
				glVertex(area.right, y1)
				glVertex(area.right, y2)
				glVertex(area.left, y2)
			end)
		end
	end

	-- Horizontal lines and their labels.
	local v = self.yMin
	local yFormat = self.yFormatter
	glColor(look.grid)
	glBeginEnd(GL_LINES, function()
		local y = v
		while y <= self.yMax + self.yStep * 0.001 do
			local py = mathFloor(self.sy(y)) + 0.5
			glVertex(area.left, py)
			glVertex(area.right, py)
			y = y + self.yStep
		end
	end)
	while v <= self.yMax + self.yStep * 0.001 do
		local label = yFormat(v)
		self:text(look.text .. label, mathFloor(area.left - fs * 0.4), mathFloor(self.sy(v) - fs * 0.35), "or", fs)
		v = v + self.yStep
	end

	-- Vertical ticks and their labels.
	local xStep = self:xTickStep()
	local xFormat = self.xFormatter
	local x0 = math.ceil(self.xMin / xStep - 1e-9) * xStep
	glColor(look.grid)
	glBeginEnd(GL_LINES, function()
		local x = x0
		while x <= self.xMax + xStep * 0.001 do
			local px = mathFloor(self.sx(x)) + 0.5
			glVertex(px, area.bottom)
			glVertex(px, area.top)
			x = x + xStep
		end
	end)
	local x = x0
	while x <= self.xMax + xStep * 0.001 do
		self:text(look.text .. xFormat(x), mathFloor(self.sx(x)), mathFloor(area.bottom - fs * 1.2), "oc", fs)
		x = x + xStep
	end

	-- The axes.
	glColor(look.axis)
	glBeginEnd(GL_LINE_STRIP, function()
		glVertex(area.left + 0.5, area.top)
		glVertex(area.left + 0.5, area.bottom + 0.5)
		glVertex(area.right, area.bottom + 0.5)
	end)
end

function Graph:drawLines()
	local cfg = self.cfg
	local look = cfg.look
	local area = self.area
	local sx, sy = self.sx, self.sy
	local smoothAll = cfg.smooth

	local order = drawOrder(self)
	-- Fills first, so every line lies on top of every fill.
	if cfg.fill then
		for _, p in ipairs(order) do
			local c = p.color
			local a = alphaOf(self, p.index, look.fillAlpha)
			glColor(c[1], c[2], c[3], a)
			local smooth = p.smooth
			if smooth == nil then
				smooth = smoothAll
			end
			for _, run in ipairs(self:curveRuns(p.ys, smooth)) do
				glBeginEnd(GL_TRIANGLE_STRIP, function()
					for _, pt in ipairs(run) do
						local px = sx(pt[1])
						glVertex(px, area.bottom)
						glVertex(px, sy(pt[2]))
					end
				end)
			end
		end
	end

	if glSmoothing then
		glSmoothing(false, true, false)
	end
	for _, p in ipairs(order) do
		local c = p.color
		local a = alphaOf(self, p.index, 1)
		local width = p.width
		if isLifted(self, p.index) then
			width = width + 1
		end
		glLineWidth(width)
		glColor(c[1], c[2], c[3], a)
		local smooth = p.smooth
		if smooth == nil then
			smooth = smoothAll
		end
		for _, run in ipairs(self:curveRuns(p.ys, smooth)) do
			if #run == 1 then
				local px, py = sx(run[1][1]), sy(run[1][2])
				glBeginEnd(GL_QUADS, function()
					glVertex(px - width, py - width)
					glVertex(px + width, py - width)
					glVertex(px + width, py + width)
					glVertex(px - width, py + width)
				end)
			else
				glBeginEnd(GL_LINE_STRIP, function()
					for _, pt in ipairs(run) do
						glVertex(sx(pt[1]), sy(pt[2]))
					end
				end)
			end
		end
	end
	glLineWidth(1)
	if glSmoothing then
		glSmoothing(false, false, false)
	end
end

-- A stacked chart: every series is a band between the top of the one under it and its
-- own top, all shares of the sample's total. Smoothing runs on the shares and the bands
-- are normalised again after it, so they still add up to the whole at every pixel.
function Graph:drawStacked()
	local cfg = self.cfg
	local look = cfg.look
	local sx, sy = self.sx, self.sy
	local xs = self.xs
	local n = #self.prepared
	if n == 0 or #xs == 0 then
		return
	end

	-- Every band's share along the (smoothed) x run.
	local runs = {}
	for si, p in ipairs(self.prepared) do
		local smooth = p.smooth
		if smooth == nil then
			smooth = cfg.smooth
		end
		local filled = {}
		for i = 1, #xs do
			filled[i] = p.shares[i] or 0
		end
		runs[si] = self:curveRuns(filled, smooth)[1] or {}
	end
	local count = #runs[1]
	for si = 2, n do
		count = mathMin(count, #runs[si])
	end

	for si = 1, n do
		local p = self.prepared[si]
		---@cast p -?
		local c = p.color
		local a = alphaOf(self, si, look.areaAlpha)
		glColor(c[1], c[2], c[3], a)
		glBeginEnd(GL_TRIANGLE_STRIP, function()
			for k = 1, count do
				---@type number
				local total = 0
				for j = 1, n do
					total = total + mathMax(0, runs[j][k][2])
				end
				---@type number, number
				local under, own = 0, 0
				for j = 1, si do
					local share = mathMax(0, runs[j][k][2])
					if total > 0 then
						share = share / total * 100
					else
						share = 0
					end
					if j < si then
						under = under + share
					else
						own = share
					end
				end
				local px = sx(runs[si][k][1])
				glVertex(px, sy(under))
				glVertex(px, sy(mathMin(100, under + own)))
			end
		end)
	end

	-- The seams between the bands, so neighbours in similar colours stay apart.
	if glSmoothing then
		glSmoothing(false, true, false)
	end
	glLineWidth(1)
	glColor(0, 0, 0, 0.25)
	for si = 1, n - 1 do
		glBeginEnd(GL_LINE_STRIP, function()
			for k = 1, count do
				---@type number
				local total = 0
				for j = 1, n do
					total = total + mathMax(0, runs[j][k][2])
				end
				---@type number
				local top = 0
				for j = 1, si do
					local share = mathMax(0, runs[j][k][2])
					top = top + (total > 0 and share / total * 100 or 0)
				end
				glVertex(sx(runs[si][k][1]), sy(top))
			end
		end)
	end
	if glSmoothing then
		glSmoothing(false, false, false)
	end

	-- The bands named inside them at their right end, where they are thick enough for
	-- the name and the name is not most of the plot.
	if cfg.bandLabels and count > 0 then
		local fs = cfg.fontSize
		local k = count
		---@type number
		local total = 0
		for j = 1, n do
			total = total + mathMax(0, runs[j][k][2])
		end
		local right = mathFloor(sx(runs[1][k][1]) - fs * 0.4)
		local left = self.area and self.area.left or right
		---@type number
		local under = 0
		for si = 1, n do
			local share = total > 0 and mathMax(0, runs[si][k][2]) / total * 100 or 0
			local y0, y1 = sy(under), sy(mathMin(100, under + share))
			if mathAbs(y1 - y0) >= fs * 1.3 then
				local p = self.prepared[si]
				---@cast p -?
				if self:textWidth(p.name, fs) <= (right - left) * 0.5 then
					self:text(look.text .. p.name, right, mathFloor((y0 + y1) * 0.5), "orv", fs)
				end
			end
			under = under + share
		end
	end
end

-- The eight corners of a rect with its corners cut off by `cut`, counter-clockwise from
-- the bottom edge, as x, y pairs.
local function chamfered(x1, y1, x2, y2, cut)
	return {
		x1 + cut,
		y1,
		x2 - cut,
		y1,
		x2,
		y1 + cut,
		x2,
		y2 - cut,
		x2 - cut,
		y2,
		x1 + cut,
		y2,
		x1,
		y2 - cut,
		x1,
		y1 + cut,
	}
end

-- A band `w` wide along the inside of a cut-corner rect's edge. The diagonal sides stay
-- as thick as the straight ones: moved in by w along its normal, a diagonal edge cuts
-- each axis w * (2 - sqrt 2) less.
local function chamferRing(x1, y1, x2, y2, cut, w)
	local inner = mathMax(0, cut - w * 0.5857864376)
	local o = chamfered(x1, y1, x2, y2, cut)
	local i = chamfered(x1 + w, y1 + w, x2 - w, y2 - w, inner)
	glBeginEnd(GL_QUADS, function()
		for k = 1, 8 do
			local a = k * 2 - 1
			local b = (k % 8) * 2 + 1
			glVertex(o[a], o[a + 1])
			glVertex(o[b], o[b + 1])
			glVertex(i[b], i[b + 1])
			glVertex(i[a], i[a + 1])
		end
	end)
end

-- How much of each corner a marker picture this many pixels wide loses.
function Graph:markerCut(width)
	local cut = self.cfg.markerCorner or mathMax(2, mathFloor(width * 0.08))
	return mathMin(cut, mathFloor(width * 0.5))
end

-- One marker: its tick, its picture with the corners cut, and its frame. `scale` grows
-- the picture about its middle, for the one under the cursor.
function Graph:drawMarker(m, scale)
	local look = self.cfg.look
	local marker = m.marker
	local x1, y1, x2, y2 = m.x1, m.y1, m.x2, m.y2
	if scale and scale ~= 1 then
		local gx = mathFloor((x2 - x1) * (scale - 1) * 0.5)
		local gy = mathFloor((y2 - y1) * (scale - 1) * 0.5)
		x1, y1, x2, y2 = x1 - gx, y1 - gy, x2 + gx, y2 + gy
	end
	local cut = self:markerCut(x2 - x1)
	-- A tick from the picture down to the plot, or to the point it sits on.
	glColor(look.markerTick)
	glBeginEnd(GL_LINES, function()
		glVertex(m.cx + 0.5, y1)
		glVertex(m.px + 0.5, m.onSeries and m.py or self.area.bottom)
	end)
	local corners = chamfered(x1, y1, x2, y2, cut)
	if marker.texture then
		-- Zoomed in a little, the more the smaller the picture: a unit picture has air
		-- around the unit. The engine's textures load flipped, so t runs from 1 down to 0
		-- going up.
		local z = marker.zoom or self.cfg.markerZoom or mathMin(0.06, 2.5 / mathMax(1, x2 - x1))
		local w, h = mathMax(1, x2 - x1), mathMax(1, y2 - y1)
		glColor(1, 1, 1, 1)
		glTexture(marker.texture)
		glBeginEnd(GL_TRIANGLE_FAN, function()
			for k = 1, 16, 2 do
				local x, y = corners[k], corners[k + 1]
				glTexCoord(z + (x - x1) / w * (1 - 2 * z), 1 - z - (y - y1) / h * (1 - 2 * z))
				glVertex(x, y)
			end
		end)
		glTexture(false)
	else
		local c = marker.color or { 1, 1, 1 }
		glColor(c[1], c[2], c[3], 0.9)
		glBeginEnd(GL_TRIANGLE_FAN, function()
			for k = 1, 16, 2 do
				glVertex(corners[k], corners[k + 1])
			end
		end)
	end
	-- The frame, in the marker's own colour when it has one (a team's), following the cut
	-- corners.
	local frame = marker.frame
	if frame then
		glColor(frame[1], frame[2], frame[3], frame[4] or 1)
	else
		glColor(look.markerFrame)
	end
	chamferRing(x1, y1, x2, y2, cut, self.cfg.markerFrameWidth)
	return x1, y1, x2, y2
end

function Graph:drawMarkers()
	for _, m in ipairs(self.placed) do
		self:drawMarker(m, 1)
	end
end

-- The title and the legend, in the room the layout kept above the plot for them.
function Graph:drawLegend()
	local cfg = self.cfg
	local look = cfg.look
	local fs = cfg.fontSize
	local plot = self.plot
	local titleH = cfg.title and fs * 1.9 or 0
	local legendH = (cfg.legend and #self.prepared > 0) and fs * 1.7 or 0
	local top = plot.top + titleH + legendH
	if cfg.title then
		self:text(look.title .. cfg.title, plot.left, mathFloor(top - fs * 1.1), "o", fs * 1.15)
	end
	if not cfg.legend then
		return
	end
	local y = mathFloor(top - titleH - fs * 1.3)
	---@type number
	local x = self.area and self.area.left or plot.left
	local swatch = mathFloor(fs * 0.8)
	for si, p in ipairs(self.prepared) do
		local w = self:textWidth(p.name, fs)
		if x + swatch + fs * 0.5 + w > plot.right then
			break
		end
		local c = p.color
		local a = alphaOf(self, si, 1)
		glColor(c[1], c[2], c[3], a)
		glBeginEnd(GL_QUADS, function()
			glVertex(x, y)
			glVertex(x + swatch, y)
			glVertex(x + swatch, y + swatch)
			glVertex(x, y + swatch)
		end)
		local color = isLit(self, si) and look.text or "\255\130\130\130"
		self:text(color .. p.name, mathFloor(x + swatch + fs * 0.4), mathFloor(y + swatch * 0.15), "o", fs)
		x = mathFloor(x + swatch + fs * 0.4 + w + fs * 1.2)
	end
end

----------------------------------------------------------------
-- Radar
----------------------------------------------------------------

function Graph:prepareRadar()
	local cfg = self.cfg
	local plot = self.plot
	local fs = cfg.fontSize
	local axes = cfg.radar.axes or {}
	self.axes = axes
	local n = #axes
	-- Label room around the wheel; a wheel drawn without labels keeps that room.
	local labelW = 0
	for _, a in ipairs(cfg.radar.labels ~= false and axes or {}) do
		labelW = mathMax(labelW, self:textWidth(a.label or a.key or "", fs))
	end
	local cx = mathFloor((plot.left + plot.right) * 0.5)
	local cy = mathFloor((plot.bottom + plot.top) * 0.5)
	local radius =
		mathMin((plot.right - plot.left) * 0.5 - labelW - fs * 0.6, (plot.top - plot.bottom) * 0.5 - fs * 1.6)
	radius = mathMax(10, radius)
	self.radar = { cx = cx, cy = cy, radius = radius, n = n }

	-- Each series' values per axis, as a share of the axis maximum.
	for _, p in ipairs(self.prepared) do
		local s = p.source
		local vals = {}
		for ai, a in ipairs(axes) do
			local v = s.values and (s.values[ai] or (a.key and s.values[a.key]))
			vals[ai] = isFinite(v) and v or 0
		end
		p.axisValues = vals
	end
	for ai, a in ipairs(axes) do
		if not a.max then
			local top = 0
			for _, p in ipairs(self.prepared) do
				top = mathMax(top, p.axisValues[ai])
			end
			a.autoMax = top > 0 and top or 1
		end
	end
	self.axisMax = function(ai)
		return axes[ai].max or axes[ai].autoMax or 1
	end
	-- Axis ai at angle: the first straight up, the rest clockwise.
	self.axisPoint = function(ai, share)
		local ang = mathPi * 0.5 - (ai - 1) / mathMax(1, n) * 2 * mathPi
		return cx + mathCos(ang) * radius * share, cy + mathSin(ang) * radius * share
	end
end

function Graph:drawRadar()
	local cfg = self.cfg
	local look = cfg.look
	local fs = cfg.fontSize
	local r = self.radar
	local n = r.n
	if n < 3 then
		return
	end
	local axisPoint = self.axisPoint

	-- Rings and spokes.
	if glSmoothing then
		glSmoothing(false, true, false)
	end
	glLineWidth(1)
	glColor(look.grid)
	for k = 1, cfg.radar.rings do
		local share = k / cfg.radar.rings
		glBeginEnd(GL_LINE_LOOP, function()
			for ai = 1, n do
				glVertex(axisPoint(ai, share))
			end
		end)
	end
	glColor(look.axis)
	glBeginEnd(GL_LINES, function()
		for ai = 1, n do
			glVertex(r.cx, r.cy)
			glVertex(axisPoint(ai, 1))
		end
	end)

	-- Series: a filled polygon and its outline.
	for _, p in ipairs(drawOrder(self)) do
		local c = p.color
		local shares = {}
		for ai = 1, n do
			shares[ai] = mathMin(1, mathMax(0, p.axisValues[ai] / self.axisMax(ai)))
		end
		if cfg.radar.fill then
			glColor(c[1], c[2], c[3], alphaOf(self, p.index, look.radarFillAlpha))
			glBeginEnd(GL_TRIANGLE_FAN, function()
				glVertex(r.cx, r.cy)
				for ai = 1, n do
					glVertex(axisPoint(ai, shares[ai]))
				end
				glVertex(axisPoint(1, shares[1]))
			end)
		end
		glLineWidth(isLifted(self, p.index) and p.width + 1 or p.width)
		glColor(c[1], c[2], c[3], alphaOf(self, p.index, 1))
		glBeginEnd(GL_LINE_LOOP, function()
			for ai = 1, n do
				glVertex(axisPoint(ai, shares[ai]))
			end
		end)
	end
	glLineWidth(1)
	if glSmoothing then
		glSmoothing(false, false, false)
	end

	-- Labels, past the end of each spoke.
	for ai, a in ipairs(cfg.radar.labels ~= false and self.axes or {}) do
		local x, y = axisPoint(ai, 1)
		local dx, dy = x - r.cx, y - r.cy
		local opts = "o"
		if dx > 1 then
			opts = "o"
			x = x + fs * 0.4
		elseif dx < -1 then
			opts = "or"
			x = x - fs * 0.4
		else
			opts = "oc"
		end
		if dy > 1 then
			y = y + fs * 0.4
		elseif dy < -1 then
			y = y - fs * 1.1
		else
			y = y - fs * 0.35
		end
		self:text(look.text .. (a.label or a.key or ""), mathFloor(x), mathFloor(y), opts, fs)
	end
	local titleH = cfg.title and fs * 1.9 or 0
	if cfg.title then
		self:text(look.title .. cfg.title, self.plot.left, mathFloor(self.plot.top + titleH - fs * 1.1), "o", fs * 1.15)
	end
	-- The legend: one row under the title, in the wheel's label room.
	if cfg.legend then
		---@type number
		local x = self.plot.left
		local y = mathFloor(self.plot.top - fs * 1.2)
		local swatch = mathFloor(fs * 0.8)
		for si, p in ipairs(self.prepared) do
			local w = self:textWidth(p.name, fs)
			if x + swatch + fs * 0.5 + w > self.plot.right then
				break
			end
			local c = p.color
			glColor(c[1], c[2], c[3], alphaOf(self, si, 1))
			glBeginEnd(GL_QUADS, function()
				glVertex(x, y)
				glVertex(x + swatch, y)
				glVertex(x + swatch, y + swatch)
				glVertex(x, y + swatch)
			end)
			self:text(look.text .. p.name, mathFloor(x + swatch + fs * 0.4), mathFloor(y + swatch * 0.15), "o", fs)
			x = mathFloor(x + swatch + fs * 0.4 + w + fs * 1.2)
		end
	end
end

----------------------------------------------------------------
-- Building and drawing
----------------------------------------------------------------

-- Everything the picture and the hit test share: the samples, the frame's layout and
-- the scales, the markers' places. No drawing in here, so a hit test can run it on
-- fresh series before they are drawn.
function Graph:measure()
	local cfg = self.cfg
	self:prepareSamples()
	self:layout()
	if cfg.kind == "radar" then
		self.placed = {}
		self:prepareRadar()
	else
		self:prepareLine()
		self:placeMarkers()
	end
end

function Graph:build()
	local cfg = self.cfg
	self.pendingCount = 0
	self:measure()
	if cfg.look.background then
		glColor(cfg.look.background)
		glBeginEnd(GL_QUADS, function()
			glVertex(cfg.x, cfg.y)
			glVertex(cfg.x + cfg.width, cfg.y)
			glVertex(cfg.x + cfg.width, cfg.y + cfg.height)
			glVertex(cfg.x, cfg.y + cfg.height)
		end)
	end
	if cfg.kind == "radar" then
		self:drawRadar()
	else
		self:drawGrid()
		if cfg.kind == "stacked" then
			self:drawStacked()
		else
			self:drawLines()
		end
		self:drawMarkers()
		self:drawLegend()
	end
	self:flushText()
	glColor(1, 1, 1, 1)
end

function Graph:draw()
	if self.dirty or not self.list then
		if self.list then
			glDeleteList(self.list)
		end
		self.list = glCreateList(function()
			self:build()
		end)
		self.dirty = false
	end
	glCallList(self.list)
	self:drawOverlay()
end

-- What moves with the cursor: a line down the hovered sample with a dot on every series,
-- or a frame around the hovered marker. Drawn straight, not baked.
function Graph:drawOverlay()
	local hit = self.hover
	if not hit then
		return
	end
	local look = self.cfg.look
	if hit.kind == "marker" then
		local m = hit.placed
		-- Drawn again over the baked ones, larger: pictures that overlap in a crowded lane
		-- are read by hovering them.
		self:drawMarker(m, self.cfg.markerHoverScale)
		glColor(1, 1, 1, 1)
		return
	end
	if hit.kind == "point" and self.area then
		local area = self.area
		glColor(look.crosshair)
		glBeginEnd(GL_LINES, function()
			glVertex(mathFloor(hit.px) + 0.5, area.bottom)
			glVertex(mathFloor(hit.px) + 0.5, area.top)
		end)
		local r = mathMax(2, self.cfg.lineWidth * 1.5)
		for _, e in ipairs(hit.entries) do
			local c = e.color
			glColor(c[1], c[2], c[3], 1)
			glBeginEnd(GL_TRIANGLE_FAN, function()
				glVertex(hit.px, e.py)
				for k = 0, 12 do
					local ang = k / 12 * 2 * mathPi
					glVertex(hit.px + mathCos(ang) * r, e.py + mathSin(ang) * r)
				end
			end)
		end
		glColor(1, 1, 1, 1)
		return
	end
	if hit.kind == "axis" and self.radar then
		glColor(look.crosshair)
		glLineWidth(2)
		glBeginEnd(GL_LINES, function()
			glVertex(self.radar.cx, self.radar.cy)
			glVertex(self.axisPoint(hit.axis, 1))
		end)
		glLineWidth(1)
		glColor(1, 1, 1, 1)
	end
end

----------------------------------------------------------------
-- Hit testing and describing
----------------------------------------------------------------

-- What is under the cursor: a marker, the nearest sample column of a line or stacked
-- chart, or the nearest axis of a radar chart. nil outside the chart or before the first
-- draw.
function Graph:hitTest(mx, my)
	local cfg = self.cfg
	if mx < cfg.x or mx > cfg.x + cfg.width or my < cfg.y or my > cfg.y + cfg.height then
		return nil
	end
	-- Fresh series are laid out for the test when they have not been drawn yet.
	if self.dirty or not self.list then
		self:measure()
	end
	-- Later markers lie on top of earlier ones, so they are tested first.
	for i = #self.placed, 1, -1 do
		local m = self.placed[i]
		---@cast m -?
		if mx >= m.x1 and mx <= m.x2 and my >= m.y1 and my <= m.y2 then
			return { kind = "marker", marker = m.marker, placed = m, px = m.px, py = m.py, text = m.marker.text }
		end
	end
	if cfg.kind == "radar" then
		local r = self.radar
		if not r or r.n < 3 then
			return nil
		end
		local dx, dy = mx - r.cx, my - r.cy
		if dx * dx + dy * dy > (r.radius * 1.15) ^ 2 then
			return nil
		end
		local ang = math.atan2(dy, dx)
		-- Axis 1 points up and the rest run clockwise.
		local turn = (mathPi * 0.5 - ang) / (2 * mathPi)
		turn = turn - mathFloor(turn)
		local axis = mathFloor(turn * r.n + 0.5) % r.n + 1
		local entries = {}
		for si, p in ipairs(self.prepared) do
			entries[#entries + 1] = { series = si, name = p.name, color = p.color, value = p.axisValues[axis] }
		end
		local a = self.axes[axis]
		---@cast a -?
		return { kind = "axis", axis = axis, label = a.label or a.key, entries = entries }
	end
	local area = self.area
	if not area or #self.xs == 0 then
		return nil
	end
	if mx < area.left or mx > area.right then
		return nil
	end
	local x = self.xMin + (mx - area.left) / mathMax(1, area.right - area.left) * (self.xMax - self.xMin)
	local i = self:nearestIndex(x)
	local px = self.sx(self.xs[i] or 0)
	local entries = {}
	for si, p in ipairs(self.prepared) do
		local v = p.ys[i]
		if cfg.kind == "stacked" then
			local share = p.shares and p.shares[i] or 0
			entries[#entries + 1] = {
				series = si,
				name = p.name,
				color = p.color,
				value = v or 0,
				share = share,
				py = self.sy(self:stackTop(si, i) - share * 0.5),
			}
		elseif v then
			entries[#entries + 1] = {
				series = si,
				name = p.name,
				color = p.color,
				value = v,
				raw = p.raw and p.raw[i] or nil,
				py = self.sy(v),
			}
		end
	end
	return { kind = "point", index = i, x = self.xs[i], px = px, entries = entries }
end

-- A tooltip for a hit: the x, then every series' value in its colour, largest first.
function Graph:describe(hit)
	if not hit then
		return nil
	end
	if hit.kind == "marker" then
		return hit.text
	end
	local cfg = self.cfg
	local lines = {}
	local entries = {}
	for i = 1, #hit.entries do
		entries[i] = hit.entries[i]
	end
	table.sort(entries, function(a, b)
		return (a.value or 0) > (b.value or 0)
	end)
	if hit.kind == "point" then
		lines[1] = cfg.look.title .. (self.xFormatter or defaultFormat)(hit.x)
		local yFormat = cfg.kind == "stacked" and (cfg.yFormat or defaultFormat) or self.yFormatter
		for _, e in ipairs(entries) do
			local value = yFormat(e.raw or e.value)
			if e.share then
				value = value .. cfg.look.text .. stringFormat("  (%d%%)", mathFloor(e.share + 0.5))
			end
			lines[#lines + 1] = colorCode(e.color) .. e.name .. "  " .. cfg.look.title .. value
		end
	else
		lines[1] = cfg.look.title .. (hit.label or "")
		local yFormat = cfg.yFormat or defaultFormat
		for _, e in ipairs(entries) do
			lines[#lines + 1] = colorCode(e.color) .. e.name .. "  " .. cfg.look.title .. yFormat(e.value)
		end
	end
	return table.concat(lines, "\n")
end

return Graph
