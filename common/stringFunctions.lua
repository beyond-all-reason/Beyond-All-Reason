local base64 = VFS.Include('common/Utilities/base64.lua')

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

function string:base64Encode()
	return base64.Encode(self)
end

function string:base64Decode()
	return base64.Decode(self)
end