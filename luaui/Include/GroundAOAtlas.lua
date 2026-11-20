-- Shared prebuilt/runtime atlas and definition lookup for ground AO plates.
-- License: GNU GPL v2 or later
local GroundAOAtlas = {}

local function normalize(path)
	return path:gsub("\\", "/"):gsub("^%./", ""):gsub("/+", "/"):lower()
end

local function basename(path)
	return path:match("([^/]+)$") or path
end

local function withoutExtension(path)
	return path:gsub("%.[^/%.]+$", "")
end

local function finite(value)
	if type(value) ~= "string" and type(value) ~= "number" then
		return nil
	end
	value = tonumber(value)
	if value and value == value and math.abs(value) < math.huge then
		return value
	end
end

local function positive(value)
	value = finite(value)
	if value and value > 0 and value * 16 < math.huge then
		return value
	end
end

local function dimension(token)
	if token:match("^%d+%.?%d*$") or token:match("^%.%d+$") then
		return positive(token)
	end
end

-- Dimensions are decal extents in 16-elmo units, not image pixels/footprints.
function GroundAOAtlas.ParseFilename(path)
	local stem = basename(normalize(path)):match("^(.*)_aoplane%.[^%.]+$")
	if not stem then
		return nil
	end
	local model, x, z = stem:match("^(.+)_([^_]+)_([^_]+)$")
	if model and dimension(x) and dimension(z) then
		return model, dimension(x), dimension(z)
	end
	return stem
end

local function disabled(value)
	if type(value) == "string" then
		value = value:lower():match("^%s*(.-)%s*$")
	end
	return value == false or value == 0 or value == "0" or value == "false"
end

local function sortedKeys(t)
	local keys = {}
	for key in pairs(t) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

-- Each widget owns one result and must Delete it on shutdown (also safe twice).
function GroundAOAtlas.Create(manifest, directory, definitions, kind)
	local result = { plates = {}, runtimeTexture = nil }
	local entries, identities, aliases, models = {}, {}, {}, {}
	local warned = {}
	directory = normalize(directory):gsub("/$", "")
	local feature = kind == "feature"
	local textureParam = feature and "decalinfo_texfile" or "buildinggrounddecaltype"
	local sizeXParam = feature and "decalinfo_sizex" or "buildinggrounddecalsizex"
	local sizeZParam = feature and "decalinfo_sizez" or "buildinggrounddecalsizey"
	local alphaParam = feature and "decalinfo_alpha" or "buildinggrounddecalalpha"

	local function warn(message)
		if not warned[message] then
			warned[message] = true
			Spring.Echo("Ground AO (" .. kind .. "): " .. message)
		end
	end

	function result:Delete()
		if self.runtimeTexture then
			gl.DeleteTextureAtlas(self.runtimeTexture)
			self.runtimeTexture = nil
		end
	end

	local function addAlias(key, entry)
		if aliases[key] == nil then
			aliases[key] = entry
		elseif aliases[key] ~= entry then
			aliases[key] = false -- ambiguous; never depend on pairs/file order
		end
	end

	local function add(path, uv)
		local key = normalize(path)
		local identity = withoutExtension(key)
		local entry = identities[identity]
		if not entry then
			local model, sizeX, sizeZ = GroundAOAtlas.ParseFilename(path)
			entry = { path = path, key = key, uv = uv, atlasIndex = uv and 0 or 1, sizeX = sizeX, sizeZ = sizeZ }
			identities[identity] = entry
			if model then
				models[model] = models[model] or {}
				models[model][#models[model] + 1] = entry
			end
		end
		entries[key] = entry
		addAlias(basename(key), entry)
		addAlias(basename(identity), entry)
		return entry
	end

	-- Copy and flip legacy UVs locally. require() can return a cached manifest.
	for _, path in ipairs(sortedKeys(manifest)) do
		local uv = manifest[path]
		if type(uv) == "table" and #uv >= 4 then
			add(path, { uv[1], uv[2], 1 - uv[3], 1 - uv[4] })
		end
	end
	local files = VFS.DirList(directory, "*.png", nil, true)
	table.sort(files)
	for _, path in ipairs(files) do
		if normalize(path):match("_aoplane%.png$") then
			add(path)
		end
	end

	local function pathsFor(reference)
		local path = normalize(reference)
		if not path:find("/", 1, true) then
			return { directory .. "/" .. path, path }
		elseif path:sub(1, 13) == "unittextures/" then
			return { path }
		end
		return { path, "unittextures/" .. path }
	end

	-- Explicit PNGs may live outside the conventional directory or have no suffix.
	for _, id in ipairs(sortedKeys(definitions)) do
		local cp = definitions[id].customParams or {}
		local reference = cp[textureParam]
		if type(reference) == "string" and normalize(reference):match("%.png$") then
			for _, path in ipairs(pathsFor(reference)) do
				if VFS.FileExists(path) then
					add(path)
					break
				end
			end
		end
	end

	local function explicit(reference)
		for _, path in ipairs(pathsFor(reference)) do
			local entry = entries[path] or identities[withoutExtension(path)]
			if entry then
				return entry
			end
		end
		if not normalize(reference):find("/", 1, true) then
			return aliases[normalize(reference)] or aliases[withoutExtension(normalize(reference))]
		end
	end

	-- Legacy unit filenames have no sizes. Borrow existing metadata only if all
	-- explicit users of the same texture agree on its physical dimensions.
	local compatibilitySizes = {}
	for _, def in pairs(definitions) do
		local cp = def.customParams or {}
		local reference = cp[textureParam]
		local entry = type(reference) == "string" and explicit(reference)
		local x, z = positive(cp[sizeXParam]), positive(cp[sizeZParam])
		if entry and x and z then
			local previous = compatibilitySizes[entry]
			if previous == nil then
				compatibilitySizes[entry] = { x, z }
			elseif previous and (previous[1] ~= x or previous[2] ~= z) then
				compatibilitySizes[entry] = false
			end
		end
	end

	local function sizes(entry, cp, isExplicit)
		local legacy = compatibilitySizes[entry] or {}
		local fallback = feature and isExplicit and 5 or nil
		return positive(cp[sizeXParam]) or entry.sizeX or legacy[1] or fallback,
			positive(cp[sizeZParam]) or entry.sizeZ or legacy[2] or fallback
	end

	local function automatic(def, cp)
		local keys = { withoutExtension(basename(normalize(def.modelname or ""))), normalize(def.name or "") }
		for _, key in ipairs(keys) do
			local candidates = models[key] or {}
			local selected, selectedX, selectedZ
			-- Prefer size-bearing names over legacy entries for automatic matching.
			for pass = 1, 2 do
				for _, entry in ipairs(candidates) do
					if (pass == 1) == (entry.sizeX ~= nil) then
						local x, z = sizes(entry, cp, false)
						if x and z then
							if selected then
								warn("ambiguous plates for " .. key .. "; set " .. textureParam)
								return nil
							end
							selected, selectedX, selectedZ = entry, x, z
						end
					end
				end
				if selected then
					return selected, selectedX, selectedZ
				end
			end
			if #candidates > 0 then
				warn("no unambiguous physical sizes for " .. key)
			end
		end
	end

	local needed = {}
	for id, def in pairs(definitions) do
		local cp = def.customParams or {}
		local defName = def.name or ("#" .. tostring(id))
		if feature or not disabled(cp.usebuildinggrounddecal) then
			local reference = cp[textureParam]
			local entry, x, z
			if type(reference) == "string" and reference ~= "" then
				entry = explicit(reference)
				if entry then
					x, z = sizes(entry, cp, true)
					if not x or not z then
						warn(
							"missing physical sizes for " .. reference .. " referenced by " .. kind .. "Def " .. defName
						)
					end
				else
					warn("cannot resolve " .. reference .. " referenced by " .. kind .. "Def " .. defName)
				end
			else
				entry, x, z = automatic(def, cp)
			end
			if entry and x and z then
				result.plates[id] = {
					texturePath = entry.path,
					atlasIndex = entry.atlasIndex,
					sizeX = x * 16,
					sizeZ = z * 16,
					alpha = finite(cp[alphaParam]) or 1,
					uv = entry.uv,
				}
				if entry.atlasIndex == 1 then
					needed[entry.key] = entry
				end
			end
		end
	end

	local function buildRuntime()
		if not next(needed) then
			return
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
				warn("runtime atlas unavailable: gl." .. name)
				return
			end
		end
		local maxX = Spring.GetConfigInt("MaxTextureAtlasSizeX", 4096)
		local maxY = Spring.GetConfigInt("MaxTextureAtlasSizeY", 4096)
		if gl.GetNumber then
			local ok, limit = pcall(gl.GetNumber, GL.MAX_TEXTURE_SIZE or 0x0D33)
			if ok and positive(limit) then
				maxX, maxY = math.min(maxX, limit), math.min(maxY, limit)
			end
		end
		local valid = {}
		for _, key in ipairs(sortedKeys(needed)) do
			local entry = needed[key]
			local ok, info = pcall(gl.TextureInfo, entry.path)
			if
				ok
				and type(info) == "table"
				and positive(info.xsize)
				and positive(info.ysize)
				and info.xsize < maxX
				and info.ysize < maxY
			then
				valid[#valid + 1] = entry
			else
				warn("invalid or oversized PNG: " .. entry.path)
			end
		end
		if #valid == 0 then
			return
		end
		-- Legacy allocator: one mip level, transparent gutters, center-based UVs.
		-- Keep the existing compressed/mipmapped DDS separate and untouched.
		local ok, atlas = pcall(gl.CreateTextureAtlas, maxX, maxY, 0)
		if not ok or not atlas then
			warn("could not create runtime atlas: " .. tostring(atlas))
			return
		end
		result.runtimeTexture = atlas
		local added = {}
		for _, entry in ipairs(valid) do
			local addedOK, err = pcall(gl.AddAtlasTexture, atlas, entry.path, entry.key)
			if addedOK then
				added[#added + 1] = entry
			else
				warn("could not add " .. entry.path .. ": " .. tostring(err))
			end
		end
		if #added == 0 then
			result:Delete()
			return
		end
		local finalized, success = pcall(gl.FinalizeTextureAtlas, atlas)
		if not finalized or not success then
			warn("runtime atlas finalization failed; keeping prebuilt plates")
			result:Delete()
			return
		end
		for _, entry in ipairs(added) do
			local found, p, q, s, t = pcall(gl.GetAtlasTexture, atlas, entry.key)
			if found and finite(p) and finite(q) and finite(s) and finite(t) then
				-- PNG rows are already in the source texture's sampling orientation.
				-- Unlike the legacy DDS manifest, these coordinates must not be flipped.
				entry.uv = { p, q, s, t }
			else
				warn("could not query runtime UVs for " .. entry.path)
			end
		end
	end

	buildRuntime()
	local hasRuntimePlate = false
	for id, plate in pairs(result.plates) do
		if plate.atlasIndex == 1 then
			plate.uv = needed[normalize(plate.texturePath)].uv
			if not plate.uv then
				result.plates[id] = nil
			else
				hasRuntimePlate = true
			end
		end
	end
	if not hasRuntimePlate then
		result:Delete()
	end
	return result
end

return GroundAOAtlas
