--[[
IMPORTANT NOTICE: Tests for these functions are provided via
`common/tableFunctionsTests.lua`, but the tests do not run unless you uncomment
them in `init.lua` (because they're not free to run, so we don't want them to
run for end users.)
]]

-- Lua 5.1 backwards compatibility
table.pack = table.pack or function(...) return { n = select("#", ...), ... } end

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
	local stringRep = string.rep
	local tableSort = table.sort
	local DEFAULT_INDENT_STEP = 2

	local function tableToString(tbl, options, _seen, _depth)
	end

	local function keyCmp(a, b)
		local ta = type(a)
		local tb = type(b)

		-- numbers always sort before other keys
		-- compare pairs of numbers directly
		-- for everything else, convert to string first
		if ta == "number" and tb == "number" then
			return a < b
		elseif ta == "number" and tb ~= "number" then
			return true
		elseif tb == "number" and ta ~= "number" then
			return false
		else
			return tableToString(a) < tableToString(b)
		end
	end

	tableToString = function(tbl, options, _seen, _depth)
		_seen = _seen or {}
		_depth = _depth or 0

		local inputType = type(tbl)

		if inputType == "string" then
			return "\"" .. tbl .. "\""
		elseif inputType == "userdata" then
			return tostring(tbl) or "<userdata>"
		elseif inputType ~= "table" then
			return tostring(tbl)
		end

		if _seen[tbl] then
			return "<recursive_reference>"
		end

		_seen[tbl] = true

		local keys = {}
		for key in pairs(tbl) do
			keys[#keys + 1] = key
		end
		tableSort(keys, (options and options.keyCmp) or keyCmp)

		local indent = (options and options.indent) or DEFAULT_INDENT_STEP

		local str = "{"
		if #keys > 0 and options and options.pretty then
			str = str .. "\n"
		end
		for i, key in ipairs(keys) do
			if options and options.pretty then
				str = str .. stringRep(" ", (_depth + 1) * indent)
			end
			if key ~= i then
				local keyType = type(key)
				if keyType == "string" then
					str = str .. key .. "="
				elseif keyType == "number" then
					str = str .. "[" .. key .. "]="
				else
					str = str .. "[" .. tableToString(key, options, _seen) .. "]="
				end
			end
			str = str .. tableToString(tbl[key], options, _seen, _depth + 1) .. ","
			if options and options.pretty then
				str = str .. "\n"
			end
		end
		if #keys > 0 then
			-- remove the last comma (normal) or newline (pretty)
			str = str:sub(1, #str - 1)

			if options and options.pretty then
				str = str .. "\n" .. stringRep(" ", _depth * indent)
			end
		end
		str = str .. "}"

		return str
	end

	---Recursively turns a table into a string, suitable for printing.
	---
	---All types of keys and values are valid. How some special types are handled:
	--- * `function` types are turned into "<function>"
	--- * `userdata` types are turned into "<userdata>", unless they have a `tostring` metamethod, which is used instead
	--- * cyclic or recursive references are turned into "<recursive_reference>"
	--- * keys that are not strings or numbers (tables, functions, etc) are first run through table.toString
	---
	---In order to keep the output deterministic, keys are sorted.
	---@param tbl table
	---@param options table Optional parameters
	---@param options.pretty boolean Whether to add newlines and indentation (default: false)
	---@param options.indent number If pretty=true, the number of spaces to indent by at each indent step (default: 2)
	---@param options.keyCmp function Custom comparison function for sorting keys. If provided, this function will be used instead of the default comparison based on `table.toString(key)`.
	---@return string
	table.toString = tableToString
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
	---@return number
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

if not table.map then
	--- Applies a function to all elements of a table and returns a new table with the results.
	---@generic K, V, RV, RK
	---@param tbl table<K, V> The input table.
	---@param callback fun(value: V, key: K, tbl: table<K, V>): RV, RK The function to apply to each element. It receives three arguments: the element's value, its key, and the original table. It should return the new value, and optionally, a new key.
	---@return table<RK, RV> A new table containing the results of applying the callback to each element.
	function table.map(tbl, callback)
		local result = {}
		for k, v in pairs(tbl) do
			local mappedValue, mappedKey = callback(v, k, tbl)
			if mappedKey ~= nil then
				result[mappedKey] = mappedValue
			else
				result[k] = mappedValue
			end
		end
		return result
	end
end

if not table.reduce then
	--- Reduces a table to a single value by applying a function to each element in order.
	---@generic K, V, R
	---@param tbl table<K, V> The input table.
	---@param callback fun(acc: R, value: V, key: K, tbl: table<K, V>): R The function to apply to each element. It receives four arguments: the accumulator, the element's value, its key, and the original table.
	---@param initial R The initial value of the accumulator. If no value is specified, the first callback will receive nil as the accumulator value.
	---@return R The final value of the accumulator after applying the callback to all elements.
	function table.reduce(tbl, callback, initial)
		local accumulator = initial

		for k, v in pairs(tbl) do
			accumulator = callback(accumulator, v, k, tbl)
		end

		return accumulator
	end
end

if not table.filterArray then
	--- Creates a new (array-style) table containing only the elements that satisfy a given condition.
	---@generic V
	---@param tbl V[] The input table.
	---@param callback fun(value: V, index: number, tbl: V[]): boolean The condition to check for each element. It receives three arguments: the element's value, its key, and the original table. It should return true if the element satisfies the condition, false otherwise.
	---@return V[] A new table containing only the elements that satisfy the condition.
	function table.filterArray(tbl, callback)
		local result = {}
		for i, v in ipairs(tbl) do
			if callback(v, i, tbl) then
				result[#result + 1] = v
			end
		end
		return result
	end
end

if not table.filterTable then
	--- Creates a new (dictionary-style) table containing only the elements that satisfy a given condition.
	---@generic K, V, R
	---@param tbl table<K, V> The input table.
	---@param callback fun(value: V, key: K, tbl: table<K, V>): boolean The condition to check for each element. It receives three arguments: the element's value, its index, and the original table. It should return true if the element satisfies the condition, false otherwise.
	---@return table<K, V> A new table containing only the elements that satisfy the condition.
	function table.filterTable(tbl, callback)
		local result = {}
		for k, v in pairs(tbl) do
			if callback(v, k, tbl) then
				result[k] = v
			end
		end
		return result
	end
end

if not table.all then
	--- Checks if all elements of a table satisfy a condition.
	---@generic K, V, R
	---@param tbl table<K, V> The input table.
	---@param callback fun(value: V, key: K, tbl: table<K, V>): boolean The condition to check for each element. It receives three arguments: the element's value, its key, and the original table. It should return true if the element satisfies the condition, false otherwise.
	---@return boolean True if all elements satisfy the condition, false otherwise.
	function table.all(tbl, callback)
		for k, v in pairs(tbl) do
			if not callback(v, k, tbl) then
				return false
			end
		end
		return true
	end
end

if not table.any then
	--- Checks if at least one element of a table satisfies a condition.
	---@generic K, V, R
	---@param tbl table<K, V> The input table.
	---@param callback fun(value: V, key: K, tbl: table<K, V>): boolean The condition to check for each element. It receives three arguments: the element's value, its key, and the original table. It should return true if the element satisfies the condition, false otherwise.
	---@return boolean True if at least one element satisfies the condition, false otherwise.
	function table.any(tbl, callback)
		for k, v in pairs(tbl) do
			if callback(v, k, tbl) then
				return true
			end
		end
		return false
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
