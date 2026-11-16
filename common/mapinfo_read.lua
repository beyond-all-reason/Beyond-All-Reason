-- The loaded map's own mapinfo.lua with every key lowercased, or nil. The engine reads mapinfo
-- case-insensitively and a map may or may not lowercase its table (the Spring template does,
-- exports before map_export lowercased did not), so readers look up lowercase keys only.
local function lowerKeys(t)
	local c = {}
	for k, v in pairs(t) do
		c[type(k) == "string" and k:lower() or k] = (type(v) == "table") and lowerKeys(v) or v
	end
	return c
end

return function()
	local ok, mapinfo = pcall(VFS.Include, "mapinfo.lua", nil, VFS.MAP)
	if not (ok and type(mapinfo) == "table") then
		return nil
	end
	return lowerKeys(mapinfo)
end
