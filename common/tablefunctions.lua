--deep not safe with circular tables! defaults To false
function table:copy(deep)
	local copy = {}
	for key, value in pairs(self) do
		if (deep and type(value) == "table") then
			copy[key] = table.copy(value, true)
		else
			copy[key] = value
		end
	end
	return copy
end

-- Recursively merge two tables and return the result in a new table.
-- When there is a conflict, values in 'secondary' override values in 'primary'.
function table.merge(primary, secondary)
	local new = table.copy(primary, true)
	for key, v in pairs(secondary) do
		-- key not used in default, assign it the value at same key in override
		if not new[key] and type(v) == "table" then
			new[key] = table.copy(v, true)
		-- values at key in both default and override are tables, merge those
		elseif type(new[key]) == "table" and type(v) == "table"  then
			new[key] = table.merge(new[key], v)
		else
			new[key] = v
		end
	end
	return new
end

local function tableToString(data, key)
	 local dataType = type(data)
	-- Check the type
	if key then
		if type(key) == "number" then
			key = "[" .. key .. "]"
		end
	end
	if dataType == "string" then
		return key .. [[="]] .. data .. [["]]
	elseif dataType == "number" then
		return key .. "=" .. data
	elseif dataType == "boolean" then
		return key .. "=" .. ((data and "true") or "false")
	elseif dataType == "table" then
		local str
		if key then
			str = key ..  "={"
		else
			str = "{"
		end
		for k, v in pairs(data) do
			str = str .. tableToString(v, k) .. ","
		end
		return str .. "}"
	else
		Spring.Echo("TableToString Error: unknown data type", dataType)
	end
	return ""
end

-- need this because SYNCED.tables are merely proxies, not real tables
local function makeRealTable(proxy, debugTag)
	if proxy == nil then
		Spring.Log("Table Utilities", LOG.ERROR, "Proxy table is nil: " .. (debugTag or "unknown table"))
		return
	end
	local proxyLocal = proxy
	local ret = {}
	for i,v in spairs(proxyLocal) do
		if type(v) == "table" then
			ret[i] = makeRealTable(v)
		else
			ret[i] = v
		end
	end
	return ret
end

return {
	TableToString = tableToString,
	MakeRealTable = makeRealTable,
}