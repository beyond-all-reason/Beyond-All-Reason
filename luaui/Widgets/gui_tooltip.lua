local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Tooltip",
		desc = "Shows tooltips",
		author = "Floris",
		date = "April 2017",
		license = "GNU GPL, v2 or later",
		layer = -1200000,
		enabled = true,
		modalExempt = true, -- the windows show their own tooltips through this widget
	}
end

-- Localized functions for performance
local mathCeil = math.ceil
local mathFloor = math.floor
local mathMax = math.max

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry

--[[

-- Available API functions:
WG['tooltip'].AddTooltip(name, area, value, delay, title)  -- area: ScreenRect {left,bottom,right,top}   value(optional): 'text'   delay(optional): #seconds   title(optional): 'text'
WG['tooltip'].RemoveTooltip(name)

WG['tooltip'].ShowTooltip(name, value, x, y, title)    -- value(optional): 'text'   x/y (optional): display coordinates   title(optional): 'text'
WG['tooltip'].UnitContent(unitDefID)   -- a unit type's tooltip as a content table: name, description, tech level, tags, cost

You can use 'AddTooltip' to add a screen area that will display a tooltip when you hover over it

Use 'ShowTooltip' to directly show a tooltip, the name you give should be unique, and not one you desined in 'AddTooltip'
(the name will be deleted after use)

A value is text (lines at "\n") or a table of parts, each optional:
  title = "Nettle",                        the title argument goes first
  text = "Light Anti-Air Missile Tower",   lines below the title
  corner = "T2",                           a small label in the top right corner
  rows = { { "Average speed", "11.5" }, { "Minimum speed", "4", dim = true } },   a table
  tags = { { tag, tag }, { tag } },        rows of tags, each { icon = "LuaUI/Images/...", label = "Medium", color = { r, g, b, a } },
                                           icon and label optional; an icon that is no file is left out
  note = "...",                            dimmer lines at the bottom
  graph = { points = { x, y, ... }, xMax = 9000, yMax = 15, left = "-5:00", right = "0:00" },
                                           a small line chart: x 0 to xMax, y 0 to yMax, what to call its left and right ends;
                                           in the values' colour unless given color = { r, g, b }
  cost = { metal = 80, energy = 900 },     in the bottom right corner (numbers rounded; a number as a string, "2.04", as it is)
Tables are compared by value and copied: a new one each call redraws nothing while it is the same.

]]
--

local cfg = {
	-- the build menus' unit tooltips (their hovered unit, WG.buildmenu.hoverID) as a unit's content table: tech level,
	-- health/DPS/speed and ability tags, cost
	unitTooltips = false,
	-- the health, DPS and speed tags say low, medium or high by how a unit ranks among the units of its kind (buildings,
	-- ground and sea units, aircraft): the fraction of them below it
	unitClassSplits = { 0.333, 0.667 },
}

local UNIT_TIP = "buildmenu" -- the build menus' tooltip
local NONE = {}
local PART_TEXT = "\255\244\244\244"
local PART_DIM = "\255\170\176\174"
local ROW_STRIPE = { 1, 1, 1, 0.05 }
local TAG_PLATE = { 1, 1, 1, 0.08 }
local GRAPH_GRID = { 1, 1, 1, 0.1 }
local GRAPH_LINE = { 244 / 255, 244 / 255, 244 / 255 } -- PART_TEXT, as the rows' values
local COST_ORDER = { "metal", "energy" }
local COST_ICONS = { metal = "LuaUI/Images/metal.png", energy = "LuaUI/Images/energy.png" }
local COST_COLORS = { metal = "\255\245\245\245", energy = "\255\255\255\130" }

local defaultDelay = 0.37
local cfgFontSize = 14

local xOffset = 12
local yOffset = -xOffset

local vsx, vsy = spGetViewGeometry()
local widgetScale = 1
local usedFontSize = cfgFontSize

local spGetMouseState = Spring.GetMouseState
local math_floor = mathFloor
local math_ceil = mathCeil
local math_isInRect = math.isInRect
local string_lines = string.lines

local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local tooltips = {}
local cleanupGuishaderAreas = {}
---@type LuaFont
local font
---@type LuaFont
local font2
---@type function
local RectRound
---@type function
local UiElement
---@type number
local bgpadding

-- Texture pool for reusing textures instead of recreating them
local texturePool = {}

-- Get or create a texture from the pool
local function getPooledTexture(width, height, key)
	local w = math_floor(width)
	local h = math_floor(height)

	if w < 1 or h < 1 then
		return nil
	end

	local sizeKey = w .. "x" .. h

	-- Try to find an existing texture of the right size
	if texturePool[sizeKey] and #texturePool[sizeKey] > 0 then
		return table.remove(texturePool[sizeKey])
	end

	-- Create a new texture
	return gl.CreateTexture(w, h, {
		target = GL.TEXTURE_2D,
		format = GL.RGBA8,
		fbo = true,
	})
end

-- Return a texture to the pool for reuse
local function returnTextureToPool(texture, width, height)
	if not texture then
		return
	end

	local w = math_floor(width)
	local h = math_floor(height)
	local sizeKey = w .. "x" .. h

	if not texturePool[sizeKey] then
		texturePool[sizeKey] = {}
	end

	-- Limit pool size per dimension to avoid memory bloat
	if #texturePool[sizeKey] < 4 then
		table.insert(texturePool[sizeKey], texture)
	else
		gl.DeleteTexture(texture)
	end
end

-- Clear all textures for a tooltip (called when content changes)
local function clearTooltipTextures(name)
	if tooltips[name].bgTex then
		returnTextureToPool(tooltips[name].bgTex, tooltips[name].bgTexWidth, tooltips[name].bgTexHeight)
		tooltips[name].bgTex = nil
		tooltips[name].bgTexWidth = nil
		tooltips[name].bgTexHeight = nil
	end
	if tooltips[name].contentTex then
		returnTextureToPool(tooltips[name].contentTex, tooltips[name].contentTexWidth, tooltips[name].contentTexHeight)
		tooltips[name].contentTex = nil
		tooltips[name].contentTexWidth = nil
		tooltips[name].contentTexHeight = nil
	end
end

--------------------------------------------------------------------------------
-- Content tables
--------------------------------------------------------------------------------

local function textOf(v)
	return v ~= nil and tostring(v) or nil
end

local function sameValue(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in pairs(a) do
		if not sameValue(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function copyValue(v)
	if type(v) ~= "table" then
		return v
	end
	local c = {}
	for k, x in pairs(v) do
		c[k] = copyValue(x)
	end
	return c
end

local function hasContent(t)
	return t.value ~= nil or t.title ~= nil or t.content ~= nil
end

-- whether a value and title differ from what the tooltip shows
local function changed(t, value, title)
	if type(value) == "table" then
		return t.content == nil or t.titleArg ~= textOf(title) or not sameValue(value, t.content)
	end
	return t.content ~= nil or t.value ~= textOf(value) or t.title ~= textOf(title)
end

-- new content: measured and drawn again when next shown
local function setText(name, value, title)
	local t = tooltips[name]
	if type(value) == "table" then
		t.content, t.value, t.titleArg = copyValue(value), nil, textOf(title)
		t.title = textOf(title) or textOf(value.title)
	else
		t.content, t.value, t.titleArg = nil, textOf(value), nil
		t.title = textOf(title)
	end
	clearTooltipTextures(name)
	t.maxWidth, t.maxHeight, t.lines, t.parts = nil, nil, nil, nil
end

--------------------------------------------------------------------------------
-- Units: a unit type's tooltip as a content table
--------------------------------------------------------------------------------

-- How each tag's level reads, and the abilities a unit type is tagged with: what says so, and the test.
local CLASS_TAGS = {
	health = { name = "ui.statusBars.health", color = { 0.51, 0.88, 0.56, 1 }, levels = { "low", "medium", "high" } },
	dps = { name = "ui.unitstats.dps", color = { 0.92, 0.39, 0.39, 1 }, levels = { "low", "medium", "high" } },
	speed = { name = "ui.unitstats.speed", color = { 0.42, 0.73, 0.96, 1 }, levels = { "slow", "medium", "fast" } },
}
local ABILITIES = {
	{
		"ui.unitstats.radar",
		function(ud)
			return ud.radarDistance >= 1000 -- not the commanders' small one
		end,
	},
	{
		"ui.unitstats.sonar",
		function(ud)
			return ud.sonarDistance > 0
		end,
	},
	{
		"ui.unitstats.jammer",
		function(ud)
			return ud.radarDistanceJam > 0
		end,
	},
	{
		"ui.keybinds.select.filterName.builder",
		function(ud)
			return ud.isBuilder and not ud.isFactory
		end,
	},
	{
		"ui.unitstats.amphibious",
		function(ud)
			-- the movedefs' amphibious depth: ships and hovers have none
			local depth = ud.moveDef and ud.moveDef.depth
			return depth ~= nil and depth >= 5000 and depth < 10000
		end,
	},
	{
		"ui.unitstats.allterrain",
		function(ud)
			local moveName = ud.moveDef and ud.moveDef.name
			return type(moveName) == "string" and string.find(moveName:lower(), "tbot", 1, true) ~= nil
		end,
	},
	{
		"ui.unitstats.cloak",
		function(ud)
			return ud.canCloak
		end,
	},
	{
		"ui.unitstats.stealth",
		function(ud)
			return ud.stealth
		end,
	},
	{
		"ui.statusBars.shield",
		function(ud)
			return ud.hasShield
		end,
	},
	{
		"ui.unitstats.stockpile",
		function(ud)
			return ud.canStockpile
		end,
	},
	{
		"ui.unitstats.resurrect",
		function(ud)
			return ud.canResurrect
		end,
	},
	{
		"ui.unitstats.capture",
		function(ud)
			return ud.canCapture
		end,
	},
	{
		"ui.unitstats.emp",
		function(ud)
			return ud.canParalyze
		end,
	},
}
local ABILITY_COLOR = { 0.82, 0.82, 0.8, 1 }

local unitRanks = nil ---@type table? per kind: sorted health, dps and speed of the players' units
local unitContents = {} ---@type table<integer, table> per unitDefID: corner, tags, cost

local function kindOf(ud)
	if ud.canFly then
		return "air"
	end
	if ud.canMove and (ud.speed or 0) > 0 then
		return "ground"
	end
	return "static"
end

---@return number
local function unitDps(ud)
	local weaponInfo = require("common/weapons")
	local armorDefault = Game.armorTypes and Game.armorTypes.default or 0
	local armorVtol = Game.armorTypes and Game.armorTypes.vtol
	local dps = 0.0
	for _, w in ipairs(ud.weapons) do
		local wd = WeaponDefs[w.weaponDef] ---@type any
		if wd and wd.customParams.bogus ~= "1" and not wd.paralyzer and wd.type ~= "Shield" then
			local damages = wd.damages
			local damage = mathMax(damages[armorDefault] or 0, armorVtol and damages[armorVtol] or 0)
			local _, maxDps = weaponInfo.GetDamagePerSecond(wd, damage)
			dps = dps + maxDps
		end
	end
	return dps
end

-- the units players build (and their commanders), to rank a unit among
local function buildRanks()
	local playable = {} ---@type table<integer, boolean>
	for id, ud in pairs(UnitDefs) do
		for _, option in ipairs(ud.buildOptions) do
			playable[option] = true
		end
		if ud.customParams.iscommander then
			playable[id] = true
		end
	end
	unitRanks = {}
	for id in pairs(playable) do
		local ud = UnitDefs[id] ---@type table?
		if ud and not (string.find(ud.name, "_scav", 1, true) or string.find(ud.name, "raptor", 1, true)) then
			local kind = kindOf(ud)
			local r = unitRanks[kind] or { health = {}, dps = {}, speed = {} }
			unitRanks[kind] = r
			r.health[#r.health + 1] = ud.health
			local dps = unitDps(ud)
			if dps > 0 then
				r.dps[#r.dps + 1] = dps
			end
			if kind ~= "static" then
				r.speed[#r.speed + 1] = ud.speed
			end
		end
	end
	for _, r in pairs(unitRanks) do
		table.sort(r.health)
		table.sort(r.dps)
		table.sort(r.speed)
	end
end

-- 1, 2 or 3: where v ranks in a sorted list (the fraction of it below v, ties counting half)
local function classOf(sorted, v)
	local n = #sorted
	if n == 0 then
		return 2
	end
	local lo, hi = 1, n + 1
	while lo < hi do
		local m = mathFloor((lo + hi) * 0.5)
		if sorted[m] < v then
			lo = m + 1
		else
			hi = m
		end
	end
	local first = lo
	hi = n + 1
	while lo < hi do
		local m = mathFloor((lo + hi) * 0.5)
		if sorted[m] <= v then
			lo = m + 1
		else
			hi = m
		end
	end
	local below = (first - 1 + (lo - first) * 0.5) / n
	local splits = cfg.unitClassSplits
	if below < splits[1] then
		return 1
	elseif below < splits[2] then
		return 2
	end
	return 3
end

local function classTag(key, sorted, v)
	local tag = CLASS_TAGS[key]
	return {
		color = tag.color,
		label = BAR.I18N(tag.name) .. ": " .. BAR.I18N("ui.tooltip." .. tag.levels[classOf(sorted, v)]),
	}
end

-- a unit type's corner, tags and cost (kept: a language change clears them)
local function unitContent(unitDefID)
	local c = unitContents[unitDefID] ---@type table?
	if c then
		return c
	end
	local ud = UnitDefs[unitDefID]
	if not ud then
		return nil
	end
	if not unitRanks then
		buildRanks()
	end
	local kind = kindOf(ud)
	local r = unitRanks and unitRanks[kind] or { health = {}, dps = {}, speed = {} }
	local classes = { classTag("health", r.health, ud.health) }
	local dps = unitDps(ud)
	if dps > 0 then
		classes[#classes + 1] = classTag("dps", r.dps, dps)
	end
	if kind ~= "static" then
		classes[#classes + 1] = classTag("speed", r.speed, ud.speed)
	end
	local abilities = {}
	for _, a in ipairs(ABILITIES) do
		if a[2](ud) then
			abilities[#abilities + 1] = { label = BAR.I18N(a[1]), color = ABILITY_COLOR }
		end
	end
	c = {
		corner = "T" .. (tonumber(ud.customParams.techlevel) or 1),
		tags = #abilities > 0 and { classes, abilities } or { classes },
		cost = { metal = ud.metalCost, energy = ud.energyCost },
	}
	unitContents[unitDefID] = c
	return c
end

-- the build menus' hovered unit, when the tooltip is its
local function hoveredUnit(t)
	local buildmenu = WG.buildmenu ---@type table?
	local id = buildmenu and buildmenu.hoverID
	local ud = id and UnitDefs[id]
	local tip = ud and ud.translatedTooltip
	if tip and tip ~= "" and t.value and string.find(t.value, tip, 1, true) then
		return id
	end
	return nil
end

-- what a content table or a unit adds to the title and text, for measuring and drawing; nil for a plain text
local function viewOf(t)
	if not (t.content or t.unitDefID) then
		return nil
	end
	local c = t.content or NONE
	local unit = t.unitDefID and unitContent(t.unitDefID) or NONE
	return {
		corner = textOf(c.corner or unit.corner),
		rows = c.rows,
		tags = c.tags or unit.tags,
		note = c.note and string_lines(tostring(c.note)) or nil,
		graph = c.graph,
		cost = c.cost or unit.cost,
	}
end

-- A texture a tag's `icon` names: a file, or the engine's own names ("#unitDefID"); else it shows no picture.
local function iconFile(icon)
	if type(icon) ~= "string" or icon == "" then
		return nil
	end
	local first = icon:sub(1, 1)
	if first == "#" or first == ":" or first == "$" or VFS.FileExists(icon) then
		return icon
	end
	return nil
end

local function colorCode(c)
	return string.char(
		255,
		mathMax(1, mathFloor(c[1] * 255)),
		mathMax(1, mathFloor(c[2] * 255)),
		mathMax(1, mathFloor(c[3] * 255))
	)
end

-- The parts under the title and text, each placed from the top of the tooltip's inner rect: its width and height grown
-- to hold them. `W`, `H`: what the title and text take.
local function measureParts(view, W, H)
	local fontSize = math_floor(usedFontSize)
	local lineHeight = fontSize + (fontSize / 4.5)
	local gap = math_floor(fontSize * 0.45)
	local parts = { view = view }
	local spans = {} -- what the costs go beside: bottom, right
	if H > 0 then
		spans[1], spans[2] = H, W
	end
	local function span(bottom, right)
		spans[#spans + 1], spans[#spans + 2] = bottom, right
		W = mathMax(W, right)
	end
	if view.corner then
		parts.cornerFs = math_floor(fontSize * 0.86)
		local w = math_ceil(font:GetTextWidth(view.corner) * parts.cornerFs)
		W = mathMax(W, (H > 0 and W + gap * 2 or 0) + w)
		H = mathMax(H, math_ceil(lineHeight))
	end
	local rows = view.rows
	if rows and #rows > 0 then
		H = H > 0 and H + gap or H
		local labelW, valueW = 0, 0
		for i = 1, #rows do
			labelW = mathMax(labelW, font:GetTextWidth(textOf(rows[i][1]) or "") * fontSize)
			valueW = mathMax(valueW, font:GetTextWidth(textOf(rows[i][2]) or "") * fontSize)
		end
		parts.rowsTop, parts.rowH = H, math_floor(fontSize * 1.42)
		parts.valueX = math_ceil(labelW) + fontSize * 2
		H = H + #rows * parts.rowH
		span(H, parts.valueX + math_ceil(valueW))
	end
	local tags = view.tags
	if tags and #tags > 0 then
		H = H > 0 and H + gap or H
		parts.tagsTop, parts.tagH = H, math_floor(fontSize * 1.45)
		parts.tagPad, parts.tagGap = math_floor(fontSize * 0.45), math_floor(fontSize * 0.25)
		parts.tagIcon = math_floor(fontSize * 1.05)
		parts.tagRows = {}
		for r = 1, #tags do
			local list, x = {}, 0
			for i = 1, #tags[r] do
				local tag = tags[r][i]
				local icon = iconFile(tag.icon)
				local label = textOf(tag.label)
				-- (an icon this widget has no file for, and nothing to say instead: no tag)
				if icon or (label and label ~= "") then
					local w = parts.tagPad * 2
					if icon then
						w = w + parts.tagIcon + (label and parts.tagGap or 0)
					end
					if label then
						w = w + math_ceil(font:GetTextWidth(label) * fontSize)
					end
					list[#list + 1] = { icon = icon, label = label, color = tag.color, x = x, w = w }
					x = x + w + parts.tagGap
				end
			end
			if #list > 0 then
				parts.tagRows[#parts.tagRows + 1] = list
				H = H + parts.tagH + parts.tagGap
				span(H - parts.tagGap, x - parts.tagGap)
			end
		end
		H = H - (#parts.tagRows > 0 and parts.tagGap or 0)
	end
	local note = view.note
	if note and #note > 0 then
		H = H > 0 and H + gap or H
		parts.noteTop = H
		for i = 1, #note do
			H = math_ceil(H + lineHeight)
			span(H, math_ceil(font:GetTextWidth(note[i]) * fontSize))
		end
	end
	local graph = view.graph
	if graph then
		H = H > 0 and H + gap or H
		parts.graphTop, parts.graphH = H, math_floor(42 * widgetScale)
		parts.axisFs = math_floor(fontSize * 0.8)
		parts.axisW = math_ceil(font:GetTextWidth(tostring(graph.yMax)) * parts.axisFs) + math_floor(5 * widgetScale)
		parts.axisH = math_floor(fontSize * 1.15)
		H = H + parts.graphH + parts.axisH
		span(H, parts.axisW + math_floor(170 * widgetScale))
	end
	local cost = view.cost
	if type(cost) == "table" then
		local lines, valuesW = {}, 0
		for _, res in ipairs(COST_ORDER) do
			local amount = tonumber(cost[res])
			if amount then
				local text = type(cost[res]) == "string" and cost[res] or tostring(mathFloor(amount + 0.5))
				lines[#lines + 1] = { res = res, text = text }
				valuesW = mathMax(valuesW, font:GetTextWidth(text) * fontSize)
			end
		end
		if #lines > 0 then
			parts.cost, parts.costRow = lines, math_floor(fontSize * 1.25)
			parts.costIcon = math_floor(fontSize * 1.05)
			local costW = math_ceil(valuesW) + gap + parts.costIcon
			local costH = #lines * parts.costRow
			H = mathMax(H, costH)
			parts.costTop = H - costH
			-- beside what it would run into, at the bottom right
			for i = 1, #spans, 2 do
				if spans[i] > parts.costTop then
					W = mathMax(W, spans[i + 1] + gap * 3 + costW)
				end
			end
			W = mathMax(W, costW)
		end
	end
	return parts, W, H
end

-- A small line chart: its vertices come from these, not a closure a draw.
local chartPoints, chartBottom, chartTop, chartR, chartG, chartB, chartWidth = {}, 0, 0, 1, 1, 1, 1
local function chartFillVertices()
	local span = chartTop - chartBottom
	for i = 1, #chartPoints - 1, 2 do
		local x, y = chartPoints[i], chartPoints[i + 1]
		gl.Color(chartR, chartG, chartB, 0)
		gl.Vertex(x, chartBottom)
		gl.Color(chartR, chartG, chartB, 0.28 * (span > 0 and (y - chartBottom) / span or 0))
		gl.Vertex(x, y)
	end
end
-- The line as a ribbon of triangles, mitred at each point: wide GL lines leave notches at the joins.
local function chartLineVertices()
	local half = chartWidth * 0.5
	for i = 1, #chartPoints - 1, 2 do
		local x, y = chartPoints[i], chartPoints[i + 1]
		local dx1, dy1 = x - (chartPoints[i - 2] or x), y - (chartPoints[i - 1] or y)
		local dx2, dy2 = (chartPoints[i + 2] or x) - x, (chartPoints[i + 3] or y) - y
		local l1, l2 = math.sqrt(dx1 * dx1 + dy1 * dy1), math.sqrt(dx2 * dx2 + dy2 * dy2)
		if l1 == 0 then
			dx1, dy1, l1 = dx2, dy2, l2
		elseif l2 == 0 then
			dx2, dy2, l2 = dx1, dy1, l1
		end
		if l1 > 0 then
			-- along the normals' sum, as far as keeps the width on both segments
			local mx, my = -(dy1 / l1 + dy2 / l2), dx1 / l1 + dx2 / l2
			local len = math.sqrt(mx * mx + my * my)
			if len > 0 then
				local k = half * math.min(2 / len, 2) / len
				mx, my = mx * k, my * k
			else
				mx, my = -dy1 / l1 * half, dx1 / l1 * half
			end
			gl.Vertex(x + mx, y + my)
			gl.Vertex(x - mx, y - my)
		end
	end
end

-- The parts, under the title and text, in the tooltip's content texture.
local function drawParts(parts, addX, addY, maxWidth)
	local view = parts.view
	local fontSize = math_floor(usedFontSize)
	local lineHeight = fontSize + (fontSize / 4.5)
	local right = addX + maxWidth
	local texts = {} -- str, x, y, size, opts: printed together after the plates
	local function text(str, x, y, size, opts)
		texts[#texts + 1] = { str, x, y, size, opts }
	end
	if view.corner then
		text(PART_DIM .. view.corner, right, addY - math_floor(lineHeight * 0.5), parts.cornerFs, "orv")
	end
	if parts.rowsTop then
		for i, row in ipairs(view.rows) do
			local top = addY - parts.rowsTop - (i - 1) * parts.rowH
			if i % 2 == 0 then
				RectRound(addX - bgpadding, top - parts.rowH, right + bgpadding, top, 0, 0, 0, 0, 0, ROW_STRIPE)
			end
			local color = row.dim and PART_DIM or PART_TEXT
			local cy = math_floor(top - parts.rowH * 0.5)
			text(color .. (textOf(row[1]) or ""), addX, cy, fontSize, "ov")
			text(color .. (textOf(row[2]) or ""), addX + parts.valueX, cy, fontSize, "ov")
		end
	end
	if parts.tagsTop then
		for r, list in ipairs(parts.tagRows) do
			local top = addY - parts.tagsTop - (r - 1) * (parts.tagH + parts.tagGap)
			local bottom = top - parts.tagH
			for _, tag in ipairs(list) do
				local x1 = addX + tag.x
				RectRound(x1, bottom, x1 + tag.w, top, math_floor(bgpadding * 0.6), 1, 1, 1, 1, TAG_PLATE)
				local x = x1 + parts.tagPad
				if tag.icon then
					local y = math_floor((top + bottom - parts.tagIcon) * 0.5)
					gl.Color(1, 1, 1, 1)
					gl.Texture(tag.icon)
					gl.TexRect(x, y, x + parts.tagIcon, y + parts.tagIcon)
					gl.Texture(false)
					x = x + parts.tagIcon + parts.tagGap
				end
				if tag.label then
					local code = tag.color and colorCode(tag.color) or PART_TEXT
					text(code .. tag.label, x, math_floor((top + bottom) * 0.5), fontSize, "ov")
				end
			end
		end
	end
	if parts.noteTop then
		for i, line in ipairs(view.note) do
			local top = addY - parts.noteTop - (i - 1) * lineHeight
			text(PART_DIM .. line, addX, math_floor(top - lineHeight * 0.5), fontSize, "ov")
		end
	end
	if parts.graphTop then
		local g = view.graph
		local top = addY - parts.graphTop
		local bottom = top - parts.graphH
		local left = addX + parts.axisW
		gl.Color(GRAPH_GRID)
		gl.Rect(left, top - 1, right, top)
		gl.Rect(left, bottom, right, bottom + 1)
		local labelY = bottom - math_floor(parts.axisH * 0.5)
		text(
			PART_DIM .. tostring(g.yMax),
			left - math_floor(5 * widgetScale),
			top - math_floor(parts.axisFs * 0.5),
			parts.axisFs,
			"orv"
		)
		text(
			PART_DIM .. "0",
			left - math_floor(5 * widgetScale),
			bottom + math_floor(parts.axisFs * 0.5),
			parts.axisFs,
			"orv"
		)
		text(PART_DIM .. (g.left or ""), left, labelY, parts.axisFs, "ov")
		text(PART_DIM .. (g.right or ""), right, labelY, parts.axisFs, "orv")
		local xMax, yMax = g.xMax > 0 and g.xMax or 1, g.yMax > 0 and g.yMax or 1
		local sx, sy = (right - left) / xMax, (top - bottom) / yMax
		chartPoints = {}
		for i = 1, #g.points - 1, 2 do
			chartPoints[i] = left + mathMax(0, math.min(xMax, g.points[i])) * sx
			chartPoints[i + 1] = bottom + mathMax(0, math.min(yMax, g.points[i + 1])) * sy
		end
		chartBottom, chartTop = bottom, top
		local c = g.color or GRAPH_LINE
		chartR, chartG, chartB = c[1], c[2], c[3]
		if #chartPoints >= 4 then
			gl.BeginEnd(GL.TRIANGLE_STRIP, chartFillVertices)
			gl.Color(chartR, chartG, chartB, 1)
			chartWidth = mathMax(1, 1.5 * widgetScale)
			gl.BeginEnd(GL.TRIANGLE_STRIP, chartLineVertices)
		end
	end
	if parts.cost then
		local iconX = right - parts.costIcon
		for i, line in ipairs(parts.cost) do
			local top = addY - parts.costTop - (i - 1) * parts.costRow
			local cy = math_floor(top - parts.costRow * 0.5)
			local y = math_floor(cy - parts.costIcon * 0.5)
			gl.Color(1, 1, 1, 1)
			gl.Texture(COST_ICONS[line.res])
			gl.TexRect(iconX, y, iconX + parts.costIcon, y + parts.costIcon)
			gl.Texture(false)
			text(COST_COLORS[line.res] .. line.text, iconX - math_floor(fontSize * 0.3), cy, fontSize, "orv")
		end
	end
	gl.Color(1, 1, 1, 1)
	if #texts > 0 then
		font:Begin(true)
		font:SetOutlineColor(0, 0, 0, 0.4)
		for _, t in ipairs(texts) do
			font:Print(t[1], t[2], t[3], t[4], t[5])
		end
		font:End()
	end
end

function widget:Initialize()
	widget:ViewResize(vsx, vsy)

	if WG.tooltip == nil then
		WG.tooltip = {}
		WG.tooltip.getFontsize = function()
			return usedFontSize
		end
		---Registers a hover tooltip over a screen rectangle. Calling again with the same
		---name updates it; pass only `name` and `area` to move an existing tooltip.
		---@param name string Caller-chosen key; pass the same one to `RemoveTooltip`.
		---@param area ScreenRect
		---@param value string|number|nil Tooltip body.
		---@param delay number? Seconds of hover before it appears. Defaults to the widget's delay.
		---@param title string|number|nil Tooltip heading.
		WG.tooltip.AddTooltip = function(name, area, value, delay, title)
			if
				(
					(value ~= nil or title ~= nil)
					and area[1] ~= nil
					and area[2] ~= nil
					and area[3] ~= nil
					and area[4] ~= nil
				) or (tooltips[name] ~= nil and hasContent(tooltips[name]))
			then
				if delay == nil then
					delay = defaultDelay
				end
				if tooltips[name] == nil then
					tooltips[name] = {}
				end
				tooltips[name].area = area
				tooltips[name].delay = delay
				if (value ~= nil or title ~= nil) and changed(tooltips[name], value, title) then
					setText(name, value, title)
				end
			end
		end
		WG.tooltip.RemoveTooltip = function(name)
			if tooltips[name] ~= nil then
				clearTooltipTextures(name)
				cleanupGuishaderAreas[name] = true
				tooltips[name] = nil
			end
		end
		WG.tooltip.ShowTooltip = function(name, value, x, y, title)
			if value ~= nil or title ~= nil then
				if not tooltips[name] then
					tooltips[name] = {}
				end
				tooltips[name].disabled = false
				if changed(tooltips[name], value, title) then
					setText(name, value, title)
				end
				if x ~= nil and y ~= nil then
					tooltips[name].pos = { x, y }
				end
			end
		end
		WG.tooltip.UnitContent = function(unitDefID)
			local ud = UnitDefs[unitDefID]
			local unit = unitContent(unitDefID)
			if not (ud and unit) then
				return nil
			end
			return {
				title = ud.translatedHumanName,
				text = ud.translatedTooltip,
				corner = unit.corner,
				tags = unit.tags,
				cost = unit.cost,
			}
		end
	end
end

function widget:Shutdown()
	if WG.guishader then
		for name, tooltip in pairs(tooltips) do
			WG.guishader.RemoveScreenRect("tooltip_" .. name)
			WG.guishader.RemoveScreenRect("2tooltip_" .. name)
		end
	end

	-- Clean up all tooltips (return textures to pool)
	for name, _ in pairs(tooltips) do
		clearTooltipTextures(name)
	end

	-- Clean up the entire texture pool
	for sizeKey, textures in pairs(texturePool) do
		for _, tex in ipairs(textures) do
			gl.DeleteTexture(tex)
		end
	end
	texturePool = {}

	WG.tooltip = nil
end

function widget:ViewResize(x, y)
	vsx, vsy = spGetViewGeometry()

	font, loadedFontSize = WG.fonts.getFont()
	font2 = WG.fonts.getFont(2, 1.6)

	widgetScale = (1 + ((vsy - 850) / 900)) * (0.95 + (ui_scale - 1) / 2.5)
	usedFontSize = cfgFontSize * widgetScale
	yOffset = -mathFloor(xOffset * 0.5) - usedFontSize

	bgpadding = mathCeil(WG.FlowUI.elementPadding * 0.66)
	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	for name, tooltip in pairs(tooltips) do
		if WG.guishader then
			WG.guishader.RemoveScreenRect("tooltip_" .. name)
			WG.guishader.RemoveScreenRect("2tooltip_" .. name)
		end
		-- Clear textures on resize (they'll be recreated with new dimensions)
		clearTooltipTextures(name)
		tooltip.maxWidth = nil
		tooltip.maxHeight = nil
		tooltip.lines = nil
		tooltip.parts = nil
	end
end

function widget:LanguageChanged()
	unitContents = {}
	for _, tooltip in pairs(tooltips) do
		tooltip.maxWidth = nil
		tooltip.maxHeight = nil
		tooltip.lines = nil
		tooltip.parts = nil
	end
	for name in pairs(tooltips) do
		clearTooltipTextures(name)
	end
end

local function drawTooltipBackground(addX, addY, paddingW, paddingH, maxWidth, maxHeight, borderSize)
	RectRound(
		addX - paddingW - borderSize,
		addY - maxHeight - paddingH - borderSize,
		addX + maxWidth + paddingW + borderSize,
		addY + paddingH + borderSize,
		bgpadding * 1.4,
		1,
		1,
		1,
		1,
		{ 0, 0, 0, 0.08 }
	)
	UiElement(
		addX - paddingW,
		addY - maxHeight - paddingH,
		addX + maxWidth + paddingW,
		addY + paddingH,
		1,
		1,
		1,
		1,
		1,
		1,
		1,
		1,
		nil,
		{ 0.85, 0.85, 0.85, (WG.guishader and 0.7 or 0.93) },
		{ 0, 0, 0, (WG.guishader and 0.5 or 0.56) },
		bgpadding
	)
end

local function drawTooltipContent(name, addX, addY, paddingH, lines)
	local titleFontSize = math_floor(usedFontSize * 1.25)
	local fontSize = math_floor(usedFontSize)
	local lineHeight = fontSize + (fontSize / 4.5)
	local maxHeight = math_floor(-fontSize * 0.9)

	if tooltips[name].title and tooltips[name].title ~= "" then
		maxHeight = math_ceil(maxHeight - (titleFontSize * 0.1))
		font2:Begin(true)
		font2:SetOutlineColor(0, 0, 0, 0.6)
		font2:Print("\255\205\255\205" .. tooltips[name].title, addX, maxHeight + addY, titleFontSize, "o")
		font2:End()
		maxHeight = math_ceil(maxHeight - (titleFontSize * 1.12))
	end

	if lines then
		font:Begin(true)
		font:SetOutlineColor(0, 0, 0, 0.4)
		for i, line in ipairs(lines) do
			font:Print("\255\244\244\244" .. line, addX, maxHeight + addY, fontSize, "o")
			maxHeight = maxHeight - lineHeight
		end
		font:End()
	end

	if tooltips[name].parts then
		drawParts(tooltips[name].parts, addX, addY, tooltips[name].maxWidth)
	end
end

local function drawTooltip(name, x, y)
	if cfg.unitTooltips and name == UNIT_TIP then
		local id = hoveredUnit(tooltips[name])
		if id ~= tooltips[name].unitDefID then
			tooltips[name].unitDefID = id
			clearTooltipTextures(name)
			tooltips[name].maxWidth = nil
		end
	end

	local paddingH = math_floor(9.5 * widgetScale)
	local paddingW = math_floor(paddingH * 1.42)

	local addX = mathFloor(vsx * 0.33) -- temp add something so flowui doesn't think its near screen edge
	local addY = mathFloor(vsy * 0.5) -- temp add something so flowui doesn't think its near screen edge

	-- Calculate dimensions if not already done
	if not tooltips[name].maxWidth or not tooltips[name].maxHeight then
		local titleFontSize = math_floor(usedFontSize * 1.25)
		local fontSize = math_floor(usedFontSize)
		local lineHeight = fontSize + (fontSize / 4.5)
		local lines
		local maxWidth = 0
		local maxHeight = 0
		if tooltips[name].title and tooltips[name].title ~= "" then
			maxWidth = math_ceil(mathMax(maxWidth, (font:GetTextWidth(tooltips[name].title) * titleFontSize)))
			maxHeight = math_ceil(maxHeight + (titleFontSize * 1.22))
		end
		local text = tooltips[name].value
		if tooltips[name].content then
			text = textOf(tooltips[name].content.text)
		elseif tooltips[name].unitDefID and text then
			text = string.gsub(text, "\255...", "") -- the build menus colour it
		end
		if text and text ~= "" then
			-- get text dimensions
			lines = string_lines(text)
			for i, line in ipairs(lines) do
				maxWidth = math_ceil(mathMax(maxWidth, (font:GetTextWidth(line) * fontSize)))
				maxHeight = math_ceil(maxHeight + lineHeight)
			end
		end
		local view = viewOf(tooltips[name])
		tooltips[name].parts = nil
		if view then
			tooltips[name].parts, maxWidth, maxHeight = measureParts(view, maxWidth, maxHeight)
		end
		tooltips[name].maxWidth = maxWidth
		tooltips[name].maxHeight = maxHeight
		tooltips[name].lines = lines
	end

	local maxWidth = tooltips[name].maxWidth
	local maxHeight = tooltips[name].maxHeight

	if maxWidth == nil or maxHeight == nil then
		return
	end

	local borderSize = 1

	-- Create display list or texture if not exists
	if not tooltips[name].bgTex then
		local w = math_floor(maxWidth + paddingW + paddingW + borderSize + borderSize)
		local h = math_floor(maxHeight + paddingH + paddingH + borderSize + borderSize)
		if w >= 1 and h >= 1 then
			tooltips[name].bgTex = getPooledTexture(w, h)
			tooltips[name].bgTexWidth = w
			tooltips[name].bgTexHeight = h
			if tooltips[name].bgTex then
				gl.R2tHelper.RenderToTexture(tooltips[name].bgTex, function()
					gl.Translate(-1, -1, 0)
					gl.Scale(2 / w, 2 / h, 0)
					gl.Translate(-addX + paddingW + borderSize, -addY + maxHeight + paddingH + borderSize, 0)
					drawTooltipBackground(addX, addY, paddingW, paddingH, maxWidth, maxHeight, borderSize)
				end, true)
			end
		end
	end
	if not tooltips[name].contentTex then
		local w = math_floor(maxWidth + paddingW + paddingW)
		local h = math_floor(maxHeight + paddingH + paddingH)
		if w >= 1 and h >= 1 then
			tooltips[name].contentTex = getPooledTexture(w, h)
			tooltips[name].contentTexWidth = w
			tooltips[name].contentTexHeight = h
			if tooltips[name].contentTex then
				gl.R2tHelper.RenderToTexture(tooltips[name].contentTex, function()
					gl.Translate(-1, -1, 0)
					gl.Scale(2 / w, 2 / h, 0)
					gl.Translate(-addX + paddingW, -addY + maxHeight + paddingH, 0)
					drawTooltipContent(name, addX, addY, paddingH, tooltips[name].lines)
				end, true)
			end
		end
	end

	-- adjust position when needed
	local posX = math_floor(x + paddingW)
	local posY = math_floor(y - paddingH)
	if posX + maxWidth + paddingW + paddingW > vsx then
		posX = math_floor(posX - maxWidth - paddingW - paddingW - (xOffset * widgetScale * 2))
	end
	if posX - paddingW < 0 then
		posX = 0 + paddingW
	end
	if posY + paddingH > vsy then
		posY = (posY - (posY - vsy)) - paddingH
	end
	if posY - maxHeight - paddingH - paddingH < 0 then
		posY = 0 + maxHeight + paddingH + paddingH
	end

	if WG.guishader then
		WG.guishader.InsertScreenRect(
			posX - paddingW + bgpadding,
			posY - maxHeight - paddingH,
			posX + maxWidth + paddingW - bgpadding,
			posY + paddingH,
			"tooltip_" .. name,
			widget
		)
		WG.guishader.InsertScreenRect(
			posX - paddingW,
			posY - maxHeight - paddingH + bgpadding,
			posX + maxWidth + paddingW,
			posY + paddingH - bgpadding,
			"2tooltip_" .. name,
			widget
		)
	end

	if tooltips[name].bgTex then
		gl.R2tHelper.BlendTexRect(
			tooltips[name].bgTex,
			posX - paddingW - borderSize,
			posY - maxHeight - paddingH - borderSize,
			posX + maxWidth + paddingW + borderSize,
			posY + paddingH + borderSize,
			true
		)
	end
	if tooltips[name].contentTex then
		gl.R2tHelper.BlendTexRect(
			tooltips[name].contentTex,
			posX - paddingW,
			posY - maxHeight - paddingH,
			posX + maxWidth + paddingW,
			posY + paddingH,
			true
		)
	end
end

function widget:DrawScreen()
	if WG.topbar and WG.topbar.showingQuit() then
		return
	end
	if WG.unitstats and WG.unitstats.isShowing() then
		return
	end
	local x, y = spGetMouseState()
	local now = os.clock()

	-- Hover tooltips belong to elements that a modal window is hiding, so they must not
	-- pop up over it. Tooltips shown outright (option descriptions and the like) stay.
	local modalActive = widgetHandler:IsModalActive()

	if WG.guishader then
		for name, _ in pairs(cleanupGuishaderAreas) do
			WG.guishader.RemoveScreenRect("tooltip_" .. name)
			WG.guishader.RemoveScreenRect("2tooltip_" .. name)
			cleanupGuishaderAreas[name] = nil
		end
	end
	for name, tooltip in pairs(tooltips) do
		if
			(tooltip.area == nil and not tooltip.disabled)
			or (
				tooltip.area
				and not modalActive
				and tooltip.area[4] ~= nil
				and math_isInRect(x, y, tooltip.area[1], tooltip.area[2], tooltip.area[3], tooltip.area[4])
			)
		then
			if tooltip.area == nil then
				if tooltip.pos ~= nil then
					drawTooltip(name, tooltip.pos[1], tooltip.pos[2])
				else
					drawTooltip(name, x + (xOffset * widgetScale), y + (yOffset * widgetScale))
				end
				cleanupGuishaderAreas[name] = true
				tooltips[name].disabled = true
			else
				if tooltip.displayTime == nil then
					tooltip.displayTime = now + tooltip.delay
				elseif tooltip.displayTime <= now then
					if tooltip.pos ~= nil then
						drawTooltip(name, tooltip.pos[1], tooltip.pos[2])
					else
						drawTooltip(name, x + (xOffset * widgetScale), y + (yOffset * widgetScale))
					end
				else
					cleanupGuishaderAreas[name] = true
					--Spring.Echo(name, os.clock())
				end
			end
		else
			if tooltip.displayTime ~= nil then
				tooltip.displayTime = nil
				if WG.guishader then
					WG.guishader.RemoveScreenRect("tooltip_" .. name)
					WG.guishader.RemoveScreenRect("2tooltip_" .. name)
				end
			end
		end
	end
end
