--deep not safe with circular tables! defaults To false
local function copyTable(tableToCopy, deep, appendTo)
  local copy = appendTo or {}
  for key, value in pairs(tableToCopy) do
    if (deep and type(value) == "table") then
      copy[key] = copyTable(value, true)
    else
      copy[key] = value
    end
  end
  return copy
end

local function mergeTable(primary, secondary, deep)
	local new = copyTable(primary, deep)
	for i, v in pairs(secondary) do
		-- key not used in primary, assign it the value at same key in secondary
		if not new[i] then
			if (deep and type(v) == "table") then
			    new[i] = copyTable(v, true)
			else
				new[i] = v
			end
		-- values at key in both primary and secondary are tables, merge those
		elseif type(new[i]) == "table" and type(v) == "table"  then
			new[i] = mergeTable(new[i], v, deep)
		end
	end
	return new
end

local function overwriteTableInplace(primary, secondary, deep)
	for i, v in pairs(secondary) do
		if primary[i] and type(primary[i]) == "table" and type(v) == "table"  then
			overwriteTableInplace(primary[i], v, deep)
		else
			if (deep and type(v) == "table") then
				primary[i] = copyTable(v, true)
			else
				primary[i] = v
			end
		end
	end
end

local function mergeWithDefault(default, override)
	local new = copyTable(default, true)
	for key, v in pairs(override) do
		-- key not used in default, assign it the value at same key in override
		if not new[key] and type(v) == "table" then
			new[key] = copyTable(v, true)
		-- values at key in both default and override are tables, merge those
		elseif type(new[key]) == "table" and type(v) == "table"  then
			new[key] = mergeWithDefault(new[key], v)
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

local function tableEcho(data, name, indent, tableChecked)
	name = name or "TableEcho"
	indent = indent or ""
	if (not tableChecked) and type(data) ~= "table" then
		Spring.Echo(indent .. name, data)
		return
	end
	Spring.Echo(indent .. name .. " = {")
	local newIndent = indent .. "    "
	for name, v in pairs(data) do
		local ty = type(v)
		if ty == "table" then
			tableEcho(v, name, newIndent, true)
		elseif ty == "boolean" then
			Spring.Echo(newIndent .. name .. " = " .. (v and "true" or "false"))
		elseif ty == "string" or ty == "number" then
			Spring.Echo(newIndent .. name .. " = " .. v)
		else
			Spring.Echo(newIndent .. name .. " = ", v)
		end
	end
	Spring.Echo(indent .. "},")
end

local function explodeString(div,str)
	if (div == '') then
		return false
	end
	local pos, arr = 0, {}
	-- for each divider found
	for st, sp in function() return string.find(str, div, pos, true) end do
		table.insert(arr, string.sub(str, pos, st - 1)) -- Attach chars left of current divider
		pos = sp + 1 -- Jump past current divider
	end
	table.insert(arr, string.sub(str,pos)) -- Attach chars right of last divider
	return arr
end

return {
	CopyTable = copyTable,
	MergeTable = mergeTable,
	OverwriteTableInplace = overwriteTableInplace,
	MergeWithDefault = mergeWithDefault,
	TableToString = tableToString,
	MakeRealTable = makeRealTable,
	TableEcho = tableEcho,
	ExplodeString = explodeString,
}