#version 150 compatibility

uniform sampler2D modelDepthTex;
uniform sampler2D mapDepthTex;
uniform sampler2D modelMiscTex;

uniform vec4 outlineColor;

#define USE_MATERIAL_INDICES ###USE_MATERIAL_INDICES###

const float eps = 1e-4;
//layout(pixel_center_integer) in vec4 gl_FragCoord;
//layout(origin_upper_left) in vec4 gl_FragCoord;

void main() {
	ivec2 imageCoord = ivec2(gl_FragCoord.xy);

	float mapDepth = texelFetch(mapDepthTex, imageCoord, 0).r;
	float modelDepth = texelFetch(modelDepthTex, imageCoord, 0).r;
	//float modelDepth = texture(modelDepthTex, uv).r;
/*
	#if (USE_MATERIAL_INDICES == 1)
		bool cond = mapDepth + eps >= modelDepth;
	#else
		bool cond = mapDepth + eps >= modelDepth && modelDepth < 1.0;
	#endif
*/

	//bool cond = true;
	bool cond = (modelDepth < 1.0);
	//bool cond = mapDepth + eps >= modelDepth && modelDepth < 1.0;

	#if (USE_MATERIAL_INDICES == 1)
		#define MATERIAL_UNITS_MAX_INDEX 127
		#define MATERIAL_UNITS_MIN_INDEX 1

		if (cond) {
			int matIndices = int(texelFetch(modelMiscTex, imageCoord, 0).r * 255.0);
			cond = cond && (matIndices >= MATERIAL_UNITS_MIN_INDEX) && (matIndices <= MATERIAL_UNITS_MAX_INDEX);
		}
	#endif

	gl_FragColor = mix(vec4(0.0, 0.0, 0.0, 0.0), outlineColor, vec4(cond));
	gl_FragDepth = mix(1.0, modelDepth, float(cond));
}