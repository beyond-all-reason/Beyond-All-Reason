#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)
#line 5000

layout (location = 0) in vec4 position_xy_uv; // l w rot and maxalpha
layout (location = 1) in vec4 uvoffsets; //idx, gfstart, currtime
layout (location = 2) in vec4 params;
layout (location = 3) in uvec4 instData; 

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

//layout(std140, binding = 0) readonly buffer MatrixBuffer {
//	mat4 mat[];
//};

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
	vec4 v_pos; 
	vec4 v_vel;
	vec4 v_params; //idx, gfstart, currtime
};

void main()
{	
	v_pos = uni[instData.y].drawpos;
	v_vel = uni[instData.y].speed;
	v_vel.w = uni[instData.y].health / uni[instData.y].maxHealth;
	v_params = uvoffsets;
	v_params.z = timeInfo.x;
	
	vec2 xy = position_xy_uv.xy;
	float idx = uvoffsets.x;
	vec4 vpos = vec4(xy.x, (idx+xy.y)/TEXY, 0.5, 1.0);
	
	gl_Position = vpos;
}
