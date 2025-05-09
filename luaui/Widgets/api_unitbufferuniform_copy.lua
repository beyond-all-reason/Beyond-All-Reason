function widget:GetInfo()
  return {
    name      = "API UnitBufferUniform Copy",
    version   = "v0.1",
    desc      = "Copies SUniformsBuffer every Gameframe",
    author    = "Beherith",
    date      = "2024.12.05",
    license   = "GPL V2",
    layer     = 0,
    enabled   = false,
  }
end

local luaShaderDir = "LuaUI/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
local cmpShader

-- The compute shader is reponsible for updating the position, velocity, and color of each particle 
local cmpSrc = [[
#version 430 core

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(std140, binding = 0) readonly buffer MatrixBuffer {
	mat4 mat[];
};

struct SUniformsBuffer {
	uint composite; //     u8 drawFlag; u8 unused1; u16 id;

	uint unused2;
	uint unused3;
	uint unused4;

	float maxHealth;
	float health;
	float unused5;
	float unused6;

    vec4 drawPos;
    vec4 speed;
    vec4[4] userDefined; //can't use float[16] because float in arrays occupies 4 * float space
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
	SUniformsBuffer uni[];
};

layout(std140, binding=4) buffer UniformsBufferCopy {
	SUniformsBuffer uniCopy[];
};

void main(void)
{
	uint index = gl_GlobalInvocationID.x;
	uniCopy[index].composite = uni[index].composite;
	uniCopy[index].maxHealth = uni[index].maxHealth;
	uniCopy[index].health = uni[index].health;
	uniCopy[index].drawPos = uni[index].drawPos * 0.5;
	uniCopy[index].speed = uni[index].speed;
	uniCopy[index].userDefined[0] = uni[index].userDefined[0];
	uniCopy[index].userDefined[1] = uni[index].userDefined[1];
	uniCopy[index].userDefined[2] = uni[index].userDefined[2];
	uniCopy[index].userDefined[3] = uni[index].userDefined[3];
}
]]

local numEntries = 32768
local structSize = 128

local copyRequested = false

local UniformsBufferCopy

function widget:Initialize()
	UniformsBufferCopy = gl.GetVBO(GL.SHADER_STORAGE_BUFFER, false)
	UniformsBufferCopy:Define(numEntries, {
		{id = 0, name = "uints", size = structSize},
	}
	)
	pcache = {}
	
	for i = 0,  (numEntries * structSize -1) do 
		pcache[i+1] = 0
	end
	UniformsBufferCopy:Upload(pcache)
	UniformsBufferCopy:BindBufferRange(4)

	cmpShader = LuaShader({
		compute = cmpSrc,
		uniformInt = {
			heightmapTex = 0,
		},
		uniformFloat = {
			frameTime = 0.016,
		}
	}, "cmpShader")
	
	shaderCompiled = cmpShader:Initialize()
	Spring.Echo("cmpShader ", shaderCompiled)
	if not shaderCompiled then widgetHandler:RemoveWidget() end

	Spring.Echo("Hello")
	WG['api_unitbufferuniform_copy'] = {}
	WG['api_unitbufferuniform_copy'].GetUnitUniformBufferCopy = function() 
		copyRequested = true
		return UniformsBufferCopy 	
	end
	widgetHandler:RegisterGlobal('GetUnitUniformBufferCopy', WG['api_unitbufferuniform_copy'].GetUnitUniformBufferCopy)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('GetUnitUniformBufferCopy')

	if cmpShader then cmpShader:Finalize() end
	if UniformsBufferCopy then UniformsBufferCopy:Delete() end
end

local lastUpdateFrame = 0
function widget:DrawScreenPost()
	if not copyRequested then return end
	if Spring.GetGameFrame() == lastUpdateFrame then
		return
	else
		lastUpdateFrame = Spring.GetGameFrame()
	end
	UniformsBufferCopy:BindBufferRange(4) -- dunno why, but if we dont, it gets lost after a few seconds
	cmpShader:Activate()
	gl.DispatchCompute((Game.maxUnits/32), 1, 1)
	cmpShader:Deactivate()
end
