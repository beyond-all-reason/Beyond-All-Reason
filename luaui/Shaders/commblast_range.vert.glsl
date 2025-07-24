#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)
#line 5000

layout (location = 0) in vec4 position; // l w rot and maxalpha
layout (location = 1) in vec3 normals;
layout (location = 2) in vec2 uvs;

layout (location = 3) in vec4 params_alphastart_alphaend_gameframe; 
layout (location = 4) in uvec4 instData; 

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

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

#line 10000

#define SNORM2NORM(value) (value * 0.5 + 0.5)

out DataVS {
	flat vec3 v_centerpos; // xyz and radius?
	flat vec4 v_teamcolor; // red or teamcolor, and alpha modifier
	noperspective vec2 v_screenUV;
};

void main()
{	
	uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
	vec4 teamCol = teamColor[teamIndex];
	v_centerpos = uni[instData.y].drawPos.xyz;

	vec4 worldPos = vec4(1.0);

	if ((uni[instData.y].composite & 0x00001fu) == 0u ){
		// if the unit is not visible, then just transform the sphere to 0
		v_centerpos = vec3(0.0); 
	}
	else{	
		worldPos.xyz = v_centerpos + position.xyz * FULLRADIUS;
	}
	gl_Position = cameraViewProj * worldPos;
	v_screenUV = SNORM2NORM(gl_Position.xy / gl_Position.w);
	
	vec3 camPos = cameraViewInv[3].xyz;
	
	// TODO:
	// modulate alpha based on time from params_alpha_health
	float time = timeInfo.x + timeInfo.w ;
	
	float alphasmooth = clamp((time - params_alphastart_alphaend_gameframe.z) / 15.0, 0.0, 1.0);
	alphasmooth = mix(params_alphastart_alphaend_gameframe.x, params_alphastart_alphaend_gameframe.y, alphasmooth);
	// modulate alpha based on health
	float damagedness = 1.0 - clamp( uni[instData.y].health/ uni[instData.y].maxHealth, 0, 1);
	// modulate alpha based on distance from camera
	float distanceToCamera = length(camPos - v_centerpos.xyz);
	distanceToCamera = clamp((distanceToCamera -2000)/1000,0,1);
	v_teamcolor.rgb = vec3(1.0, 0.0, 0.0);
	#if (TEAMCOLORED == 1)
		v_teamcolor.rgb = teamCol.rgb;
	#endif
	
	v_teamcolor.a = alphasmooth + damagedness - distanceToCamera;
}
