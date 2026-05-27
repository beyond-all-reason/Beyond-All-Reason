--------------------------------------------------------------------------------
-- IceUI-GL4 - framework facade
--------------------------------------------------------------------------------
-- Ties the three layers together into one widget-friendly API:
--   core_gl4.lua  -> instanced GL4 rendering (rectangles only)
--   style.lua     -> CSS-like stylesheets (named, inheritable styles)
--   layout.lua    -> grid / row / column geometry
--
-- A widget loads this once:
--   local IceUI = VFS.Include("luaui/Include/IceUI/iceui.lua")
--
-- ...builds a stylesheet, creates a Panel, fills it with elements each frame,
-- and lets IceUI handle rendering, hover/press state, hit-testing and text.
--
-- The Panel does NOT retain a scene graph. Each frame the widget rebuilds its
-- element list (cheap: it's just Lua tables) and IceUI draws it. This keeps the
-- model dead simple -- no diffing, no dirty flags -- while still being one
-- instanced draw call thanks to the core.
--
-- Text is drawn separately from the instanced rects, via WG['fonts'], after the
-- rect flush (text can't go through the SDF rect shader).
--------------------------------------------------------------------------------

-- VFS.RAW_FIRST so includes resolve from the unpacked working copy as well as
-- from a packaged mod archive.
local Style  = VFS.Include("luaui/Include/IceUI/style.lua",  nil, VFS.RAW_FIRST)
local Layout = VFS.Include("luaui/Include/IceUI/layout.lua", nil, VFS.RAW_FIRST)

local IceUI = {}
IceUI.Style  = Style
IceUI.Layout = Layout

-- The three BAR font indices (Poppins / Exo2 / monospace). Used to group text
-- by font so font Begin/End runs once per distinct font, without allocating a
-- set table every frame. Declared early -- both tooltip and base text use it.
local FONT_INDICES = { 1, 2, 3 }

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------
-- A Panel is a frame-rebuilt draw buffer. Rendering runs in two phases to
-- match the IceUI-GL4 host (rects first, then text on top):
--
--   draw phase (host draw callback):
--     panel:begin(mx, my, mouseDown)   -- pass current mouse state
--     panel:box(style, rect [,opts])   -- queue a styled rectangle
--     panel:label(text, rect [,opts])  -- queue centered text (not drawn yet)
--     panel:button(id, style, rect, label) -> hovered, clicked
--     panel:finish()                   -- end the draw phase, settle input state
--
--   text phase (host text callback):
--     panel:drawText()                 -- draw all queued text, over the rects
--
-- Hover/press tinting is resolved automatically from the mouse state passed to
-- :begin(). `clicked` is reported on mouse-button release inside the element
-- that the press started on (standard click semantics).

local Panel = {}
Panel.__index = Panel

-- Return a cached list of `n` ones, for equal-weight Layout.row/column splits.
-- Cached so tabBar etc. allocate no weight table per frame.
local onesCache = {}
local function ones(n)
	local t = onesCache[n]
	if not t then
		t = {}
		for i = 1, n do t[i] = 1 end
		onesCache[n] = t
	end
	return t
end

-- Create a Panel bound to a resolved stylesheet.
-- `sheet` is the raw stylesheet table; it is resolved here.
function IceUI.newPanel(sheet)
	local self = setmetatable({}, Panel)
	self.styles  = Style.resolve(sheet or {})
	self.texts   = {}      -- queued text draws for this frame: {text,x,y,size,opts}
	self.mx      = 0
	self.my      = 0
	self.mdown   = false
	self.pressId = nil     -- element id the current press started on
	self.tip     = nil     -- pending tooltip request for this frame
	self.tipRect = nil     -- computed tooltip box rect (set in :finish)
	return self
end

-- Look up a resolved style by name. Accepts a name string or a style table
-- directly (for one-off inline styles).
function Panel:style(nameOrTable)
	if type(nameOrTable) == "table" then
		return nameOrTable
	end
	return self.styles[nameOrTable] or {}
end

-- Begin a frame. mx,my = mouse position (pixels), mdown = left button held.
function Panel:begin(mx, my, mdown)
	self.mx, self.my = mx, my

	-- track press start so we can detect a real click on release
	if mdown and not self.mdown then
		self._pressStarted = true       -- a new press began this frame
	end
	self._releasedThisFrame = (not mdown) and self.mdown
	self.mdown = mdown

	for i = #self.texts, 1, -1 do self.texts[i] = nil end
	-- self.tip is NOT cleared here: the tooltip is managed every frame by
	-- :buildTooltip, independent of the (possibly cached) draw phase.
end

-- Queue a styled rectangle. `opts` may carry:
--   hover / press / z        -- interaction + depth overrides
--   uv = {u0,v0,u1,v1}       -- atlas UV rect of an icon to draw on the rect
--   iconInset                -- 0..0.5 inset of the icon inside the rect
function Panel:box(styleRef, rect, opts)
	local style = self:style(styleRef)
	local quad  = Style.toQuad(style, rect, opts)
	if opts then
		quad.uv        = opts.uv
		quad.iconInset = opts.iconInset
	end
	WG.IceUI.add(quad)
	return rect
end

-- Like :box, but queues into the OVERLAY layer (drawn on top of all base
-- content of every IceUI widget). Used for the tooltip box.
function Panel:overlayBox(styleRef, rect, opts)
	local style = self:style(styleRef)
	local quad  = Style.toQuad(style, rect, opts)
	if opts then
		quad.uv        = opts.uv
		quad.iconInset = opts.iconInset
	end
	if WG.IceUI.addOverlay then
		WG.IceUI.addOverlay(quad)
	else
		WG.IceUI.add(quad)   -- fallback if host has no overlay layer
	end
	return rect
end

-- Queue centered text inside `rect`. Button labels are drawn in ALL CAPS for
-- a consistent UI look; pass opts.keepCase to keep the original casing (used
-- for the hotkey badge, which is already a single upper-case letter, etc.).
-- By default the label is auto-shrunk in :drawText() so it fits within `rect`
-- (minus a small margin). Set opts.noFit to keep the text at its given size.
-- opts.color / opts.size / opts.font / opts.align override the style defaults.
-- opts.insetL : left inset (px) -- shifts the text right and shrinks its fit
--               width, e.g. to leave room for an icon on the left of a tab.
function Panel:label(text, rect, opts)
	opts = opts or {}
	if not opts.keepCase and type(text) == "string" then
		text = text:upper()
	end
	local size   = opts.size or 14
	local insetL = opts.insetL or 0
	local align  = opts.align or "cvo"
	-- x: centred on the rect for a centred ("c") align, else the rect's left
	-- edge (+insetL) so non-centred text (left-aligned labels) starts there.
	local cx
	if align:find("c", 1, true) then
		cx = (rect[1] + insetL + rect[3]) * 0.5
	else
		cx = rect[1] + insetL
	end
	local cy   = (rect[2] + rect[4]) * 0.5

	-- max pixel width the text may occupy; :drawText() shrinks/wraps to fit.
	-- nil disables fitting/wrapping. NOTE: must be a real if -- the idiom
	-- `opts.noFit and nil or X` always yields X in Lua (nil is falsy).
	local maxw
	if not opts.noFit then
		maxw = (rect[3] - rect[1] - insetL) - 6
	end

	self.texts[#self.texts + 1] = {
		text  = text,
		x     = cx,
		y     = cy,
		size  = size,
		maxw  = maxw,
		-- font option letters: c=horizontally centered, v=vertically centered,
		-- o=outline. "cvo" centers the glyphs on (x,y); "vo" = left-aligned.
		opts  = align,
		color = opts.color,
		font  = opts.font,
	}
end

-- Reusable scratch rect for badge geometry -- :box and :label copy what they
-- need, so one shared table avoids a per-badge allocation.
local badgeScratch = { 0, 0, 0, 0 }

-- Draw a small text badge sized to its text in one CORNER of `rect`.
-- `corner` is "tr" (default), "tl", "br" or "bl". `badgeStyleRef` names the
-- style (a hotkeyBadge-like style: badgeSize / badgeInset / badgePad[L/R] /
-- fontSize / font / text). No-op for empty text. The box is queued, then the
-- text -- callers should call this AFTER queuing the element it sits on.
function Panel:_cornerBadge(rect, text, badgeStyleRef, corner)
	if not text or text == "" then return end
	local st = self:style(badgeStyleRef or "hotkeyBadge")

	local getFont = WG['fonts'] and WG['fonts'].getFont
	local font    = getFont and getFont(st.font or 2)
	if not font then return end

	local size  = st.fontSize  or 11
	local h     = st.badgeSize or 16
	local inset = st.badgeInset or 2
	local padL  = st.badgePadL or st.badgePad or 3
	local padR  = st.badgePadR or st.badgePad or 3

	local label = (st.keepCase and text) or text:upper()
	local textW = font:GetTextWidth(label) * size
	local w     = textW + padL + padR

	corner = corner or "tr"
	local isLeft = (corner == "tl" or corner == "bl")
	local isTop  = (corner == "tr" or corner == "tl")
	local x1 = isLeft and (rect[1] + inset) or (rect[3] - inset - w)
	local y2 = isTop  and (rect[4] - inset) or (rect[2] + inset + h)
	local b = badgeScratch
	b[1], b[2], b[3], b[4] = x1, y2 - h, x1 + w, y2

	self:box(st, b)
	-- the text rect is the badge minus the L/R padding; :label centers within
	-- it, which places the glyphs with the asymmetric left/right margins.
	-- noFit: the rect is sized exactly to the text, don't shrink it.
	self:label(label, { b[1] + padL, b[2], b[3] - padR, b[4] },
		{ color = st.text, size = size, font = st.font, noFit = true,
		  keepCase = st.keepCase })
end

-- Draw a small hotkey badge in the top-right corner of `rect`. Thin wrapper
-- over :_cornerBadge for the common hotkey case (top-right, "hotkeyBadge").
function Panel:_hotkeyBadge(rect, hotkey, badgeStyleRef)
	self:_cornerBadge(rect, hotkey, badgeStyleRef or "hotkeyBadge", "tr")
end

-- Composite button: draws a styled box, applies hover/pressed states from the
-- stylesheet, draws an icon OR a text label, and returns (hovered, clicked).
-- `styleRef` must name a style that may define states.hover / states.pressed.
--
-- `opts` (optional):
--   icon      = {u0,v0,u1,v1}  -- atlas UV rect; if set, the icon is drawn
--                                 INSTEAD of the label
--   iconInset = number         -- 0..0.5, padding of the icon inside the button.
--                                 Default 0: the icon fills the button edge to
--                                 edge. Only text labels keep a margin.
--   labelColor / labelSize     -- text overrides when a label is drawn
--   hotkey    = string         -- if set, a small hotkey badge is drawn in
--                                 the top-right corner of the button
function Panel:button(id, styleRef, rect, label, opts)
	opts = opts or {}
	local style   = self:style(styleRef)
	local hovered = Layout.hit(rect, self.mx, self.my)

	-- remember which element a press started on (for click detection)
	if hovered and self._pressStarted then
		self.pressId = id
	end

	-- The button always draws with its BASE style: hover/press feedback is an
	-- animated shader uniform (WG.IceUI.setHover), not part of the VBO. This
	-- keeps the base VBO static while hovering -- no rebuild, no re-upload.
	-- Icons fill the button edge to edge (iconInset defaults to 0).
	self:box(style, rect, {
		uv        = opts.icon,
		iconInset = opts.icon and (opts.iconInset or 0) or nil,
	})

	-- icon replaces the label; fall back to text when there is no icon.
	-- opts.labelInsetL leaves room on the left (e.g. for a separately-drawn
	-- tab icon) -- the text is then centred in the remaining space.
	if not opts.icon and label then
		self:label(label, rect, {
			color  = opts.labelColor or style.text,
			size   = opts.labelSize  or style.fontSize,
			insetL = opts.labelInsetL,
		})
	end

	-- hotkey badge in the top-right corner, on top of icon/label
	if opts.hotkey then
		self:_hotkeyBadge(rect, opts.hotkey, opts.badgeStyle)
	end

	-- click = release inside the element that the press started on
	local clicked = hovered and self._releasedThisFrame and (self.pressId == id)
	return hovered, clicked
end

-- A tab button: like :button, but it carries a selected state. A selected tab
-- is drawn with `selectedStyleRef`, an unselected one with `styleRef`.
-- Returns (hovered, clicked) -- the caller decides what "clicked" does (it is
-- the caller that tracks which tab is active).
--
--   id               unique element id
--   styleRef         style for an UNSELECTED tab
--   selectedStyleRef style for the SELECTED tab
--   rect             {l,b,r,t}
--   label            text shown on the tab
--   selected         true if this tab is the active one
--   opts             optional: hotkey, labelColor, labelSize (see :button)
function Panel:tab(id, styleRef, selectedStyleRef, rect, label, selected, opts)
	local ref = selected and selectedStyleRef or styleRef
	return self:button(id, ref, rect, label, opts)
end

-- Lay out a horizontal row of tabs across `rect` and draw them.
--   spec.tabs        list of { label=, hotkey= } (one per tab)
--   spec.selected    index of the currently active tab
--   spec.style       style name for unselected tabs   (default "tab")
--   spec.selStyle    style name for the selected tab   (default "tabActive")
--   spec.gap         pixels between tabs               (default 0)
--   spec.idPrefix    id prefix for the tab buttons     (default "tab")
-- Returns the index of a tab CLICKED this frame, or nil.
function Panel:tabBar(rect, spec)
	local tabs = spec.tabs
	local n = #tabs
	if n == 0 then return nil end

	local segs = Layout.row(rect, ones(n), spec.gap or 0)
	local style    = spec.style    or "tab"
	local selStyle = spec.selStyle or "tabActive"
	local prefix   = spec.idPrefix or "tab"

	local clickedIndex
	for i = 1, n do
		local t = tabs[i]
		local _, clicked = self:tab(prefix .. i, style, selStyle,
			segs[i], t.label, i == spec.selected, { hotkey = t.hotkey })
		if clicked then
			clickedIndex = i
		end
	end
	return clickedIndex
end

-- End the draw phase. Instanced base rects were queued via :box; here we only
-- settle one-shot input state. The tooltip is handled separately, every frame,
-- by :buildTooltip (it must stay live even when the base layer is cached).
function Panel:finish()
	self._pressStarted = false
	if self._releasedThisFrame then
		self.pressId = nil
	end
	self._releasedThisFrame = false
end

-- Build the tooltip for this frame and queue its box into the OVERLAY layer.
-- Call EVERY frame from the host's overlay-build phase, with the spec for the
-- currently hovered element, or nil for no tooltip. Unlike the old draw-phase
-- tooltip, this is independent of :begin/:finish so it works while the base
-- layer is cached. The tooltip text is drawn afterwards by :drawTooltipText.
-- `spec`:
--   spec.title   -- optional bold/amber heading line
--   spec.hotkey  -- optional hotkey string, shown next to the title
--   spec.text    -- optional body text (may contain \n for multiple lines)
function Panel:buildTooltip(spec)
	if spec and (spec.title or spec.text or spec.costs) then
		self.tip = spec
		self:_layoutTooltip()
		if self.tipRect then
			self:overlayBox("tooltip", self.tipRect)
		end
	else
		self.tip = nil
	end
end

-- Smallest font size we will shrink to before giving up.
local MIN_FONT_SIZE = 7

-- Word-wrap `text` into as many lines as needed so each fits `maxw` pixels at
-- `size`. Breaks on spaces; a single word wider than maxw is left on its own
-- line. Appends the resulting line strings to `out` and returns it. Used for
-- tooltip body text so a long unit description does not blow out the box.
local function wrapToWidth(font, text, size, maxw, out)
	out = out or {}
	if not maxw or maxw <= 0 or font:GetTextWidth(text) * size <= maxw then
		out[#out + 1] = text
		return out
	end
	local line = nil
	for word in text:gmatch("%S+") do
		if not line then
			line = word
		else
			local try = line .. " " .. word
			if font:GetTextWidth(try) * size <= maxw then
				line = try
			else
				out[#out + 1] = line
				line = word
			end
		end
	end
	if line then out[#out + 1] = line end
	return out
end

-- Split `text` into at most 2 lines that each fit `maxw` pixels at `size`.
-- Breaks on spaces only. Returns a list of 1 or 2 line strings. If even a
-- 2-way split does not fit, the caller shrinks the size afterwards.
local function wrapTwoLines(font, text, size, maxw)
	if font:GetTextWidth(text) * size <= maxw then
		return { text }                       -- already fits on one line
	end

	-- collect word boundaries
	local words = {}
	for w in text:gmatch("%S+") do
		words[#words + 1] = w
	end
	if #words < 2 then
		return { text }                       -- nothing to break on
	end

	-- find the split point that best balances the two lines
	local best, bestDiff
	for split = 1, #words - 1 do
		local l1 = table.concat(words, " ", 1, split)
		local l2 = table.concat(words, " ", split + 1)
		local w1 = font:GetTextWidth(l1) * size
		local w2 = font:GetTextWidth(l2) * size
		local diff = math.abs(w1 - w2)
		-- prefer splits where both lines fit; among those, the most balanced
		local over = math.max(0, w1 - maxw) + math.max(0, w2 - maxw)
		local score = over * 10000 + diff
		if not bestDiff or score < bestDiff then
			bestDiff = score
			best = { l1, l2 }
		end
	end
	return best or { text }
end

-- Largest font size <= `size` at which every line fits `maxw`.
local function fitSize(font, lines, size, maxw)
	local widest = 0
	for i = 1, #lines do
		local w = font:GetTextWidth(lines[i])
		if w > widest then widest = w end
	end
	if widest * size <= maxw then
		return size
	end
	return math.max(MIN_FONT_SIZE, maxw / widest)
end

-- Resolve the UI font (index 2). Returns nil if WG['fonts'] is unavailable.
local function uiFont()
	local getFont = WG['fonts'] and WG['fonts'].getFont
	return getFont and getFont(2) or nil
end

-- Build an inline colour escape from a {r,g,b} table.
local function colorEscape(c)
	if not c then return "" end
	return string.char(255,
		math.floor((c[1] or 1) * 255),
		math.floor((c[2] or 1) * 255),
		math.floor((c[3] or 1) * 255))
end

--------------------------------------------------------------------------------
-- tooltip layout + rendering
--------------------------------------------------------------------------------

-- Compute self.tipRect: the tooltip box, sized to its text and placed near the
-- mouse but kept fully on screen. Builds self.tip.lines as a flat list of
-- { text, size, color, font } ready for :drawText to print. No-op without a
-- font getter. Title and body may use different fonts (style.font/bodyFont).
-- Measure the tooltip content (lines, box width/height) and cache it on
-- self._tipCache. The expensive part -- string assembly + per-line
-- font:GetTextWidth measurement -- only re-runs when the tooltip CONTENT
-- changes (a different button), not every frame. Returns the cache, or nil.
function Panel:_measureTooltip(tip)
	-- Cache validity is checked by comparing the content FIELDS directly --
	-- never by assembling a key string, which would allocate every frame while
	-- a tooltip is shown. `costs` is compared by table identity: tooltip specs
	-- are cached per item by the consumer, so the same hover yields the same
	-- table. _measureTooltip runs every frame; this check must allocate nothing.
	local cache = self._tipCache
	if cache and cache.kTitle == tip.title and cache.kText == tip.text
			and cache.kHotkey == tip.hotkey and cache.kCosts == tip.costs then
		return cache
	end

	local getFont = WG['fonts'] and WG['fonts'].getFont
	if not getFont then return nil end

	local st = self:style("tooltip")
	local padL, padB, padR, padT = Style.padding(st)
	local bodySize  = st.fontSize  or 14
	local titleSize = st.titleSize or 15
	local titleFont = st.font     or 2
	local bodyFont  = st.bodyFont or 1

	-- assemble the lines (title + hotkey, then body lines, then a cost row).
	-- the title is upper-cased to match the all-caps button labels; the body
	-- keeps its normal casing (it is descriptive prose).
	local lines = {}
	if tip.title then
		local titleStr = tip.title:upper()
		if tip.hotkey and tip.hotkey ~= "" then
			titleStr = titleStr .. "  " ..
				colorEscape(st.hotkeyText) .. "[" .. tip.hotkey:upper() .. "]"
		end
		lines[#lines + 1] = { text = titleStr, size = titleSize,
		                      color = st.titleText, font = titleFont }
	end
	if tip.text then
		-- body: split on explicit newlines, then word-wrap each piece to
		-- st.maxBodyW so a long unit description does not blow out the box.
		local bodyFontObj = getFont(bodyFont)
		local maxBodyW = st.maxBodyW
		for line in (tip.text .. "\n"):gmatch("(.-)\n") do
			if line ~= "" then
				if bodyFontObj and maxBodyW then
					local wrapped = wrapToWidth(bodyFontObj, line, bodySize,
						maxBodyW)
					for w = 1, #wrapped do
						lines[#lines + 1] = { text = wrapped[w],
							size = bodySize, color = st.text, font = bodyFont }
					end
				else
					lines[#lines + 1] = { text = line, size = bodySize,
					                      color = st.text, font = bodyFont }
				end
			end
		end
	end
	-- cost row: a list of { icon=path, value=number, color={r,g,b} } drawn as
	-- "[icon] value   [icon] value" on one line.
	if tip.costs and #tip.costs > 0 then
		lines[#lines + 1] = { costs = tip.costs, size = bodySize,
		                      font = bodyFont }
	end
	if #lines == 0 then return nil end

	-- measure each line with its own font. ALSO precompute everything the
	-- per-frame draw needs (the colour-prefixed print string, cost-item number
	-- strings and their x offsets) so _drawTooltipText never concatenates a
	-- string or measures text -- it just prints. This runs only on a content
	-- change; the draw runs every frame.
	local maxW, totalH = 0, 0
	for i = 1, #lines do
		local ln = lines[i]
		local font = getFont(ln.font)
		if ln.costs then
			-- cost row: each item = icon (square, line height) + gap + number,
			-- items separated by a wider gap.
			ln.h = ln.size * 1.4
			local iconW = ln.h
			local gapIconText = ln.size * 0.3
			local gapItems    = ln.size * 0.9
			local w  = 0
			-- per-item draw data, precomputed: number string + x offsets
			ln.items = {}
			for j = 1, #ln.costs do
				local c = ln.costs[j]
				local numW = font and (font:GetTextWidth(tostring(c.value))
					* ln.size) or 0
				ln.items[j] = {
					iconDX = w,                       -- icon left, from row x
					textDX = w + iconW + gapIconText, -- number left, from row x
					numStr = colorEscape(c.color) .. tostring(c.value),
					icon   = c.icon,
					color  = c.color,
				}
				w = w + iconW + gapIconText + numW
				if j < #ln.costs then w = w + gapItems end
			end
			ln.iconW = iconW
			if w > maxW then maxW = w end
		else
			local w = font and (font:GetTextWidth(ln.text) * ln.size) or 0
			if w > maxW then maxW = w end
			ln.h = ln.size * 1.25
			ln.printStr = colorEscape(ln.color) .. ln.text   -- ready to Print
		end
		totalH = totalH + ln.h
	end

	cache = {
		-- the content fields this measurement was computed for (see the
		-- field-by-field check at the top -- no key string assembled)
		kTitle  = tip.title,
		kText   = tip.text,
		kHotkey = tip.hotkey,
		kCosts  = tip.costs,
		lines = lines,
		boxW  = maxW + padL + padR,
		boxH  = totalH + padB + padT,
		padL  = padL,
		padT  = padT,
	}
	self._tipCache = cache
	return cache
end

-- Compute self.tipRect: the tooltip box, sized to its (cached) content and
-- placed near the mouse, kept on screen. Only the placement runs every frame;
-- the measurement is cached by :_measureTooltip.
function Panel:_layoutTooltip()
	local tip = self.tip
	if not tip then
		self.tipRect = nil
		return
	end

	local m = self:_measureTooltip(tip)
	if not m then
		self.tipRect = nil
		return
	end

	-- place near the mouse, above-right, clamped to the screen.
	-- Query the mouse live -- self.mx/my are only refreshed on a base rebuild.
	local vsx, vsy = Spring.GetViewGeometry()
	local mx, my = Spring.GetMouseState()
	local left = mx + 18
	local bottom = my + 18
	if left + m.boxW > vsx then left = mx - 18 - m.boxW end
	if left < 0 then left = 0 end
	if bottom + m.boxH > vsy then bottom = my - 18 - m.boxH end
	if bottom < 0 then bottom = 0 end

	-- reuse a persistent tipRect table -- this runs every frame while a tooltip
	-- is shown, so allocating a fresh rect here is needless garbage.
	local r = self.tipRect
	if not r then
		r = {}
		self.tipRect = r
	end
	r[1], r[2], r[3], r[4] = left, bottom, left + m.boxW, bottom + m.boxH

	tip.lines     = m.lines
	tip.boxLeft   = left
	tip.boxTop    = bottom + m.boxH
	tip.padL      = m.padL
	tip.padT      = m.padT
end

-- Draw the icons of one cost row (no font work -- the numbers are printed
-- separately, batched into the caller's font Begin/End). ln.items is the
-- per-item draw data precomputed by _measureTooltip.
local function drawCostRowIcons(ln, x, cy)
	local iconW = ln.iconW
	local half  = iconW * 0.5
	for j = 1, #ln.items do
		local it  = ln.items[j]
		local col = it.color
		local cx  = x + it.iconDX
		gl.Color(col and col[1] or 1, col and col[2] or 1,
		         col and col[3] or 1, 1)
		gl.Texture(it.icon)
		gl.TexRect(cx, cy - half, cx + iconW, cy + half)
	end
	gl.Texture(false)
	gl.Color(1, 1, 1, 1)
end

-- Draw the tooltip text inside its box. Two passes so font Begin/End runs ONCE
-- (not per line / per cost item, which dominated the hover cost): pass 1 draws
-- all cost-row icons (gl.Texture, no font), pass 2 prints every text string and
-- cost number inside a single font Begin/End. All strings + offsets were
-- precomputed by _measureTooltip -- this never concatenates or measures.
function Panel:_drawTooltipText()
	local tip = self.tip
	if not tip or not tip.lines then return end

	local getFont = WG['fonts'] and WG['fonts'].getFont
	if not getFont then return end

	local lines = tip.lines
	local x = tip.boxLeft + (tip.padL or 0)
	local y = tip.boxTop  - (tip.padT or 0)

	-- pass 1: cost-row icons (no font state involved)
	local yy = y
	for i = 1, #lines do
		local ln = lines[i]
		if ln.costs then
			drawCostRowIcons(ln, x, yy - ln.h * 0.5)
		end
		yy = yy - ln.h
	end

	-- pass 2: all text, in one font Begin/End per distinct font. Most tooltips
	-- use a single font, so this is usually one Begin/End for the whole tooltip.
	for fi = 1, #FONT_INDICES do
		local fontIdx = FONT_INDICES[fi]
		-- does any line use this font?
		local any = false
		for i = 1, #lines do
			if (lines[i].font or 2) == fontIdx then any = true break end
		end
		if any then
			local font = getFont(fontIdx)
			if font then
				font:Begin()
				yy = y
				for i = 1, #lines do
					local ln = lines[i]
					if (ln.font or 2) == fontIdx then
						local cy = yy - ln.h * 0.5
						if ln.costs then
							for j = 1, #ln.items do
								local it = ln.items[j]
								font:Print(it.numStr, x + it.textDX, cy,
									ln.size, "vo")
							end
						else
							font:Print(ln.printStr, x, cy, ln.size, "vo")
						end
					end
					yy = yy - ln.h
				end
				font:End()
			end
		end
	end
end

-- Compute the print plan for a text item ONCE: the colour prefix, the wrap
-- into 1-2 lines, the fitted size, and each line's final string + x/y. Cached
-- on t.plan so subsequent frames just print it -- wrapTwoLines/fitSize do
-- font:GetTextWidth measurements, far too costly to redo every frame.
-- A text item lives until the next rebuild (panel.texts is only rebuilt then),
-- so the cache stays valid for the whole cached period.
local function buildTextPlan(font, t)
	local prefix = colorEscape(t.color)
	local plan = {}   -- list of { str, x, y, size }

	if t.maxw and t.maxw > 0 then
		local lines = wrapTwoLines(font, t.text, t.size, t.maxw)
		local size  = fitSize(font, lines, t.size, t.maxw)
		if #lines == 1 then
			plan[1] = { str = prefix .. lines[1], x = t.x, y = t.y, size = size }
		else
			local lineH = size * 1.05
			plan[1] = { str = prefix .. lines[1], x = t.x,
			            y = t.y + lineH * 0.5, size = size }
			plan[2] = { str = prefix .. lines[2], x = t.x,
			            y = t.y - lineH * 0.5, size = size }
		end
	else
		plan[1] = { str = prefix .. t.text, x = t.x, y = t.y, size = t.size }
	end
	t.plan = plan
end

-- Draw one queued text item with the given (already begun) font. The expensive
-- layout (wrap/fit/measure) is done once by buildTextPlan and cached on t.plan.
local function printTextItem(font, t)
	if not t.plan then
		buildTextPlan(font, t)
	end
	local plan = t.plan
	for i = 1, #plan do
		local p = plan[i]
		font:Print(p.str, p.x, p.y, p.size, t.opts)
	end
end

-- Text phase: draw all BASE text queued this frame, on top of the flushed
-- base rectangles. Each item is drawn with ITS OWN font (t.font, default 2),
-- so labels and badges can use different fonts. Items are grouped per font so
-- font Begin/End runs once per distinct font. Long labels wrap to 2 lines and
-- shrink to fit; items with maxw == nil keep their size. Tooltip text is drawn
-- separately by :drawOverlayText.
-- Allocation-free: iterates the fixed FONT_INDICES list, no per-frame table.
function Panel:drawText(fontGetter)
	if #self.texts == 0 then return end

	local getFont = fontGetter or (WG['fonts'] and WG['fonts'].getFont)
	if not getFont then return end

	-- one pass per font index: begin that font, draw every item using it, end.
	-- a font with no items is skipped cheaply (no Begin/End).
	for fi = 1, #FONT_INDICES do
		local fontIdx = FONT_INDICES[fi]
		-- does any item use this font?
		local any = false
		for i = 1, #self.texts do
			if (self.texts[i].font or 2) == fontIdx then
				any = true
				break
			end
		end
		if any then
			local font = getFont(fontIdx)
			if font then
				font:Begin()
				for i = 1, #self.texts do
					local t = self.texts[i]
					if (t.font or 2) == fontIdx then
						printTextItem(font, t)
					end
				end
				font:End()
			end
		end
	end
end

-- Overlay text phase: draw the tooltip text, on top of the overlay layer's
-- tooltip box. Call from the host's overlay callback (after the overlay flush).
-- _drawTooltipText manages its own font Begin/End (lines may differ in font).
function Panel:drawOverlayText()
	self:_drawTooltipText()
end

return IceUI
