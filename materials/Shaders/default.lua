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

	uniform vec3 sunDiffuse;
	uniform vec3 sunAmbient;
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

	#ifdef use_vertex_ao
		out float aoTerm;
	#endif

	out vec3 viewDir;

	#ifdef use_normalmapping
		out mat3 tbnMatrix;
	#else
		out vec3 normalv;
	#endif

	out vec2 tex_coord0;
	out vec4 tex_coord1;
	out vec4 worldPos;

	void main(void)
	{
		vec4 vertex = gl_Vertex;
		vec3 normal = gl_Normal;

		%%VERTEX_PRE_TRANSFORM%%

		#ifdef use_normalmapping
			vec3 tangent   = gl_MultiTexCoord5.xyz;
			vec3 bitangent = gl_MultiTexCoord6.xyz;
			tbnMatrix = gl_NormalMatrix * mat3(tangent, bitangent, normal);
		#else
			normalv = gl_NormalMatrix * normal;
		#endif

		worldPos = gl_ModelViewMatrix * vertex;
		gl_Position   = gl_ProjectionMatrix * (camera * worldPos);
		viewDir     = cameraPos - worldPos.xyz;

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
			aoTerm = max(0.4, fract(gl_MultiTexCoord0.s * 16384.0) * 1.3); // great
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
	#line 20120

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
		#define SPECULARMULT 1.0
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

	#ifdef use_vertex_ao
		in float aoTerm;
	#endif

	uniform vec4 teamColor;
	in vec3 viewDir;
	//varying float fogFactor;

	#ifdef flashlights
		in float selfIllumMod;
	#endif

	#ifdef use_normalmapping
		in mat3 tbnMatrix;
		uniform sampler2D normalMap;
		#define normalv tbnMatrix[2]
	#else
		in vec3 normalv;
	#endif

	#ifdef USE_LOSMAP
		uniform vec2 mapSize;
		uniform float inLosMode;
		uniform sampler2D losMapTex;
	#endif

	in vec2 tex_coord0;
	in vec4 tex_coord1;
	in vec4 worldPos;

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

	float hash12(vec2 p) {
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

	float GetShadowPCFRandom() {
		float shadow = 0.0;

		vec3 shadowCoord = tex_coord1.xyz / tex_coord1.w;

		vec2 dZduv = DepthGradient(shadowCoord.xyz);

		#if defined(SHADOW_SAMPLES) && (SHADOW_SAMPLES > 1)


			float rndRotAngle = NORM2SNORM(hash12(gl_FragCoord.xy)) * PI / 2.0 * SHADOW_RANDOMNESS;

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

		return mix(1.0, shadow, shadowDensity);
	}
#endif

	// From PBR branch

	// Normal (Microfacet) Distribution function --------------------------------------
	// Standard across every implementation so far
	float D_GGX(float NdotH, float roughness4) {
		float denom = NdotH * NdotH * (roughness4 - 1.0) + 1.0;
		return roughness4/(PI * denom * denom);
	}

	float G_SchlickSmithGGX(float NdotL, float NdotV, float roughness) {
		float k = roughness + 1.0;
		k = k * k / 8.0;
		float GL = NdotL / (NdotL * (1.0 - k) + k);
		float GV = NdotV / (NdotV * (1.0 - k) + k);
		return GL * GV;
	}

	vec3 F_Schlick(float VdotX, vec3 R0) {
		return R0 + (vec3(1.0) - R0) * pow(1.0 - VdotX, 5.0);
	}

	void main(void){
		%%FRAGMENT_PRE_SHADING%%
		#line 20340

		#ifdef use_normalmapping
			vec2 tc = tex_coord0.st;
			#ifdef flip_normalmap
				tc.t = 1.0 - tc.t;
			#endif
			vec4 normaltex = texture(normalMap, tc);
			vec3 nvTS = normalize(NORM2SNORM(normaltex.xyz));
			vec3 N = tbnMatrix * nvTS;
		#else
			vec3 N = normalize(normalv);
		#endif

		vec4 diffuseIn  = texture(textureS3o1, tex_coord0.st);

		#ifdef LUMAMULT
			vec3 yCbCr = RGB2YCBCR * diffuseIn.rgb;
			yCbCr.x *= LUMAMULT;
			diffuseIn.rgb = YCBCR2RGB * yCbCr;
		#endif
		diffuseIn.rgb = mix(diffuseIn.rgb, teamColor.rgb, diffuseIn.a);

		vec4 extraColor = texture(textureS3o2, tex_coord0.st);

		vec3 V = normalize(viewDir);
		vec3 Rv = -reflect(V, N);
		vec3 L = normalize(lightDir);

		vec3 H = normalize(L + V);
		float NdotLu = dot(N, L);
		float NdotL = max(NdotLu, 1e-3);
		float HdotN = max(dot(H, N), 1e-3);
		float NdotV = max(dot(N, V), 1e-3);
		float VdotH = max(dot(V, H), 0.0);

		float roughness = extraColor.b;
		roughness = clamp(roughness, 0.05, 1.0);

		float roughness4 = roughness * roughness;
		roughness4 *= roughness4;

		vec3 R0 = mix(vec3(0.04), diffuseIn.rgb, extraColor.g);

		vec3 F = F_Schlick(VdotH, R0);
		float G = G_SchlickSmithGGX(NdotL, NdotV, roughness4);
		float D = D_GGX(HdotN, roughness4);


		vec3 light = (vec3(1.0) - F) * (NdotL * sunDiffuse / PI) + sunAmbient;

		vec3 specularColor;
		specularColor = D * F * G / (4.0 * NdotL * NdotV);
		specularColor *= SPECULARMULT * sunSpecular;

		ivec2 reflectionTexSize = textureSize(reflectTex, 0);
		float reflectionTexMaxLOD = log2(float(max(reflectionTexSize.x, reflectionTexSize.y)));
		float lodBias = reflectionTexMaxLOD * roughness;
		vec3 reflection = texture(reflectTex,  Rv, lodBias).rgb;

		float nShadowMix = smoothstep(0.0, 0.35, NdotLu);
		float nShadow = mix(1.0, nShadowMix, shadowDensity);

		#ifdef use_shadows
			float gShadow = GetShadowPCFRandom();
		#else
			float gShadow = 1.0;
		#endif

		float shadow = min(nShadow, gShadow);

		light = mix(sunAmbient, light, shadow);
		specularColor *= shadow;

		//reflection = mix(light, reflection, extraColor.g); // reflection
		//reflection = light + reflection * extraColor.g; // reflection
		reflection = light + reflection * R0; // reflection


		#ifdef flashlights
			extraColor.r = extraColor.r * selfIllumMod;
		#endif

		reflection += (extraColor.rrr); // self-illum

		vec4 outColor = diffuseIn;
		outColor.rgb = outColor.rgb * reflection + specularColor;
		outColor.a   = extraColor.a;

		#ifdef use_vertex_ao
			outColor.rgb = outColor.rgb * aoTerm;
		#endif

		#ifdef USE_LOSMAP
			float losValue = 0.5 + texture(losMapTex, worldPos.xz / mapSize).r;
			losValue = mix(1.0, losValue, inLosMode);

			outColor.rgb *= losValue;
			specularColor.rgb *= losValue;
			extraColor.r *= losValue;
		#endif

		// debug hook
		#if 0
			//outColor.rgb = vec3(normalv);
			outColor.rgb = vec3(N);
		#endif

		#if (deferred_mode == 0)
			fragData[0] = outColor;
		#else
			fragData[GBUFFER_NORMTEX_IDX] = vec4(SNORM2NORM(N), 1.0);
			fragData[GBUFFER_DIFFTEX_IDX] = outColor;
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
