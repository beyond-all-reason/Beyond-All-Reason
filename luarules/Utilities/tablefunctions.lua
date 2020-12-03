Spring.Utilities = Spring.Utilities or {}
--if not Spring.Utilities.Base64Decode then
--	VFS.Include("LuaRules/Utilities/base64.lua")
--end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
--deep not safe with circular tables! defaults To false
function Spring.Utilities.CopyTable(tableToCopy, deep, appendTo)
  local copy = appendTo or {}
  for key, value in pairs(tableToCopy) do
    if (deep and type(value) == "table") then
      copy[key] = Spring.Utilities.CopyTable(value, true)
    else
      copy[key] = value
    end
  end
  return copy
end

function Spring.Utilities.MergeTable(primary, secondary, deep)
	local new = Spring.Utilities.CopyTable(primary, deep)
	for i, v in pairs(secondary) do
		-- key not used in primary, assign it the value at same key in secondary
		if not new[i] then
			if (deep and type(v) == "table") then
			    new[i] = Spring.Utilities.CopyTable(v, true)
			else
				new[i] = v
			end
		-- values at key in both primary and secondary are tables, merge those
		elseif type(new[i]) == "table" and type(v) == "table"  then
			new[i] = Spring.Utilities.MergeTable(new[i], v, deep)
		end
	end
	return new
end

function Spring.Utilities.OverwriteTableInplace(primary, secondary, deep)
	for i, v in pairs(secondary) do
		if primary[i] and type(primary[i]) == "table" and type(v) == "table"  then
			Spring.Utilities.OverwriteTableInplace(primary[i], v, deep)
		else
			if (deep and type(v) == "table") then
				primary[i] = Spring.Utilities.CopyTable(v, true)
			else
				primary[i] = v
			end
		end
	end
end

function Spring.Utilities.MergeWithDefault(default, override)
	local new = Spring.Utilities.CopyTable(default, true)
	for key, v in pairs(override) do
		-- key not used in default, assign it the value at same key in override
		if not new[key] and type(v) == "table" then
			new[key] = Spring.Utilities.CopyTable(v, true)
		-- values at key in both default and override are tables, merge those
		elseif type(new[key]) == "table" and type(v) == "table"  then
			new[key] = Spring.Utilities.MergeWithDefault(new[key], v)
		else
			new[key] = v
		end
	end
	return new
end

function Spring.Utilities.TableToString(data, key)
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
			str = str .. Spring.Utilities.TableToString(v, k) .. ","
		end
		return str .. "}"
	else
		Spring.Echo("TableToString Error: unknown data type", dataType)
	end
	return ""
end

-- need this because SYNCED.tables are merely proxies, not real tables
local function MakeRealTable(proxy, debugTag)
	if proxy == nil then
		Spring.Log("Table Utilities", LOG.ERROR, "Proxy table is nil: " .. (debugTag or "unknown table"))
		return
	end
	local proxyLocal = proxy
	local ret = {}
	for i,v in spairs(proxyLocal) do
		if type(v) == "table" then
			ret[i] = MakeRealTable(v)
		else
			ret[i] = v
		end
	end
	return ret
end

Spring.Utilities.MakeRealTable = MakeRealTable

local function TableEcho(data, name, indent, tableChecked)
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
			TableEcho(v, name, newIndent, true)
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

function Spring.Utilities.ExplodeString(div,str)
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

Spring.Utilities.TableEcho = TableEcho

--function Spring.Utilities.CustomKeyToUsefulTable(dataRaw)
--	if not dataRaw then
--		return
--	end
--	if not type(dataRaw) == 'string' then
--		Spring.Echo("Customkey data error! type == " .. type(dataRaw))
--	else
--		dataRaw = string.gsub(dataRaw, '_', '=')
--		dataRaw = Spring.Utilities.Base64Decode(dataRaw)
--		local dataFunc, err = loadstring("return " .. dataRaw)
--		if dataFunc then
--			local success, usefulTable = pcall(dataFunc)
--			if success then
--				if collectgarbage then
--					collectgarbage("collect")
--				end
--				return usefulTable
--			end
--		end
--		if err then
--			Spring.Echo("Customkey error", err)
--		end
--	end
--	if collectgarbage then
--		collectgarbage("collect")
--	end
--end
