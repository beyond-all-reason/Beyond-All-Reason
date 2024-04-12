#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000
uniform float iconDistance = 20000.0;
in DataGS {
	vec4 g_centerpos; // xyz true world position, and width [-1,1] packed into w for ribbons
	vec4 g_uv; // xy is billboard uvs,  , z is index , w progress
};

uniform sampler3D noisetex3dcube;
uniform sampler2D minimap;
uniform sampler2D heightMap;

out vec4 fragColor;

//  Wombat
//  An efficient texture-free GLSL procedural noise library
//  Source: https://github.com/BrianSharpe/Wombat
//  Derived from: https://github.com/BrianSharpe/GPU-Noise-Lib
//
//  I'm not one for copyrights.  Use the code however you wish.
//  All I ask is that credit be given back to the blog or myself when appropriate.
//  And also to let me know if you come up with any changes, improvements, thoughts or interesting uses for this stuff. :)
//  Thanks!
//
//  Brian Sharpe
//  brisharpe CIRCLE_A yahoo DOT com
//  http://briansharpe.wordpress.com
//  https://github.com/BrianSharpe
//
//
//  This is a modified version of Stefan Gustavson's and Ian McEwan's work at http://github.com/ashima/webgl-noise
//  Modifications are...
//  - faster random number generation
//  - analytical final normalization
//  - space scaled can have an approx feature size of 1.0
//  - filter kernel changed to fix discontinuities at tetrahedron boundaries

//  Simplex Perlin Noise 3D Deriv
//  Return value range of -1.0->1.0, with format vec4( value, xderiv, yderiv, zderiv )
vec4 SimplexPerlin3D_Deriv(vec3 P)
{
    //  https://github.com/BrianSharpe/Wombat/blob/master/SimplexPerlin3D_Deriv.glsl

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

    //	normalize random gradient vectors
    vec4 norm = inversesqrt( hash_0 * hash_0 + hash_1 * hash_1 + hash_2 * hash_2 );
    hash_0 *= norm;
    hash_1 *= norm;
    hash_2 *= norm;

    //	evaluate gradients
    vec4 grad_results = hash_0 * v1234_x + hash_1 * v1234_y + hash_2 * v1234_z;

    //  evaulate the kernel weights ( use (0.5-x*x)^3 instead of (0.6-x*x)^4 to fix discontinuities )
    vec4 m = v1234_x * v1234_x + v1234_y * v1234_y + v1234_z * v1234_z;
    m = max(0.5 - m, 0.0);
    vec4 m2 = m*m;
    vec4 m3 = m*m2;

    //  calc the derivatives
    vec4 temp = -6.0 * m2 * grad_results;
    float xderiv = dot( temp, v1234_x ) + dot( m3, hash_0 );
    float yderiv = dot( temp, v1234_y ) + dot( m3, hash_1 );
    float zderiv = dot( temp, v1234_z ) + dot( m3, hash_2 );

    //	Normalization factor to scale the final result to a strict 1.0->-1.0 range
    //	http://briansharpe.wordpress.com/2012/01/13/simplex-noise/#comment-36
    const float FINAL_NORMALIZATION = 37.837227241611314102871574478976;

    //  sum and return all results as a vec3
    return vec4( dot( m3, grad_results ), xderiv, yderiv, zderiv ) * FINAL_NORMALIZATION;
}

//  Value Noise 3D
//  Return value range of 0.0->1.0
float Value3D( vec3 P )
{
    //  https://github.com/BrianSharpe/Wombat/blob/master/Value3D.glsl

    // establish our grid cell and unit position
    vec3 Pi = floor(P);
    vec3 Pf = P - Pi;
    vec3 Pf_min1 = Pf - 1.0;

    // clamp the domain
    Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
    vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

    // calculate the hash
    vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
    Pt *= Pt;
    Pt = Pt.xzxz * Pt.yyww;
    vec2 hash_mod = vec2( 1.0 / ( 635.298681 + vec2( Pi.z, Pi_inc1.z ) * 48.500388 ) );
    vec4 hash_lowz = fract( Pt * hash_mod.xxxx );
    vec4 hash_highz = fract( Pt * hash_mod.yyyy );

    //	blend the results and return
	// quintic:
    //vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0); 
	// cube:
    vec3 blend = Pf * Pf * (3.0 - 2.0 * Pf );
    vec4 res0 = mix( hash_lowz, hash_highz, blend.z );
    vec4 blend2 = vec4( blend.xy, vec2( 1.0 - blend.xy ) );
    return dot( res0, blend2.zxzx * blend2.wwyy ); 
}

//  Value Noise 3D Deriv
//  Return value range of 0.0->1.0, with format vec4( value, xderiv, yderiv, zderiv )
vec4 Value3D_Deriv( vec3 P )
{
    //  https://github.com/BrianSharpe/Wombat/blob/master/Value3D_Deriv.glsl

    // establish our grid cell and unit position
    vec3 Pi = floor(P);
    vec3 Pf = P - Pi;
    vec3 Pf_min1 = Pf - 1.0;

    // clamp the domain
    Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
    vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

    // calculate the hash
    vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
    Pt *= Pt;
    Pt = Pt.xzxz * Pt.yyww;
    vec2 hash_mod = vec2( 1.0 / ( 635.298681 + vec2( Pi.z, Pi_inc1.z ) * 48.500388 ) );
    vec4 hash_lowz = fract( Pt * hash_mod.xxxx );
    vec4 hash_highz = fract( Pt * hash_mod.yyyy );

    //	blend the results and return
    vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
    vec3 blendDeriv = Pf * Pf * (Pf * (Pf * 30.0 - 60.0) + 30.0);
    vec4 res0 = mix( hash_lowz, hash_highz, blend.z );
    vec4 res1 = mix( res0.xyxz, res0.zwyw, blend.yyxx );
    vec4 res3 = mix( vec4( hash_lowz.xy, hash_highz.xy ), vec4( hash_lowz.zw, hash_highz.zw ), blend.y );
    vec2 res4 = mix( res3.xz, res3.yw, blend.x );
    return vec4( res1.x, 0.0, 0.0, 0.0 ) + ( vec4( res1.yyw, res4.y ) - vec4( res1.xxz, res4.x ) ) * vec4( blend.x, blendDeriv );
}


// Inigo Quilez's work:
float hash( in ivec2 p )  // this hash is not production ready, please
{                         // replace this by something better

    // 2D -> 1D
    int n = p.x*3 + p.y*113;

    // 1D hash by Hugo Elias
	n = (n << 13) ^ n;
    n = n * (n * n * 15731 + 789221) + 1376312589;
    return -1.0+2.0*float( n & 0x0fffffff)/float(0x0fffffff);
}


float noise( in vec2 p )
{
    ivec2 i = ivec2(floor( p ));

    vec2 f = fract( p );
	
    #if 1
    // quintic interpolant
    vec2 u = f*f*f*(f*(f*6.0-15.0)+10.0);
    #else
    // cubic interpolant
    vec2 u = f*f*(3.0-2.0*f);
    #endif    

    return mix( mix( hash( i + ivec2(0,0) ), 
                     hash( i + ivec2(1,0) ), u.x),
                mix( hash( i + ivec2(0,1) ), 
                     hash( i + ivec2(1,1) ), u.x), u.y);
}

// Beherith's work:
vec4 CurlNoiseX(vec3 worldPos, vec3 uvproj){
	float seconds = (timeInfo.x + timeInfo.w)/30.0;
	float noiseScale = 0.07;
	vec3 noisePos = worldPos * noiseScale;
	noisePos.y -= 0.1 *seconds;
	
	vec3 derivUV = noisePos;
	
	vec4 noise_deriv;
	vec3 uvdelta;
	
	for (int s = 0; s < 1; s++){
		noise_deriv = SimplexPerlin3D_Deriv(derivUV + vec3( 0, -0.5 * seconds, 0));
		uvdelta = noise_deriv.wyz * vec3(1,-1,-1);
		derivUV += uvdelta * 0.001;
	}
	//return fract(derivUV.rgbb);
	//return (noise_deriv.yzwx * 0.2 + 0.5);
	float outnoise = 0;
	float persistence = 0.66;
	float magnitude = 1.0;
	float normsum = 0;
	derivUV = derivUV * 3;
	//https://www.andre-gaschler.com/rotationconverter/
	mat3 rotation = mat3(	0.5618833, -0.6698698,  0.4853469,
							0.7681311,  0.6402684, -0.0055704,
							-0.3070208,  0.3759400,  0.8743039);
	rotation = mat3(1,0,0,0,1,0,0,0,1);
	float scale = 1.91;
	for (int i =0; i < 4; i++){
		outnoise += magnitude * Value3D(derivUV ); 		
		normsum += magnitude;
		derivUV = scale* rotation * derivUV ;
		magnitude *= persistence;
	}
	return vec4(outnoise/normsum);
	
}

vec4 CurlNoise(vec4 modpos){
	float iTime = (timeInfo.x + timeInfo.w) / 60.0;
	vec3 noisepos = (g_centerpos.xyz - vec3(0, 0.1 * timeInfo.x,0)) * 0.015	 + g_uv.zzz;
	
    vec2 p = g_uv.xy;

	vec2 uv = p*vec2(g_centerpos.xy * 0.001) + iTime*0.025;
    vec2 baseUVs = p;
	
	float f = 0.0;


    // right: fbm - fractal noise (4 octaves)
 
        
        vec4 spd;
        vec2 cuv;
        
        for (int s = 0; s <4; s++){
            spd = SimplexPerlin3D_Deriv(vec3(uv + iTime* 0.1, iTime*0.1) * 4.0);
            //spd.yzw = normalize(spd.yzw);
            cuv = vec2(-spd.z, spd.y);
            
            // This is actually very interesting, normalizing these gives sharper curls
            vec2 normcuv = normalize(cuv);
            cuv = mix(cuv, normcuv, baseUVs.x);
            //cuv = normalize(cuv);
            uv += cuv * 0.015;
        }
     
        //uv += vec2(-spd.y, spd.x);
    
        uv -= iTime* 0.1;
		uv *= 8.0;
        mat2 m = mat2( 1.6,  1.2, -1.2,  1.6 );
		f  = 0.5000*noise( uv ); uv = m*uv;
		f += 0.5000*noise( uv ); uv = m*uv;
		//f += 0.1250*noise( uv ); uv = m*uv;
		f += 0.25*noise( uv ); uv = m*uv;
	

	f = 0.5 + 0.5*f;
	
	return vec4(f);
}

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
		vec4 simplexd = SimplexPerlin3D_Deriv(g_centerpos.xyz * 0.182);
		vec3 simpnorm = normalize(simplexd.yzw);
		noise = texture(noisetex3dcube, noisePos - simplexd.yzw * 0.02);
		vec2 distcenter = (abs(g_uv.xy * 2.0 - 1.0));
		float alphacircle = clamp(1.0 - dot(distcenter, distcenter), 0.0, 1.0);
		alphacircle = pow(alphacircle, 0.66);
		fragColor.rgba = vec4(vec3(noise.a), alphacircle * progress);
		float soften = clamp((g_centerpos.y - worldHeight) * 0.125, 0.0, 1.5);
		fragColor.a *= soften;
		fragColor.rgb = mix(fragColor.rgb,  fragColor.rgb *(minimapColor.rgb *1.5), 0.25 + 	noise.b);
	
		
		//fragColor.rgba = vec4(vec3(g_uv.rgb), 1 );
		fragColor.rgb = vec3(fragColor.a); 
		fragColor.a = 1.0;
		
		vec4 curl = CurlNoiseX(g_centerpos.xyz, g_uv.xyw);
		fragColor.rgb = curl.rgb;
		fragColor.a *= alphacircle * noise.a * soften* progress;
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