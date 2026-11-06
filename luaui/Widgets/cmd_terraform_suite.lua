local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Terraform Suite Launcher",
		desc = "Loads the map editor suite on demand (/terraformbrush, /terraformpanel, /terraformsuite)",
		author = "PtaQ",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		handler = true,
	}
end

-- The editor widgets ship enabled = false so players who never open the editor
-- pay nothing for the suite: no Lua parse, no RML documents, no callins.
-- This launcher is the only always-on piece. It owns the suite entry commands,
-- enables the suite widgets on first use, then passes every later invocation
-- through to the real handlers (they sort after us in the action list).
-- Backends first, UI panels last: enable order is load order, and the RML
-- panels expect their WG.* backends to exist when they initialize.
local SUITE_WIDGETS = {
	"Terraform Brush",
	"Clone Tool",
	"Decal Capture",
	"Decal Placer",
	"Diffuse Painter",
	"DrawFeatureShape GL4",
	"Feature Placer",
	"Grass Brush",
	"Light Placer",
	"Metal Brush",
	"Splat Painter",
	"Start Positions Tool",
	"Terraform Brush Capture",
	"Weather Brush",
	"Water Type Overlay GL4",
	"Terraform Image Overlay",
	"Terraformer Shared RmlUi Helpers",
	"Terraform Brush UI",
	"Decal Placer UI",
	"Diffuse Library UI",
	"Feature Placer UI",
	"Weather Brush UI",
	"Map Labels UI",
	"Unit Library UI",
	"Unit Placer",
	"Map Project",
	"Map Transform",
	"Terraform Key Gate",
}

-- Widgets the tileset shader sync installs in the write dir (LuaUI/Widgets/),
-- not shipped with the game. They are off by default, and they only show up in
-- knownWidgets when they are installed and user widgets are allowed, so the
-- suite turns them on with itself when it finds them. Without them a project's
-- TILESET and SURFACE sections are skipped on load. Tileset first: the surface
-- painter draws into its variant mask.
local OPTIONAL_WIDGETS = {
	"Tileset Terrain Prototype",
	"Surface Painter (Tileset Variants)",
}
-- The optional widgets this suite turned on, so Shutdown turns off only those:
-- someone who enabled one by hand keeps it. Saved in our config data because
-- EnableWidget saves the order list right away, and a crash must not leave the
-- tileset shader on in normal games.
local optionalEnabled = {}

-- Entry commands that must work before the suite is loaded. Sub-tool actions
-- (/diffusepaint, /grassbrush, ...) become available once the suite is up.
local ENTRY_ACTIONS = {
	"terraformbrush",
	"terraformup",
	"terraformdown",
	"terraformlevel",
	"terraformsmooth",
	"terraformerode",
	"terraformramp",
	"terraformrestore",
	"terraformexport",
	"terraformimport",
	"terraformpanel",
}

local suiteEnabled = false
local pendingCommand, pendingFrames -- entry command to re-dispatch once the suite is in

-- A map exported from a Terraform Brush project with a tileset look carries it in
-- mapconfig/tileset/ (its presence is the renderer switch). This launcher turns the
-- tileset shader on for such a map and applies the look once the shader's API is up:
-- biome, pattern frame, metal style, tints, knobs, slots and the surface masks, read
-- straight from the archive. Viewer knobs (performance and debug) stay the player's.
-- In the editor the surface painter takes the masks, so they can be painted and saved.
local mapTileset = {
	FILE = "mapconfig/tileset/tileset.lua",
	VIEWER_KNOBS = {
		farCache = true,
		farStart = true,
		farBand = true,
		farCliffFp = true,
		clipCache = true,
		clipRes = true,
		clipCoarseMin = true,
		coProgram = true,
		debugView = true,
		passSlopeDeg = true,
	},
	cfg = nil, -- the map's tileset.lua while it waits; kept after applying for the painter hand-back
	waited = 0.0,
	applied = false,
	painterFed = false,
}

local function readMapTileset()
	if not VFS.FileExists(mapTileset.FILE, VFS.MAP) then
		return nil
	end
	local ok, cfg = pcall(VFS.Include, mapTileset.FILE, {}, VFS.MAP)
	if ok and type(cfg) == "table" and cfg.renderer == "tileset" and cfg.format_version == 1 then
		return cfg
	end
	Spring.Echo("[Terraform Suite] " .. mapTileset.FILE .. " not applied: " .. tostring(ok and "unknown format" or cfg))
	return nil
end

local function deepCopy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = type(v) == "table" and deepCopy(v) or v
	end
	return c
end

-- The handler collects GetConfigData before the shutdown pass, so the map's look would
-- become the player's saved shader config (and their next editor session's). Pin what
-- the shader would have saved before the map touched it.
local function pinShaderConfig()
	for _, w in ipairs(widgetHandler.widgets or {}) do
		if w.whInfo and w.whInfo.name == OPTIONAL_WIDGETS[1] and w.GetConfigData then
			local ok, snap = pcall(w.GetConfigData, w)
			if ok and type(snap) == "table" then
				snap = deepCopy(snap)
				w.GetConfigData = function()
					return snap
				end
			end
			return
		end
	end
end

local function feedPainter(sp, cfg)
	local s = cfg.surface_slots
	local picks = {}
	for i = 1, 8 do
		picks[i] = (s["slot" .. i] ~= "" and s["slot" .. i]) or nil
	end
	sp.applySlots(picks)
	sp.setInfluenceTable(s.influence)
	sp.loadMask(cfg.surface)
end

local function surfaceFits(cfg)
	local s = cfg.surface_slots
	return cfg.surface and type(s) == "table" and (s.biome == nil or s.biome == "" or s.biome == cfg.biome)
end

local function applyMapTileset(T, cfg)
	pinShaderConfig()
	if not T.isActive() then
		T.setActive(true)
	end
	local f = type(cfg.pattern_frame) == "table" and cfg.pattern_frame or {}
	T.setPatternFrame(f[1] or 1, f[2] or 0, f[3] or 0, f[4] or 1, f[5] or 0, f[6] or 0)
	local _, _, active = T.getActiveBiome()
	if type(cfg.biome) == "string" and cfg.biome ~= "" and cfg.biome ~= active then
		T.setBiome(cfg.biome)
	end
	-- knobs the file lacks go to the biome's defaults, not the player's own tuning
	T.reset()
	if type(cfg.metal_style) == "string" and cfg.metal_style ~= "" then
		T.setMetalStyle(cfg.metal_style)
	end
	for asset in pairs(T.getSlotTints() or {}) do
		T.setSlotTint(asset, 1, 1, 1)
	end
	for asset, c in pairs(type(cfg.slot_tints) == "table" and cfg.slot_tints or {}) do
		T.setSlotTint(asset, c[1], c[2], c[3])
	end
	-- the map ships its ramp under mapconfig/; an older shader keeps only the name and shows a same-named local one
	T.setRamp(type(cfg.ramp) == "string" and cfg.ramp or "")
	local live = T.getKnobs()
	for k, v in pairs(type(cfg.knobs) == "table" and cfg.knobs or {}) do
		if type(v) == "number" and not mapTileset.VIEWER_KNOBS[k] and not T.setKnob(k, v) and live[k] ~= nil then
			live[k] = v
		end
	end
	if cfg.metal_lights ~= nil then
		T.setMetalLights(cfg.metal_lights)
	end
	if type(cfg.slot4_material) == "string" and cfg.slot4_material ~= "" then
		T.setSlot4Material(cfg.slot4_material)
	end
	if surfaceFits(cfg) then
		---@type table?
		local sp = WG.SurfacePainter
		if sp and sp.loadMask then
			feedPainter(sp, cfg)
			mapTileset.painterFed = true
		else
			-- a normal game: bind the masks straight, no painter
			local s = cfg.surface_slots
			for i = 1, 8 do
				T.setSurfaceVariant(i, (s["slot" .. i] ~= "" and s["slot" .. i]) or nil)
			end
			T.setSurfaceMask(":l:" .. cfg.surface)
			if cfg.surface_v4 then
				T.setSurfaceMask2(":l:" .. cfg.surface_v4)
			end
		end
	end
	Spring.Echo(
		"[Terraform Suite] tileset look applied from " .. mapTileset.FILE .. " (biome " .. tostring(cfg.biome) .. ")"
	)
end

-- Per frame until the map's tileset is applied, then only to hand the masks to a painter
-- that appears later (the editor opened mid-game): its first stroke would otherwise paint
-- over a blank mask.
local function updateMapTileset(dt)
	local cfg = mapTileset.cfg
	if not cfg then
		return
	end
	if mapTileset.applied and WG.TilesetTerrain and WG.TilesetTerrain ~= mapTileset.appliedTo then
		-- the shader widget restarted (switched off and on in the widget list): it came back
		-- with the player's saved look, so the map's goes on again once its API is up
		mapTileset.applied, mapTileset.painterFed, mapTileset.waited = false, false, 0.0
	end
	if mapTileset.applied then
		---@type table?
		local sp = WG.SurfacePainter
		if not mapTileset.painterFed and sp and sp.loadMask and not (sp.hasMaskState and sp.hasMaskState()) then
			mapTileset.painterFed = true
			if surfaceFits(cfg) then
				feedPainter(sp, cfg)
			end
		end
		return
	end
	---@type table?
	local T = WG.TilesetTerrain
	---@type table?
	local MP = WG.MapProject
	if T and T.setSlotTint and not (MP and MP.isLoading and MP.isLoading()) then
		mapTileset.applied, mapTileset.appliedTo = true, T
		local ok, err = pcall(applyMapTileset, T, cfg)
		if not ok then
			Spring.Echo("[Terraform Suite] map tileset failed: " .. tostring(err))
		end
		return
	end
	-- capped: the first Update after the loading screen carries the whole load in its dt
	mapTileset.waited = mapTileset.waited + math.min(dt, 0.25)
	if mapTileset.waited > 20 then
		Spring.Echo("[Terraform Suite] this map has a tileset look, but the tileset shader is not available")
		mapTileset.cfg = nil
	end
end

local function enableOptionalWidgets()
	local known = widgetHandler.knownWidgets
	if not (known and widgetHandler.orderList) then
		return
	end
	for i = 1, #OPTIONAL_WIDGETS do
		local name = OPTIONAL_WIDGETS[i]
		if known[name] and (widgetHandler.orderList[name] or 0) <= 0 then
			optionalEnabled[name] = true
			widgetHandler:EnableWidget(name)
		end
	end
end

local function enableSuite()
	if suiteEnabled then
		return false
	end
	suiteEnabled = true
	enableOptionalWidgets()
	for i = 1, #SUITE_WIDGETS do
		widgetHandler:EnableWidget(SUITE_WIDGETS[i])
	end
	return true
end

function widget:Initialize()
	-- the key gate hands keys to these widgets first
	WG.TerraformSuiteWidgets = SUITE_WIDGETS

	-- EnableWidget persists enablement through SaveConfigData. If a crash
	-- skipped our Shutdown cleanup the suite comes back enabled next game;
	-- adopt it so entry commands pass through and Shutdown disables it again.
	local order = widgetHandler.orderList and widgetHandler.orderList["Terraform Brush"]
	if order and order > 0 then
		suiteEnabled = true
		enableOptionalWidgets()
		-- enableSuite() will not run this session, and a saved order list can predate
		-- widgets added to SUITE_WIDGETS: enable any that are missing.
		for i = 1, #SUITE_WIDGETS do
			if (widgetHandler.orderList[SUITE_WIDGETS[i]] or 0) <= 0 then
				widgetHandler:EnableWidget(SUITE_WIDGETS[i])
			end
		end
	end

	-- A map that carries a tileset look switches the tileset shader on (released at Shutdown
	-- like the suite's own optional widgets, so normal maps stay on the engine shader).
	mapTileset.cfg = readMapTileset()
	if mapTileset.cfg then
		local known = widgetHandler.knownWidgets
		local name = OPTIONAL_WIDGETS[1]
		if known and known[name] and widgetHandler.orderList and (widgetHandler.orderList[name] or 0) <= 0 then
			optionalEnabled[name] = true
			widgetHandler:EnableWidget(name)
		end
	end

	-- handler = true hands us the RAW widgetHandler, which has no AddAction
	-- method (that lives on the per-widget proxy). Register through the
	-- actionHandler directly, like gui_options and dbg_test_runner do.
	widgetHandler.actionHandler:AddAction(widget, "terraformsuite", function()
		if not enableSuite() then
			Spring.Echo("[Terraform Suite] Already loaded")
		end
		return true
	end, nil, "t")

	for i = 1, #ENTRY_ACTIONS do
		local cmd = ENTRY_ACTIONS[i]
		widgetHandler.actionHandler:AddAction(widget, cmd, function(_, optLine)
			if suiteEnabled then
				return false -- suite widgets own this command now
			end
			enableSuite()
			-- Re-dispatch so the real handler receives the original command with its
			-- arguments. Not right away: widgets enabled from inside an action are only
			-- inserted on a later frame, and a command sent now would reach no handler.
			pendingCommand = cmd .. ((optLine and optLine ~= "") and (" " .. optLine) or "")
			pendingFrames = 2
			return true
		end, nil, "t")
	end
end

function widget:Update(dt)
	updateMapTileset(dt)
	if not pendingCommand then
		return
	end
	pendingFrames = pendingFrames - 1
	if pendingFrames <= 0 then
		local cmd = pendingCommand
		pendingCommand = nil
		Spring.SendCommands(cmd)
	end
end

function widget:Shutdown()
	-- Leave the widget config the way we found it, otherwise SaveConfigData
	-- keeps the whole suite enabled for all of this player's future games.
	-- Direct orderList write instead of DisableWidgetRaw: removing widgets
	-- while the handler iterates its shutdown list is not safe.
	if not (widgetHandler.orderList and widgetHandler.widgets) then
		return
	end
	-- Only when LuaUI itself goes down. Switching off just this launcher marks
	-- it inactive before its Shutdown runs, and the suite it loaded keeps
	-- running, so its config must keep saying so.
	local own = widget.whInfo and widgetHandler.knownWidgets and widgetHandler.knownWidgets[widget.whInfo.name]
	if own and own.active == false then
		return
	end
	local release = {}
	if suiteEnabled then
		for i = 1, #SUITE_WIDGETS do
			release[SUITE_WIDGETS[i]] = true
		end
	end
	for name in pairs(optionalEnabled) do
		release[name] = true
	end
	optionalEnabled = {}
	if not next(release) then
		return
	end
	-- SaveConfigData writes orderList[name] = position for every widget still in
	-- the handler's list, and at Shutdown all of them are, so a plain save turns
	-- the zeros back into "enabled". Saves also follow this callin (an EnableWidget
	-- queued during the shutdown pass saves again), so every save from here on
	-- leaves the released widgets out. Their config data was already collected
	-- before the shutdown pass; a reload builds a fresh handler without this override.
	local handlerSave = widgetHandler.SaveConfigData
	local function saveReleased(handler)
		for name in pairs(release) do
			if (handler.orderList[name] or 0) > 0 then
				handler.orderList[name] = 0
			end
		end
		local all = handler.widgets
		local kept = {}
		for i = 1, #all do
			if not release[all[i].whInfo.name] then
				kept[#kept + 1] = all[i]
			end
		end
		handler.widgets = kept
		local ok, err = pcall(handlerSave, handler)
		handler.widgets = all
		if not ok then
			Spring.Echo("[Terraform Suite] could not save the widget config: " .. tostring(err))
		end
	end
	widgetHandler.SaveConfigData = saveReleased
	saveReleased(widgetHandler)
end

function widget:GetConfigData()
	local names = {}
	for name in pairs(optionalEnabled) do
		names[#names + 1] = name
	end
	return { optionalEnabled = names }
end

function widget:SetConfigData(data)
	if type(data) == "table" and type(data.optionalEnabled) == "table" then
		for _, name in ipairs(data.optionalEnabled) do
			if type(name) == "string" then
				optionalEnabled[name] = true
			end
		end
	end
end
