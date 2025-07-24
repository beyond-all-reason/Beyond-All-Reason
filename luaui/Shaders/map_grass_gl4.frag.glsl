#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is Copyright (c) 2024 Beherith (mysterme@gmail.com) and licensed under the MIT License

#line 20000
//__DEFINES__
/*
#define    MAPCOLORFACTOR 0.4
#define    DARKENBASE 0.5
#define    ALPHATHRESHOLD 0.01
#define    WINDSTRENGTH 1.0
#define    WINDSCALE 0.33
#define    FADESTART 2000
#define    FADEEND 3000
*/

uniform vec4 grassuniforms; //windx, windz, windstrength, globalalpha

uniform float distanceMult; //yes this is the additional distance multiplier

uniform vec4 nightFactor;

uniform sampler2D grassBladeColorTex;
uniform sampler2D mapGrassColorModTex;
uniform sampler2D grassWindPerturbTex;

in DataVS {
	//vec3 worldPos;
	//vec3 Normal;
	vec4 texCoord0;
	//vec3 Tangent;
	//vec3 Bitangent;
	vec4 mapColor;
	//vec4 grassNoise;
	vec4 instanceParamsVS;
	#if DEBUG == 1 
		vec4 debuginfo;
	#endif
};

//__ENGINEUNIFORMBUFFERDEFS__

out vec4 fragColor;

void main() {
	fragColor = texture(grassBladeColorTex, texCoord0.xy);
	fragColor.rgb = mix(fragColor.rgb,fragColor.rgb * (mapColor.rgb * 2.0), MAPCOLORFACTOR); //blend mapcolor multiplicative
	fragColor.rgb = mix(fragColor.rgb,mapColor.rgb, (1.0 - texCoord0.y)* MAPCOLORBASE); // blend more mapcolor mix at base
	//fragColor.rgb = fragColor.rgb * 0.8; // futher darken
	fragColor.rgb = mix(fogColor.rgb,fragColor.rgb, mapColor.a ); // blend fog
	fragColor.a = fragColor.a * grassuniforms.w * instanceParamsVS.x; // increase transparency with distance
	fragColor.rgb = fragColor.rgb * instanceParamsVS.y; // darken with shadows
	fragColor.rgb = fragColor.rgb * instanceParamsVS.z; // darken out of los
	fragColor.rgb = fragColor.rgb * instanceParamsVS.w; // darken with windnoise
	fragColor.rgb *= GRASSBRIGHTNESS;

	fragColor.a = clamp((fragColor.a-0.5) * 1.5 + 0.5, 0.0, 1.0);

	//fragColor.rgb = vec3(instanceParamsVS.y	);
	//fragColor.a = 1;
	//fragColor = vec4(debuginfo.r,debuginfo.g, 0, (debuginfo.g)*5	);
	//fragColor = vec4(1.0, 1.0, 1.0, 1.0);
	//fragColor = vec4(debuginfo.w*5, 1.0 - debuginfo.w*5.0, 0,1.0);
	#if DEBUG == 1
		fragColor.a *= clamp(texCoord0.w *3,0.0,1.0);
	#endif
	fragColor.rgb *= nightFactor.rgb;

	if (fragColor.a < ALPHATHRESHOLD)
		discard;// needed for depthmask

}