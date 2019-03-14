return {
vertex = [[
	//#define use_normalmapping
	//#define flip_normalmap
	//#define use_shadows
	%%VERTEX_GLOBAL_NAMESPACE%%

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

	#ifdef use_treadoffset
		uniform float treadOffset;
	#endif

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

		vec4 worldPos = gl_ModelViewMatrix * vertex;
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
	#if (GL_FRAGMENT_PRECISION_HIGH == 1)
	// ancient GL3 ATI drivers confuse GLSL for GLSL-ES and require this
	precision highp float;
	#else
	precision mediump float;
	#endif

	%%FRAGMENT_GLOBAL_NAMESPACE%%
	#line 10116

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

	uniform int lightingModel;
	const float sunSpecularExp = 16.0;

	uniform vec3 etcLoc;

	#ifndef SPECULARMULT
		#define SPECULARMULT 2.0
	#endif

	#ifndef SHADOW_SAMPLES
		#define SHADOW_SAMPLES 2
	#endif

	#ifdef use_shadows
		uniform sampler2DShadow shadowTex;
		uniform float shadowDensity;
	#endif

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
	#else
		in vec3 normalv;
	#endif

	in vec2 tex_coord0;
	in vec4 tex_coord1;

	#if (deferred_mode == 1)
		out vec4 fragData[GBUFFER_COUNT];
	#else
		out vec4 fragData[1];
	#endif

	float GetShadowPCFGrid(float NdotL) {
		float shadow = 0.0;

		const float cb = 0.00005;
		float bias = cb * tan(acos(NdotL));
		bias = clamp(bias, 0.0, 5.0 * cb);

		vec4 shTexCoord = tex_coord1;
		shTexCoord.z -= bias;

		#if defined(SHADOW_SAMPLES) && (SHADOW_SAMPLES > 1)
			const int ssHalf = int(floor(float(SHADOW_SAMPLES) / 2.0));
			const float ssSum = float((ssHalf + 1) * (ssHalf + 1));

			for( int x = -ssHalf; x <= ssHalf; x++ ) {
				float wx = float(ssHalf - abs(x) + 1) / ssSum;
				for( int y = -ssHalf; y <= ssHalf; y++ ) {
					float wy = float(ssHalf - abs(y) + 1) / ssSum;
					shadow += wx * wy * textureProjOffset ( shadowTex, shTexCoord, ivec2(x, y) );
				}
			}
		#else
			shadow = textureProj( shadowTex, shTexCoord );
		#endif

		return mix(1.0, shadow, shadowDensity);
	}

	void main(void){
		%%FRAGMENT_PRE_SHADING%%
		#line 20212

		const float PI = acos(0.0) * 2.0;

		#define NORM2SNORM(value) (value * 2.0 - 1.0)
		#define SNORM2NORM(value) (value * 0.5 + 0.5)

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

		vec3 L = normalize(lightDir); //just in case

		float NdotLu = dot(N, L);
		float NdotL = max(NdotLu, 0.0);
		vec3 light = NdotL * sunDiffuse + sunAmbient;

		vec4 diffuseIn  = texture(textureS3o1, tex_coord0.st);
		vec4 outColor   = diffuseIn;
		vec4 extraColor = texture(textureS3o2, tex_coord0.st);

		vec3 V = normalize(viewDir);
		vec3 Rv = -reflect(V, N);

		vec3 specularColor;

		if (lightingModel == 1) { //blinn-phong
			vec3 H = normalize(L + V);
			float HdotN = max(dot(H, N), 0.0);
			specularColor = sunSpecular * pow(HdotN, sunSpecularExp);
		}
		else if (lightingModel == 2) { //phong
			vec3 Rl = -reflect(L, N);
			float VdotRl = max(dot(Rl, V), 0.0);
			specularColor = sunSpecular * min(1.0, (pow(VdotRl, sunSpecularExp) + pow(VdotRl, 3.0) * 0.15));
		}
		else {
			specularColor = texture(specularTex, Rv).rgb;
		}

		specularColor *= extraColor.g * SPECULARMULT;

		vec3 reflection = texture(reflectTex,  Rv).rgb;

		float nShadowMix = smoothstep(0.0, 0.35, NdotLu);
		float nShadow = mix(1.0, nShadowMix, shadowDensity);

		#ifdef use_shadows
			float gShadow = GetShadowPCFGrid(NdotL);
		#else
			float gShadow = 1.0;
		#endif

		float shadow = min(nShadow, gShadow);

		light     = mix(sunAmbient, light, shadow);
		specularColor *= shadow;

		reflection = mix(light, reflection, extraColor.g); // reflection

		#ifdef flashlights
			extraColor.r = extraColor.r * selfIllumMod;
		#endif

		reflection += (extraColor.rrr); // self-illum

		outColor.rgb = mix(outColor.rgb, teamColor.rgb, outColor.a);

		//#if (deferred_mode == 0)
			// diffuse + specularColor + envcube lighting
			// (reflection contains the NdotL term!)
			outColor.rgb = outColor.rgb * reflection + specularColor;
		//#endif

		outColor.a   = extraColor.a;
		//outColor.rgb = outColor.rgb + outColor.rgb * (normaltex.a - 0.5) * etcLoc.g; // no more wreck color blending

		#ifdef use_vertex_ao
			outColor.rgb = outColor.rgb * aoTerm;
		#endif

		#if (deferred_mode == 0)
			fragData[0] = outColor;
		#else
			fragData[GBUFFER_NORMTEX_IDX] = vec4(SNORM2NORM(N), 1.0);
			fragData[GBUFFER_DIFFTEX_IDX] = outColor;
			fragData[GBUFFER_SPECTEX_IDX] = vec4(specularColor, extraColor.a);
			fragData[GBUFFER_EMITTEX_IDX] = vec4(extraColor.rrr, 1.0);
			fragData[GBUFFER_MISCTEX_IDX] = vec4(0.0);
		#endif

		%%FRAGMENT_POST_SHADING%%
	}
]],

	uniformInt = {
		textureS3o1 = 0,
		textureS3o2 = 1,
		shadowTex   = 2,
		specularTex = 3,
		reflectTex  = 4,
		normalMap   = 5,
		--detailMap   = 6,

		lightingModel = 1,
	},
	uniformFloat = {
		-- sunPos = {gl.GetSun("pos")}, -- material has sunPosLoc
		sunAmbient = {gl.GetSun("ambient" ,"unit")},
		sunDiffuse = {gl.GetSun("diffuse" ,"unit")},
		sunSpecular = {gl.GetSun("specular" ,"unit")},
		--sunSpecularExp = gl.GetSun("specularExponent"), -- this might return crazy values like 100.0, which are unapplicable for Phong/Blinn-Phong
		shadowDensity = gl.GetSun("shadowDensity" ,"unit"),
		-- shadowParams  = {gl.GetShadowMapParams()}, -- material has shadowParamsLoc
	},
	uniformMatrix = {
		-- shadowMatrix = {gl.GetMatrixData("shadow")}, -- material has shadow{Matrix}Loc
	},
}
