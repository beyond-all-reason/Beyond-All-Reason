local scavDisplacementPlugin = {
	VERTEX_GLOBAL_NAMESPACE = [[
		#ifdef SCAVENGER_VERTEX_DISPLACEMENT
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
		#endif
	]],
	VERTEX_PRE_TRANSFORM = [[
		#ifdef SCAVENGER_VERTEX_DISPLACEMENT
		{
			//modelPos.xyz += Perlin3D(0.1 * modelPos.xyz) * SCAVENGER_VERTEX_DISPLACEMENT * normalize(mix(normalize(modelPos.xyz), modelNormal, 0.2));	// this causes gaps
			modelPos.xyz += Perlin3D(0.1 * modelPos.xyz) * SCAVENGER_VERTEX_DISPLACEMENT * normalize(modelPos.xyz);
		}
		#endif
	]],
}

local wreckMetalHighlights = {
	BLABLABLA = [[
		#define wreckMetal floatOptions[1]
		if (BITMASK_FIELD(bitOptions, OPTION_METAL_HIGHLIGHT) && wreckMetal > 0.0) {
			//	local alpha = (0.25*(intensity/100)) + (0.5 * (intensity/100) * math.abs(1 - (timer * 2) % 2))

			//	local x100  = 100  / (100  + metal)
			//	local x1000 = 1000 / (1000 + metal)
			//	local v = 0.2 + 0.8 / (1 + 40 / metal)
			//	local r = v * (1 - x1000)
			//	local g = v * (x1000 - x100)
			//	local b = v * (x100)
			float boundedMetal = max(wreckMetal, 20.0);

			float alpha = 0.35 + 0.65 * SNORM2NORM( sin(simFrame * 0.2) );
			vec3 x100_1000 = vec3(100.0 / (100.0 + boundedMetal), 1000.0 / (1000.0 + boundedMetal), 0.2 + 0.8 / (1 + 40 / boundedMetal));
			addColor = vec4((1.0 - x100_1000.y) * x100_1000.z, (x100_1000.y - x100_1000.x) * x100_1000.z, x100_1000.x * x100_1000.z, alpha);
		}
		#undef wreckMetal
	]],
}

local unitsFog = {
	VERTEX_POST_TRANSFORM = [[
		if (BITMASK_FIELD(bitOptions, OPTION_UNITSFOG)) {
			float fogCoord = length(gl_Position.xyz);
			fogFactor = (gl_Fog.end - fogCoord) * gl_Fog.scale; //linear

			// these two don't work correctly as they should. Probably gl_Fog.density is not set correctly
			//fogFactor = exp(-gl_Fog.density * fogCoord); //exp
			//fogFactor = exp(-pow((gl_Fog.density * fogCoord), 2.0)); //exp2

			fogFactor = clamp(fogFactor, 0.0, 1.0);
		}
	]],
}

local armThreadsPlugun = {
	VERTEX_UV_TRANSFORM = [[
		#define OPTION_TREEWIND_ARM 8
	]],
	VERTEX_GLOBAL_NAMESPACE = [[
		#define threadOffset floatOptions[0]
		if (BITMASK_FIELD(bitOptions, OPTION_MOVING_THREADS)) {
			const vec4 treadBoundaries = vec4(0.6279296875, 0.74951171875, 0.5702890625, 0.6220703125);

			if ( all(bvec4(
					greaterThanEqual(modelUV, treadBoundaries.xz),
					lessThanEqual(modelUV, treadBoundaries.yw)))) {
				modelUV.x += threadOffset;
			}
		}
		#undef threadOffset
	]],
}

local coreThreadsPlugun = {
	UV_PRE_TRANSFORM = [[
		#define OPTION_TREEWIND_ARM 8
	]],
	VERTEX_GLOBAL_NAMESPACE = [[
		#define threadOffset floatOptions[0]
		if (BITMASK_FIELD(bitOptions, OPTION_MOVING_THREADS)) {
			const vec4 treadBoundaries = vec4( 0.04541015625,0.17138671875, 0.80419921875, 0.845703125);

			if ( all(bvec4(
					greaterThanEqual(modelUV, treadBoundaries.xz),
					lessThanEqual(modelUV, treadBoundaries.yw)))) {
				modelUV.x += threadOffset;
			}
		}
		#undef threadOffset
	]],
}

local lumaMultPlugun = {
	FRAGMENT_GLOBAL_NAMESPACE = [[
		const mat3 RGB2YCBCR = mat3(
			0.2126, -0.114572, 0.5,
			0.7152, -0.385428, -0.454153,
			0.0722, 0.5, -0.0458471);

		const mat3 YCBCR2RGB = mat3(
			1.0, 1.0, 1.0,
			0.0, -0.187324, 1.8556,
			1.5748, -0.468124, -5.55112e-17);
	]],
}

local pbrPlugin = {
	FRAGMENT_GLOBAL_NAMESPACE = [[
		/***********************************************************************/
		// PBR Definitions
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

		#if (ENV_SMPL_NUM == 0)
			#undef USE_ENVIRONMENT_DIFFUSE
			#undef USE_ENVIRONMENT_SPECULAR
			#define USE_ENVIRONMENT_DIFFUSE 0
			#define USE_ENVIRONMENT_SPECULAR 0
		#endif

		const float MIN_ROUGHNESS = 0.04;
		const float DEFAULT_F0 = 0.04;

		// gamma correction & tonemapping
		#ifdef GAMMA
			#define INV_GAMMA 1.0 / GAMMA
			#define SRGBtoLINEAR(c) ( pow(c, vec3(GAMMA)) )
			#define LINEARtoSRGB(c) ( pow(c, vec3(INV_GAMMA)) )
		#else
			#define SRGBtoLINEAR(c) ( c )
			#define LINEARtoSRGB(c) ( c )
		#endif

		/***********************************************************************/
		// Noise function

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
	]]
}

local treeWindPlugun = {
	GLOBAL_OPTIONS = [[
		#define OPTION_TREEWIND 8
	]],
	VERTEX_GLOBAL_NAMESPACE = [[
		vec2 GetWind(int period) {
			vec2 wind;
			wind.x = sin(period * 5.0);
			wind.y = cos(period * 5.0);
			return wind * 10.0f;
		}
		]],
	VERTEX_PRE_TRANSFORM = [[
		void DoWindVertexMove(inout vec4 mVP) {
			vec2 curWind = GetWind(simFrame / 750);
			vec2 nextWind = GetWind(simFrame / 750 + 1);
			float tweenFactor = smoothstep(0.0f, 1.0f, max(simFrame % 750 - 600, 0) / 150.0f);
			vec2 wind = mix(curWind, nextWind, tweenFactor);

			// fractional part of model position, clamped to >.4
			vec4 modelPos = gl_ModelViewMatrix[3];
			modelPos = fract(modelPos);
			modelPos = clamp(modelPos, 0.4, 1.0);

			// crude measure of wind intensity
			float abswind = abs(wind.x) + abs(wind.y);

			vec4 cosVec;
			float simTime = 0.02 * simFrame;
			// these determine the speed of the wind"s "cosine" waves.
			cosVec.w = 0.0;
			cosVec.x = simTime * modelPos[0] + mVP.x;
			cosVec.y = simTime * modelPos[2] / 3.0 + modelPos.x;
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

		if (BITMASK_FIELD(bitOptions, OPTION_TREEWIND)) {
				DoWindVertexMove(modelVertexPos);
		}
	]],
}

local function SunChanged(curShaderObj)
	curShaderObj:SetUniformAlways("shadowDensity", gl.GetSun("shadowDensity" ,"unit"))

	curShaderObj:SetUniformAlways("sunAmbient", gl.GetSun("ambient" ,"unit"))
	curShaderObj:SetUniformAlways("sunDiffuse", gl.GetSun("diffuse" ,"unit"))
	curShaderObj:SetUniformAlways("sunSpecular", gl.GetSun("specular" ,"unit"))

	curShaderObj:SetUniformFloatArrayAlways("pbrParams", {
        Spring.GetConfigFloat("tonemapA", 4.8),
        Spring.GetConfigFloat("tonemapB", 0.8),
        Spring.GetConfigFloat("tonemapC", 3.35),
        Spring.GetConfigFloat("tonemapD", 1.0),
        Spring.GetConfigFloat("tonemapE", 1.15),
        Spring.GetConfigFloat("envAmbient", 0.3),
        Spring.GetConfigFloat("unitSunMult", 1.35),
        Spring.GetConfigFloat("unitExposureMult", 1.0),
	})
end

local function PackTableIntoString(tbl, str0)
	local str = str0 or ""
	for k, v in pairs(tbl) do
		str = string.format("%s|%s=%s|", str, tostring(k), tostring(v))
	end
	return str
end

local function FillMaterials(unitMaterials, materials, matTemplate, matParentName, udID)
	local udef = UnitDefs[udID]
	local udefCM = udef.customParams
	local lm = tonumber(udefCM.lumamult) or 1
	local scvd = tonumber(udefCM.scavvertdisp) or 0

	local params = {
		lm = lm,
		scvd = scvd,
	}

	local matName = PackTableIntoString(params, matParentName)

	if not materials[matName] then
		materials[matName] = Spring.Utilities.CopyTable(matTemplate, true)

		if lm ~= 1 then
			local lmLM = string.format("#define LUMAMULT %f", lm)
			table.insert(materials[matName].shaderDefinitions, lmLM)
			table.insert(materials[matName].deferredDefinitions, lmLM)
		end

		if scvd ~= 0 then
			local lmLM = string.format("#define SCAVENGER_VERTEX_DISPLACEMENT %f", scvd)
			table.insert(materials[matName].shaderDefinitions, lmLM)
			table.insert(materials[matName].deferredDefinitions, lmLM)
		end
	end

	unitMaterials[udef.id] = {matName,
		TEX1 = GG.GetScavTexture(udID, 0) or string.format("%%%%%d:0", udID),
		TEX2 = GG.GetScavTexture(udID, 1) or string.format("%%%%%d:1", udID),
		NORMALTEX = udefCM.normaltex
	}
end


return {
	scavDisplacementPlugin = scavDisplacementPlugin,
	treeDisplacementPlugun = treeDisplacementPlugun,
	SunChanged = SunChanged,
	FillMaterials = FillMaterials,
}