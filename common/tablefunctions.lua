--[[
IMPORTANT NOTICE: Tests for these functions are provided via
`common/tableFunctionsTests.lua`, but the tests do not run unless you uncomment
them in `init.lua` (because they're not free to run, so we don't want them to
run for end users.)
]]

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
	---Return a new table of values from mergeData recursively merged into
	---mergeTarget, using deep copies. When there is a conflict, values in
	---mergeData take precedence.
	---@param mergeTarget table
	---@param mergeData table
	---@return table
	function table.merge(mergeTarget, mergeData)
		local new = table.copy(mergeTarget)
		for key, value in pairs(mergeData) do
			-- key not used in default, assign it the value at same key in override
			if not new[key] and type(value) == "table" then
				new[key] = table.copy(value)
				-- values at key in both default and override are tables, merge those
			elseif type(new[key]) == "table" and type(value) == "table" then
				new[key] = table.merge(new[key], value)
			else
				new[key] = value
			end
		end
		return new
	end
end

if not table.mergeInPlace then
	---Recursively in-place merge values from mergeData into mergeTarget. When
	---there is a conflict, values in mergeData take precedence.
	---@param mergeTarget table
	---@param mergeData table
	---@param deep? boolean if true, deep copy tables coming from mergeData (default: false)
	---@return table mergeTarget
	function table.mergeInPlace(mergeTarget, mergeData, deep)
		deep = deep or false
		for key, value in pairs(mergeData) do
			if type(value) == 'table' and type(mergeTarget[key] or false) == 'table' then
				table.mergeInPlace(mergeTarget[key], value, deep)
			elseif type(value) == "table" and deep then
				mergeTarget[key] = table.copy(value)
			else
				mergeTarget[key] = value
			end
		end
		return mergeTarget
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
