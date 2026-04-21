local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Terraform Brush",
		desc = "Hover mouse and raise/lower terrain with /terraformup and /terraformdown commands",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local MSG = {
	BRUSH       = "$terraform_brush$",
	RAMP        = "$terraform_ramp$",
	SPLINE_RAMP = "$terraform_ramp_spline$",
	RESTORE     = "$terraform_restore$",
	FULL_RESTORE = "$terraform_full_restore$",
	IMPORT      = "$terraform_import$",
	UNDO        = "$terraform_undo$",
	UNDO_STROKE = "$terraform_undo_stroke$",
	REDO        = "$terraform_redo$",
	MERGE_END   = "$terraform_merge_end$",
	STROKE_END  = "$terraform_stroke_end$",
	NOISE       = "$terraform_noise$",
	FILL_SHAPE  = "$terraform_fill$",
}
local DEFAULT_RADIUS = 100
local UPDATE_INTERVAL = 0.05

-- Prefix all terraform messages with $c$ when cheat is enabled.
-- This certification is recorded in demos, so during replay the prefix is
-- preserved and the gadget can trust it without needing live cheat state.
-- NOTE: Only enable $c$ wrapping when the gadget also supports it (after game restart).
local function SendLuaRulesMsg(msg)
	Spring.SendLuaRulesMsg(msg)
end
local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetGroundHeight = Spring.GetGroundHeight
local Echo = Spring.Echo
local ForceTesselationUpdate = Spring.ForceTesselationUpdate

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glVertex = gl.Vertex
local glBeginEnd = gl.BeginEnd
local glDrawGroundCircle = gl.DrawGroundCircle
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glPolygonOffset = gl.PolygonOffset
local GetDrawFrame = Spring.GetDrawFrame
local GetCameraPosition = Spring.GetCameraPosition

local floor = math.floor
local max = math.max
local min = math.min
local cos = math.cos
local sin = math.sin
local abs = math.abs
local pi = math.pi
local ceil = math.ceil
local atan2 = math.atan2
local log = math.log
local exp = math.exp
local GetModKeyState = Spring.GetModKeyState
local GetKeyState = Spring.GetKeyState
local KEYSYMS_SPACE = 0x20
local KEYSYMS_R = 0x72

local RING_WIDTH_STEP = 0.05
local RADIUS_STEP = 8
local ROTATION_STEP = 3
local CURVE_STEP = 0.1
local MAX_RADIUS = 2000
local MIN_RADIUS = 8
local MIN_CURVE = 0.1
local MAX_CURVE = 5.0
local DEFAULT_CURVE = 1.0
local INTENSITY_STEP = 0.1
local MIN_INTENSITY = 0.1
local MAX_INTENSITY = 100.0
local DEFAULT_INTENSITY = 1.0
local CIRCLE_SEGMENTS = 64
local FALLOFF_DISPLAY_HEIGHT = 60
local ringInnerRatio = 0.6
local DEFAULT_LENGTH_SCALE = 1.0
local MIN_LENGTH_SCALE = 0.2
local MAX_LENGTH_SCALE = 5.0
local LENGTH_SCALE_STEP = 0.1
local GRID_SNAP_SIZE = 48  -- default; overridden by extraState.gridSnapSize
local PRESETS_DIR = "Terraform Brush/Presets/"
local KEYBINDS_DIR = "Terraform Brush/"
local KEYBINDS_FILE = KEYBINDS_DIR .. "keybinds.lua"

-- ═══════════════════════════════════════════════════════════════════════
-- CONFIGURABLE KEYBINDS
-- Each entry: { key = <keycode>, label = <display label>, desc = <description> }
-- key = integer keycode (SDL scancode), label = what badge shows
-- ═══════════════════════════════════════════════════════════════════════
local DEFAULT_KEYBINDS = {
	-- Terrain modes (no modifier required)
	mode_level    = { key = 108, label = "L",   desc = "Smooth / Level mode (toggles)" },
	mode_noise    = { key = 110, label = "N",   desc = "Noise mode" },
	mode_ramp     = { key = 114, label = "R",   desc = "Ramp mode" },
	mode_restore  = { key = 101, label = "E",   desc = "Restore mode" },
	-- Shapes (no modifier required)
	shape_circle  = { key = 99,  label = "C",   desc = "Circle shape" },
	shape_square  = { key = 115, label = "S",   desc = "Square shape" },
	shape_triangle = { key = 116, label = "T",  desc = "Triangle shape" },
	shape_hexagon = { key = 104, label = "H",   desc = "Hexagon shape" },
	shape_octagon = { key = 111, label = "O",   desc = "Octagon shape" },
	-- Toggles (no modifier required)
	toggle_clay   = { key = 120, label = "X",   desc = "Toggle clay mode" },
	-- Tool modes (handled by RML UI widget)
	tool_grass       = { key = 107, label = "K",   desc = "Grass tool" },
	tool_metal       = { key = 109, label = "M",   desc = "Metal tool" },
	tool_features    = { key = 102, label = "F",   desc = "Features tool" },
	tool_splat       = { key = 112, label = "P",   desc = "Splat tool" },
	tool_decals      = { key = 103, label = "G",   desc = "Decals tool" },
	tool_weather     = { key = 119, label = "W",   desc = "Weather tool" },
	tool_environment = { key = 118, label = "V",   desc = "Environment tool" },
	tool_lights      = { key = 0,   label = "-",   desc = "Lights tool" },
	tool_startpos    = { key = 0,   label = "-",   desc = "Start Positions tool" },
	tool_clone       = { key = 106, label = "J",   desc = "Clone tool" },
	-- Scroll controls: key = primary hold-key, key2 = secondary hold-key (0=none)
	-- Scroll itself is always scroll wheel; these control which modifier(s) activate each.
	scroll_size      = { key = 306, key2 = 0,   label = "LCTRL",     label2 = "",      desc = "Brush size",    scroll = true },
	scroll_rotation      = { key = 308, key2 = 0,   label = "LALT",   label2 = "",      desc = "Rotation",         scroll = true },
	scroll_protractor    = { key = 308, key2 = 97,  label = "LALT",   label2 = "A",     desc = "Protractor spoke",  scroll = true },
	scroll_curve     = { key = 304, key2 = 0,   label = "LSHIFT",    label2 = "",      desc = "Falloff curve", scroll = true },
	scroll_intensity = { key = 32,  key2 = 0,   label = "SPACE",     label2 = "",      desc = "Intensity",     scroll = true },
	scroll_length    = { key = 306, key2 = 308, label = "LCTRL",     label2 = "LALT",  desc = "Length",        scroll = true },
	scroll_ring      = { key = 306, key2 = 114, label = "LCTRL",     label2 = "R",     desc = "Ring width",    scroll = true },
	scroll_cap_max   = { key = 308, key2 = 304, label = "LALT",      label2 = "LSHIFT", desc = "Height cap max", scroll = true },
}

local activeKeybinds = {}  -- runtime copy; initialized from defaults then overwritten by saved

local function deepCopyKeybinds(src)
	local copy = {}
	for k, v in pairs(src) do
		copy[k] = { key = v.key, label = v.label, desc = v.desc,
			key2 = v.key2, label2 = v.label2, scroll = v.scroll }
	end
	return copy
end

local function loadKeybindsFromDisk()
	activeKeybinds = deepCopyKeybinds(DEFAULT_KEYBINDS)
	if VFS.FileExists(KEYBINDS_FILE, VFS.RAW) then
		local raw = VFS.LoadFile(KEYBINDS_FILE, VFS.RAW)
		if raw then
			local fn, err = loadstring(raw)
			if fn then
				local ok, data = pcall(fn)
				if ok and type(data) == "table" then
					for action, entry in pairs(data) do
						if activeKeybinds[action] and type(entry) == "table" and entry.key then
							activeKeybinds[action].key = tonumber(entry.key) or activeKeybinds[action].key
							activeKeybinds[action].label = tostring(entry.label or activeKeybinds[action].label)
							if entry.key2 ~= nil then
								activeKeybinds[action].key2 = tonumber(entry.key2) or activeKeybinds[action].key2
							end
							if entry.label2 ~= nil then
								activeKeybinds[action].label2 = tostring(entry.label2)
							end
						end
					end
				end
			end
		end
	end
end

local function saveKeybindsToDisk()
	Spring.CreateDir(KEYBINDS_DIR)
	local lines = { "return {" }
	local sorted = {}
	for k in pairs(activeKeybinds) do sorted[#sorted + 1] = k end
	table.sort(sorted)
	for _, action in ipairs(sorted) do
		local kb = activeKeybinds[action]
		if kb.scroll then
			lines[#lines + 1] = string.format(
				'\t%s = { key = %d, label = %q, key2 = %d, label2 = %q },',
				action, kb.key, kb.label, kb.key2 or 0, kb.label2 or ""
			)
		else
			lines[#lines + 1] = string.format(
				'\t%s = { key = %d, label = %q },',
				action, kb.key, kb.label
			)
		end
	end
	lines[#lines + 1] = "}"
	local f = io.open(KEYBINDS_FILE, "w")
	if f then
		f:write(table.concat(lines, "\n") .. "\n")
		f:close()
	end
end

local function getKeybindKey(action)
	local kb = activeKeybinds[action]
	return kb and kb.key or 0
end

local function getKeybindLabel(action)
	local kb = activeKeybinds[action]
	return kb and kb.label or "?"
end

-- Built-in brush presets (always available, cannot be deleted)
local BUILTIN_PRESETS = {
	{
		name = "Ditch Digger",
		mode = "lower",
		shape = "square",
		radius = 80,
		rotationDeg = 0,
		curve = 1.8,
		intensity = 2.5,
		lengthScale = 3.5,
		heightCapMin = nil,
		heightCapMax = nil,
		heightCapAbsolute = true,
		clayMode = false,
		noiseType = "perlin",
		noiseScale = 64,
		noiseOctaves = 4,
		noisePersistence = 0.5,
		noiseLacunarity = 2.0,
		noiseSeed = 0,
	},
	{
		name = "Sandworm",
		mode = "noise",
		shape = "circle",
		radius = 180,
		rotationDeg = 0,
		curve = 1.0,
		intensity = 6.0,
		lengthScale = 2.5,
		heightCapMin = nil,
		heightCapMax = nil,
		heightCapAbsolute = true,
		clayMode = false,
		noiseType = "ridged",
		noiseScale = 160,
		noiseOctaves = 3,
		noisePersistence = 0.45,
		noiseLacunarity = 2.2,
		noiseSeed = 0,
	},
	{
		name = "Crater",
		mode = "lower",
		shape = "circle",
		radius = 120,
		rotationDeg = 0,
		curve = 2.8,
		intensity = 4.0,
		lengthScale = 1.0,
		heightCapMin = nil,
		heightCapMax = nil,
		heightCapAbsolute = true,
		clayMode = false,
		noiseType = "perlin",
		noiseScale = 64,
		noiseOctaves = 4,
		noisePersistence = 0.5,
		noiseLacunarity = 2.0,
		noiseSeed = 0,
	},
	{
		name = "Mesa",
		mode = "raise",
		shape = "square",
		radius = 160,
		rotationDeg = 0,
		curve = 0.5,
		intensity = 5.0,
		lengthScale = 1.0,
		heightCapMin = nil,
		heightCapMax = nil,
		heightCapAbsolute = true,
		clayMode = true,
		noiseType = "perlin",
		noiseScale = 64,
		noiseOctaves = 4,
		noisePersistence = 0.5,
		noiseLacunarity = 2.0,
		noiseSeed = 0,
	},
	{
		name = "Ball",
		mode = "raise",
		shape = "circle",
		radius = 250,
		rotationDeg = 0,
		curve = 0.4,
		intensity = 1.5,
		lengthScale = 1.0,
		heightCapMin = nil,
		heightCapMax = nil,
		heightCapAbsolute = true,
		clayMode = false,
		noiseType = "perlin",
		noiseScale = 64,
		noiseOctaves = 4,
		noisePersistence = 0.5,
		noiseLacunarity = 2.0,
		noiseSeed = 0,
	},
	{
		name = "Moat",
		mode = "lower",
		shape = "ring",
		radius = 200,
		rotationDeg = 0,
		curve = 1.5,
		intensity = 3.0,
		lengthScale = 1.0,
		heightCapMin = nil,
		heightCapMax = nil,
		heightCapAbsolute = true,
		clayMode = false,
		noiseType = "perlin",
		noiseScale = 64,
		noiseOctaves = 4,
		noisePersistence = 0.5,
		noiseLacunarity = 2.0,
		noiseSeed = 0,
	},
	{
		name = "Badlands",
		mode = "noise",
		shape = "circle",
		radius = 300,
		rotationDeg = 0,
		curve = 1.0,
		intensity = 8.0,
		lengthScale = 1.0,
		heightCapMin = nil,
		heightCapMax = nil,
		heightCapAbsolute = true,
		clayMode = false,
		noiseType = "voronoi",
		noiseScale = 80,
		noiseOctaves = 3,
		noisePersistence = 0.5,
		noiseLacunarity = 2.0,
		noiseSeed = 0,
	},
	{
		name = "Dunes",
		mode = "noise",
		shape = "circle",
		radius = 250,
		rotationDeg = 0,
		curve = 1.0,
		intensity = 4.0,
		lengthScale = 1.8,
		heightCapMin = nil,
		heightCapMax = nil,
		heightCapAbsolute = true,
		clayMode = false,
		noiseType = "fbm",
		noiseScale = 120,
		noiseOctaves = 5,
		noisePersistence = 0.55,
		noiseLacunarity = 2.0,
		noiseSeed = 0,
	},
}

local builtinPresetNames = {}
for _, p in ipairs(BUILTIN_PRESETS) do
	builtinPresetNames[p.name] = true
end

local activeDirection = nil
local activeRadius = DEFAULT_RADIUS
local activeShape = "circle"
local activeRotation = 0
local activeCurve = DEFAULT_CURVE
local activeIntensity = DEFAULT_INTENSITY
local activeLengthScale = DEFAULT_LENGTH_SCALE
local activeMode = nil
local updateTimer = 0
local heightCapMin = nil
local heightCapMax = nil
local heightCapAbsolute = true
local brushOpacity = 1.0
local gridOverlay = false
local dustEffects = false
local seismicEffects = false
local djMode = false
local extraState = {
	heightColormap = false,
	curveOverlay = false,
	velocityIntensity = false,
	gridSnap = false,
	gridSnapSize = 48,
	lastDragScreenX = nil,
	lastDragScreenY = nil,
	dragVelocityFactor = 1.0,
	restoreStrength = 1.0,
	seismicTimer = 0,
	-- Protractor: snaps brush rotation to an angle grid
	angleSnap = false,
	angleSnapStep = 15,          -- degrees per step (1–90)
	angleSnapAuto = true,        -- true = auto-snap to nearest spoke each frame; false = manual spoke lock
	angleSnapManualSpoke = 0,    -- index 0..numSpokes-1 of the locked spoke in manual mode
	angleSnapScrollAccum = 0,    -- accumulated scroll ticks toward a spoke change
	angleSnapScrollDir   = 0,    -- +1 or -1: direction of accumulation
	snapCommittedSpokeAngle = nil,  -- during a drag stroke: the last committed spoke angle (for hysteresis)
	protractorCursorX = nil,        -- world X of brush center this frame (for DrawScreen labels)
	protractorCursorZ = nil,        -- world Z of brush center this frame
	protractorSpokeLen = 0,         -- spoke tip distance (world units) for label placement
	protractorStep = 15,            -- angle step currently displayed
	protractorHighlight = 0,        -- highlighted spoke angle (degrees)
	-- Measure tool: world-space ruler with chainable polylines
	measureActive = false,
	measureDrawing = false,      -- true = actively placing points (brush UI hidden); false = view mode
	measureLines = {},           -- [{pts={{x,z},...}}] committed chains
	measureDragLine = nil,       -- {chain=i, pt=j} while dragging an endpoint
	measurePressDragCandidate = nil,  -- {chain,pt}: pressed near endpoint, not yet dragging
	measurePressCandidateWorld = nil, -- {x,z}: world pos of the pressed-near endpoint
	measurePressScreenX = nil,
	measurePressScreenY = nil,
	measureActivePt = nil,       -- {x,z} of pending first click
	measureActiveChain = nil,    -- chain index being extended (its last pt = measureActivePt)
	measureCursorX = nil,
	measureCursorZ = nil,
	measureHoverNear = nil,       -- {chain,pt} when cursor is over an existing endpoint in drawing mode
	measureRulerMode = false,     -- when true, terraform brush snaps to measure-line segments
	measureHandleDrag = nil,      -- {chain=c, seg=s} while dragging a spline handle control point
	measureHoverHandle = nil,     -- {chain=c, seg=s} when cursor is near an existing handle
	measureHoverMidSeg = nil,     -- {chain=c, seg=s, wx, wz} when cursor is near a segment body
	measureStickyMode = false,    -- linked-brush mode: recorded strokes follow spline reshaping
	measureDistortMode = false,   -- origin drag re-mirrors lines instead of translating them
	measureShowLength = true,     -- when true, draw elmos/km labels on each segment
	linkedStrokes = {},           -- parametric records of ruler-mode brush strokes
	linkedStrokeGroupCount = 0,  -- how many undo entries the current linkedStrokes span
	gadgetUndoCount = 0,         -- latest undo-stack depth reported by the gadget
	stickyUndoBaseline = nil,     -- gadgetUndoCount when sticky recording began
	squareFaces = {
		{ -1, -1,  1, -1 },
		{  1, -1,  1,  1 },
		{  1,  1, -1,  1 },
		{ -1,  1, -1, -1 },
	},
	gridDL = nil,
	gridDirty = true,
	-- Height sampling mode: pick a terrain height from the colormap to set as a height cap
	heightSamplingMode = nil,   -- nil, "max", or "min" – which cap to populate
	colormapHoverContour = nil, -- height of the topo contour line currently under cursor (or nil)
	colormapHoverPeak = false,  -- true when cursor is near the peak elevation label
	colormapContourStep = nil,  -- contour interval from the last colormap draw
	colormapHMin = nil,         -- minimum height from the last colormap draw
	colormapHMax = nil,         -- maximum height from the last colormap draw
	colormapLastMesh = nil,     -- {gx,gz,gy,ga,gridN} – vertex data from last colormap draw
	-- Unmouse: park brush beside UI panel while mouse hovers over it
	unmouseActive   = false,   -- true while mouse is over the terraform panel
	unmouseAnimT    = 0.0,     -- 0 = following mouse, 1 = fully parked
	unmouseFromX    = 0.0,     -- world X at moment mouse entered panel
	unmouseFromZ    = 0.0,
	unmouseToX      = 0.0,     -- world X of the parked position beside the panel
	unmouseToZ      = 0.0,
	unmouseLastTime = nil,     -- Spring.GetTimer() of last applyUnmouse call
	unmouseLastSpan = 0,       -- activeRadius * activeLengthScale at last target compute
	-- Symmetry tool: mirror/radial replication of brush strokes
	symmetryActive = false,      -- master toggle
	symmetryOriginX = nil,       -- world X of symmetry center (nil = map center)
	symmetryOriginZ = nil,       -- world Z of symmetry center (nil = map center)
	symmetryMirrorX = false,     -- mirror across X axis (reflects Z coords)
	symmetryMirrorY = false,     -- mirror across Y axis (reflects X coords) — "Y" means map-view vertical
	symmetryRadial = false,      -- radial (N-way rotational) mode
	symmetryRadialCount = 2,     -- number of radial copies (2–16)
	symmetryPlacingOrigin = false, -- true when user is click-placing the origin
	symmetryDraggingOrigin = false, -- true while LMB-dragging the origin gizmo
	symmetryHoveringOrigin = false, -- true when mouse is near origin (for cursor)
	symmetryMirrorAngle = 0,     -- rotation angle of the mirror axis in degrees (0=horizontal)
	symmetryFlipped = false,     -- mirrored-flipped mode: mirror + invert heights
	symmetryLastWorldX = nil,    -- last known world position for overlay when mouse is over UI
	symmetryLastWorldZ = nil,
	-- Spline ramp sub-display-list: only rebuilt when point count or radius changes
	splineCacheList   = nil,
	splineCacheCount  = -1,
	splineCacheRadius = -1,
	-- Throttle gadget SPLINE_RAMP sends during active stroke (apply on release for final)
	splineRampLastSendCount = 0,
	-- Progressive commitment: stores smoothed positions of settled early path segments
	-- so their display and terrain stop changing as the stroke extends further away.
	splineCommitted = nil,  -- nil between strokes; {pts={{x,z},...}, rawIdx=N} during stroke
	-- D5: cursor-anchored parameter feedback HUD
	paramHudText  = nil,   -- formatted label string, or nil when hidden
	paramHudTimer = 0.0,   -- seconds remaining (1.5 on trigger; fades in last 0.35s)
	-- G4: automatically attach a measure chain when a ramp stroke completes
	rampAutoAttach = true,
	-- G4: gadgetUndoCount captured at the start of the current ramp stroke (before any commits)
	rampStrokeUndoBaseline = nil,
	-- G4: queued undo+sync+reapply operation when a ramp chain endpoint/handle is moved
	rampReapplyQueue = nil,
	-- Wiggle: sinusoidal brush offset applied while stroking
	wiggleEnabled = false,
	wiggleAmpIdx  = 1,
	wiggleSpdIdx  = 1,
	wigglePhase   = 0,
	-- Dwell-merge: true when the last tick did NOT close its undo entry (brush stationary).
	-- The open gadget mergeSnapshot accumulates until movement or the next finalizeMerge.
	mergeLeftOpen = false,
	-- Pen pressure: tablet pressure modulates brush intensity when enabled
	penPressureEnabled = false,
	penPressure = 1.0,       -- current pressure value (0.0–1.0), 1.0 = no modulation
	penTiltX = 0,            -- pen tilt in X (-90..90 degrees)
	penTiltY = 0,            -- pen tilt in Y (-90..90 degrees)
	penInContact = false,    -- true when pen tip is touching the tablet
	penOverUI = false,       -- true when pen/cursor is over the UI panel (suppress brush modulation)
	penPressureFile = nil,   -- resolved at runtime via WRITEDIR
	penPressureReadTimer = 0,
	penPressureReadInterval = 0.016,  -- ~60Hz file poll rate
	penPressureModulateIntensity = true,  -- pressure affects intensity
	penPressureModulateSize = false,      -- pressure affects brush size
	penPressureModulateRadius = false, -- legacy: also scales brush radius (via sendTerraformMessage)
	penPressureRadiusScale = 0.5,     -- how much pressure affects radius (0=none, 1=full)
	penPressureSensitivity = 1.0,     -- multiplier applied before curve (0.1–3.0)
	penPressureCurve = 2,             -- 1=linear, 2=quadratic, 3=cubic, 4=s-curve, 5=log
}

-- Pen pressure: read tablet pressure from shared file written by tools/pen_pressure_server.py
extraState.readPenPressure = function(dt)
	if not extraState.penPressureEnabled then return end
	-- Lazy-resolve absolute path on first call
	if not extraState.penPressureFile then
		local wd = (Spring.GetWriteDir and Spring.GetWriteDir()) or ""
		extraState.penPressureFile = wd .. "cache/pen_pressure.txt"
		Spring.Echo("[TF Pen] resolved file path: " .. extraState.penPressureFile)
	end
	extraState.penPressureReadTimer = extraState.penPressureReadTimer + dt
	if extraState.penPressureReadTimer < extraState.penPressureReadInterval then return end
	extraState.penPressureReadTimer = 0
	local f = io.open(extraState.penPressureFile, "r")
	if not f then
		-- Try once per second to avoid log spam
		extraState._penDiagTimer = (extraState._penDiagTimer or 0) + extraState.penPressureReadInterval
		if extraState._penDiagTimer >= 1.0 then
			extraState._penDiagTimer = 0
			Spring.Echo("[TF Pen] WARN: cannot open " .. tostring(extraState.penPressureFile))
		end
		return
	end
	local raw = f:read("*a")
	f:close()
	if not raw or #raw == 0 then
		extraState._penDiagTimer = (extraState._penDiagTimer or 0) + extraState.penPressureReadInterval
		if extraState._penDiagTimer >= 1.0 then
			extraState._penDiagTimer = 0
			Spring.Echo("[TF Pen] WARN: file empty")
		end
		return
	end
	-- Format: "pressure tiltX tiltY inContact" e.g. "0.7500 15 -3 1"
	local p, tx, ty, ic = raw:match("([%d%.]+)%s+([%-?%d]+)%s+([%-?%d]+)%s+(%d)")
	if p then
		extraState.penPressure = max(0.0, min(1.0, tonumber(p) or 1.0))
		extraState.penTiltX = tonumber(tx) or 0
		extraState.penTiltY = tonumber(ty) or 0
		extraState.penInContact = (ic == "1")
	else
		-- Simple format: just a float
		local val = tonumber(raw)
		if val then
			extraState.penPressure = max(0.0, min(1.0, val))
		else
			Spring.Echo("[TF Pen] WARN: unparseable content: [" .. raw:sub(1, 60) .. "]")
			return
		end
	end
	-- Apply sensitivity + curve mapping → penPressureMapped
	local raw_p = extraState.penPressure
	local sens = extraState.penPressureSensitivity or 1.0
	local p_s = min(1.0, raw_p * sens)
	local curve = extraState.penPressureCurve or 2
	local mapped
	if curve == 1 then      mapped = p_s                                     -- linear
	elseif curve == 2 then  mapped = p_s * p_s                               -- quadratic (soft start)
	elseif curve == 3 then  mapped = p_s * p_s * p_s                         -- cubic (very soft)
	elseif curve == 4 then  mapped = p_s * p_s * (3 - 2 * p_s)              -- S-curve (smoothstep)
	elseif curve == 5 then  mapped = math.log(1 + p_s * 9) / math.log(10)   -- logarithmic (fast start)
	else                    mapped = p_s * p_s
	end
	extraState.penPressureMapped = max(0.0, min(1.0, mapped))
	-- Periodic diagnostics (~every 2 seconds)
	extraState._penDiagTimer = (extraState._penDiagTimer or 0) + extraState.penPressureReadInterval
	if extraState._penDiagTimer >= 2.0 then
		extraState._penDiagTimer = 0
		Spring.Echo(string.format("[TF Pen] OK pressure=%.3f tilt=%d,%d contact=%s",
			extraState.penPressure, extraState.penTiltX, extraState.penTiltY,
			tostring(extraState.penInContact)))
	end
end

-- G8: per-mode cursor names — swap "cursornormal" for a custom cursor name when artwork is ready
extraState.modeCursors = {
	raise   = "cursornormal",
	lower   = "cursornormal",
	level   = "cursornormal",
	ramp    = "cursornormal",
	restore = "cursornormal",
	noise   = "cursornormal",
}

-- D5: trigger cursor-anchored parameter feedback HUD (1.5s fade)
extraState.setParamHud = function(text)
	extraState.paramHudText  = text
	extraState.paramHudTimer = 1.5
end

-- Symmetry: get effective origin (fallback to map center)
extraState.getSymmetryOrigin = function()
	local ox = extraState.symmetryOriginX or (Game.mapSizeX * 0.5)
	local oz = extraState.symmetryOriginZ or (Game.mapSizeZ * 0.5)
	return ox, oz
end

-- Symmetry: compute all symmetric copies of a point + rotation.
-- Returns array of {x, z, rot} including the original.
extraState.getSymmetricPositions = function(wx, wz, rot)
	if not extraState.symmetryActive then
		return {{ x = wx, z = wz, rot = rot }}
	end
	local ox, oz = extraState.getSymmetryOrigin()
	local dx, dz = wx - ox, wz - oz
	local positions = {{ x = wx, z = wz, rot = rot }}

	if extraState.symmetryRadial then
		local count = extraState.symmetryRadialCount
		local step = (2 * pi) / count
		for k = 1, count - 1 do
			local angle = k * step
			local cosA = cos(angle)
			local sinA = sin(angle)
			local rx = ox + dx * cosA - dz * sinA
			local rz = oz + dx * sinA + dz * cosA
			local rrot = (rot + angle * 180 / pi) % 360
			positions[#positions + 1] = { x = rx, z = rz, rot = rrot }
		end
	else
		-- Rotate offset into mirror-axis-aligned space, reflect, rotate back.
		-- mirrorAngle rotates the entire axis system so X/Y mirrors are relative to it.
		local ang = (extraState.symmetryMirrorAngle or 0) * pi / 180
		local cosA = cos(ang)
		local sinA = sin(ang)
		-- Transform into axis-aligned space
		local adx = dx * cosA + dz * sinA
		local adz = -dx * sinA + dz * cosA
		local mirrorX = extraState.symmetryMirrorX
		local mirrorY = extraState.symmetryMirrorY
		if mirrorX then
			-- Reflect across rotated X axis (negate aligned-Z, transform back)
			local rx = ox + (adx * cosA - (-adz) * sinA)
			local rz = oz + (adx * sinA + (-adz) * cosA)
			positions[#positions + 1] = { x = rx, z = rz, rot = (2 * (extraState.symmetryMirrorAngle or 0) - rot) % 360 }
		end
		if mirrorY then
			-- Reflect across rotated Y axis (negate aligned-X, transform back)
			local rx = ox + ((-adx) * cosA - adz * sinA)
			local rz = oz + ((-adx) * sinA + adz * cosA)
			positions[#positions + 1] = { x = rx, z = rz, rot = (180 + 2 * (extraState.symmetryMirrorAngle or 0) - rot) % 360 }
		end
		if mirrorX and mirrorY then
			-- Both: point symmetry through origin
			positions[#positions + 1] = { x = ox - dx, z = oz - dz, rot = (rot + 180) % 360 }
		end
	end
	return positions
end

-- Build and cache a full-map grid display list (terrain-following lines at grid-snap intervals).
-- Vertices are placed at every grid intersection; line strips connect them along rows and columns.
extraState.buildFullMapGrid = function()
	if extraState.gridDL then
		glDeleteList(extraState.gridDL)
		extraState.gridDL = nil
	end
	local gs  = extraState.gridSnapSize
	local msx = Game.mapSizeX
	local msz = Game.mapSizeZ
	local BUMP = 3
	extraState.gridDL = glCreateList(function()
		glLineWidth(1)
		glColor(1, 1, 0.6, 0.20)
		glPolygonOffset(-2, -2)
		-- Horizontal lines: walk Z rows, strip along X
		local z = 0
		while z <= msz do
			glBeginEnd(GL.LINE_STRIP, function()
				local x = 0
				while x <= msx do
					glVertex(x, GetGroundHeight(x, z) + BUMP, z)
					x = x + gs
				end
				if msx % gs ~= 0 then
					glVertex(msx, GetGroundHeight(msx, z) + BUMP, z)
				end
			end)
			z = z + gs
		end
		-- Vertical lines: walk X columns, strip along Z
		local x = 0
		while x <= msx do
			glBeginEnd(GL.LINE_STRIP, function()
				local zz = 0
				while zz <= msz do
					glVertex(x, GetGroundHeight(x, zz) + BUMP, zz)
					zz = zz + gs
				end
				if msz % gs ~= 0 then
					glVertex(x, GetGroundHeight(x, msz) + BUMP, msz)
				end
			end)
			x = x + gs
		end
		glPolygonOffset(0, 0)
		glColor(1, 1, 1, 1)
		glLineWidth(1)
	end)
	extraState.gridDirty = false
end

local lockedWorldX = nil
local lockedWorldZ = nil
local lockedGroundY = nil
local lastScreenX = nil
local lastScreenY = nil
local rampEndX = nil
local rampEndZ = nil
local rampSplinePoints = {}
local SPLINE_SAMPLE_DIST = 24
local SPLINE_MAX_POINTS = 40
local SPLINE_SEND_WINDOW = 14  -- raw points per intermediate gadget apply (caps bbox near cursor)
local dragOriginX = nil
local dragOriginZ = nil
local shiftState = { axis = nil, originX = nil, originZ = nil, wasHeld = false }
local gridShowing = false
local rightMouseHeld = false
local savedModeBeforeRMB = nil
local savedDirectionBeforeRMB = nil
local clayMode = false
local stampApplied = false -- stamp mode: true after first apply at current position

-- Noise brush state
local activeNoiseType = "perlin"  -- perlin, ridged, voronoi, fbm, billow
local noiseScale = 64
local noiseOctaves = 4
local noisePersistence = 0.5
local noiseLacunarity = 2.0
local noiseSeed = 0

-- History slider state
local historyUndoCount = 0
local historyRedoCount = 0

-- Tessellation refresh: force mesh re-tessellation for N frames after heightmap edits
local TESS_DIRTY_FRAMES = 10
local tessellationDirtyFrames = 0

local function markTessellationDirty()
	tessellationDirtyFrames = TESS_DIRTY_FRAMES
end

-- Per-tick MERGE_END: each tick creates one undo entry within the current stroke.
-- The gadget tags all entries with the same stroke ID until closeBrushStroke().
-- UNDO_STROKE pops all entries for the latest stroke atomically.

local function afterBrushTick()
	markTessellationDirty()
	SendLuaRulesMsg(MSG.MERGE_END)
end

-- Close the stroke: sends MERGE_END to flush partial entry, then STROKE_END
-- to advance the stroke ID in the gadget. Called on mouse release.
local function closeBrushStroke()
	SendLuaRulesMsg(MSG.STROKE_END)
end

local function getWorldMousePosition()
	local mx, my = GetMouseState()
	local _, pos = TraceScreenRay(mx, my, true)

	if pos then
		return pos[1], pos[3]
	end

	return nil, nil
end

-- Project the mouse ray onto a fixed horizontal plane at planeY.
-- Returns worldX, worldZ on that plane, or falls back to terrain trace.
local function getWorldMousePositionOnPlane(planeY)
	local mx, my = GetMouseState()
	local _, pos = TraceScreenRay(mx, my, true)
	if not pos then return nil, nil end

	local camX, camY, camZ = GetCameraPosition()
	local hitX, hitY, hitZ = pos[1], pos[2], pos[3]
	local dx, dy, dz = hitX - camX, hitY - camY, hitZ - camZ
	if math.abs(dy) < 0.001 then
		return hitX, hitZ  -- nearly horizontal ray, can't intersect plane
	end
	local t = (planeY - camY) / dy
	return camX + dx * t, camZ + dz * t
end

local AXIS_LOCK_THRESHOLD = 25  -- screen pixels

-- Find any land unit def for force-showing the build grid
local gridForceShowDefID
for id, def in pairs(UnitDefs) do
	if not def.modCategories or not def.modCategories.underwater then
		gridForceShowDefID = id
		break
	end
end

local function showBuildGrid()
	if gridShowing then return end
	local bg = WG['buildinggrid']
	if bg and bg.setForceShow and gridForceShowDefID then
		bg.setForceShow("terraform", true, gridForceShowDefID)
		gridShowing = true
	end
end

local function hideBuildGrid()
	if not gridShowing then return end
	local bg = WG['buildinggrid']
	if bg and bg.setForceShow then
		bg.setForceShow("terraform", false)
		gridShowing = false
	end
end

local function snapToGrid(x, z, angleDeg)
	local gs = extraState.gridSnapSize
	if not angleDeg or angleDeg == 0 then
		return floor(x / gs + 0.5) * gs,
		       floor(z / gs + 0.5) * gs
	end
	-- Rotate into aligned grid space, snap, rotate back so grid follows protractor axis
	local rad = angleDeg * pi / 180
	local cr = cos(rad)
	local sr = sin(rad)
	local lx = floor(( x * cr + z * sr) / gs + 0.5) * gs
	local lz = floor((-x * sr + z * cr) / gs + 0.5) * gs
	return lx * cr - lz * sr,
	       lx * sr + lz * cr
end
extraState.snapToGrid = snapToGrid

local function constrainToAxis(originX, originZ, rawX, rawZ)
	-- Convert world-space displacement to screen-space pixels for zoom-independent threshold
	local originY = GetGroundHeight(originX, originZ)
	local sx0, sy0 = Spring.WorldToScreenCoords(originX, originY, originZ)
	local sx1, sy1 = Spring.WorldToScreenCoords(rawX, originY, rawZ)
	local screenDx = abs(sx1 - sx0)
	local screenDz = abs(sy1 - sy0)

	if not shiftState.axis then
		-- Initial axis determination using screen-space threshold
		if screenDx > AXIS_LOCK_THRESHOLD or screenDz > AXIS_LOCK_THRESHOLD then
			if screenDx >= screenDz then
				shiftState.axis = "x"
			else
				shiftState.axis = "z"
			end
		else
			return originX, originZ
		end
	else
		-- E2: Allow mid-drag axis switch when dominant direction clearly flips
		-- Require 2× threshold in the new axis AND new axis must be 2× the current axis
		local SWITCH_FACTOR = 2
		if shiftState.axis == "x" and screenDz > AXIS_LOCK_THRESHOLD * SWITCH_FACTOR and screenDz > screenDx * SWITCH_FACTOR then
			shiftState.axis = "z"
		elseif shiftState.axis == "z" and screenDx > AXIS_LOCK_THRESHOLD * SWITCH_FACTOR and screenDx > screenDz * SWITCH_FACTOR then
			shiftState.axis = "x"
		end
	end

	if shiftState.axis == "x" then
		return rawX, originZ
	else
		return originX, rawZ
	end
end

-- Stamp mode: intensity maxed + at least one height cap â†’ instant apply
local function isStampMode()
	return activeIntensity >= MAX_INTENSITY and (heightCapMin ~= nil or heightCapMax ~= nil)
end

local function sendTerraformMessage(direction, worldX, worldZ, radius, shape, rotation, curve, flattenHeight)
	-- Pen pressure: modulate radius by tablet pressure
	if extraState.penPressureEnabled and not extraState.penOverUI then
		local pm = extraState.penPressureMapped or extraState.penPressure or 0
		local sens = extraState.penPressureSensitivity or 1.0
		if extraState.penPressureModulateSize then
			local pScale = 1.0 + pm * sens
			radius = max(8, floor(radius * pScale + 0.5))
		elseif extraState.penPressureModulateRadius then
			local pScale = 1.0 + pm * sens
			radius = max(8, floor(radius * pScale + 0.5))
		end
	end
	-- Wiggle: sinusoidal offset applied each stroke tick while painting
	if extraState.wiggleEnabled then
		extraState.wigglePhase = extraState.wigglePhase + extraState.wiggleSpdIdx * 3.0 * UPDATE_INTERVAL
		local wamp = extraState.wiggleAmpIdx * 0.2 * radius
		worldX = worldX + math.sin(extraState.wigglePhase) * wamp
		worldZ = worldZ + math.sin(extraState.wigglePhase * 1.3 + 2.1) * wamp * 0.7
	end
	local absCapMin, absCapMax
	if heightCapAbsolute then
		absCapMin = heightCapMin and string.format("%.0f", heightCapMin) or "nil"
		absCapMax = heightCapMax and string.format("%.0f", heightCapMax) or "nil"
	else
		absCapMin = (heightCapMin and lockedGroundY) and string.format("%.0f", lockedGroundY + heightCapMin) or "nil"
		absCapMax = (heightCapMax and lockedGroundY) and string.format("%.0f", lockedGroundY + heightCapMax) or "nil"
	end
	local instant = isStampMode() and "1" or "0"
	local flattenStr = flattenHeight and string.format("%.0f", flattenHeight) or "nil"
	local penPressureFactor = 1
	if extraState.penPressureEnabled and extraState.penPressureModulateIntensity and not extraState.penOverUI then
		local pm = extraState.penPressureMapped or extraState.penPressure or 0
		local sens = extraState.penPressureSensitivity or 1.0
		penPressureFactor = 1.0 + pm * sens  -- base value is minimum, pressure adds up to sens× more
	end
	local effectiveIntensity = activeIntensity * (extraState.velocityIntensity and extraState.dragVelocityFactor or 1) * (extraState.interpIntensityScale or 1) * penPressureFactor
	local positions = extraState.getSymmetricPositions(worldX, worldZ, rotation)
	local isFlipped = extraState.symmetryFlipped
	-- Sticky mode recording: snapshot this stroke parametrically (primary position only)
	if extraState.measureRulerMode and extraState.measureStickyMode then
		extraState.recordLinkedStroke(
			worldX, worldZ, direction, radius, shape, rotation, curve,
			flattenStr, absCapMin, absCapMax,
			string.format("%.1f", effectiveIntensity),
			string.format("%.1f", activeLengthScale),
			(clayMode and "1" or "0"),
			(djMode and dustEffects and "1" or "0"),
			string.format("%.2f", brushOpacity),
			instant,
			string.format("%.2f", ringInnerRatio))
		-- Set baseline on first sticky stroke so we can compute undo count from gadget feedback
		if not extraState.stickyUndoBaseline then
			extraState.stickyUndoBaseline = extraState.gadgetUndoCount or 0
		end
		-- All symmetric copies sent first, then ONE afterBrushTick() so they all land
		-- in the same undo entry.  Each Update tick = one undo entry; hold Ctrl+Z to undo continuously.
		for i = 1, #positions do
			local p = positions[i]
			local dir = direction
			if isFlipped and i > 1 then dir = -direction end
			local msg = MSG.BRUSH
				.. dir .. " "
				.. floor(p.x) .. " "
				.. floor(p.z) .. " "
				.. radius .. " "
				.. shape .. " "
				.. p.rot .. " "
				.. string.format("%.1f", curve) .. " "
				.. absCapMin .. " "
				.. absCapMax .. " "
				.. string.format("%.1f", effectiveIntensity) .. " "
				.. string.format("%.1f", activeLengthScale) .. " "
				.. (clayMode and "1" or "0") .. " "
				.. (djMode and dustEffects and "1" or "0") .. " "
				.. string.format("%.2f", brushOpacity) .. " "
				.. instant .. " "
				.. flattenStr .. " "
				.. string.format("%.2f", ringInnerRatio)
			SendLuaRulesMsg(msg)
		end
		afterBrushTick()
		return
	end
	for i = 1, #positions do
		local p = positions[i]
		-- Flipped mode: invert direction for mirrored copies (raise becomes lower)
		local dir = direction
		if isFlipped and i > 1 then
			dir = -direction
		end
		local msg = MSG.BRUSH
			.. dir .. " "
			.. floor(p.x) .. " "
			.. floor(p.z) .. " "
			.. radius .. " "
			.. shape .. " "
			.. p.rot .. " "
			.. string.format("%.1f", curve) .. " "
			.. absCapMin .. " "
			.. absCapMax .. " "
			.. string.format("%.1f", effectiveIntensity) .. " "
			.. string.format("%.1f", activeLengthScale) .. " "
			.. (clayMode and "1" or "0") .. " "
			.. (djMode and dustEffects and "1" or "0") .. " "
			.. string.format("%.2f", brushOpacity) .. " "
			.. instant .. " "
			.. flattenStr .. " "
			.. string.format("%.2f", ringInnerRatio)
		SendLuaRulesMsg(msg)
	end
	-- Caller calls afterBrushTick() ONCE after the full interpolated loop so all
	-- steps + symmetric copies land in the same per-tick undo entry.
end

local function parseRadius(args)
	if args and args[1] then
		local radius = tonumber(args[1])
		if radius and radius > 0 then
			return floor(radius)
		end
	end

	return DEFAULT_RADIUS
end

local function activate(direction, mode, args)
	activeDirection = direction
	activeMode = mode
	activeRadius = parseRadius(args)
	if mode == "level" or mode == "smooth" then
		activeCurve = 2.5
		clayMode = true
		activeIntensity = 0.5
	end
	local modeLabels = { raise = "RAISE", lower = "LOWER", level = "LEVEL", smooth = "SMOOTH", ramp = "RAMP", restore = "RESTORE" }
	local modeLabel = modeLabels[mode] or mode
	Echo("[Terraform Brush] Mode: " .. modeLabel .. " | Radius: " .. activeRadius .. " | Hold left-click to terraform, /terraformbrushoff to stop")
	return true
end

local function activateTerraformUp(_, _, args)
	return activate(1, "raise", args)
end

local function activateTerraformDown(_, _, args)
	return activate(-1, "lower", args)
end

local function activateTerraformLevel(_, _, args)
	return activate(0, "level", args)
end

local function activateTerraformRamp(_, _, args)
	-- Default to straight ramp unless spline was explicitly chosen last time
	if activeShape ~= "circle" then activeShape = "square" end
	return activate(0, "ramp", args)
end

local function activateTerraformRestore(_, _, args)
	return activate(0, "restore", args)
end

-- Forward declaration
local invalidateDrawCache

local function deactivateTerraform()
	if activeMode then
		Echo("[Terraform Brush] Deactivated")
		Spring.SetMouseCursor("cursornormal")  -- G8: restore default cursor on exit
	end

	invalidateDrawCache()
	activeDirection = nil
	activeMode = nil
	extraState.heightSamplingMode = nil  -- cancel pending height sampling
	return true
end

local function setMode(mode)
	if mode == "raise" then
		activeDirection = 1
		activeMode = "raise"
	elseif mode == "lower" then
		activeDirection = -1
		activeMode = "lower"
	elseif mode == "level" or mode == "smooth" then
		activeDirection = 0
		activeMode = mode
		activeCurve = 2.5
		clayMode = true
		activeIntensity = 0.5
		if activeShape == "ring" then
			activeShape = "circle"
		end
	elseif mode == "ramp" then
		activeDirection = 0
		activeMode = "ramp"
		if activeShape ~= "circle" and activeShape ~= "square" then
			activeShape = "square"
		end
	elseif mode == "restore" then
		activeDirection = 0
		activeMode = "restore"
	elseif mode == "noise" then
		activeDirection = 1
		activeMode = "noise"
	end
end

local function setShape(shape)
	if shape == "circle" or shape == "square" or shape == "ring" or shape == "hexagon" or shape == "octagon" or shape == "triangle" or shape == "fill" then
		if activeMode == "ramp" and shape ~= "circle" and shape ~= "square" then
			return
		end
		if (activeMode == "level" or activeMode == "smooth") and shape == "ring" then
			return
		end
		activeShape = shape
	end
end

local function rotateBy(degrees)
	activeRotation = (activeRotation + degrees) % 360
	if extraState.angleSnap and extraState.angleSnapStep > 0 then
		local s = extraState.angleSnapStep
		activeRotation = (floor(activeRotation / s + 0.5) * s) % 360
	end
end

-- Constrain a world position onto a protractor spoke from the drag origin.
-- Manual mode: always uses the pinned spoke, no detection, no hysteresis — 100% locked.
-- Auto mode: nearest-spoke with hysteresis (>65% step to switch).
-- Dot-product projection eliminates all perpendicular / terrain-jitter drift.
local function snapDragToSpoke(wx, wz)
	if not dragOriginX then return wx, wz end
	local dx = wx - dragOriginX
	local dz = wz - dragOriginZ
	if dx*dx + dz*dz < 1 then return wx, wz end
	local step = extraState.angleSnapStep
	local snappedDeg
	if not extraState.angleSnapAuto then
		-- Manual mode: unconditionally use the pinned spoke index
		local numSpokes = floor(360 / step)
		snappedDeg = (extraState.angleSnapManualSpoke % numSpokes) * step
	else
		-- Auto mode: nearest spoke with hysteresis.
		-- Shift held  = fully lock to committed spoke, no switching (hold to pin axis mid-stroke).
		-- Dead zone   = freeze when cursor is within 32wu of current dragOrigin (jitter guard).
		-- Bidir fold  = treat committed as a 2-way axis so the "back" direction (≈180°) never
		--               triggers a switch on its own.
		-- Re-origin   = on a genuine spoke switch, move dragOriginX/Z to the projection of the
		--               cursor onto the current spoke (the bend point), then recompute dx/dz so
		--               the new segment projects from there.  This eliminates the sweep-through-
		--               all-angles distortion that occurs when the old origin is reused.
		local _, _, _, shiftHeld = GetModKeyState()
		local angleDeg = atan2(dz, dx) * 180 / pi
		if angleDeg < 0 then angleDeg = angleDeg + 360 end
		local committed = extraState.snapCommittedSpokeAngle
		if not committed then
			-- First movement: commit to nearest spoke
			snappedDeg = (floor(angleDeg / step + 0.5) * step) % 360
			extraState.snapCommittedSpokeAngle = snappedDeg
		elseif shiftHeld or (dx*dx + dz*dz) < (32 * 32) then
			-- Shift lock or near current origin: freeze to committed
			snappedDeg = committed
		else
			-- Hysteresis: bidirectional axis fold
			local diff = ((angleDeg - committed + 540) % 360) - 180
			if diff > 90 then diff = diff - 180 elseif diff < -90 then diff = diff + 180 end
			if abs(diff) < step * 0.65 then
				snappedDeg = committed
			else
				-- Spoke switch: re-origin — move dragOriginX/Z to the projection of the cursor
				-- onto the current spoke (the bend point), recompute dx/dz from there.
				local oldRad  = committed * pi / 180
				local oldSpkX = cos(oldRad)
				local oldSpkZ = sin(oldRad)
				local projD   = dx * oldSpkX + dz * oldSpkZ
				dragOriginX = dragOriginX + oldSpkX * projD
				dragOriginZ = dragOriginZ + oldSpkZ * projD
				-- Refresh dx/dz: now equals the perpendicular component (cursor offset from bend)
				dx = wx - dragOriginX
				dz = wz - dragOriginZ
				if dx*dx + dz*dz >= 4 then
					local newAngle = atan2(dz, dx) * 180 / pi
					if newAngle < 0 then newAngle = newAngle + 360 end
					snappedDeg = (floor(newAngle / step + 0.5) * step) % 360
				else
					snappedDeg = committed  -- perpendicular too small, keep
				end
				extraState.snapCommittedSpokeAngle = snappedDeg
			end
		end
	end
	-- Update activeRotation so the DrawWorld protractor highlights the correct spoke
	activeRotation = snappedDeg
	-- Project cursor onto the spoke using dot product — eliminates all lateral drift
	local snappedRad = snappedDeg * pi / 180
	local spokeX = cos(snappedRad)
	local spokeZ = sin(snappedRad)
	local projDist = dx * spokeX + dz * spokeZ   -- signed distance along spoke
	return dragOriginX + spokeX * projDist, dragOriginZ + spokeZ * projDist
end

local function setRotation(degrees)
	activeRotation = degrees % 360
	if extraState.angleSnap and extraState.angleSnapStep > 0 then
		local s = extraState.angleSnapStep
		activeRotation = (floor(activeRotation / s + 0.5) * s) % 360
	end
end

local function setCurve(value)
	activeCurve = max(MIN_CURVE, min(MAX_CURVE, value))
end

local function setIntensity(value)
	activeIntensity = max(MIN_INTENSITY, min(MAX_INTENSITY, value))
end

local function setLengthScale(value)
	activeLengthScale = max(MIN_LENGTH_SCALE, min(MAX_LENGTH_SCALE, value))
end

local function setRadius(value)
	activeRadius = max(MIN_RADIUS, min(MAX_RADIUS, floor(value)))
end

local function setHeightCapMin(value)
	heightCapMin = value
end

local function setHeightCapMax(value)
	heightCapMax = value
end

local function setHeightCapAbsolute(value)
	heightCapAbsolute = value
end

local function setClayMode(value)
	clayMode = value and true or false
end

local function setBrushOpacity(value)
	brushOpacity = math.max(0.01, math.min(1.0, tonumber(value) or 1.0))
end

local function setGridOverlay(value)
	gridOverlay = value and true or false
	if gridOverlay then extraState.gridDirty = true end
end

local function setDustEffects(value)
	dustEffects = value and true or false
end

local function setSeismicEffects(value)
	seismicEffects = value and true or false
end

local function setDjMode(value)
	djMode = value and true or false
end

local function setHeightColormap(value)
	extraState.heightColormap = value and true or false
end

local function setCurveOverlay(value)
	extraState.curveOverlay = value and true or false
end

local function setRingInnerRatio(value)
	ringInnerRatio = math.max(0.05, math.min(0.95, value or 0.6))
end



local function setNoiseType(ntype)
	if ntype == "perlin" or ntype == "ridged" or ntype == "voronoi" or ntype == "fbm" or ntype == "billow" then
		activeNoiseType = ntype
	end
end

local function setNoiseScale(value)
	noiseScale = max(8, min(512, floor(value)))
end

local function setNoiseOctaves(value)
	noiseOctaves = max(1, min(8, floor(value)))
end

local function setNoisePersistence(value)
	noisePersistence = max(0.1, min(0.9, value))
end

local function setNoiseLacunarity(value)
	noiseLacunarity = max(1.0, min(4.0, value))
end

local function setNoiseSeed(value)
	noiseSeed = max(0, min(9999, floor(value)))
end

local function sendNoiseMessage(worldX, worldZ, radius, shape, rotation, lengthScale)
	local positions = extraState.getSymmetricPositions(worldX, worldZ, rotation)
	for i = 1, #positions do
		local p = positions[i]
		local msg = MSG.NOISE
			.. floor(p.x) .. " "
			.. floor(p.z) .. " "
			.. radius .. " "
			.. shape .. " "
			.. p.rot .. " "
			.. string.format("%.1f", activeCurve) .. " "
			.. string.format("%.1f", activeIntensity) .. " "
			.. string.format("%.1f", lengthScale) .. " "
			.. activeNoiseType .. " "
			.. noiseScale .. " "
			.. noiseOctaves .. " "
			.. string.format("%.2f", noisePersistence) .. " "
			.. string.format("%.1f", noiseLacunarity) .. " "
			.. noiseSeed .. " "
			.. (djMode and dustEffects and "1" or "0")
		SendLuaRulesMsg(msg)
	end
	afterBrushTick()
end

-- Preset save/load system
local presets = {}
local presetsLoaded = false

local function sanitizePresetName(name)
	return name:gsub("[^%w%s%-_]", ""):match("^%s*(.-)%s*$"):sub(1, 64)
end

local function loadPresetsFromDisk()
	if presetsLoaded then return end
	presetsLoaded = true
	-- Load built-in presets first
	for _, p in ipairs(BUILTIN_PRESETS) do
		presets[p.name] = p
	end
	-- User-saved presets override built-ins with same name
	local files = VFS.DirList(PRESETS_DIR, "*.lua", VFS.RAW)
	if not files then return end
	for _, path in ipairs(files) do
		local ok, data = pcall(function()
			local chunk = loadfile(path)
			if chunk then return chunk() end
		end)
		if ok and type(data) == "table" and data.name then
			presets[data.name] = data
		end
	end
end

local function isBuiltinPreset(name)
	return builtinPresetNames[name] == true
end

local function getPresetNames()
	loadPresetsFromDisk()
	local names = {}
	for name, _ in pairs(presets) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

local function savePreset(name)
	if not name or name == "" then return end
	name = sanitizePresetName(name)
	if name == "" then return end
	loadPresetsFromDisk()
	local data = {
		name = name,
		mode = activeMode,
		shape = activeShape,
		radius = activeRadius,
		rotationDeg = activeRotation,
		curve = activeCurve,
		intensity = activeIntensity,
		lengthScale = activeLengthScale,
		heightCapMin = heightCapMin,
		heightCapMax = heightCapMax,
		heightCapAbsolute = heightCapAbsolute,
		clayMode = clayMode,
		noiseType = activeNoiseType,
		noiseScale = noiseScale,
		noiseOctaves = noiseOctaves,
		noisePersistence = noisePersistence,
		noiseLacunarity = noiseLacunarity,
		noiseSeed = noiseSeed,
		ringInnerRatio = ringInnerRatio,
		gridOverlay = gridOverlay,
		gridSnap = extraState.gridSnap,
		gridSnapSize = extraState.gridSnapSize,
		curveOverlay = extraState.curveOverlay,
		velocityIntensity = extraState.velocityIntensity,
		restoreStrength = extraState.restoreStrength,
		dustEffects = dustEffects,
		seismicEffects = seismicEffects,
		djMode = djMode,
		savedAt = os.time(),
	}
	presets[name] = data
	Spring.CreateDir(PRESETS_DIR)
	local filename = PRESETS_DIR .. name:gsub("%s+", "_") .. ".lua"
	local file = io.open(filename, "w")
	if not file then
		Echo("[Terraform Brush] Failed to save preset: " .. name)
		return
	end
	file:write("return {\n")
	file:write(string.format("\tname = %q,\n", data.name))
	if data.mode then file:write(string.format("\tmode = %q,\n", data.mode)) end
	file:write(string.format("\tshape = %q,\n", data.shape))
	file:write(string.format("\tradius = %s,\n", tostring(data.radius)))
	file:write(string.format("\trotationDeg = %s,\n", tostring(data.rotationDeg)))
	file:write(string.format("\tcurve = %s,\n", tostring(data.curve)))
	file:write(string.format("\tintensity = %s,\n", tostring(data.intensity)))
	file:write(string.format("\tlengthScale = %s,\n", tostring(data.lengthScale)))
	if data.heightCapMin then file:write(string.format("\theightCapMin = %s,\n", tostring(data.heightCapMin))) end
	if data.heightCapMax then file:write(string.format("\theightCapMax = %s,\n", tostring(data.heightCapMax))) end
	file:write(string.format("\theightCapAbsolute = %s,\n", tostring(data.heightCapAbsolute)))
	file:write(string.format("\tclayMode = %s,\n", tostring(data.clayMode)))
	file:write(string.format("\tnoiseType = %q,\n", data.noiseType))
	file:write(string.format("\tnoiseScale = %s,\n", tostring(data.noiseScale)))
	file:write(string.format("\tnoiseOctaves = %s,\n", tostring(data.noiseOctaves)))
	file:write(string.format("\tnoisePersistence = %s,\n", tostring(data.noisePersistence)))
	file:write(string.format("\tnoiseLacunarity = %s,\n", tostring(data.noiseLacunarity)))
	file:write(string.format("\tnoiseSeed = %s,\n", tostring(data.noiseSeed)))
	file:write(string.format("\tringInnerRatio = %s,\n", tostring(data.ringInnerRatio)))
	file:write(string.format("\tgridOverlay = %s,\n", tostring(data.gridOverlay)))
	file:write(string.format("\tgridSnap = %s,\n", tostring(data.gridSnap)))
	file:write(string.format("\tgridSnapSize = %s,\n", tostring(data.gridSnapSize)))
	file:write(string.format("\tcurveOverlay = %s,\n", tostring(data.curveOverlay)))
	file:write(string.format("\tvelocityIntensity = %s,\n", tostring(data.velocityIntensity)))
	file:write(string.format("\trestoreStrength = %s,\n", tostring(data.restoreStrength)))
	file:write(string.format("\tdustEffects = %s,\n", tostring(data.dustEffects)))
	file:write(string.format("\tseismicEffects = %s,\n", tostring(data.seismicEffects)))
	file:write(string.format("\tdjMode = %s,\n", tostring(data.djMode)))
	file:write(string.format("\tsavedAt = %s,\n", tostring(data.savedAt or 0)))
	file:write("}\n")
	file:close()
	Echo("[Terraform Brush] Preset saved: " .. name)
end

local function loadPreset(name)
	loadPresetsFromDisk()
	local data = presets[name]
	if not data then
		Echo("[Terraform Brush] Preset not found: " .. tostring(name))
		return
	end
	-- Validate and apply with tonumber guards to prevent crashes from corrupted data
	local ok, err = pcall(function()
		-- Set mode FIRST so its defaults (curve/intensity/clayMode for "level") can be
		-- overridden by the preset's saved values applied below.
		if type(data.mode) == "string" then setMode(data.mode) end
		if type(data.shape) == "string" then setShape(data.shape) end
		if tonumber(data.radius) then setRadius(tonumber(data.radius)) end
		if tonumber(data.rotationDeg) then setRotation(tonumber(data.rotationDeg)) end
		if tonumber(data.curve) then setCurve(tonumber(data.curve)) end
		if tonumber(data.intensity) then setIntensity(tonumber(data.intensity)) end
		if tonumber(data.lengthScale) then setLengthScale(tonumber(data.lengthScale)) end
		setHeightCapMin(tonumber(data.heightCapMin))
		setHeightCapMax(tonumber(data.heightCapMax))
		setHeightCapAbsolute(data.heightCapAbsolute ~= false)
		setClayMode(data.clayMode or false)
		if type(data.noiseType) == "string" then setNoiseType(data.noiseType) end
		setNoiseScale(tonumber(data.noiseScale) or 64)
		setNoiseOctaves(tonumber(data.noiseOctaves) or 4)
		setNoisePersistence(tonumber(data.noisePersistence) or 0.5)
		setNoiseLacunarity(tonumber(data.noiseLacunarity) or 2.0)
		setNoiseSeed(tonumber(data.noiseSeed) or 0)
		if tonumber(data.ringInnerRatio) then setRingInnerRatio(tonumber(data.ringInnerRatio)) end
		if data.gridOverlay ~= nil then setGridOverlay(data.gridOverlay) end
		if data.gridSnap ~= nil then extraState.gridSnap = data.gridSnap and true or false end
		if tonumber(data.gridSnapSize) then extraState.gridSnapSize = max(16, min(128, tonumber(data.gridSnapSize))) end
		if data.curveOverlay ~= nil then setCurveOverlay(data.curveOverlay) end
		if data.velocityIntensity ~= nil then
			extraState.velocityIntensity = data.velocityIntensity and true or false
			if not extraState.velocityIntensity then
				extraState.dragVelocityFactor = 1.0
				extraState.lastDragScreenX = nil
				extraState.lastDragScreenY = nil
			end
		end
		if tonumber(data.restoreStrength) then
			extraState.restoreStrength = max(0.0, min(1.0, tonumber(data.restoreStrength)))
		end
		if data.dustEffects ~= nil then setDustEffects(data.dustEffects) end
		if data.seismicEffects ~= nil then setSeismicEffects(data.seismicEffects) end
		if data.djMode ~= nil then setDjMode(data.djMode) end
	end)
	if not ok then
		Echo("[Terraform Brush] Preset '" .. name .. "' has invalid data: " .. tostring(err))
		return
	end
	Echo("[Terraform Brush] Preset loaded: " .. name)
end

local function deletePreset(name)
	loadPresetsFromDisk()
	if not presets[name] then return end
	if isBuiltinPreset(name) then
		Echo("[Terraform Brush] Cannot delete built-in preset: " .. name)
		return
	end
	presets[name] = nil
	local filename = PRESETS_DIR .. name:gsub("%s+", "_") .. ".lua"
	os.remove(filename)
	Echo("[Terraform Brush] Preset deleted: " .. name)
end

local function getPreset(n)
	loadPresetsFromDisk()
	return presets[n]
end

local function getState()
	return {
		active = activeMode ~= nil,
		mode = activeMode,
		direction = activeDirection,
		radius = activeRadius,
		shape = activeShape,
		rotationDeg = activeRotation,
		curve = activeCurve,
		intensity = activeIntensity,
		lengthScale = activeLengthScale,
		heightCapMin = heightCapMin,
		heightCapMax = heightCapMax,
		heightCapAbsolute = heightCapAbsolute,
		clayMode = clayMode,
		dustEffects = dustEffects,
		seismicEffects = seismicEffects,
		djMode = djMode,
		wiggleEnabled = extraState.wiggleEnabled,
		wiggleAmpIdx  = extraState.wiggleAmpIdx,
		wiggleSpdIdx  = extraState.wiggleSpdIdx,
			heightColormap = extraState.heightColormap,

		gridOverlay = gridOverlay,
		gridSnap = extraState.gridSnap,
		gridSnapSize = extraState.gridSnapSize,
		angleSnap = extraState.angleSnap,
		angleSnapStep = extraState.angleSnapStep,
		angleSnapAuto = extraState.angleSnapAuto,
		angleSnapManualSpoke = extraState.angleSnapManualSpoke,
		measureActive = extraState.measureActive,
		measureDrawing = extraState.measureDrawing,
		measureRulerMode = extraState.measureRulerMode,
		measureStickyMode = extraState.measureStickyMode,
		measureDistortMode = extraState.measureDistortMode,
		measureShowLength = extraState.measureShowLength,
		linkedStrokeCount = #(extraState.linkedStrokes or {}),
		measureChainCount = #(extraState.measureLines or {}),
		rampAutoAttach = extraState.rampAutoAttach,
		curveOverlay = extraState.curveOverlay,
		velocityIntensity = extraState.velocityIntensity,
		dragVelocityFactor = extraState.dragVelocityFactor,
		restoreStrength = extraState.restoreStrength,

		undoCount = historyUndoCount,
		redoCount = historyRedoCount,
		noiseType = activeNoiseType,
		noiseScale = noiseScale,
		noiseOctaves = noiseOctaves,
		noisePersistence = noisePersistence,
		noiseLacunarity = noiseLacunarity,
		noiseSeed = noiseSeed,
		ringInnerRatio = ringInnerRatio,
		importProgress = importHeightRows and importRowIndex or nil,
		importTotal = importHeightRows and #importHeightRows or nil,
		symmetryActive = extraState.symmetryActive,
		symmetryOriginX = extraState.symmetryOriginX,
		symmetryOriginZ = extraState.symmetryOriginZ,
		symmetryMirrorX = extraState.symmetryMirrorX,
		symmetryMirrorY = extraState.symmetryMirrorY,
		symmetryRadial = extraState.symmetryRadial,
		symmetryRadialCount = extraState.symmetryRadialCount,
		symmetryPlacingOrigin = extraState.symmetryPlacingOrigin,
		symmetryMirrorAngle = extraState.symmetryMirrorAngle,
		symmetryFlipped = extraState.symmetryFlipped,
		symmetryHoveringOrigin = extraState.symmetryHoveringOrigin,
		symmetryDraggingOrigin = extraState.symmetryDraggingOrigin,
		penPressureEnabled = extraState.penPressureEnabled,
		penPressure = extraState.penPressure,
		penPressureMapped = extraState.penPressureMapped or extraState.penPressure,
		penTiltX = extraState.penTiltX,
		penTiltY = extraState.penTiltY,
		penInContact = extraState.penInContact,
		penPressureModulateIntensity = extraState.penPressureModulateIntensity,
		penPressureModulateSize = extraState.penPressureModulateSize,
		penPressureModulateRadius = extraState.penPressureModulateRadius,
		penPressureRadiusScale = extraState.penPressureRadiusScale,
		penPressureSensitivity = extraState.penPressureSensitivity,
		penPressureCurve = extraState.penPressureCurve,
	}
end

local importHeightRows = nil
local importRowIndex = 0
local IMPORT_ROWS_PER_FRAME = 32
local pendingExport = false

-- Display list cache to avoid rebuilding geometry every frame
local drawCacheList = nil
local drawCacheParams = {}

invalidateDrawCache = function()
	if drawCacheList then
		glDeleteList(drawCacheList)
		drawCacheList = nil
	end
end

local function isDrawCacheValid(worldX, worldZ, groundY)
	local p = drawCacheParams
	return drawCacheList
		and p.worldX == worldX and p.worldZ == worldZ
		and p.groundY == groundY
		and p.shape == activeShape and p.radius == activeRadius
		and p.rotation == activeRotation and p.curve == activeCurve
		and p.lengthScale == activeLengthScale
		and p.mode == activeMode and p.direction == activeDirection
		and p.capMin == heightCapMin and p.capMax == heightCapMax
		and p.capAbsolute == heightCapAbsolute
		and p.intensity == activeIntensity
		and p.ringInnerRatio == ringInnerRatio
			and p.heightColormap == extraState.heightColormap
		and p.lockedX == lockedWorldX and p.lockedZ == lockedWorldZ
		and p.lockedY == lockedGroundY
		and p.rampEndX == rampEndX and p.rampEndZ == rampEndZ
		and p.splineCount == #rampSplinePoints
end

local function updateDrawCacheParams(worldX, worldZ, groundY)
	local p = drawCacheParams
	p.worldX = worldX
	p.worldZ = worldZ
	p.groundY = groundY
	p.shape = activeShape
	p.radius = activeRadius
	p.rotation = activeRotation
	p.curve = activeCurve
	p.lengthScale = activeLengthScale
	p.mode = activeMode
	p.direction = activeDirection
	p.capMin = heightCapMin
	p.capMax = heightCapMax
	p.capAbsolute = heightCapAbsolute
	p.intensity = activeIntensity
	p.ringInnerRatio = ringInnerRatio
	p.heightColormap = extraState.heightColormap

	p.lockedX = lockedWorldX
	p.lockedZ = lockedWorldZ
	p.lockedY = lockedGroundY
	p.rampEndX = rampEndX
	p.rampEndZ = rampEndZ
	p.splineCount = #rampSplinePoints
end

local function exportHeightmap()
	pendingExport = true
	Echo("[Terraform Brush] Export queued, will save on next draw frame...")
end

local function doExportHeightmap()
	local squareSize = Game.squareSize
	local w = Game.mapSizeX / squareSize + 1
	local h = Game.mapSizeZ / squareSize + 1

	local minH, maxH = math.huge, -math.huge
	local heightGrid = {}
	for zi = 0, Game.mapSizeZ, squareSize do
		local row = {}
		for xi = 0, Game.mapSizeX, squareSize do
			local gh = GetGroundHeight(xi, zi)
			if gh < minH then minH = gh end
			if gh > maxH then maxH = gh end
			row[#row + 1] = gh
		end
		heightGrid[#heightGrid + 1] = row
	end

	local heightRange = maxH - minH
	if heightRange < 1 then heightRange = 1 end

	local HEIGHTMAPS_DIR = "Terraform Brush/Heightmaps/"
	Spring.CreateDir(HEIGHTMAPS_DIR)
	local baseName = HEIGHTMAPS_DIR .. "heightmap_export_" .. Game.mapName
	local filename = baseName .. ".png"

	local fboTex = gl.CreateTexture(w, h, {
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})

	if not fboTex then
		Echo("[Terraform Brush] Failed to create FBO texture for export")
		return
	end

	-- Render heights AND save inside same FBO binding (proven pattern from GenEnvLut/GenBrdfLut)
	gl.RenderToTexture(fboTex, function()
		gl.Blending(false)
		gl.DepthTest(false)

		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PushMatrix()
		gl.LoadIdentity()

		gl.BeginEnd(GL.QUADS, function()
			for zi = 1, #heightGrid do
				local row = heightGrid[zi]
				local y0 = (zi - 1) / #heightGrid * 2 - 1
				local y1 = zi / #heightGrid * 2 - 1
				for xi = 1, #row do
					local norm = (row[xi] - minH) / heightRange
					gl.Color(norm, norm, norm, 1)
					local x0 = (xi - 1) / #row * 2 - 1
					local x1 = xi / #row * 2 - 1
					gl.Vertex(x0, y0, 0)
					gl.Vertex(x1, y0, 0)
					gl.Vertex(x1, y1, 0)
					gl.Vertex(x0, y1, 0)
				end
			end
		end)

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()

		-- Save INSIDE the FBO callback (critical!)
		gl.SaveImage(0, 0, w, h, filename, { yflip = false })

		gl.Blending(true)
	end)

	gl.DeleteTexture(fboTex)

	-- Write metadata
	local metaFile = io.open(baseName .. ".txt", "w")
	if metaFile then
		metaFile:write(string.format("%.2f %.2f\n", minH, maxH))
		metaFile:close()
	end

	Echo("[Terraform Brush] Exported to: " .. filename .. " (" .. w .. "x" .. h .. ", range: " .. floor(minH) .. " to " .. floor(maxH) .. ")")
end

local pendingImportFile = nil

local function importHeightmap(_, _, args)
	if not args or not args[1] then
		Echo("[Terraform Brush] Usage: /terraformimport <filename.png>")
		return
	end
	pendingImportFile = args[1]
	Echo("[Terraform Brush] Import queued: " .. pendingImportFile)
end

local function doImportHeightmapRead()
	local filename = pendingImportFile
	pendingImportFile = nil

	local squareSize = Game.squareSize
	local w = Game.mapSizeX / squareSize + 1
	local h = Game.mapSizeZ / squareSize + 1

	-- Load the PNG as a GL texture
	local loaded = gl.Texture(0, filename)
	if not loaded then
		Echo("[Terraform Brush] Failed to load texture: " .. filename)
		return
	end

	local fboTex = gl.CreateTexture(w, h, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})

	if not fboTex then
		Echo("[Terraform Brush] Failed to create FBO for import")
		gl.Texture(0, false)
		return
	end

	-- Render loaded texture to FBO and read pixels in same binding
	local res
	gl.RenderToTexture(fboTex, function()
		gl.Blending(false)
		gl.DepthTest(false)

		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PushMatrix()
		gl.LoadIdentity()

		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()

		res = gl.ReadPixels(0, 0, w, h)

		gl.Blending(true)
	end)

	gl.Texture(0, false)
	gl.DeleteTexture(fboTex)

	if not res then
		Echo("[Terraform Brush] Failed to read pixels from " .. filename)
		return
	end

	-- Read metadata
	local metaBase = filename:gsub("%.png$", ".txt")
	local minH, maxH
	local metaFile = io.open(metaBase, "r")
	if metaFile then
		local content = metaFile:read("*a")
		metaFile:close()
		if content then
			local a, b = content:match("([%-%.%d]+)%s+([%-%.%d]+)")
			minH = tonumber(a)
			maxH = tonumber(b)
		end
	end

	if not minH or not maxH then
		local gMin, gMax = Spring.GetGroundExtremes()
		minH = gMin or -200
		maxH = gMax or 800
		Echo("[Terraform Brush] No metadata file, using map height range: " .. minH .. " to " .. maxH)
	end

	local heightRange = maxH - minH
	local columns = {}
	for col = 1, #res do
		local row = res[col]
		local numRows = #row
		local heights = {}
		for rowIdx = 1, numRows do
			local flippedIdx = numRows - rowIdx + 1
			local pixel = row[flippedIdx]
			local grey = (pixel[1] + pixel[2] + pixel[3]) / 3
			heights[rowIdx] = minH + grey * heightRange
		end
		columns[col] = heights
	end

	importHeightRows = columns
	importRowIndex = 0
	Echo("[Terraform Brush] Loaded " .. filename .. " (" .. #res .. "x" .. #res[1] .. "), applying " .. IMPORT_ROWS_PER_FRAME .. " cols/frame...")
end

local function doImportHeightmapSend()
	if not importHeightRows then
		return
	end

	local squareSize = Game.squareSize
	local totalCols = #importHeightRows
	local rowsThisFrame = 0

	while importRowIndex < totalCols and rowsThisFrame < IMPORT_ROWS_PER_FRAME do
		importRowIndex = importRowIndex + 1
		rowsThisFrame = rowsThisFrame + 1

		local heights = importHeightRows[importRowIndex]
		local x = (importRowIndex - 1) * squareSize

		local parts = {}
		for j = 1, #heights do
			parts[j] = string.format("%.0f", heights[j])
		end

		local msg = MSG.IMPORT .. x .. " " .. table.concat(parts, " ")
		SendLuaRulesMsg(msg)
	end

	markTessellationDirty()

	if importRowIndex >= totalCols then
		Echo("[Terraform Brush] Heightmap import complete!")
		importHeightRows = nil
		importRowIndex = 0
	end
end

function widget:Initialize()
	widgetHandler:AddAction("terraformbrush", function(_, _, args)
		if activeMode then
			return deactivateTerraform()
		else
			return activate(1, "raise", args)
		end
	end, nil, "t")
	widgetHandler:AddAction("terraformup", activateTerraformUp, nil, "t")
	widgetHandler:AddAction("terraformdown", activateTerraformDown, nil, "t")
	widgetHandler:AddAction("terraformlevel", activateTerraformLevel, nil, "t")
	widgetHandler:AddAction("terraformsmooth", function(_, _, args) return activate(0, "smooth", args) end, nil, "t")
	widgetHandler:AddAction("terraformramp", activateTerraformRamp, nil, "t")
	widgetHandler:AddAction("terraformrestore", activateTerraformRestore, nil, "t")
	widgetHandler:AddAction("terraformbrushoff", deactivateTerraform, nil, "t")
	widgetHandler:AddAction("terraformexport", exportHeightmap, nil, "t")
	widgetHandler:AddAction("terraformimport", importHeightmap, nil, "t")

	loadKeybindsFromDisk()

	WG.TerraformBrush = {
		setMode = setMode,
		setShape = setShape,
		rotate = rotateBy,
		setRotation = setRotation,
		setCurve = setCurve,
		setIntensity = setIntensity,
		setLengthScale = setLengthScale,
		setRadius = setRadius,
		setHeightCapMin = setHeightCapMin,
		setHeightCapMax = setHeightCapMax,
		setHeightCapAbsolute = setHeightCapAbsolute,
		setClayMode = setClayMode,

		setBrushOpacity = setBrushOpacity,
		setGridOverlay = setGridOverlay,
		setGridSnap = function(value)
			extraState.gridSnap = value and true or false
		end,
		setGridSnapSize = function(value)
			extraState.gridSnapSize = max(16, min(128, tonumber(value) or 48))
			extraState.gridDirty = true
		end,
		setAngleSnap = function(value)
			extraState.angleSnap = value and true or false
		end,
		setAngleSnapAuto = function(value)
			extraState.angleSnapAuto = value and true or false
		end,
		setAngleSnapManualSpoke = function(idx)
			local step = extraState.angleSnapStep
			local numSpokes = (step > 0) and floor(360 / step) or 1
			extraState.angleSnapManualSpoke = idx % numSpokes
			activeRotation = (extraState.angleSnapManualSpoke * step) % 360
			extraState.angleSnapScrollAccum = 0
		end,
		setAngleSnapStep = function(value)
			extraState.angleSnapStep = max(0.5, min(90, tonumber(value) or 15))
			-- re-snap current rotation immediately
			if extraState.angleSnap and extraState.angleSnapStep > 0 then
				local s = extraState.angleSnapStep
				activeRotation = (floor(activeRotation / s + 0.5) * s) % 360
			end
		end,
		setMeasureShowLength = function(value)
			extraState.measureShowLength = value and true or false
		end,
		setMeasureActive = function(value)
			extraState.measureActive = value and true or false
			if extraState.measureActive then
				extraState.measureDrawing = true  -- always enter drawing mode on activation
				extraState.measureDrawStartTimer = Spring.GetTimer()  -- seed pulse animation
				-- Own text to intercept Enter before the chatall action binding fires
				widgetHandler:OwnText()
			else
				extraState.measureDrawing = false
				extraState.measureActivePt = nil
				extraState.measureActiveChain = nil
				extraState.measureDragLine = nil
				widgetHandler:DisownText()
			end
		end,
		clearMeasureLines = function()
			extraState.measureLines = {}
			extraState.measureActivePt = nil
			extraState.measureActiveChain = nil
			extraState.measureDragLine = nil
		end,
		-- G4: clear only ramp-linked chains from the measure layer
		clearRampChains = function()
			local kept = {}
			for _, c in ipairs(extraState.measureLines) do
				if not c.isRampChain then kept[#kept + 1] = c end
			end
			extraState.measureLines = kept
		end,
		-- G4: toggle automatic ramp-chain attachment
		setRampAutoAttach = function(value)
			extraState.rampAutoAttach = value and true or false
		end,
		setMeasureRulerMode = function(value)
			extraState.measureRulerMode = value and true or false
		end,
		setMeasureStickyMode = function(value)
			extraState.measureStickyMode = value and true or false
			if not extraState.measureStickyMode then
				extraState.linkedStrokes          = {}
				extraState.linkedStrokeGroupCount  = 0
				extraState.stickyUndoBaseline      = nil
			end
		end,
		setMeasureDistortMode = function(value)
			extraState.measureDistortMode = value and true or false
		end,
		clearLinkedStrokes = function()
			extraState.linkedStrokes          = {}
			extraState.linkedStrokeGroupCount  = 0
			extraState.stickyUndoBaseline      = nil
		end,
		setDustEffects = setDustEffects,
		setSeismicEffects = setSeismicEffects,
		setDjMode = setDjMode,
		setWiggle = function(enabled, ampIdx, spdIdx)
			extraState.wiggleEnabled = enabled and true or false
			extraState.wiggleAmpIdx  = math.max(1, math.min(4, tonumber(ampIdx) or 1))
			extraState.wiggleSpdIdx  = math.max(1, math.min(4, tonumber(spdIdx) or 1))
			if not extraState.wiggleEnabled then extraState.wigglePhase = 0 end
		end,
		setHeightColormap = setHeightColormap,
		setHeightSamplingMode = function(target)
			extraState.heightSamplingMode = (target == "max" or target == "min") and target or nil
			if extraState.heightSamplingMode then
				setHeightColormap(true)  -- auto-enable the colormap so contours are visible
			end
		end,
		getHeightSamplingMode = function()
			return extraState.heightSamplingMode
		end,
		setCurveOverlay = setCurveOverlay,
		setVelocityIntensity = function(value)
			extraState.velocityIntensity = value and true or false
			if not extraState.velocityIntensity then
				extraState.dragVelocityFactor = 1.0
				extraState.lastDragScreenX = nil
				extraState.lastDragScreenY = nil
			end
		end,
		setRestoreStrength = function(value)
			extraState.restoreStrength = max(0.0, min(1.0, tonumber(value) or 1.0))
		end,
		setRingInnerRatio = setRingInnerRatio,
		-- Pen pressure API
		setPenPressure = function(value)
			extraState.penPressureEnabled = value and true or false
			if not extraState.penPressureEnabled then
				extraState.penPressure = 1.0
				extraState.penPressureMapped = 1.0
				extraState.penInContact = false
			end
		end,
		setPenPressureModulateIntensity = function(value)
			extraState.penPressureModulateIntensity = value and true or false
		end,
		setPenPressureModulateSize = function(value)
			extraState.penPressureModulateSize = value and true or false
		end,
		setPenPressureModulateRadius = function(value)
			extraState.penPressureModulateRadius = value and true or false
		end,
		setPenPressureRadiusScale = function(value)
			extraState.penPressureRadiusScale = max(0.0, min(1.0, tonumber(value) or 0.5))
		end,
		setPenPressureSensitivity = function(value)
			extraState.penPressureSensitivity = max(0.1, min(3.0, tonumber(value) or 1.0))
		end,
		setPenPressureCurve = function(value)
			extraState.penPressureCurve = max(1, min(5, math.floor(tonumber(value) or 2)))
		end,
		setPenOverUI = function(value)
			extraState.penOverUI = value and true or false
		end,

		setNoiseType = setNoiseType,
		setNoiseScale = setNoiseScale,
		setNoiseOctaves = setNoiseOctaves,
		setNoisePersistence = setNoisePersistence,
		setNoiseLacunarity = setNoiseLacunarity,
		setNoiseSeed = setNoiseSeed,
		-- Symmetry API
		setSymmetryActive = function(value)
			extraState.symmetryActive = value and true or false
			if not extraState.symmetryActive then
				extraState.symmetryPlacingOrigin = false
				extraState.symmetryDraggingOrigin = false
			end
		end,
		setSymmetryOrigin = function(x, z)
			extraState.symmetryOriginX = tonumber(x)
			extraState.symmetryOriginZ = tonumber(z)
		end,
		setSymmetryMirrorX = function(value)
			extraState.symmetryMirrorX = value and true or false
			if extraState.symmetryMirrorX then
				extraState.symmetryRadial = false
			end
		end,
		setSymmetryMirrorY = function(value)
			extraState.symmetryMirrorY = value and true or false
			if extraState.symmetryMirrorY then
				extraState.symmetryRadial = false
			end
		end,
		setSymmetryRadial = function(value)
			extraState.symmetryRadial = value and true or false
			if extraState.symmetryRadial then
				extraState.symmetryMirrorX = false
				extraState.symmetryMirrorY = false
			end
		end,
		setSymmetryRadialCount = function(value)
			extraState.symmetryRadialCount = max(2, min(16, floor(tonumber(value) or 2)))
		end,
		setSymmetryPlacingOrigin = function(value)
			extraState.symmetryPlacingOrigin = value and true or false
		end,
		setSymmetryMirrorAngle = function(value)
			extraState.symmetryMirrorAngle = (tonumber(value) or 0) % 360
		end,
		setSymmetryFlipped = function(value)
			extraState.symmetryFlipped = value and true or false
		end,
		clearSymmetry = function()
			extraState.symmetryActive = false
			extraState.symmetryPlacingOrigin = false
			extraState.symmetryDraggingOrigin = false
			extraState.symmetryMirrorX = false
			extraState.symmetryMirrorY = false
			extraState.symmetryRadial = false
			extraState.symmetryRadialCount = 2
			extraState.symmetryOriginX = nil
			extraState.symmetryOriginZ = nil
			extraState.symmetryMirrorAngle = 0
			extraState.symmetryFlipped = false
		end,
		getSymmetricPositions = extraState.getSymmetricPositions,
		getSymmetryOrigin = extraState.getSymmetryOrigin,
		snapWorld = function(x, z, angleDeg)
			if not extraState.gridSnap then return x, z end
			return extraState.snapToGrid(x, z, angleDeg or 0)
		end,
		getState = getState,
		isStampMode = isStampMode,
		savePreset = savePreset,
		loadPreset = loadPreset,
		deletePreset = deletePreset,
		getPresetNames = getPresetNames,
		isBuiltinPreset = isBuiltinPreset,
		getPreset = getPreset,
		deactivate = deactivateTerraform,
		undo = function()
			if historyUndoCount > 0 then
				SendLuaRulesMsg(MSG.UNDO)
			end
		end,
		redo = function()
			if historyRedoCount > 0 then
				SendLuaRulesMsg(MSG.REDO)
			end
		end,
		fullRestore = function()
			SendLuaRulesMsg(MSG.FULL_RESTORE)
		end,
		-- Keybind configuration API
		getKeybinds = function() return deepCopyKeybinds(activeKeybinds) end,
		getDefaultKeybinds = function() return deepCopyKeybinds(DEFAULT_KEYBINDS) end,
		setKeybind = function(action, keyCode, label)
			if activeKeybinds[action] then
				activeKeybinds[action].key = tonumber(keyCode) or activeKeybinds[action].key
				activeKeybinds[action].label = tostring(label or activeKeybinds[action].label)
			end
		end,
		applyKeybinds = function(binds)
			if type(binds) ~= "table" then return end
			for action, entry in pairs(binds) do
				if activeKeybinds[action] and type(entry) == "table" and entry.key then
					activeKeybinds[action].key = tonumber(entry.key) or activeKeybinds[action].key
					activeKeybinds[action].label = tostring(entry.label or activeKeybinds[action].label)
					if entry.key2 ~= nil then
						activeKeybinds[action].key2 = tonumber(entry.key2) or activeKeybinds[action].key2
					end
					if entry.label2 ~= nil then
						activeKeybinds[action].label2 = tostring(entry.label2)
					end
				end
			end
		end,
		saveKeybinds = saveKeybindsToDisk,
		resetKeybinds = function()
			activeKeybinds = deepCopyKeybinds(DEFAULT_KEYBINDS)
		end,
		getKeybindLabel = getKeybindLabel,
	}

	widgetHandler:RegisterGlobal("TerraformBrushStackUpdate", function(undoCount, redoCount)
		historyUndoCount = undoCount or 0
		historyRedoCount = redoCount or 0
		extraState.gadgetUndoCount = undoCount or 0
		-- Cap baseline if gadget evicted old entries (not during our own undo phase)
		if extraState.stickyUndoBaseline then
			local inUndo = extraState.replayQueue and extraState.replayQueue.phase == "undo"
			if not inUndo and extraState.gadgetUndoCount < extraState.stickyUndoBaseline then
				extraState.stickyUndoBaseline = extraState.gadgetUndoCount
			end
		end
		markTessellationDirty()
		extraState.gridDirty = true
	end)
end

function widget:Shutdown()
	invalidateDrawCache()
	if extraState.splineCacheList then
		glDeleteList(extraState.splineCacheList)
		extraState.splineCacheList = nil
	end
	if extraState.gridDL then
		glDeleteList(extraState.gridDL)
		extraState.gridDL = nil
	end
	-- Release text ownership if measure mode was active when widget unloaded
	if extraState.measureActive then
		widgetHandler:DisownText()
	end
	widgetHandler:RemoveAction("terraformbrush")
	widgetHandler:RemoveAction("terraformup")
	widgetHandler:RemoveAction("terraformdown")
	widgetHandler:RemoveAction("terraformlevel")
	widgetHandler:RemoveAction("terraformsmooth")
	widgetHandler:RemoveAction("terraformramp")
	widgetHandler:RemoveAction("terraformrestore")
	widgetHandler:RemoveAction("terraformbrushoff")
	widgetHandler:RemoveAction("terraformexport")
	widgetHandler:RemoveAction("terraformimport")
	widgetHandler:DeregisterGlobal("TerraformBrushStackUpdate")
	hideBuildGrid()
	WG.TerraformBrush = nil
end

local function smoothSplinePoints(points, passes)
	if #points < 3 then return points end
	local result = points
	for _ = 1, (passes or 2) do
		local smoothed = { result[1] }
		for i = 2, #result - 1 do
			smoothed[i] = {
				(result[i - 1][1] + result[i][1] + result[i + 1][1]) / 3,
				(result[i - 1][2] + result[i][2] + result[i + 1][2]) / 3,
			}
		end
		smoothed[#result] = result[#result]
		result = smoothed
	end
	return result
end

local function downsamplePoints(points, maxCount)
	if #points <= maxCount then return points end
	local result = { points[1] }
	local step = (#points - 1) / (maxCount - 1)
	for i = 2, maxCount - 1 do
		local idx = floor(1 + (i - 1) * step + 0.5)
		result[i] = points[idx]
	end
	result[maxCount] = points[#points]
	return result
end

local function getSmoothedSpline()
	local pts = rampSplinePoints
	if #pts < 2 then return pts end
	pts = downsamplePoints(pts, SPLINE_MAX_POINTS)
	return smoothSplinePoints(pts, 2)
end

-- Stored on extraState to avoid consuming a chunk-level local slot (at 200-local limit).
-- Returns a smoothed slice of only the last SPLINE_SEND_WINDOW raw points.
extraState.getSmoothedSplineWindow = function()
	local pts = rampSplinePoints
	local n = #pts
	if n < 2 then return pts end
	local startIdx = max(1, n - SPLINE_SEND_WINDOW + 1)
	local slice = {}
	for i = startIdx, n do slice[#slice + 1] = pts[i] end
	slice = downsamplePoints(slice, SPLINE_MAX_POINTS)
	return smoothSplinePoints(slice, 2)
end

-- Package and send a SPLINE_RAMP message. snapFull=true → gadget uses factor 1.0 (instant snap).
-- Respects symmetry: sends one SPLINE_RAMP per symmetric copy, transforming all points.
extraState.sendSplinePts = function(pts, snapFull)
	if #pts < 2 then return end
	local nPts = #pts
	-- Build per-point symmetric copies in one pass (getSymmetricPositions once per point)
	local symPts = {}  -- symPts[k][i] = {x,z} for copy k of point i
	local nCopies = 1
	for i = 1, nPts do
		local copies = extraState.getSymmetricPositions(pts[i][1], pts[i][2], 0)
		if i == 1 then
			nCopies = #copies
			for k = 1, nCopies do symPts[k] = {} end
		end
		for k = 1, nCopies do
			symPts[k][i] = copies[k] or copies[1]
		end
	end
	for k = 1, nCopies do
		local parts = { MSG.SPLINE_RAMP, tostring(activeRadius), " ", tostring(nPts) }
		for i = 1, nPts do
			local p = symPts[k][i]
			parts[#parts + 1] = " "
			parts[#parts + 1] = tostring(floor(p.x))
			parts[#parts + 1] = " "
			parts[#parts + 1] = tostring(floor(p.z))
		end
		parts[#parts + 1] = " "
		parts[#parts + 1] = clayMode and "1" or "0"
		parts[#parts + 1] = " "
		parts[#parts + 1] = djMode and dustEffects and "1" or "0"
		parts[#parts + 1] = " "
		parts[#parts + 1] = snapFull and "1" or "0"
		SendLuaRulesMsg(table.concat(parts))
	end
	afterBrushTick()
end

-- Commit settled early raw points: smooth raw[prevRawIdx..windowStart], snap-apply them,
-- and store the smoothed positions so the display stops shifting for those points.
extraState.doSplineCommit = function()
	local n = #rampSplinePoints
	local windowStart = max(1, n - SPLINE_SEND_WINDOW + 1)
	local sc = extraState.splineCommitted
	if not sc or windowStart <= sc.rawIdx + 1 then return end
	-- Build slice: from prev committed idx (inclusive for smooth anchor) to windowStart + 2
	local from = max(1, sc.rawIdx)
	local to = min(n, windowStart + 2)
	local slice = {}
	for i = from, to do slice[#slice + 1] = rampSplinePoints[i] end
	local smoothedCommit = smoothSplinePoints(downsamplePoints(slice, SPLINE_MAX_POINTS), 2)
	-- Store all but the trailing overshoot points so next window has clean overlap
	local storeUpTo = max(1, #smoothedCommit - 2)
	for i = 1, storeUpTo do
		sc.pts[#sc.pts + 1] = smoothedCommit[i]
	end
	sc.rawIdx = windowStart
	extraState.sendSplinePts(smoothedCommit, true)
end

-- Build the final complete path from committed pts + smoothed uncommitted tail.
extraState.buildFinalSplinePts = function()
	local sc = extraState.splineCommitted
	if not sc or #sc.pts == 0 then
		return getSmoothedSpline()
	end
	local result = {}
	for _, p in ipairs(sc.pts) do result[#result + 1] = p end
	local from = max(1, sc.rawIdx)
	local tailSlice = {}
	for i = from, #rampSplinePoints do tailSlice[#tailSlice + 1] = rampSplinePoints[i] end
	if #tailSlice >= 2 then
		local tail = smoothSplinePoints(downsamplePoints(tailSlice, SPLINE_MAX_POINTS), 2)
		for i = 2, #tail do result[#result + 1] = tail[i] end
	end
	return result
end

-- G4: Tessellate a ramp chain (applying bezier handles) into a flat array of world {x,z} points.
-- Used when re-applying so curved chains produce smooth ramp paths.
extraState.tessellateRampChain = function(chain)
	local STEPS = 16
	local pts = chain.pts
	local hs  = chain.handles or {}
	local np  = #pts
	local result = {{pts[1][1], pts[1][2]}}
	for i = 1, np - 1 do
		local ax, az = pts[i][1], pts[i][2]
		local bx, bz = pts[i+1][1], pts[i+1][2]
		local h = hs[i]
		if h then
			for st = 1, STEPS do
				local t  = st / STEPS
				local mt = 1 - t
				local qx = mt*mt*ax + 2*mt*t*h[1] + t*t*bx
				local qz = mt*mt*az + 2*mt*t*h[2] + t*t*bz
				result[#result + 1] = {qx, qz}
			end
		else
			result[#result + 1] = {bx, bz}
		end
	end
	return result
end

-- G4: Re-apply the terrain operation stored in a ramp chain, using the chain's current
-- geometry.  Always sends as SPLINE_RAMP so curved (handle-modified) chains work correctly.
extraState.reapplyRampChain = function(chain)
	if not chain or not chain.isRampChain then return end
	local tpts = extraState.tessellateRampChain(chain)
	if #tpts < 2 then return end
	local r   = chain.rampRadius or 64
	local clay = chain.rampClay  and "1" or "0"
	local parts = { MSG.SPLINE_RAMP, tostring(r), " ", tostring(#tpts) }
	for i = 1, #tpts do
		parts[#parts + 1] = " "
		parts[#parts + 1] = tostring(floor(tpts[i][1]))
		parts[#parts + 1] = " "
		parts[#parts + 1] = tostring(floor(tpts[i][2]))
	end
	parts[#parts + 1] = " " .. clay .. " 0 1"   -- clay, dustEffects=0, snapFull=1
	SendLuaRulesMsg(table.concat(parts))
	afterBrushTick()
end

-- G4: Queue an undo+sync+reapply for a ramp chain after an endpoint/handle drag.
-- Sends one UNDO per widget:Update tick (safe, avoids batched-undo stripy terrain bug).
-- If a sticky replayQueue is active the re-apply is skipped to avoid conflicts.
extraState.queueRampReapply = function(chain)
	if not chain or not chain.isRampChain then return end
	-- Don't conflict with an active sticky replay
	if extraState.replayQueue then
		extraState.reapplyRampChain(chain)  -- fallback: paint on top (no undo)
		return
	end
	local baseline = chain.rampUndoBaseline or 0
	local undoNeeded = math.max(0, (extraState.gadgetUndoCount or 0) - baseline)
	if undoNeeded == 0 then
		-- Nothing to undo (chain was never applied, or already clean) — just apply
		extraState.reapplyRampChain(chain)
		return
	end
	extraState.rampReapplyQueue = { chain = chain, phase = "undo", remaining = undoNeeded }
end

-- G4: Store a completed ramp path as a persistent chain in the measure layer.
-- Fits the dense path to as few bezier segments as possible (ideally 1) using
-- iterative quadratic-bezier splitting (Douglas-Peucker style).
-- pts = array of {x,z}; radius, clay copied from current brush state.
extraState.attachRampChain = function(pts, radius, clay)
	if not pts or #pts < 2 then return end
	local n = #pts
	-- Straight ramp (2 pts): trivial case, no handle needed
	if n <= 2 then
		local chain = { pts = {{pts[1][1],pts[1][2]},{pts[n][1],pts[n][2]}}, handles = {}, isRampChain = true, rampRadius = radius, rampClay = clay }
		extraState.measureLines[#extraState.measureLines + 1] = chain
		return
	end
	-- Compute the quadratic bezier handle for a sub-path pts[ia..ib].
	-- Uses the index-midpoint of the sub-path to derive H = 2*M - 0.5*(P0+P1).
	local function fitHandle(ia, ib)
		local m  = floor((ia + ib) / 2)
		local p0x, p0z = pts[ia][1], pts[ia][2]
		local p1x, p1z = pts[ib][1], pts[ib][2]
		local mx,  mz  = pts[m][1],  pts[m][2]
		return 2*mx - 0.5*(p0x+p1x), 2*mz - 0.5*(p0z+p1z)
	end
	-- Max squared deviation of pts[ia..ib] from the quadratic bezier with handle (hx,hz).
	-- Returns max_sq_deviation, index_of_worst_point.
	local function maxDevSq(ia, ib, hx, hz)
		local p0x, p0z = pts[ia][1], pts[ia][2]
		local p1x, p1z = pts[ib][1], pts[ib][2]
		local span = ib - ia
		local best, bestI = 0, floor((ia+ib)/2)
		for i = ia + 1, ib - 1 do
			local t  = (i - ia) / span
			local mt = 1 - t
			local bx = mt*mt*p0x + 2*mt*t*hx + t*t*p1x
			local bz = mt*mt*p0z + 2*mt*t*hz + t*t*p1z
			local dx, dz = pts[i][1] - bx, pts[i][2] - bz
			local d = dx*dx + dz*dz
			if d > best then best = d; bestI = i end
		end
		return best, bestI
	end
	-- Iterative bezier fit: start with 1 segment, split at worst point until
	-- max deviation < THRESHOLD or MAX_SEGS segments reached.
	-- Loose tolerance (80 units) + max 2 segments keeps ramp chains at 1-2 bezier arcs.
	local MAX_SEGS = 2
	local THRESH_SQ = 80 * 80  -- 80 world-unit deviation (loose: prefer fewer segments)
	-- Each segment is {a=startIdx, b=endIdx} into original pts[]
	local segs = { {a=1, b=n} }
	while #segs < MAX_SEGS do
		local worstDev, worstI, worstSeg = 0, nil, nil
		for si = 1, #segs do
			local s = segs[si]
			if s.b - s.a >= 2 then
				local hx, hz = fitHandle(s.a, s.b)
				local dsq, mi = maxDevSq(s.a, s.b, hx, hz)
				if dsq > worstDev then
					worstDev = dsq; worstI = mi; worstSeg = si
				end
			end
		end
		if not worstI or worstDev <= THRESH_SQ then break end
		-- Split worstSeg at worstI
		local old = segs[worstSeg]
		table.remove(segs, worstSeg)
		table.insert(segs, worstSeg,   {a=old.a, b=worstI})
		table.insert(segs, worstSeg+1, {a=worstI, b=old.b})
	end
	-- Build keypoints from split indices (first pts of each seg + final endpoint)
	local chainPts = {}
	for si = 1, #segs do chainPts[si] = {pts[segs[si].a][1], pts[segs[si].a][2]} end
	chainPts[#chainPts+1] = {pts[segs[#segs].b][1], pts[segs[#segs].b][2]}
	-- Compute bezier handle per segment; omit if nearly straight
	local handles = {}
	for si = 1, #segs do
		local s = segs[si]
		if s.b - s.a >= 2 then
			local hx, hz = fitHandle(s.a, s.b)
			local smx = (pts[s.a][1] + pts[s.b][1]) * 0.5
			local smz = (pts[s.a][2] + pts[s.b][2]) * 0.5
			local dx, dz = hx - smx, hz - smz
			if dx*dx + dz*dz > 9 then  -- non-trivial curvature (> 3 units)
				handles[si] = {hx, hz}
			end
		end
	end
	local chain = {
		pts              = chainPts,
		handles          = handles,
		isRampChain      = true,
		rampRadius       = radius,
		rampClay         = clay,
		-- G4: undo-stack depth at the start of this ramp stroke; used to undo all its
		-- entries before re-applying after a drag.  Captures state before first commit.
		rampUndoBaseline = extraState.rampStrokeUndoBaseline or extraState.gadgetUndoCount,
	}
	extraState.measureLines[#extraState.measureLines + 1] = chain
end

function widget:Update(dt)
	-- Pen pressure: poll tablet pressure from shared file
	extraState.readPenPressure(dt)
	-- D5: parameter HUD fade timer (runs regardless of activeMode)
	if extraState.paramHudTimer > 0 then
		extraState.paramHudTimer = extraState.paramHudTimer - dt
	end
	-- Drain replay queue: undo phase sends lightweight messages (high batch),
	-- sync phase waits 1 tick for gadget feedback, apply phase sends BRUSH (low batch)
	if extraState.replayQueue then
		local q = extraState.replayQueue
		local limit = (q.phase == "undo") and 50 or (q.phase == "sync") and 1 or 6
		for _ = 1, limit do
			if not extraState.replayQueueTick() then break end
		end
	end
	-- G4: Drain ramp re-apply queue.
	-- Sequential same-area undos in correct (newest-first) order are safe to batch;
	-- see /memories/repo/bar_stripy_terrain_bug.md.  Use up to 20/frame so the
	-- undo+sync+reapply cycle finishes in ~3 frames rather than ~120 frames.
	if extraState.rampReapplyQueue and not extraState.replayQueue then
		local rq = extraState.rampReapplyQueue
		if rq.phase == "undo" then
			local batch = math.min(rq.remaining, 20)
			for _ = 1, batch do
				SendLuaRulesMsg(MSG.UNDO)
			end
			rq.remaining = rq.remaining - batch
			if rq.remaining <= 0 then
				rq.phase = "sync"
			end
		elseif rq.phase == "sync" then
			-- Snap baseline to actual post-undo depth before re-applying
			rq.chain.rampUndoBaseline = extraState.gadgetUndoCount
			rq.phase = "apply"
		elseif rq.phase == "apply" then
			extraState.reapplyRampChain(rq.chain)
			extraState.rampReapplyQueue = nil
		end
	end

	if not activeMode then
		return
	end

	updateTimer = updateTimer + dt
	if updateTimer < UPDATE_INTERVAL then
		return
	end
	updateTimer = 0

	local mx, my, leftPressed, _, rightPressed = GetMouseState()
	local anyPressed = leftPressed or (rightPressed and rightMouseHeld)
	if not anyPressed then
		stampApplied = false
		-- Final apply: snap the complete assembled path (committed + tail) in one go
		if activeMode == "ramp" and activeShape == "circle" and #rampSplinePoints >= 2 then
			local finalPts = extraState.buildFinalSplinePts()
			extraState.sendSplinePts(finalPts, true)
			-- G4: auto-attach ramp chain to the measure layer
			if extraState.rampAutoAttach and dragOriginX then
				extraState.attachRampChain(finalPts, activeRadius, clayMode)
			end
		elseif activeMode == "ramp" and activeShape ~= "circle" and rampEndX and dragOriginX then
			-- G4: straight ramp — attach a 2-pt chain to the measure layer
			if extraState.rampAutoAttach then
				extraState.attachRampChain({{dragOriginX, dragOriginZ}, {rampEndX, rampEndZ}}, activeRadius, clayMode)
			end
		end
		-- Close the undo entry AFTER any final applies so the entire stroke
		-- (including the final ramp snap) is one Ctrl+Z.
		closeBrushStroke()
		extraState.mergeLeftOpen = false
		extraState.splineRampLastSendCount = 0
		extraState.splineCommitted = nil
		lockedWorldX = nil
		lockedWorldZ = nil
		lockedGroundY = nil
		lastScreenX = nil
		lastScreenY = nil
		extraState.lastDragScreenX = nil
		extraState.lastDragScreenY = nil
		extraState.dragVelocityFactor = 1.0
		rampEndX = nil
		rampEndZ = nil
		if extraState.splineCacheList then
			glDeleteList(extraState.splineCacheList)
			extraState.splineCacheList = nil
			extraState.splineCacheCount = -1
		end
		rampSplinePoints = {}
		dragOriginX = nil
		dragOriginZ = nil
		extraState.snapCommittedSpokeAngle = nil
		shiftState.axis = nil
		return
	end

	if not lockedWorldX then
		return
	end

	local _, _, _, shift = GetModKeyState()
	if not shift then
		shiftState.axis = nil
		shiftState.originX = nil
		shiftState.originZ = nil
	end

	if activeMode == "ramp" then
		if activeShape == "circle" then
			-- Spline ramp: collect path points as user drags
			if mx ~= lastScreenX or my ~= lastScreenY then
				lastScreenX = mx
				lastScreenY = my
				local worldX, worldZ = getWorldMousePositionOnPlane(lockedGroundY)
				if worldX then
					local addPoint = true
					if #rampSplinePoints > 0 then
						local last = rampSplinePoints[#rampSplinePoints]
						local dx = worldX - last[1]
						local dz = worldZ - last[2]
						if (dx * dx + dz * dz) < SPLINE_SAMPLE_DIST * SPLINE_SAMPLE_DIST then
							addPoint = false
						end
					end
					if addPoint then
						rampSplinePoints[#rampSplinePoints + 1] = { worldX, worldZ }
					end
					rampEndX = worldX
					rampEndZ = worldZ
				end
			end

			if #rampSplinePoints >= 2
			   and (#rampSplinePoints - extraState.splineRampLastSendCount) >= 5 then
				extraState.splineRampLastSendCount = #rampSplinePoints
				-- Commit settled early segments first (snap-apply, freeze display)
				extraState.doSplineCommit()
				-- Apply live window near cursor (blend 30%)
				extraState.sendSplinePts(extraState.getSmoothedSplineWindow(), false)
			end
		else
			-- Square ramp: straight line from A to B
			if mx ~= lastScreenX or my ~= lastScreenY then
				lastScreenX = mx
				lastScreenY = my
				local worldX, worldZ = getWorldMousePositionOnPlane(lockedGroundY)
				if worldX then
					if shift and (shiftState.originX or dragOriginX) then
						local ox = shiftState.originX or dragOriginX
						local oz = shiftState.originZ or dragOriginZ
						worldX, worldZ = constrainToAxis(ox, oz, worldX, worldZ)
					end
					rampEndX = worldX
					rampEndZ = worldZ
				end
			end

			if rampEndX then
				-- Apply symmetry: transform both start and end through each symmetric copy
				local startCopies = extraState.getSymmetricPositions(lockedWorldX, lockedWorldZ, 0)
				local endCopies   = extraState.getSymmetricPositions(rampEndX, rampEndZ, 0)
				for i = 1, #startCopies do
					local sp = startCopies[i]
					local ep = endCopies[i] or endCopies[1]
					local startY = (i == 1) and lockedGroundY or GetGroundHeight(sp.x, sp.z)
					local endY   = GetGroundHeight(ep.x, ep.z)
					local msg = MSG.RAMP
						.. floor(sp.x) .. " "
						.. floor(sp.z) .. " "
						.. string.format("%.0f", startY) .. " "
						.. floor(ep.x) .. " "
						.. floor(ep.z) .. " "
						.. string.format("%.0f", endY) .. " "
						.. activeRadius .. " "
						.. (clayMode and "1" or "0") .. " "
						.. (djMode and dustEffects and "1" or "0")
					SendLuaRulesMsg(msg)
				end
				afterBrushTick()
			end
		end
	elseif activeMode == "restore" then
		if mx ~= lastScreenX or my ~= lastScreenY then
			lastScreenX = mx
			lastScreenY = my
			local worldX, worldZ = getWorldMousePositionOnPlane(lockedGroundY)
			if worldX then
				if shift and (shiftState.originX or dragOriginX) then
					local ox = shiftState.originX or dragOriginX
					local oz = shiftState.originZ or dragOriginZ
					worldX, worldZ = constrainToAxis(ox, oz, worldX, worldZ)
				end
				if extraState.measureActive and extraState.measureRulerMode then
					worldX, worldZ = extraState.snapToMeasureLine(worldX, worldZ)
				end
				lockedWorldX = worldX
				lockedWorldZ = worldZ
			end
		end

		local restorePositions = extraState.getSymmetricPositions(lockedWorldX, lockedWorldZ, activeRotation)
		for ri = 1, #restorePositions do
			local rp = restorePositions[ri]
			local msg = MSG.RESTORE
				.. floor(rp.x) .. " "
				.. floor(rp.z) .. " "
				.. activeRadius .. " "
				.. activeShape .. " "
				.. rp.rot .. " "
				.. string.format("%.1f", activeCurve) .. " "
				.. string.format("%.1f", activeIntensity) .. " "
				.. string.format("%.1f", activeLengthScale) .. " "
				.. string.format("%.2f", extraState.restoreStrength)
			SendLuaRulesMsg(msg)
		end
		afterBrushTick()
	elseif activeMode == "noise" then
		if mx ~= lastScreenX or my ~= lastScreenY then
			lastScreenX = mx
			lastScreenY = my
			local worldX, worldZ = getWorldMousePositionOnPlane(lockedGroundY)
			if worldX then
				-- Protractor takes precedence over shift-axis-lock; shift handled inside snapDragToSpoke
				if extraState.angleSnap and dragOriginX then
					worldX, worldZ = snapDragToSpoke(worldX, worldZ)
				elseif shift and (shiftState.originX or dragOriginX) then
					local ox = shiftState.originX or dragOriginX
					local oz = shiftState.originZ or dragOriginZ
					worldX, worldZ = constrainToAxis(ox, oz, worldX, worldZ)
				end
				if extraState.measureActive and extraState.measureRulerMode then
					worldX, worldZ = extraState.snapToMeasureLine(worldX, worldZ)
				end
				lockedWorldX = worldX
				lockedWorldZ = worldZ
			end
		end

		sendNoiseMessage(lockedWorldX, lockedWorldZ, activeRadius, activeShape, activeRotation, activeLengthScale)
	else
		local mouseMoved = false
		if mx ~= lastScreenX or my ~= lastScreenY then
			mouseMoved = true
			lastScreenX = mx
			lastScreenY = my
			local worldX, worldZ = getWorldMousePositionOnPlane(lockedGroundY)
			if worldX then
				-- Protractor takes precedence over shift-axis-lock; shift handled inside snapDragToSpoke
				if extraState.angleSnap and dragOriginX then
					worldX, worldZ = snapDragToSpoke(worldX, worldZ)
				elseif shift and (shiftState.originX or dragOriginX) then
					local ox = shiftState.originX or dragOriginX
					local oz = shiftState.originZ or dragOriginZ
					worldX, worldZ = constrainToAxis(ox, oz, worldX, worldZ)
				end
				if extraState.measureActive and extraState.measureRulerMode then
					worldX, worldZ = extraState.snapToMeasureLine(worldX, worldZ)
				end
				lockedWorldX = worldX
				lockedWorldZ = worldZ
			end
		end

		-- Velocity-sensitive intensity: scale brush strength by drag speed
		if extraState.velocityIntensity then
			if extraState.lastDragScreenX and mouseMoved then
				local dx = mx - extraState.lastDragScreenX
				local dy = my - extraState.lastDragScreenY
				local speed = (dx * dx + dy * dy) ^ 0.5
				extraState.dragVelocityFactor = max(0.1, min(3.0, speed / 15))
			elseif not extraState.lastDragScreenX then
				extraState.dragVelocityFactor = 1.0
			end
			extraState.lastDragScreenX = mx
			extraState.lastDragScreenY = my
		end

		-- Stamp mode: apply once per position, re-apply only when mouse moves
		if isStampMode() then
			if stampApplied and not mouseMoved then
				return
			end
			stampApplied = true
		end

		-- For level/smooth mode (direction=0): pass the flatten target height.
		-- level: first-click height (pinned target). smooth: live mean of brush area.
		local fh = nil
		if activeDirection == 0 then
			if activeMode == "smooth" then
				local sum = 0
				local step = activeRadius * 0.4
				for ix = -2, 2 do
					for iz = -2, 2 do
						sum = sum + GetGroundHeight(lockedWorldX + ix * step, lockedWorldZ + iz * step)
					end
				end
				fh = sum / 25
			else
				fh = lockedGroundY
			end
		end

		-- Interpolated stamps: bridge the gap between last applied position and
		-- current so fast mouse moves still produce a connected stroke.
		-- Skipped in stamp mode (which is discrete stamps by design).
		local prevX, prevZ = extraState.lastAppliedX, extraState.lastAppliedZ
		local steps = 1
		if prevX and not isStampMode() then
			local ddx = lockedWorldX - prevX
			local ddz = lockedWorldZ - prevZ
			local dist = (ddx * ddx + ddz * ddz) ^ 0.5
			-- Denser overlap (~15% of radius) eliminates visible banding at
			-- slow-to-mid drag speeds; fast drags are capped by maxSteps.
			local stepSize = max(4, activeRadius * 0.15)
			steps = floor(dist / stepSize + 0.5)
			if steps < 1 then steps = 1 end
			if steps > 48 then steps = 48 end
		end
		if steps <= 1 or not prevX then
			sendTerraformMessage(activeDirection, lockedWorldX, lockedWorldZ, activeRadius, activeShape, activeRotation, activeCurve, fh)
		else
			-- Clay mode is additive (each stamp compounds on current height).
			-- Without compensation, N interpolated stamps = Nx the stroke force
			-- → runaway rise. Split the per-tick intensity across substeps.
			-- Non-clay modes aren't additive, so leave full intensity.
			if clayMode then
				extraState.interpIntensityScale = 1 / steps
			end
			for i = 1, steps do
				local t = i / steps
				local ix = prevX + (lockedWorldX - prevX) * t
				local iz = prevZ + (lockedWorldZ - prevZ) * t
				local fhi = fh
				if activeMode == "smooth" and activeDirection == 0 then
					local sum = 0
					local step = activeRadius * 0.4
					for jx = -2, 2 do
						for jz = -2, 2 do
							sum = sum + GetGroundHeight(ix + jx * step, iz + jz * step)
						end
					end
					fhi = sum / 25
				end
				sendTerraformMessage(activeDirection, ix, iz, activeRadius, activeShape, activeRotation, activeCurve, fhi)
			end
			extraState.interpIntensityScale = 1
		end
		-- Per-tick MERGE_END: each tick = one undo entry, all tagged with same stroke ID.
		-- UNDO_STROKE pops entire stroke atomically. closeBrushStroke() on mouse release.
		afterBrushTick()
		extraState.lastAppliedX = lockedWorldX
		extraState.lastAppliedZ = lockedWorldZ
	end

	-- Seismic sound feedback: play periodic impact sounds while actively sculpting
	if djMode and seismicEffects then
		extraState.seismicTimer = extraState.seismicTimer - UPDATE_INTERVAL
		if extraState.seismicTimer <= 0 then
			local vol = max(0.15, min(0.45, (activeIntensity or 1.0) / 15))
			Spring.PlaySoundFile("sounds/weapons/bimpact1.wav", vol, lockedWorldX or 0, GetGroundHeight(lockedWorldX or 0, lockedWorldZ or 0), lockedWorldZ or 0, "battle")
			extraState.seismicTimer = 0.28 + math.random() * 0.18
		end
	else
		extraState.seismicTimer = 0
	end
end

local function rotatePoint(px, pz, angleDeg)
	local rad = angleDeg * pi / 180
	local cosA = cos(rad)
	local sinA = sin(rad)
	return px * cosA - pz * sinA, px * sinA + pz * cosA
end

-- Returns the base RGB for the active mode
local function getModeRGB()
	if activeMode == "raise"   then return 0.2,  0.8,  0.2
	elseif activeMode == "lower"   then return 0.8,  0.2,  0.2
	elseif activeMode == "restore" then return 0.7,  0.3,  0.9
	elseif activeMode == "noise"   then return 0.96, 0.62, 0.04
	elseif activeMode == "ramp"    then return 0.9,  0.7,  0.2
	else                               return 0.3,  0.5,  0.9   -- level
	end
end

-- Returns a brightened/saturated RGB for falloff curve and accents
local function getModeRGBBright()
	if activeMode == "raise"   then return 0.45, 1.0,  0.45
	elseif activeMode == "lower"   then return 1.0,  0.45, 0.45
	elseif activeMode == "restore" then return 0.88, 0.58, 1.0
	elseif activeMode == "noise"   then return 1.0,  0.82, 0.3
	elseif activeMode == "ramp"    then return 1.0,  0.88, 0.4
	else                               return 0.5,  0.78, 1.0   -- level
	end
end


extraState.EDGE_SEGMENTS = 16  -- subdivisions per edge for terrain-following outlines

function extraState.drawRotatedSquare(cx, cz, radius, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	local corners = {
		{ -radius, -radius * lengthScale },
		{  radius, -radius * lengthScale },
		{  radius,  radius * lengthScale },
		{ -radius,  radius * lengthScale },
	}

	glPolygonOffset(-2, -2)
	glBeginEnd(GL.LINE_LOOP, function()
		for i = 1, 4 do
			local next = (i % 4) + 1
			local x0, z0 = corners[i][1], corners[i][2]
			local x1, z1 = corners[next][1], corners[next][2]
			for s = 0, extraState.EDGE_SEGMENTS - 1 do
				local t = s / extraState.EDGE_SEGMENTS
				local lx = x0 + (x1 - x0) * t
				local lz = z0 + (z1 - z0) * t
				local rx, rz = rotatePoint(lx, lz, angleDeg)
				local wx, wz = cx + rx, cz + rz
				local wy = GetGroundHeight(wx, wz)
				glVertex(wx, wy, wz)
			end
		end
	end)
	glPolygonOffset(false)
end

function extraState.drawRegularPolygon(cx, cz, radius, angleDeg, numSides, lengthScale)
	lengthScale = lengthScale or 1.0
	local angleStep = 2 * pi / numSides
	local subdiv = numSides <= 8 and extraState.EDGE_SEGMENTS or 1
	glPolygonOffset(-2, -2)
	glBeginEnd(GL.LINE_LOOP, function()
		for i = 0, numSides - 1 do
			local a0 = i * angleStep
			local a1 = (i + 1) * angleStep
			local x0 = cos(a0) * radius
			local z0 = sin(a0) * radius * lengthScale
			local x1 = cos(a1) * radius
			local z1 = sin(a1) * radius * lengthScale
			for s = 0, subdiv - 1 do
				local t = s / subdiv
				local lx = x0 + (x1 - x0) * t
				local lz = z0 + (z1 - z0) * t
				local rx, rz = rotatePoint(lx, lz, angleDeg)
				local wx = cx + rx
				local wz = cz + rz
				local wy = GetGroundHeight(wx, wz)
				glVertex(wx, wy, wz)
			end
		end
	end)
	glPolygonOffset(false)
end

function extraState.drawRing(cx, cz, radius, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	angleDeg = angleDeg or 0
	local innerR = radius * ringInnerRatio
	glPolygonOffset(-2, -2)
	for _, r in ipairs({radius, innerR}) do
		glBeginEnd(GL.LINE_LOOP, function()
			for i = 0, CIRCLE_SEGMENTS - 1 do
				local a = (i / CIRCLE_SEGMENTS) * 2 * pi
				local lx = cos(a) * r
				local lz = sin(a) * r * lengthScale
				local rx, rz = rotatePoint(lx, lz, angleDeg)
				local wx, wz = cx + rx, cz + rz
				local wy = GetGroundHeight(wx, wz)
				glVertex(wx, wy, wz)
			end
		end)
	end
	glPolygonOffset(false)
end

-- Re-draws just the outline of the active shape (used for glow passes outside display list cache)
function extraState.drawCurrentOutline(cx, cz, groundY)
	if activeShape == "circle" then
		extraState.drawRegularPolygon(cx, cz, activeRadius, activeRotation, CIRCLE_SEGMENTS, activeLengthScale)
	elseif activeShape == "square" then
		extraState.drawRotatedSquare(cx, cz, activeRadius, activeRotation, activeLengthScale)
	elseif activeShape == "triangle" then
		extraState.drawRegularPolygon(cx, cz, activeRadius, activeRotation, 3, activeLengthScale)
	elseif activeShape == "hexagon" then
		extraState.drawRegularPolygon(cx, cz, activeRadius, activeRotation, 6, activeLengthScale)
	elseif activeShape == "octagon" then
		extraState.drawRegularPolygon(cx, cz, activeRadius, activeRotation, 8, activeLengthScale)
	elseif activeShape == "ring" then
		extraState.drawRing(cx, cz, activeRadius, activeRotation, activeLengthScale)
	elseif activeShape == "fill" then
		-- Diamond crosshair cursor for fill brush
		local BUMP = 4
		local arm = 24
		local gy = groundY or GetGroundHeight(cx, cz)
		glPolygonOffset(-2, -2)
		glBeginEnd(GL.LINE_LOOP, function()
			glVertex(cx,       gy + BUMP, cz - arm)
			glVertex(cx + arm, gy + BUMP, cz)
			glVertex(cx,       gy + BUMP, cz + arm)
			glVertex(cx - arm, gy + BUMP, cz)
		end)
		glBeginEnd(GL.LINES, function()
			glVertex(cx - arm * 1.6, gy + BUMP, cz)
			glVertex(cx + arm * 1.6, gy + BUMP, cz)
			glVertex(cx, gy + BUMP, cz - arm * 1.6)
			glVertex(cx, gy + BUMP, cz + arm * 1.6)
		end)
		glPolygonOffset(false)
	end
end

-- Symmetry overlay: guide lines radiating from origin + ghost brush outlines at mirror positions
extraState.drawSymmetryOverlay = function(worldX, worldZ, groundY)
	if not extraState.symmetryActive then return end
	-- Allow drawing when any terrain tool (terraform/metal/grass/feature-placer/splat) is active
	if not activeMode then
		local mbSt = WG.MetalBrush and WG.MetalBrush.getState()
		local gbSt = WG.GrassBrush and WG.GrassBrush.getState()
		local fpSt = WG.FeaturePlacer and WG.FeaturePlacer.getState()
		local spSt = WG.SplatPainter and WG.SplatPainter.getState()
		if not ((mbSt and mbSt.active) or (gbSt and gbSt.active) or (fpSt and fpSt.active) or (spSt and spSt.active)) then
			return
		end
	end

	local ox, oz = extraState.getSymmetryOrigin()
	local BUMP = 5
	local SEGS = 60
	local msx = Game.mapSizeX
	local msz = Game.mapSizeZ
	local maxLen = ((msx * msx + msz * msz) ^ 0.5) * 0.5
	local ang = (extraState.symmetryMirrorAngle or 0) * pi / 180

	glPolygonOffset(-1, -1)

	-- Draw origin crosshair (larger when hovering/dragging for grab affordance)
	local isOriginInteract = extraState.symmetryHoveringOrigin or extraState.symmetryDraggingOrigin
	local crossSize = isOriginInteract and 60 or 40
	local crossAlpha = isOriginInteract and 1.0 or 0.7
	glLineWidth(isOriginInteract and 3 or 2)
	glColor(0.2, 0.9, 0.9, crossAlpha)
	glBeginEnd(GL.LINES, function()
		glVertex(ox - crossSize, GetGroundHeight(ox - crossSize, oz) + BUMP + 2, oz)
		glVertex(ox + crossSize, GetGroundHeight(ox + crossSize, oz) + BUMP + 2, oz)
		glVertex(ox, GetGroundHeight(ox, oz - crossSize) + BUMP + 2, oz - crossSize)
		glVertex(ox, GetGroundHeight(ox, oz + crossSize) + BUMP + 2, oz + crossSize)
	end)
	-- Origin ring
	if isOriginInteract then
		glLineWidth(2)
		glColor(0.2, 0.9, 0.9, 0.5)
		local oy = GetGroundHeight(ox, oz)
		glDrawGroundCircle(ox, oy, oz, 30, 24)
	end

	-- Draw guide line: terrain-following from origin to map edges
	local function drawGuideLine(angleRad, lineWidth, r, g, b, a)
		local dx = cos(angleRad) * (maxLen / SEGS)
		local dz = sin(angleRad) * (maxLen / SEGS)
		glLineWidth(lineWidth)
		glColor(r, g, b, a)
		glBeginEnd(GL.LINE_STRIP, function()
			for s = -SEGS, SEGS do
				local sx = ox + dx * s
				local sz = oz + dz * s
				if sx >= 0 and sx <= msx and sz >= 0 and sz <= msz then
					glVertex(sx, GetGroundHeight(sx, sz) + BUMP, sz)
				end
			end
		end)
	end

	-- Draw semi-transparent gradient quad strip along a mirror axis line
	-- The gradient rises from the axis with decreasing alpha to show which side is source
	local function drawAxisGradient(angleRad, r, g, b)
		local GRAD_HEIGHT = 120  -- world units above terrain
		local GRAD_SEGS = 30
		local perpX = -sin(angleRad)
		local perpZ = cos(angleRad)
		local stepX = cos(angleRad) * (maxLen / GRAD_SEGS)
		local stepZ = sin(angleRad) * (maxLen / GRAD_SEGS)
		-- Offset perpendicular to the axis (positive side gets the gradient)
		local OFFSET = 40  -- perpendicular offset for the top edge
		glBeginEnd(GL.TRIANGLE_STRIP, function()
			for s = -GRAD_SEGS, GRAD_SEGS do
				local bx = ox + stepX * s
				local bz = oz + stepZ * s
				if bx >= -200 and bx <= msx + 200 and bz >= -200 and bz <= msz + 200 then
					local by = GetGroundHeight(bx, bz) + BUMP
					-- Bottom vertex: on the axis line, semi-opaque
					glColor(r, g, b, 0.12)
					glVertex(bx, by, bz)
					-- Top vertex: offset perpendicular + elevated, transparent
					glColor(r, g, b, 0.0)
					glVertex(bx + perpX * OFFSET, by + GRAD_HEIGHT, bz + perpZ * OFFSET)
				end
			end
		end)
	end

	if extraState.symmetryRadial then
		local count = extraState.symmetryRadialCount
		local step = (2 * pi) / count
		for k = 0, count - 1 do
			drawGuideLine(k * step, 1, 0.2, 0.9, 0.9, 0.25)
		end
	else
		if extraState.symmetryMirrorX then
			-- Rotated X axis guide line: thick glow + core + gradient
			local axisAngle = ang  -- rotated horizontal axis
			drawGuideLine(axisAngle, 7, 0.9, 0.3, 0.3, 0.10)  -- outer glow
			drawGuideLine(axisAngle, 4, 0.9, 0.3, 0.3, 0.30)  -- mid glow
			drawGuideLine(axisAngle, 2, 1.0, 0.5, 0.5, 0.65)  -- core
			drawAxisGradient(axisAngle, 0.9, 0.3, 0.3)
		end
		if extraState.symmetryMirrorY then
			-- Rotated Y axis guide line: thick glow + core + gradient
			local axisAngle = ang + pi * 0.5  -- rotated vertical axis
			drawGuideLine(axisAngle, 7, 0.3, 0.3, 0.9, 0.10)
			drawGuideLine(axisAngle, 4, 0.3, 0.3, 0.9, 0.30)
			drawGuideLine(axisAngle, 2, 0.5, 0.5, 1.0, 0.65)
			drawAxisGradient(axisAngle, 0.3, 0.3, 0.9)
		end
	end

	-- Ghost brush outlines at symmetric positions (skip when suppressing brush or fill shape)
	if not extraState.symmetryPlacingOrigin and not extraState.symmetryDraggingOrigin
	   and not extraState.symmetryHoveringOrigin and activeShape ~= "fill" then
		local positions = extraState.getSymmetricPositions(worldX, worldZ, activeRotation)
		local mr, mg, mb = getModeRGB()
		for i = 2, #positions do
			local p = positions[i]
			local gy = GetGroundHeight(p.x, p.z)
			glLineWidth(2)
			glColor(mr, mg, mb, 0.35)
			if activeShape == "circle" then
				extraState.drawRegularPolygon(p.x, p.z, activeRadius, p.rot, CIRCLE_SEGMENTS, activeLengthScale)
			elseif activeShape == "square" then
				extraState.drawRotatedSquare(p.x, p.z, activeRadius, p.rot, activeLengthScale)
			elseif activeShape == "triangle" then
				extraState.drawRegularPolygon(p.x, p.z, activeRadius, p.rot, 3, activeLengthScale)
			elseif activeShape == "hexagon" then
				extraState.drawRegularPolygon(p.x, p.z, activeRadius, p.rot, 6, activeLengthScale)
			elseif activeShape == "octagon" then
				extraState.drawRegularPolygon(p.x, p.z, activeRadius, p.rot, 8, activeLengthScale)
			elseif activeShape == "ring" then
				extraState.drawRing(p.x, p.z, activeRadius, p.rot, activeLengthScale)
			end
			glLineWidth(1)
			glColor(mr, mg, mb, 0.5)
			local dotSize = 6
			glBeginEnd(GL.LINES, function()
				glVertex(p.x - dotSize, gy + BUMP, p.z)
				glVertex(p.x + dotSize, gy + BUMP, p.z)
				glVertex(p.x, gy + BUMP, p.z - dotSize)
				glVertex(p.x, gy + BUMP, p.z + dotSize)
			end)
		end
	end

	glLineWidth(1)
	glColor(1, 1, 1, 1)
	glPolygonOffset(0, 0)
end

function extraState.getShapeCorners(shape, radius, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	if shape == "circle" or shape == "ring" then
		local corners = {}
		local segments = 32
		for i = 0, segments - 1 do
			local angle = (i / segments) * 2 * pi
			local lx = cos(angle) * radius
			local lz = sin(angle) * radius * lengthScale
			local rx, rz = rotatePoint(lx, lz, angleDeg)
			corners[#corners + 1] = { rx, rz }
		end

		return corners
	elseif shape == "square" then
		local raw = {
			{ -radius, -radius * lengthScale },
			{  radius, -radius * lengthScale },
			{  radius,  radius * lengthScale },
			{ -radius,  radius * lengthScale },
		}
		local corners = {}
		for i = 1, 4 do
			local next = (i % 4) + 1
			local x0, z0 = raw[i][1], raw[i][2]
			local x1, z1 = raw[next][1], raw[next][2]
			for s = 0, extraState.EDGE_SEGMENTS - 1 do
				local t = s / extraState.EDGE_SEGMENTS
				local lx = x0 + (x1 - x0) * t
				local lz = z0 + (z1 - z0) * t
				local rx, rz = rotatePoint(lx, lz, angleDeg)
				corners[#corners + 1] = { rx, rz }
			end
		end

		return corners
	elseif shape == "triangle" or shape == "hexagon" or shape == "octagon" then
		local numSides = shape == "triangle" and 3 or (shape == "hexagon" and 6 or 8)
		local angleStep = 2 * pi / numSides
		local corners = {}
		for i = 0, numSides - 1 do
			local a0 = i * angleStep
			local a1 = (i + 1) * angleStep
			local x0 = cos(a0) * radius
			local z0 = sin(a0) * radius * lengthScale
			local x1 = cos(a1) * radius
			local z1 = sin(a1) * radius * lengthScale
			for s = 0, extraState.EDGE_SEGMENTS - 1 do
				local t = s / extraState.EDGE_SEGMENTS
				local lx = x0 + (x1 - x0) * t
				local lz = z0 + (z1 - z0) * t
				local rx, rz = rotatePoint(lx, lz, angleDeg)
				corners[#corners + 1] = { rx, rz }
			end
		end

		return corners
	end

	return {}
end

-- Draws a terrain-following semi-transparent fill for the brush footprint.
-- Vertices sample GetGroundHeight so the poly hugs hills/valleys.

function extraState.drawShapeGroundFill(cx, cz, radius, shape, angleDeg, groundY, lengthScale)
	lengthScale = lengthScale or 1.0
	local segments = 48

	-- Fill shape: no footprint fill (it has no fixed footprint)
	if shape == "fill" then return end

	-- Ring shape: draw an annulus (donut) with transparent center
	if shape == "ring" then
		local innerR = radius * ringInnerRatio
		gl.DepthTest(false)
		glBeginEnd(GL.TRIANGLE_STRIP, function()
			for i = 0, segments do
				local a = (i / segments) * 2 * pi
				-- outer vertex
				local olx = cos(a) * radius
				local olz = sin(a) * radius * lengthScale
				local orx, orz = rotatePoint(olx, olz, angleDeg)
				local owx, owz = cx + orx, cz + orz
				glVertex(owx, GetGroundHeight(owx, owz), owz)
				-- inner vertex
				local ilx = cos(a) * innerR
				local ilz = sin(a) * innerR * lengthScale
				local irx, irz = rotatePoint(ilx, ilz, angleDeg)
				local iwx, iwz = cx + irx, cz + irz
				glVertex(iwx, GetGroundHeight(iwx, iwz), iwz)
			end
		end)
		gl.DepthTest(true)
		return
	end

	local corners
	if shape == "circle" then
		corners = {}
		for i = 0, segments do
			local a = (i / segments) * 2 * pi
			local lx = cos(a) * radius
			local lz = sin(a) * radius * lengthScale
			local rx, rz = rotatePoint(lx, lz, angleDeg)
			corners[#corners + 1] = { rx, rz }
		end
	else
		corners = extraState.getShapeCorners(shape, radius, angleDeg, lengthScale)
		-- close the loop
		corners[#corners + 1] = corners[1]
	end
	gl.DepthTest(false)
	glBeginEnd(GL.TRIANGLE_FAN, function()
		glVertex(cx, groundY, cz)
		for i = 1, #corners do
			local wx = cx + corners[i][1]
			local wz = cz + corners[i][2]
			glVertex(wx, GetGroundHeight(wx, wz), wz)
		end
	end)
	gl.DepthTest(true)
end

-- Draws a vertical "ruler" post at the brush center showing max effect height.
-- Tick-marks at peak and mid-height give a visual scale reference.
function extraState.drawCenterPost(cx, cz, groundY, effectHeight)
	if abs(effectHeight) < 4 then return end
	local tipY = groundY + effectHeight
	local tickSize = max(6, activeRadius * 0.04)
	-- Vertical shaft
	glBeginEnd(GL.LINES, function()
		glVertex(cx, groundY + 1, cz)
		glVertex(cx, tipY, cz)
	end)
	-- Peak cross-tick (full cross)
	glBeginEnd(GL.LINES, function()
		glVertex(cx - tickSize, tipY, cz)
		glVertex(cx + tickSize, tipY, cz)
		glVertex(cx, tipY, cz - tickSize)
		glVertex(cx, tipY, cz + tickSize)
	end)
	-- Mid-height minor tick (single bar)
	local midY = groundY + effectHeight * 0.5
	local midTick = tickSize * 0.55
	glBeginEnd(GL.LINES, function()
		glVertex(cx - midTick, midY, cz)
		glVertex(cx + midTick, midY, cz)
	end)
end

function extraState.drawShapeAtHeight(cx, cz, corners, height, filled)
	glBeginEnd(GL.LINE_LOOP, function()
		for i = 1, #corners do
			glVertex(cx + corners[i][1], height, cz + corners[i][2])
		end
	end)
	if filled then
		glBeginEnd(GL.TRIANGLE_FAN, function()
			glVertex(cx, height, cz)
			for i = 1, #corners do
				glVertex(cx + corners[i][1], height, cz + corners[i][2])
			end
			glVertex(cx + corners[1][1], height, cz + corners[1][2])
		end)
	end
end

function extraState.drawVerticalEdges(cx, cz, corners, bottomY, topY, stride)
	stride = stride or 1
	glBeginEnd(GL.LINES, function()
		for i = 1, #corners, stride do
			local wx = cx + corners[i][1]
			local wz = cz + corners[i][2]
			glVertex(wx, bottomY, wz)
			glVertex(wx, topY, wz)
		end
	end)
end

function extraState.drawPrism(cx, cz, radius, shape, angleDeg, groundY, capMin, capMax, lengthScale)
	local corners = extraState.getShapeCorners(shape, radius, angleDeg, lengthScale)
	if #corners == 0 then
		return
	end

	local topY = capMax or groundY
	local botY = capMin or groundY
	local hasCaps = capMin or capMax

	local vertStride = 1
	if #corners > 8 then
		vertStride = math.ceil(#corners / 8)
	end

	if hasCaps then
		if capMax then
			glColor(1.0, 0.6, 0.1, 0.15)
			extraState.drawShapeAtHeight(cx, cz, corners, topY, true)
			glColor(1.0, 0.6, 0.1, 0.6)
			extraState.drawShapeAtHeight(cx, cz, corners, topY)
		end

		if capMin then
			glColor(0.1, 0.6, 1.0, 0.15)
			extraState.drawShapeAtHeight(cx, cz, corners, botY, true)
			glColor(0.1, 0.6, 1.0, 0.6)
			extraState.drawShapeAtHeight(cx, cz, corners, botY)
		end

		glColor(1, 1, 1, 0.2)
		extraState.drawVerticalEdges(cx, cz, corners, botY, topY, vertStride)
	end
end

function extraState.drawRingPrism(cx, cz, radius, angleDeg, groundY, capMin, capMax, lengthScale)
	local outerCorners = extraState.getShapeCorners("circle", radius, angleDeg, lengthScale)
	local innerCorners = extraState.getShapeCorners("circle", radius * ringInnerRatio, angleDeg, lengthScale)

	local topY = capMax or groundY
	local botY = capMin or groundY
	local hasCaps = capMin or capMax

	local vertStride = ceil(#outerCorners / 8)

	if hasCaps then
		if capMax then
			glColor(1.0, 0.6, 0.1, 0.1)
			extraState.drawShapeAtHeight(cx, cz, outerCorners, topY, true)
			glColor(1.0, 0.6, 0.1, 0.6)
			extraState.drawShapeAtHeight(cx, cz, outerCorners, topY)
			extraState.drawShapeAtHeight(cx, cz, innerCorners, topY)
		end

		if capMin then
			glColor(0.1, 0.6, 1.0, 0.1)
			extraState.drawShapeAtHeight(cx, cz, outerCorners, botY, true)
			glColor(0.1, 0.6, 1.0, 0.6)
			extraState.drawShapeAtHeight(cx, cz, outerCorners, botY)
			extraState.drawShapeAtHeight(cx, cz, innerCorners, botY)
		end

		glColor(1, 1, 1, 0.2)
		extraState.drawVerticalEdges(cx, cz, outerCorners, botY, topY, vertStride)
		extraState.drawVerticalEdges(cx, cz, innerCorners, botY, topY, vertStride)
	end
end


function extraState.drawFalloffCurveCircle(cx, cz, radius, curvePower, baseY, effectHeight, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	angleDeg = angleDeg or 0
	local segments = 64
	-- Collect vertices for reuse across arc and curtain passes
	local vx, vy, vz = {}, {}, {}
	for i = 0, segments - 1 do
		local theta = (i / segments) * 2 * pi
		local nd = cos(theta)
		local rawFalloff = 1 - nd * nd
		if rawFalloff < 0 then rawFalloff = 0 end
		local falloff = rawFalloff ^ curvePower
		local lx = cos(theta) * radius
		local lz = sin(theta) * radius * lengthScale
		local rx, rz = rotatePoint(lx, lz, angleDeg)
		vx[i] = cx + rx
		vy[i] = baseY + falloff * effectHeight
		vz[i] = cz + rz
	end
	-- Arc line
	glBeginEnd(GL.LINE_LOOP, function()
		for i = 0, segments - 1 do
			glVertex(vx[i], vy[i], vz[i])
		end
	end)
	-- Curtain: sparse vertical drops every 4 segments
	glBeginEnd(GL.LINES, function()
		for i = 0, segments - 1, 4 do
			glVertex(vx[i], vy[i], vz[i])
			glVertex(vx[i], baseY, vz[i])
		end
	end)
end

function extraState.drawFalloffCurveRing(cx, cz, radius, curvePower, baseY, effectHeight, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	angleDeg = angleDeg or 0
	local midR = radius * (1 + ringInnerRatio) * 0.5
	local segments = 64
	local vx, vy, vz = {}, {}, {}
	for i = 0, segments - 1 do
		local theta = (i / segments) * 2 * pi
		local nd = cos(theta)
		local rawFalloff = 1 - nd * nd
		if rawFalloff < 0 then rawFalloff = 0 end
		local falloff = rawFalloff ^ curvePower
		local lx = cos(theta) * midR
		local lz = sin(theta) * midR * lengthScale
		local rx, rz = rotatePoint(lx, lz, angleDeg)
		vx[i] = cx + rx
		vy[i] = baseY + falloff * effectHeight
		vz[i] = cz + rz
	end
	glBeginEnd(GL.LINE_LOOP, function()
		for i = 0, segments - 1 do
			glVertex(vx[i], vy[i], vz[i])
		end
	end)
	glBeginEnd(GL.LINES, function()
		for i = 0, segments - 1, 4 do
			glVertex(vx[i], vy[i], vz[i])
			glVertex(vx[i], baseY, vz[i])
		end
	end)
end

function extraState.drawFalloffCurveRegularPoly(cx, cz, radius, angleDeg, numSides, curvePower, baseY, effectHeight, lengthScale)
	lengthScale = lengthScale or 1.0
	local segmentsPerFace = 8
	local angleStep = 2 * pi / numSides
	local vx, vy, vz = {}, {}, {}
	local n = 0
	for side = 0, numSides - 1 do
		local a0 = side * angleStep
		local a1 = (side + 1) * angleStep
		local x0, z0 = cos(a0) * radius, sin(a0) * radius
		local x1, z1 = cos(a1) * radius, sin(a1) * radius
		for i = 0, segmentsPerFace - 1 do
			local t = i / segmentsPerFace
			local lx = x0 + (x1 - x0) * t
			local lz = z0 + (z1 - z0) * t
			local dist = (lx * lx + lz * lz) ^ 0.5
			local angle = atan2(lz, lx)
			if angle < 0 then angle = angle + 2 * pi end
			local aInSector = (angle % angleStep) - angleStep / 2
			local apothem = radius * cos(pi / numSides)
			local edgeDist = apothem / cos(aInSector)
			local nd = dist / edgeDist
			local rawFalloff = 1 - nd
			if rawFalloff < 0 then rawFalloff = 0 end
			local falloff = rawFalloff ^ curvePower
			local slz = lz * lengthScale
			local rx, rz = rotatePoint(lx, slz, angleDeg)
			vx[n] = cx + rx
			vy[n] = baseY + falloff * effectHeight
			vz[n] = cz + rz
			n = n + 1
		end
	end
	glBeginEnd(GL.LINE_LOOP, function()
		for i = 0, n - 1 do
			glVertex(vx[i], vy[i], vz[i])
		end
	end)
	-- Curtain at every other segment (one per face edge)
	glBeginEnd(GL.LINES, function()
		for i = 0, n - 1, 2 do
			glVertex(vx[i], vy[i], vz[i])
			glVertex(vx[i], baseY, vz[i])
		end
	end)
end

-- squareFaces moved into extraState to stay within 200-local limit

function extraState.drawFalloffCurvePoly(cx, cz, faces, radiusX, radiusZ, angleDeg, curvePower, baseY, effectHeight)
	local segmentsPerFace = 12
	local vx, vy, vz = {}, {}, {}
	local n = 0
	for _, face in ipairs(faces) do
		for i = 0, segmentsPerFace - 1 do
			local t = i / segmentsPerFace
			local lx = (face[1] + (face[3] - face[1]) * t) * radiusX
			local lz = (face[2] + (face[4] - face[2]) * t) * radiusZ
			local nd = max(abs(lx) / radiusX, abs(lz) / radiusZ)
			local rawFalloff = 1 - nd
			if rawFalloff < 0 then rawFalloff = 0 end
			local falloff = rawFalloff ^ curvePower
			local rx, rz = rotatePoint(lx, lz, angleDeg)
			vx[n] = cx + rx
			vy[n] = baseY + falloff * effectHeight
			vz[n] = cz + rz
			n = n + 1
		end
	end
	glBeginEnd(GL.LINE_LOOP, function()
		for i = 0, n - 1 do
			glVertex(vx[i], vy[i], vz[i])
		end
	end)
	-- Curtain every 3 segments
	glBeginEnd(GL.LINES, function()
		for i = 0, n - 1, 3 do
			glVertex(vx[i], vy[i], vz[i])
			glVertex(vx[i], baseY, vz[i])
		end
	end)
end

function extraState.drawRampPreview(startX, startZ, startY, endX, endZ, endY, width)
	local dx = endX - startX
	local dz = endZ - startZ
	local length = (dx * dx + dz * dz) ^ 0.5
	if length < 1 then
		return
	end

	local nx = -dz / length * width
	local nz = dx / length * width

	local c1x, c1z = startX + nx, startZ + nz
	local c2x, c2z = startX - nx, startZ - nz
	local c3x, c3z = endX - nx, endZ - nz
	local c4x, c4z = endX + nx, endZ + nz

	glColor(0.9, 0.7, 0.2, 0.7)
	glLineWidth(3)
	glBeginEnd(GL.LINE_LOOP, function()
		glVertex(c1x, startY + 4, c1z)
		glVertex(c4x, endY + 4, c4z)
		glVertex(c3x, endY + 4, c3z)
		glVertex(c2x, startY + 4, c2z)
	end)

	glColor(0.9, 0.7, 0.2, 0.4)
	glBeginEnd(GL.LINES, function()
		glVertex(startX, startY + 4, startZ)
		glVertex(endX, endY + 4, endZ)
	end)
end


-- Bundle draw helpers into a single table to reduce upvalue count for DrawWorld
-- (LuaJIT limit: 60 upvalues per function)
-- Height colormap: topographic color ramp (8 stops, terrain elevation visualization)
-- Inspired by USGS/topographic map colors — dark water blues through greens to warm peaks.
do
	extraState.CMAP_STOPS = {
		{ h = 0.00, r = 0.10, g = 0.20, b = 0.45 },  -- deep water
		{ h = 0.12, r = 0.15, g = 0.38, b = 0.55 },  -- shallow water / low ground
		{ h = 0.24, r = 0.18, g = 0.55, b = 0.50 },  -- teal shoreline
		{ h = 0.36, r = 0.22, g = 0.62, b = 0.34 },  -- lowland green
		{ h = 0.50, r = 0.48, g = 0.68, b = 0.25 },  -- mid-elevation yellow-green
		{ h = 0.65, r = 0.78, g = 0.68, b = 0.22 },  -- warm yellow
		{ h = 0.80, r = 0.82, g = 0.48, b = 0.18 },  -- orange-brown
		{ h = 0.92, r = 0.62, g = 0.30, b = 0.20 },  -- red-brown peaks
		{ h = 1.00, r = 0.95, g = 0.92, b = 0.90 },  -- snow caps
	}
	extraState.cmapStops = extraState.CMAP_STOPS
	extraState.cmapN = #extraState.cmapStops

	function extraState.cmapSample(t)
		if t <= 0 then return extraState.cmapStops[1].r, extraState.cmapStops[1].g, extraState.cmapStops[1].b end
		if t >= 1 then return extraState.cmapStops[extraState.cmapN].r, extraState.cmapStops[extraState.cmapN].g, extraState.cmapStops[extraState.cmapN].b end
		for i = 1, extraState.cmapN - 1 do
			if t <= extraState.cmapStops[i + 1].h then
				local s0, s1 = extraState.cmapStops[i], extraState.cmapStops[i + 1]
				local f = (t - s0.h) / (s1.h - s0.h)
				-- Smooth-step interpolation for perceptual uniformity
				f = f * f * (3 - 2 * f)
				return s0.r + (s1.r - s0.r) * f,
				       s0.g + (s1.g - s0.g) * f,
				       s0.b + (s1.b - s0.b) * f
			end
		end
		return extraState.cmapStops[extraState.cmapN].r, extraState.cmapStops[extraState.cmapN].g, extraState.cmapStops[extraState.cmapN].b
	end

	-- Draw a height-colored grid overlay on the terrain within the brush footprint.
	-- Uses a square sampling grid clipped to the brush shape.
	extraState.CMAP_GRID = 24  -- grid resolution: NxN quads within the bounding box
	function extraState.drawHeightColormap(cx, cz, radius, shape, angleDeg, lengthScale)
		lengthScale = lengthScale or 1.0
		local gridN = extraState.CMAP_GRID
		-- Compute height range within brush footprint (two-pass: sample then draw)
		local spanX = radius
		local spanZ = radius * lengthScale
		-- Collect grid data: world positions and heights
		local gx, gz, gy = {}, {}, {} -- arrays of grid point data [row * (gridN+1) + col]
		local hMin, hMax = 1e9, -1e9
		local peakX, peakZ = cx, cz
		local sinA = sin(angleDeg * pi / 180)
		local cosA = cos(angleDeg * pi / 180)
		-- Snap grid to fixed world positions to eliminate contour jitter when moving.
		-- Project brush center onto rotated axes, find fractional offset within a cell,
		-- and subtract it from each grid point so vertices align to a world-fixed grid.
		local cellSizeX = 2 * spanX / gridN
		local cellSizeZ = 2 * spanZ / gridN
		local projX = cx * cosA + cz * sinA
		local projZ = -cx * sinA + cz * cosA
		local fracOffX = projX % cellSizeX
		if fracOffX > cellSizeX * 0.5 then fracOffX = fracOffX - cellSizeX end
		local fracOffZ = projZ % cellSizeZ
		if fracOffZ > cellSizeZ * 0.5 then fracOffZ = fracOffZ - cellSizeZ end
		-- Per-vertex shape alpha: smooth 0..1 fade at brush boundary (eliminates staircase edges)
		local fadeNorm = 2.0 / gridN  -- ~1 cell width in normalized shape space
		local function shapeAlpha(lx, lz)
			local d -- signed distance from edge in normalized units (positive = inside)
			if shape == "circle" then
				d = 1.0 - (lx * lx / (spanX * spanX) + lz * lz / (spanZ * spanZ)) ^ 0.5
			elseif shape == "ring" then
				local nd = (lx * lx / (spanX * spanX) + lz * lz / (spanZ * spanZ)) ^ 0.5
				d = min(1.0 - nd, nd - ringInnerRatio)
			elseif shape == "square" then
				d = min(1.0 - abs(lx) / spanX, 1.0 - abs(lz) / spanZ)
			elseif shape == "triangle" or shape == "hexagon" or shape == "octagon" then
				-- Regular N-gon SDF in normalized (spanX, spanZ) space.
				-- Vertices lie on the unit circle after normalization, so the SDF is exact.
				-- Sector boundaries sit at vertex angles (0, th, 2*th, ...) matching drawRegularPolygon.
				local N  = (shape == "triangle") and 3 or (shape == "hexagon") and 6 or 8
				local nx, nz = lx / spanX, lz / spanZ
				local th  = 2 * pi / N
				local r   = (nx * nx + nz * nz) ^ 0.5
				-- ang_mod in [0, th): angle within current sector; edge normal at th/2
				local ang_mod = atan2(nz, nx) % th
				-- d_raw=0 at polygon edge (vertices and edge midpoints), positive inside
				local d_raw = cos(th * 0.5) - r * cos(ang_mod - th * 0.5)
				d = d_raw / cos(pi / N)
			else
				d = 1.05 - (lx * lx / (spanX * spanX) + lz * lz / (spanZ * spanZ)) ^ 0.5
			end
			if d >= fadeNorm then return 1.0 end
			if d <= 0 then return 0.0 end
			return d / fadeNorm
		end
		local ga = {} -- per-vertex shape alpha
		for row = 0, gridN do
			for col = 0, gridN do
				local lx = -spanX + col * cellSizeX - fracOffX
				local lz = -spanZ + row * cellSizeZ - fracOffZ
				-- Rotate to world space
				local wx = cx + lx * cosA - lz * sinA
				local wz = cz + lx * sinA + lz * cosA
				local idx = row * (gridN + 1) + col
				gx[idx] = wx
				gz[idx] = wz
				local h = GetGroundHeight(wx, wz)
				gy[idx] = h
				ga[idx] = shapeAlpha(lx, lz)
				if h < hMin then hMin = h end
				if h > hMax then hMax = h; peakX = wx; peakZ = wz end
			end
		end
		-- If terrain is perfectly flat, nothing useful to show
		local hRange = hMax - hMin
		if hRange < 1 then extraState.colormapLabels = nil; extraState.colormapPeak = nil; return end

		gl.DepthTest(false)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		glBeginEnd(GL.TRIANGLES, function()
			for row = 0, gridN - 1 do
				for col = 0, gridN - 1 do
					local i00 = row * (gridN + 1) + col
					local i10 = i00 + 1
					local i01 = (row + 1) * (gridN + 1) + col
					local i11 = i01 + 1
					local a00, a10, a01, a11 = ga[i00], ga[i10], ga[i01], ga[i11]
					if a00 > 0 or a10 > 0 or a01 > 0 or a11 > 0 then
						-- Triangle 1: i00, i10, i01
						local t = (gy[i00] - hMin) / hRange
						local cr, cg, cb = extraState.cmapSample(t)
						glColor(cr, cg, cb, 0.55 * a00)
						glVertex(gx[i00], gy[i00] + 2, gz[i00])
						t = (gy[i10] - hMin) / hRange
						cr, cg, cb = extraState.cmapSample(t)
						glColor(cr, cg, cb, 0.55 * a10)
						glVertex(gx[i10], gy[i10] + 2, gz[i10])
						t = (gy[i01] - hMin) / hRange
						cr, cg, cb = extraState.cmapSample(t)
						glColor(cr, cg, cb, 0.55 * a01)
						glVertex(gx[i01], gy[i01] + 2, gz[i01])
						-- Triangle 2: i10, i11, i01
						t = (gy[i10] - hMin) / hRange
						cr, cg, cb = extraState.cmapSample(t)
						glColor(cr, cg, cb, 0.55 * a10)
						glVertex(gx[i10], gy[i10] + 2, gz[i10])
						t = (gy[i11] - hMin) / hRange
						cr, cg, cb = extraState.cmapSample(t)
						glColor(cr, cg, cb, 0.55 * a11)
						glVertex(gx[i11], gy[i11] + 2, gz[i11])
						t = (gy[i01] - hMin) / hRange
						cr, cg, cb = extraState.cmapSample(t)
						glColor(cr, cg, cb, 0.55 * a01)
						glVertex(gx[i01], gy[i01] + 2, gz[i01])
					end
				end
			end
		end)

		-- Contour lines at fixed absolute height intervals for jitter-free display
		glLineWidth(1.5)
		local LOG10 = log(10)
		local rawStep = hRange / 10
		local exp10 = floor(log(rawStep > 0 and rawStep or 1) / LOG10)
		local base10 = 10 ^ exp10
		local nrm = rawStep / base10
		local contourStep
		if nrm < 1.5 then contourStep = base10
		elseif nrm < 3.5 then contourStep = 2 * base10
		elseif nrm < 7.5 then contourStep = 5 * base10
		else contourStep = 10 * base10 end
		local firstContour = ceil(hMin / contourStep) * contourStep
		local contourH = firstContour
		local nContour = 0
		while contourH < hMax and nContour < 20 do
			local ct = (contourH - hMin) / hRange
			local cr, cg, cb = extraState.cmapSample(ct)
			-- Brighten contour slightly and increase opacity
			glColor(min(1, cr + 0.15), min(1, cg + 0.15), min(1, cb + 0.15), 0.70)
			glBeginEnd(GL.LINES, function()
				for row = 0, gridN - 1 do
					for col = 0, gridN - 1 do
						local i00 = row * (gridN + 1) + col
						local i10 = i00 + 1
						local i01 = (row + 1) * (gridN + 1) + col
						local i11 = i01 + 1
						if ga[i00] > 0 or ga[i10] > 0 or ga[i01] > 0 or ga[i11] > 0 then
							-- Check the 4 edges of this quad for contour crossings
							local h00, h10, h01, h11 = gy[i00], gy[i10], gy[i01], gy[i11]
							-- Edge helpers: interpolate position along edge where contourH crosses
							-- Bottom edge (i00 → i10)
							if (h00 - contourH) * (h10 - contourH) < 0 then
								local f = (contourH - h00) / (h10 - h00)
								local ax = gx[i00] + (gx[i10] - gx[i00]) * f
								local az = gz[i00] + (gz[i10] - gz[i00]) * f
								-- Find a matching edge
								-- Right edge (i10 → i11)
								if (h10 - contourH) * (h11 - contourH) < 0 then
									local f2 = (contourH - h10) / (h11 - h10)
									glVertex(ax, contourH + 3, az)
									glVertex(gx[i10] + (gx[i11] - gx[i10]) * f2, contourH + 3, gz[i10] + (gz[i11] - gz[i10]) * f2)
								end
								-- Top edge (i01 → i11)
								if (h01 - contourH) * (h11 - contourH) < 0 then
									local f2 = (contourH - h01) / (h11 - h01)
									glVertex(ax, contourH + 3, az)
									glVertex(gx[i01] + (gx[i11] - gx[i01]) * f2, contourH + 3, gz[i01] + (gz[i11] - gz[i01]) * f2)
								end
								-- Left edge (i00 → i01)
								if (h00 - contourH) * (h01 - contourH) < 0 then
									local f2 = (contourH - h00) / (h01 - h00)
									glVertex(ax, contourH + 3, az)
									glVertex(gx[i00] + (gx[i01] - gx[i00]) * f2, contourH + 3, gz[i00] + (gz[i01] - gz[i00]) * f2)
								end
							end
							-- Left edge (i00 → i01) → Right edge (i10 → i11)
							if (h00 - contourH) * (h01 - contourH) < 0 and (h10 - contourH) * (h11 - contourH) < 0 then
								local f1 = (contourH - h00) / (h01 - h00)
								local f2 = (contourH - h10) / (h11 - h10)
								glVertex(gx[i00] + (gx[i01] - gx[i00]) * f1, contourH + 3, gz[i00] + (gz[i01] - gz[i00]) * f1)
								glVertex(gx[i10] + (gx[i11] - gx[i10]) * f2, contourH + 3, gz[i10] + (gz[i11] - gz[i10]) * f2)
							end
							-- Top edge (i01 → i11) → others handled above if bottom was already a crossing
							if (h01 - contourH) * (h11 - contourH) < 0 and not ((h00 - contourH) * (h10 - contourH) < 0) then
								local f = (contourH - h01) / (h11 - h01)
								local ax = gx[i01] + (gx[i11] - gx[i01]) * f
								local az = gz[i01] + (gz[i11] - gz[i01]) * f
								-- Left edge
								if (h00 - contourH) * (h01 - contourH) < 0 then
									local f2 = (contourH - h00) / (h01 - h00)
									glVertex(ax, contourH + 3, az)
									glVertex(gx[i00] + (gx[i01] - gx[i00]) * f2, contourH + 3, gz[i00] + (gz[i01] - gz[i00]) * f2)
								end
								-- Right edge
								if (h10 - contourH) * (h11 - contourH) < 0 then
									local f2 = (contourH - h10) / (h11 - h10)
									glVertex(ax, contourH + 3, az)
									glVertex(gx[i10] + (gx[i11] - gx[i10]) * f2, contourH + 3, gz[i10] + (gz[i11] - gz[i10]) * f2)
								end
							end
						end
					end
				end
			end)
			contourH = contourH + contourStep
			nContour = nContour + 1
		end
		extraState.colormapPeak = {peakX, hMax, peakZ, tostring(floor(hMax + 0.5))}
		extraState.collectColormapLabels(cx, cz, spanX, spanZ, cosA, sinA, hMin, hRange, contourStep, shape)
		-- Persist mesh + contour params so the per-frame hover-highlight pass can use them
		-- outside the display-list cache (Lua assignments are not recorded by glCreateList).
		extraState.colormapContourStep = contourStep
		extraState.colormapHMin = hMin
		extraState.colormapHMax = hMax
		extraState.colormapLastMesh = { gx = gx, gz = gz, gy = gy, ga = ga, gridN = gridN }
		glLineWidth(1)
		gl.DepthTest(true)
	end

	extraState.collectColormapLabels = function(cx, cz, spanX, spanZ, cosA, sinA, hMin, hRange, contourStep, shapeHint)
		local BDRY_STEPS = 64
		local bH = {}
		local bWX, bWZ = {}, {}
		local nSides = shapeHint == "triangle" and 3
		              or shapeHint == "hexagon"  and 6
		              or shapeHint == "octagon"  and 8
		              or 0
		for k = 0, BDRY_STEPS - 1 do
			local t = k / BDRY_STEPS
			local lbx, lbz
			if shapeHint == "square" then
				-- Walk the rectangle perimeter: 4 sides, each 1/4 of BDRY_STEPS
				local t4 = t * 4
				if t4 < 1 then
					lbx = -spanX + t4 * 2 * spanX; lbz = -spanZ
				elseif t4 < 2 then
					lbx = spanX; lbz = -spanZ + (t4 - 1) * 2 * spanZ
				elseif t4 < 3 then
					lbx = spanX - (t4 - 2) * 2 * spanX; lbz = spanZ
				else
					lbx = -spanX; lbz = spanZ - (t4 - 3) * 2 * spanZ
				end
			elseif nSides > 0 then
				-- Walk the N-sided polygon perimeter
				local edge  = t * nSides
				local side  = floor(edge)
				local f     = edge - side
				local a0    = side * 2 * pi / nSides
				local a1    = (side + 1) * 2 * pi / nSides
				lbx = (cos(a0) + (cos(a1) - cos(a0)) * f) * spanX
				lbz = (sin(a0) + (sin(a1) - sin(a0)) * f) * spanZ
			else
				local angle = t * 2 * pi
				lbx = spanX * cos(angle)
				lbz = spanZ * sin(angle)
			end
			local bwx = cx + lbx * cosA - lbz * sinA
			local bwz = cz + lbx * sinA + lbz * cosA
			bH[k]  = GetGroundHeight(bwx, bwz)
			bWX[k] = bwx
			bWZ[k] = bwz
		end
		local newLabels = {}
		local hMax = hMin + hRange
		local contourH = ceil(hMin / contourStep) * contourStep
		local nContour = 0
		while contourH < hMax and nContour < 20 do
			local ct = (contourH - hMin) / hRange
			for k = 0, BDRY_STEPS - 1 do
				local k2 = (k + 1) % BDRY_STEPS
				local ha, hb = bH[k], bH[k2]
				if (ha - contourH) * (hb - contourH) < 0 then
					local f   = (contourH - ha) / (hb - ha)
					local bwx = bWX[k] + (bWX[k2] - bWX[k]) * f
					local bwz = bWZ[k] + (bWZ[k2] - bWZ[k]) * f
					local dx  = bwx - cx
					local dz  = bwz - cz
					local dd  = (dx * dx + dz * dz) ^ 0.5
					if dd > 0 then
						local OFFS = max(25, spanX * 0.12)
						local lwx = bwx + dx / dd * OFFS
						local lwz = bwz + dz / dd * OFFS
						local lwy = GetGroundHeight(lwx, lwz)
						local cr, cg, cb = extraState.cmapSample(ct)
						newLabels[#newLabels + 1] = {lwx, lwy, lwz,
							tostring(floor(contourH + 0.5)),
							min(1, cr + 0.25), min(1, cg + 0.25), min(1, cb + 0.25),
							contourH}  -- [8] = raw height for hover-highlight comparison
					end
					break
				end
			end
			contourH = contourH + contourStep
			nContour = nContour + 1
		end
		extraState.colormapLabels = newLabels
	end

end

-- Draw the single contour line at height `contourH` using the last-cached mesh,
-- with a bright highlight colour and wider stroke.  Called every frame outside
-- the display-list cache so hover state changes are reflected immediately.
extraState.drawContourHighlight = function(contourH)
	local mesh = extraState.colormapLastMesh
	if not mesh then return end
	local gx2, gz2, gy2, ga2, gridN2 = mesh.gx, mesh.gz, mesh.gy, mesh.ga, mesh.gridN
	gl.DepthTest(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glLineWidth(4.0)
	glColor(1.0, 0.95, 0.2, 0.95)
	glBeginEnd(GL.LINES, function()
		for row = 0, gridN2 - 1 do
			for col = 0, gridN2 - 1 do
				local i00 = row * (gridN2 + 1) + col
				local i10 = i00 + 1
				local i01 = (row + 1) * (gridN2 + 1) + col
				local i11 = i01 + 1
				if ga2[i00] > 0 or ga2[i10] > 0 or ga2[i01] > 0 or ga2[i11] > 0 then
					local h00, h10, h01, h11 = gy2[i00], gy2[i10], gy2[i01], gy2[i11]
					-- Bottom edge (i00→i10)
					if (h00 - contourH) * (h10 - contourH) < 0 then
						local f  = (contourH - h00) / (h10 - h00)
						local bx = gx2[i00] + (gx2[i10] - gx2[i00]) * f
						local bz = gz2[i00] + (gz2[i10] - gz2[i00]) * f
						if (h10 - contourH) * (h11 - contourH) < 0 then
							local f2 = (contourH - h10) / (h11 - h10)
							glVertex(bx, contourH + 5, bz)
							glVertex(gx2[i10] + (gx2[i11] - gx2[i10]) * f2, contourH + 5, gz2[i10] + (gz2[i11] - gz2[i10]) * f2)
						end
						if (h01 - contourH) * (h11 - contourH) < 0 then
							local f2 = (contourH - h01) / (h11 - h01)
							glVertex(bx, contourH + 5, bz)
							glVertex(gx2[i01] + (gx2[i11] - gx2[i01]) * f2, contourH + 5, gz2[i01] + (gz2[i11] - gz2[i01]) * f2)
						end
						if (h00 - contourH) * (h01 - contourH) < 0 then
							local f2 = (contourH - h00) / (h01 - h00)
							glVertex(bx, contourH + 5, bz)
							glVertex(gx2[i00] + (gx2[i01] - gx2[i00]) * f2, contourH + 5, gz2[i00] + (gz2[i01] - gz2[i00]) * f2)
						end
					end
					-- Left edge (i00→i01) → Right edge (i10→i11)
					if (h00 - contourH) * (h01 - contourH) < 0 and (h10 - contourH) * (h11 - contourH) < 0 then
						local f1 = (contourH - h00) / (h01 - h00)
						local f2 = (contourH - h10) / (h11 - h10)
						glVertex(gx2[i00] + (gx2[i01] - gx2[i00]) * f1, contourH + 5, gz2[i00] + (gz2[i01] - gz2[i00]) * f1)
						glVertex(gx2[i10] + (gx2[i11] - gx2[i10]) * f2, contourH + 5, gz2[i10] + (gz2[i11] - gz2[i10]) * f2)
					end
					-- Top edge (i01→i11) only when bottom edge didn't already cover this quad
					if (h01 - contourH) * (h11 - contourH) < 0 and not ((h00 - contourH) * (h10 - contourH) < 0) then
						local f  = (contourH - h01) / (h11 - h01)
						local tx = gx2[i01] + (gx2[i11] - gx2[i01]) * f
						local tz = gz2[i01] + (gz2[i11] - gz2[i01]) * f
						if (h00 - contourH) * (h01 - contourH) < 0 then
							local f2 = (contourH - h00) / (h01 - h00)
							glVertex(tx, contourH + 5, tz)
							glVertex(gx2[i00] + (gx2[i01] - gx2[i00]) * f2, contourH + 5, gz2[i00] + (gz2[i01] - gz2[i00]) * f2)
						end
						if (h10 - contourH) * (h11 - contourH) < 0 then
							local f2 = (contourH - h10) / (h11 - h10)
							glVertex(tx, contourH + 5, tz)
							glVertex(gx2[i10] + (gx2[i11] - gx2[i10]) * f2, contourH + 5, gz2[i10] + (gz2[i11] - gz2[i10]) * f2)
						end
					end
				end
			end
		end
	end)
	glLineWidth(1)
	gl.DepthTest(true)
end

-- Called every frame from DrawWorld (outside the display-list cache) to detect
-- which topo contour/peak the cursor is over in height-sampling mode and draw the
-- highlight.  Defined as an extraState function so DrawWorld gains zero new
-- upvalues (only `extraState` is referenced, which is already a DrawWorld upvalue).
extraState.doSamplingHover = function(groundY)
	if not extraState.heightSamplingMode then return end
	if not extraState.heightColormap then return end
	local cStep = extraState.colormapContourStep
	local cMin  = extraState.colormapHMin
	local cMax  = extraState.colormapHMax
	if cStep and cStep > 0 and cMin and cMax then
		local rawNearest = floor(groundY / cStep + 0.5) * cStep
		local firstC     = ceil(cMin / cStep) * cStep
		local threshold  = cStep * 0.25
		if rawNearest >= firstC and rawNearest < cMax
		   and abs(groundY - rawNearest) < threshold then
			extraState.colormapHoverContour = rawNearest
		else
			extraState.colormapHoverContour = nil
		end
	else
		extraState.colormapHoverContour = nil
	end
	-- Peak hover: screen-space distance to peak elevation label
	extraState.colormapHoverPeak = false
	if extraState.colormapPeak then
		local pk = extraState.colormapPeak
		local psx, psy = Spring.WorldToScreenCoords(pk[1], pk[2] + 8, pk[3])
		if psx then
			local smx, smy = Spring.GetMouseState()
			local pdx, pdy = smx - psx, smy - psy
			extraState.colormapHoverPeak = (pdx * pdx + pdy * pdy < 625) -- 25 px radius
		end
	end
	-- Draw highlighted contour line
	if extraState.colormapHoverContour then
		extraState.drawContourHighlight(extraState.colormapHoverContour)
	end
end

extraState.drawEx = {
	falloffCircle      = extraState.drawFalloffCurveCircle,
	falloffPoly        = extraState.drawFalloffCurvePoly,
	falloffRegularPoly = extraState.drawFalloffCurveRegularPoly,
	falloffRing        = extraState.drawFalloffCurveRing,
	centerPost         = extraState.drawCenterPost,
	rampPreview        = extraState.drawRampPreview,
	splineRampPreview = function(points, width)
		if #points < 2 then return end

		-- Center line
		glColor(0.9, 0.7, 0.2, 0.7)
		glLineWidth(3)
		glBeginEnd(GL.LINE_STRIP, function()
			for i = 1, #points do
				local y = GetGroundHeight(points[i][1], points[i][2])
				glVertex(points[i][1], y + 4, points[i][2])
			end
		end)

		-- Compute normals per point
		local normals = {}
		for i = 1, #points do
			local nx, nz = 0, 0
			if i < #points then
				local dx = points[i + 1][1] - points[i][1]
				local dz = points[i + 1][2] - points[i][2]
				local len = (dx * dx + dz * dz) ^ 0.5
				if len > 0 then nx, nz = -dz / len, dx / len end
			end
			if i > 1 then
				local dx = points[i][1] - points[i - 1][1]
				local dz = points[i][2] - points[i - 1][2]
				local len = (dx * dx + dz * dz) ^ 0.5
				if len > 0 then
					local n2x, n2z = -dz / len, dx / len
					if i < #points then
						nx = (nx + n2x) * 0.5
						nz = (nz + n2z) * 0.5
						local nlen = (nx * nx + nz * nz) ^ 0.5
						if nlen > 0 then nx, nz = nx / nlen, nz / nlen end
					else
						nx, nz = n2x, n2z
					end
				end
			end
			normals[i] = { nx * width, nz * width }
		end

		-- Left edge
		glColor(0.9, 0.7, 0.2, 0.4)
		glLineWidth(2.5)
		glBeginEnd(GL.LINE_STRIP, function()
			for i = 1, #points do
				local lx = points[i][1] + normals[i][1]
				local lz = points[i][2] + normals[i][2]
				local y = GetGroundHeight(lx, lz)
				glVertex(lx, y + 4, lz)
			end
		end)

		-- Right edge
		glBeginEnd(GL.LINE_STRIP, function()
			for i = 1, #points do
				local rx = points[i][1] - normals[i][1]
				local rz = points[i][2] - normals[i][2]
				local y = GetGroundHeight(rx, rz)
				glVertex(rx, y + 4, rz)
			end
		end)

		-- End caps
		local startY = GetGroundHeight(points[1][1], points[1][2])
		local endY = GetGroundHeight(points[#points][1], points[#points][2])
		glBeginEnd(GL.LINES, function()
			glVertex(points[1][1] + normals[1][1], startY + 4, points[1][2] + normals[1][2])
			glVertex(points[1][1] - normals[1][1], startY + 4, points[1][2] - normals[1][2])
			local n = #points
			glVertex(points[n][1] + normals[n][1], endY + 4, points[n][2] + normals[n][2])
			glVertex(points[n][1] - normals[n][1], endY + 4, points[n][2] - normals[n][2])
		end)
	end,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- MEASURE TOOL: world-space line drawing (runs outside terraform mode)
-- ─────────────────────────────────────────────────────────────────────────────
extraState.MEASURE_KM_SCALE = 192.0      -- elmos per km (display only)
extraState.MEASURE_SNAP_PX  = 22         -- screen-pixel radius for endpoint snap/drag

-- Draw all committed measure chains + the live in-progress segment.
-- Call from DrawWorld (always, not inside the cached display list).
-- Straight segments and Bezier-curved segments (when a control handle is set) are both supported.
function extraState.drawMeasureWorld()
	local ms   = extraState.measureLines
	local apr  = extraState.measureActivePt
	local cx   = extraState.measureCursorX
	local cz   = extraState.measureCursorZ
	local BUMP   = 8    -- elmos above terrain
	local BSTEPS = 20   -- tessellation steps per Bezier segment

	-- Colour palette
	local LR, LG, LB = 0.10, 0.85, 1.00   -- line / ring teal (regular chains)
	local RR, RG, RB = 1.00, 0.65, 0.10   -- ramp chain amber (G4)
	local HR, HG, HB = 1.00, 0.72, 0.10   -- control handle orange
	local SEG_DASH    = 24                  -- dash period (elmos)

	-- Dashed straight segment verts (GL.LINES mode assumed)
	local function dashedSegVerts(ax, az, bx, bz)
		local dx, dz = bx - ax, bz - az
		local totalD = (dx * dx + dz * dz) ^ 0.5
		if totalD < 0.1 then return end
		local nSeg = math.max(1, floor(totalD / (SEG_DASH * 2)))
		for i = 0, nSeg - 1 do
			local t0 = (i * 2 * SEG_DASH) / totalD
			local t1 = math.min(1.0, ((i * 2 + 1) * SEG_DASH) / totalD)
			local x0, z0 = ax + dx * t0, az + dz * t0
			local x1, z1 = ax + dx * t1, az + dz * t1
			glVertex(x0, GetGroundHeight(x0, z0) + BUMP, z0)
			glVertex(x1, GetGroundHeight(x1, z1) + BUMP, z1)
		end
	end

	-- Dashed Bezier segment verts (GL.LINES mode, approximate dashing by skipping alts)
	local function dashedBezierVerts(ax, az, hx, hz, bx, bz)
		local N = BSTEPS * 2
		local prevX, prevZ = ax, az
		for i = 1, N do
			local t = i / N
			local mt = 1 - t
			local qx = mt*mt*ax + 2*mt*t*hx + t*t*bx
			local qz = mt*mt*az + 2*mt*t*hz + t*t*bz
			if i % 2 == 0 then
				glVertex(prevX, GetGroundHeight(prevX, prevZ) + BUMP, prevZ)
				glVertex(qx, GetGroundHeight(qx, qz) + BUMP, qz)
			end
			prevX, prevZ = qx, qz
		end
	end

	-- GL.LINE_STRIP verts for a full chain, tessellating Bezier segments where present
	local function chainStripVerts(pts, hs, np)
		local sx0, sz0 = pts[1][1], pts[1][2]
		glVertex(sx0, GetGroundHeight(sx0, sz0) + BUMP, sz0)
		for i = 1, np - 1 do
			local ax2, az2 = pts[i][1], pts[i][2]
			local bx2, bz2 = pts[i+1][1], pts[i+1][2]
			local h = hs[i]
			if h then
				for st = 1, BSTEPS do
					local t = st / BSTEPS
					local mt = 1 - t
					local qx = mt*mt*ax2 + 2*mt*t*h[1] + t*t*bx2
					local qz = mt*mt*az2 + 2*mt*t*h[2] + t*t*bz2
					glVertex(qx, GetGroundHeight(qx, qz) + BUMP, qz)
				end
			else
				glVertex(bx2, GetGroundHeight(bx2, bz2) + BUMP, bz2)
			end
		end
	end

	-- 3-layer endpoint marker; isRamp=true uses amber, isHover=true adds a glow ring
	local function drawEndpoint(px, pz, isCursor, isRamp, isHover)
		local py = GetGroundHeight(px, pz) + BUMP
		local er = isRamp and RR or LR
		local eg = isRamp and RG or LG
		local eb = isRamp and RB or LB
		if isHover then
			-- Pulsing outer glow ring (brightened, layered)
			local t = Spring.DiffTimers(Spring.GetTimer(), extraState.measureDrawStartTimer or Spring.GetTimer())
			local pulse = 0.50 + 0.50 * math.sin(t * 4.0)  -- 0..1, 2 Hz
			glLineWidth(10)
			glColor(er, eg, eb, 0.15 + 0.20 * pulse)
			glDrawGroundCircle(px, py, pz, 22, 28)
			glLineWidth(3.5)
			glColor(er, eg, eb, 0.55 + 0.30 * pulse)
			glDrawGroundCircle(px, py, pz, 16, 28)
		end
		glLineWidth(6)
		glColor(0, 0, 0, isHover and 0.85 or 0.65)
		glDrawGroundCircle(px, py, pz, 13, 20)
		glLineWidth(isHover and 3.5 or 2.5)
		glColor(er, eg, eb, 1.00)
		glDrawGroundCircle(px, py, pz, 10, 20)
		if isCursor then
			glLineWidth(1.5)
			glColor(er, eg, eb, 0.30)
			glDrawGroundCircle(px, py, pz, 18, 20)
		else
			glLineWidth(2.5)
			glColor(isHover and 1.0 or 1.0, isHover and 1.0 or 1.0, isHover and 1.0 or 1.0, isHover and 1.00 or 0.88)
			glDrawGroundCircle(px, py, pz, isHover and 5 or 4, 12)
		end
	end

	-- Spline handle diamond marker (orange ◇ with dark halo)
	local function drawHandle(hx, hz, isHover)
		local hy = GetGroundHeight(hx, hz) + BUMP
		local R = isHover and 11 or 8
		glLineWidth(5)
		glColor(0, 0, 0, 0.60)
		glBeginEnd(GL.LINE_LOOP, function()
			glVertex(hx,     hy, hz - R) ; glVertex(hx + R, hy, hz    )
			glVertex(hx,     hy, hz + R) ; glVertex(hx - R, hy, hz    )
		end)
		glLineWidth(isHover and 2.5 or 2.0)
		glColor(HR, HG, HB, isHover and 1.0 or 0.90)
		glBeginEnd(GL.LINE_LOOP, function()
			glVertex(hx,     hy, hz - R) ; glVertex(hx + R, hy, hz    )
			glVertex(hx,     hy, hz + R) ; glVertex(hx - R, hy, hz    )
		end)
		if isHover then
			local R2 = R + 7
			glLineWidth(1.5)
			glColor(HR, HG, HB, 0.30)
			glBeginEnd(GL.LINE_LOOP, function()
				glVertex(hx,      hy, hz - R2) ; glVertex(hx + R2, hy, hz     )
				glVertex(hx,      hy, hz + R2) ; glVertex(hx - R2, hy, hz     )
			end)
		end
	end

	-- Control-arm line from endpoint to handle
	local function drawArm(ax, az, bx, bz)
		glBeginEnd(GL.LINES, function()
			glVertex(ax, GetGroundHeight(ax, az) + BUMP, az)
			glVertex(bx, GetGroundHeight(bx, bz) + BUMP, bz)
		end)
	end

	-- ⊕ affordance at segment body showing where a handle would be placed
	local function drawMidHint(wx, wz)
		local wy = GetGroundHeight(wx, wz) + BUMP
		local R = 9
		glLineWidth(4)
		glColor(0, 0, 0, 0.45)
		glDrawGroundCircle(wx, wy, wz, R + 2, 16)
		glLineWidth(1.5)
		glColor(HR, HG, HB, 0.60)
		glDrawGroundCircle(wx, wy, wz, R, 16)
		glBeginEnd(GL.LINES, function()
			glVertex(wx - R*1.5, wy, wz) ; glVertex(wx + R*1.5, wy, wz)
			glVertex(wx, wy, wz - R*1.5) ; glVertex(wx, wy, wz + R*1.5)
		end)
	end

	local hoverH = extraState.measureHoverHandle
	local hoverM = extraState.measureHoverMidSeg

	glPolygonOffset(-2, -2)

	-- ── Pass 1 (depth OFF): underground ghost ──────────────────────────────────
	gl.DepthTest(false)
	glLineWidth(1.5)
	for ci = 1, #ms do
		local chain = ms[ci]
		local pts = chain.pts
		local hs  = chain.handles or {}
		local np  = #pts
		if np >= 2 then
			local cr = chain.isRampChain and RR or LR
			local cg = chain.isRampChain and RG or LG
			local cb = chain.isRampChain and RB or LB
			glColor(cr, cg, cb, 0.28)
			glBeginEnd(GL.LINES, function()
				for i = 1, np - 1 do
					if hs[i] then
						dashedBezierVerts(pts[i][1], pts[i][2], hs[i][1], hs[i][2], pts[i+1][1], pts[i+1][2])
					else
						dashedSegVerts(pts[i][1], pts[i][2], pts[i+1][1], pts[i+1][2])
					end
				end
			end)
		end
	end
	if apr and cx then
		glColor(LR, LG, LB, 0.16)
		glBeginEnd(GL.LINES, function() dashedSegVerts(apr[1], apr[2], cx, cz) end)
	end

	-- ── Pass 2 (depth ON): committed lines — dark border then bright core ──────
	gl.DepthTest(true)
	glLineWidth(5)
	for ci = 1, #ms do
		local chain = ms[ci]
		local pts = chain.pts
		local hs  = chain.handles or {}
		local np  = #pts
		if np >= 2 then
			glColor(0, 0, 0, 0.55)
			glBeginEnd(GL.LINE_STRIP, function() chainStripVerts(pts, hs, np) end)
		end
	end
	glLineWidth(2.5)
	for ci = 1, #ms do
		local chain = ms[ci]
		local pts = chain.pts
		local hs  = chain.handles or {}
		local np  = #pts
		if np >= 2 then
			local cr = chain.isRampChain and RR or LR
			local cg = chain.isRampChain and RG or LG
			local cb = chain.isRampChain and RB or LB
			glColor(cr, cg, cb, 0.95)
			glBeginEnd(GL.LINE_STRIP, function() chainStripVerts(pts, hs, np) end)
		end
		for pi = 1, np do
			local hn  = extraState.measureHoverNear
			local hov = hn and hn.chain == ci and hn.pt == pi
			drawEndpoint(pts[pi][1], pts[pi][2], false, chain.isRampChain, hov)
		end
	end

	-- ── Pass 2-sym: symmetry mirror copies (non-interactive ghosts) ────────────
	if extraState.symmetryActive then
		for ci = 1, #ms do
			local chain = ms[ci]
			local pts = chain.pts
			local hs  = chain.handles or {}
			local np  = #pts
			if np >= 2 then
				local sym0 = extraState.getSymmetricPositions(pts[1][1], pts[1][2], 0)
				for k = 2, #sym0 do
					local mpts = {}
					local mhs  = {}
					for pi = 1, np do
						local s = extraState.getSymmetricPositions(pts[pi][1], pts[pi][2], 0)
						mpts[pi] = {s[k].x, s[k].z}
					end
					for si, h in pairs(hs) do
						local s = extraState.getSymmetricPositions(h[1], h[2], 0)
						mhs[si] = {s[k].x, s[k].z}
					end
					-- Border
					glLineWidth(4)
					glColor(0, 0, 0, 0.35)
					glBeginEnd(GL.LINE_STRIP, function() chainStripVerts(mpts, mhs, np) end)
					-- Core line
					glLineWidth(2)
					glColor(LR, LG, LB, 0.50)
					glBeginEnd(GL.LINE_STRIP, function() chainStripVerts(mpts, mhs, np) end)
					-- Endpoints (simplified ring)
					for pi = 1, np do
						local px, pz = mpts[pi][1], mpts[pi][2]
						local py = GetGroundHeight(px, pz) + BUMP
						glLineWidth(2)
						glColor(LR, LG, LB, 0.45)
						glDrawGroundCircle(px, py, pz, 10, 20)
					end
				end
			end
		end
	end

	-- ── Pass 2b: control handles + arms ────────────────────────────────────────
	for ci = 1, #ms do
		local chain = ms[ci]
		if chain and chain.handles then
			local pts = chain.pts
			for si, h in pairs(chain.handles) do
				local isHov = hoverH and hoverH.chain == ci and hoverH.seg == si
				glLineWidth(1.0)
				glColor(HR, HG, HB, 0.40)
				drawArm(pts[si][1], pts[si][2], h[1], h[2])
				drawArm(h[1], h[2], pts[si+1][1], pts[si+1][2])
				drawHandle(h[1], h[2], isHov)
			end
		end
	end

	-- ── Pass 2c: segment-midpoint hover hint ───────────────────────────────────
	if hoverM then
		drawMidHint(hoverM.wx, hoverM.wz)
	end

	-- ── Pass 3: live preview segment ───────────────────────────────────────────
	if apr and cx then
		local ax, az = apr[1], apr[2]
		local bx, bz = cx, cz
		local dx, dz = bx - ax, bz - az
		local totalD = (dx * dx + dz * dz) ^ 0.5
		if totalD > 0.1 then
			local seg = SEG_DASH
			local nSeg = math.max(1, floor(totalD / (seg * 2)))
			glLineWidth(4)
			glColor(0, 0, 0, 0.32)
			glBeginEnd(GL.LINES, function()
				for i = 0, nSeg - 1 do
					local t0 = (i * 2 * seg) / totalD
					local t1 = math.min(1.0, ((i * 2 + 1) * seg) / totalD)
					local sx0, sz0 = ax + dx * t0, az + dz * t0
					local sx1, sz1 = ax + dx * t1, az + dz * t1
					glVertex(sx0, GetGroundHeight(sx0, sz0) + BUMP, sz0)
					glVertex(sx1, GetGroundHeight(sx1, sz1) + BUMP, sz1)
				end
			end)
			glLineWidth(2)
			glColor(LR, LG, LB, 0.65)
			glBeginEnd(GL.LINES, function()
				for i = 0, nSeg - 1 do
					local t0 = (i * 2 * seg) / totalD
					local t1 = math.min(1.0, ((i * 2 + 1) * seg) / totalD)
					local sx0, sz0 = ax + dx * t0, az + dz * t0
					local sx1, sz1 = ax + dx * t1, az + dz * t1
					glVertex(sx0, GetGroundHeight(sx0, sz0) + BUMP, sz0)
					glVertex(sx1, GetGroundHeight(sx1, sz1) + BUMP, sz1)
				end
			end)
		end
		drawEndpoint(bx, bz, true)
	end

	-- ── Pass 3-sym: mirror copies of live preview segment ─────────────────────
	if apr and cx and extraState.symmetryActive then
		local asyms = extraState.getSymmetricPositions(apr[1], apr[2], 0)
		local csyms = extraState.getSymmetricPositions(cx, cz, 0)
		for k = 2, #asyms do
			local mAx, mAz = asyms[k].x, asyms[k].z
			local mBx, mBz = csyms[k].x, csyms[k].z
			glLineWidth(2)
			glColor(LR, LG, LB, 0.35)
			glBeginEnd(GL.LINES, function() dashedSegVerts(mAx, mAz, mBx, mBz) end)
			local py = GetGroundHeight(mBx, mBz) + BUMP
			glLineWidth(2)
			glColor(LR, LG, LB, 0.35)
			glDrawGroundCircle(mBx, py, mBz, 10, 20)
		end
	end

	glColor(1, 1, 1, 1)
	glLineWidth(1)
	glPolygonOffset(0, 0)
	gl.DepthTest(true)
end

-- Format a distance for display: "NNN el  /  N.NN km"
function extraState.measureFmtDist(elmos)
	local km = elmos / extraState.MEASURE_KM_SCALE
	if km >= 1.0 then
		return string.format("%.0f el  /  %.2f km", elmos, km)
	else
		return string.format("%.0f el  /  %.0f m", elmos, km * 1000)
	end
end

-- Snaps a world point to horizontal or vertical from the reference point (Shift).
function extraState.measureShiftSnap(refX, refZ, wx, wz)
	local dx, dz = wx - refX, wz - refZ
	if abs(dx) >= abs(dz) then
		return wx, refZ
	else
		return refX, wz
	end
end

-- ─── Spline (quadratic Bezier) helpers ────────────────────────────────────────
-- Evaluate quadratic Bezier at parameter t: A → handle H → B
extraState.bezierEval = function(t, ax, az, hx, hz, bx, bz)
	local mt = 1.0 - t
	return mt*mt*ax + 2*mt*t*hx + t*t*bx,
	       mt*mt*az + 2*mt*t*hz + t*t*bz
end

-- Approximate arc length of quadratic Bezier by N-step sampling
extraState.bezierArcLen = function(ax, az, hx, hz, bx, bz, N)
	N = N or 32
	local len, px, pz = 0, ax, az
	for i = 1, N do
		local t = i / N
		local mt = 1 - t
		local qx = mt*mt*ax + 2*mt*t*hx + t*t*bx
		local qz = mt*mt*az + 2*mt*t*hz + t*t*bz
		local ddx, ddz = qx - px, qz - pz
		len = len + (ddx*ddx + ddz*ddz)^0.5
		px, pz = qx, qz
	end
	return len
end

-- Closest point on quadratic Bezier to (px,pz). Returns cx, cz, bestDistSq.
extraState.closestOnBezier = function(px, pz, ax, az, hx, hz, bx, bz)
	local N = 32
	local bestDSq = math.huge
	local bestCx, bestCz = ax, az
	for i = 0, N do
		local t = i / N
		local mt = 1 - t
		local cx = mt*mt*ax + 2*mt*t*hx + t*t*bx
		local cz = mt*mt*az + 2*mt*t*hz + t*t*bz
		local ddx, ddz = px - cx, pz - cz
		local dSq = ddx*ddx + ddz*ddz
		if dSq < bestDSq then bestDSq = dSq; bestCx = cx; bestCz = cz end
	end
	return bestCx, bestCz, bestDSq
end

-- Screen-space search for the nearest committed handle. Returns {chain=c,seg=s} or nil.
extraState.measureFindNearHandle = function(sx, sy)
	local ms   = extraState.measureLines
	local SNAP = extraState.MEASURE_SNAP_PX * 1.8
	local best, bestD = nil, SNAP * SNAP
	for ci = 1, #ms do
		local chain = ms[ci]
		if chain and chain.handles then
			for si, h in pairs(chain.handles) do
				local wy = GetGroundHeight(h[1], h[2])
				local ex, ey = Spring.WorldToScreenCoords(h[1], wy, h[2])
				if ex then
					local ddx, ddy = sx - ex, sy - ey
					local dd = ddx*ddx + ddy*ddy
					if dd < bestD then bestD = dd; best = {chain = ci, seg = si} end
				end
			end
		end
	end
	return best
end

-- Screen-space search for a segment body (no handle yet) close to cursor.
-- Returns {chain=c, seg=s, wx=w, wz=z} projected onto the segment, or nil.
extraState.measureFindNearSegMid = function(sx, sy)
	local ms   = extraState.measureLines
	local SNPX = extraState.MEASURE_SNAP_PX * 2.5
	local best, bestD = nil, SNPX * SNPX
	for ci = 1, #ms do
		local chain = ms[ci]
		if chain then
			local pts = chain.pts
			local hs  = chain.handles or {}
			for si = 1, #pts - 1 do
				if not hs[si] then
					local ax, az = pts[si][1], pts[si][2]
					local bx, bz = pts[si+1][1], pts[si+1][2]
					local ay = GetGroundHeight(ax, az)
					local by = GetGroundHeight(bx, bz)
					local eax, eay = Spring.WorldToScreenCoords(ax, ay, az)
					local ebx, eby = Spring.WorldToScreenCoords(bx, by, bz)
					if eax and ebx then
						local sdx, sdz = ebx - eax, eby - eay
						local lenSq = sdx*sdx + sdz*sdz
						if lenSq > 16 then
							local t = ((sx-eax)*sdx + (sy-eay)*sdz) / lenSq
							if t >= 0.1 and t <= 0.9 then
								local cpx = eax + sdx*t
								local cpy = eay + sdz*t
								local ddx, ddy = sx - cpx, sy - cpy
								local dd = ddx*ddx + ddy*ddy
								if dd < bestD then
									bestD = dd
									best = {chain=ci, seg=si,
									        wx = ax + (bx-ax)*t,
									        wz = az + (bz-az)*t}
								end
							end
						end
					end
				end
			end
		end
	end
	return best
end

-- Returns the index of the nearest chain within snap distance of any segment (straight or Bezier).
-- Used for RMB chain deletion.
extraState.measureFindNearChain = function(sx, sy)
	local ms   = extraState.measureLines
	local SNPX = extraState.MEASURE_SNAP_PX * 2.5
	local best, bestD = nil, SNPX * SNPX
	for ci = 1, #ms do
		local chain = ms[ci]
		if chain then
			local pts = chain.pts
			local hs  = chain.handles or {}
			for si = 1, #pts - 1 do
				local ax, az = pts[si][1], pts[si][2]
				local bx, bz = pts[si+1][1], pts[si+1][2]
				local h = hs[si]
				if h then
					local hx, hz = h[1], h[2]
					local prevSx, prevSy
					for ti = 0, 8 do
						local t   = ti / 8
						local ex, ez = extraState.bezierEval(t, ax, az, hx, hz, bx, bz)
						local ey = GetGroundHeight(ex, ez)
						local scx, scy = Spring.WorldToScreenCoords(ex, ey, ez)
						if scx then
							if prevSx then
								local sdx = scx - prevSx
								local sdz = scy - prevSy
								local lenSq = sdx*sdx + sdz*sdz
								if lenSq > 4 then
									local t2 = ((sx-prevSx)*sdx + (sy-prevSy)*sdz) / lenSq
									if t2 >= 0 and t2 <= 1 then
										local cpx = prevSx + sdx*t2
										local cpy = prevSy + sdz*t2
										local dd = (sx-cpx)*(sx-cpx) + (sy-cpy)*(sy-cpy)
										if dd < bestD then bestD = dd; best = ci end
									end
								end
							end
							prevSx, prevSy = scx, scy
						end
					end
				else
					local ay = GetGroundHeight(ax, az)
					local by = GetGroundHeight(bx, bz)
					local eax, eay = Spring.WorldToScreenCoords(ax, ay, az)
					local ebx, eby = Spring.WorldToScreenCoords(bx, by, bz)
					if eax and ebx then
						local sdx = ebx - eax
						local sdz = eby - eay
						local lenSq = sdx*sdx + sdz*sdz
						if lenSq > 4 then
							local t = ((sx-eax)*sdx + (sy-eay)*sdz) / lenSq
							if t >= 0.05 and t <= 0.95 then
								local cpx = eax + sdx*t
								local cpy = eay + sdz*t
								local dd = (sx-cpx)*(sx-cpx) + (sy-cpy)*(sy-cpy)
								if dd < bestD then bestD = dd; best = ci end
							end
						end
					end
				end
			end
		end
	end
	return best
end

-- Record a brush stroke parametrically relative to the nearest measure line segment.
-- Called each time a ruler-mode+sticky-mode brush stroke is applied.
extraState.recordLinkedStroke = function(wx, wz, dir, rad, shape, rot, curve, fhStr, capMin, capMax, intensStr, lenStr, clayStr, djStr, opStr, instStr, ringStr)
	local lines = extraState.measureLines
	if not lines or #lines == 0 then return end
	local bestDist = 200 * 200  -- max 200 world units off-line to record
	local bestCi, bestSi, bestT, bestCx, bestCz = nil, nil, nil, nil, nil
	for ci = 1, #lines do
		local chain = lines[ci]
		if chain then
			local pts = chain.pts
			local hs  = chain.handles or {}
			for si = 1, #pts - 1 do
				local ax, az = pts[si][1], pts[si][2]
				local bx, bz = pts[si+1][1], pts[si+1][2]
				local h = hs[si]
				if h then
					local hx, hz = h[1], h[2]
					for k = 0, 32 do
						local kt = k / 32
						local ex, ez = extraState.bezierEval(kt, ax, az, hx, hz, bx, bz)
						local ddx, ddz = wx - ex, wz - ez
						local dd = ddx*ddx + ddz*ddz
						if dd < bestDist then
							bestDist = dd
							bestCi, bestSi, bestT = ci, si, kt
							bestCx, bestCz = ex, ez
						end
					end
				else
					local dx, dz = bx - ax, bz - az
					local lenSq = dx*dx + dz*dz
					local kt = 0
					if lenSq > 0 then
						kt = max(0, min(1, ((wx-ax)*dx + (wz-az)*dz) / lenSq))
					end
					local cx, cz = ax + dx*kt, az + dz*kt
					local ddx, ddz = wx - cx, wz - cz
					local dd = ddx*ddx + ddz*ddz
					if dd < bestDist then
						bestDist = dd
						bestCi, bestSi, bestT = ci, si, kt
						bestCx, bestCz = cx, cz
					end
				end
			end
		end
	end
	if bestCi then
		local strokes = extraState.linkedStrokes
		strokes[#strokes + 1] = {
			ci=bestCi, si=bestSi, t=bestT, perpX=wx-bestCx, perpZ=wz-bestCz,
			dir=dir, rad=rad, shape=shape, rot=rot, curve=curve, fhStr=fhStr,
			capMin=capMin, capMax=capMax, intensStr=intensStr,
			lenStr=lenStr, clayStr=clayStr, djStr=djStr, opStr=opStr,
			instStr=instStr, ringStr=ringStr,
		}
	end
end

-- Undo the last linked-stroke group, then re-apply all recorded strokes at their
-- new parametric positions (following spline geometry changes in sticky mode).
-- Both phases are frame-batched to avoid hitting the bandwidth limit.
-- Phase 1: undo N entries per frame.  Phase 2: apply N strokes per frame.
extraState.replayLinkedStrokes = function()
	local strokes = extraState.linkedStrokes
	if not strokes or #strokes == 0 then return end
	-- Cancel any in-progress queue
	extraState.replayQueue = nil
	-- Compute actual undo count from gadget-reported stack depth.
	-- This is always correct regardless of merges, auto-splits, or evictions.
	local baseline = extraState.stickyUndoBaseline or 0
	local undoNeeded = (extraState.gadgetUndoCount or 0) - baseline
	if undoNeeded < 0 then undoNeeded = 0 end
	extraState.linkedStrokeGroupCount = undoNeeded
	-- Start undo phase (batched across frames)
	extraState.replayQueue = {
		phase = "undo",
		remaining = undoNeeded,
		idx = 1,
	}
end

-- Process one tick of the replay queue. Returns true if work was done.
extraState.replayQueueTick = function()
	local q = extraState.replayQueue
	if not q then return false end

	if q.phase == "undo" then
		if q.remaining <= 0 then
			-- Wait one tick for gadget feedback to arrive before applying
			q.phase = "sync"
			return true
		end
		SendLuaRulesMsg(MSG.UNDO)
		q.remaining = q.remaining - 1
		return true
	end

	if q.phase == "sync" then
		-- Snap baseline to actual post-undo depth (handles eviction/drift)
		extraState.stickyUndoBaseline = extraState.gadgetUndoCount or 0
		q.phase = "apply"
		return true
	end

	-- phase == "apply"
	local strokes = extraState.linkedStrokes
	if not strokes or q.idx > #strokes then
		extraState.replayQueue = nil
		return false
	end
	local s = strokes[q.idx]
	local lines = extraState.measureLines
	local chain = lines and lines[s.ci]
	if chain then
		local pts = chain.pts
		local hs  = chain.handles or {}
		local a   = pts[s.si]
		local b   = pts[s.si + 1]
		if a and b then
			local t = s.t
			local wx, wz
			local h = hs[s.si]
			if h then
				wx, wz = extraState.bezierEval(t, a[1], a[2], h[1], h[2], b[1], b[2])
			else
				wx = a[1] + (b[1] - a[1]) * t
				wz = a[2] + (b[2] - a[2]) * t
			end
			wx = wx + s.perpX
			wz = wz + s.perpZ
			-- Per-position batching: each symmetric copy gets its own merge
			local positions = extraState.getSymmetricPositions(wx, wz, s.rot)
			local isFlipped  = extraState.symmetryFlipped
			for j = 1, #positions do
				local p   = positions[j]
				local dir = (isFlipped and j > 1) and -s.dir or s.dir
				local msg = MSG.BRUSH
					.. dir .. " "
					.. floor(p.x) .. " "
					.. floor(p.z) .. " "
					.. s.rad .. " "
					.. s.shape .. " "
					.. p.rot .. " "
					.. s.curve .. " "
					.. s.capMin .. " "
					.. s.capMax .. " "
					.. s.intensStr .. " "
					.. s.lenStr .. " "
					.. s.clayStr .. " "
					.. s.djStr .. " "
					.. s.opStr .. " "
					.. s.instStr .. " "
					.. s.fhStr .. " "
					.. s.ringStr
				SendLuaRulesMsg(msg)
				afterBrushTick()
			end
		end
	end
	q.idx = q.idx + 1
	return true
end

-- Snaps a world point to the nearest measure-line segment (straight or Bezier curve).
-- Returns the snapped position (or the original if no segment is close enough).
function extraState.snapToMeasureLine(x, z)
	local lines = extraState.measureLines
	if not lines or #lines == 0 then return x, z end
	local snapRad = activeRadius * 1.5 + 32
	local threshSq = snapRad * snapRad
	local bestDist = threshSq
	local bestX, bestZ = x, z
	for i = 1, #lines do
		local chain = lines[i]
		if chain and chain.pts then
			local pts = chain.pts
			local hs  = chain.handles or {}
			for j = 1, #pts - 1 do
				local ax, az = pts[j][1], pts[j][2]
				local bx, bz = pts[j+1][1], pts[j+1][2]
				if hs[j] then
					local cx2, cz2, dSq = extraState.closestOnBezier(x, z, ax, az, hs[j][1], hs[j][2], bx, bz)
					if dSq < bestDist then bestDist = dSq; bestX = cx2; bestZ = cz2 end
				else
					local dx, dz = bx - ax, bz - az
					local lenSq = dx*dx + dz*dz
					if lenSq > 0.01 then
						local t = ((x-ax)*dx + (z-az)*dz) / lenSq
						if t < 0 then t = 0 elseif t > 1 then t = 1 end
						local cx = ax + t*dx
						local cz = az + t*dz
						local distSq = (x-cx)*(x-cx) + (z-cz)*(z-cz)
						if distSq < bestDist then bestDist = distSq; bestX = cx; bestZ = cz end
					end
				end
			end
		end
	end
	return bestX, bestZ
end

-- Returns {chain=i, pt=j} for the endpoint nearest to (sx,sy) in screen space,
-- or nil if none is within MEASURE_SNAP_PX pixels.
function extraState.measureFindNearEndpoint(sx, sy)
	local ms    = extraState.measureLines
	local best  = nil
	local bestD = extraState.MEASURE_SNAP_PX * extraState.MEASURE_SNAP_PX
	for ci = 1, #ms do
		local pts = ms[ci].pts
		for pi = 1, #pts do
			local wx, wz = pts[pi][1], pts[pi][2]
			local wy = GetGroundHeight(wx, wz)
			local ex, ey = Spring.WorldToScreenCoords(wx, wy, wz)
			if ex then
				local ddx, ddy = sx - ex, sy - ey
				local dd = ddx * ddx + ddy * ddy
				if dd < bestD then bestD = dd; best = {chain = ci, pt = pi} end
			end
		end
	end
	return best
end

function widget:DrawScreen()
	if pendingExport then
		pendingExport = false
		doExportHeightmap()
	end
	if pendingImportFile then
		doImportHeightmapRead()
	end
	if importHeightRows then
		doImportHeightmapSend()
	end
	-- Height colormap contour labels: height values at topo-line / brush-edge intersections
	if extraState.heightColormap and extraState.colormapLabels then
		for _, lbl in ipairs(extraState.colormapLabels) do
			local sx, sy = Spring.WorldToScreenCoords(lbl[1], lbl[2] + 5, lbl[3])
			if sx then
				-- Highlight label when its contour is hovered in height-sampling mode
				if extraState.heightSamplingMode and extraState.colormapHoverContour
				   and lbl[8] and abs(lbl[8] - extraState.colormapHoverContour) < 0.01 then
					glColor(0, 0, 0, 0.92)
					gl.Text(lbl[4], sx + 2, sy - 2, 26, "co")
					glColor(1.0, 0.95, 0.2, 1.0)
					gl.Text(lbl[4], sx, sy, 26, "co")
				else
					glColor(0, 0, 0, 0.85)
					gl.Text(lbl[4], sx + 2, sy - 2, 22, "co")
					glColor(lbl[5], lbl[6], lbl[7], 1.0)
					gl.Text(lbl[4], sx, sy, 22, "co")
				end
			end
		end
		glColor(1, 1, 1, 1)
	end
	if extraState.heightColormap and extraState.colormapPeak then
		local pk = extraState.colormapPeak
		local sx, sy = Spring.WorldToScreenCoords(pk[1], pk[2] + 8, pk[3])
		if sx then
			-- cast shadow: dark offset slightly right and down
			glColor(0, 0, 0, 0.92)
			gl.Text(pk[4], sx + 2, sy - 2, 28, "co")
			-- In height-sampling mode: brighten + enlarge the label when hovered
			if extraState.heightSamplingMode and extraState.colormapHoverPeak then
				glColor(1.0, 0.85, 0.15, 1.0)
				gl.Text(pk[4], sx, sy, 34, "co")
			else
				-- main label: crisp white
				glColor(1, 1, 1, 1.0)
				gl.Text(pk[4], sx, sy, 28, "co")
			end
		end
		glColor(1, 1, 1, 1)
	end

	-- Protractor degree labels: dim text at each spoke tip
	if extraState.angleSnap and extraState.protractorCursorX then
		local cx    = extraState.protractorCursorX
		local cz    = extraState.protractorCursorZ
		local slen  = extraState.protractorSpokeLen * 0.88  -- slightly inside tip
		local pstep = extraState.protractorStep
		local hiAng = extraState.protractorHighlight
		local numSp = floor(360 / pstep)
		for si = 0, numSp - 1 do
			local angleDeg = si * pstep
			local rad      = angleDeg * pi / 180
			local tipX = cx + cos(rad) * slen
			local tipZ = cz + sin(rad) * slen
			local tipY = GetGroundHeight(tipX, tipZ) + 4
			local sx, sy = Spring.WorldToScreenCoords(tipX, tipY, tipZ)
			if sx then
				local lbl = tostring(angleDeg)
				if angleDeg == hiAng then
					-- Highlighted spoke: bright, large
					glColor(0, 0, 0, 0.85)
					gl.Text(lbl, sx + 1, sy - 1, 26, "co")
					glColor(1.0, 1.0, 0.4, 1.0)
					gl.Text(lbl, sx, sy, 26, "co")
				else
					-- Reference spoke label
					glColor(0, 0, 0, 0.75)
					gl.Text(lbl, sx + 1, sy - 1, 20, "co")
					glColor(1.0, 0.92, 0.3, 0.82)
					gl.Text(lbl, sx, sy, 20, "co")
				end
			end
		end
		glColor(1, 1, 1, 1)
	end

	-- Measure tool distance labels drawn via DrawScreenEffects (works in F5 mode too)
end

-- ─── Unmouse: park brush beside the terraform UI panel ─────────────────────
-- Computes the parked world position when the mouse is over the UI panel.
-- Returns (newWorldX, newWorldZ), possibly unchanged when not hovering.

-- Helper: find a valid on-terrain world position to park the brush.
-- Tries screen centre first; if the panel covers it, tries left then right quarter.
extraState.computeUnmouseTarget = function(bounds)
	local vsx, vsy = Spring.GetViewGeometry()
	local brushSpan = activeRadius * math.max(1.0, activeLengthScale) + 70
	local midY = math.floor(vsy * 0.5)
	local candidates = {
		math.floor(vsx * 0.5),            -- centre
		math.floor(vsx * 0.25),           -- left quarter
		math.floor(vsx * 0.75),           -- right quarter
	}
	for _, sx in ipairs(candidates) do
		-- Skip if this candidate falls inside the panel
		if not (sx >= bounds.left - brushSpan and sx <= bounds.right + brushSpan) then
			local _, pos = TraceScreenRay(sx, midY, true)
			if pos then return pos[1], pos[3] end
		end
	end
	-- All preferred spots blocked — just use raw centre regardless
	local _, pos = TraceScreenRay(math.floor(vsx * 0.5), midY, true)
	return pos and pos[1] or nil, pos and pos[3] or nil
end

extraState.applyUnmouse = function(worldX, worldZ)
	-- Never reposition while actively painting (brush locked to drag plane)
	if lockedWorldX then
		extraState.unmouseActive = false
		extraState.unmouseAnimT  = math.max(0, extraState.unmouseAnimT - 0.15)
		if extraState.unmouseAnimT <= 0 then return worldX, worldZ end
		local t = extraState.unmouseAnimT
		t = t * t * (3 - 2 * t)
		return extraState.unmouseFromX + (extraState.unmouseToX - extraState.unmouseFromX) * t,
		       extraState.unmouseFromZ + (extraState.unmouseToZ - extraState.unmouseFromZ) * t
	end
	local tfUI = WG.TerraformBrushUI
	if not tfUI or not tfUI.getPanelBounds then
		extraState.unmouseAnimT  = 0
		extraState.unmouseActive = false
		return worldX, worldZ
	end
	local bounds = tfUI.getPanelBounds()
	if not bounds then
		extraState.unmouseAnimT  = 0
		extraState.unmouseActive = false
		return worldX, worldZ
	end
	local mx, my = GetMouseState()
	local overPanel = mx >= bounds.left and mx <= bounds.right
	                  and my >= bounds.bottomY and my <= bounds.topY
	local now = Spring.GetTimer()
	local dt  = extraState.unmouseLastTime
	           and math.min(0.1, Spring.DiffTimers(now, extraState.unmouseLastTime)) or 0
	extraState.unmouseLastTime = now
	if overPanel then
		local curSpan = activeRadius * math.max(1.0, activeLengthScale)
		local spanChanged = abs(curSpan - extraState.unmouseLastSpan) > 12
		if not extraState.unmouseActive or spanChanged then
			-- First entry or brush resized: compute new target, animate from current pos
			if extraState.unmouseActive and spanChanged then
				-- Already parked: slide from current interpolated position
				local tc = extraState.unmouseAnimT
				tc = tc * tc * (3 - 2 * tc)
				extraState.unmouseFromX = extraState.unmouseFromX + (extraState.unmouseToX - extraState.unmouseFromX) * tc
				extraState.unmouseFromZ = extraState.unmouseFromZ + (extraState.unmouseToZ - extraState.unmouseFromZ) * tc
				extraState.unmouseAnimT = 0
			else
				extraState.unmouseFromX = worldX
				extraState.unmouseFromZ = worldZ
			end
			extraState.unmouseActive   = true
			extraState.unmouseLastSpan = curSpan
			local tx, tz = extraState.computeUnmouseTarget(bounds)
			extraState.unmouseToX = tx or extraState.unmouseFromX
			extraState.unmouseToZ = tz or extraState.unmouseFromZ
		end
		extraState.unmouseAnimT = math.min(1, extraState.unmouseAnimT + dt * 7)
	else
		extraState.unmouseActive = false
		extraState.unmouseAnimT  = math.max(0, extraState.unmouseAnimT - dt * 7)
	end
	if extraState.unmouseAnimT <= 0 then return worldX, worldZ end
	local t = extraState.unmouseAnimT
	t = t * t * (3 - 2 * t)
	return extraState.unmouseFromX + (extraState.unmouseToX - extraState.unmouseFromX) * t,
	       extraState.unmouseFromZ + (extraState.unmouseToZ - extraState.unmouseFromZ) * t
end

-- Draws a gentle extra outline pulse when brush is parked beside the UI panel.
-- Called from DrawWorld (zero new locals added there).
extraState.doUnmouseDraw = function(worldX, worldZ, groundY)
	local animT = extraState.unmouseAnimT
	if animT <= 0.03 or activeMode == "ramp" then return end
	if not extraState.unmouseActive then return end
	local drawFrame = GetDrawFrame()
	local pulseT = (drawFrame % 75) / 75.0
	local pulse  = 0.5 + 0.5 * sin(pulseT * 2 * pi)
	local smoothT = animT * animT * (3 - 2 * animT)
	glLineWidth(9)
	glColor(1, 1, 1, smoothT * pulse * 0.13)
	extraState.drawCurrentOutline(worldX, worldZ, groundY)
	glLineWidth(3)
	glColor(1, 1, 1, smoothT * pulse * 0.22)
	extraState.drawCurrentOutline(worldX, worldZ, groundY)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

extraState.doUnmouseScreenFx = function() end  -- intentionally empty
-- ─────────────────────────────────────────────────────────────────────────────

-- Draws measure distance labels. Called from both DrawScreen (normal) and
-- DrawScreenEffects (F5 / hidden-UI mode) so they always show.
function extraState.drawMeasureLabels()
	if not extraState.measureActive then return end
	if not extraState.measureShowLength then return end
	-- Guard against GL state bleed (e.g. from colormap FBO render leaving depth test on)
	gl.DepthTest(false)
	glColor(1, 1, 1, 1)
	local ms  = extraState.measureLines
	local apr = extraState.measureActivePt
	local cx  = extraState.measureCursorX
	local cz  = extraState.measureCursorZ
	local SZ  = 24  -- font size (dp)

	-- h = spline handle {x,z} or nil for straight
	local function labelSeg(ax, az, bx, bz, h)
		local midX, midZ, d
		if h then
			d = extraState.bezierArcLen(ax, az, h[1], h[2], bx, bz)
			midX = 0.25*ax + 0.5*h[1] + 0.25*bx
			midZ = 0.25*az + 0.5*h[2] + 0.25*bz
		else
			local dx2, dz2 = bx - ax, bz - az
			d = (dx2 * dx2 + dz2 * dz2) ^ 0.5
			midX = (ax + bx) * 0.5
			midZ = (az + bz) * 0.5
		end
		local midY = GetGroundHeight(midX, midZ) + 6
		local sx, sy = Spring.WorldToScreenCoords(midX, midY, midZ)
		if not sx then return end
		local txt = extraState.measureFmtDist(d)
		glColor(0, 0, 0, 0.92)
		gl.Text(txt, sx + 1, sy + 13, SZ, "co")
		glColor(1.0, 1.0, 1.0, 1.0)
		gl.Text(txt, sx, sy + 14, SZ, "co")
	end

	for ci = 1, #ms do
		local chain = ms[ci]
		local pts = chain.pts
		local hs  = chain.handles or {}
		for i = 1, #pts - 1 do
			labelSeg(pts[i][1], pts[i][2], pts[i+1][1], pts[i+1][2], hs[i])
		end
	end
	-- live preview label (always straight, no handle on pending segment)
	if apr and cx then
		labelSeg(apr[1], apr[2], cx, cz, nil)
	end
	glColor(1, 1, 1, 1)
end

-- DrawScreenEffects is NOT suppressed by F5 (IsGUIHidden), so measure labels
-- always appear even when the full UI is hidden.
function widget:DrawScreenEffects()
	extraState.drawMeasureLabels()
	-- Unmouse: amber arrow pointing from parked brush toward real cursor (over panel)
	extraState.doUnmouseScreenFx()
	-- D5: cursor-anchored parameter feedback HUD
	if extraState.paramHudText and extraState.paramHudTimer > 0 then
		local fadeIn  = min(1.0, (1.5 - extraState.paramHudTimer) / 0.15)
		local fadeOut = min(1.0, extraState.paramHudTimer / 0.35)
		local alpha   = min(fadeIn, fadeOut)
		local mx, my = GetMouseState()
		local hx, hy = mx + 20, my + 6
		gl.DepthTest(false)
		glColor(0, 0, 0, alpha * 0.88)
		gl.Text(extraState.paramHudText, hx + 1, hy - 1, 22, "")
		glColor(1, 1, 1, alpha)
		gl.Text(extraState.paramHudText, hx, hy, 22, "")
		glColor(1, 1, 1, 1)
	end
	-- G8: future hook — overlay cursor graphics here when custom artwork is added
end

-- Protractor spokes overlay: reusable across terraform / metal / grass / feature placer.
-- Draws angle-step spokes radiating from (cx, cz) plus a highlighted snap axis.
-- Also updates activeRotation to the highlighted spoke so paint ops pick it up.
extraState.drawProtractorOverlay = function(cx, cz, radius)
	local step      = extraState.angleSnapStep
	if not step or step <= 0 then return end
	local spokeLen  = (radius or 100) * 1.85
	local activeLen = (radius or 100) * 2.3
	local numSpokes = floor(360 / step)
	local BUMP = 4
	local SEGS = 14

	-- Determine which spoke to highlight
	local highlightAngle
	if extraState.angleSnapAuto then
		local nearest = floor(activeRotation / step + 0.5) % numSpokes
		highlightAngle = nearest * step
		activeRotation = highlightAngle
	else
		local idx = (extraState.angleSnapManualSpoke or 0) % numSpokes
		highlightAngle = idx * step
		activeRotation = highlightAngle
	end

	local function drawSpoke(rad, len)
		local dx = cos(rad) * (len / SEGS)
		local dz = sin(rad) * (len / SEGS)
		glBeginEnd(GL.LINE_STRIP, function()
			for s = 0, SEGS do
				local sx = cx + dx * s
				local sz = cz + dz * s
				glVertex(sx, GetGroundHeight(sx, sz) + BUMP, sz)
			end
		end)
	end
	local function drawBiSpoke(rad, len)
		local dx = cos(rad) * (len / SEGS)
		local dz = sin(rad) * (len / SEGS)
		glBeginEnd(GL.LINE_STRIP, function()
			for s = -SEGS, SEGS do
				local sx = cx + dx * s
				local sz = cz + dz * s
				glVertex(sx, GetGroundHeight(sx, sz) + BUMP, sz)
			end
		end)
	end

	extraState.protractorCursorX  = cx
	extraState.protractorCursorZ  = cz
	extraState.protractorSpokeLen = spokeLen
	extraState.protractorStep     = step
	extraState.protractorHighlight = highlightAngle

	glPolygonOffset(-1, -1)
	glLineWidth(1)
	glColor(1.0, 0.92, 0.25, 0.22)
	for si = 0, numSpokes - 1 do
		local angleDeg = si * step
		if angleDeg ~= highlightAngle then
			drawSpoke(angleDeg * pi / 180, spokeLen)
		end
	end
	local aRad = highlightAngle * pi / 180
	glLineWidth(9)
	glColor(1.0, 0.88, 0.1, 0.12)
	drawBiSpoke(aRad, activeLen)
	glLineWidth(5)
	glColor(1.0, 0.88, 0.1, 0.40)
	drawBiSpoke(aRad, activeLen)
	glLineWidth(2)
	glColor(1.0, 1.0, 0.6, 1.0)
	drawBiSpoke(aRad, activeLen)
	glLineWidth(1)
	glColor(1, 1, 1, 1)
	glPolygonOffset(0, 0)
end

function widget:DrawWorld()
	if tessellationDirtyFrames > 0 then
		ForceTesselationUpdate(true)
		tessellationDirtyFrames = tessellationDirtyFrames - 1
	end

	-- Full-map grid overlay: visible across the whole map regardless of brush active state
	if gridOverlay then
		if extraState.gridDirty or not extraState.gridDL then
			extraState.buildFullMapGrid()
		end
		glCallList(extraState.gridDL)
	end

	if not activeMode then
		invalidateDrawCache()
		hideBuildGrid()
		-- Measure tool runs independently of terraform mode
		if extraState.measureActive then
			local mx2, mz2 = getWorldMousePosition()
			-- Hover detection: when drawing, check endpoints, handles, segment bodies
			extraState.measureHoverNear   = nil
			extraState.measureHoverHandle = nil
			extraState.measureHoverMidSeg = nil
			if extraState.measureDrawing then
				local smx, smy = Spring.GetMouseState()
				extraState.measureHoverNear = extraState.measureFindNearEndpoint(smx, smy)
				if extraState.measureHoverNear then
					Spring.SetMouseCursor("Move")
				else
					extraState.measureHoverHandle = extraState.measureFindNearHandle(smx, smy)
					if extraState.measureHoverHandle then
						Spring.SetMouseCursor("Move")
					else
						extraState.measureHoverMidSeg = extraState.measureFindNearSegMid(smx, smy)
					end
				end
			end
			if mx2 then
				local _, _, _, shiftHeld = GetModKeyState()
				if shiftHeld and extraState.measureActivePt then
					mx2, mz2 = extraState.measureShiftSnap(
						extraState.measureActivePt[1], extraState.measureActivePt[2], mx2, mz2)
				end
			end
			-- Suppress live preview when hovering a point (hides preview line + label)
			extraState.measureCursorX = extraState.measureHoverNear and nil or mx2
			extraState.measureCursorZ = extraState.measureHoverNear and nil or mz2
			extraState.drawMeasureWorld()
		end
		-- Height colormap overlay: works when feature placer or other tools are active
		if extraState.heightColormap then
			local fpState = WG.FeaturePlacer and WG.FeaturePlacer.getState()
			if fpState and fpState.active then
				local wx, wz = getWorldMousePosition()
				if wx then
					extraState.drawHeightColormap(wx, wz, fpState.radius or 200, fpState.shape or "circle", fpState.rotation or 0, 1.0)
				end
			else
				local mbState = WG.MetalBrush and WG.MetalBrush.getState()
				local gbState = WG.GrassBrush and WG.GrassBrush.getState()
				local spState = WG.SplatPainter and WG.SplatPainter.getState()
				if (mbState and mbState.active) or (gbState and gbState.active) then
					local wx, wz = getWorldMousePosition()
					if wx then
						extraState.drawHeightColormap(wx, wz, activeRadius, activeShape, activeRotation, activeLengthScale)
					end
				elseif spState and spState.active then
					local wx, wz = getWorldMousePosition()
					if wx then
						extraState.drawHeightColormap(wx, wz, spState.radius or 200, spState.shape or "circle", spState.rotationDeg or 0, 1.0)
					end
				end
			end
		end
		-- Protractor overlay: runs for feature placer / metal / grass when angle snap is on
		if extraState.angleSnap then
			local fpState = WG.FeaturePlacer and WG.FeaturePlacer.getState()
			local mbState = WG.MetalBrush and WG.MetalBrush.getState()
			local gbState = WG.GrassBrush and WG.GrassBrush.getState()
			local spState = WG.SplatPainter and WG.SplatPainter.getState()
			local r
			if fpState and fpState.active then r = fpState.radius or 200
			elseif (mbState and mbState.active) or (gbState and gbState.active) then r = activeRadius
			elseif spState and spState.active then r = spState.radius or 200 end
			if r then
				local wx, wz = getWorldMousePosition()
				if wx then
					extraState.drawProtractorOverlay(wx, wz, r)
				else
					extraState.protractorCursorX = nil
				end
			else
				extraState.protractorCursorX = nil
			end
		else
			extraState.protractorCursorX = nil
		end
		-- Symmetry overlay: works when feature placer or other tools are active
		if extraState.symmetryActive then
			local wx, wz = getWorldMousePosition()
			if wx then
				extraState.symmetryLastWorldX = wx
				extraState.symmetryLastWorldZ = wz
				-- Hover detection for symmetry origin (allows dragging without activeMode)
				extraState.symmetryHoveringOrigin = false
				if not extraState.symmetryPlacingOrigin then
					if extraState.symmetryDraggingOrigin then
						extraState.symmetryOriginX = wx
						extraState.symmetryOriginZ = wz
						Spring.SetMouseCursor("Move")
					else
						local ox, oz = extraState.getSymmetryOrigin()
						local oy = GetGroundHeight(ox, oz)
						local osx, osy = Spring.WorldToScreenCoords(ox, oy, oz)
						local smx, smy = Spring.GetMouseState()
						local sdx, sdy = smx - osx, smy - osy
						if sdx * sdx + sdy * sdy < 20 * 20 then
							extraState.symmetryHoveringOrigin = true
							Spring.SetMouseCursor("Move")
						end
					end
				else
					Spring.SetMouseCursor("Move")
				end
				local gy = Spring.GetGroundHeight(wx, wz) or 0
				extraState.drawSymmetryOverlay(wx, wz, gy)
			elseif extraState.symmetryLastWorldX then
				-- Mouse over UI: keep drawing symmetry lines at last known position
				local gy = Spring.GetGroundHeight(extraState.symmetryLastWorldX, extraState.symmetryLastWorldZ) or 0
				extraState.drawSymmetryOverlay(extraState.symmetryLastWorldX, extraState.symmetryLastWorldZ, gy)
			end
		end
		return
	end

	local worldX, worldZ
	if lockedGroundY then
		-- During active painting, project onto the fixed plane to prevent cursor drift
		worldX, worldZ = getWorldMousePositionOnPlane(lockedGroundY)
	else
		worldX, worldZ = getWorldMousePosition()
	end
	if not worldX then
		-- Mouse over UI: still draw symmetry lines at last known position
		if extraState.symmetryActive and extraState.symmetryLastWorldX then
			local gy = Spring.GetGroundHeight(extraState.symmetryLastWorldX, extraState.symmetryLastWorldZ) or 0
			extraState.drawSymmetryOverlay(extraState.symmetryLastWorldX, extraState.symmetryLastWorldZ, gy)
		end
		return
	end

	-- Unmouse: slide brush to side of terraform UI panel while mouse is over it
	worldX, worldZ = extraState.applyUnmouse(worldX, worldZ)

	-- Cache world position for symmetry overlay when mouse moves over UI
	if extraState.symmetryActive then
		extraState.symmetryLastWorldX = worldX
		extraState.symmetryLastWorldZ = worldZ
	end

	-- Symmetry origin: hover detection + drag update
	extraState.symmetryHoveringOrigin = false
	if extraState.symmetryActive and not extraState.symmetryPlacingOrigin then
		if extraState.symmetryDraggingOrigin then
			-- Continuously move origin to mouse while dragging
			local prevX = extraState.symmetryDragPrevX or worldX
			local prevZ = extraState.symmetryDragPrevZ or worldZ
			extraState.symmetryOriginX = worldX
			extraState.symmetryOriginZ = worldZ
			extraState.symmetryDragPrevX = worldX
			extraState.symmetryDragPrevZ = worldZ
			-- Translate measure lines by the same delta (skip in distort mode)
			if not extraState.measureDistortMode then
				local dx, dz = worldX - prevX, worldZ - prevZ
				if (dx ~= 0 or dz ~= 0) and extraState.measureLines then
					for ci = 1, #extraState.measureLines do
						local chain = extraState.measureLines[ci]
						for pi = 1, #chain.pts do
							chain.pts[pi][1] = chain.pts[pi][1] + dx
							chain.pts[pi][2] = chain.pts[pi][2] + dz
						end
						if chain.handles then
							for si, h in pairs(chain.handles) do
								h[1] = h[1] + dx
								h[2] = h[2] + dz
							end
						end
					end
				end
			end
			Spring.SetMouseCursor("Move")
		else
			-- Check hover: is mouse within screen-space grab radius of origin?
			local ox, oz = extraState.getSymmetryOrigin()
			local oy = GetGroundHeight(ox, oz)
			local osx, osy = Spring.WorldToScreenCoords(ox, oy, oz)
			local smx, smy = Spring.GetMouseState()
			local sdx, sdy = smx - osx, smy - osy
			if sdx * sdx + sdy * sdy < 20 * 20 then
				extraState.symmetryHoveringOrigin = true
				Spring.SetMouseCursor("Move")
			end
		end
	end

	-- Symmetry origin placing mode: show crosshair cursor, skip normal brush
	if extraState.symmetryPlacingOrigin then
		Spring.SetMouseCursor("Move")
	end

	-- G8: set per-mode cursor (replace cursor name in modeCursors table for custom artwork)
	if not extraState.measureDrawing and not extraState.symmetryHoveringOrigin
	   and not extraState.symmetryDraggingOrigin and not extraState.symmetryPlacingOrigin then
		Spring.SetMouseCursor(extraState.modeCursors[activeMode] or "cursornormal")
	end

	-- Track shift key state for axis-lock origin capture
	local _, _, _, shiftHeld = GetModKeyState()
	if shiftHeld and not shiftState.wasHeld then
		shiftState.originX = worldX
		shiftState.originZ = worldZ
		shiftState.axis = nil
	elseif not shiftHeld and shiftState.wasHeld then
		shiftState.originX = nil
		shiftState.originZ = nil
		shiftState.axis = nil
	end
	shiftState.wasHeld = shiftHeld

	-- When protractor is active during a stroke, it owns brush positioning (shift handled inside).
	-- Only use constrainToAxis for shift when protractor is not active.
	if shiftState.originX and shiftHeld and not (extraState.angleSnap and lockedWorldX) then
		worldX, worldZ = constrainToAxis(shiftState.originX, shiftState.originZ, worldX, worldZ)
	end

	-- Snap logic: grid snap (pre-press) hands off to spoke snap (during drag) without fighting
	if extraState.angleSnap and lockedWorldX and dragOriginX then
		-- Mouse is pressed and angle-snap is active: spoke snapping owns brush positioning
		-- (shift-lock handled internally by snapDragToSpoke)
		worldX, worldZ = snapDragToSpoke(worldX, worldZ)
		if extraState.gridSnap or gridOverlay then showBuildGrid() else hideBuildGrid() end
	elseif shiftHeld or extraState.gridSnap then
		-- Pre-press (or no angle-snap): grid snap, rotated to match protractor axis when active
		worldX, worldZ = snapToGrid(worldX, worldZ, extraState.angleSnap and activeRotation or 0)
		showBuildGrid()
	elseif gridOverlay then
		showBuildGrid()
	else
		hideBuildGrid()
	end

	-- Ruler mode: snap brush to nearest measure-line segment when overlay is active
	if extraState.measureActive and extraState.measureRulerMode and not extraState.measureDrawing then
		worldX, worldZ = extraState.snapToMeasureLine(worldX, worldZ)
	end

	local groundY = GetGroundHeight(worldX, worldZ)

	-- Pen pressure visual modulation: temporarily override activeRadius / activeIntensity
	-- so all drawing code (cache, glow, outline) reflects pen state.
	local savedRadius, savedIntensity
	if extraState.penPressureEnabled and extraState.penInContact and not extraState.penOverUI then
		local pm = extraState.penPressureMapped or extraState.penPressure or 0
		local sens = extraState.penPressureSensitivity or 1.0
		if extraState.penPressureModulateIntensity then
			savedIntensity = activeIntensity
			activeIntensity = activeIntensity * (1.0 + pm * sens)
		end
		if extraState.penPressureModulateSize then
			savedRadius = activeRadius
			activeRadius = max(MIN_RADIUS, floor(activeRadius * (1.0 + pm * sens) + 0.5))
		end
	end
	-- Must be called before EVERY return in DrawWorld to restore base values.
	local function penRestoreDraw()
		if savedIntensity then activeIntensity = savedIntensity end
		if savedRadius    then activeRadius    = savedRadius    end
	end

	-- Suppress brush outline when placing/hovering/dragging symmetry origin
	local suppressBrush = extraState.symmetryPlacingOrigin
		or extraState.symmetryDraggingOrigin
		or extraState.symmetryHoveringOrigin

	-- Animated glow outline â€” drawn every frame outside the display-list cache so it can pulse.
	if activeMode and activeMode ~= "ramp" and not suppressBrush then
		local drawFrame = GetDrawFrame()
		local pulseT = (drawFrame % 90) / 90.0
		-- Map intensity (0.1-100) to a 0-1 strength via log scale
		local intFrac = (math.log(activeIntensity + 1) / math.log(101))
		local baseAlpha   = 0.04 + 0.20 * intFrac
		local swingAlpha  = 0.03 + 0.18 * intFrac
		local pulseAlpha = baseAlpha + swingAlpha * sin(pulseT * 2 * pi)
		local mr, mg, mb = getModeRGB()
		-- Outer soft halo
		glLineWidth(11)
		glColor(mr, mg, mb, pulseAlpha * 0.7)
		extraState.drawCurrentOutline(worldX, worldZ, groundY)
		-- Inner sharper halo
		glLineWidth(5)
		glColor(mr, mg, mb, pulseAlpha * 1.6)
		extraState.drawCurrentOutline(worldX, worldZ, groundY)
		glColor(1, 1, 1, 1)
		glLineWidth(1)
	end

	-- Unmouse amber glow + landing ring (only drawn while brush is parked beside UI)
	extraState.doUnmouseDraw(worldX, worldZ, groundY)

	-- Protractor spokes: angle grid radiating from brush center when angle snap is on.
	-- Ramp mode: anchor spokes at the drag origin while dragging so they visibly radiate
	-- from the ramp start point; before press, use the live cursor.
	if extraState.angleSnap then
		local pcx, pcz = worldX, worldZ
		if activeMode == "ramp" and dragOriginX then
			pcx, pcz = dragOriginX, dragOriginZ
		end
		extraState.drawProtractorOverlay(pcx, pcz, activeRadius)
	else
		-- Protractor not active: clear cached position so DrawScreen skips labels
		extraState.protractorCursorX = nil
	end

	-- Symmetry: guide lines + ghost brush cursors (outside cache, every frame)
	extraState.drawSymmetryOverlay(worldX, worldZ, groundY)

	-- Measure tool: also draw when terraform mode is active
	if extraState.measureActive then
		extraState.measureHoverNear   = nil
		extraState.measureHoverHandle = nil
		extraState.measureHoverMidSeg = nil
		if extraState.measureDrawing then
			local smx, smy = Spring.GetMouseState()
			extraState.measureHoverNear = extraState.measureFindNearEndpoint(smx, smy)
			if extraState.measureHoverNear then
				Spring.SetMouseCursor("Move")
				extraState.measureCursorX = nil
				extraState.measureCursorZ = nil
			else
				extraState.measureHoverHandle = extraState.measureFindNearHandle(smx, smy)
				if extraState.measureHoverHandle then
					Spring.SetMouseCursor("Move")
				else
					extraState.measureHoverMidSeg = extraState.measureFindNearSegMid(smx, smy)
				end
				extraState.measureCursorX = worldX
				extraState.measureCursorZ = worldZ
			end
		end
		extraState.drawMeasureWorld()
	end

	-- In measure-drawing mode or symmetry-origin interaction the brush shape is fully hidden
	if extraState.measureActive and extraState.measureDrawing then penRestoreDraw(); return end
	if suppressBrush then penRestoreDraw(); return end

	-- ── Height sampling: hover detection + contour highlight (every frame, outside cache) ──
	-- Delegated to extraState.doSamplingHover so DrawWorld gains no new upvalues.
	extraState.doSamplingHover(groundY)

	-- Spline ramp bypasses the main display-list cache: cursor circle is drawn fresh
	-- each frame (trivially cheap), spline geometry uses a dedicated sub-cache that
	-- only rebuilds when new path points are added or the brush radius changes.
	if activeMode == "ramp" and activeShape == "circle" then
		glColor(0.9, 0.7, 0.2, 0.7)
		glLineWidth(3)
		glDrawGroundCircle(worldX, groundY, worldZ, activeRadius, CIRCLE_SEGMENTS)
		if #rampSplinePoints >= 2 then
			local sc2 = #rampSplinePoints
			local sr = activeRadius
			if extraState.splineCacheCount ~= sc2 or extraState.splineCacheRadius ~= sr then
				extraState.splineCacheCount  = sc2
				extraState.splineCacheRadius = sr
				if extraState.splineCacheList then
					glDeleteList(extraState.splineCacheList)
				end
				-- Build display path: committed positions (stable) + live window
				local sc = extraState.splineCommitted
				local displayPts
				if sc and #sc.pts > 0 then
					displayPts = {}
					for _, p in ipairs(sc.pts) do displayPts[#displayPts + 1] = p end
					local win = extraState.getSmoothedSplineWindow()
					for _, p in ipairs(win) do displayPts[#displayPts + 1] = p end
				else
					displayPts = getSmoothedSpline()
				end
				extraState.splineCacheList = glCreateList(function()
					extraState.drawEx.splineRampPreview(displayPts, sr)
				end)
			end
			if extraState.splineCacheList then
				glCallList(extraState.splineCacheList)
			end
		elseif lockedWorldX then
			extraState.drawEx.rampPreview(lockedWorldX, lockedWorldZ, lockedGroundY, worldX, worldZ, groundY, activeRadius)
		end
		glColor(1, 1, 1, 1)
		glLineWidth(1)
		penRestoreDraw(); return
	end

	-- Reuse cached display list when nothing changed
	if isDrawCacheValid(worldX, worldZ, groundY) then
		glCallList(drawCacheList)
		penRestoreDraw(); return
	end

	invalidateDrawCache()
	drawCacheList = glCreateList(function()
		if activeMode == "ramp" then
			glColor(0.9, 0.7, 0.2, 0.7)
			glLineWidth(3)

			-- Straight ramp preview (non-circle shapes; circle+spline handled above)
			glDrawGroundCircle(worldX, groundY, worldZ, activeRadius, CIRCLE_SEGMENTS)
			if lockedWorldX and rampEndX then
				local endY = GetGroundHeight(rampEndX, rampEndZ)
				extraState.drawEx.rampPreview(lockedWorldX, lockedWorldZ, lockedGroundY, rampEndX, rampEndZ, endY, activeRadius)
			elseif lockedWorldX then
				extraState.drawEx.rampPreview(lockedWorldX, lockedWorldZ, lockedGroundY, worldX, worldZ, groundY, activeRadius)
			end

			glColor(1, 1, 1, 1)
			glLineWidth(1)
			return
		end

		local mr, mg, mb = getModeRGB()
		local br, bg, bb = getModeRGBBright()

		-- Intensity visual factor: 0..1 mapped logarithmically from MIN_INTENSITY..MAX_INTENSITY
		local intensityT = log(activeIntensity / MIN_INTENSITY) / log(MAX_INTENSITY / MIN_INTENSITY)
		intensityT = max(0, min(1, intensityT))

		-- Semi-transparent footprint fill -- opacity scales with intensity
		local fillAlpha = min(0.6, 0.05 + intensityT * 0.40)
		glColor(mr, mg, mb, fillAlpha)
		extraState.drawShapeGroundFill(worldX, worldZ, activeRadius, activeShape, activeRotation, groundY, activeLengthScale)

		-- Height colormap: topographic elevation visualization within brush footprint
		if extraState.heightColormap then
			extraState.drawHeightColormap(worldX, worldZ, activeRadius, activeShape, activeRotation, activeLengthScale)
		end

		-- Outline
		glColor(mr, mg, mb, 0.4 + intensityT * 0.55)
		glLineWidth(2.5)

		if activeShape == "circle" then
			extraState.drawRegularPolygon(worldX, worldZ, activeRadius, activeRotation, CIRCLE_SEGMENTS, activeLengthScale)
		elseif activeShape == "square" then
			extraState.drawRotatedSquare(worldX, worldZ, activeRadius, activeRotation, activeLengthScale)
		elseif activeShape == "triangle" then
			extraState.drawRegularPolygon(worldX, worldZ, activeRadius, activeRotation, 3, activeLengthScale)
		elseif activeShape == "hexagon" then
			extraState.drawRegularPolygon(worldX, worldZ, activeRadius, activeRotation, 6, activeLengthScale)
		elseif activeShape == "octagon" then
			extraState.drawRegularPolygon(worldX, worldZ, activeRadius, activeRotation, 8, activeLengthScale)
		elseif activeShape == "ring" then
			extraState.drawRing(worldX, worldZ, activeRadius, activeRotation, activeLengthScale)
		end

		if heightCapMin or heightCapMax then
			glLineWidth(2.5)
			local refY = lockedGroundY or groundY
			local absCapMin, absCapMax
			if heightCapAbsolute then
				absCapMin = heightCapMin and heightCapMin or nil
				absCapMax = heightCapMax and heightCapMax or nil
			else
				absCapMin = heightCapMin and (refY + heightCapMin) or nil
				absCapMax = heightCapMax and (refY + heightCapMax) or nil
			end
			local drawX = lockedWorldX or worldX
			local drawZ = lockedWorldZ or worldZ

			if activeShape == "ring" then
				extraState.drawRingPrism(drawX, drawZ, activeRadius, activeRotation, refY, absCapMin, absCapMax, activeLengthScale)
			else
				extraState.drawPrism(drawX, drawZ, activeRadius, activeShape, activeRotation, refY, absCapMin, absCapMax, activeLengthScale)
			end
		end

		local dir = activeDirection ~= 0 and activeDirection or 1
		-- Scale falloff display height by intensity (20..180 elmos)
		local baseDisplayHeight = 20 + intensityT * 160
		local effectHeight = baseDisplayHeight
		if heightCapMax and dir > 0 then
			effectHeight = heightCapMax
		elseif heightCapMin and dir < 0 then
			effectHeight = -heightCapMin
		end
		effectHeight = effectHeight * dir

		-- Falloff arc + curtains in mode's bright color
		if extraState.curveOverlay then
		local curveBaseY = lockedGroundY or groundY
		glColor(br, bg, bb, 0.85)
		glLineWidth(2.5)

		if activeShape == "circle" then
			extraState.drawEx.falloffCircle(worldX, worldZ, activeRadius, activeCurve, curveBaseY, effectHeight, activeRotation, activeLengthScale)
		elseif activeShape == "square" then
			extraState.drawEx.falloffPoly(worldX, worldZ, extraState.squareFaces, activeRadius, activeRadius * activeLengthScale, activeRotation, activeCurve, curveBaseY, effectHeight)
		elseif activeShape == "triangle" then
			extraState.drawEx.falloffRegularPoly(worldX, worldZ, activeRadius, activeRotation, 3, activeCurve, curveBaseY, effectHeight, activeLengthScale)
		elseif activeShape == "hexagon" then
			extraState.drawEx.falloffRegularPoly(worldX, worldZ, activeRadius, activeRotation, 6, activeCurve, curveBaseY, effectHeight, activeLengthScale)
		elseif activeShape == "octagon" then
			extraState.drawEx.falloffRegularPoly(worldX, worldZ, activeRadius, activeRotation, 8, activeCurve, curveBaseY, effectHeight, activeLengthScale)
		elseif activeShape == "ring" then
			extraState.drawEx.falloffRing(worldX, worldZ, activeRadius, activeCurve, curveBaseY, effectHeight, activeRotation, activeLengthScale)
		end

		-- Center ruler post: vertical shaft + tick-marks showing max effect height
		glColor(br, bg, bb, 0.80)
		glLineWidth(2.5)
		extraState.drawEx.centerPost(worldX, worldZ, curveBaseY, effectHeight)
		end

		glColor(1, 1, 1, 1)
		glLineWidth(1)
	end)
	updateDrawCacheParams(worldX, worldZ, groundY)
	glCallList(drawCacheList)

	penRestoreDraw()
end

function widget:KeyPress(key, mods, isRepeat)
	-- When game chat input is open, pass all keys through so chat works normally
	if WG['chat'] and WG['chat'].isInputActive() then
		return false
	end

	-- Forward key to settings window key capture if active; always consume the
	-- key while capturing so it cannot reach other widgets or Spring actions
	if WG.TerraformBrushUI and WG.TerraformBrushUI.isCapturingKey() then
		WG.TerraformBrushUI.captureKey(key)
		return true
	end

	-- Measure tool: Enter toggles between drawing mode (brush hidden) and view mode (brush active)
	if key == 13 and extraState.measureActive and not mods.ctrl and not mods.alt then
		extraState.measureDrawing = not extraState.measureDrawing
		if not extraState.measureDrawing then
			-- Exiting drawing mode: cancel any in-progress segment
			extraState.measureActivePt    = nil
			extraState.measureActiveChain = nil
			extraState.measureDragLine    = nil
			extraState.measurePressDragCandidate = nil
		end
		return true
	end

	if not activeMode then
		-- Tool switching keys (only when NOT in terrain mode, so terrain keys take priority)
		if not mods.ctrl and not mods.alt and WG.TerraformBrushUI and WG.TerraformBrushUI.handleToolKey then
			if WG.TerraformBrushUI.handleToolKey(key) then
				return true
			end
		end
		return false
	end
	if mods.ctrl and key == 122 then -- Ctrl+Z
		local count
		if isRepeat then
			local elapsed = os.clock() - (extraState.undoHoldStart or os.clock())
			if elapsed > 12 then
				count = 80
			elseif elapsed > 8 then
				count = 40
			elseif elapsed > 5 then
				count = 20
			elseif elapsed > 2 then
				count = 10
			else
				count = 5
			end
		else
			extraState.undoHoldStart = os.clock()
			count = 1
		end
		if mods.shift then
			for _ = 1, count do SendLuaRulesMsg(MSG.REDO) end
			if not isRepeat then Echo("[Terraform Brush] Redo") end
		else
			for _ = 1, count do SendLuaRulesMsg(MSG.UNDO) end
			if not isRepeat then Echo("[Terraform Brush] Undo") end
		end
		return true
	end

	if key == KEYSYMS_SPACE then
		return true -- suppress other keybinds while brush is active (space controls intensity via scroll)
	end

	-- Bracket keys [ / ] with modifiers matching scroll conventions:
	--   Ctrl+[/]     = Size       (matches Ctrl+Scroll)
	--   Alt+[/]      = Rotation   (matches Alt+Scroll)
	--   Shift+[/]    = Curve      (matches Shift+Scroll)
	--   Ctrl+Alt+[/] = Length     (matches Ctrl+Alt+Scroll)
	--   Space+[/]    = Intensity  (matches Space+Scroll)
	if key == 91 or key == 93 then -- [ or ]
		local increase = (key == 93)
		local spaceHeld = GetKeyState(KEYSYMS_SPACE)

		if mods.ctrl and mods.alt then
			if increase then
				setLengthScale(activeLengthScale + LENGTH_SCALE_STEP)
			else
				setLengthScale(activeLengthScale - LENGTH_SCALE_STEP)
			end
			Echo("[Terraform Brush] Length: " .. string.format("%.1f", activeLengthScale))
			return true
		elseif mods.ctrl then
			if increase then
				activeRadius = min(MAX_RADIUS, activeRadius + RADIUS_STEP)
			else
				activeRadius = max(MIN_RADIUS, activeRadius - RADIUS_STEP)
			end
			Echo("[Terraform Brush] Radius: " .. activeRadius)
			return true
		elseif mods.alt then
			-- Block rotation change during an active brush stroke (angle-snap: one stroke = one angle)
			if extraState.angleSnap and lockedWorldX then return true end
			local step = (extraState.angleSnap and extraState.angleSnapStep > 0)
				and extraState.angleSnapStep or ROTATION_STEP
			-- Angle-snap: bracket keys also require 2 presses to advance (same detent as scroll)
			if extraState.angleSnap then
				local dir = increase and 1 or -1
				if dir ~= extraState.angleSnapScrollDir then
					extraState.angleSnapScrollAccum = 1
					extraState.angleSnapScrollDir   = dir
				else
					extraState.angleSnapScrollAccum = extraState.angleSnapScrollAccum + 1
				end
				if extraState.angleSnapScrollAccum >= 2 then
					extraState.angleSnapScrollAccum = 0
					rotateBy(dir * step)
					-- Keep manual spoke & locked axis in sync with the brush rotation
					if extraState.angleSnap then
						local ns = floor(360 / step)
						extraState.angleSnapManualSpoke = floor(activeRotation / step + 0.5) % ns
						extraState.angleSnapAuto = false
					end
					Echo("[Terraform Brush] Rotation: " .. activeRotation .. "°")
				end
			else
				rotateBy(increase and step or -step)
				Echo("[Terraform Brush] Rotation: " .. activeRotation .. "°")
			end
			return true
		elseif mods.shift then
			if increase then
				activeCurve = min(MAX_CURVE, activeCurve + CURVE_STEP)
			else
				activeCurve = max(MIN_CURVE, activeCurve - CURVE_STEP)
			end
			activeCurve = floor(activeCurve * 10 + 0.5) / 10
			Echo("[Terraform Brush] Curve: " .. string.format("%.1f", activeCurve))
			return true
		elseif spaceHeld then
			if increase then
				local newI = activeIntensity * 1.15
				if newI < activeIntensity + 0.1 then newI = activeIntensity + 0.1 end
				setIntensity(newI)
			else
				local newI = activeIntensity / 1.15
				if newI > activeIntensity - 0.1 then newI = activeIntensity - 0.1 end
				setIntensity(newI)
			end
			Echo("[Terraform Brush] Intensity: " .. string.format("%.1f", activeIntensity))
			return true
		end
	end

	if not mods.ctrl and not mods.alt then
		-- Toggle keys (configurable)
		if key == getKeybindKey("toggle_clay") then
			setClayMode(not clayMode)
			Echo("[Terraform Brush] Clay: " .. (clayMode and "ON" or "OFF"))
			return true
		end

		-- Shape keys (configurable)
		if key == getKeybindKey("shape_circle") then
			setShape("circle")
			return true
		elseif key == getKeybindKey("shape_square") then
			setShape("square")
			return true
		elseif key == getKeybindKey("shape_triangle") then
			setShape("triangle")
			return true
		elseif key == getKeybindKey("shape_hexagon") then
			setShape("hexagon")
			return true
		elseif key == getKeybindKey("shape_octagon") then
			setShape("octagon")
			return true
		elseif key == getKeybindKey("mode_ramp") then
			setMode("ramp")
			return true
		elseif key == getKeybindKey("mode_restore") then
			setMode("restore")
			return true
		elseif key == getKeybindKey("mode_level") then
			-- Toggle between SMOOTH (primary) and LEVEL (submode)
			if activeMode == "smooth" then setMode("level") else setMode("smooth") end
			return true
		elseif key == getKeybindKey("mode_noise") then
			setMode("noise")
			return true
		end
	end

	-- Tool switching (after terrain keys, so terrain mode/shape keys take priority)
	if not mods.ctrl and not mods.alt and WG.TerraformBrushUI and WG.TerraformBrushUI.handleToolKey then
		if WG.TerraformBrushUI.handleToolKey(key) then
			return true
		end
	end

	return false
end

function widget:MousePress(mx, my, button)
	-- ── Symmetry origin (works regardless of terraform mode; also during metal/grass/FP) ──
	if button == 1 and extraState.symmetryActive then
		if extraState.symmetryPlacingOrigin then
			local wx, wz = getWorldMousePosition()
			if wx then
				extraState.symmetryOriginX = wx
				extraState.symmetryOriginZ = wz
				extraState.symmetryPlacingOrigin = false
			end
			return true
		end
		if extraState.symmetryHoveringOrigin and not extraState.symmetryDraggingOrigin then
			extraState.symmetryDraggingOrigin = true
			local ox, oz = extraState.getSymmetryOrigin()
			extraState.symmetryDragPrevX = ox
			extraState.symmetryDragPrevZ = oz
			return true
		end
	end
	-- ── Measure tool (works regardless of terraform mode) ──────────────────────
	if extraState.measureActive and extraState.measureDrawing then
		if button == 1 then
			local worldX, worldZ = getWorldMousePosition()
			if not worldX then return false end
			local _, _, _, shiftHeld = GetModKeyState()
			-- Shift-snap to H/V from pending first point
			if shiftHeld and extraState.measureActivePt then
				worldX, worldZ = extraState.measureShiftSnap(
					extraState.measureActivePt[1], extraState.measureActivePt[2], worldX, worldZ)
			end
			-- Record press location (for drag-threshold detection in MouseMove)
			extraState.measurePressScreenX   = mx
			extraState.measurePressScreenY   = my
			local near = extraState.measureFindNearEndpoint(mx, my)
			if near then
				extraState.measurePressDragCandidate = near
				local chain = extraState.measureLines[near.chain]
				if chain then
					extraState.measurePressCandidateWorld = { chain.pts[near.pt][1], chain.pts[near.pt][2] }
				end
				-- If no segment is in progress, snap the pending start point to this
				-- endpoint immediately so the live-preview line draws from it at once.
				-- Flag as provisional: MouseRelease will resolve into start/extend (not complete).
				if not extraState.measureActivePt then
					local w = extraState.measurePressCandidateWorld
					if w then
						extraState.measureActivePt    = {w[1], w[2]}
						extraState.measureActiveChain = nil
						extraState.measurePressSnapStart = true
					end
				end
			else
				extraState.measurePressDragCandidate = nil
				extraState.measurePressCandidateWorld = nil
				-- Check for handle drag (existing handle hit)
				local nearH = extraState.measureFindNearHandle(mx, my)
				if nearH then
					extraState.measureHandleDrag = nearH
					return true
				end
				-- Check for segment body (create new handle there)
				local nearSeg = extraState.measureFindNearSegMid(mx, my)
				if nearSeg then
					local chain = extraState.measureLines[nearSeg.chain]
					if chain then
						chain.handles = chain.handles or {}
						chain.handles[nearSeg.seg] = {nearSeg.wx, nearSeg.wz}
						extraState.measureHandleDrag = {chain = nearSeg.chain, seg = nearSeg.seg}
					end
					return true
				end
				-- Place or complete
				if extraState.measureActivePt then
					local ap = extraState.measureActivePt
					local chainIdx = extraState.measureActiveChain
					if chainIdx then
						local chain = extraState.measureLines[chainIdx]
						if chain then
							chain.pts[#chain.pts + 1] = {worldX, worldZ}
							extraState.measureActivePt   = {worldX, worldZ}
							extraState.measureActiveChain = chainIdx
						end
					else
						local newChain = {pts = { {ap[1], ap[2]}, {worldX, worldZ} }, handles = {}}
						extraState.measureLines[#extraState.measureLines + 1] = newChain
						extraState.measureActivePt    = {worldX, worldZ}
						extraState.measureActiveChain = #extraState.measureLines
					end
				else
					extraState.measureActivePt    = {worldX, worldZ}
					extraState.measureActiveChain = nil
				end
			end
			return true
		end
		if button == 3 then
			-- RMB near a handle: delete the handle
			local nearH = extraState.measureFindNearHandle(mx, my)
			if nearH then
				local chain = extraState.measureLines[nearH.chain]
				if chain and chain.handles then
					chain.handles[nearH.seg] = nil
				end
				return true
			end
			-- RMB near a line/spline: delete the entire chain
			local nearCI = extraState.measureFindNearChain(mx, my)
			if nearCI then
				table.remove(extraState.measureLines, nearCI)
				-- Fix up active chain index after removal
				if extraState.measureActiveChain then
					if extraState.measureActiveChain == nearCI then
						extraState.measureActivePt    = nil
						extraState.measureActiveChain = nil
					elseif extraState.measureActiveChain > nearCI then
						extraState.measureActiveChain = extraState.measureActiveChain - 1
					end
				end
				return true
			end
			-- RMB away from everything: exit drawing mode, return to brush
			extraState.measureDrawing = false
			extraState.measureActivePt    = nil
			extraState.measureActiveChain = nil
			extraState.measureDragLine    = nil
			extraState.measureHandleDrag  = nil
			extraState.measurePressDragCandidate = nil
			extraState.measurePressSnapStart = false
			return true
		end
	end
	-- ── Terraform mode ─────────────────────────────────────────────────────────
	if not activeMode then
		return false
	end
	if button == 1 then
		-- Height sampling mode: capture the hovered contour or peak height then exit
		if extraState.heightSamplingMode then
			local sampledH = nil
			if extraState.colormapHoverPeak and extraState.colormapPeak then
				sampledH = extraState.colormapPeak[2]
			elseif extraState.colormapHoverContour then
				sampledH = extraState.colormapHoverContour
			end
			local sampledTarget = extraState.heightSamplingMode
			if sampledH then
				local rounded = floor(sampledH + 0.5)
				if sampledTarget == "max" then
					setHeightCapMax(rounded)
				else
					setHeightCapMin(rounded)
				end
				extraState.heightSamplingMode = nil
				if WG.TerraformBrushUI and WG.TerraformBrushUI.onHeightSampled then
					WG.TerraformBrushUI.onHeightSampled(sampledTarget, rounded)
				end
			else
				extraState.heightSamplingMode = nil
			end
			return true
		end
		-- Symmetry origin placement: LMB sets the origin, then exit placing mode
		if extraState.symmetryPlacingOrigin then
			local wx, wz = getWorldMousePosition()
			if wx then
				extraState.symmetryOriginX = wx
				extraState.symmetryOriginZ = wz
				extraState.symmetryPlacingOrigin = false
			end
			return true
		end
		-- Symmetry origin drag: start drag when clicking on hovered origin
		if extraState.symmetryHoveringOrigin and not extraState.symmetryDraggingOrigin then
			extraState.symmetryDraggingOrigin = true
			local ox, oz = extraState.getSymmetryOrigin()
			extraState.symmetryDragPrevX = ox
			extraState.symmetryDragPrevZ = oz
			return true
		end
		-- Fill brush: single-click flood fill — send message immediately, don't lock for drag
		if activeShape == "fill" then
			local worldX, worldZ = getWorldMousePosition()
			if worldX then
				local positions = extraState.getSymmetricPositions(worldX, worldZ, 0)
				for _, p in ipairs(positions) do
					if p.x >= 0 and p.x <= Game.mapSizeX
					   and p.z >= 0 and p.z <= Game.mapSizeZ then
						SendLuaRulesMsg(MSG.FILL_SHAPE
							.. floor(p.x) .. " "
							.. floor(p.z))
					end
				end
			end
			return true
		end
		local worldX, worldZ = getWorldMousePosition()
		if worldX then
			if extraState.measureActive and extraState.measureRulerMode then
				worldX, worldZ = extraState.snapToMeasureLine(worldX, worldZ)
			end
			lockedWorldX = worldX
			lockedWorldZ = worldZ
			lockedGroundY = GetGroundHeight(worldX, worldZ)
			lastScreenX = mx
			lastScreenY = my
			dragOriginX = worldX
			dragOriginZ = worldZ
			-- Reset interpolation anchor so strokes don't connect across mouse-down events
			extraState.lastAppliedX = nil
			extraState.lastAppliedZ = nil
			extraState.mergeLeftOpen = false
			-- If shift already held, use existing shift origin for drag
			if shiftState.originX then
				dragOriginX = shiftState.originX
				dragOriginZ = shiftState.originZ
			end
			-- G4: record undo baseline at ramp stroke start so we can undo the whole stroke later
			if activeMode == "ramp" then
				extraState.rampStrokeUndoBaseline = extraState.gadgetUndoCount
			end
			-- Initialize spline points for circle+ramp
			if activeMode == "ramp" and activeShape == "circle" then
				if extraState.splineCacheList then
					glDeleteList(extraState.splineCacheList)
					extraState.splineCacheList = nil
					extraState.splineCacheCount = -1
				end
				extraState.splineRampLastSendCount = 0
				extraState.splineCommitted = { pts = {}, rawIdx = 0 }
				rampSplinePoints = { { worldX, worldZ } }
			end
		end

		return true
	end

	if button == 3 then
		if not rightMouseHeld then
			savedModeBeforeRMB = activeMode
			savedDirectionBeforeRMB = activeDirection
			rightMouseHeld = true
			setMode("lower")
			Echo("[Terraform Brush] RMB → LOWER (release to restore " .. (savedModeBeforeRMB or "raise"):upper() .. ")")
		end
		local worldX, worldZ = getWorldMousePosition()
		if worldX then
			if extraState.measureActive and extraState.measureRulerMode then
				worldX, worldZ = extraState.snapToMeasureLine(worldX, worldZ)
			end
			lockedWorldX = worldX
			lockedWorldZ = worldZ
			lockedGroundY = GetGroundHeight(worldX, worldZ)
			lastScreenX = mx
			lastScreenY = my
			dragOriginX = worldX
			dragOriginZ = worldZ
			extraState.lastAppliedX = nil
			extraState.lastAppliedZ = nil
			extraState.mergeLeftOpen = false
		end
		return true
	end

	return false
end

function widget:MouseRelease(mx, my, button)
	-- ── Symmetry origin drag release ────────────────────────────────────────────
	if extraState.symmetryDraggingOrigin and button == 1 then
		extraState.symmetryDraggingOrigin = false
		extraState.symmetryDragPrevX = nil
		extraState.symmetryDragPrevZ = nil
		-- Replay sticky terrain at new positions
		if extraState.measureStickyMode and #extraState.linkedStrokes > 0 then
			extraState.replayLinkedStrokes()
		end
		return true
	end
	-- ── Measure tool ───────────────────────────────────────────────────────────
	if extraState.measureActive and extraState.measureDrawing and button == 1 then
		if extraState.measureHandleDrag then
			-- G4: capture chain ref before clearing, so we can re-apply ramp chains
			local hd = extraState.measureHandleDrag
			local hdChain = hd and extraState.measureLines[hd.chain]
			extraState.measureHandleDrag = nil
			-- Final sticky replay at the released handle position
			if extraState.measureStickyMode and #extraState.linkedStrokes > 0 then
				extraState.replayLinkedStrokes()
			end
			-- G4: re-apply ramp if the handle that was dragged belongs to a ramp chain
			if hdChain and hdChain.isRampChain then
				extraState.queueRampReapply(hdChain)
			end
			return true
		end
		if extraState.measureDragLine then
			-- G4: capture chain ref before clearing
			local dl = extraState.measureDragLine
			local dlChain = dl and extraState.measureLines[dl.chain]
			extraState.measureDragLine = nil
			-- Final sticky replay at the released endpoint position
			if extraState.measureStickyMode and #extraState.linkedStrokes > 0 then
				extraState.replayLinkedStrokes()
			end
			-- G4: re-apply ramp if the endpoint that was dragged belongs to a ramp chain
			if dlChain and dlChain.isRampChain then
				extraState.queueRampReapply(dlChain)
			end
			return true
		end
		if extraState.measurePressDragCandidate then
			-- Was a click near endpoint (didn't become a drag) → start/extend from it
			local world = extraState.measurePressCandidateWorld
			local near  = extraState.measurePressDragCandidate
			if world then
				if extraState.measureActivePt and not extraState.measurePressSnapStart then
					-- There was already an in-progress segment before the press:
					-- complete it TO this existing endpoint.
					local ap = extraState.measureActivePt
					local chainIdx = extraState.measureActiveChain
					if chainIdx then
						local chain = extraState.measureLines[chainIdx]
						if chain then
							chain.pts[#chain.pts + 1] = {world[1], world[2]}
							extraState.measureActivePt    = {world[1], world[2]}
							extraState.measureActiveChain = chainIdx
						end
					else
						local newChain = {pts = { {ap[1], ap[2]}, {world[1], world[2]} }, handles = {}}
						extraState.measureLines[#extraState.measureLines + 1] = newChain
						extraState.measureActivePt    = {world[1], world[2]}
						extraState.measureActiveChain = #extraState.measureLines
					end
				else
					-- No prior active segment (provisional snap or fresh click):
					-- start extending from this endpoint. If it's the last pt of its chain,
					-- continue that chain; otherwise start a free new chain from this point.
					if near.pt == #extraState.measureLines[near.chain].pts then
						extraState.measureActivePt    = {world[1], world[2]}
						extraState.measureActiveChain = near.chain
					else
						extraState.measureActivePt    = {world[1], world[2]}
						extraState.measureActiveChain = nil
					end
				end
			end
			extraState.measurePressSnapStart = false
			extraState.measurePressDragCandidate = nil
			extraState.measurePressCandidateWorld = nil
			return true
		end
	end
	-- ── Terraform mode ─────────────────────────────────────────────────────────
	if button == 3 and rightMouseHeld then
		rightMouseHeld = false
		stampApplied = false
		if savedModeBeforeRMB then
			setMode(savedModeBeforeRMB)
			Echo("[Terraform Brush] Restored: " .. (savedModeBeforeRMB):upper())
		else
			activeMode = nil
			activeDirection = nil
		end
		savedModeBeforeRMB = nil
		savedDirectionBeforeRMB = nil
		lockedWorldX = nil
		lockedWorldZ = nil
		lockedGroundY = nil
		return true
	end
	return false
end

function widget:MouseMove(mx, my, _dx, _dy, button)
	-- Measure tool: handle drag-threshold detection and endpoint dragging
	if extraState.measureActive and extraState.measureDrawing and button == 1 then
		local DRAG_THRESHOLD_SQ = 9  -- 3 pixels: activate drag almost immediately on move
		-- Handle control point drag (immediate, no threshold needed)
		if extraState.measureHandleDrag then
			local worldX, worldZ = getWorldMousePosition()
			if worldX then
				local hd    = extraState.measureHandleDrag
				local chain = extraState.measureLines[hd.chain]
				if chain then
					chain.handles = chain.handles or {}
					chain.handles[hd.seg] = {worldX, worldZ}
				end
			end
			return true
		end
		-- Promote press-candidate to actual drag once threshold exceeded
		if extraState.measurePressDragCandidate then
			local pdx = mx - (extraState.measurePressScreenX or mx)
			local pdy = my - (extraState.measurePressScreenY or my)
			if pdx * pdx + pdy * pdy > DRAG_THRESHOLD_SQ then
				extraState.measureDragLine = extraState.measurePressDragCandidate
				extraState.measurePressDragCandidate = nil
				extraState.measurePressCandidateWorld = nil
				-- Revert the provisional snap-start we set on press; the drag owns this point now
				if extraState.measurePressSnapStart then
					extraState.measureActivePt    = nil
					extraState.measureActiveChain = nil
					extraState.measurePressSnapStart = false
				end
			end
		end
		-- Execute drag: move the held endpoint
		if extraState.measureDragLine then
			local worldX, worldZ = getWorldMousePosition()
			if worldX then
				local _, _, _, shiftHeld = GetModKeyState()
				if shiftHeld then
					local dl    = extraState.measureDragLine
					local chain = extraState.measureLines[dl.chain]
					if chain then
						local pts  = chain.pts
						local refPt = (dl.pt > 1) and pts[dl.pt - 1]
						           or (dl.pt < #pts and pts[dl.pt + 1])
						if refPt then
							worldX, worldZ = extraState.measureShiftSnap(refPt[1], refPt[2], worldX, worldZ)
						end
					end
				end
				local dl    = extraState.measureDragLine
				local chain = extraState.measureLines[dl.chain]
				if chain then
					chain.pts[dl.pt] = {worldX, worldZ}
				end
			end
			return true
		end
		return false
	end
	return false
end

-- Check if a scroll keybind's modifier key(s) are currently held.
-- Maps modifier keycodes to GetModKeyState flags for reliable L/R detection.
local function isScrollModHeld(action)
	local kb = activeKeybinds[action]
	if not kb or not kb.key or kb.key == 0 then return false end
	local alt, ctrl, _, shift = GetModKeyState()
	local function isHeld(kc)
		if kc == 304 or kc == 303 then return shift end   -- LSHIFT / RSHIFT
		if kc == 306 or kc == 305 then return ctrl end    -- LCTRL / RCTRL
		if kc == 308 or kc == 307 then return alt end     -- LALT / RALT
		return GetKeyState(kc)
	end
	if not isHeld(kb.key) then return false end
	if kb.key2 and kb.key2 ~= 0 then
		if not isHeld(kb.key2) then return false end
	end
	return true
end

-- Priority order: dual-key combos first, then single-key
local SCROLL_PRIORITY = {
	"scroll_ring", "scroll_length", "scroll_cap_max",
	"scroll_protractor", "scroll_rotation", "scroll_curve", "scroll_intensity", "scroll_size",
}

function widget:MouseWheel(up, value)
	if not activeMode then
		return false
	end

	for _, action in ipairs(SCROLL_PRIORITY) do
		if isScrollModHeld(action) then
			if action == "scroll_ring" then
				if up then setRingInnerRatio(ringInnerRatio + RING_WIDTH_STEP)
				else       setRingInnerRatio(ringInnerRatio - RING_WIDTH_STEP) end
				Echo("[Terraform Brush] Ring width: " .. floor((1 - ringInnerRatio) * 100 + 0.5) .. "%")
				extraState.setParamHud("Ring: " .. floor((1 - ringInnerRatio) * 100 + 0.5) .. "%")  -- D5
				return true
			elseif action == "scroll_protractor" then
				if not extraState.angleSnap then return false end
				if lockedWorldX then return true end  -- block during stroke
				local step = extraState.angleSnapStep
				local numSpokes = (step > 0) and floor(360 / step) or 1
				local dir = up and 1 or -1
				if dir ~= extraState.angleSnapScrollDir then
					extraState.angleSnapScrollAccum = 1
					extraState.angleSnapScrollDir   = dir
				else
					extraState.angleSnapScrollAccum = extraState.angleSnapScrollAccum + 1
				end
				if extraState.angleSnapScrollAccum >= 2 then
					extraState.angleSnapScrollAccum = 0
					-- Advance the manual spoke and disable autosnap
					extraState.angleSnapAuto = false
					local curIdx = floor(activeRotation / step + 0.5) % numSpokes
					extraState.angleSnapManualSpoke = (curIdx + dir + numSpokes) % numSpokes
					activeRotation = (extraState.angleSnapManualSpoke * step) % 360
					Echo("[Terraform Brush] Protractor: " .. activeRotation .. "\194\176")
					extraState.setParamHud("Spoke: " .. activeRotation .. "\194\176")  -- D5
				end
				return true
			elseif action == "scroll_length" then
				if up then setLengthScale(activeLengthScale + LENGTH_SCALE_STEP)
				else       setLengthScale(activeLengthScale - LENGTH_SCALE_STEP) end
				Echo("[Terraform Brush] Length: " .. string.format("%.1f", activeLengthScale))
				extraState.setParamHud("Length: " .. string.format("%.1f", activeLengthScale))  -- D5
				return true
			elseif action == "scroll_rotation" then
				-- Block rotation change during an active brush stroke (angle-snap: one stroke = one angle)
				if extraState.angleSnap and lockedWorldX then
					extraState.angleSnapScrollAccum = 0
					extraState.angleSnapScrollDir   = 0
					return true
				end
				local step = (extraState.angleSnap and extraState.angleSnapStep > 0)
					and extraState.angleSnapStep or ROTATION_STEP
				-- Angle-snap: require 2 ticks in the same direction before advancing a spoke
				if extraState.angleSnap then
					local dir = up and 1 or -1
					if dir ~= extraState.angleSnapScrollDir then
						extraState.angleSnapScrollAccum = 1
						extraState.angleSnapScrollDir   = dir
					else
						extraState.angleSnapScrollAccum = extraState.angleSnapScrollAccum + 1
					end
					if extraState.angleSnapScrollAccum >= 2 then
						extraState.angleSnapScrollAccum = 0
						rotateBy(dir * step)
						-- Keep manual spoke & locked axis in sync with the brush rotation
						local ns = floor(360 / step)
						extraState.angleSnapManualSpoke = floor(activeRotation / step + 0.5) % ns
						extraState.angleSnapAuto = false
						Echo("[Terraform Brush] Rotation: " .. activeRotation)
						extraState.setParamHud("Rot: " .. activeRotation .. "\194\176")  -- D5
					end
				else
					rotateBy(up and step or -step)
					Echo("[Terraform Brush] Rotation: " .. activeRotation)
					extraState.setParamHud("Rot: " .. activeRotation .. "\194\176")  -- D5
				end
				return true
			elseif action == "scroll_curve" then
				if up then activeCurve = min(MAX_CURVE, activeCurve + CURVE_STEP)
				else       activeCurve = max(MIN_CURVE, activeCurve - CURVE_STEP) end
				activeCurve = floor(activeCurve * 10 + 0.5) / 10
				Echo("[Terraform Brush] Curve: " .. string.format("%.1f", activeCurve))
				extraState.setParamHud("Curve: " .. string.format("%.1f", activeCurve))  -- D5
				return true
			elseif action == "scroll_intensity" then
				if up then
					local newI = activeIntensity * 1.15
					if newI < activeIntensity + 0.1 then newI = activeIntensity + 0.1 end
					setIntensity(newI)
				else
					local newI = activeIntensity / 1.15
					if newI > activeIntensity - 0.1 then newI = activeIntensity - 0.1 end
					setIntensity(newI)
				end
				Echo("[Terraform Brush] Intensity: " .. string.format("%.1f", activeIntensity))
				extraState.setParamHud("Intensity: " .. string.format("%.1f", activeIntensity))  -- D5
				return true
			elseif action == "scroll_size" then
				if up then activeRadius = min(MAX_RADIUS, activeRadius + RADIUS_STEP)
				else       activeRadius = max(MIN_RADIUS, activeRadius - RADIUS_STEP) end
				Echo("[Terraform Brush] Radius: " .. activeRadius)
				extraState.setParamHud("Radius: " .. activeRadius)  -- D5
				return true
			elseif action == "scroll_cap_max" then
				local current = heightCapMax or 0
				setHeightCapMax(current + (up and 8 or -8))
				local capStr = heightCapMax and tostring(heightCapMax) or "off"
				Echo("[Terraform Brush] Height cap max: " .. capStr)
				extraState.setParamHud("Cap max: " .. capStr)
				if WG.TerraformBrushUI and WG.TerraformBrushUI.expandHeightCap then
					WG.TerraformBrushUI.expandHeightCap()
				end
				return true
			end
		end
	end

	return false
end
