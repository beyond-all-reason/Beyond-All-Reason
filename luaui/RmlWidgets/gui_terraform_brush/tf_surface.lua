-- tf_surface.lua: panel for the SURFACE (soft variant paint) and LAYERS (hard
-- splat-override paint) tools. Both run as activeTool 'surf'; dm.surfMode
-- ('soft' / 'hard') picks which sections show.
-- The engines are NOT in this repo: soft paint is the write-dir widget
-- dev_surface_painter.lua (WG.SurfacePainter), and the variant catalog, mask
-- binding and shader knobs live in the write-dir dev_tileset_terrain.lua
-- (WG.TilesetTerrain). Hard paint reuses the splat painter (WG.SplatPainter).
-- Every call into those APIs is nil-guarded, because either may be missing.
local M = {}

-- Slot chips the RML draws. The painter owns the real slot count
-- (WG.SurfacePainter.getState().slotCount); this is only the lookup ceiling.
local MAX_SLOTS = 7

-- RmlUi listener closures can run outside the widget env, where bare globals
-- read nil; capture them as upvalues.
local WG = WG
local Spring = Spring

-- Sliders tracked for drag state (value changes come from the RML).
local SLIDER_IDS = {
	{ "surf-slider-size", "surf-size" },
	{ "surf-slider-strength", "surf-strength" },
	{ "surf-slider-falloff", "surf-falloff" },
	{ "surf-slider-spacing", "surf-spacing" },
	{ "surf-slider-scatter-pos", "surf-scatter-pos" },
	{ "surf-slider-scatter-size", "surf-scatter-size" },
	{ "surf-slider-scatter-str", "surf-scatter-str" },
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
	-- HARD smart filters (WG.SplatPainter)
	{ "surf-hard-slider-slope-max", "surf-hard-slope-max" },
	{ "surf-hard-slider-alt-min", "surf-hard-alt-min" },
	{ "surf-hard-slider-alt-max", "surf-hard-alt-max" },
	-- SOFT smart filters (WG.SurfacePainter)
	{ "surf-soft-slider-slope-max", "surf-soft-slope-max" },
	{ "surf-soft-slider-alt-min", "surf-soft-alt-min" },
	{ "surf-soft-slider-alt-max", "surf-soft-alt-max" },
	-- SELECTED SLOT tint (GRADING), stored per asset by WG.TilesetTerrain
	{ "surf-slider-slotTintR", "surf-slotTintR" },
	{ "surf-slider-slotTintG", "surf-slotTintG" },
	{ "surf-slider-slotTintB", "surf-slotTintB" },
	-- INFLUENCE, shared by both submodes (the handler routes by surfMode)
	{ "surf-slider-inf-alt-min", "surf-inf-alt-min" },
	{ "surf-slider-inf-alt-max", "surf-inf-alt-max" },
	{ "surf-slider-inf-alt-feather", "surf-inf-alt-feather" },
	{ "surf-slider-inf-slope-min", "surf-inf-slope-min" },
	{ "surf-slider-inf-slope-max", "surf-inf-slope-max" },
	{ "surf-slider-inf-slope-feather", "surf-inf-slope-feather" },
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
	-- One thumb per slot; a missing element is skipped, so the RML and the
	-- painter may disagree on the slot count.
	widgetState.surfSlotThumbEls = { base = doc:GetElementById("surf-slot-base-thumb") }
	for slot = 1, MAX_SLOTS do
		widgetState.surfSlotThumbEls[slot] = doc:GetElementById("surf-slot-" .. slot .. "-thumb")
	end
	widgetState.surfNowThumbEl = doc:GetElementById("surf-now-thumb")
	widgetState.surfPaletteSectionEl = doc:GetElementById("section-surf-palette")
	-- Fresh document: rebuild the palette on the next sync.
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
	-- The hover preview is a persistent entry in the GL thumbnail pass whose .tex
	-- the sync rewrites: rebuilding the grid on hover would destroy the hovered
	-- element. u0/u1 show the whole texture (tiles show a quarter crop).
	widgetState.surfPreviewEntry = {
		el = doc:GetElementById("surf-picker-preview"),
		tex = nil,
		sec = widgetState.surfPickerEl,
		u0 = 0.0,
		u1 = 1.0,
	}
	widgetState.surfHover = nil
	widgetState.surfSculptSectionEl = doc:GetElementById("section-surf-sculpt")
	widgetState.surfPickerSlot = nil -- nil = closed, else the target slot

	-- Slot buttons are wired here so StopPropagation keeps the click off the
	-- slot's own select handler. PICK opens the library; the slot itself only arms it.
	for slot = 1, MAX_SLOTS do
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
		local pick = doc:GetElementById("surf-slot-" .. slot .. "-pick")
		if pick then
			pick:AddEventListener("mousedown", function(event)
				-- PICK on the slot that is already open closes the picker.
				local open = (widgetState.surfPickerSlot ~= slot) and slot or nil
				widgetState.surfPickerSlot = open
				widgetState.surfPaletteSig = nil -- rebuild for the new target
				widgetState.surfHover = nil
				ctx.playSound(open and "dropdown" or "click")
				event:StopPropagation()
			end, false)
		end
	end
	-- FLIP toggles the normal map's G channel for the SELECTED slot's texture
	-- (BASE = slot 0). WG.TilesetTerrain keys the flag by asset, so it follows
	-- the texture into any slot. One button, not one per tile, to keep the
	-- slot buttons large enough to hit.
	local function selectedSurfAsset()
		local sp = WG.SurfacePainter
		local st = sp and sp.getState and sp.getState()
		if not st then
			return nil
		end
		local sel = st.selSlot or 0
		if sel == 0 then
			local T = WG.TilesetTerrain
			local list = T and T.getSurfaceVariants and T.getSurfaceVariants()
			return list and list[1] and list[1].asset
		end
		return st["slot" .. sel]
	end
	widgetState.surfSelectedAsset = selectedSurfAsset
	widgetState.surfFlipSelEl = doc:GetElementById("surf-flip-sel")
	if widgetState.surfFlipSelEl then
		widgetState.surfFlipSelEl:AddEventListener("mousedown", function(event)
			---@type table?
			local T = WG.TilesetTerrain
			local asset = (T and T.setNormalFlip) and selectedSurfAsset() or nil
			if asset and T then
				local on = not T.getNormalFlip(asset)
				T.setNormalFlip(asset, on)
				widgetState.surfFlipSelEl:SetClass("active", on)
				ctx.playSound(on and "toggleOn" or "toggleOff")
			else
				ctx.playSound("click") -- selected slot has no texture to flip
			end
			event:StopPropagation()
		end, false)
	end
	local closeBtn = doc:GetElementById("surf-picker-close")
	if closeBtn then
		closeBtn:AddEventListener("mousedown", function(event)
			widgetState.surfPickerSlot = nil
			ctx.playSound("click")
			event:StopPropagation()
		end, false)
	end

	-- Section collapse is wired in tf_environment.lua (envSectionToggle).
end

-- Ctrl SNEAK PEEK gate (DISPLAY chip). The engines watch Ctrl and feed the
-- brush footprint to WG.TilesetTerrain.setSurfacePreview; the panel only owns
-- the on/off switch and pushes it to both engines every sync.
local function pushPeekEnabled(dm)
	local on = dm.surfReveal and true or false
	local sp = WG.SurfacePainter
	if sp and sp.setPreviewEnabled then
		sp.setPreviewEnabled(on)
	end
	local hsp = WG.SplatPainter
	if hsp and hsp.setTilesetPreviewEnabled then
		hsp.setTilesetPreviewEnabled(on)
	end
end

-- Palette signature: biome, variant list, selection, picker target and slots.
-- A biome has only a handful of tiles, so a rebuild on any change is cheap.
local function paletteSig(list, bkey, surfState, pickSlot)
	local parts = {
		tostring(bkey),
		tostring(surfState.variant or ""),
		tostring(pickSlot or "-"),
	}
	for i = 1, (surfState.slotCount or MAX_SLOTS) do
		parts[#parts + 1] = tostring(surfState["slot" .. i] or "")
	end
	for i = 1, #list do
		parts[#parts + 1] = list[i].asset .. (list[i].sculpted and "*" or "")
	end
	return table.concat(parts, "|")
end

-- targetSlot: the slot the picker assigns into; a tile click always lands there.
local function buildTile(doc, ctx, v, surfState, targetSlot)
	local playSound = ctx.playSound
	local widgetState = ctx.widgetState
	local tile = doc:CreateElement("div")
	tile:SetClass("tf-biome-tile", true)
	-- surf-tile adds position: relative for the corner tag without touching the shared class.
	tile:SetClass("surf-tile", true)
	local sel = (v.base and (surfState.variant or "") == "") or (not v.base and surfState.variant == v.asset)
	if sel then
		tile:SetClass("active", true)
		-- Ring in the channel color, matching the slot rail and the brush ring.
		for i = 1, (surfState.slotCount or MAX_SLOTS) do
			if surfState["slot" .. i] == v.asset then
				tile:SetClass("surf-sel-c" .. i, true)
				break
			end
		end
	end

	-- Placeholder: the albedo is GL-drawn over this rect in DrawScreenPost. An
	-- RmlUi <img> would decode the full 4K bitmap into the TexMemPool, while
	-- gl.Texture reuses the texture the terrain shader already holds.
	local thumb = doc:CreateElement("div")
	thumb:SetClass("tf-surf-thumb", true)
	tile:AppendChild(thumb)

	-- Corner badge with the slot number, in the slot's channel color.
	if not v.base then
		local slotN
		for i = 1, (surfState.slotCount or MAX_SLOTS) do
			if surfState["slot" .. i] == v.asset then
				slotN = i
				break
			end
		end
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

	-- Hover drives the preview. mouseout clears only if this tile is still the
	-- one shown, so crossing to the next tile cannot blank its preview.
	tile:AddEventListener("mouseover", function(_event)
		widgetState.surfHover = { asset = v.asset, diff = v.diff, label = v.label, base = v.base }
	end, false)
	tile:AddEventListener("mouseout", function(_event)
		local h = widgetState.surfHover
		if h and h.asset == v.asset then
			widgetState.surfHover = nil
		end
	end, false)

	tile:AddEventListener("mousedown", function(_event)
		local sp = WG.SurfacePainter
		if not sp then
			return
		end
		local ok, err
		if targetSlot and sp.setVariantSlot then
			ok, err = sp.setVariantSlot(targetSlot, v.base and "" or v.asset)
			-- A successful pick closes the picker.
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
	-- The tile grid exists only while a slot's picker is open; otherwise the
	-- panel shows the slot rail thumbs.
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
	-- SCULPTED FEATURES: the variants the tileset tags as sculpted, shown again
	-- on their own. With none tagged the grid stays empty and the RML shows a note.
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
			-- Assign into the picker's slot when one is open, else slot 1.
			local tile, thumb = buildTile(doc, ctx, srcList[i], surfState, pickSlot or 1)
			srow:AppendChild(tile)
			widgetState.surfPaletteEls[#widgetState.surfPaletteEls + 1] =
				{ el = thumb, tex = srcList[i].diff, sec = widgetState.surfSculptSectionEl }
		end
	end

	-- The NOW PAINTING strip and slot rail join the same GL thumbnail pass. An
	-- empty slot registers nothing, so its placeholder background reads as empty.
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
	local prev = widgetState.surfPreviewEntry
	if prev and prev.el then
		els[#els + 1] = prev
	end
	local slotEls = widgetState.surfSlotThumbEls or {}
	if slotEls.base and baseDiff then
		els[#els + 1] = { el = slotEls.base, tex = baseDiff }
	end
	for i = 1, (surfState.slotCount or MAX_SLOTS) do
		local asset = surfState["slot" .. i]
		if slotEls[i] and asset and byAsset[asset] then
			els[#els + 1] = { el = slotEls[i], tex = byAsset[asset] }
		end
	end
end

local function shortAsset(asset)
	if not asset then
		return "\226\128\148"
	end
	return asset:match("(%d+)$") or asset
end

-- GRADING tints are WG.TilesetTerrain shader knobs and serve both submodes.
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
	-- SELECTED SLOT tint: the armed texture's per-asset entry, re-stamped only
	-- when the asset or a channel changes and never under a dragged slider.
	do
		---@type table?
		local TT = WG.TilesetTerrain
		local asset = widgetState.surfSelectedAsset and widgetState.surfSelectedAsset()
		if TT and TT.getSlotTint and asset then
			local r, g, b = TT.getSlotTint(asset)
			local vals = { R = r, G = g, B = b }
			for ch, v in pairs(vals) do
				local key = "slotTint" .. ch
				if ds ~= ("surf-" .. key) then
					local id = "surf-slider-" .. key
					local sig = asset .. "|" .. string.format("%.4f", v)
					if cache[id] ~= sig then
						cache[id] = sig
						local sl = doc:GetElementById(id)
						if sl then
							sl:SetAttribute("value", tostring(v))
						end
						local nb = doc:GetElementById(id .. "-numbox")
						if nb then
							nb:SetAttribute("value", string.format("%.2f", v))
						end
					end
				end
			end
		end
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

-- HARD submode: the tileset shader reads splat channels R/G/B/A as auto /
-- intermediate / cliff / plateau overrides (splatDistrTex in WG.TilesetTerrain).
-- The chip colors live in the rcss (surf-hard-*).
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
	local setDm = ctx.setDm

	-- With the tileset shader off, hard strokes paint the plain DNTS splat
	-- distribution instead of overrides; the panel says so.
	local T = WG.TilesetTerrain
	setDm("surfShaderOff", not (T and T.isActive and T.isActive()))

	-- The NOW PAINTING strip says what the next stroke does.
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
	do
		-- SAMPLE buttons light while the terraform brush samples height for their bound.
		local hs = WG.TerraformBrush
			and WG.TerraformBrush.getState
			and (WG.TerraformBrush.getState() or {}).heightSamplingMode
		setDm("surfAltMinSample", hs == "spAltMin")
		setDm("surfAltMaxSample", hs == "spAltMax")
		setDm("surfInfAltMinSample", hs == "spInfAltMin")
		setDm("surfInfAltMaxSample", hs == "spInfAltMax")
	end
	setDm("surfHardExportFmt", string.upper(spState.exportFormat or "png"))
	setDm("surfHardOverlay", spState.showSplatOverlay == true)
	-- Warn chip: a filter is engaged while its section is folded.
	ctx.syncWarnChip(
		doc,
		"warn-chip-sf-smart",
		"section-sf-smart",
		(sf.avoidWater or sf.avoidCliffs or sf.altMinEnable or sf.altMaxEnable) and true or false
	)
	-- INFLUENCE chips and the active channel's profile name
	local inf = spState.influence or {}
	setDm("surfInfAlt", inf.altOn == true)
	setDm("surfInfSlope", inf.slopeOn == true)
	setDm("surfInfKey", spState.influenceKey or "")
	ctx.syncWarnChip(
		doc,
		"warn-chip-sf-influence",
		"section-sf-influence",
		(inf.altOn or inf.slopeOn) and true or false
	)

	-- BRUSH sliders mirror the splat engine here (slider units: strength x100, curve x10).
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
	-- Every slider goes through the dirty-checked path: a stamp raises a change
	-- event, and an every-frame stamp would make the echo guard swallow real drags.
	ss("surf-hard-slider-slope-max", "surf-hard-slope-max", tostring(sf.slopeMax or 45))
	ss("surf-hard-slider-alt-min", "surf-hard-alt-min", tostring(sf.altMin or 0))
	ss("surf-hard-slider-alt-max", "surf-hard-alt-max", tostring(sf.altMax or 200))
	ss("surf-slider-inf-alt-min", "surf-inf-alt-min", tostring(math.floor((inf.altMin or 0) + 0.5)))
	ss("surf-slider-inf-alt-max", "surf-inf-alt-max", tostring(math.floor((inf.altMax or 200) + 0.5)))
	ss("surf-slider-inf-alt-feather", "surf-inf-alt-feather", tostring(math.floor((inf.altFeatherLo or 40) + 0.5)))
	ss("surf-slider-inf-slope-min", "surf-inf-slope-min", tostring(math.floor((inf.slopeMin or 0) + 0.5)))
	ss("surf-slider-inf-slope-max", "surf-inf-slope-max", tostring(math.floor((inf.slopeMax or 30) + 0.5)))
	ss("surf-slider-inf-slope-feather", "surf-inf-slope-feather", tostring(math.floor((inf.slopeFeather or 10) + 0.5)))
	do
		local setAttrValueIfChanged = ctx.setAttrValueIfChanged
		local function nb(id, txt)
			setAttrValueIfChanged(getCachedEl(doc, id), id, txt)
		end
		nb("surf-slider-size-numbox", tostring(spState.radius or 100))
		nb("surf-slider-strength-numbox", string.format("%.2f", spState.strength or 0.15))
		nb("surf-slider-falloff-numbox", string.format("%.1f", spState.curve or 1.0))
		nb("surf-hard-slider-slope-max-numbox", tostring(sf.slopeMax or 45))
		nb("surf-slider-inf-alt-min-numbox", tostring(math.floor((inf.altMin or 0) + 0.5)))
		nb("surf-slider-inf-alt-max-numbox", tostring(math.floor((inf.altMax or 200) + 0.5)))
		nb("surf-slider-inf-alt-feather-numbox", tostring(math.floor((inf.altFeatherLo or 40) + 0.5)))
		nb("surf-slider-inf-slope-min-numbox", tostring(math.floor((inf.slopeMin or 0) + 0.5)))
		nb("surf-slider-inf-slope-max-numbox", tostring(math.floor((inf.slopeMax or 30) + 0.5)))
		nb("surf-slider-inf-slope-feather-numbox", tostring(math.floor((inf.slopeFeather or 10) + 0.5)))
		nb("surf-hard-slider-alt-min-numbox", tostring(sf.altMin or 0))
		nb("surf-hard-slider-alt-max-numbox", tostring(sf.altMax or 200))
	end
	uiState.updatingFromCode = false
	-- RmlUi echoes a stamp back as a change event a few frames later, so the
	-- handlers ignore changes that close to one (see onSurfSlider). Arm that
	-- window only on a real stamp: this sync runs every frame.
	if stamped then
		uiState.surfStampFrame = Spring.GetDrawFrame()
	end

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
	-- HARD needs only the splat engine; WG.SurfacePainter is checked in the soft branch.
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

	-- Shared by both submodes, so these run before the hard branch.
	if ctx.syncTBMirrorControls then
		ctx.syncTBMirrorControls(doc, "sf")
	end
	pushPeekEnabled(dm)

	-- Active biome line under the submode row.
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

	-- HARD mirrors the splat engine, not the variant mask.
	if dm.surfMode == "hard" and WG.SplatPainter then
		syncHard(doc, ctx, setSummary)
		return
	end
	if not (surfState and WG.SurfacePainter) then
		return
	end

	---@type table?
	local T = WG.TilesetTerrain
	local list, bkey = nil, nil
	if T and T.getSurfaceVariants then
		list, bkey = T.getSurfaceVariants()
	end
	local pickSlot = widgetState.surfPickerSlot
	-- Coverage is a gl.ReadPixels (a GPU sync) whose only reader is the picker's
	-- "already carries paint" warning, so ask for it only while a picker is open.
	do
		---@type table?
		local sp = WG.SurfacePainter
		if sp and sp.setCoverageWanted then
			sp.setCoverageWanted(pickSlot ~= nil)
		end
	end
	if list then
		local sig = paletteSig(list, bkey, surfState, pickSlot)
		if sig ~= widgetState.surfPaletteSig then
			widgetState.surfPaletteSig = sig
			rebuildPalette(doc, ctx, list, surfState)
		end
	end
	-- Picker visibility is set here: the open slot lives in widgetState, not the data model.
	do
		local pk = widgetState.surfPickerEl
		if pk then
			pk:SetClass("hidden", pickSlot == nil)
		end
	end

	local setDm = ctx.setDm
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
	-- Soft smart filters and their warn chip
	do
		local ssf = surfState.smartFilters or {}
		setDm("surfSoftAvoidWater", ssf.avoidWater == true)
		setDm("surfSoftAvoidCliffs", ssf.avoidCliffs == true)
		setDm("surfSoftAltMin", ssf.altMinEnable == true)
		setDm("surfSoftAltMax", ssf.altMaxEnable == true)
		local hs = WG.TerraformBrush
			and WG.TerraformBrush.getState
			and (WG.TerraformBrush.getState() or {}).heightSamplingMode
		setDm("surfAltMinSample", hs == "sfAltMin")
		setDm("surfAltMaxSample", hs == "sfAltMax")
		setDm("surfInfAltMinSample", hs == "sfInfAltMin")
		setDm("surfInfAltMaxSample", hs == "sfInfAltMax")
		ctx.syncWarnChip(
			doc,
			"warn-chip-sf-smart",
			"section-sf-smart",
			(ssf.avoidWater or ssf.avoidCliffs or ssf.altMinEnable or ssf.altMaxEnable) and true or false
		)
	end
	-- INFLUENCE chips and the armed texture's profile name
	do
		local inf = surfState.influence or {}
		setDm("surfInfAlt", inf.altOn == true)
		setDm("surfInfSlope", inf.slopeOn == true)
		setDm("surfInfKey", shortAsset(surfState.influenceKey or "base"))
		ctx.syncWarnChip(
			doc,
			"warn-chip-sf-influence",
			"section-sf-influence",
			(inf.altOn or inf.slopeOn) and true or false
		)
	end
	-- Per-slot chips. FILL WITH NOISE is enabled only while some slot is both
	-- assigned and switched on.
	local canFill = false
	for i = 1, MAX_SLOTS do
		local asset = surfState["slot" .. i]
		local fill = surfState["fillV" .. i]
		setDm("surfSlot" .. i .. "Name", shortAsset(asset))
		setDm("surfSlot" .. i .. "Assigned", asset ~= nil)
		setDm("surfFillV" .. i, fill and true or false)
		if asset and fill then
			canFill = true
		end
	end
	-- FLIP mirrors the selected slot's flag (BASE included).
	if widgetState.surfFlipSelEl then
		local selAsset = widgetState.surfSelectedAsset and widgetState.surfSelectedAsset()
		local fl = false
		if selAsset and T and T.getNormalFlip then
			fl = T.getNormalFlip(selAsset)
		end
		widgetState.surfFlipSelEl:SetClass("active", fl)
		widgetState.surfFlipSelEl:SetClass("unavailable", selAsset == nil)
	end
	setDm("surfCanFill", canFill)
	setDm("surfPickSlot", pickSlot or 0)
	do
		local cov = (pickSlot and surfState["v" .. pickSlot .. "Coverage"]) or 0
		setDm("surfPickerTitle", pickSlot and ("Assign to slot " .. pickSlot) or "")
		setDm("surfPickerHasPaint", cov >= 0.005)

		-- HOVER PREVIEW: the hovered tile, else what the target slot already holds.
		local hover = widgetState.surfHover
		local prevDiff, prevName, prevHint
		if hover then
			prevDiff = hover.diff
			prevName = hover.base and "BASE" or shortAsset(hover.asset)
			prevHint = pickSlot and ("click to assign to slot " .. pickSlot) or "click to paint with this"
		else
			local held = pickSlot and surfState["slot" .. pickSlot] or nil
			if held then
				for i = 1, (list and #list or 0) do
					if list[i].asset == held then
						prevDiff = list[i].diff
						break
					end
				end
				prevName = shortAsset(held)
				prevHint = "slot " .. tostring(pickSlot) .. " holds this \226\128\148 hover a tile to compare"
			else
				prevDiff = list and list[1] and list[1].diff
				prevName = "BASE"
				prevHint = "slot is empty \226\128\148 hover a tile to preview"
			end
		end
		setDm("surfPreviewName", prevName or "\226\128\148")
		setDm("surfPreviewHint", prevHint or "")
		local prev = widgetState.surfPreviewEntry
		if prev then
			prev.tex = prevDiff
		end
	end

	-- NOW PAINTING strip, and the selected slot for the rail's active ring
	do
		local sel = surfState.variant
		local selSlot = surfState.selSlot or 0
		setDm("surfSelSlot", selSlot)
		local nowName, nowDetail
		if surfState.eraseMode or selSlot == 0 then
			nowName = "BASE"
			-- Painting BASE forces top_001 over the automatic choice (plateau
			-- included). Erasing (RMB) withdraws the claim, back to automatic.
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

	syncTints(doc, ctx)

	-- Brush and fill sliders and numboxes
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
	ss("surf-slider-scatter-pos", "surf-scatter-pos", tostring(math.floor((surfState.scatterPos or 0) * 100 + 0.5)))
	ss("surf-slider-scatter-size", "surf-scatter-size", tostring(math.floor((surfState.scatterSize or 0) * 100 + 0.5)))
	ss("surf-slider-scatter-str", "surf-scatter-str", tostring(math.floor((surfState.scatterStr or 0) * 100 + 0.5)))
	ss("surf-slider-fill-scale", "surf-fill-scale", tostring(surfState.fillScale or 1400))
	ss("surf-slider-fill-seed", "surf-fill-seed", tostring(surfState.fillSeed or 0))
	do
		local ssf = surfState.smartFilters or {}
		ss("surf-soft-slider-slope-max", "surf-soft-slope-max", tostring(ssf.slopeMax or 45))
		ss("surf-soft-slider-alt-min", "surf-soft-alt-min", tostring(ssf.altMin or 0))
		ss("surf-soft-slider-alt-max", "surf-soft-alt-max", tostring(ssf.altMax or 200))
		local inf = surfState.influence or {}
		ss("surf-slider-inf-alt-min", "surf-inf-alt-min", tostring(math.floor((inf.altMin or 0) + 0.5)))
		ss("surf-slider-inf-alt-max", "surf-inf-alt-max", tostring(math.floor((inf.altMax or 200) + 0.5)))
		ss("surf-slider-inf-alt-feather", "surf-inf-alt-feather", tostring(math.floor((inf.altFeatherLo or 40) + 0.5)))
		ss("surf-slider-inf-slope-min", "surf-inf-slope-min", tostring(math.floor((inf.slopeMin or 0) + 0.5)))
		ss("surf-slider-inf-slope-max", "surf-inf-slope-max", tostring(math.floor((inf.slopeMax or 30) + 0.5)))
		ss(
			"surf-slider-inf-slope-feather",
			"surf-inf-slope-feather",
			tostring(math.floor((inf.slopeFeather or 10) + 0.5))
		)
	end
	do
		local setAttrValueIfChanged = ctx.setAttrValueIfChanged
		local function nb(id, txt)
			setAttrValueIfChanged(getCachedEl(doc, id), id, txt)
		end
		nb("surf-slider-size-numbox", tostring(surfState.radius or 72))
		nb("surf-slider-strength-numbox", string.format("%.2f", surfState.strength or 0.15))
		nb("surf-slider-falloff-numbox", string.format("%.1f", surfState.curve or 0.5))
		nb("surf-slider-spacing-numbox", (surfState.spacing or 0) > 0 and tostring(surfState.spacing) or "off")
		nb("surf-slider-scatter-pos-numbox", string.format("%.2f", surfState.scatterPos or 0))
		nb("surf-slider-scatter-size-numbox", string.format("%.2f", surfState.scatterSize or 0))
		nb("surf-slider-scatter-str-numbox", string.format("%.2f", surfState.scatterStr or 0))
		nb("surf-slider-fill-scale-numbox", tostring(surfState.fillScale or 1400))
		nb("surf-slider-fill-seed-numbox", tostring(surfState.fillSeed or 0))
		local ssf = surfState.smartFilters or {}
		nb("surf-soft-slider-slope-max-numbox", tostring(ssf.slopeMax or 45))
		nb("surf-soft-slider-alt-min-numbox", tostring(ssf.altMin or 0))
		nb("surf-soft-slider-alt-max-numbox", tostring(ssf.altMax or 200))
		local inf = surfState.influence or {}
		nb("surf-slider-inf-alt-min-numbox", tostring(math.floor((inf.altMin or 0) + 0.5)))
		nb("surf-slider-inf-alt-max-numbox", tostring(math.floor((inf.altMax or 200) + 0.5)))
		nb("surf-slider-inf-alt-feather-numbox", tostring(math.floor((inf.altFeatherLo or 40) + 0.5)))
		nb("surf-slider-inf-slope-min-numbox", tostring(math.floor((inf.slopeMin or 0) + 0.5)))
		nb("surf-slider-inf-slope-max-numbox", tostring(math.floor((inf.slopeMax or 30) + 0.5)))
		nb("surf-slider-inf-slope-feather-numbox", tostring(math.floor((inf.slopeFeather or 10) + 0.5)))
	end
	uiState.updatingFromCode = false
	-- Arm the echo window only on a real stamp (see syncHard): armed every frame
	-- it would swallow the user's own slider changes.
	if stamped then
		uiState.surfStampFrame = Spring.GetDrawFrame()
	end

	if setSummary then
		local what
		if surfState.eraseMode then
			what = "ERASE \226\134\146 auto"
		elseif surfState.variant and surfState.variant ~= "" then
			local selSlot = surfState.selSlot
			what = shortAsset(surfState.variant) .. ((selSlot and selSlot > 0) and (" \194\183" .. selSlot) or "")
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
			string.format("%.2f", surfState.strength or 0)
		)
	end
end

return M
