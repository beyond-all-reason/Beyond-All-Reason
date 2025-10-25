
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
  -- Handle any remaining % positional placeholders (e.g., %s, %d)
  -- Only if they exist and vars can be treated as array
  if str:find('%%') and not str:find('%%{') and not str:find('%%<') then
    local percentCount = 0
    for _ in str:gmatch('%%') do
      percentCount = percentCount + 1
    end
    -- For positional placeholders, assume vars[1], vars[2], etc.
    local args = {}
    for i = 1, percentCount do
      args[i] = vars[i] or vars[tostring(i)] or 'nil'
    end
    str = string.format(str, unpack(args))
  end
  str = unescapeDoublePercent(str)
  return str
end

return interpolate
