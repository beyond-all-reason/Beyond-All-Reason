-- tf_tileset.lua: Tileset Terrain tuning UI module for gui_terraform_brush.
-- Folds the /tileset prototype's knob panel into the TF brush as the TILESET
-- floating window, opened from the SCENE menu and independent of the active
-- tool. The knobs live in the write-dir widget dev_tileset_terrain.lua and are
-- driven through WG.TilesetTerrain (getKnobs/setKnob/reset). The RML rows are
-- generated from the same spec below, so this list and the .rml stay in step.
local M = {}

-- Capture WG as an upvalue: RmlUi-dispatched event closures can run outside the
-- host widget's global env, where the global `WG` reads as nil.
local WG = WG

-- { knob key, numbox display format }. Order is irrelevant here (lookup by key).
local KNOBS = {
	{ "scaleBase", "%.0f" },
	{ "scaleIntermediate", "%.0f" },
	{ "scaleCliff", "%.0f" },
	{ "scalePlat", "%.0f" },
	{ "scaleFoot", "%.0f" },
	-- albedo tiling per flat layer, as a multiple of that layer's shape scale
	-- (albDecouple is the checkbox below, not a slider — same as debugView)
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
	{ "intermediateScatter", "%.2f" },
	{ "intermediateStartDeg", "%.1f" },
	{ "intermediateFullDeg", "%.1f" },
	-- cliffProtect is not here: it is on/off, so it renders as the PROTECT
	-- CLIFFS highlight button (mirrored to dm.tsCliffProtectOn below), not a
	-- 0/1 slider.
	{ "splatInfluence", "%.2f" },
	{ "surfClaim", "%.2f" },
	{ "splatPunchIntermediate", "%.2f" },
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
	{ "lumaTops", "%.2f" },
	{ "heightBlend", "%.2f" },
	{ "heightDepth", "%.2f" },
	{ "curvHighlight", "%.2f" },
	{ "curvShadow", "%.2f" },
	{ "curvRadius", "%.0f" },
	{ "specStrength", "%.2f" },
	{ "specAA", "%.2f" },
	{ "hemiAmbient", "%.2f" },
	{ "exposure", "%.2f" },
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
	{ "metalReflect", "%.2f" },
	{ "metalRoughMul", "%.2f" },
	{ "metalScale", "%.0f" },
	{ "metalRelief", "%.2f" },
	{ "metalEdge", "%.2f" },
	-- silhouette band: which terrain layer skirts a spot (0 base, 1 intermediate,
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
	"frame-ts-slot4",
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
	-- fresh document: the section gray-out is back at its markup default, so
	-- drop the cache and let the next M.sync re-apply it from the widget
	ctx.widgetState.tsShaderLast = nil
	ctx.widgetState.tsAlbDecoupleLast = nil
	-- SLOT 4 label/material caches: markup defaults are the plateau-mode texts,
	-- so force one re-apply from the widget on a fresh document
	ctx.widgetState.tsSlot4Last = nil
	ctx.widgetState.tsSlot4MatLast = nil
	-- same for the METAL SPOTS suite toggle's gray-out
	ctx.widgetState.tsDetail3Last = nil
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
	-- Only push values while the TILESET floating window (SCENE menu) is open.
	-- It is independent of the active tool by design, so this is the only gate.
	if not dm or not dm.envTilesetVisible then
		return
	end

	-- Master SHADER button: mirror the widget (covers the persisted-off startup
	-- state and console-driven /tileset shader). dm.tsShaderOn drives the
	-- button highlight AND grays the PAINT SURFACES neighbour; with the shader
	-- off every tuning section below is inert too, so gray those out here.
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

	-- Keep the BIOME LIBRARY active-tile highlight in sync with the widget
	-- (covers the initial state + console-driven /tileset biome changes).
	if WG.TilesetTerrain.getActiveBiome then
		local _, _, bkey = WG.TilesetTerrain.getActiveBiome()
		if bkey and dm.tsBiome ~= bkey then
			dm.tsBiome = bkey
		end
	end

	-- EXTRA LAYER section (slot 4): mirror the mode buttons, retitle the two
	-- reused sliders and the description line for the active mode, and gray
	-- out the rows the mode ignores (covers startup + console /tileset slot4).
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
					ctx.setDisabledIds(doc, { "ts-row-slot4-mat" }, mname == "off")
				end
			end
		end
	end
	if WG.TilesetTerrain.getSlot4State then
		local st = WG.TilesetTerrain.getSlot4State()
		local mat = st.material or "biome pick"
		if widgetState.tsSlot4MatLast ~= mat then
			widgetState.tsSlot4MatLast = mat
			local el = doc:GetElementById("ts-slot4-mat-name")
			if el then
				el.inner_rml = mat
			end
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
	-- METAL SPOTS suite toggle (SPOT TEXTURE / DETAIL SLOT 3): mirror the
	-- widget into both windows' flags, and gray the metal body while the suite
	-- is repurposed — every metal knob below the toggle is inert then.
	if WG.TilesetTerrain.getDetail3 then
		local d3 = WG.TilesetTerrain.getDetail3() and true or false
		if dm.tsDetail3On ~= d3 then
			dm.tsDetail3On = d3
		end
		if dm.surfDetail3 ~= d3 then
			dm.surfDetail3 = d3
		end
		if widgetState.tsDetail3Last ~= d3 then
			widgetState.tsDetail3Last = d3
			if ctx.setDisabledIds then
				ctx.setDisabledIds(doc, { "ts-metal-body" }, d3)
			end
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
	local stamped = false
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
					stamped = true
				end
				local nb = doc:GetElementById(id .. "-numbox")
				if nb then
					nb:SetAttribute("value", string.format(k[2], v))
				end
			end
		end
	end
	uiState.updatingFromCode = false
	-- RmlUi delivers the change events these SetAttribute stamps raise on a
	-- LATER frame, when updatingFromCode is already false. onTilesetKnob uses
	-- this timestamp to drop that deferred echo — otherwise every programmatic
	-- restamp (biome swap seeds ~a dozen knobs) reads back clamped/stale slider
	-- values into the knob table, compounding per swap (the "red intermediate area
	-- grows with every Teizer<->Enborelde swap until it pins" ratchet).
	if stamped then
		uiState.tsStampFrame = Spring.GetDrawFrame()
	end

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

	-- PROTECT CLIFFS button highlight: a knob, but rendered as a button rather
	-- than a 0/1 slider, so mirror it by hand (covers startup, biome swaps and
	-- console /tileset changes).
	if knobs.cliffProtect ~= nil then
		local cp = knobs.cliffProtect >= 1
		if dm.tsCliffProtectOn ~= cp then
			dm.tsCliffProtectOn = cp
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
