function widget:GetInfo()
	return {
		name      = "Noise Tester",
		desc      = "Tests various noise functions",
		author    = "Beherith",
		date      = "2024.11.04",
		license   = "GPLv2",
		layer     = 100000,
		enabled   = true
	}
end

local autoreload = true
local noiseShader
local fullScreenRectVAO


local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")



VFS.Include(luaShaderDir.."instancevbotable.lua")

local minY, maxY = Spring.GetGroundExtremes()



local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com), Licensed under the MIT License

layout (location = 0) in vec4 position; // .xy is [-1, +1], .zw is [0, 1]

#line 10000

out DataVS {
	vec4 v_position;
};

void main()
{	
	// output the screen-space position exactly as a fullscreen quad, at a depth of 0
	gl_Position = vec4(position.xy, 0.0, 1.0);
	v_position = position;
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com), Licensed under the MIT License

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 20000

in DataVS {
	vec4 v_position;
};

uniform sampler2D mapDepths;

out vec4 fragColor;


#define PRIME_A 57                   
#define PRIME_B 1549                 // 1549.0 
// WOW 1549 is PERFECT!

float FBMNoise3D(in vec3 x) // nah this is the fastest!
{
	vec3 p = floor(x);
	vec3 f = fract(x);
	
	f = f * f * (3.0 - 2.0 * f);

	float n = p.x  + p.y * PRIME_A + p.z * PRIME_B;

	#if 1
		vec4 sin_0 = sin(vec4(0 , PRIME_A, PRIME_B, PRIME_A + PRIME_B) + n    );
		vec4 sin_1 = sin(vec4(0 , PRIME_A, PRIME_B, PRIME_A + PRIME_B) + n + 1);
	#else
		vec4 offset1 = vec4(0 , PRIME_A, PRIME_B, PRIME_A + PRIME_B) + n    ;
		vec4 offset2 = vec4(0 , PRIME_A, PRIME_B, PRIME_A + PRIME_B) + n + 1;
		
		vec4 sin_0 = sin(vec4(offset1.xy, offset2.xy));
		vec4 sin_1 = cos(vec4(offset1.zw, offset2.zw));

	#endif 
	vec4 hash_0 = fract(sin_0 * 4758.5453);
	vec4 hash_1 = fract(sin_1 * 4758.5453); 

	vec4 mix_4 = mix(hash_0, hash_1, f.x);
	vec2 mix_2 = mix(mix_4.xz, mix_4.yw, f.y);
	float myn = mix(mix_2.x, mix_2.y, f.z);
	return myn;
}

vec4 FBMNoiseRGBA(in vec3 x) // 4 channels of noise cost 2x as much as 1 channel, still better than 4x
{
	vec3 p = floor(x);
	vec3 f = fract(x);
	
	f = f * f * (3.0 - 2.0 * f);
	
	float n = p.x  + p.y * PRIME_A + p.z * PRIME_B ;

	vec4 sin_0 = sin(vec4(0 , PRIME_A, PRIME_B, PRIME_A + PRIME_B) + n    );
	vec4 sin_1 = sin(vec4(0 , PRIME_A, PRIME_B, PRIME_A + PRIME_B) + n + 1);
	
	vec4 hash_0_r = fract(sin_0 * 43758.5453);
	vec4 hash_1_r = fract(sin_1 * 43758.5453);
	vec4 mix_4_r = mix(hash_0_r, hash_1_r, f.x);
	vec2 mix_2_r = mix(mix_4_r.xz, mix_4_r.yw, f.y);
	float myn_r = mix(mix_2_r.x, mix_2_r.y, f.z);

	vec4 hash_0_g = fract(sin_0 * 33758.5453);
	vec4 hash_1_g = fract(sin_1 * 33758.5453);
	vec4 mix_4_g = mix(hash_0_g, hash_1_g, f.x);
	vec2 mix_2_g = mix(mix_4_g.xz, mix_4_g.yw, f.y);
	float myn_g = mix(mix_2_g.x, mix_2_g.y, f.z);

	vec4 hash_0_b = fract(sin_0 * 43758.5453 );
	vec4 hash_1_b = fract(sin_1 * 43758.5453 );
	vec4 mix_4_b = mix(hash_0_b, hash_1_b, f.x);
	vec2 mix_2_b = mix(mix_4_b.xz, mix_4_b.yw, f.y);
	float myn_b = mix(mix_2_b.x, mix_2_b.y, f.z);

	vec4 hash_0_a = fract(sin_0 * 13758.5453);
	vec4 hash_1_a = fract(sin_1 * 13758.5453);
	vec4 mix_4_a = mix(hash_0_a, hash_1_a, f.x);
	vec2 mix_2_a = mix(mix_4_a.xz, mix_4_a.yw, f.y);
	float myn_a = mix(mix_2_a.x, mix_2_a.y, f.z);

	return vec4(myn_r, myn_g, myn_b, myn_a);
}


#line 21000
void main(void)

{
	// use v_position to draw a sphere:
	vec3 normSphere = v_position.xyz;
	// scale it to make a sphere within view size
	normSphere.x*= viewGeometry.x / viewGeometry.y;
	if (length(normSphere.xy) < 1.0)
	{
		
		normSphere.z = sqrt (1.0 - dot(normSphere.xy, normSphere.xy));
	}
	else
	{
		normSphere.z = normSphere.x * 0.1;
	}
	float size = sin(0.01 * (timeInfo.x+timeInfo.w));
	fragColor.rgb = vec3(FBMNoise3D(normSphere.xyz * (200 + 20 * size)));
    fragColor.a = 0.5;
}

]]

local shaderSourceCache = {
    vertex = vsSrc,
    fragment = fsSrc,
    --vssrcpath = "LuaUI/Widgets/Shaders/norush_timer.vert.glsl",
    --fssrcpath = "LuaUI/Widgets/Shaders/norush_timer.frag.glsl",
    uniformInt = {
        mapDepths = 0,
    },
    uniformFloat = {
    },
    shaderName = "Norush Timer GL4",
    shaderConfig = {
    }
}


function widget:Initialize()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
    vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
    fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
    noiseShader =  LuaShader(
    {
      vertex = vsSrc:gsub("//__DEFINES__", "#define MYGRAVITY " .. tostring(Game.gravity+0.1)),
      fragment = fsSrc:gsub("//__DEFINES__", "#define USE_STIPPLE ".. tostring(0) ),
      --geometry = gsSrc, no geom shader for now
      uniformInt = {
        mapDepths = 0,
      },
      uniformFloat = {
        circleuniforms = {1,1,1,1}, -- unused
      },
    },
    "noise shader"
    )
    shaderCompiled = noiseShader:Initialize()
	
    if not shaderCompiled then widgetHandler:RemoveWidget(self) end

	--noiseShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or noiseShader
	fullScreenRectVAO = MakeTexRectVAO()
end

function widget:DrawScreen()
	if autoReload then
		--noiseShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or noiseShader
	end

    gl.Culling(GL.FRONT)
	gl.DepthTest(false)

	noiseShader:Activate()
	--noiseShader:SetUniform("noiseShader1", 1)
	fullScreenRectVAO:DrawArrays(GL.TRIANGLES)
	noiseShader:Deactivate()
	gl.Texture(0, false)
	gl.Culling(false)
	gl.DepthTest(false)
end