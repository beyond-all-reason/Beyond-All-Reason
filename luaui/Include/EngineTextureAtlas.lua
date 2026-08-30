local EngineTextureAtlas = {}

local cache = {}

local Atlas = {}
Atlas.__index = Atlas

local function normalizeName(name)
	if type(name) ~= "string" or name == "" then
		error("engine texture atlas name must be a non-empty string", 3)
	end
	name = name:lower()
	if name:sub(1, 7) == "$atlas:" then
		name = name:sub(8)
	end
	return name
end

function Atlas:Get(entryName)
	if type(entryName) ~= "string" or entryName == "" then
		error("engine texture atlas entry name must be a non-empty string", 2)
	end
	local entry = self.entries[entryName:lower()]
	if entry == nil then
		error(("engine texture atlas '%s' has no entry '%s'"):format(self.name, entryName), 2)
	end
	return entry[1], entry[2], entry[3], entry[4], entry[5], entry[6], entry[7]
end

function Atlas:Bind(textureUnit)
	if gl == nil or gl.Texture == nil then
		error("gl.Texture is unavailable", 2)
	end
	gl.Texture(textureUnit or 0, self.reference)
end

function Atlas:GetInfo()
	return self.info
end

function Atlas:GetReference()
	return self.reference
end

function EngineTextureAtlas.Get(name)
	name = normalizeName(name)
	if cache[name] ~= nil then
		return cache[name]
	end
	if gl == nil or gl.GetEngineAtlasInfo == nil or gl.GetEngineAtlasTexturesV2 == nil then
		error("this Recoil version does not provide engine texture atlas metadata", 2)
	end
	local reference = "$atlas:" .. name
	local info = gl.GetEngineAtlasInfo(reference)
	local entries = gl.GetEngineAtlasTexturesV2(reference)
	if type(info) ~= "table" or type(entries) ~= "table" then
		error(("engine texture atlas '%s' is unavailable or not finalized"):format(name), 2)
	end
	local atlas = setmetatable({
		name = name,
		reference = reference,
		info = info,
		entries = entries,
	}, Atlas)
	cache[name] = atlas
	return atlas
end

function EngineTextureAtlas.ClearCache()
	cache = {}
end

return EngineTextureAtlas
