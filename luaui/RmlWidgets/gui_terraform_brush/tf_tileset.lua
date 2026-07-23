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
	{ "scaleSoil", "%.0f" }, { "scaleRocky", "%.0f" }, { "scaleCliff", "%.0f" },
	{ "scalePlat", "%.0f" }, { "scaleFoot", "%.0f" },
	{ "normalStrength", "%.2f" }, { "cliffNormStrength", "%.2f" }, { "footNormStrength", "%.2f" },
	{ "cliffStartDeg", "%.1f" }, { "chunkyCliff", "%d" }, { "foothillsSpanDeg", "%.1f" }, { "footFloor", "%.2f" },
	{ "splatInfluence", "%.2f" }, { "antiTileWarp", "%.0f" }, { "macroVar", "%.2f" }, { "albedoSortMode", "%d" },
	{ "staggerAmount", "%.2f" }, { "maskScale1", "%.0f" }, { "maskScale2", "%.0f" }, { "lumaBlend", "%.2f" },
	{ "curvHighlight", "%.2f" }, { "curvShadow", "%.2f" }, { "curvRadius", "%.0f" },
	{ "specStrength", "%.2f" }, { "hemiAmbient", "%.2f" }, { "aoStrength", "%.2f" }, { "wetBand", "%.0f" },
	{ "shadowMode", "%d" }, { "shadowBias", "%.4f" },
	{ "smtBlend", "%.2f" }, { "oldCliffBlend", "%.2f" },
	{ "tintR", "%.2f" }, { "tintG", "%.2f" }, { "tintB", "%.2f" },
	{ "soilTintR", "%.2f" }, { "soilTintG", "%.2f" }, { "soilTintB", "%.2f" },
	{ "rockyTintR", "%.2f" }, { "rockyTintG", "%.2f" }, { "rockyTintB", "%.2f" },
	{ "cliffTintR", "%.2f" }, { "cliffTintG", "%.2f" }, { "cliffTintB", "%.2f" },
	{ "platTintR", "%.2f" }, { "platTintG", "%.2f" }, { "platTintB", "%.2f" },
	{ "debugView", "%d" },
}

function M.attach(doc, ctx)
	local trackSliderDrag = ctx.trackSliderDrag
	ctx.widgetState.tsLastVal = ctx.widgetState.tsLastVal or {}
	-- Slider drag tracking only. Section collapse for the ts-* frames is wired
	-- centrally in tf_environment.lua (envSectionToggle), like every other tool.
	for _, k in ipairs(KNOBS) do
		local el = doc:GetElementById("ts-slider-" .. k[1])
		if el and trackSliderDrag then trackSliderDrag(el, "ts-" .. k[1]) end
	end
end

function M.sync(doc, ctx, setSummary)
	if not doc or not WG.TilesetTerrain then return end
	local widgetState = ctx.widgetState
	local dm = widgetState.dmHandle
	-- Only push values while the TILESET tool owns the panel.
	if not dm or dm.activeTool ~= "ts" then return end

	local knobs = WG.TilesetTerrain.getKnobs and WG.TilesetTerrain.getKnobs()
	if not knobs then return end

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
				if sl then sl:SetAttribute("value", slStr) end
				local nb = doc:GetElementById(id .. "-numbox")
				if nb then nb:SetAttribute("value", string.format(k[2], v)) end
			end
		end
	end
	uiState.updatingFromCode = false

	if setSummary then
		local on = WG.TilesetTerrain.isActive and WG.TilesetTerrain.isActive()
		setSummary("TILESET", "#fdc04c", "", on and "shader on" or "shader off")
	end
end

return M
