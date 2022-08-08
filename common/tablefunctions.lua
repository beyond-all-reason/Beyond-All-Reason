
if not table.copy then
	function table:copy()
		local copy = {}
		for key, value in pairs(self) do
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
	-- Recursively merge two tables and return the result in a new table.
	-- When there is a conflict, values in 'secondary' override values in 'primary'.
	function table.merge(primary, secondary)
		local new = table.copy(primary)
		for key, v in pairs(secondary) do
			-- key not used in default, assign it the value at same key in override
			if not new[key] and type(v) == "table" then
				new[key] = table.copy(v)
				-- values at key in both default and override are tables, merge those
			elseif type(new[key]) == "table" and type(v) == "table"  then
				new[key] = table.merge(new[key], v)
			else
				new[key] = v
			end
		end
		return new
	end
end

if not table.mergeInPlace then
	-- Recursively merge values, mutating the table 'mergeTarget'.
	-- When there is a conflict, values in 'mergeData' take precedence.
	function table.mergeInPlace(mergeTarget, mergeData)
		local mergedData = table.merge(mergeTarget, mergeData)

		for key, value in pairs(mergedData) do
			mergeTarget[key] = value
		end
	end
end

if not table.toString then
	function table.toString(data, key)
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
	function table:invert()
		local inverted = {}
		for key, value in pairs(self) do
			inverted[value] = key
		end
		return inverted
	end
end


if not table.append then
	function table.append(appendTarget, appendData)
		for _, value in pairs(appendData) do
			table.insert(appendTarget, value)
		end
	end
end