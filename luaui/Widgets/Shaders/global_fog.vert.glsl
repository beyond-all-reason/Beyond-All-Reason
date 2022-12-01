#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)
#line 5000

layout (location = 0) in vec4 positionxy_xyfract; // l w rot and maxalpha

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

uniform sampler2D heightmapTex;
uniform sampler2D mapDepths;
uniform sampler2D modelDepths;

uniform float fogPlaneHeight;

out DataVS {
	vec4 v_worldPos;
	vec4 v_uvs;
	vec4 v_fragWorld;
	vec4 v_mapPos;
	vec4 v_simplex;
	vec4 v_perlin;
	vec4 v_meanpos;
};

float Perlin4D( vec4 P )
{
    //  https://github.com/BrianSharpe/Wombat/blob/master/Perlin4D.glsl

    // establish our grid cell and unit position
    vec4 Pi = floor(P);
    vec4 Pf = P - Pi;
    vec4 Pf_min1 = Pf - 1.0;

    // clamp the domain
    Pi = Pi - floor(Pi * ( 1.0 / 69.0 )) * 69.0;
    vec4 Pi_inc1 = step( Pi, vec4( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

    // calculate the hash.
    const vec4 OFFSET = vec4( 16.841230, 18.774548, 16.873274, 13.664607 );
    const vec4 SCALE = vec4( 0.102007, 0.114473, 0.139651, 0.084550 );
    Pi = ( Pi * SCALE ) + OFFSET;
    Pi_inc1 = ( Pi_inc1 * SCALE ) + OFFSET;
    Pi *= Pi;
    Pi_inc1 *= Pi_inc1;
    vec4 x0y0_x1y0_x0y1_x1y1 = vec4( Pi.x, Pi_inc1.x, Pi.x, Pi_inc1.x ) * vec4( Pi.yy, Pi_inc1.yy );
    vec4 z0w0_z1w0_z0w1_z1w1 = vec4( Pi.z, Pi_inc1.z, Pi.z, Pi_inc1.z ) * vec4( Pi.ww, Pi_inc1.ww );
    const vec4 SOMELARGEFLOATS = vec4( 56974.746094, 47165.636719, 55049.667969, 49901.273438 );
    vec4 hashval = x0y0_x1y0_x0y1_x1y1 * z0w0_z1w0_z0w1_z1w1.xxxx;
    vec4 lowz_loww_hash_0 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.x ) );
    vec4 lowz_loww_hash_1 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.y ) );
    vec4 lowz_loww_hash_2 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.z ) );
    vec4 lowz_loww_hash_3 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.w ) );
    hashval = x0y0_x1y0_x0y1_x1y1 * z0w0_z1w0_z0w1_z1w1.yyyy;
    vec4 highz_loww_hash_0 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.x ) );
    vec4 highz_loww_hash_1 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.y ) );
    vec4 highz_loww_hash_2 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.z ) );
    vec4 highz_loww_hash_3 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.w ) );
    hashval = x0y0_x1y0_x0y1_x1y1 * z0w0_z1w0_z0w1_z1w1.zzzz;
    vec4 lowz_highw_hash_0 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.x ) );
    vec4 lowz_highw_hash_1 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.y ) );
    vec4 lowz_highw_hash_2 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.z ) );
    vec4 lowz_highw_hash_3 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.w ) );
    hashval = x0y0_x1y0_x0y1_x1y1 * z0w0_z1w0_z0w1_z1w1.wwww;
    vec4 highz_highw_hash_0 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.x ) );
    vec4 highz_highw_hash_1 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.y ) );
    vec4 highz_highw_hash_2 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.z ) );
    vec4 highz_highw_hash_3 = fract( hashval * ( 1.0 / SOMELARGEFLOATS.w ) );

    // calculate the gradients
    lowz_loww_hash_0 -= 0.49999;
    lowz_loww_hash_1 -= 0.49999;
    lowz_loww_hash_2 -= 0.49999;
    lowz_loww_hash_3 -= 0.49999;
    highz_loww_hash_0 -= 0.49999;
    highz_loww_hash_1 -= 0.49999;
    highz_loww_hash_2 -= 0.49999;
    highz_loww_hash_3 -= 0.49999;
    lowz_highw_hash_0 -= 0.49999;
    lowz_highw_hash_1 -= 0.49999;
    lowz_highw_hash_2 -= 0.49999;
    lowz_highw_hash_3 -= 0.49999;
    highz_highw_hash_0 -= 0.49999;
    highz_highw_hash_1 -= 0.49999;
    highz_highw_hash_2 -= 0.49999;
    highz_highw_hash_3 -= 0.49999;

    vec4 grad_results_lowz_loww = inversesqrt( lowz_loww_hash_0 * lowz_loww_hash_0 + lowz_loww_hash_1 * lowz_loww_hash_1 + lowz_loww_hash_2 * lowz_loww_hash_2 + lowz_loww_hash_3 * lowz_loww_hash_3 );
    grad_results_lowz_loww *= ( vec2( Pf.x, Pf_min1.x ).xyxy * lowz_loww_hash_0 + vec2( Pf.y, Pf_min1.y ).xxyy * lowz_loww_hash_1 + Pf.zzzz * lowz_loww_hash_2 + Pf.wwww * lowz_loww_hash_3 );

    vec4 grad_results_highz_loww = inversesqrt( highz_loww_hash_0 * highz_loww_hash_0 + highz_loww_hash_1 * highz_loww_hash_1 + highz_loww_hash_2 * highz_loww_hash_2 + highz_loww_hash_3 * highz_loww_hash_3 );
    grad_results_highz_loww *= ( vec2( Pf.x, Pf_min1.x ).xyxy * highz_loww_hash_0 + vec2( Pf.y, Pf_min1.y ).xxyy * highz_loww_hash_1 + Pf_min1.zzzz * highz_loww_hash_2 + Pf.wwww * highz_loww_hash_3 );

    vec4 grad_results_lowz_highw = inversesqrt( lowz_highw_hash_0 * lowz_highw_hash_0 + lowz_highw_hash_1 * lowz_highw_hash_1 + lowz_highw_hash_2 * lowz_highw_hash_2 + lowz_highw_hash_3 * lowz_highw_hash_3 );
    grad_results_lowz_highw *= ( vec2( Pf.x, Pf_min1.x ).xyxy * lowz_highw_hash_0 + vec2( Pf.y, Pf_min1.y ).xxyy * lowz_highw_hash_1 + Pf.zzzz * lowz_highw_hash_2 + Pf_min1.wwww * lowz_highw_hash_3 );

    vec4 grad_results_highz_highw = inversesqrt( highz_highw_hash_0 * highz_highw_hash_0 + highz_highw_hash_1 * highz_highw_hash_1 + highz_highw_hash_2 * highz_highw_hash_2 + highz_highw_hash_3 * highz_highw_hash_3 );
    grad_results_highz_highw *= ( vec2( Pf.x, Pf_min1.x ).xyxy * highz_highw_hash_0 + vec2( Pf.y, Pf_min1.y ).xxyy * highz_highw_hash_1 + Pf_min1.zzzz * highz_highw_hash_2 + Pf_min1.wwww * highz_highw_hash_3 );

    // Classic Perlin Interpolation
    vec4 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
    vec4 res0 = grad_results_lowz_loww + ( grad_results_lowz_highw - grad_results_lowz_loww ) * blend.wwww;
    vec4 res1 = grad_results_highz_loww + ( grad_results_highz_highw - grad_results_highz_loww ) * blend.wwww;
    res0 = res0 + ( res1 - res0 ) * blend.zzzz;
    blend.zw = vec2( 1.0 ) - blend.xy;
    return dot( res0, blend.zxzx * blend.wwyy );
}
float SimplexPerlin3D( vec3 P )
{
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
void main()
{
	float time = (timeInfo.x + timeInfo.w) * 0.1;
	vec3 camPos = cameraViewInv[3].xyz ;
	
	vec2 screenPos = positionxy_xyfract.xy ;
	vec2 screenUV = (positionxy_xyfract.xy * 0.5) + 0.5;// * viewGeometry.xy;
	
	float mapdepth = 0;//texture(mapDepths, screenUV).x;
	float modeldepth = 0;//texture(modelDepths, screenUV).x;
	mapdepth = min(mapdepth, modeldepth);

	vec4 mapWorldPos =  vec4( vec3(screenPos, mapdepth),  1.0);
	mapWorldPos = cameraViewProjInv * mapWorldPos;
	mapWorldPos.xyz = mapWorldPos.xyz / mapWorldPos.w;
	vec4 vertexPos = vec4( screenPos.x, screenPos.y, 0.5, 1);
	gl_Position = vertexPos;
	//v_mapPos = vertexPos;
	//v_mapPos.r = mapdepth*10;
	//v_mapPos = mapWorldPos;
	
	//v_simplex.x = Perlin4D(vec4(mapWorldPos.xyz, time * 50) * 0.004);
	//v_simplex.y = Perlin4D(vec4(mapWorldPos.xyz, time * 50) * 0.003);

	//v_mapPos.w = length(v_mapPos.xyz - cameraViewInv[3].xyz);
	// LETS MARCH BACKWARDS LIKE IDIOTS!
	v_simplex.z = 0.0;
	if (mapdepth > 0.9999) {
		v_simplex.xy = vec2(0);
		return;
	}
	
	vec3 mapToCam = camPos - mapWorldPos.xyz;
	vec3 toCameraNormalized = normalize(mapToCam);
	float marchcollection = 0;

	vec3 rayEnd = mapWorldPos.xyz;
	
	const float NOISETHRESHOLD = 0.1;
	
	rayEnd = clamp((fogPlaneHeight - mapWorldPos.y)/ (camPos.y- mapWorldPos.y),   0, 1) * mapToCam + mapWorldPos.xyz;
	/*
	v_meanpos = vec4(0.001);
	if (mapWorldPos.y < fogPlaneHeight) {
		
		float distanceFromTop = fogPlaneHeight - mapWorldPos.y;
		float steps = 10.0;
		for (float f = 0.0; f <= 1.0; f += 1.0 / steps){
			vec3 rayPos = mix(mapWorldPos.xyz, rayEnd, f);
			float noiseval = max(0.0,  Perlin4D(vec4(rayPos, time * 15) * 0.004) - NOISETHRESHOLD);
			marchcollection +=  noiseval;
			v_meanpos.xyz +=  rayPos * noiseval;
		}
		v_meanpos /= marchcollection ;
		marchcollection /= steps;
	
	}
	v_simplex.z = marchcollection;
	*/
	return;	
}