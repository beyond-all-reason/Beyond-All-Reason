--------------------------------------------------------------------------------
-- IceUI-GL4 - styling system
--------------------------------------------------------------------------------
-- A small, CSS-like styling layer. A "style" is just a table of visual
-- properties; this module handles resolving, inheriting and merging them so
-- widgets can be designed and re-themed by editing data, not draw code.
--
-- Concepts
--   * A stylesheet is a table of named styles: { panel = {...}, button = {...} }.
--   * A style may set `extends = "<otherName>"` to inherit all properties of
--     another style in the same sheet (single inheritance, resolved once).
--   * A style may define `states` (e.g. hover, pressed, disabled): per-state
--     property overrides that callers blend in by name.
--   * resolve() flattens inheritance so lookups are plain table reads.
--
-- Recognised properties (all optional):
--   background  = {r,g,b,a}      -- solid fill (becomes color1+color2)
--   gradient    = {topColor, bottomColor}  -- overrides background
--   corner      = number         -- uniform corner radius (px or scalable unit)
--   corners     = {tl,tr,br,bl}  -- per-corner radius (overrides corner)
--   border      = number         -- border width
--   borderColor = {r,g,b}
--   gloss       = number         -- 0..1 highlight strength
--   padding     = number | {l,b,r,t}  -- inner spacing for layout
--   text        = {r,g,b,a}      -- text color
--   font        = number         -- font index for WG['fonts'].getFont
--   fontSize    = number
--
-- Nothing here touches the GPU. style.toQuad() converts a resolved style +
-- a rect into the table shape Core:add() expects.
--------------------------------------------------------------------------------

local Style = {}

-- Properties that are colors, used when blending state overrides.
local COLOR_KEYS = { borderColor = true, text = true }

--------------------------------------------------------------------------------
-- internal helpers
--------------------------------------------------------------------------------

-- shallow copy
local function copy(t)
	local r = {}
	for k, v in pairs(t) do r[k] = v end
	return r
end

-- copy `src` properties into `dst` only where `dst` doesn't already have them
local function inheritInto(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = v
		end
	end
end

--------------------------------------------------------------------------------
-- public API
--------------------------------------------------------------------------------

-- Resolve a whole stylesheet: flatten `extends` chains so every style is a
-- complete, self-contained table. Returns a new sheet; the input is untouched.
-- Cyclic `extends` chains are detected and reported (the cycle is broken).
function Style.resolve(sheet)
	local out = {}

	-- recursively resolve one style by name, memoising into `out`
	local resolving = {}
	local function resolveOne(name)
		if out[name] then return out[name] end
		local raw = sheet[name]
		if not raw then
			Spring.Echo("[IceUI-GL4] style not found: " .. tostring(name))
			return {}
		end
		if resolving[name] then
			Spring.Echo("[IceUI-GL4] cyclic style extends at: " .. tostring(name))
			return copy(raw)
		end
		resolving[name] = true

		local flat = copy(raw)
		flat.extends = nil
		if raw.extends then
			local parent = resolveOne(raw.extends)
			inheritInto(flat, parent)
			-- states inherit per-state too
			if parent.states then
				flat.states = flat.states or {}
				for stateName, stateProps in pairs(parent.states) do
					if flat.states[stateName] == nil then
						flat.states[stateName] = stateProps
					end
				end
			end
		end

		resolving[name] = false
		out[name] = flat
		return flat
	end

	for name in pairs(sheet) do
		resolveOne(name)
	end
	return out
end

-- Merge a state override (e.g. style.states.hover) onto a resolved base style.
-- Returns a new table; colors are replaced wholesale, scalars overwritten.
function Style.applyState(base, stateProps)
	if not stateProps then return base end
	local merged = copy(base)
	for k, v in pairs(stateProps) do
		merged[k] = v
	end
	return merged
end

-- One reusable quad table. Style.toQuad fills and returns THIS table instead
-- of allocating a fresh one per call -- the result is consumed immediately by
-- Core:add (which copies the values out), so a single shared table is safe and
-- avoids ~25 table allocations per rebuild + one per tooltip frame. Keeping
-- per-frame allocations near zero is what keeps the widget's kB/s low.
local sharedQuad = {}

-- Convert a resolved style + a pixel rect into a Core:add() quad table.
-- `rect` is { left, bottom, right, top }. Extra per-call values:
--   opts.hover, opts.press : 0..1 tint amounts (passed straight through)
--   opts.z                 : depth
-- WARNING: the returned table is reused on the next call -- consume it (pass
-- it straight to Core:add) before calling Style.toQuad again.
function Style.toQuad(style, rect, opts)
	opts = opts or {}
	local q = sharedQuad

	q.left   = rect[1]
	q.bottom = rect[2]
	q.right  = rect[3]
	q.top    = rect[4]
	q.hover  = opts.hover
	q.press  = opts.press
	q.z      = opts.z or style.z
	q.gloss  = style.gloss
	q.borderWidth = style.border
	q.borderColor = style.borderColor

	-- corners
	if style.corners then
		q.corner = nil
		q.tl = style.corners[1]
		q.tr = style.corners[2]
		q.br = style.corners[3]
		q.bl = style.corners[4]
	else
		q.tl, q.tr, q.br, q.bl = nil, nil, nil, nil
		q.corner = style.corner
	end

	-- fill: gradient takes precedence over a solid background
	if style.gradient then
		q.color1 = style.gradient[1]
		q.color2 = style.gradient[2]
	elseif style.background then
		q.color1 = style.background
		q.color2 = style.background
	else
		q.color1, q.color2 = nil, nil
	end

	-- uv / iconInset are set by the caller (Panel:box) after this returns
	q.uv        = nil
	q.iconInset = nil

	return q
end

-- Resolve padding into explicit left, bottom, right, top pixels.
-- The `padding` property accepts three forms:
--   number          -- uniform on all four sides
--   {h, v}          -- horizontal (left+right), vertical (bottom+top)
--   {l, b, r, t}    -- explicit per-side
-- Alternatively set paddingX / paddingY directly for horizontal / vertical;
-- these override `padding` when present.
-- Returns 0s when nothing is set.
function Style.padding(style)
	local l, b, r, t = 0, 0, 0, 0

	local p = style.padding
	if type(p) == "number" then
		l, b, r, t = p, p, p, p
	elseif type(p) == "table" then
		if #p == 2 then
			-- {horizontal, vertical}
			l, r = p[1] or 0, p[1] or 0
			b, t = p[2] or 0, p[2] or 0
		else
			-- {left, bottom, right, top}
			l, b, r, t = p[1] or 0, p[2] or 0, p[3] or 0, p[4] or 0
		end
	end

	-- explicit per-axis overrides
	if style.paddingX then
		l, r = style.paddingX, style.paddingX
	end
	if style.paddingY then
		b, t = style.paddingY, style.paddingY
	end

	return l, b, r, t
end

return Style
