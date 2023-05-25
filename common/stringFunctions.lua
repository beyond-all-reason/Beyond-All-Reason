local base64 = VFS.Include('common/luaUtilities/base64.lua')

if not string.split then
	function string.split(str, delimiter)
		delimiter = delimiter or '%s'
		local results = {}
		for part in str:gmatch("[^" .. delimiter .. "]+") do
			table.insert(results, part)
		end
		return results
	end
end

if not string.base64Encode then
	function string.base64Encode(str)
		return base64.Encode(str)
	end

	function string.base64Decode(str)
		return base64.Decode(str)
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

if not string.partition then
	function string.partition(str, sep)
		local seppos = str:find(sep, nil, true)
		if seppos == nil then
			return str, nil, nil
		else
			if seppos == 1 then
				return nil, sep, str:sub(sep:len() + 1)
			else
				return str:sub(1, seppos - 1), sep, str:sub(seppos + sep:len())
			end
		end
	end
end

if not string.formatTime then
	function string.formatTime(time)
		local hours = math.floor(time / 3600)
		local minutes = math.floor((time % 3600) / 60)
		local seconds = math.floor(time % 60)
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

return string
