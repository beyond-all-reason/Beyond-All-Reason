#version 150 compatibility

#define DEPTH_CLIP01 ###DEPTH_CLIP01###
#define MAX_POINTS ###MAX_POINTS###

uniform sampler2D mapDepthTex;
uniform sampler2D modelsDepthTex;
uniform samplerCube reflectionTex;

uniform vec2 viewPortSize;

uniform ivec2 effects;

uniform vec4 color1;
uniform vec4 color2;

#if 1
	uniform mat4 projMat;
#else
	#define projMat gl_ProjectionMatrix
#endif

uniform mat4 inverseViewMat;
uniform float gameFrame;

uniform vec4 translationScale;

struct ImpactInfo {
	int count;
	vec4 impactInfoArray[MAX_POINTS];
};
uniform ImpactInfo impactInfo;

in Data {
	vec4 modelPos;
	vec4 worldPos;
	vec4 viewPos;

	vec3 viewNormal;

	vec3 viewHalfVec;

	vec3 reflectionVec;

	float colormix;
};

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)


//Lua limitations only allow to send 24 bits. Should be enough :)
#define BITMASK_FIELD(value, pos) ((uint(value) & (1u << uint(pos))) != 0u)

float GetViewSpaceDepth(float depthNDC) {
	return -projMat[3][2] / (projMat[2][2] + depthNDC);
}

mat4 CalculateLookAtMatrix(vec3 eye, vec3 center, vec3 up) {
	vec3 zaxis = normalize(center - eye); //from center towards eye vector
	vec3 xaxis = normalize(cross(zaxis, up));
	vec3 yaxis = cross(xaxis, zaxis);

	mat4 lookAtMatrix;

	lookAtMatrix[0] = vec4(xaxis.x, yaxis.x, zaxis.x, 0.0);
	lookAtMatrix[1] = vec4(xaxis.y, yaxis.y, zaxis.y, 0.0);
	lookAtMatrix[2] = vec4(xaxis.z, yaxis.z, zaxis.z, 0.0);
	lookAtMatrix[3] = vec4(dot(xaxis, -eye), dot(yaxis, -eye), dot(zaxis, -eye), 1.0);

	return lookAtMatrix;
}

mat4 CalculateLookAtMatrix(vec3 eye, vec3 center, float roll) {
	return CalculateLookAtMatrix(eye, center, vec3(sin(roll), cos(roll), 0.0));
}

float Value3D( vec3 P ) {
	//  https://github.com/BrianSharpe/Wombat/blob/master/Value3D.glsl

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
	vec2 hash_mod = vec2( 1.0 / ( 635.298681 + vec2( Pi.z, Pi_inc1.z ) * 48.500388 ) );
	vec4 hash_lowz = fract( Pt * hash_mod.xxxx );
	vec4 hash_highz = fract( Pt * hash_mod.yyyy );

	//	blend the results and return
	vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
	vec4 res0 = mix( hash_lowz, hash_highz, blend.z );
	vec4 blend2 = vec4( blend.xy, vec2( 1.0 - blend.xy ) );
	return dot( res0, blend2.zxzx * blend2.wwyy );
}

float SimplexPerlin3D( vec3 P ) {
    //  https://github.com/BrianSharpe/Wombat/blob/master/SimplexPerlin3D.glsl

    //  simplex math constants
    const float SKEWFACTOR = 1.0/3.0;
    const float UNSKEWFACTOR = 1.0/6.0;
    const float SIMPLEX_CORNER_POS = 0.5;
    const float SIMPLEX_TETRAHADRON_HEIGHT = 0.70710678118654752440084436210485;    // sqrt( 0.5 )

    //  establish our grid cell.
    P *= SIMPLEX_TETRAHADRON_HEIGHT;    // scale space so we can have an approx feature size of 1.0
    vec3 Pi = floor( P + dot( P, vec3( SKEWFACTOR) ) );

    //  Find the vectors to the corners of our simplex tetrahedron
    vec3 x0 = P - Pi + dot(Pi, vec3( UNSKEWFACTOR ) );
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 Pi_1 = min( g.xyz, l.zxy );
    vec3 Pi_2 = max( g.xyz, l.zxy );
    vec3 x1 = x0 - Pi_1 + UNSKEWFACTOR;
    vec3 x2 = x0 - Pi_2 + SKEWFACTOR;
    vec3 x3 = x0 - SIMPLEX_CORNER_POS;

    //  pack them into a parallel-friendly arrangement
    vec4 v1234_x = vec4( x0.x, x1.x, x2.x, x3.x );
    vec4 v1234_y = vec4( x0.y, x1.y, x2.y, x3.y );
    vec4 v1234_z = vec4( x0.z, x1.z, x2.z, x3.z );

    // clamp the domain of our grid cell
    Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
    vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

    //	generate the random vectors
    vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
    Pt *= Pt;
    vec4 V1xy_V2xy = mix( Pt.xyxy, Pt.zwzw, vec4( Pi_1.xy, Pi_2.xy ) );
    Pt = vec4( Pt.x, V1xy_V2xy.xz, Pt.z ) * vec4( Pt.y, V1xy_V2xy.yw, Pt.w );
    const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
    const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
    vec3 lowz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi.zzz * ZINC.xyz ) );
    vec3 highz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi_inc1.zzz * ZINC.xyz ) );
    Pi_1 = ( Pi_1.z < 0.5 ) ? lowz_mods : highz_mods;
    Pi_2 = ( Pi_2.z < 0.5 ) ? lowz_mods : highz_mods;
    vec4 hash_0 = fract( Pt * vec4( lowz_mods.x, Pi_1.x, Pi_2.x, highz_mods.x ) ) - 0.49999;
    vec4 hash_1 = fract( Pt * vec4( lowz_mods.y, Pi_1.y, Pi_2.y, highz_mods.y ) ) - 0.49999;
    vec4 hash_2 = fract( Pt * vec4( lowz_mods.z, Pi_1.z, Pi_2.z, highz_mods.z ) ) - 0.49999;

    //	evaluate gradients
    vec4 grad_results = inversesqrt( hash_0 * hash_0 + hash_1 * hash_1 + hash_2 * hash_2 ) * ( hash_0 * v1234_x + hash_1 * v1234_y + hash_2 * v1234_z );

    //	Normalization factor to scale the final result to a strict 1.0->-1.0 range
    //	http://briansharpe.wordpress.com/2012/01/13/simplex-noise/#comment-36
    const float FINAL_NORMALIZATION = 37.837227241611314102871574478976;

    //  evaulate the kernel weights ( use (0.5-x*x)^3 instead of (0.6-x*x)^4 to fix discontinuities )
    vec4 kernel_weights = v1234_x * v1234_x + v1234_y * v1234_y + v1234_z * v1234_z;
    kernel_weights = max(0.5 - kernel_weights, 0.0);
    kernel_weights = kernel_weights*kernel_weights*kernel_weights;

    //	sum with the kernel and return
    return dot( kernel_weights, grad_results ) * FINAL_NORMALIZATION;
}

float Hexagon2D(vec2 p, float edge0, float edge1) {
	p.x *= 0.57735 * 2.0;
	p.y += mod(floor(p.x), 2.0)*0.5;
	p = abs((mod(p, 1.0) - 0.5));
	float val = abs(max(p.x*1.5 + p.y, p.y*2.0) - 1.0);
	return smoothstep(edge0, edge1, val);
}

const mat3 RGB2YUV = mat3
						(0.2126, 0.7152, 0.0722,
						-0.09991, -0.33609,  0.436,
						0.615, -0.55861, -0.05639);
const mat3 YUV2RGB = mat3
						(1.0, 0.0, 1.28033,
						1.0, -0.21482, -0.38059,
						1.0, 2.12798, 0.0);

const float PI = acos(0.0) * 2.0;
const float PI8 = PI * 8.0;

void main() {

	vec4 color;
	color = mix(color1, color2, colormix);

	vec3 worldVec = normalize(worldPos.xyz - translationScale.xyz);

	const float valueNoiseMovePace = 0.4;

	vec3 valueNoiseVec = worldPos.xyz;
	valueNoiseVec.y += gameFrame * valueNoiseMovePace;
	float valueNoise = Value3D(valueNoiseVec);

	if (BITMASK_FIELD(effects.y, 5)) {
		const float perlinNoiseMovePace = 0.0005;
		float waveFront = mod(-gameFrame * 0.005, 1.0);

		vec3 perlinNoiseVec = modelPos.xyz;
		perlinNoiseVec.y += gameFrame * perlinNoiseMovePace;

		float perlin = 0.65 * abs(SimplexPerlin3D(perlinNoiseVec * 31.0)) + 0.35 * abs(SimplexPerlin3D(perlinNoiseVec * 63.0));

		float band = SNORM2NORM(cos((modelPos.y - waveFront)*PI*4.0));

		float pb = pow( clamp(perlin * band, 0.0, 0.95), 0.8 );

		color = pow(color, vec4(1.0 - pb));
	}

	if (effects.x > 0) { // specular highlights
		const float specularStrength = 1.0;

		vec4 specularColor = vec4(0.0, 0.0, 0.0, 0.8);

		if (BITMASK_FIELD(effects.y, 3)) { // environment reflection
			vec3 reflectionColor = texture(reflectionTex, normalize(reflectionVec)).rgb;
			specularColor.rgb += reflectionColor;
		}

		vec3 sunColor = vec3(1.0, 1.0, 1.0);
		specularColor.rgb += sunColor;

		float specularFactor = pow(max(dot( normalize(viewNormal), normalize(viewHalfVec) ), 0.0), float(effects.x));
		specularFactor *= float(effects.x + 8) / PI8; // http://www.rorydriscoll.com/2009/01/25/energy-conservation-in-games/
		specularFactor *= mix(0.9, 1.0, valueNoise);

		specularFactor *= specularStrength;

		color = mix(color, specularColor, specularFactor);
	}

	if (BITMASK_FIELD(effects.y, 1) || BITMASK_FIELD(effects.y, 2)) {
		const float outlineEffectSize = 14.0;
		const float outlineAlpha = 0.45;

		float minDepth = 1.0;
		vec2 viewPortUV = gl_FragCoord.xy/viewPortSize;
		if (BITMASK_FIELD(effects.y, 1)) { // terrain outline
			minDepth = min(minDepth, texture( mapDepthTex, viewPortUV ).r);
		}
		if (BITMASK_FIELD(effects.y, 2)) { // units outline
			minDepth = min(minDepth, texture( modelsDepthTex, viewPortUV ).r);
		}

		#if (DEPTH_CLIP01 == 1)
			// Nothing. NDC and window/texture space are same for depth
		#else
			float minDepth = NORM2SNORM(minDepth);
		#endif

		float minDepthView = GetViewSpaceDepth( minDepth );
		float outlineFactor = smoothstep( 0.0, abs(viewPos.z - minDepthView), outlineEffectSize * valueNoise );

		color.a = mix(color.a, outlineAlpha, outlineFactor);
	}

	if (BITMASK_FIELD(effects.y, 4)) { // impact animation
		const vec4 impactColor = vec4(0.5);
		vec4 impactFactor = vec4(0.0);
		for (int i = 0; i < impactInfo.count; ++i) {
			vec3 worldImpactVec = normalize(impactInfo.impactInfoArray[i].xyz);
			float angleDist = acos( dot(worldVec, worldImpactVec) );
			vec3 thisImpactFactor = vec3(smoothstep( impactInfo.impactInfoArray[i].w, 0.0, angleDist ));

			float centerFactor = pow(thisImpactFactor.r, 6.0);

			// 0.1 * PI * centerFactor -- swirl a bit
			mat4 worldImpactMat = CalculateLookAtMatrix(worldImpactVec, vec3(0.0), 0.2 * PI * centerFactor);
			vec3 impactNoiseVec = mat3(worldImpactMat) * worldVec;
			impactNoiseVec *= 48.0;

			vec2 noiseVecOffset = 0.5 * centerFactor * vec2( sin(gameFrame * PI * 0.15), cos(gameFrame * PI * 0.15) );

			// Make chormatic aberation effect around the impact point
			thisImpactFactor.r *= Hexagon2D(impactNoiseVec.xy + vec2(noiseVecOffset.x, noiseVecOffset.y), 0.2, 0.2);
			thisImpactFactor.g *= Hexagon2D(impactNoiseVec.xy + vec2(-noiseVecOffset.x, -noiseVecOffset.y), 0.2, 0.2);
			thisImpactFactor.b *= Hexagon2D(impactNoiseVec.xy + vec2(noiseVecOffset.x * noiseVecOffset.y, 0.0), 0.2, 0.2);

			thisImpactFactor *= mix(0.6, 1.0, valueNoise);
			impactFactor.rgb += thisImpactFactor.rgb;
			impactFactor.a = 0.333333 * (impactFactor.r + impactFactor.g + impactFactor.b);
		}

		color += impactColor * impactFactor;
	}

	//poor man's tonemapping ahead
	const float maxLuma = 0.6;
	vec3 yuvColor = RGB2YUV * color.rgb;
	yuvColor.x = min(yuvColor.x, maxLuma);
	color.rgb = YUV2RGB * yuvColor;

	const float maxAlpha = 0.6;
	color.a = min(color.a, maxAlpha);

	gl_FragColor = color;
}