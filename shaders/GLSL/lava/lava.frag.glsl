#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is Copyright (c) 2024 Beherith (mysterme@gmail.com) and licensed under the MIT License

#line 20000

uniform float lavaHeight;
uniform float heatdistortx;
uniform float heatdistortz;

uniform sampler2D heightmapTex;
uniform sampler2D lavaDiffuseEmit;
uniform sampler2D lavaNormalHeight;
uniform sampler2D lavaDistortion;
uniform sampler2DShadow shadowTex;
uniform sampler2D infoTex;

in DataVS {
	vec4 worldPos;
	vec4 worldUV;
	float inboundsness;
	vec4 randpervertex;
};

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

vec2 inverseMapSize = 1.0 / mapSize.xy;

float heightAtWorldPos(vec2 w){
	// Some texel magic to make the heightmap tex perfectly align:
	const vec2 heightmaptexel = vec2(8.0, 8.0);
	w +=  vec2(-8.0, -8.0) * (w * inverseMapSize) + vec2(4.0, 4.0) ;

	vec2 uvhm = clamp(w, heightmaptexel, mapSize.xy - heightmaptexel);
	uvhm = uvhm	* inverseMapSize;

	return texture(heightmapTex, uvhm, 0.0).x;
}

out vec4 fragColor;

#line 22000


void main() {

	vec4 camPos = cameraViewInv[3];
	vec3 worldtocam = camPos.xyz - worldPos.xyz;

	// Sample emissive as heat indicator here for later displacement
	vec4 nodiffuseEmit =  texture(lavaDiffuseEmit, worldUV.xy * WORLDUVSCALE );

	vec2 rotatearoundvertices = worldUV.zw * SWIRLAMPLITUDE;

	float localheight = OUTOFMAPHEIGHT ;
	if (inboundsness > 0)
		localheight = heightAtWorldPos(worldPos.xz);

	if (localheight > lavaHeight - HEIGHTOFFSET ) discard;

	// Calculate how far the fragment is from the coast
	float coastfactor = clamp((localheight-lavaHeight + COASTWIDTH + HEIGHTOFFSET) * (1.0 / COASTWIDTH),  0.0, 1.0);

	// this is ramp function that ramps up for 90% of the coast, then ramps down at the last 10% of coastwidth
	if (coastfactor > 0.90)
	{coastfactor = 9*( 1.0 - coastfactor);
		coastfactor = pow(coastfactor/0.9, 1.0);
	}else{
		coastfactor = pow(coastfactor/0.9, 3.0);
	}

	// Sample shadow map for shadow factor:
	vec4 shadowVertexPos = shadowView * vec4(worldPos.xyz,1.0);
	shadowVertexPos.xy += vec2(0.5);
	float shadow = clamp(textureProj(shadowTex, shadowVertexPos), 0.0, 1.0);

	// Sample LOS texture for LOS, and scale it into a sane range
	vec2 losUV = clamp(worldPos.xz, vec2(0.0), mapSize.xy ) / mapSize.zw;
	float losTexSample = dot(vec3(0.33), texture(infoTex, losUV).rgb) ; // lostex is PO2
	losTexSample = clamp(losTexSample * 4.0 - 1.0, LOSDARKNESS, 1.0);
	if (inboundsness < 0.0) losTexSample = 1.0;

	// We shift the distortion texture camera-upwards according to the uniforms that got passed in
	vec2 camshift =  vec2(heatdistortx, heatdistortz) * 0.001;
	vec4 distortionTexture = texture(lavaDistortion, (worldUV.xy + camshift) * 45.2) ;

	vec2 distortion = distortionTexture.xy * 0.2 * 0.02;
	distortion.xy *= clamp(nodiffuseEmit.a * 0.5 + coastfactor, 0.2, 2.0);

	vec2 diffuseNormalUVs =  worldUV.xy * WORLDUVSCALE + distortion.xy + rotatearoundvertices;
	vec4 normalHeight =  texture(lavaNormalHeight, diffuseNormalUVs);

	// Perform optional parallax mapping
	#if (PARALLAXDEPTH > 0 )
		vec3 viewvec = normalize(worldtocam * -1.0);
		float pdepth = PARALLAXDEPTH * (PARALLAXOFFSET - normalHeight.a ) * (1.0 - coastfactor);
		diffuseNormalUVs += pdepth * viewvec.xz * 0.002;
		normalHeight =  texture(lavaNormalHeight, diffuseNormalUVs);
	#endif

	vec4 diffuseEmit =   texture(lavaDiffuseEmit , diffuseNormalUVs);

	fragColor.rgba = diffuseEmit;

	// Calculate lighting based on normal map
	vec3 fragNormal = (normalHeight.xzy * 2.0 -1.0);
	fragNormal.z = -1 * fragNormal.z; // for some goddamned reason Z(G) is inverted again
	fragNormal = normalize(fragNormal);
	float lightamount = clamp(dot(sunDir.xyz, fragNormal), 0.2, 1.0) * max(0.5,shadow);
	fragColor.rgb *= lightamount;

	fragColor.rgb += COASTCOLOR * coastfactor;

	// Specular Color
	vec3 reflvect = reflect(normalize(-1.0 * sunDir.xyz), normalize(fragNormal));
	float specular = clamp(pow(dot(normalize(worldtocam), normalize(reflvect)), SPECULAREXPONENT), 0.0, SPECULARSTRENGTH) * shadow;
	fragColor.rgb += fragColor.rgb * specular;

	fragColor.rgb += fragColor.rgb * (diffuseEmit.a * distortion.y * 700.0);

	fragColor.rgb *= losTexSample;

	// some debugging stuff:
	//fragColor.rgb = fragNormal.xzy;
	//fragColor.rgb = vec3(losTexSample);
	//fragColor.rgb = vec3(shadow);
	//fragColor.rgb = distortionTexture.rgb ;
	//fragColor.rg = worldUV.zw  ;
	//fragColor.rgba *= vec4(fract(hmap*0.05));
	//fragColor.rgb = vec3(randpervertex.w * 0.5 + 0.5);
	//fragColor.rgb = fract(4*vec3(coastfactor));
	fragColor.a = 1.0;
	fragColor.a = clamp(  inboundsness * 2.0 +2.0, 0.0, 1.0);
	SWIZZLECOLORS
}
