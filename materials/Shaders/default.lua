return {
vertex = [[
	//shader version is added via gadget
	%%GLOBAL_NAMESPACE%%

	//#define use_normalmapping
	//#define flip_normalmap
	//#define use_shadows
	%%VERTEX_GLOBAL_NAMESPACE%%
	#line 10010

	uniform mat4 camera;   //ViewMatrix (gl_ModelViewMatrix is ModelMatrix!)
	uniform vec3 cameraPos;

	uniform vec3 etcLoc;
	uniform int simFrame;

	out float selfIllumMod;
	//uniform float frameLoc;

	//The api_custom_unit_shaders supplies this definition:
	#ifdef use_shadows
		uniform mat4 shadowMatrix;
		uniform vec4 shadowParams;
	#endif

	out float aoTerm;

	out vec3 viewDir;

	out vec3 worldTangent;
	out vec3 worldBitangent;
	out vec3 worldNormal;

	out vec2 modelUV;
	out vec4 shadowVertexPos;
	out vec4 modelPos;
	out vec4 worldPos;

	void main(void)
	{
		modelPos = gl_Vertex;
		vec3 modelNormal = gl_Normal;

		%%VERTEX_PRE_TRANSFORM%%

		vec3 modelTangent   = gl_MultiTexCoord5.xyz;
		vec3 modelBitangent = gl_MultiTexCoord6.xyz;

		#if 1
			if (dot(modelTangent, modelTangent) < 0.1 || dot(modelBitangent, modelBitangent) < 0.1) {
				modelTangent = vec3(1.0, 0.0, 0.0);
				modelBitangent = vec3(0.0, 0.0, 1.0);
			}
		#endif

		worldTangent = gl_NormalMatrix * modelTangent;
		worldBitangent = gl_NormalMatrix * modelBitangent;
		worldNormal = gl_NormalMatrix * modelNormal;

		worldPos = gl_ModelViewMatrix * modelPos;
		gl_Position = gl_ProjectionMatrix * (camera * worldPos);
		viewDir = cameraPos - worldPos.xyz;

		#ifdef use_shadows
			shadowVertexPos = shadowMatrix * worldPos;
			shadowVertexPos.xy = shadowVertexPos.xy + 0.5;
		#endif

		modelUV.xy = gl_MultiTexCoord0.xy;
		#ifdef use_treadoffset_core
		{
			const float atlasSize = 2048.0;
			// note, invert we invert Y axis
			const vec4 treadBoundaries = vec4(1536.0, 2048.0, atlasSize - 2048.0, atlasSize - 1792.0) / atlasSize;
			if (all(bvec4(
					modelUV.x >= treadBoundaries.x, modelUV.x <= treadBoundaries.y,
					modelUV.y >= treadBoundaries.z, modelUV.y <= treadBoundaries.w))) {
				modelUV.x += etcLoc.z;
			}
		}
		#endif
		#ifdef use_treadoffset_arm
		{
			const float atlasSize = 4096.0;
			// note, invert we invert Y axis
			const vec4 treadBoundaries = vec4(2572.0, 3070.0, atlasSize - 1761.0, atlasSize - 1548.0) / atlasSize;
			if (all(bvec4(
					modelUV.x >= treadBoundaries.x, modelUV.x <= treadBoundaries.y,
					modelUV.y >= treadBoundaries.z, modelUV.y <= treadBoundaries.w))) {
				modelUV.x += etcLoc.z;
			}
		}
		#endif

		#ifdef use_vertex_ao
			aoTerm = clamp(1.0 * fract(gl_MultiTexCoord0.s * 16384.0), 0.1, 1.0);
		#else
			aoTerm = 1.0;
		#endif

		#ifdef flashlights
			// gl_ModelViewMatrix[3][0] + gl_ModelViewMatrix[3][2] are Tx, Tz elements of translation of matrix
			selfIllumMod = max(-0.2, sin(simFrame * 0.063 + (gl_ModelViewMatrix[3][0] + gl_ModelViewMatrix[3][2]) * 0.1)) + 0.2;
		#else
			selfIllumMod = 1.0;
		#endif

		//float fogCoord = length(gl_Position.xyz); // maybe fog should be readded?
		//fogFactor = (gl_Fog.end - fogCoord) * gl_Fog.scale; //gl_Fog.scale := 1.0 / (gl_Fog.end - gl_Fog.start)
		//fogFactor = clamp(fogFactor, 0.0, 1.0);

		%%VERTEX_POST_TRANSFORM%%
	}
]],


fragment = [[
	//shader version is added via gadget
	%%GLOBAL_NAMESPACE%%

	#if (GL_FRAGMENT_PRECISION_HIGH == 1)
	// ancient GL3 ATI drivers confuse GLSL for GLSL-ES and require this
	precision highp float;
	#else
	precision mediump float;
	#endif

	%%FRAGMENT_GLOBAL_NAMESPACE%%
	#line 20123

	#if (deferred_mode == 1)
		#define GBUFFER_NORMTEX_IDX 0
		#define GBUFFER_DIFFTEX_IDX 1
		#define GBUFFER_SPECTEX_IDX 2
		#define GBUFFER_EMITTEX_IDX 3
		#define GBUFFER_MISCTEX_IDX 4

		#define GBUFFER_COUNT 5
	#endif

	uniform sampler2D textureS3o1;
	uniform sampler2D textureS3o2;
	uniform samplerCube reflectTex;

	uniform sampler2D envLUT;

	uniform vec3 sunPos; //light direction in fact
	#define lightDir sunPos

	uniform vec3 sunDiffuse;
	uniform vec3 sunAmbient;
	uniform vec3 sunSpecular;

	uniform vec3 etcLoc;
	uniform int simFrame;

	uniform float pbrParams[8];

	#ifndef MAT_IDX
		#define MAT_IDX 0
	#endif

	#define SHADOW_HARD 0
	#define SHADOW_SOFT 1
	#define SHADOW_SOFTER 2
	#define SHADOW_SOFTEST 3

	#ifndef SHADOW_SOFTNESS
		#define SHADOW_SOFTNESS SHADOW_SOFT
	#endif

	#if (SHADOW_SOFTNESS == SHADOW_HARD)
		#define SHADOW_SAMPLES 1
	#endif

	#if (SHADOW_SOFTNESS == SHADOW_SOFT)
		#define SHADOW_SAMPLES 2 // number of shadowmap samples per fragment
		#define SHADOW_RANDOMNESS 0.5 // 0.0 - blocky look, 1.0 - random points look
		#define SHADOW_SAMPLING_DISTANCE 2.0 // how far shadow samples go (in shadowmap texels) as if it was applied to 8192x8192 sized shadow map
	#endif

	#if (SHADOW_SOFTNESS == SHADOW_SOFTER)
		#define SHADOW_SAMPLES 6 // number of shadowmap samples per fragment
		#define SHADOW_RANDOMNESS 0.4 // 0.0 - blocky look, 1.0 - random points look
		#define SHADOW_SAMPLING_DISTANCE 2.0 // how far shadow samples go (in shadowmap texels) as if it was applied to 8192x8192 sized shadow map
	#endif

	#if (SHADOW_SOFTNESS == SHADOW_SOFTEST)
		#define SHADOW_SAMPLES 8 // number of shadowmap samples per fragment
		#define SHADOW_RANDOMNESS 0.4 // 0.0 - blocky look, 1.0 - random points look
		#define SHADOW_SAMPLING_DISTANCE 2.5 // how far shadow samples go (in shadowmap texels) as if it was applied to 8192x8192 sized shadow map
	#endif

	#ifndef ENV_SMPL_NUM
		#define ENV_SMPL_NUM 0
	#endif

	#ifndef USE_ENVIRONMENT_DIFFUSE
		#define USE_ENVIRONMENT_DIFFUSE 0
	#endif

	#ifndef USE_ENVIRONMENT_SPECULAR
		#define USE_ENVIRONMENT_SPECULAR 0
	#endif

	#if (ENV_SMPL_NUM == 0)
		#undef USE_ENVIRONMENT_DIFFUSE
		#undef USE_ENVIRONMENT_SPECULAR
		#define USE_ENVIRONMENT_DIFFUSE 0
		#define USE_ENVIRONMENT_SPECULAR 0
	#endif

	#ifdef use_shadows
		uniform sampler2DShadow shadowTex;
	#endif
	uniform float shadowDensity;

	in float aoTerm;

	uniform vec4 teamColor;
	in vec3 viewDir;
	//varying float fogFactor;

	in float selfIllumMod;


	#ifdef use_normalmapping
		uniform sampler2D normalMap;
	#endif

	#ifdef USE_LOSMAP
		uniform vec2 mapSize;
		uniform float inLosMode;
		uniform sampler2D losMapTex;
	#endif

	uniform sampler2D brdfLUT;

	in vec3 worldTangent;
	in vec3 worldBitangent;
	in vec3 worldNormal;

	in vec2 modelUV;
	in vec4 shadowVertexPos;
	in vec4 worldPos;
	in vec4 modelPos;

	#if (deferred_mode == 1)
		out vec4 fragData[GBUFFER_COUNT];
	#else
		out vec4 fragData[1];
	#endif

	const float PI = 3.1415926535897932384626433832795;
	const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
	const float EPS = 1e-4;

	const float MIN_ROUGHNESS = 0.04;
	const float DEFAULT_F0 = 0.04;

	const mat3 RGB2YCBCR = mat3(
		0.2126, -0.114572, 0.5,
		0.7152, -0.385428, -0.454153,
		0.0722, 0.5, -0.0458471);

	const mat3 YCBCR2RGB = mat3(
		1.0, 1.0, 1.0,
		0.0, -0.187324, 1.8556,
		1.5748, -0.468124, -5.55112e-17);

	#define NORM2SNORM(value) (value * 2.0 - 1.0)
	#define SNORM2NORM(value) (value * 0.5 + 0.5)

	// gamma correction & tonemapping
	#ifdef GAMMA
		#define INV_GAMMA 1.0 / GAMMA
		#define SRGBtoLINEAR(c) ( pow(c, vec3(GAMMA)) )
		#define LINEARtoSRGB(c) ( pow(c, vec3(INV_GAMMA)) )
	#else
		#define SRGBtoLINEAR(c) ( c )
		#define LINEARtoSRGB(c) ( c )
	#endif

	// http://blog.marmakoide.org/?p=1
	const float goldenAngle = 2.3999632297286533222315555066336; // PI * (3.0 - sqrt(5.0));
	vec2 SpiralSNorm(int i, int N) {
		float theta = float(i) * goldenAngle;
		float r = sqrt(float(i)) / sqrt(float(N));
		return vec2 (r * cos(theta), r * sin(theta));
	}

	float hash12L(vec2 p) {
		const float HASHSCALE1 = 0.1031;
		vec3 p3  = fract(vec3(p.xyx) * HASHSCALE1);
		p3 += dot(p3, p3.yzx + 19.19);
		return fract((p3.x + p3.y) * p3.z);
	}

	float Perlin3D( vec3 P ) {
		//  https://github.com/BrianSharpe/Wombat/blob/master/Perlin3D.glsl

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
		const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
		const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
		vec3 lowz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi.zzz * ZINC ) );
		vec3 highz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi_inc1.zzz * ZINC ) );
		vec4 hashx0 = fract( Pt * lowz_mod.xxxx );
		vec4 hashx1 = fract( Pt * highz_mod.xxxx );
		vec4 hashy0 = fract( Pt * lowz_mod.yyyy );
		vec4 hashy1 = fract( Pt * highz_mod.yyyy );
		vec4 hashz0 = fract( Pt * lowz_mod.zzzz );
		vec4 hashz1 = fract( Pt * highz_mod.zzzz );

		// calculate the gradients
		vec4 grad_x0 = hashx0 - 0.49999;
		vec4 grad_y0 = hashy0 - 0.49999;
		vec4 grad_z0 = hashz0 - 0.49999;
		vec4 grad_x1 = hashx1 - 0.49999;
		vec4 grad_y1 = hashy1 - 0.49999;
		vec4 grad_z1 = hashz1 - 0.49999;
		vec4 grad_results_0 = inversesqrt( grad_x0 * grad_x0 + grad_y0 * grad_y0 + grad_z0 * grad_z0 ) * ( vec2( Pf.x, Pf_min1.x ).xyxy * grad_x0 + vec2( Pf.y, Pf_min1.y ).xxyy * grad_y0 + Pf.zzzz * grad_z0 );
		vec4 grad_results_1 = inversesqrt( grad_x1 * grad_x1 + grad_y1 * grad_y1 + grad_z1 * grad_z1 ) * ( vec2( Pf.x, Pf_min1.x ).xyxy * grad_x1 + vec2( Pf.y, Pf_min1.y ).xxyy * grad_y1 + Pf_min1.zzzz * grad_z1 );

		// Classic Perlin Interpolation
		vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
		vec4 res0 = mix( grad_results_0, grad_results_1, blend.z );
		vec4 blend2 = vec4( blend.xy, vec2( 1.0 - blend.xy ) );
		float final = dot( res0, blend2.zxzx * blend2.wwyy );
		return ( final * 1.1547005383792515290182975610039 );  // scale things to a strict -1.0->1.0 range  *= 1.0/sqrt(0.75)
	}

#ifdef use_shadows
	// Derivatives of light-space depth with respect to texture2D coordinates
	vec2 DepthGradient(vec3 xyz) {
		vec2 dZduv = vec2(0.0, 0.0);

		vec3 dUVZdx = dFdx(xyz);
		vec3 dUVZdy = dFdy(xyz);

		dZduv.x  = dUVZdy.y * dUVZdx.z;
		dZduv.x -= dUVZdx.y * dUVZdy.z;

		dZduv.y  = dUVZdx.x * dUVZdy.z;
		dZduv.y -= dUVZdy.x * dUVZdx.z;

		float det = (dUVZdx.x * dUVZdy.y) - (dUVZdx.y * dUVZdy.x);
		dZduv /= det;

		return dZduv;
	}

	float BiasedZ(float z0, vec2 dZduv, vec2 offset) {
		return z0 + dot(dZduv, offset);
	}

	float GetShadowPCFRandom(float NdotL) {
		float shadow = 0.0;

		vec3 shadowCoord = shadowVertexPos.xyz; // shadowVertexPos.w is always 1.0

		#if defined(SHADOW_SAMPLES) && (SHADOW_SAMPLES > 1)
			vec2 dZduv = DepthGradient(shadowCoord.xyz);

			float rndRotAngle = NORM2SNORM(hash12L(gl_FragCoord.xy)) * PI / 2.0 * SHADOW_RANDOMNESS;

			vec2 vSinCos = vec2(sin(rndRotAngle), cos(rndRotAngle));
			mat2 rotMat = mat2(vSinCos.y, -vSinCos.x, vSinCos.x, vSinCos.y);

			vec2 filterSize = vec2(SHADOW_SAMPLING_DISTANCE / 8192.0);

			for (int i = 0; i < SHADOW_SAMPLES; ++i) {
				// SpiralSNorm return low discrepancy sampling vec2
				vec2 offset = (rotMat * SpiralSNorm( i, SHADOW_SAMPLES )) * filterSize;

				vec3 shadowSamplingCoord = vec3(shadowCoord.xy, 0.0) + vec3(offset, BiasedZ(shadowCoord.z, dZduv, offset));
				shadow += texture( shadowTex, shadowSamplingCoord );
			}

			shadow /= float(SHADOW_SAMPLES);
			shadow *= 1.0 - smoothstep(shadow, 1.0,  0.2);
		#else
			const float cb = 5e-5;
			float bias = cb * tan(acos(NdotL));
			bias = clamp(bias, 0.0, 5.0 * cb);

			vec3 shadowSamplingCoord = shadowCoord;
			shadowSamplingCoord.z -= bias;

			shadow = texture( shadowTex, shadowSamplingCoord );
		#endif
		return shadow;
	}
#endif


/***********************************************************************/
// Spherical Harmonics Lib
	// Constants, see here: http://en.wikipedia.org/wiki/Table_of_spherical_harmonics
	#define k01 0.2820947918 // sqrt(  1/PI)/2
	#define k02 0.4886025119 // sqrt(  3/PI)/2
	#define k03 1.0925484306 // sqrt( 15/PI)/2
	#define k04 0.3153915652 // sqrt(  5/PI)/4
	#define k05 0.5462742153 // sqrt( 15/PI)/4
	#define k06 0.5900435860 // sqrt( 70/PI)/8
	#define k07 2.8906114210 // sqrt(105/PI)/2
	#define k08 0.4570214810 // sqrt( 42/PI)/8
	#define k09 0.3731763300 // sqrt(  7/PI)/4
	#define k10 1.4453057110 // sqrt(105/PI)/4

	// Y_l_m(s), where l is the band and m the range in [-l..l]
	float SphericalHarmonic( in int l, in int m, in vec3 n )
	{
		//----------------------------------------------------------
		if( l==0 )          return   k01;

		//----------------------------------------------------------
		if( l==1 && m==-1 ) return  -k02*n.y;
		if( l==1 && m== 0 ) return   k02*n.z;
		if( l==1 && m== 1 ) return  -k02*n.x;

		//----------------------------------------------------------
		if( l==2 && m==-2 ) return   k03*n.x*n.y;
		if( l==2 && m==-1 ) return  -k03*n.y*n.z;
		if( l==2 && m== 0 ) return   k04*(3.0*n.z*n.z-1.0);
		if( l==2 && m== 1 ) return  -k03*n.x*n.z;
		if( l==2 && m== 2 ) return   k05*(n.x*n.x-n.y*n.y);
		//----------------------------------------------------------

		return 0.0;
	}

	mat3 shEvaluate(vec3 n) {
		mat3 r;
		r[0][0] =  SphericalHarmonic(0,  0, n);
		r[0][1] = -SphericalHarmonic(1, -1, n);
		r[0][2] =  SphericalHarmonic(1,  0, n);
		r[1][0] = -SphericalHarmonic(1,  1, n);

		r[1][1] =  SphericalHarmonic(2, -2, n);
		r[1][2] = -SphericalHarmonic(2, -1, n);
		r[2][0] =  SphericalHarmonic(2,  0, n);
		r[2][1] = -SphericalHarmonic(2,  1, n);
		r[2][2] =  SphericalHarmonic(2,  2, n);
		return r;
	}

	// Recovers the value of a SH function in the direction dir.
	float shUnproject(mat3 functionSh, vec3 dir)
	{
		mat3 sh = shEvaluate(dir);
		return
			dot(functionSh[0], sh[0]) +
			dot(functionSh[1], sh[1]) +
			dot(functionSh[2], sh[2]);
	}

	const vec3 convCoeff = vec3(1.0, 2.0/3.0, 1.0/4.0);
	mat3 shDiffuseConvolution(mat3 sh) {
		mat3 r = sh;

		r[0][0] *= convCoeff.x;

		r[0][1] *= convCoeff.y;
		r[0][2] *= convCoeff.y;
		r[1][0] *= convCoeff.y;

		r[1][1] *= convCoeff.z;
		r[1][2] *= convCoeff.z;
		r[2][0] *= convCoeff.z;
		r[2][1] *= convCoeff.z;
		r[2][2] *= convCoeff.z;

		return r;
	}

	vec3 shToColor(mat3 shR, mat3 shG, mat3 shB, vec3 rayDir) {
		vec3 rgbColor = vec3(
			shUnproject(shR, rayDir),
			shUnproject(shG, rayDir),
			shUnproject(shB, rayDir));

		// A "max" is usually recomended to avoid negative values (can happen with SH)
		rgbColor = max(vec3(0.0), vec3(rgbColor));
		return rgbColor;
	}


/***********************************************************************/
// Environment sampling functions
	#define FAKE_ENV_HDR 0.4
	#define FAKE_ENV_THR 0.55
	vec3 SampleReflectionMapMod(vec3 colorIn){
		vec3 color = SRGBtoLINEAR(colorIn);
		#if defined (FAKE_ENV_HDR)
			color *= 1.0 + FAKE_ENV_HDR * smoothstep(FAKE_ENV_THR, 1.0, dot(LUMA, color)); //HDR for poors
		#endif
		return color;
	}

	vec3 SampleReflectionMap(vec3 sp, float lodBias){
		return SampleReflectionMapMod(texture(reflectTex, sp, lodBias).rgb);
	}

	vec3 SampleReflectionMapLod(vec3 sp, float lodBias){
		return SampleReflectionMapMod(textureLod(reflectTex, sp, lodBias).rgb);
	}

	vec3 SampleEnvironmentWithRoughness(vec3 samplingVec, float roughness) {
		float maxLodLevel = log2(float(textureSize(reflectTex, 0).x));

		// makes roughness of reflection scale perceptually much more linear
		// Assumes "CubeTexSizeReflection" = 1024
		maxLodLevel -= 4.0;

		float lodBias = maxLodLevel * roughness;

		return SampleReflectionMap(samplingVec, lodBias);
	}

	vec3 SpherePoints_GoldenAngle(float i, float numSamples) {
		float theta = i * goldenAngle;
		float z = (1.0 - 1.0 / numSamples) * (1.0 - 2.0 * i / (numSamples - 1.0));
		float radius = sqrt(1.0 - z * z);
		return vec3(radius * vec2(cos(theta), sin(theta)), z);
	}

	void TextureEnvBlured(in vec3 N, in vec3 Rv, out vec3 iblDiffuse, out vec3 iblSpecular) {
		iblDiffuse = vec3(0.0);
		iblSpecular = vec3(0.0);

		vec2 sum = vec2(0.0);

		vec2 ts = vec2(textureSize(reflectTex, 0));
		float maxMipMap = log2(max(ts.x, ts.y));

		vec2 lodBias = vec2(maxMipMap - 4.0, 4.0);

		#if 0
			for (int i=0; i < ENV_SMPL_NUM; ++i) {
				vec3 sp = SpherePoints_GoldenAngle(float(i), float(ENV_SMPL_NUM));

				vec2 w = vec2(
					dot(sp, N ) * 0.5 + 0.5,
					dot(sp, Rv) * 0.5 + 0.5);


				w = pow(w, vec2(4.0, 32.0));

				vec3 iblD = SampleReflectionMapLod(sp, lodBias.x);
				vec3 iblS = SampleReflectionMapLod(sp, lodBias.y);

				iblDiffuse  += iblD * w.x;
				iblSpecular += iblS * w.y;

				sum += w;
			}

			iblDiffuse  /= sum.x;
			iblSpecular /= sum.y;
		#else
			mat3 shR, shG, shB;

			#if 0 //loop version
				for (int x = 0; x < 3; ++x)
					for (int y = 0; y < 3; ++y) {
						vec3 sample = texelFetch(envLUT, ivec2(x, y), 0).rgb;
						shR[x][y] = sample.r;
						shG[x][y] = sample.g;
						shB[x][y] = sample.b;
					}
			#else //unrolled version
				#define SH_FILL(x, y) \
				{ \
					vec3 sample = texelFetch(envLUT, ivec2(x, y), 0).rgb; \
					shR[x][y] = sample.r; \
					shG[x][y] = sample.g; \
					shB[x][y] = sample.b; \
				}
				SH_FILL(0, 0)
				SH_FILL(0, 1)
				SH_FILL(0, 2)

				SH_FILL(1, 0)
				SH_FILL(1, 1)
				SH_FILL(1, 2)

				SH_FILL(2, 0)
				SH_FILL(2, 1)
				SH_FILL(2, 2)

				#undef SH_FILL
			#endif

			mat3 shRD = shDiffuseConvolution(shR);
			mat3 shGD = shDiffuseConvolution(shG);
			mat3 shBD = shDiffuseConvolution(shB);

			iblDiffuse = shToColor(shRD, shGD, shBD, N);
			iblSpecular = shToColor(shR, shG, shB, Rv);

			iblSpecular = mix(iblSpecular, SampleReflectionMapLod(Rv, 5.0), 0.2); //add some shininess
		#endif
	}


/***********************************************************************/
// PBR related functions


	// Fresnel - Schlick
	// F term
	vec3 FresnelSchlick(vec3 R0, vec3 R90, float VdotH) {
		return R0 + (R90 - R0) * pow(clamp(1.0 - VdotH, 0.0, 1.0), 5.0);
	}

	// Fresnel - Schlick with Roughness - LearnOpenGL
	vec3 FresnelSchlickWithRoughness(vec3 R0, vec3 R90, float VdotH, float roughness) {
		return R0 + (max(R90 - vec3(roughness), R0) - R0) * pow(1.0 - VdotH, 5.0);
	}

	// Fresnel - Blender - Seems like it's not applicable for us
	vec3 FresnelBlenderWithRoughness(vec3 R0, vec3 R90, vec2 envBRDF) {
		return clamp(envBRDF.y * R90 + envBRDF.x * R0, vec3(0.0), vec3(1.0));
	}
	#define FresnelWithRoughness(R0, R90, VdotH, roughness, envBRDF) \
	FresnelSchlickWithRoughness(R0, R90, VdotH, roughness)
	//FresnelBlenderWithRoughness(R0, R90, envBRDF)

	// Smith GGX Correlated visibility function
	// Note: Vis = G / (4 * NdotL * NdotV)
	#define VisibilityOcclusion(NdotL, NdotV, roughness2, roughness4) \
	VisibilityOcclusionFast(NdotL, NdotV, roughness2)
	//VisibilityOcclusionSlow(NdotL, NdotV, roughness4)

	float VisibilityOcclusionFast(float NdotL, float NdotV, float roughness2) {
		float GGXV = NdotL * (NdotV * (1.0 - roughness2) + roughness2);
		float GGXL = NdotV * (NdotL * (1.0 - roughness2) + roughness2);

		float GGX = GGXV + GGXL;

		return mix(0.0, 0.5 / GGX, float(GGX > 0.0));
	}

	float VisibilityOcclusionSlow(float NdotL, float NdotV, float roughness4) {
		float GGXV = NdotL * sqrt(NdotV * NdotV * (1.0 - roughness4) + roughness4);
		float GGXL = NdotV * sqrt(NdotL * NdotL * (1.0 - roughness4) + roughness4);

		float GGX = GGXV + GGXL;

		return mix(0.0, 0.5 / GGX, float(GGX > 0.0));
	}


	float MicrofacetDistribution(float NdotH, float roughness4) {
		float f = (NdotH * roughness4 - NdotH) * NdotH + 1.0;
		return roughness4 / (/*PI */ f * f);
	}

	float ComputeSpecularAOBlender(float NoV, float diffuseAO, float roughness2) {
		#if defined(SPECULAR_AO) && defined(use_vertex_ao)
			return clamp(pow(NoV + diffuseAO, roughness2) - 1.0 + diffuseAO, 0.0, 1.0);
		#else
			return diffuseAO;
		#endif
	}

	float ComputeSpecularAOFilament(float NoV, float diffuseAO, float roughness2) {
	#if defined(SPECULAR_AO) && defined(use_vertex_ao)
		return clamp(pow(NoV + diffuseAO, exp2(-16.0 * roughness2 - 1.0)) - 1.0 + diffuseAO, 0.0, 1.0);
	#else
		return diffuseAO;
	#endif
	}
	#define ComputeSpecularAO ComputeSpecularAOFilament


	// https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile
	vec2 EnvBRDFApprox(float ndotv, float roughness) {
		const vec4 c0 = vec4(-1, -0.0275, -0.572, 0.022);
		const vec4 c1 = vec4(1, 0.0425, 1.04, -0.04);
		vec4 r = roughness * c0 + c1;
		float a004 = min(r.x * r.x, exp2(-9.28 * ndotv)) * r.x + r.y;
		vec2 AB = vec2(-1.04, 1.04) * a004 + r.zw;
		return clamp(AB, vec2(0.0), vec2(1.0));
	}



/***********************************************************************/
// Tonemapping and helper functions

	//https://mynameismjp.wordpress.com/2010/04/30/a-closer-look-at-tone-mapping/ (comments by STEVEM)
	vec3 SteveMTM1(in vec3 x) {
		const float a = 15.0; /// Mid
		const float b = 0.3; /// Toe
		const float c = 0.5; /// Shoulder
		const float d = 1.5; /// Mid

		return LINEARtoSRGB((x * (a * x + b)) / (x * (a * x + c) + d));
	}

	vec3 SteveMTM2(in vec3 x) {
		const float a = 1.8; /// Mid
		const float b = 1.4; /// Toe
		const float c = 0.5; /// Shoulder
		const float d = 1.5; /// Mid

		return LINEARtoSRGB((x * (a * x + b)) / (x * (a * x + c) + d));
	}

	vec3 FilmicTM(in vec3 x) {
		vec3 outColor = max(vec3(0.0), x - vec3(0.004));
		return (outColor * (6.2 * outColor + 0.5)) / (outColor * (6.2 * outColor + 1.7) + 0.06);
	}

	vec3 Reinhard(const vec3 x) {
		// Reinhard et al. 2002, "Photographic Tone Reproduction for Digital Images", Eq. 3
		return LINEARtoSRGB(x / (1.0 + dot(LUMA, x)));
	}

	vec3 JodieReinhard(vec3 c){
		float l = dot(c, LUMA);
		vec3 tc = c / (c + 1.0);

		return LINEARtoSRGB(mix(c / (l + 1.0), tc, tc));
	}

	vec3 ACESFilmicTM(in vec3 x) {
		float a = 2.51;
		float b = 0.03;
		float c = 2.43;
		float d = 0.59;
		float e = 0.14;
		return LINEARtoSRGB((x * (a * x + b)) / (x * (c * x + d) + e));
	}

	vec3 Unreal(const vec3 x) {
		// Unreal, Documentation: "Color Grading"
		// Adapted to be close to Tonemap_ACES, with similar range
		// Gamma 2.2 correction is baked in, don't use with sRGB conversion!
		return x / (x + 0.155) * 1.019;
	}

	vec3 ACESRec2020(const vec3 x) {
		// Narkowicz 2016, "HDR Display вЂ“ First Steps"
		const float a = 15.8;
		const float b = 2.12;
		const float c = 1.2;
		const float d = 5.92;
		const float e = 1.9;
		return LINEARtoSRGB((x * (a * x + b)) / (x * (c * x + d) + e));
	}

	vec3 CustomTM(const vec3 x) {
		return LINEARtoSRGB((x * (pbrParams[0] * x + pbrParams[1])) / (x * (pbrParams[2] * x + pbrParams[3]) + pbrParams[4]));
	}

	// RNM - Already unpacked
	// https://www.shadertoy.com/view/4t2SzR
	vec3 NormalBlendUnpackedRNM(vec3 n1, vec3 n2) {
		n1 += vec3(0.0, 0.0, 1.0);
		n2 *= vec3(-1.0, -1.0, 1.0);

		return n1 * dot(n1, n2) / n1.z - n2;
	}

	ivec2 NPOT(ivec2 n) {
		ivec2 v = n;

		v--;
		v |= v >> 1;
		v |= v >> 2;
		v |= v >> 4;
		v |= v >> 8;
		v |= v >> 16;
		return ++v; // next power of 2
	}

	float AdjustRoughnessByNormalMap(in float roughness, in vec3 normal) {
		// Based on The Order : 1886 SIGGRAPH course notes implementation (page 21 notes)
		float nlen2 = dot(normal, normal);
		if (nlen2 < 1.0) {
			float nlen = sqrt(nlen2);
			float kappa = (3.0 * nlen -  nlen2 * nlen) / (1.0 - nlen2);
			// http://www.frostbite.com/2014/11/moving-frostbite-to-pbr/
			// page 91 : they use 0.5/kappa instead
			return min(1.0, sqrt(roughness * roughness + 1.0 / kappa));
		}
		return roughness;
	}

	#define smoothclamp(v, v0, v1) ( mix(v0, v1, smoothstep(v0, v1, v)) )

	#ifndef TONEMAP
		#define TONEMAP(c) LINEARtoSRGB(c)
	#endif


/***********************************************************************/
// Main function body

	void main(void){
		%%FRAGMENT_PRE_SHADING%%
		#line 20810

		#ifdef use_normalmapping
			vec2 tc = modelUV.st;
			vec4 normaltex = texture(normalMap, tc);
			vec3 nvTS = NORM2SNORM(normaltex.xyz);
		#else
			vec3 nvTS = vec3(0.0, 0.0, 1.0);
		#endif

		mat3 worldTBN = mat3(
			normalize(worldTangent),
			normalize(worldBitangent),
			normalize(worldNormal)
		);

		vec4 diffuseColIn = texture(textureS3o1, modelUV.st);
		vec4 extraColor   = texture(textureS3o2, modelUV.st);

		#ifdef EMISSIVENESS
			float emissiveness    = EMISSIVENESS;
		#else
			float emissiveness    = extraColor.r;
		#endif

		emissiveness = clamp(emissiveness, 0.0, 1.0);
		emissiveness *= selfIllumMod;

		#ifdef METALNESS
			float metalness    = METALNESS;
		#else
			float metalness    = extraColor.g;
		#endif

		//metalness = SNORM2NORM( sin(simFrame * 0.05) );
		//metalness = 1.0;

		//metalness = clamp(metalness, 0.0, 1.0);

		#ifdef ROUGHNESS
			float roughness    = ROUGHNESS;
		#else
			float roughness    = extraColor.b;
		#endif

		//roughness = SNORM2NORM( sin(simFrame * 0.025) );
		//roughness = 0.0;

		// this is great to remove specular aliasing on the edges.
		#ifdef ROUGHNESS_AA
			roughness = mix(roughness, AdjustRoughnessByNormalMap(roughness, nvTS), ROUGHNESS_AA);
		#endif

		roughness = clamp(roughness, MIN_ROUGHNESS, 1.0);

		float roughness2 = roughness * roughness;
		float roughness4 = roughness2 * roughness2;

		//nvTS = normalize(nvTS);

		#if defined(ROUGHNESS_PERTURB_NORMAL) || defined(ROUGHNESS_PERTURB_COLOR)
			vec3 seedVec = modelPos.xyz * 8.0;
			float rndValue = Perlin3D(seedVec.xyz);
		#endif
		#if defined(ROUGHNESS_PERTURB_NORMAL)
			float normalPerturbScale = mix(0.0, ROUGHNESS_PERTURB_NORMAL, roughness);
			vec3 rndNormal = normalize(vec3(
				normalPerturbScale * vec2(rndValue),
				1.0
			));
			nvTS = NormalBlendUnpackedRNM(nvTS, rndNormal);
		#endif

		vec3 N = normalize(worldTBN * nvTS);

		vec3 L = normalize(lightDir); //just in case
		vec3 V = normalize(viewDir);
		vec3 Rv = -reflect(V, N);
		vec3 H = normalize(L + V);

		float NdotLu = dot(N, L);
		float NdotL = clamp(NdotLu, 0.0, 1.0);
		float NdotH = clamp(dot(H, N), 0.0, 1.0);
		float NdotV = clamp(dot(N, V), EPS, 1.0);
		float VdotH = clamp(dot(V, H), 0.0, 1.0);

		#ifdef LUMAMULT
			vec3 yCbCr = RGB2YCBCR * diffuseColIn.rgb;
			#if defined(LUMAMULT)
				yCbCr.x *= LUMAMULT;
			#endif
		#endif

		vec3 albedoColor = SRGBtoLINEAR(mix(diffuseColIn.rgb, teamColor.rgb, diffuseColIn.a));

		#if defined(ROUGHNESS_PERTURB_COLOR)
			float colorPerturbScale = mix(0.0, ROUGHNESS_PERTURB_COLOR, roughness);
			albedoColor *= (1.0 + colorPerturbScale * rndValue); //try cheap way first (no RGB2YCBCR / YCBCR2RGB)
		#endif

		// shadows
		float shadowMult;
		{
			float nShadow = smoothstep(0.0, 0.35, NdotLu); //normal based shadowing, always on

			#ifdef use_shadows
				float gShadow = GetShadowPCFRandom(NdotL);
			#else
				float gShadow = 1.0;
			#endif

			//TODO: somehow scale the shadow strength with SUNMULT
			shadowMult = mix(1.0, min(nShadow, gShadow), shadowDensity);
		}

        ///
        // calculate reflectance at normal incidence; if dia-electric (like plastic) use F0
        // of 0.04 and if it's a metal, use the albedo color as F0 (metallic workflow)
        vec3 F0 = vec3(DEFAULT_F0);
        F0 = mix(F0, albedoColor, metalness);

		//float reflectance = dot(LUMA, F0);
		float reflectance = max(F0.r, max(F0.g, F0.b));

		// Anything less than 2% is physically impossible and is instead considered to be shadowing. Compare to "Real-Time-Rendering" 4th editon on page 325.
		vec3 F90 = vec3(clamp(reflectance * 50.0, 0.0, 1.0));

		#if 1
			vec2 envBRDF = textureLod(brdfLUT, vec2(NdotV, roughness), 0.0).rg;
		#else
			vec2 envBRDF = EnvBRDFApprox(NdotV, roughness);
		#endif

		vec3 energyCompensation = 1.0 + F0 * (1.0 / max(envBRDF.x, EPS) - 1.0);

        vec3 dirContrib = vec3(0.0);
		vec3 outSpecularColor = vec3(0.0);

		if (any( greaterThan(vec2(NdotL, NdotV), vec2(EPS)) )) {
			// Cook-Torrance BRDF

			vec3 F = FresnelSchlick(F0, F90, VdotH);
			float Vis = VisibilityOcclusion(NdotL, NdotV, roughness2, roughness4);
			float D = MicrofacetDistribution(NdotH, roughness4);
			outSpecularColor = F * Vis * D;

			vec3 maxSun = mix(sunSpecular, sunDiffuse, step(dot(sunSpecular, LUMA), dot(sunDiffuse, LUMA)));
			#ifdef SUNMULT
				maxSun *= SUNMULT;
			#endif

			outSpecularColor *= maxSun;
			outSpecularColor *= NdotL * shadowMult;

            // Scale the specular lobe to account for multiscattering
            // https://google.github.io/filament/Filament.md.html#toc4.7.2
			outSpecularColor *= energyCompensation;

			 // kS is equal to Fresnel
			//vec3 kS = F;

			// for energy conservation, the diffuse and specular light can't
			// be above 1.0 (unless the surface emits light); to preserve this
			// relationship the diffuse component (kD) should equal 1.0 - kS.
			vec3 kD = vec3(1.0) - F;

			// multiply kD by the inverse metalness such that only non-metals
			// have diffuse lighting, or a linear blend if partly metal (pure metals
			// have no diffuse light).
			kD *= 1.0 - metalness;

			// add to outgoing radiance dirContrib
			dirContrib  = maxSun * (kD * albedoColor /* PI */) * NdotL * shadowMult;
			dirContrib += outSpecularColor;
        }


		// getSpecularDominantDirection (Filament)
		//Rv = mix(Rv, N, roughness4);

        vec3 outColor;
		vec3 ambientContrib;
        {
            // ambient lighting (we now use IBL as the ambient term)
			vec3 F = FresnelWithRoughness(F0, F90, VdotH, roughness, envBRDF);

            //vec3 kS = F;
            vec3 kD = 1.0 - F;
            kD *= 1.0 - metalness;

            ///
			vec3 iblDiffuse, iblSpecular;

			#if (USE_ENVIRONMENT_DIFFUSE == 1) || (USE_ENVIRONMENT_SPECULAR == 1)
				TextureEnvBlured(N, Rv, iblDiffuse, iblSpecular);
			#endif
            ///

            #if (USE_ENVIRONMENT_DIFFUSE == 1)
			{
				#if 0
					vec3 iblDiffuseYCbCr = RGB2YCBCR * iblDiffuse;
					float sunAmbientLuma = dot(LUMA, sunAmbient);

					vec2 sunAmbientLumaLeeway = vec2(pbrParams[5]);

					iblDiffuseYCbCr.x = smoothclamp(iblDiffuseYCbCr.x,
						(1.0 - sunAmbientLumaLeeway.x) * sunAmbientLuma,
						(1.0 + sunAmbientLumaLeeway.y) * sunAmbientLuma);

					iblDiffuse = YCBCR2RGB * iblDiffuseYCbCr;
				#else
					iblDiffuse = mix(sunAmbient, iblDiffuse, pbrParams[5]);
				#endif
			}
			#else
				iblDiffuse = sunAmbient;
            #endif

            vec3 diffuse = iblDiffuse * albedoColor * aoTerm;

            // sample both the pre-filter map and the BRDF lut and combine them together as per the Split-Sum approximation to get the IBL specular part.
            vec3 reflectionColor = SampleEnvironmentWithRoughness(Rv, roughness);

			#if (USE_ENVIRONMENT_SPECULAR == 1)
				reflectionColor = mix(reflectionColor, iblSpecular, roughness);
			#endif

            //vec3 specular = reflectionColor * (F * envBRDF.x + (1.0 - F) * envBRDF.y);

			// specular ambient occlusion (see Filament)
			float aoTermSpec = ComputeSpecularAO(NdotV, aoTerm, roughness2);
			//vec3 specular = reflectionColor * mix(vec3(envBRDF.y), vec3(envBRDF.x), F);
			vec3 specular = reflectionColor * (F0 * envBRDF.x + F90 * envBRDF.y);
			specular *= aoTermSpec * energyCompensation;


			outSpecularColor += specular;

            ambientContrib = (kD * diffuse + specular);

            outColor = ambientContrib + dirContrib;
        }

		outColor += emissiveness * albedoColor;

		#ifdef USE_LOSMAP
			vec2 losMapUV = worldPos.xz;
			//losMapUV /= exp2(ceil(log2((mapSize)))); // $infomap is next power of two of mapSize
			losMapUV /= vec2(NPOT( ivec2(mapSize) ));
			float losValue = 0.5 + texture(losMapTex, losMapUV).r;
			losValue = mix(1.0, losValue, inLosMode);

			outColor *= losValue;
			outSpecularColor.rgb *= losValue;
			emissiveness *= losValue;
		#endif

		#ifdef EXPOSURE
			outSpecularColor.rgb *= EXPOSURE;
			outColor *= EXPOSURE;
		#endif

		outColor = TONEMAP(outColor);

		// debug hook
		#if 0
			//outColor = ambientContrib;
			//outColor = vec3( NdotV );
			//outColor = LINEARtoSRGB(FresnelSchlick(F0, F90, NdotV));
		#endif

		#if (deferred_mode == 0)
			fragData[0] = vec4(outColor, extraColor.a);
		#else
			outSpecularColor = TONEMAP(outSpecularColor);

			fragData[GBUFFER_NORMTEX_IDX] = vec4(SNORM2NORM(N), 1.0);
			fragData[GBUFFER_DIFFTEX_IDX] = vec4(outColor, extraColor.a);
			fragData[GBUFFER_SPECTEX_IDX] = vec4(outSpecularColor, extraColor.a);
			fragData[GBUFFER_EMITTEX_IDX] = vec4(vec3(emissiveness), 1.0);
			fragData[GBUFFER_MISCTEX_IDX] = vec4(float(MAT_IDX) / 255.0, 0.0, 0.0, 0.0);
		#endif

		%%FRAGMENT_POST_SHADING%%
	}
]],
	uniformInt = {
		textureS3o1  = 0,
		textureS3o2  = 1,
		shadowTex    = 2,
		reflectTex   = 3,
		normalMap    = 4,
		losMapTex    = 5,
		brdfLUT      = 6,
		envLUT       = 7,
	},
	uniformFloat = {
		mapSize = {Game.mapSizeX, Game.mapSizeZ},
	},
}