
if not LuaShaderNewLocationMessageShown then
	local msg = "A user widget is including LuaRules/Gadgets/Include/LuaShader.lua directly, please change it to use gl.LuaShader instead."
	Spring.Log('UserWidget', LOG.DEPRECATED, msg)
	LuaShaderNewLocationMessageShown = true
end

local dest = widget or gadget

dest.LuaShader = gl.LuaShader

