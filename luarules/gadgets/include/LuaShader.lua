
if not LuaShaderNewLocationMessageShown then
	local dest = widget or gadget
	local info = dest and dest.GetInfo()
	local name = info and info.name or 'unknown'
	local msg = "A user widget (" .. name .. ") is including LuaRules/Gadgets/Include/LuaShader.lua directly, please change it to use gl.LuaShader instead."
	Spring.Log('UserWidget', LOG.DEPRECATED, msg)
	LuaShaderNewLocationMessageShown = true
end

return gl.LuaShader

