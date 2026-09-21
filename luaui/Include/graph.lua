-- Charts for widgets: line graphs, 100% stacked areas, radar charts and bars. The picture is
-- baked into a display list and only the hover overlay is drawn each frame, so a chart
-- costs a list call while nothing changes.
--
--   local Graph = VFS.Include("luaui/Include/graph.lua")
--   local chart = Graph.new({
--       kind = "line",                         -- "line" | "stacked" | "radar" | "bars"
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
--           { x = 5400, shape = "up", color = { 1, 0.5, 0.3 }, text = "Peak", series = 2 },
--           { x = 6000, texture = "#12", text = "...", badge = { sign = "minus", color = { 0.9, 0.3, 0.25 } } },
--       },
--       markerLegend = { { badge = { sign = "minus", color = ... }, name = "Lost" } },  -- in the title row
--       spans = {                               -- stretches of x in strips outside an edge
--           { from = 900, to = 2700, row = 1, edge = "bottom", color = { 1, 0.5, 0.3 }, text = "..." },
--       },
--   })
--   chart:draw()                              -- in DrawScreen
--   local hit = chart:hitTest(mx, my)          -- nil, or what is under the cursor
--   chart:setHover(hit)                        -- what the overlay marks
--   WG.tooltip.ShowTooltip("mychart", chart:describe(hit))
--
-- Everything in the constructor can be changed later through chart:configure({ ... }),
-- chart:setSeries(list), chart:setMarkers(list), chart:setSpans(list), chart:setBounds(x, y, w, h) and
-- chart:setHighlight(seriesIndex, or { [seriesIndex] = true, ... } for several); each
-- marks the picture for a rebuild on the next draw.
-- chart:destroy() frees the list. Radar charts take `radar = { axes = { { key = "speed",
-- label = "Speed", max = 100 }, ... }, rings = 4 }` and series with `values` keyed by axis
-- (an array in axis order, or a table by axis key). A stacked chart turns every sample
-- into shares of that sample's total, so the y axis is 0 to 100% - or, with
-- `stackShares = false`, piles the amounts themselves up. A series with `step = true` holds
-- its value until the next sample rather than running a line to it: a count. A picture's
-- `badge` - a round plate in its bottom right corner with a sign ("plus", "minus", "cross",
-- "up") - says what kind of event it is, and `markerLegend` names the badges once, at the
-- right of the title row (less `titleInset` pixels kept free there). Bars take a
-- row a series - { name, value, sub, color, texture, valueText, text } - and draw its
-- picture and name, a bar as long as its value with a thin one as long as `sub` under it,
-- and the value; `text` is its tooltip. The rows that do not fit are counted under the last
-- by `bars.more(n)`, or with `bars.scroll` scrolled through by chart:scrollBars(delta), and
-- `bars.legend` ({ { name, color }, ... }) says what the two bars are.

---@class Graph
---@field cfg table<string, any>
---@field series table[]
---@field markers table[]
---@field spans table[]
---@field spanRects table[]
---@field spanBelow number
---@field spanAbove number
---@field stripH number
---@field totals number[]
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
---@field endLabelW number
---@field measures integer
---@field memoGen integer
---@field memoHit table?
---@field legendRows integer
---@field xFormatter fun(v: number): string
---@field yFormatter fun(v: number): string
---@field radar table<string, number>
---@field axes table[]
---@field axisMax fun(ai: integer): number
---@field axisPoint fun(ai: integer, share: number): number, number
---@field barRows table[]
---@field barMore integer
---@field barLayout table<string, number>
---@field barOffset number?
---@field barScrolls boolean?
---@field barKey any
---@field slopes number[]?
---@field secants number[]?
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
	-- Stacked: every sample as the shares of its total, or the amounts piled up. The name
	-- the total goes by in the tooltip of the amounts; none leaves it out.
	stackShares = true,
	totalLabel = nil,
	-- A point's third value is what it really is (a bounded value unbounded) - or, with this
	-- set, something beside what is plotted, which the tooltip gives after it in this format:
	-- a place in a ranking, and the score behind it.
	rawFormat = nil,
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
	-- Where the x axis starts, when not at the first sample: 0 for a game clock that runs
	-- from the start whatever the first sample is.
	xMin = nil,
	-- A line chart's series named at their right ends, in their colours, kept apart; the
	-- plot gives up the room they take, and they are left out when they would not fit.
	endLabels = false,
	-- Curves through the samples rather than corners at them. Steps between two samples
	-- come from the pixel distance when left nil.
	smooth = false,
	smoothSteps = nil,
	-- A point hit takes the tables of the one before it, for a caller that uses a hit only
	-- until its next hitTest: a hover sweeping over a chart made a table a series a frame.
	reuseHits = false,
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
	-- A marker drawn as a shape rather than a picture - a point of a line - is this share of
	-- the font size across.
	markerShapeSize = 1.0,
	-- How much larger the hovered picture is drawn.
	markerHoverScale = 1.2,
	-- The badges named in the title row, and room kept free at its right end for whatever the
	-- chart's owner draws there.
	markerLegend = nil,
	titleInset = 0,
	radar = {
		rings = 4,
		axes = nil,
		fill = true,
		-- The axes are named around the wheel; off for a chart too small to read them.
		labels = true,
	},
	bars = {
		-- A row is at least and at most this many font sizes tall; the room decides between.
		minRow = 1.5,
		maxRow = 2.4,
		-- The names never take more than this share of the width.
		nameShare = 0.32,
		-- How many rows did not fit, in words: fn(n). nil says nothing of them.
		more = nil,
		-- Or scrolled through instead (scrollBars), where the owner hands the chart the wheel;
		-- `key` names the rows, and other ones start from the top.
		scroll = false,
		key = nil,
		legend = nil,
		subColor = { 1, 1, 1, 0.32 },
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

-- One channel of a colour code: never nothing, which ends a string for the engine, nor a
-- line break, which cuts a line of text in two wherever it is split into lines.
local function codeByte(v)
	local byte = mathMax(1, mathMin(255, mathFloor(v * 255)))
	if byte == 10 or byte == 13 then
		byte = byte + 1
	end
	return byte
end

local function colorCode(c)
	return stringChar(255, codeByte(c[1]), codeByte(c[2]), codeByte(c[3]))
end

-- Monotone cubic interpolation (Fritsch-Carlson): a curve through the samples that never
-- overshoots them, so a value that never went above 10 is never drawn above 10.
-- The slopes of samples first..last of xs/ys, three or more, into `m` at the same indices;
-- `d` takes the secants between them. Both are the caller's to keep and use again: what they
-- hold outside the range is never read.
local function slopesInto(m, d, xs, ys, first, last)
	for i = first, last - 1 do
		local dx = xs[i + 1] - xs[i]
		d[i] = dx > 0 and (ys[i + 1] - ys[i]) / dx or 0
	end
	m[first] = d[first]
	m[last] = d[last - 1]
	for i = first + 1, last - 1 do
		if d[i - 1] * d[i] <= 0 then
			m[i] = 0
		else
			m[i] = (d[i - 1] + d[i]) * 0.5
		end
	end
	for i = first, last - 1 do
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
-- Vertex emitters
----------------------------------------------------------------

-- What gl.BeginEnd calls, handed what it draws as arguments: named once, rather than a
-- closure made for every primitive of every bake (and every hover frame).
local function emitStrip(run, sx, sy)
	for k = 1, #run - 1, 2 do
		glVertex(sx(run[k]), sy(run[k + 1]))
	end
end

local function emitFill(run, sx, sy, bottom)
	for k = 1, #run - 1, 2 do
		local px = sx(run[k])
		glVertex(px, bottom)
		glVertex(px, sy(run[k + 1]))
	end
end

local function emitSquare(px, py, w)
	glVertex(px - w, py - w)
	glVertex(px + w, py - w)
	glVertex(px + w, py + w)
	glVertex(px - w, py + w)
end

local function emitLine(x1, y1, x2, y2)
	glVertex(x1, y1)
	glVertex(x2, y2)
end

local function emitBand(pxs, count, own, under, cap, sy)
	for k = 1, count do
		local px = pxs[k]
		glVertex(px, sy(under and under[k] or 0))
		glVertex(px, sy(mathMin(cap, own[k] or 0)))
	end
end

local function emitSeam(pxs, count, own, sy)
	for k = 1, count do
		glVertex(pxs[k], sy(own[k] or 0))
	end
end

local function emitFan(corners)
	for k = 1, #corners - 1, 2 do
		glVertex(corners[k], corners[k + 1])
	end
end

-- A picture's cut-corner outline with its texture laid over it, zoomed in by z.
local function emitPictureFan(corners, x1, y1, w, h, z)
	for k = 1, #corners - 1, 2 do
		local x, y = corners[k], corners[k + 1]
		glTexCoord(z + (x - x1) / w * (1 - 2 * z), 1 - z - (y - y1) / h * (1 - 2 * z))
		glVertex(x, y)
	end
end

-- The unit circle, worked out once: 16 points round (a round mark or badge) and 12 steps
-- round with both ends (the fan of a dot under the cursor).
local CIRCLE16, CIRCLE12 = {}, {}
for k = 0, 15 do
	local ang = k / 16 * 2 * mathPi
	CIRCLE16[#CIRCLE16 + 1] = mathCos(ang)
	CIRCLE16[#CIRCLE16 + 1] = mathSin(ang)
end
for k = 0, 12 do
	local ang = k / 12 * 2 * mathPi
	CIRCLE12[#CIRCLE12 + 1] = mathCos(ang)
	CIRCLE12[#CIRCLE12 + 1] = mathSin(ang)
end

local function emitEllipse(cx, cy, rx, ry)
	for k = 1, #CIRCLE16 - 1, 2 do
		glVertex(cx + CIRCLE16[k] * rx, cy + CIRCLE16[k + 1] * ry)
	end
end

local function emitDot(cx, cy, r)
	glVertex(cx, cy)
	for k = 1, #CIRCLE12 - 1, 2 do
		glVertex(cx + CIRCLE12[k] * r, cy + CIRCLE12[k + 1] * r)
	end
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
	self.spans = self.cfg.spans or {}
	self.cfg.series = nil
	self.cfg.markers = nil
	self.cfg.spans = nil
	self.spanRects = {}
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
	if cfg.spans then
		self.spans = cfg.spans
		self.cfg.spans = nil
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

function Graph:setSpans(spans)
	self.spans = spans or {}
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

-- `asName` marks what a series is called - a player, a team - which the caller can ask to
-- be set in a face of its own (`cfg.nameFont`), the way the rest of the interface writes
-- names. Everything else is the interface's own face.
function Graph:text(str, x, y, opts, size, asName)
	local n = self.pendingCount + 1
	self.pendingCount = n
	self.pending[n] = { str, x, y, size or self.cfg.fontSize, opts or "o", asName or false }
end

-- One batch a face, with the outline pinned: the fonts are shared with every widget, so a
-- bake would otherwise freeze in whatever outline the last one set.
function Graph:printBatch(face, asName, all)
	local began = false
	for i = 1, self.pendingCount do
		local p = self.pending[i]
		---@cast p -?
		if all or p[6] == asName then
			if not began then
				began = true
				face:Begin()
				face:SetOutlineColor(self.cfg.look.outline)
			end
			face:Print(p[1], p[2], p[3], p[4], p[5])
		end
	end
	if began then
		face:End()
	end
end

function Graph:flushText()
	local font = self.cfg.font
	if not font or self.pendingCount == 0 then
		self.pendingCount = 0
		return
	end
	local nameFont = self.cfg.nameFont or font
	if nameFont == font then
		self:printBatch(font, false, true)
	else
		self:printBatch(font, false)
		self:printBatch(nameFont, true)
	end
	for i = 1, self.pendingCount do
		self.pending[i] = nil
	end
	self.pendingCount = 0
end

function Graph:textWidth(str, size, asName)
	local font = (asName and self.cfg.nameFont) or self.cfg.font
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
	-- Series that all have their points at the same x values, rising - the usual case,
	-- every team sampled at once - are read straight into place: no map of x a series.
	---@type table[]?
	local direct = nil
	if not shared and n == 0 then
		for _, s in ipairs(self.series) do
			local points = s.points
			if not points then
				direct = nil
				break
			end
			if not direct then
				direct = points
				for i = 2, #points do
					if points[i][1] <= points[i - 1][1] then
						direct = nil
						break
					end
				end
				if not direct then
					break
				end
			elseif #points ~= #direct then
				direct = nil
				break
			else
				for i = 1, #points do
					local d = direct[i]
					---@cast d -?
					if points[i][1] ~= d[1] then
						direct = nil
						break
					end
				end
				if not direct then
					break
				end
			end
		end
	end
	if direct then
		for i = 1, #direct do
			local d = direct[i]
			---@cast d -?
			xs[i] = d[1]
		end
	else
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
	end

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
		if direct then
			local points = s.points
			for i = 1, #points do
				local p = points[i]
				if isFinite(p[2]) then
					ys[i] = p[2]
					-- A third value is what the point really is, when the plotted one was
					-- bounded: the tooltip says that one.
					if p[3] ~= nil then
						raw = raw or {}
						raw[i] = p[3]
					end
				end
			end
		elseif not s.values then
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
			step = s.step,
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
	if cfg.legend and #self:legendEntries(self.series) > 0 and cfg.kind ~= "radar" then
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
	-- Piled up as amounts rather than shares: the totals make the range.
	local amounts = stacked and cfg.stackShares == false

	-- Stacked: every sample's values become shares of the sample's total.
	self.totals = {}
	if stacked then
		for i = 1, #xs do
			local total = 0
			for _, p in ipairs(self.prepared) do
				total = total + (p.ys[i] or 0)
			end
			self.totals[i] = total
			for _, p in ipairs(self.prepared) do
				p.shares = p.shares or {}
				p.shares[i] = total > 0 and (p.ys[i] or 0) / total * 100 or 0
			end
		end
	end

	local yMin, yMax = mathHuge, -mathHuge
	if stacked and not amounts then
		yMin, yMax = 0, 100
	else
		if amounts then
			yMin, yMax = 0, 0
			for i = 1, #xs do
				yMax = mathMax(yMax, self.totals[i] or 0)
			end
		end
		for _, p in ipairs(amounts and {} or self.prepared) do
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
		or (stacked and not amounts and function(v)
			return stringFormat("%d%%", mathFloor(v + 0.5))
		end)
		or defaultFormat
	self.yFormatter = yFormat
	local step = (stacked and not amounts) and 25 or niceStep(yMax - yMin, cfg.gridLines)
	self.yStep = step
	local labelW = 0
	local v = yMin
	while v <= yMax + step * 0.001 do
		labelW = mathMax(labelW, self:textWidth(yFormat(v), fs))
		v = v + step
	end
	local left = mathFloor(plot.left + labelW + fs * 0.6)
	-- Rows of strips for the spans, outside the values: under the plot, over the x axis
	-- labels, and over it, under the marker lane.
	local stripH = mathMax(2, mathFloor(fs * 0.35))
	local rowsBelow, rowsAbove = 0, 0
	for _, s in ipairs(self.spans) do
		if s.edge == "top" then
			rowsAbove = mathMax(rowsAbove, s.row or 1)
		else
			rowsBelow = mathMax(rowsBelow, s.row or 1)
		end
	end
	self.stripH = stripH
	self.spanBelow = rowsBelow > 0 and rowsBelow * (stripH + 1) + 4 or 0
	self.spanAbove = rowsAbove > 0 and rowsAbove * (stripH + 1) + 4 or 0
	local bottom = mathFloor(plot.bottom + fs * 1.5) + self.spanBelow
	local right = plot.right
	-- A legend too wide for one row wraps onto more, each taken from the plot's height.
	self.legendRows = 1
	if cfg.legend and #self.prepared > 0 then
		local rows, x = 1, left
		for _, p in ipairs(self.prepared) do
			local w = mathFloor(fs * 0.8) + fs * 0.4 + self:textWidth(p.name, fs, true)
			if x + w > plot.right and x > left then
				rows = rows + 1
				x = left
			end
			x = mathFloor(x + w + fs * 1.2)
		end
		if rows > 1 then
			plot.top = mathFloor(plot.top - (rows - 1) * fs * 1.7)
			self.legendRows = rows
		end
	end
	-- The names at the lines' ends take their room from the plot, never more than a third.
	self.endLabelW = 0
	if cfg.endLabels and not stacked and #self.prepared > 0 then
		local w = 0
		for _, p in ipairs(self.prepared) do
			w = mathMax(w, self:textWidth(p.name, fs, true))
		end
		local room = mathFloor(w + fs * 0.8)
		if room < (right - left) / 3 then
			right = right - room
			self.endLabelW = room
		end
	end

	local xMin, xMax = cfg.xMin or xs[1] or 0, xs[#xs] or 1
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
	-- What a picture is when the lane is not crowded: a hovered one is drawn at least as
	-- large, so one shrunk in a crowd can be read.
	self.markerFullSize = size
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
	local top = plot.top - (rows > 0 and (rows * size + mathFloor(fs * 0.4)) or 0) - self.spanAbove
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

-- Where each marker goes: on its series' value at its x, or in its row of the lane. A
-- shape - a point of a line rather than a picture - is small, whatever the pictures are.
function Graph:placeMarkers()
	local cfg = self.cfg
	local pictureSize = self.markerSize or cfg.markerSize or mathFloor(cfg.fontSize * 2.6)
	local shapeSize = mathMax(6, mathFloor(cfg.fontSize * cfg.markerShapeSize))
	local area = self.area
	self.placed = {}
	for mi, m in ipairs(self.markers) do
		local size = m.shape and shapeSize or pictureSize
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
					py = area.top
						+ (self.spanAbove or 0)
						+ mathFloor(cfg.fontSize * 0.4)
						+ size * 0.5
						+ (row - 1) * size
				end
				local half = size * 0.5
				-- The picture stays inside the plot's width, so one at the first sample does
				-- not sit on the axis labels; its tick still points at the true x.
				local cx = mathMin(mathMax(px, area.left + half), area.right - half)
				-- The point it stands for, before it is moved out of the way.
				local ty = py
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
							local reach = (size + other.size) * 0.5
							if mathAbs(other.cx - cx) < reach and mathAbs(other.py - py) < reach * 0.81 then
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
					ty = ty,
					cx = cx,
					size = size,
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

-- The top of a stacked series at sample i: its share and every share under it, or its
-- amount and every amount under it.
function Graph:stackTop(si, i)
	local amounts = self.cfg.stackShares == false
	local top = 0
	for k = 1, si do
		local p = self.prepared[k]
		---@cast p -?
		top = top + (amounts and mathMax(0, p.ys[i] or 0) or (p.shares[i] or 0))
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

-- The points of a curve: the samples, the smoothed run through them or steps from one to
-- the next, each run flat as x1, y1, x2, y2, ... (no table a point). A gap (a sample with no
-- value) ends one run and starts the next.
function Graph:curveRuns(ys, smooth, step)
	local xs = self.xs
	local cfg = self.cfg
	local runs = {}
	local n = #xs
	local i = 1
	-- Each stretch of samples with a value, first..last, read where it is rather than copied.
	while i <= n do
		while i <= n and not ys[i] do
			i = i + 1
		end
		if i > n then
			break
		end
		local first = i
		while i <= n and ys[i] do
			i = i + 1
		end
		local last = i - 1
		local run, r = {}, 0
		if step then
			-- Held until the next sample, where it moves at once.
			for k = first, last do
				if k > first then
					run[r + 1], run[r + 2] = xs[k], ys[k - 1]
					r = r + 2
				end
				run[r + 1], run[r + 2] = xs[k], ys[k]
				r = r + 2
			end
		elseif smooth and last - first > 1 then
			local m, d = self.slopes, self.secants
			if not m then
				m, d = {}, {}
				self.slopes, self.secants = m, d
			end
			slopesInto(m, d, xs, ys, first, last)
			local steps = cfg.smoothSteps
			if not steps then
				local xFirst, xLast = xs[first], xs[last]
				---@cast xFirst -?
				---@cast xLast -?
				local px = (self.sx(xLast) - self.sx(xFirst)) / mathMax(1, last - first)
				steps = mathMax(1, mathMin(10, mathFloor(px / 3)))
			end
			for k = first, last - 1 do
				local x1, x2 = xs[k], xs[k + 1]
				---@cast x1 -?
				---@cast x2 -?
				for s = 0, steps - 1 do
					local x = x1 + (x2 - x1) * s / steps
					run[r + 1], run[r + 2] = x, hermite(xs, ys, m, k, x)
					r = r + 2
				end
			end
			run[r + 1], run[r + 2] = xs[last], ys[last]
		else
			for k = first, last do
				run[r + 1], run[r + 2] = xs[k], ys[k]
				r = r + 2
			end
		end
		runs[#runs + 1] = run
	end
	return runs
end

-- The spans: each a stretch of x in a strip under the plot or over it, its row counted out
-- from that edge - outside the values, so a line along the edge stays clear of them. Worked
-- out with the rest of the layout, so the hit test has them before anything is drawn. A
-- stretch too short to see keeps a sliver.
function Graph:placeSpans()
	self.spanRects = {}
	local area = self.area
	if not area or #self.spans == 0 then
		return
	end
	local h = self.stripH or mathMax(2, mathFloor(self.cfg.fontSize * 0.3))
	for _, s in ipairs(self.spans) do
		if isFinite(s.from) and isFinite(s.to) and s.to >= self.xMin and s.from <= self.xMax then
			local x1 = self.sx(mathMax(s.from, self.xMin))
			local x2 = self.sx(mathMin(s.to, self.xMax))
			if x2 - x1 < 2 then
				local mid = (x1 + x2) * 0.5
				x1, x2 = mid - 1, mid + 1
			end
			local row = (s.row or 1) - 1
			local y1, y2
			if s.edge == "top" then
				y1 = mathFloor(area.top + 3 + row * (h + 1))
				y2 = y1 + h
			else
				y2 = mathFloor(area.bottom - 3 - row * (h + 1))
				y1 = y2 - h
			end
			self.spanRects[#self.spanRects + 1] =
				{ span = s, x1 = mathFloor(x1), y1 = y1, x2 = mathFloor(x2 + 0.5), y2 = y2 }
		end
	end
end

function Graph:drawSpans()
	for _, r in ipairs(self.spanRects) do
		local c = r.span.color or { 1, 1, 1 }
		glColor(c[1], c[2], c[3], c[4] or 0.8)
		glBeginEnd(GL_QUADS, function()
			glVertex(r.x1, r.y1)
			glVertex(r.x2, r.y1)
			glVertex(r.x2, r.y2)
			glVertex(r.x1, r.y2)
		end)
	end
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
		self:text(
			look.text .. xFormat(x),
			mathFloor(self.sx(x)),
			mathFloor(area.bottom - (self.spanBelow or 0) - fs * 1.2),
			"oc",
			fs
		)
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
	-- Each curve worked out once, for its fill, its line and the hover overlay.
	for _, p in ipairs(order) do
		local smooth = p.smooth
		if smooth == nil then
			smooth = smoothAll
		end
		p.runs = self:curveRuns(p.ys, smooth, p.step)
	end
	-- Fills first, so every line lies on top of every fill.
	if cfg.fill then
		for _, p in ipairs(order) do
			local c = p.color
			local a = alphaOf(self, p.index, look.fillAlpha)
			glColor(c[1], c[2], c[3], a)
			for _, run in ipairs(p.runs) do
				glBeginEnd(GL_TRIANGLE_STRIP, emitFill, run, sx, sy, area.bottom)
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
		self:strokeRuns(p.runs, width)
	end
	glLineWidth(1)
	if glSmoothing then
		glSmoothing(false, false, false)
	end
end

-- Each line's name at its last point, just right of the plot, in its colour - faded with
-- the line when another is lifted. Sorted by height and pushed apart so none touch, then
-- back inside the plot from the top; left out altogether when they cannot all fit.
function Graph:drawEndLabels()
	if (self.endLabelW or 0) <= 0 then
		return
	end
	local area = self.area
	local fs = self.cfg.fontSize
	local items = {}
	for si, p in ipairs(self.prepared) do
		for i = #self.xs, 1, -1 do
			local v = p.ys[i]
			if v then
				items[#items + 1] = { p = p, si = si, y = self.sy(v) }
				break
			end
		end
	end
	local gap = fs * 1.1
	if #items == 0 or #items * gap > area.top - area.bottom + gap then
		return
	end
	table.sort(items, function(a, b)
		return a.y < b.y
	end)
	local low = area.bottom + fs * 0.5
	for _, it in ipairs(items) do
		it.y = mathMax(it.y, low)
		low = it.y + gap
	end
	local high = area.top - fs * 0.5
	for i = #items, 1, -1 do
		local it = items[i]
		it.y = mathMin(it.y, high)
		high = it.y - gap
	end
	local x = mathFloor(area.right + fs * 0.4)
	for _, it in ipairs(items) do
		local c = it.p.color
		local k = alphaOf(self, it.si, 1)
		local faded = { c[1] * k + 0.1 * (1 - k), c[2] * k + 0.1 * (1 - k), c[3] * k + 0.1 * (1 - k) }
		self:text(colorCode(faded) .. it.p.name, x, mathFloor(it.y), "ov", fs, true)
	end
end

-- A line's runs as the current colour and width set them: a lone sample as a dot.
function Graph:strokeRuns(runs, width)
	local sx, sy = self.sx, self.sy
	for _, run in ipairs(runs) do
		if #run == 2 then
			glBeginEnd(GL_QUADS, emitSquare, sx(run[1]), sy(run[2]), width)
		else
			glBeginEnd(GL_LINE_STRIP, emitStrip, run, sx, sy)
		end
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

	-- Every band's share - or amount - along the (smoothed) x run.
	local amounts = cfg.stackShares == false
	local cap = amounts and self.yMax or 100
	local runs = {}
	for si, p in ipairs(self.prepared) do
		local smooth = p.smooth
		if smooth == nil then
			smooth = cfg.smooth
		end
		local filled = {}
		for i = 1, #xs do
			filled[i] = amounts and mathMax(0, p.ys[i] or 0) or (p.shares[i] or 0)
		end
		runs[si] = self:curveRuns(filled, smooth)[1] or {}
	end
	local count = mathFloor(#runs[1] / 2)
	for si = 2, n do
		count = mathMin(count, mathFloor(#runs[si] / 2))
	end
	-- Where every band ends at every point of the run, as a share of the whole there (or
	-- the amounts piled up to it): the bands, the seams and the names all read these,
	-- worked out once.
	---@type number[]
	local pxs = {}
	---@type number[][]
	local tops = {}
	for si = 1, n do
		tops[si] = {}
	end
	for k = 1, count do
		pxs[k] = sx(runs[1][2 * k - 1])
		---@type number
		local total = 0
		for j = 1, n do
			total = total + mathMax(0, runs[j][2 * k])
		end
		---@type number
		local top = 0
		for j = 1, n do
			if amounts then
				top = top + mathMax(0, runs[j][2 * k])
			elseif total > 0 then
				top = top + mathMax(0, runs[j][2 * k]) / total * 100
			end
			local band = tops[j]
			---@cast band -?
			band[k] = top
		end
	end

	for si = 1, n do
		local p = self.prepared[si]
		---@cast p -?
		local c = p.color
		local a = alphaOf(self, si, look.areaAlpha)
		local own, under = tops[si], tops[si - 1]
		---@cast own -?
		glColor(c[1], c[2], c[3], a)
		glBeginEnd(GL_TRIANGLE_STRIP, emitBand, pxs, count, own, under, cap, sy)
	end

	-- The seams between the bands, so neighbours in similar colours stay apart.
	if glSmoothing then
		glSmoothing(false, true, false)
	end
	glLineWidth(1)
	glColor(0, 0, 0, 0.25)
	for si = 1, n - 1 do
		glBeginEnd(GL_LINE_STRIP, emitSeam, pxs, count, tops[si], sy)
	end
	if glSmoothing then
		glSmoothing(false, false, false)
	end

	-- The bands named inside them at their right end, where they are thick enough for
	-- the name and the name is not most of the plot.
	if cfg.bandLabels and count > 0 then
		local fs = cfg.fontSize
		local k = count
		local lastX = pxs[k]
		---@cast lastX -?
		local right = mathFloor(lastX - fs * 0.4)
		local left = self.area and self.area.left or right
		---@type number
		local under = 0
		for si = 1, n do
			local band = tops[si]
			---@cast band -?
			local share = (band[k] or 0) - under
			local y0, y1 = sy(under), sy(mathMin(cap, under + share))
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

-- The band between two cut-corner outlines, a quad an edge.
local function emitRing(o, i)
	for k = 1, 8 do
		local a = k * 2 - 1
		local b = (k % 8) * 2 + 1
		glVertex(o[a], o[a + 1])
		glVertex(o[b], o[b + 1])
		glVertex(i[b], i[b + 1])
		glVertex(i[a], i[a + 1])
	end
end

-- A band `w` wide along the inside of a cut-corner rect's edge. The diagonal sides stay
-- as thick as the straight ones: moved in by w along its normal, a diagonal edge cuts
-- each axis w * (2 - sqrt 2) less.
local function chamferRing(x1, y1, x2, y2, cut, w)
	local inner = mathMax(0, cut - w * 0.5857864376)
	glBeginEnd(GL_QUADS, emitRing, chamfered(x1, y1, x2, y2, cut), chamfered(x1 + w, y1 + w, x2 - w, y2 - w, inner))
end

-- How much of each corner a marker picture this many pixels wide loses.
function Graph:markerCut(width)
	local cut = self.cfg.markerCorner or mathMax(2, mathFloor(width * 0.08))
	return mathMin(cut, mathFloor(width * 0.5))
end

-- The outline of a shape marker in a rect, as x, y pairs round it: a triangle pointing up
-- or down, a diamond, or a round dot.
local function shapeCorners(shape, x1, y1, x2, y2)
	local cx, cy = (x1 + x2) * 0.5, (y1 + y2) * 0.5
	if shape == "up" then
		return { cx, y2, x1, y1, x2, y1 }
	elseif shape == "down" then
		return { cx, y1, x2, y2, x1, y2 }
	elseif shape == "diamond" then
		return { cx, y2, x1, cy, cx, y1, x2, cy }
	end
	local corners = {}
	local rx, ry = (x2 - x1) * 0.5, (y2 - y1) * 0.5
	for k = 0, 15 do
		local ang = k / 16 * 2 * mathPi
		corners[#corners + 1] = cx + mathCos(ang) * rx
		corners[#corners + 1] = cy + mathSin(ang) * ry
	end
	return corners
end

local function fillCorners(corners)
	glBeginEnd(GL_TRIANGLE_FAN, emitFan, corners)
end

-- A shape filled in a rect: the round one straight off the unit circle, no outline made.
local function fillShape(shape, x1, y1, x2, y2)
	if shape == "up" or shape == "down" or shape == "diamond" then
		fillCorners(shapeCorners(shape, x1, y1, x2, y2))
	else
		glBeginEnd(GL_TRIANGLE_FAN, emitEllipse, (x1 + x2) * 0.5, (y1 + y2) * 0.5, (x2 - x1) * 0.5, (y2 - y1) * 0.5)
	end
end

-- A badge's plate and sign, centred on cx, cy with radius r: a dark rim, the plate in its
-- colour, the sign in white - a plus, a minus, a cross or an arrowhead up.
local function drawBadgeAt(badge, cx, cy, r)
	glColor(0, 0, 0, 0.8)
	fillShape("dot", cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1)
	local c = badge.color or { 1, 1, 1 }
	glColor(c[1], c[2], c[3], 1)
	fillShape("dot", cx - r, cy - r, cx + r, cy + r)
	glColor(1, 1, 1, 1)
	local s = r * 0.55
	local t = mathMax(0.75, r * 0.17)
	local sign = badge.sign
	if sign == "plus" or sign == "minus" then
		glBeginEnd(GL_QUADS, function()
			glVertex(cx - s, cy - t)
			glVertex(cx + s, cy - t)
			glVertex(cx + s, cy + t)
			glVertex(cx - s, cy + t)
			if sign == "plus" then
				glVertex(cx - t, cy - s)
				glVertex(cx + t, cy - s)
				glVertex(cx + t, cy + s)
				glVertex(cx - t, cy + s)
			end
		end)
	elseif sign == "cross" then
		-- Two bars on the diagonals, as thick as the others.
		local d, e = s * 0.7071, t * 0.7071
		glBeginEnd(GL_QUADS, function()
			glVertex(cx - d + e, cy - d - e)
			glVertex(cx + d + e, cy + d - e)
			glVertex(cx + d - e, cy + d + e)
			glVertex(cx - d - e, cy - d + e)
			glVertex(cx + d + e, cy - d + e)
			glVertex(cx - d + e, cy + d + e)
			glVertex(cx - d - e, cy + d - e)
			glVertex(cx + d - e, cy - d - e)
		end)
	elseif sign == "up" then
		fillShape("up", cx - s, cy - s * 0.8, cx + s, cy + s * 0.9)
	end
end

-- For a legend drawn outside a chart: a badge, or a mark's shape over its dark rim, centred
-- on cx, cy with radius r. Drawn at once, not baked.
function Graph.drawBadgeAt(badge, cx, cy, r)
	drawBadgeAt(badge, cx, cy, r)
	glColor(1, 1, 1, 1)
end

function Graph.drawShapeAt(shape, cx, cy, r, color)
	glColor(0, 0, 0, 0.75)
	fillShape(shape, cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1)
	glColor(color[1], color[2], color[3], color[4] or 1)
	fillShape(shape, cx - r, cy - r, cx + r, cy + r)
	glColor(1, 1, 1, 1)
end

-- A picture's badge, over its bottom right corner.
function Graph:drawBadge(badge, x1, y1, x2, y2)
	local w = x2 - x1
	if w < 16 then
		return
	end
	local r = mathMax(3.5, w * 0.21)
	drawBadgeAt(badge, x2 - r * 0.55, y1 + r * 0.55, r)
end

-- The badges on the chart, named at the right end of the title row, before `titleInset`: a
-- plate and a word each, for the badges on a picture drawn. Left out when they would reach
-- the title.
function Graph:drawMarkerLegend(titleEnd, baseline)
	local cfg = self.cfg
	if not cfg.markerLegend then
		return
	end
	-- A badge is known by its sign and colour: the configuration is copied, not referenced.
	local function known(badge)
		local c = badge.color or {}
		return stringFormat("%s:%s:%s:%s", tostring(badge.sign), tostring(c[1]), tostring(c[2]), tostring(c[3]))
	end
	local drawn = {}
	for _, p in ipairs(self.placed) do
		local badge = p.marker.badge
		if badge and p.x2 - p.x1 >= 16 then
			drawn[known(badge)] = true
		end
	end
	local entries = {}
	for _, e in ipairs(cfg.markerLegend) do
		if e.badge and drawn[known(e.badge)] then
			entries[#entries + 1] = e
		end
	end
	if #entries == 0 then
		return
	end
	local fs = cfg.fontSize
	local size = fs * 0.9
	local r = mathMax(3.5, fs * 0.42)
	local gap = mathFloor(fs * 1.1)
	local widths, total = {}, 0
	for i, e in ipairs(entries) do
		widths[i] = r * 2 + fs * 0.35 + self:textWidth(e.name or "", size)
		total = total + widths[i] + (i > 1 and gap or 0)
	end
	local right = cfg.x + cfg.width - self.plot.pad - (cfg.titleInset or 0)
	local x = right - total
	if x < titleEnd + fs * 2 then
		return
	end
	local cy = baseline + fs * 0.36
	for i, e in ipairs(entries) do
		drawBadgeAt(e.badge, x + r, cy, r)
		self:text(cfg.look.text .. (e.name or ""), mathFloor(x + r * 2 + fs * 0.35), mathFloor(baseline), "o", size)
		x = x + widths[i] + gap
	end
end

-- A marker drawn as a shape in its colour, over a dark one a little larger, so it reads on
-- any line; a thin line down to the point it stands for when it had to move off it.
function Graph:drawShape(m, x1, y1, x2, y2)
	local marker = m.marker
	local look = self.cfg.look
	if m.ty and mathAbs(m.ty - m.py) > 1 then
		glColor(look.markerTick)
		glBeginEnd(GL_LINES, emitLine, m.px + 0.5, m.py, m.px + 0.5, m.ty)
	end
	local rim = mathMax(1, mathFloor((x2 - x1) * 0.14))
	glColor(0, 0, 0, 0.75)
	fillShape(marker.shape, x1 - rim, y1 - rim, x2 + rim, y2 + rim)
	local c = marker.color or { 1, 1, 1 }
	glColor(c[1], c[2], c[3], 1)
	fillShape(marker.shape, x1, y1, x2, y2)
	return x1, y1, x2, y2
end

-- One marker: its tick, its picture with the corners cut, its frame and its badge (left to
-- the caller with `noBadge`). `scale` grows the picture about its middle, for the one under
-- the cursor.
function Graph:drawMarker(m, scale, noBadge)
	local look = self.cfg.look
	local marker = m.marker
	local x1, y1, x2, y2 = m.x1, m.y1, m.x2, m.y2
	if scale and scale ~= 1 then
		local gx = mathFloor((x2 - x1) * (scale - 1) * 0.5)
		local gy = mathFloor((y2 - y1) * (scale - 1) * 0.5)
		x1, y1, x2, y2 = x1 - gx, y1 - gy, x2 + gx, y2 + gy
	end
	if marker.shape then
		return self:drawShape(m, x1, y1, x2, y2)
	end
	-- A tick from the picture down to the plot, or to the point it sits on.
	glColor(look.markerTick)
	glBeginEnd(GL_LINES, emitLine, m.cx + 0.5, y1, m.px + 0.5, m.onSeries and m.py or self.area.bottom)
	self:drawPicture(marker, x1, y1, x2, y2)
	if marker.badge and not noBadge then
		self:drawBadge(marker.badge, x1, y1, x2, y2)
	end
	return x1, y1, x2, y2
end

-- A picture in a rect with its corners cut and a frame round it: its texture - a unit's,
-- zoomed in a little - or its colour, on a backdrop of its own when it has one.
function Graph:drawPicture(marker, x1, y1, x2, y2)
	local look = self.cfg.look
	local cut = self:markerCut(x2 - x1)
	local corners = chamfered(x1, y1, x2, y2, cut)
	-- A picture with see-through parts can sit on a backdrop of its own.
	local backdrop = marker.backdrop
	if backdrop then
		glColor(backdrop[1], backdrop[2], backdrop[3], backdrop[4] or 1)
		glBeginEnd(GL_TRIANGLE_FAN, emitFan, corners)
	end
	if marker.texture then
		-- Zoomed in a little, the more the smaller the picture: a unit picture has air
		-- around the unit. The engine's textures load flipped, so t runs from 1 down to 0
		-- going up.
		local z = marker.zoom or self.cfg.markerZoom or mathMin(0.06, 2.5 / mathMax(1, x2 - x1))
		local w, h = mathMax(1, x2 - x1), mathMax(1, y2 - y1)
		glColor(1, 1, 1, 1)
		glTexture(marker.texture)
		glBeginEnd(GL_TRIANGLE_FAN, emitPictureFan, corners, x1, y1, w, h, z)
		glTexture(false)
	else
		local c = marker.color or { 1, 1, 1 }
		glColor(c[1], c[2], c[3], 0.9)
		glBeginEnd(GL_TRIANGLE_FAN, emitFan, corners)
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
end

function Graph:drawMarkers()
	for _, m in ipairs(self.placed) do
		self:drawMarker(m, 1, true)
	end
	-- The badges over every picture: one drawn after its neighbour would cover the corner a
	-- badge reaches past.
	for _, m in ipairs(self.placed) do
		local marker = m.marker
		if marker.badge and not marker.shape then
			self:drawBadge(marker.badge, m.x1, m.y1, m.x2, m.y2)
		end
	end
end

-- What the legend names: the series, or what the two bars of a row are.
function Graph:legendEntries(series)
	if self.cfg.kind == "bars" then
		return self.cfg.bars.legend or {}
	end
	return series
end

-- The title and the legend, in the room the layout kept above the plot for them.
function Graph:drawLegend()
	local cfg = self.cfg
	local look = cfg.look
	local fs = cfg.fontSize
	local plot = self.plot
	local entries = self:legendEntries(self.prepared)
	local titleH = cfg.title and fs * 1.9 or 0
	local legendH = (cfg.legend and #entries > 0) and fs * 1.7 * (self.legendRows or 1) or 0
	local top = plot.top + titleH + legendH
	if cfg.title then
		local baseline = mathFloor(top - fs * 1.1)
		self:text(look.title .. cfg.title, plot.left, baseline, "o", fs * 1.15)
		self:drawMarkerLegend(plot.left + self:textWidth(cfg.title, fs * 1.15), baseline)
	end
	if not cfg.legend then
		return
	end
	local y = mathFloor(top - titleH - fs * 1.3)
	---@type number
	local x0 = self.area and self.area.left or plot.left
	local x = x0
	local swatch = mathFloor(fs * 0.8)
	for si, p in ipairs(entries) do
		local w = self:textWidth(p.name, fs, true)
		-- Wrapped where the layout counted a row for it.
		if x + swatch + fs * 0.4 + w > plot.right and x > x0 then
			x = x0
			y = mathFloor(y - fs * 1.7)
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
		self:text(color .. p.name, mathFloor(x + swatch + fs * 0.4), mathFloor(y + swatch * 0.15), "o", fs, true)
		x = mathFloor(x + swatch + fs * 0.4 + w + fs * 1.2)
	end
end

----------------------------------------------------------------
-- Bars
----------------------------------------------------------------

local function fillRect(x1, y1, x2, y2)
	glBeginEnd(GL_QUADS, function()
		glVertex(x1, y1)
		glVertex(x2, y1)
		glVertex(x2, y2)
		glVertex(x1, y2)
	end)
end

-- A text cut to a width, with ".." where it was cut; whole characters only.
function Graph:fitText(str, width, size)
	if self:textWidth(str, size) <= width then
		return str
	end
	local cut = str
	while #cut > 0 do
		-- Back over one character: its continuation bytes, then its first.
		local n = #cut
		while n > 1 and cut:byte(n) >= 128 and cut:byte(n) < 192 do
			n = n - 1
		end
		cut = cut:sub(1, n - 1)
		if self:textWidth(cut .. "..", size) <= width then
			return cut .. ".."
		end
	end
	return ""
end

-- A row a series, top down: its picture, its name, a bar as long as its value with a thin
-- one as long as `sub` under it - both on one scale - and its value at the right edge. As
-- many rows as fit, each as tall as the room gives it between the least and the most; the
-- ones left over are counted in a line under the last.
function Graph:prepareBars()
	local cfg = self.cfg
	local bars = cfg.bars
	local plot = self.plot
	local fs = cfg.fontSize
	local rows = self.series
	local n = #rows
	local height = plot.top - plot.bottom
	local least = mathMax(fs + 2, mathFloor(fs * bars.minRow))
	local most = mathMax(least, mathFloor(fs * bars.maxRow))
	local rowH = n > 0 and mathMax(least, mathMin(most, mathFloor(height / n))) or most
	local fit = mathMin(n, mathFloor(height / rowH))
	-- More rows than room: scrolled through where the owner lets the wheel do it, with a bar
	-- along the right edge; else the rest counted in a line under the last.
	local scrolls = fit < n and bars.scroll == true
	if fit < n and not scrolls and bars.more then
		fit = mathMax(0, mathFloor((height - fs * 1.5) / rowH))
	end
	-- Other rows altogether start from the top again.
	if self.barKey ~= bars.key then
		self.barKey, self.barOffset = bars.key, 0
	end
	local offset = scrolls and mathMax(0, mathMin(self.barOffset or 0, n - fit)) or 0
	self.barOffset, self.barScrolls = offset, scrolls
	self.barMore = scrolls and 0 or n - fit
	self.legendRows = 1
	local gap = mathFloor(fs * 0.5)
	-- The columns and the scale are every row's, the ones scrolled out of view too, so
	-- nothing moves while the rows go by.
	local pictures = false
	local yFormat = cfg.yFormat or defaultFormat
	local nameW, valueW, top = 0, 0, 0
	local texts = {}
	for i = 1, n do
		local r = rows[i]
		---@cast r -?
		if r.texture then
			pictures = true
		end
		nameW = mathMax(nameW, self:textWidth(r.name or "", fs))
		texts[i] = r.valueText or yFormat(r.value or 0)
		valueW = mathMax(valueW, self:textWidth(texts[i], fs))
		top = mathMax(top, r.value or 0, r.sub or 0)
	end
	local pic = pictures and rowH - mathMax(2, mathFloor(rowH * 0.12)) * 2 or 0
	nameW = mathMin(mathFloor(nameW + 1), mathFloor((plot.right - plot.left) * bars.nameShare))
	local nameX = plot.left + (pic > 0 and pic + gap or 0)
	local left = nameX + (nameW > 0 and nameW + gap or 0)
	local trackW = scrolls and mathMax(3, mathFloor(fs * 0.35)) or 0
	local valueX = plot.right - (scrolls and trackW + gap or 0)
	local right = mathMax(left + 10, mathFloor(valueX - valueW - gap))
	-- One scale for every bar and every thin one.
	local scale = top > 0 and (right - left) / top or 0
	local placed = {}
	for j = 1, fit do
		local i = offset + j
		local r = rows[i]
		---@cast r -?
		local y2 = plot.top - (j - 1) * rowH
		placed[j] = {
			row = r,
			index = i,
			y1 = y2 - rowH,
			y2 = y2,
			name = self:fitText(r.name or "", nameW, fs),
			valueText = texts[i],
			barEnd = left + mathMax(0, r.value or 0) * scale,
			subEnd = r.sub and left + mathMax(0, r.sub) * scale or nil,
		}
	end
	self.barRows = placed
	self.barLayout = {
		pic = pic,
		nameX = nameX,
		left = left,
		right = right,
		rowH = rowH,
		valueX = valueX,
		trackW = trackW,
		total = n,
		fit = fit,
	}
	self.area = { left = plot.left, right = plot.right, bottom = plot.top - fit * rowH, top = plot.top }
end

-- Scrolls a bar chart with more rows than room by `delta` rows. Answers whether it moved.
function Graph:scrollBars(delta)
	if self.cfg.kind ~= "bars" then
		return false
	end
	if self.dirty or not self.list then
		self:measure()
	end
	local lay = self.barLayout
	if not self.barScrolls or not lay then
		return false
	end
	local to = mathMax(0, mathMin(lay.total - lay.fit, (self.barOffset or 0) + delta))
	if to == self.barOffset then
		return false
	end
	self.barOffset = to
	self.dirty = true
	return true
end

function Graph:drawBars()
	local cfg = self.cfg
	local bars = cfg.bars
	local look = cfg.look
	local fs = cfg.fontSize
	local plot = self.plot
	local lay = self.barLayout
	local barH = mathMax(3, mathFloor(lay.rowH * 0.36))
	local subH = mathMax(2, mathFloor(lay.rowH * 0.12))
	for i, p in ipairs(self.barRows) do
		local r = p.row
		-- Every other row on a faint plate, to read across by.
		if i % 2 == 0 then
			glColor(look.plotFill)
			fillRect(plot.left, p.y1, plot.right, p.y2)
		end
		local mid = mathFloor((p.y1 + p.y2) * 0.5)
		if lay.pic > 0 and r.texture then
			local y1 = mathFloor(mid - lay.pic * 0.5)
			self:drawPicture(r, plot.left, y1, plot.left + lay.pic, y1 + lay.pic)
		end
		-- The bar and the thin one under it, the two of them centred in the row.
		local both = barH + (p.subEnd and subH + 1 or 0)
		local by2 = mathFloor(mid + both * 0.5)
		local by1 = by2 - barH
		local c = r.color or { 0.8, 0.8, 0.8 }
		if p.barEnd > lay.left then
			glColor(c[1], c[2], c[3], 0.85)
			fillRect(lay.left, by1, mathMax(lay.left + 1, p.barEnd), by2)
		end
		if p.subEnd and p.subEnd > lay.left then
			glColor(bars.subColor)
			fillRect(lay.left, by1 - 1 - subH, mathMax(lay.left + 1, p.subEnd), by1 - 1)
		end
		local ty = mathFloor(mid - fs * 0.35)
		self:text(look.text .. p.name, lay.nameX, ty, "o", fs)
		self:text(look.title .. p.valueText, lay.valueX, ty, "or", fs)
	end
	-- Scrolled: a track along the right edge, and on it the part in view.
	if self.barScrolls and lay.total > 0 then
		local area = self.area
		local x2 = plot.right
		local x1 = x2 - lay.trackW
		local span = area.top - area.bottom
		glColor(1, 1, 1, 0.06)
		fillRect(x1, area.bottom, x2, area.top)
		local thumbH = mathMax(fs, span * lay.fit / lay.total)
		local room = lay.total - lay.fit
		local thumbTop = area.top - (room > 0 and (span - thumbH) * (self.barOffset or 0) / room or 0)
		glColor(1, 1, 1, 0.32)
		fillRect(x1, mathFloor(thumbTop - thumbH), x2, mathFloor(thumbTop))
	end
	if self.barMore > 0 and bars.more then
		local last = self.barRows[#self.barRows]
		local y = (last and last.y1 or plot.top) - fs * 1.2
		self:text(look.text .. bars.more(self.barMore), lay.nameX, mathFloor(y), "o", fs)
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
			local w = self:textWidth(p.name, fs, true)
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
			self:text(
				look.text .. p.name,
				mathFloor(x + swatch + fs * 0.4),
				mathFloor(y + swatch * 0.15),
				"o",
				fs,
				true
			)
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
	if cfg.kind == "bars" then
		self.xs, self.prepared, self.placed, self.spanRects = {}, {}, {}, {}
		self:layout()
		self:prepareBars()
		self.measures = (self.measures or 0) + 1
		return
	end
	self:prepareSamples()
	self:layout()
	if cfg.kind == "radar" then
		self.placed = {}
		self.spanRects = {}
		self:prepareRadar()
	else
		self:prepareLine()
		self:placeMarkers()
		self:placeSpans()
	end
	-- What a hit remembered is only good for the layout it was found in.
	self.measures = (self.measures or 0) + 1
end

-- The hit found last is handed back while the chart is laid out as it was and the cursor
-- is over the same thing, the tooltip it worked out with it, rather than made again every
-- frame; `last` is it while it may be.
local function lastHit(self)
	return self.memoGen == self.measures and self.memoHit or nil
end

local function remember(self, hit)
	self.memoHit, self.memoGen = hit, self.measures
	return hit
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
	elseif cfg.kind == "bars" then
		self:drawBars()
		self:drawLegend()
	else
		self:drawGrid()
		if cfg.kind == "stacked" then
			self:drawStacked()
		else
			self:drawLines()
			self:drawEndLabels()
		end
		-- Over the curves: a stretch along the bottom is often where a line lies, at nothing.
		self:drawSpans()
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
		-- Drawn again over the baked ones, larger - at least the size it has in an uncrowded
		-- lane: pictures that overlap and shrink in a crowded one are read by hovering them.
		local scale = self.cfg.markerHoverScale
		local width = m.x2 - m.x1
		if self.markerFullSize and width > 0 then
			scale = mathMax(scale, self.markerFullSize / width)
		end
		self:drawMarker(m, scale)
		glColor(1, 1, 1, 1)
		return
	end
	if hit.kind == "row" then
		local p = hit.placed
		glColor(1, 1, 1, 0.07)
		fillRect(self.plot.left, p.y1, self.plot.right, p.y2)
		glColor(1, 1, 1, 1)
		return
	end
	if hit.kind == "span" then
		local r = hit.rect
		local c = r.span.color or { 1, 1, 1 }
		glColor(c[1], c[2], c[3], 1)
		glBeginEnd(GL_QUADS, function()
			glVertex(r.x1, r.y1 - 1)
			glVertex(r.x2, r.y1 - 1)
			glVertex(r.x2, r.y2 + 1)
			glVertex(r.x1, r.y2 + 1)
		end)
		glColor(look.crosshair)
		glBeginEnd(GL_LINES, function()
			glVertex(r.x1 + 0.5, self.area.bottom)
			glVertex(r.x1 + 0.5, self.area.top)
			glVertex(r.x2 - 0.5, self.area.bottom)
			glVertex(r.x2 - 0.5, self.area.top)
		end)
		glColor(1, 1, 1, 1)
		return
	end
	if hit.kind == "point" and self.area then
		local area = self.area
		-- The line under the cursor drawn again over the others, at full strength.
		---@type table?
		local near = hit.nearest and self.prepared[hit.nearest]
		if near and near.runs then
			local c = near.color
			local width = near.width + 1
			if glSmoothing then
				glSmoothing(false, true, false)
			end
			glLineWidth(width)
			glColor(c[1], c[2], c[3], 1)
			self:strokeRuns(near.runs, width)
			glLineWidth(1)
			if glSmoothing then
				glSmoothing(false, false, false)
			end
		end
		glColor(look.crosshair)
		glBeginEnd(GL_LINES, function()
			glVertex(mathFloor(hit.px) + 0.5, area.bottom)
			glVertex(mathFloor(hit.px) + 0.5, area.top)
		end)
		local r = mathMax(2, self.cfg.lineWidth * 1.5)
		for _, e in ipairs(hit.entries) do
			local c = e.color
			glColor(c[1], c[2], c[3], 1)
			glBeginEnd(GL_TRIANGLE_FAN, emitDot, hit.px, e.py, r)
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
			local last = lastHit(self)
			if last and last.placed == m then
				return last
			end
			return remember(
				self,
				{ kind = "marker", marker = m.marker, placed = m, px = m.px, py = m.py, text = m.marker.text }
			)
		end
	end
	for i = #self.spanRects, 1, -1 do
		local r = self.spanRects[i]
		---@cast r -?
		if mx >= r.x1 - 1 and mx <= r.x2 + 1 and my >= r.y1 - 1 and my <= r.y2 + 1 then
			local last = lastHit(self)
			if last and last.rect == r then
				return last
			end
			return remember(self, { kind = "span", rect = r, text = r.span.text })
		end
	end
	if cfg.kind == "bars" then
		for _, p in ipairs(self.barRows or {}) do
			if my >= p.y1 and my < p.y2 and mx >= self.plot.left and mx <= self.plot.right then
				local last = lastHit(self)
				if last and last.kind == "row" and last.index == p.index then
					return last
				end
				return remember(self, { kind = "row", index = p.index, placed = p, text = p.row.text })
			end
		end
		return nil
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
		local last = lastHit(self)
		if last and last.kind == "axis" and last.axis == axis then
			return last
		end
		local entries = {}
		for si, p in ipairs(self.prepared) do
			entries[#entries + 1] = { series = si, name = p.name, color = p.color, value = p.axisValues[axis] }
		end
		local a = self.axes[axis]
		---@cast a -?
		return remember(self, { kind = "axis", axis = axis, label = a.label or a.key, entries = entries })
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
	-- The line the cursor is over, if one is close enough to it: brought to the front.
	---@type integer?
	local nearest = nil
	if cfg.kind == "line" then
		local best = mathMax(8, cfg.fontSize) + 0.5
		for si, p in ipairs(self.prepared) do
			local v = p.ys[i]
			if v then
				local d = mathAbs(self.sy(v) - my)
				if d < best then
					nearest, best = si, d
				end
			end
		end
	end
	local last = lastHit(self)
	if last and last.kind == "point" and last.index == i and last.nearest == nearest then
		return last
	end
	local px = self.sx(self.xs[i] or 0)
	-- A series an entry, in the tables of the chart's last point hit when the caller lets it
	-- go at every hitTest (`reuseHits`).
	local old = cfg.reuseHits and self.memoHit or nil
	local entries = old and old.kind == "point" and old.entries or {}
	local n = 0
	for si, p in ipairs(self.prepared) do
		local v = p.ys[i]
		if cfg.kind == "stacked" or v then
			n = n + 1
			local e = entries[n]
			if not e then
				e = {}
				entries[n] = e
			end
			e.series, e.name, e.color = si, p.name, p.color
			if cfg.kind == "stacked" then
				local share = p.shares and p.shares[i] or 0
				local part = cfg.stackShares == false and mathMax(0, v or 0) or share
				e.value, e.share, e.raw = v or 0, share, nil
				e.py = self.sy(self:stackTop(si, i) - part * 0.5)
			else
				e.value, e.share, e.raw = v, nil, p.raw and p.raw[i] or nil
				e.py = self.sy(v)
			end
		end
	end
	for k = #entries, n + 1, -1 do
		entries[k] = nil
	end
	return remember(self, {
		kind = "point",
		index = i,
		x = self.xs[i],
		px = px,
		entries = entries,
		nearest = nearest,
		total = cfg.kind == "stacked" and cfg.stackShares == false and self.totals[i] or nil,
	})
end

-- A tooltip for a hit: the x, then every series' value in its colour, largest first.
function Graph:describe(hit)
	if not hit then
		return nil
	end
	if hit.kind == "marker" or hit.kind == "span" then
		return hit.text
	end
	if hit.kind == "row" then
		return hit.text or (self.cfg.look.title .. (hit.placed.row.name or "") .. "  " .. hit.placed.valueText)
	end
	-- Worked out once for a hit, which is handed back while the cursor stays on it.
	if hit.described then
		return hit.described
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
		if hit.total and cfg.totalLabel then
			lines[2] = cfg.look.text .. cfg.totalLabel .. "  " .. cfg.look.title .. yFormat(hit.total)
		end
		for _, e in ipairs(entries) do
			local value
			if cfg.rawFormat and e.raw then
				value = yFormat(e.value) .. cfg.look.text .. "  " .. cfg.rawFormat(e.raw)
			else
				value = yFormat(e.raw or e.value)
			end
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
	hit.described = table.concat(lines, "\n")
	return hit.described
end

return Graph
