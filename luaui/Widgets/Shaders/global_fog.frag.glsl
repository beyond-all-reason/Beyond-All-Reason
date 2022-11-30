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
uniform sampler2D dithernoise2d;
uniform sampler2D simpledither;
uniform sampler3D worley3d3level;

uniform float windX;
uniform float windZ;
uniform vec4 globalFogColor;

uniform float fogGlobalDensity;
uniform float fogGroundDensity;
uniform float fogPlaneHeight;
uniform float fogExpFactor;


out vec4 fragColor;

float frequency;

// https://gist.github.com/wwwtyro/beecc31d65d1004f5a9d
vec2 raySphereIntersect(vec3 r0, vec3 rd, vec3 s0, float sr) {
    // - r0: ray origin
    // - rd: normalized ray direction
    // - s0: sphere center
    // - sr: sphere radius
    // - Returns distance from r0 to first intersection with sphere,
    //   or -1.0 if no intersection.
    float a = dot(rd, rd);
    vec3 s0_r0 = r0 - s0;
    float b = 2.0 * dot(rd, s0_r0);
    float c = dot(s0_r0, s0_r0) - (sr * sr);
	float disc = b * b - 4.0 * a* c;
    if (disc < 0.0) {
        return vec2(-1.0, -1.0);
    }else{
		disc = sqrt(disc);
		return vec2(-b - disc, -b + disc) / (2.0 * a);
	}
}

float shadowAtWorldPos(vec3 worldPos){
		vec4 shadowVertexPos = shadowView * vec4(worldPos,1.0);
		shadowVertexPos.xy += vec2(0.5);
		return clamp(textureProj(shadowTex, shadowVertexPos), 0.0, 1.0);
}

float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float smoothmin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5*(a-b)/k, 0.0, 1.0);
	return mix(a, b, h) - k*h*(1.0-h);
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
	
	vec3 mapToCam = camPos - mapWorldPos.xyz;
	
	float distToCamSquared = dot(mapToCam, mapToCam);
	float underWaterFraction = 0;
	// if mapworldpos is below 0, then adjust it back
	if (mapWorldPos.y < -0){
		underWaterFraction = (-mapWorldPos.y) / abs(mapToCam.y);
		mapWorldPos.xyz = mapWorldPos.xyz + (mapToCam.xyz * underWaterFraction * 1.0001);
		//mapWorldPos.y = fract(underwaterfraction*0.1);
	}
	vec3 fragWorldPos = v_worldPos.xyz;

	fragColor.rgb = fract(mapWorldPos.xyz * 0.01);
	fragColor.a = fract(sqrt(distToCamSquared) * 0.01);
	//fragColor.a = underWaterFraction * 10;
	//fragColor.a = pow(distToCamSquared, -0.001);
	fragColor.a = 1.0;
	
	// calculate the distance fog density
	float distanceToCamera = sqrt(distToCamSquared);
	float distanceFogAmount = fogGlobalDensity * distanceToCamera;
	
	
	float fogIntegralPower = 2;
	// calculate the Height-based fog amount
	#if (0)
		// simple approach where fog amount is only height based, but this is stupid and useless
		float heightBasedFog = max(0.0, fogPlaneHeight - mapWorldPos.y);
		if ((camPos.y < fogPlaneHeight) && (mapWorldPos.y < camPos.y)){ // we are under the fog plane
			heightBasedFog = max(0.0, camPos.y - mapWorldPos.y);
		}
		vec3 toCameraNormalized = normalize(mapToCam);
		heightBasedFog = heightBasedFog / max(0.33, toCameraNormalized.y);
		heightBasedFog = fogGroundDensity * pow(heightBasedFog, fogIntegralPower);
	#else
		//the height based fog amount should only depend on the length of the ray underneath the fog plane limit
		float rayFractionInFog = 1.0;
		rayFractionInFog = clamp((fogPlaneHeight-mapWorldPos.y)/ (camPos.y - mapWorldPos.y),0.0,1.0);
		if (mapWorldPos.y >= camPos.y) {
			rayFractionInFog = clamp((fogPlaneHeight-camPos.y)/ (mapWorldPos.y- camPos.y),0.0,1.0);
		}
		float heightBasedFog = fogGroundDensity * distanceToCamera * rayFractionInFog * 30;
		//heightBasedFog = 10000.0;
	#endif

	float noiseScale = 0.01;
	vec3 noiseOffset = vec3(0.0);
	noiseOffset.xz += vec2(windX, windZ) * 0.01;
	noiseOffset.y += sin(fragWorldPos.x*0.001) ;
	noiseOffset.y += cos(fragWorldPos.z*0.0012) ;
	
	//vec4 noisesample = texture(noise64cube, v_meanpos.xyz * noiseScale  + noiseOffset);
	//fragColor.a  *= (noisesample.b + 1);
	
	// Marching:
	const float steps = RAYMARCHSTEPS;
	vec3 rayStart = mapWorldPos.xyz;
	vec3 rayEnd = clamp((fogPlaneHeight - mapWorldPos.y)/ (camPos.y- mapWorldPos.y),   0, 1) * mapToCam + mapWorldPos.xyz;
	if (camPos.y <= mapWorldPos.y) rayEnd = mapWorldPos.xyz +  mapToCam;
	
	float collectedNoise = 0.0;
	float collectedShadow = 0.0; // What fraction of samples were shadowed along the way.
	
	// TODO: FIX ABOVE FOG TOP!
	if (mapWorldPos.y < fogPlaneHeight || 1==1 ) { //TODO: add special case where cam is below fogtop!
		float rayJitterOffset = (2 * rand(screenUV)) / steps ;
		for (float f = 0; f < 1.0; f += 1.0 / steps){
			vec3 rayPos = mix(rayStart.xyz, rayEnd, f + rayJitterOffset);
			
			
			float localShadow= shadowAtWorldPos(rayPos); // 1 for lit, 0 for unlit
			float shadowDelta = 0.25 * (abs(dFdx(localShadow)) + abs(dFdy(localShadow)));
			
			localShadow = mix(shadowDelta, 1.0 - shadowDelta, localShadow);
			collectedShadow += localShadow;
			
			rayPos = mix(rayStart.xyz, rayEnd, f );
			float mySimplexSample = 0;//SimplexPerlin3D(rayPos*0.1*(0.2));
			//collectedShadow += dot(vec3(0.33), abs(vec3(localShadow, rightShadow,upShadow))); 
			collectedNoise += max(0, mySimplexSample);
			
			vec4 localNoise =  texture(noise64cube, rayPos.xyz * noiseScale  + noiseOffset); // TODO: SUBSAMPLE THIS ONE!
			//collectedNoise += max(0,localNoise.a);
		}
		collectedShadow /= steps;
		collectedShadow = pow(collectedShadow, 2.0);
		//heightBasedFog *= collectedNoise/steps;
	}
	if (mapWorldPos.y >= fogPlaneHeight){
		collectedShadow = 1.0;
	}

	
	//modulate the height based component only, not the distance based component
	
	// but modulate _before_ addition!
	const float expfactor = fogExpFactor;
	

	float heightBasedFogExp = exp(heightBasedFog * expfactor);
	float distanceFogAmountExp = exp(distanceFogAmount * expfactor);
	
	float totalfog = heightBasedFogExp * distanceFogAmountExp;
	
	float outputfogalpha = max(0, 0.99 - totalfog);
	
	float shadowColorization = clamp(heightBasedFogExp/distanceFogAmountExp,0,1);
	
	fragColor.rgb = mix(vec3(0.0), globalFogColor.rgb, collectedShadow );
	fragColor.rgb = mix( globalFogColor.rgb, fragColor.rgb,distanceFogAmountExp);
	
	fragColor.rgb = mix (fragColor.rgb, globalFogColor.rgb, shadowColorization);
	
	//fragColor.rgb= vec3(1.0);
	//fragColor.rgba = vec4(heightBasedFogExp, distanceFogAmountExp,0,1);
	//fragColor.rgba = vec4(shadowColorization,shadowColorization,shadowColorization,1);
	fragColor.a = outputfogalpha;
	
	return;
	
}