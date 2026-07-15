--- Public contract of the sharing module — everything code outside
--- modules/sharing/ may consume. Reach it through the module handler:
---
---   local Sharing = VFS.Include("modules/module_handler.lua").Get("sharing")
---   local canTake = Sharing.TakeComms.CanTake(...)
---
--- Entries resolve lazily (and load once per Lua state) so that pulling the
--- contract from synced code never includes unsynced-only files, and vice
--- versa. Everything not listed here is module-internal; include paths under
--- modules/sharing/ from outside are a boundary violation.

local ModuleHandler = VFS.Include("modules/module_handler.lua")

local exports = {
	-- enums
	TransferEnums = "modules/sharing/enums.lua",
	-- unsynced transfer surface (widgets)
	TeamTransferUnsynced = "modules/sharing/unsynced.lua",
	UnitTransferUnsynced = "modules/sharing/unit/unsynced.lua",
	UnitTransferShared = "modules/sharing/unit/shared.lua",
	TakeComms = "modules/sharing/take/comms.lua",
	-- advplayerslist sharing-tab extensions
	PolicyViewsHelpers = "modules/sharing/policy_views/helpers.lua",
	PolicyViewsApiExtensions = "modules/sharing/policy_views/api_extensions.lua",
}

return setmetatable({}, {
	__index = function(api, key)
		local path = exports[key]
		if not path then
			return nil
		end
		local value = ModuleHandler.Include(path)
		api[key] = value
		return value
	end,
})
