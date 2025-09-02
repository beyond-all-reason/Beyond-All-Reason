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
	vec4 sampleUVs;
};

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D heightmapTex;
uniform sampler2D infoTex;
#if SHADOWSAMPLER == 1 
	uniform sampler2DShadow shadowTex;
#else
	uniform sampler2D shadowTex;
	ivec2 shadowTexSize = textureSize(shadowTex,0);
#endif
uniform sampler3D noise64cube;
uniform sampler2D miniMapTex;
uniform sampler2D blueNoise64;
uniform sampler2D packedNoise;
uniform sampler3D uniformNoiseTex;

uniform vec4 windFractFull;
uniform vec4 heightFogColor;
uniform vec4 cloudGlobalColor;
uniform vec4 distanceFogColor;
uniform vec4 shadowedColor;
uniform vec4 noiseLFParams;
uniform vec4 noiseHFParams;

uniform float cloudDensity;
uniform float heightFogTop;
uniform float heightFogBottom;

uniform vec4 cloudVolumeMin;
uniform vec4 cloudVolumeMax;
uniform vec4 scavengerPlane;

out vec4 fragColor;

float frequency;

#if 1 // These are globally useful helpers
	float shadowAtWorldPos(vec3 worldPos){
			vec4 shadowVertexPos = shadowView * vec4(worldPos,1.0);
			shadowVertexPos.xy += vec2(0.5);
			#define SHADOWLODBIAS 2
			// Details on textureProj PCF http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-16-shadow-mapping/
			// Idea for using texelFetch https://community.khronos.org/t/can-you-use-sampler2d-and-sampler2dshadow-on-the-same-texture/76203
			#if SHADOWSAMPLER == 1 // TextureProj does 4 sample PCF filtering in hardware
				return clamp(textureProj(shadowTex, shadowVertexPos, - SHADOWLODBIAS), 0.0, 1.0);
			#endif
			#if SHADOWSAMPLER == 0 // Regular Texture Fetch operation
				return step(shadowVertexPos.z, texture(shadowTex, shadowVertexPos.xy, 10).z);
			#endif
			#if SHADOWSAMPLER == 2 // http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-16-shadow-mapping/
				//float clampy = 
				// TODO: if ray starts or ends outside of shadow map, just stop
				if (any(bvec4(greaterThan(shadowVertexPos.xy, vec2(0.999)), lessThan(shadowVertexPos.xy, vec2(0.0))))) return 1.0;
				else 
					return step(shadowVertexPos.z, texelFetch(shadowTex, ivec2(shadowTexSize *shadowVertexPos.xy) , 0).z);
			#endif			
			#if SHADOWSAMPLER == 3 // This one results in the most interesting, ambient-occlusion-like effect i have ever seen!
				float near = 0.1; 
				float far  = 100.0; 
				float shadowZ = texelFetch(shadowTex, ivec2(shadowTexSize *shadowVertexPos.xy) , 0).z; 
				float linearShad = (20) / (100.1 - shadowZ * (99.9 )) * 100;
				float linearSamp = (20) / (100.1 - shadowVertexPos.z * (99.9 )) * 100;
				
				return clamp((linearShad -  linearSamp ) * 2, 0,1);
			#endif
	}
	float losLevelAtWorldPos(vec3 worldPos){ // this returns 0 for not in los, 1 for in los, -100 for never seen
		vec2 losUV = clamp(worldPos.xz, vec2(0.0), mapSize.xy ) / mapSize.xy;
		vec4 infoTexSample = texture(infoTex, losUV);
		if (infoTexSample.r > 0.2) 
			return clamp((infoTexSample.r -0.2) / 0.70 ,0,1) * LOSREDUCEFOG;
		else 
			//return 0;
			return (LOSFOGUNDISCOVERED) * (-100) * (0.2 - infoTexSample.r);
	}

	float rand(vec2 co){
		return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
	}
	
	// returns the linear distance to the closest edge of the map in 3d
	float linearDistanceMap(vec3 worldpos){
		vec3 worldMax = vec3(float(MAPSIZEX), float(MAPSIZEY),float(MAPSIZEZ));
		vec3 minDist = max(-1 * worldpos, worldpos - worldMax);
		minDist = max(minDist, vec3(0.0));
		return max(minDist.x, max(minDist.y, minDist.z));
	}

	// returns the linear distance to the closest edge of the map, in elmos
	vec2 linearDistanceMapXZ(vec2 worldpos){
		vec2 worldMax = vec2(float(MAPSIZEX), float(MAPSIZEZ));
		vec2 minDist = max(-1 * worldpos, worldpos - worldMax);
		minDist = max(minDist, vec2(0.0));
		return minDist;
	}

	float linearDistanceMapXZThreshold(vec2 worldpos, float thresholdElmos){
		vec2 worldMax = vec2(float(MAPSIZEX), float(MAPSIZEZ));
		vec2 minDist = max(-1 * worldpos, worldpos - worldMax);
		minDist = max(minDist, vec2(0.0));
		float realdist = sqrt(dot(minDist, minDist));
		realdist = (thresholdElmos - realdist + 1)/ max(1,thresholdElmos);
		return realdist;
	}
	// This will bound within the min/max values, with feathering along the w coordinates of CloudVolume
	float CloudVoumeWeight(vec2 worldpos){
		vec2 cloudDist = max(vec2(0), max(cloudVolumeMin.xz - worldpos, worldpos - cloudVolumeMax.xz));
		float cloudEdgeDistanceWeight = sqrt(dot(cloudDist, cloudDist));
		cloudEdgeDistanceWeight = ((cloudVolumeMax.w + 1) - cloudEdgeDistanceWeight)/(1 +cloudVolumeMax.w);
		cloudEdgeDistanceWeight = clamp(cloudEdgeDistanceWeight,0,1);
		cloudEdgeDistanceWeight = sqrt(cloudEdgeDistanceWeight);
		return cloudEdgeDistanceWeight;
	}
	

#endif

#if 1 // These are all standard, useful Noise functions 
//  https://github.com/BrianSharpe/Wombat/blob/master/Value3D.glsl
float Value3D( vec3 P )// actually works and is correct and fast and random
{
    // establish our grid cell and unit position
    vec3 Pi = floor(P);
    vec3 Pf = P - Pi;

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
    //vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
    //vec3 blend = smoothstep(0,1,Pf); // better than 5th order as above (and faster)
    vec3 blend = Pf * Pf * (3.0 - 2.0 * Pf); // better than 5th order as above (and faster)
    vec4 res0 = mix( hash_lowz, hash_highz, blend.z );
    vec4 blend2 = vec4( blend.xy, vec2( 1.0 - blend.xy ) );
    return dot( res0, blend2.zxzx * blend2.wwyy );
}

vec4 Value3D_Deriv( vec3 P ) // actually works and is correct and fast and random
{
    // establish our grid cell and unit position
    vec3 Pi = floor(P);
    vec3 Pf = P - Pi;

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

	// better than 5th order poly used previously
    vec3 blend = Pf * Pf * (3.0 - 2.0 * Pf); 

    //	blend the results and return
	// res0 results in the 2d squash along Z:
    vec4 res0 =  mix(hash_lowz, hash_highz, blend.z );
	vec2 res1 =  mix(res0.xy  , res0.zw   , blend.y);
	float res2 = mix(res1.x   , res1.y    , blend.x);

	// Below is the simple derivative based approach
	// DERIVATIVES
	#define DERIVSTEP 1024.0
	vec3 derivatives = vec3(0);
	// Move the Pf vector a bit
	vec3 blendderiv = min(vec3(1), Pf + 1.0/DERIVSTEP); // The min is to ensure we dont move out of smoothstep range
	blendderiv =   blendderiv * blendderiv * (3.0 - 2.0 * blendderiv);
	// Calculate the same three as above, just at a the derivative step of Z
	vec4 res0deriv   = mix(hash_lowz   , hash_highz  , blendderiv.z);
	vec2 res1derivz  = mix(res0deriv.xy, res0deriv.zw, blend.y);
	derivatives.z    = mix(res1derivz.x, res1derivz.y, blend.x);

	// Then on derivative step of Y
	vec2 res1derivy =  mix(res0.xy  , res0.zw   , blendderiv.y);
	derivatives.y   =  mix(res1derivy.x   , res1derivy.y    , blend.x);
	
	// then on derivatie step of X
	derivatives.x   =  mix(res1.x   , res1.y    , blendderiv.x);
	derivatives = (res2 - derivatives) * DERIVSTEP;
    return vec4(derivatives, res2);
}

// fastest 3d noise ever? https://www.shadertoy.com/view/WslGWl
// its nice, but not random enough
float fbmhash(float n){return fract(sin(n) * 43758.5453);}
vec4 FBMNoise3DDeriv(in vec3 x) // uses S
{
	vec3 p = floor(x);
	vec3 f = fract(x);
	vec3 oldf = f;
	
	vec3 fd =  - 6.0 * f * f + 6.0 * f; 
	f = f * f * (3.0 - 2.0 * f);
	
	float n = p.x + p.y * 57.0 + p.z * 113.0;
	
	vec4 hash_0 = fract(sin(vec4(0, 57, 113, 170)+ n    ) * 43758.5453);
	vec4 hash_1 = fract(sin(vec4(0, 57, 113, 170)+ n + 1) * 43758.5453);
	vec4 mix_4 = mix(hash_0, hash_1, f.x);
	vec2 mix_2 = mix(mix_4.xz, mix_4.yw, f.y);
	float myn = mix(mix_2.x, mix_2.y, f.z);
	
	// This is simple directional derivative inspired by https://iquilezles.org/articles/derivative/ 
	float stepsize = 0.001;
	vec3 dir = sunDir.xyz * stepsize;
	vec3 f2 = oldf - dir * fd;
	
	f2 = smoothstep(0,1,f2);
	vec4 mix2_4 = mix(hash_0, hash_1, f2.x);
	vec2 mix2_2 = mix(mix2_4.xz, mix2_4.yw, f2.y);
	float myn2 = mix(mix2_2.x, mix2_2.y, f2.z);
	vec3 deriv =  vec3(myn - myn2)/ stepsize;
	return vec4(myn, deriv * myn);
}

float FBMNoise3D(in vec3 x) // nah this is the fastest!
{
	vec3 p = floor(x);
	vec3 f = fract(x);
	
	f = f * f * (3.0 - 2.0 * f);
	
	float n = p.x + p.y * 57.0 + p.z * 113.0;
	
	vec4 hash_0 = fract(sin(vec4(0, 57, 113, 170)+ n    ) * 43758.5453);
	vec4 hash_1 = fract(sin(vec4(0, 57, 113, 170)+ n + 1) * 43758.5453);
	vec4 mix_4 = mix(hash_0, hash_1, f.x);
	vec2 mix_2 = mix(mix_4.xz, mix_4.yw, f.y);
	float myn = mix(mix_2.x, mix_2.y, f.z);
	return myn;
}

float FBMNoise3DXF(in vec3 x) // nah this is the fastest!
{
	vec3 p = floor(x);
	vec3 f = x - p;
	 
	//f = f * f * (3.0 - 2.0 * f);
	float n = p.x + p.y * 57.0 + p.z * 113.0;
	//vec4 H1Pre = sin(vec4(0, 57, 113, 170)+ n    ) ;
	vec4 hash_0 = fract(sin(vec4(0, 57, 113, 170)+ n    ) * 43758.5453);
	vec4 hash_1 = fract(sin(vec4(0, 57, 113, 170)+ n  + 1) * 43758.5453);
	vec4 mix_4 = mix(hash_0, hash_1, f.x);
	vec2 mix_2 = mix(mix_4.xz, mix_4.yw, f.y);
	float myn = mix(mix_2.x, mix_2.y, f.z);
	return myn;
}


vec2 FBMNoise3D_rg(in vec3 x) // return two noise floats
{
	vec3 p = floor(x);
	vec3 f = x - p;
	 
	//f = f * f * (3.0 - 2.0 * f);
	
	float n = p.x + p.y * 57.0 + p.z * 113.0;
	//vec4 H1Pre = sin(vec4(0, 57, 113, 170)+ n    ) ;
	vec4 pos_0 = sin(vec4(0, 57, 113, 170)+ n    );
	vec4 pos_1 = sin(vec4(0, 57, 113, 170)+ n  + 1);

	vec4 hash_r_0 = fract( pos_0 * 43758.5453);
	vec4 hash_r_1 = fract( pos_1 * 43758.5453);
	vec4 mix_r_4 = mix(hash_r_0, hash_r_1, f.x);

	vec4 hash_g_0 = fract( pos_0 * 41758.5453);
	vec4 hash_g_1 = fract( pos_1 * 41758.5453);
	vec4 mix_g_4 = mix(hash_g_0, hash_g_1, f.x);
	
	vec4 mix_rg = mix(vec4(mix_r_4.xz, mix_g_4.xz), vec4(mix_r_4.yw, mix_g_4.yw), f.y);
	return mix(mix_rg.xz, mix_rg.yw,f.z);
}

vec4 FBMNoise3D_rgba(in vec3 x) // return 4 noise floats
{
	vec3 p = floor(x);
	vec3 f = x - p;
	 
	f = f * f * (3.0 - 2.0 * f);
	
	float n = p.x + p.y * 57.0 + p.z * 113.0;
	//vec4 H1Pre = sin(vec4(0, 57, 113, 170)+ n    ) ;
	vec4 pos_0 = sin(vec4(0, 57, 113, 170)+ n    );
	vec4 pos_1 = sin(vec4(0, 57, 113, 170)+ n  + 1);

	vec4 hash_r_0 = fract( pos_0 * 43758.5453);
	vec4 hash_r_1 = fract( pos_1 * 43758.5453);
	vec4 mix_r_4 = mix(hash_r_0, hash_r_1, f.x);

	vec4 hash_g_0 = fract( pos_0 * 41758.5453);
	vec4 hash_g_1 = fract( pos_1 * 41758.5453);
	vec4 mix_g_4 = mix(hash_g_0, hash_g_1, f.x);
	
	vec4 mix_rg = mix(vec4(mix_r_4.xz, mix_g_4.xz), vec4(mix_r_4.yw, mix_g_4.yw), f.y);

	vec4 hash_b_0 = fract( pos_0 * 39758.5453);
	vec4 hash_b_1 = fract( pos_1 * 39758.5453);
	vec4 mix_b_4 = mix(hash_b_0, hash_b_1, f.x);

	vec4 hash_a_0 = fract( pos_0 * 31758.5453);
	vec4 hash_a_1 = fract( pos_1 * 31758.5453);
	vec4 mix_a_4 = mix(hash_a_0, hash_a_1, f.x);

	vec4 mix_ba = mix(vec4(mix_b_4.xz, mix_a_4.xz), vec4(mix_b_4.yw, mix_a_4.yw), f.y);
	
	return mix(vec4(mix_rg.xz, mix_ba.xz), vec4(mix_rg.yw, mix_ba.yw),f.z);
}



//https://www.shadertoy.com/view/4sfGzS

float hash3(vec3 p)  // replace this by something better
{
    p  = fract( p*0.3183099+.1 );
	p *= 17.0;
    return fract( p.x*p.y*p.z*(p.x+p.y+p.z) );
}

float noiseIQ3( in vec3 x )
{
    vec3 f = fract(x);
    vec3 i = x-f;
    //vec3 f = fract(x);
    f = f*f*(3.0-2.0*f);
	
    return mix(mix(mix( hash3(i+vec3(0,0,0)), 
                        hash3(i+vec3(1,0,0)),f.x),
                   mix( hash3(i+vec3(0,1,0)), 
                        hash3(i+vec3(1,1,0)),f.x),f.y),
               mix(mix( hash3(i+vec3(0,0,1)), 
                        hash3(i+vec3(1,0,1)),f.x),
                   mix( hash3(i+vec3(0,1,1)), 
                        hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}

float FBMNoise2D(in vec2 x) // nah this is the fastest!
{
	vec2 f = fract(x);
	vec2 p = x-f;
	
	f = f * f * (3.0 - 2.0 * f);
	
	float n = p.x + p.y * 57;
	
	vec4 hash_0 = fract((vec4(0, 57, 1, 58) + n) * 20.7453);
	//hash_0 = vec4(0,0,1,0);
	vec2 mix_2 = mix(hash_0.xy, hash_0.zw, f.x);
	float myn = mix(mix_2.x, mix_2.y, f.y);
	return myn;
}

//  https://github.com/BrianSharpe/Wombat/blob/master/Value3D.glsl
vec4 Value3D3( vec3 P )
{
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
    //vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
    vec3 blend = Pf * Pf * (3.0 - 2.0 * Pf); // better than 5th order as above (and faster)
    vec4 res0 = mix( hash_lowz, hash_highz, blend.z );
    vec4 blend2 = vec4( blend.xy, vec2( 1.0 - blend.xy ) );
	
    return vec4(dot( res0, blend2.zxzx * blend2.wwyy ), blend);
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

//  Cellular Noise 3D Deriv
//  Return value range of 0.0->1.0, with format vec4( value, xderiv, yderiv, zderiv )
//
vec4 Cellular3D_Deriv( vec3 P )
{
    //  https://github.com/BrianSharpe/Wombat/blob/master/Cellular3D_Deriv.glsl

    //	establish our grid cell and unit position
    vec3 Pi = floor(P);
    vec3 Pf = P - Pi;

    // clamp the domain
    Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
    vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

    // calculate the hash ( over -1.0->1.0 range )
    vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
    Pt *= Pt;
    Pt = Pt.xzxz * Pt.yyww;
    const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
    const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
    vec3 lowz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi.zzz * ZINC ) );
    vec3 highz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi_inc1.zzz * ZINC ) );
    vec4 hash_x0 = fract( Pt * lowz_mod.xxxx ) * 2.0 - 1.0;
    vec4 hash_x1 = fract( Pt * highz_mod.xxxx ) * 2.0 - 1.0;
    vec4 hash_y0 = fract( Pt * lowz_mod.yyyy ) * 2.0 - 1.0;
    vec4 hash_y1 = fract( Pt * highz_mod.yyyy ) * 2.0 - 1.0;
    vec4 hash_z0 = fract( Pt * lowz_mod.zzzz ) * 2.0 - 1.0;
    vec4 hash_z1 = fract( Pt * highz_mod.zzzz ) * 2.0 - 1.0;

    //  generate the 8 point positions
    const float JITTER_WINDOW = 0.166666666;	// 0.166666666 will guarentee no artifacts.
    hash_x0 = ( ( hash_x0 * hash_x0 * hash_x0 ) - sign( hash_x0 ) ) * JITTER_WINDOW + vec4( 0.0, 1.0, 0.0, 1.0 );
    hash_y0 = ( ( hash_y0 * hash_y0 * hash_y0 ) - sign( hash_y0 ) ) * JITTER_WINDOW + vec4( 0.0, 0.0, 1.0, 1.0 );
    hash_x1 = ( ( hash_x1 * hash_x1 * hash_x1 ) - sign( hash_x1 ) ) * JITTER_WINDOW + vec4( 0.0, 1.0, 0.0, 1.0 );
    hash_y1 = ( ( hash_y1 * hash_y1 * hash_y1 ) - sign( hash_y1 ) ) * JITTER_WINDOW + vec4( 0.0, 0.0, 1.0, 1.0 );
    hash_z0 = ( ( hash_z0 * hash_z0 * hash_z0 ) - sign( hash_z0 ) ) * JITTER_WINDOW + vec4( 0.0, 0.0, 0.0, 0.0 );
    hash_z1 = ( ( hash_z1 * hash_z1 * hash_z1 ) - sign( hash_z1 ) ) * JITTER_WINDOW + vec4( 1.0, 1.0, 1.0, 1.0 );

    //	return the closest squared distance + derivatives ( thanks to Jonathan Dupuy )
    vec4 dx1 = Pf.xxxx - hash_x0;
    vec4 dy1 = Pf.yyyy - hash_y0;
    vec4 dz1 = Pf.zzzz - hash_z0;
    vec4 dx2 = Pf.xxxx - hash_x1;
    vec4 dy2 = Pf.yyyy - hash_y1;
    vec4 dz2 = Pf.zzzz - hash_z1;
    vec4 d1 = dx1 * dx1 + dy1 * dy1 + dz1 * dz1;
    vec4 d2 = dx2 * dx2 + dy2 * dy2 + dz2 * dz2;
    vec4 r1 = d1.x < d1.y ? vec4( d1.x, dx1.x, dy1.x, dz1.x ) : vec4( d1.y, dx1.y, dy1.y, dz1.y );
    vec4 r2 = d1.z < d1.w ? vec4( d1.z, dx1.z, dy1.z, dz1.z ) : vec4( d1.w, dx1.w, dy1.w, dz1.w );
    vec4 r3 = d2.x < d2.y ? vec4( d2.x, dx2.x, dy2.x, dz2.x ) : vec4( d2.y, dx2.y, dy2.y, dz2.y );
    vec4 r4 = d2.z < d2.w ? vec4( d2.z, dx2.z, dy2.z, dz2.z ) : vec4( d2.w, dx2.w, dy2.w, dz2.w );
    vec4 t1 = r1.x < r2.x ? r1 : r2;
    vec4 t2 = r3.x < r4.x ? r3 : r4;
    return ( t1.x < t2.x ? t1 : t2 ) * vec4( 1.0, vec3( 2.0 ) ) * ( 9.0 / 12.0 ); // return a value scaled to 0.0->1.0
}
#endif

#if 1 // The packed 3D noise sampler by Beherith

float packedNoiseLod = 0;
vec4 getPackedNoise(vec3 P){
	// e.g. worley3_256x128x64_RBGA_LONG.png/dds
	// This system assumes that a noise texture is packed into 2D with the following rules:
	// The noises Z axis is tiled along the X axis of the 2D texture
	// The G and A channels are higher precision in DXT5
	// The R ang B channels are lower precision
	// the RG and BA channels are offset by one step along the Z tiling so that interpolation can be done
	// needs textureLOD to prevent seams from warping.
	// perf Benefits from DDS compression greatly, but quality suffers a bit
	// The LOD level selection needs to be done carefully, as DDS suffers from shitty compression artifacts
	// can we fix LOD issues? yes cause .png suffers from bad lodding and hammering the memory subsystem, which is fixed by the packedNoiseLod dependent on camera distance.
	// VERY IMPORTANT NOTE: the fract operations + wide texture means precision is lost after a lot of offset in X
	// Thus must be mitigated by FRACT-ing the wind offsets from Lua to ensure they stay within [0-1] throughout the game
	// returns noise G + A in x, R + B in y, and the uninterpolated results in zw
	
	#define PACKX 256 // MUST BE SET TO PACKED TEXTURE DIMS
	#define PACKY 128
	#define PACKZ 64
	P = P.xzy; // swizzle coords here, because Z and Y are swapped
	P = P * vec3(1,2,4);
	

	//X is Y, 
	// Split Z into PACKZ levels, and put it into Y
	vec2 packedUV = vec2(P.x, fract(P.y));
	float fractZ = fract(P.z * PACKZ);
	float floorz = P.z * PACKZ - fractZ;
	packedUV.y = (packedUV.y + floorz) / PACKZ;
	//fractZ *= fractZ * fractZ * (3.0 - 2.0 * fractZ); // optional smoothing?
	vec4 packedSample = textureLod(packedNoise, packedUV.yx, packedNoiseLod); //yz is swapped here cause tex is tiled along X
	vec2 mixedSample = mix(packedSample.rg, packedSample.ba,  fractZ );
 
	return vec4(mixedSample.y, mixedSample.x,packedSample.w, packedSample.z);
}
#endif

#line 31000

#if 1 // Fast and simple FBM noises
//from : https://www.shadertoy.com/view/4dS3Wd
// Precision-adjusted variations of https://www.shadertoy.com/view/4djSRW
float hash(float p) { p = fract(p * 0.011); p *= p + 7.5; p *= p + p; return fract(p); }
float hash(vec2 p) {vec3 p3 = fract(vec3(p.xyx) * 0.13); p3 += dot(p3, p3.yzx + 3.333); return fract((p3.x + p3.y) * p3.z); }

float noise(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f);
    return mix(hash(i), hash(i + 1.0), u);
}


float noise(vec2 x) {
    vec2 i = floor(x);
    vec2 f = fract(x);

	// Four corners in 2D of a tile
	float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    // Simple 2D lerp using smoothstep envelope between the values.
	// return vec3(mix(mix(a, b, smoothstep(0.0, 1.0, f.x)),
	//			mix(c, d, smoothstep(0.0, 1.0, f.x)),
	//			smoothstep(0.0, 1.0, f.y)));

	// Same code, with the clamps in smoothstep and common subexpressions
	// optimized away.
    vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}


float noise(vec3 x) {
    const vec3 step = vec3(110, 241, 171);

    vec3 i = floor(x);
    vec3 f = fract(x);
 
    // For performance, compute the base input to a 1D hash from the integer part of the argument and the 
    // incremental change to the 1D based on the 3D -> 1D wrapping
    float n = dot(i, step);

    vec3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix( hash(n + dot(step, vec3(0, 0, 0))), hash(n + dot(step, vec3(1, 0, 0))), u.x),
                   mix( hash(n + dot(step, vec3(0, 1, 0))), hash(n + dot(step, vec3(1, 1, 0))), u.x), u.y),
               mix(mix( hash(n + dot(step, vec3(0, 0, 1))), hash(n + dot(step, vec3(1, 0, 1))), u.x),
                   mix( hash(n + dot(step, vec3(0, 1, 1))), hash(n + dot(step, vec3(1, 1, 1))), u.x), u.y), u.z);
}
#endif

#line 32000

#if 1 // QUAD MESSAGE PASSING LIBRARY
// https://github.com/libretro/common-shaders/blob/master/include/quad-pixel-communication.h 
vec4 get_quad_vector_naive(vec4 output_pixel_num_wrt_uvxy)
	{
		//  Requires:   Two measures of the current fragment's output pixel number
		//              in the range ([0, IN.output_size.x), [0, IN.output_size.y)):
		//              1.) output_pixel_num_wrt_uvxy.xy increase with uv coords.
		//              2.) output_pixel_num_wrt_uvxy.zw increase with screen xy.
		//  Returns:    Two measures of the fragment's position in its 2x2 quad:
		//              1.) The .xy components are its 2x2 placement with respect to
		//                  uv direction (the origin (0, 0) is at the top-left):
		//                  top-left     = (-1.0, -1.0) top-right    = ( 1.0, -1.0)
		//                  bottom-left  = (-1.0,  1.0) bottom-right = ( 1.0,  1.0)
		//                  You need this to arrange/weight shared texture samples.
		//              2.) The .zw components are its 2x2 placement with respect to
		//                  screen xy direction (IN.position); the origin varies.
		//                  quad_gather needs this measure to work correctly.
		//              Note: quad_vector.zw = quad_vector.xy * float2(
		//                      ddx(output_pixel_num_wrt_uvxy.x),
		//                      ddy(output_pixel_num_wrt_uvxy.y));
		//  Caveats:    This function assumes the GPU driver always starts 2x2 pixel
		//              quads at even pixel numbers.  This assumption can be wrong
		//              for odd output resolutions (nondeterministically so).
		vec4 pixel_odd = fract(output_pixel_num_wrt_uvxy * 0.5) * 2.0;
		vec4 quad_vector = pixel_odd * 2.0 - vec4(1.0);
		return quad_vector;
	}
vec4 get_quad_vector(vec4 output_pixel_num_wrt_uvxy)
{
    //  Requires:   Same as get_quad_vector_naive() (see that first).
    //  Returns:    Same as get_quad_vector_naive() (see that first), but it's
    //              correct even if the 2x2 pixel quad starts at an odd pixel,
    //              which can occur at odd resolutions.
    vec4 quad_vector_guess =
        get_quad_vector_naive(output_pixel_num_wrt_uvxy);
    //  If quad_vector_guess.zw doesn't increase with screen xy, we know
    //  the 2x2 pixel quad starts at an odd pixel:
    vec2 odd_start_mirror = 0.5 * vec2(dFdx(quad_vector_guess.z),
                                                dFdy(quad_vector_guess.w));
    return quad_vector_guess * odd_start_mirror.xyxy;
}
/*

vec4 quad_gather(const vec4 quad_vector, const float curr)
{
    //  Float version:
    //  Returns:    return.x == current
    //              return.y == adjacent x
    //              return.z == adjacent y
    //              return.w == diagonal
    //vec4 all = vec4(curr);
    //all.y = all.x - dFdx(all.x) * quad_vector.z;
    //all.zw = all.xy - dFxy(all.xy) * quad_vector.w;
    //return all;
}

vec4 quad_gather_sum(const vec4 quad_vector, const vec4 curr)
{
    //  Requires:   Same as quad_gather()
    //  Returns:    Sum of an input vector (curr) at all fragments in a quad.
    //vec4 adjx, adjy, diag;
    //quad_gather(quad_vector, curr, adjx, adjy, diag);
    //return (curr + adjx + adjy + diag);
}
*/
#line 32100
// Most of what follows is the based on the paper
// Shader Amortization using Pixel Quad Message // Passing
// https://gitea.yiem.net/QianMo/Real-Time-Rendering-4th-Bibliography-Collection/raw/branch/main/Chapter%201-24/[1368]%20[GPU%20Pro2%202011]%20Shader%20Amortization%20Using%20Pixel%20Quad%20Message%20Passing.pdf

vec2 quadVector = vec2(0); // REQUIRED, contains the [-1,1] mappings
// one-hot encoding of thread ID
//vec4 threadMask = vec4(0); // contains the thread ID in one-hot

vec4 selfWeights = vec4(WEIGHTFACTOR*WEIGHTFACTOR, WEIGHTFACTOR*(1.0-WEIGHTFACTOR), WEIGHTFACTOR*(1.0-WEIGHTFACTOR), (1.0-WEIGHTFACTOR)*(1.0-WEIGHTFACTOR)); // F*F, F*(1.0-F), F*(1.0-F), (1-F)*(1-F)
#define selfWeightFactor 0.07
//vec4 selfWeights = vec4(0.25) + vec4(selfWeightFactor, selfWeightFactor/ -3.0, selfWeightFactor/ -3.0, selfWeightFactor/-3.0);

vec4 quadGetThreadMask(vec2 qv){ 
	vec4 threadMask =  step(vec4(qv.xy,0,0),vec4( 0,0,qv.xy));
	return threadMask.xzxz * threadMask.yyww;
}

// [-1,1] quad vector as per get_quad_vector_naive
vec2 quadGetQuadVector(vec2 screenCoords){
	vec2 quadVector =  fract(floor(screenCoords) * 0.5) * 4.0 - 1.0;
	vec2 odd_start_mirror = 0.5 * vec2(dFdx(quadVector.x), dFdy(quadVector.y));
	quadVector = quadVector * odd_start_mirror;
	return sign(quadVector);
}

// Swizzle thread mask to be able to sort values from individual threads 
// Only needed if thread order matters, unlike with Sum
// NOTE THAT THIS ALLOWS FOR AMAZING FILTERING STEPS!
mat4 quadGetThreadMatrix(float smoothfactor){
	vec4 threadMask =  step(vec4(quadVector.xy,0,0),vec4( 0,0,quadVector.xy));
	return mat4(
		clamp(vec4(threadMask.xyzw),smoothfactor/3, 1.0-smoothfactor),
		clamp(vec4(threadMask.yxwz),smoothfactor/3, 1.0-smoothfactor),
		clamp(vec4(threadMask.zwxy),smoothfactor/3, 1.0-smoothfactor),
		clamp(vec4(threadMask.wzyx),smoothfactor/3, 1.0-smoothfactor) );
}


vec4 quadFBM(vec3 Pos, vec4 frequencies, vec2 screenUV, vec2 screenCoords){
	// identify each fragment
	vec4 quad_vector = get_quad_vector_naive(vec4(screenUV, floor(screenCoords))); // div screencoods by 2 wtf?
	// zw of this is [-1,1]
	//return vec4(0.0);
	
		//vec4 pixel_odd = fract(output_pixel_num_wrt_uvxy * 0.5) * 2.0;
		//vec4 quad_vector = pixel_odd * 2.0 - vec4(1.0);
	
	vec4 threadMask = vec4(0);
	//if ((quad_vector.z < -0.5 )&& (quad_vector.w < -0.5 )) threadMask.x = 1;
	//if ((quad_vector.z > 0.5 )&& (quad_vector.w < -0.5 )) threadMask.y = 1;
	//if ((quad_vector.z < -0.5 )&& (quad_vector.w > 0.5 )) threadMask.z = 1;
	//if ((quad_vector.z > 0.5 )&& (quad_vector.w > 0.5 )) threadMask.w = 1;
	threadMask = step(vec4(quad_vector.zw,0,0),vec4( 0,0,quad_vector.zw));
	threadMask = threadMask.spsp * threadMask.ttqq;
	
	// establish a common position as the average?
	//	Not always needed... and expensive too!
	#if 0
		vec3 adjx = Pos - dFdx(Pos) * quad_vector.z;
		vec3 adjy = Pos - dFdy(Pos) * quad_vector.w;
		vec3 diag = adjx - dFdy(adjx) * quad_vector.w;
		Pos = Pos + adjx + adjy + diag;
		Pos = Pos /4;
	#endif
	
	vec4 octaves = vec4(0);
	
	#if (0) // 2d nosie
	//everyone do the noise
		vec4 noise = FBMNoise3DDeriv(Pos * dot(threadMask, frequencies));
		
		//gather the noise like above
		vec4 nadjx = noise - dFdx(noise) * quad_vector.z;
		vec4 nadjy = noise - dFdy(noise) * quad_vector.w;
		vec4 ndiag = nadjx - dFdy(nadjy) * quad_vector.w;
		octaves.x = dot(vec4(noise.x, nadjx.x, nadjy.x, ndiag.x), 1.0/frequencies);
		octaves.y = dot(vec4(noise.y, nadjx.y, nadjy.y, ndiag.y), 1.0/frequencies);
	#else
		float noise = FBMNoise3D(Pos * dot(threadMask, frequencies)) * dot(threadMask, 1.0/frequencies);
		//gather the noise like above
		float nadjx = noise - dFdx(noise) * quad_vector.z;
		float nadjy = noise - dFdy(noise) * quad_vector.w;
		float ndiag = nadjx - dFdy(nadjx) * quad_vector.w;
		
		vec4 result = vec4(0.0);
		octaves = vec4(noise , nadjx, nadjy, ndiag);
		#if 0
			result.r = dot(octaves.xyzw,threadMask);
			result.g = dot(octaves.yxwz,threadMask);
			result.b = dot(octaves.zwxy,threadMask);
			result.a = dot(octaves.wzyx,threadMask);
			octaves = result;
		#else 
			octaves = vec4(dot(vec4(0.25), octaves));
		#endif
	#endif
	//return vec4(vec3(quad_vector.zwx), 1.0);
	return octaves;
}

#line 32300
// takes a float, and gathers it from the adjacent fragments
vec4 quadGather(float myvalue){
		float inputadjx = myvalue - dFdx(myvalue) * quadVector.x;
		float inputadjy = myvalue - dFdy(myvalue) * quadVector.y;
		float inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return vec4(myvalue, inputadjx, inputadjy, inputdiag);
}

vec4 quadGather(float myvalue, vec2 qv){
		float inputadjx = myvalue - dFdx(myvalue) * quadVector.x;
		float inputadjy = myvalue - dFdy(myvalue) * quadVector.y;
		float inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return vec4(myvalue, inputadjx, inputadjy, inputdiag);
}

float quadGatherWeighted(float myvalue){
		float inputadjx = myvalue - dFdx(myvalue) * quadVector.x;
		float inputadjy = myvalue - dFdy(myvalue) * quadVector.y;
		float inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return dot( vec4(myvalue, inputadjx, inputadjy, inputdiag), selfWeights);
}

// takes a gentype, and gathers and sums it from adjacent fragments
float quadGatherSumFloat(float myvalue){
		float inputadjx = myvalue - dFdx(myvalue) * quadVector.x;
		float inputadjy = myvalue - dFdy(myvalue) * quadVector.y;
		float inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return dot( vec4(myvalue, inputadjx, inputadjy, inputdiag), vec4(0.25));
}


vec2 quadGatherSum2D(vec2 myvalue){
		vec2 inputadjx = myvalue - dFdx(myvalue) * quadVector.x;
		vec2 inputadjy = myvalue - dFdy(myvalue) * quadVector.y;
		vec2 inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return vec2(
			dot( vec4(myvalue.x, inputadjx.x, inputadjy.x, inputdiag.x), vec4(1.0)),
			dot( vec4(myvalue.y, inputadjx.y, inputadjy.y, inputdiag.y), vec4(1.0))
			);
}
vec3 quadGatherSum3D(vec3 myvalue){
		vec3 inputadjx = myvalue - dFdx(myvalue) * quadVector.x;
		vec3 inputadjy = myvalue - dFdy(myvalue) * quadVector.y;
		vec3 inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return vec3(
			dot( vec4(myvalue.x, inputadjx.x, inputadjy.x, inputdiag.x), vec4(1.0)),
			dot( vec4(myvalue.y, inputadjx.y, inputadjy.y, inputdiag.y), vec4(1.0)),
			dot( vec4(myvalue.z, inputadjx.z, inputadjy.z, inputdiag.z), vec4(1.0))
			);
}
vec4 quadGatherSum4D(vec4 myvalue){
		vec4 inputadjx = myvalue - dFdx(myvalue) * quadVector.x;
		vec4 inputadjy = myvalue - dFdy(myvalue) * quadVector.y;
		vec4 inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return vec4(
			dot( vec4(myvalue.x, inputadjx.x, inputadjy.x, inputdiag.x), vec4(1.0)),
			dot( vec4(myvalue.y, inputadjx.y, inputadjy.y, inputdiag.y), vec4(1.0)),
			dot( vec4(myvalue.z, inputadjx.z, inputadjy.z, inputdiag.z), vec4(1.0)),
			dot( vec4(myvalue.w, inputadjx.w, inputadjy.w, inputdiag.w), vec4(1.0))
			);
}

vec4 quadGatherWeighted4D(vec4 myvalue){
		vec4 inputadjx = myvalue - dFdx(myvalue) * quadVector.x;
		vec4 inputadjy = myvalue - dFdy(myvalue) * quadVector.y;
		vec4 inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return vec4(
			dot( vec4(myvalue.x, inputadjx.x, inputadjy.x, inputdiag.x), selfWeights),
			dot( vec4(myvalue.y, inputadjx.y, inputadjy.y, inputdiag.y), selfWeights),
			dot( vec4(myvalue.z, inputadjx.z, inputadjy.z, inputdiag.z), selfWeights),
			dot( vec4(myvalue.w, inputadjx.w, inputadjy.w, inputdiag.w), selfWeights)
			);
}
vec2 quadGatherWeighted2D(vec2 myvalue){
		vec2 inputadjx = myvalue - dFdx(myvalue) * quadVector.x;
		vec2 inputadjy = myvalue - dFdy(myvalue) * quadVector.y;
		vec2 inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return vec2(
			dot( vec4(myvalue.x, inputadjx.x, inputadjy.x, inputdiag.x), selfWeights),
			dot( vec4(myvalue.y, inputadjx.y, inputadjy.y, inputdiag.y), selfWeights)
			);
}

vec4 quadGatherSortFloat(vec4 unsorted){ // this could really use modification into a threadmask matrix!
	vec4 threadMask =  step(vec4(quadVector.xy,0,0),vec4( 0,0,quadVector.xy));
	vec4 sorted = vec4(0.0);
	sorted.r = dot(unsorted.xyzw, threadMask);
	sorted.g = dot(unsorted.yxwz, threadMask);
	sorted.b = dot(unsorted.zwxy, threadMask);
	sorted.a = dot(unsorted.wzyx, threadMask);
	return sorted;
}

vec4 debugQuad(vec2 qv){
	// Returns a checkerboard pattern of quads. Yay?
	// B R
	// G Y
	vec2 sharedCoords = quadGatherSum2D(gl_FragCoord.xy);
	float quadAlpha = 0.0;
	if (fract((sharedCoords.x + sharedCoords.y) * 0.2) > 0.25) quadAlpha = 1.0;
	vec3 QVC = vec3(// [[BR],[GY]]
		step(0, qv.x), // red if x positive
		step(qv.y, 0), // Green if y negative
		step(qv.x, 0) * step(0, qv.y)    // blue if x negative and y positive
	);
	//if (step(0, qv.x) * step(qv.y, 0) > 0 ){
	//	
	//}
	return vec4(QVC,quadAlpha);
}



// Use this to sample 4 octaves on any noise you want, and return the sum of its octaves
float fastQuadFBM3D(vec3 Pos, vec4 frequencies, vec4 weights, vec2 screenCoords){
	vec2 quad_vector = fract(floor(screenCoords) * 0.5) * 4.0 - 1.0;
	vec4 threadMask = quadGetThreadMask(quad_vector);
	
	float noise = FBMNoise3D(Pos * dot(threadMask, frequencies)) * dot(threadMask, weights);
	return dot(vec4(1.0),  quadGather(noise, quad_vector));
}

// Fast single channel texture lookup
float fastQuadTexture3DLookupSum(sampler3D ttt, vec3 Pos, vec3 stepsize, vec4 weights, vec2 screenCoords){ 
	vec2 quad_vector = fract(floor(screenCoords) * 0.5) * 4.0 - 1.0;
	vec4 threadMask =  quadGetThreadMask(quad_vector);
	vec4 offsets = vec4(0,0.25,0.5, 0.75);
	
	float noise = texture(ttt, Pos + stepsize * dot(threadMask, offsets)).r * dot(threadMask, weights);
	return dot(vec4(1.0), quadGather(noise, quad_vector));
}

// Fast single channel texture lookup
float fastQuadTexture2DLookupSum(sampler2D t, vec2 Pos, vec2 stepsize, vec4 weights, vec2 screenCoords){ 
	vec2 quad_vector = fract(floor(screenCoords) * 0.5) * 4.0 - 1.0;
	vec4 threadMask =  quadGetThreadMask(quad_vector);
	vec4 offsets = vec4(0,0.25,0.5, 0.75);
	
	float noise = texture(t,Pos + stepsize * dot(threadMask, offsets)).r * dot(threadMask, weights);
	return dot(quadGather(noise, quad_vector), vec4(1.0));
}

// Fast single channel texture lookup
float fastQuadTexture2DLookupInd(sampler2D t, vec2 Pos, vec2 stepsize, vec4 weights, vec2 screenCoords){ 
	vec2 quad_vector = fract(floor(screenCoords) * 0.5) * 4.0 - 1.0;
	vec4 threadMask =  quadGetThreadMask(quad_vector);
	vec4 offsets = vec4(0,0.25,0.5, 0.75);
	
	float noise = texture(t,Pos + stepsize * dot(threadMask, offsets)).r * dot(threadMask, weights);
	return dot( quadGather(noise, quad_vector), vec4(1.0));
}
#endif



////-----------------------------STATIC DEFINES-----------------
// These defines were empirically determined to be the kind that its not worth touching

#define BLUENOISESTRENGTH 1.1
#define NOISESKEW vec3(0.21, 0.32, 0.26)
//#define NOISESKEW vec3(0.0, 0.1, 0.0)
#define NOISESCALE1024 NOISESCALE/1024.0

#define FASTSMOOTHSTEP(A) (A * A * (3.0 - 2.0 * A))
// HIGHFREQUENCY UNIFORM NOISE PARAMS
// noiseHFParams perturbation stuff
// this is uniform 16x16x16 noise, pretty fast
// x - relative scale (FROM NOISE)
// y - perturb strength
// z - offset speedx, as a fraction of base speed
// w - offset speedy, as a fraction of base speed

// LOWFREQUENCY WORLEY NOISE PARAMS
// x - scale
// y - threshold

// Oooh cool mie func: https://research.nvidia.com/labs/rtr/approximate-mie/
// bitsquid.blogspot.com/2016/07/volumetric-clouds.html
// https://advances.realtimerendering.com/s2015/The%20Real-time%20Volumetric%20Cloudscapes%20of%20Horizon%20-%20Zero%20Dawn%20-%20ARTR.pdf
// https://www.scratchapixel.com/lessons/3d-basic-rendering/volume-rendering-for-developers/intro-volume-rendering.html
//https://www.scratchapixel.com/lessons/3d-basic-rendering/volume-rendering-for-developers/ray-marching-algorithm.html
//https://pbr-book.org/3ed-2018/contents



////------------------------------GLOBAL NOISE SAMPLING FUNCTIONS ---------------------------------

// static vars:
vec3 noiseOffset;
// everything that has to do with initializing the actual noise stuff 
vec2 initNoise(){
	return vec2(0,0);
}

vec2 hfnoisesampler(){
	return vec2(0,0);
}

vec2 sampleWorldNoise(){
	return vec2(0,0);
}

void WorldToNoiseSpace(in vec3 wp, out vec3 lf, out vec3 hf){
	lf = wp * NOISESCALE1024 * noiseLFParams.x;
	hf = lf * noiseHFParams.x * 10;
	hf -= hf.zxx * NOISESKEW;
	hf.xz += noiseOffset.xz * noiseHFParams.zw * 1;
	hf -= noiseOffset.xyz;

	lf += lf.zxx * NOISESKEW * 1.0;
	lf -= noiseOffset.xyz;
}

vec4 SampleNoiseSpace(in vec3 noiseLFSpacePos, in vec3 noiseHFSpacePos, in float perturbfactor){

	vec4 highFreqNoise = textureLod(uniformNoiseTex, noiseHFSpacePos,0);
	//vec4 highFreqNoise =  texture(uniformNoiseTex, noiseHFSpacePos);
	
	highFreqNoise.rgb = highFreqNoise.rgb * 0.5 - 0.25; // scale down to [-0.25, 0.25]
	highFreqNoise *= (highFreqNoise.a) * perturbfactor; // Further modulate with own alpha channel
	
	noiseLFSpacePos += highFreqNoise.rgb * noiseHFParams.y;
	
	vec4 textureNoise = vec4(0.0);

	#if (TEXTURESAMPLER == 1)
		textureNoise = getPackedNoise(noiseLFSpacePos); 
	#endif
	#if (TEXTURESAMPLER == 2)
		textureNoise = texture(noise64cube, noiseLFSpacePos.xzy).argb; // almost universally the best :'( 
	#endif
	#if (TEXTURESAMPLER == 3)
		textureNoise = 1.0 - Cellular3D_Deriv(noiseLFSpacePos.xzy).rgba; // almost universally the best :'( 
	#endif
	#if (TEXTURESAMPLER == 4)
		//textureNoise = 1.0 - noiseLFSpacePos.xzy;
		vec3 centers = fract(noiseLFSpacePos.xyz) - 0.5;
		float disttocenter = max(0, 1.0 - sqrt(dot (centers, centers)));
		textureNoise = vec4(step(0.6,disttocenter),disttocenter,disttocenter,disttocenter);
	#endif
	
	#if (QUADNOISEFETCHING == 1) // this sure as FUCK does not need to be done here!
		//textureNoise.r = quadGatherWeighted(textureNoise.r);
		//textureNoise.g = quadGatherWeighted(textureNoise.g);
	#endif

	return textureNoise.xyzw;
}


float expImpulse( float x, float k )
{
    float h = k*x;
    return h*exp(1.0-h);
}


float expSustainedImpulse( float x, float f, float k )
{
    float s = max(x-f,0.0);
    return min( x*x/(f*f), 1.0+(2.0/f)*s*exp(-k*s));
}

float BeersLaw(float d,float k){
	return exp(-1*k*d);
}

float PowderLaw(float d, float k){
	return 1.0 - exp(-2*k*d);
}

float BeersPowder(float d, float k){
	return BeersLaw(d,k) * PowderLaw(d,k);
}

//https://github.com/erickTornero/realtime-volumetric-cloudscapes/blob/master/shaders/RayMarching2.glsl

float HenyeyGreenstein(in vec3 inLightVector, in vec3 inViewVector, in float g){
    // Cos of angle
    float cos_angle = dot(normalize(inLightVector), normalize(inViewVector));

    // Define the HenyeyGreenstein function
    return (1.0 - g * g)/(pow(1.0 + g * g - 2.0 * g * cos_angle, 1.50) * 4 * 3.14159265);
}

// ** Define the total energy 
float GetLightEnergy(float density, float probRain, float henyeyGreensteinFactor){
    float beer_laws = exp( -density * probRain);
    float powdered_sugar = 1.0 - exp( -2.0 * density);

    //float henyeyGreensteinFactor = HenyeyGreenstein(lightVector, rayDirection, g);
    float totalEnergy = 2.0 * beer_laws * powdered_sugar * henyeyGreensteinFactor;

    return totalEnergy;
}

//https://encreative.blogspot.com/2019/05/forward-and-backward-alpha-blending-for.html 

// remember that accumulatedColor.a is (1.0 - alpha)
void BackwardBlend(inout vec4 accumulatedColor, in vec4 currentColor){
	accumulatedColor.rgb += accumulatedColor.rgb * (accumulatedColor.a * currentColor.a);
	accumulatedColor.a *= (1.0 - currentColor.a);
}
//------------------------------------

vec4 WorldToShadowSpace(vec3 worldPos){
		vec4 shadowVertexPos = shadowView * vec4(worldPos,1.0);
		shadowVertexPos.xy += vec2(0.5);
		return shadowVertexPos;
		//return clamp(textureProj(shadowTex, shadowVertexPos), 0.0, 1.0);
}

////----------------------------------------------------------------
////------------------------------MAIN------------------------------
////----------------------------------------------------------------

#line 33000
void main(void)
{

	float time = timeInfo.x + timeInfo.w;
	vec3 camPos = cameraViewInv[3].xyz ;
	
	// ----------------- BEGIN UNIVERSAL PART ------------------------------ 
	#if 1 
	#line 33200
	quadVector = quadGetQuadVector(gl_FragCoord.xy);

	//fragColor.rgba = debugQuad(quadVector);return;
	// Note that the offsets are not in ascending order. This has the fun side effect of being bluer in noise
	float thisQuadOffset = dot (quadGetThreadMask(quadVector), vec4(0.5, 0.25, 0.0, 0.75)); 

	// ---------- Calculate the UV coordinates of the depth textures ---------
  
	#if (RESOLUTION == 2)
		// Exploit hardware linear sampling in best case
		vec2 screenUV = sampleUVs.zw;
		// The following clamp is needed cause the UV's of gbuffers arent clamped for some reason
		screenUV = clamp(screenUV, vec2(0.5/VSX, 0.5/VSY), vec2(1.0 - 0.5/VSY,1.0 - 0.5/VSY));
	#else
		vec2 screenUV = gl_FragCoord.xy * RESOLUTION / viewGeometry.xy;
	#endif



	// clamp the UV's of deferred buffer fetches as they are not edge repeats.
	//screenUV = clamp(screenUV, vec2(0.5/VSX, 0.5/VSY), vec2(1.0) - vec2(0.5/VSX, 0.5/VSY));

	// Sample the depth buffers, and choose whichever is closer to the screen (TexelFetch is no better in perf)
	float mapdepth = texture(mapDepths, screenUV).x; 
	float modeldepth = texture(modelDepths, screenUV).x;

	#if 0
		// This is the debugging yellow row that should be present in bottom left
		if (any(lessThan(abs(gl_FragCoord.xy - 2.5) ,vec2( 0.5)))) {
			fragColor.rgba = vec4(1,1,0,1); return;
		}
		// This is the debug grid
		if (any(lessThan(fract(gl_FragCoord.xy / 64.0) ,vec2( 1.0/64.0)))) {
			fragColor.rgba = vec4(0,step( modeldepth, 0.9999),0,1); return;
		}
	#endif
	mapdepth = min(mapdepth, modeldepth);


	// Transform screen-space depth to world-space position
	vec4 mapWorldPos =  vec4( vec3(screenUV.xy * 2.0 - 1.0, mapdepth),  1.0);
	mapWorldPos = cameraViewProjInv * mapWorldPos;
	mapWorldPos.xyz = mapWorldPos.xyz / mapWorldPos.w; // YAAAY this works!

	vec3 trueMapWorldPos = mapWorldPos.xyz;
	
	// if mapworldpos is below 0, then pull it back to waterlevel
	vec3 mapFromCam = mapWorldPos.xyz - camPos;
	if (mapWorldPos.y < 0){
		float abovewaterfraction = camPos.y / abs(mapFromCam.y);
		mapWorldPos.xyz = (mapFromCam.xyz * abovewaterfraction) + camPos;
	}
	#endif 
	
	// rayStart is the distant point through fog 
	vec3 rayStart = mapWorldPos.xyz; 
	// rayEnd is the close point through fog
	vec3 rayEnd = camPos; 
	mapFromCam = mapWorldPos.xyz - camPos; // readjust this
	
	float lengthMapFromCam = length(mapFromCam);
	
	vec4 blueNoiseSample = textureLod(blueNoise64,gl_FragCoord.xy/64, 0) *BLUENOISESTRENGTH;
	
	
	float noiseScale = NOISESCALE;
	//time = fract(time/16384) * 16384; 
	// this must be moved to lua side
	// we must ensure that this is rolled over, especially the time part at units of 1
	noiseOffset = vec3(windFractFull.x,  time * RISERATE, windFractFull.y ) * NOISESCALE1024;
	noiseOffset.y = fract(noiseOffset.y); // time can only be rolled over here

	// ----------------- END UNIVERSAL PART -------------------------------
	
	// ----------------- BEGIN DISTANCE-BASED FOG ------------------------------
		#line 33400
		// calculate the distance fog density
		float distanceFogAmount = lengthMapFromCam;
		
		// Modulate distance fog density with angle of ray compared to sky?
		vec3 camToMapNorm = mapFromCam / lengthMapFromCam;
		float rayUpness = 1.0;
		if (camToMapNorm.y > 0) {
			rayUpness = pow(1.0 - camToMapNorm.y, 8.0);
			distanceFogAmount *= rayUpness;
		}
		float distanceFogAmountExp = exp(-1 * distanceFogAmount * 0.0005 * distanceFogColor.a);
		// power easing distance fog
		distanceFogAmountExp =  pow(1.0 - distanceFogAmountExp, EASEGLOBAL);
		//fragColor.rgba = vec4(distanceFogColor.rgb, distanceFogAmountExp);	return; // OUTPUT DISTANCE-BASED FOG
	// ----------------- END DISTANCE-BASED FOG ------------------------------
	
	
	// ----------------- BEGIN HEIGHT-BASED FOG -------------------------------
	#line 33600
	vec4 heightBasedFogColor = vec4(0);
	// If raystart is above the fog plane height
	if (mapWorldPos.y > heightFogTop) {
		if (camPos.y < heightFogTop) { // But cam is below fog (C)
			float rayFractionInFog = clamp((heightFogTop - camPos.y)/(mapWorldPos.y - camPos.y), 0, 1);
			rayStart = rayEnd * (1.0 - rayFractionInFog) + rayStart * rayFractionInFog; // pull back rayStart to heightFogTop
		}else{ // Cam and Ray both above fog
			rayStart = rayEnd;
		}
	}else{ // Ray starts below fog plane
		if (camPos.y > heightFogTop) { // Camera is Above fog (A) 
			float rayFractionInFog = clamp((heightFogTop - mapWorldPos.y)/(camPos.y - mapWorldPos.y), 0, 1);
			rayEnd = rayStart + (rayEnd - rayStart) * rayFractionInFog; // pull back 
		}
	}

	float rayLength = length(rayEnd - rayStart);

	// Average the distance to the center of the ray?
	//vec2 avgDistanceMapEdge = linearDistanceMapXZ((rayEnd.xz + rayStart.xz) * 0.5 ) ;
	float edgeDistanceWeight = linearDistanceMapXZThreshold((rayEnd.xz + rayStart.xz) * 0.5, max(MAPSIZEX, MAPSIZEZ) * 0.25);
	//sqrt(dot(avgDistanceMapEdge,avgDistanceMapEdge)); //
	//edgeDistanceWeight = (max(MAPSIZEX, MAPSIZEZ) * 0.25 - edgeDistanceWeight) / (max(MAPSIZEX, MAPSIZEZ) * 0.25);
	if (edgeDistanceWeight <= 0 ) rayLength = 0.0;
	//fragColor.rgba = vec4(vec3(edgeDistanceWeight), 1.0); return;
	
	float heightBasedFog = 0;
	float heightShadow = 1; // What fraction of samples were LIT along the way.
	
	float densityModulation = 1.0;
	// ----------------- BEGIN HEIGHT-BASED FOG AND SHADOWING -------------------------------
	#line 33700
	#if (HEIGHTSHADOWSTEPS > 0) || (HEIGHTNOISESTEPS > 0)
		float inmapness = 0;// max( linearDistanceMap(rayEnd), linearDistanceMap(rayStart));
		//fragColor.rgba = vec4(vec3( fract(inmapness * 0.01)),1.0);
		//return;
		if (quadGatherSumFloat(rayLength) > 0.01 && inmapness < 512.0) {

			#if (HEIGHTSHADOWSTEPS > 0)
				// Ray Coords for shadow-space
				vec4 heightShadowStartPos = WorldToShadowSpace(rayStart); // The more distant position
				vec4 heightShadowEndStep   = WorldToShadowSpace(rayEnd); // The position closer to camera
				heightShadowEndStep  = ( heightShadowEndStep- heightShadowStartPos) / HEIGHTSHADOWSTEPS; // points toward camera
				heightShadowStartPos +=  heightShadowEndStep * (thisQuadOffset + blueNoiseSample.r * 0.25); // Give it some jitter for smoothing
			
				heightShadow = 0;
				for (uint i = 0; i < HEIGHTSHADOWSTEPS; i++){
					heightShadow += textureProj(shadowTex, heightShadowStartPos, -2).r; // 1 for lit, 0 
					//heightShadow += 1 ;
					heightShadowStartPos += heightShadowEndStep;
				}
				heightShadow =  quadGatherWeighted(heightShadow);

				heightShadow /= HEIGHTSHADOWSTEPS;
			#endif
			
			// TODO: add correct wind
			#if HEIGHTNOISESTEPS > 0
				// Ray Coords for noise-space
				vec3 noiseOffset2 = vec3(windFractFull.z, time * RISERATE, windFractFull.w) *  5.0 ; // This must be an integer multiplier!
				//noiseOffset2.y = fract(noiseOffset2.y); // time can only be rolled over here

				vec3 heightFogRayStep = (rayEnd - rayStart) / HEIGHTNOISESTEPS;
				vec3 heightFogRayStart = (quadGatherSum3D(rayStart) * 0.33) + (thisQuadOffset + blueNoiseSample.r * (HEIGHTNOISESTEPS / 64 )) * heightFogRayStep; // Pull back the start with blue noise
				
				float stepSize = rayLength / HEIGHTNOISESTEPS;
				float myfreq = (thisQuadOffset + 0.1);
				densityModulation = 0.0;
				for (uint i = 0; i < HEIGHTNOISESTEPS; i++){
					vec3 lfnoisepos = (heightFogRayStart *  0.1 - noiseOffset2.xyz * 0.01  ) *NOISESCALE  ;
					//lfnoisepos += lfnoisepos.zzx * NOISESKEW;
					//lfnoisepos.y = 0;
					float cloudy = 1.0;
					//myfreq = 0.1;
					//cloudy =  texture(noise64cube, 0.06* lfnoisepos.zxy * vec3(1,1,4)).r;
					//cloudy =  texture(uniformNoiseTex, 0.06* lfnoisepos.zxy * vec3(1,1,4)).r;
					//cloudy =  FBMNoise3DXF(lfnoisepos.xyz * vec3(1,1,1)) * 4 ;
					cloudy = Value3D(lfnoisepos.xyz * vec3(1,1,1)*myfreq) /myfreq ;
					//cloudy = abs(0.5 +  Value3D_Deriv(lfnoisepos.yxz * vec3(1,1,1)*myfreq).a) /myfreq ;
					//cloudy = dot(FBMNoise3D_rg( lfnoisepos.xyz * vec3(1,1,1)), vec2(0.5));
					//cloudy = dot(FBMNoise3D_rgba( lfnoisepos.xyz * vec3(1,1,1)), vec4(0.25));
					
					densityModulation +=  cloudy ;
					heightFogRayStart += heightFogRayStep;
				}
				
				densityModulation = quadGatherSumFloat(densityModulation);
				densityModulation = densityModulation/(HEIGHTNOISESTEPS);
			#endif

		}
		// Fun idea: since shadow darkness shafts always follow a known sun-based pattern, they could be directionally blurred in combine shader, if draw to a separate render target
	#endif

		// just use the density function of fogtop-fogbottom
		
	float fogPlaneSizeInv = 1.0 / (heightFogTop - heightFogBottom);
	float startDensity = clamp( (heightFogTop - rayStart.y) * fogPlaneSizeInv, 0, 1);
	float endDensity = clamp( (heightFogTop - rayEnd.y) * fogPlaneSizeInv, 0, 1);
	heightBasedFog = (startDensity + endDensity) * 2 * rayLength;
	heightBasedFog *=  densityModulation ;
	
	// A very simple approach to ease height based fog with distance from camera
	heightBasedFog = cloudDensity * heightBasedFog  * smoothstep(0.0,2000.0 * EASEHEIGHT, length(rayStart-camPos));
	
	float heightBasedFogExp = 1.0 - exp( - 1 * heightBasedFog * heightFogColor.a * 0.1);
	heightBasedFogColor.rgb = mix(shadowedColor.rgb, heightFogColor.rgb, heightShadow);
	heightBasedFogColor.a = heightBasedFogExp * edgeDistanceWeight;	
	//Debug shadowing of fog:
	//fragColor.rgba = vec4(vec3(heightShadow),0.9); return;
	// TODO: BLEND ORDER OF HEIGHT-BASED and CLOUD LAYER MUST BE DEPENDENT ON VIEW ANGLE
	//Debug purely height-based fog
	//fragColor.rgba = vec4(heightBasedFogColor.rgba);	return;
	// ----------------- END HEIGHT-BASED FOG AND SHADOWING -------------------------------





	// ----------------- END HEIGHT-BASED FOG -------------------------------
	
	// ----------------- BEGIN UNDERWATER SHADOW RAYS -------------------------------
	#line 33800

	vec4 uwShadowRays = vec4(0,0,0,0);
	#if UNDERWATERSHADOWSTEPS > 0
		if (rayLength > 0.01 && trueMapWorldPos.y < 0) {
			// Draw these back to front
			// Each shadow sample costs on average, 0.5 FPS at 1080p and half resolution
			// Indeed, stepping in shadow space is much faster, and possible due to the linear transformation of it. 
			// Now to also handle clipping within shadow space as not to get out of hand!
			// NEEDS SHADOWSAMPLER == 1 
			vec4 shadStart = WorldToShadowSpace(trueMapWorldPos); 
			vec4 shadEnd   = WorldToShadowSpace(mapWorldPos.xyz);
			vec4 shadStep  = (shadEnd - shadStart) / UNDERWATERSHADOWSTEPS; // points toward camera

			shadStart += (thisQuadOffset + blueNoiseSample.r * 0.25) * shadStep;

			for (uint i = 0; i < UNDERWATERSHADOWSTEPS ; i++){
				uwShadowRays.w += textureProj(shadowTex, shadStart, -2).r; // 1 for lit, 0 
				shadStart += shadStep;
			}
			// This was Floris's idea, to add a bit of additional surface shadow
			float lastunderwatershadow = quadGatherWeighted(textureProj(shadowTex, shadEnd, -2).r);
			// Special sauce PQM
			uwShadowRays.w = quadGatherWeighted(uwShadowRays.w);
			// Discount by # rays
			uwShadowRays.w /= UNDERWATERSHADOWSTEPS;
			// half it a little bit:
			uwShadowRays.a = (1.0 - uwShadowRays.w) ;
			// This was Floris's idea, to add a bit of additional surface shadow
			uwShadowRays.a += 0.3 * (1.0 - lastunderwatershadow);
			// modulate density up to shallowdepth:
			uwShadowRays.a *= smoothstep(0, 20, -1 * trueMapWorldPos.y);
			uwShadowRays.a = clamp(uwShadowRays.a, 0, 1) * shadowedColor.a;
		}
		// Debug underwater shadow rays:
		//fragColor.rgba = vec4(vec3(uwShadowRays.rgb),uwShadowRays.a * 2); return;	
	#endif
	// ----------------- END UNDERWATER SHADOW RAYS -------------------------------

	
	// ----------------- BEGIN CLOUD LAYER -------------------------------
	#line 34000
	// Start by calculating the absolute, mapdepth scaled ray start and ray end factors

	vec4 cloudBlendRGBT = vec4(0,0,0, 0); // Zero color, and Transparency of 1

	#if (CLOUDSTEPS > 0)
	vec3 cloudRayDir = camToMapNorm;
	vec3 cloudRayDirInv = 1.0 / camToMapNorm;
	
	// take the ray start, and clamp it to the most distant of all 
	
	vec3 cloudBoxSize = (cloudVolumeMax.xyz - cloudVolumeMin.xyz ) * 0.5 + vec3(cloudVolumeMax.w, 0, cloudVolumeMax.w) * 1;
	vec3 cloudBoxCenter = (cloudVolumeMax.xyz + cloudVolumeMin.xyz) * 0.5;
	
	vec3 rayOriginInbox = camPos - cloudBoxCenter;
	
	vec3 rayNormal = cloudRayDirInv * rayOriginInbox;
	vec3 k = abs(cloudRayDirInv) * cloudBoxSize;
	vec3 t1 = -rayNormal - k;
	vec3 t2 = -rayNormal + k;
	
	float nearDist = max( max( t1.x, t1.y ), t1.z );
	float farDist  = min( min( t2.x, t2.y ), t2.z );
	
	vec3 cloudRayEnd   = camPos + nearDist * cloudRayDir; // Near point
	vec3 cloudRayStart = camPos + farDist  * cloudRayDir; // Far Point

	lengthMapFromCam = length(camPos - mapWorldPos.xyz);
	if (farDist > lengthMapFromCam) cloudRayStart = mapWorldPos.xyz; // map is closer than back of cloud box
	if (nearDist < 0) cloudRayEnd = camPos; // we are in the box
	if (nearDist > lengthMapFromCam) cloudRayEnd = mapWorldPos.xyz; // the map is closer than the front of the cloud box
	
	if (step(nearDist, farDist) * step(0.0,farDist) < 0.5) cloudRayStart = cloudRayEnd; // cant remember what clipping this solves
	/*
	float cloudEdgeDistanceWeight = dot(max(vec3(0),vec3( 
		CloudVoumeWeight((cloudRayStart.xz + cloudRayEnd.xz) * 0.5),
		CloudVoumeWeight((cloudRayStart.xz ) ),
		CloudVoumeWeight((cloudRayEnd.xz) ))),
		vec3(0.33))	;
	*/

	float cloudEdgeDistanceWeight =	CloudVoumeWeight((cloudRayStart.xz + cloudRayEnd.xz) * 0.5);
	//vec3 rayStartFromBox = abs(cloudRayEnd - cloudBoxCenter) - cloudBoxSize;
	//float rayStartDistFromBox = length(max(rayStartFromBox,0.0)) + min(max(cloudBoxSize.x,max(cloudBoxSize.y,cloudBoxSize.z)),0.0);
	//fragColor.rgba = vec4 (fract((cloudRayEnd + 0.5) /1024), step(nearDist, farDist) * step(0.0,farDist));
	//fragColor.rgba = vec4 (fract((vec3(cloudRayStart) + 0.5) /256), step(nearDist, farDist) * step(0.0,farDist));
	//fragColor.rgba = vec4(fract((cloudRayStart - cloudRayEnd) + 0.5) /1024, length(cloudRayStart - cloudRayEnd) * 0.1); return;
	
	float cloudRayLength = length(cloudRayStart-cloudRayEnd);
	if (cloudEdgeDistanceWeight <= 0) cloudRayLength = 0;

	if (cloudRayLength > 0 ){
		vec3 cloudRayStep = (cloudRayEnd - cloudRayStart) / CLOUDSTEPS; // Points towards camera
		float stepLength = cloudRayLength/CLOUDSTEPS; 

		vec3 quadStep = cloudRayStep * (thisQuadOffset + ( CLOUDSTEPS / 128) * blueNoiseSample.g); 

		float fogHeightInv  = 1.0/(cloudVolumeMax.y - cloudVolumeMin.y); 
		float heightFractionStartPos = clamp( (cloudRayStart.y  - cloudVolumeMin.y) *fogHeightInv,0,1); // starts at 0.0 at bottom
		float heightFractionEndStep   = clamp( (cloudRayEnd.y    - cloudVolumeMin.y) *fogHeightInv,0,1); // ends a 1.0 at top
		heightFractionEndStep = ( heightFractionEndStep - heightFractionStartPos) / CLOUDSTEPS; 
		// Todo: There could be use in adaptively stepping more frequently through denser regions of the clouds
		
		#if (QUADNOISEFETCHING == 1)
			cloudRayStart += quadStep;
			cloudRayEnd += quadStep;
		#else
			cloudRayStart += cloudRayStep  * blueNoiseSample.g * BLUENOISESTRENGTH;
			cloudRayEnd += cloudRayStep  * blueNoiseSample.g * BLUENOISESTRENGTH;
		#endif
		
		
		vec3 noiseLFStart;
		vec3 noiseLFEndStep;
		vec3 noiseHFStart;
		vec3 noiseHFEndStep;
		
		WorldToNoiseSpace(cloudRayStart, noiseLFStart, noiseHFStart); // near point
		WorldToNoiseSpace(cloudRayEnd, noiseLFEndStep, noiseHFEndStep); // far point
		
		noiseLFEndStep = (noiseLFEndStep - noiseLFStart) / CLOUDSTEPS;
		noiseHFEndStep = (noiseHFEndStep - noiseHFStart) / CLOUDSTEPS;

		#line 36300
		float prevdensity = 0.0;
		cloudBlendRGBT.rgb +=  cloudGlobalColor.rgb;

	
		for (uint ns = 0; ns < CLOUDSTEPS; ns++){ // We march backwards, from furthest to closest
			// A rule of thumb: Each line here, at 16 samples costs 1 fps, texture lookups cost 5 fps 
			//float heightFraction = clamp( ((cloudRayStart.y + cloudRayStep.y *  rayIndexFloat ) - cloudVolumeMin.y) *fogHeightInv,0,1); // 1 at the top of fog, 0 at the bottom
			float perturbmod = 1;//(1.0 - heightFractionStartPos) *  (1.0 - heightFractionStartPos) * 1;
			heightFractionStartPos += heightFractionEndStep;
	
			vec4 textureNoise = SampleNoiseSpace(noiseLFStart, noiseHFStart,  perturbmod);
			noiseHFStart += noiseHFEndStep;
			noiseLFStart += noiseLFEndStep;

			float clampedNoise = max(0, (textureNoise.r  - noiseLFParams.y) * cloudDensity * ( 1.0 - heightFractionStartPos) * stepLength) * 1.0;
			//cloudBlendRGBT.w += clampedNoise; // FUCKING KEEP THIS!
			
			// Try a gradient based approach to density
			// for now, quickly assume we go over top
			float currdens =  clampedNoise ;
			cloudBlendRGBT.w += currdens;
			
			currdens /= stepLength;
			float gradient_density = currdens - prevdensity ; // positive if increasing
			prevdensity = currdens;
			gradient_density *= 10;
			gradient_density -= gradient_density * step(0,gradient_density) * 10.5; 
			cloudBlendRGBT.rgb = mix (cloudBlendRGBT.rgb, vec3(0.0),gradient_density * 0.05 );
			
		}
	}
	cloudBlendRGBT.a  = quadGatherWeighted(1.0 - exp(-1 * cloudBlendRGBT.w ))* cloudGlobalColor.a;
	cloudBlendRGBT.a *= cloudEdgeDistanceWeight;
	#endif
	// ----------------- BEGIN CLOUD SHADOWS -------------------------------

		#line 38000
		vec4 cloudShadowColor = vec4(0);
		#if (CLOUDSHADOWS > 0 )

		if (mapdepth < 0.9998 ){ // No cloud shadows on distant areas
				// TODO: also clip to within cloudvolume
					
				// this was used to prevent secondary shadowing, might want to think about it...
				//float shadowRayStart = shadowAtWorldPos(rayStart + sunDir.xyz * 1); 
				
				vec3 cloudShadowRayGroundPos = trueMapWorldPos.xyz;

				// adjust rayEnd to point from rayStart to the sun direction!
				// the pos at which the vector in sun dir intercepts fog plane

				//
				float cloudBottomDistanceMultiplier = (cloudVolumeMin.y - cloudShadowRayGroundPos.y) / sunDir.y;
				vec3 cloudShadowRayStartPos = cloudShadowRayGroundPos + sunDir.xyz * cloudBottomDistanceMultiplier;

				float cloudTopDistanceMultiplier = (cloudVolumeMax.y - cloudShadowRayGroundPos.y) / sunDir.y;
				vec3 cloudShadowRayEndStep = cloudShadowRayGroundPos + sunDir.xyz * cloudTopDistanceMultiplier;
				
				float cloudShadowEdgeDistanceWeight = CloudVoumeWeight((cloudShadowRayStartPos.xz + cloudShadowRayEndStep.xz) * 0.5);

				if (cloudShadowEdgeDistanceWeight > 0){

				float stepLength = length(cloudShadowRayStartPos-cloudShadowRayEndStep)/CLOUDSHADOWS; 

				

				vec3 noiseLFStart;
				vec3 noiseLFEndStep;
				vec3 noiseHFStart;
				vec3 noiseHFEndStep;
				
				WorldToNoiseSpace(cloudShadowRayStartPos, noiseLFStart, noiseHFStart); // near point
				WorldToNoiseSpace(cloudShadowRayEndStep, noiseLFEndStep, noiseHFEndStep); // far point
				
				noiseLFEndStep = (noiseLFEndStep - noiseLFStart) / CLOUDSHADOWS;
				noiseHFEndStep = (noiseHFEndStep - noiseHFStart) / CLOUDSHADOWS;

				noiseLFStart.xyz += noiseLFEndStep *( thisQuadOffset + 0.25 * blueNoiseSample.r ) ;
			


				for (uint i = 0; i < CLOUDSHADOWS; i++){
					float perturbmod = 1.0;
					vec4 textureNoise = SampleNoiseSpace(noiseLFStart, noiseHFStart,  perturbmod);
					noiseHFStart += noiseHFEndStep;
					noiseLFStart += noiseLFEndStep;

					float clampedNoise = max(0, (textureNoise.r  - noiseLFParams.y) * cloudDensity * stepLength);
					cloudShadowColor.w += clampedNoise;
				}
				cloudShadowColor.w = quadGatherWeighted(cloudShadowColor.w);
				cloudShadowColor.w *=cloudShadowEdgeDistanceWeight;
				}
			}
		cloudShadowColor.w = (1.0 - exp(-1 * cloudShadowColor.w ) ) * shadowedColor.a * cloudGlobalColor.a;
		#endif
		//fragColor = vec4(step(0.5,threadMask.rga), 1.0);return;
		//fragColor.rgba = vec4(vec3(1.0 - cloudShadowColor.w), 0.95); return;
		


	// ----------------- END CLOUD SHADOWS -------------------------------
	
	// ----------------- BEGIN CHROMA SHIFTING /SCATTERING ---------------------
	// ----------------- END CHROMA SHIFTING /SCATTERING ---------------------

	// ----------------- BEGIN COMPOSITING ---------------------
	vec4 outColor = vec4(0.0);
	// 1. Blend uwShadowRays.rgba
	outColor.a = outColor.a = 1.0 -  (1.0 - outColor.a) * (1.0 - uwShadowRays.a);

	outColor.rgb = outColor.rgb * (1.0 - uwShadowRays.a) + shadowedColor.rgb * uwShadowRays.a;

	// 2. Blend cloudShadowColor.rgba
	outColor.a = outColor.a = 1.0 -  (1.0 - outColor.a) * (1.0 - cloudShadowColor.a);
	outColor.rgb = outColor.rgb * (1.0 - cloudShadowColor.a) + shadowedColor.rgb * cloudShadowColor.a;

	// The order here has to be dependent on which is first!
	if ((camToMapNorm.y > 0) && (mapWorldPos.y > heightFogTop)){
		
	// 4. Blend cloudBlendRGBT.rgba
	outColor.rgb = mix(outColor.rgb, cloudBlendRGBT.rgb, cloudBlendRGBT.a);
	outColor.a = 1.0 -  (1.0 - outColor.a) * (1.0 - cloudBlendRGBT.a);
	// 3. Blend heightBasedFogColor.rgba
	float newalpha =  1.0 -  (1.0 - outColor.a) * (1.0 - heightBasedFogColor.a);
	outColor.rgb = mix(outColor.rgb, heightBasedFogColor.rgb,heightBasedFogColor.a - outColor.a * outColor.a);
	outColor.a = newalpha;

	}else{
	// 3. Blend heightBasedFogColor.rgba
	float newalpha =  1.0 -  (1.0 - outColor.a) * (1.0 - heightBasedFogColor.a);
	outColor.rgb = mix(outColor.rgb, heightBasedFogColor.rgb,heightBasedFogColor.a - outColor.a * outColor.a);
	outColor.a = newalpha;

	// 4. Blend cloudBlendRGBT.rgba
	outColor.rgb = mix(outColor.rgb, cloudBlendRGBT.rgb, cloudBlendRGBT.a);
	outColor.a = 1.0 -  (1.0 - outColor.a) * (1.0 - cloudBlendRGBT.a);

	}

	// 5. Blend distanceFogColor.rgba
	outColor.a = 1.0 -  (1.0 - outColor.a) * (1.0 - distanceFogAmountExp);
	outColor.rgb = mix(outColor.rgb, distanceFogColor.rgb, distanceFogAmountExp);

	//outColor *= 1.5 - outColor.a * 0.5; 


	// Fake Reinhard ToneMapping:
	//vec3 fakerein = outColor.rgb * outColor.a;
	//fakerein = pow((fakerein / (1.0 + dot(vec3(0.2126, 0.7152, 0.0722), fakerein))), vec3(1.0 / 2.2));
	//outColor.rgb = fakerein / outColor.a; 
	
	fragColor = outColor; 
	
	#if (FULLALPHA == 1) 
		fragColor.a = 1.0;
	#endif
	#if (RESOLUTION == 1) // When not using combine shader, we must pre-multiple color with alpha!
		fragColor.rgb *= fragColor.a;
	#endif
	
	//printf(fragColor.rgba);
	return;


	// ----------------- END COMPOSITING   ---------------------

	// -----------------
	// Composite uwShadorRays with cloudBlendRGBT
	fragColor = vec4(0.0);

	// we need to *subtract darken* the uwshadowed bit.
	fragColor.rgb = cloudBlendRGBT.rgb;
	fragColor.rgb -= cloudBlendRGBT.rgb * (sqrt(uwShadowRays.a + cloudShadowColor.a)) *( 1.0 - cloudBlendRGBT.a);
	
	//fragColor.a = clamp( alpha + cloudShadowColor.a * (1.0 - alpha) ,0, 1);
	fragColor.a = clamp( cloudBlendRGBT.a + (uwShadowRays.a + cloudShadowColor.a ) * (1.0 - cloudBlendRGBT.a) ,0, 1);
	

	//fragColor.rgb = cloudBlendRGBT.rgb; * min(1.0, (1.0 - uwShadowRays.a) ) ;
	//fragColor.a = alpha + uwShadowRays.a * (1.0 - alpha);
	
	//fragColor.rgba = vec4(cloudBlendRGBT.rgb, alpha);
	
	//fragColor.rgb *= alpha;
	//fragColor.g = fract(fragColor.g * 10);
	//fragColor.a = alpha;
	//vec4 debugtransp = vec4 (alpha, alpha, alpha, 1.0);
	vec4 debugtransp = vec4 (1,1,1, cloudBlendRGBT.a);
	//fragColor.rgba = debugtransp;
	//fragColor.rgb = cloudColor.rgb;
	//fragColor.rgb *= 2.0;
	//fragColor.a = heightBasedFogExp; 
	//fragColor.a = 1.0 - exp(-1 * myfog * 0.1);
	
	// Blend the UW rays:
	//fragColor.rgb = mix(fragColor.rgb, uwShadowRays.rgb,uwShadowRays.a );

	vec4 dbgQuad = debugQuad(quadVector);
	//fragColor.a *=(1.0 - dbgQuad.b);

	

	return;
	
	fragColor.rgb = fragColor.rgb * debugQuad(quadVector).rgb * 0.5;
	if (step(0, quadVector.x) * step(quadVector.y, 0) > 0 ){
		//fragColor.rgb = vec3(step(modeldepth, mapdepth));
	}
	fragColor.b = step(modeldepth, mapdepth) * 0.75;
	return;
// ********************************* END COMPLETE REWRITE *******************************
// ********************************* END COMPLETE REWRITE *******************************
// ********************************* END COMPLETE REWRITE *******************************

/*	
	// compilation helpers
	float collectedShadow = 0;
	
	float collectedNoise = 0.0;  // total noise we marched through
	
	// TODO: fix warps sampling zero simplex!
	vec2 mymin = min(mapWorldPos.xz,mapSize.xy - mapWorldPos.xz);
	float outofboundsness = min(mymin.x, mymin.y); 
	float inlos = 0;
	vec4 densityposition = vec4(0);
	
	float heightFogTopInv = 1.0 / heightFogTop; 
	
	#if (USELOS == 1)
		inlos = losLevelAtWorldPos( mapWorldPos.xyz);
		bool outofmap = any(lessThan(vec4(mapWorldPos.xz, mapSize.xy),  vec4(0.0, 0.0, mapWorldPos.xz)));
		if (outofmap) inlos = 0;
	#endif 
	
	fragColor.rgba = vec4(fract(rayStart*0.01),1.0);
	//return;
	
	#if (RAYTRACING == 0)
		// With raytracing off, we have a bit more freedom in the height-based fog.
		collectedShadow = 1.0;
		
		// Modulate the noise based on its depth below fogplane, this is 1 at 0 height, and 0 at heightFogTop
		float rayStartDepthRatio = 1.0 - rayStart.y * heightFogTopInv;
		rayStartDepthRatio = clamp(rayStartDepthRatio * HEIGHTDENSITY, 0, 1);
		
		float rayEndDepthRatio = 1.0 - rayEnd.y * heightFogTopInv;
		rayEndDepthRatio = clamp(rayEndDepthRatio * HEIGHTDENSITY, 0, 1);
		
		float rayDepthratio = (rayStartDepthRatio + rayEndDepthRatio) * 0.5;
		
		
		// Fog reaches full density at half depth to waterplane
		heightBasedFog *= rayDepthratio;
		
	#else
		#if 0
		// Always marching from most distant point to closest point
		// =============== For quad message passing: =====================

		
		//fragColor.rgba = vec4(threadMask.rgb,1.0); return;
		//fragColor.rgba = vec4(quadVector.ryx,1.0); return;
		
		mat4 smoothThreadMatrix = quadGetThreadMatrix(0.6);
		
		// This weights own pixels more then neighbours, by a tiny bit.
		float sf = 0.75;//sin(timeInfo.z*0.01) * 0.0;
		//vec4 selfweight = vec4(0.25) + vec4(sf, -sf/3,-sf/3,-sf/3);
		// ==============   End Quad Message Passing ====================
		
		vec4 blueNoiseSample = textureLod(blueNoise64,gl_FragCoord.xy/64, 0);
		float noiseValues[CLOUDSTEPS+1];
		vec4 shadedFogColor = vec4(0);
		noiseValues[0] = 1;
		
		const float stepsInv = 1.0 / HEIGHTSHADOWSTEPS;

		//vec3 noiseOffset = vec3(0, - time*4, 0) * NOISESCALE1024 * WINDSTRENGTH * 0.3;
		float rayJitterOffset = 0;
		
		//manually set packedNoiseLod
		packedNoiseLod = floor(lengthMapFromCam * 0.00003 * noiseLFParams.x);
		
		// in-progress blending
		vec4 groundRGBA = vec4(shadowedColor.rgb, 0);
		
		mat3 rot3 = transpose(mat3(vec3(0.3120517, -0.7351478,  0.6018150), 
						 vec3(0.9490337,  0.2116918, -0.2334984),
						 vec3(0.0442566,  0.6440064,  0.7637389)));
						 
		if (rayLength> 0.1 && inlos < 0.99) { 
			#if 1 //newest method with no interleaving to prevent membus hammering
				// First we walk through the noise samples at each position, with a bit of jitter added 
				fragColor.rgb = blueNoiseSample.rgb;

				rayJitterOffset = rand(screenUV + vec2(time) * 0.0000) * 1.0  ;
				vec3 rayStep = (rayEnd - rayStart) / CLOUDSTEPS;
				float stepLength = rayLength/CLOUDSTEPS;
				
				vec4 quadoffsets = vec4(0,0.25,0.5, 0.75) * 1.0; 
				vec3 quadStep = rayStep * dot(threadMask,quadoffsets);
				
				#if (CLOUDSTEPS > 0)
				float noiseJitterOffset = rayJitterOffset * (1.0 / CLOUDSTEPS);
				for (uint ns = 0; ns < CLOUDSTEPS; ns++){
						vec3 rayPos = rayStart + rayStep * (float(ns) + rayJitterOffset*0.00 );
						
						#if 1
							vec3 noisePos = rot3 * rayPos * NOISESCALE1024 * noiseLFParams.x * 1.0 + noiseOffset; // this sure as fuck aint free!
							//vec4 simplexDeriv = vec4(0.0); // no-op
							//vec4 simplexDeriv = SimplexPerlin3D_Deriv(noisePos);
							//vec4 simplexDeriv = FBMNoise3DDeriv(noisePos + FBMNoise3D((noisePos +  noiseOffset) * 1.42) * 2 );
							//vec4 simplexDeriv = vec4(FBMNoise3D(noisePos));
							//vec4 simplexDeriv = vec4(FBMNoise3D(noisePos)) +  vec4(FBMNoise3D(noisePos+1));
							//vec4 simplexDeriv = FBMNoise3DDeriv(noisePos);
							//vec4 simplexDeriv = vec4(FBMNoise3D(noisePos + FBMNoise3D(noisePos * 1.42) * 2 ));
							//vec4 simplexDeriv = vec4(SimplexPerlin3D(noisePos));
							vec4 freqs = vec4(1.1,3.1,5.1,7.1);
							vec4 weights = 1.0/freqs;
							float fastQuadFBM3Dnoise = FBMNoise3D(0.33*noisePos * dot(threadMask, freqs)) * dot(threadMask, weights);
							//vec4 simplexDeriv = vec4(quadGatherWeighted(fastQuadFBM3Dnoise));
							
							float quadSin = sin(dot(vec4(noisePos.xz,noisePos.xz),threadMask) * dot(freqs,threadMask) * 0.01) * 10;
							//vec4 simplexDeriv =  vec4(quadGatherWeighted(quadSin));
							//float quadFBMNoise2D = FBMNoise2D(noisePos.xz * dot(threadMask, freqs)) * 1;
							
							//vec4 simplexDeriv =  vec4(quadGatherSumFloat(FBMNoise2D(rayPos.xz * dot(threadMask, freqs) * 0.002) * 0.3));  
							//vec4 simplexDeriv =  texture(heightmapTex, (rayPos.xz * 0.0002) * 0.01);  
							vec4 simplexDeriv =  texture(uniformNoiseTex, (rayPos.xyz * 0.0002 * noiseHFParams.x)) * (0.01+noiseLFParams.y);  
							//vec4 simplexDeriv =  vec4(FBMNoise2D(rayPos.xz *0.01)) * 0.1;  
							
							//vec4 simplexDeriv = quadFBM(noisePos* noiseLFParams.y, freqs, screenUV, gl_FragCoord.xy*2);
							//simplexDeriv = vec4(0.0);
							fragColor.rgba = vec4(simplexDeriv.rgb, 1.0);
							//return;
							vec3 qfbm = simplexDeriv.rgb;// *noiseLFParams.y;
							fragColor.rgba = vec4(simplexDeriv.rgb,1.0);
							//return ;
							float simplexnoise = simplexDeriv.r;
							//densityposition.xzy += simplexDeriv.yzw;// * simplexDeriv.x;
							//float simplexnoise =  SimplexPerlin3D(rayPos * NOISESCALE1024 * noiseLFParams.x * 1.0 + noiseOffset); // range [-1;1]
							//float simplexnoise =  SimplexPerlin3D(rayPos * NOISESCALE1024 * noiseLFParams.x * 1.0 + noiseOffset); // range [-1;1]
						#endif
						
						#line 35300
						vec4 textureNoise = vec4(qfbm.r); // None
						#if (TEXTURESAMPLER == 1)
							#if (QUADNOISEFETCHING == 0)
								vec3 noiseTexUVW = (rayPos * NOISESCALE1024 * noiseHFParams.x + noiseOffset + qfbm * 1.1);
								textureNoise = getPackedNoise(noiseTexUVW.xyz); 
							#else
								//noiseTexUVW = (rayPos * NOISESCALE1024 * noiseHFParams.x + noiseOffset + qfbm * 0.1);
								vec3 noiseTexUVW = ((rayPos + quadStep) * NOISESCALE1024 * noiseHFParams.x + noiseOffset + qfbm * 1.1);
								textureNoise = getPackedNoise(noiseTexUVW.xyz ); // texture(ttt, Pos + stepsize * dot(threadMask, offsets)).r * dot(threadMask, weights);
								#if 1 // use gathersum
									//vec4 weightedGather = quadGather(textureNoise.r);
									textureNoise.r = quadGatherWeighted(textureNoise.r);
								#endif
								
							#endif 
						#endif
						#if (TEXTURESAMPLER == 2)
							textureNoise = texture(heightmapTex, (noiseTexUVW.xz + noiseTexUVW.z * 0.5)); 
						#endif
						#if (TEXTURESAMPLER == 3)
							textureNoise = texture(noise64cube, noiseTexUVW.xzy); // almost universally the best :'( 
						#endif
						#if (TEXTURESAMPLER == 4)
							textureNoise = vec4(FBMNoise3D(noiseTexUVW.xyz)); 
						#endif
						#if (TEXTURESAMPLER == 5)
							textureNoise = vec4(Value3D(noiseTexUVW.xyz)); 
						#endif
						#if (TEXTURESAMPLER == 6)
							textureNoise = vec4(SimplexPerlin3D(noiseTexUVW.xyz)); 
						#endif
						
						simplexnoise = simplexnoise - noiseLFParams.y;
						
						// Modulate the noise based on its depth below fogplane, this is 1 at 0 height, and 0 at heightFogTop
						float rayDepthratio = clamp((1.0 - rayPos.y * heightFogTopInv) * HEIGHTDENSITY,0,1);
						
						float clampedNoise = clamp( cloudDensity * (textureNoise.r * noiseLFParams.x - noiseLFParams.y) * rayDepthratio * stepLength, 0, 1);
						noiseValues[ns] = clampedNoise;
						float shadeFactor = max(0.0, textureNoise.g -noiseLFParams.y) ;
						vec3 fogShaded = mix(heightFogColor.rgb, shadowedColor.rgb,  rayDepthratio * rayDepthratio* shadeFactor*0 );
						//clampedNoise = step(sin(time * 0.01) * 0.1 + 0.5, clampedNoise);
						fogRGBA.rgb = fogShaded.rgb * clampedNoise + fogRGBA.rgb * (1.0 - clampedNoise);
						fogRGBA.a = clampedNoise + fogRGBA.a * (1.0 - clampedNoise); // the sA*sA term is questionable here!
				}
				#endif
				
	
				#if (HEIGHTSHADOWSTEPS > 0)
					float shadowJitterOffset = rayJitterOffset;
					rayStep = (rayEnd - rayStart) / HEIGHTSHADOWSTEPS;
					float numShadowSamplesTaken = 0;
					for (uint i = 0; i < HEIGHTSHADOWSTEPS; i++){
						uint noiseIndex = (i * CLOUDSTEPS) / HEIGHTSHADOWSTEPS;
						float currentnoise = 1;//noiseValues[noiseIndex];
						if (currentnoise > 0 || 1 == 1){
						//if (currentnoise > 0.01){
							vec3 rayPos = rayStart + rayStep * (float(i) + rayJitterOffset );
							
							float localShadow= shadowAtWorldPos(rayPos); // 1 for lit, 0 for unlit
							
							
							float shadowDelta = 0.25 * (abs(dFdx(localShadow)) + abs(dFdy(localShadow)));
							float rayDepthratio = clamp((1.0 - rayPos.y * heightFogTopInv) * HEIGHTDENSITY,0,1);
							
							localShadow = mix(shadowDelta, 1.0 - shadowDelta, localShadow);
							collectedShadow += max(localShadow, 1.0 - rayDepthratio);
							numShadowSamplesTaken += 1.0;
						}
					}
					collectedShadow = collectedShadow/numShadowSamplesTaken;
				#else
				#endif
				
				#if (CLOUDSHADOWS > 0 && CLOUDSTEPS > 0)
					float cloudstrength  =0; // yes indeedy do
					// adjust rayEnd to point from rayStart to the sun direction!
					// the pos at which the vector in sun dir intercepts fog plane
					// could use a lower res, or a forced lower LOD bias for sampling at speed?
					// TODO: this means we actually have to get back to 3 pass rendering, at the very least :/ 
					 
					float shadowRayStart = shadowAtWorldPos(rayStart + sunDir.xyz * 1);
					
					
					if (mapdepth < 0.9998 && shadowRayStart > -1.75){
						
						
						
						float shadowJitterOffset = rayJitterOffset;
						rayStep = sunDir.xyz * ((heightFogTop - rayStart.y) / sunDir.y) / CLOUDSHADOWS;
						quadStep = rayStep * dot(threadMask,quadoffsets) * NOISESCALE1024 * noiseHFParams.x;
						float stepLength = length(rayStep);
						float numShadowSamplesTaken = 0;
						for (uint i = 0; i < CLOUDSHADOWS; i++){
							vec3 rayPos = rayStart + rayStep * (float(i) + rayJitterOffset *0.00001);
							vec3 noiseTexUVW = (rayPos * NOISESCALE1024 * noiseHFParams.x + noiseOffset + 0.0 * 0.1);
							//vec4 textureNoise = texture(noise64cube, noiseTexUVW.xzy, 1); // give it a hefty LOD bias for speed and clarity
							#if QUADNOISEFETCHING == 0
								vec4 textureNoise = getPackedNoise(noiseTexUVW.xyz);
							#else
								vec4 textureNoise = getPackedNoise(noiseTexUVW.xyz + quadStep * 0.02);  // TODO: give it a hefty LOD bias for speed and clarity
								
							#endif
							
							
							float rayDepthratio = clamp((1.0 - rayPos.y * heightFogTopInv) * HEIGHTDENSITY,0,1);
							
							float clampedTextureNoise = max(0.0, (textureNoise.r - noiseLFParams.y) * (1.0 - noiseLFParams.y));
							cloudstrength += clampedTextureNoise * rayDepthratio;
							
							float clampedNoise = clamp(cloudDensity * (textureNoise.r * noiseLFParams.x - noiseLFParams.y) * rayDepthratio * stepLength, 0, 1);
							groundRGBA.a = clampedNoise + groundRGBA.a * (1.0 - clampedNoise);
							//if (rayPos.y > heightFogTop) groundRGBA.rgba = vec4(1.0);
						}
						
						cloudstrength = cloudstrength/CLOUDSHADOWS;
						//collectedShadow -= cloudstrength *10;
						//heightBasedFog = 10000;
						float shadtest = sin(time * 0.1) * 0.5  + 0.5;
						shadtest = shadowedColor.a;
						groundRGBA.a = clamp(groundRGBA.a,0,1);
						groundRGBA.a = groundRGBA.a  * shadtest;
						groundRGBA.rgb = mix(fogRGBA.rgb, groundRGBA.rgb,  groundRGBA.a);
						//groundRGBA = vec4(shadowedColor.rgb, cloudstrength * 10);
					}
				#endif
				//fogRGBA.a = 0;
				fogRGBA.rgb = fogRGBA.rgb * fogRGBA.a + groundRGBA.rgb * (1.0 - fogRGBA.a);
				fogRGBA.a   = groundRGBA.a * (1.0 - fogRGBA.a) + fogRGBA.a;
				//fogRGBA = vec4( fogRGBA.rgb  + groundRGBA.rgb * (1.0 - fogRGBA.a), groundRGBA.a * (1.0 - fogRGBA.a) + fogRGBA.a);
				//fogRGBA =groundRGBA;
				fragColor.rgba = fogRGBA;
				//fragColor.rgba = groundRGBA;
				return;
				//collectedShadow = 1.0;
				
			#else
				#if 0 // old deprecated method
					float rayJitterOffset = (1 * rand(screenUV)) *  stepsInv;
					#if (HEIGHTSHADOWSTEPS > 0)
					for (uint i = 0; i < HEIGHTSHADOWSTEPS; i++){
						float f = float(i) stepsInv;
						vec3 rayPos = mix(rayStart.xyz, rayEnd, f + rayJitterOffset);
						
						float localShadow= shadowAtWorldPos(rayPos); // 1 for lit, 0 for unlit
						float shadowDelta = 0.25 * (abs(dFdx(localShadow)) + abs(dFdy(localShadow)));
						
						localShadow = mix(shadowDelta, 1.0 - shadowDelta, localShadow);
						collectedShadow += localShadow;
					}
					
					collectedShadow *= stepsInv;
					collectedShadow = collectedShadow * collectedShadow;
					#else
						collectedShadow = 1.0;
					#endif
					#if (CLOUDSTEPS > 0)
						for (uint i = 0; i < (CLOUDSTEPS); i++){
							float f = float(i) / (CLOUDSTEPS);
							vec3 rayPos = mix(rayStart.xyz, rayEnd, f + 0.005 * rayJitterOffset);
						//if (1 == 1){
							vec4 localNoise =  texture(noise64cube, rayPos.xyz * NOISESCALE1024  + noiseOffset); // TODO: SUBSAMPLE THIS ONE!
							
							float simplexnoise = SimplexPerlin3D ((rayPos ) * NOISESCALE1024 * noiseLFParams.x + noiseOffset);

							float thisraynoise = max(0,localNoise.a + noiseLFParams.y - simplexnoise);
							collectedNoise += thisraynoise;
						}
						heightBasedFog *= collectedNoise/(CLOUDSTEPS);
					#endif
					
				#else // new interleaved sampling
					#if ((HEIGHTSHADOWSTEPS > 0) && (CLOUDSTEPS >0))
						float numShadowSamplesTaken = 0.001;
						uint shadowSteps = HEIGHTSHADOWSTEPS / CLOUDSTEPS;
						float rayJitterOffset = (1 * rand(screenUV)) * stepsInv ;
						for (uint n = 0; n < CLOUDSTEPS; n ++){
							float f = float(n) / CLOUDSTEPS;
							
							vec3 rayPos = mix(rayStart.xyz, rayEnd, f + 0.5 * rayJitterOffset);
							
							//vec4 localNoise =  texture(noise64cube, rayPos.xyz * NOISESCALE1024 + noiseOffset); // TODO: SUBSAMPLE THIS ONE!
							vec3 skewed3dpos = (rayPos.xyz * NOISESCALE1024 * noiseHFParams.x + noiseOffset) * vec3(1,4,1);
							float localNoise = 1.0 - texture(noise64cube, skewed3dpos.xzy).r; // TODO: SUBSAMPLE THIS ONE!
							#if 1
								float simplexnoise =  SimplexPerlin3D((rayPos) * NOISESCALE1024 * noiseHFParams.x +
								noiseOffset) * noiseLFParams.y;
							#else // yeah nested perlin is uggo
								float a = 0.001;
								vec3 swirlpos = rayPos.xyz * vec3(1.0, 1.1, 1.2) * a + vec3(time)*a * 0.0001 ;
								vec3 swirly = vec3(Value3D(swirlpos.xyz * 1.1 + 31.33), Value3D(swirlpos.yzx * 1.4 + 60.66), Value3D(swirlpos.zxy)); 
								float simplexnoise = SimplexPerlin3D(swirlpos + swirly * 1.5) * 0.5 + 0.5;
								//perlinswirl = noise(swirlpos + swirly * 3);
							#endif
							float thisraynoise = max(0, localNoise.r + noiseLFParams.y - simplexnoise);
							
							// Modulate the noise based on its depth below fogplane, this is 1 at 0 height, and 0 at heightFogTop
							float rayDepthratio = 1.0 - rayPos.y / (heightFogTop);
							
							// Fog reaches full density at half depth to waterplane
							rayDepthratio = clamp(rayDepthratio * HEIGHTDENSITY, 0, 1);
							

							
							collectedNoise += thisraynoise * rayDepthratio;
							
							densityposition += vec4(rayPos*thisraynoise, thisraynoise); // collecting the 'center' of the noise cloud
							//if (thisraynoise > 0) { // only sample shadow if we have actual fog here!
								for (uint m = 0; m < shadowSteps; m++){ // step through the small local volume 
									f += (float(m)) * stepsInv; 
									//float f = (float(m) + float(n) * CLOUDSTEPS)/ steps;
									vec3 rayPos = mix(rayStart.xyz, rayEnd, f + rayJitterOffset);
									
									float localShadow= shadowAtWorldPos(rayPos); // 1 for lit, 0 for unlit
									float shadowDelta = 0.25 * (abs(dFdx(localShadow)) + abs(dFdy(localShadow))); // magic smoothing using adjacent pixels
									
									localShadow = mix(shadowDelta, 1.0 - shadowDelta, localShadow);
									collectedShadow += localShadow;
									numShadowSamplesTaken += 1.0;
								}
							//}
						}
						collectedShadow /= numShadowSamplesTaken; // get the true litness by only taking into account actual samples taken
						
						//apply shadow power:
						collectedShadow = pow(collectedShadow, 2* shadowedColor.a);
						
						densityposition.xyz /= densityposition.w;

						heightBasedFog *= collectedNoise/(CLOUDSTEPS);
					#else // fall back to retard mode
						collectedShadow = 1.0;
						densityposition.xyz = (rayStart + rayEnd)*0.5;
					#endif
				
				#endif
			#endif
		}else{
			collectedShadow = 1.0;
		}
		#endif
	#endif
	//modulate the height based component only, not the distance based component
	
	// but modulate _before_ addition!
	//const float expfactor = fogExpFactor * -0.0001;
	
	// Modulate distance fog density with angle of ray compared to sky?
	//vec3 camToMapNorm = normalize(mapFromCam);
	//float rayUpness = 1.0;
	if (camToMapNorm.y > 0) {
		rayUpness = pow(1.0 - camToMapNorm.y, 8.0);
		distanceFogAmount *= rayUpness;
	}
	
	
	// reduce height-based fog for in-los areas:
	heightBasedFog *= (1.0 - inlos);
	
	// Modulate the amount of fog based on how shadowed it is, by adding more fog to shadowed areas
	heightBasedFog += heightBasedFog * smoothstep( 0.0,1.0, 1.0 - collectedShadow); 
	
	// TODO, COMPLETELY SEPARATE HEIGHT AND DISTANCE BASED FOGS!
	//float heightBasedFogExp = exp(heightBasedFog * expfactor);
	
	
	
	// Sum the two components of fog by multiplication?
	float totalfog = heightBasedFogExp * distanceFogAmountExp;
	
	// Clamp the total amout of fog at 99% outputfogalpha, see quilezs Almost Identity (II)
	totalfog = sqrt(totalfog * totalfog + (1.0 - heightFogColor.a) * 0.1);
	fragColor.a = min(1.0, max(0, 1.0 - totalfog));
	
	// Colorize fog based on view angle: TODO do this on center weight of both !
	float sunAngleCos =  dot( camToMapNorm, sunDir.xyz); // this goes from into sun at 1 to sun behind us at -1 
	float sunPower = (1.0 + distanceFogColor.a * 8);
	float sunRatio = 1.0;
	if (sunAngleCos < 0 ){ // SUN IS BEHIND US
		sunPower *= 2;
		sunAngleCos *= -1.0;
		sunRatio = 0.2;
	}
	float sphericalharmonic = pow(sunAngleCos, sunPower) * sunRatio;
	
	vec3 chromaSphericalHarmonic = pow(vec3(sunAngleCos), vec3(sunPower) * vec3(1.0, 1.0 + SUNCHROMASHIFT, 1.0 + 2.0 * SUNCHROMASHIFT)) * sunRatio;
	
	// CHROMA SHIFTING?
	
	
	// This will be our output color
	vec3 fogColor = heightFogColor.rgb;
	
	//colorize based on the sun level
	//fogColor = mix(fogColor, 2*distanceFogColor.rgb, sphericalharmonic);
	fogColor = mix(fogColor, 2*distanceFogColor.rgb, chromaSphericalHarmonic);
	
	// Set the base color depending on how shadowed it is, 
	// shadowed components should tend toward heightFogColor
	vec3 heightFogColor = mix(heightFogColor.rgb, fogColor, collectedShadow);
	
	// Darkened the shadowed bits towards shadowedColor
	fragColor.rgb = mix(vec3(shadowedColor), heightFogColor.rgb, collectedShadow);	
	
	//Calculate backscatter color from minimap if possible?
	#if (USEMINIMAP == 1) 
		vec4 minimapcolor = textureLod(miniMapTex, heighmapUVatWorldPosMirrored(mapWorldPos.xz), 4.0);
		//if (camToMapNorm.y > 0 && mapdepth > 0.9999) rayUpness = 0;
		fragColor.rgb += minimapcolor.rgb * MINIMAPSCATTER * collectedShadow * rayUpness ;
	#endif
	
	// Colorize the fog wether its in shadow or not
	float heightDistFogRatio = heightBasedFog / (heightBasedFog + distanceFogAmount);
	// Above that, mix back regular fog color for distance based fog
	fragColor.rgb = mix( fogColor.rgb, fragColor.rgb,heightDistFogRatio);
	
	// get noise gradient and colorize with that
	vec3 fognormal = normalize(densityposition.xyz);
	
	float fogSun = 1.0 + clamp(dot(fognormal, sunDir.xyz), -1, 1);
	//fragColor.rgb *= fogSun;
	
	//fragColor.rgb = vec3(densityposition.g);
	//fragColor.a = 1.0;  

	return;
	*/
}