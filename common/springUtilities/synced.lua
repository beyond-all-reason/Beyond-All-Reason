-- need this because SYNCED.tables are merely proxies, not real tables
local function makeRealTable(proxy, debugTag)
	if proxy == nil then
		Spring.Log("Table Utilities", LOG.ERROR, "Proxy table is nil: " .. (debugTag or "unknown table"))
		return
	end
	local proxyLocal = proxy
	local ret = {}
	for i,v in pairs(proxyLocal) do
		if type(v) == "table" then
			ret[i] = makeRealTable(v)
		else
			ret[i] = v
		end
	end
	return ret
end

return {
	MakeRealTable = makeRealTable,
}