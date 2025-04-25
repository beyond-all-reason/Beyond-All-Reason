local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name	  = "Skybox",
		desc	  = "Very psychedelic",
		author	  = "Beherith",
		layer	  = 1900,
		enabled   = true,
	}
end

local glTexture		 = gl.Texture
local glBlending	 = gl.Blending

local luaShaderDir = "LuaUI/Include/"


local vsglass = [[
#version 430

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is Copyright (c) 2024 Beherith (mysterme@gmail.com) and licensed under the MIT License

#line 10000
layout (location = 0) in vec4 pos;

out DataVS {
	vec4 v_pos;
};
//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

void main()
{
	v_pos = pos;
	gl_Position = cameraViewProj * vec4(v_pos.xyz*5000, 1.0);
}
]]

local fsglass = [[
#version 430
#line 20058

//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D screenCopyTex;
uniform samplerCube skyboxTex;

out vec4 fragColor;

in DataVS {
	vec4 v_pos;
};
uniform float iTime = 0;

void main( )
{
	vec2 fc = gl_FragCoord.xy / vec2(64.0);
	vec3 c = texture(skyboxTex, normalize(v_pos.xyz)).rgb;
	fragColor = vec4(c, step(0.1, fract(fc.x + fc.y)));
}
]]

local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")

VFS.Include(luaShaderDir.."instancevbotable.lua")

local screenCopyTex
local glassShader
local fullTexQuad
local cubevbo 
local cubevao
 

function widget:Initialize()
	glassShader = LuaShader.CheckShaderUpdates({
		vsSrc = vsglass,
		fsSrc = fsglass,
		uniformInt = {
			skyboxTex = 1,
			screenCopyTex = 0,
		},
		uniformFloat = {
			iTime = 1,
			strength = 0,
		},
		shaderConfig = {},
		silent = false,
		forceupdate = true,

	})

	local shaderCompiled = glassShader:Initialize()
	if not shaderCompiled then
			Spring.Echo("Failed to compile Contrast Adaptive Sharpen shader, removing widget")
			widgetHandler:RemoveWidget()
			return
	end
	cubevbo = makeBoxVBO(-1,-1,-1, 1, 1, 1)

	cubevao = gl.GetVAO()
	cubevao:AttachVertexBuffer(cubevbo)
end

function widget:Shutdown()
	--gl.DeleteTexture(screenCopyTex)
	if glassShader then
		glassShader:Finalize()
	end
end

function widget:DrawAlphaFeaturesLua(drawReflection, drawRefraction)
	gl.Culling(false)
	glBlending(true)
	gl.Texture(1, "luaui/images/HUBBLE ANDROMEDA 2k.dds")
	glassShader:Activate()
	cubevao:DrawArrays(GL.TRIANGLES, 36)
	glassShader:Deactivate()
	glBlending(true)
end

