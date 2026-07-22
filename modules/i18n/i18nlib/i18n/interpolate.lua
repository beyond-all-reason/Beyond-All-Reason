
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

-- formats remaining positional placeholders (%s, %d, %5d, ...); unconsumed args and lone % render raw instead of crashing
local function interpolatePositionalVariables(str, vars)
  if str:find('%%') and not str:find('%%{') and not str:find('%%<') then
    local scan = str:gsub('%%%%', '')
    local _, percentCount = scan:gsub('%%[%-%d%.]*%a', '')
    local args = {}
    for i = 1, percentCount do
      args[i] = vars[i] or vars[tostring(i)] or 'nil'
    end
    local ok, formatted = pcall(string.format, str, unpack(args))
    if ok then
      str = formatted
    end
  end
  return str
end


local function interpolate(str, vars)
  vars = vars or {}
  str = escapeDoublePercent(str)
  str = interpolateVariables(str, vars)
  str = interpolateFormattedVariables(str, vars)
  str = interpolatePositionalVariables(str, vars)
  str = unescapeDoublePercent(str)
  return str
end

return interpolate
