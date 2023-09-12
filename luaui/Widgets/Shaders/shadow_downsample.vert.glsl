#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

layout (location = 0) in vec4 positionxy_uv; // pos -1 to 1, uv 0 to 1

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

out DataVS {
	vec2 uv;
};

void main()
{
	vec2 uv = positionxy_uv.zw;
	gl_Position =  vec4( positionxy_uv.x, positionxy_uv.y, 0.5, 1);
}