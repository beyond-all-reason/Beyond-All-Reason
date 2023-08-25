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
				str = key .. "={"
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

if not table.count then
	---Count the number of values in table.
	---Note that this always works, whereas the default length operator (#table)
	---only works if the table is a Lua sequence (i.e. indexes form a contiguous
	---sequence starting from 1).
	---@param tbl table
	---@return integer
	function table.count(tbl)
		local count = 0
		for _ in pairs(tbl) do
			count = count + 1
		end
		return count
	end
end

if not table.getKeyOf then
	---Find key of value in table.
	---Will always return the first key found, no matter if the table contains
	---multiple instances of the value.
	---@generic K, V
	---@param tbl table<K, V>
	---@param value V
	---@return K? # key if found, nil otherwise
	function table.getKeyOf(tbl, value)
		for key, v in pairs(tbl) do
			if v == value then
				return key
			end
		end
		return nil
	end
end

if not table.contains then
	---Check if value is in table.
	---@generic V
	---@param tbl table<any, V>
	---@param value V
	---@return boolean
	function table.contains(tbl, value)
		return table.getKeyOf(tbl, value) ~= nil
	end
end

if not table.removeIf then
	---Remove values in table if they match the given predicate.
	---@generic V
	---@param tbl table<any, V>
	---@param predicate fun(value: V): boolean
	function table.removeIf(tbl, predicate)
		for key, value in pairs(tbl) do
			if predicate(value) then
				tbl[key] = nil
			end
		end
	end
end

if not table.removeAll then
	---Remove all instances of value in table.
	---@generic V
	---@param tbl table<any, V>
	---@param value V
	function table.removeAll(tbl, value)
		table.removeIf(tbl, function(v) return v == value end)
	end
end

if not table.removeFirst then
	---Remove first instance of value in table.
	---If table is a Lua sequence (i.e. indexes form a contiguous sequence
	---starting from 1), it will use `table.remove` to keep the sequence
	---contiguous, otherwise it will `nil` the instance.
	---@generic V
	---@param tbl V[]|table<any, V>
	---@param value V
	---@return boolean # true if a value was removed, false otherwise
	function table.removeFirst(tbl, value)
		-- first, try to handle the table as a proper Lua sequence
		-- this will fail as soon as there's a gap (missing integer index), but if
		-- the table is a sequence then we want to keep that property by using
		-- `table.remove` to keep the sequence intact without any gaps
		for index, v in ipairs(tbl) do
			if v == value then
				table.remove(tbl, index)
				return true
			end
		end

		-- otherwise, try to handle the table normally and simply `nil` the value
		local found = table.getKeyOf(tbl, value)
		if found ~= nil then
			tbl[found] = nil
			return true
		end

		return false
	end
end

if not table.shuffle then
	---Shuffle sequence using Knuth (Fisher–Yates) algorithm.
	---@param sequence any[] must be a Lua sequence (i.e. indexes form a contiguous sequence starting from 1), with the exception that we optionally allow starting from 0
	---@param firstIndex? 0|1 first index in the sequence (optional, default: 1)
	function table.shuffle(sequence, firstIndex)
		firstIndex = firstIndex or 1
		for i = firstIndex, #sequence - 2 + firstIndex do
			local j = math.random(i, #sequence)
			sequence[i], sequence[j] = sequence[j], sequence[i]
		end
	end
end

if not pairsByKeys then
	---pairs-like iterator function traversing the table in the order of its keys.
	---Natural sort order will be used by default, optionally pass a comparator
	---function for custom sorting.
	---@generic K, V
	---@param tbl table<K, V>
	---@param keySortFunction? fun(a: K, b: K): boolean comparator function passed to table.sort for sorting keys
	---@return fun(table: table<K, V>, index?: K): K, V
	---@return table<K, V>
	---(Implementation copied straight from the docs at https://www.lua.org/pil/19.3.html.)
	function pairsByKeys(tbl, keySortFunction)
		local keys = {}
		for key in pairs(tbl) do table.insert(keys, key) end
		table.sort(keys, keySortFunction)
		local i = 0           -- iterator variable
		local iter = function() -- iterator function
			i = i + 1
			if keys[i] == nil then
				return nil
			else
				return keys[i], tbl[keys[i]]
			end
		end
		return iter
	end
end
