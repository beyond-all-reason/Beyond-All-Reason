#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)
#line 5000

layout (location = 0) in vec4 position; // l w rot and maxalpha
layout (location = 1) in vec3 normals;
layout (location = 2) in vec2 uvs;

layout (location = 3) in vec4 params_alpha_health; 
layout (location = 4) in uvec4 instData; 

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

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

	vec4 speed;
	vec4[5] userDefined; //can't use float[20] because float in arrays occupies 4 * float space
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
	SUniformsBuffer uni[];
};

#line 10000

out DataVS {
	vec4 v_worldPosRad;
	vec4 v_params;
	vec3 v_centerpos;
	vec4 v_fragWorld;
};

void main()
{
	
	mat4 worldMatrix = mat[instData.x];
	v_centerpos = worldMatrix[3].xyz;
	vec4 worldPos = vec4(1.0);
	
	worldPos.xyz =  position.xyz * FULLRADIUS;
	
	worldPos = worldMatrix * worldPos;
	v_worldPosRad = worldPos;
	
	v_fragWorld = cameraViewProj * worldPos;
	gl_Position = v_fragWorld;
	
	vec3 camPos = cameraViewInv[3].xyz;
}