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



	#define NORM2SNORM(value) (value * 2.0 - 1.0)
	#define SNORM2NORM(value) (value * 0.5 + 0.5)


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
			//outColor = vec3(1.0);
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