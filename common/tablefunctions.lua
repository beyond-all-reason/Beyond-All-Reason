if not table.copy then
	function table.copy(tbl)
		local copy = {}
		for key, value in pairs(tbl) do
			if type(value) == "table" then
				copy[key] = table.copy(value)
			else
				copy[key] = value
			end
		end
		return copy
	end
end

if not table.merge then
	function table.merge(primary, secondary)
		local new = table.copy(primary)
		for key, value in pairs(secondary) do
			if type(value) == "table" and type(new[key]) == "table" then
				new[key] = table.merge(new[key], value)
			else
				new[key] = value
			end
		end
		return new
	end
end

if not table.mergeInPlace then
	function table.mergeInPlace(mergeTarget, mergeData, deep)
		if not deep then
			local mergedData = table.merge(mergeTarget, mergeData)
			for key, value in pairs(mergedData) do
				mergeTarget[key] = value
			end
			return
		end

		for key, value in pairs(mergeData) do
			if type(value) == "table" and type(mergeTarget[key]) == "table" then
				table.mergeInPlace(mergeTarget[key], value, deep)
			else
				mergeTarget[key] = value
			end
		end
	end
end

if not table.toString then
	function table.toString(data, key)
		local dataType = type(data)
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
			return key .. "=" .. (data and "true" or "false")
		elseif dataType == "table" then
			local str
			if key then
				str = key ..  "={"
			else
				str = "{"
			end
			for k, v in pairs(data) do
				str = str .. table.toString(v, k) .. ","
			end
			return str .. "}"
		else
			error("table.toString Error: unknown data type: " .. dataType)
		end
		return ""
	end
end

if not table.invert then
	function table.invert(tbl)
		local inverted = {}
		for key, value in pairs(tbl) do
			inverted[value] = key
		end
		return inverted
	end
end

if not table.append then
	function table.append(appendTarget, appendData)
		for _, value in ipairs(appendData) do
			table.insert(appendTarget, value)
		end
	end
end

return table
