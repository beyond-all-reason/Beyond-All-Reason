#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

layout (location = 0) in vec4 positionxy_xyfract; // l w rot and maxalpha

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

out DataVS {
	vec4 v_worldPos;
};

void main()
{
	vec2 screenPos = positionxy_xyfract.xy ;
	gl_Position =  vec4( screenPos.x, screenPos.y, 0.5, 1);
}