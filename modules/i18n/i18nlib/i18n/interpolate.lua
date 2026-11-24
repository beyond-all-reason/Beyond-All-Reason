local unpack = unpack or table.unpack -- lua 5.2 compat
local find = string.find
local noVars = {} -- never written to

local bracketDummy = "@@@@@@@@@{@@@@@@@@@"
local ltDummy = "@@@@@@@@@<@@@@@@@@@"

-- matches a string of type %{age}
local function interpolateVariables(str, vars)
	return str:gsub("%%{%s*(.-)%s*}", function(key)
		return tostring(vars[key])
	end)
end

-- matches a string of type %<age>.d
local function interpolateFormattedVariables(str, vars)
	return str:gsub("%%<%s*(.-)%s*>%.([cdEefgGiouXxsq])", function(key, formatChar)
		return string.format("%" .. formatChar, vars[key] or "nil")
	end)
end

local function escapeDoublePercent(str)
	return str:gsub("%%%%{", bracketDummy):gsub("%%%%<", ltDummy)
end

local function unescapeDoublePercent(str)
	return str:gsub(ltDummy, "%%<"):gsub(bracketDummy, "%%{")
end

-- formats remaining positional placeholders (%s, %d, %5d, ...); unconsumed args and lone % render raw instead of crashing
local function interpolatePositionalVariables(str, vars)
	if str:find("%%") and not str:find("%%{") and not str:find("%%<") then
		local scan = str:gsub("%%%%", "")
		local _, percentCount = scan:gsub("%%[%-%d%.]*%a", "")
		local args = {}
		for i = 1, percentCount do
			args[i] = vars[i] or vars[tostring(i)] or "nil"
		end
		local ok, formatted = pcall(string.format, str, unpack(args))
		if ok then
			str = formatted
		end
	end
	return str
end

local function interpolate(str, vars)
	-- with no "%" and no escape dummy in it, every step below returns the string as it is
	if type(str) == "string" and not find(str, "%", 1, true) and not find(str, "@@@@@@@@@", 1, true) then
		return str
	end
	vars = vars or noVars
	-- each step is skipped only when its pattern cannot match; a non-string still errors in the first one
	if type(str) ~= "string" or find(str, "%%", 1, true) then
		str = escapeDoublePercent(str)
	end
	if find(str, "%{", 1, true) then
		str = interpolateVariables(str, vars)
	end
	if find(str, "%<", 1, true) then
		str = interpolateFormattedVariables(str, vars)
	end
	str = interpolatePositionalVariables(str, vars)
	if find(str, "@@@@@@@@@", 1, true) then
		str = unescapeDoublePercent(str)
	end
	return str
end

return interpolate
