
local unpack = unpack or table.unpack -- lua 5.2 compat

local bracketDummy = "@@@@@@@@@{@@@@@@@@@"
local ltDummy      = "@@@@@@@@@<@@@@@@@@@"

-- matches a string of type %{age}
local function interpolateVariables(str, vars)
  return str:gsub("%%{%s*(.-)%s*}", function(key) return tostring(vars[key]) end)
end

-- matches a string of type %<age>.d
local function interpolateFormattedVariables(str, vars)
  return str:gsub("%%<%s*(.-)%s*>%.([cdEefgGiouXxsq])", function(key, formatChar)
    return string.format("%" .. formatChar, vars[key] or 'nil')
  end)
end

local function escapeDoublePercent(str)
  return str:gsub("%%%%{", bracketDummy):gsub("%%%%<", ltDummy)
end

local function unescapeDoublePercent(str)
  return str:gsub(ltDummy, "%%<"):gsub(bracketDummy, "%%{")
end


local function interpolate(str, vars)
  vars = vars or {}
  str = escapeDoublePercent(str)
  str = interpolateVariables(str, vars)
  str = interpolateFormattedVariables(str, vars)
  str = string.format(str, unpack(vars))
  str = unescapeDoublePercent(str)
  return str
end

return interpolate
