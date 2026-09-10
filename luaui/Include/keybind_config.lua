-- Reader for the shared keybind JSON configs in common/configs.
--
-- A malformed file costs the caller its data, never the LuaUI session: Json.decode raises
-- on bad input, and an unguarded decode at include time takes the widget down with it.
-- Callers do their own shape checks; this only guarantees a table or nil.

local Json = Json or VFS.Include("common/luaUtilities/json.lua")

local M = {}

function M.load(path)
	local ok, decoded = pcall(Json.decode, VFS.LoadFile(path))
	if ok and type(decoded) == "table" then
		return decoded
	end

	Spring.Echo("[keybinds] Error: could not load " .. path)

	return nil
end

return M
