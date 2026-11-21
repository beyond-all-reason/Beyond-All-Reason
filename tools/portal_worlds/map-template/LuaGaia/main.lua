-- This optional entry-point function is supplied only in the LuaGaia environment.
---@type fun(message: string)?
local allowUnsafeChanges = _G.AllowUnsafeChanges
if allowUnsafeChanges then
	allowUnsafeChanges("USE AT YOUR OWN PERIL")
end
VFS.Include("LuaGadgets/gadgets.lua", nil, VFS.BASE)
