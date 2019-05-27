#version 150 compatibility

uniform sampler2D modelDepthTex;
uniform sampler2D mapDepthTex;
uniform sampler2D modelMiscTex;

uniform vec4 outlineColor;

#define USE_MATERIAL_INDICES ###USE_MATERIAL_INDICES###

void main() {
	ivec2 imageCoord = ivec2(gl_FragCoord.xy);

	float mapDepth = texelFetch(mapDepthTex, imageCoord, 0).r;
	float modelDepth = texelFetch(modelDepthTex, imageCoord, 0).r;

	bool cond = mapDepth > modelDepth && modelDepth < 1.0;

	vec4 validUnit = vec4(cond);
	#if (USE_MATERIAL_INDICES == 1)
		#define MATERIAL_UNITS_MAX_INDEX 127
		#define MATERIAL_UNITS_MIN_INDEX 1

		if (cond) {
			int matIndices = int(texelFetch(modelMiscTex, imageCoord, 0).r * 255.0);
			validUnit *= float( (matIndices >= MATERIAL_UNITS_MIN_INDEX) && (matIndices <= MATERIAL_UNITS_MAX_INDEX) );
		}
	#endif

	gl_FragColor = mix(vec4(0.0), outlineColor, validUnit);
}