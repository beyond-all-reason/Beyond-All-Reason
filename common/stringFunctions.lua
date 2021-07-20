-- Split a string into a table of substrings, based on a delimiter.
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