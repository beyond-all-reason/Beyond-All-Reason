-- Paired prebuilt/runtime atlases for the normalmapped decal renderer.
-- License: GNU GPL v2 or later
local DecalAtlas = {}

local function normalize(path)
	return path:gsub("\\", "/"):gsub("^%./", ""):gsub("/+", "/"):lower()
end

local function identity(path)
	return normalize(path):gsub("%.[^/%.]+$", "")
end

local function sortedKeys(t)
	local keys = {}
	for key in pairs(t) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function DecalAtlas.Create(diffuse, normal, directory)
	local result = { entries = {}, runtimeAlbedo = nil, runtimeNormal = nil, runtimeCount = 0 }
	local baked, normals, warned = {}, {}, {}
	local function warn(message)
		if not warned[message] then
			warned[message] = true
			Spring.Echo("Decals GL4 atlas: " .. message)
		end
	end

	function result:Get(path)
		if type(path) ~= "string" then
			return nil
		end
		local key = normalize(path)
		return self.entries[key] or baked[identity(key)] or self.entries[identity(key) .. ".png"]
	end

	function result:Delete()
		for _, field in ipairs({ "runtimeAlbedo", "runtimeNormal" }) do
			if self[field] then
				gl.DeleteTextureAtlas(self[field])
				self[field] = nil
			end
		end
	end

	for path, uv in pairs(normal) do
		if type(uv) == "table" and #uv >= 4 then
			normals[identity(path)] = uv
		end
	end
	for _, path in ipairs(sortedKeys(diffuse)) do
		local uv = diffuse[path]
		if type(uv) == "table" and #uv >= 6 and normals[identity(path):gsub("_a$", "_n")] then
			-- Keep the legacy inset and Y flip, without mutating require()'s cache.
			local px = (8 / 512) * uv[5] / diffuse.width
			local py = (8 / 512) * uv[6] / diffuse.height
			local entry = {
				key = normalize(path),
				atlasIndex = 0,
				uv = { uv[1] + px, uv[2] - px, 1 - uv[3] - py, 1 - uv[4] + py },
			}
			result.entries[entry.key] = entry
			baked[identity(path)] = entry
		end
	end

	-- Match full paths, including subdirectories: scars and footprints can share names.
	local files = VFS.DirList(directory, "*.png", nil, true)
	local pngs, needed = {}, {}
	for _, path in ipairs(files) do
		pngs[normalize(path)] = path
	end
	for _, key in ipairs(sortedKeys(pngs)) do
		if key:match("_a%.png$") and not baked[identity(key)] then
			local normalPath = pngs[key:gsub("_a%.png$", "_n.png")]
			if normalPath then
				needed[#needed + 1] = { key = key, albedo = pngs[key], normal = normalPath }
			else
				warn("missing normal PNG for " .. pngs[key])
			end
		end
	end
	if #needed == 0 then
		return result
	end
	for _, name in ipairs({
		"CreateTextureAtlas",
		"AddAtlasTexture",
		"FinalizeTextureAtlas",
		"GetAtlasTexture",
		"DeleteTextureAtlas",
		"TextureInfo",
	}) do
		if not gl[name] then
			warn("runtime atlases unavailable: gl." .. name)
			return result
		end
	end
	local maxX = Spring.GetConfigInt("MaxTextureAtlasSizeX", 4096)
	local maxY = Spring.GetConfigInt("MaxTextureAtlasSizeY", 4096)
	if gl.GetNumber then
		local ok, limit = pcall(gl.GetNumber, GL.MAX_TEXTURE_SIZE or 0x0D33)
		if ok and finite(limit) and limit > 0 then
			maxX, maxY = math.min(maxX, limit), math.min(maxY, limit)
		end
	end
	local valid = {}
	for _, pair in ipairs(needed) do
		local usable = true
		for _, path in ipairs({ pair.albedo, pair.normal }) do
			local ok, info = pcall(gl.TextureInfo, path)
			if
				not (
					ok
					and type(info) == "table"
					and finite(info.xsize)
					and finite(info.ysize)
					and info.xsize > 0
					and info.ysize > 0
					and info.xsize < maxX
					and info.ysize < maxY
				)
			then
				warn("invalid or oversized PNG: " .. path)
				usable = false
			end
		end
		if usable then
			valid[#valid + 1] = pair
		end
	end
	if #valid == 0 then
		return result
	end

	local function build()
		-- Equal image sizes and identical insertion order give both atlases the same layout.
		-- Allocator 0 uses one mip level, transparent gutters and texel-center UVs.
		result.runtimeAlbedo = assert(gl.CreateTextureAtlas(maxX, maxY, 0))
		result.runtimeNormal = assert(gl.CreateTextureAtlas(maxX, maxY, 0))
		for _, pair in ipairs(valid) do
			gl.AddAtlasTexture(result.runtimeAlbedo, pair.albedo, pair.key)
			gl.AddAtlasTexture(result.runtimeNormal, pair.normal, pair.key)
		end
		assert(gl.FinalizeTextureAtlas(result.runtimeAlbedo), "albedo finalization failed")
		assert(gl.FinalizeTextureAtlas(result.runtimeNormal), "normal finalization failed")
		local entries = {}
		for _, pair in ipairs(valid) do
			local p, q, s, t = gl.GetAtlasTexture(result.runtimeAlbedo, pair.key)
			assert(finite(p) and finite(q) and finite(s) and finite(t), "missing UVs for " .. pair.key)
			-- Reverse Y within this rectangle to match the baked decal orientation.
			-- A global 1-y would select a different row of the runtime atlas.
			local px, py = (q - p) * (8 / 512), (t - s) * (8 / 512)
			entries[pair.key] = {
				key = pair.key,
				atlasIndex = 1,
				uv = { p + px, q - px, t - py, s + py },
			}
		end
		return entries
	end
	local ok, entries = pcall(build)
	if ok then
		for key, entry in pairs(entries) do
			result.entries[key] = entry
			result.runtimeCount = result.runtimeCount + 1
		end
	else
		warn("runtime atlas pair failed; keeping baked decals: " .. tostring(entries))
		result:Delete()
	end
	return result
end

return DecalAtlas
