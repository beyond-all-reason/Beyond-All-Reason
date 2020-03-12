local shaderTemplate = {
vertex = [[
	//shader version is added via gadget

	%%GLOBAL_NAMESPACE%%

	%%VERTEX_GLOBAL_NAMESPACE%%

	/***********************************************************************/
	#line 10010

	/***********************************************************************/
	// Options in use
	#define OPTION_SHADOWMAPPING 0
	#define OPTION_NORMALMAPPING 1
	#define OPTION_MOVING_THREADS 2
	#define OPTION_VERTEX_AO 3
	#define OPTION_FLASHLIGHTS 4
	#define OPTION_UNITSFOG 5
	#define OPTION_NORMALMAP_FLIP 6
	#define OPTION_METAL_HIGHLIGHT 7
	#define OPTION_TREEWIND 8
	#define OPTION_POM 9
	#define OPTION_AUTONORMAL 10

	%%GLOBAL_OPTIONS%%

	/***********************************************************************/
	// Definitions
	#define BITMASK_FIELD(value, pos) ((uint(value) & (1u << uint(pos))) != 0u)

	#define NORM2SNORM(value) (value * 2.0 - 1.0)
	#define SNORM2NORM(value) (value * 0.5 + 0.5)

	//For a moment let's pretend we have passed OpenGL 2.0 gl_XYZ era
	#define modelMatrix gl_ModelViewMatrix			// don't trust the ModelView name, it's modelMatrix in fact
	#define modelNormalMatrix gl_NormalMatrix		// gl_NormalMatrix seems to represent world space model matrix

	/***********************************************************************/
	// Matrix uniforms
	uniform mat4 viewMatrix;
	uniform mat4 projectionMatrix;
	uniform mat4 shadowMatrix;

	/***********************************************************************/
	// Uniforms
	uniform vec3 cameraPos; // world space camera position
	uniform vec3 cameraDir; // forward vector of camera

	uniform vec3 rndVec;
	uniform int simFrame;
	uniform int drawFrame;

	uniform float floatOptions[2];
	uniform int bitOptions;


	/***********************************************************************/
	// Varyings
	out Data {
		// TBN matrix components
		vec3 worldTangent;
		vec3 worldBitangent;
		vec3 worldNormal;
		// main light vector(s)
		vec3 worldCameraDir;

		// main textureCoord
		vec2 modelUV;

		// shadowPosition
		vec4 shadowVertexPos;

		// auxilary varyings
		vec4 addColor;
		float aoTerm;
		float selfIllumMod;
		float fogFactor;
	};

	/***********************************************************************/
	// Auxilary functions


	/***********************************************************************/
	// Vertex shader main()
	void main(void)
	{
		vec4 modelVertexPos = gl_Vertex;
		vec3 modelVertexNormal = gl_Normal;

		%%VERTEX_PRE_TRANSFORM%%

		modelUV = gl_MultiTexCoord0.xy;

		#if (RENDERING_MODE != 2) //non-shadow pass

			%%VERTEX_UV_TRANSFORM%%

			vec4 worldVertexPos = modelMatrix * modelVertexPos;
			/***********************************************************************/
			// Main vectors for lighting
			// V
			worldCameraDir = normalize(cameraPos - worldVertexPos.xyz); //from fragment to camera, world space

			if (BITMASK_FIELD(bitOptions, OPTION_SHADOWMAPPING)) {
				shadowVertexPos = shadowMatrix * worldVertexPos;
				shadowVertexPos.xy += vec2(0.5);  //no need for shadowParams anymore
			}

			if (BITMASK_FIELD(bitOptions, OPTION_NORMALMAPPING) || BITMASK_FIELD(bitOptions, OPTION_AUTONORMAL)) {
				//no need to do Gram-Schmidt re-orthogonalization, because engine does it for us anyway
				vec3 T = gl_MultiTexCoord5.xyz;
				vec3 B = gl_MultiTexCoord6.xyz;

				// tangent --> world space transformation (for vectors)
				worldTangent = modelNormalMatrix * T;
				worldBitangent = modelNormalMatrix * B;
				worldNormal = modelNormalMatrix * modelVertexNormal;
			} else {
				worldTangent = modelNormalMatrix * vec3(1.0, 0.0, 0.0);
				worldBitangent = modelNormalMatrix * vec3(0.0, 1.0, 0.0);
				worldNormal = modelNormalMatrix * modelVertexNormal;
			}

			if (BITMASK_FIELD(bitOptions, OPTION_VERTEX_AO)) {
				aoTerm = clamp(1.0 * fract(modelUV.x * 16384.0), 0.1, 1.0);
			} else {
				aoTerm = 1.0;
			}

			if (BITMASK_FIELD(bitOptions, OPTION_FLASHLIGHTS)) {
				// modelMatrix[3][0] + modelMatrix[3][2] are Tx, Tz elements of translation of matrix
				selfIllumMod = max(-0.2, sin(simFrame * 0.0667 + (modelMatrix[3][0] + modelMatrix[3][2]) * 0.1)) + 0.2;
			}

			gl_Position = projectionMatrix * viewMatrix * worldVertexPos;

			%%VERTEX_POST_TRANSFORM%%

		#else //shadow pass
			vec4 lightVertexPos = gl_ModelViewMatrix * modelVertexPos;
			vec3 lightVertexNormal = normalize(gl_NormalMatrix * modelVertexNormal);

			float NdotL = clamp(dot(lightVertexNormal, vec3(0.0, 0.0, 1.0)), 0.0, 1.0);

			//use old bias formula from GetShadowPCFRandom(), but this time to write down shadow depth map values
			const float cb = 5e-5;
			float bias = cb * tan(acos(NdotL));
			bias = clamp(bias, 0.0, 5.0 * cb);

			lightVertexPos.xy += vec2(0.5);
			lightVertexPos.z += bias;

			gl_Position = gl_ProjectionMatrix * lightVertexPos;
		#endif
	}
]],

fragment = [[
	//shader version is added via gadget

	#if (RENDERING_MODE == 2) //shadows pass. AMD requests that extensions are declared right on top of the shader
		#if (SUPPORT_DEPTH_LAYOUT == 1)
			//#extension GL_ARB_conservative_depth : enable
			//#extension GL_EXT_conservative_depth : enable
			// preserve early-z performance if possible
			//layout(depth_unchanged) out float gl_FragDepth;
		#endif
	#endif

	/***********************************************************************/
	// Options in use
	#define OPTION_SHADOWMAPPING 0
	#define OPTION_NORMALMAPPING 1
	#define OPTION_MOVING_THREADS 2
	#define OPTION_VERTEX_AO 3
	#define OPTION_FLASHLIGHTS 4
	#define OPTION_UNITSFOG 5
	#define OPTION_NORMALMAP_FLIP 6
	#define OPTION_METAL_HIGHLIGHT 7
	#define OPTION_TREEWIND 8
	#define OPTION_POM 9
	#define OPTION_AUTONORMAL 10

	%%GLOBAL_OPTIONS%%

	/***********************************************************************/
	// Definitions
	#define BITMASK_FIELD(value, pos) ((uint(value) & (1u << uint(pos))) != 0u)

	#define NORM2SNORM(value) (value * 2.0 - 1.0)
	#define SNORM2NORM(value) (value * 0.5 + 0.5)

	#if (RENDERING_MODE == 1)
		#define GBUFFER_NORMTEX_IDX 0
		#define GBUFFER_DIFFTEX_IDX 1
		#define GBUFFER_SPECTEX_IDX 2
		#define GBUFFER_EMITTEX_IDX 3
		#define GBUFFER_MISCTEX_IDX 4

		#define GBUFFER_COUNT 5
	#endif

	#line 20270


	/***********************************************************************/
	// Sampler uniforms
	uniform sampler2D texture1;
	uniform sampler2D texture2;
	uniform sampler2D normalTex;
	uniform samplerCube reflectTex;
	uniform sampler2DShadow shadowTex;

	/***********************************************************************/
	// Sunlight uniforms
	uniform vec3 sunDir;
	uniform vec3 sunDiffuse;
	uniform vec3 sunAmbient;
	uniform vec3 sunSpecular;


	/***********************************************************************/
	// Misc. uniforms
	uniform vec4 teamColor;
	uniform float shadowDensity;

	uniform vec4 pomParams;
	uniform vec2 autoNormalParams;

	uniform int shadowsQuality;
	uniform int materialIndex;

	uniform vec3 rndVec;
	uniform int simFrame;
	uniform int drawFrame;

	// PBR uniforms
	uniform float pbrParams[8];

	// Unit/Feature uniforms
	uniform float floatOptions[2];

	uniform int bitOptions;


	/***********************************************************************/
	// Shadow mapping quality params
	struct ShadowQuality {
		float samplingRandomness;	// 0.0 - blocky look, 1.0 - random points look
		float samplingDistance;		// how far shadow samples go (in shadowmap texels) as if it was applied to 8192x8192 sized shadow map
		int shadowSamples;			// number of shadowmap samples per fragment
	};

	#define SHADOW_QUALITY_PRESETS 4
	const ShadowQuality shadowQualityPresets[SHADOW_QUALITY_PRESETS] = ShadowQuality[](
		ShadowQuality(0.0, 0.0, 1),	// hard
		ShadowQuality(1.0, 1.0, 3),	// soft
		ShadowQuality(0.4, 2.0, 6),	// softer
		ShadowQuality(0.4, 3.0, 8)	// softest
	);


	%%FRAGMENT_GLOBAL_NAMESPACE%%


	/***********************************************************************/
	// Varyings
	in Data {
		// TBN matrix components
		vec3 worldTangent;
		vec3 worldBitangent;
		vec3 worldNormal;

		// main light vector(s)
		vec3 worldCameraDir;

		// main textureCoord
		vec2 modelUV;

		// shadowPosition
		vec4 shadowVertexPos;

		// auxilary varyings
		vec4 addColor;
		float aoTerm;
		float selfIllumMod;
		float fogFactor;
	};

	/***********************************************************************/
	// Constants
	const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

	//const float PI = acos(0.0) * 2.0;
	const float PI = 3.1415926535897932384626433832795;

	//const float goldenAngle = PI * (3.0 - sqrt(5.0));
	const float goldenAngle = 2.3999632297286533222315555066336;

	/***********************************************************************/
	// Shadow mapping functions

	// http://blog.marmakoide.org/?p=1
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

		return dZduv / det;
	}

	float BiasedZ(float z0, vec2 dZduv, vec2 offset) {
		return z0 + dot(dZduv, offset);
	}

	float GetShadowPCFRandom(float NdotL) {
		float shadow = 0.0;

		vec3 shadowCoord = shadowVertexPos.xyz; // shadowVertexPos.w is always 1.0
		int presetIndex = clamp(shadowsQuality, 0, SHADOW_QUALITY_PRESETS - 1);

		float samplingRandomness = shadowQualityPresets[presetIndex].samplingRandomness;
		float samplingDistance = shadowQualityPresets[presetIndex].samplingDistance;
		int shadowSamples = shadowQualityPresets[presetIndex].shadowSamples;

		if (shadowSamples > 1) {
			vec2 dZduv = DepthGradient(shadowCoord.xyz);

			float rndRotAngle = NORM2SNORM(hash12L(gl_FragCoord.xy)) * PI / 2.0 * samplingRandomness;

			vec2 vSinCos = vec2(sin(rndRotAngle), cos(rndRotAngle));
			mat2 rotMat = mat2(vSinCos.y, -vSinCos.x, vSinCos.x, vSinCos.y);

			vec2 filterSize = vec2(samplingDistance / 8192.0);

			for (int i = 0; i < shadowSamples; ++i) {
				// SpiralSNorm return low discrepancy sampling vec2
				vec2 offset = (rotMat * SpiralSNorm( i, shadowSamples )) * filterSize;

				vec3 shadowSamplingCoord = vec3(shadowCoord.xy, 0.0) + vec3(offset, BiasedZ(shadowCoord.z, dZduv, offset));
				//vec3 shadowSamplingCoord = vec3(shadowCoord.xy, 0.0) + vec3(offset, shadowCoord.z);
				shadow += texture( shadowTex, shadowSamplingCoord );
			}
			shadow /= float(shadowSamples);
		} else { //shadowSamples == 1
			#if 0
				const float cb = 0.00005;
				float bias = cb * tan(acos(NdotL));
				bias = clamp(bias, 0.0, 5.0 * cb);

				vec3 shadowSamplingCoord = shadowCoord;
				shadowSamplingCoord.z -= bias;

				shadow = texture( shadowTex, shadowSamplingCoord );
			#else
				shadow = texture( shadowTex, shadowCoord );
			#endif
		}
		return shadow;
	}


	#define GetDiffuseVal(tex, uv) length(texture(tex, fract(uv)).rgb)
	//#define GetDiffuseVal(tex, uv) dot(LUMA, texture(tex, uv).rgb)
	vec2 GetDiffuseGrad(vec2 uv, vec2 delta) {
		vec3 d = vec3(delta, 0.0);
		vec2 grad = vec2(
			GetDiffuseVal(texture1, uv + d.xz) - GetDiffuseVal(texture1, uv - d.xz),
			GetDiffuseVal(texture1, uv + d.zy) - GetDiffuseVal(texture1, uv - d.zy)
		);
		return grad / delta;
	}

	vec3 GetNormalFromDiffuse(vec2 uv) {
		vec2 texDim = vec2(textureSize(texture1, 0));
		return normalize(
			vec3(GetDiffuseGrad(uv, autoNormalParams.x / texDim), 1.0 / autoNormalParams.y)
		);
	}

	#define POM_SCALE pomParams.x
	#define POM_MINLAYERS pomParams.y
	#define POM_MAXLAYERS pomParams.z
	#define POM_LODBIAS pomParams.w
	#define GET_DISPLACEMENT_VALUE(coord) (1.0 - texture(normalTex, coord, POM_LODBIAS).w)

	vec2 ParallaxOcclusionMapping(vec2 uv, vec3 viewDir, float camDistNorm) {

		float oneDotVDZ = abs(dot(vec3(0.0, 0.0, 1.0), viewDir));
		float numLayers = POM_MAXLAYERS * (1.0 - oneDotVDZ) * camDistNorm;
		numLayers = ceil(numLayers);

		numLayers = clamp(numLayers, POM_MINLAYERS, POM_MAXLAYERS);

		// calculate the size of each layer
		float layerDepth = 1.0 / numLayers;

		// depth of current layer
		float currentLayerDepth = 0.0;

		vec2 Pn = viewDir.xy;
		vec2 Pp = Pn / viewDir.z;

		float Pmix = smoothstep(0.0, 0.4, oneDotVDZ);
		//float Pmix = step(0.5, oneDotVDZ);


		vec2 P = mix(Pn, Pp, Pmix) * POM_SCALE;

		vec2 deltaTexCoords = P / numLayers;

		// get initial values
		vec2  currentTexCoords     = uv;
		float currentDepthMapValue = GET_DISPLACEMENT_VALUE(currentTexCoords);

		int currentStep = int(numLayers);
		while(currentStep > 0) {
			// shift texture coordinates along direction of P
			currentTexCoords -= deltaTexCoords;

			// get depthmap value at current texture coordinates
			currentDepthMapValue = GET_DISPLACEMENT_VALUE(currentTexCoords);

			// get depth of next layer
			currentLayerDepth += layerDepth;
			if (currentLayerDepth >= currentDepthMapValue)
				break;

			currentStep--;
		}


		// get texture coordinates before collision (reverse operations)
		vec2 prevTexCoords = currentTexCoords + deltaTexCoords;


		// get depth after and before collision for linear interpolation
		float afterDepth  = currentDepthMapValue - currentLayerDepth;
		float beforeDepth = GET_DISPLACEMENT_VALUE(prevTexCoords) - currentLayerDepth + layerDepth;

		// interpolation of texture coordinates
		float weight = afterDepth / (afterDepth - beforeDepth);
		vec2 finalTexCoords = mix(currentTexCoords, prevTexCoords, weight);

		return finalTexCoords;
	}

	/***********************************************************************/
	// Shader output definitions
	#if (RENDERING_MODE == 1)
		out vec4 fragData[GBUFFER_COUNT];
	#else
		out vec4 fragData[1];
	#endif

	/***********************************************************************/

#if (RENDERING_MODE != 2) //non-shadow pass
	// Fragment shader main()
	void main(void){
		#line 30540

		vec2 myUV = modelUV;

		if (BITMASK_FIELD(bitOptions, OPTION_NORMALMAP_FLIP)) {
			myUV.y = 1.0 - myUV.y;
		}

		mat3 worldTBN;
		if (BITMASK_FIELD(bitOptions, OPTION_NORMALMAPPING) ||
			BITMASK_FIELD(bitOptions, OPTION_POM) ||
			BITMASK_FIELD(bitOptions, OPTION_AUTONORMAL))
		{
			worldTBN = mat3(worldTangent, worldBitangent, worldNormal);
		}

		if (BITMASK_FIELD(bitOptions, OPTION_POM)) {
			mat3 invWorldTBN = transpose(worldTBN);
			vec3 tbnV = invWorldTBN * normalize(worldCameraDir);

			float depthPomScale = 1.0 - smoothstep(15.0, 250.0, 1.0 / gl_FragCoord.w);
			myUV = ParallaxOcclusionMapping(myUV, tbnV, depthPomScale);

			bvec4 badTexCoords = bvec4(myUV.x > 1.0, myUV.y > 1.0, myUV.x < 0.0, myUV.y < 0.0);
			if (any(badTexCoords)) {
				discard;
			}
		}

		// N - worldFragNormal
		vec3 N;

		if (BITMASK_FIELD(bitOptions, OPTION_NORMALMAPPING)) {
			vec3 tbnNormal = NORM2SNORM(texture(normalTex, myUV).xyz);
			N = worldTBN * tbnNormal;
		} else if (BITMASK_FIELD(bitOptions, OPTION_AUTONORMAL)) {
			vec3 tbnNormal = GetNormalFromDiffuse(myUV);
			N = worldTBN * tbnNormal;
		} else {
			N = worldNormal;
		}

		N = normalize(N);

		if (BITMASK_FIELD(bitOptions, OPTION_NORMALMAP_FLIP)) {
			myUV.y = 1.0 - myUV.y;
		}

		vec4 texColor1 = texture(texture1, myUV);
		vec4 texColor2 = texture(texture2, myUV);

		// L - worldLightDir
		/// Sun light is considered infinitely far, so it stays same no matter worldVertexPos.xyz
		vec3 L = normalize(sunDir); //from fragment to light, world space

		// V - worldCameraDir
		vec3 V = normalize(worldCameraDir);

		// H - worldHalfVec
		vec3 H = normalize(L + V); //half vector

		// R - reflection of worldCameraDir against worldFragNormal
		vec3 Rv = -reflect(V, N);

		// N.L
		float NdotLu = dot(N, L);
		float NdotL = max(NdotLu, 1e-3);

		// N.H
		float HdotN = max(dot(N, H), 1e-3);

		// shadows
		float nShadow = smoothstep(0.0, 0.35, NdotLu); //normal based shadowing, always on
		float gShadow = 1.0; // shadow mapping
		if (BITMASK_FIELD(bitOptions, OPTION_SHADOWMAPPING)) {
			gShadow = GetShadowPCFRandom(NdotL);
		}
		float shadow = min(nShadow, gShadow);
		float shadowMult = mix(1.0, shadow, shadowDensity);

		// light
		vec3 lightAmbient = aoTerm * sunAmbient;
		vec3 lightDiffuse = NdotL * sunDiffuse;

		// sunSpecularParams = (exponent, multiplier, bias)
		vec3 lightSpecular = sunSpecular * pow(HdotN, sunSpecularParams.x);
		lightSpecular *= sunSpecularParams.z + texColor2.g * sunSpecularParams.y;

		// apply shadows
		vec3 lightAD = lightAmbient + lightDiffuse * shadowMult;
		lightSpecular *= shadowMult;

		// environment reflection
		vec3 lightADR = texture(reflectTex,  Rv).rgb;
		lightADR = mix(lightAD, lightADR, texColor2.g);

		// emissive color
		vec3 emissiveMult = texColor2.rrr;
		if (BITMASK_FIELD(bitOptions, OPTION_FLASHLIGHTS)) {
			emissiveMult *= selfIllumMod;
		}

		// final color
		vec3 modelDiffuseColor = mix(texColor1.rgb, teamColor.rgb, texColor1.a); //mix diffuse texture with team color
		vec3 finalColor = modelDiffuseColor.rgb * (lightADR + emissiveMult) + lightSpecular;

		if (BITMASK_FIELD(bitOptions, OPTION_UNITSFOG)) {
			finalColor = mix(gl_Fog.color.rgb, finalColor, fogFactor);
		}

		#define wreckMetal floatOptions[1]
		if (BITMASK_FIELD(bitOptions, OPTION_METAL_HIGHLIGHT) && wreckMetal > 0.0) {
			//finalColor = mix(finalColor, addColor.aaa, addColor.rgb);
			finalColor += addColor.a * addColor.rgb - lightSpecular;
		}
		#undef wreckMetal

		#if 0
			finalColor = vec3( GetNormalFromDiffuse(myUV));
		#endif

		#if (RENDERING_MODE == 0)
			fragData[0] = vec4(finalColor, texColor2.a);
		#else
			fragData[GBUFFER_NORMTEX_IDX] = vec4(SNORM2NORM(N), 1.0);
			fragData[GBUFFER_DIFFTEX_IDX] = vec4(modelDiffuseColor, texColor2.a);
			fragData[GBUFFER_SPECTEX_IDX] = vec4(lightSpecular, texColor2.a);
			fragData[GBUFFER_EMITTEX_IDX] = vec4(texColor2.rrr, 1.0);
			fragData[GBUFFER_MISCTEX_IDX] = vec4(float(materialIndex) / 255.0, 0.0, 0.0, 0.0);
		#endif
	}
#else //shadow pass
	void main(void){
		vec4 texColor2 = texture(texture2, modelUV);
		if (texColor2.a < 0.5)
			discard;

	}
#endif
]],
	uniformInt = {
		texture1 	= 0,
		texture2 	= 1,
		shadowTex	= 2,
		reflectTex	= 4,
		normalTex	= 5,
	},
	uniformFloat = {
		sunAmbient		= {gl.GetSun("ambient" ,"unit")},
		sunDiffuse		= {gl.GetSun("diffuse" ,"unit")},
		sunSpecular		= {gl.GetSun("specular" ,"unit")},
		shadowDensity	=  gl.GetSun("shadowDensity" ,"unit"),
	},
}

local defaultMaterialTemplate = {
	--standardUniforms --locs, set by api_cus
	--deferredUniforms --locs, set by api_cus

	shader   = shaderTemplate, -- `shader` is replaced with standardShader later in api_cus
	deferred = shaderTemplate, -- `deferred` is replaced with deferredShader later in api_cus
	shadow   = shaderTemplate, -- `shadow` is replaced with deferredShader later in api_cus

	shaderDefinitions = {
		"#define RENDERING_MODE 0",
	},
	deferredDefinitions = {
		"#define RENDERING_MODE 1",
	},
	shadowDefinitions = {
		"#define RENDERING_MODE 2",
		"#define SUPPORT_DEPTH_LAYOUT ".. tostring((Platform.glSupportFragDepthLayout and 1) or 0),
		"#define SUPPORT_CLIP_CONTROL ".. tostring((Platform.glSupportClipSpaceControl and 1) or 0),
	},

	shaderOptions = {
		shadowmapping 	= true,
		normalmapping 	= false,
		threads 		= false,
		vertex_ao 		= false,
		flashlights 	= false,
		unitsfog 		= false,
		normalmap_flip 	= false,
		metal_highlight = false,
		treewind 		= false,
		pom 			= false,
		autonormal 		= false,

		shadowsQuality	= 2,
		materialIndex	= 0,

		autoNormalParams = {1.0, 0.00200}, -- Sampling distance, autonormal value
		sunSpecularParams = {18.0, 4.0, 0.0}, -- Exponent, multiplier, bias
		pomParams = {0.002, 1.0, 24.0, -2.0}, -- scale, minLayers, maxLayers, lodBias
	},

	deferredOptions = {
		shadowmapping 	= true,
		normalmapping 	= false,
		threads 		= false,
		vertex_ao 		= false,
		flashlights 	= false,
		unitsfog 		= false,
		normalmap_flip 	= false,
		metal_highlight = false,
		treewind 		= false,
		pom 			= false,
		autonormal 		= false,

		shadowsQuality	= 0,
		materialIndex	= 0,

		sunSpecularParams = {18.0, 4.0, 0.0}, -- Exponent, multiplier, bias
	},

	shadowOptions = {
		treewind 		= false,
	},

	feature = false,

	texUnits = {
		[2] = "$shadow",
		[4] = "$reflection",
	},

	predl = nil, -- `predl` is replaced with `prelist` later in api_cus
	postdl = nil, -- `postdl` is replaced with `postlist` later in api_cus

	uuid = nil, -- currently unused (not sent to engine)
	order = nil, -- currently unused (not sent to engine)

	culling = GL.BACK, -- usually GL.BACK is default, except for 3do
	shadowCulling = GL.BACK,
	usecamera = false, -- usecamera ? {gl_ModelViewMatrix, gl_NormalMatrix} = {modelViewMatrix, modelViewNormalMatrix} : {modelMatrix, modelNormalMatrix}
}

local shaderPlugins = {
}


--[[
	#define OPTION_SHADOWMAPPING 0
	#define OPTION_NORMALMAPPING 1
	#define OPTION_MOVING_THREADS 2
	#define OPTION_VERTEX_AO 3
	#define OPTION_FLASHLIGHTS 4
	#define OPTION_UNITSFOG 5
	#define OPTION_NORMALMAP_FLIP 6
	#define OPTION_METAL_HIGHLIGHT 7
	#define OPTION_TREEWIND 8
	#define OPTION_POM 9
]]--

-- bit = (index - 1)
local knownBitOptions = {
	["shadowmapping"] = 0,
	["normalmapping"] = 1,
	["threads"] = 2,
	["vertex_ao"] = 3,
	["flashlights"] = 4,
	["unitsfog"] = 5,
	["normalmap_flip"] = 6,
	["metal_highlight"] = 7,
	["treewind"] = 8,
	["pom"] = 9,
	["autonormal"] = 10,
}

local knownIntOptions = {
	["shadowsQuality"] = 1,
	["materialIndex"] = 1,

}
local knownFloatOptions = {
	["autoNormalParams"] = 2,
	["pomParams"] = 4,
	["sunSpecularParams"] = 3,
}

local allOptions = nil

-- Lua limitations only allow to send 24 bits. Should be enough for now.
local function EncodeBitmaskField(bitmask, option, position)
	return math.bit_or(bitmask, ((option and 1) or 0) * math.floor(2 ^ position))
end

local function ProcessOptions(materialDef, optName, optValues)
	local handled = false

	if not materialDef.originalOptions then
		materialDef.originalOptions = {}
		materialDef.originalOptions[1] = Spring.Utilities.CopyTable(materialDef.shaderOptions)
		materialDef.originalOptions[2] = Spring.Utilities.CopyTable(materialDef.deferredOptions)
		materialDef.originalOptions[3] = Spring.Utilities.CopyTable(materialDef.shadowOptions)
	end

	for id, optTable in ipairs({materialDef.shaderOptions, materialDef.deferredOptions, materialDef.shadowOptions}) do
		if knownBitOptions[optName] then --boolean
			local optValue = unpack(optValues or {})
			local optOriginalValue = materialDef.originalOptions[id][optName]

			--Spring.Echo(optName, type(optValue), "optValue", optValue, "optOriginalValue", optOriginalValue)
			if optOriginalValue then
				if optValue ~= nil then
					if type(optValue) == "boolean" then
						optTable[optName] = optValue
					elseif type(tonumber(optValue)) == "number" then
						optTable[optName] = ((tonumber(optValue) > 0) and true) or false
					end
				else
					optTable[optName] = not optTable[optName] -- apparently `not nil` == true
				end
				--Spring.Echo("optTable[optName]", optTable[optName])
				handled = true
			end
		elseif knownIntOptions[optName] then --integer
			--TODO
			--handled = true
		elseif knownFloatOptions[optName] then --float
			--TODO
			--handled = true
		end
	end

	--Spring.Echo("ProcessOptions", optName, unpack(optValues))
	--Spring.Echo("ProcessOptions")
	return handled
end

local function ApplyOptions(luaShader, materialDef, key)

	local optionsTbl
	if key == 1 then
		optionsTbl = materialDef.shaderOptions
	elseif key == 2 then
		optionsTbl = materialDef.deferredOptions
	elseif key == 3 then
		optionsTbl = materialDef.shadowOptions
	end

	local intOption = 0

	--Spring.Utilities.TableEcho(optionsTbl, "optionsTbl")

	for optName, optValue in pairs(optionsTbl) do
		if knownBitOptions[optName] then --boolean

			intOption = EncodeBitmaskField(intOption, optValue, knownBitOptions[optName]) --encode options into Int.

		elseif knownIntOptions[optName] then --integer

			if type(optValue) == "number" and knownIntOptions[optName] == 1 then
				luaShader:SetUniformInt(optName, optValue)
			elseif type(optValue) == "table" and knownIntOptions[optName] == #optValue then
				luaShader:SetUniformInt(optName, unpack(optValue))
			end

		elseif knownFloatOptions[optName] then --float
			if type(optValue) == "number" and knownFloatOptions[optName] == 1 then
				luaShader:SetUniformFloat(optName, optValue)
			elseif type(optValue) == "table" and knownFloatOptions[optName] == #optValue then
				luaShader:SetUniformFloat(optName, unpack(optValue))
			end

		end
	end

	--Spring.Echo("ApplyOptions")
	luaShader:SetUniformInt("bitOptions", intOption)
end

local function GetAllOptions()
	if not allOptions then
		allOptions = {}
		for k, _ in pairs(knownBitOptions) do
			allOptions[k] = true
		end

		for k, _ in pairs(knownIntOptions) do
			allOptions[k] = true
		end

		for k, _ in pairs(knownFloatOptions) do
			allOptions[k] = true
		end
	end
	return allOptions
end

local function SunChanged(luaShader)
	luaShader:SetUniformAlways("shadowDensity", gl.GetSun("shadowDensity" ,"unit"))

	luaShader:SetUniformAlways("sunAmbient", gl.GetSun("ambient" ,"unit"))
	luaShader:SetUniformAlways("sunDiffuse", gl.GetSun("diffuse" ,"unit"))
	luaShader:SetUniformAlways("sunSpecular", gl.GetSun("specular" ,"unit"))
end

defaultMaterialTemplate.ProcessOptions = ProcessOptions
defaultMaterialTemplate.ApplyOptions = ApplyOptions
defaultMaterialTemplate.GetAllOptions = GetAllOptions

defaultMaterialTemplate.SunChangedOrig = SunChanged
defaultMaterialTemplate.SunChanged = SunChanged

return defaultMaterialTemplate
