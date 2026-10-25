-- tf_tileset.lua: the TILESET floating window (opened from the SCENE menu,
-- independent of the active tool), which tunes the tileset terrain shader.
-- The shader is NOT in this repo: it is the write-dir widget
-- dev_tileset_terrain.lua, driven through WG.TilesetTerrain (getKnobs /
-- setKnob / reset and friends). It may be missing or an older build, so every
-- call is nil-guarded and newer features hide when their API is absent.
local tfStrings = require("luaui/RmlWidgets/gui_terraform_brush/tf_strings")
local M = {}

-- RmlUi listener closures can run outside the widget env, where global WG is
-- nil; capture it as an upvalue.
local WG = WG

-- { knob key, numbox format }. Each key pairs with a ts-slider-<key> row in the
-- .rml; keep the two in step. Order does not matter (lookup by key).
local KNOBS = {
	{ "scaleBase", "%.0f" },
	{ "scaleIntermediate", "%.0f" },
	{ "scaleCliff", "%.0f" },
	{ "scalePlat", "%.0f" },
	{ "scaleFoot", "%.0f" },
	-- albedo tiling per flat layer, as a multiple of that layer's shape scale
	-- (albDecouple is a checkbox, mirrored by hand in M.sync)
	{ "albTileBase", "%.2f" },
	{ "albTileIntermediate", "%.2f" },
	{ "albTilePlat", "%.2f" },
	{ "normalStrength", "%.2f" },
	{ "baseNormStrength", "%.2f" },
	{ "intermediateNormStrength", "%.2f" },
	{ "platNormStrength", "%.2f" },
	{ "cliffNormStrength", "%.2f" },
	{ "footNormStrength", "%.2f" },
	{ "cliffStartDeg", "%.1f" },
	{ "chunkyCliff", "%d" },
	{ "foothillsSpanDeg", "%.1f" },
	{ "footFloor", "%.2f" },
	{ "platHeight", "%.2f" },
	{ "platBlend", "%.2f" },
	{ "cliffBlend", "%.2f" },
	{ "intermediateHeight", "%.2f" },
	{ "intermediateBlend", "%.2f" },
	{ "intermediateEvidence", "%.2f" },
	{ "cavityFloor", "%.2f" },
	-- DEPOSIT section (automatic sand slot: lee side + pockets)
	{ "depositSlot", "%d" },
	{ "depositStrength", "%.2f" },
	{ "depositLee", "%.2f" },
	{ "depositCavity", "%.2f" },
	{ "windDirDeg", "%.0f" },
	{ "depositSlopeDeg", "%.1f" },
	{ "intermediateScatter", "%.2f" },
	{ "intermediateStartDeg", "%.1f" },
	{ "intermediateFullDeg", "%.1f" },
	-- NEW SORT (3-band sort, shader build 19+): the two intermediary bands in
	-- dot space (1 flat, 0 vertical) and the two shared colour sets. The flip
	-- knobs are checkboxes, synced by hand in syncSortModel.
	{ "nLowerStart", "%.3f" },
	{ "nLowerFade", "%.3f" },
	{ "nUpperStart", "%.3f" },
	{ "nUpperFade", "%.3f" },
	{ "aLowerStart", "%.3f" },
	{ "aLowerFade", "%.3f" },
	{ "aUpperStart", "%.3f" },
	{ "aUpperFade", "%.3f" },
	{ "rockHue", "%.3f" },
	{ "rockSat", "%.2f" },
	{ "rockVal", "%.2f" },
	{ "rockTintR", "%.2f" },
	{ "rockTintG", "%.2f" },
	{ "rockTintB", "%.2f" },
	{ "topsHue", "%.3f" },
	{ "topsSat", "%.2f" },
	{ "topsVal", "%.2f" },
	{ "topsTintR", "%.2f" },
	{ "topsTintG", "%.2f" },
	{ "topsTintB", "%.2f" },
	-- cliffProtect is the PROTECT CLIFFS button (dm.tsCliffProtectOn), not a row.
	{ "splatInfluence", "%.2f" },
	{ "surfClaim", "%.2f" },
	{ "splatPunchIntermediate", "%.2f" },
	{ "splatPunchCliff", "%.2f" },
	{ "splatPunchPlat", "%.2f" },
	{ "antiTileWarp", "%.0f" },
	{ "parallaxAmp", "%.2f" },
	-- PERFORMANCE section levers
	{ "detileMul", "%.0f" },
	{ "foothills", "%d" },
	{ "stagger", "%d" },
	{ "cliffGateDeg", "%.1f" },
	{ "farCache", "%d" },
	{ "farStart", "%.2f" },
	{ "farBand", "%.2f" },
	{ "farCliffFp", "%.2f" },
	{ "clipCache", "%d" },
	{ "macroVar", "%.2f" },
	{ "macroLod", "%.1f" },
	{ "albedoSortMode", "%d" },
	{ "staggerAmount", "%.2f" },
	{ "maskScale1", "%.0f" },
	{ "maskScale2", "%.0f" },
	{ "lumaBlend", "%.2f" },
	{ "lumaTops", "%.2f" },
	{ "heightBlend", "%.2f" },
	{ "heightDepth", "%.2f" },
	{ "curvHighlight", "%.2f" },
	{ "curvShadow", "%.2f" },
	{ "curvRadius", "%.0f" },
	{ "specAA", "%.2f" },
	{ "wetBand", "%.0f" },
	{ "wetGloss", "%.2f" },
	{ "wetStrength", "%.2f" },
	{ "wetSlope", "%.2f" },
	-- terrain-driven water opacity (WATER section)
	{ "maxWalkDepth", "%.0f" },
	{ "shallowsTint", "%.2f" },
	{ "shallowsClear", "%.2f" },
	{ "shallowsCurve", "%.2f" },
	{ "shallowsHue", "%.3f" },
	{ "shallowsSat", "%.2f" },
	{ "shallowsIntensity", "%.2f" },
	{ "deepsIntensity", "%.2f" },
	{ "shadowMode", "%d" },
	{ "smtBlend", "%.2f" },
	{ "oldCliffBlend", "%.2f" },
	{ "tintR", "%.2f" },
	{ "tintG", "%.2f" },
	{ "tintB", "%.2f" },
	{ "baseTintR", "%.2f" },
	{ "baseTintG", "%.2f" },
	{ "baseTintB", "%.2f" },
	{ "intermediateTintR", "%.2f" },
	{ "intermediateTintG", "%.2f" },
	{ "intermediateTintB", "%.2f" },
	{ "cliffTintR", "%.2f" },
	{ "cliffTintG", "%.2f" },
	{ "cliffTintB", "%.2f" },
	{ "platTintR", "%.2f" },
	{ "platTintG", "%.2f" },
	{ "platTintB", "%.2f" },
	{ "metalInfluence", "%.2f" },
	{ "metalness", "%.2f" },
	{ "metalRoughMul", "%.2f" },
	{ "metalScale", "%.0f" },
	{ "metalRelief", "%.2f" },
	{ "metalEdge", "%.2f" },
	-- silhouette band: which terrain layer skirts a spot (0 base, 1 intermediate,
	-- 2 cliff, 3 plateau) and how much it darkens
	{ "metalApronLayer", "%d" },
	{ "metalApronTone", "%.2f" },
	{ "metalApronWidth", "%.2f" },
	{ "metalTintR", "%.2f" },
	{ "metalTintG", "%.2f" },
	{ "metalTintB", "%.2f" },
	-- GLOW LIGHT rows (point-light controls for every spot's light); the on/off
	-- switch is a checkbox, mirrored by hand in M.sync
	{ "metalGlowBright", "%.2f" },
	{ "metalGlowRadius", "%.0f" },
	{ "metalGlowHeight", "%.0f" },
	{ "metalGlowR", "%.2f" },
	{ "metalGlowG", "%.2f" },
	{ "metalGlowB", "%.2f" },
	-- HEIGHT TINT. The colour knobs (gradeLow*, strataColorN*, snow*, stop*)
	-- have no rows of their own: the selected chip edits them through the shared
	-- ts-hg-slider-* sliders (syncHeightTint below).
	{ "hgRefMin", "%.0f" },
	{ "hgRefSpan", "%.0f" },
	{ "hgTiltDeg", "%.1f" },
	{ "hgTiltDirDeg", "%.0f" },
	{ "hgWobble", "%.0f" },
	{ "gradeStrength", "%.2f" },
	{ "gradeSplit", "%.2f" },
	{ "strataStrength", "%.2f" },
	{ "strataCount", "%d" },
	{ "strataPeriod", "%.0f" },
	{ "strataPhase", "%.2f" },
	{ "strataHardness", "%.2f" },
	{ "strataWobble", "%.0f" },
	{ "strataJitter", "%.2f" },
	{ "strataThickJitter", "%.2f" },
	{ "stopsStrength", "%.2f" },
	{ "stopsCount", "%d" },
	{ "rampStrength", "%.2f" },
	{ "rampRepeat", "%.1f" },
	{ "satLow", "%.2f" },
	{ "satHigh", "%.2f" },
	{ "tideRings", "%d" },
	{ "tidePeriod", "%.1f" },
	{ "tideStrength", "%.2f" },
	{ "tideWobble", "%.1f" },
	{ "snowStrength", "%.2f" },
	{ "snowLine", "%.0f" },
	{ "snowBand", "%.0f" },
	{ "snowSlopeDeg", "%.0f" },
	-- debugView is the DEBUG multi-toggle (dm.tsDebugView), not a row.
}

-- The AUTOMATIC DEPOSIT rows live in the SURFACE panel (FILL AND SEED), so
-- M.syncDeposit stamps just these from the SURFACE sync while the TILESET
-- window is closed. A separate set rather than a flag on the KNOBS rows: the
-- type analyzer types every row from the first, so a tagged row is a mismatch.
local DEPOSIT_KNOBS = {
	depositSlot = true,
	depositStrength = true,
	depositLee = true,
	depositCavity = true,
	windDirDeg = true,
	depositSlopeDeg = true,
}

-- HEIGHT TINT colour chips -> the three knobs behind each. Grade, strata beds
-- and snow are stored as R/G/B, the gradient stops as H/S/V, so a chip carries
-- its keys and a storage flag and hgGet / hgSet convert either way. The panel
-- handlers reach them through widgetState.tsHgGet / tsHgSet (set in M.attach).
local function hgTarget(hsv, k1, k2, k3)
	return { hsv = hsv, keys = { k1, k2, k3 } }
end
local function rgbTarget(prefix)
	return hgTarget(false, prefix .. "R", prefix .. "G", prefix .. "B")
end
local HG_TARGETS = {
	low = rgbTarget("gradeLow"),
	mid = rgbTarget("gradeMid"),
	high = rgbTarget("gradeHigh"),
	snow = rgbTarget("snow"),
}
for n = 1, 8 do
	HG_TARGETS["s" .. n] = rgbTarget("strataColor" .. n)
	HG_TARGETS["p" .. n] = hgTarget(true, "stopH" .. n, "stopS" .. n, "stopV" .. n)
end
local HG_TARGET_NAMES = {
	low = "GRADE LOW",
	mid = "GRADE MID",
	high = "GRADE HIGH",
	snow = "SNOW",
}
for n = 1, 8 do
	HG_TARGET_NAMES["s" .. n] = "BED " .. n
	HG_TARGET_NAMES["p" .. n] = "STOP " .. n
end
local HG_CHANNELS = { "R", "G", "B", "H", "S", "V" }

-- HSV (0..1, hue around the wheel; value may exceed 1) <-> RGB
local function hsvToRgb(h, s, v)
	h = (tonumber(h) or 0) % 1.0
	s = math.max(0, math.min(1, tonumber(s) or 0))
	v = math.max(0, tonumber(v) or 1)
	local i = math.floor(h * 6) % 6
	local f = h * 6 - math.floor(h * 6)
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	if i == 0 then
		return v, t, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, t
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return t, p, v
	end
	return v, p, q
end

local function rgbToHsv(r, g, b)
	r, g, b = tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0
	local maxc, minc = math.max(r, g, b), math.min(r, g, b)
	local d = maxc - minc
	local h = 0.0
	if d > 0 then
		if maxc == r then
			h = ((g - b) / d) % 6
		elseif maxc == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h = h / 6
	end
	local s = (maxc > 0) and (d / maxc) or 0
	return h, s, maxc
end

-- Hue does not survive RGB storage (any gray reads back as h = 0, so SAT to 0
-- and back would snap to red), and value 0 loses saturation the same way.
-- Remember the last well-defined H/S per chip and return it while the colour
-- is degenerate.
local hgHsvMem = {}

-- forced: an explicit edit (a slider drag, a stored H/S/V chip) always wins;
-- otherwise H/S are kept only while the colour actually carries them.
local function hgMemo(target, h, s, v, forced)
	if not target then
		return
	end
	h, s, v = tonumber(h) or 0, tonumber(s) or 0, tonumber(v) or 0
	local m = hgHsvMem[target]
	if not m then
		m = { h = 0, s = 1 }
		hgHsvMem[target] = m
	end
	if forced or (v > 0 and s > 0) then
		m.h = h % 1.0
	end
	if forced or v > 0 then
		m.s = s
	end
end

local function hgRecall(target, h, s, v)
	local m = target and hgHsvMem[target]
	if not m then
		return h, s
	end
	if v <= 0 then
		return m.h, m.s -- black: the hue and the saturation are both gone
	elseif s <= 0 then
		return m.h, s -- gray: only the hue is gone
	end
	return h, s
end

-- A chip's colour in both spaces: r, g, b, h, s, v (nil when the knobs are missing).
local function hgGet(knobs, target)
	local t = HG_TARGETS[target]
	if not (t and knobs) then
		return nil
	end
	local a, b, c = knobs[t.keys[1]], knobs[t.keys[2]], knobs[t.keys[3]]
	if a == nil or b == nil or c == nil then
		return nil
	end
	if t.hsv then
		local r, g, bb = hsvToRgb(a, b, c)
		hgMemo(target, a, b, c, true) -- stored H/S/V: authoritative
		return r, g, bb, a, b, c
	end
	local h, s, v = rgbToHsv(a, b, c)
	hgMemo(target, h, s, v)
	h, s = hgRecall(target, h, s, v)
	return a, b, c, h, s, v
end

-- Write a chip's colour from either space: pass r, g, b (h, s, v nil) or
-- h, s, v (r, g, b nil); the target's own storage decides what is converted.
local function hgSet(target, r, g, b, h, s, v)
	local t = HG_TARGETS[target]
	---@type table?
	local T = WG.TilesetTerrain
	if not (t and T and T.setKnob) then
		return false
	end
	local a, bb, c
	if t.hsv then
		if h == nil then
			h, s, v = rgbToHsv(r, g, b)
			h, s = hgRecall(target, h, s, v)
		end
		hgMemo(target, h, s, v, true)
		a, bb, c = h, s, v
	else
		if r == nil then
			hgMemo(target, h, s, v, true)
			r, g, b = hsvToRgb(h, s, v)
		end
		a, bb, c = r, g, b
	end
	T.setKnob(t.keys[1], a)
	T.setKnob(t.keys[2], bb)
	T.setKnob(t.keys[3], c)
	return true
end

-- Every section under the SHADER switch: grayed out while the switch is off,
-- because nothing in them affects an engine-rendered map.
local TUNING_FRAMES = {
	"frame-ts-library",
	"frame-ts-perf",
	"frame-ts-metal",
	"frame-ts-scale",
	"frame-ts-normals",
	"frame-ts-rocknorm",
	"frame-ts-rockcol",
	"frame-ts-sortn",
	"frame-ts-sorta",
	"frame-ts-topscol",
	"frame-ts-cliffs",
	"frame-ts-place",
	"frame-ts-slot4",
	"frame-ts-blend",
	"frame-ts-curv",
	"frame-ts-light",
	"frame-ts-water",
	"frame-ts-oldmap",
	"frame-ts-biome",
	"frame-ts-tints",
	"frame-ts-htint",
	"frame-ts-debug",
	"frame-ts-presets",
}

-- Tileset presets as files: one file per saved preset in
-- Terraform Brush/TilesetPresets/, written on SAVE, in the format of the
-- shader's shipped tileset_dev/presets/*.lua. The brush does the file work
-- because the shader is a user widget and the sandbox lets it write only under
-- LuaUI/. The shader keeps presets in memory and drops filed ones from its
-- BYAR.lua entry. Needs shader build 21+ (addUserPreset); older builds keep
-- presets in their widget config.
local PRESET_DIR = "Terraform Brush/TilesetPresets/"
local presetFile = {} -- preset name -> its file

local function presetPath(name)
	if presetFile[name] then
		return presetFile[name]
	end
	local base = name:gsub("[^%w%-_ ]", "_"):gsub("%s+", "_")
	if base == "" then
		base = "preset"
	end
	local path, n = PRESET_DIR .. base .. ".lua", 1
	while VFS.FileExists(path, VFS.RAW) do
		n = n + 1
		path = PRESET_DIR .. base .. "_" .. n .. ".lua"
	end
	return path
end

local function writePresetFile(name, knobs, biome)
	local keys = {}
	for k, v in pairs(knobs) do
		if type(v) == "number" then
			keys[#keys + 1] = k
		end
	end
	table.sort(keys)
	local out = {
		"-- Tileset preset, saved from the TILESET window. One preset per file: copy it to",
		"-- share it, or into LuaUI/Widgets/tileset_dev/presets/ to ship it with the shader.",
		"return {",
		string.format("\tname = %q,", name),
	}
	if type(biome) == "string" and biome ~= "" then
		out[#out + 1] = string.format("\tbiome = %q,", biome)
	end
	out[#out + 1] = "\tknobs = {"
	for _, k in ipairs(keys) do
		out[#out + 1] = string.format("\t\t%s = %s,", k, tostring(knobs[k]))
	end
	out[#out + 1] = "\t},"
	out[#out + 1] = "}"
	Spring.CreateDir(PRESET_DIR)
	local path = presetPath(name)
	local f = io.open(path, "w")
	if not f then
		Spring.Echo("[TerraformBrush] could not write tileset preset " .. path)
		return false
	end
	f:write(table.concat(out, "\n") .. "\n")
	f:close()
	presetFile[name] = path
	return true
end

-- SAVE in the panel; the shader has just snapshotted the knobs under `name`.
function M.savePresetFile(name)
	local T = WG.TilesetTerrain
	if not (T and T.setPresetFiled and T.getKnobs and T.getActiveBiome) then
		-- Shader older than build 21: it keeps the preset in its own widget config.
		Spring.Echo(
			"[TerraformBrush] tileset preset '"
				.. name
				.. "' saved in the game's config (LuaUI/Config/BYAR.lua, written on quit); tileset shader build 21 saves presets as files"
		)
		return false
	end
	local _, _, bkey = T.getActiveBiome()
	if writePresetFile(name, T.getKnobs(), bkey) then
		T.setPresetFiled(name, true)
		local path = presetFile[name]
		local okAbs, abs = pcall(VFS.GetFileAbsolutePath, path, VFS.RAW)
		Spring.Echo("[TerraformBrush] tileset preset '" .. name .. "' saved to " .. ((okAbs and abs) or path))
		return true
	end
	return false
end

-- DELETE in the preset list; the shader has already dropped it from memory.
function M.deletePresetFile(name)
	local path = presetFile[name]
	if path then
		os.remove(path)
		presetFile[name] = nil
	end
end

-- Once per tileset widget instance: hand every preset file to the shader, then
-- write out any user preset still kept only in its widget config, so every
-- preset ends up as a file.
local function loadPresetFiles(T)
	presetFile = {}
	local files = VFS.DirList(PRESET_DIR, "*.lua", VFS.RAW) or {}
	table.sort(files)
	local n = 0
	for _, path in ipairs(files) do
		local chunk = VFS.LoadFile(path, VFS.RAW)
		local fn = chunk and loadstring(chunk, "=" .. path)
		local ok, data = false, nil
		if fn then
			setfenv(fn, {})
			ok, data = pcall(fn)
		end
		if ok and type(data) == "table" and type(data.name) == "string" and type(data.knobs) == "table" then
			if T.addUserPreset(data.name, data.knobs, data.biome) then
				presetFile[data.name] = path
				n = n + 1
			end
		else
			Spring.Echo("[TerraformBrush] skipped tileset preset file " .. path .. ": not a preset")
		end
	end
	local moved = 0
	for _, p in ipairs(T.getUnfiledPresets() or {}) do
		if writePresetFile(p.name, p.knobs, p.biome) then
			T.setPresetFiled(p.name, true)
			moved = moved + 1
		end
	end
	if moved > 0 then
		Spring.Echo(
			string.format(
				"[TerraformBrush] moved %d saved tileset preset(s) into %s (one file each)",
				moved,
				PRESET_DIR
			)
		)
	end
	return n
end

function M.attach(doc, ctx)
	local trackSliderDrag = ctx.trackSliderDrag
	ctx.widgetState.tsLastVal = ctx.widgetState.tsLastVal or {}
	-- The panel's preset handlers are defined before this module is required,
	-- so they reach the file side through widgetState.
	ctx.widgetState.tsSavePresetFile = M.savePresetFile
	ctx.widgetState.tsDeletePresetFile = M.deletePresetFile
	-- A fresh document is back at its markup defaults: drop every "last applied"
	-- cache so the next M.sync re-applies gray-outs, slot 4 labels and the glow bar.
	ctx.widgetState.tsShaderLast = nil
	ctx.widgetState.tsAlbDecoupleLast = nil
	ctx.widgetState.tsSlot4Last = nil
	-- The material-picker element handles belong to the old document; the GL
	-- thumb pass must not touch them.
	ctx.widgetState.ts4PaletteSig = nil
	ctx.widgetState.ts4PaletteEls = nil
	ctx.widgetState.ts4SectionEl = nil
	ctx.widgetState.tsGlowPrevLast = nil
	-- Drag tracking only; section collapse is wired in tf_environment.lua (envSectionToggle).
	for _, k in ipairs(KNOBS) do
		local el = doc:GetElementById("ts-slider-" .. k[1])
		if el and trackSliderDrag then
			trackSliderDrag(el, "ts-" .. k[1])
		end
	end
	-- LAYER SORT chips and the rock normal flip checkboxes have no data-model
	-- fields; syncSortModel mirrors them from the widget.
	ctx.widgetState.tsSortLast = nil
	ctx.widgetState.tsFlipLast = nil
	ctx.widgetState.tsSortSumLast = nil
	for _, b in ipairs({ { "btn-ts-sort-old", "old" }, { "btn-ts-sort-new", "new" } }) do
		local el = doc:GetElementById(b[1])
		if el then
			el:AddEventListener("mousedown", function(_event)
				local T = WG.TilesetTerrain
				if T and T.setSortModel and T.setSortModel(b[2]) and ctx.playSound then
					ctx.playSound("click")
				end
			end, false)
		end
	end
	for _, f in ipairs({ { "btn-ts-flip-inter", "flipIntermediateNormal" }, { "btn-ts-flip-cliff", "flipCliffNormal" } }) do
		local el = doc:GetElementById(f[1])
		if el then
			el:AddEventListener("mousedown", function(_event)
				local T = WG.TilesetTerrain
				local k = T and T.getKnobs and T.getKnobs()
				if k and k[f[2]] ~= nil and T.setKnob then
					T.setKnob(f[2], (k[f[2]] >= 1) and 0 or 1)
					if ctx.playSound then
						ctx.playSound("click")
					end
				end
			end, false)
		end
	end
	-- HEIGHT TINT: the shared colour sliders track drags like the knob rows; the
	-- chip, slider and ramp-list caches restart on a fresh document.
	ctx.widgetState.tsHgTargets = HG_TARGETS
	ctx.widgetState.tsHgGet = hgGet
	ctx.widgetState.tsHgSet = hgSet
	ctx.widgetState.tsHgChipLast = {}
	ctx.widgetState.tsHgTrioLast = nil
	ctx.widgetState.tsRampListSig = nil
	for _, ch in ipairs({ "r", "g", "b", "h", "s", "v" }) do
		local el = doc:GetElementById("ts-hg-slider-" .. ch)
		if el and trackSliderDrag then
			trackSliderDrag(el, "ts-hg-" .. ch)
		end
	end
end

-- EXTRA LAYER material picker: one tile per catalog entry. The thumb rects are
-- GL-overdrawn in DrawScreenPost (drawTs4PaletteThumbs in gui_terraform_brush.lua)
-- because an RmlUi <img> would decode the full 4K bitmap into the TexMemPool.
-- Tile 1 is the "biome pick" default: the material follows biome swaps again.
local function rebuildS4Palette(doc, ctx, list, current)
	local widgetState = ctx.widgetState
	local grid = doc:GetElementById("ts-slot4-mat-grid")
	widgetState.ts4SectionEl = doc:GetElementById("section-ts-slot4")
	if not grid then
		return
	end
	grid.inner_rml = ""
	widgetState.ts4PaletteEls = {}
	local row
	for i = 1, #list do
		local v = list[i]
		if not row or ((i - 1) % 3) == 0 then
			row = doc:CreateElement("div")
			row:SetClass("flex", true)
			row:SetClass("flex-row", true)
			row:SetClass("gap-1", true)
			row:SetClass("mb-1", true)
			grid:AppendChild(row)
		end
		local tile = doc:CreateElement("div")
		tile:SetClass("tf-biome-tile", true)
		local isDefault = (i == 1)
		local sel = (current and current == v.asset) or (not current and isDefault)
		if sel then
			tile:SetClass("active", true)
		end
		local thumb = doc:CreateElement("div")
		thumb:SetClass("tf-surf-thumb", true)
		tile:AppendChild(thumb)
		local name = doc:CreateElement("div")
		name:SetClass("tf-biome-name", true)
		name.inner_rml = isDefault and "biome pick" or v.asset
		tile:AppendChild(name)
		tile:AddEventListener("mousedown", function(_event)
			local T = WG.TilesetTerrain
			if T and T.setSlot4Material then
				T.setSlot4Material(isDefault and nil or v.asset)
				if ctx.playSound then
					ctx.playSound("click")
				end
			end
		end, false)
		row:AppendChild(tile)
		widgetState.ts4PaletteEls[#widgetState.ts4PaletteEls + 1] = { el = thumb, tex = v.diff }
	end
end

-- BIOME LIBRARY tiles, built from WG.TilesetTerrain.getBiomes() (one manifest
-- per biome in tileset_dev/tilesets/), so a biome added on disk needs no RML
-- edit. Thumbnails are GL overdraws (drawTsBiomeThumbs in gui_terraform_brush.lua).
local function rebuildBiomePalette(doc, ctx, rows, activeKey)
	local widgetState = ctx.widgetState
	local grid = doc:GetElementById("ts-biome-grid")
	widgetState.tsBiomeSectionEl = doc:GetElementById("section-ts-library")
	if not grid then
		return
	end
	grid.inner_rml = ""
	widgetState.tsBiomeTileEls = {}
	local row
	for i = 1, #rows do
		local b = rows[i]
		if not row or ((i - 1) % 3) == 0 then
			row = doc:CreateElement("div")
			row:SetClass("tf-biome-grid", true)
			row:SetClass("flex", true)
			row:SetClass("flex-row", true)
			row:SetClass("gap-1", true)
			row:SetClass("mb-1", true)
			grid:AppendChild(row)
		end
		local tile = doc:CreateElement("div")
		tile:SetClass("tf-biome-tile", true)
		if b.key == activeKey then
			tile:SetClass("active", true)
		end
		if b.file then
			tile:SetAttribute("title", b.file)
		end
		local thumb = doc:CreateElement("div")
		thumb:SetClass("tf-biome-thumb", true)
		tile:AppendChild(thumb)
		local name = doc:CreateElement("div")
		name:SetClass("tf-biome-name", true)
		name.inner_rml = b.name or b.key
		tile:AppendChild(name)
		tile:AddEventListener("mousedown", function(_event)
			if widgetState.pickBiome then
				widgetState.pickBiome(b.key)
			end
		end, false)
		row:AppendChild(tile)
		widgetState.tsBiomeTileEls[#widgetState.tsBiomeTileEls + 1] = { el = thumb, tex = b.thumb, crop = b.thumbCrop }
	end
	-- Invisible pads keep a short last row at tile width (flex: 1 1 0).
	local rem = #rows % 3
	if row and rem > 0 then
		for _ = 1, 3 - rem do
			local pad = doc:CreateElement("div")
			pad:SetClass("tf-biome-tile", true)
			pad:SetClass("tf-biome-pad", true)
			row:AppendChild(pad)
		end
	end
end

-- Push the knob values into the ts-slider-* rows (slider + numbox), skipping
-- the slider being dragged. `only` = nil for every row, or a key set (see
-- DEPOSIT_KNOBS) to stamp just those rows.
local function stampKnobRows(doc, ctx, knobs, only)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local cache = widgetState.tsLastVal
	local ds = uiState.draggingSlider
	uiState.updatingFromCode = true
	local stamped = false
	local stampedKeys = nil -- /tfsliders: which knobs this pass restamped
	for _, k in ipairs(KNOBS) do
		local key = k[1]
		local v = knobs[key]
		if v ~= nil and ds ~= ("ts-" .. key) and (only == nil or only[key]) then
			local id = "ts-slider-" .. key
			local slStr = tostring(v)
			if cache[id] ~= slStr then
				cache[id] = slStr
				local sl = doc:GetElementById(id)
				if sl then
					sl:SetAttribute("value", slStr)
					stamped = true
					stampedKeys = stampedKeys and (stampedKeys .. "," .. key) or key
				end
				local nb = doc:GetElementById(id .. "-numbox")
				if nb then
					nb:SetAttribute("value", string.format(k[2], v))
				end
			end
		end
	end
	uiState.updatingFromCode = false
	-- RmlUi delivers the change events these stamps raise on a LATER frame, when
	-- updatingFromCode is already false. onTilesetKnob uses this timestamp to drop
	-- that echo; otherwise each restamp (a biome swap seeds a dozen knobs) writes
	-- clamped slider values back into the knobs and the drift compounds per swap.
	if stamped then
		uiState.tsStampFrame = Spring.GetDrawFrame()
		widgetState.tsStampKeys = stampedKeys
	end
end

local function cssColor(r, g, b)
	local function ch(v)
		return math.floor(math.max(0, math.min(1, v or 1)) * 255 + 0.5)
	end
	return string.format("background-color: #%02x%02x%02x;", ch(r), ch(g), ch(b))
end

local function rebuildRampList(doc, ctx, T)
	local widgetState = ctx.widgetState
	local listEl = doc:GetElementById("ts-ramp-list")
	if not (listEl and T.getRamps and T.getRamp) then
		return
	end
	local files = T.getRamps(false) or {}
	local current = T.getRamp() or ""
	local sig = current .. "|" .. table.concat(files, "|")
	if widgetState.tsRampListSig == sig then
		return
	end
	widgetState.tsRampListSig = sig
	-- The ramp folder belongs to the shader build, so ask it rather than guess.
	local dirEl = doc:GetElementById("ts-ramp-dir")
	if dirEl and T.getRampDir then
		dirEl.inner_rml = tostring(T.getRampDir())
	end
	listEl.inner_rml = ""
	if #files == 0 then
		listEl.inner_rml = '<div class="tf-hm-empty">No images in '
			.. tostring(T.getRampDir and T.getRampDir() or "Terraform Brush/Ramps/")
			.. " yet. Drop a gradient PNG in and hit Rescan folder.</div>"
		return
	end
	for _, name in ipairs(files) do
		local item = doc:CreateElement("div")
		item:SetClass("tf-hm-row", true)
		if name == current then
			item:SetClass("ts-ramp-current", true)
		end
		local safe = tostring(name):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
		item.inner_rml = '<div class="tf-hm-row-line"><div class="tf-hm-mapname">' .. safe .. "</div></div>"
		item:AddEventListener("click", function(ev)
			---@type table?
			local api = WG.TilesetTerrain
			if api and api.setRamp then
				api.setRamp(name)
				-- A pick with the ramp off would show nothing: switch it on.
				local k = api.getKnobs and api.getKnobs()
				if k and (k.rampMode or 0) == 0 and api.setKnob then
					api.setKnob("rampMode", 1)
				end
				if ctx.playSound then
					ctx.playSound("apply")
				end
			end
			widgetState.tsRampListSig = nil
			ev:StopPropagation()
		end, false)
		listEl:AppendChild(item)
	end
end

-- HEIGHT TINT editor: paint every chip from its knobs, restamp the shared
-- sliders from the SELECTED chip (skipping a dragged channel, with the same
-- echo guard as stampKnobRows), mirror mode state into the data model, and
-- refresh the RAMP file list.
local function syncHeightTint(doc, ctx, knobs, dm)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	if knobs.hgRefMode == nil then
		return
	end
	local ref = math.floor((knobs.hgRefMode or 0) + 0.5)
	if dm.tsHgRef ~= ref then
		dm.tsHgRef = ref
	end
	local cnt = math.floor((knobs.strataCount or 4) + 0.5)
	if dm.tsStrataCount ~= cnt then
		dm.tsStrataCount = cnt
	end
	local m = math.floor((knobs.strataLayerMask or 0) + 0.5)
	local bits = {
		tsStrataBase = (m % 2) >= 1,
		tsStrataInter = (m % 4) >= 2,
		tsStrataCliff = (m % 8) >= 4,
		tsStrataPlat = (m % 16) >= 8,
	}
	for k, v in pairs(bits) do
		if dm[k] ~= v then
			dm[k] = v
		end
	end
	local rm = math.floor((knobs.rampMode or 0) + 0.5)
	if dm.tsRampMode ~= rm then
		dm.tsRampMode = rm
	end
	local sc = math.floor((knobs.stopsCount or 3) + 0.5)
	if dm.tsStopsCount ~= sc then
		dm.tsStopsCount = sc
	end
	local sm = math.floor((knobs.stopsMode or 1) + 0.5)
	if dm.tsStopsMode ~= sm then
		dm.tsStopsMode = sm
	end
	local target = dm.tsHgTarget
	if not HG_TARGETS[target] then
		target = "low"
		dm.tsHgTarget = target
	end
	local tname = HG_TARGET_NAMES[target] or target
	if dm.tsHgTargetName ~= tname then
		dm.tsHgTargetName = tname
	end

	-- chips
	local chipCache = widgetState.tsHgChipLast
	if not chipCache then
		chipCache = {}
		widgetState.tsHgChipLast = chipCache
	end
	for t in pairs(HG_TARGETS) do
		local cr, cg, cb = hgGet(knobs, t)
		local css = cr and cssColor(cr, cg, cb) or nil
		if css and chipCache[t] ~= css then
			chipCache[t] = css
			local el = doc:GetElementById("ts-hg-chip-" .. t)
			if el then
				el:SetAttribute("style", css)
			end
		end
	end

	-- shared editor (R/G/B and H/S/V sliders) and preview bar for the selected chip
	local r, g, b, h, s, v = hgGet(knobs, target)
	if r and g and b then
		local css = cssColor(r, g, b)
		if widgetState.tsHgPrevLast ~= css then
			widgetState.tsHgPrevLast = css
			local el = doc:GetElementById("ts-hg-preview")
			if el then
				el:SetAttribute("style", css)
			end
		end
		local sig =
			table.concat({ target, tostring(r), tostring(g), tostring(b), tostring(h), tostring(s), tostring(v) }, "|")
		if widgetState.tsHgTrioLast ~= sig then
			widgetState.tsHgTrioLast = sig
			local vals = { R = r, G = g, B = b, H = h, S = s, V = v }
			local ds = uiState.draggingSlider
			uiState.updatingFromCode = true
			local stamped = false
			for _, C in ipairs(HG_CHANNELS) do
				local c = C:lower()
				if ds ~= ("ts-hg-" .. c) then
					local sl = doc:GetElementById("ts-hg-slider-" .. c)
					if sl then
						sl:SetAttribute("value", tostring(vals[C]))
						stamped = true
					end
					local nb = doc:GetElementById("ts-hg-slider-" .. c .. "-numbox")
					if nb then
						nb:SetAttribute("value", string.format((C == "H") and "%.3f" or "%.2f", vals[C]))
					end
				end
			end
			uiState.updatingFromCode = false
			if stamped then
				uiState.tsStampFrame = Spring.GetDrawFrame()
			end
		end
	end

	-- ramp file label and list
	---@type table?
	local T = WG.TilesetTerrain
	if T and T.getRamp then
		local cur, err = T.getRamp()
		local label = (cur and cur ~= "") and cur or "none"
		if err and err ~= "" then
			label = label .. " (" .. err .. ")"
		end
		if dm.tsRampFile ~= label then
			dm.tsRampFile = label
		end
		rebuildRampList(doc, ctx, T)
	end
end

-- SURFACE sync hook: the AUTOMATIC DEPOSIT rows (FILL AND SEED) are tileset
-- knobs, so keep them current while the TILESET window is closed.
function M.syncDeposit(doc, ctx)
	if not doc or not WG.TilesetTerrain or not ctx.widgetState.tsLastVal then
		return
	end
	local knobs = WG.TilesetTerrain.getKnobs and WG.TilesetTerrain.getKnobs()
	if knobs then
		stampKnobRows(doc, ctx, knobs, DEPOSIT_KNOBS)
	end
end

-- SHADER UPDATE row. Deliberately NOT gated on WG.TilesetTerrain: it must work
-- when the shader widget is missing or stale. Hidden without Team Sync.
-- Matched against the shader manifest's brush_versions; patch releases keep the minor.
local BRUSH_VERSION = "1.18"

local function shaderFitsBrush(shader)
	local wanted = shader.brush_versions
	if type(wanted) ~= "table" or #wanted == 0 then
		return true -- a manifest that names no brush release fits every brush
	end
	for _, value in ipairs(wanted) do
		if tostring(value) == BRUSH_VERSION then
			return true
		end
	end
	return false
end

local function shaderSize(bytes)
	local count = tonumber(bytes) or 0
	if count < 1024 * 1024 then
		return string.format("%.0f KB", count / 1024)
	end
	return string.format("%.0f MB", count / (1024 * 1024))
end

function M.syncShader(doc, ctx)
	local dm = ctx.widgetState.dmHandle
	if not dm or not dm.envTilesetVisible then
		return
	end
	local project = WG.MapProject
	local client = project and project.library
	local shader = client and client.shader and client.shader()
	if not shader or not ctx.widgetState.teamSyncEnabled then
		dm.tsShaderSyncShown = false
		return
	end
	dm.tsShaderSyncShown = true
	if not client.state.online then
		-- Team Sync is not running: the row stays and says so, and clicking it
		-- opens the start card in the Projects window.
		if dm.tsShaderSyncState ~= "offline" then
			dm.tsShaderSyncState = "offline"
		end
		local offline = tfStrings.text("shaderOffline")
		if dm.tsShaderSyncLabel ~= offline then
			dm.tsShaderSyncLabel = offline
		end
		return
	end
	local code = tostring(shader.code or "")
	local version = tostring(shader.shader_version or "")
	local state, label
	if client.isBusy() or code == "unchecked" or code == "" then
		state = "checking"
		label = tfStrings.text("shaderChecking")
	elseif code == "synced" then
		state = "synced"
		label = tfStrings.text("shaderSynced", { version = version })
	elseif code == "update" and shaderFitsBrush(shader) then
		state = "update"
		label = tfStrings.text("shaderUpdate", {
			version = version,
			size = shaderSize(shader.bytes),
		})
	elseif code == "update" then
		state = "mismatch"
		label = tfStrings.text("shaderMismatch", { version = version })
	else
		state = "error"
		label = tfStrings.text("shaderError")
	end
	if dm.tsShaderSyncState ~= state then
		dm.tsShaderSyncState = state
	end
	if dm.tsShaderSyncLabel ~= label then
		dm.tsShaderSyncLabel = label
	end
end

-- LAYER SORT A/B (shader build 19+). The SORT chips switch the look and the
-- slider set: OLD shows the original sections, NEW shows the 3-band groups and
-- hides rows that only feed the old sort. Both knob sets persist, so switching
-- loses nothing. A shader without the switch keeps the chips, flips and NEW
-- sections hidden.
local OLD_SORT_FRAMES = { "frame-ts-cliffs", "frame-ts-place", "frame-ts-slot4" }
local NEW_SORT_FRAMES = { "frame-ts-rockcol", "frame-ts-sortn", "frame-ts-sorta", "frame-ts-topscol" }
-- single rows (found by their slider) that only feed the old sort
local OLD_SORT_ROWS = {
	"footNormStrength",
	"platNormStrength",
	"scaleFoot",
	"scalePlat",
	"albTilePlat",
	"albedoSortMode",
	"staggerAmount",
	"lumaBlend",
	"lumaTops",
	"heightBlend",
	"heightDepth",
	"splatPunchPlat",
	"platTintR",
	"platTintG",
	"platTintB",
}

-- the angle a dot-space value puts on the ground (1 flat = 0 deg, 0 = a wall)
local function degOf(d)
	return math.deg(math.acos(math.max(0, math.min(1, tonumber(d) or 1))))
end

local function bandSummary(ls, lf, us, uf)
	return string.format(
		"Top until %.0f deg, full intermediary %.0f to %.0f deg, full cliff from %.0f deg.",
		degOf((us or 0) + (uf or 0)),
		degOf(us),
		degOf(ls),
		degOf((ls or 0) - (lf or 0))
	)
end

local function syncSortModel(doc, ctx, knobs)
	local widgetState = ctx.widgetState
	local T = WG.TilesetTerrain
	local has = T.getSortModel ~= nil and knobs.nLowerStart ~= nil
	local newOn = has and T.getSortModel() == 1
	local sig = tostring(has) .. ":" .. tostring(newOn)
	if widgetState.tsSortLast ~= sig then
		widgetState.tsSortLast = sig
		local function hide(id, on)
			local el = doc:GetElementById(id)
			if el then
				el:SetClass("hidden", on)
			end
		end
		-- RmlUi: .flex beats .hidden at equal specificity, so flex rows hide by an
		-- inline style. None of these rows has a style of its own.
		local function hideFlex(el, on)
			if el then
				el:SetClass("hidden", on)
				-- Set both ways: RmlUi keeps an inline display after RemoveAttribute.
				el:SetAttribute("style", on and "display: none;" or "display: flex;")
			end
		end
		hideFlex(doc:GetElementById("ts-sort-row"), not has)
		hide("ts-sort-desc", not has)
		for _, id in ipairs(OLD_SORT_FRAMES) do
			hide(id, newOn)
		end
		for _, id in ipairs(NEW_SORT_FRAMES) do
			hide(id, not newOn)
		end
		for _, key in ipairs(OLD_SORT_ROWS) do
			local el = doc:GetElementById("ts-slider-" .. key)
			hideFlex(el and el.parent_node, newOn)
		end
		-- The flips and the per-pass debug views need shader build 19+; the two
		-- normal multipliers work on any build.
		for _, id in ipairs({ "btn-ts-flip-inter", "btn-ts-flip-cliff" }) do
			local el = doc:GetElementById(id)
			hideFlex(el and el.parent_node, not has)
		end
		hide("ts-rocknorm-note", not has)
		hide("btn-ts-dbg-sortn", not has)
		hide("btn-ts-dbg-sorta", not has)
		local o, n = doc:GetElementById("btn-ts-sort-old"), doc:GetElementById("btn-ts-sort-new")
		if o then
			o:SetClass("active", not newOn)
		end
		if n then
			n:SetClass("active", newOn)
		end
		local d = doc:GetElementById("ts-sort-desc")
		if d then
			d.inner_rml = newOn
					and "NEW: three layers (top, intermediary, cliff) placed by slope, twice: normal maps by the terrain's slope, colour by the normal-mapped slope. No plateau, no foothills. Each biome opens in the sort its settings were tuned in; this switch compares the two until the next biome pick, and is never saved into a preset or map."
				or "OLD: the layer sort biomes were tuned with before MrBob's three layers. Each biome opens in the sort its settings were tuned in; this switch compares the two until the next biome pick, and is never saved into a preset or map."
		end
	end
	if not has then
		return
	end
	local fi, fc = (knobs.flipIntermediateNormal or 0) >= 1, (knobs.flipCliffNormal or 0) >= 1
	local fsig = tostring(fi) .. tostring(fc)
	if widgetState.tsFlipLast ~= fsig then
		widgetState.tsFlipLast = fsig
		for _, f in ipairs({ { "btn-ts-flip-inter", fi }, { "btn-ts-flip-cliff", fc } }) do
			local el = doc:GetElementById(f[1])
			if el then
				el:SetAttribute(
					"src",
					f[2] and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png"
				)
			end
		end
	end
	local sn = bandSummary(knobs.nLowerStart, knobs.nLowerFade, knobs.nUpperStart, knobs.nUpperFade)
	local sa = bandSummary(knobs.aLowerStart, knobs.aLowerFade, knobs.aUpperStart, knobs.aUpperFade)
	if widgetState.tsSortSumLast ~= sn .. sa then
		widgetState.tsSortSumLast = sn .. sa
		local en, ea = doc:GetElementById("ts-sortn-sum"), doc:GetElementById("ts-sorta-sum")
		if en then
			en.inner_rml = sn
		end
		if ea then
			ea.inner_rml = sa
		end
	end
end

function M.sync(doc, ctx, setSummary)
	if not doc or not WG.TilesetTerrain then
		return
	end
	local widgetState = ctx.widgetState
	-- Preset files load once per shader widget instance, window open or not: a
	-- shader reload replaces the WG table and drops its in-memory presets.
	local tsW = WG.TilesetTerrain
	if tsW.addUserPreset and widgetState.tsPresetFilesFor ~= tsW then
		widgetState.tsPresetFilesFor = tsW
		loadPresetFiles(tsW)
	end
	local dm = widgetState.dmHandle
	-- The window is independent of the active tool, so being open is the only gate.
	if not dm or not dm.envTilesetVisible then
		return
	end

	-- The mirrors below follow the widget, so startup state and console
	-- /tileset commands show up too.
	-- SHADER switch: dm.tsShaderOn lights the button and grays PAINT SURFACES;
	-- with the shader off every tuning section is inert, so gray those too.
	if WG.TilesetTerrain.isActive then
		local on = WG.TilesetTerrain.isActive() and true or false
		if dm.tsShaderOn ~= on then
			dm.tsShaderOn = on
		end
		if widgetState.tsShaderLast ~= on then
			widgetState.tsShaderLast = on
			if ctx.setDisabledIds then
				ctx.setDisabledIds(doc, TUNING_FRAMES, not on)
			end
		end
	end

	-- BIOME LIBRARY active tile
	if WG.TilesetTerrain.getActiveBiome then
		local _, _, bkey = WG.TilesetTerrain.getActiveBiome()
		if bkey and dm.tsBiome ~= bkey then
			dm.tsBiome = bkey
		end
	end

	-- EXTRA LAYER (slot 4): mode buttons, plus the two shared sliders' titles,
	-- the description and the gray-out for the active mode.
	if WG.TilesetTerrain.getSlot4Mode then
		local _, mname = WG.TilesetTerrain.getSlot4Mode()
		if mname and dm.tsSlot4Mode ~= mname then
			dm.tsSlot4Mode = mname
		end
		if mname and widgetState.tsSlot4Last ~= mname then
			widgetState.tsSlot4Last = mname
			-- { height-slider title, blend-slider title, description, sliders inert }
			local modes = {
				plateau = {
					"Starts at height",
					"Edge width",
					"Flat ground above the height slider becomes this layer, like a mountain cap. The LAYERS tool's 4th channel also paints it anywhere.",
					false,
				},
				detail = {
					"(not used)",
					"(not used)",
					"Appears only where the LAYERS tool's 4th channel paints it. Unlike SURFACE variants it brings its own relief and roughness.",
					true,
				},
				interm2 = {
					"Amount",
					"Patch edge",
					"A second scree: takes over patches of the intermediate band so it reads less uniform. Amount 0 = none, 1 = the whole band.",
					false,
				},
				cliff2 = {
					"Splits at height",
					"Edge width",
					"A second rock: cliff faces above the height slider use this texture instead, reading as strata.",
					false,
				},
				off = {
					"(slot off)",
					"(slot off)",
					"The layer is disabled and its texture lookups are skipped, which renders slightly faster.",
					true,
				},
			}
			local m = modes[mname]
			if m then
				local e1 = doc:GetElementById("ts-label-platHeight")
				local e2 = doc:GetElementById("ts-label-platBlend")
				local ed = doc:GetElementById("ts-slot4-desc")
				if e1 then
					e1.inner_rml = m[1]
				end
				if e2 then
					e2.inner_rml = m[2]
				end
				if ed then
					ed.inner_rml = m[3]
				end
				if ctx.setDisabledIds then
					ctx.setDisabledIds(doc, { "ts-row-platHeight", "ts-row-platBlend" }, m[4])
					ctx.setDisabledIds(doc, { "ts-slot4-mat-grid" }, mname == "off")
				end
			end
		end
	end
	-- BIOME LIBRARY tiles: rebuild when the manifest list, a thumbnail or the
	-- active biome changes.
	---@type table?
	local tsT = WG.TilesetTerrain
	if tsT and tsT.getBiomes then
		local rows = tsT.getBiomes()
		local sigParts = { tostring(dm.tsBiome) }
		for i = 1, #rows do
			sigParts[#sigParts + 1] = rows[i].key .. "=" .. tostring(rows[i].thumb)
		end
		local sig = table.concat(sigParts, "|")
		if widgetState.tsBiomeSig ~= sig then
			widgetState.tsBiomeSig = sig
			rebuildBiomePalette(doc, ctx, rows, dm.tsBiome)
		end
	end

	-- Material picker tiles: rebuild when the biome catalog or the pick changes.
	if WG.TilesetTerrain.getSlot4Materials then
		local list, bkey, current = WG.TilesetTerrain.getSlot4Materials()
		local sigParts = { tostring(bkey), tostring(current or "") }
		for i = 1, #list do
			sigParts[#sigParts + 1] = list[i].asset
		end
		local sig = table.concat(sigParts, "|")
		if widgetState.ts4PaletteSig ~= sig then
			widgetState.ts4PaletteSig = sig
			rebuildS4Palette(doc, ctx, list, current)
		end
	end

	-- METAL SPOTS style and the glow-light checkbox
	if WG.TilesetTerrain.getActiveMetalStyle then
		local _, _, mkey = WG.TilesetTerrain.getActiveMetalStyle()
		if mkey and dm.tsMetalStyle ~= mkey then
			dm.tsMetalStyle = mkey
		end
	end
	if WG.TilesetTerrain.getMetalLights then
		local glow = WG.TilesetTerrain.getMetalLights() and true or false
		if dm.tsGlowOn ~= glow then
			dm.tsGlowOn = glow -- grays the GLOW LIGHT block while the light is off
		end
		if widgetState.tsGlowLast ~= glow then
			widgetState.tsGlowLast = glow
			local el = doc:GetElementById("btn-ts-metal-glow")
			if el then
				el:SetAttribute(
					"src",
					glow and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png"
				)
			end
		end
	end

	local knobs = WG.TilesetTerrain.getKnobs and WG.TilesetTerrain.getKnobs()
	if not knobs then
		return
	end

	stampKnobRows(doc, ctx, knobs, nil)

	syncSortModel(doc, ctx, knobs)

	-- LAYER PLACEMENT: past 1.0 the scatter's noise multiplier goes negative and
	-- wipes the intermediate layer. Live while dragging: the knob is already written.
	local scatterOver = (tonumber(knobs.intermediateScatter) or 0) > 1.0
	if widgetState.tsScatterOver ~= scatterOver or widgetState.tsScatterDoc ~= doc then
		widgetState.tsScatterOver, widgetState.tsScatterDoc = scatterOver, doc
		local warn = doc:GetElementById("ts-scatter-warn")
		if warn then
			warn:SetClass("hidden", not scatterOver)
		end
	end

	-- GLOW LIGHT preview bar, driven by the knobs so a style swap, a section
	-- RESET or a project load show up too.
	if knobs.metalGlowR and knobs.metalGlowG and knobs.metalGlowB then
		local function ch(v)
			return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5)
		end
		local css = string.format(
			"background-color: #%02x%02x%02x;",
			ch(knobs.metalGlowR),
			ch(knobs.metalGlowG),
			ch(knobs.metalGlowB)
		)
		if widgetState.tsGlowPrevLast ~= css then
			widgetState.tsGlowPrevLast = css
			local el = doc:GetElementById("ts-glow-preview")
			if el then
				el:SetAttribute("style", css)
			end
		end
	end

	syncHeightTint(doc, ctx, knobs, dm)

	-- On/off knobs drawn as a checkbox or button rather than a slider are mirrored by hand.
	if knobs.albDecouple ~= nil then
		local dec = knobs.albDecouple >= 1
		if widgetState.tsAlbDecoupleLast ~= dec then
			widgetState.tsAlbDecoupleLast = dec
			local el = doc:GetElementById("btn-ts-alb-decouple")
			if el then
				el:SetAttribute(
					"src",
					dec and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png"
				)
			end
		end
	end

	if knobs.cliffProtect ~= nil then
		local cp = knobs.cliffProtect >= 1
		if dm.tsCliffProtectOn ~= cp then
			dm.tsCliffProtectOn = cp
		end
	end

	-- debugView drives the DEBUG multi-toggle highlight.
	if knobs.debugView ~= nil and dm.tsDebugView ~= knobs.debugView then
		dm.tsDebugView = knobs.debugView
	end

	-- PERFORMANCE: the active quality tier lights its preset button.
	if WG.TilesetTerrain.getQuality then
		local q = WG.TilesetTerrain.getQuality()
		if q and dm.tsQuality ~= q then
			dm.tsQuality = q
		end
	end

	if setSummary then
		local on = WG.TilesetTerrain.isActive and WG.TilesetTerrain.isActive()
		setSummary("TILESET", "#fdc04c", "", on and "shader on" or "shader off")
	end
end

return M
