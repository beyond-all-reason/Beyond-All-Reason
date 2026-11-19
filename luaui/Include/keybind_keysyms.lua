-- Serves the engine key constants to the keybind editor includes.
--
-- barwidgets.lua loads KEYSYMS into the widget-handler environment, which an Include from
-- inside a widget does not inherit, so the global may or may not be visible here.

local KEYSYMS = KEYSYMS

if not KEYSYMS then
	-- keysym.h.lua's proxy calls setmetatable() at load time, and its __pairs
	-- closure calls next later, so this bare env needs both or it errors.
	local env = { setmetatable = setmetatable, next = next }
	-- the engine installs its own LuaUI/Headers loose, and the default mode reads raw files first
	VFS.Include("luaui/Headers/keysym.h.lua", env, VFS.ZIP)
	KEYSYMS = env.KEYSYMS
end

return KEYSYMS
