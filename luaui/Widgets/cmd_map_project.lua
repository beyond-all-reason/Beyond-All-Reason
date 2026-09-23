function widget:GetInfo()
	return {
		name = "Map Project",
		desc = "Save and load map projects: one git-friendly folder bundling heightmap, splat, metal, features, decals, lights, environment, weather, grass, start positions and (optionally) the unit loadout",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000000,
		enabled = false,
	}
end

-- Save orchestration for map projects (see doc: map-project-format-draft.md).
-- One project = one folder under MapProjects/<slug>/ with a versioned manifest
-- (project.lua, written LAST as the commit marker) plus per-section files in the
-- existing tools' formats. Filenames are fixed and serialization is deterministic:
-- git history is the versioning, so a re-save of unchanged state must produce a
-- zero diff except the manifest's `modified` field.
--
-- The save runs as a small state machine pumped from widget:DrawScreen (the
-- codebase's pattern for deferred work, and the env snapshot needs a draw
-- context for gl.Get*): heightmap sampling is millions of GetGroundHeight calls
-- (chunked here), and the splat PNG is written by the splat painter inside its
-- own draw pump (requested, then polled).
--
-- LOAD: opening a project restarts the engine into a blank map of the project's
-- recorded size (the UI builds the start script and writes a pointer file),
-- then a post-restart driver here replays every section in phase order. The
-- pointer file carries a phase journal: it is updated after each completed
-- phase and only deleted when the load finishes (or is aborted), so a
-- /luaui reload mid-load RESUMES instead of dying — every phase is an
-- idempotent replay. The driver consumes the pointer ONLY when the session
-- matches the recorded map (blank-map name, exact size, map damage enabled,
-- local singleplayer); on mismatch it deletes the pointer and explains itself.

-- Engine globals as chunk locals: the CI analyzer counts every bare engine
-- global as an undefined-global finding (same table objects, no behaviour change).
local Spring = Spring
local VFS = VFS
local Echo = Spring.Echo

local PROJECTS_DIR = "MapProjects/"
local FORMAT_VERSION = 1
local ELMOS_PER_UNIT = 512
local POINTER_PATH = "Terraform Brush/pending_project.lua"
local ACK_PARAM = "tfb_import_done" -- rules param set by the terraform gadget after $terraform_import_end$

-- Chunk budgets per Update tick (keep the UI responsive during save)
local HEIGHT_ROWS_PER_TICK = 32
local METAL_ROWS_PER_TICK = 128
local SPLAT_TIMEOUT_TICKS = 300

-- Load driver pacing (all in draw-frame ticks unless noted)
local CHEAT_RESEND_TICKS = 150 -- min gap between /cheat sends ("cheat" TOGGLES — never double-send)
local CHEAT_MAX_SENDS = 8 -- then abort loudly
local DNTS_WAIT_TICKS = 300 -- wait for splat normals to appear before splat load
local SPLAT_LOAD_TIMEOUT = 600
local IMPORT_START_TICKS = 300 -- import never went in-flight => decode failed
local ACK_TIMEOUT_FRAMES = 120 -- GAME frames after stream end without sim ack => failed
local DIFFUSE_TIMEOUT_TICKS = 3600 -- full-map diffuse capture/load is many chunked GL ticks
local UNITS_TIMEOUT_TICKS = 300 -- synced units export round-trip
local UNITS_ACK_PARAM = "mpu_ack" -- rules param set by the units gadget after a replace

local heightmapPNG = nil -- lazy VFS.Include of the shared 16-bit PNG codec

-- The two job tables are declared nil and built by startSave / maybeStartLoad;
-- every step function runs only while its job exists. Typed as tables so the
-- analyzer reads the steps' field access as such rather than as nil.
---@type table
local job = nil -- active save job, nil when idle
---@type table
local loadJob = nil -- active load job, nil when idle (never both at once)
local unitsRx = nil -- receive buffer for the synced units export (stepUnits)
---@type table?
local mapLibrary = nil -- unsynced companion queue; Git runs outside the engine

-- The project this session IS: set when a load starts (the session exists to
-- replay that project) and when a save completes. FILE > Save targets it.
---@type string?
local currentSlug = nil

-- Outcome of the most recent save ({ok, slug}), for the UI's transient
-- "SAVED: <name>" readout — it polls saveProgress() and reads this when the
-- running save disappears.
local lastSaveInfo = nil
-- Unsaved-changes flag: how many edits were reported since the last save or
-- load. Tools report through WG.MapProject.markDirty; the count is cleared by
-- a finished save or load, and ignored for a few seconds after either, while
-- the engine's own heightmap updates are still trickling in.
local dirtyCount = 0
local dirtyGraceUntil = 0.0
-- The project whose diffuse/ squares the painter is known to hold: set when a
-- load's diffuse phase delivered them (or the project had none) and when a
-- save's capture left the folder exact. A save over a project whose squares
-- this session never loaded (the phase skipped, failed or timed out) must not
-- treat the painter's empty state as "no paint" and delete them.
local diffuseLoadedSlug = nil

-- Autosave (Settings > General): a snapshot of the open project every few
-- minutes while it has unsaved changes, into MapProjects/_autosave/ as
-- <project>-YYYYMMDDHHMM. The panel pushes the settings through setAutosave;
-- until it does, the defaults stand (configureAutosave fills the table, so
-- its fields type from that assignment rather than from literals here).
local AUTOSAVE_DIR = "_autosave"
local autosaveCfg = {}
local autosaveNextAt = 0.0 -- os.clock() of the next attempt
local autosavePruneAt = 0.0 -- os.clock() of the next sweep of old snapshots
local autosaveDirtyMark = 0 -- dirtyCount when the last snapshot started
local autosaveJournal = {} -- slugs written this session; VFS.SubDirs cannot see their folders yet
---@type string?
local autosaveLoadedSlug = nil -- the snapshot this session was opened from, spared by the sweep
---@type table?
local lastAutosaveInfo = nil

----------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------

local function echoP(msg)
	Echo("[Map Project] " .. msg)
end

-- Windows reserved device names make CreateDir fail or produce unusable paths.
local RESERVED_NAMES = {
	con = true,
	prn = true,
	aux = true,
	nul = true,
	com1 = true,
	com2 = true,
	com3 = true,
	com4 = true,
	com5 = true,
	com6 = true,
	com7 = true,
	com8 = true,
	com9 = true,
	lpt1 = true,
	lpt2 = true,
	lpt3 = true,
	lpt4 = true,
	lpt5 = true,
	lpt6 = true,
	lpt7 = true,
	lpt8 = true,
	lpt9 = true,
}

-- A project name may carry folders ("campaign/cm09", "maps-repo/teizer/duel"):
-- each segment follows the single-name rules, the depth is capped and the whole
-- path stays short. Folders are what let a git clone of a maps repository sit
-- inside MapProjects/ and list as a tree in the Open Project dialog. Returns
-- the normalized slug (forward slashes, no leading or trailing separator);
-- callers must use the returned value, not their argument.
local MAX_SLUG_DEPTH = 4
local function validateSlug(slug)
	if type(slug) ~= "string" or slug == "" then
		return nil, "missing project name"
	end
	slug = slug:gsub("\\", "/"):gsub("^/+", ""):gsub("/+$", "")
	if slug == "" then
		return nil, "missing project name"
	end
	if #slug > 128 then
		return nil, "project path too long (max 128)"
	end
	if slug:find("//", 1, true) then
		return nil, "project path has an empty folder segment"
	end
	local depth = 0
	for seg in slug:gmatch("[^/]+") do
		depth = depth + 1
		if #seg > 64 then
			return nil, "project name segment too long (max 64)"
		end
		-- Spaces are allowed inside a segment (a git clone of a maps repository
		-- keeps its folder names), never at either end: Windows strips trailing
		-- spaces from folder names, so such a slug would never round-trip.
		if not seg:match("^[A-Za-z0-9_%- ]+$") then
			return nil, "project names may only contain letters, digits, spaces, _ and -; / separates folders"
		end
		if seg:sub(1, 1) == " " or seg:sub(-1) == " " then
			return nil, "a folder or project name cannot start or end with a space"
		end
		if rawget(RESERVED_NAMES, seg:lower()) then
			return nil, "'" .. seg .. "' is a reserved Windows device name"
		end
	end
	if depth > MAX_SLUG_DEPTH then
		return nil, "project path too deep (max " .. MAX_SLUG_DEPTH .. " levels)"
	end
	return slug
end

local function isoNow()
	return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- Always binary mode: Windows text mode would write CRLF, making project bytes
-- differ across OSes and desync the manifest's recorded sizes from #content.
-- All orchestrator-written text uses LF.
local function writeFile(path, content)
	local f = io.open(path, "wb")
	if not f then
		if job then
			job.uploadBlocked = true
		end
		return nil
	end
	local written = f:write(content)
	local closed = f:close()
	if not written or not closed then
		if job then
			job.uploadBlocked = true
		end
		return nil
	end
	return #content
end

local function fileSize(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local size = f:seek("end")
	f:close()
	return size
end

-- Numbers in the manifest: integers stay integers, floats get fixed precision
-- (deterministic serialization).
local function fmtNum(v)
	if v == math.floor(v) then
		return string.format("%d", v)
	end
	return string.format("%.4f", v)
end

local function basename(path)
	return path:match("([^/\\]+)$") or path
end

-- Read a previously saved manifest (created timestamp + canonical height range
-- must survive re-saves). Raw io.open, never VFS: fresh files can be invisible
-- or stale in the VFS view within a session. Also the load-side manifest reader.
local function readPrevManifest(dir)
	local f = io.open(dir .. "project.lua", "r")
	if not f then
		return nil
	end
	local raw = f:read("*a")
	f:close()
	local chunk = loadstring(raw)
	if not chunk then
		return nil
	end
	local ok, data = pcall(chunk)
	if not ok or type(data) ~= "table" then
		return nil
	end
	return data
end

-- Recently opened or saved projects, newest first: written by raw io to the
-- write dir, read back by the Open Project list. Two jobs: RECENT ordering by
-- last touch rather than last save, and a second discovery path for folders
-- the VFS snapshot cannot see yet (a project saved this session, a fresh git
-- clone): a manifest raw io can read gets listed even when VFS.SubDirs misses
-- its folder.
local RECENT_PATH = "Terraform Brush/recent_projects.lua"
local RECENT_MAX = 40

local function readRecent()
	local f = io.open(RECENT_PATH, "rb")
	if not f then
		return {}
	end
	local raw = f:read("*a")
	f:close()
	raw = raw:gsub("^\239\187\191", "")
	local chunk = loadstring(raw)
	if not chunk then
		return {}
	end
	local ok, data = pcall(chunk)
	if not ok or type(data) ~= "table" then
		return {}
	end
	local out = {}
	for _, e in ipairs(data) do
		local slug = type(e) == "table" and validateSlug(e.slug) or nil
		if slug then
			out[#out + 1] = { slug = slug, at = tostring(e.at or "") }
		end
	end
	return out
end

local function touchRecent(slug)
	local kept = { { slug = slug, at = isoNow() } }
	for _, e in ipairs(readRecent()) do
		if e.slug ~= slug and #kept < RECENT_MAX then
			kept[#kept + 1] = e
		end
	end
	local parts = { "-- Recently opened or saved map projects, newest first (Terraform Brush).", "return {" }
	for _, e in ipairs(kept) do
		parts[#parts + 1] = string.format("\t{ slug = %q, at = %q },", e.slug, e.at)
	end
	parts[#parts + 1] = "}"
	Spring.CreateDir("Terraform Brush")
	writeFile(RECENT_PATH, table.concat(parts, "\n") .. "\n")
end

-- Generic `return {...}` section file reader (raw io, same VFS-staleness rule).
local function readLuaFile(path)
	local f = io.open(path, "rb")
	if not f then
		return nil, "cannot open"
	end
	local raw = f:read("*a")
	f:close()
	local chunk, err = loadstring(raw)
	if not chunk then
		return nil, "parse error: " .. tostring(err)
	end
	local ok, data = pcall(chunk)
	if not ok then
		return nil, "run error: " .. tostring(data)
	end
	if type(data) ~= "table" then
		return nil, "not a table"
	end
	return data
end

-- TGA header dims (18-byte header: width LE at offset 12, height LE at 14).
-- Used to validate the grass grid against the session before it can misplace
-- every patch.
local function readTGADims(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local header = f:read(18)
	f:close()
	if not header or #header < 18 then
		return nil
	end
	local w = header:byte(13) + header:byte(14) * 256
	local h = header:byte(15) + header:byte(16) * 256
	return w, h
end

----------------------------------------------------------------
-- Section reporting
----------------------------------------------------------------

local function sectionOk(name, file, bytes, extra)
	job.sections[#job.sections + 1] = { name = name, file = file, bytes = bytes or 0, extra = extra }
end

local function sectionSkip(name, reason, failed)
	job.skipped[#job.skipped + 1] = { name = name, reason = reason }
	if failed then
		job.uploadBlocked = true
	end
end

local function warn(msg, informational)
	job.warnings[#job.warnings + 1] = msg
	if not informational then
		job.uploadBlocked = true
	end
	echoP("WARNING: " .. msg)
end

local function findSection(name)
	for _, s in ipairs(job.sections) do
		if s.name == name then
			return s
		end
	end
	return nil
end

----------------------------------------------------------------
-- Save steps (each returns true when finished; job.cursor holds chunk state)
----------------------------------------------------------------

local function stepPrepare()
	Spring.CreateDir(job.dir .. "assets/decals")
	Spring.CreateDir(job.dir .. "assets/dnts")
	Spring.CreateDir(job.dir .. "mission")

	job.prev = readPrevManifest(job.dir)
	job.mapOptions = Spring.GetMapOptions() or {}

	local mo = job.mapOptions
	if not (mo.blank_map_x or mo.blank_map_y) then
		warn(
			"current map is not an editor blank map; project will record its state, but loading will replay it onto a flat canvas",
			true
		)
	end
	return true
end

-- Sampling is chunked over ticks; the encode runs in the same step's final tick
-- (one step — the pump resets job.cursor between steps, so sample state must
-- not cross a step boundary).
local function stepHeightmap()
	local sq = Game.squareSize
	local c = job.cursor
	if not c.z then
		c.z = 0
		c.idx = 0
		c.heights = {}
		c.minH, c.maxH = math.huge, -math.huge
		c.w = Game.mapSizeX / sq + 1
		c.h = Game.mapSizeZ / sq + 1
	end
	if c.z <= Game.mapSizeZ then
		local rows = 0
		local heights, idx = c.heights, c.idx
		local minH, maxH = c.minH, c.maxH
		local GetGroundHeight = Spring.GetGroundHeight
		while c.z <= Game.mapSizeZ and rows < HEIGHT_ROWS_PER_TICK do
			local z = c.z
			for x = 0, Game.mapSizeX, sq do
				local gh = GetGroundHeight(x, z)
				if gh < minH then
					minH = gh
				end
				if gh > maxH then
					maxH = gh
				end
				idx = idx + 1
				heights[idx] = gh
			end
			c.z = c.z + sq
			rows = rows + 1
		end
		c.idx, c.minH, c.maxH = idx, minH, maxH
		if c.z <= Game.mapSizeZ then
			return false
		end
		-- Sampling complete; encode next tick (known hitch: the codec's per-pixel
		-- loop is one synchronous call — announce it so the freeze is explained).
		echoP("encoding heightmap PNG (" .. c.w .. "x" .. c.h .. ")...")
		return false
	end
	-- Canonical range: previous manifest range auto-widened to live extremes,
	-- rounded outward to integers so an unchanged terrain re-quantizes to the
	-- exact same PNG bytes. Never clip terrain (silent data loss).
	local minH = math.floor(c.minH)
	local maxH = math.ceil(c.maxH)
	local prevRange = job.prev and job.prev.map and job.prev.map.height_range
	if prevRange and prevRange.min and prevRange.max then
		local widened = minH < prevRange.min or maxH > prevRange.max
		minH = math.min(minH, prevRange.min)
		maxH = math.max(maxH, prevRange.max)
		if widened then
			warn(
				string.format(
					"terrain exceeded the recorded height range; widened to %d..%d (full heightmap diff this save)",
					minH,
					maxH
				),
				true
			)
		end
	end
	if maxH - minH < 1 then
		maxH = minH + 1
	end

	local range = maxH - minH
	local samples = {}
	local floor = math.floor
	for i = 1, c.idx do
		local norm = (c.heights[i] - minH) / range
		if norm < 0 then
			norm = 0
		elseif norm > 1 then
			norm = 1
		end
		samples[i] = floor(norm * 65535 + 0.5)
	end

	local png = heightmapPNG.encodeGray16(c.w, c.h, samples, minH, maxH)
	if not png then
		warn("heightmap PNG encode failed; section skipped")
		sectionSkip("heightmap", "encode failed")
		return true
	end
	local bytes = writeFile(job.dir .. "heightmap.png", png)
	if not bytes then
		warn("could not write heightmap.png")
		sectionSkip("heightmap", "write failed")
		return true
	end
	job.heightRange = { min = minH, max = maxH }
	sectionOk("heightmap", "heightmap.png", bytes)
	return true
end

local function stepSplat()
	local sp = WG.SplatPainter
	local c = job.cursor
	if not c.requested then
		if not (sp and sp.hasSplatState and sp.hasSplatState()) then
			sectionSkip("splat", "no splat paint state (painter inactive or blank map without DNTS)")
			return true
		end
		sp.saveSplats(job.dir .. "splat.png")
		c.requested = true
		c.ticks = 0
		return false
	end
	c.ticks = c.ticks + 1
	if sp.isSavePending() then
		if c.ticks > SPLAT_TIMEOUT_TICKS then
			warn("splat save timed out (painter draw pump never ran)")
			sectionSkip("splat", "timeout")
			return true
		end
		return false
	end
	local bytes = fileSize(job.dir .. "splat.png")
	if bytes then
		sectionOk("splat", "splat.png", bytes)
	else
		sectionSkip("splat", "painter reported done but file missing", true)
	end
	return true
end

-- How many SURFACE variant slots the manifest carries. The painter owns the
-- real number (getState().slotCount); this only has to be >= it, since empty
-- slots serialize as "" and load back as nil.
local MAX_SURFACE_SLOTS = 8

-- SURFACE variant mask (the tileset paint tool, dev_surface_painter.lua):
-- mask PNG like the splat, plus a small surface.lua carrying biome + slot
-- assignment — the mask channels are meaningless without knowing WHICH top
-- variants they weight. Same request/poll shape as the splat step.
-- The painter writes a second "surface_v4.png" beside the first whenever
-- variant 4 carries paint (its weights do not fit the first mask's RGBA); it
-- needs no manifest entry — the loader looks for the sibling itself.
local function stepSurface()
	local sp = WG.SurfacePainter
	local c = job.cursor
	if not c.requested then
		if not (sp and sp.hasMaskState and sp.hasMaskState()) then
			sectionSkip("surface", "no surface paint state (painter inactive or never used)")
			return true
		end
		sp.saveMask(job.dir .. "surface.png")
		c.requested = true
		c.ticks = 0
		return false
	end
	c.ticks = c.ticks + 1
	if sp.isSavePending() then
		if c.ticks > SPLAT_TIMEOUT_TICKS then
			warn("surface mask save timed out (painter draw pump never ran)")
			sectionSkip("surface", "timeout")
			return true
		end
		return false
	end
	local bytes = fileSize(job.dir .. "surface.png")
	if not bytes then
		sectionSkip("surface", "painter reported done but file missing", true)
		return true
	end
	local meta = (sp.getPersist and sp.getPersist()) or {}
	-- every slot the painter reports, so this keeps working as slots are added
	local lines = {
		"return {",
		string.format("\tbiome = %q,", tostring(meta.biome or "")),
	}
	for i = 1, MAX_SURFACE_SLOTS do
		lines[#lines + 1] = string.format("\tslot%d = %q,", i, tostring(meta["slot" .. i] or ""))
	end
	-- INFLUENCE profiles (soft altitude / slope bands the painter remembers per
	-- texture), keyed by asset name, sorted for a stable file.
	if type(meta.influence) == "table" and next(meta.influence) then
		local names = {}
		for n, p in pairs(meta.influence) do
			if type(n) == "string" and type(p) == "table" then
				names[#names + 1] = n
			end
		end
		table.sort(names)
		lines[#lines + 1] = "\tinfluence = {"
		for _, n in ipairs(names) do
			local p = meta.influence[n]
			lines[#lines + 1] = string.format(
				"\t\t[%q] = { altOn = %s, altMin = %s, altMax = %s, altFeatherLo = %s, altFeatherHi = %s, "
					.. "slopeOn = %s, slopeMin = %s, slopeMax = %s, slopeFeather = %s },",
				n,
				tostring(p.altOn and true or false),
				fmtNum(tonumber(p.altMin) or 0),
				fmtNum(tonumber(p.altMax) or 0),
				fmtNum(tonumber(p.altFeatherLo) or 0),
				fmtNum(tonumber(p.altFeatherHi) or 0),
				tostring(p.slopeOn and true or false),
				fmtNum(tonumber(p.slopeMin) or 0),
				fmtNum(tonumber(p.slopeMax) or 0),
				fmtNum(tonumber(p.slopeFeather) or 0)
			)
		end
		lines[#lines + 1] = "\t},"
	end
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""

	if not writeFile(job.dir .. "surface.lua", table.concat(lines, "\n")) then
		warn("surface.lua write failed — the mask will load without slot assignments")
	end
	sectionOk(
		"surface",
		"surface.png",
		bytes,
		(function()
			local n = 0
			for i = 1, MAX_SURFACE_SLOTS do
				if meta["slot" .. i] then
					n = n + 1
				end
			end
			return (n > 0) and (n .. " slot" .. ((n == 1) and "" or "s") .. " assigned") or "no slots assigned"
		end)()
	)
	return true
end

-- Full tileset configuration. surface.lua records only biome + variant slot
-- picks, and only when a mask was ever painted; this section owns the rest of
-- the scene setup — every tuning knob, the metal-spot style and glow lights,
-- and the slot-4 EXTRA LAYER material — so a project round-trips the whole
-- TILESET window. Deliberately NOT in SECTION_FILES: a save run without the
-- write-dir tileset widget must keep the previous tileset.lua (the state it
-- describes cannot have changed without the widget), not delete it as stale.
local function stepTileset()
	local T = WG.TilesetTerrain
	if not (T and T.getKnobs and T.getActiveBiome) then
		sectionSkip("tileset", "tileset widget not loaded")
		return true
	end
	local _, _, biomeKey = T.getActiveBiome()
	local lines = {
		"return {",
		string.format("\tbiome = %q,", tostring(biomeKey or "")),
	}
	if T.getActiveMetalStyle then
		local _, _, msKey = T.getActiveMetalStyle()
		lines[#lines + 1] = string.format("\tmetal_style = %q,", tostring(msKey or ""))
	end
	if T.getMetalLights then
		lines[#lines + 1] = string.format("\tmetal_lights = %s,", tostring(T.getMetalLights() and true or false))
	end
	if T.getSlot4State then
		local s4 = T.getSlot4State()
		if s4 and s4.material then
			lines[#lines + 1] = string.format("\tslot4_material = %q,", tostring(s4.material))
		end
	end
	-- HEIGHT TINT ramp image (tileset shader 0.27): the gradient's basename,
	-- Lua-side state like the biome key rather than a knob
	if T.getRamp then
		local rampFile = T.getRamp()
		if rampFile and rampFile ~= "" then
			lines[#lines + 1] = string.format("\tramp = %q,", tostring(rampFile))
		end
	end
	-- per-texture albedo tints of painted variants (SURFACE > GRADING), sorted
	if T.getSlotTints then
		local tints = T.getSlotTints() or {}
		local names = {}
		for a, c in pairs(tints) do
			if type(a) == "string" and type(c) == "table" then
				names[#names + 1] = a
			end
		end
		table.sort(names)
		if #names > 0 then
			lines[#lines + 1] = "\tslot_tints = {"
			for _, a in ipairs(names) do
				local c = tints[a]
				lines[#lines + 1] = string.format(
					"\t\t[%q] = { %s, %s, %s },",
					a,
					fmtNum(tonumber(c[1]) or 1),
					fmtNum(tonumber(c[2]) or 1),
					fmtNum(tonumber(c[3]) or 1)
				)
			end
			lines[#lines + 1] = "\t},"
		end
	end
	-- keys sorted so repeated saves of unchanged state serialize identically
	-- (project files live in git)
	local knobs = T.getKnobs() or {}
	local keys = {}
	for k, v in pairs(knobs) do
		if type(k) == "string" and type(v) == "number" then
			keys[#keys + 1] = k
		end
	end
	table.sort(keys)
	lines[#lines + 1] = "\tknobs = {"
	for _, k in ipairs(keys) do
		lines[#lines + 1] = string.format("\t\t%s = %s,", k, fmtNum(knobs[k]))
	end
	lines[#lines + 1] = "\t},"
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	local bytes = writeFile(job.dir .. "tileset.lua", table.concat(lines, "\n"))
	if bytes then
		sectionOk("tileset", "tileset.lua", bytes, #keys .. " knobs, biome '" .. tostring(biomeKey) .. "'")
	else
		sectionSkip("tileset", "write failed")
	end
	return true
end

-- Baked diffuse capture (per-square PNGs + enabled shading channels).
-- On real (compiled) maps EVERY square is captured, so a map whose diffuse was
-- generated externally (World Machine workflow) carries its full texture in
-- the project; blank canvases save only painted squares. Layers/masks are NOT
-- serialized — the project records the baked result, and post-load painting
-- extends it (same ownership semantics as the splat section).
-- Failure skips (widget missing, busy, timeout, all captures failed) must NOT
-- delete the diffuse dir or drop the section — hours of paint could live
-- there. Carry the previous manifest section forward so the loader still sees
-- the old files; only a genuine "no paint state" marks the dir as deletable.
local function diffuseFailSkip(reason, notLoaded)
	local prev = job.prev and job.prev.sections and job.prev.sections.diffuse
	if prev or reason ~= "diffuse painter widget not loaded" then
		job.uploadBlocked = true
	end
	if prev and prev.dir then
		if notLoaded then
			warn(reason .. "; keeping the previous save's diffuse files")
		else
			warn("diffuse capture failed (" .. reason .. "); keeping the previous save's diffuse files")
		end
		job.diffuse = {
			full = prev.full or false,
			channels = prev.channels or {},
			squareSize = tonumber(prev.square_size) or 1024,
			count = tonumber(prev.squares) or 0,
		}
		sectionOk("diffuse", "diffuse/", tonumber(prev.bytes) or 0, "carried forward from previous save")
	else
		sectionSkip("diffuse", reason)
	end
	return true
end

local function stepDiffuse()
	local dp = WG.DiffusePainter
	local c = job.cursor
	if not c.requested then
		if not (dp and dp.saveProject) then
			return diffuseFailSkip("diffuse painter widget not loaded")
		end
		-- Saving over the open project while its diffuse squares on disk were
		-- never loaded this session (the load phase skipped, failed or timed
		-- out). A Save As over some other project is that project being
		-- replaced on purpose, so only the session's own project is guarded.
		local prevDiffuse = job.prev and job.prev.sections and job.prev.sections.diffuse
		local guarded = prevDiffuse and prevDiffuse.dir and job.slug == currentSlug
		job.diffuseOnDiskUnloaded = (guarded and diffuseLoadedSlug ~= job.slug) and true or false
		local mo = job.mapOptions
		local isBlank = (mo.blank_map_x or mo.blank_map_y) and true or false
		if isBlank and not (dp.hasProjectState and dp.hasProjectState()) then
			if job.diffuseOnDiskUnloaded then
				-- The project on disk has squares this session never loaded;
				-- the painter's empty state says nothing about them, and the
				-- cleanup step would delete them. Carry the section forward.
				return diffuseFailSkip(
					"diffuse/ holds "
						.. (tonumber(job.prev.sections.diffuse.squares) or 0)
						.. " square(s) this session never loaded",
					true
				)
			end
			sectionSkip("diffuse", "no diffuse paint state")
			job.diffuseStateEmpty = true -- the ONE case where cleanup may wipe diffuse/
			if not job.autosave then
				diffuseLoadedSlug = job.slug -- an empty painter now matches an empty folder
			end
			return true
		end
		Spring.CreateDir(job.dir .. "diffuse")
		if not dp.saveProject(job.dir .. "diffuse/", not isBlank) then
			return diffuseFailSkip("painter is busy")
		end
		echoP("capturing diffuse squares" .. ((not isBlank) and " (full map)" or "") .. "...")
		c.requested = true
		c.ticks = 0
		return false
	end
	c.ticks = c.ticks + 1
	if dp.isProjectSavePending() then
		if c.ticks > DIFFUSE_TIMEOUT_TICKS then
			return diffuseFailSkip("timed out (painter draw pump never finished)")
		end
		return false
	end
	local res = dp.getProjectSaveResult and dp.getProjectSaveResult()
	if not res or res.error or #(res.squares or {}) == 0 then
		return diffuseFailSkip((res and res.error) or "no squares captured")
	end
	-- Stale files inside diffuse/ from a previous save would be resurrected by
	-- the loader's glob — remove anything this save did not write. (VFS listing
	-- of files created earlier THIS session is unpinned; cross-session staleness
	-- is what this reliably covers.)
	local writtenSet = {}
	for _, f in ipairs(res.squares) do
		writtenSet[f] = true
	end
	for _, key in ipairs(res.channels) do
		writtenSet["channel_" .. key .. ".png"] = true
	end
	local existing = VFS.DirList(job.dir .. "diffuse/", "*.png", VFS.RAW) or {}
	local kept = 0
	for _, p in ipairs(existing) do
		local name = basename(p)
		if not writtenSet[name] then
			if job.diffuseOnDiskUnloaded then
				-- Squares this session never loaded are not stale, they are
				-- unseen: leave them for the next load's glob to pick up.
				kept = kept + 1
			else
				os.remove(job.dir .. "diffuse/" .. name)
				echoP("removed stale diffuse/" .. name)
			end
		end
	end
	if kept > 0 then
		warn(string.format("kept %d unloaded diffuse square(s) beside the %d captured", kept, #res.squares))
	elseif not job.autosave then
		-- The folder is exactly what the painter holds. A snapshot's folder is
		-- too, but the painter's project is still the one it was loaded from.
		diffuseLoadedSlug = job.slug
	end
	local bytes = 0
	for name in pairs(writtenSet) do
		bytes = bytes + (fileSize(job.dir .. "diffuse/" .. name) or 0)
	end
	job.diffuse = {
		full = res.full,
		channels = res.channels,
		squareSize = res.squareSize or 1024,
		count = #res.squares,
		bytes = bytes,
	}
	sectionOk(
		"diffuse",
		"diffuse/",
		bytes,
		#res.squares .. " squares" .. (#res.channels > 0 and (", channels: " .. table.concat(res.channels, " ")) or "")
	)
	if (res.failed or 0) > 0 then
		warn(res.failed .. " diffuse square(s) failed to capture")
	end
	return true
end

local function stepMetal()
	local METAL_SQ = Game.metalMapSquareSize or 16
	local mmX = math.floor(Game.mapSizeX / METAL_SQ)
	local mmZ = math.floor(Game.mapSizeZ / METAL_SQ)
	local c = job.cursor
	if not c.mz then
		c.mz = 0
		c.spots = 0
		c.lines = {
			"-- Metal map data for map project",
			"-- Generated by Map Project (Metal Brush format)",
			"-- Metalmap size: " .. mmX .. " x " .. mmZ .. "  squareSize: " .. METAL_SQ,
			"return {",
			"  squareSize = " .. METAL_SQ .. ",",
			"  width = " .. mmX .. ",",
			"  height = " .. mmZ .. ",",
			"  spots = {",
		}
	end
	local rows = 0
	local lines = c.lines
	local GetMetalAmount = Spring.GetMetalAmount
	local format = string.format
	while c.mz < mmZ and rows < METAL_ROWS_PER_TICK do
		local mz = c.mz
		for mx = 0, mmX - 1 do
			local amount = GetMetalAmount(mx, mz)
			if amount > 0.001 then
				local wx = mx * METAL_SQ + METAL_SQ * 0.5
				local wz = mz * METAL_SQ + METAL_SQ * 0.5
				lines[#lines + 1] = format("    {x=%.0f,z=%.0f,mx=%d,mz=%d,amount=%.3f},", wx, wz, mx, mz, amount)
				c.spots = c.spots + 1
			end
		end
		c.mz = c.mz + 1
		rows = rows + 1
	end
	if c.mz < mmZ then
		return false
	end

	if c.spots == 0 then
		sectionSkip("metal", "no metal on map")
		return true
	end
	lines[#lines + 1] = "  },"
	lines[#lines + 1] = "}"
	local bytes = writeFile(job.dir .. "metal.lua", table.concat(lines, "\n"))
	if bytes then
		sectionOk("metal", "metal.lua", bytes, c.spots .. " spots")
	else
		sectionSkip("metal", "write failed")
	end
	return true
end

-- Features come from the feature placer's synced export, not from a local walk
-- of Spring.GetAllFeatures(). Spring.GetFeatureRotation called from LuaUI reads
-- transMatrix[0], which FeatureDrawerData only refreshes for features that were
-- actually drawn this frame, so an unsynced walk reports zero rotation for
-- everything off screen -- the saved bytes would depend on where the camera
-- happened to be pointing. The gadget runs synced, where the transform is always
-- current, and it is also the thing that decides whether a feature is merely
-- ground-aligned or genuinely gizmo-tilted.
--
-- Same request/poll shape as stepUnits.
local FEATURES_TIMEOUT_TICKS = 300
local featuresRx = nil

-- Fallback for when the synced export is unavailable (it needs /cheat, and
-- nothing can have been gizmo-transformed without /cheat either). Reads what the
-- old code read and writes the same 4-field records, deliberately never emitting
-- a transform tail: unsynced rotation is camera-dependent, so guessing from it
-- would be worse than omitting it.
local function writeFeaturesUnsynced(reason)
	local featureIDs = Spring.GetAllFeatures()
	local entries = {}
	for i = 1, #featureIDs do
		local fid = featureIDs[i]
		local defID = Spring.GetFeatureDefID(fid)
		local def = defID and FeatureDefs[defID]
		local x, _, z = Spring.GetFeaturePosition(fid)
		if def and x then
			entries[#entries + 1] = { name = def.name, x = x, z = z, rot = Spring.GetFeatureHeading(fid) or 0 }
		end
	end
	if #entries == 0 then
		sectionSkip("features", "no features on map")
		return true
	end
	table.sort(entries, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		if a.x ~= b.x then
			return a.x < b.x
		end
		if a.z ~= b.z then
			return a.z < b.z
		end
		return a.rot < b.rot
	end)
	local lines = { "local setcfg = {", "\tunitlist = {},", "\tbuildinglist = {},", "\tobjectlist = {" }
	for _, e in ipairs(entries) do
		lines[#lines + 1] = string.format("\t\t{ name = %q, x = %.1f, z = %.1f, rot = %d },", e.name, e.x, e.z, e.rot)
	end
	lines[#lines + 1] = "\t},"
	lines[#lines + 1] = "}"
	lines[#lines + 1] = "return setcfg"
	local bytes = writeFile(job.dir .. "features.lua", table.concat(lines, "\n"))
	if bytes then
		warn("features saved without transform data (" .. reason .. ")")
		sectionOk("features", "features.lua", bytes, #entries .. " features")
	else
		sectionSkip("features", "write failed")
	end
	return true
end

local function stepFeatures()
	local fp = WG.FeaturePlacer
	if not (fp and fp.requestFeatureData) then
		return writeFeaturesUnsynced("feature placer widget not loaded")
	end

	local c = job.cursor
	if not c.requested then
		featuresRx = nil
		local started = fp.requestFeatureData(function(entries, err)
			featuresRx = { entries = entries, err = err, done = true }
		end)
		if not started then
			-- Refused up front (usually /cheat off, which also means nothing can
			-- have been gizmo-transformed). Write what is readable rather than
			-- dropping the whole section.
			local why = (featuresRx and featuresRx.err) or "export unavailable"
			featuresRx = nil
			return writeFeaturesUnsynced(why)
		end
		c.requested = true
		c.ticks = 0
		return false
	end

	c.ticks = c.ticks + 1
	if not (featuresRx and featuresRx.done) then
		if c.ticks > FEATURES_TIMEOUT_TICKS then
			featuresRx = nil
			return writeFeaturesUnsynced("export timed out")
		end
		return false
	end

	local rx = featuresRx
	featuresRx = nil
	if rx.err or not rx.entries then
		return writeFeaturesUnsynced(tostring(rx.err))
	end

	local entries = rx.entries
	if #entries == 0 then
		sectionSkip("features", "no features on map")
		return true
	end

	-- Feature IDs are transient (re-assigned every load), so order by content.
	-- The comparator has to stay total across every field that is written, or two
	-- features differing only in tilt could swap places between saves and produce
	-- a spurious diff.
	local function num(v)
		return v or 0
	end
	table.sort(entries, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		if a.x ~= b.x then
			return a.x < b.x
		end
		if a.z ~= b.z then
			return a.z < b.z
		end
		if a.rot ~= b.rot then
			return a.rot < b.rot
		end
		if num(a.y) ~= num(b.y) then
			return num(a.y) < num(b.y)
		end
		if num(a.pitch) ~= num(b.pitch) then
			return num(a.pitch) < num(b.pitch)
		end
		if num(a.roll) ~= num(b.roll) then
			return num(a.roll) < num(b.roll)
		end
		return (a.scale or 1) < (b.scale or 1)
	end)

	local lines = {
		"local setcfg = {",
		"	unitlist = {},",
		"	buildinglist = {},",
		"	objectlist = {",
	}
	local format = string.format
	for _, e in ipairs(entries) do
		-- The tails are present exactly when the gadget decided this feature was
		-- transformed or scaled, so an unedited map writes the same 4-field
		-- records it always did.
		local scaleField = e.scale and format(", scale = %.3f", e.scale) or ""
		if e.pitch and e.roll and e.y then
			lines[#lines + 1] = format(
				"		{ name = %q, x = %.1f, z = %.1f, rot = %d, pitch = %.4f, roll = %.4f, y = %.1f%s },",
				e.name,
				e.x,
				e.z,
				e.rot,
				e.pitch,
				e.roll,
				e.y,
				scaleField
			)
		else
			lines[#lines + 1] =
				format("		{ name = %q, x = %.1f, z = %.1f, rot = %d%s },", e.name, e.x, e.z, e.rot, scaleField)
		end
	end
	lines[#lines + 1] = "	},"
	lines[#lines + 1] = "}"
	lines[#lines + 1] = "return setcfg"
	local bytes = writeFile(job.dir .. "features.lua", table.concat(lines, "\n"))
	if bytes then
		sectionOk("features", "features.lua", bytes, #entries .. " features")
	else
		sectionSkip("features", "write failed")
	end
	return true
end

-- Shared by the project save and by WG.MapProject.requestUnits: the gadget
-- streams pipe-joined "name x z rot team neutral" records in batches.
local function parseUnitBatches(batches)
	local entries = {}
	for _, payload in ipairs(batches or {}) do
		for entry in payload:gmatch("[^|]+") do
			local name, x, z, rot, team, neutral = entry:match("^(%S+) (%S+) (%S+) (%S+) (%S+) (%S+)$")
			x, z = tonumber(x), tonumber(z)
			if name and x and z then
				entries[#entries + 1] = {
					name = name,
					x = x,
					z = z,
					rot = tonumber(rot) or 0,
					team = tonumber(team) or 0,
					neutral = neutral == "1",
				}
			end
		end
	end
	return entries
end

-- One-shot unit-list read for other widgets (Terraform Brush Capture builds its
-- SVG unit layer from this). Same synced round-trip as the save path, so it sees
-- units outside the player's LOS; refused while a save/load job owns the buffer.
local unitsWaiter = nil
local unitsWaiterTicks = 0

local function requestUnits(callback)
	if type(callback) ~= "function" then
		return false
	end
	if job or loadJob then
		callback(nil, "a project save/load is running")
		return false
	end
	if unitsWaiter then
		callback(nil, "a unit list request is already pending")
		return false
	end
	unitsRx = nil
	unitsWaiter = callback
	unitsWaiterTicks = 0
	Spring.SendLuaRulesMsg("$mpunits_export$")
	return true
end

local function pollUnitsWaiter()
	if not unitsWaiter then
		return
	end
	unitsWaiterTicks = unitsWaiterTicks + 1
	if not (unitsRx and unitsRx.done) then
		if unitsWaiterTicks > UNITS_TIMEOUT_TICKS then
			local cb = unitsWaiter
			unitsWaiter = nil
			cb(nil, "units export timed out (is the Map Project Unit Loadout gadget loaded?)")
		end
		return
	end
	local rx = unitsRx
	unitsRx = nil
	local cb = unitsWaiter
	unitsWaiter = nil
	if rx.denied then
		cb(nil, rx.denied)
	else
		cb(parseUnitBatches(rx.batches))
	end
end

-- Units loadout (opt-in via the Save Project dialog toggle). Collection is a
-- synced gadget round-trip (cmd_map_project_units.lua): the unsynced unit view
-- is LOS-limited, so reading Spring.GetAllUnits here would silently drop every
-- enemy unit outside the player's own LOS — exactly the units a mission draft
-- cares about. The gadget streams begin/data/end into the globals registered
-- in Initialize; this step polls the buffer (same request/poll shape as splat).
local function stepUnits()
	if not job.saveUnits then
		if job.prev and job.prev.sections and job.prev.sections.units then
			warn("'save units loadout' was OFF — the previous save's units.lua will be removed", true)
		end
		sectionSkip("units", "'save units loadout' toggle off")
		return true
	end
	local c = job.cursor
	if not c.requested then
		unitsRx = nil
		Spring.SendLuaRulesMsg("$mpunits_export$")
		c.requested = true
		c.ticks = 0
		return false
	end
	c.ticks = c.ticks + 1
	if not (unitsRx and unitsRx.done) then
		if c.ticks > UNITS_TIMEOUT_TICKS then
			warn("units export timed out (is the Map Project Unit Loadout gadget loaded?)")
			sectionSkip("units", "export timeout")
			unitsRx = nil
			return true
		end
		return false
	end
	local rx = unitsRx
	unitsRx = nil
	if rx.denied then
		warn("units export refused: " .. rx.denied)
		sectionSkip("units", rx.denied)
		return true
	end
	local entries = parseUnitBatches(rx.batches)
	if #entries == 0 then
		sectionSkip("units", "no units on map")
		return true
	end
	-- Unit IDs are transient; order by content for deterministic diffs.
	table.sort(entries, function(a, b)
		if a.team ~= b.team then
			return a.team < b.team
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		if a.x ~= b.x then
			return a.x < b.x
		end
		if a.z ~= b.z then
			return a.z < b.z
		end
		return a.rot < b.rot
	end)
	local lines = {
		"-- Unit loadout for map project (position/team of every unit at save time)",
		"-- Entry fields (name/x/z/rot/team) match scenariooptions.unitloadout",
		"return {",
		"\tversion = 1,",
		"\tunits = {",
	}
	local format = string.format
	for _, e in ipairs(entries) do
		lines[#lines + 1] = format(
			"\t\t{ name = %q, x = %.1f, z = %.1f, rot = %d, team = %d%s },",
			e.name,
			e.x,
			e.z,
			e.rot,
			e.team,
			e.neutral and ", neutral = true" or ""
		)
	end
	lines[#lines + 1] = "\t},"
	lines[#lines + 1] = "}"
	local bytes = writeFile(job.dir .. "units.lua", table.concat(lines, "\n"))
	if bytes then
		job.unitsCount = #entries
		sectionOk("units", "units.lua", bytes, #entries .. " units")
	else
		sectionSkip("units", "write failed")
	end
	return true
end

local function stepDecals()
	local dp = WG.DecalPlacer
	if not (dp and dp.saveProject) then
		sectionSkip("decals", "decal placer not loaded")
		return true
	end
	local path = job.dir .. "decals.lua"
	local n = dp.saveProject(path)
	if not n then
		sectionSkip("decals", "save failed", true)
	elseif n == 0 then
		os.remove(path)
		sectionSkip("decals", "no placed decals")
	else
		sectionOk("decals", "decals.lua", fileSize(path), n .. " decals")
	end
	return true
end

local function stepLights()
	local lp = WG.LightPlacer
	if not lp then
		sectionSkip("lights", "light placer not loaded")
		return true
	end
	local count = lp.getPlacedCount and lp.getPlacedCount() or 0
	if count == 0 then
		sectionSkip("lights", "no placed lights")
		return true
	end
	local path = job.dir .. "lights.lua"
	lp.save(path)
	local bytes = fileSize(path)
	if bytes then
		sectionOk("lights", "lights.lua", bytes, count .. " lights")
	else
		sectionSkip("lights", "write failed")
	end
	return true
end

local function stepLabels()
	local ml = WG.MapLabels
	if not (ml and ml.saveProject) then
		sectionSkip("labels", "map labels widget not loaded")
		return true
	end
	local path = job.dir .. "labels.lua"
	local n = ml.saveProject(path)
	if not n then
		sectionSkip("labels", "save failed", true)
	elseif n == 0 then
		os.remove(path)
		sectionSkip("labels", "no comments placed")
	else
		sectionOk("labels", "labels.lua", fileSize(path), n .. " comments")
	end
	return true
end

local function stepStartPos()
	local st = WG.StartPosTool
	if not st then
		sectionSkip("startpos", "startpos tool not loaded")
		sectionSkip("startboxes", "startpos tool not loaded")
		return true
	end
	local posPath = job.dir .. "startpos.lua"
	if st.saveStartPositions(nil, posPath) then
		sectionOk("startpos", "startpos.lua", fileSize(posPath))
	else
		sectionSkip("startpos", "write failed")
	end
	local boxPath = job.dir .. "startboxes.lua"
	if st.saveStartboxes(nil, boxPath) then
		sectionOk("startboxes", "startboxes.lua", fileSize(boxPath))
	else
		sectionSkip("startboxes", "write failed")
	end
	return true
end

local function stepEnvironment()
	local ui = WG.TerraformBrushUI
	if not (ui and ui.buildEnvConfigContent) then
		sectionSkip("environment", "terraform UI not loaded")
		return true
	end
	local content = ui.buildEnvConfigContent({ nodate = true })
	if type(content) ~= "string" then
		sectionSkip("environment", "snapshot failed", true)
		return true
	end
	local bytes = writeFile(job.dir .. "environment.lua", content)
	if bytes then
		sectionOk("environment", "environment.lua", bytes)
	else
		sectionSkip("environment", "write failed")
	end
	return true
end

local function stepWeather()
	local wb = WG.WeatherBrush
	if not (wb and wb.getPersistentSpawners) then
		sectionSkip("weather", "weather brush not loaded")
		return true
	end
	local spawners = wb.getPersistentSpawners()
	if #spawners == 0 then
		sectionSkip("weather", "no persistent weather spawners")
		return true
	end
	-- Absolute frame fields are session-local; persist remaining lifetime in
	-- seconds (-1 = permanent) and rebase at load. NOTE: finite spawners recompute
	-- persistence against the current frame, so re-saves churn weather.lua by
	-- design; permanent spawners (the common case) are stable.
	local now = Spring.GetGameFrame()
	local gameSpeed = Game.gameSpeed or 30
	local format = string.format
	-- Serialize each spawner to its full text block, then sort the blocks:
	-- lexicographic order over ALL fields is a total order, so ties in any
	-- individual field cannot flip entries between sessions.
	local blocks = {}
	for _, s in ipairs(spawners) do
		local persistence = -1
		if s.expireFrame then
			persistence = math.max(1, math.floor((s.expireFrame - now) / gameSpeed + 0.5))
		end
		local cegParts = {}
		for i = 1, #s.cegs do
			cegParts[i] = format("%q", s.cegs[i])
		end
		blocks[#blocks + 1] = table.concat({
			"\t\t{",
			format("\t\t\tx = %s, z = %s,", fmtNum(s.x), fmtNum(s.z)),
			"\t\t\tcegs = { " .. table.concat(cegParts, ", ") .. " },",
			format("\t\t\tradius = %s,", fmtNum(s.radius)),
			format("\t\t\tcount = %d,", s.count),
			format("\t\t\tshape = %q,", s.shape or "circle"),
			format("\t\t\tangleDeg = %s,", fmtNum(s.angleDeg or 0)),
			format("\t\t\tlengthScale = %s,", fmtNum(s.lengthScale or 1)),
			format("\t\t\taltitude = %s,", fmtNum(s.altitude or 0)),
			format("\t\t\tinterval = %d,", s.interval),
			format("\t\t\trefreshInterval = %d,", s.refreshInterval),
			format("\t\t\tpersistence = %d,", persistence),
			"\t\t},",
		}, "\n")
	end
	table.sort(blocks)
	local lines = {
		"return {",
		"\tversion = 1,",
		"\tspawners = {",
	}
	for _, b in ipairs(blocks) do
		lines[#lines + 1] = b
	end
	lines[#lines + 1] = "\t},"
	lines[#lines + 1] = "}"
	local bytes = writeFile(job.dir .. "weather.lua", table.concat(lines, "\n"))
	if bytes then
		sectionOk("weather", "weather.lua", bytes, #spawners .. " spawners")
	else
		sectionSkip("weather", "write failed")
	end
	return true
end

local function stepGrass()
	local api = WG.grassgl4
	if not api then
		sectionSkip("grass", "grass widget not loaded")
		return true
	end
	if not (api.hasGrass and api.hasGrass()) then
		sectionSkip("grass", "no grass on map")
		return true
	end
	local tgaPath = job.dir .. "grass_dist.tga"
	if not api.saveGrassTGA(tgaPath) then
		sectionSkip("grass", "TGA write failed", true)
		return true
	end
	api.saveGrassConfig(job.dir .. "grass_config.lua", { nodate = true })
	local cfg = api.getConfig and api.getConfig() or {}
	sectionOk("grass", "grass_dist.tga", fileSize(tgaPath), "patchResolution " .. tostring(cfg.patchResolution))
	job.grassPatchResolution = cfg.patchResolution
	return true
end

-- Read a live engine texture into a PNG (GL context required — the save pump
-- runs in DrawScreen). Plain fixed-function blit, alpha preserved (DNTS normal
-- alpha carries the diffuse-blend weight).
local function captureLiveTexture(texName, destPath)
	local info = gl.TextureInfo(texName)
	if not (info and info.xsize and info.xsize > 1) then
		return nil
	end
	local w, h = info.xsize, info.ysize
	local fbo = gl.CreateTexture(w, h, {
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})
	if not fbo then
		return nil
	end
	local ok
	gl.RenderToTexture(fbo, function()
		gl.Blending(false)
		gl.Texture(0, texName)
		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		gl.Texture(0, false)
		gl.Blending(true)
		ok = gl.SaveImage(0, 0, w, h, destPath, { yflip = false, alpha = true })
	end)
	gl.DeleteTexture(fbo)
	return ok and true or false
end

local function stepAssets()
	local mo = job.mapOptions
	-- DNTS set: copy the resolved textures INTO the project (libraries mutate
	-- over months; projects must stay self-contained) and record the resolved
	-- scales/mults so load does not depend on the library.
	local dnts = nil
	local seenSource = {} -- dest name -> source path (detects basename collisions across sets)
	for ch = 1, 4 do
		local tex = mo["blank_map_splatdetailnormaltex" .. ch]
		if tex and tex ~= "" then
			dnts = dnts or { textures = {}, scales = {}, mults = {} }
			local name = basename(tex)
			if seenSource[name] and seenSource[name] ~= tex then
				-- Same filename from a different source: keep both, disambiguated
				name = "ch" .. ch .. "_" .. name
			end
			if not seenSource[name] then
				seenSource[name] = tex
				local data = VFS.LoadFile(tex, VFS.RAW_FIRST)
				if not data then
					-- The VFS cannot see a folder created this session (a project
					-- moved or downloaded since the game started), but the file is
					-- there: the engine is drawing it. Raw io reads it.
					local f = io.open(tex, "rb")
					if f then
						data = f:read("*a")
						f:close()
					end
				end
				if not data then
					-- The session references the texture where its project was when
					-- the game started; a rename or a move since then took the file
					-- with it. Look where the open project is now, then in this
					-- project's own copy from an earlier save.
					local candidates = {}
					if currentSlug then
						candidates[#candidates + 1] = PROJECTS_DIR .. currentSlug .. "/assets/dnts/" .. name
					end
					candidates[#candidates + 1] = job.dir .. "assets/dnts/" .. name
					for _, candidate in ipairs(candidates) do
						if candidate ~= tex then
							local f = io.open(candidate, "rb")
							if f then
								data = f:read("*a")
								f:close()
								if data and #data > 0 then
									break
								end
								data = nil
							end
						end
					end
				end
				if data then
					writeFile(job.dir .. "assets/dnts/" .. name, data)
				else
					warn("DNTS texture not readable, not copied: " .. tex)
				end
			end
			dnts.textures[ch] = "assets/dnts/" .. name
			dnts.scales[ch] = tonumber(mo["blank_map_splattexscale" .. ch]) or 0
			dnts.mults[ch] = tonumber(mo["blank_map_splattexmult" .. ch]) or 0
		end
	end
	if dnts then
		dnts.diffuse_alpha = tonumber(mo.blank_map_splatdetailnormaldiffusealpha) or 1
		-- Provenance: the library set folder name, if the path reveals one
		local firstTex = mo.blank_map_splatdetailnormaltex1 or ""
		dnts.set = firstTex:match("([^/\\]+)[/\\][^/\\]+$")
	end

	-- Compiled maps carry no blank_map_splat* options — their splat setup lives
	-- in mapinfo. Capture the LIVE engine textures instead, so the project is
	-- self-contained and the saved splat.png has textures to modulate on load
	-- (without a dnts record, a splat section saved from a compiled map is
	-- unloadable on the blank canvas).
	if not dnts then
		local scR, scG, scB, scA = gl.GetMapRendering("splatTexScales")
		local muR, muG, muB, muA = gl.GetMapRendering("splatTexMults")
		local scales = { scR, scG, scB, scA }
		local mults = { muR, muG, muB, muA }
		for ch = 1, 4 do
			local name = "capture_normals" .. ch .. ".png"
			if captureLiveTexture("$ssmf_splat_normals:" .. (ch - 1), job.dir .. "assets/dnts/" .. name) then
				dnts = dnts or { textures = {}, scales = {}, mults = {} }
				dnts.textures[ch] = "assets/dnts/" .. name
				dnts.scales[ch] = tonumber(scales[ch]) or 0
				dnts.mults[ch] = tonumber(mults[ch]) or 0
			end
		end
		-- Legacy SSMF maps modulate a single grayscale detail texture instead of
		-- (or in addition to) DNTS normals — capture it too.
		if captureLiveTexture("$ssmf_splat_detail", job.dir .. "assets/dnts/capture_detail.png") then
			dnts = dnts or { textures = {}, scales = scales, mults = mults }
			dnts.detail = "assets/dnts/capture_detail.png"
		end
		if dnts then
			dnts.set = "live-capture"
			dnts.diffuse_alpha = gl.GetMapRendering("splatDetailNormalDiffuseAlpha") and 1 or 0
			echoP("captured the map's live splat textures into assets/dnts/")
		elseif findSection("splat") then
			warn(
				"map has a splat distribution but no capturable splat textures — splat.png may not load onto a blank canvas"
			)
		end
	end
	job.dnts = dnts

	-- Decal captures: copy captures REFERENCED by this project's placements into
	-- the project so they survive archive resets. Reference check is a substring
	-- match of the capture name against the serialized decals.lua (placement tex
	-- strings carry the capture name). Install state is whether the capture also
	-- lives in the game archive's decal atlas source.
	job.assetDecals = {}
	local decalsContent = nil
	do
		local f = io.open(job.dir .. "decals.lua", "rb")
		if f then
			decalsContent = f:read("*a")
			f:close()
		end
	end
	if decalsContent then
		local captures = VFS.DirList("LuaUI/Cache/decal_captures/", "*.png", VFS.RAW) or {}
		for _, path in ipairs(captures) do
			local name = basename(path)
			local nameNoExt = name:gsub("%.png$", "")
			if decalsContent:find(nameNoExt, 1, true) then
				local data = VFS.LoadFile(path, VFS.RAW_FIRST)
				if data then
					writeFile(job.dir .. "assets/decals/" .. name, data)
					job.assetDecals[#job.assetDecals + 1] = {
						name = nameNoExt,
						file = "assets/decals/" .. name,
						installed = VFS.FileExists("bitmaps/decals/" .. name, VFS.MOD) and true or false,
					}
				end
			end
		end
	end
	table.sort(job.assetDecals, function(a, b)
		return a.name < b.name
	end)
	return true
end

-- Canonical section files: anything present on disk but NOT written this save is
-- stale state from a previous save (e.g. metal cleared since) and must go, or a
-- file-presence loader would resurrect deleted state.
local SECTION_FILES = {
	heightmap = { "heightmap.png" },
	-- The thumbnail too: a save whose minimap step skipped (engine texture
	-- not ready) used to keep the picture of two saves ago, so the browser
	-- showed terrain the project no longer had.
	minimap = { "minimap.png" },
	splat = { "splat.png" },
	metal = { "metal.lua" },
	features = { "features.lua" },
	units = { "units.lua" },
	decals = { "decals.lua" },
	startpos = { "startpos.lua" },
	startboxes = { "startboxes.lua" },
	lights = { "lights.lua" },
	labels = { "labels.lua" },
	environment = { "environment.lua" },
	weather = { "weather.lua" },
	grass = { "grass_dist.tga", "grass_config.lua" },
}

local function stepCleanupStale()
	for name, files in pairs(SECTION_FILES) do
		if not findSection(name) then
			for _, file in ipairs(files) do
				local path = job.dir .. file
				if fileSize(path) then
					os.remove(path)
					echoP("removed stale " .. file .. " (section now empty)")
				end
			end
		end
	end
	-- Dir-based diffuse section: clear its folder ONLY when the state is
	-- genuinely empty (paint deleted). Failure skips carry the previous section
	-- forward instead — wiping a dir of up to thousands of square PNGs because
	-- the painter widget happened to be disabled would be data loss.
	if not findSection("diffuse") and job.diffuseStateEmpty then
		local existing = VFS.DirList(job.dir .. "diffuse/", "*.png", VFS.RAW) or {}
		for _, p in ipairs(existing) do
			os.remove(job.dir .. "diffuse/" .. basename(p))
		end
		if #existing > 0 then
			echoP("removed " .. #existing .. " stale diffuse square(s) (section now empty)")
		end
	end
	return true
end

local function stepManifest()
	local mo = job.mapOptions
	local prev = job.prev
	local created = (prev and prev.created) or isoNow()
	-- The name is the leaf: the folder is where the project is, not what it
	-- is called. A manifest that carried the whole path listed as
	-- "Random_maps/pojpjo"; one written that way is corrected on re-save.
	local name = prev and prev.name
	if type(name) ~= "string" or name == "" or name:find("/", 1, true) then
		name = job.slug:match("([^/]+)$") or job.slug
	end

	local lines = {
		"return {",
		'\tkind = "bar-map-project",',
		"\tformat_version = " .. FORMAT_VERSION .. ",",
		string.format("\tname = %q,", name),
		string.format("\tcreated = %q,", created),
		string.format("\tmodified = %q,", isoNow()),
		string.format("\tgame_version = %q,", Game.gameVersion or "unknown"),
		"",
		"\tmap = {",
		string.format("\t\tsize_x = %d, size_z = %d,", Game.mapSizeX / ELMOS_PER_UNIT, Game.mapSizeZ / ELMOS_PER_UNIT),
	}
	if job.autosave then
		-- Which project the snapshot belongs to ("" for a canvas without one):
		-- opening it makes that project the Save target again, and the
		-- Autosaves view labels the row with it.
		table.insert(lines, 5, string.format("\tautosave_of = %q,", currentSlug or ""))
	end
	local function add(line)
		lines[#lines + 1] = line
	end

	local baseHeight = tonumber(mo.blank_map_height)
	if baseHeight then
		add(string.format("\t\tbase_height = %s,", fmtNum(baseHeight)))
	end
	local cr, cg, cb = tonumber(mo.blank_map_color_r), tonumber(mo.blank_map_color_g), tonumber(mo.blank_map_color_b)
	if cr and cg and cb then
		add(string.format("\t\tbase_color = { %s, %s, %s },", fmtNum(cr), fmtNum(cg), fmtNum(cb)))
	end
	if job.heightRange then
		add(string.format("\t\theight_range = { min = %d, max = %d },", job.heightRange.min, job.heightRange.max))
	end
	-- Prefer the runtime pick from the ENVIRONMENT panel over the skybox the
	-- blank canvas was booted with: SetSkyBoxTexture never touches mapOptions,
	-- so mapOptions alone would round-trip the boot skybox forever.
	local ui = WG.TerraformBrushUI
	local liveSkybox = ui and ui.getCurrentSkybox and ui.getCurrentSkybox() or nil
	local skyboxSrc = (liveSkybox and liveSkybox ~= "" and liveSkybox) or mo.blank_map_skybox
	if skyboxSrc and skyboxSrc ~= "" then
		add(string.format("\t\tskybox = %q,", basename(skyboxSrc)))
	end
	add(string.format("\t\tsource_map = %q,", Game.mapName or "unknown"))
	if job.dnts then
		add("\t\tdnts = {")
		if job.dnts.set then
			add(string.format("\t\t\tset = %q,", job.dnts.set))
		end
		add("\t\t\ttextures = {")
		for ch = 1, 4 do
			if job.dnts.textures[ch] then
				add(string.format("\t\t\t\t[%d] = %q,", ch, job.dnts.textures[ch]))
			end
		end
		add("\t\t\t},")
		if job.dnts.detail then
			add(string.format("\t\t\tdetail = %q,", job.dnts.detail))
		end
		local function quad(name, t)
			add(
				string.format(
					"\t\t\t%s = { %s, %s, %s, %s },",
					name,
					fmtNum(t[1] or 0),
					fmtNum(t[2] or 0),
					fmtNum(t[3] or 0),
					fmtNum(t[4] or 0)
				)
			)
		end
		quad("scales", job.dnts.scales)
		quad("mults", job.dnts.mults)
		add(string.format("\t\t\tdiffuse_alpha = %s,", fmtNum(job.dnts.diffuse_alpha)))
		add("\t\t},")
	end
	add("\t},")
	add("")
	add("\tsections = {")
	-- Fixed emission order (deterministic diffs); only sections actually written.
	local order = {
		"heightmap",
		"minimap",
		"splat",
		"surface",
		"tileset",
		"diffuse",
		"metal",
		"features",
		"units",
		"decals",
		"startpos",
		"startboxes",
		"lights",
		"labels",
		"environment",
		"weather",
		"grass",
	}
	for _, name in ipairs(order) do
		local s = findSection(name)
		if s then
			if name == "diffuse" then
				-- Dir-based section: per-square PNGs, discovered by glob at load.
				local d = job.diffuse or {}
				local chParts = {}
				for i, key in ipairs(d.channels or {}) do
					chParts[i] = string.format("%q", key)
				end
				add(
					string.format(
						'\t\tdiffuse = { dir = "diffuse/", version = 1, bytes = %d, square_size = %d, squares = %d, full = %s, channels = { %s } },',
						s.bytes,
						d.squareSize or 1024,
						d.count or 0,
						tostring(d.full or false),
						table.concat(chParts, ", ")
					)
				)
			else
				local extraFields = ""
				if name == "units" and job.unitsCount then
					extraFields = string.format(" count = %d,", job.unitsCount)
				end
				if name == "surface" then
					extraFields = ' meta = "surface.lua",'
				end
				if name == "minimap" and job.minimapSize then
					extraFields = string.format(" width = %d, height = %d,", job.minimapSize.w, job.minimapSize.h)
				end
				if name == "grass" then
					if job.grassPatchResolution then
						extraFields = string.format(" patch_resolution = %d,", job.grassPatchResolution)
					end
					extraFields = extraFields .. ' config = "grass_config.lua",'
				end
				add(
					string.format(
						"\t\t%s = { file = %q, version = 1, bytes = %d,%s },",
						name,
						s.file,
						s.bytes,
						extraFields
					)
				)
			end
		end
	end
	add("\t},")
	add("")
	add("\tassets = {")
	add("\t\tdecals = {")
	for _, d in ipairs(job.assetDecals or {}) do
		add(string.format("\t\t\t{ name = %q, file = %q, installed = %s },", d.name, d.file, tostring(d.installed)))
	end
	add("\t\t},")
	add("\t},")
	add("")
	add("\t-- Reserved for mission tooling (zones/markers/placeholders); additive only.")
	add("\tmission = {")
	add("\t\tzones = {},")
	add("\t\tmarkers = {},")
	add("\t\tplaceholders = {},")
	add('\t\tnotes = "",')
	add("\t},")
	add("}")
	add("")

	local bytes = writeFile(job.dir .. "project.lua", table.concat(lines, "\n"))
	if not bytes then
		job.failed = "could not write project.lua (the manifest is the commit marker — this save is INVALID)"
	end
	return true
end

-- Minimap thumbnail, so a project can be recognised by its picture in the
-- browsers rather than by its name. The engine keeps the map's colour in
-- $minimap and its lighting in $shading, and the minimap everyone knows is the
-- two multiplied -- exactly what the in-game minimap shader computes
-- (minimapColor.rgb * shadingColor.rgb) -- so a second pass with a multiply
-- blend reproduces it without a shader of our own.
--
-- $minimap is square whatever the map's proportions are, so the thumbnail takes
-- its aspect from the map and the whole texture is sampled into it. Blit
-- conventions (TexRect coordinates, SaveImage yflip) are captureLiveTexture's,
-- which is the pattern already writing correct images from this file.
local MINIMAP_LONG_EDGE = 512

local function stepMinimap()
	local info = gl.TextureInfo("$minimap")
	if not (info and (info.xsize or 0) > 1) then
		-- Regenerating after a graphics change, or never drawn this session.
		sectionSkip("minimap", "engine minimap texture not ready")
		return true
	end
	local mapX, mapZ = Game.mapSizeX or 0, Game.mapSizeZ or 0
	if mapX <= 0 or mapZ <= 0 then
		sectionSkip("minimap", "map size unavailable")
		return true
	end
	local w, h = MINIMAP_LONG_EDGE, MINIMAP_LONG_EDGE
	if mapX >= mapZ then
		h = math.max(16, math.floor(MINIMAP_LONG_EDGE * mapZ / mapX + 0.5))
	else
		w = math.max(16, math.floor(MINIMAP_LONG_EDGE * mapX / mapZ + 0.5))
	end
	local fbo = gl.CreateTexture(w, h, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})
	if not fbo then
		sectionSkip("minimap", "could not allocate the thumbnail buffer")
		return true
	end
	local path = job.dir .. "minimap.png"
	local ok
	gl.RenderToTexture(fbo, function()
		gl.Blending(false)
		gl.Texture(0, "$minimap")
		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		gl.Texture(0, false)
		local shading = gl.TextureInfo("$shading")
		if shading and (shading.xsize or 0) > 1 then
			-- dst * src: the multiply the minimap shader does.
			gl.Blending(GL.DST_COLOR, GL.ZERO)
			gl.Texture(0, "$shading")
			gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
			gl.Texture(0, false)
		end
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		-- No alpha: this is a picture of the map, and a thumbnail with an alpha
		-- channel would only cost bytes in every project and every upload.
		ok = gl.SaveImage(0, 0, w, h, path, { yflip = false, alpha = false })
	end)
	gl.DeleteTexture(fbo)
	if ok then
		job.minimapSize = { w = w, h = h }
		sectionOk("minimap", "minimap.png", fileSize(path), string.format("%dx%d", w, h))
	else
		sectionSkip("minimap", "write failed")
	end
	return true
end

local STEPS = {
	{ name = "prepare", run = stepPrepare },
	{ name = "heightmap", run = stepHeightmap },
	{ name = "minimap", run = stepMinimap },
	{ name = "splat", run = stepSplat },
	{ name = "surface", run = stepSurface },
	{ name = "tileset", run = stepTileset },
	{ name = "diffuse", run = stepDiffuse },
	{ name = "metal", run = stepMetal },
	{ name = "features", run = stepFeatures },
	{ name = "units", run = stepUnits },
	{ name = "decals", run = stepDecals },
	{ name = "lights", run = stepLights },
	{ name = "labels", run = stepLabels },
	{ name = "startpos", run = stepStartPos },
	{ name = "environment", run = stepEnvironment },
	{ name = "weather", run = stepWeather },
	{ name = "grass", run = stepGrass },
	{ name = "assets", run = stepAssets },
	{ name = "cleanup", run = stepCleanupStale },
	{ name = "manifest", run = stepManifest },
}

----------------------------------------------------------------
-- Job control
----------------------------------------------------------------

local function finishSave()
	-- The returned receipt belongs to THIS job, unlike an idle flag or old manifest.
	job.result.done = true
	job.result.ok = not job.failed
	job.result.uploadReady = not job.failed and not job.uploadBlocked and findSection("heightmap") ~= nil
	if job.autosave then
		lastAutosaveInfo = job.result
	else
		lastSaveInfo = job.result
	end
	if job.failed then
		echoP(
			(job.autosave and "AUTOSAVE FAILED for '" or "SAVE FAILED for project '") .. job.slug .. "': " .. job.failed
		)
		job = nil
		return
	end
	-- Any finished save, either kind, starts the autosave interval over.
	autosaveNextAt = os.clock() + (tonumber(autosaveCfg.minutes) or 10) * 60
	if job.autosave then
		-- A snapshot changes nothing about the session: the project is still
		-- the Save target and its unsaved changes are still unsaved.
		echoP("autosaved to " .. job.dir)
		autosaveJournal[#autosaveJournal + 1] = job.slug
		autosavePruneAt = os.clock() + 2
	else
		echoP("saved project '" .. job.slug .. "' to " .. job.dir)
		currentSlug = job.slug
		dirtyCount = 0
		autosaveDirtyMark = 0
		dirtyGraceUntil = os.clock() + 2
		touchRecent(currentSlug)
	end
	for _, s in ipairs(job.sections) do
		echoP(string.format("  %-12s %s (%d bytes%s)", s.name, s.file, s.bytes, s.extra and (", " .. s.extra) or ""))
	end
	for _, s in ipairs(job.skipped) do
		echoP(string.format("  %-12s skipped: %s", s.name, s.reason))
	end
	if #job.warnings > 0 then
		echoP(#job.warnings .. " warning(s) above")
	end
	job = nil
end

-- opts.saveUnits: record the unit loadout (position/team of every unit) into
-- units.lua so a loaded project restores the drafted mission state.
-- Returns accepted, receipt; receipt gains done/ok/uploadReady at completion.
local function startSave(slug, opts)
	if mapLibrary and mapLibrary.isBusy() then
		echoP("cannot save while the map library is transferring a project")
		return false
	end
	if job then
		echoP("a save is already running")
		return false
	end
	if loadJob then
		echoP("cannot save while a project load is running")
		return false
	end
	local ok, err = validateSlug(slug)
	if not ok then
		echoP("cannot save: " .. err)
		return false
	end
	slug = ok
	if not heightmapPNG then
		heightmapPNG = VFS.Include("luaui/Widgets/cmd_terraform_brush_png.lua")
	end
	job = {
		slug = slug,
		result = { slug = slug, done = false },
		dir = PROJECTS_DIR .. slug .. "/",
		step = 1,
		cursor = {},
		sections = {},
		skipped = {},
		warnings = {},
		saveUnits = (opts and opts.saveUnits) and true or false,
		autosave = (opts and opts.autosave) and true or false,
	}
	echoP(
		(job.autosave and "autosaving to '" or "saving project '")
			.. slug
			.. "'..."
			.. (job.saveUnits and " (with units loadout)" or "")
	)
	return true, job.result
end

-- Does a project folder with a readable manifest exist? (UI overwrite guard:
-- Save As over an existing project asks for a second click first.)
local function projectExists(slug)
	local ok = validateSlug(slug)
	if not ok then
		return false
	end
	return readPrevManifest(PROJECTS_DIR .. ok .. "/") ~= nil
end

-- Does a saved project include a units section? (UI confirm guard: warns
-- before a toggle-off re-save silently drops a previously saved loadout.)
local function projectHasUnits(slug)
	local ok = validateSlug(slug)
	if not ok then
		return false
	end
	local manifest = readPrevManifest(PROJECTS_DIR .. ok .. "/")
	return (manifest and manifest.sections and manifest.sections.units) and true or false
end

-- One Open Project row. `folder` is the slug's parent path ("" at the root);
-- `last_touched` comes from the recent-projects journal (nil when never
-- opened or saved through this widget).
local function projectEntry(slug, manifest, touchedAt)
	local m = manifest.map or {}
	-- A manifest name that carries a path (saves made before the leaf rule)
	-- lists by its leaf like every other project.
	local name = manifest.name
	if type(name) ~= "string" or name == "" or name:find("/", 1, true) then
		name = slug:match("([^/]+)$") or slug
	end
	return {
		slug = slug,
		folder = slug:match("^(.*)/[^/]+$") or "",
		name = name,
		size_x = tonumber(m.size_x),
		size_z = tonumber(m.size_z),
		created = manifest.created,
		modified = manifest.modified or manifest.created,
		last_touched = touchedAt,
		format_version = tonumber(manifest.format_version),
	}
end

-- One project's listing entry, read straight from its manifest, or nil if there
-- is no project at that path. The listing walks folders with VFS.SubDirs, which
-- cannot see a directory created during this session, so a project that has
-- just been downloaded is missing from it until the next reload -- and the
-- journal fallback does not cover it either, because a download is not an open
-- or a save. Anything that knows the slug it wants can ask here instead: the
-- manifest is read with raw io, which is disk truth.
local function describeProject(slug)
	local ok = validateSlug(slug)
	if not ok then
		return nil
	end
	local manifest = readPrevManifest(PROJECTS_DIR .. ok .. "/")
	if not manifest or manifest.kind ~= "bar-map-project" then
		return nil
	end
	return projectEntry(ok, manifest, nil)
end

-- Folder walk for the listing, MAX_SLUG_DEPTH deep: a folder with project.lua
-- is a project and is not descended into; one without is a container. Hidden
-- folders (".git" in a cloned repository) and names validateSlug rejects are
-- skipped.
local function walkProjects(rel, depth, out, seen, touchedAt)
	local dirs = VFS.SubDirs(PROJECTS_DIR .. (rel ~= "" and (rel .. "/") or ""), "*", VFS.RAW) or {}
	for _, d in ipairs(dirs) do
		local seg = d:match("([^/\\]+)[/\\]*$")
		-- _replaced holds the copies a Team Sync download replaced (newest
		-- three per project), kept for a hand recovery; they are not projects.
		-- _autosave holds the timed snapshots, listed by their own view.
		if seg and seg:sub(1, 1) ~= "." and seg ~= "_replaced" and seg ~= AUTOSAVE_DIR then
			local slug = rel == "" and seg or (rel .. "/" .. seg)
			if validateSlug(slug) then
				local manifest = readPrevManifest(PROJECTS_DIR .. slug .. "/")
				if manifest and manifest.kind == "bar-map-project" then
					seen[slug] = true
					out[#out + 1] = projectEntry(slug, manifest, touchedAt[slug])
				elseif not manifest and depth < MAX_SLUG_DEPTH then
					walkProjects(slug, depth + 1, out, seen, touchedAt)
				end
			end
		end
	end
end

-- Enumerate projects with manifest details for the Open Project dialog.
-- VFS.SubDirs sees the folders (walked as a tree, see walkProjects); manifests
-- are read via raw io (same-session folders may be invisible/stale in the VFS
-- view — SubDirs RAW semantics for folders created THIS session are unpinned).
-- The recent-projects journal then adds any project the snapshot missed whose
-- manifest raw io can read, so a project saved this session or a fresh clone
-- that was opened once still lists. Sorted newest-modified first; the dialog
-- re-sorts per its own control.
local function listProjectsDetailed()
	local out, seen, touchedAt = {}, {}, {}
	local recent = readRecent()
	for _, e in ipairs(recent) do
		touchedAt[e.slug] = e.at
	end
	walkProjects("", 1, out, seen, touchedAt)
	for _, e in ipairs(recent) do
		if not seen[e.slug] then
			local manifest = readPrevManifest(PROJECTS_DIR .. e.slug .. "/")
			if manifest and manifest.kind == "bar-map-project" then
				seen[e.slug] = true
				local p = projectEntry(e.slug, manifest, e.at)
				p.discovered = "recent"
				out[#out + 1] = p
			end
		end
	end
	table.sort(out, function(a, b)
		if (a.modified or "") ~= (b.modified or "") then
			return (a.modified or "") > (b.modified or "")
		end
		return a.slug < b.slug
	end)
	return out
end

local function listProjects()
	local found = listProjectsDetailed()
	for _, p in ipairs(found) do
		echoP(
			string.format(
				"  %-24s %sx%s  modified %s",
				p.slug,
				tostring(p.size_x),
				tostring(p.size_z),
				tostring(p.modified)
			)
		)
	end
	if #found == 0 then
		echoP("no projects in " .. PROJECTS_DIR)
	end
	return #found
end

-- Delete a project folder. validateSlug only admits letter/digit/_/- segments
-- joined by "/", so the target is always a folder under PROJECTS_DIR (never
-- "..", never an absolute path), and a readable manifest is required — never
-- delete a folder this widget did not write. Parent folders of a nested
-- project are left alone. The manifest goes first on purpose: if a file is
-- locked and the sweep leaves junk behind, the project has already stopped
-- listing (both list paths need project.lua) instead of showing up half-deleted.
local function deleteProject(slug)
	if mapLibrary and mapLibrary.isBusy() then
		echoP("cannot delete while the map library is transferring a project")
		return false
	end
	if job then
		echoP("cannot delete a project while a save is running")
		return false
	end
	if loadJob then
		echoP("cannot delete a project while a load is running")
		return false
	end
	local ok, err = validateSlug(slug)
	if not ok then
		echoP("cannot delete: " .. err)
		return false
	end
	slug = ok
	local dir = PROJECTS_DIR .. slug .. "/"
	if not readPrevManifest(dir) then
		echoP("cannot delete '" .. slug .. "': no readable project.lua in " .. dir)
		return false
	end
	local removed, failed = 0, 0
	if os.remove(dir .. "project.lua") then
		removed = removed + 1
	else
		failed = failed + 1
	end
	for _, path in ipairs(VFS.DirList(dir, "*", VFS.RAW, true) or {}) do
		if os.remove(path) then
			removed = removed + 1
		else
			failed = failed + 1
		end
	end
	-- Deepest first, otherwise a parent is still non-empty when we reach it.
	local subs = VFS.SubDirs(dir, "*", VFS.RAW, true) or {}
	table.sort(subs, function(a, b)
		return #a > #b
	end)
	subs[#subs + 1] = dir
	for _, d in ipairs(subs) do
		os.remove((d:gsub("[/\\]+$", "")))
	end
	-- Leftovers are inert: without project.lua the folder no longer lists, so
	-- report and move on rather than failing the delete.
	if failed > 0 then
		echoP(
			string.format(
				"deleted '%s' (%d files, %d could not be removed — folder may linger in %s)",
				slug,
				removed,
				failed,
				PROJECTS_DIR
			)
		)
	else
		echoP(string.format("deleted project '%s' (%d files)", slug, removed))
	end
	-- The session's Save target is gone; the next Save must ask for a name.
	if currentSlug == slug then
		currentSlug = nil
	end
	return true
end

-- Delete a folder under MapProjects/ and every project inside it. The browser
-- asks twice before calling this. Each project goes through deleteProject, so
-- the same guards apply to every one of them (validated path, readable
-- manifest, never a folder this widget did not write); the folders themselves
-- are only removed once they are empty, so anything unexpected inside is left
-- alone rather than swept away with it.
local function deleteFolder(path)
	if mapLibrary and mapLibrary.isBusy() then
		echoP("cannot delete while the map library is transferring a project")
		return false
	end
	if job or loadJob then
		echoP("cannot delete a folder while a save or load is running")
		return false
	end
	local folder, err = validateSlug(path)
	if not folder then
		echoP("cannot delete: " .. tostring(err))
		return false
	end
	local dir = PROJECTS_DIR .. folder .. "/"
	if readPrevManifest(dir) then
		echoP("'" .. folder .. "' is a project, not a folder")
		return false
	end
	local inside = {}
	for _, p in ipairs(listProjectsDetailed()) do
		if p.slug:sub(1, #folder + 1) == (folder .. "/") then
			inside[#inside + 1] = p.slug
		end
	end
	-- Deepest first: a nested project has to go before the folder holding it.
	table.sort(inside, function(a, b)
		return #a > #b
	end)
	local removed = 0
	for _, slug in ipairs(inside) do
		if deleteProject(slug) then
			removed = removed + 1
		end
	end
	if removed < #inside then
		echoP(string.format("deleted %d of %d projects in '%s'; folder kept", removed, #inside, folder))
		return false
	end
	-- Now the empty folders, deepest first. os.remove refuses a non-empty
	-- directory, which is the guard: anything still in there stays.
	local subs = VFS.SubDirs(dir, "*", VFS.RAW, true) or {}
	table.sort(subs, function(a, b)
		return #a > #b
	end)
	subs[#subs + 1] = dir
	for _, d in ipairs(subs) do
		os.remove((d:gsub("[/\\]+$", "")))
	end
	echoP(string.format("deleted folder '%s' (%d project%s)", folder, removed, removed == 1 and "" or "s"))
	return true
end

-- Move a project to another folder under MapProjects/ (the browser's drag and
-- drop). Both ends go through validateSlug, so source and destination are
-- always folders under PROJECTS_DIR, never ".." and never absolute; the source
-- must hold a readable manifest, so this never moves a folder this widget did
-- not write; and the destination must not exist, so a move never overwrites a
-- project. os.rename does the whole thing in one step where the filesystem
-- allows it (same volume, no handle open); the copy path is the fallback, and
-- it only deletes the source once every file has been written.
local function moveProject(slug, target)
	if mapLibrary and mapLibrary.isBusy() then
		echoP("cannot move while the map library is transferring a project")
		return false
	end
	if job or loadJob then
		echoP("cannot move a project while a save or load is running")
		return false
	end
	local from, fromErr = validateSlug(slug)
	if not from then
		echoP("cannot move: " .. tostring(fromErr))
		return false
	end
	local to, toErr = validateSlug(target)
	if not to then
		echoP("cannot move: " .. tostring(toErr))
		return false
	end
	if from == to then
		return false
	end
	-- A project cannot be moved inside itself.
	if to:sub(1, #from + 1) == (from .. "/") then
		echoP("cannot move '" .. from .. "' into itself")
		return false
	end
	local fromDir = PROJECTS_DIR .. from .. "/"
	local toDir = PROJECTS_DIR .. to .. "/"
	if not readPrevManifest(fromDir) then
		echoP("cannot move '" .. from .. "': no readable project.lua in " .. fromDir)
		return false
	end
	if readPrevManifest(toDir) then
		echoP("cannot move: '" .. to .. "' already exists")
		return false
	end
	-- Parent folders first: CreateDir makes one level at a time.
	local walked = PROJECTS_DIR:gsub("/+$", "")
	for segment in to:gmatch("[^/]+") do
		walked = walked .. "/" .. segment
		Spring.CreateDir(walked)
	end
	local renamed = false
	pcall(function()
		renamed = os.rename(fromDir:gsub("/+$", ""), toDir:gsub("/+$", "")) and true or false
	end)
	if not renamed then
		-- Copy every file across, then take the source down the way delete does.
		local files = VFS.DirList(fromDir, "*", VFS.RAW, true) or {}
		files[#files + 1] = fromDir .. "project.lua"
		local copied, seen, written = 0, {}, {}
		for _, path in ipairs(files) do
			local rel = path:gsub("\\", "/"):sub(#fromDir + 1)
			if rel ~= "" and not seen[rel] then
				seen[rel] = true
				local input = io.open(path, "rb")
				if input then
					local data = input:read("*a")
					input:close()
					local sub = rel:match("^(.*)/[^/]+$")
					if sub then
						local dir = toDir:gsub("/+$", "")
						for segment in sub:gmatch("[^/]+") do
							dir = dir .. "/" .. segment
							Spring.CreateDir(dir)
						end
					end
					local output = io.open(toDir .. rel, "wb")
					if not output then
						echoP("cannot move '" .. from .. "': could not write " .. toDir .. rel)
						-- Take the half-made copy back out. Without a project.lua it
						-- never listed, but its files were in the way of the next
						-- move to this path.
						for _, done in ipairs(written) do
							os.remove(done)
						end
						return false
					end
					output:write(data)
					output:close()
					written[#written + 1] = toDir .. rel
					copied = copied + 1
				end
			end
		end
		if copied == 0 then
			echoP("cannot move '" .. from .. "': nothing could be read from " .. fromDir)
			return false
		end
		-- The copy is complete, so the source can go. Leftovers are inert: a
		-- folder without project.lua no longer lists.
		os.remove(fromDir .. "project.lua")
		for _, path in ipairs(VFS.DirList(fromDir, "*", VFS.RAW, true) or {}) do
			os.remove(path)
		end
		local subs = VFS.SubDirs(fromDir, "*", VFS.RAW, true) or {}
		table.sort(subs, function(a, b)
			return #a > #b
		end)
		subs[#subs + 1] = fromDir
		for _, d in ipairs(subs) do
			os.remove((d:gsub("[/\\]+$", "")))
		end
	end
	if currentSlug == from then
		currentSlug = to
	end
	-- The journal addresses projects by slug, so the entry has to follow.
	local kept = {}
	for _, e in ipairs(readRecent()) do
		kept[#kept + 1] = { slug = e.slug == from and to or e.slug, at = e.at }
	end
	local parts = { "-- Recently opened or saved map projects, newest first (Terraform Brush).", "return {" }
	for _, e in ipairs(kept) do
		parts[#parts + 1] = string.format("\t{ slug = %q, at = %q },", e.slug, e.at)
	end
	parts[#parts + 1] = "}"
	Spring.CreateDir("Terraform Brush")
	writeFile(RECENT_PATH, table.concat(parts, "\n") .. "\n")
	echoP(string.format("moved project '%s' to '%s'%s", from, to, renamed and "" or " (copied)"))
	return true
end

-- Rename a project in place: a move within its own folder, and the
-- manifest's name follows, since that is what the browser shows. Returns
-- true and the new slug.
local function renameProject(slug, newLeaf)
	local ok = validateSlug(slug)
	if not ok then
		echoP("cannot rename: bad project path")
		return false
	end
	local leaf = tostring(newLeaf or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if leaf == "" or leaf:find("[/\\]") then
		echoP("cannot rename: the new name must be a single name, not a path")
		return false
	end
	local folder = ok:match("^(.*)/[^/]+$")
	local target = validateSlug((folder and (folder .. "/") or "") .. leaf)
	if not target then
		echoP("cannot rename: '" .. leaf .. "' is not a valid project name")
		return false
	end
	if target == ok then
		return true, target
	end
	if not moveProject(ok, target) then
		return false
	end
	local path = PROJECTS_DIR .. target .. "/project.lua"
	local f = io.open(path, "rb")
	if f then
		local text = f:read("*a")
		f:close()
		-- The name line stepManifest writes; the charset validateSlug allows
		-- has no quotes, so the balanced match is exact.
		local patched, n = text:gsub('\n\tname = %b"",', "\n\tname = " .. string.format("%q", leaf) .. ",", 1)
		if n == 1 then
			local out = io.open(path, "wb")
			if out then
				out:write(patched)
				out:close()
			end
		end
	end
	return true, target
end

----------------------------------------------------------------
-- Load: pointer file (restart survivor with phase journal)
----------------------------------------------------------------

-- Raw io ONLY for the pointer: VFS caches stale content for files created or
-- rewritten within a session (the reason pending_newmap.lua does the same).
----------------------------------------------------------------
-- Autosave
----------------------------------------------------------------

local function configureAutosave(cfg)
	cfg = cfg or {}
	local wasMinutes = autosaveCfg.minutes
	autosaveCfg.enabled = cfg.enabled ~= false
	autosaveCfg.minutes = math.max(1, math.floor(tonumber(cfg.minutes) or 10))
	autosaveCfg.keepDays = math.max(0, tonumber(cfg.keepDays) or 3)
	autosaveCfg.keepLatestDays = math.max(autosaveCfg.keepDays, tonumber(cfg.keepLatestDays) or 10)
	if autosaveCfg.minutes ~= wasMinutes then
		autosaveNextAt = os.clock() + autosaveCfg.minutes * 60
	end
end

-- <project>-YYYYMMDDHHMM -> the project part and the stamp as os.time (local
-- time, the way it was written). nil for a folder that is not one of ours.
local function parseAutosaveLeaf(leaf)
	local base, y, mo, d, h, mi = tostring(leaf):match("^(.+)%-(%d%d%d%d)(%d%d)(%d%d)(%d%d)(%d%d)$")
	if not base then
		return nil
	end
	local stamp = os.time({
		year = tonumber(y) or 0,
		month = tonumber(mo) or 0,
		day = tonumber(d) or 0,
		hour = tonumber(h) or 0,
		min = tonumber(mi) or 0,
		sec = 0,
	})
	return base, stamp
end

-- Every snapshot on disk, newest first: the folder walk plus this session's
-- own writes, whose folders VFS.SubDirs cannot see yet. Entries are shaped
-- like listDetailed's, flat (folder ""), plus the autosave fields.
local function listAutosaves()
	local out, seen = {}, {}
	local function take(slug)
		if seen[slug] then
			return
		end
		local manifest = readPrevManifest(PROJECTS_DIR .. slug .. "/")
		if not manifest or manifest.kind ~= "bar-map-project" then
			return
		end
		seen[slug] = true
		local p = projectEntry(slug, manifest, nil)
		local base, stamp = parseAutosaveLeaf(slug:match("([^/]+)$") or slug)
		out[#out + 1] = {
			slug = p.slug,
			folder = "",
			name = p.name,
			size_x = p.size_x,
			size_z = p.size_z,
			created = p.created,
			modified = p.modified,
			format_version = p.format_version,
			autosave = true,
			autosave_of = type(manifest.autosave_of) == "string" and manifest.autosave_of or "",
			autosave_base = base or p.name,
			autosave_stamp = stamp or 0,
		}
	end
	for _, d in ipairs(VFS.SubDirs(PROJECTS_DIR .. AUTOSAVE_DIR .. "/", "*", VFS.RAW) or {}) do
		local seg = d:match("([^/\\]+)[/\\]*$")
		if seg and validateSlug(AUTOSAVE_DIR .. "/" .. seg) then
			take(AUTOSAVE_DIR .. "/" .. seg)
		end
	end
	for _, slug in ipairs(autosaveJournal) do
		take(slug)
	end
	table.sort(out, function(a, b)
		if a.autosave_stamp ~= b.autosave_stamp then
			return a.autosave_stamp > b.autosave_stamp
		end
		return a.slug < b.slug
	end)
	return out
end

-- Which snapshots to delete: older than keepDays, except the newest of each
-- project, which lives keepLatestDays. Pure, so the spec can pin it down.
local function autosavePrunePlan(entries, now, keepDays, keepLatestDays)
	---@type table<string, number>
	local newestStamp = {}
	---@type table<string, string>
	local newestSlug = {}
	for _, e in ipairs(entries) do
		local base = tostring(e.autosave_base or "")
		local stamp = tonumber(e.autosave_stamp) or 0
		if stamp >= (newestStamp[base] or 0) then
			newestStamp[base] = stamp
			newestSlug[base] = e.slug
		end
	end
	local doomed = {}
	for _, e in ipairs(entries) do
		local base = tostring(e.autosave_base or "")
		local limit = (newestSlug[base] == e.slug) and keepLatestDays or keepDays
		if now - (tonumber(e.autosave_stamp) or 0) > limit * 86400 then
			doomed[#doomed + 1] = e.slug
		end
	end
	return doomed
end

-- Deletes what the plan says, through deleteProject's guards. Never the
-- snapshot this session was opened from, never while a save or load runs.
local function pruneAutosaves()
	local busy = job ~= nil or loadJob ~= nil or (mapLibrary ~= nil and mapLibrary.isBusy())
	if busy then
		return false
	end
	local doomed = autosavePrunePlan(listAutosaves(), os.time(), autosaveCfg.keepDays, autosaveCfg.keepLatestDays)
	local removed = 0
	for _, slug in ipairs(doomed) do
		if slug ~= autosaveLoadedSlug and deleteProject(slug) then
			removed = removed + 1
		end
	end
	if removed > 0 then
		echoP(string.format("autosave: removed %d old snapshot(s)", removed))
	end
	return true
end

-- The name a snapshot carries: the open project's leaf, else the map's name.
local function autosaveBaseName()
	local leaf = currentSlug and currentSlug:match("([^/]+)$") or nil
	if leaf and leaf ~= "" then
		return leaf
	end
	local name = tostring(Game.mapName or "map"):gsub("[^%w_%- ]", "_"):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		return "map"
	end
	return name
end

-- One snapshot now. force skips the unsaved-changes check (the console
-- action); the timer never does.
local function autosaveNow(force)
	local busy = job ~= nil or loadJob ~= nil or (mapLibrary ~= nil and mapLibrary.isBusy())
	if busy then
		return false, "busy"
	end
	if not force and dirtyCount <= autosaveDirtyMark then
		return false, "no unsaved changes"
	end
	local slug = AUTOSAVE_DIR .. "/" .. autosaveBaseName() .. "-" .. os.date("%Y%m%d%H%M")
	if projectExists(slug) then
		return false, "a snapshot for this minute exists"
	end
	local withUnits = currentSlug ~= nil and projectHasUnits(currentSlug)
	local ok = startSave(slug, { autosave = true, saveUnits = withUnits })
	if not ok then
		return false, "save refused"
	end
	autosaveDirtyMark = dirtyCount
	return true
end

-- The timer. The sweep runs whatever the switch says (retention is a setting
-- too); a snapshot only in an editor session with something to snapshot (a
-- project this session opened or saved, or a New Map canvas), never a normal
-- game, never mid-stroke, never while a save or load runs.
local function autosaveTick()
	local now = os.clock()
	if autosavePruneAt > 0 and now >= autosavePruneAt then
		-- Half an hour between sweeps; a minute when one could not run (a save
		-- or load was in flight), so the startup sweep is not lost to the load.
		autosavePruneAt = now + (pruneAutosaves() and 1800 or 60)
	end
	if not autosaveCfg.enabled or now < autosaveNextAt then
		return
	end
	---@type table?
	local ui = WG.TerraformBrushUI
	local mo = Spring.GetMapOptions() or {}
	local canvas = (mo.blank_map_x or mo.blank_map_y) and true or false
	if not ui or not (currentSlug or canvas) or Spring.GetGameFrame() <= 0 then
		autosaveNextAt = now + 30
		return
	end
	local _, _, lmb, _, rmb = Spring.GetMouseState()
	if lmb or rmb then
		autosaveNextAt = now + 5
		return
	end
	local ok = autosaveNow(false)
	-- Nothing to snapshot yet: look again soon, so the first edit after a
	-- pause is covered within the minute rather than a whole interval later.
	autosaveNextAt = now + (ok and autosaveCfg.minutes * 60 or 30)
end

local function writePointer(t)
	Spring.CreateDir("Terraform Brush")
	local content = string.format(
		"return { path = %q, size_x = %d, size_z = %d, phase = %d, phases = %d }\n",
		t.path,
		t.size_x,
		t.size_z,
		t.phase or 0,
		t.phases or 0
	)
	return writeFile(POINTER_PATH, content) ~= nil
end

-- Counts clients rather than team-attached players: a map editor session runs with no teams
-- at all, so its lone spectator counts as zero. api_permissions gates the same way.
local function isLocalSession()
	local count = BAR.Utilities and BAR.Utilities.GetPlayerCount and BAR.Utilities.GetPlayerCount()

	return count == nil or count <= 1
end

local function readPointer()
	local f = io.open(POINTER_PATH, "r")
	if not f then
		return nil
	end
	local raw = f:read("*a")
	f:close()
	if not raw or raw == "" then
		return nil
	end
	local chunk = loadstring(raw)
	if not chunk then
		return nil
	end
	local ok, t = pcall(chunk)
	if ok and type(t) == "table" and type(t.path) == "string" then
		return t
	end
	return nil
end

local function deletePointer()
	os.remove(POINTER_PATH)
end

----------------------------------------------------------------
-- Load: manifest validation
----------------------------------------------------------------

local function validateManifest(manifest)
	if type(manifest) ~= "table" then
		return nil, "manifest is not a table"
	end
	if manifest.kind ~= "bar-map-project" then
		return nil, "not a map project (kind=" .. tostring(manifest.kind) .. ")"
	end
	local fv = tonumber(manifest.format_version)
	if not fv then
		return nil, "manifest has no format_version"
	end
	if fv > FORMAT_VERSION then
		return nil,
			string.format(
				"project format_version %d is NEWER than this tool understands (%d) — update the game before opening it (re-saving with an older tool would silently lose data)",
				fv,
				FORMAT_VERSION
			)
	end
	local m = manifest.map
	if type(m) ~= "table" then
		return nil, "manifest has no map block"
	end
	local sx, sz = tonumber(m.size_x), tonumber(m.size_z)
	if not sx or not sz then
		return nil, "manifest has no map size"
	end
	if sx < 2 or sx > 64 or sz < 2 or sz > 64 or sx % 2 ~= 0 or sz % 2 ~= 0 then
		return nil,
			string.format(
				"implausible map size %sx%s (need even map units in 2..64)",
				tostring(m.size_x),
				tostring(m.size_z)
			)
	end
	if type(manifest.sections) ~= "table" then
		return nil, "manifest has no sections table"
	end
	-- The format is git-managed and hand-editable: type-check every section
	-- entry (and normalize bytes to a number) so a merge artifact fails with a
	-- clean refusal instead of a raw Lua error mid-open.
	for name, sec in pairs(manifest.sections) do
		if type(sec) ~= "table" then
			return nil, "section '" .. tostring(name) .. "' is not a table"
		end
		if sec.file ~= nil and type(sec.file) ~= "string" then
			return nil, "section '" .. tostring(name) .. "' has a non-string file"
		end
		sec.bytes = tonumber(sec.bytes)
	end
	return true
end

----------------------------------------------------------------
-- Load: phase machinery
----------------------------------------------------------------

local function loadOk(name, detail)
	loadJob.loaded[#loadJob.loaded + 1] = { name = name, detail = detail }
	echoP("loaded " .. name .. (detail and (" (" .. detail .. ")") or ""))
end

local function loadSkip(name, reason)
	loadJob.skipped[#loadJob.skipped + 1] = { name = name, reason = reason }
	echoP("SKIPPED " .. name .. ": " .. reason)
end

-- Resolve a section to its on-disk file. Absent from the manifest => nil,nil
-- (section legitimately empty — silent). Listed but missing on disk => loud
-- skip, ONCE (multi-tick phases re-poll every tick). Byte mismatch => warn,
-- load best-effort (incomplete-save policy).
local function sectionFile(key)
	local sec = loadJob.manifest.sections and loadJob.manifest.sections[key]
	if not (sec and sec.file) then
		return nil
	end
	local path = loadJob.dir .. sec.file
	local size = fileSize(path)
	if not size then
		if not loadJob.missingWarned[key] then
			loadJob.missingWarned[key] = true
			loadSkip(key, "file missing: " .. sec.file)
		end
		return nil
	end
	if sec.bytes and sec.bytes > 0 and size ~= sec.bytes and not loadJob.byteWarned[key] then
		loadJob.byteWarned[key] = true
		echoP(
			string.format(
				"WARNING: %s is %d bytes but the manifest recorded %d (incomplete save?) — loading best-effort",
				sec.file,
				size,
				sec.bytes
			)
		)
	end
	return path, sec
end

-- Phase 1: heightmap. Stream via the terraform importer, then BLOCK on the
-- gadget's sim-side ack (rules param): draw frames say nothing about whether
-- the sim applied the columns, and startpos slope validation + feature ground
-- snap in later phases read the sim-fed height mirror. Pause-aware: while the
-- game frame does not advance the timeout clock does not run.
local function phaseHeightmap(c)
	local path = sectionFile("heightmap")
	if not path then
		return true
	end
	local tb = WG.TerraformBrush
	if not (tb and tb.getImportStatus) then
		loadSkip("heightmap", "terraform brush widget not loaded")
		return true
	end
	if not c.sent then
		if tb.getImportStatus() then
			return false
		end -- another import in flight; wait
		c.ackBase = Spring.GetGameRulesParam(ACK_PARAM) or 0
		c.frameAtSend = Spring.GetGameFrame()
		local range = loadJob.manifest.map and loadJob.manifest.map.height_range
		if tb.importHeightmap then
			tb.importHeightmap(path, range and range.min, range and range.max)
		else
			Spring.SendCommands("terraformimport " .. path)
		end
		c.sent = true
		c.ticks = 0
		echoP("heightmap: importing " .. path .. " ...")
		return false
	end
	c.ticks = c.ticks + 1
	local busy, colsDone, colsTotal = tb.getImportStatus()
	if busy then
		c.sawBusy = true
		c.frameAtEnd = nil
		if c.ticks % 180 == 0 and colsTotal and colsTotal > 0 then
			echoP(string.format("heightmap: %d%% streamed", math.floor(colsDone / colsTotal * 100)))
		end
		return false
	end
	local ack = Spring.GetGameRulesParam(ACK_PARAM) or 0
	if ack > c.ackBase then
		-- the tileset shader anchors gravel/plateau placement to the ground
		-- extremes; the import just replaced them wholesale, so re-snapshot
		if WG.TilesetTerrain and WG.TilesetTerrain.refreshHeightRef then
			WG.TilesetTerrain.refreshHeightRef()
		end
		-- same story for the custom heightmap-export range: it was seeded from
		-- the blank canvas, so re-seed it from the project terrain (no-op if
		-- the user hand-typed a range)
		if WG.TerraformBrush and WG.TerraformBrush.reseedExportRange then
			WG.TerraformBrush.reseedExportRange(5)
		end
		loadOk("heightmap", "sim-acknowledged")
		return true
	end
	if not c.sawBusy then
		-- Import never observed in-flight: the importer rejected the file
		-- before streaming (decode failure — its own console message says
		-- why). Only conclude that once game frames have advanced past the
		-- send, so a frozen sim can never journal a false skip.
		if c.ticks > IMPORT_START_TICKS and Spring.GetGameFrame() > (c.frameAtSend or 0) then
			loadSkip("heightmap", "import never started (see the terraform brush messages above)")
			return true
		end
		return false
	end
	local frame = Spring.GetGameFrame()
	if not c.frameAtEnd then
		c.frameAtEnd = frame
		c.ticksAtEnd = c.ticks
	end
	if frame > c.frameAtEnd + ACK_TIMEOUT_FRAMES then
		loadSkip("heightmap", "sim never acknowledged the import (was /cheat disabled mid-stream?)")
		return true
	end
	if frame == c.frameAtEnd and ((c.ticks - c.ticksAtEnd) % 300) == 299 then
		echoP("heightmap: waiting for the sim to apply the import — unpause the game to continue")
	end
	return false
end

-- Phase 2: DNTS + splat. DNTS binding comes from the start script's
-- blank_map_splat* keys plus the terraform widget's force-bind fallback; we
-- only poll for the result because splat distribution is meaningless without
-- the detail normals bound first.
local function phaseDntsSplat(c)
	local m = loadJob.manifest.map or {}
	local hasDnts = type(m.dnts) == "table"
	local splatPath = sectionFile("splat")
	if not splatPath and not hasDnts then
		return true
	end
	if hasDnts and not c.dntsChecked then
		c.ticks = (c.ticks or 0) + 1
		local info = gl.TextureInfo("$ssmf_splat_normals:0")
		if info and info.xsize and info.xsize > 0 then
			c.dntsChecked = true
			loadOk("dnts", "splat normals bound")
		elseif c.ticks > DNTS_WAIT_TICKS then
			c.dntsChecked = true
			loadSkip(
				"dnts",
				"splat normals never appeared (engine honoring blank_map_splat* keys?) — splat visuals may be missing"
			)
		else
			return false
		end
	end
	if not splatPath then
		return true
	end
	if not hasDnts and not c.noDntsWarned then
		c.noDntsWarned = true
		echoP(
			"WARNING: project has splat.png but no DNTS record — the splat data will load with no textures to modulate"
		)
	end
	local sp = WG.SplatPainter
	if not (sp and sp.loadSplats) then
		loadSkip("splat", "splat painter widget not loaded")
		return true
	end
	if not c.splatRequested then
		if not sp.loadSplats(splatPath) then
			loadSkip("splat", "load request rejected")
			return true
		end
		c.splatRequested = true
		c.splatTicks = 0
		return false
	end
	if sp.isLoadPending() then
		c.splatTicks = c.splatTicks + 1
		if c.splatTicks > SPLAT_LOAD_TIMEOUT then
			loadSkip("splat", "timed out waiting for the painter draw pump")
			return true
		end
		return false
	end
	local result = sp.getLoadResult and sp.getLoadResult()
	if result == "ok" then
		loadOk("splat", nil)
	else
		loadSkip("splat", tostring(result or "no result reported"))
	end
	return true
end

-- Phase 2b: SURFACE variant mask. Restores the tileset biome + variant slot
-- assignment from surface.lua first (the mask channels only mean something
-- against those), then blits surface.png into the painter's mask — same
-- request/poll shape as the splat phase. Soft-skips when the write-dir
-- widgets (dev_tileset_terrain / dev_surface_painter) are not loaded.
local function phaseSurface(c)
	local maskPath = sectionFile("surface")
	if not maskPath then
		return true
	end
	local sp = WG.SurfacePainter
	if not (sp and sp.loadMask) then
		loadSkip("surface", "surface painter widget not loaded")
		return true
	end
	if not c.surfMetaDone then
		c.surfMetaDone = true
		local meta = readLuaFile(loadJob.dir .. "surface.lua")
		local T = WG.TilesetTerrain
		if meta and T then
			if meta.biome and meta.biome ~= "" and T.setBiome then
				T.setBiome(meta.biome)
			end
			if sp.applySlots then
				local picks = {}
				for i = 1, MAX_SURFACE_SLOTS do
					local a = meta["slot" .. i]
					picks[i] = (a and a ~= "") and a or nil
				end
				sp.applySlots(picks)
			end
			-- per-texture INFLUENCE profiles (absent in older projects = none)
			if sp.setInfluenceTable then
				sp.setInfluenceTable(meta.influence)
			end
		elseif not T then
			echoP(
				"WARNING: surface.png present but the tileset widget is not loaded — the mask loads with no variants bound"
			)
		end
	end
	if not c.surfRequested then
		if not sp.loadMask(maskPath) then
			loadSkip("surface", "load request rejected")
			return true
		end
		c.surfRequested = true
		c.surfTicks = 0
		return false
	end
	if sp.isLoadPending() then
		c.surfTicks = c.surfTicks + 1
		if c.surfTicks > SPLAT_LOAD_TIMEOUT then
			loadSkip("surface", "timed out waiting for the painter draw pump")
			return true
		end
		return false
	end
	local result = sp.getLoadResult and sp.getLoadResult()
	if result == "ok" then
		loadOk("surface", nil)
	else
		loadSkip("surface", tostring(result or "no result reported"))
	end
	return true
end

-- Tileset tuning (tileset.lua). Runs after the surface phase because setBiome
-- resets every biome-tuned knob to the recipe and clears the slot-4 material —
-- the saved values must land on top. Apply order matters for the same reason
-- WITHIN the phase: biome and metal style both reseed knobs, so they go first
-- and the knob table is restored over them.
local function phaseTileset(c)
	local path = sectionFile("tileset")
	if not path then
		return true
	end
	local T = WG.TilesetTerrain
	if not T then
		loadSkip("tileset", "tileset widget not loaded")
		return true
	end
	if not c.cfg then
		local data, err = readLuaFile(path)
		if type(data) ~= "table" then
			loadSkip("tileset", "unreadable tileset.lua (" .. tostring(err) .. ")")
			return true
		end
		c.cfg = data
		c.ticks = 0
	end
	local d = c.cfg
	-- setSlot4Material attaches lazily from the tileset widget's DrawGenesis;
	-- give it a few ticks before applying without it
	if d.slot4_material and d.slot4_material ~= "" and not T.setSlot4Material then
		c.ticks = c.ticks + 1
		if c.ticks < 90 then
			return false
		end
	end
	if d.biome and d.biome ~= "" and T.setBiome then
		local activeKey
		if T.getActiveBiome then
			local _, _, k = T.getActiveBiome()
			activeKey = k
		end
		if activeKey ~= d.biome then
			T.setBiome(d.biome)
		end
	end
	if d.metal_style and d.metal_style ~= "" and T.setMetalStyle then
		T.setMetalStyle(d.metal_style)
	end
	if type(d.slot_tints) == "table" and T.setSlotTint then
		for a, col in pairs(d.slot_tints) do
			if type(a) == "string" and type(col) == "table" then
				T.setSlotTint(a, col[1], col[2], col[3])
			end
		end
	end
	-- HEIGHT TINT ramp image: an absent key clears any ramp left over from the
	-- previous scene, so a project without one loads clean
	if T.setRamp then
		T.setRamp((type(d.ramp) == "string") and d.ramp or "")
	end
	local applied, unknown = 0, 0
	if type(d.knobs) == "table" and T.setKnob then
		local live = T.getKnobs() or {}
		for k, v in pairs(d.knobs) do
			if type(v) == "number" then
				if T.setKnob(k, v) then
					applied = applied + 1
				elseif live[k] ~= nil then
					-- knob without a slider spec (setKnob refuses those): write it
					-- straight into the live table; its uniform reads the table
					live[k] = v
					applied = applied + 1
				else
					unknown = unknown + 1
				end
			end
		end
	end
	if d.metal_lights ~= nil and T.setMetalLights then
		T.setMetalLights(d.metal_lights)
	end
	if d.slot4_material and d.slot4_material ~= "" and T.setSlot4Material then
		T.setSlot4Material(d.slot4_material)
	end
	loadOk("tileset", applied .. " knobs" .. ((unknown > 0) and (", " .. unknown .. " unknown skipped") or ""))
	return true
end

-- Phase 3: diffuse. Per-square PNGs blitted into painter-owned seed+composite
-- textures (later paint bakes over the loaded state), channel PNGs into the
-- painter's channel textures. Files discovered by glob — the save side keeps
-- the diffuse/ dir exact.
local function phaseDiffuse(c)
	local sec = loadJob.manifest.sections and loadJob.manifest.sections.diffuse
	if not (sec and sec.dir) then
		diffuseLoadedSlug = loadJob.slug -- nothing on disk for the painter to be missing
		return true
	end
	local dp = WG.DiffusePainter
	if not (dp and dp.loadProject) then
		loadSkip("diffuse", "diffuse painter widget not loaded")
		return true
	end
	if not c.requested then
		local dir = loadJob.dir .. sec.dir
		local files = VFS.DirList(dir, "*.png", VFS.RAW) or {}
		local sqs, chans, nChans = {}, {}, 0
		for _, p in ipairs(files) do
			local name = p:match("([^/\\]+)$")
			-- NOT `name and name:match(...)`: `and` truncates a multi-return to
			-- its first value, which would silently drop sy.
			local sx, sy
			if name then
				sx, sy = name:match("^sq_(%d+)_(%d+)%.png$")
			end
			if sx and sy then
				sqs[#sqs + 1] = { sx = tonumber(sx), sy = tonumber(sy), path = dir .. name }
			else
				local key = name and name:match("^channel_(%w+)%.png$")
				if key then
					chans[key] = dir .. name
					nChans = nChans + 1
				end
			end
		end
		if #sqs == 0 and nChans == 0 then
			loadSkip("diffuse", "no PNGs found in " .. sec.dir)
			return true
		end
		table.sort(sqs, function(a, b)
			if a.sy ~= b.sy then
				return a.sy < b.sy
			end
			return a.sx < b.sx
		end)
		if not dp.loadProject(sqs, chans) then
			loadSkip("diffuse", "painter is busy")
			return true
		end
		echoP(
			string.format(
				"diffuse: loading %d squares%s...",
				#sqs,
				nChans > 0 and (" + " .. nChans .. " channel(s)") or ""
			)
		)
		c.requested = true
		c.ticks = 0
		return false
	end
	c.ticks = c.ticks + 1
	if dp.isProjectLoadPending() then
		if c.ticks > DIFFUSE_TIMEOUT_TICKS then
			loadSkip("diffuse", "timed out (painter draw pump never finished)")
			return true
		end
		return false
	end
	local res = dp.getProjectLoadResult and dp.getProjectLoadResult()
	if not res or res.error or ((res.loaded or 0) == 0 and (res.channels or 0) == 0) then
		loadSkip("diffuse", (res and (res.error or ((res.failed or 0) .. " square(s) failed"))) or "no result reported")
	else
		diffuseLoadedSlug = loadJob.slug
		loadOk(
			"diffuse",
			(res.loaded or 0)
				.. " squares"
				.. ((res.channels or 0) > 0 and (", " .. res.channels .. " channel(s)") or "")
		)
		if (res.failed or 0) > 0 then
			echoP("WARNING: " .. res.failed .. " diffuse square(s) failed to load")
		end
	end
	return true
end

-- Phase 4: metal. Direct $metal_clear$/$metal_load$ batching (mirrors the
-- save side: no dependency on the metal brush widget being enabled).
local function phaseMetal(c)
	local path = sectionFile("metal")
	if not path then
		return true
	end
	if not c.spots then
		local data, err = readLuaFile(path)
		if not (data and type(data.spots) == "table") then
			loadSkip("metal", "unreadable metal.lua (" .. tostring(err) .. ")")
			return true
		end
		c.spots = data.spots
		c.i = 1
		Spring.SendLuaRulesMsg("$metal_clear$")
		return false
	end
	local parts = {}
	local format = string.format
	local processed = 0
	while c.i <= #c.spots and processed < 400 do
		local s = c.spots[c.i]
		if s.mx and s.mz and s.amount then
			parts[#parts + 1] = s.mx
			parts[#parts + 1] = s.mz
			parts[#parts + 1] = format("%.3f", s.amount)
			if #parts >= 300 then
				Spring.SendLuaRulesMsg("$metal_load$" .. table.concat(parts, " "))
				parts = {}
			end
		end
		c.i = c.i + 1
		processed = processed + 1
	end
	if #parts > 0 then
		Spring.SendLuaRulesMsg("$metal_load$" .. table.concat(parts, " "))
	end
	if c.i > #c.spots then
		loadOk("metal", #c.spots .. " spots")
		return true
	end
	return false
end

-- Phase 5: features. Clear-all first so a resumed replay cannot duplicate.
local function phaseFeatures(c)
	local path = sectionFile("features")
	if not path then
		return true
	end
	local fp = WG.FeaturePlacer
	if not (fp and fp.load) then
		loadSkip("features", "feature placer widget not loaded")
		return true
	end
	Spring.SendLuaRulesMsg("$feature_clearall$")
	fp.load(path)
	loadOk("features", "replaying (applies over the next frames)")
	return true
end

-- Phase 6: units. Streamed to the units gadget, which replaces the map's
-- units atomically (spawn saved loadout, then remove pre-existing units —
-- including the session's freshly spawned commanders, which the saved loadout
-- itself contains from save time). Runs after the sim-acked heightmap so
-- ground snap uses final heights. Completion is a rules-param ack, pause-aware
-- like the heightmap phase.
local function phaseUnits(c)
	local path = sectionFile("units")
	if not path then
		return true
	end
	if not c.sent then
		local data, err = readLuaFile(path)
		if not (data and type(data.units) == "table") then
			loadSkip("units", "unreadable units.lua (" .. tostring(err) .. ")")
			return true
		end
		-- Build every batch BEFORE sending anything: an all-invalid file must not
		-- leave the gadget with a dangling begin. All messages go out in one tick
		-- so the sim applies the whole replace in a single frame.
		local batches, parts = {}, {}
		local format = string.format
		local count = 0
		for _, u in ipairs(data.units) do
			local x, z = tonumber(u.x), tonumber(u.z)
			if type(u.name) == "string" and x and z then
				count = count + 1
				parts[#parts + 1] = format(
					"%s %.1f %.1f %d %d %d",
					u.name,
					x,
					z,
					tonumber(u.rot) or 0,
					tonumber(u.team) or 0,
					u.neutral and 1 or 0
				)
				if #parts >= 25 then
					batches[#batches + 1] = table.concat(parts, "|")
					parts = {}
				end
			end
		end
		if #parts > 0 then
			batches[#batches + 1] = table.concat(parts, "|")
		end
		if #batches == 0 then
			loadSkip("units", "no valid entries in units.lua")
			return true
		end
		Spring.SendLuaRulesMsg("$mpunits_begin$")
		for _, b in ipairs(batches) do
			Spring.SendLuaRulesMsg("$mpunits_data$" .. b)
		end
		Spring.SendLuaRulesMsg("$mpunits_end$")
		c.sent = true
		c.count = count
		c.ackBase = Spring.GetGameRulesParam(UNITS_ACK_PARAM) or 0
		c.frameAtSend = Spring.GetGameFrame()
		c.ticks = 0
		echoP("units: replaying " .. count .. " units...")
		return false
	end
	local ack = Spring.GetGameRulesParam(UNITS_ACK_PARAM) or 0
	if ack > c.ackBase then
		local spawned = Spring.GetGameRulesParam("mpu_spawned") or 0
		local failed = Spring.GetGameRulesParam("mpu_failed") or 0
		local remapped = Spring.GetGameRulesParam("mpu_remapped") or 0
		loadOk(
			"units",
			spawned
				.. " spawned"
				.. (failed > 0 and (", " .. failed .. " FAILED (unknown def or unit limit)") or "")
				.. (remapped > 0 and (", " .. remapped .. " remapped to Gaia (team missing/dead)") or "")
		)
		return true
	end
	c.ticks = c.ticks + 1
	local frame = Spring.GetGameFrame()
	if frame > c.frameAtSend + ACK_TIMEOUT_FRAMES then
		loadSkip("units", "sim never acknowledged the loadout (was /cheat disabled mid-load?)")
		return true
	end
	if frame == c.frameAtSend and (c.ticks % 300) == 299 then
		echoP("units: waiting for the sim to apply the loadout — unpause the game to continue")
	end
	return false
end

-- Phase 7: decals + lights + map labels (client-side; all three need the final
-- heights — light Y and label dots are both projected onto the loaded terrain).
local function phaseDecalsLights(c)
	local decalPath = sectionFile("decals")
	if decalPath then
		local dp = WG.DecalPlacer
		if dp and dp.load then
			for _, a in ipairs((loadJob.manifest.assets and loadJob.manifest.assets.decals) or {}) do
				if a.name and not VFS.FileExists("bitmaps/decals/" .. a.name .. ".png", VFS.MOD) then
					echoP(
						"WARNING: decal capture '"
							.. a.name
							.. "' is not installed in the game archive — copy "
							.. loadJob.dir
							.. tostring(a.file)
							.. " into bitmaps/decals/ and restart to see it"
					)
				end
			end
			if dp.clearAll then
				dp.clearAll()
			end
			dp.load(decalPath)
			loadOk("decals", nil)
		else
			loadSkip("decals", "decal placer widget not loaded")
		end
	end
	local lightPath = sectionFile("lights")
	if lightPath then
		local lp = WG.LightPlacer
		if lp and lp.load then
			if lp.load(lightPath) then
				loadOk("lights", nil)
			else
				loadSkip("lights", "light placer rejected the file")
			end
		else
			loadSkip("lights", "light placer widget not loaded")
		end
	end
	local labelPath = sectionFile("labels")
	local ml = WG.MapLabels
	if labelPath then
		if ml and ml.loadProject then
			local ok, n = ml.loadProject(labelPath)
			if ok then
				loadOk("labels", (n or 0) .. " comments")
			else
				loadSkip("labels", "map labels widget rejected the file")
			end
		else
			loadSkip("labels", "map labels widget not loaded")
		end
	elseif ml and ml.clearProject then
		-- No labels section: this project has no comments. The live set is keyed
		-- by map name, which generated canvases share, so clear it rather than
		-- letting the previously opened project's comments show up here.
		local hasSection = loadJob.manifest.sections and loadJob.manifest.sections.labels
		if not hasSection then
			ml.clearProject()
		end
	end
	return true
end

-- Phase 8: environment. Short settle countdown mirrors the New Map env-preset
-- pattern (the water renderer needs a few draw frames after map changes).
local function phaseEnvironment(c)
	local path = sectionFile("environment")
	if not path then
		return true
	end
	local ui = WG.TerraformBrushUI
	if not (ui and ui.applyEnvConfig) then
		loadSkip("environment", "terraform UI widget not loaded")
		return true
	end
	if not c.cfg then
		local data, err = readLuaFile(path)
		if type(data) ~= "table" then
			loadSkip("environment", "unreadable environment.lua (" .. tostring(err) .. ")")
			return true
		end
		c.cfg = data
		c.countdown = 15
		return false
	end
	c.countdown = c.countdown - 1
	if c.countdown > 0 then
		return false
	end
	ui.applyEnvConfig(c.cfg)
	loadOk("environment", nil)
	return true
end

-- Phase 9: weather. Clear persistent spawners first (idempotent replay), then
-- rebuild each from its serialized entry with rebased timing.
local function phaseWeather(c)
	local path = sectionFile("weather")
	if not path then
		return true
	end
	local wb = WG.WeatherBrush
	if not (wb and wb.addSpawnerRaw) then
		loadSkip("weather", "weather brush widget not loaded (or too old — needs addSpawnerRaw)")
		return true
	end
	local data, err = readLuaFile(path)
	if not (data and type(data.spawners) == "table") then
		loadSkip("weather", "unreadable weather.lua (" .. tostring(err) .. ")")
		return true
	end
	if wb.clearAllPersistent then
		wb.clearAllPersistent()
	end
	local added = 0
	for _, s in ipairs(data.spawners) do
		if wb.addSpawnerRaw(s) then
			added = added + 1
		end
	end
	loadOk("weather", added .. " of " .. #data.spawners .. " spawners")
	return true
end

-- Phase 10: startpos + startboxes + grass (all need sim-acked terrain: slope
-- validation and patch ground-snap read final heights).
local function phaseStartposGrass(c)
	local st = WG.StartPosTool
	local posPath = sectionFile("startpos")
	if posPath then
		if st and st.loadStartPositions then
			if st.loadStartPositions(nil, posPath) then
				loadOk("startpos", nil)
			else
				loadSkip("startpos", "startpos tool rejected the file")
			end
		else
			loadSkip("startpos", "startpos tool widget not loaded")
		end
	end
	local boxPath = sectionFile("startboxes")
	if boxPath then
		if st and st.loadStartboxes then
			if st.loadStartboxes(nil, boxPath) then
				loadOk("startboxes", nil)
			else
				loadSkip("startboxes", "startpos tool rejected the file")
			end
		else
			loadSkip("startboxes", "startpos tool widget not loaded")
		end
	end
	local grassPath, grassSec = sectionFile("grass")
	if grassPath then
		local api = WG.grassgl4
		if not (api and api.loadGrass) then
			loadSkip("grass", "grass widget not loaded")
		else
			local cfg = (api.getConfig and api.getConfig()) or {}
			local sessionRes = tonumber(cfg.patchResolution) or 32
			local savedRes = tonumber(grassSec and grassSec.patch_resolution)
			local tw, th = readTGADims(grassPath)
			local ew = math.floor(Game.mapSizeX / sessionRes)
			local eh = math.floor(Game.mapSizeZ / sessionRes)
			if savedRes and savedRes ~= sessionRes then
				loadSkip(
					"grass",
					string.format(
						"patch resolution mismatch (project %d, session %d) — a mismatched grid would misplace every patch",
						savedRes,
						sessionRes
					)
				)
			elseif not tw then
				loadSkip("grass", "cannot read grass_dist.tga header")
			elseif tw ~= ew or th ~= eh then
				loadSkip("grass", string.format("grass grid is %dx%d but this map needs %dx%d", tw, th, ew, eh))
			else
				-- loadGrass side effect: it enters grass dev placement mode,
				-- whose MousePress swallows EVERY world click (no commander
				-- placement, no terraform). Restore the prior mode.
				local wasEdit = api.isEditMode and api.isEditMode() or false
				api.loadGrass(grassPath)
				if not wasEdit and api.disableEditMode then
					api.disableEditMode()
				end
				loadOk("grass", tw .. "x" .. th .. " patches grid")
			end
		end
	end
	return true
end

local LOAD_PHASES = {
	{ name = "heightmap", run = phaseHeightmap },
	{ name = "dnts+splat", run = phaseDntsSplat },
	{ name = "surface", run = phaseSurface },
	{ name = "tileset", run = phaseTileset },
	{ name = "diffuse", run = phaseDiffuse },
	{ name = "metal", run = phaseMetal },
	{ name = "features", run = phaseFeatures },
	{ name = "units", run = phaseUnits },
	{ name = "decals+lights", run = phaseDecalsLights }, -- also map labels
	{ name = "environment", run = phaseEnvironment },
	{ name = "weather", run = phaseWeather },
	{ name = "startpos+grass", run = phaseStartposGrass },
}

local function finishLoad()
	echoP("PROJECT LOAD COMPLETE: '" .. loadJob.slug .. "'")
	for _, s in ipairs(loadJob.loaded) do
		echoP(string.format("  %-12s %s", s.name, s.detail or "ok"))
	end
	for _, s in ipairs(loadJob.skipped) do
		echoP(string.format("  %-12s SKIPPED: %s", s.name, s.reason))
	end
	if #loadJob.skipped > 0 then
		echoP(#loadJob.skipped .. " section(s) skipped — reasons above")
	end
	deletePointer()
	-- What was loaded from a snapshot differs from the project it belongs to
	-- until it is saved back, so the session starts out with changes; the
	-- timer waits for an edit on top of that before taking the next snapshot.
	local fromAutosave = loadJob.autosaveOf ~= nil
	loadJob = nil
	dirtyCount = fromAutosave and 1 or 0
	autosaveDirtyMark = dirtyCount
	dirtyGraceUntil = os.clock() + 8
	autosaveNextAt = os.clock() + (tonumber(autosaveCfg.minutes) or 10) * 60

	-- Leave pregame, or the whole map is unclickable above the canvas base height.
	--
	-- The engine clips every ground ray at readMap->GetCurrMaxHeight()
	-- (CGround::LineGroundCol -> ClampInMapHeight). That bound is only refreshed
	-- from CReadMap::Update(), which runs per SIM FRAME — and the entire project
	-- load happens in pregame at f=-1, where no sim frames run. So the bound
	-- stays at the blank canvas's flat base height while the imported terrain
	-- towers above it: clicks over anything higher find no ground at all, which
	-- kills commander placement AND every editor tool that traces the cursor.
	-- The engine fixes the bound itself the moment pregame ends — CGame does a
	-- full UpdateHeightBounds() with the comment "needed in case pre-game
	-- terraform changed the map" — so starting the game is the cure.
	if Spring.GetGameFrame() <= 0 then
		echoP(
			"starting the game: terrain taller than the canvas base is unclickable in pregame (engine clips ground rays at the last known max height, which only updates once sim frames run)"
		)
		Spring.SendCommands("forcestart")
	end

	-- A loaded project is there to be edited: bring the Terraformer up
	-- (requested by PtaQ 2026-09-04). The panel widget owns the how.
	---@type table?
	local ui = WG.TerraformBrushUI
	if ui and ui.openEditor then
		ui.openEditor()
	end
end

local function abortLoad(reason)
	echoP("PROJECT LOAD ABORTED: " .. reason)
	deletePointer()
	loadJob = nil
end

-- One pump tick. The cheat gate is a PRECONDITION, not a journaled phase: the
-- synced gadgets ($terraform_import$, $metal_load$, $feature_load$) all require
-- live cheat outside map-editor sessions (where a $c$-certified message is
-- accepted instead), and cheat resets across engine restart AND can be toggled
-- off by the user mid-load, so it is re-verified on every tick. "cheat"
-- TOGGLES — only (re)send while observed OFF, with a generous gap so an
-- in-flight send cannot be doubled.
local function runLoadTick()
	if not Spring.IsCheatingEnabled() then
		local c = loadJob
		c.cheatTicks = (c.cheatTicks or 0) + 1
		if not c.cheatLastSend or (c.cheatTicks - c.cheatLastSend) >= CHEAT_RESEND_TICKS then
			if (c.cheatSends or 0) + 1 > CHEAT_MAX_SENDS then
				abortLoad(
					"could not enable /cheat (required for terrain/metal/feature replay); enable cheats and open the project again"
				)
				return
			end
			-- Route through the terraform widget's shared single-flight window
			-- when it is loaded: "cheat" TOGGLES, so a send of ours landing on
			-- top of one another editor widget already has in flight turns cheat
			-- back OFF. Only count the attempt when a toggle really went out.
			local sent = true
			if type(WG.TerraformEnsureCheat) == "function" then
				sent = WG.TerraformEnsureCheat() and true or false
			else
				Spring.SendCommands("cheat")
			end
			if sent then
				c.cheatSends = (c.cheatSends or 0) + 1
				c.cheatLastSend = c.cheatTicks
				echoP("enabling /cheat for the load (attempt " .. c.cheatSends .. ")...")
			end
		end
		return
	end
	loadJob.cheatTicks, loadJob.cheatLastSend, loadJob.cheatSends = nil, nil, nil

	local phaseIdx = loadJob.phase + 1
	local phase = LOAD_PHASES[phaseIdx]
	if not phase then
		finishLoad()
		return
	end
	if not loadJob.announced then
		loadJob.announced = true
		echoP(string.format("phase %d/%d: %s", phaseIdx, #LOAD_PHASES, phase.name))
	end
	local ok, done = pcall(phase.run, loadJob.cursor)
	if not ok then
		echoP("ERROR in load phase '" .. phase.name .. "': " .. tostring(done))
		loadSkip(phase.name, "error: " .. tostring(done))
		done = true
	end
	if done then
		loadJob.phase = phaseIdx
		loadJob.cursor = {}
		loadJob.announced = nil
		-- Journal progress so /luaui reload mid-load resumes here.
		writePointer({
			path = loadJob.dir,
			size_x = loadJob.sizeX,
			size_z = loadJob.sizeZ,
			phase = loadJob.phase,
			phases = #LOAD_PHASES,
		})
		if not LOAD_PHASES[loadJob.phase + 1] then
			finishLoad()
		end
	end
end

-- Consume the pointer at widget init — but ONLY when this session actually is
-- the blank map the restart was supposed to produce. Anything else (restart
-- failed, user aborted, joined a multiplayer game, plain /luaui reload on an
-- unrelated map) deletes the pointer with a loud explanation and touches
-- nothing (critique blocker: a stale pointer must never replay onto the wrong
-- session, and must not survive to ambush a future matching one).
local function maybeStartLoad()
	local ptr = readPointer()
	if not ptr then
		return
	end
	local reasons = {}
	if
		not (
			ptr.size_x
			and ptr.size_z
			and Game.mapSizeX == ptr.size_x * ELMOS_PER_UNIT
			and Game.mapSizeZ == ptr.size_z * ELMOS_PER_UNIT
		)
	then
		reasons[#reasons + 1] = string.format(
			"map size is %dx%d units, pointer wants %sx%s",
			Game.mapSizeX / ELMOS_PER_UNIT,
			Game.mapSizeZ / ELMOS_PER_UNIT,
			tostring(ptr.size_x),
			tostring(ptr.size_z)
		)
	end
	-- Project restarts auto-name their canvas "Editor Flat ...", but accept any
	-- blank-generated map (mapoptions gate) so wizard-named canvases don't trip
	-- a false session mismatch.
	local mo = Spring.GetMapOptions()
	local isBlankCanvas = type(mo) == "table"
		and ((tonumber(mo.blank_map_x) or 0) > 0 or (tonumber(mo.blank_map_y) or 0) > 0)
	if not (isBlankCanvas or (Game.mapName or ""):match("^Editor Flat %d+x%d+")) then
		reasons[#reasons + 1] = "map is '" .. tostring(Game.mapName) .. "', not an editor blank map"
	end
	if Game.mapDamage == false then
		reasons[#reasons + 1] = "map damage is disabled (terrain cannot be replayed)"
	end
	if Spring.IsReplay() then
		reasons[#reasons + 1] = "this is a replay"
	end
	if not isLocalSession() then
		reasons[#reasons + 1] = "not a local singleplayer session"
	end
	if #reasons > 0 then
		deletePointer()
		echoP(
			"PENDING PROJECT LOAD CANCELLED — session mismatch: "
				.. table.concat(reasons, "; ")
				.. ". Pointer removed; open the project again from the FILE menu."
		)
		return
	end
	local manifest = readPrevManifest(ptr.path)
	if not manifest then
		deletePointer()
		echoP("PENDING PROJECT LOAD CANCELLED: cannot read " .. ptr.path .. "project.lua. Pointer removed.")
		return
	end
	local vok, verr = validateManifest(manifest)
	if not vok then
		deletePointer()
		echoP("PENDING PROJECT LOAD CANCELLED: " .. verr .. ". Pointer removed.")
		return
	end
	-- A journal written by a different code version counts phases on a different
	-- list; resuming would silently skip the wrong ones. Phases are idempotent,
	-- so restart from the beginning instead.
	local startPhase = tonumber(ptr.phase) or 0
	if startPhase > 0 and tonumber(ptr.phases) ~= #LOAD_PHASES then
		echoP("phase journal was written by a different version; restarting the load from the beginning")
		startPhase = 0
	end
	-- The pointer's path is PROJECTS_DIR .. slug .. "/". Take the slug back out
	-- WHOLE: keeping only the leaf turned "Other/CM01Draft1" into "CM01Draft1",
	-- so the next FILE > Save wrote a new root project and the OPEN badge never
	-- found its row.
	local pointerSlug = tostring(ptr.path):gsub("\\", "/"):gsub("/+$", "")
	if pointerSlug:sub(1, #PROJECTS_DIR) == PROJECTS_DIR then
		pointerSlug = pointerSlug:sub(#PROJECTS_DIR + 1)
	end
	pointerSlug = validateSlug(pointerSlug) or pointerSlug:match("([^/]+)$") or pointerSlug
	loadJob = {
		slug = pointerSlug,
		dir = ptr.path,
		sizeX = ptr.size_x,
		sizeZ = ptr.size_z,
		manifest = manifest,
		phase = startPhase,
		cursor = {},
		loaded = {},
		skipped = {},
		byteWarned = {},
		missingWarned = {},
	}
	currentSlug = loadJob.slug
	-- A snapshot opens as the project it was taken from: FILE > Save writes
	-- back to that project, the snapshot itself is never a Save target, and
	-- the sweep spares it while it is the session's origin. A snapshot of a
	-- canvas that had no project ("") leaves Save asking for a name.
	if type(manifest.autosave_of) == "string" then
		autosaveLoadedSlug = loadJob.slug
		local origin = validateSlug(manifest.autosave_of)
		loadJob.autosaveOf = origin or ""
		currentSlug = origin
		echoP(
			origin and ("this is an autosave of '" .. origin .. "': FILE > Save writes there")
				or "this is an autosave of an unsaved canvas: FILE > Save asks for a name"
		)
	end
	if loadJob.phase > 0 then
		echoP(string.format("resuming project load '%s' at phase %d/%d", loadJob.slug, loadJob.phase + 1, #LOAD_PHASES))
	else
		echoP(string.format("loading project '%s' (%d phases)...", loadJob.slug, #LOAD_PHASES))
	end
end

----------------------------------------------------------------
-- Load: open (validate + restart), callable from UI and console
----------------------------------------------------------------

local function openProject(slug)
	if mapLibrary and mapLibrary.isBusy() then
		echoP("cannot open while the map library is transferring a project")
		return false
	end
	if job then
		echoP("cannot open a project while a save is running")
		return false
	end
	if loadJob then
		echoP("cannot open a project while a load is running")
		return false
	end
	local ok, err = validateSlug(slug)
	if not ok then
		echoP("cannot open: " .. err)
		return false
	end
	slug = ok
	if not isLocalSession() then
		echoP("cannot open: project loading needs a local singleplayer session")
		return false
	end
	local dir = PROJECTS_DIR .. slug .. "/"
	local manifest = readPrevManifest(dir)
	if not manifest then
		echoP("cannot open '" .. slug .. "': no readable project.lua in " .. dir)
		return false
	end
	local vok, verr = validateManifest(manifest)
	if not vok then
		echoP("cannot open '" .. slug .. "': " .. verr)
		return false
	end
	local ui = WG.TerraformBrushUI
	if not (ui and ui.buildProjectStartScript) then
		echoP("cannot open: the Terraform Brush UI widget is required (it builds the blank-map start script)")
		return false
	end
	local script, serr = ui.buildProjectStartScript(manifest, slug)
	if not script then
		echoP("cannot open '" .. slug .. "': " .. tostring(serr))
		return false
	end
	-- Cheap pre-restart integrity report (sections load best-effort regardless).
	for name, sec in pairs(manifest.sections) do
		if sec.file then
			local size = fileSize(dir .. sec.file)
			if size == nil then
				echoP("WARNING: section '" .. name .. "' file is missing (" .. sec.file .. ") — it will be skipped")
			elseif sec.bytes and sec.bytes > 0 and size ~= sec.bytes then
				echoP("WARNING: section '" .. name .. "' size differs from the manifest (incomplete save?)")
			end
		end
	end
	-- Stale New Map recipes must not fire on the fresh session. REMOVE the
	-- files rather than blanking them: the terraform UI reads an EXISTING but
	-- empty pending_newmap_env.lua as "New Map with Default environment" and
	-- would stomp the project's baked skybox with the first library one.
	Spring.CreateDir("Terraform Brush")
	os.remove("Terraform Brush/pending_newmap.lua")
	os.remove("Terraform Brush/pending_newmap_env.lua")
	local m = manifest.map
	if not writePointer({ path = dir, size_x = m.size_x, size_z = m.size_z, phase = 0, phases = #LOAD_PHASES }) then
		echoP("cannot open: failed to write " .. POINTER_PATH)
		return false
	end
	echoP(string.format("restarting into a blank %dx%d map for project '%s'...", m.size_x, m.size_z, slug))
	touchRecent(slug)
	Spring.Restart("", script)
	return true
end

-- Job driver. DrawScreenPost, NOT DrawScreen: the widget handler skips
-- DrawScreen while the interface is hidden and the Terraformer's FOCUS MODE
-- hides it on purpose, so a Save / Open started there would sit until the HUD
-- came back. Nothing here grabs the screen (the thumbnail step renders to its
-- own FBO), so running after the UI pass changes nothing.
function widget:DrawScreenPost()
	if unitsWaiter then
		pollUnitsWaiter()
	end
	if loadJob then
		runLoadTick()
	end
	if not job then
		return
	end
	local step = STEPS[job.step]
	if not step then
		finishSave()
		return
	end
	local ok, done = pcall(step.run)
	if not ok then
		echoP("ERROR in step '" .. step.name .. "': " .. tostring(done))
		if step.name == "manifest" then
			job.failed = "manifest step errored: " .. tostring(done)
		else
			sectionSkip(step.name, "error: " .. tostring(done), true)
		end
		done = true
	end
	if done then
		job.step = job.step + 1
		job.cursor = {}
		if not STEPS[job.step] then
			finishSave()
		end
	end
end

----------------------------------------------------------------
-- Widget interface
----------------------------------------------------------------

local function mapProjectAction(_, optLine, params)
	local sub = params and params[1]
	if sub == "save" then
		startSave(params[2], { saveUnits = params[3] == "units" })
	elseif sub == "open" then
		openProject(params[2])
	elseif sub == "list" then
		listProjects()
	elseif sub == "delete" then
		deleteProject(params[2])
	elseif sub == "autosave" then
		local ok, why = autosaveNow(true)
		if not ok then
			echoP("autosave not started: " .. tostring(why))
		end
	elseif sub == "prune" then
		pruneAutosaves()
	elseif sub == "dirty" then
		-- Marks the session as having unsaved changes, for exercising the guards
		-- (the quit popup, Open's confirm, the autosave timer) without an edit.
		dirtyCount = dirtyCount + 1
		echoP("session marked as changed (unsaved changes: " .. dirtyCount .. ")")
	else
		echoP(
			"usage: /mapproject save <name> [units]  |  /mapproject open <name>  |  /mapproject list  |  /mapproject delete <name>  |  /mapproject autosave  |  /mapproject prune  |  /mapproject dirty"
		)
	end
end

function widget:Initialize()
	mapLibrary = VFS.Include("luaui/Include/map_library.lua").new({
		validateSlug = validateSlug,
		downloaded = touchRecent,
		isProjectBusy = function()
			return job ~= nil or loadJob ~= nil
		end,
	})
	widgetHandler:AddAction("mapproject", mapProjectAction, nil, "t")
	-- A fresh session's opening heightmap updates are not edits.
	dirtyGraceUntil = os.clock() + 8
	configureAutosave({})
	-- The first sweep of old snapshots a minute in, then every half hour.
	autosavePruneAt = os.clock() + 60
	-- Units export round-trip receivers (cmd_map_project_units.lua relays the
	-- synced walk through these; see stepUnits for why collection is synced).
	widgetHandler:RegisterGlobal("mapproject_units_save_begin", function(count)
		unitsRx = { batches = {}, expected = count, done = false }
	end)
	widgetHandler:RegisterGlobal("mapproject_units_save_data", function(payload)
		if unitsRx and type(payload) == "string" then
			unitsRx.batches[#unitsRx.batches + 1] = payload
		end
	end)
	widgetHandler:RegisterGlobal("mapproject_units_save_end", function(_count)
		if unitsRx then
			unitsRx.done = true
		end
	end)
	widgetHandler:RegisterGlobal("mapproject_units_save_denied", function(reason)
		unitsRx = { batches = {}, done = true, denied = tostring(reason or "export denied") }
	end)
	WG.MapProject = {
		library = mapLibrary,
		save = startSave,
		validateSlug = validateSlug,
		open = openProject,
		list = listProjects,
		listDetailed = listProjectsDetailed,
		-- One known slug's entry, read from its manifest rather than found by
		-- walking folders, so a project that landed this session is visible.
		describe = describeProject,
		-- { {slug, at}, ... } newest first: projects opened or saved through
		-- this widget (the journal behind the dialog's RECENT order).
		recent = readRecent,
		delete = deleteProject,
		deleteFolder = deleteFolder,
		move = moveProject,
		-- rename(slug, newLeaf) -> true, newSlug: a move within the folder,
		-- and the manifest's name follows.
		rename = renameProject,
		hasUnitsSection = projectHasUnits,
		exists = projectExists,
		-- Slug of the project this session was loaded from or last saved to
		-- (nil until one of those happens) — the FILE > Save target.
		current = function()
			return currentSlug
		end,
		-- Unsaved changes. Tools call markDirty when they change the map; the
		-- terraform UI polls the terrain version for the heightmap. Cleared by
		-- a finished save or load.
		markDirty = function(_source)
			if loadJob or job or os.clock() < dirtyGraceUntil then
				return
			end
			dirtyCount = dirtyCount + 1
		end,
		isDirty = function()
			return dirtyCount > 0
		end,
		-- (phase, total, phaseName) of the running load, nil when idle: the
		-- status strip draws a LOADING bar from it after the restart.
		loadProgress = function()
			if not loadJob then
				return nil
			end
			local index = math.min((tonumber(loadJob.phase) or 0) + 1, #LOAD_PHASES)
			local entry = LOAD_PHASES[index] or {}
			return index, #LOAD_PHASES, entry.name or ""
		end,
		-- (step, total, stepName, kind) of the running save, nil when idle —
		-- drives the status-strip segment bar in the terraform UI; kind is
		-- "save" or "autosave", which the strip labels differently.
		saveProgress = function()
			if not job then
				return nil
			end
			local step = math.min(job.step, #STEPS)
			return step, #STEPS, STEPS[step] and STEPS[step].name or "", job.autosave and "autosave" or "save"
		end,
		-- Completed receipt {done, ok, slug, uploadReady}; same object returned by save.
		lastSave = function()
			return lastSaveInfo
		end,
		-- Autosave (Settings > General). setAutosave({enabled, minutes, keepDays,
		-- keepLatestDays}) from the panel; listAutosaves for the Projects
		-- window's Autosaves view; autosaveNow(force) is the console action; the
		-- prune plan is exposed for the spec. lastAutosave is the receipt of the
		-- newest snapshot (the manual receipt in lastSave is never an autosave).
		setAutosave = configureAutosave,
		listAutosaves = listAutosaves,
		autosaveNow = autosaveNow,
		autosavePrunePlan = autosavePrunePlan,
		lastAutosave = function()
			return lastAutosaveInfo
		end,
		-- callback(entries) on success, callback(nil, reason) on failure
		requestUnits = requestUnits,
		isBusy = function()
			return job ~= nil or loadJob ~= nil or mapLibrary.isBusy()
		end,
		isLoading = function()
			return loadJob ~= nil
		end,
	}
	maybeStartLoad()
end

function widget:Update(dt)
	if mapLibrary then
		mapLibrary.update(dt)
	end
	autosaveTick()
end

function widget:Shutdown()
	WG.MapProject = nil
	widgetHandler:RemoveAction("mapproject")
	widgetHandler:DeregisterGlobal("mapproject_units_save_begin")
	widgetHandler:DeregisterGlobal("mapproject_units_save_data")
	widgetHandler:DeregisterGlobal("mapproject_units_save_end")
	widgetHandler:DeregisterGlobal("mapproject_units_save_denied")
	if job then
		echoP("save aborted by widget shutdown — project may be incomplete (no manifest written)")
		job.result.done = true
		job.result.ok = false
		job.result.uploadReady = false
		job = nil
	end
	if loadJob then
		echoP("project load interrupted by widget shutdown — it will resume from the phase journal on reload")
		loadJob = nil
	end
end
