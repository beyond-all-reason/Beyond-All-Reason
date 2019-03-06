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

float Hexagon2D(vec2 p, float width, float coreSize) {
	p.x *= 0.57735 * 2.0;
	p.y += mod(floor(p.x), 2.0)*0.5;
	p = abs((mod(p, 1.0) - 0.5));
	float val = abs(max(p.x*1.5 + p.y, p.y*2.0) - 1.0);
	return smoothstep(coreSize, width, val);
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

	const float noiseMovePace = 0.4;

	vec3 valueNoiseVec = worldPos.xyz;
	valueNoiseVec.y += gameFrame * noiseMovePace;
	float valueNoise = Value3D(valueNoiseVec);

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
		vec3 worldVec = normalize(worldPos.xyz - translationScale.xyz);
		for (int i = 0; i < impactInfo.count; ++i) {
			vec3 worldImpactVec = normalize(impactInfo.impactInfoArray[i].xyz);
			float angleDist = acos( dot(worldVec, worldImpactVec) );
			vec3 thisImpactFactor = vec3(smoothstep( impactInfo.impactInfoArray[i].w, 0.0, angleDist ));

			float centerFactor = pow(thisImpactFactor.r, 6.0);

			// 0.1 * PI * centerFactor -- swirl a bit
			mat4 worldImpactMat = CalculateLookAtMatrix(worldImpactVec, vec3(0.0), 0.2 * PI * centerFactor);
			vec3 impactNoiseVec = mat3(worldImpactMat) * worldVec;
			impactNoiseVec *= 48.0;

			vec2 noiseVecOffset = 0.25 * centerFactor * vec2( sin(gameFrame * PI * 0.15), cos(gameFrame * PI * 0.15) );

			// Make chormatic aberation effect around the impact point
			thisImpactFactor.r *= Hexagon2D(impactNoiseVec.xy + vec2(noiseVecOffset.x, noiseVecOffset.y), 0.1, 0.2);
			thisImpactFactor.g *= Hexagon2D(impactNoiseVec.xy + vec2(-noiseVecOffset.x, -noiseVecOffset.y), 0.1, 0.2);
			thisImpactFactor.b *= Hexagon2D(impactNoiseVec.xy + vec2(noiseVecOffset.x * noiseVecOffset.y, 0.0), 0.1, 0.2);

			thisImpactFactor *= mix(0.6, 1.0, valueNoise);
			impactFactor.rgb += thisImpactFactor.rgb;
			impactFactor.a = 0.333333 * (impactFactor.r + impactFactor.g + impactFactor.b);
		}

		color += impactColor * impactFactor;
	}

	//poor man's tonemapping ahead
	const float maxLuma = 0.5;
	vec3 yuvColor = RGB2YUV * color.rgb;
	yuvColor.x = min(yuvColor.x, maxLuma);
	color.rgb = YUV2RGB * yuvColor;

	const float maxAlpha = 0.5;
	color.a = min(color.a, maxAlpha);

	gl_FragColor = color;
}