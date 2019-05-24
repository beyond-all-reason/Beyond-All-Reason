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

	bool modelDepth00 = modelDepth < 1.0;

	// I don't see any difference between horizontal only (below) and horizontal and vertical edge detection passes, thus let's do only horizontal
	bool modelDepth0p = texelFetchOffset(modelDepthTex, imageCoord, 0, ivec2(0,  1)).r < 1.0;
	bool modelDepth0n = texelFetchOffset(modelDepthTex, imageCoord, 0, ivec2(0, -1)).r < 1.0;

	bool cond = mapDepth > modelDepth;

	cond = cond && (
			(modelDepth00 != modelDepth0p) ||
			(modelDepth00 != modelDepth0n)
	);

	vec4 validUnit = vec4(cond);
	#if (USE_MATERIAL_INDICES == 1)
		#define MATERIAL_UNITS_MAX_INDEX 127
		#define MATERIAL_UNITS_MIN_INDEX 1

		if (cond) {
			ivec3 matIndices = ivec3(
				int(texelFetch(modelMiscTex, imageCoord, 0).r * 255.0),
				int(texelFetchOffset(modelMiscTex, imageCoord, 0, ivec2(0,  1)).r * 255.0),
				int(texelFetchOffset(modelMiscTex, imageCoord, 0, ivec2(0, -1)).r * 255.0)
			);

			validUnit *= float(any(lessThanEqual( matIndices, ivec3(MATERIAL_UNITS_MAX_INDEX) )));
			validUnit *= float(any(greaterThanEqual( matIndices, ivec3(MATERIAL_UNITS_MIN_INDEX) )));
		}
	#endif

	gl_FragColor = mix(vec4(0.0), outlineColor, validUnit);
}