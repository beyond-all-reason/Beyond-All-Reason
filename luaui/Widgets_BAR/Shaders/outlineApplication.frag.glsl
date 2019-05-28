#version 150 compatibility

uniform sampler2D tex;
uniform sampler2D modelDepthTex;
uniform sampler2D mapDepthTex;

uniform float strength = 1.0;
uniform mat4 projMat;

const float epsVS = 3.0;

#define DEPTH_CLIP01 ###DEPTH_CLIP01###

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

//comprehension challenge. What do I do here ?
// spoiler
// 1. depth[0,1] to depthNDC[0,1 or -1,1]
// 2. depthNDC to view-space depth vsDepth
// 3. Add view-space addition vsAdd to vsDepth
// 4. vsDepth to depthNDC
// 5. depthNDC to depth[0,1], which gl_FragDepth expects
// Profit. Hopefully....

float GetNewNDCDepth(float tDepth, float vsAdd) {
	//todo tDepth to ndcDepth
	#if (DEPTH_CLIP01 == 1)
		float ndcDepth = tDepth;
	#else
		float ndcDepth = NORM2SNORM(tDepth);
	#endif

	float vsDepth = -projMat[3][2] / (projMat[2][2] + ndcDepth);
	vsDepth += vsAdd;

	ndcDepth = (-projMat[3][2] - projMat[2][2] * vsDepth) / vsDepth;

	#if (DEPTH_CLIP01 == 1)
		float tDepthOut = ndcDepth;
	#else
		float tDepthOut = SNORM2NORM(tDepth);
	#endif
	return tDepthOut;
}

void main() {
	ivec2 imageCoord = ivec2(gl_FragCoord.xy);

	vec4 color = texelFetch(tex, imageCoord, 0);
	float modelDepth = texelFetch(modelDepthTex, imageCoord, 0).r;
	float mapDepth = texelFetch(mapDepthTex, imageCoord, 0).r;

	gl_FragColor = mix(vec4(0.0), color, vec4(strength));
	gl_FragDepth = GetNewNDCDepth(mapDepth, epsVS); //precision hack. Move depth a bit closer to camera than terrain surface
}
