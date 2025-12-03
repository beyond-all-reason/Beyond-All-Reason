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
	#define OPTION_NORMALMAP_FLIP 2
	#define OPTION_VERTEX_AO 3
	#define OPTION_FLASHLIGHTS 4

	#define OPTION_TREADS_ARM 5
	#define OPTION_TREADS_CORE 6

	#define OPTION_HEALTH_TEXTURING 7
	#define OPTION_HEALTH_DISPLACE 8
	#define OPTION_HEALTH_TEXRAPTORS 9

	#define OPTION_MODELSFOG 10

	#define OPTION_TREEWIND 11

	#define OPTION_AUTONORMAL 21

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
	// Misc. uniforms
	uniform float shadowDensity;


	/***********************************************************************/
	// Uniforms
	uniform vec3 cameraPos; // world space camera position
	uniform vec3 cameraDir; // forward vector of camera

	uniform vec3 rndVec;
	uniform int simFrame;
	uniform int drawFrame;

	uniform int intOptions[1];

	//[0]-healthMix, [1]-healthMod, [2]-vertDisplacement, [3]-tracks
	uniform float floatOptions[4];
	uniform int bitOptions;



	/***********************************************************************/
	// Varyings
	out Data {
		vec4 modelVertexPos;
		vec4 pieceVertexPosOrig;
		vec4 worldVertexPos;
		// TBN matrix components
		vec3 worldTangent;
		vec3 worldBitangent;
		vec3 worldNormal;
		// main light vector(s)
		vec3 worldCameraDir;

		// shadowPosition
		vec4 shadowVertexPos;

		// auxilary varyings
		float aoTerm;
		float selfIllumMod;
		float fogFactor;
	};

	/***********************************************************************/
	// Misc functions

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

	float hash11(float p) {
		const float HASHSCALE1 = 0.1031;
		vec3 p3  = fract(vec3(p) * HASHSCALE1);
		p3 += dot(p3, p3.yzx + 19.19);
		return fract((p3.x + p3.y) * p3.z);
	}

	vec3 hash31(float p) {
		const vec3 HASHSCALE3 = vec3(0.1031, 0.1030, 0.0973);
		vec3 p3 = fract(vec3(p) * HASHSCALE3);
		p3 += dot(p3, p3.yzx + 19.19);
		return fract((p3.xxy + p3.yzz) * p3.zyx);
	}

	/***********************************************************************/
	// Auxilary functions

	vec2 GetWind(int period) {
		vec2 wind;
		wind.x = sin(period * 5.0);
		wind.y = cos(period * 5.0);
		return wind * 10.0f;
	}

	void DoWindVertexMove(inout vec4 mVP) {
		vec2 curWind = GetWind(simFrame / 750);
		vec2 nextWind = GetWind(simFrame / 750 + 1);
		float tweenFactor = smoothstep(0.0f, 1.0f, max(simFrame % 750 - 600, 0) / 150.0f);
		vec2 wind = mix(curWind, nextWind, tweenFactor);

		#if 0
			// fractional part of model position, clamped to >.4
			vec3 modelXYZ = gl_ModelViewMatrix[3].xyz;
		#else
			vec3 modelXYZ = 16.0 * hash31(float(intOptions[0]));
		#endif
		modelXYZ = fract(modelXYZ);
		modelXYZ = clamp(modelXYZ, 0.4, 1.0);

		// crude measure of wind intensity
		float abswind = abs(wind.x) + abs(wind.y);

		vec4 cosVec;
		float simTime = 0.02 * simFrame;
		// these determine the speed of the wind"s "cosine" waves.
		cosVec.w = 0.0;
		cosVec.x = simTime * modelXYZ.x + mVP.x;
		cosVec.y = simTime * modelXYZ.z / 3.0 + modelXYZ.x;
		cosVec.z = simTime * 1.0 + mVP.z;

		// calculate "cosines" in parallel, using a smoothed triangle wave
		vec4 tri = abs(fract(cosVec + 0.5) * 2.0 - 1.0);
		cosVec = tri * tri *(3.0 - 2.0 * tri);

		float limit = clamp((mVP.x * mVP.z * mVP.y) / 3000.0, 0.0, 0.2);

		float diff = cosVec.x * limit;
		float diff2 = cosVec.y * clamp(mVP.y / 30.0, 0.05, 0.2);

		mVP.xyz += cosVec.z * limit * clamp(abswind, 1.2, 1.7);

		mVP.xz += diff + diff2 * wind;
	}


	/***********************************************************************/
	// Vertex shader main()
	void main(void)
	{
		modelVertexPos = gl_Vertex;
		pieceVertexPosOrig = modelVertexPos;
		vec3 modelVertexNormal = gl_Normal;

		%%VERTEX_PRE_TRANSFORM%%

		if (BITMASK_FIELD(bitOptions, OPTION_TREEWIND)) {
			DoWindVertexMove(modelVertexPos);
		}

		if (BITMASK_FIELD(bitOptions, OPTION_HEALTH_DISPLACE)) {
			vec3 seedVec = 0.1 * modelVertexPos.xyz;
			seedVec.y += 1024.0 * hash11(float(intOptions[0]));

			modelVertexPos.xyz +=
				max(floatOptions[0] + floatOptions[1], 0.0) *
				floatOptions[2] *							//vertex displacement value
				Perlin3D(seedVec) * normalize(modelVertexPos.xyz);
		}

		gl_TexCoord[0] = gl_MultiTexCoord0;

		#if (RENDERING_MODE != 2) //non-shadow pass

			%%VERTEX_UV_TRANSFORM%%

			if (BITMASK_FIELD(bitOptions, OPTION_TREADS_ARM)) {
				const float atlasSize = 4096.0;
				const float gfMod = 8.0;
				const float texSpeed = 4.0;

				float texOffset = floatOptions[3] * mod(float(simFrame), gfMod) * (texSpeed / atlasSize);

				// note, invert we invert Y axis
				const vec4 treadBoundaries = vec4(2572.0, 3070.0, atlasSize - 1761.0, atlasSize - 1548.0) / atlasSize;
				if (all(bvec4(
						gl_TexCoord[0].x >= treadBoundaries.x, gl_TexCoord[0].x <= treadBoundaries.y,
						gl_TexCoord[0].y >= treadBoundaries.z, gl_TexCoord[0].y <= treadBoundaries.w))) {
					gl_TexCoord[0].x += texOffset;
				}
			}

			if (BITMASK_FIELD(bitOptions, OPTION_TREADS_CORE)) {
				const float atlasSize = 2048.0;
				const float gfMod = 6.0;
				const float texSpeed = -6.0;

				float texOffset = floatOptions[3] * mod(float(simFrame), gfMod) * (texSpeed / atlasSize);

				// note, invert we invert Y axis
				const vec4 treadBoundaries = vec4(1536.0, 2048.0, atlasSize - 2048.0, atlasSize - 1792.0) / atlasSize;
				if (all(bvec4(
						gl_TexCoord[0].x >= treadBoundaries.x, gl_TexCoord[0].x <= treadBoundaries.y,
						gl_TexCoord[0].y >= treadBoundaries.z, gl_TexCoord[0].y <= treadBoundaries.w))) {
					gl_TexCoord[0].x += texOffset;
				}
			}

			worldVertexPos = modelMatrix * modelVertexPos;
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

				#if 1
					if (dot(T, T) < 0.1 || dot(B, B) < 0.1) {
						T = vec3(1.0, 0.0, 0.0);
						B = vec3(0.0, 0.0, 1.0);
					}
				#endif

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
				//aoTerm = clamp(1.0 * fract(gl_TexCoord[0].x * 16384.0), shadowDensity, 1.0);
				aoTerm = clamp(1.0 * fract(gl_TexCoord[0].x * 16384.0), 0.1, 1.0);
			} else {
				aoTerm = 1.0;
			}

			if (BITMASK_FIELD(bitOptions, OPTION_FLASHLIGHTS)) {
				// modelMatrix[3][0] + modelMatrix[3][2] are Tx, Tz elements of translation of matrix
				selfIllumMod = max(-0.2, sin(simFrame * 2.0/30.0 + (modelMatrix[3][0] + modelMatrix[3][2]) * 0.1)) + 0.2;
			} else {
				selfIllumMod = 1.0;
			}

			gl_Position = projectionMatrix * viewMatrix * worldVertexPos;

			if (BITMASK_FIELD(bitOptions, OPTION_MODELSFOG)) {
				gl_ClipVertex = viewMatrix * worldVertexPos;
				// emulate linear fog
				float fogCoord = length(gl_ClipVertex.xyz);
				fogFactor = (gl_Fog.end - fogCoord) * gl_Fog.scale; // gl_Fog.scale == 1.0 / (gl_Fog.end - gl_Fog.start)
				fogFactor = clamp(fogFactor, 0.0, 1.0);
			}

			%%VERTEX_POST_TRANSFORM%%

		#elif (RENDERING_MODE == 2) //shadow pass

			vec4 lightVertexPos = gl_ModelViewMatrix * modelVertexPos;
			vec3 lightVertexNormal = normalize(gl_NormalMatrix * modelVertexNormal);

			float NdotL = clamp(dot(lightVertexNormal, vec3(0.0, 0.0, 1.0)), 0.0, 1.0);

			//use old bias formula from GetShadowPCFRandom(), but this time to write down shadow depth map values
			const float cb = 5e-5;
			float bias = cb * tan(acos(NdotL));
			bias = clamp(bias, 0.0, 5.0 * cb);

			lightVertexPos.xy += vec2(0.5);
			lightVertexPos.z += bias;

			gl_Position = gl_ProjectionMatrix * lightVertexPos; //TODO figure out gl_ProjectionMatrix replacement ?
		#endif
	}
]],

fragment = [[
	//shader version is added via gadget

	#if (RENDERING_MODE == 2) //shadows pass. AMD requests that extensions are declared right on top of the shader
		#if (SUPPORT_DEPTH_LAYOUT == 1)
			#extension GL_ARB_conservative_depth : require
			//#extension GL_EXT_conservative_depth : require
			// preserve early-z performance if possible
			layout(depth_unchanged) out float gl_FragDepth;
		#endif
	#endif

	/***********************************************************************/
	// Options in use
	#define OPTION_SHADOWMAPPING 0
	#define OPTION_NORMALMAPPING 1
	#define OPTION_NORMALMAP_FLIP 2
	#define OPTION_VERTEX_AO 3
	#define OPTION_FLASHLIGHTS 4

	#define OPTION_TREADS_ARM 5
	#define OPTION_TREADS_CORE 6

	#define OPTION_HEALTH_TEXTURING 7
	#define OPTION_HEALTH_DISPLACE 8
	#define OPTION_HEALTH_TEXRAPTORS 9

	#define OPTION_MODELSFOG 10

	#define OPTION_TREEWIND 11

	#define OPTION_AUTONORMAL 21

	%%GLOBAL_OPTIONS%%

	/***********************************************************************/
	// General definitions
	#define BITMASK_FIELD(value, pos) ((uint(value) & (1u << uint(pos))) != 0u)

	#define NORM2SNORM(value) (value * 2.0 - 1.0)
	#define SNORM2NORM(value) (value * 0.5 + 0.5)


	/***********************************************************************/
	// Rendering & PBR definitions

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
	uniform sampler2D texture1;			//0
	uniform sampler2D texture2;			//1
	uniform sampler2D normalTex;		//2

	uniform sampler2D texture1w;		//3
	uniform sampler2D texture2w;		//4
	uniform sampler2D normalTexw;		//5

	uniform sampler2DShadow shadowTex;	//6
	uniform samplerCube reflectTex;		//7

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

	uniform vec2 autoNormalParams;

	uniform int shadowsQuality;
	uniform int materialIndex;

	uniform vec3 rndVec;
	uniform int simFrame;
	uniform int drawFrame;

	#ifdef USE_LOSMAP
		uniform vec2 mapSize;
		uniform float inLosMode;
		uniform sampler2D losMapTex;	//8
	#endif

	/***********************************************************************/
	// PBR uniforms
	uniform sampler2D brdfLUT;			//9
	uniform sampler2D envLUT;			//10
	uniform sampler2D rgbNoise;			//11

	uniform float pbrParams[8];
	uniform float gamma;

	/***********************************************************************/
	// Unit/Feature uniforms
	uniform int intOptions[1];

	//[0]-healthMix, [1]-healthMod, [2]-vertDisplacement, [3]-tracks
	uniform float floatOptions[4];


	/***********************************************************************/
	// Options
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
		vec4 modelVertexPos;
		vec4 pieceVertexPosOrig;
		vec4 worldVertexPos;
		// TBN matrix components
		vec3 worldTangent;
		vec3 worldBitangent;
		vec3 worldNormal;

		// main light vector(s)
		vec3 worldCameraDir;

		// shadowPosition
		vec4 shadowVertexPos;

		// auxilary varyings
		float aoTerm;
		float selfIllumMod;
		float fogFactor;
	};

	/***********************************************************************/
	// Generic constants
	const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

	const mat3 RGB2YCBCR = mat3(
		0.2126, -0.114572, 0.5,
		0.7152, -0.385428, -0.454153,
		0.0722, 0.5, -0.0458471);

	const mat3 YCBCR2RGB = mat3(
		1.0, 1.0, 1.0,
		0.0, -0.187324, 1.8556,
		1.5748, -0.468124, -5.55112e-17);

	//const float PI = acos(0.0) * 2.0;
	const float PI = 3.1415926535897932384626433832795;

	//const float goldenAngle = PI * (3.0 - sqrt(5.0));
	const float goldenAngle = 2.3999632297286533222315555066336;

	const float EPS = 1e-4;

	/***********************************************************************/
	// PBR constants
	const float MIN_ROUGHNESS = 0.04;
	const float DEFAULT_F0 = 0.04;

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


	/***********************************************************************/
	// Misc functions

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

	float noiseTex3D(in vec3 x) {
		const float noiseTexSizeInv = 1.0 / 256.0;
		vec3 p = floor(x);
		vec3 f = fract(x);
		f = f * f * (3.0-2.0 * f);
		vec2 uv = (p.xz + vec2(37.0,17.0) * p.y) + f.xz;
		vec2 rg = texture(rgbNoise, (uv + 0.5) * noiseTexSizeInv).yx;
		return smoothstep(-0.5, 0.5, 2.0 * (NORM2SNORM((mix(rg.x, rg.y, f.y)))));
	}

	float hash11(float p) {
		const float HASHSCALE1 = 0.1031;
		vec3 p3  = fract(vec3(p) * HASHSCALE1);
		p3 += dot(p3, p3.yzx + 19.19);
		return fract((p3.x + p3.y) * p3.z);
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

	#define smoothclamp(v, v0, v1) ( mix(v0, v1, smoothstep(v0, v1, v)) )

	/***********************************************************************/
	// Autonormal related function

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
	// Tonemapping and helper functions

	/***********************************************************************/
	// Gamma Correction
	vec3 LINEARtoSRGB(vec3 c) {
		if (gamma == 1.0)
			return c;

		float invGamma = 1.0 / gamma;
		return pow(c, vec3(invGamma));
	}

	vec3 SRGBtoLINEAR(vec3 c) {
		if (gamma == 1.0)
			return c;

		return pow(c, vec3(gamma));
	}

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

	#ifndef TONEMAP
		#define TONEMAP(c) LINEARtoSRGB(c)
	#endif

	/***********************************************************************/
	// Environment sampling functions

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
		#if defined(SPECULAR_AO)
			return clamp(pow(NoV + diffuseAO, roughness2) - 1.0 + diffuseAO, 0.0, 1.0);
		#else
			return diffuseAO;
		#endif
	}

	float ComputeSpecularAOFilament(float NoV, float diffuseAO, float roughness2) {
	#if defined(SPECULAR_AO)
		return clamp(pow(NoV + diffuseAO, exp2(-16.0 * roughness2 - 1.0)) - 1.0 + diffuseAO, 0.0, 1.0);
	#else
		return diffuseAO;
	#endif
	}
	#define ComputeSpecularAO ComputeSpecularAOFilament

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

	/***********************************************************************/
	// Rendering related functions
	// // RNM - Already unpacked https://www.shadertoy.com/view/4t2SzR
	vec3 NormalBlendUnpackedRNM(vec3 n1, vec3 n2) {
		n1 += vec3(0.0, 0.0, 1.0);
		n2 *= vec3(-1.0, -1.0, 1.0);

		return n1 * dot(n1, n2) / n1.z - n2;
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

		vec2 myUV = gl_TexCoord[0].xy;

		if (BITMASK_FIELD(bitOptions, OPTION_NORMALMAP_FLIP)) {
			myUV.y = 1.0 - myUV.y;
		}

		mat3 worldTBN = mat3(worldTangent, worldBitangent, worldNormal);

		// N - worldFragNormal
		vec3 N;

		vec4 normalTexVal;
		if (BITMASK_FIELD(bitOptions, OPTION_NORMALMAPPING) || BITMASK_FIELD(bitOptions, OPTION_HEALTH_TEXRAPTORS)) {
			normalTexVal = texture(normalTex, myUV);
		}

		float healthMix;
		vec3 seedVec;
		if (BITMASK_FIELD(bitOptions, OPTION_HEALTH_TEXTURING) || BITMASK_FIELD(bitOptions, OPTION_HEALTH_TEXRAPTORS)) {
			seedVec = pieceVertexPosOrig.xyz * 0.6;
			seedVec.y += 1024.0 * hash11(float(intOptions[0]));

			healthMix = SNORM2NORM(Perlin3D(seedVec.xyz)) * (2.0 - floatOptions[1]);
			healthMix = smoothstep(0.0, healthMix, max(floatOptions[0] + floatOptions[1], 0.0));
		}

		vec3 tbnNormal;
		if (BITMASK_FIELD(bitOptions, OPTION_NORMALMAPPING)) {
			tbnNormal = NORM2SNORM(normalTexVal.xyz);
			if (BITMASK_FIELD(bitOptions, OPTION_HEALTH_TEXTURING)) {
				vec3 tbnNormalw = NORM2SNORM(texture(normalTexw, myUV).xyz);
				tbnNormal = mix(tbnNormal, tbnNormalw, healthMix);
			}
			if (BITMASK_FIELD(bitOptions, OPTION_HEALTH_TEXRAPTORS)) {
				vec3 tbnNormalw = NORM2SNORM(texture(rgbNoise, 0.5 * myUV).rgb);
				tbnNormalw = mix(tbnNormal, tbnNormalw, 0.5);

				tbnNormal = mix(tbnNormal, tbnNormalw, healthMix);
			}
		} else if (BITMASK_FIELD(bitOptions, OPTION_AUTONORMAL)) {
			tbnNormal = GetNormalFromDiffuse(myUV);
		} else {
			tbnNormal = vec3(0.0, 0.0, 1.0);
		}


		if (BITMASK_FIELD(bitOptions, OPTION_NORMALMAP_FLIP)) {
			myUV.y = 1.0 - myUV.y;
		}

		vec4 texColor1 = texture(texture1, myUV);
		vec4 texColor2 = texture(texture2, myUV);

		if (BITMASK_FIELD(bitOptions, OPTION_HEALTH_TEXTURING)) {
			vec4 texColor1w = texture(texture1w, myUV);
			vec4 texColor2w = texture(texture2w, myUV);
			healthMix *= (1.0 - 0.9 * texColor2.r); //emissive parts don't get too damaged
			texColor1 = mix(texColor1, texColor1w, healthMix);
			texColor2.xyz = mix(texColor2.xyz, texColor2w.xyz, healthMix);
			texColor2.z += 0.5 * healthMix; //additional roughness
		}


		#ifdef LUMAMULT
		{
			vec3 yCbCr = RGB2YCBCR * texColor1.rgb;
			yCbCr.x = clamp(yCbCr.x * LUMAMULT, 0.0, 1.0);
			texColor1.rgb = YCBCR2RGB * yCbCr;
		}
		#endif

		vec3 albedoColor = SRGBtoLINEAR(mix(texColor1.rgb, teamColor.rgb, texColor1.a));

		if (BITMASK_FIELD(bitOptions, OPTION_HEALTH_TEXRAPTORS)) {
			float texHeight = normalTexVal.a;
			float healthyness = clamp(healthMix * 2.0 - 0.5, 0.0, 1.0); //healthyness of 0 is near dead, 1 is fully healthy
			if (texHeight < healthyness){
				float bloodRedDeepness = clamp((healthyness - texHeight) * 8.0, 0.0, 1.0);
				tbnNormal = mix(tbnNormal, vec3(0.0, 0.0, 1.0), bloodRedDeepness); // make the surface flat
				texColor2.g = 0.2;  // a bit metallic
				texColor2.b = texColor2.b * 0.2;  // completely polished
				albedoColor.rgb = mix(vec3(0.4, 0.0, 0.01), vec3(0.12, 0.0, 0.0), bloodRedDeepness);
			}
		}


		N = normalize(worldTBN * tbnNormal);

		// PBR Params
		#ifdef EMISSIVENESS
			float emissiveness = EMISSIVENESS;
		#else
			float emissiveness = texColor2.r;
		#endif

		emissiveness = clamp(selfIllumMod * emissiveness, 0.0, 1.0);

		#ifdef METALNESS
			float metalness = METALNESS;
		#else
			float metalness = texColor2.g;
		#endif

		//metalness = SNORM2NORM( sin(simFrame * 0.05) );
		//metalness = 1.0;

		metalness = clamp(metalness, 0.0, 1.0);

		#ifdef ROUGHNESS
			float roughness = ROUGHNESS;
		#else
			float roughness = texColor2.b;
		#endif

		//roughness = SNORM2NORM( sin(simFrame * 0.25) );
		//roughness = 0.5;

		// this is great to remove specular aliasing on the edges.
		#ifdef ROUGHNESS_AA
			roughness = mix(roughness, AdjustRoughnessByNormalMap(roughness, tbnNormal), ROUGHNESS_AA);
		#endif

		roughness = clamp(roughness, MIN_ROUGHNESS, 1.0);

		float roughness2 = roughness * roughness;
		float roughness4 = roughness2 * roughness2;

		// L - worldLightDir
		/// Sun light is considered infinitely far, so it stays same no matter worldVertexPos.xyz
		vec3 L = normalize(sunDir); //from fragment to light, world space

		// V - worldCameraDir
		vec3 V = normalize(worldCameraDir);

		// H - worldHalfVec
		vec3 H = normalize(L + V); //half vector

		// R - reflection of worldCameraDir against worldFragNormal
		vec3 Rv = -reflect(V, N);

		// dot products
		float NdotLu = dot(N, L);
		float NdotL = clamp(NdotLu, 0.0, 1.0);
		float NdotH = clamp(dot(H, N), 0.0, 1.0);
		float NdotV = clamp(dot(N, V), EPS, 1.0);
		float VdotH = clamp(dot(V, H), 0.0, 1.0);


		#if defined(ROUGHNESS_PERTURB_COLOR)
			float colorPerturbScale = mix(0.0, ROUGHNESS_PERTURB_COLOR, roughness);
			albedoColor *= (1.0 + colorPerturbScale * rndValue); //try cheap way first (no RGB2YCBCR / YCBCR2RGB)
		#endif


		/// shadows
		float shadowMult;
		{
			float nShadow = smoothstep(0.0, 0.35, NdotLu); //normal based shadowing, always on
			float gShadow = 1.0; // shadow mapping
			if (BITMASK_FIELD(bitOptions, OPTION_SHADOWMAPPING)) {
				gShadow = GetShadowPCFRandom(NdotL);
			}
			shadowMult = mix(1.0, min(nShadow, gShadow), shadowDensity);
		}


        ///
        // calculate reflectance at normal incidence; if dia-electric (like plastic) use F0
        // of 0.04 and if it's a metal, use the albedo color as F0 (metallic workflow)
        vec3 F0 = vec3(DEFAULT_F0);
		vec3 F90;
		{
			F0 = mix(F0, albedoColor, metalness);

			float reflectance = max(F0.r, max(F0.g, F0.b));

			// Anything less than 2% is physically impossible and is instead considered to be shadowing. Compare to "Real-Time-Rendering" 4th editon on page 325.
			F90 = vec3(clamp(reflectance * 50.0, 0.0, 1.0));
		}

		vec2 envBRDF = textureLod(brdfLUT, vec2(NdotV, roughness), 0.0).rg;

		vec3 energyCompensation = clamp(1.0 + F0 * (1.0 / max(envBRDF.x, EPS) - 1.0), vec3(1.0), vec3(2.0));


		//// Direct (sun) PBR lighting
        vec3 dirContrib = vec3(0.0);
		vec3 outSpecularColor = vec3(0.0);

		if (any( greaterThan(vec2(NdotL, NdotV), vec2(EPS)) )) {
			// Cook-Torrance BRDF

			vec3 F = FresnelSchlick(F0, F90, VdotH);
			float Vis = VisibilityOcclusion(NdotL, NdotV, roughness2, roughness4);
			float D = MicrofacetDistribution(NdotH, roughness4);
			outSpecularColor = F * Vis * D /* * PI */;

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
		Rv = mix(Rv, N, roughness4);


		// Indirect and ambient lighting
        vec3 outColor;
		vec3 ambientContrib;
		vec3 iblDiffuse, iblSpecular;
        {
            // ambient lighting (we now use IBL as the ambient term)
			vec3 F = FresnelWithRoughness(F0, F90, VdotH, roughness, envBRDF);

            //vec3 kS = F;
            vec3 kD = 1.0 - F;
            kD *= 1.0 - metalness;

            ///
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

		// final color
		outColor += emissiveness * albedoColor;

		#ifdef USE_LOSMAP
			vec2 losMapUV = worldVertexPos.xz;
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

		if (BITMASK_FIELD(bitOptions, OPTION_MODELSFOG)) {
			outColor = mix(gl_Fog.color.rgb, outColor, fogFactor);
		}

		// debug hook
		#if 0
			//outColor = dirContrib + ambientContrib;
			//outColor = vec3( NdotV );
			//outColor = LINEARtoSRGB(FresnelSchlick(F0, F90, NdotV));
			outColor = vec3(normalTexVal.aaa);
		#endif

		#if (RENDERING_MODE == 0)
			fragData[0] = vec4(outColor, texColor2.a);
		#elif (RENDERING_MODE == 1)
			float alphaBin = (texColor2.a < 0.5) ? 0.0 : 1.0;

			outSpecularColor = TONEMAP(outSpecularColor);

			fragData[GBUFFER_NORMTEX_IDX] = vec4(SNORM2NORM(N), alphaBin);
			fragData[GBUFFER_DIFFTEX_IDX] = vec4(outColor, alphaBin);
			fragData[GBUFFER_SPECTEX_IDX] = vec4(outSpecularColor, alphaBin);
			fragData[GBUFFER_EMITTEX_IDX] = vec4(vec3(emissiveness), alphaBin);
			fragData[GBUFFER_MISCTEX_IDX] = vec4(float(materialIndex) / 255.0, 0.0, 0.0, alphaBin);
		#endif
	}
#else //shadow pass

#endif
]],
	uniformInt = {
		texture1 	 = 0,
		texture2 	 = 1,
		normalTex    = 2,

		texture1w    = 3,
		texture2w    = 4,
		normalTexw   = 5,

		shadowTex    = 6,
		reflectTex   = 7,

		losMapTex    = 8,
		brdfLUT      = 9,
		envLUT       = 10,
		rgbNoise     = 11,
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

	-- note these definitions below are not inherited!!!
	-- they need to be redefined on every child material that has its own {shader,deferred,shadow}Definitions
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
		shadowmapping     = true,
		normalmapping     = false,

		vertex_ao         = false,
		flashlights       = false,
		normalmap_flip    = false,

		treads_arm       = false,
		treads_core      = false,

		health_displace  = false,
		health_texturing = false,
		health_texraptors = false,

		modelsfog        = true,

		treewind         = false,
		autonormal       = false,

		shadowsQuality   = 2,

		autoNormalParams = {1.0, 0.00200}, -- Sampling distance, autonormal value
	},

	deferredOptions = {
		shadowmapping    = true,
		normalmapping    = false,

		vertex_ao        = false,
		flashlights      = false,
		normalmap_flip   = false,

		treads_arm      = false,
		treads_core     = false,

		modelsfog        = true,

		health_displace  = false,
		health_texturing = false,
		health_texraptors = false,

		treewind         = false,
		autonormal       = false,

		shadowsQuality   = 0,
		materialIndex    = 0,
	},

	shadowOptions = {
		treewind         = false,
	},

	feature = false,

	texUnits = {
		[6] = "$shadow",
		[7] = "$reflection",

		[9] = GG.GetBrdfTexture(),
		[10] = GG.GetEnvTexture(),
		[11] = ":l:LuaUI/Images/rgbnoise.png",
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
	#define OPTION_NORMALMAP_FLIP 2
	#define OPTION_VERTEX_AO 3
	#define OPTION_FLASHLIGHTS 4

	#define OPTION_TREADS_ARM 5
	#define OPTION_TREADS_CORE 6

	#define OPTION_HEALTH_TEXTURING 7
	#define OPTION_HEALTH_DISPLACE 8
	#define OPTION_HEALTH_TEXRAPTORS 9

	#define OPTION_MODELSFOG 10

	#define OPTION_TREEWIND 11

	#define OPTION_AUTONORMAL 21
]]--

-- bit = (index - 1)
local knownBitOptions = {
	["shadowmapping"] = 0,
	["normalmapping"] = 1,
	["normalmap_flip"] = 2,
	["vertex_ao"] = 3,
	["flashlights"] = 4,

	["treads_arm"] = 5,
	["treads_core"] = 6,

	["health_texturing"] = 7,
	["health_displace"] = 8,
	["health_texraptors"] = 9,

	["modelsfog"] = 10,

	["treewind"] = 11,
	["autonormal"] = 21,
}

local knownIntOptions = {
	["shadowsQuality"] = 1,
	["materialIndex"] = 1,

}
local knownFloatOptions = {
	["autoNormalParams"] = 2,
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
		materialDef.originalOptions[1] = table.copy(materialDef.shaderOptions)
		materialDef.originalOptions[2] = table.copy(materialDef.deferredOptions)
		materialDef.originalOptions[3] = table.copy(materialDef.shadowOptions)
	end

	for id, optTable in ipairs({materialDef.shaderOptions, materialDef.deferredOptions, materialDef.shadowOptions}) do
		if knownBitOptions[optName] then --boolean
			local optValue = unpack(optValues or {})
			local optOriginalValue = materialDef.originalOptions[id][optName]

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

	luaShader:SetUniformFloatArrayAlways("pbrParams", {
        Spring.GetConfigFloat("tonemapA", 4.75),
        Spring.GetConfigFloat("tonemapB", 0.75),
        Spring.GetConfigFloat("tonemapC", 3.5),
        Spring.GetConfigFloat("tonemapD", 0.85),
        Spring.GetConfigFloat("tonemapE", 1.0),
        Spring.GetConfigFloat("envAmbient", 0.25),
        Spring.GetConfigFloat("unitSunMult", 1.0),
        Spring.GetConfigFloat("unitExposureMult", 1.0),
	})
	luaShader:SetUniformFloatAlways("gamma", Spring.GetConfigFloat("modelGamma", 1.0))
end

defaultMaterialTemplate.ProcessOptions = ProcessOptions
defaultMaterialTemplate.ApplyOptions = ApplyOptions
defaultMaterialTemplate.GetAllOptions = GetAllOptions

defaultMaterialTemplate.SunChangedOrig = SunChanged
defaultMaterialTemplate.SunChanged = SunChanged

return defaultMaterialTemplate
