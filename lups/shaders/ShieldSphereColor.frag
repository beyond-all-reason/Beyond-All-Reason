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

//uniform mat4 inverseViewMat;
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

	vec3 viewSunDir;
	vec3 viewCameraDir;

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

		vec3 viewHalfVec = normalize(viewSunDir + viewCameraDir);
		float specularFactor = pow(max(dot( normalize(viewNormal), viewHalfVec ), 0.0), float(effects.x));
		specularFactor *= float(effects.x + 8) / PI8; // http://www.rorydriscoll.com/2009/01/25/energy-conservation-in-games/
		specularFactor *= mix(0.9, 1.0, valueNoise);

		specularFactor *= specularStrength;

		color = mix(color, specularColor, specularFactor);
	}

	if (BITMASK_FIELD(effects.y, 1) || BITMASK_FIELD(effects.y, 2)) {
		const float outlineEffectSize = 3.0;
		const float outlineAlpha = 0.8;

		float minDepth = 1.0;
		vec2 viewPortUV = gl_FragCoord.xy/viewPortSize;
		if (BITMASK_FIELD(effects.y, 1)) { // terrain outline
			//minDepth = min(minDepth, texelFetch( mapDepthTex, ivec2(gl_FragCoord.xy), 0 ).r);
			minDepth = min(minDepth, texture( mapDepthTex, viewPortUV ).r);
		}
		if (BITMASK_FIELD(effects.y, 2)) { // units outline
			//minDepth = min(minDepth, texelFetch( modelsDepthTex, ivec2(gl_FragCoord.xy), 0 ).r);
			minDepth = min(minDepth, texture( modelsDepthTex, viewPortUV ).r);
		}
		#if (DEPTH_CLIP01 == 1)
			// Nothing. NDC and window/texture space are same for depth
		#else
			float minDepth = NORM2SNORM(minDepth);
		#endif

		float minDepthView = GetViewSpaceDepth( minDepth );
		float outlineFactor = smoothstep( abs(viewPos.z - minDepthView), 0.0, outlineEffectSize * valueNoise);
		outlineFactor *= outlineFactor;
		outlineFactor = 1.0 - outlineFactor;

		color.a = mix(color.a, outlineAlpha, outlineFactor);
	}

	if (BITMASK_FIELD(effects.y, 4)) { // impact animation
		float impactFactor = 0.0;
		vec3 worldCenteredPos = normalize(worldPos.xyz - translationScale.xyz);
		for (int i = 0; i < impactInfo.count; ++i) {
			vec3 worldCenteredImpactPos = normalize(impactInfo.impactInfoArray[i].xyz);
			float angleDist = acos( dot(worldCenteredPos, worldCenteredImpactPos) );
			impactFactor += smoothstep(impactInfo.impactInfoArray[i].w, 0.0, angleDist) / float(impactInfo.count);
		}
		color = vec4(impactFactor);
	}

	gl_FragColor = color;
}