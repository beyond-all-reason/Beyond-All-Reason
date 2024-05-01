#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

// TODO: maybe sample SSMF mapnormals too?

#line 30000
uniform float iconDistance;
in DataGS {
	//vec4 g_color;
	vec4 g_uv;
	vec4 g_position; // how to get tbnmatrix here?	
	vec4 g_parameters; // x: BWfactor, y:glowsustain, z:glowadd,
	mat3 tbnmatrix; // this currently contains the Z-up world-rotated orthogonal coords of each vertex
};

uniform sampler2D infoTex;
uniform sampler2D miniMapTex;
uniform sampler2D mapNormalsTex;
uniform sampler2DShadow shadowTex;
uniform sampler2D atlasColorAlpha;
uniform sampler2D atlasNormals;


#if (PARALLAX == 1)
	uniform sampler2D atlasHeights;
#endif

#if (AMBIENTOCCLUSION == 1)
	uniform sampler2D atlasORM;
#endif

#if (USEGLOW == 1)
	uniform sampler2D atlasRG;
#endif

out vec4 fragColor;

// This blends shadow amounts along the warp
float shadowAtWorldPosSoft(vec3 worldPos){
		vec4 shadowVertexPos = shadowView * vec4(worldPos,1.0);
		shadowVertexPos.xy += vec2(0.5);
		float localShadow = clamp(textureProj(shadowTex, shadowVertexPos), 0.0, 1.0);
		float shadowDelta = 0.25 * (abs(dFdx(localShadow)) + abs(dFdy(localShadow)));
		localShadow = mix(shadowDelta, 1.0 - shadowDelta, localShadow);
		return localShadow;
}

vec3 Temperature(float temperatureInKelvins)
{
	vec3 retColor;
	
	float coldness = clamp((temperatureInKelvins - 300)* 0.0005, 0.0, 1.0) ;
	temperatureInKelvins = clamp(temperatureInKelvins, 1000.0, 40000.0) / 100.0;
	
	if (temperatureInKelvins <= 66.0)
	{
		retColor.r = 1.0;
		retColor.g = 0.39008157876901960784 * log(temperatureInKelvins) - 0.63184144378862745098;
	}
	else
	{
		float t = temperatureInKelvins - 60.0;
		retColor.r = 1.29293618606274509804 * pow(t, -0.1332047592);
		retColor.g = 1.12989086089529411765 * pow(t, -0.0755148492);
	}
	
	if (temperatureInKelvins >= 66.0)
		retColor.b = 1.0;
	else if(temperatureInKelvins <= 19.0)
		retColor.b = 0.0;
	else
		retColor.b = 0.54320678911019607843 * log(temperatureInKelvins - 10.0) - 1.19625408914;

	retColor = clamp(retColor,0.0,1.0);
	retColor = mix( vec3(0.0),retColor, coldness);
	return retColor;
}

// RNM func from: https://blog.selfshadow.com/publications/blending-in-detail/
vec3 ReOrientNormalPacked(vec3 basenormal, vec3 detailnormal){ // for normals packed to [0,1], z-up
	vec3 t = basenormal.xyz   * vec3( 2.0,  2.0, 2.0) + vec3(-1.0, -1.0,  0.0);
	vec3 u = detailnormal.xyz * vec3(-2.0, -2.0, 2.0) + vec3( 1.0,  1.0, -1.0);
	vec3 r = t * dot(t, u) - u * t.z;
	return normalize(r);
}
vec3 ReOrientNormalUnpacked(vec3 basenormal, vec3 detailnormal){ // for unpacked [-1,1] normals, only works when Z is up
	vec3 t = basenormal.xyz + vec3(0.0, 0.0,  1.0);
	vec3 u = detailnormal.xyz * vec3(-1.0, -1.0, 1.0);
	vec3 r = t * dot(t, u)/t.z - u;
	return normalize(r);
}

vec2 ParallaxMapping(vec2 texCoords, vec3 viewDir, float height)
{    
    vec2 p = (viewDir.xz)* (height * 1);
    return p;    
} 

#line 31000
void main(void)
{
	vec3 campos = cameraViewInv[3].xyz;
	vec3 camtoworld = normalize(g_position.xyz - campos);
	
	vec3 tangentviewpos = (tbnmatrix * campos.xzy).xyz; // Y points to camera
	vec3 tangentfragpos = (tbnmatrix * g_position.xzy).xyz; // Y points up
	vec3 tangentviewdir =  normalize(tangentfragpos - tangentviewpos); // Y points up!
	vec3 tspace = tangentfragpos - tangentviewpos;
	
	#if (PARALLAX == 1) 
		vec4 tex3color = texture(atlasHeights, g_uv.xy);
		//float height = 
		
		// do parallax here !
		vec2 parallaxUV = (tangentviewdir.xz) * (1.0 - tex3color.b )* 0.00002;
	#else
		vec2 parallaxUV = vec2(0.0);
		
	#endif

	
	vec2 uvhm = heightmapUVatWorldPos(g_position.xz);
	vec4 minimapcolor = textureLod(miniMapTex, uvhm, 0.0);
	vec3 mapnormal = textureLod(mapNormalsTex, uvhm, 0.0).raa; // seems to be in the [-1, 1] range!, raaa is its true return
	mapnormal.g = sqrt( 1.0 - dot( mapnormal.rb, mapnormal.rb)); // reconstruct Y	from it
	float offaxis = 1.0 - clamp(dot(mapnormal,-camtoworld), 0.0, 1.0);
	float bias = (offaxis*offaxis)*-2.0;
	
	vec4 tex1color = texture(atlasColorAlpha, g_uv.xy - parallaxUV.xy, bias);
	tex1color.rgb = mix (tex1color.rgb, vec3(dot(tex1color.rgb, vec3(0.299, 0.587, 0.114))), g_parameters.x);
	
	// bail early if theres shit here, but this might not be useful in the long term, due to no emissive application?
	
	if (tex1color.a < 0.005){
		fragColor.rgba = vec4(0.0); 
		discard; 
		return;
	}
	
	vec4 tex2color = texture(atlasNormals, g_uv.xy  - parallaxUV.xy, bias);
	vec3 fragNormal = tex2color.rgb * 2.0 - 1.0;
	if (dot(tex2color.rgb, vec3(1.0)) < 0.001) fragNormal = vec3(0.0, 0.0, 1.0);// check if the normals are missing, if yes, then sub with Z up. 
	
	// Ambient color calculation, tint with minimap, and with sunAmbientMap
	vec3 blendedcolor = tex1color.rgb * (minimapcolor.rgb * 2.0); // just your basic color modulation
	blendedcolor.rgb = mix(tex1color.rgb, blendedcolor.rgb, MINIMAPCOLORBLENDFACTOR);
	fragColor.rgb = blendedcolor * (sunAmbientMap.rgb * 2.0); 
	
	// take the square of the alpha, this is not ideal, but works well in practice
	fragColor.a = tex1color.a * tex1color.a * 0.999; 
	
	// Reorient the normals of the decal according to what we sampled from mapnormals and decal
	vec3 worldspacenormal = tbnmatrix * fragNormal.rgb;
	vec3 reorientedNormal = ReOrientNormalUnpacked(mapnormal.xzy, worldspacenormal.xzy).xzy;
	
	//debug the normals:
	/* 
		if (fract(gl_FragCoord.x * 0.01)>0.5)
			fragColor.rgb = (worldspacenormal + 1.0) * 0.5;
		else
			fragColor.rgb = (reorientedNormal + 1.0) * 0.5;
		fragColor.a = 1.0;
		return;
	*/
	// diffuse lighting, apply global sunDiffuseMap
	float diffuselight = clamp(dot(sunDir.xyz, reorientedNormal), -1.0, 1.0);
	fragColor.rgb += vec3(diffuselight) * ( fragColor.rgb * sunDiffuseMap.rgb * 2.0);
	
	// Specular Color
	vec3 reflvect = reflect(normalize(1.0 * sunDir.xyz), reorientedNormal);
	float specular = clamp(pow(clamp(dot(normalize(camtoworld), normalize(reflvect)), 0.0, 1.0), SPECULAREXPONENT), 0.0, 1.0) * SPECULARSTRENGTH;// * shadow;
	fragColor.rgb += fragColor.rgb * specular;
	
	// Apply darkening based on LOS texture
	vec2 losUV = clamp(g_position.xz, vec2(0.0), mapSize.xy ) / mapSize.zw;
	float loslevel = dot(vec3(0.33), texture(infoTex, losUV).rgb) ; // lostex is PO2
	loslevel = clamp(loslevel * 4.0 - 1.0, LOSDARKNESS, 1.0);
	fragColor.rgb *= loslevel;
	
	// Blend underwater parts of the decals correctly
	vec4 waterblendfactors = waterBlend(g_position.y);
	fragColor.rgb = mix(fragColor.rgb, fragColor.rgb * waterblendfactors.rgb, waterblendfactors.a);
	#if (AMBIENTOCCLUSION == 1) 
		vec4 tex4color = texture(atlasORM, g_uv.xy  - parallaxUV.xy);
	#else
		vec4 tex4color = vec4 (0.0);
	#endif
	
	// Darken the whole goddamned decal:
	fragColor.rgb *= 0.80; 
	
	// calculate the shadow factor, note that this is partially smoothed
	float shadow = shadowAtWorldPosSoft(g_position.xyz);
	fragColor.rgb *= clamp(shadow, 0.5, 1.0);
	
	// Fade the decal out with time
	fragColor.a *= g_position.w;
	//fragColor.a = fract(g_position.w*10);
	
	// add emissive heat, if required
	#if (USEGLOW == 1) 
		float glowChannel = tex2color.a; // Could use a power operator here?

		float hotness = max(0,g_parameters.w);
		vec3 heatColor = Temperature(hotness*glowChannel);
		//fragColor.rgb += heatColor * pow(glowChannel.r, 2) * hotness ;
		//fragColor.rgb = vec3(fract(g_uv.w*20));
		fragColor.rgb += (heatColor.rgb * max(glowChannel,0.0)*12); //was *10 - icex increase to more brightness
		
		//experiment with glowadd:
		// we kinda need to additively blend here... 
		float heatalpha = dot (vec3(1.0),heatColor);
		fragColor.rgba +=  g_parameters.z * heatalpha * vec4(heatColor.rgb ,g_position.w); 
	#endif 
	
	//fragColor.a = 1.0;
	// plenty of debug outputs for your viewing pleasure
	//fragColor.a *= g_parameters.z ;
	//fragColor.r += g_parameters.w;
	//fragColor.rgb += heatColor;
	//fragColor.rgb = tbnmatrix[2] * 0.5 + 0.5;
	//fragColor.rgb = tangentviewdir.yyy * 0.5 + 0.5;
	//fragColor.rgb = tex1color.rgb;
	//fragColor.rgb = tex3color.bbb;
	//fragColor.rgb = abs((parallaxUV.xyx * 10) + 0.5);
	//fragColor.rgb = fract(tspace.xyz* 0.01);
	//fragColor.rgb = reorientedNormal.rgb * 0.5 + 0.5;
	//fragColor.rgb = max(vec3(parallaxUV.x, - parallaxUV.x, 0.0) * 10, 0.0);
	//fragColor.a = 1.0;
	//fragColor.rgb = g_uv.zyy;
	//fragColor.rgba = vec4(0.5);
	
	//if (fract(gl_FragCoord.x * 0.01) > 0.5 ) fragColor.rgba = tex1color.rgba;
	//else fragColor.rgba = tex2color.rgba;
}