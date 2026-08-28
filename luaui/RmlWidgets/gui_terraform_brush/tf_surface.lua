-- tf_surface.lua: UI module for the SURFACE (soft variant paint) and LAYERS
-- (hard splat-override paint) tools of gui_terraform_brush. Both run as
-- activeTool 'surf' and share this panel; dm.surfMode ('soft'/'hard') picks
-- which sections show. The soft engine lives in the write-dir widget
-- dev_surface_painter.lua (WG.SurfacePainter), the hard engine is the Splat
-- Painter reused headless (WG.SplatPainter); the variant catalog, mask
-- binding and shader taps live in dev_tileset_terrain.lua (WG.TilesetTerrain).
-- Panel: palette tile grid (built imperatively — the variant list is
-- per-biome and dynamic), brush rows, fill/seed, sculpted hint, and the two
-- GROUP tint rows (TOPS / ROCK, meeting 2026-08-05).
local M = {}

-- Capture engine globals as module upvalues: RmlUi-dispatched event closures
-- can run outside the host widget's global env, where bare globals read nil.
local WG = WG
local Spring = Spring

-- Slider ids tracked for drag (change events are declarative in the RML).
local SLIDER_IDS = {
	{ "surf-slider-size", "surf-size" },
	{ "surf-slider-strength", "surf-strength" },
	{ "surf-slider-falloff", "surf-falloff" },
	{ "surf-slider-spacing", "surf-spacing" },
	{ "surf-slider-fill-scale", "surf-fill-scale" },
	{ "surf-slider-fill-seed", "surf-fill-seed" },
	{ "surf-slider-topsTintR", "surf-topsTintR" },
	{ "surf-slider-topsTintG", "surf-topsTintG" },
	{ "surf-slider-topsTintB", "surf-topsTintB" },
	{ "surf-slider-topsDesat", "surf-topsDesat" },
	{ "surf-slider-rockTintR", "surf-rockTintR" },
	{ "surf-slider-rockTintG", "surf-rockTintG" },
	{ "surf-slider-rockTintB", "surf-rockTintB" },
	{ "surf-slider-rockDesat", "surf-rockDesat" },
	-- HARD submode smart-filter sliders (engine = WG.SplatPainter)
	{ "surf-hard-slider-slope-max", "surf-hard-slope-max" },
	{ "surf-hard-slider-alt-min", "surf-hard-alt-min" },
	{ "surf-hard-slider-alt-max", "surf-hard-alt-max" },
}

-- Group tint knobs mirrored from WG.TilesetTerrain (GRADING section).
local TINT_KNOBS = {
	{ "topsTintR", "%.2f" },
	{ "topsTintG", "%.2f" },
	{ "topsTintB", "%.2f" },
	{ "topsDesat", "%.2f" },
	{ "rockTintR", "%.2f" },
	{ "rockTintG", "%.2f" },
	{ "rockTintB", "%.2f" },
	{ "rockDesat", "%.2f" },
}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local trackSliderDrag = ctx.trackSliderDrag

	widgetState.surfControlsEl = doc:GetElementById("tf-surface-controls")
	widgetState.surfPaletteGridEl = doc:GetElementById("surf-palette-grid")
	widgetState.surfSculptGridEl = doc:GetElementById("surf-sculpt-grid")
	widgetState.surfCoverageBarEl = doc:GetElementById("surf-coverage-bar")
	widgetState.surfCovV1El = doc:GetElementById("surf-cov-v1")
	widgetState.surfCovV2El = doc:GetElementById("surf-cov-v2")
	widgetState.surfNowThumbEl = doc:GetElementById("surf-now-thumb")
	widgetState.surfSlotThumbEls = {
		base = doc:GetElementById("surf-slot-base-thumb"),
		doc:GetElementById("surf-slot-1-thumb"),
		doc:GetElementById("surf-slot-2-thumb"),
	}
	widgetState.surfPaletteSectionEl = doc:GetElementById("section-surf-palette")
	-- fresh document: rebuild the palette + re-stamp checkboxes on next sync
	widgetState.surfPaletteSig = nil
	widgetState.surfPaletteEls = {} -- { {el, tex} } for the GL thumbnail pass
	widgetState.surfTintLast = widgetState.surfTintLast or {}

	for _, entry in ipairs(SLIDER_IDS) do
		local sl = doc:GetElementById(entry[1])
		if sl and trackSliderDrag then
			trackSliderDrag(sl, entry[2])
		end
	end

	widgetState.surfPickerEl = doc:GetElementById("surf-picker")
	widgetState.surfSculptSectionEl = doc:GetElementById("section-surf-sculpt")
	widgetState.surfPickerSlot = nil -- nil = closed, else the target slot

	-- Slot free (×) and picker (▾) buttons: imperative so the click doesn't
	-- bubble into the slot chip's select handler.
	for slot = 1, 2 do
		local btn = doc:GetElementById("surf-slot-" .. slot .. "-free")
		if btn then
			btn:AddEventListener("mousedown", function(event)
				local sp = WG.SurfacePainter
				if sp and sp.freeSlot and sp.freeSlot(slot) then
					ctx.playSound("toggleOff")
				end
				event:StopPropagation()
			end, false)
		end
	end
	local closeBtn = doc:GetElementById("surf-picker-close")
	if closeBtn then
		closeBtn:AddEventListener("mousedown", function(event)
			widgetState.surfPickerSlot = nil
			ctx.playSound("click")
			event:StopPropagation()
		end, false)
	end
	-- Section collapse for the surf-* frames is wired centrally in
	-- tf_environment.lua (envSectionToggle), like every other tool.
end

-- Palette signature: biome + variant list + selection + slot assignment.
-- ≤ 11 tiles, so a rebuild on any of those changing is cheap.
local function paletteSig(list, bkey, surfState, pickSlot)
	local parts = {
		tostring(bkey),
		tostring(surfState.variant or ""),
		tostring(surfState.slot1 or ""),
		tostring(surfState.slot2 or ""),
		tostring(pickSlot or "-"),
	}
	for i = 1, #list do
		parts[#parts + 1] = list[i].asset .. (list[i].sculpted and "*" or "")
	end
	return table.concat(parts, "|")
end

-- targetSlot: the slot the picker is assigning into. Clicking a tile always
-- lands in THAT slot (no "first free slot" guessing, no refusals).
local function buildTile(doc, ctx, v, surfState, targetSlot)
	local playSound = ctx.playSound
	local widgetState = ctx.widgetState
	local tile = doc:CreateElement("div")
	tile:SetClass("tf-biome-tile", true)
	-- surf-tile scopes position:relative for the corner tag without touching
	-- the shared biome-tile class.
	tile:SetClass("surf-tile", true)
	local sel = (v.base and (surfState.variant or "") == "") or (not v.base and surfState.variant == v.asset)
	if sel then
		tile:SetClass("active", true)
		-- Ring in the CHANNEL color, so tile / rail / brush ring all agree.
		if surfState.slot1 == v.asset then
			tile:SetClass("surf-sel-c1", true)
		elseif surfState.slot2 == v.asset then
			tile:SetClass("surf-sel-c2", true)
		end
	end

	-- thumb placeholder: the actual albedo is GL-rendered over this rect in
	-- DrawScreenPost (RmlUi <img> would decode the full 4K bitmap into the
	-- TexMemPool — the skybox library lesson — while gl.Texture reuses the
	-- terrain shader's already-resident texture for free)
	local thumb = doc:CreateElement("div")
	thumb:SetClass("tf-surf-thumb", true)
	tile:AppendChild(thumb)

	-- Slot tag: colored corner badge in the slot's channel color (the same
	-- color marks the slot rail, coverage bar and brush ring).
	if not v.base then
		local slotN = (surfState.slot1 == v.asset and 1) or (surfState.slot2 == v.asset and 2) or nil
		if slotN then
			local tag = doc:CreateElement("div")
			tag:SetClass("surf-tile-tag", true)
			tag:SetClass("surf-tag-c" .. slotN, true)
			tag.inner_rml = tostring(slotN)
			tile:AppendChild(tag)
		end
	end

	local name = doc:CreateElement("div")
	name:SetClass("tf-biome-name", true)
	name.inner_rml = v.label
	tile:AppendChild(name)

	tile:AddEventListener("mousedown", function(_event)
		local sp = WG.SurfacePainter
		if not sp then
			return
		end
		local ok, err
		if targetSlot and sp.setVariantSlot then
			ok, err = sp.setVariantSlot(targetSlot, v.base and "" or v.asset)
			-- Choosing is a one-shot action: close the picker on success so the
			-- panel returns to its compact state.
			if ok then
				widgetState.surfPickerSlot = nil
			end
		elseif sp.setVariant then
			ok, err = sp.setVariant(v.base and "" or v.asset)
		end
		if ok then
			playSound("click")
		elseif err then
			Spring.Echo("[Terraform Brush] SURFACE: " .. err)
		end
	end, false)

	return tile, thumb
end

local function rebuildPalette(doc, ctx, list, surfState)
	local widgetState = ctx.widgetState
	local grid = widgetState.surfPaletteGridEl
	if not grid then
		return
	end
	grid.inner_rml = ""
	widgetState.surfPaletteEls = {}
	local pickSlot = widgetState.surfPickerSlot
	-- The tile grid only exists while the picker is open (per-slot dropdown);
	-- the rail's thumbs below are what the panel shows the rest of the time.
	local row
	if pickSlot then
		for i = 1, #list do
			if not row or ((i - 1) % 3) == 0 then
				row = doc:CreateElement("div")
				row:SetClass("flex", true)
				row:SetClass("flex-row", true)
				row:SetClass("gap-1", true)
				row:SetClass("mb-1", true)
				grid:AppendChild(row)
			end
			local tile, thumb = buildTile(doc, ctx, list[i], surfState, pickSlot)
			row:AppendChild(tile)
			widgetState.surfPaletteEls[#widgetState.surfPaletteEls + 1] =
				{ el = thumb, tex = list[i].diff, sec = widgetState.surfPickerEl }
		end
	end
	-- SCULPTED FEATURES: same tiles, surfaced separately to teach the workflow.
	-- Only tagged layers appear; until the tileset tags them (b.sculpted), the
	-- grid stays empty and the section shows its "not tagged yet" note.
	local sg = widgetState.surfSculptGridEl
	if sg then
		local tagged = {}
		for i = 1, #list do
			if list[i].sculpted then
				tagged[#tagged + 1] = list[i]
			end
		end
		sg.inner_rml = ""
		local srcList = (#tagged > 0) and tagged or {}
		local srow
		for i = 1, #srcList do
			if not srow or ((i - 1) % 3) == 0 then
				srow = doc:CreateElement("div")
				srow:SetClass("flex", true)
				srow:SetClass("flex-row", true)
				srow:SetClass("gap-1", true)
				srow:SetClass("mb-1", true)
				sg:AppendChild(srow)
			end
			-- Sculpted tiles assign like any other variant; target the picker's
			-- slot when one is open, else slot 1 (never the removed
			-- "first free slot" path, whose refusal message no longer matches
			-- this UI).
			local tile, thumb = buildTile(doc, ctx, srcList[i], surfState, pickSlot or 1)
			srow:AppendChild(tile)
			widgetState.surfPaletteEls[#widgetState.surfPaletteEls + 1] =
				{ el = thumb, tex = srcList[i].diff, sec = widgetState.surfSculptSectionEl }
		end
	end

	-- Fixed thumbs (NOW PAINTING strip + slot rail) join the same GL overlay
	-- pass as the tiles. An empty slot registers nothing — the placeholder
	-- background reads as "empty".
	local byAsset = {}
	for i = 1, #list do
		byAsset[list[i].asset] = list[i].diff
	end
	local baseDiff = list[1] and list[1].diff
	local els = widgetState.surfPaletteEls
	local sel = surfState.variant
	local nowTex = (sel and sel ~= "" and byAsset[sel]) or baseDiff
	if widgetState.surfNowThumbEl and nowTex then
		els[#els + 1] = { el = widgetState.surfNowThumbEl, tex = nowTex }
	end
	local slotEls = widgetState.surfSlotThumbEls or {}
	if slotEls.base and baseDiff then
		els[#els + 1] = { el = slotEls.base, tex = baseDiff }
	end
	if slotEls[1] and surfState.slot1 and byAsset[surfState.slot1] then
		els[#els + 1] = { el = slotEls[1], tex = byAsset[surfState.slot1] }
	end
	if slotEls[2] and surfState.slot2 and byAsset[surfState.slot2] then
		els[#els + 1] = { el = slotEls[2], tex = byAsset[surfState.slot2] }
	end
end

local function shortAsset(asset)
	if not asset then
		return "\226\128\148"
	end
	return asset:match("(%d+)$") or asset
end

-- GRADING group tints (shader knobs) serve BOTH submodes, so the sync is
-- shared between the soft path and syncHard below.
local function syncTints(doc, ctx)
	local T = WG.TilesetTerrain
	if not (T and T.getKnobs) then
		return
	end
	local knobs = T.getKnobs()
	if not knobs then
		return
	end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	uiState.updatingFromCode = true
	local ds = uiState.draggingSlider
	local cache = widgetState.surfTintLast
	if not cache then
		cache = {}
		widgetState.surfTintLast = cache
	end
	for _, k in ipairs(TINT_KNOBS) do
		local key = k[1]
		local v = knobs[key]
		if v ~= nil and ds ~= ("surf-" .. key) then
			local id = "surf-slider-" .. key
			local vStr = tostring(v)
			if cache[id] ~= vStr then
				cache[id] = vStr
				local sl = doc:GetElementById(id)
				if sl then
					sl:SetAttribute("value", vStr)
				end
				local nb = doc:GetElementById(id .. "-numbox")
				if nb then
					nb:SetAttribute("value", string.format(k[2], v))
				end
			end
		end
	end
	uiState.updatingFromCode = false
end

-- HARD submode: splat channels R/G/B/A are repurposed by the tileset shader
-- as auto/intermediate/cliff/plateau overrides (dev_tileset_terrain splatDistrTex).
-- Colors repeat on the chips + NOW strip (rcss surf-hard-*).
local HARD_CHANNELS = {
	{ "AUTO", "painting removes the override \226\128\148 slope placement returns" },
	{ "INTERMEDIATE", "forcing intermediate material where painted" },
	{ "CLIFF", "forcing cliff rock where painted" },
	{ "PLATEAU", "forcing the plateau cap where painted" },
}

local function syncHard(doc, ctx, setSummary)
	local sp = WG.SplatPainter
	local spState = sp and sp.getState and sp.getState()
	if not spState then
		return
	end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local dm = widgetState.dmHandle
	local syncAndFlash = ctx.syncAndFlash
	local getCachedEl = ctx.getCachedEl
	local function setDm(f, v)
		if dm[f] ~= v then
			dm[f] = v
		end
	end

	-- Honesty line: with the shader off, hard strokes drive the legacy DNTS
	-- distribution instead of tileset overrides.
	local T = WG.TilesetTerrain
	setDm("surfShaderOff", not (T and T.isActive and T.isActive()))

	-- Channel chips + NOW PAINTING strip: always says what the next stroke does.
	local ch = spState.channel or 1
	setDm("surfHardCh", ch)
	local info = HARD_CHANNELS[ch] or HARD_CHANNELS[1]
	setDm("surfHardNowName", info[1])
	setDm("surfHardNowDetail", info[2])

	local sf = spState.smartFilters or {}
	setDm("surfHardAvoidWater", sf.avoidWater == true)
	setDm("surfHardAvoidCliffs", sf.avoidCliffs == true)
	setDm("surfHardAltMin", sf.altMinEnable == true)
	setDm("surfHardAltMax", sf.altMaxEnable == true)
	setDm("surfHardExportFmt", string.upper(spState.exportFormat or "png"))

	-- BRUSH sliders mirror the splat engine in this submode (same slider-unit
	-- mappings as the legacy panel: strength*100, curve*10).
	uiState.updatingFromCode = true
	local stamped = false
	local function ss(id, key, val)
		if syncAndFlash(getCachedEl(doc, id), key, val) then
			stamped = true
		end
	end
	ss("surf-slider-size", "surf-size", tostring(spState.radius or 100))
	ss("surf-slider-strength", "surf-strength", tostring(math.floor((spState.strength or 0.15) * 100 + 0.5)))
	ss("surf-slider-falloff", "surf-falloff", tostring(math.floor((spState.curve or 1.0) * 10 + 0.5)))
	-- Smart-filter sliders go through the same dirty-checked path: stamping
	-- them every frame raised a change event every frame, which the echo guard
	-- then had to swallow — taking the user's real drags with it.
	ss("surf-hard-slider-slope-max", "surf-hard-slope-max", tostring(sf.slopeMax or 45))
	ss("surf-hard-slider-alt-min", "surf-hard-alt-min", tostring(sf.altMin or 0))
	ss("surf-hard-slider-alt-max", "surf-hard-alt-max", tostring(sf.altMax or 200))
	do
		local setAttrValueIfChanged = ctx.setAttrValueIfChanged
		local function nb(id, txt)
			setAttrValueIfChanged(getCachedEl(doc, id), id, txt)
		end
		nb("surf-slider-size-numbox", tostring(spState.radius or 100))
		nb("surf-slider-strength-numbox", string.format("%.2f", spState.strength or 0.15))
		nb("surf-slider-falloff-numbox", string.format("%.1f", spState.curve or 1.0))
		nb("surf-hard-slider-slope-max-numbox", tostring(sf.slopeMax or 45))
		nb("surf-hard-slider-alt-min-numbox", tostring(sf.altMin or 0))
		nb("surf-hard-slider-alt-max-numbox", tostring(sf.altMax or 200))
	end
	uiState.updatingFromCode = false
	-- SOFT and HARD share Size/Strength/Falloff; RmlUi echoes these stamps back
	-- as change events a few frames later, so the handlers ignore anything that
	-- close to a stamp (see onSurfSlider). ONLY arm that window on a real
	-- stamp — this sync runs every frame.
	if stamped then
		uiState.surfStampFrame = Spring.GetDrawFrame()
	end

	-- GRADING serves both submodes.
	syncTints(doc, ctx)

	if setSummary then
		setSummary(
			"LAYERS",
			"#fdc04c",
			"",
			info[1],
			"R ",
			tostring(spState.radius or 0),
			"Str ",
			string.format("%.2f", spState.strength or 0),
			"Undo ",
			tostring(spState.undoCount or 0)
		)
	end
end

function M.sync(doc, ctx, surfState, setSummary)
	-- HARD only needs the splat engine, so the soft painter is required for the
	-- soft branch (below), not for the whole module.
	if not doc then
		return
	end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local dm = widgetState.dmHandle
	local syncAndFlash = ctx.syncAndFlash
	local getCachedEl = ctx.getCachedEl
	if not dm or dm.activeTool ~= "surf" then
		return
	end

	-- Active biome line under the submode row (serves both submodes).
	do
		local T = WG.TilesetTerrain
		local name
		if T and T.getActiveBiome then
			local _, n = T.getActiveBiome()
			name = n
		end
		name = name or "\226\128\148"
		if dm.surfBiomeName ~= name then
			dm.surfBiomeName = name
		end
	end

	-- HARD submode: the panel mirrors the splat engine, not the variant mask.
	if dm.surfMode == "hard" and WG.SplatPainter then
		syncHard(doc, ctx, setSummary)
		return
	end
	if not (surfState and WG.SurfacePainter) then
		return
	end

	-- Palette rebuild on biome / list / selection / slot / picker-target change.
	-- Per-slot picking replaced the old "first free slot" assignment, so there
	-- is no unassignable state left to dim for.
	local T = WG.TilesetTerrain
	local list, bkey = nil, nil
	if T and T.getSurfaceVariants then
		list, bkey = T.getSurfaceVariants()
	end
	local pickSlot = widgetState.surfPickerSlot
	if list then
		local sig = paletteSig(list, bkey, surfState, pickSlot)
		if sig ~= widgetState.surfPaletteSig then
			widgetState.surfPaletteSig = sig
			rebuildPalette(doc, ctx, list, surfState)
		end
	end
	-- Picker visibility + header (imperative: the open slot lives in
	-- widgetState, and the grid inside is imperative anyway).
	do
		local pk = widgetState.surfPickerEl
		if pk then
			pk:SetClass("hidden", pickSlot == nil)
		end
	end

	-- dm flags for data-if / data-class-active
	local function setDm(f, v)
		if dm[f] ~= v then
			dm[f] = v
		end
	end
	setDm("surfHasVariants", (list and #list > 1) and true or false)
	do
		local anySculpted = false
		if list then
			for i = 1, #list do
				if list[i].sculpted then
					anySculpted = true
					break
				end
			end
		end
		setDm("surfHasSculpted", anySculpted)
	end
	setDm("surfShaderOff", not surfState.shaderOn)
	setDm("surfErase", surfState.eraseMode and true or false)
	setDm("surfPreset", surfState.preset or "")
	setDm("surfFillV1", surfState.fillV1 and true or false)
	setDm("surfFillV2", surfState.fillV2 and true or false)
	-- FILL WITH NOISE only writes a channel that is both assigned and enabled.
	setDm(
		"surfCanFill",
		((surfState.slot1 and surfState.fillV1) or (surfState.slot2 and surfState.fillV2)) and true or false
	)
	setDm("surfSlot1Name", shortAsset(surfState.slot1))
	setDm("surfSlot2Name", shortAsset(surfState.slot2))
	setDm("surfSlot1Assigned", surfState.slot1 ~= nil)
	setDm("surfSlot2Assigned", surfState.slot2 ~= nil)
	do
		local cov = (pickSlot == 1) and (surfState.v1Coverage or 0)
			or (pickSlot == 2) and (surfState.v2Coverage or 0)
			or 0
		setDm("surfPickerTitle", pickSlot and ("Assign to slot " .. pickSlot) or "")
		setDm("surfPickerHasPaint", cov >= 0.005)
	end

	-- NOW PAINTING strip + selection slot for the rail's active ring
	do
		local sel = surfState.variant
		local selSlot = 0
		if sel and sel ~= "" then
			selSlot = (surfState.slot1 == sel and 1) or (surfState.slot2 == sel and 2) or 0
		end
		setDm("surfSelSlot", selSlot)
		local nowName, nowDetail
		if surfState.eraseMode or selSlot == 0 then
			nowName = "BASE"
			-- BASE is a paint target since the paintability flip: it forces
			-- top_001 over whatever the automatic sort chose (plateau included).
			-- Erasing is RMB and means "withdraw the claim, go back to automatic".
			nowDetail = surfState.eraseMode and "strokes withdraw the claim (back to automatic)"
				or "paints plain base over the automatic choice"
		else
			nowName = shortAsset(sel)
			nowDetail = "painting into slot " .. selSlot
		end
		setDm("surfNowName", nowName)
		setDm("surfNowDetail", nowDetail)
		setDm("surfNowMode", surfState.eraseMode and "ERASE" or "PAINT")
	end

	-- Coverage meter: split base/V1/V2 bar + per-slot shares (histogram is
	-- computed by the painter on stroke end); base amber below 80%.
	do
		local cov = surfState.baseCoverage
		local v1 = surfState.v1Coverage or 0
		local v2 = surfState.v2Coverage or 0
		local covStr = cov and string.format("%d%%", math.floor(cov * 100 + 0.5)) or "\226\128\148"
		setDm("surfCoverageStr", covStr)
		setDm("surfCoverageAmber", (cov and cov < 0.8) and true or false)
		setDm("surfBaseShare", covStr)
		setDm("surfSlot1Share", surfState.slot1 and string.format("%.0f%%", v1 * 100) or "empty")
		setDm("surfSlot2Share", surfState.slot2 and string.format("%.0f%%", v2 * 100) or "empty")
		local key = string.format("%.3f|%.3f|%.3f", cov or -1, v1, v2)
		if widgetState.surfCovKey ~= key then
			widgetState.surfCovKey = key
			local basePct = cov and math.max(1, math.floor(cov * 100 + 0.5)) or 100
			local bar = widgetState.surfCoverageBarEl
			if bar then
				bar:SetAttribute("style", "width: " .. basePct .. "%;")
				bar:SetClass("surf-cov-amber", (cov and cov < 0.8) and true or false)
			end
			local b1 = widgetState.surfCovV1El
			if b1 then
				b1:SetAttribute("style", "width: " .. math.floor(v1 * 100 + 0.5) .. "%;")
			end
			local b2 = widgetState.surfCovV2El
			if b2 then
				b2:SetAttribute("style", "width: " .. math.floor(v2 * 100 + 0.5) .. "%;")
			end
		end
	end

	-- Cliff protection moved to the TILESET window (PROTECT CLIFFS button): it
	-- is a shader knob, and for THIS tool the sweep-around is structural
	-- anyway — variants only ever retexture the soft top.
	-- GRADING sliders (group tints live as shader knobs; shared with HARD)
	syncTints(doc, ctx)

	-- Brush + fill sliders / numboxes
	uiState.updatingFromCode = true
	local stamped = false
	local function ss(id, key, val)
		if syncAndFlash(getCachedEl(doc, id), key, val) then
			stamped = true
		end
	end
	ss("surf-slider-size", "surf-size", tostring(surfState.radius or 72))
	ss("surf-slider-strength", "surf-strength", tostring(math.floor((surfState.strength or 0.15) * 100 + 0.5)))
	ss("surf-slider-falloff", "surf-falloff", tostring(math.floor((surfState.curve or 0.5) * 10 + 0.5)))
	ss("surf-slider-spacing", "surf-spacing", tostring(surfState.spacing or 0))
	ss("surf-slider-fill-scale", "surf-fill-scale", tostring(surfState.fillScale or 1400))
	ss("surf-slider-fill-seed", "surf-fill-seed", tostring(surfState.fillSeed or 0))
	do
		local setAttrValueIfChanged = ctx.setAttrValueIfChanged
		local function nb(id, txt)
			setAttrValueIfChanged(getCachedEl(doc, id), id, txt)
		end
		nb("surf-slider-size-numbox", tostring(surfState.radius or 72))
		nb("surf-slider-strength-numbox", string.format("%.2f", surfState.strength or 0.15))
		nb("surf-slider-falloff-numbox", string.format("%.1f", surfState.curve or 0.5))
		nb("surf-slider-spacing-numbox", (surfState.spacing or 0) > 0 and tostring(surfState.spacing) or "off")
		nb("surf-slider-fill-scale-numbox", tostring(surfState.fillScale or 1400))
		nb("surf-slider-fill-seed-numbox", tostring(surfState.fillSeed or 0))
	end
	uiState.updatingFromCode = false
	-- ONLY when a slider was actually re-stamped (see syncHard's note): this
	-- sync runs every frame, so arming the window unconditionally would swallow
	-- every change event the user's own dragging raises — which is exactly what
	-- left FILL AND SEED dead (scale/seed never reached the painter).
	if stamped then
		uiState.surfStampFrame = Spring.GetDrawFrame()
	end

	if setSummary then
		local what
		if surfState.eraseMode then
			what = "ERASE \226\134\146 auto"
		elseif surfState.variant and surfState.variant ~= "" then
			local selSlot = (surfState.slot1 == surfState.variant and 1) or (surfState.slot2 == surfState.variant and 2)
			what = shortAsset(surfState.variant) .. (selSlot and (" \194\183" .. selSlot) or "")
		else
			what = "base"
		end
		setSummary(
			"SURFACE",
			"#fdc04c",
			"",
			what,
			"R ",
			tostring(surfState.radius or 0),
			"Str ",
			string.format("%.2f", surfState.strength or 0),
			"Base ",
			dm.surfCoverageStr or "\226\128\148"
		)
	end
end

return M
