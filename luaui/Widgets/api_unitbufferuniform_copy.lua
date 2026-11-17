function widget:GetInfo()
	return {
		name = "API UnitBufferUniform Copy",
		version = "v0.2",
		desc = "Copies SUniformsBuffer every Gameframe",
		author = "Beherith",
		date = "2024.12.05",
		license = "GPL V2",
		layer = 0,
		enabled = false,
	}
end

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spEcho = Spring.Echo
local glGetEngineModelUniformDataSize = gl.GetEngineModelUniformDataSize
local glDispatchCompute = gl.DispatchCompute
local mathCeil = math.ceil

local LuaShader = gl.LuaShader

local COPY_BINDING = 4
local GROUP_SIZE = 64 -- local_size_x of cmpSrc
local ENTRY_SIZE_IN_VEC4S = 8 -- SUniformsBuffer is 128 bytes
local CAPACITY_STEP = 2048 -- entries, the step the engine grows its own buffer by
local SHADER_STORAGE_BARRIER_BIT = GL.SHADER_STORAGE_BARRIER_BIT

local cmpShader

-- One invocation per entry
local cmpSrc = [[
#version 430 core

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

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

layout(std140, binding=4) writeonly buffer UniformsBufferCopy {
	SUniformsBuffer uniCopy[];
};

uniform int numEntries; // not uint: the engine sets uniformInt values with glUniform1i

void main(void)
{
	uint index = gl_GlobalInvocationID.x;
	if (index >= uint(numEntries)) {
		return;
	}

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

local numEntries = 0
local capacity = 0

local copyRequested = false
local lastUpdateFrame = 0

local UniformsBufferCopy

local function allocateCopyBuffer(entries)
	if UniformsBufferCopy then
		UniformsBufferCopy:Delete()
	end
	capacity = mathCeil(entries / CAPACITY_STEP) * CAPACITY_STEP
	UniformsBufferCopy = gl.GetVBO(GL.SHADER_STORAGE_BUFFER, false)
	UniformsBufferCopy:Define(capacity, {
		{ id = 0, name = "modelUniformData", type = GL.FLOAT_VEC4, size = ENTRY_SIZE_IN_VEC4S },
	})
	UniformsBufferCopy:Clear()
end

-- The buffer is replaced when the engine outgrows it, so consumers fetch it every frame
local function getUnitUniformBufferCopy()
	if not copyRequested and UniformsBufferCopy then
		copyRequested = true
		widgetHandler:UpdateCallIn("DrawScreenPost")
	end
	return UniformsBufferCopy
end

function widget:Initialize()
	if not glGetEngineModelUniformDataSize then
		spEcho("UnitBufferUniform Copy: engine does not support gl.GetEngineModelUniformDataSize")
		widgetHandler:RemoveWidget()
		return
	end

	-- the second value is the size of all entries, not of one
	local entries, sizeInBytes = glGetEngineModelUniformDataSize(0)
	if not entries or entries < 1 or sizeInBytes ~= entries * ENTRY_SIZE_IN_VEC4S * 16 then
		spEcho("UnitBufferUniform Copy: invalid engine model uniform buffer size")
		widgetHandler:RemoveWidget()
		return
	end

	cmpShader = LuaShader({
		compute = cmpSrc,
		uniformInt = {
			numEntries = entries,
		},
	}, "cmpShader")
	if not cmpShader:Initialize() then
		widgetHandler:RemoveWidget()
		return
	end
	numEntries = entries
	allocateCopyBuffer(entries)

	WG.api_unitbufferuniform_copy = {
		GetUnitUniformBufferCopy = getUnitUniformBufferCopy,
	}
	widgetHandler:RegisterGlobal("GetUnitUniformBufferCopy", getUnitUniformBufferCopy)
	widgetHandler:RemoveCallIn("DrawScreenPost") -- until a consumer asks for the copy
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("GetUnitUniformBufferCopy")
	WG.api_unitbufferuniform_copy = nil

	if cmpShader then
		cmpShader:Finalize()
	end
	if UniformsBufferCopy then
		UniformsBufferCopy:Delete()
		UniformsBufferCopy = nil
	end
end

function widget:DrawScreenPost()
	local gameFrame = spGetGameFrame()
	if gameFrame == lastUpdateFrame then
		return
	end
	lastUpdateFrame = gameFrame

	local entries = glGetEngineModelUniformDataSize(0)
	if entries > capacity then
		allocateCopyBuffer(entries)
	end
	UniformsBufferCopy:BindBufferRange(COPY_BINDING) -- other users of the binding point replace it
	cmpShader:Activate()
	if entries ~= numEntries then
		numEntries = entries
		cmpShader:SetUniformInt("numEntries", entries)
	end
	glDispatchCompute(mathCeil(entries / GROUP_SIZE), 1, 1, SHADER_STORAGE_BARRIER_BIT)
	cmpShader:Deactivate()
end
