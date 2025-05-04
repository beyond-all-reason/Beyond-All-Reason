#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com), licensed under the MIT license

layout (location = 0) in vec4 position_texcoords; // .xy is [-1, +1], uv is [0, 1]

//__DEFINES__

#ifdef CUSTOM_TEXRECT
	//__ENGINEUNIFORMBUFFERDEFS__
#endif

#line 10000

out DataVS {
	vec4 vs_position_texcoords; // .xy is [-1, +1], uv is [0, 1]
};

void main()
{	
	#ifdef CUSTOM_TEXRECT
		TEXRECT_PRE_VERTEX
	#endif
	// output the screen-space position exactly as a fullscreen quad, at a depth of 0
	gl_Position = vec4(position_texcoords.xy, 0.0, 1.0);
	vs_position_texcoords = position_texcoords;
	#ifdef CUSTOM_TEXRECT
		TEXRECT_POST_VERTEX
	#endif
}