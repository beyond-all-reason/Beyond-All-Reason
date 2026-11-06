-- Map export: turns a saved Terraform Brush map project into the files of a map archive.
--
-- Plain Lua 5.1 with no Spring calls, so the same code runs in the game (FILE > EXPORT MAP) and in a
-- build workflow (tools/map_export/export.lua) that has no game. Every file access goes through the
-- `io` adapter the caller passes:
--   read(path) -> string?        whole file, binary safe
--   write(path, data) -> bool    creates or replaces the file; the caller's mkdir has made its folder
--   mkdir(path)                  creates a folder and its parents
--   exists(path) -> bool
--
-- Output, under `out`:
--   archive/   what goes into the .sd7: mapinfo.lua, maps/ (textures, skybox), mapconfig/ (one file per
--              section the game reads at load: tileset, featureplacer, lights, decals, weather, blockout,
--              edge extension, start boxes, grass distribution)
--   compile/   inputs for the binary step that writes maps/<base>.smf and .smt (heightmap, minimap,
--              diffuse squares, metal grid) and compile.json describing them; not shipped
--   export_report.txt
--
-- The map carries data only: feature models, decal textures, CEGs, blockout models and the tileset's
-- textures come from the game. The report lists every such reference so the caller can check them.

local MapExport = {}

MapExport.FORMAT_VERSION = 1
MapExport.TILESET_FORMAT_VERSION = 1

local format = string.format
local floor = math.floor

--------------------------------------------------------------------------------
-- Lua table files
--------------------------------------------------------------------------------

-- Loads a `return {...}` file (comments and leading locals allowed) with no globals in reach.
---@return table? tbl
---@return string? err
function MapExport.loadTable(text, chunkName)
	if type(text) ~= "string" then
		return nil, "no file"
	end
	text = text:gsub("^\239\187\191", "") -- UTF-8 BOM
	local fn, err = loadstring(text, chunkName)
	if not fn then
		return nil, err
	end
	setfenv(fn, {})
	local ok, result = pcall(fn)
	if not ok then
		return nil, tostring(result)
	end
	if type(result) ~= "table" then
		return nil, "file does not return a table"
	end
	return result
end

local LUA_KEYWORDS = {}
for word in
	("and break do else elseif end false for function if in local nil not or repeat return then true until while"):gmatch(
		"%a+"
	)
do
	LUA_KEYWORDS[word] = true
end

local function fmtNumber(n)
	if n ~= n then
		return "0"
	end
	if n == floor(n) and n > -1e15 and n < 1e15 then
		return format("%d", n)
	end
	return format("%.7g", n)
end
MapExport.fmtNumber = fmtNumber

local function isArray(t)
	local n = #t
	for k in pairs(t) do
		if type(k) ~= "number" or k < 1 or k > n or k ~= floor(k) then
			return false
		end
	end
	return true
end

local function keyLess(a, b)
	local ta, tb = type(a), type(b)
	if ta ~= tb then
		return ta == "number"
	end
	return a < b
end

-- Deterministic: arrays in order, other keys sorted, so the same data always gives the same bytes.
local function serialize(value, indent, out)
	local t = type(value)
	if t == "table" then
		local inner = indent .. "\t"
		if next(value) == nil then
			out[#out + 1] = "{}"
			return
		end
		if isArray(value) then
			local flat = true
			for i = 1, #value do
				if type(value[i]) == "table" then
					flat = false
					break
				end
			end
			if flat and #value <= 8 then
				out[#out + 1] = "{ "
				for i = 1, #value do
					serialize(value[i], inner, out)
					out[#out + 1] = (i < #value) and ", " or " }"
				end
				return
			end
			out[#out + 1] = "{\n"
			for i = 1, #value do
				out[#out + 1] = inner
				serialize(value[i], inner, out)
				out[#out + 1] = ",\n"
			end
			out[#out + 1] = indent .. "}"
			return
		end
		local keys = {}
		for k in pairs(value) do
			keys[#keys + 1] = k
		end
		table.sort(keys, keyLess)
		out[#out + 1] = "{\n"
		for _, k in ipairs(keys) do
			out[#out + 1] = inner
			if type(k) == "string" and k:match("^[%a_][%w_]*$") and not LUA_KEYWORDS[k] then
				out[#out + 1] = k
			elseif type(k) == "number" then
				out[#out + 1] = "[" .. fmtNumber(k) .. "]"
			else
				out[#out + 1] = format("[%q]", tostring(k))
			end
			out[#out + 1] = " = "
			serialize(value[k], inner, out)
			out[#out + 1] = ",\n"
		end
		out[#out + 1] = indent .. "}"
	elseif t == "number" then
		out[#out + 1] = fmtNumber(value)
	elseif t == "string" then
		out[#out + 1] = format("%q", value)
	elseif t == "boolean" then
		out[#out + 1] = tostring(value)
	else
		out[#out + 1] = "nil"
	end
end

function MapExport.serialize(value)
	local out = {}
	serialize(value, "", out)
	return table.concat(out)
end

-- Adds to a `return {...}` file the top-level keys of `carried` it lacks, so a build that does not
-- know a setting (heightFog, blockout rings) still saves it back unchanged.
---@param text string
---@param carried table?
---@return string text
function MapExport.carryKeys(text, carried)
	local have = MapExport.loadTable(text)
	if not (have and type(carried) == "table") then
		return text
	end
	local keys = {}
	for k in pairs(carried) do
		if type(k) == "string" and k:match("^[%a_][%w_]*$") and not LUA_KEYWORDS[k] and have[k] == nil then
			keys[#keys + 1] = k
		end
	end
	local head, tail = text:match("^(.*)(}%s*)$")
	if #keys == 0 or not head then
		return text
	end
	table.sort(keys)
	local out = { head, "\n\t-- Kept from the loaded project (this build does not use them)\n" }
	for _, k in ipairs(keys) do
		out[#out + 1] = "\t" .. k .. " = "
		serialize(carried[k], "\t", out)
		out[#out + 1] = ",\n"
	end
	out[#out + 1] = tail
	return table.concat(out)
end

-- JSON for compile.json (read by the binary step, which is not Lua). Same ordering rules.
local function jsonValue(value, indent, out)
	local t = type(value)
	if t == "table" then
		local inner = indent .. "  "
		if next(value) == nil then
			out[#out + 1] = isArray(value) and "[]" or "{}"
			return
		end
		if isArray(value) then
			out[#out + 1] = "["
			for i = 1, #value do
				if type(value[i]) == "table" then
					out[#out + 1] = (i == 1 and "\n" or "") .. inner
				end
				jsonValue(value[i], inner, out)
				if i < #value then
					out[#out + 1] = type(value[i]) == "table" and ",\n" or ", "
				end
			end
			out[#out + 1] = type(value[#value]) == "table" and ("\n" .. indent .. "]") or "]"
			return
		end
		local keys = {}
		for k in pairs(value) do
			keys[#keys + 1] = tostring(k)
		end
		table.sort(keys)
		out[#out + 1] = "{\n"
		for i, k in ipairs(keys) do
			out[#out + 1] = inner .. format("%q", k) .. ": "
			local v = value[k]
			if v == nil then
				v = value[tonumber(k)]
			end
			jsonValue(v, inner, out)
			out[#out + 1] = (i < #keys) and ",\n" or "\n"
		end
		out[#out + 1] = indent .. "}"
	elseif t == "number" then
		out[#out + 1] = fmtNumber(value)
	elseif t == "string" then
		out[#out + 1] = '"'
			.. value:gsub('[%c"\\]', function(c)
				local named = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
				return named[c] or format("\\u%04x", c:byte())
			end)
			.. '"'
	elseif t == "boolean" then
		out[#out + 1] = tostring(value)
	else
		out[#out + 1] = "null"
	end
end

function MapExport.toJson(value)
	local out = {}
	jsonValue(value, "", out)
	return table.concat(out) .. "\n"
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- 1x1 grey PNG (127, 127, 127): the splat detail texture of a tileset map
local FLAT_DETAIL_NAME = "tileset_flat_detail.png"
local FLAT_DETAIL_PNG = "\137\80\78\71\13\10\26\10\0\0\0\13\73\72\68\82\0\0\0\1\0\0\0\1\8\2\0\0\0\144\119\83\222"
	.. "\0\0\0\12\73\68\65\84\120\218\99\168\175\175\7\0\2\254\1\126\132\216\163\137\0\0\0\0\73\69\78\68\174\66\96\130"

-- A file name part from a map name: lower case, letters, digits and underscores.
function MapExport.fileBase(name, version)
	local s = (tostring(name or "map") .. ((version and version ~= "") and ("_" .. version) or ""))
	s = s:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
	return (s ~= "" and s or "map")
end

local function basename(path)
	return (tostring(path):gsub("\\", "/"):match("([^/]+)$")) or tostring(path)
end

local function copyTable(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = (type(v) == "table") and copyTable(v) or v
	end
	return c
end

-- mapinfo.lua is written with lowercase keys, as the Spring map template's lowerkeys() returns
-- it: the engine reads either case, but Lua readers (VFS.Include("mapinfo.lua")) look up
-- custom.grassconfig, lighting.sundir, voidwater and the like in lowercase only.
local function lowerKeys(t)
	local c = {}
	for k, v in pairs(t) do
		c[type(k) == "string" and k:lower() or k] = (type(v) == "table") and lowerKeys(v) or v
	end
	return c
end

local function vec(v, n)
	if type(v) ~= "table" then
		return nil
	end
	local r = {}
	for i = 1, n do
		local x = tonumber(v[i])
		if x == nil then
			return nil
		end
		r[i] = x
	end
	return r
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

---@class MapExportOpts
---@field project string project folder, with or without a trailing slash
---@field out string output folder (archive/, compile/ and the report go under it)
---@field io table the file adapter (see the top of this file)
---@field name string? map name; default: the project's name
---@field version string? map version; default "1.0"
---@field description string?
---@field author string?
---@field assetDirs string[]? folders searched for files the project only names (the skybox)

---@class MapExportReport
---@field ok boolean
---@field name string full map name ("<name> <version>")
---@field fileBase string
---@field written string[] archive paths written
---@field files string[] every file written, full path (the caller removes them before a re-export)
---@field sections table<string, string> per project section: what became of it
---@field notes string[]
---@field missing string[] files the map needs that the export could not find
---@field references table<string, string[]> game content the map names (features, decal textures, CEGs, blockout models, biome)
---@field errors string[]

---@param opts MapExportOpts
---@return MapExportReport
function MapExport.run(opts)
	local fs = assert(opts.io, "map export: no io adapter")
	local projectDir = (opts.project:gsub("\\", "/"):gsub("/?$", "/"))
	local outDir = (opts.out:gsub("\\", "/"):gsub("/?$", "/"))
	local archiveDir = outDir .. "archive/"
	local compileDir = outDir .. "compile/"

	---@type MapExportReport
	local report = {
		ok = false,
		name = "",
		fileBase = "",
		written = {},
		files = {},
		sections = {},
		notes = {},
		missing = {},
		references = {},
		errors = {},
	}
	local refSets = {}
	local function reference(kind, name)
		if type(name) ~= "string" or name == "" then
			return
		end
		refSets[kind] = refSets[kind] or {}
		refSets[kind][name] = true
	end
	local function note(s)
		report.notes[#report.notes + 1] = s
	end
	local function fail(s)
		report.errors[#report.errors + 1] = s
	end

	local function projectFile(rel)
		return fs.read(projectDir .. rel)
	end
	local function projectTable(rel)
		local text = projectFile(rel)
		if not text then
			return nil, "missing"
		end
		return MapExport.loadTable(text, "@" .. rel)
	end

	local madeDirs = {}
	local function ensureDir(path)
		local dir = path:match("^(.*)/[^/]*$")
		if dir and not madeDirs[dir] then
			fs.mkdir(dir)
			madeDirs[dir] = true
		end
	end
	-- rel is relative to archive/ (shipped) or compile/ (when toCompile)
	local function emit(rel, data, toCompile)
		local path = (toCompile and compileDir or archiveDir) .. rel
		ensureDir(path)
		if not fs.write(path, data) then
			fail("could not write " .. path)
			return false
		end
		report.files[#report.files + 1] = path
		if not toCompile then
			report.written[#report.written + 1] = rel
		end
		return true
	end
	local function emitTable(rel, header, tbl, localName)
		local body = MapExport.serialize(tbl)
		local text
		if localName then
			text = header .. "local " .. localName .. " = " .. body .. "\n\nreturn " .. localName .. "\n"
		else
			text = header .. "return " .. body .. "\n"
		end
		return emit(rel, text)
	end
	local function copyFromProject(rel, dest, toCompile)
		local data = projectFile(rel)
		if not data then
			report.missing[#report.missing + 1] = "project file " .. rel
			return false
		end
		return emit(dest, data, toCompile)
	end
	-- a file the project only names (skybox, ramp image): as given, in the project, then by name in assetDirs
	local function libraryFile(name)
		local data = fs.read(name) or projectFile(name)
		if data then
			return data
		end
		for _, dir in ipairs(opts.assetDirs or {}) do
			data = fs.read((dir:gsub("\\", "/"):gsub("/?$", "/")) .. basename(name))
			if data then
				return data
			end
		end
		return nil
	end

	-- Manifest ---------------------------------------------------------------
	local manifest, mErr = projectTable("project.lua")
	if not manifest then
		fail("project.lua: " .. tostring(mErr))
		return report
	end
	if manifest.kind ~= "bar-map-project" then
		fail("project.lua is not a map project (kind = " .. tostring(manifest.kind) .. ")")
		return report
	end
	local map = type(manifest.map) == "table" and manifest.map or {}
	local sections = type(manifest.sections) == "table" and manifest.sections or {}
	local sizeX, sizeZ = tonumber(map.size_x), tonumber(map.size_z)
	if not (sizeX and sizeZ) then
		fail("project.lua has no map size")
		return report
	end

	local mapName = (opts.name and opts.name ~= "") and opts.name or tostring(manifest.name or "Map")
	local version = (opts.version and opts.version ~= "") and opts.version or "1.0"
	local base = MapExport.fileBase(mapName, version)
	report.name = mapName .. " " .. version
	report.fileBase = base
	local header = format(
		"-- %s %s, exported from a Terraform Brush map project by map_export v%d\n\n",
		mapName,
		version,
		MapExport.FORMAT_VERSION
	)

	local function sectionFile(name)
		local s = sections[name]
		return type(s) == "table" and type(s.file) == "string" and s.file or nil
	end

	local mapinfo = {
		-- The full archive name, version included: the engine appends the version to the name
		-- only when the name does not already contain it anywhere, so "CM12" version "1" would
		-- register as plain "CM12" (ArchiveScanner) and nothing could find "CM12 1".
		name = report.name,
		shortname = base,
		description = opts.description or "",
		author = opts.author or "",
		version = version,
		mapfile = "maps/" .. base .. ".smf",
		modtype = 3,
		depend = {},
		replace = {},
		maphardness = 100,
		notDeformable = false,
		gravity = 130,
		tidalStrength = 0,
		maxMetal = 0.02,
		extractorRadius = tonumber(map.extractor_radius) or 90,
		voidWater = false,
		voidGround = false,
		autoShowMetal = true,
		smf = {},
		lighting = {},
		atmosphere = {},
		water = {},
		splats = {},
		resources = {},
		teams = {},
		terrainTypes = {},
		custom = {},
	}
	local compile = {
		format_version = MapExport.FORMAT_VERSION,
		name = report.name,
		file_base = base,
		smf = "maps/" .. base .. ".smf",
		smt = "maps/" .. base .. ".smt",
		size_x = sizeX,
		size_z = sizeZ,
		square_size = 8,
	}
	if type(map.height_range) == "table" and tonumber(map.height_range.min) and tonumber(map.height_range.max) then
		mapinfo.smf.minheight = tonumber(map.height_range.min)
		mapinfo.smf.maxheight = tonumber(map.height_range.max)
		compile.height = { min = mapinfo.smf.minheight, max = mapinfo.smf.maxheight }
	end

	-- Height, minimap: inputs of the binary step -----------------------------
	local hmFile = sectionFile("heightmap")
	if hmFile and copyFromProject(hmFile, "heightmap.png", true) then
		compile.heightmap = "heightmap.png"
		report.sections.heightmap = "compile/heightmap.png (written into the .smf)"
	else
		fail("the project has no heightmap")
	end
	local mmFile = sectionFile("minimap")
	if mmFile and copyFromProject(mmFile, "minimap.png", true) then
		compile.minimap = "minimap.png"
		report.sections.minimap = "compile/minimap.png (written into the .smf)"
	end

	-- Diffuse: per-square captures and/or a flat base colour, for the .smt -----
	local diffuse = { base_color = vec(map.base_color, 3) }
	local dsec = sections.diffuse
	if type(dsec) == "table" then
		local sq = tonumber(dsec.square_size) or 1024
		local nx = floor(sizeX * 512 / sq + 0.5)
		local nz = floor(sizeZ * 512 / sq + 0.5)
		local dir = type(dsec.dir) == "string" and dsec.dir or "diffuse/"
		local squares = {}
		for sz = 0, nz - 1 do
			for sx = 0, nx - 1 do
				local rel = format("%ssq_%d_%d.png", dir, sx, sz)
				if
					fs.exists(projectDir .. rel) and copyFromProject(rel, format("diffuse/sq_%d_%d.png", sx, sz), true)
				then
					squares[#squares + 1] = { sx, sz }
				end
			end
		end
		diffuse.square_size = sq
		diffuse.squares = squares
		report.sections.diffuse = format("compile/diffuse/ (%d squares, into the .smt)", #squares)
	else
		report.sections.diffuse = "none: the .smt gets the base colour"
	end
	compile.diffuse = diffuse

	-- Metal: the .smf metal map ------------------------------------------------
	local metalFile = sectionFile("metal")
	if metalFile then
		local metal, err = projectTable(metalFile)
		if metal and type(metal.spots) == "table" then
			local maxAmount = 0
			local amounts = {}
			for _, s in ipairs(metal.spots) do
				local amount = tonumber(s.amount) or 0
				amounts[#amounts + 1] = amount
				maxAmount = math.max(maxAmount, amount)
			end
			-- The engine reads a cell as byte * maxMetal (MetalMap.cpp), and the brush saved
			-- GetMetalAmount, so every amount is a whole number of the session's maxMetal (to the
			-- 3 decimals metal.lua keeps). Recover that scale: the most steps up to 255 that fit
			-- every amount; 255 steps of the largest amount when none does.
			local maxMetal = 0.02
			if maxAmount > 0 then
				maxMetal = maxAmount / 255
				for steps = 255, 64, -1 do
					local m = maxAmount / steps
					local fits = true
					for i = 1, #amounts do
						local q = amounts[i] / m
						if math.abs(q - floor(q + 0.5)) * m > 0.0006 then
							fits = false
							break
						end
					end
					if fits then
						maxMetal = m
						break
					end
				end
			end
			mapinfo.maxMetal = maxMetal
			local cells = {}
			for _, s in ipairs(metal.spots) do
				local amount = tonumber(s.amount) or 0
				local b = floor(amount / maxMetal + 0.5)
				if b > 0 then
					cells[#cells + 1] = { tonumber(s.mx) or 0, tonumber(s.mz) or 0, math.min(255, b) }
				end
			end
			compile.metal = {
				max_metal = maxMetal,
				square_size = tonumber(metal.squareSize) or 16,
				width = tonumber(metal.width),
				height = tonumber(metal.height),
				cells = cells,
			}
			report.sections.metal =
				format("compile.json metal grid (%d cells, maxMetal %s)", #cells, fmtNumber(maxMetal))
		else
			fail("metal.lua: " .. tostring(err or "no spots"))
		end
	end

	-- Environment: lighting, atmosphere, water, splats, fog, blockout ---------
	local envFile = sectionFile("environment")
	local env = envFile and projectTable(envFile) or nil
	if env then
		local L = mapinfo.lighting
		local sd = vec(env.sunDir, 3)
		if sd then
			L.sunDir = { sd[1], sd[2], sd[3], tonumber(env.sunIntensity) or 1 }
		end
		for _, k in ipairs({
			"groundAmbientColor",
			"groundDiffuseColor",
			"groundSpecularColor",
			"unitAmbientColor",
			"unitDiffuseColor",
			"unitSpecularColor",
		}) do
			L[k] = vec(env[k], 3)
		end
		L.groundShadowDensity = tonumber(env.groundShadowDensity)
		-- the engine reads the model value as unitShadowDensity (MapInfo.cpp)
		L.unitShadowDensity = tonumber(env.modelShadowDensity)

		local A = mapinfo.atmosphere
		A.fogStart = tonumber(env.fogStart)
		A.fogEnd = tonumber(env.fogEnd)
		A.fogColor = vec(env.fogColor, 4) or vec(env.fogColor, 3)
		A.sunColor = vec(env.sunColor, 3)
		A.skyColor = vec(env.skyColor, 3)
		A.cloudColor = vec(env.cloudColor, 3)
		A.skyAxisAngle = vec(env.skyAxisAngle, 4)

		mapinfo.splats.texScales = vec(env.splatTexScales, 4)
		mapinfo.splats.texMults = vec(env.splatTexMults, 4)
		if env.splatDetailNormalDiffuseAlpha ~= nil then
			mapinfo.resources.splatDetailNormalDiffuseAlpha = env.splatDetailNormalDiffuseAlpha and true or false
		end
		mapinfo.voidWater = env.voidWater == true
		mapinfo.voidGround = env.voidGround == true

		if type(env.water) == "table" then
			for k, v in pairs(env.water) do
				mapinfo.water[k] = v
			end
		end
		for k, v in pairs(env) do
			local colorName = type(k) == "string" and k:match("^waterColors_(.+)$")
			if colorName then
				mapinfo.water[colorName] = vec(v, 3)
			end
		end

		if type(env.heightFog) == "table" then
			-- the fog widget applies these by the names the panel saves them under
			mapinfo.custom.atmosphere = { heightFog = copyTable(env.heightFog) }
		end

		if type(env.blockout) == "table" and #env.blockout > 0 then
			local layers = {}
			for i, layer in ipairs(env.blockout) do
				if type(layer) == "table" and type(layer.def) == "string" then
					layers[#layers + 1] =
						{ def = layer.def, yaw = tonumber(layer.yaw) or 0, scale = tonumber(layer.scale) or 1 }
					reference("blockout models", layer.def)
				end
			end
			emitTable("mapconfig/blockout.lua", header, { version = 1, layers = layers })
			report.sections.blockout = format("mapconfig/blockout.lua (%d layers)", #layers)
		end

		-- the skybox: the project names a file in the user's library; it ships inside the map
		local sky = (type(env.skybox) == "string" and env.skybox ~= "" and env.skybox) or map.skybox
		if type(sky) == "string" and sky ~= "" then
			local data = libraryFile(sky)
			if data then
				emit("maps/" .. basename(sky), data)
				A.skyBox = basename(sky)
				report.sections.skybox = "maps/" .. basename(sky)
			else
				report.missing[#report.missing + 1] = "skybox " .. sky
			end
		end
		report.sections.environment = "mapinfo.lua lighting, atmosphere, water, splats"
			.. (mapinfo.custom.atmosphere and ", custom.atmosphere.heightFog" or "")
	else
		note("no environment section: the engine's default lighting, atmosphere and water")
	end

	-- Splats: the distribution texture (both renderers read it) + DNTS sets (legacy renderer only) --
	local splatFile = sectionFile("splat")
	if splatFile then
		local splatName = base .. "_splat.png"
		if copyFromProject(splatFile, "maps/" .. splatName) then
			mapinfo.resources.splatDistrTex = splatName
			report.sections.splat = "maps/" .. splatName
		end
	end
	local dnts = type(map.dnts) == "table" and map.dnts or nil
	if dnts and sectionFile("tileset") then
		dnts = nil
		report.sections.dnts = "not shipped: the tileset renderer does not draw them"
	end
	-- the engine loads the distribution only when a detail or DNTS texture is named
	-- (SMFReadMap), and the tileset shader samples it: a 1x1 grey detail stands in
	if not dnts and mapinfo.resources.splatDistrTex and sectionFile("tileset") then
		emit("maps/" .. FLAT_DETAIL_NAME, FLAT_DETAIL_PNG)
		mapinfo.resources.splatDetailTex = FLAT_DETAIL_NAME
	end
	if dnts then
		local function dntsFile(path)
			if type(path) ~= "string" or path == "" then
				return nil
			end
			local candidates = { path, "assets/dnts/" .. basename(path) }
			if dnts.set then
				candidates[#candidates + 1] = "assets/dnts/" .. tostring(dnts.set) .. "/" .. basename(path)
			end
			for _, rel in ipairs(candidates) do
				local data = projectFile(rel)
				if data then
					emit("maps/" .. basename(path), data)
					return basename(path)
				end
			end
			report.missing[#report.missing + 1] = "DNTS texture " .. path
			return nil
		end
		if type(dnts.textures) == "table" then
			for ch = 1, 4 do
				mapinfo.resources["splatDetailNormalTex" .. ch] = dntsFile(dnts.textures[ch])
			end
		end
		mapinfo.resources.splatDetailTex = dntsFile(dnts.detail)
		-- the set's defaults only fill in: the environment's values are what the panel tuned
		mapinfo.splats.texScales = mapinfo.splats.texScales or vec(dnts.scales, 4)
		mapinfo.splats.texMults = mapinfo.splats.texMults or vec(dnts.mults, 4)
		if dnts.diffuse_alpha ~= nil and mapinfo.resources.splatDetailNormalDiffuseAlpha == nil then
			mapinfo.resources.splatDetailNormalDiffuseAlpha = (tonumber(dnts.diffuse_alpha) or 0) > 0
		end
		report.sections.dnts = "maps/ (splat detail textures, copied from the project)"
	end

	-- Start positions and boxes -------------------------------------------------
	local spFile = sectionFile("startpos")
	if spFile then
		local positions = projectTable(spFile)
		if positions then
			local list = {}
			for _, p in pairs(positions) do
				if type(p) == "table" and tonumber(p.x) and tonumber(p.z) then
					list[#list + 1] = p
				end
			end
			table.sort(list, function(a, b)
				local aa, ba = tonumber(a.allyTeam) or 0, tonumber(b.allyTeam) or 0
				if aa ~= ba then
					return aa < ba
				end
				return (tonumber(a.teamSlot) or 0) < (tonumber(b.teamSlot) or 0)
			end)
			for i, p in ipairs(list) do
				mapinfo.teams[i - 1] = {
					startPos = { x = floor(tonumber(p.x)), z = floor(tonumber(p.z)) },
					-- not read by the engine: the editor's import gets the sides back
					allyTeam = tonumber(p.allyTeam),
					teamSlot = tonumber(p.teamSlot),
				}
			end
			if #list > 0 then
				report.sections.startpos = format("mapinfo.lua teams (%d)", #list)
			else
				report.sections.startpos = "empty"
				note("no start positions: fine for a mission, a skirmish on this map needs them")
			end
		end
	end
	local sbFile = sectionFile("startboxes")
	if sbFile then
		local boxes = projectTable(sbFile)
		if boxes and next(boxes) then
			emitTable("mapconfig/map_startboxes.lua", header, boxes)
			report.sections.startboxes =
				"mapconfig/map_startboxes.lua (data for the lobby; the game takes boxes from the start script)"
		elseif boxes then
			report.sections.startboxes = "empty"
		end
	end

	-- Features: positions, rotation, pitch/roll, height and scale -------------
	local featFile = sectionFile("features")
	if featFile then
		local setcfg, err = projectTable(featFile)
		if setcfg then
			local objects = type(setcfg.objectlist) == "table" and setcfg.objectlist or {}
			for _, o in ipairs(objects) do
				reference("features", o.name)
			end
			emitTable("mapconfig/featureplacer/set.lua", header, {
				-- the game's loader reads only marked sets: legacy maps ship their own set.lua for
				-- the old featureplacer gadget, which the game keeps switched off on purpose
				exporter = "terraform-brush",
				format_version = MapExport.FORMAT_VERSION,
				unitlist = setcfg.unitlist or {},
				buildinglist = setcfg.buildinglist or {},
				objectlist = objects,
			}, "setcfg")
			report.sections.features = format("mapconfig/featureplacer/set.lua (%d features)", #objects)
		else
			fail("features: " .. tostring(err))
		end
	end

	-- Tileset look: the section's presence switches the map onto the tileset renderer --
	local tsFile = sectionFile("tileset")
	if tsFile then
		local tileset, err = projectTable(tsFile)
		if tileset then
			tileset.renderer = "tileset"
			tileset.format_version = MapExport.TILESET_FORMAT_VERSION
			reference("biome", tileset.biome)
			local surf = sections.surface
			if type(surf) == "table" and type(surf.file) == "string" then
				if copyFromProject(surf.file, "mapconfig/tileset/surface.png") then
					tileset.surface = "mapconfig/tileset/surface.png"
				end
				if
					projectFile("surface_v4.png")
					and copyFromProject("surface_v4.png", "mapconfig/tileset/surface_v4.png")
				then
					tileset.surface_v4 = "mapconfig/tileset/surface_v4.png"
				end
				local meta = type(surf.meta) == "string" and projectTable(surf.meta) or nil
				if meta then
					tileset.surface_slots = meta
				end
			end
			-- the height-tint ramp image: named from the user's ramp library, it ships inside the map
			if type(tileset.ramp) == "string" and tileset.ramp ~= "" then
				local data = libraryFile(tileset.ramp)
				if data then
					tileset.ramp = "mapconfig/tileset/ramps/" .. basename(tileset.ramp)
					emit(tileset.ramp, data)
				else
					report.missing[#report.missing + 1] = "ramp image " .. tileset.ramp
				end
			end
			emitTable("mapconfig/tileset/tileset.lua", header, tileset)
			report.sections.tileset = "mapconfig/tileset/ (renderer = tileset)"
				.. (tileset.surface and ", surface masks" or "")
				.. (tileset.ramp and tileset.ramp:find("/") and ", ramp image" or "")
		else
			fail("tileset: " .. tostring(err))
		end
	end

	-- Lights, decals, weather, edge extension: one file each -----------------
	local function passThrough(section, rel, describe)
		local file = sectionFile(section)
		if not file then
			return
		end
		local tbl, err = projectTable(file)
		if not tbl then
			fail(section .. ": " .. tostring(err))
			return
		end
		tbl.mapName = nil -- names the session the file was saved in, not this map
		emitTable(rel, header, tbl)
		report.sections[section] = rel .. (describe and describe(tbl) or "")
	end
	passThrough("lights", "mapconfig/lights.lua", function(t)
		return format(" (%d lights)", type(t.lights) == "table" and #t.lights or 0)
	end)
	passThrough("decals", "mapconfig/decals.lua", function(t)
		for _, d in ipairs(t) do
			if type(d) == "table" then
				reference("decal textures", d.tex)
			end
		end
		return format(" (%d decals)", #t)
	end)
	passThrough("weather", "mapconfig/weather.lua", function(t)
		local n = 0
		for _, s in ipairs(type(t.spawners) == "table" and t.spawners or {}) do
			n = n + 1
			for _, ceg in ipairs(type(s.cegs) == "table" and s.cegs or {}) do
				reference("CEGs", ceg)
			end
		end
		return format(" (%d spawners, visual only)", n)
	end)
	passThrough("edge_extension", "mapconfig/edge_extension.lua")

	-- Grass: the Lua grass widget's config + distribution map ------------------
	local grass = sections.grass
	if type(grass) == "table" and type(grass.file) == "string" then
		if copyFromProject(grass.file, "mapconfig/grass_dist.tga") then
			local cfgTbl = type(grass.config) == "string" and projectTable(grass.config) or nil
			local cfg = cfgTbl and cfgTbl.custom and cfgTbl.custom.grassConfig
			cfg = type(cfg) == "table" and copyTable(cfg) or {}
			cfg.grassDistTGA = "mapconfig/grass_dist.tga"
			cfg.patchResolution = tonumber(grass.patch_resolution) or cfg.patchResolution
			mapinfo.custom.grassConfig = cfg
			reference("grass textures", cfg.grassBladeColorTex)
			report.sections.grass = "mapconfig/grass_dist.tga + mapinfo custom.grassConfig"
		end
	end

	-- What stays behind ------------------------------------------------------
	for name in pairs(sections) do
		if not report.sections[name] then
			if name == "units" then
				report.sections.units = "not exported: units belong to a mission's loadout"
			elseif name == "labels" then
				report.sections.labels = "not exported: editor comments"
			elseif name == "surface" then
				report.sections.surface = tsFile and "with the tileset" or "not exported: no tileset section"
			elseif name ~= "heightmap" then
				report.sections[name] = "not exported"
			end
		end
	end
	local captured = manifest.assets and manifest.assets.decals
	if type(captured) == "table" and #captured > 0 then
		note(
			format(
				"%d captured decal texture(s) live in the project's assets/decals: they must be added to the game",
				#captured
			)
		)
	end

	-- mapinfo.lua + compile.json ----------------------------------------------
	local mapinfoText = header
		.. "local mapinfo = "
		.. MapExport.serialize(lowerKeys(mapinfo))
		.. "\n\nreturn mapinfo\n"
	emit("mapinfo.lua", mapinfoText)
	compile.max_metal = mapinfo.maxMetal
	emit("compile.json", MapExport.toJson(compile), true)

	for kind, set in pairs(refSets) do
		local list = {}
		for n in pairs(set) do
			list[#list + 1] = n
		end
		table.sort(list)
		report.references[kind] = list
	end
	table.sort(report.written)
	report.ok = #report.errors == 0

	fs.write(outDir .. "export_report.txt", MapExport.formatReport(report))
	report.files[#report.files + 1] = outDir .. "export_report.txt"
	return report
end

function MapExport.formatReport(report)
	local lines = {
		format("Map export: %s (%s)", report.name, report.ok and "OK" or "FAILED"),
		"",
	}
	local function block(title, list)
		if list and #list > 0 then
			lines[#lines + 1] = title
			for _, s in ipairs(list) do
				lines[#lines + 1] = "  " .. s
			end
			lines[#lines + 1] = ""
		end
	end
	block("Errors:", report.errors)
	block("Missing:", report.missing)
	local names = {}
	for n in pairs(report.sections) do
		names[#names + 1] = n
	end
	table.sort(names)
	local sec = {}
	for _, n in ipairs(names) do
		sec[#sec + 1] = n .. ": " .. report.sections[n]
	end
	block("Sections:", sec)
	block("Notes:", report.notes)
	local kinds = {}
	for k in pairs(report.references) do
		kinds[#kinds + 1] = k
	end
	table.sort(kinds)
	for _, k in ipairs(kinds) do
		block("Game content named (" .. k .. "):", report.references[k])
	end
	block("Archive files:", report.written)
	if report.ok then
		block("Next:", {
			"python tools/map_export/compile_map.py <this folder>",
			"writes the .smf and .smt into archive/maps/ and packs archive/ into "
				.. tostring(report.fileBase)
				.. ".sd7",
		})
	end
	return table.concat(lines, "\n")
end

return MapExport
