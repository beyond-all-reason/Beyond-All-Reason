#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)
#line 5000

layout (location = 0) in vec4 position; // xyz and etc garbage
//layout (location = 1) in vec3 normals; // unused
//layout (location = 2) in vec2 uvs;  // unused

layout (location = 3) in vec4 worldposrad; 
layout (location = 4) in vec4 worldposrad2; 
layout (location = 5) in vec4 lightcolor; 
layout (location = 6) in vec4 falloff_dense_scattering;
layout (location = 7) in vec4 otherparams;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000
uniform int pointbeamcone = 0; // 0 = point, 1 = beam, 2 = cone

out DataVS {
	vec4 v_worldPosRad;
	vec4 v_worldPosRad2;
	vec4 v_lightcolor;
	vec4 v_falloff_dense_scattering;
	vec4 v_otherparams;
	vec4 v_debug;
};

void main()
{
	float time = timeInfo.x + timeInfo.w;
	v_worldPosRad = worldPosRad ;//
	
	vec4 worldPos = vec4(1.0);
	if (pointbeamcone == 0){
		worldPos = v_worldPosRad.xyz + position.xyz * v_worldPosRad.w;
	}
	if (pointbeamcone == 1){
		// we will tranform along this vector, where Y shall be the upvector
		// our null vector is +X
		vec3 centertoend = v_worldPosRad.xyz - v_worldPosRad2.xyz;
		float halfbeamlength = length(centertoend);
		// Scale the box to correct size (along beam is X dir)
		worldPos.xyz = position.xyz * vec3(halfbeamlength + worldposrad.w , worldposrad.w, worldposrad.w )
		// TODO rotate this box
		// Place the box in the world
		worldPos.xyz += v_worldPosRad.xyz;
	}
	if (pointbeamcone == 2){ //cone that points up, (y = 1), with radius =1, bottom flat on Y=0 plane
		
		
		
	}
	gl_Position = cameraViewProj * worldPos;

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