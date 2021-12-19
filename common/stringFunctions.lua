local base64 = VFS.Include('common/luaUtilities/base64.lua')

if not string.split then
	-- Split a string into a table of substrings, based on a delimiter.
	-- If not supplied, delimiter defaults to whitespace.
	-- Consecutive delimiters are treated as one.
	-- string.split(csvText, ',')	csvText:split(',')
	function string:split(delimiter)
		delimiter = delimiter or '%s'
		local results = {}
		for part in self:gmatch("[^" .. delimiter .. "]+") do
			table.insert(results, part)
		end
		return results
	end
end

if not string.base64Encode then
	function string:base64Encode()
		return base64.Encode(self)
	end

	function string:base64Decode()
		return base64.Decode(self)
	end
end

if not string.lines then
	function string.lines(str)
		local text = {}
		local function helper(line)
			text[#text+1] = line
			return ""
		end
		helper((str:gsub("(.-)\r?\n", helper)))
		return text
	end
end