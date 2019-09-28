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

	#ifdef flashlights
		out float selfIllumMod;
	#endif
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

	out vec2 tex_coord0;
	out vec4 tex_coord1;
	out vec4 modelPos;
	out vec4 worldPos;

	void main(void)
	{
		vec4 vertex = gl_Vertex;
		vec3 normal = gl_Normal;

		%%VERTEX_PRE_TRANSFORM%%

		vec3 tangent   = gl_MultiTexCoord5.xyz;
		vec3 bitangent = gl_MultiTexCoord6.xyz;

		worldTangent = gl_NormalMatrix * tangent;
		worldBitangent = gl_NormalMatrix * bitangent;
		worldNormal = gl_NormalMatrix * normal;

		modelPos = vertex;
		worldPos = gl_ModelViewMatrix * vertex;
		gl_Position = gl_ProjectionMatrix * (camera * worldPos);
		viewDir = cameraPos - worldPos.xyz;

		#ifdef use_shadows
			tex_coord1 = shadowMatrix * worldPos;
			#if 1
				tex_coord1.xy = tex_coord1.xy + 0.5;
			#else
				tex_coord1.xy *= (inversesqrt(abs(tex_coord1.xy) + shadowParams.zz) + shadowParams.ww);
				tex_coord1.xy += shadowParams.xy;
			#endif
		#endif

		#ifdef use_treadoffset
			tex_coord0.st = gl_MultiTexCoord0.st;
			const vec4 treadBoundaries = vec4(0.6279296875, 0.74951171875, 0.5702890625, 0.6220703125);
			if (all(bvec4(
					tex_coord0.s >= treadBoundaries.x, tex_coord0.s <= treadBoundaries.y,
					tex_coord0.t >= treadBoundaries.z, tex_coord0.t <= treadBoundaries.w))) {
				tex_coord0.s = gl_MultiTexCoord0.s + etcLoc.z;
			}
		#endif

		#ifdef use_vertex_ao
			aoTerm = clamp(1.0 * fract(gl_MultiTexCoord0.s * 16384.0), 0.1, 1.0);
		#else
			aoTerm = 1.0;
		#endif

		#ifndef use_treadoffset
			tex_coord0.st = gl_MultiTexCoord0.st;
		#endif

		#ifdef flashlights
			// gl_ModelViewMatrix[3][0] + gl_ModelViewMatrix[3][2] are Tx, Tz elements of translation of matrix
			selfIllumMod = max(-0.2, sin(simFrame * 0.063 + (gl_ModelViewMatrix[3][0] + gl_ModelViewMatrix[3][2]) * 0.1)) + 0.2;
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
	#line 20117

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
	uniform samplerCube specularTex;
	uniform samplerCube reflectTex;

	uniform vec3 sunPos; //light direction in fact
	#define lightDir sunPos

	uniform vec3 sunDiffuse;
	uniform vec3 sunAmbient;
	uniform vec3 sunSpecular;

	uniform vec3 etcLoc;
	uniform int simFrame;

	#ifndef SPECULARMULT
		#define SPECULARMULT 2.0
	#endif

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

	#ifdef use_shadows
		uniform sampler2DShadow shadowTex;
	#endif
	uniform float shadowDensity;

	in float aoTerm;

	uniform vec4 teamColor;
	in vec3 viewDir;
	//varying float fogFactor;

	#ifdef flashlights
		in float selfIllumMod;
	#endif


	#ifdef use_normalmapping
		uniform sampler2D normalMap;
	#endif

	#ifdef USE_LOSMAP
		uniform vec2 mapSize;
		uniform float inLosMode;
		uniform sampler2D losMapTex;
	#endif

	in vec3 worldTangent;
	in vec3 worldBitangent;
	in vec3 worldNormal;

	in vec2 tex_coord0;
	in vec4 tex_coord1;
	in vec4 worldPos;
	in vec4 modelPos;

	#if (deferred_mode == 1)
		out vec4 fragData[GBUFFER_COUNT];
	#else
		out vec4 fragData[1];
	#endif

	const float PI = 3.1415926535897932384626433832795;
	const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

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
	#if 1
		#define GAMMA 2.2
		#define INV_GAMMA 1.0 / GAMMA
		#define SRGBtoLINEAR(c) ( pow(c, vec3(GAMMA)) )
		#define LINEARtoSRGB(c) ( pow(c, vec3(INV_GAMMA)) )
		//#define LINEARtoSRGB(c) ( c )
		#define TONEMAP(c) ACESFilmicTM(c)
	#else
		#define SRGBtoLINEAR(c) ( c )
		#define LINEARtoSRGB(c) ( c )
		#define TONEMAP(c) (c)
	#endif

	// http://blog.marmakoide.org/?p=1
	const float goldenAngle = PI * (3.0 - sqrt(5.0));
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

	vec3 SampleEnvironmentWithRoughness(vec3 samplingVec, float roughness) {
		int reflectTexSize = textureSize(reflectTex, 0).x;
		float maxLodLevel = log2(float(reflectTexSize));

		// makes roughness of reflection scale perceptually much more linear
		// Assumes "CubeTexSizeReflection" = 2048
		maxLodLevel -= 5.0;

		float lodBias = maxLodLevel * roughness;

		vec3 reflection = SRGBtoLINEAR(texture(reflectTex, samplingVec, lodBias).rgb);

		return reflection;
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

	float GetShadowPCFRandom() {
		float shadow = 0.0;

		vec3 shadowCoord = tex_coord1.xyz / tex_coord1.w;

		vec2 dZduv = DepthGradient(shadowCoord.xyz);

		#if defined(SHADOW_SAMPLES) && (SHADOW_SAMPLES > 1)


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
			vec3 shadowSamplingCoord = vec3(shadowCoord.xy, BiasedZ(shadowCoord.z, dZduv, vec2(0.0)));
			shadow = texture( shadowTex, shadowSamplingCoord );
		#endif
		return shadow;
	}
#endif


	vec3 SpherePoints_GoldenAngle(float i, float numSamples) {
		float theta = i * goldenAngle;
		float z = (1.0 - 1.0 / numSamples) * (1.0 - 2.0 * i / (numSamples - 1.0));
		float radius = sqrt(1.0 - z * z);
		return vec3(radius * vec2(cos(theta), sin(theta)), z);
	}

	#define ENV_SMPL_NUM 32
	void textureEnvBlured(in vec3 N, in vec3 Rv, out vec3 iblDiffuse, out vec3 iblSpecular, out float avgDiffLum) {
		iblDiffuse = vec3(0.0);
		iblSpecular = vec3(0.0);
		avgDiffLum = 0.0;

		vec2 sum = vec2(0.0);

		vec2 ts = vec2(textureSize(reflectTex, 0));
		float maxMipMap = log2(max(ts.x, ts.y));

		vec2 lodBias = vec2(maxMipMap - 2.0, 2.0);

		for (int i=0; i < ENV_SMPL_NUM; ++i) {
			vec3 sp = SpherePoints_GoldenAngle(float(i), float(ENV_SMPL_NUM));

			vec2 w = vec2(
					dot(sp, N ) * 0.5 + 0.5,
					dot(sp, Rv) * 0.5 + 0.5);

			w = pow(w, vec2(2.0, 6.0));

			vec3 iblD = SRGBtoLINEAR(texture(reflectTex, sp, lodBias.x).rgb);
			vec3 iblS = SRGBtoLINEAR(texture(reflectTex, sp, lodBias.y).rgb);

			avgDiffLum  += dot(LUMA, iblD);

			iblDiffuse  += iblD * w.x;
			iblSpecular += iblS * w.y;

			sum += w;
		}

		iblDiffuse  /= sum.x;
		iblSpecular /= sum.y;
		avgDiffLum  /= float(ENV_SMPL_NUM);

	}
	#undef ENV_SMPL_NUM

	float GetSpecularBlinnPhong(float NdotH, float roughness) {
		float power = 2.0 / max(roughness * 0.25, 0.01);
		float powerNorm = (power + 8.0) / 128.0;

		//float power = 16.0 / max(roughness * 0.25, 0.005);
		//float powerNorm = power / 200.0;

		return pow(NdotH, power) * powerNorm;
	}

	float G1V(float dotX, float k ) {
		return 1.0 / (dotX * (1.0 - k) + k);
	}

	float GGX(float NdotL, float NdotV, float NdotH, float LdotH, float roughness, float F0) {
		float alpha = roughness * roughness;

		float D, G, F;

		// NDF : GGX
		{
			float alphaSqr = alpha * alpha;
			float denom = NdotH * NdotH * (alphaSqr - 1.0) + 1.0;
			D = alphaSqr / (PI * denom * denom);
		}

		// Fresnel (Schlick)
		{
			float Fs = pow(1.0 - LdotH, 5.0);
			F = F0 + (1.0 - F0) * Fs;
		}

		// Visibility term (G) : Smith with Schlick's approximation
		float k = alpha / 2.0;
		G = G1V(NdotL, k) * G1V (NdotV, k);

		return NdotL * D * F * G;
	}


	//https://mynameismjp.wordpress.com/2010/04/30/a-closer-look-at-tone-mapping/ (comments by STEVEM)
	vec3 SteveMTM1(in vec3 x) {
		const float a = 10.0; /// Mid
		const float b = 0.3; /// Toe
		const float c = 0.5; /// Shoulder
		const float d = 1.5; /// Mid

		return (x * (a * x + b)) / (x * (a * x + c) + d);
	}

	vec3 FilmicTM(in vec3 x) {
		vec3 outColor = max(vec3(0.0), x - vec3(0.004));
		return (outColor * (6.2 * outColor + 0.5)) / (outColor * (6.2 * outColor + 1.7) + 0.06);
	}

	vec3 ACESFilmicTM(in vec3 x) {
		float a = 2.51;
		float b = 0.03;
		float c = 2.43;
		float d = 0.59;
		float e = 0.14;
		return (x * (a * x + b)) / (x * (c * x + d) + e);
	}

	// RNM - Already unpacked
	// https://www.shadertoy.com/view/4t2SzR
	vec3 NormalBlendUnpackedRNM(vec3 n1, vec3 n2) {
		n1 += vec3(0.0, 0.0, 1.0);
		n2 *= vec3(-1.0, -1.0, 1.0);

		return n1 * dot(n1, n2) / n1.z - n2;
	}

	const float angleEPS = 1e-3;

	void main(void){
		%%FRAGMENT_PRE_SHADING%%
		#line 20469

		#ifdef use_normalmapping
			vec2 tc = tex_coord0.st;
			#ifdef flip_normalmap
				tc.t = 1.0 - tc.t;
			#endif
			vec4 normaltex = texture(normalMap, tc);
			vec3 nvTS = normalize(NORM2SNORM(normaltex.xyz));
		#else
			vec3 nvTS = vec3(0.0, 0.0, 1.0);
		#endif

		mat3 worldTBN = mat3(
			normalize(worldTangent),
			normalize(worldBitangent),
			normalize(worldNormal)
		);

		vec4 diffuseColIn = texture(textureS3o1, tex_coord0.st);
		vec4 extraColor   = texture(textureS3o2, tex_coord0.st);

		float emissiveness = extraColor.r;

		float roughness    = extraColor.b;
		//roughness = SNORM2NORM( sin(simFrame * 0.1) );

		float metalness    = extraColor.g;

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
		float NdotL = max(NdotLu, angleEPS);
		float NdotH = max(dot(H, N), angleEPS);
		float NdotV = max(dot(N, V), angleEPS);
		float LdotH = max(dot(L, H), angleEPS);

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

        // fresnel
		float fresnel;
		{
			float fresnelPow = mix(5.0, 3.5, metalness);
			fresnel = max(1.0 - NdotV, 0.0);
			fresnel = pow(fresnel, fresnelPow);
		}

		// IBL
		vec3 iblDiffuse;
		vec3 iblSpecular;
		vec3 ambientColor;
		{
			float avgDiffLum;
			textureEnvBlured(N, Rv, iblDiffuse, iblSpecular, avgDiffLum);
			#if 0
				vec3 iblDiffuseYCbCr = RGB2YCBCR * iblDiffuse;
				//iblDiffuseYCbCr.x *= dot(LUMA, sunAmbient) / avgDiffLum;
				iblDiffuseYCbCr.x = dot(LUMA, sunAmbient);
				iblDiffuse = YCBCR2RGB * iblDiffuseYCbCr;
				ambientColor = aoTerm * iblDiffuse;
			#else
				ambientColor = aoTerm * sunAmbient;
			#endif
		}


		// environment reflection
		vec3 reflection;
		{
			reflection = SampleEnvironmentWithRoughness(Rv, roughness);
			//reflection = SRGBtoLINEAR(texture(reflectTex, Rv).rgb);
			//reflection = mix(reflection, iblSpecular, (1.0 - fresnel) * roughness);
			//reflection = mix(reflection, iblSpecular, roughness);
		}
		reflection += vec3(emissiveness);


		// shadows
		float shadowMult;
		{
			float nShadowMix = smoothstep(0.0, 0.35, NdotLu);
			float nShadow = mix(1.0, nShadowMix, shadowDensity);

			#ifdef use_shadows
				float gShadow = GetShadowPCFRandom();
			#else
				float gShadow = 1.0;
			#endif

			shadowMult = mix(1.0, min(nShadow, gShadow), shadowDensity);
		}

		float spec;
		{
			#if 0
				spec = GetSpecularBlinnPhong(NdotH, roughness);
			#else
				spec = GGX(NdotL, NdotV, NdotH, LdotH, roughness * 0.7, 0.04);
			#endif
		}

		vec3 outColor;
		vec3 diffuseColor;
		vec3 specularColor;
		{
			specularColor = SPECULARMULT * spec * sunSpecular * shadowMult;
			diffuseColor  = sunDiffuse * NdotL * shadowMult;

			outColor  = diffuseColor;
			outColor  = mix(outColor, reflection, fresnel  );
			outColor  = mix(outColor, reflection, metalness);
			outColor += ambientColor;

			outColor *= albedoColor;

			outColor += specularColor;
		}

		#ifdef USE_LOSMAP
			float losValue = 0.5 + texture(losMapTex, worldPos.xz / mapSize).r;
			losValue = mix(1.0, losValue, inLosMode);

			outColor *= losValue;
			specularColor.rgb *= losValue;
			extraColor.r *= losValue;
		#endif

		outColor = TONEMAP(outColor);
		outColor = LINEARtoSRGB(outColor);

		// debug hook
		#if 0
			//outColor = vec3(metalness);
			outColor = vec3(aoTerm*sunAmbient);
		#endif

		#if (deferred_mode == 0)
			fragData[0] = vec4(outColor, extraColor.a);
		#else
			specularColor = TONEMAP(specularColor);
			specularColor = LINEARtoSRGB(specularColor);

			fragData[GBUFFER_NORMTEX_IDX] = vec4(SNORM2NORM(N), 1.0);
			fragData[GBUFFER_DIFFTEX_IDX] = vec4(outColor, extraColor.a);
			fragData[GBUFFER_SPECTEX_IDX] = vec4(specularColor, extraColor.a);
			fragData[GBUFFER_EMITTEX_IDX] = vec4(extraColor.rrr, 1.0);
			fragData[GBUFFER_MISCTEX_IDX] = vec4(float(MAT_IDX) / 255.0, 0.0, 0.0, 0.0);
		#endif

		%%FRAGMENT_POST_SHADING%%
	}
]],
	uniformInt = {
		textureS3o1 = 0,
		textureS3o2 = 1,
		shadowTex   = 2,
		reflectTex  = 4,
		normalMap   = 5,
		losMapTex   = 6,
	},
	uniformFloat = {
		sunAmbient = {gl.GetSun("ambient" ,"unit")},
		sunDiffuse = {gl.GetSun("diffuse" ,"unit")},
		sunSpecular = {gl.GetSun("specular" ,"unit")},
		shadowDensity = gl.GetSun("shadowDensity" ,"unit"),
		mapSize = {Game.mapSizeX, Game.mapSizeZ},
	},
}
