--- Public contract of the sharing module — everything code outside
--- modules/sharing/ may consume, organized by domain (never by file layout):
---
---   local Sharing = VFS.Include("modules/module_handler.lua").Get("sharing")
---   Sharing.Unsynced.Units.ShareUnits(teamID)   -- widgets
---   Sharing.Units.ValidateUnits(...)            -- gadgets (both-state surface)
---   Sharing.Take.CanTake(...)
---
--- Entries resolve lazily (and load once per Lua state) so that pulling the
--- contract from synced code never includes unsynced-only files, and vice
--- versa. Everything not listed here is module-internal; include paths under
--- modules/sharing/ from outside are a boundary violation.

local ModuleHandler = VFS.Include("modules/module_handler.lua")

local exports = {
	Enums = "modules/sharing/enums.lua",
	-- the widget-facing facade: .Resources, .Units (incl. Units.ShareUnits)
	Unsynced = "modules/sharing/unsynced.lua",
	-- unit surface safe in both states: validation, factors, cached pair policy
	Units = "modules/sharing/unit/shared.lua",
	Take = "modules/sharing/take/comms.lua",
	PolicyViews = {
		Helpers = "modules/sharing/policy_views/helpers.lua",
		ApiExtensions = "modules/sharing/policy_views/api_extensions.lua",
	},
}

local function lazy(entries)
	return setmetatable({}, {
		__index = function(api, key)
			local entry = entries[key]
			if entry == nil then
				return nil
			end
			local value
			if type(entry) == "table" then
				value = lazy(entry)
			else
				value = ModuleHandler.Include(entry)
			end
			api[key] = value
			return value
		end,
	})
end

return lazy(exports)
