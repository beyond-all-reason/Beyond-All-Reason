function widget:GetInfo()
	return {
		name    = "Map Project",
		desc    = "Save map projects: one git-friendly folder bundling heightmap, splat, metal, features, decals, lights, environment, weather, grass and start positions",
		author  = "PtaQ",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 1000000,
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

local Echo = Spring.Echo

local PROJECTS_DIR   = "MapProjects/"
local FORMAT_VERSION = 1
local ELMOS_PER_UNIT = 512

-- Chunk budgets per Update tick (keep the UI responsive during save)
local HEIGHT_ROWS_PER_TICK = 32
local METAL_ROWS_PER_TICK  = 128
local SPLAT_TIMEOUT_TICKS  = 300

local heightmapPNG = nil  -- lazy VFS.Include of the shared 16-bit PNG codec

local job = nil  -- active save job, nil when idle

----------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------

local function echoP(msg)
	Echo("[Map Project] " .. msg)
end

-- Windows reserved device names make CreateDir fail or produce unusable paths.
local RESERVED_NAMES = {
	con = true, prn = true, aux = true, nul = true,
	com1 = true, com2 = true, com3 = true, com4 = true, com5 = true,
	com6 = true, com7 = true, com8 = true, com9 = true,
	lpt1 = true, lpt2 = true, lpt3 = true, lpt4 = true, lpt5 = true,
	lpt6 = true, lpt7 = true, lpt8 = true, lpt9 = true,
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
	if not f then return nil end
	f:write(content)
	f:close()
	return #content
end

local function fileSize(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local size = f:seek("end")
	f:close()
	return size
end

-- Numbers in the manifest: integers stay integers, floats get fixed precision
-- (deterministic serialization).
local function fmtNum(v)
	if v == math.floor(v) then return string.format("%d", v) end
	return string.format("%.4f", v)
end

local function basename(path)
	return path:match("([^/\\]+)$") or path
end

-- Read a previously saved manifest (created timestamp + canonical height range
-- must survive re-saves). Raw io.open, never VFS: fresh files can be invisible
-- or stale in the VFS view within a session.
local function readPrevManifest(dir)
	local f = io.open(dir .. "project.lua", "r")
	if not f then return nil end
	local raw = f:read("*a")
	f:close()
	local chunk = loadstring(raw)
	if not chunk then return nil end
	local ok, data = pcall(chunk)
	if not ok or type(data) ~= "table" then return nil end
	return data
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
		if s.name == name then return s end
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
				if gh < minH then minH = gh end
				if gh > maxH then maxH = gh end
				idx = idx + 1
				heights[idx] = gh
			end
			c.z = c.z + sq
			rows = rows + 1
		end
		c.idx, c.minH, c.maxH = idx, minH, maxH
		if c.z <= Game.mapSizeZ then return false end
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
	if maxH - minH < 1 then maxH = minH + 1 end

	local range = maxH - minH
	local samples = {}
	local floor = math.floor
	for i = 1, c.idx do
		local norm = (c.heights[i] - minH) / range
		if norm < 0 then norm = 0 elseif norm > 1 then norm = 1 end
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
	if c.mz < mmZ then return false end

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
		if a.name ~= b.name then return a.name < b.name end
		if a.x ~= b.x then return a.x < b.x end
		if a.z ~= b.z then return a.z < b.z end
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
		for i = 1, #s.cegs do cegParts[i] = format("%q", s.cegs[i]) end
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

local function stepAssets()
	local mo = job.mapOptions
	-- DNTS set: copy the resolved textures INTO the project (libraries mutate
	-- over months; projects must stay self-contained) and record the resolved
	-- scales/mults so load does not depend on the library.
	local dnts = nil
	local seenSource = {}  -- dest name -> source path (detects basename collisions across sets)
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
	table.sort(job.assetDecals, function(a, b) return a.name < b.name end)
	return true
end

-- Canonical section files: anything present on disk but NOT written this save is
-- stale state from a previous save (e.g. metal cleared since) and must go, or a
-- file-presence loader would resurrect deleted state.
local SECTION_FILES = {
	heightmap   = { "heightmap.png" },
	splat       = { "splat.png" },
	metal       = { "metal.lua" },
	features    = { "features.lua" },
	decals      = { "decals.lua" },
	startpos    = { "startpos.lua" },
	startboxes  = { "startboxes.lua" },
	lights      = { "lights.lua" },
	environment = { "environment.lua" },
	weather     = { "weather.lua" },
	grass       = { "grass_dist.tga", "grass_config.lua" },
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
	local function add(line) lines[#lines + 1] = line end

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
		local function quad(name, t)
			add(string.format("\t\t\t%s = { %s, %s, %s, %s },", name,
				fmtNum(t[1] or 0), fmtNum(t[2] or 0), fmtNum(t[3] or 0), fmtNum(t[4] or 0)))
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
	local order = { "heightmap", "splat", "metal", "features", "decals", "startpos", "startboxes", "lights", "environment", "weather", "grass" }
	for _, name in ipairs(order) do
		local s = findSection(name)
		if s then
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
	{ name = "prepare",     run = stepPrepare },
	{ name = "heightmap",   run = stepHeightmap },
	{ name = "splat",       run = stepSplat },
	{ name = "metal",       run = stepMetal },
	{ name = "features",    run = stepFeatures },
	{ name = "decals",      run = stepDecals },
	{ name = "lights",      run = stepLights },
	{ name = "startpos",    run = stepStartPos },
	{ name = "environment", run = stepEnvironment },
	{ name = "weather",     run = stepWeather },
	{ name = "grass",       run = stepGrass },
	{ name = "assets",      run = stepAssets },
	{ name = "cleanup",     run = stepCleanupStale },
	{ name = "manifest",    run = stepManifest },
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

local function listProjects()
	local dirs = VFS.SubDirs(PROJECTS_DIR, "*", VFS.RAW) or {}
	local found = 0
	for _, d in ipairs(dirs) do
		-- Raw io read: same-session folders may be invisible/stale in the VFS view
		local f = io.open(d .. "project.lua", "r")
		if f then
			f:close()
			found = found + 1
			echoP("  " .. (d:match("([^/\\]+)[/\\]*$") or d))
		end
	end
	if found == 0 then
		echoP("no projects in " .. PROJECTS_DIR)
	end
	return found
end

function widget:DrawScreen()
	if not job then return end
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
	elseif sub == "list" then
		listProjects()
	else
		echoP("usage: /mapproject save <name>  |  /mapproject list")
	end
end

function widget:Initialize()
	widgetHandler:AddAction("mapproject", mapProjectAction, nil, "t")
	WG.MapProject = {
		save = startSave,
		list = listProjects,
		isBusy = function() return job ~= nil end,
	}
end

function widget:Shutdown()
	WG.MapProject = nil
	widgetHandler:RemoveAction("mapproject")
	if job then
		echoP("save aborted by widget shutdown — project may be incomplete (no manifest written)")
		job = nil
	end
end
