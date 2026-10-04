local function pack(...)
	return { ... }
end

local function splitFirstElement(tbl)
	if type(tbl) ~= "table" then
		error("Input must be a table")
	end

	if #tbl < 1 then
		return nil, {}
	end

	local firstElement = table.remove(tbl, 1)
	return firstElement, tbl
end

local function splitPhrases(input)
	local result = {}
	local currentPhrase = ""

	local function appendPhrase(phrase)
		table.insert(result, phrase:match("^%s*(.-)%s*$"))  -- Trim whitespace
		currentPhrase = ""
	end

	local i = 1
	local len = string.len(input)

	while i <= len do
		local char = string.sub(input, i, i)

		if char == " " and currentPhrase ~= "" then
			appendPhrase(currentPhrase)
		elseif char == "\"" then
			local quoteStart = i
			repeat
				i = i + 1
				char = string.sub(input, i, i)
				if char == "\\" then
					i = i + 1 -- Skip escaped character
				end
			until char == "\"" or i > len

			local quoteEnd = i
			appendPhrase(string.sub(input, quoteStart + 1, quoteEnd - 1))
		else
			currentPhrase = currentPhrase .. char
		end

		i = i + 1
	end

	if currentPhrase ~= "" then
		appendPhrase(currentPhrase)
	end

	return result
end

local function removeFileExtension(filename)
	local lastDotIndex = filename:match(".+()%.%w+$")
	if lastDotIndex then
		return filename:sub(1, lastDotIndex - 1)
	else
		return filename
	end
end

local function yieldable_pcall(func, ...)
	-- this works just like pcall, but while pcall fails on yield, this handles yield transparently
	local function helper(co, ok, ...)
		if ok then
			if coroutine.status(co) == "dead" then
				return true, (...)
			end
			return helper(co, coroutine.resume(co, coroutine.yield(...)))
		else
			return false, (...)
		end
	end

	local co = coroutine.create(function(...)
		return func(...)
	end)

	return helper(co, coroutine.resume(co, ...))
end

return {
	pack = pack,
	yieldable_pcall = yieldable_pcall,
	splitFirstElement = splitFirstElement,
	splitPhrases = splitPhrases,
	removeFileExtension = removeFileExtension,
}
