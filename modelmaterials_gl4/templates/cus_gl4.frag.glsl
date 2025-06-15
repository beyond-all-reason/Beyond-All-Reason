//shader version is added via gadget

#if (RENDERING_MODE == 2) //shadows pass. AMD requests that extensions are declared right on top of the shader
	#if (SUPPORT_DEPTH_LAYOUT == 1)
		//#extension GL_ARB_conservative_depth : enable // this is commented out because AMD wants me to add it at start of shader, hope this works...
		//#extension GL_EXT_conservative_depth : require
		// preserve early-z performance if possible
		// for future reference: https://github.com/buildaworldnet/IrrlichtBAW/wiki/Early-Fragment-Tests,-Hi-Z,-Depth,-Stencil-and-other-benchmarks
		#if (GL_ARB_conservative_depth == 1)
			layout(depth_unchanged) out float gl_FragDepth;
		#endif
	#endif
#endif

/***********************************************************************/
// Options in use
#define OPTION_SHADOWMAPPING 0
#define OPTION_NORMALMAPPING 1
#define OPTION_SHIFT_RGBHSV 2
#define OPTION_VERTEX_AO 3
#define OPTION_FLASHLIGHTS 4

#define OPTION_TREADS_ARM 5
#define OPTION_TREADS_CORE 6

#define OPTION_HEALTH_TEXTURING 7
#define OPTION_HEALTH_DISPLACE 8
#define OPTION_HEALTH_TEXRAPTORS 9

#define OPTION_MODELSFOG 10

#define OPTION_TREEWIND 11
#define OPTION_PBROVERRIDE 12

#define OPTION_TREADS_LEG 13

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


//uniform int shadowsQuality;
int shadowsQuality = 0;
uniform int materialIndex;

//uniform vec3 rndVec;

#ifdef USE_LOSMAP
	//uniform vec2 mapSize;
	//uniform float inLosMode;
	uniform sampler2D losMapTex;	//8
#endif


/***********************************************************************/
// PBR uniforms
uniform sampler2D brdfLUT;			//9
uniform sampler3D noisetex3dcube;			//10
uniform sampler2D envLUT;			//11




uniform float gamma = 1.0;


//[0]-healthMix, [1]-healthMod, [2]-vertDisplacement, [3]-tracks
//uniform float floatOptions[4];

uniform float baseVertexDisplacement = 0.0; // this is for the scavengers,
uniform int drawPass = 1;
/***********************************************************************/
// Options
uniform int bitOptions;

uniform float brightnessFactor = 1.5;
//int bitOptions = 1 +  2 + 8 + 16 + 128 + 256;

float simFrame = (timeInfo.z * 30.0);

float textureLODBias =  -0.5; //-0.5 * sin (simFrame * 0.1) - 0.5;

//uniform float pbrParams[8];

/*  Spring.GetConfigFloat("tonemapA", 4.75),
	Spring.GetConfigFloat("tonemapB", 0.75),
	Spring.GetConfigFloat("tonemapC", 3.5),
	Spring.GetConfigFloat("tonemapD", 0.85),
	Spring.GetConfigFloat("tonemapE", 1.0),
	Spring.GetConfigFloat("envAmbient", 0.25),
	Spring.GetConfigFloat("unitSunMult", 1.0),
	Spring.GetConfigFloat("unitExposureMult", 1.0),*/

//float pbrParams[8] = float[8](4.75, 0.75, 3.5, 0.85, 1.0, 0.25, 1.0, 1.0 );	// old pre gl4 cus values
float pbrParams[8] = float[8](4.85, 0.85, 3.5, 0.85, 1.0, 0.23, 1.0, 1.0 );

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
	vec4 pieceVertexPosOrig; // .w contains model maxY
	vec4 worldVertexPos; //.w contains cloakTime
	// TBN matrix components
	vec3 worldTangent;
	//vec3 worldBitangent;
	vec3 worldNormal;

	vec4 uvCoords;
	flat vec4 teamCol; //.a contains selectedness
	// main light vector(s)
//	vec3 worldCameraDir;

	// shadowPosition
	vec4 shadowVertexPos;


	//vec3 debugvarying; // for passing through debug garbage
	// aoterm_fogFactor_selfIllumMod_healthFraction varyings
	vec4 aoterm_fogFactor_selfIllumMod_healthFraction; // aoterm, fogFactor, selfIllumMod, healthFraction
//	float aoTerm;
//	float fogFactor;
//	flat float selfIllumMod;
//	flat float healthFraction;
//	flat int unitID;
//	flat vec4 userDefined2;
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
#line 20600
float GetShadowPCFRandom(float NdotL) {
	float shadow = 0.0;

	vec3 shadowCoord = shadowVertexPos.xyz; // shadowVertexPos.w is always 1.0
	int presetIndex = clamp(shadowsQuality, 0, SHADOW_QUALITY_PRESETS - 1);

	float samplingRandomness = shadowQualityPresets[presetIndex].samplingRandomness;
	float samplingDistance = shadowQualityPresets[presetIndex].samplingDistance;
	int shadowSamples = 1;// shadowQualityPresets[presetIndex].shadowSamples;

	if (shadowSamples > 1) {
		/*
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
			shadow += texture( shadowTex, shadowSamplingCoord ).r;
		}
		shadow /= float(shadowSamples);
		*/
	} else { //shadowSamples == 1
		float shadowTexelSizeInv = 0.5 / textureSize(shadowTex, 0).x; // Used to be hard coded as 0.00005
		float bias = shadowTexelSizeInv * tan(acos(NdotL));
		bias = clamp(bias, 0.0, 5.0 * shadowTexelSizeInv);
		shadowCoord.z -= bias;
		shadow = texture( shadowTex, shadowCoord ).r;

		// a neat trick i just learned
		//float dShadowX = dFdx(shadow);
		//float dShadowY = dFdy(shadow);
		//shadow = shadow + (abs(dShadowX) + abs(dShadowY))*0.5;

	}
	return shadow;
}


/***********************************************************************/
// Misc functions

float Perlin3D( vec3 P ) {

	return (textureLod(noisetex3dcube, fract(P*0.1), 0.0).a * 2.0 - 1.0);
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

#ifdef SHIFT_RGBHSV
	vec3 rgb2hsv(vec3 c)
	{
		vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
		vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
		vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

		float d = q.x - min(q.w, q.y);
		float e = 1.0e-10;
		return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
	}

	vec3 hsv2rgb(vec3 c)
	{
		vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
		vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
		return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
	}
#endif

/***********************************************************************/
// Environment sampling functions

#line 21000

#ifndef ENV_SMPL_NUM
	#define ENV_SMPL_NUM 64
#endif

#ifndef USE_ENVIRONMENT_DIFFUSE
	#define USE_ENVIRONMENT_DIFFUSE 1
#endif

#ifndef USE_ENVIRONMENT_SPECULAR
	#define USE_ENVIRONMENT_SPECULAR 1
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
				vec3 lutsample = texelFetch(envLUT, ivec2(x, y), 0).rgb;
				shR[x][y] = lutsample.r;
				shG[x][y] = lutsample.g;
				shB[x][y] = lutsample.b;
			}
	#else //unrolled version
		#define SH_FILL(x, y) \
		{ \
			vec3 lutsample = texelFetch(envLUT, ivec2(x, y), 0).rgb; \
			shR[x][y] = lutsample.r; \
			shG[x][y] = lutsample.g; \
			shB[x][y] = lutsample.b; \
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

	iblSpecular = mix(iblSpecular, SampleReflectionMapLod(Rv, 5.0), 0.1); //add some shininess
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

float ComputeSpecularAOFilament(float NoV, float diffuseAO, float roughness2) {
#if defined(SPECULAR_AO)
	return clamp(pow(NoV + diffuseAO, exp2(-16.0 * roughness2 - 1.0)) - 1.0 + diffuseAO, 0.0, 1.0);
#else
	return diffuseAO;
#endif
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

	vec2 myUV = uvCoords.xy;
	float unitID = uvCoords.z;
	vec3 worldBitangent = normalize(cross(worldNormal, worldTangent));
	mat3 worldTBN = mat3(worldTangent, worldBitangent, worldNormal);

	// N - worldFragNormal
	vec3 N;

	vec4 normalTexVal;
	if (BITMASK_FIELD(bitOptions, OPTION_NORMALMAPPING) || BITMASK_FIELD(bitOptions, OPTION_HEALTH_TEXRAPTORS)) {
		normalTexVal = texture(normalTex, myUV);
	}

	float healthMix;
	vec3 seedVec;

	#ifdef ENABLE_OPTION_HEALTH_TEXTURING
	vec4 myPerlin = vec4(0.0);
	if (BITMASK_FIELD(bitOptions, OPTION_HEALTH_TEXTURING) || BITMASK_FIELD(bitOptions, OPTION_HEALTH_TEXRAPTORS)) {
		seedVec = pieceVertexPosOrig.xyz * 0.6;
		seedVec.y += 1024.0 * hash11(float(unitID)) + dot(seedVec.xz, vec2(0.1,0.1));
		myPerlin = textureLod(noisetex3dcube, fract(seedVec.xyz*0.1), 0.0) * 2.0 - 1.0;
		
		healthMix = SNORM2NORM(myPerlin.x) * (2.0 - baseVertexDisplacement);
		healthMix = smoothstep(0.0, healthMix, max((1.0 - aoterm_fogFactor_selfIllumMod_healthFraction.w) + baseVertexDisplacement, 0.0)) * 0.8; // Reduce maximum damage shading to 80%
	}
	#endif

	vec3 tbnNormal;
	vec3 wrecknormal;
	if (BITMASK_FIELD(bitOptions, OPTION_NORMALMAPPING)) {
		tbnNormal = NORM2SNORM(normalTexVal.xyz);

		#ifdef ENABLE_OPTION_HEALTH_TEXTURING
			if (BITMASK_FIELD(bitOptions, OPTION_HEALTH_TEXTURING) || BITMASK_FIELD(bitOptions, OPTION_HEALTH_TEXRAPTORS)) {
				if (healthMix > 0.05){
					vec3 tbnNormalw = NORM2SNORM(texture(normalTexw, myUV, textureLODBias).xyz);
					wrecknormal = tbnNormalw;
					tbnNormal = mix(tbnNormal, tbnNormalw, healthMix);
				}
			}
		#endif

		tbnNormal = normalize(tbnNormal);
	} else {
		tbnNormal = vec3(0.0, 0.0, 1.0);
	}




	vec4 texColor1 = texture(texture1, myUV, textureLODBias);
	vec4 texColor2 = texture(texture2, myUV, textureLODBias);

	#ifdef SHIFT_RGBHSV
	/*
		if (BITMASK_FIELD(bitOptions, OPTION_SHIFT_RGBHSV)){
			vec3 hsvColor1 = rgb2hsv(texColor1.rgb) + userDefined2.rgb;
			hsvColor1.r = fract(hsvColor1.r);
			//hsvColor1.gb = clamp(hsvColor1.gb, 0.0, 1.0);
			texColor1.rgb = hsv2rgb(hsvColor1);
		}
	*/
	#endif

	#ifdef TREE_RANDOMIZATION
		float funitID = float(unitID);
		vec3 randluma = (funitID * vec3(0.01,0.013, 0.017) - 0.5);
		float saturation =  clamp(dot(abs(texColor1.rgb - texColor1.gbr), vec3( 1.0)), 0.0, 1.0);
		randluma = fract(randluma)*( saturation) + 1.0;
		texColor1.rgb *= randluma;
	#endif

	#ifdef ENABLE_OPTION_HEALTH_TEXTURING
		#if (RENDERING_MODE == 0)
		// disable this in deferred mode

			if (BITMASK_FIELD(bitOptions, OPTION_HEALTH_TEXTURING)) {
				if (healthMix > 0.05){
					vec4 texColor1w = texture(texture1w, myUV);
					vec4 texColor2w = texture(texture2w, myUV);
					healthMix *= (1.0 - 0.9 * texColor2.r); //emissive parts don't get too damaged
					texColor1 = mix(texColor1, texColor1w, healthMix);
					texColor2.xyz = mix(texColor2.xyz, texColor2w.xyz, healthMix);
					texColor2.z += 0.5 * healthMix; //additional roughness
				}
			}

		#endif
	#endif

	#ifdef LUMAMULT
	{
		vec3 yCbCr = RGB2YCBCR * texColor1.rgb;
		yCbCr.x = clamp(yCbCr.x * LUMAMULT, 0.0, 1.0);
		texColor1.rgb = YCBCR2RGB * yCbCr;
	}
	#endif
	vec4 teamColor = teamCol;
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

	float emissiveness = texColor2.r;

	emissiveness = clamp(aoterm_fogFactor_selfIllumMod_healthFraction.z * emissiveness, 0.0, 1.0);

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

	if (BITMASK_FIELD(bitOptions, OPTION_PBROVERRIDE)){
		emissiveness = 0.2;
		roughness = 0.8;
		metalness = 0.1;
	}

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
	vec3 L = normalize(sunDir.xyz); //from fragment to light, world space

	// V - worldCameraDir
	vec3 V = normalize(cameraViewInv[3].xyz - worldVertexPos.xyz);

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
	float gShadow = 1.0; // shadow mapping
	float nShadow = smoothstep(0.0, 0.35, NdotLu); //normal based shadowing, always on

	{
		if (BITMASK_FIELD(bitOptions, OPTION_SHADOWMAPPING)) {
			gShadow = GetShadowPCFRandom(NdotL);
		}
		shadowMult = mix(1.0, min(nShadow, gShadow), shadowDensity.y);
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

		vec3 maxSun = mix(sunSpecularModel.rgb, sunDiffuseModel.rgb, step(dot(sunSpecularModel.rgb, LUMA), dot(sunDiffuseModel.rgb, LUMA)));
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
	vec3 iblDiffuse = vec3(0);
	vec3 iblSpecular = vec3(0);
	vec3 specular = vec3(0);
	{
		// ambient lighting (we now use IBL as the ambient term)
		vec3 F = FresnelWithRoughness(F0, F90, VdotH, roughness, envBRDF);

		//vec3 kS = F;
		vec3 kD = 1.0 - F;
		kD *= 1.0 - metalness;

		///
		#if (USE_ENVIRONMENT_DIFFUSE == 1) || (USE_ENVIRONMENT_SPECULAR == 1)
			#if (RENDERING_MODE == 0)
				//TextureEnvBlured(N, Rv, iblDiffuse, iblSpecular);	//needed for Intel GPU
			#endif
		#endif
		///

		#if (USE_ENVIRONMENT_DIFFUSE == 1)
		{
			#if 0
				vec3 iblDiffuseYCbCr = RGB2YCBCR * iblDiffuse;
				float sunAmbientLuma = dot(LUMA, sunAmbientModel.rgb);

				vec2 sunAmbientLumaLeeway = vec2(pbrParams[5]);

				iblDiffuseYCbCr.x = smoothclamp(iblDiffuseYCbCr.x,
					(1.0 - sunAmbientLumaLeeway.x) * sunAmbientLuma,
					(1.0 + sunAmbientLumaLeeway.y) * sunAmbientLuma);

				iblDiffuse = YCBCR2RGB * iblDiffuseYCbCr;
			#else
				iblDiffuse = mix(sunAmbientModel.rgb, iblDiffuse, pbrParams[5]);
			#endif
		}
		#else
			iblDiffuse = sunAmbientModel.rgb;
		#endif

		//vec4 debugColor = vec4(albedoColor.rgb ,1.0);
		vec3 diffuse = iblDiffuse * albedoColor * aoterm_fogFactor_selfIllumMod_healthFraction.x;

		// sample both the pre-filter map and the BRDF lut and combine them together as per the Split-Sum approximation to get the IBL specular part.

		#if (RENDERING_MODE == 0)
			vec3 reflectionColor = SampleEnvironmentWithRoughness(Rv, roughness);
		#else
			vec3 reflectionColor = vec3(0.0);
		#endif

		#if (USE_ENVIRONMENT_SPECULAR == 1)
			reflectionColor = mix(reflectionColor, iblSpecular, roughness);
		#endif

		//vec3 specular = reflectionColor * (F * envBRDF.x + (1.0 - F) * envBRDF.y);

		// specular ambient occlusion (see Filament)
		float aoTermSpec = ComputeSpecularAOFilament(NdotV, aoterm_fogFactor_selfIllumMod_healthFraction.x, roughness2);
		//vec3 specular = reflectionColor * mix(vec3(envBRDF.y), vec3(envBRDF.x), F);
		specular = reflectionColor * (F0 * envBRDF.x + F90 * envBRDF.y);
		specular *= aoTermSpec * energyCompensation;


		outSpecularColor += specular;

		ambientContrib = (kD * diffuse + specular);

		outColor = ambientContrib + dirContrib;
	}

	// final color
	outColor += emissiveness * albedoColor;
	//vec3 debugloscolor;
	#ifdef USE_LOSMAP
		vec2 losMapUV = worldVertexPos.xz;
		losMapUV /= mapSize.zw; //xz, xzPO2
		//debugloscolor = texture(losMapTex, losMapUV).rgb * 2.0 ;
		float losValue =  texture(losMapTex, losMapUV).r * 2.0;
		losValue = clamp(losValue,0.5, 1.0);

		outColor *= losValue;
		outSpecularColor.rgb *= losValue;
		emissiveness *= losValue;
	#endif

	vec4 debugColor = vec4(outColor.rgb ,1.0);
	#ifdef EXPOSURE
		outSpecularColor.rgb *= EXPOSURE;
		outColor *= EXPOSURE;
	#endif



	outColor = TONEMAP(outColor);

	if (BITMASK_FIELD(bitOptions, OPTION_MODELSFOG)) {
		outColor = mix(fogColor.rgb, outColor, aoterm_fogFactor_selfIllumMod_healthFraction.y);
	}
	#ifdef REFLECT_DISCARD
		//if ((uint(drawPass) & 4u ) == 4u){ // reflections
			//if (worldVertexPos.y < -2.0) discard; // I cant figure out how clipspace works, so this is poor mans clip
		// AVOID THIS DISCARD LIKE THE PLAGUE, even DYNAMICALLY UNIFORM DISCARDS ARENT FREE!
		//}
	#endif

	outColor.rgb *= brightnessFactor; // this is to correct for lack of env mapping, the nastiest hack there has ever been...

	//iblDiffuse, iblSpecular
	//outColor.rgb = iblSpecular;
	
	#if ENABLE_OPTION_HEALTH_TEXTURING
		// Under Construction effect
		// We really need to know the full height of the model here :/
		float buildProgress = shadowVertexPos.w;
		if (buildProgress > -0.5){
			// myPerlin contains 4 channels of noise with decreasing frequency from r to a
			myPerlin= myPerlin;
			
			// Height is the relative height of the fragment in the model compared to the full height
			float height = clamp(pieceVertexPosOrig.w/1.0,0,1);

			// Helper sinusoidal patterns:
			float sintime = 0.5 + 0.5 * sin(simFrame * 0.1); // pulses every 3 seconds
			float sintimefast = 0.5 + 0.5 * sin(simFrame * 0.15); // pulses faster
			float sinprogress = 0.5 + 0.5 * sin(buildProgress * 0.01 * 3.1415); // pulses every percent of buildProgress
			//outColor.rgb += buildeff;
			
			// progressLevels are a vec4 of values that progressively increase from 0 to 1,
			// with a power curve, each next faster than the other, meaning .x is the bottom level, .w is the top level
			vec4 progressLevels = vec4(buildProgress);
			progressLevels = pow(progressLevels, vec4(3.0, 1.5, 0.7, 0.35));
			// Add perlin and ensure that perlin doesnt cause inaccuracy at the top of the model:
			progressLevels = mix(progressLevels, vec4(myPerlin.g + myPerlin.b*sin(simFrame * 0.042342)), 0.05 * smoothstep(0.00, 0.05, 1.0 - buildProgress));
			
			vec4 levelLines = clamp(1.0 - 100 * abs(progressLevels - vec4(height)), 0,1);

			// levelFactor is 1 when the height of a fragment is within 1% of a progressLevel, 0 otherwise.
			float levelFactor = dot(levelLines, vec4(1.0));
	
			// BuildGrid is defined as the distance from the 8 elmo world grid that the model is built on.
			// Meaning it is 0 on the grid, and 4 in the middle
			//vec3 buildGrid = 1.0 - abs(fract((worldVertexPos.xyz / 8.0)) - 0.5) * 2.0;

			// buildGridFactor is the minimum of all distances from the grid:
			//buildGrid = smoothstep(vec3(0.0), vec3(0.05), buildGrid);
			//float buildGridFactor = 1.0 - clamp( buildGrid.x * buildGrid.y * buildGrid.z, 0.0, 1.0);

			// Compute anti-aliased world-space grid lines
			vec3 fragSize = fwidth(worldVertexPos.xyz);
			float fragSizeFactor = 1.0/  dot(vec3(1.0),fragSize);
			vec3 buildGrid = abs(fract(worldVertexPos.xyz/8.0 - 0.5) - 0.5) * (8)/fragSize;
			float line = 1.0 - min(min(buildGrid.x, buildGrid.y), buildGrid.z);
			line = clamp(line * smoothstep(-0.5, 1.0, fragSizeFactor),0.0,1.0);
			
			// A dynamic grid which starts at 12 elmos size, then shrinks to 2 elmos size at 100% buildProgress
			float gridSize = clamp((1.0 - buildProgress) * 10 + 2, 2, 12);
			vec3 grid = step(0.5, clamp(1.0 - 10* fract((pieceVertexPosOrig.xyz) / gridSize), 0.0, 1.0));


			
			// The entire model will always get the 8 elmo buildgrid:
			//outColor.rgb = mix(outColor.rgb, vec3(1.0, 0.0, 1.0), buildGridFactor);
			//outColor.rgb = vec3(buildGridFactor); 
			vec3 pulseTeamColor = mix(teamCol.rgb, teamCol.rgb * 1.78, sintimefast );

			// Second to bottom level, ensure that we dont emit light
			if (height > progressLevels.x){
				float unemissive = 1.0 - smoothstep(progressLevels.x, progressLevels.y, height);
				outSpecularColor.rgb *= unemissive;
				outColor -= emissiveness * albedoColor * (1.0-  unemissive);
				emissiveness = emissiveness * unemissive;
				//outColor.rgb = vec3(unemissive);
			}

			// Middle level, use texture normals
			if (height > progressLevels.y){
				outColor.rgb = mix(outColor.rgb, pulseTeamColor.rgb,  smoothstep(progressLevels.y, progressLevels.z, height));
			}

			// Second to top level, use texture normals
			if (height > progressLevels.z){
				outColor.rgb = pulseTeamColor.rgb * clamp(NdotL, 0.3, 1.0);
			}

			// very top, just teamColor with flat light, some pulsating, 
			if (height > progressLevels.w){
				float heightProgress = smoothstep(progressLevels.w, 1.0, height) ;
				float flatlight = 0.3 + 0.7 * smoothstep(0.0, 1.0, clamp(dot(worldNormal, L) * 0.5 + 0.5, heightProgress * 0.2, 1.0));
				outColor.rgb = pulseTeamColor.rgb * flatlight;
				// Disable the normals pumped into deferred pipeline too:
				N = worldNormal;
				//outColor.rgb = vec3(heightProgress);
				#if (RENDERING_MODE == 0)
					// only modulate alpha on the forward pass
					texColor2.a *= max(0.4, max(clamp(line,buildProgress,1), (1.0 - heightProgress)));
				#endif
			}

			
			// Always display a grid when building, but fade it out on the last 5% of buildProgress
			float last5percent = smoothstep(0.0, 0.05, 1.0 - buildProgress);
			outColor.rgb = mix(outColor.rgb, pulseTeamColor , line * last5percent);

			// Always show level lines
			outColor.rgb += vec3(levelFactor);

			// Add bloom for the levels:
			outSpecularColor+= vec3(levelFactor);

			// Add bloom for the grid lines:
			outSpecularColor+= pulseTeamColor * line * sintimefast * 2.0 ;
	
		}
	#endif

	// SELECTION EFFECTS!
	#if 1
		// unit buffer uniforms 1.z (#6)
		// 0 means unit is un selected
		// 1 means unit is selected
		// +0.5 means ally also selected unit
		// +2 means its mouseovered
		// Sho
		float selectedness = teamCol.a;
		
		//selectedness = 0.0;
		if (selectedness > 0.25){
			float inselection = (selectedness == 1.0 || selectedness == 3.0) ? 1.0 : 0.0;
			float mouseovered = (selectedness > 1.5 ) ? 1.0 : 0.0;
			float allyselected = step(abs(fract(selectedness) - 0.5), 0.25);
			
			float mouseOverAnimation = fract(worldVertexPos.y * (1.0/30.0) + (simFrame)  * (2.0/40.0));

			// Base highlight amount, rgb contains the color of the highlight
			// Alpha contains the strength of the highlight
			vec4 selectionHighlight = vec4(0);
			selectionHighlight.rgb = clamp(teamCol.rgb, 0.65, 1.0);


			float dotcamera = dot(worldNormal, V);

			float highLightOpacity = clamp(1.0 - dotcamera, 0, 1);
			highLightOpacity = highLightOpacity * highLightOpacity;

			vec4 mouseOverHighlight = selectionHighlight;

			outColor.rgb += mouseovered * mouseOverAnimation * mouseOverHighlight.rgb * 0.5;
			outColor.rgb += inselection * highLightOpacity * selectionHighlight.rgb;
		}
	#endif 

	// CLOAK EFFECTS
	#if ENABLE_OPTION_HEALTH_TEXTURING 
		float cloakTime = worldVertexPos.w;
		if (abs(cloakTime) > 0.5){
			float cloakedness = 0.0;
			if (cloakTime > 0){
				cloakedness = clamp((timeInfo.x - cloakTime) / 15.0, 0.0, 1.0);
				//outColor.g = 1.0;
			}
			if (cloakTime < 0){
				cloakedness = 1.0 - clamp((timeInfo.x + cloakTime) / 15.0, 0.0, 1.0);
				//outColor.r = 1.0;
			}
			float sintime =	fract(simFrame * 0.02); // pulses every 3 seconds
			myPerlin.g = myPerlin.g * 0.5 + 0.5;
			texColor2.a = 1.0 - clamp(cloakedness*0.49, 0.0, 0.49);
			float perlinline1 = clamp(1.0 - 20* abs(myPerlin.g - fract(simFrame * 0.005)), 0.0, 1.0);
			float perlinline2 = clamp(1.0 - 20* abs(myPerlin.g - fract(simFrame * 0.005 +0.5)), 0.0, 1.0);
			float cloaknoise = cloakedness*perlinline1 + cloakedness*perlinline2;
			outColor.rgb += cloaknoise * 0.85;

			#if 1
			float dotcamera = dot(worldNormal, V);

			float highLightOpacity = clamp(1.0 - dotcamera, 0, 1);
			highLightOpacity = highLightOpacity * highLightOpacity;
			outColor.rgb = mix(outColor.rgb, teamCol.rgb * 3.0, highLightOpacity * cloakedness);
			
			//Add bloom to the perlin noise:
			outSpecularColor.rgb+= vec3(clamp(cloaknoise * 0.75,0.0,1.0));
			#endif
		} 
	#endif

	#if (RENDERING_MODE == 0)
		// Forward Rendering Mode
		fragData[0] = vec4(outColor, texColor2.a);
		//fragData[0] = vec4(vec3(aoterm_fogFactor_selfIllumMod_healthFraction.x/1.3), texColor2.a);
		//fragData[0] = vec4(vec3(fract((shadowVertexPos.xyz )  ))	, 1.0); //debug
		//fragData[0] = vec4(vec3(fract(healthMix	))	, 1.0); //debug
		//fragData[0] = vec4(debugloscolor	, 1.0); //debug
		//fragData[0] = vec4(cameraView[0].z,cameraView[1].z,cameraView[2].z, 1.0); //debug
		//fragData[0] = vec4(SNORM2NORM(V), 1.0); //debug
		//fragData[0] = vec4(NORM2SNORM(worldNormal), 1.0); //debug
		//fragData[0] = vec4(vec3(worldTBN[2]), 1.0); //debug TBN
		#ifdef HASALPHASHADOWS
			if (texColor2.a < 0.5) discard;
		#endif
	#elif (RENDERING_MODE == 1)
		// Deferred Rendering Mode
		float alphaBin = (texColor2.a < 0.5) ? 0.0 : 1.0;

		outSpecularColor = TONEMAP(outSpecularColor);
		#ifdef HASALPHASHADOWS
			if (texColor2.a < 0.5) {
				discard;
				return;
			}
		#endif


		// Important note: even if you do not write any data in fragData, that will still write vec4(0.0) into that buffer.
		fragData[GBUFFER_NORMTEX_IDX] = vec4(SNORM2NORM(N), alphaBin);
		fragData[GBUFFER_DIFFTEX_IDX] = vec4(outColor, alphaBin);

		fragData[GBUFFER_SPECTEX_IDX] = vec4(outSpecularColor, alphaBin);

		#ifndef HASALPHASHADOWS
			// This seems to be a silly way of forcing no bloom on trees, as only trees HASALPHASHADOWS
			fragData[GBUFFER_EMITTEX_IDX] = vec4(vec3(albedoColor * emissiveness * 2.0) + outSpecularColor * 0.3, alphaBin);
		#endif
		fragData[GBUFFER_MISCTEX_IDX] = vec4(float(materialIndex) / 255.0, 0.0, 0.0, alphaBin);
	#endif
}
#else //shadow pass
#line 25000

void main(void)
{
// TODO: if we really wanna have the construction effect here, then it would be prudent to also calc construction shadows here.
// Note that this is decidedly not free :/ 
#ifdef HASALPHASHADOWS
	vec4 texColor2 = texture(texture2, uvCoords.xy, 0); // note that we bind tex2 to pos0 here!
	if (texColor2.a < 0.5 ) discard;
#endif
}

//FLUTYISBROÁFélő[]
#endif