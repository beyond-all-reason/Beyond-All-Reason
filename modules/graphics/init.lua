local function Init(gl)
	if gl then
		gl.InstanceVBOTable = VFS.Include("modules/graphics/instancevbotable.lua")
		gl.InstanceVBOIdTable = VFS.Include("modules/graphics/instancevboidtable.lua")
		gl.LuaShader = VFS.Include("LuaUI/Include/LuaShader.lua")
	end
end

return {
	Init = Init,
}
