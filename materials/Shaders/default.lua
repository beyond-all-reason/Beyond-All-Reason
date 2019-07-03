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

	out mat3 tbnMatrix;
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
		tbnMatrix = gl_NormalMatrix * mat3(tangent, bitangent, normal);

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
	#line 20180

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


	#define normalv tbnMatrix[2]
	#ifdef use_normalmapping
		uniform sampler2D normalMap;
	#endif

	#ifdef USE_LOSMAP
		uniform vec2 mapSize;
		uniform float inLosMode;
		uniform sampler2D losMapTex;
	#endif

	in mat3 tbnMatrix;
	in vec2 tex_coord0;
	in vec4 tex_coord1;
	in vec4 worldPos;
	in vec4 modelPos;

	#if (deferred_mode == 1)
		out vec4 fragData[GBUFFER_COUNT];
	#else
		out vec4 fragData[1];
	#endif

	const float PI = acos(0.0) * 2.0;

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

	vec3 GetSpecularBlinnPhong(float HdotN, float roughness) {
		float power = 1.0 / max(roughness * 0.4, 0.01);
		float powerNorm = (power + 8.0) / (PI * 8.0);
		return sunSpecular * pow(HdotN, power) * powerNorm;
	}

	//https://mynameismjp.wordpress.com/2010/04/30/a-closer-look-at-tone-mapping/ (comments by STEVEM)
	vec3 SteveMTM1(in vec3 x) {
		const float a = 10.0; /// Mid
		const float b = 0.3; /// Toe
		const float c = 0.5; /// Shoulder
		const float d = 1.5; /// Mid

		return (x * (a * x + b)) / (x * (a * x + c) + d);
	}

	// RNM - Already unpacked
	// https://www.shadertoy.com/view/4t2SzR
	vec3 NormalBlendUnpackedRNM(vec3 n1, vec3 n2) {
		n1 += vec3(0.0, 0.0, 1.0);
		n2 *= vec3(-1.0, -1.0, 1.0);

		return n1 * dot(n1, n2) / n1.z - n2;
	}

	// gamma correction
	#if 1
		#define GAMMA 2.2
		#define INV_GAMMA 1.0 / GAMMA
		#define SRGBtoLINEAR(c) ( pow(c, vec3(GAMMA)) )
		#define LINEARtoSRGB(c) ( pow(c, vec3(INV_GAMMA)) )
	#else
		#define SRGBtoLINEAR(c) ( c )
		#define LINEARtoSRGB(c) ( c )
	#endif

	const float angleEPS = 1e-3;

	void main(void){
		%%FRAGMENT_PRE_SHADING%%
		#line 20370

		#ifdef use_normalmapping
			vec2 tc = tex_coord0.st;
			#ifdef flip_normalmap
				tc.t = 1.0 - tc.t;
			#endif
			vec4 normaltex = texture(normalMap, tc, -2.0);
			vec3 nvTS = normalize(NORM2SNORM(normaltex.xyz));

		#else
			vec3 nvTS = vec3(0.0, 0.0, 1.0);
		#endif

		vec4 diffuseIn  = texture(textureS3o1, tex_coord0.st);
		vec4 extraColor = texture(textureS3o2, tex_coord0.st);

		float roughness = extraColor.b;
		//roughness = 0.5;
		//roughness = SNORM2NORM(sin(simFrame * 0.1));
		float metalness = extraColor.g;

		#if defined(ROUGHNESS_PERTURB_NORMAL) || defined(ROUGHNESS_PERTURB_COLOR)
			vec3 seedVec = modelPos.xyz * 4.0;
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

		vec3 N = normalize(tbnMatrix * nvTS);

		vec3 L = normalize(lightDir); //just in case
		vec3 V = normalize(viewDir);
		vec3 Rv = -reflect(V, N);
		vec3 H = normalize(L + V);

		float NdotLu = dot(N, L);
		float NdotL = max(NdotLu, angleEPS);
		float NdotH = max(dot(H, N), angleEPS);

		#ifdef LUMAMULT
			vec3 yCbCr = RGB2YCBCR * diffuseIn.rgb;
			#if defined(LUMAMULT)
				yCbCr.x *= LUMAMULT;
			#endif
		#endif

		vec3 outColor = mix(diffuseIn.rgb, teamColor.rgb, diffuseIn.a);

		outColor = SRGBtoLINEAR(outColor);

		#if defined(ROUGHNESS_PERTURB_COLOR)
			float colorPerturbScale = mix(0.0, ROUGHNESS_PERTURB_COLOR, roughness);
			outColor *= (1.0 - colorPerturbScale * rndValue); //try cheap way first (no RGB2YCBCR / YCBCR2RGB)
		#endif


		vec3 specularColor = vec3(0.0);
		if (NdotL > angleEPS) {
			specularColor = GetSpecularBlinnPhong(NdotH, roughness);
		}

		specularColor *= metalness * SPECULARMULT;

		// environment reflection
		ivec2 reflectTexSize = textureSize(reflectTex, 0);
		float reflectTexMaxLOD = log2(float(max(reflectTexSize.x, reflectTexSize.y)));
		float lodBias = reflectTexMaxLOD * roughness;

		vec3 reflection = mix(
			textureLod(reflectTex, Rv, lodBias).rgb,
			texture(reflectTex, Rv, lodBias).rgb,
			0.5);

		float nShadowMix = smoothstep(0.0, 0.35, NdotLu);
		float nShadow = mix(1.0, nShadowMix, shadowDensity);

		#ifdef use_shadows
			float gShadow = GetShadowPCFRandom();
		#else
			float gShadow = 1.0;
		#endif

		float shadow = mix(1.0, min(nShadow, gShadow), shadowDensity);

		vec3 light = aoTerm * sunAmbient + NdotL * sunDiffuse * shadow;
		specularColor *= shadow;

		reflection = mix(light, reflection, metalness); // reflection
		//reflection = light + reflection * metalness;

		#ifdef flashlights
			extraColor.r = extraColor.r * selfIllumMod;
		#endif

		reflection += (extraColor.rrr); // self-illum

		outColor = outColor * reflection + specularColor;

		#ifdef USE_LOSMAP
			float losValue = 0.5 + texture(losMapTex, worldPos.xz / mapSize).r;
			losValue = mix(1.0, losValue, inLosMode);

			outColor *= losValue;
			specularColor.rgb *= losValue;
			extraColor.r *= losValue;
		#endif

		outColor = SteveMTM1(outColor);
		outColor = LINEARtoSRGB(outColor);

		// debug hook
		#if 0
			outColor = vec3(roughness);
		#endif

		#if (deferred_mode == 0)
			fragData[0] = vec4(outColor, extraColor.a);
		#else
			specularColor = SteveMTM1(specularColor);
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
		-- sunPos = {gl.GetSun("pos")}, -- material has sunPosLoc
		sunAmbient = {gl.GetSun("ambient" ,"unit")},
		sunDiffuse = {gl.GetSun("diffuse" ,"unit")},
		sunSpecular = {gl.GetSun("specular" ,"unit")},
		--sunSpecularExp = gl.GetSun("specularExponent"), -- this might return crazy values like 100.0, which are unapplicable for Phong/Blinn-Phong
		shadowDensity = gl.GetSun("shadowDensity" ,"unit"),
		-- shadowParams  = {gl.GetShadowMapParams()}, -- material has shadowParamsLoc
		mapSize = {Game.mapSizeX, Game.mapSizeZ},
	},
	uniformMatrix = {
		-- shadowMatrix = {gl.GetMatrixData("shadow")}, -- material has shadow{Matrix}Loc
	},
}
