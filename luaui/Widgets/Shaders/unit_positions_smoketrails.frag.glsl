#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000
uniform float iconDistance = 20000.0;
in DataGS {
	vec4 g_centerpos; // xyz, and width [-1,1] packed into w
	vec4 g_uv;
};

uniform sampler3D noisetex3dcube;
uniform sampler2D minimap;
out vec4 fragColor;

void main(void)
{
	vec4 texcolor = vec4(1.0);
	#if (USETEXTURE == 1)
		texcolor = texture(noisetex3dcube, g_centerpos.xyz);
	#endif
	fragColor.rgba = vec4(g_uv.rgb * texcolor.rgb , texcolor.a  );
	POST_SHADING
	fragColor.rgba = vec4(g_uv.rgw, 0.6);
	#if (DISCARD == 1)
		if (fragColor.a < 0.01) discard;
	#endif
	//fragColor.a = (1.0 -  g_uv.w);
	
	return;
	vec3 noisePos = g_centerpos.xyz - vec3(0, 0.5 * timeInfo.x,0);
	vec4 noise = texture(noisetex3dcube, noisePos * 0.01);
	fragColor.rgb = vec3(noise.a);
	fragColor.a = noise.a * (1.0 - abs(g_centerpos.w)) ;
	fragColor.a *= (1.0 -  g_uv.w);
	
	vec2 minimapUV = g_centerpos.xz/ mapSize.xy;
	vec4 minimapColor = texture(minimap, minimapUV);
	
	fragColor.rgb= (minimapColor.rgb * (dot(noise.rgb, vec3(0.5))));
	//fragColor.a *= 1.5;
}