local ordinal = {}
local defaultFunction = nil
-- helper functions

local function assertPresentString(functionName, paramName, value)
  if type(value) ~= 'string' or #value == 0 then
    local msg = "Expected param %s of function %s to be a string, but got %s (a value of type %s) instead"
    error(msg:format(paramName, functionName, tostring(value), type(value)))
  end
end

local function assertNumber(functionName, paramName, value)
  if type(value) ~= 'number' then
    local msg = "Expected param %s of function %s to be a number, but got %s (a value of type %s) instead"
    error(msg:format(paramName, functionName, tostring(value), type(value)))
  end
end

-- transforms "foo bar baz" into {'foo','bar','baz'}
local function words(str)
  local result, length = {}, 0
  str:gsub("%S+", function(word)
    length = length + 1
    result[length] = word
  end)
  return result
end

local function isInteger(n)
  return n == math.floor(n)
end

local function between(value, min, max)
  return value >= min and value <= max
end

local function inside(v, list)
  for i=1, #list do
    if v == list[i] then return true end
  end
  return false
end


-- ordinalization functions

local ordinalization = {}

local f1 = function(n)
  if not isInteger(n) then return 'other' end
  local n_10, n_100 = n % 10, n % 100
  return (n_10 == 1 and n_100 ~= 11 and 'one') or
         (n_10 == 2 and n_100 ~= 12 and 'two') or
         (n_10 == 3 and n_100 ~= 13 and 'few') or
         'other'
end
ordinalization[f1] = words([[
  af asa bem bez bg bn brx ca cgg chr da de dv ee el
  en eo es et eu fi fo fur fy gl gsw gu ha haw he is
  it jmc kaj kcg kk kl ksb ku lb lg mas ml mn mr nah
  nb nd ne nl nn no nr ny nyn om or pa pap ps pt rm
  rof rwk saq seh sn so sq ss ssy st sv sw syr ta te
  teo tig tk tn ts ur ve vun wae xh xog zu
]])

local f2 = function(n)
  return "other"
end
ordinalization[f2] = words([[
  az bm bo dz fa hu id ig ii ja jv ka kde kea km kn
  ko lo ms my root sah ses sg th to tr vi wo yo zh
]])

local ordinalizationFunctions = {}
for f,locales in pairs(ordinalization) do
  for _,locale in ipairs(locales) do
    ordinalizationFunctions[locale] = f
  end
end

-- public interface

function ordinal.get(locale, n)
  assertPresentString('i18n.ordinal.get', 'locale', locale)
  assertNumber('i18n.ordinal.get', 'n', n)

  local f = ordinalizationFunctions[locale] or defaultFunction
  if not f then
    f = ordinalizationFunctions['en'] -- Ultimate fallback
  end

  return f(math.abs(n))
end

function ordinal.setDefaultFunction(f)
  defaultFunction = f
end

function ordinal.reset()
  defaultFunction = ordinalizationFunctions['en']
end

ordinal.reset()

return ordinal
