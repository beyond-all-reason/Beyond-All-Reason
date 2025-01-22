local unpack = table.unpack or unpack

local registry = { }
local current_namespace
local fallback_namespace

local s = {

  _COPYRIGHT   = "Copyright (c) 2012 Olivine Labs, LLC.",
  _DESCRIPTION = "A simple string key/value store for i18n or any other case where you want namespaced strings.",
  _VERSION     = "Say 1.3",

  set_namespace = function(self, namespace)
    current_namespace = namespace
    if not registry[current_namespace] then
      registry[current_namespace] = {}
    end
  end,

  set_fallback = function(self, namespace)
    fallback_namespace = namespace
    if not registry[fallback_namespace] then
      registry[fallback_namespace] = {}
    end
  end,

  set = function(self, key, value)
    registry[current_namespace][key] = value
  end
}

local __meta = {
  __call = function(self, key, vars)
    if vars ~= nil and type(vars) ~= "table" then
      error(("expected parameter table to be a table, got '%s'"):format(type(vars)), 2)
    end
    vars = vars or {}
    vars.n = math.max((vars.n or 0), #vars)

    local str = registry[current_namespace][key] or registry[fallback_namespace][key]

    if str == nil then
      return nil
    end
    str = tostring(str)
    local strings = {}

    for i = 1, vars.n or #vars do
      table.insert(strings, tostring(vars[i]))
    end

    return #strings > 0 and str:format(unpack(strings)) or str
  end,

  __index = function(self, key)
    return registry[key]
  end
}

s:set_fallback('en')
s:set_namespace('en')

s._registry = registry

return setmetatable(s, __meta)
