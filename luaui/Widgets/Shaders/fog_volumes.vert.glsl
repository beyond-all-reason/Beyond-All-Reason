#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)
#line 5000

layout (location = 0) in vec4 position; // l w rot and maxalpha
layout (location = 1) in vec3 normals;
layout (location = 2) in vec2 uvs;

layout (location = 3) in vec4 worldPosRad; 
layout (location = 4) in vec4 colordensity; 
layout (location = 5) in vec4 velocity; 
layout (location = 6) in vec4 fadeparameters; //fadeinstart, fadeinrate, fadeoutstart, fadeoutrate, 
layout (location = 7) in vec4 spawnframe_frequency_riserate_windstrength;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

out DataVS {
	vec4 v_worldPosRad;
	vec4 v_colordensity;
	vec4 v_spawnframe_frequency_riserate_windstrength;
	vec2 v_uvs;
	vec3 v_fragWorld;
	float currfade;
};

void main()
{
	float time = timeInfo.x + timeInfo.w;
	v_worldPosRad = worldPosRad ;//
	#if MOTION == 1
		v_worldPosRad += (time - spawnframe_frequency_riserate_windstrength.x) * velocity;
	#endif
	v_colordensity = colordensity;
	v_spawnframe_frequency_riserate_windstrength = spawnframe_frequency_riserate_windstrength;
	v_uvs = v_uvs;
	vec3 worldPos = position.xyz * v_worldPosRad.w + v_worldPosRad.xyz ;
	
	gl_Position = cameraViewProj * vec4(worldPos, 1.0);
	
	vec3 camPos = cameraViewInv[3].xyz;
	v_fragWorld = worldPos.xyz;
	
	float fadeinstart = fadeparameters.x;
	float fadeinrate = fadeparameters.y;
	float fadeoutstart = fadeparameters.z;
	float fadeoutrate = fadeparameters.w;
	#if MOTION == 1
		currfade = clamp((time - fadeinstart) * fadeinrate, 0.0, 1.0) - clamp((time - fadeoutstart) * fadeoutrate, 0.0, 1.0);
	#else
		currfade = 1.0;
	#endif
}