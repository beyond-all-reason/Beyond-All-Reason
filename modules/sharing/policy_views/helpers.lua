--- Aggregates sub-helper modules so gui_advplayerslist.lua avoids the Lua local cap
local PolicyHelpers = VFS.Include("modules/sharing/policy_views/policy.lua")
local ResourceHelpersFactory = VFS.Include("modules/sharing/policy_views/resource.lua")
local UnitValidationHelpers = VFS.Include("modules/sharing/policy_views/validation.lua")

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
