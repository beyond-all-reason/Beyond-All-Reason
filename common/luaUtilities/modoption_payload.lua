-- modoptions decoder.
-- Expected format: base64url(zlib(json)), but zlib is optional

local base64 = VFS.Include("common/luaUtilities/base64.lua")

local function decodeJson(text)
	if not text or text == "" then
		return nil
	end

	local ok, parsed = pcall(Json.decode, text)
	if not ok or type(parsed) ~= "table" then
		return nil
	end

	return parsed
end

local function Decode(raw)
	if type(raw) ~= "string" or #raw == 0 then
		return nil
	end

	local okDecode, decoded = pcall(base64.Decode, raw)
	if not okDecode or not decoded or decoded == "" then
		return nil
	end

	-- VFS.ZlibDecompress raises on non-zlib or empty input rather than returning nil.
	local okZlib, decompressed = pcall(VFS.ZlibDecompress, decoded)
	if okZlib and decompressed then
		local parsed = decodeJson(decompressed)
		if parsed then
			return parsed
		end
	end

	-- Uncompressed payload: the base64 already yielded the json.
	return decodeJson(decoded)
end

return {
	Decode = Decode,
}
