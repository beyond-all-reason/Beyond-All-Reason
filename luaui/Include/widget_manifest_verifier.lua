local base64 = require("common/luaUtilities/base64")

-- The content hash must stay in sync with the catalog builder, which computes it when publishing:
-- https://github.com/beyond-all-reason/BAR-Widgets (builder/src/contentHash.ts). Any change to what is
-- hashed or how it is framed needs a new format name on both sides, and is not backwards compatible:
-- widgets whose catalog entry was built with the other format fail to verify. The test vector in
-- spec/luaui/widget_manifest_verifier_spec.lua is the builder's, so the two can be compared.
local HASH_FORMAT = "bar-widget-content-v1"
local CATALOG_FILENAME = "manifests.json"
local SIGNATURE_FILENAME = "manifests.json.sig"

-- Ed25519 keys, hex, whose signature on a catalog is trusted. They ship in the game archive, which is
-- what makes them trustworthy: never read one from a modoption, config or raw file. To rotate, add the
-- new key, and drop the old one once catalogs signed with it are no longer about.
local TRUSTED_PUBLIC_KEYS = {
	"31babb2d26cc7867b51d2205018aeacdc08103fbf98b42f882ed8b18fca81693",
}

local function decodeHex(value)
	if type(value) ~= "string" or #value % 2 ~= 0 or value:find("[^0-9a-fA-F]") then
		return nil
	end

	local bytes = {}
	for index = 1, #value, 2 do
		bytes[#bytes + 1] = string.char(tonumber(value:sub(index, index + 1), 16) or 0)
	end
	return table.concat(bytes)
end

-- The shared decoder drops what it does not understand, so the shape is checked here first: this is
-- the only caller that wants a malformed signature refused rather than quietly shortened.
local function decodeBase64(value)
	if type(value) ~= "string" then
		return nil
	end

	value = value:gsub("%s", "")
	if #value % 4 ~= 0 or not value:match("^[A-Za-z0-9+/]+=?=?$") then
		return nil
	end

	return base64.Decode(value)
end

local function appendField(parts, value)
	parts[#parts + 1] = VFS.PackU32(#value)
	parts[#parts + 1] = value
end

local function calculateWidgetHash(widgetDirectory)
	local files = VFS.DirList(widgetDirectory, "*", VFS.RAW, true) or {}
	table.sort(files)

	local seenPaths = {}
	local parts = {}
	appendField(parts, HASH_FORMAT)

	for _, filename in ipairs(files) do
		if filename:sub(1, #widgetDirectory) ~= widgetDirectory then
			return nil, "file escaped widget directory: " .. filename
		end

		local relativePath = filename:sub(#widgetDirectory + 1):gsub("\\", "/")
		local collisionKey = relativePath:lower()
		if seenPaths[collisionKey] then
			return nil, "ambiguous widget paths: " .. seenPaths[collisionKey] .. " and " .. relativePath
		end
		seenPaths[collisionKey] = relativePath

		local contents = VFS.LoadFile(filename, VFS.RAW)
		if contents == nil then
			return nil, "could not read " .. relativePath
		end
		appendField(parts, relativePath)
		appendField(parts, contents)
	end

	return "sha512:" .. VFS.CalculateHash(table.concat(parts), 1)
end

local function loadCatalog(widgetDirectory, publicKeysHex)
	local catalog = VFS.LoadFile(widgetDirectory .. CATALOG_FILENAME, VFS.RAW)
	local encodedSignature = VFS.LoadFile(widgetDirectory .. SIGNATURE_FILENAME, VFS.RAW)
	local signature = decodeBase64(encodedSignature)

	if not catalog then
		return nil, "missing " .. CATALOG_FILENAME
	end
	if not signature or #signature ~= 64 then
		return nil, "invalid base64 signature in " .. SIGNATURE_FILENAME
	end
	-- Every key is checked before any is used: a bad one is a mistake in the game, not in the catalog
	local publicKeys = {}
	for _, publicKeyHex in ipairs(publicKeysHex) do
		local publicKey = decodeHex(publicKeyHex)
		if not publicKey or #publicKey ~= 32 then
			return nil, "invalid embedded Ed25519 public key"
		end
		publicKeys[#publicKeys + 1] = publicKey
	end
	if #publicKeys == 0 then
		return nil, "no embedded Ed25519 public key"
	end
	if type(VFS.VerifyEd25519) ~= "function" then
		return nil, "engine does not support Ed25519 verification"
	end
	local signedByTrustedKey = false
	for _, publicKey in ipairs(publicKeys) do
		if VFS.VerifyEd25519(catalog, signature, publicKey) then
			signedByTrustedKey = true
			break
		end
	end
	if not signedByTrustedKey then
		return nil, "invalid signature for " .. CATALOG_FILENAME
	end

	local success, manifests = pcall(Json.decode, catalog)
	if not success or type(manifests) ~= "table" then
		return nil, "invalid JSON in " .. CATALOG_FILENAME
	end
	return manifests
end

-- options.requireAnonymousSafe leaves out every widget whose manifest entry does not set anonymous_safe,
-- the reviewer's word that it hides players the way the game's own widgets do in anonymous mode. Without 
-- the option the field is ignored and they load as before. options.publicKeys stands in for the trusted
-- keys, for specs.
local function getVerifiedWidgetFiles(widgetDirectory, options)
	options = options or {}
	local requireAnonymousSafe = options.requireAnonymousSafe
	local manifests, catalogError = loadCatalog(widgetDirectory, options.publicKeys or TRUSTED_PUBLIC_KEYS)
	if not manifests then
		return nil, { catalogError }
	end

	local existingDirectories = {}
	for _, name in ipairs(VFS.SubDirs(widgetDirectory, "*", VFS.RAW) or {}) do
		existingDirectories[name] = true
	end

	local widgetFiles = {}
	local errors = {}
	local notAnonymousSafe = {}
	local seenIds = {}
	for _, manifest in ipairs(manifests) do
		local widgetId = type(manifest) == "table" and manifest.id
		local expectedHash = type(manifest) == "table" and manifest.content_hash
		if type(widgetId) ~= "string" or not widgetId:match("^[a-z][a-z0-9_]*$") then
			errors[#errors + 1] = "catalog contains an invalid widget id"
		elseif seenIds[widgetId] then
			return nil, { "catalog contains duplicate widget id: " .. widgetId }
		elseif type(expectedHash) ~= "string" or not expectedHash:match("^sha512:[0-9a-f]+$") or #expectedHash ~= 135 then
			errors[#errors + 1] = widgetId .. ": missing or invalid content_hash"
		else
			seenIds[widgetId] = true
			local directory = widgetDirectory .. widgetId .. "/"
			if not existingDirectories[directory] then
				-- listed in the catalog but not installed
			elseif requireAnonymousSafe and manifest.anonymous_safe ~= true then
				notAnonymousSafe[#notAnonymousSafe + 1] = widgetId
			else
				local actualHash, hashError = calculateWidgetHash(directory)
				if not actualHash then
					errors[#errors + 1] = widgetId .. ": " .. hashError
				elseif actualHash ~= expectedHash then
					errors[#errors + 1] = widgetId .. ": content hash mismatch"
				else
					local luaFiles = VFS.DirList(directory, "*.lua", VFS.RAW) or {}
					for _, filename in ipairs(luaFiles) do
						widgetFiles[#widgetFiles + 1] = filename
					end
				end
			end
		end
	end

	table.sort(widgetFiles)
	return widgetFiles, errors, notAnonymousSafe
end

return {
	CalculateWidgetHash = calculateWidgetHash,
	GetVerifiedWidgetFiles = getVerifiedWidgetFiles,
}
