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
	function string:lines()
		local text = {}
		local function helper(line)
			text[#text+1] = line
			return ""
		end
		helper((self:gsub("(.-)\r?\n", helper)))
		return text
	end
end

-- Returns python style tuple string.partition()
if not string.partition then 
	function string:partition(sep)
		local seppos = self:find(sep, nil, true)
		if seppos == nil then 
			return self, nil, nil 
		else
			if seppos == 1 then 
				return nil, sep, self:sub(sep:len()+1)
			else
				return self:sub(1, seppos -1), sep, self:sub(seppos + sep:len())
			end
		end
	end
end

if not string.formatTime then
	function string:formatTime()
		local hours = math.floor(self / 3600)
		local minutes = math.floor((self % 3600) / 60)
		local seconds = math.floor(self % 60)
		local hoursString = tostring(hours)
		local minutesString = tostring(minutes)
		local secondsString = tostring(seconds)
		if seconds < 10 then
			secondsString = "0" .. secondsString
		end
		if hours > 0 and minutes < 10 then
			minutesString = "0" .. minutesString
		end
		if hours > 0 then
			return hoursString .. ":" .. minutesString .. ":" .. secondsString
		else
			return minutesString .. ":" .. secondsString
		end
	end
end
-- Unit test:
-- print(string.partition("blaksjdfsaldkj","ldkj"))
-- print(string.partition("blaksjdfsaldkj","aks"))


