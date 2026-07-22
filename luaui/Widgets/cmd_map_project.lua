function widget:GetInfo()
	return {
		name = "Map Project",
		desc = "Save and load map projects: one git-friendly folder bundling heightmap, splat, metal, features, decals, lights, environment, weather, grass and start positions",
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

local heightmapPNG = nil -- lazy VFS.Include of the shared 16-bit PNG codec

local job = nil -- active save job, nil when idle
local loadJob = nil -- active load job, nil when idle (never both at once)

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

local function validateSlug(slug)
	if type(slug) ~= "string" or slug == "" then
		return nil, "missing project name"
	end
	if #slug > 64 then
		return nil, "project name too long (max 64)"
	end
	if not slug:match("^[A-Za-z0-9_%-]+$") then
		return nil, "project name may only contain letters, digits, _ and - (no spaces)"
	end
	if RESERVED_NAMES[slug:lower()] then
		return nil, "'" .. slug .. "' is a reserved Windows device name"
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
		return nil
	end
	f:write(content)
	f:close()
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

local function sectionSkip(name, reason)
	job.skipped[#job.skipped + 1] = { name = name, reason = reason }
end

local function warn(msg)
	job.warnings[#job.warnings + 1] = msg
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
		warn("current map is not an editor blank map; project will record its state, but loading will replay it onto a flat canvas")
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
			warn(string.format("terrain exceeded the recorded height range; widened to %d..%d (full heightmap diff this save)", minH, maxH))
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
		sectionSkip("splat", "painter reported done but file missing")
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
local function diffuseFailSkip(reason)
	local prev = job.prev and job.prev.sections and job.prev.sections.diffuse
	if prev and prev.dir then
		warn("diffuse capture failed (" .. reason .. "); keeping the previous save's diffuse files")
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
		local mo = job.mapOptions
		local isBlank = (mo.blank_map_x or mo.blank_map_y) and true or false
		if isBlank and not (dp.hasProjectState and dp.hasProjectState()) then
			sectionSkip("diffuse", "no diffuse paint state")
			job.diffuseStateEmpty = true -- the ONE case where cleanup may wipe diffuse/
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
	for _, p in ipairs(existing) do
		local name = basename(p)
		if not writtenSet[name] then
			os.remove(job.dir .. "diffuse/" .. name)
			echoP("removed stale diffuse/" .. name)
		end
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
	sectionOk("diffuse", "diffuse/", bytes, #res.squares .. " squares" .. (#res.channels > 0 and (", channels: " .. table.concat(res.channels, " ")) or ""))
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

local function stepFeatures()
	-- Serialized unsynced straight from the engine: the feature placer's own save
	-- is an async gadget round-trip with no completion signal, and the data is
	-- fully readable from here. Output format = FeaturePlacer setcfg (unchanged),
	-- so the existing loader consumes it as-is.
	local featureIDs = Spring.GetAllFeatures()
	local entries = {}
	for i = 1, #featureIDs do
		local fid = featureIDs[i]
		local defID = Spring.GetFeatureDefID(fid)
		local def = defID and FeatureDefs[defID]
		local x, _, z = Spring.GetFeaturePosition(fid)
		if def and x then
			entries[#entries + 1] = {
				name = def.name,
				x = x,
				z = z,
				rot = Spring.GetFeatureHeading(fid) or 0,
			}
		end
	end
	if #entries == 0 then
		sectionSkip("features", "no features on map")
		return true
	end
	-- Feature IDs are transient (re-assigned every load), so order by content.
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
	local lines = {
		"local setcfg = {",
		"\tunitlist = {},",
		"\tbuildinglist = {},",
		"\tobjectlist = {",
	}
	local format = string.format
	for _, e in ipairs(entries) do
		lines[#lines + 1] = format("\t\t{ name = %q, x = %.1f, z = %.1f, rot = %d },", e.name, e.x, e.z, e.rot)
	end
	lines[#lines + 1] = "\t},"
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

local function stepDecals()
	local dp = WG.DecalPlacer
	if not (dp and dp.saveProject) then
		sectionSkip("decals", "decal placer not loaded")
		return true
	end
	local path = job.dir .. "decals.lua"
	local n = dp.saveProject(path)
	if not n then
		sectionSkip("decals", "save failed")
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
		sectionSkip("environment", "snapshot failed")
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
	local api = WG["grassgl4"]
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
		sectionSkip("grass", "TGA write failed")
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
			warn("map has a splat distribution but no capturable splat textures — splat.png may not load onto a blank canvas")
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
	splat = { "splat.png" },
	metal = { "metal.lua" },
	features = { "features.lua" },
	decals = { "decals.lua" },
	startpos = { "startpos.lua" },
	startboxes = { "startboxes.lua" },
	lights = { "lights.lua" },
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

	local lines = {
		"return {",
		'\tkind = "bar-map-project",',
		"\tformat_version = " .. FORMAT_VERSION .. ",",
		string.format("\tname = %q,", (prev and prev.name) or job.slug),
		string.format("\tcreated = %q,", created),
		string.format("\tmodified = %q,", isoNow()),
		string.format("\tgame_version = %q,", Game.gameVersion or "unknown"),
		"",
		"\tmap = {",
		string.format("\t\tsize_x = %d, size_z = %d,", Game.mapSizeX / ELMOS_PER_UNIT, Game.mapSizeZ / ELMOS_PER_UNIT),
	}
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
	if mo.blank_map_skybox and mo.blank_map_skybox ~= "" then
		add(string.format("\t\tskybox = %q,", basename(mo.blank_map_skybox)))
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
			add(string.format("\t\t\t%s = { %s, %s, %s, %s },", name, fmtNum(t[1] or 0), fmtNum(t[2] or 0), fmtNum(t[3] or 0), fmtNum(t[4] or 0)))
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
	local order = { "heightmap", "splat", "diffuse", "metal", "features", "decals", "startpos", "startboxes", "lights", "environment", "weather", "grass" }
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
				add(string.format('\t\tdiffuse = { dir = "diffuse/", version = 1, bytes = %d, square_size = %d, squares = %d, full = %s, channels = { %s } },', s.bytes, d.squareSize or 1024, d.count or 0, tostring(d.full or false), table.concat(chParts, ", ")))
			else
				local extraFields = ""
				if name == "grass" then
					if job.grassPatchResolution then
						extraFields = string.format(" patch_resolution = %d,", job.grassPatchResolution)
					end
					extraFields = extraFields .. ' config = "grass_config.lua",'
				end
				add(string.format("\t\t%s = { file = %q, version = 1, bytes = %d,%s },", name, s.file, s.bytes, extraFields))
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

local STEPS = {
	{ name = "prepare", run = stepPrepare },
	{ name = "heightmap", run = stepHeightmap },
	{ name = "splat", run = stepSplat },
	{ name = "diffuse", run = stepDiffuse },
	{ name = "metal", run = stepMetal },
	{ name = "features", run = stepFeatures },
	{ name = "decals", run = stepDecals },
	{ name = "lights", run = stepLights },
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
	if job.failed then
		echoP("SAVE FAILED for project '" .. job.slug .. "': " .. job.failed)
		job = nil
		return
	end
	echoP("saved project '" .. job.slug .. "' to " .. job.dir)
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

local function startSave(slug)
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
	if not heightmapPNG then
		heightmapPNG = VFS.Include("luaui/Widgets/cmd_terraform_brush_png.lua")
	end
	job = {
		slug = slug,
		dir = PROJECTS_DIR .. slug .. "/",
		step = 1,
		cursor = {},
		sections = {},
		skipped = {},
		warnings = {},
	}
	echoP("saving project '" .. slug .. "'...")
	return true
end

-- Enumerate projects with manifest details for the Open Project dialog.
-- VFS.SubDirs sees the folders; manifests are read via raw io (same-session
-- folders may be invisible/stale in the VFS view — SubDirs RAW semantics for
-- folders created THIS session are unpinned, so a just-saved project may need
-- an engine restart to appear; the dialog says so when the list is empty).
local function listProjectsDetailed()
	local out = {}
	local dirs = VFS.SubDirs(PROJECTS_DIR, "*", VFS.RAW) or {}
	for _, d in ipairs(dirs) do
		local slug = d:match("([^/\\]+)[/\\]*$")
		if slug then
			local manifest = readPrevManifest(PROJECTS_DIR .. slug .. "/")
			if manifest and manifest.kind == "bar-map-project" then
				local m = manifest.map or {}
				out[#out + 1] = {
					slug = slug,
					name = manifest.name or slug,
					size_x = tonumber(m.size_x),
					size_z = tonumber(m.size_z),
					modified = manifest.modified,
					format_version = tonumber(manifest.format_version),
				}
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
		echoP(string.format("  %-24s %sx%s  modified %s", p.slug, tostring(p.size_x), tostring(p.size_z), tostring(p.modified)))
	end
	if #found == 0 then
		echoP("no projects in " .. PROJECTS_DIR)
	end
	return #found
end

----------------------------------------------------------------
-- Load: pointer file (restart survivor with phase journal)
----------------------------------------------------------------

-- Raw io ONLY for the pointer: VFS caches stale content for files created or
-- rewritten within a session (the reason pending_newmap.lua does the same).
local function writePointer(t)
	Spring.CreateDir("Terraform Brush")
	local content = string.format("return { path = %q, size_x = %d, size_z = %d, phase = %d, phases = %d }\n", t.path, t.size_x, t.size_z, t.phase or 0, t.phases or 0)
	return writeFile(POINTER_PATH, content) ~= nil
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
		return nil, string.format("project format_version %d is NEWER than this tool understands (%d) — update the game before opening it (re-saving with an older tool would silently lose data)", fv, FORMAT_VERSION)
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
		return nil, string.format("implausible map size %sx%s (need even map units in 2..64)", tostring(m.size_x), tostring(m.size_z))
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
		echoP(string.format("WARNING: %s is %d bytes but the manifest recorded %d (incomplete save?) — loading best-effort", sec.file, size, sec.bytes))
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
		Spring.SendCommands("terraformimport " .. path)
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
			loadSkip("dnts", "splat normals never appeared (engine honoring blank_map_splat* keys?) — splat visuals may be missing")
		else
			return false
		end
	end
	if not splatPath then
		return true
	end
	if not hasDnts and not c.noDntsWarned then
		c.noDntsWarned = true
		echoP("WARNING: project has splat.png but no DNTS record — the splat data will load with no textures to modulate")
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

-- Phase 3: diffuse. Per-square PNGs blitted into painter-owned seed+composite
-- textures (later paint bakes over the loaded state), channel PNGs into the
-- painter's channel textures. Files discovered by glob — the save side keeps
-- the diffuse/ dir exact.
local function phaseDiffuse(c)
	local sec = loadJob.manifest.sections and loadJob.manifest.sections.diffuse
	if not (sec and sec.dir) then
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
		echoP(string.format("diffuse: loading %d squares%s...", #sqs, nChans > 0 and (" + " .. nChans .. " channel(s)") or ""))
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
		loadOk("diffuse", (res.loaded or 0) .. " squares" .. ((res.channels or 0) > 0 and (", " .. res.channels .. " channel(s)") or ""))
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

-- Phase 6: decals + lights (client-side; need final heights for light Y).
local function phaseDecalsLights(c)
	local decalPath = sectionFile("decals")
	if decalPath then
		local dp = WG.DecalPlacer
		if dp and dp.load then
			for _, a in ipairs((loadJob.manifest.assets and loadJob.manifest.assets.decals) or {}) do
				if a.name and not VFS.FileExists("bitmaps/decals/" .. a.name .. ".png", VFS.MOD) then
					echoP("WARNING: decal capture '" .. a.name .. "' is not installed in the game archive — copy " .. loadJob.dir .. tostring(a.file) .. " into bitmaps/decals/ and restart to see it")
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
	return true
end

-- Phase 7: environment. Short settle countdown mirrors the New Map env-preset
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

-- Phase 8: weather. Clear persistent spawners first (idempotent replay), then
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

-- Phase 9: startpos + startboxes + grass (all need sim-acked terrain: slope
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
		local api = WG["grassgl4"]
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
				loadSkip("grass", string.format("patch resolution mismatch (project %d, session %d) — a mismatched grid would misplace every patch", savedRes, sessionRes))
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
	{ name = "diffuse", run = phaseDiffuse },
	{ name = "metal", run = phaseMetal },
	{ name = "features", run = phaseFeatures },
	{ name = "decals+lights", run = phaseDecalsLights },
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
	loadJob = nil
end

local function abortLoad(reason)
	echoP("PROJECT LOAD ABORTED: " .. reason)
	deletePointer()
	loadJob = nil
end

-- One pump tick. The cheat gate is a PRECONDITION, not a journaled phase: the
-- synced gadgets ($terraform_import$, $metal_load$, $feature_load$) all require
-- live cheat outside replays ($c$ certification is replay-only), and cheat
-- resets across engine restart AND can be toggled off by the user mid-load, so
-- it is re-verified on every tick. "cheat" TOGGLES — only (re)send while
-- observed OFF, with a generous gap so an in-flight send cannot be doubled.
local function runLoadTick()
	if not Spring.IsCheatingEnabled() then
		local c = loadJob
		c.cheatTicks = (c.cheatTicks or 0) + 1
		if not c.cheatLastSend or (c.cheatTicks - c.cheatLastSend) >= CHEAT_RESEND_TICKS then
			c.cheatSends = (c.cheatSends or 0) + 1
			if c.cheatSends > CHEAT_MAX_SENDS then
				abortLoad("could not enable /cheat (required for terrain/metal/feature replay); enable cheats and open the project again")
				return
			end
			c.cheatLastSend = c.cheatTicks
			Spring.SendCommands("cheat")
			echoP("enabling /cheat for the load (attempt " .. c.cheatSends .. ")...")
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
		writePointer({ path = loadJob.dir, size_x = loadJob.sizeX, size_z = loadJob.sizeZ, phase = loadJob.phase, phases = #LOAD_PHASES })
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
	if not (ptr.size_x and ptr.size_z and Game.mapSizeX == ptr.size_x * ELMOS_PER_UNIT and Game.mapSizeZ == ptr.size_z * ELMOS_PER_UNIT) then
		reasons[#reasons + 1] = string.format("map size is %dx%d units, pointer wants %sx%s", Game.mapSizeX / ELMOS_PER_UNIT, Game.mapSizeZ / ELMOS_PER_UNIT, tostring(ptr.size_x), tostring(ptr.size_z))
	end
	if not (Game.mapName or ""):match("^Editor Flat %d+x%d+") then
		reasons[#reasons + 1] = "map is '" .. tostring(Game.mapName) .. "', not an editor blank map"
	end
	if Game.mapDamage == false then
		reasons[#reasons + 1] = "map damage is disabled (terrain cannot be replayed)"
	end
	if Spring.IsReplay() then
		reasons[#reasons + 1] = "this is a replay"
	end
	local gt = BAR.Utilities and BAR.Utilities.Gametype
	if gt and gt.IsSinglePlayer and not gt.IsSinglePlayer() then
		reasons[#reasons + 1] = "not a local singleplayer session"
	end
	if #reasons > 0 then
		deletePointer()
		echoP("PENDING PROJECT LOAD CANCELLED — session mismatch: " .. table.concat(reasons, "; ") .. ". Pointer removed; open the project again from the FILE menu.")
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
	loadJob = {
		slug = ptr.path:match("([^/\\]+)[/\\]*$") or ptr.path,
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
	local gt = BAR.Utilities and BAR.Utilities.Gametype
	if gt and gt.IsSinglePlayer and not gt.IsSinglePlayer() then
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
	Spring.Restart("", script)
	return true
end

function widget:DrawScreen()
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
			sectionSkip(step.name, "error: " .. tostring(done))
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
		startSave(params[2])
	elseif sub == "open" then
		openProject(params[2])
	elseif sub == "list" then
		listProjects()
	else
		echoP("usage: /mapproject save <name>  |  /mapproject open <name>  |  /mapproject list")
	end
end

function widget:Initialize()
	widgetHandler:AddAction("mapproject", mapProjectAction, nil, "t")
	WG.MapProject = {
		save = startSave,
		open = openProject,
		list = listProjects,
		listDetailed = listProjectsDetailed,
		isBusy = function()
			return job ~= nil or loadJob ~= nil
		end,
		isLoading = function()
			return loadJob ~= nil
		end,
	}
	maybeStartLoad()
end

function widget:Shutdown()
	WG.MapProject = nil
	widgetHandler:RemoveAction("mapproject")
	if job then
		echoP("save aborted by widget shutdown — project may be incomplete (no manifest written)")
		job = nil
	end
	if loadJob then
		echoP("project load interrupted by widget shutdown — it will resume from the phase journal on reload")
		loadJob = nil
	end
end
