
if not LuaShaderNewLocationMessageShown then
	local msg = "A user widget is including LuaUI/Include/LuaShader.lua directly, please change it to use gl.LuaShader instead."
	Spring.Log('UserWidget', LOG.DEPRECATED, msg)
	LuaShaderNewLocationMessageShown = true
end

LuaShader = gl.LuaShader

