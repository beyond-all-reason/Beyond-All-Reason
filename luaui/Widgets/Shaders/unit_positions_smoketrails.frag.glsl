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
	vec4 g_uv; // x is length ,y , z is index , w progress
};

uniform sampler3D noisetex3dcube;
uniform sampler2D minimap;
uniform sampler2D heightMap;

out vec4 fragColor;

void main(void)
{

	vec2 UVHM =  heightmapUVatWorldPos(g_centerpos.xz);
	float worldHeight = textureLod(heightMap, UVHM, 0.0).x;
	
	vec4 texcolor = vec4(1.0);

	fragColor.rgba = vec4(g_uv.rgb * texcolor.rgb , texcolor.a  );
	// POST_SHADING
	fragColor.rgba = vec4(g_uv.rgw, 0.6);
	#if (DISCARD == 1)
		if (fragColor.a < 0.01) discard;
	#endif
	fragColor.a = (1.0 );
	fragColor.r = abs(g_centerpos.w);
	vec4 noise;
	vec3 noisePos;
	float progress = 1.0 -  g_uv.w * g_uv.w;
	
	
	vec2 minimapUV = g_centerpos.xz/ mapSize.xy;
	vec4 minimapColor = texture(minimap, minimapUV);
		
	// BILLBOARDS:
	#if 1
		noisePos = (g_centerpos.xyz - vec3(0, 0.1 * timeInfo.x,0)) * 0.015	 + g_uv.zzz;
		noise = texture(noisetex3dcube, noisePos);
		vec2 distcenter = (abs(g_uv.xy * 2.0 - 1.0));
		float alphacircle = 1.0 - dot(distcenter, distcenter);
		fragColor.rgba = vec4(vec3(noise.a), alphacircle * progress * noise.a);
		float soften = clamp((g_centerpos.y - worldHeight) * 0.125, 0, 1.5);
		fragColor.a *= soften;
		fragColor.rgb = mix(fragColor.rgb,  fragColor.rgb *(minimapColor.rgb *1.5), 0.25 + 	noise.b);
	
		
		//fragColor.rgba = vec4(vec3(g_uv.rgb), 1 );
		return;
	#endif
	
	return;
	
	
	
	noisePos = g_centerpos.xyz - vec3(0, 0.5 * timeInfo.x,0);
	noise = texture(noisetex3dcube, noisePos * 0.01);
	fragColor.rgb = vec3(noise.a);
	fragColor.a = noise.a * (1.0 - abs(g_centerpos.w)) ;
	fragColor.a *= (1.0 -  g_uv.w);
	
	
	fragColor.rgb= (minimapColor.rgb * (dot(noise.rgb, vec3(0.5))));
	//fragColor.a *= 1.5;
} 