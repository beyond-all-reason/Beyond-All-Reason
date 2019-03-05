#version 150 compatibility

#define DEPTH_CLIP01 ###DEPTH_CLIP01###
#define MAX_POINTS ###MAX_POINTS###

uniform sampler2D mapDepthTex;
uniform sampler2D modelsDepthTex;

uniform vec2 viewPortSize;

uniform ivec2 outlines;

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
	vec4 impactInfoItem[MAX_POINTS];
};
uniform ImpactInfo impactInfo;

in Data {
	vec4 modelPos;
	vec4 worldPos;
	vec4 viewPos;
	float colormix;
};

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

float GetViewSpaceDepth(float depthNDC) {
	return -projMat[3][2] / (projMat[2][2] + depthNDC);
}

/*
#define HASHSCALE1 .1031
float hash11(float p) {
	vec3 p3  = fract(vec3(p) * HASHSCALE1);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

float noise11(float p){
	float fl = floor(p);
	float fc = fract(p);
	return mix(hash11(fl), hash11(fl + 1.0), fc);
}
*/

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
//const float PI_2 = PI / 2.0;

const float outlineEffectSize = 3.0;
const float outlineAlpha = 0.8;

void main() {
	float d = 0.0;
	if (outlines.x == 1 || outlines.y == 1) {
		float minDepth = 1.0;
		vec2 viewPortUV = gl_FragCoord.xy/viewPortSize;
		if (outlines.x == 1) { // terrain outline
			//minDepth = min(minDepth, texelFetch( mapDepthTex, ivec2(gl_FragCoord.xy), 0 ).r);
			minDepth = min(minDepth, texture( mapDepthTex, viewPortUV ).r);
		}
		if (outlines.y == 1) { // units outline
			//minDepth = min(minDepth, texelFetch( modelsDepthTex, ivec2(gl_FragCoord.xy), 0 ).r);
			minDepth = min(minDepth, texture( modelsDepthTex, viewPortUV ).r);
		}
		#if (DEPTH_CLIP01 == 1)
			// Nothing. NDC and window/texture space are same for depth
		#else
			float minDepth = NORM2SNORM(minDepth);
		#endif

		//float polarAngle = atan(worldPos.z - translationScale.z, worldPos.x - translationScale.x);
		//polarAngle += gameFrame * 0.01;
		//polarAngle *= PI * 10.0;


		vec3 outlineNoiseVec = worldPos.xyz;
		outlineNoiseVec.y += gameFrame * 0.4;

		float minDepthView = GetViewSpaceDepth( minDepth );
		d = smoothstep( abs(viewPos.z - minDepthView), 0.0, outlineEffectSize * Value3D(outlineNoiseVec) );
	}

	vec4 color;

	color = mix(color1, color2, colormix);

	color.a = mix(outlineAlpha, color.a, d * d);

	gl_FragColor = vec4(1.0, 1.0, 1.0, 0.1);
	gl_FragColor = color;
}