function widget:GetInfo()
	return {
		name = "Map Transform",
		desc = "Rotates, mirrors and resizes the whole map, carrying every authored layer across and reloading onto the new canvas",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000001, -- after Map Project: it drives that widget's save/open
		enabled = false,
	}
end

-- Horizontal map manipulation for the Terraformer (SCENE > Dimensions).
--
-- Map size and orientation are fixed at load time: the engine builds the
-- heightmap, the metal map, the texture squares and the minimap from the
-- archive when the map is loaded and nothing in Lua can resize them. So the
-- only honest way to turn or resize an authored map is to write the authoring
-- out, transform it, and boot a fresh canvas that reads it back in — which is
-- exactly what the map project format already does for save and load. This
-- widget is the transform in the middle:
--
--   1. save the live session into a staging project (_transform/source)
--   2. rewrite every section of it onto the new canvas (_transform/staged)
--   3. hand the staged project to Map Project, which restarts the engine into
--      a blank map of the new size and replays it
--
-- The user's own project is never touched. After the restart the session holds
-- the transformed map with its original project still as the Save target, so
-- FILE > Save commits the transform and closing without saving discards it.
--
-- Section by section:
--   heightmap   NOT rewritten here. The importer resamples it onto the new grid
--               anyway, so the transform rides along in the pointer file and is
--               applied while the rows stream (see cmd_terraform_brush.lua).
--               Rewriting the PNG would mean a Lua decode + re-encode of up to
--               4M 16-bit samples for nothing.
--   masks       splat / surface / surface_v4 / diffuse squares + channels: a GL
--               blit of the source quad into the destination image, so a turn
--               is a corner permutation and a resize is one bilinear pass.
--   grass       the distribution TGA, permuted in Lua (the loader demands an
--               exact mapSize/patchResolution grid, so it has to be resized).
--   tables      metal, features, units, decals, lights, labels, start positions,
--               start boxes, weather: positions, headings and angles through
--               the shared math, anything off the new canvas dropped.
--   environment sun azimuth turns with the map, so the authored light keeps
--               falling on the terrain the way it was authored.
--   tileset     knobs copied verbatim (they are scales and looks, which mean
--               the same on a turned map) plus the WORLD PATTERN FRAME, which
--               is composed so the shader's automatic placement turns too.
--   the rest    DNTS assets, decal captures: copied verbatim.
--
-- EXPAND is the same machine with TWO placements of the one source instead of
-- one: the map keeps its scale on the side it grew from, and the new half is
-- either left empty or filled with a copy (plain, mirrored across the seam,
-- flipped along it, or both). Every layer is simply replayed once per
-- placement, so a doubling duplicates the features, the metal, the paint and
-- the start positions exactly the way it duplicates the terrain.

local Spring = Spring
local VFS = VFS
local gl = gl
local GL = GL
local BAR = BAR
local Echo = Spring.Echo

-- GL through chunk locals, like the painters: one lookup per call instead of
-- two, and the CI analyzer stops reading the engine stubs' arity.
local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture
local glRenderToTexture = gl.RenderToTexture
local glTexture = gl.Texture
local glTextureInfo = gl.TextureInfo
local glSaveImage = gl.SaveImage
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glTexCoord = gl.TexCoord
local glClear = gl.Clear
local glBlending = gl.Blending
local glCulling = gl.Culling

local MapTransform = VFS.Include("luaui/Include/map_transform.lua")

local PROJECTS_DIR = "MapProjects/"
-- Both live under one folder so a single delete cleans up, and the folder is
-- skipped by the project browser's walk (see cmd_map_project.lua walkProjects).
local TRANSFORM_DIR = "_transform"
local SOURCE_SLUG = TRANSFORM_DIR .. "/source"
local STAGED_SLUG = TRANSFORM_DIR .. "/staged"
local ELMOS_PER_UNIT = 512
local DIFFUSE_SQUARE_DEFAULT = 1024

-- Map units the blank-map generator accepts (must be even; see the New Map
-- dialog, which enforces the same range).
local MIN_UNITS = 4
local MAX_UNITS = 32

---@type table
local job = nil -- nil while idle; every step runs only while it exists
local lastResult = nil

local function echoT(msg)
	Echo("[Map Transform] " .. msg)
end

----------------------------------------------------------------
-- Small file helpers (raw io: the staging copy is written and read back
-- inside one session, where the VFS view of new files is unreliable)
----------------------------------------------------------------

local function readFileBytes(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local data = f:read("*a")
	f:close()
	return data
end

local function writeFileBytes(path, data)
	local f = io.open(path, "wb")
	if not f then
		return false
	end
	f:write(data)
	f:close()
	return true
end

local function copyFile(src, dst)
	local data = readFileBytes(src)
	if not data then
		return false
	end
	return writeFileBytes(dst, data)
end

local function fileExists(path)
	local f = io.open(path, "rb")
	if not f then
		return false
	end
	f:close()
	return true
end

-- Empty a staging folder without caring whether it holds a readable project:
-- a half-written run leaves files that no manifest lists, and a stale diffuse
-- square would be picked up by the loader's glob as if this run had made it.
local function wipeDir(dir)
	for _, p in ipairs(VFS.DirList(dir, "*", VFS.RAW, true) or {}) do
		os.remove(p)
	end
end

local function readLuaFile(path)
	local raw = readFileBytes(path)
	if not raw or raw == "" then
		return nil, "empty"
	end
	raw = raw:gsub("^\239\187\191", "") -- a BOM would kill the 5.1 lexer
	local chunk = loadstring(raw)
	if not chunk then
		return nil, "parse failed"
	end
	local ok, t = pcall(chunk)
	if not ok or type(t) ~= "table" then
		return nil, "not a table"
	end
	return t
end

----------------------------------------------------------------
-- Generic Lua table serialization
--
-- Every section file is a plain `return <table>`, so the transform can read one
-- in, walk it and write it back without knowing the format by heart. The
-- staging copy is deleted after the load and the user's next FILE > Save goes
-- through each tool's own writer, so only parseability matters here — not the
-- byte-for-byte determinism the real project files keep for git.
----------------------------------------------------------------

local function fmtNumber(v)
	if v ~= v or v == math.huge or v == -math.huge then
		return "0"
	end
	if v == math.floor(v) and math.abs(v) < 1e15 then
		return string.format("%d", v)
	end
	return string.format("%.4f", v)
end

-- One recursive function rather than a mutually recursive pair: a forward
-- declaration would read as possibly-nil at every call site.
local function serializeValue(v, indent, out)
	local tv = type(v)
	if tv == "string" then
		out[#out + 1] = string.format("%q", v)
		return
	elseif tv == "number" then
		out[#out + 1] = fmtNumber(v)
		return
	elseif tv == "boolean" then
		out[#out + 1] = v and "true" or "false"
		return
	elseif tv ~= "table" then
		out[#out + 1] = "nil"
		return
	end
	local pad = string.rep("\t", indent)
	out[#out + 1] = "{\n"
	local n = 0
	for i, item in ipairs(v) do
		out[#out + 1] = pad .. "\t"
		serializeValue(item, indent + 1, out)
		out[#out + 1] = ",\n"
		n = i
	end
	local keys = {}
	for k in pairs(v) do
		if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
			keys[#keys + 1] = k
		end
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for _, k in ipairs(keys) do
		if type(k) == "string" then
			out[#out + 1] = pad .. "\t" .. k .. " = "
		else
			out[#out + 1] = pad .. "\t[" .. fmtNumber(k) .. "] = "
		end
		serializeValue(v[k], indent + 1, out)
		out[#out + 1] = ",\n"
	end
	out[#out + 1] = pad .. "}"
end

local function writeLuaFile(path, t)
	local out = { "return " }
	serializeValue(t, 0, out)
	out[#out + 1] = "\n"
	return writeFileBytes(path, table.concat(out))
end

----------------------------------------------------------------
-- Section rewrite rules
--
-- Each rule names only the fields that carry map-space meaning; everything else
-- is copied through untouched, so a format that grows a field keeps it.
--   list     key holding the array of records (nil = the file IS the array)
--   sub      records hold a nested array under this key (start box anchors)
--   pos      {x,z} world-elmo field pairs
--   grid     {x,z} field pairs in grid squares, with the square size
--   heading  engine heading fields (0..65535)
--   rad/deg  angle-about-Y fields in radians / degrees
--   size     {x,z} extent field pairs, scaled with the map
--   radius   isotropic extent fields (scaled by the smaller axis: a circle
--            cannot follow a non-uniform stretch, so keep it inside)
--   tilt     record carries pitch/roll
--   drop     records outside the new canvas are removed
--   reverse  a mirror flips polygon winding, so the anchor order is reversed
--   team     ally-team field, renumbered per copy when a map is duplicated
----------------------------------------------------------------

local FILE_RULES = {
	["metal.lua"] = {
		list = "spots",
		pos = { { "x", "z" } },
		grid = { { "mx", "mz" } },
		gridSize = "metal",
		drop = true,
	},
	["features.lua"] = {
		list = "objectlist",
		pos = { { "x", "z" } },
		heading = { "rot" },
		tilt = true,
		drop = true,
	},
	["units.lua"] = {
		list = "units",
		pos = { { "x", "z" } },
		heading = { "rot" },
		drop = true,
	},
	["decals.lua"] = {
		pos = { { "x", "z" } },
		rad = { "rot" },
		size = { { "sx", "sz" } },
		drop = true,
	},
	["lights.lua"] = {
		list = "lights",
		pos3 = { "pos" },
		deg = { "yaw" },
		radius = { "radius", "beamLength" },
		drop = true,
	},
	["labels.lua"] = {
		list = "labels",
		pos = { { "x", "z" } },
		drop = true,
	},
	["startpos.lua"] = {
		pos = { { "x", "z" } },
		team = "allyTeam",
		drop = true,
	},
	["startboxes.lua"] = {
		sub = "anchors",
		pos = { { "x", "z" } },
		team = "allyTeam",
		reverse = true,
	},
	["weather.lua"] = {
		list = "spawners",
		pos = { { "x", "z" } },
		deg = { "angleDeg" },
		radius = { "radius" },
		drop = true,
	},
}

-- Transform one record in place. Returns false when it fell off the new canvas.
local function transformRecord(rec, rule, T, gridSquare)
	---@type boolean
	local kept = true
	for _, pair in ipairs(rule.pos or {}) do
		local x, z = tonumber(rec[pair[1]]), tonumber(rec[pair[2]])
		if x and z then
			local dx, dz, inside = T:srcToDst(x, z)
			rec[pair[1]], rec[pair[2]] = dx, dz
			if rule.drop and not inside then
				kept = false
			end
		end
	end
	for _, key in ipairs(rule.pos3 or {}) do
		local p = rec[key]
		if type(p) == "table" and tonumber(p[1]) and tonumber(p[3]) then
			local dx, dz, inside = T:srcToDst(p[1], p[3])
			p[1], p[3] = dx, dz
			if rule.drop and not inside then
				kept = false
			end
		end
	end
	for _, pair in ipairs(rule.grid or {}) do
		local gx, gz = tonumber(rec[pair[1]]), tonumber(rec[pair[2]])
		if gx and gz and gridSquare and gridSquare > 0 then
			-- Square centre through the transform, then back to a square index:
			-- corners land on a boundary and round unpredictably.
			local dx, dz, inside = T:srcToDst((gx + 0.5) * gridSquare, (gz + 0.5) * gridSquare)
			rec[pair[1]] = math.floor(dx / gridSquare)
			rec[pair[2]] = math.floor(dz / gridSquare)
			if rule.drop and not inside then
				kept = false
			end
		end
	end
	for _, key in ipairs(rule.heading or {}) do
		if tonumber(rec[key]) then
			rec[key] = T:heading(rec[key])
		end
	end
	for _, key in ipairs(rule.rad or {}) do
		if tonumber(rec[key]) then
			rec[key] = T:angleRad(rec[key])
		end
	end
	for _, key in ipairs(rule.deg or {}) do
		if tonumber(rec[key]) then
			rec[key] = T:angleDeg(rec[key])
		end
	end
	local sx, sz = T:sizeScale()
	for _, pair in ipairs(rule.size or {}) do
		if tonumber(rec[pair[1]]) then
			rec[pair[1]] = rec[pair[1]] * sx
		end
		if tonumber(rec[pair[2]]) then
			rec[pair[2]] = rec[pair[2]] * sz
		end
	end
	local iso = math.min(sx, sz)
	for _, key in ipairs(rule.radius or {}) do
		if tonumber(rec[key]) then
			rec[key] = rec[key] * iso
		end
	end
	if rule.tilt then
		local p, r = T:tilt(rec.pitch, rec.roll)
		if rec.pitch then
			rec.pitch = p
		end
		if rec.roll then
			rec.roll = r
		end
	end
	return kept
end

-- Highest value a field holds across the records, for the team renumbering
-- below (-1 when the field is absent, so the first copy starts at 0).
local function maxField(list, key)
	local top = -1
	for _, rec in ipairs(list) do
		local v = type(rec) == "table" and tonumber(rec[key]) or nil
		if v and v > top then
			top = v
		end
	end
	return top
end

-- Shallow copy: records are flat field tables, except for the start box anchor
-- list, which is copied element by element.
local function copyRecord(rec, subKey)
	local out = {}
	for k, v in pairs(rec) do
		out[k] = v
	end
	if subKey and type(rec[subKey]) == "table" then
		local anchors = {}
		for i, a in ipairs(rec[subKey]) do
			local one = {}
			for k, v in pairs(a) do
				one[k] = v
			end
			anchors[i] = one
		end
		out[subKey] = anchors
	end
	return out
end

-- Returns kept, dropped. Every record is replayed once per placement, so an
-- expansion duplicates the layer the same way it duplicates the terrain.
local function transformSectionFile(srcPath, dstPath, name, placements, gridSquare)
	local data, err = readLuaFile(srcPath)
	if not data then
		return nil, err
	end
	local rule = FILE_RULES[name]
	if not rule then
		return nil, "no rule"
	end
	local list = rule.list and data[rule.list] or data
	if type(list) ~= "table" then
		return nil, "no records"
	end
	local kept, dropped = 0, 0
	local out = {}
	-- Copies of a start position or a box would land on the team the original
	-- belongs to; shift each copy past the highest team in the source so a
	-- doubled map comes out with somewhere for the extra players to stand.
	local teamShift = 0
	if rule.team and #placements > 1 then
		teamShift = maxField(list, rule.team) + 1
	end
	for pass, T in ipairs(placements) do
		for _, rec in ipairs(list) do
			if type(rec) ~= "table" then
				if pass == 1 then
					out[#out + 1] = rec
				end
			else
				local work = (pass == 1) and rec or copyRecord(rec, rule.sub)
				if rule.team and pass > 1 and tonumber(work[rule.team]) then
					work[rule.team] = work[rule.team] + teamShift * (pass - 1)
				end
				local keepIt = true
				if rule.sub then
					local anchors = work[rule.sub]
					if type(anchors) == "table" then
						for _, a in ipairs(anchors) do
							transformRecord(a, rule, T, gridSquare)
						end
						if rule.reverse and (T.mirrorX or T.mirrorZ) then
							local rev = {}
							for i = #anchors, 1, -1 do
								rev[#rev + 1] = anchors[i]
							end
							work[rule.sub] = rev
						end
					end
				else
					keepIt = transformRecord(work, rule, T, gridSquare)
				end
				if keepIt then
					out[#out + 1] = work
					kept = kept + 1
				else
					dropped = dropped + 1
				end
			end
		end
	end
	if rule.list then
		data[rule.list] = out
	else
		data = out
	end
	if rule.gridSize and gridSquare and gridSquare > 0 and type(data) == "table" then
		-- The metal file carries its own grid header. Nothing reads it back
		-- (the loader replays mx/mz), but a stale one is still a lie. Every
		-- placement shares one destination, so the first one speaks for all.
		data.width = math.floor(placements[1].dstW / gridSquare)
		data.height = math.floor(placements[1].dstH / gridSquare)
		data.squareSize = gridSquare
	end
	if not writeLuaFile(dstPath, data) then
		return nil, "write failed"
	end
	return kept, dropped
end

----------------------------------------------------------------
-- Image transform (GL)
--
-- One quad: the SOURCE image's own corners, placed where the transform puts
-- them on the destination. A quarter turn is then a corner permutation, a
-- resize is one bilinear pass, a crop is clipped by the viewport, and an
-- extended canvas keeps the cleared background (for a paint mask "nothing" is
-- the right answer — the heightmap, where it is not, clamps instead).
----------------------------------------------------------------

local function drawSourceQuad(T, texName, srcRect, dstRect)
	-- srcRect/dstRect: {x0,z0,x1,z1} in source / destination ELMOS. UVs are the
	-- source rect's own corners, so the caller can blit a whole map or one
	-- diffuse square with the same code.
	local sw = srcRect[3] - srcRect[1]
	local sh = srcRect[4] - srcRect[2]
	local dw = dstRect[3] - dstRect[1]
	local dh = dstRect[4] - dstRect[2]
	if sw <= 0 or sh <= 0 or dw <= 0 or dh <= 0 then
		return
	end
	local function corner(u, v)
		local dx, dz = T:srcToDst(srcRect[1] + u * sw, srcRect[2] + v * sh)
		glTexCoord(u, v)
		glVertex((dx - dstRect[1]) / dw * 2 - 1, (dz - dstRect[2]) / dh * 2 - 1)
	end
	glTexture(0, texName)
	glBeginEnd(GL.QUADS, function()
		corner(0, 0)
		corner(1, 0)
		corner(1, 1)
		corner(0, 1)
	end)
	glTexture(0, false)
end

-- Blit a list of source images into one destination image and save it.
-- pieces: { {path, srcRect, T}, ... } — each piece carries the placement that
-- puts it on the destination, so one image can hold both halves of an
-- expansion. dstRect is the destination image's own elmo rect.
local function renderImage(pieces, dstRect, dstW, dstH, outPath)
	local fbo = glCreateTexture(dstW, dstH, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL.RGBA8,
	})
	if not fbo then
		return false, "could not create the destination texture"
	end
	---@type boolean
	local saved = false
	glRenderToTexture(fbo, function()
		glClear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		glBlending(false)
		glCulling(false)
		for _, piece in ipairs(pieces) do
			local texName = ":l:" .. piece.path
			if glTexture(texName) then
				glTexture(false)
				drawSourceQuad(piece.T, texName, piece.srcRect, dstRect)
				glDeleteTexture(texName)
			end
		end
		glBlending(true)
		saved = glSaveImage(0, 0, dstW, dstH, outPath, { yflip = false, alpha = true }) and true or false
	end)
	glDeleteTexture(fbo)
	return saved and true or false
end

-- A full-map mask is a grid over the map, in one of two shapes: a texel grid
-- (extent/step, the splat distribution) or a VERTEX grid (extent/step + 1, the
-- tileset variant mask, which is per heightmap vertex). Scaling the pixel count
-- proportionally gets the second one wrong by a texel - a 1025-tall mask on a
-- map that doubled came out 2050 where the new map's own grid is 2049, and the
-- painter then rescaled the whole mask by half a texel on load. Recover the
-- step from the source instead, and lay the destination out on the same step.
---@return number
local function maskAxis(px, srcExtent, dstExtent)
	if px > 1 and srcExtent > 0 then
		local step = srcExtent / (px - 1)
		if step == math.floor(step) and (dstExtent / step) == math.floor(dstExtent / step) then
			return math.floor(dstExtent / step) + 1
		end
	end
	if px > 0 and srcExtent > 0 then
		local step = srcExtent / px
		if step == math.floor(step) and step > 0 then
			return math.max(1, math.floor(dstExtent / step))
		end
	end
	return math.max(1, math.floor(px * (dstExtent / srcExtent) + 0.5))
end

-- gl.TextureInfo on a file name only answers once the file has been bound
-- (same order the splat painter's loader uses).
local function imageSize(path)
	local texName = ":l:" .. path
	if not glTexture(texName) then
		return nil
	end
	glTexture(false)
	local info = glTextureInfo(texName)
	glDeleteTexture(texName)
	if info and info.xsize and info.xsize > 0 then
		return info.xsize, info.ysize
	end
	return nil
end

----------------------------------------------------------------
-- Grass distribution TGA (8-bit, one byte per patch, row major)
----------------------------------------------------------------

local function transformGrassTGA(srcPath, dstPath, placements, dstW, dstH)
	local tex, err = BAR.Utilities.LoadTGA(srcPath)
	if not tex then
		return nil, tostring(err)
	end
	local sw, sh = tex.width, tex.height
	if not (sw and sh and sw > 0 and sh > 0) then
		return nil, "bad header"
	end
	-- The loader insists on exactly mapSize/patchResolution, so the grid is
	-- rebuilt at the destination's resolution rather than permuted in place.
	local out = BAR.Utilities.NewTGA(dstW, dstH, tex.channels or 1)
	local first = placements[1]
	local elmoPerX = first.dstW / dstW
	local elmoPerZ = first.dstH / dstH
	local chans = tex.channels or 1
	for y = 1, dstH do
		local row = out[y]
		for x = 1, dstW do
			local wx, wz = (x - 0.5) * elmoPerX, (y - 0.5) * elmoPerZ
			local value = 0
			-- Placements do not overlap, so the first one that covers this
			-- patch owns it; a patch no placement covers stays bare.
			for _, T in ipairs(placements) do
				local sx, sz, inside = T:dstToSrc(wx, wz)
				if inside then
					local gx = math.floor(sx / T.srcW * sw) + 1
					local gy = math.floor(sz / T.srcH * sh) + 1
					if gx < 1 then
						gx = 1
					elseif gx > sw then
						gx = sw
					end
					if gy < 1 then
						gy = 1
					elseif gy > sh then
						gy = sh
					end
					value = tex[gy][(gx - 1) * chans + 1] or 0
					break
				end
			end
			for k = 1, chans do
				row[(x - 1) * chans + k] = value
			end
		end
	end
	local saveErr = BAR.Utilities.SaveTGA(out, dstPath)
	if saveErr then
		return nil, tostring(saveErr)
	end
	return true
end

----------------------------------------------------------------
-- Steps
----------------------------------------------------------------

local function fail(reason)
	echoT("TRANSFORM FAILED: " .. reason)
	lastResult = { done = true, ok = false, reason = reason }
	job = nil
end

local function stepSave()
	local c = job.cursor
	---@type table?
	local mp = WG.MapProject
	if not (mp and type(mp.save) == "function") then
		fail("the Map Project widget is not loaded")
		return false
	end
	if not c.started then
		-- Only the capture folder. The staged one still holds the DNTS textures
		-- of a session that itself came out of a transform, and THIS save is
		-- what copies them somewhere that outlives it.
		Spring.CreateDir(PROJECTS_DIR .. TRANSFORM_DIR)
		wipeDir(PROJECTS_DIR .. SOURCE_SLUG .. "/")
		-- internal: this save is scratch, so it must not become the session's
		-- Save target, touch the recent list or clear the unsaved-changes count.
		local ok, receipt = mp.save(SOURCE_SLUG, { internal = true, saveUnits = true })
		if not ok then
			fail("the project save was refused (another save or load running?)")
			return false
		end
		c.started = true
		c.receipt = receipt
		echoT("capturing the current map...")
		return false
	end
	if not (c.receipt and c.receipt.done) then
		return false
	end
	if not c.receipt.ok then
		fail("the project save did not complete")
		return false
	end
	return true
end

local function stepPrepare()
	local srcDir = PROJECTS_DIR .. SOURCE_SLUG .. "/"
	local dstDir = PROJECTS_DIR .. STAGED_SLUG .. "/"
	local manifest = readLuaFile(srcDir .. "project.lua")
	if not (manifest and type(manifest.map) == "table") then
		fail("the staged copy has no readable project.lua")
		return false
	end
	-- Safe here and not a step earlier: the capture above has already copied the
	-- live DNTS set out of this folder.
	wipeDir(dstDir)
	Spring.CreateDir(dstDir)
	Spring.CreateDir(dstDir .. "assets")
	Spring.CreateDir(dstDir .. "assets/dnts")
	Spring.CreateDir(dstDir .. "assets/decals")

	job.srcDir, job.dstDir = srcDir, dstDir
	job.manifest = manifest
	job.sections = manifest.sections or {}

	local srcW = (tonumber(manifest.map.size_x) or 0) * ELMOS_PER_UNIT
	local srcH = (tonumber(manifest.map.size_z) or 0) * ELMOS_PER_UNIT
	if srcW <= 0 or srcH <= 0 then
		fail("the staged copy records no map size")
		return false
	end
	-- One placement per copy of the map on the new canvas: a plain transform
	-- has one, an expansion with a duplicated half has two. job.T is the first
	-- one, kept as its own value rather than read back out of the list: an
	-- indexed read types as possibly-nil and every use of it downstream would
	-- have to be guarded against a case that cannot happen.
	local first = MapTransform.new(job.specs[1], srcW, srcH, job.dstW, job.dstH)
	job.placements = { first }
	for i = 2, #job.specs do
		job.placements[i] = MapTransform.new(job.specs[i], srcW, srcH, job.dstW, job.dstH)
	end
	job.T = first
	job.report = { dropped = 0, kept = 0 }

	-- Work lists live on the job, not the cursor: the pump clears the cursor
	-- between steps, and these are built once for the steps that follow.
	job.tables = {}
	for name in pairs(FILE_RULES) do
		if fileExists(srcDir .. name) then
			job.tables[#job.tables + 1] = name
		end
	end
	table.sort(job.tables)

	job.images = {}
	for _, name in ipairs({ "splat.png", "surface.png", "surface_v4.png" }) do
		if fileExists(srcDir .. name) then
			job.images[#job.images + 1] = { name = name, full = true }
		end
	end
	local diffuse = job.sections.diffuse
	if diffuse and diffuse.dir then
		local sq = tonumber(diffuse.square_size) or DIFFUSE_SQUARE_DEFAULT
		job.diffuseSquare = sq
		Spring.CreateDir(dstDir .. "diffuse")
		-- Source squares present on disk (the glob the loader uses).
		local have = {}
		for _, p in ipairs(VFS.DirList(srcDir .. diffuse.dir, "*.png", VFS.RAW) or {}) do
			local base = p:match("([^/\\]+)$")
			if base then
				-- Matched inside the guard: a pre-declared pair of locals reads
				-- as nil-only to the analyzer, which then calls the test dead.
				local sx, sy = base:match("^sq_(%d+)_(%d+)%.png$")
				if sx and sy then
					have[tonumber(sx) .. ":" .. tonumber(sy)] = diffuse.dir .. base
				elseif base:match("^channel_%w+%.png$") then
					job.images[#job.images + 1] = { name = diffuse.dir .. base, full = true, subdir = "diffuse" }
				end
			end
		end
		job.diffuseHave = have
		-- Destination squares, each pulling from whichever source squares reach
		-- into it.
		local nx = math.floor(job.dstW / sq)
		local nz = math.floor(job.dstH / sq)
		for j = 0, nz - 1 do
			for i = 0, nx - 1 do
				job.images[#job.images + 1] = { square = true, i = i, j = j, sq = sq, dir = diffuse.dir }
			end
		end
	end

	-- Everything else rides across untouched. The list is built from the
	-- manifest rather than hardcoded, so a section added to the project format
	-- later survives a transform (unturned, but present) instead of vanishing
	-- from the staged copy; the named extras are the siblings no section points
	-- at (the heightmap's range sidecar, the SURFACE slot assignment, the grass
	-- settings beside its distribution).
	job.copies = {}
	local handled = { ["grass_dist.tga"] = true }
	for _, name in ipairs(job.tables) do
		handled[name] = true
	end
	for _, item in ipairs(job.images) do
		if item.name then
			handled[item.name] = true
		end
	end
	local function addCopy(name)
		if not handled[name] and fileExists(srcDir .. name) then
			handled[name] = true
			job.copies[#job.copies + 1] = name
		end
	end
	-- tileset.lua is NOT a verbatim copy: stepTileset rewrites its pattern frame
	handled["tileset.lua"] = true
	addCopy("heightmap.png")
	addCopy("heightmap.txt")
	addCopy("surface.lua")
	addCopy("grass_config.lua")
	for _, sec in pairs(job.sections) do
		if type(sec) == "table" and type(sec.file) == "string" then
			addCopy(sec.file)
		end
	end
	for _, sub in ipairs({ "assets/dnts", "assets/decals" }) do
		for _, p in ipairs(VFS.DirList(srcDir .. sub .. "/", "*", VFS.RAW) or {}) do
			local base = p:match("([^/\\]+)$")
			if base then
				job.copies[#job.copies + 1] = sub .. "/" .. base
			end
		end
	end
	echoT(
		string.format(
			"%s, %dx%d -> %dx%d units%s",
			job.label or MapTransform.describe(job.specs[1]),
			srcW / ELMOS_PER_UNIT,
			srcH / ELMOS_PER_UNIT,
			job.dstW / ELMOS_PER_UNIT,
			job.dstH / ELMOS_PER_UNIT,
			(#job.placements > 1) and " (both halves)" or ""
		)
	)
	return true
end

local function stepTables()
	local c = job.cursor
	c.i = c.i or 1
	local name = job.tables[c.i]
	if not name then
		return true
	end
	c.i = c.i + 1
	local gridSquare = nil
	if FILE_RULES[name].gridSize == "metal" then
		gridSquare = Game.metalMapSquareSize or 16
	end
	local kept, droppedOrErr =
		transformSectionFile(job.srcDir .. name, job.dstDir .. name, name, job.placements, gridSquare)
	if not kept then
		echoT(
			"WARNING: " .. name .. " could not be transformed (" .. tostring(droppedOrErr) .. "); copying it unchanged"
		)
		copyFile(job.srcDir .. name, job.dstDir .. name)
		return false
	end
	local dropped = tonumber(droppedOrErr) or 0
	job.report.kept = job.report.kept + kept
	job.report.dropped = job.report.dropped + dropped
	if dropped > 0 then
		echoT(string.format("%s: %d kept, %d outside the new canvas and dropped", name, kept, dropped))
	end
	return false
end

local function stepImages()
	local c = job.cursor
	c.i = c.i or 1
	local item = job.images[c.i]
	if not item then
		return true
	end
	c.i = c.i + 1
	local T = job.T
	if item.full then
		local srcPath = job.srcDir .. item.name
		local w, h = imageSize(srcPath)
		if not w then
			echoT("WARNING: could not read " .. item.name .. "; skipped")
			return false
		end
		-- A full-map mask keeps its texel density on the destination's own grid.
		-- A quarter turn feeds the source's X axis into the destination's Z, so
		-- the axes are paired accordingly.
		local dw, dh
		if T.rot == 90 or T.rot == 270 then
			dw = maskAxis(h, T.srcH, T.dstW)
			dh = maskAxis(w, T.srcW, T.dstH)
		else
			dw = maskAxis(w, T.srcW, T.dstW)
			dh = maskAxis(h, T.srcH, T.dstH)
		end
		-- One piece per placement: an expansion paints the same mask into both
		-- halves of the new image.
		local pieces = {}
		for _, placement in ipairs(job.placements) do
			pieces[#pieces + 1] = { path = srcPath, srcRect = { 0, 0, T.srcW, T.srcH }, T = placement }
		end
		local ok = renderImage(pieces, { 0, 0, T.dstW, T.dstH }, dw, dh, job.dstDir .. item.name)
		if not ok then
			echoT("WARNING: " .. item.name .. " could not be written")
		end
		return false
	end
	-- One diffuse square: every source square that reaches into it, through
	-- every placement that puts one there.
	local sq = item.sq
	local dstRect = { item.i * sq, item.j * sq, (item.i + 1) * sq, (item.j + 1) * sq }
	local pieces = {}
	for _, placement in ipairs(job.placements) do
		local sx0, sz0 = placement:dstToSrc(dstRect[1], dstRect[2])
		local sx1, sz1 = placement:dstToSrc(dstRect[3], dstRect[4])
		if sx1 < sx0 then
			sx0, sx1 = sx1, sx0
		end
		if sz1 < sz0 then
			sz0, sz1 = sz1, sz0
		end
		local i0 = math.max(0, math.floor(sx0 / sq))
		local i1 = math.min(math.floor(T.srcW / sq) - 1, math.floor((sx1 - 0.001) / sq))
		local j0 = math.max(0, math.floor(sz0 / sq))
		local j1 = math.min(math.floor(T.srcH / sq) - 1, math.floor((sz1 - 0.001) / sq))
		for j = j0, j1 do
			for i = i0, i1 do
				local rel = job.diffuseHave[i .. ":" .. j] or ""
				if rel ~= "" then
					pieces[#pieces + 1] = {
						path = job.srcDir .. rel,
						srcRect = { i * sq, j * sq, (i + 1) * sq, (j + 1) * sq },
						T = placement,
					}
				end
			end
		end
	end
	if #pieces == 0 then
		return false
	end
	local px = job.diffusePx
	if not px then
		local w = imageSize(pieces[1].path)
		px = w or 512
		job.diffusePx = px
	end
	local outName = string.format("%ssq_%d_%d.png", item.dir, item.i, item.j)
	if not renderImage(pieces, dstRect, px, px, job.dstDir .. outName) then
		echoT("WARNING: diffuse square " .. item.i .. "," .. item.j .. " could not be written")
	else
		job.diffuseWritten = (job.diffuseWritten or 0) + 1
	end
	return false
end

local function stepGrass()
	local sec = job.sections.grass
	if not (sec and sec.file and fileExists(job.srcDir .. sec.file)) then
		return true
	end
	local res = tonumber(sec.patch_resolution) or 32
	local dw = math.floor(job.dstW / res)
	local dh = math.floor(job.dstH / res)
	local ok, err = transformGrassTGA(job.srcDir .. sec.file, job.dstDir .. sec.file, job.placements, dw, dh)
	if not ok then
		echoT("WARNING: grass distribution could not be transformed (" .. tostring(err) .. "); dropped")
		job.dropGrass = true
	end
	return true
end

local function stepCopy()
	local c = job.cursor
	c.i = c.i or 1
	local name = job.copies[c.i]
	if not name then
		return true
	end
	c.i = c.i + 1
	if not copyFile(job.srcDir .. name, job.dstDir .. name) then
		echoT("WARNING: could not copy " .. name)
	end
	return false
end

-- The sun turns with the map so the authored light keeps falling on the terrain
-- the way it was authored. Elevation and colour are untouched.
local function stepEnvironment()
	local srcPath = job.srcDir .. "environment.lua"
	if not fileExists(srcPath) then
		return true
	end
	local dstPath = job.dstDir .. "environment.lua"
	local rot = job.T.rot
	local mirrored = job.T.mirrorX or job.T.mirrorZ
	if rot == 0 and not mirrored then
		copyFile(srcPath, dstPath)
		return true
	end
	local raw = readFileBytes(srcPath)
	if not raw then
		return true
	end
	-- environment.lua is the panel's own snapshot format, so the direction is
	-- rewritten in the text rather than round-tripped through a table.
	local sx, sy, sz = raw:match("sunDir%s*=%s*{%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")
	if sx and sy and sz then
		local T = job.T
		local x = tonumber(sx) or 0
		local z = tonumber(sz) or 0
		-- A direction, not a position: rotate it about the map centre by putting
		-- it through the transform as an offset from the origin.
		local ox, oz = T:srcToDst(T.srcW * 0.5, T.srcH * 0.5)
		local px, pz = T:srcToDst(T.srcW * 0.5 + x * 100, T.srcH * 0.5 + z * 100)
		local ndx = (px - ox) / 100
		local ndz = (pz - oz) / 100
		-- The stretch scales are not part of a direction; renormalise the
		-- horizontal part back to its original length.
		local oldLen = math.sqrt(x * x + z * z)
		local newLen = math.sqrt(ndx * ndx + ndz * ndz)
		if newLen > 1e-6 and oldLen > 1e-6 then
			ndx = ndx / newLen * oldLen
			ndz = ndz / newLen * oldLen
		end
		local replaced = raw:gsub(
			"sunDir%s*=%s*{%s*[%-%d%.]+%s*,%s*[%-%d%.]+%s*,%s*[%-%d%.]+%s*}",
			string.format("sunDir = { %.4f, %s, %.4f }", ndx, sy, ndz),
			1
		)
		writeFileBytes(dstPath, replaced)
		return true
	end
	copyFile(srcPath, dstPath)
	return true
end

-- Tileset knobs ride across untouched - a texture scale or a slope threshold
-- means the same thing on a turned map - with one exception. Everything the
-- shader places WITHOUT the artist (the stagger mask lerps, the fbm fields, the
-- anti-tile warp, the deposit wind) is addressed in WORLD XZ, so a quarter turn
-- slides all of it across terrain that did turn, which is what "the texture is
-- messed up in many areas" looked like on CM02. The WORLD PATTERN FRAME carries
-- the turn into the shader instead: composed here, applied by patternXZ in
-- dev_tileset_terrain.lua, so the map comes out of a turn looking like the map
-- that went in. See MapTransform:composeFrame.
local function stepTileset()
	local srcPath = job.srcDir .. "tileset.lua"
	if not fileExists(srcPath) then
		return true
	end
	local dstPath = job.dstDir .. "tileset.lua"
	local data = readLuaFile(srcPath)
	if type(data) ~= "table" then
		-- unreadable knobs are still better carried across than dropped
		copyFile(srcPath, dstPath)
		echoT("WARNING: tileset.lua did not parse; copied verbatim, its pattern frame is stale")
		return true
	end
	-- EXPAND places the source twice; job.T is the placement that KEEPS the map
	-- (see stepPrepare), so the original half's patterns stay exactly where they
	-- were and the new half continues them rather than mirroring them.
	local m00, m01, m10, m11, tx, tz = job.T:composeFrame(data.pattern_frame)
	if MapTransform.isIdentityFrame(m00, m01, m10, m11, tx, tz) then
		data.pattern_frame = nil
	else
		data.pattern_frame = { m00, m01, m10, m11, tx, tz }
	end
	writeLuaFile(dstPath, data)
	return true
end

local function stepManifest()
	local m = job.manifest
	m.map.size_x = math.floor(job.dstW / ELMOS_PER_UNIT)
	m.map.size_z = math.floor(job.dstH / ELMOS_PER_UNIT)
	m.name = "transform staging"
	-- Opens as the project it came from: FILE > Save writes the transformed map
	-- back there, and an unsaved canvas still has no Save target.
	m.transform_of = job.originSlug or ""
	m.autosave_of = nil
	-- Sections whose file did not survive the rewrite must not be advertised.
	local sections = m.sections or {}
	if job.dropGrass then
		sections.grass = nil
	end
	for key, sec in pairs(sections) do
		if type(sec) == "table" and sec.file and not fileExists(job.dstDir .. sec.file) then
			sections[key] = nil
		end
	end
	if sections.diffuse then
		if (job.diffuseWritten or 0) == 0 then
			sections.diffuse = nil
		else
			sections.diffuse.squares = job.diffuseWritten
		end
	end
	-- Byte counts were the source's; the loader only warns on a mismatch, but a
	-- stale number is a lie either way.
	for _, sec in pairs(sections) do
		if type(sec) == "table" then
			sec.bytes = nil
		end
	end
	m.sections = sections
	if not writeLuaFile(job.dstDir .. "project.lua", m) then
		fail("could not write the staged project.lua")
		return false
	end
	return true
end

local function stepOpen()
	---@type table?
	local mp = WG.MapProject
	if not (mp and type(mp.openStaged) == "function") then
		fail("this build's Map Project widget cannot open a staged project")
		return false
	end
	-- The capture has done its job; the restart only reads the staged copy. It
	-- is left on disk rather than scanned away here: Map Project sweeps both on
	-- the next start that is not a project load.
	-- The heightmap is the one layer not rewritten on disk: the importer
	-- replays it through these placements while it streams. fill_height is
	-- what ground outside every placement becomes — the canvas base for an
	-- expansion with an empty half; absent means "continue the old border",
	-- which is what a nudged edge wants.
	local list = {}
	for i, spec in ipairs(job.specs) do
		local c = MapTransform.canonical(spec)
		list[i] = {
			rot = c.rot,
			mirrorX = c.mirrorX,
			mirrorZ = c.mirrorZ,
			fit = c.fit,
			anchorX = c.anchorX,
			anchorZ = c.anchorZ,
		}
	end
	local ok, err = mp.openStaged(STAGED_SLUG, {
		transform = {
			placements = list,
			src_x = job.T.srcW / ELMOS_PER_UNIT,
			src_z = job.T.srcH / ELMOS_PER_UNIT,
			fill_height = job.fillHeight,
		},
		originSlug = job.originSlug,
	})
	if not ok then
		fail(tostring(err or "the staged project could not be opened"))
		return false
	end
	lastResult = { done = true, ok = true }
	job = nil
	return true
end

local STEPS = {
	{ name = "save", run = stepSave },
	{ name = "prepare", run = stepPrepare },
	{ name = "layers", run = stepTables },
	{ name = "masks", run = stepImages },
	{ name = "grass", run = stepGrass },
	{ name = "assets", run = stepCopy },
	{ name = "environment", run = stepEnvironment },
	{ name = "tileset", run = stepTileset },
	{ name = "manifest", run = stepManifest },
	{ name = "restart", run = stepOpen },
}

----------------------------------------------------------------
-- Entry point
----------------------------------------------------------------

local function canTransform()
	---@type table?
	local mp = WG.MapProject
	if not mp then
		return false, "the Map Project widget is not loaded"
	end
	if type(mp.isBusy) == "function" and mp.isBusy() then
		return false, "a project save or load is running"
	end
	if job then
		return false, "a transform is already running"
	end
	if Spring.IsReplay() then
		return false, "this is a replay"
	end
	return true
end

-- Shared by both entry points: check the session, then start the job.
local function startJob(specs, unitsX, unitsZ, label, fillHeight)
	local ok, why = canTransform()
	if not ok then
		echoT("cannot transform: " .. tostring(why))
		return false, why
	end
	if unitsX < MIN_UNITS or unitsX > MAX_UNITS or unitsZ < MIN_UNITS or unitsZ > MAX_UNITS then
		local msg = string.format("map size must be %d..%d units on both axes", MIN_UNITS, MAX_UNITS)
		echoT("cannot transform: " .. msg)
		return false, msg
	end
	---@type table?
	local mp = WG.MapProject
	job = {
		specs = specs,
		label = label,
		fillHeight = fillHeight,
		dstW = unitsX * ELMOS_PER_UNIT,
		dstH = unitsZ * ELMOS_PER_UNIT,
		originSlug = (mp and mp.current and mp.current()) or nil,
		step = 1,
		cursor = {},
	}
	lastResult = nil
	echoT(label .. "; the session restarts when the new canvas is ready")
	return true
end

-- spec: rot / mirrorX / mirrorZ / fit / anchorX / anchorZ (see map_transform).
-- unitsX, unitsZ: the new map size in 512-elmo map units (even, 4..32).
local function beginTransform(spec, unitsX, unitsZ)
	local ux = math.floor((tonumber(unitsX) or 0) / 2 + 0.5) * 2
	local uz = math.floor((tonumber(unitsZ) or 0) / 2 + 0.5) * 2
	local canonical = MapTransform.canonical(spec or {})
	local probe = MapTransform.new(canonical, Game.mapSizeX, Game.mapSizeZ, ux * ELMOS_PER_UNIT, uz * ELMOS_PER_UNIT)
	if probe:isIdentity() then
		echoT("nothing to do: that is the map you already have")
		return false, "no change"
	end
	return startJob({ canonical }, ux, uz, "transforming the map")
end

-- Double the map along one axis (see MapTransform.expandPlan).
--   dir  "left" | "right" | "up" | "down"
--   copy nil for an empty half, else "none" | "mirror" | "flip" | "both"
local function beginExpand(dir, copy)
	local srcW, srcH = Game.mapSizeX, Game.mapSizeZ
	local plan, dstW, dstH = MapTransform.expandPlan(dir, copy, srcW, srcH)
	local unitsX = math.floor(dstW / ELMOS_PER_UNIT)
	local unitsZ = math.floor(dstH / ELMOS_PER_UNIT)
	if unitsX > MAX_UNITS or unitsZ > MAX_UNITS then
		local msg =
			string.format("doubling would make a %dx%d map and %d units is the limit", unitsX, unitsZ, MAX_UNITS)
		echoT("cannot expand: " .. msg)
		return false, msg
	end
	-- An empty half is an empty CANVAS: flat at the height a New Map starts at,
	-- rather than the old border smeared across it. Read from the session's own
	-- map options, which is where the blank generator put it.
	local fillHeight = nil
	if not copy then
		local mo = Spring.GetMapOptions() or {}
		fillHeight = tonumber(mo.blank_map_height)
		if not fillHeight then
			local lo = Spring.GetGroundExtremes()
			fillHeight = lo or 0
		end
	end
	return startJob(plan, unitsX, unitsZ, MapTransform.describeExpand(dir, copy), fillHeight)
end

----------------------------------------------------------------
-- Pump
----------------------------------------------------------------

-- DrawScreenPost, like the project save: the image steps need a GL context and
-- the Terraformer's FOCUS MODE hides the interface (which skips DrawScreen).
function widget:DrawScreenPost()
	if not job then
		return
	end
	local step = STEPS[job.step]
	if not step then
		fail("ran out of steps")
		return
	end
	local ok, done = pcall(step.run)
	if not ok then
		fail(step.name .. " step errored: " .. tostring(done))
		return
	end
	if done and job then
		job.step = job.step + 1
		job.cursor = {}
	end
end

function widget:Initialize()
	WG.MapTransform = {
		-- apply(spec, unitsX, unitsZ) -> accepted, reason
		apply = beginTransform,
		-- expand(dir, copy) -> accepted, reason: double the map one way, with
		-- the new half empty or holding a copy of it
		expand = beginExpand,
		-- can() -> ok, reason: why the APPLY button is greyed out
		can = canTransform,
		-- (step, total, stepName) while running, nil when idle
		progress = function()
			if not job then
				return nil
			end
			local i = math.min(job.step, #STEPS)
			return i, #STEPS, STEPS[i] and STEPS[i].name or ""
		end,
		isBusy = function()
			return job ~= nil
		end,
		lastResult = function()
			return lastResult
		end,
		-- The panel draws its preview from the same math the transform runs on.
		math = MapTransform,
	}
end

function widget:Shutdown()
	WG.MapTransform = nil
end
