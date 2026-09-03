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

-- Slot chips the RML draws. The painter is the authority on how many slots
-- actually exist (WG.SurfacePainter.getState().slotCount); this is only the
-- ceiling for element lookups.
local MAX_SLOTS = 7

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
	-- SOFT submode smart-filter sliders (engine = WG.SurfacePainter)
	{ "surf-soft-slider-slope-max", "surf-soft-slope-max" },
	{ "surf-soft-slider-alt-min", "surf-soft-alt-min" },
	{ "surf-soft-slider-alt-max", "surf-soft-alt-max" },
	-- SELECTED SLOT tint (GRADING; per-asset, dev_tileset_terrain slotTintN)
	{ "surf-slider-slotTintR", "surf-slotTintR" },
	{ "surf-slider-slotTintG", "surf-slotTintG" },
	{ "surf-slider-slotTintB", "surf-slotTintB" },
	-- INFLUENCE sliders (shared by both submodes; handler routes by surfMode)
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
	-- One thumb per variant slot. MAX_SLOTS just has to be >= the painter's slot
	-- count; missing elements are skipped, so the panel tolerates a painter with
	-- fewer slots than the RML draws and vice versa.
	widgetState.surfSlotThumbEls = { base = doc:GetElementById("surf-slot-base-thumb") }
	for slot = 1, MAX_SLOTS do
		widgetState.surfSlotThumbEls[slot] = doc:GetElementById("surf-slot-" .. slot .. "-thumb")
	end
	widgetState.surfNowThumbEl = doc:GetElementById("surf-now-thumb")
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
	-- The picker's hover preview shares the palette's GL thumbnail pass, but as
	-- a PERSISTENT entry whose .tex the sync rewrites every frame: rebuilding
	-- the tile grid on every mouse move would destroy the element the pointer is
	-- over, and with it the hover it is meant to report. u0/u1 widen the crop —
	-- the tiles show a quarter window, the preview shows the whole tile.
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

	-- Slot buttons are imperative so a click on them does NOT also reach the
	-- tile's select handler underneath. PICK owns opening the library; the tile
	-- itself only arms the slot for painting.
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
				-- clicking PICK on the open slot closes it again (same button,
				-- same place — no separate close to hunt for)
				local open = (widgetState.surfPickerSlot ~= slot) and slot or nil
				widgetState.surfPickerSlot = open
				widgetState.surfPaletteSig = nil -- rebuild for the new target
				widgetState.surfHover = nil
				ctx.playSound(open and "dropdown" or "click")
				event:StopPropagation()
			end, false)
		end
	end
	-- FLIP: per-texture normal G toggle, straight through to the tileset shader
	-- (asset-keyed there, so re-picking the same texture into another slot keeps
	-- the flag). ONE button acting on the SELECTED slot (BASE = slot 0, whose
	-- texture is every empty slot's fallback): a FLIP on every tile left
	-- PICK / FLIP / X too cramped to hit.
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

	-- Section collapse for the surf-* frames is wired centrally in
	-- tf_environment.lua (envSectionToggle), like every other tool.
end

-- Ctrl SNEAK PEEK toggle (DISPLAY chip). The peek itself is engine-driven —
-- dev_surface_painter / cmd_splat_painter watch Ctrl and feed the brush
-- footprint to WG.TilesetTerrain.setSurfacePreview — the panel only owns the
-- on/off gate and mirrors it into both engines each sync.
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

-- Palette signature: biome + variant list + selection + slot assignment.
-- ≤ 11 tiles, so a rebuild on any of those changing is cheap.
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
		for i = 1, (surfState.slotCount or MAX_SLOTS) do
			if surfState["slot" .. i] == v.asset then
				tile:SetClass("surf-sel-c" .. i, true)
				break
			end
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

	-- Hover drives the preview above the grid. mouseout only clears when this
	-- tile is still the one on show, so the pointer crossing a gap between two
	-- tiles cannot blank a preview the newer tile just claimed.
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
	-- SELECTED SLOT tint: the armed texture's per-asset entry in the tileset
	-- widget, restamped only when the asset or a channel changes (and never
	-- under the slider being dragged).
	do
		local T = WG.TilesetTerrain
		local asset = widgetState.surfSelectedAsset and widgetState.surfSelectedAsset()
		if T and T.getSlotTint and asset then
			local r, g, b = T.getSlotTint(asset)
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
	setDm("surfHardOverlay", spState.showSplatOverlay == true)
	-- FILTERS live in a canonical collapsed section now, so they get the
	-- standard "engaged while folded" warn chip.
	ctx.syncWarnChip(
		doc,
		"warn-chip-sf-smart",
		"section-sf-smart",
		(sf.avoidWater or sf.avoidCliffs or sf.altMinEnable or sf.altMaxEnable) and true or false
	)
	-- INFLUENCE chips + the active channel's profile name
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

	-- Canonical DISPLAY/INSTRUMENTS mirror (shared TB state, sf prefix) —
	-- serves both submodes, so it runs before the hard branch below.
	if ctx.syncTBMirrorControls then
		ctx.syncTBMirrorControls(doc, "sf")
	end
	-- Ctrl sneak-peek gate, mirrored into both paint engines (both submodes)
	pushPeekEnabled(dm)

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
	---@type table?
	local T = WG.TilesetTerrain
	local list, bkey = nil, nil
	if T and T.getSurfaceVariants then
		list, bkey = T.getSurfaceVariants()
	end
	local pickSlot = widgetState.surfPickerSlot
	-- The painter's coverage histogram is a gl.ReadPixels (a GPU sync) and its
	-- only reader here is the picker's "already carries paint" warning, so the
	-- painter computes it only while a picker is open (gated readback).
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
	-- Soft smart filters (canonical FILTERS section) + its warn chip
	do
		local ssf = surfState.smartFilters or {}
		setDm("surfSoftAvoidWater", ssf.avoidWater == true)
		setDm("surfSoftAvoidCliffs", ssf.avoidCliffs == true)
		setDm("surfSoftAltMin", ssf.altMinEnable == true)
		setDm("surfSoftAltMax", ssf.altMaxEnable == true)
		ctx.syncWarnChip(
			doc,
			"warn-chip-sf-smart",
			"section-sf-smart",
			(ssf.avoidWater or ssf.avoidCliffs or ssf.altMinEnable or ssf.altMaxEnable) and true or false
		)
	end
	-- INFLUENCE chips + the armed texture's profile name
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
	-- Per-slot chip state, and FILL WITH NOISE stays enabled only while some
	-- channel is both assigned and switched on.
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
	-- The single FLIP button mirrors the SELECTED slot's flag (BASE included)
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

		-- HOVER PREVIEW. Hovered tile wins; with nothing hovered the preview
		-- shows what the slot being assigned already holds, so opening the
		-- picker starts from the current material rather than an empty box.
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

	-- NOW PAINTING strip + selection slot for the rail's active ring
	do
		local sel = surfState.variant
		local selSlot = surfState.selSlot or 0
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

	-- Coverage percentages are gone from the panel (2026-08-22): an artist reads
	-- the ground, not a histogram, and the bar plus eight per-tile shares cost
	-- more space than the slot buttons did. The painter still computes coverage
	-- on stroke end — the picker uses it for the "this slot already carries
	-- paint" warning, which is a consequence, not a metric.

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
