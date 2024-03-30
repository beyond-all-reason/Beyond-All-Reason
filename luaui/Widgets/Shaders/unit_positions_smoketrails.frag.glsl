#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000
uniform float iconDistance = 20000.0;
in DataGS {
	vec4 g_centerpos;
	vec4 g_uv;
};

uniform sampler3D noisetex3dcube;
out vec4 fragColor;

void main(void)
{
	vec4 texcolor = vec4(1.0);
	#if (USETEXTURE == 1)
		texcolor = texture(noisetex3dcube, g_centerpos.xyz);
	#endif
	fragColor.rgba = vec4(g_uv.rgb * texcolor.rgb , texcolor.a  );
	POST_SHADING
	fragColor.rgba = vec4(g_uv.rgb, 1.0);
	#if (DISCARD == 1)
		if (fragColor.a < 0.01) discard;
	#endif
}