
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
	function table.merge(primary, secondary, deep)
		local new = table.copy(primary)
		for i, v in pairs(secondary) do
			-- key not used in primary, assign it the value at same key in secondary
			if not new[i] then
				if (deep and type(v) == "table") then
					new[i] = table.copy(v)
				else
					new[i] = v
				end
			-- values at key in both primary and secondary are tables, merge those
			elseif type(new[i]) == "table" and type(v) == "table"  then
				new[i] = table.merge(new[i], v, deep)
			end
		end
		return new
	end
end

if not table.mergeInPlace then
	function table.mergeInPlace(primary, secondary, deep)
		for i, v in pairs(secondary) do
			if primary[i] and type(primary[i]) == "table" and type(v) == "table" then
				table.mergeInPlace(primary[i], v, deep)
			else
				if (deep and type(v) == "table") then
					primary[i] = table.copy(v)
				else
					primary[i] = v
				end
			end
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
