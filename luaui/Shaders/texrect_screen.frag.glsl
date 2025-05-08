#version 430 core

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com), licensed under the MIT license

#line 20000

uniform vec4 uniformparams = vec4(0.0);

uniform sampler2D tex0;

//__DEFINES__

#ifdef CUSTOM_TEXRECT
	//__ENGINEUNIFORMBUFFERDEFS__
#endif

in DataVS {
	vec4 vs_position_texcoords;
};

out vec4 fragColor;

void main() {
	#ifdef CUSTOM_TEXRECT
		TEXRECT_PRE_FRAGMENT
	#endif
	vec4 texColor = texture(tex0, vs_position_texcoords.zw);
	fragColor = texColor;
	#ifdef CUSTOM_TEXRECT
		TEXRECT_POST_FRAGMENT
	#endif
}