-- Serves the engine's key constants to the keybind editor's includes.
--
-- barwidgets.lua loads KEYSYMS into the widget-handler environment, which an Include from
-- inside a widget does not inherit, so the global may or may not be visible here.

local KEYSYMS = KEYSYMS

if not KEYSYMS then
	local env = {}
	VFS.Include("luaui/Headers/keysym.h.lua", env)
	KEYSYMS = env.KEYSYMS
end

return KEYSYMS
