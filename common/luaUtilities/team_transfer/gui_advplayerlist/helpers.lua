--- Aggregates sub-helper modules so gui_advplayerslist.lua avoids the Lua local cap
local PolicyHelpers = VFS.Include("common/luaUtilities/team_transfer/gui_advplayerlist/policy.lua")
local ResourceHelpersFactory = VFS.Include("common/luaUtilities/team_transfer/gui_advplayerlist/resource.lua")
local UnitValidationHelpers = VFS.Include("common/luaUtilities/team_transfer/gui_advplayerlist/validation.lua")

local Helpers = {}

local function extend(source)
  for key, value in pairs(source) do
    Helpers[key] = value
  end
end

extend(PolicyHelpers)
extend(ResourceHelpersFactory(PolicyHelpers))
extend(UnitValidationHelpers)

return Helpers
