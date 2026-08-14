-- tf_tileset.lua: Tileset Terrain tuning UI module for gui_terraform_brush.
-- Folds the /tileset prototype's knob panel into the TF brush as the TILESET
-- tool. The knobs live in the write-dir widget dev_tileset_terrain.lua and are
-- driven through WG.TilesetTerrain (getKnobs/setKnob/reset). The RML rows are
-- generated from the same spec below, so this list and the .rml stay in step.
local M = {}

-- Capture WG as an upvalue: RmlUi-dispatched event closures can run outside the
-- host widget's global env, where the global `WG` reads as nil.
local WG = WG

-- { knob key, numbox display format }. Order is irrelevant here (lookup by key).
local KNOBS = {
	{ "scaleSoil", "%.0f" },
	{ "scaleRocky", "%.0f" },
	{ "scaleCliff", "%.0f" },
	{ "scalePlat", "%.0f" },
	{ "scaleFoot", "%.0f" },
	-- albedo tiling per flat layer, as a multiple of that layer's shape scale
	-- (albDecouple is the checkbox below, not a slider — same as debugView)
	{ "albTileSoil", "%.2f" },
	{ "albTileRocky", "%.2f" },
	{ "albTilePlat", "%.2f" },
	{ "normalStrength", "%.2f" },
	{ "soilNormStrength", "%.2f" },
	{ "rockyNormStrength", "%.2f" },
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
	{ "gravelHeight", "%.2f" },
	{ "gravelBlend", "%.2f" },
	{ "talusPatch", "%.2f" },
	{ "talusStartDeg", "%.1f" },
	{ "talusFullDeg", "%.1f" },
	{ "splatInfluence", "%.2f" },
	{ "cliffProtect", "%d" },
	{ "splatPunchTalus", "%.2f" },
	{ "splatPunchCliff", "%.2f" },
	{ "splatPunchPlat", "%.2f" },
	{ "antiTileWarp", "%.0f" },
	{ "parallaxAmp", "%.2f" },
	{ "macroVar", "%.2f" },
	{ "macroLod", "%.1f" },
	{ "albedoSortMode", "%d" },
	{ "staggerAmount", "%.2f" },
	{ "maskScale1", "%.0f" },
	{ "maskScale2", "%.0f" },
	{ "lumaBlend", "%.2f" },
	{ "heightBlend", "%.2f" },
	{ "heightDepth", "%.2f" },
	{ "curvHighlight", "%.2f" },
	{ "curvShadow", "%.2f" },
	{ "curvRadius", "%.0f" },
	{ "specStrength", "%.2f" },
	{ "specAA", "%.2f" },
	{ "hemiAmbient", "%.2f" },
	{ "aoStrength", "%.2f" },
	{ "wetBand", "%.0f" },
	{ "wetGloss", "%.2f" },
	{ "shadowMode", "%d" },
	{ "shadowBias", "%.4f" },
	{ "smtBlend", "%.2f" },
	{ "oldCliffBlend", "%.2f" },
	{ "tintR", "%.2f" },
	{ "tintG", "%.2f" },
	{ "tintB", "%.2f" },
	{ "soilTintR", "%.2f" },
	{ "soilTintG", "%.2f" },
	{ "soilTintB", "%.2f" },
	{ "rockyTintR", "%.2f" },
	{ "rockyTintG", "%.2f" },
	{ "rockyTintB", "%.2f" },
	{ "cliffTintR", "%.2f" },
	{ "cliffTintG", "%.2f" },
	{ "cliffTintB", "%.2f" },
	{ "platTintR", "%.2f" },
	{ "platTintG", "%.2f" },
	{ "platTintB", "%.2f" },
	{ "metalInfluence", "%.2f" },
	{ "metalness", "%.2f" },
	{ "metalReflect", "%.2f" },
	{ "metalRoughMul", "%.2f" },
	{ "metalScale", "%.0f" },
	{ "metalRelief", "%.2f" },
	{ "metalEdge", "%.2f" },
	-- silhouette band: which terrain layer skirts a spot (0 soil, 1 talus,
	-- 2 cliff, 3 plateau) and how much it darkens
	{ "metalApronLayer", "%d" },
	{ "metalApronTone", "%.2f" },
	{ "metalTintR", "%.2f" },
	{ "metalTintG", "%.2f" },
	{ "metalTintB", "%.2f" },
	-- debugView is not a slider anymore — it's the DEBUG multi-toggle, mirrored to
	-- dm.tsDebugView in M.sync below (so it's intentionally omitted from this list).
}

-- Every section under the SHADER switch: grayed out while the switch is off,
-- because nothing in them affects an engine-rendered map.
local TUNING_FRAMES = {
	"frame-ts-library",
	"frame-ts-metal",
	"frame-ts-scale",
	"frame-ts-normals",
	"frame-ts-cliffs",
	"frame-ts-place",
	"frame-ts-blend",
	"frame-ts-curv",
	"frame-ts-light",
	"frame-ts-oldmap",
	"frame-ts-biome",
	"frame-ts-tints",
	"frame-ts-debug",
	"frame-ts-presets",
}

function M.attach(doc, ctx)
	local trackSliderDrag = ctx.trackSliderDrag
	ctx.widgetState.tsLastVal = ctx.widgetState.tsLastVal or {}
	-- fresh document: the SHADER checkbox is back at its markup default, so drop
	-- the cache and let the next M.sync re-stamp it from the widget
	ctx.widgetState.tsShaderLast = nil
	ctx.widgetState.tsAlbDecoupleLast = nil
	-- Slider drag tracking only. Section collapse for the ts-* frames is wired
	-- centrally in tf_environment.lua (envSectionToggle), like every other tool.
	for _, k in ipairs(KNOBS) do
		local el = doc:GetElementById("ts-slider-" .. k[1])
		if el and trackSliderDrag then
			trackSliderDrag(el, "ts-" .. k[1])
		end
	end
end

function M.sync(doc, ctx, setSummary)
	if not doc or not WG.TilesetTerrain then
		return
	end
	local widgetState = ctx.widgetState
	local dm = widgetState.dmHandle
	-- Only push values while the TILESET tool owns the panel.
	if not dm or dm.activeTool ~= "ts" then
		return
	end

	-- Master SHADER switch: mirror the widget (covers the persisted-off startup
	-- state and console-driven /tileset shader). With the shader off every tuning
	-- section below it is inert, so gray them out.
	if WG.TilesetTerrain.isActive then
		local on = WG.TilesetTerrain.isActive() and true or false
		if widgetState.tsShaderLast ~= on then
			widgetState.tsShaderLast = on
			local el = doc:GetElementById("btn-ts-shader")
			if el then
				el:SetAttribute(
					"src",
					on and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png"
				)
			end
			if ctx.setDisabledIds then
				ctx.setDisabledIds(doc, TUNING_FRAMES, not on)
			end
		end
	end

	-- Keep the BIOME LIBRARY active-tile highlight in sync with the widget
	-- (covers the initial state + console-driven /tileset biome changes).
	if WG.TilesetTerrain.getActiveBiome then
		local _, _, bkey = WG.TilesetTerrain.getActiveBiome()
		if bkey and dm.tsBiome ~= bkey then
			dm.tsBiome = bkey
		end
	end

	-- Same for the METAL SPOTS style tiles + the glow-light checkbox (covers
	-- /tileset metal + /tileset metallights console changes).
	if WG.TilesetTerrain.getActiveMetalStyle then
		local _, _, mkey = WG.TilesetTerrain.getActiveMetalStyle()
		if mkey and dm.tsMetalStyle ~= mkey then
			dm.tsMetalStyle = mkey
		end
	end
	if WG.TilesetTerrain.getMetalLights then
		local glow = WG.TilesetTerrain.getMetalLights() and true or false
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

	local uiState = ctx.uiState
	local cache = widgetState.tsLastVal
	local ds = uiState.draggingSlider
	uiState.updatingFromCode = true
	for _, k in ipairs(KNOBS) do
		local key = k[1]
		local v = knobs[key]
		-- Skip the slider the user is dragging so we don't fight the drag.
		if v ~= nil and ds ~= ("ts-" .. key) then
			local id = "ts-slider-" .. key
			local slStr = tostring(v)
			if cache[id] ~= slStr then
				cache[id] = slStr
				local sl = doc:GetElementById(id)
				if sl then
					sl:SetAttribute("value", slStr)
				end
				local nb = doc:GetElementById(id .. "-numbox")
				if nb then
					nb:SetAttribute("value", string.format(k[2], v))
				end
			end
		end
	end
	uiState.updatingFromCode = false

	-- Decouple-albedo checkbox: a knob, but rendered as a checkbox rather than a
	-- 0/1 slider, so mirror it by hand (covers startup + console /tileset changes).
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

	-- Mirror debugView -> tsDebugView so the DEBUG multi-toggle highlight tracks the
	-- widget (initial state + console-driven /tileset changes); debugView has no slider.
	if knobs.debugView ~= nil and dm.tsDebugView ~= knobs.debugView then
		dm.tsDebugView = knobs.debugView
	end

	if setSummary then
		local on = WG.TilesetTerrain.isActive and WG.TilesetTerrain.isActive()
		setSummary("TILESET", "#fdc04c", "", on and "shader on" or "shader off")
	end
end

return M
