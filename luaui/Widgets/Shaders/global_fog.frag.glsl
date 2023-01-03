#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)
// Notes:
// texelFetch is hardly faster but has banding artifacts, do not use!

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000

in DataVS {
	vec4 v_worldPos;
	vec4 v_uvs;
	vec4 v_fragWorld;
	vec4 v_mapPos;
	vec4 v_simplex;
	vec4 v_perlin;
	vec4 v_meanpos;
};

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D heightmapTex;
uniform sampler2D infoTex;
uniform sampler2DShadow shadowTex;
uniform sampler3D noise64cube;
uniform sampler2D miniMapTex;
uniform sampler2D simpledither;
uniform sampler3D worley3d3level;

uniform float windX;
uniform float windZ;
uniform vec4 fogGlobalColor;
uniform vec4 fogSunColor;
uniform vec4 fogShadowedColor;
uniform vec4 noiseParams;

uniform float fogGlobalDensity;
uniform float fogGroundDensity;
uniform float fogPlaneHeight;
uniform float fogExpFactor;

out vec4 fragColor;

float frequency;

float shadowAtWorldPos(vec3 worldPos){
		vec4 shadowVertexPos = shadowView * vec4(worldPos,1.0);
		shadowVertexPos.xy += vec2(0.5);
		return clamp(textureProj(shadowTex, shadowVertexPos), 0.0, 1.0);
}
float losLevelAtWorldPos(vec3 worldPos){ // this returns 
	#if 1
		vec2 losUV = clamp(worldPos.xz, vec2(0.0), mapSize.xy ) / mapSize.xy;
		vec4 infoTexSample = texture(infoTex, losUV);
		if (infoTexSample.r > 0.2) 
			return clamp((infoTexSample.r -0.2) / 0.8 ,0,1);
		else 
			//return 0;
			return (LOSFOGUNDISCOVERED) * (-100) * (0.2 - infoTexSample.r);
	#else
		vec2 losUV = clamp(worldPos.xz, vec2(0.0), mapSize.xy ) / mapSize.zw;
		vec4 infoTexSample = texture(infoTex, losUV);
		float loslevel = dot(vec3(0.33), infoTexSample.rgb) ; // lostex is PO2
		float dx = dFdx(loslevel);
		float dy = dFdy(loslevel);
		vec4 neighbourinos = vec4(loslevel, loslevel + dx, loslevel + dy, loslevel+ dx + dy) ;// me, l/r, t/b, opposite
		//vec4 neighbourinos = vec4(loslevel) ;// me, l/r, t/b, opposite
		
		loslevel = dot(neighbourinos, vec4(0.25));
		loslevel = smoothstep(0.4, 0.5, loslevel);
		//loslevel = 
		//loslevel = step(0.5,loslevel);
		return loslevel;
		//return loslevel;
	#endif
}

float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float smoothmin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5*(a-b)/k, 0.0, 1.0);
	return mix(a, b, h) - k*h*(1.0-h);
}

float fogAmountHeightBased(float h){
	return h;
}

float SimplexPerlin3D( vec3 P ){
    //  https://github.com/BrianSharpe/Wombat/blob/master/SimplexPerlin3D.glsl

    //  simplex math constants
    const float SKEWFACTOR = 1.0/3.0;
    const float UNSKEWFACTOR = 1.0/6.0;
    const float SIMPLEX_CORNER_POS = 0.5;
    const float SIMPLEX_TETRAHEDRON_HEIGHT = 0.70710678118654752440084436210485;    // sqrt( 0.5 )

    //  establish our grid cell.
    P *= SIMPLEX_TETRAHEDRON_HEIGHT;    // scale space so we can have an approx feature size of 1.0
    vec3 Pi = floor( P + dot( P, vec3( SKEWFACTOR) ) );

    //  Find the vectors to the corners of our simplex tetrahedron
    vec3 x0 = P - Pi + dot(Pi, vec3( UNSKEWFACTOR ) );
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 Pi_1 = min( g.xyz, l.zxy );
    vec3 Pi_2 = max( g.xyz, l.zxy );
    vec3 x1 = x0 - Pi_1 + UNSKEWFACTOR;
    vec3 x2 = x0 - Pi_2 + SKEWFACTOR;
    vec3 x3 = x0 - SIMPLEX_CORNER_POS;

    //  pack them into a parallel-friendly arrangement
    vec4 v1234_x = vec4( x0.x, x1.x, x2.x, x3.x );
    vec4 v1234_y = vec4( x0.y, x1.y, x2.y, x3.y );
    vec4 v1234_z = vec4( x0.z, x1.z, x2.z, x3.z );

    // clamp the domain of our grid cell
    Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
    vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

    //	generate the random vectors
    vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
    Pt *= Pt;
    vec4 V1xy_V2xy = mix( Pt.xyxy, Pt.zwzw, vec4( Pi_1.xy, Pi_2.xy ) );
    Pt = vec4( Pt.x, V1xy_V2xy.xz, Pt.z ) * vec4( Pt.y, V1xy_V2xy.yw, Pt.w );
    const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
    const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
    vec3 lowz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi.zzz * ZINC.xyz ) );
    vec3 highz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi_inc1.zzz * ZINC.xyz ) );
    Pi_1 = ( Pi_1.z < 0.5 ) ? lowz_mods : highz_mods;
    Pi_2 = ( Pi_2.z < 0.5 ) ? lowz_mods : highz_mods;
    vec4 hash_0 = fract( Pt * vec4( lowz_mods.x, Pi_1.x, Pi_2.x, highz_mods.x ) ) - 0.49999;
    vec4 hash_1 = fract( Pt * vec4( lowz_mods.y, Pi_1.y, Pi_2.y, highz_mods.y ) ) - 0.49999;
    vec4 hash_2 = fract( Pt * vec4( lowz_mods.z, Pi_1.z, Pi_2.z, highz_mods.z ) ) - 0.49999;

    //	evaluate gradients
    vec4 grad_results = inversesqrt( hash_0 * hash_0 + hash_1 * hash_1 + hash_2 * hash_2 ) * ( hash_0 * v1234_x + hash_1 * v1234_y + hash_2 * v1234_z );

    //	Normalization factor to scale the final result to a strict 1.0->-1.0 range
    //	http://briansharpe.wordpress.com/2012/01/13/simplex-noise/#comment-36
    const float FINAL_NORMALIZATION = 37.837227241611314102871574478976;

    //  evaulate the kernel weights ( use (0.5-x*x)^3 instead of (0.6-x*x)^4 to fix discontinuities )
    vec4 kernel_weights = v1234_x * v1234_x + v1234_y * v1234_y + v1234_z * v1234_z;
    kernel_weights = max(0.5 - kernel_weights, 0.0);
    kernel_weights = kernel_weights*kernel_weights*kernel_weights;

    //	sum with the kernel and return
    return dot( kernel_weights, grad_results ) * FINAL_NORMALIZATION;
}
#line 31000

#line 32000
void main(void)
{
	float time = timeInfo.x + timeInfo.w;
	vec3 camPos = cameraViewInv[3].xyz ;
	
	vec3 camDir = normalize(camPos-v_fragWorld.xyz);

	vec2 screenUV = gl_FragCoord.xy * RESOLUTION / viewGeometry.xy;

	// Sample the depth buffers, and choose whichever is closer to the screen
	float mapdepth = texture(mapDepths, screenUV).x;
	float modeldepth = texture(modelDepths, screenUV).x;
	mapdepth = min(mapdepth, modeldepth);
	
	// Transform screen-space depth to world-space position
	vec4 mapWorldPos =  vec4( vec3(screenUV.xy * 2.0 - 1.0, mapdepth),  1.0);
	mapWorldPos = cameraViewProjInv * mapWorldPos;
	mapWorldPos.xyz = mapWorldPos.xyz / mapWorldPos.w; // YAAAY this works!
	
	vec3 mapFromCam = mapWorldPos.xyz - camPos.xyz;
	
	float distToCamSquared = dot(mapFromCam, mapFromCam);
	float underWaterFraction = 0;
	// if mapworldpos is below 0, then adjust it back
	if (mapWorldPos.y < 0){
		float abovewaterfraction = camPos.y / abs(mapFromCam.y);
		mapWorldPos.xyz = (mapFromCam.xyz * abovewaterfraction) + camPos.xyz;
	}
	vec3 fragWorldPos = v_worldPos.xyz;

	#if (NOISESAMPLES > 0)
		float noiseScale =  0.001 * noiseParams.x;
		vec3 noiseOffset = vec3(0.0);
		noiseOffset.xz -= vec2(windX, windZ) * noiseScale ;
		noiseOffset.y += sin(fragWorldPos.x*0.001) ;
		noiseOffset.y += cos(fragWorldPos.z*0.0012) ;
		noiseOffset.y -= time * noiseScale ;
	#endif
	
	// calculate the Height-based fog amount
	// rayStart is the distant point through fog and rayEnd is the close point through fog
	vec3 rayStart = mapWorldPos.xyz; // Ray starts at most distant point
	vec3 rayEnd = camPos.xyz; // Ends at closes point
	float rayFractionInFog = 0; 
	
	// If raystart is above the fog plane height
	if (mapWorldPos.y > fogPlaneHeight) {
		if (camPos.y > fogPlaneHeight) { // Cam is above fog too (B), so no fog at all
			rayEnd = rayStart;
		}else{ // But cam is below fog (C)
			rayFractionInFog = clamp((fogPlaneHeight - camPos.y)/(mapWorldPos.y - camPos.y), 0, 1);
			rayStart = rayEnd + (rayStart - rayEnd) * rayFractionInFog;
		}
	}else{ // Ray starts below fog plane
		if (camPos.y > fogPlaneHeight) { // Camera is Above fog (A) 
			rayFractionInFog = clamp((fogPlaneHeight - mapWorldPos.y)/(camPos.y - mapWorldPos.y), 0, 1);
			rayEnd = rayStart + (rayEnd - rayStart) * rayFractionInFog;
		}else{ // Ray starts and ends inside of fog
			rayFractionInFog = 1.0;
		}
	}
	float rayLength = length(rayEnd - rayStart);
	float heightBasedFog = fogGroundDensity * rayLength * 400;
	
	// Marching:
	const float steps = RAYMARCHSTEPS;
	
	float collectedNoise = 0.0;
	float collectedShadow = 0.0; // What fraction of samples were LIT along the way.
	
	float largenoise = SimplexPerlin3D ((rayStart ) * noiseScale * noiseParams.z + noiseOffset);
	
	vec4 densityposition = vec4(0); // Ok, this contains the center-weighted sum of all positions, 
	// TODO: FIX ABOVE FOG TOP!
	// TODO: fix warps sampling zero simplex!
	vec2 mymin = min(mapWorldPos.xz,mapSize.xy - mapWorldPos.xz);
	float outofboundsness = min(mymin.x, mymin.y) ;
	//outofboundsness /= min(mapSize.x, mapSize.y);
	float inlos = 0;
	#if (LOSREDUCEFOG < 1)
		inlos = losLevelAtWorldPos( mapWorldPos.xyz);
		
		bool outofmap = any(lessThan(vec4(mapWorldPos.xz, mapSize.xy),  vec4(0.0, 0.0, mapWorldPos.xz)));
		if (outofmap) inlos = 0;

	#endif
	
	if (rayLength> 0.0001 && inlos < 0.99) { 
		#if 0 // old deprecated method
			float rayJitterOffset = (1 * rand(screenUV)) / steps ;
			#if (RAYMARCHSTEPS > 0)
			for (uint i = 0; i < steps; i++){
				float f = float(i) / steps;
				vec3 rayPos = mix(rayStart.xyz, rayEnd, f + rayJitterOffset);
				
				float localShadow= shadowAtWorldPos(rayPos); // 1 for lit, 0 for unlit
				float shadowDelta = 0.25 * (abs(dFdx(localShadow)) + abs(dFdy(localShadow)));
				
				localShadow = mix(shadowDelta, 1.0 - shadowDelta, localShadow);
				collectedShadow += localShadow;
			}
			
			collectedShadow /= steps;
			collectedShadow = pow(collectedShadow, 2.0);
			#else
				collectedShadow = 1.0;
			#endif
			#if (NOISESAMPLES > 0)
				for (uint i = 0; i < (NOISESAMPLES); i++){
					float f = float(i) / (NOISESAMPLES);
					vec3 rayPos = mix(rayStart.xyz, rayEnd, f + 0.005 * rayJitterOffset);
				//if (1 == 1){
					vec4 localNoise =  texture(noise64cube, rayPos.xyz * noiseScale  + noiseOffset); // TODO: SUBSAMPLE THIS ONE!
					
					float simplexnoise = SimplexPerlin3D ((rayPos ) * noiseScale * noiseParams.z + noiseOffset);
					//simplexnoise = largenoise;
					float thisraynoise = max(0,localNoise.a + noiseParams.y - simplexnoise);
					collectedNoise += thisraynoise;
				}
				heightBasedFog *= collectedNoise/(NOISESAMPLES);
			#endif
			
		#else// new interleaved sampling
			
			#if ((RAYMARCHSTEPS > 0) && (NOISESAMPLES >0))
				float numShadowSamplesTaken = 0.001;
				uint shadowSteps = RAYMARCHSTEPS / NOISESAMPLES;
				float rayJitterOffset = (1 * rand(screenUV)) / steps ;
				for (uint n = 0; n < NOISESAMPLES; n ++){
					float f = float(n) / NOISESAMPLES;
					
					vec3 rayPos = mix(rayStart.xyz, rayEnd, f + 0.5 * rayJitterOffset);
					
					//vec4 localNoise =  texture(noise64cube, rayPos.xyz * noiseScale + noiseOffset); // TODO: SUBSAMPLE THIS ONE!
					vec3 skewed3dpos = (rayPos.xyz * noiseScale*0.5 + noiseOffset) * vec3(1,4,1);
					float localNoise = 1.0 - texture(noise64cube, skewed3dpos.xzy).r; // TODO: SUBSAMPLE THIS ONE!
					float simplexnoise = SimplexPerlin3D((rayPos) * noiseScale * noiseParams.z + noiseOffset)*0.5;
					//simplexnoise = 0;
					float thisraynoise = max(0, localNoise.r + noiseParams.y - simplexnoise);
					
					// Modulate the noise based on its depth below fogplane:
					float rayDepthratio = clamp( 1.0 - rayPos.y / (fogPlaneHeight) , 0.0, 1.0);
					
					float rayDepthFactor = min(1.0, 1 * rayDepthratio);
					
					collectedNoise += thisraynoise * rayDepthFactor;
					
					densityposition += vec4(rayPos*thisraynoise, thisraynoise); // collecting the 'center' of the noise cloud
					if (thisraynoise > 0 ) { // only sample shadow if we have actual fog here!
						for (uint m = 0; m < shadowSteps; m++){ // step through the small local volume 
							f += (float(m)) / (steps); 
							//float f = (float(m) + float(n) * NOISESAMPLES)/ steps;
							vec3 rayPos = mix(rayStart.xyz, rayEnd, f + rayJitterOffset);
							
							float localShadow= shadowAtWorldPos(rayPos); // 1 for lit, 0 for unlit
							float shadowDelta = 0.25 * (abs(dFdx(localShadow)) + abs(dFdy(localShadow))); // magic smoothing using adjacent pixels
							
							localShadow = mix(shadowDelta, 1.0 - shadowDelta, localShadow);
							collectedShadow += localShadow;
							numShadowSamplesTaken += 1.0;
						}
					}
				}
				collectedShadow /= numShadowSamplesTaken; // get the true litness by only taking into account actual samples taken
				densityposition.xyz /= densityposition.w;

				heightBasedFog *= collectedNoise/(NOISESAMPLES);
			#else // fall back to retard mode
				collectedShadow = 1.0;
				densityposition.xyz = (rayStart + rayEnd)*0.5;
			#endif
		
		#endif
	}else{
		collectedShadow = 1.0;
	}
	if (mapWorldPos.y >= fogPlaneHeight){
		//collectedShadow = 1.0; 
	}
	//modulate the height based component only, not the distance based component
	
	// but modulate _before_ addition!
	const float expfactor = fogExpFactor;
	
	// calculate the distance fog density
	float distanceFogAmount = fogGlobalDensity * length(mapFromCam);
	
	// Modulate distance fog density with angle of ray compared to sky?
	vec3 fromCameraNormalized = normalize(mapFromCam);
	if (fromCameraNormalized.y > 0) {
		distanceFogAmount *= pow(1.0 - fromCameraNormalized.y, 16.0) ;
	}
	

	//fragColor.a = 1.0;
	//fragColor.rgb = vec3(inlos);
	//return;
	
	// reduce height-based fog for in-los areas:
	heightBasedFog *= (1.0 - inlos *(1.0- LOSREDUCEFOG));
	
	// Modulate the amount of fog based on how shadowed it is, by adding more fog to shadowed areas
	heightBasedFog += heightBasedFog * smoothstep( 0.0,1.0, 1.0 - collectedShadow); 
	
	float heightBasedFogExp = exp(heightBasedFog * expfactor);
	float distanceFogAmountExp = exp(distanceFogAmount * expfactor);
	
	float totalfog = heightBasedFogExp * distanceFogAmountExp;
	//float totalfog = exp((heightBasedFogExp + distanceFogAmountExp) * expfactor);
	
	float outputfogalpha = min(0.99, max(0, 1.0 - totalfog));
	
	float shadowColorization = clamp(heightBasedFogExp/distanceFogAmountExp,0,1);
	
	// Colorize fog based on view angle: TODO do this on center weigth of both !

	float sunAngleCos =  dot( fromCameraNormalized, sunDir.xyz); // this goes from into sun at 1 to sun behind us at -1 
	
	float sphericalharmonic = 1.0;//pow(1.3, (cos(cos(sunAngleCos - 1.0) * 3.14*10)));
	
	//reduce sun back glare
	if (sunAngleCos < 0.0) sunAngleCos = sunAngleCos * sunAngleCos*sunAngleCos*sunAngleCos*sunAngleCos*sunAngleCos*sunAngleCos;

	//sunAngleCos *= ( step( sunAngleCos, 0) * 0.5 +0.5);
	
	sphericalharmonic *= abs(sunAngleCos);
	
	//sphericalharmonic *= abs(sunAngleCos);
	vec3 fogColor = fogGlobalColor.rgb;
	
	//sphericalharmonic = step(sunAngleCos, 0.75);
	fogColor = mix(fogColor, 2*fogSunColor.rgb, pow(sphericalharmonic,4.0));
	
	// Set the base color depending on how shadowed it is, 
	// shadowed components should tend toward fogGlobalColor
	vec3 heightFogColor = mix(fogGlobalColor.rgb, fogColor, collectedShadow);
	

	
	// Darkened the shadowed bits towards fogShadowedColor
	fragColor.rgb = mix(vec3(fogShadowedColor), heightFogColor.rgb, collectedShadow);	
	
	//Calculate backscatter color from minimap if possible?
	#if 1 // set to 1 or 0 to turn on/off
		#if (USEMINIMAP == 1) 
			vec4 minimapcolor = textureLod(miniMapTex, heighmapUVatWorldPosMirrored(mapWorldPos.xz), 4.0);
			//fogColor.rgb = mix(fogColor.rgb, minimapcolor.rgb, MINIMAPSCATTER);
			fragColor.rgb += minimapcolor.rgb * MINIMAPSCATTER * collectedShadow;
		#endif
	#endif
	//fragColor.rgb = fract((mapWorldPos.xyz) / 32 -0.5);
	//fragColor.a = 1.0;
	// Above that, mix back regular fog color for distance based fog
	fragColor.rgb = mix( fogColor.rgb, fragColor.rgb,distanceFogAmountExp);

	//fragColor.rgb= vec3(1.0);
	//fragColor.rgba = vec4(heightBasedFogExp, distanceFogAmountExp,0,1);
	//fragColor.rgba = vec4(shadowColorization,shadowColorization,shadowColorization,1);
	fragColor.a = outputfogalpha;
	
	//fragColor.rgb = vec3(fract(rayLength/200));
	return;
}