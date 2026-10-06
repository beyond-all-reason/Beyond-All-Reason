#version 420
#line 20000

// Jammer preview, projected onto the terrain: drawn over the screen area of the coverage, each pixel rebuilds its
// world position from the map g-buffer depth and takes the coverage of its radar cell, outlined along the border
// with uncovered radar cells. Being the rendered terrain itself, it covers steep cliffs a sheet of per-cell quads
// cuts through. Over water it lies on the water surface; units and features in front of the terrain stay untinted.

//__DEFINES__

uniform sampler2D mapDepths;   // $map_gbuffer_zvaltex
#if MODEL_DEPTH_TEST
uniform sampler2D modelDepths; // $model_gbuffer_zvaltex
#endif
uniform sampler2D coverageTex; // smoothed coverage of the previewed jammer, one texel per radar cell of its disc
uniform sampler2D alliedTex;   // R = 1 where an allied jammer covers the radar cell, one texel per radar cell of the map

uniform vec4 previewParams; // previewed jammer's emitter cell x, cell z, radius in cells (-1: nothing previewed), seconds since the preview appeared
uniform vec2 emitterXZ;     // world x, z of the previewed jammer's emitter, where the spawn ripple starts
uniform vec2 alliedParams;  // allied coverage on (1) / off (0), its opacity

//__ENGINEUNIFORMBUFFERDEFS__

#line 21000

out vec4 fragColor;

const float cellSize = float(RADAR_CELL_SIZE);
const vec3 sheetColor = SHEET_COLOR;
const vec3 alliedColor = ALLIED_COLOR;
const vec3 outlineColor = OUTLINE_COLOR;
const float sheetAlpha = float(SHEET_ALPHA);
const float sheetOutlineAlpha = float(SHEET_OUTLINE_ALPHA);
const float outlineWidth = float(OUTLINE_WIDTH); // pixels at 1080p, scaled with the vertical resolution
const float alliedAlpha = float(ALLIED_ALPHA);
const float minCoverage = float(MIN_COVERAGE);
const float spawnSpeed = float(SPAWN_SPEED);

// smoothed coverage of the previewed jammer at a radar cell, 0 outside its disc
float previewCoverageAt(ivec2 cell) {
	int radius = int(previewParams.z);
	ivec2 texel = cell - ivec2(previewParams.xy) + ivec2(radius);
	if (radius < 0 || any(lessThan(texel, ivec2(0))) || any(greaterThanEqual(texel, ivec2(2 * radius + 1)))) {
		return 0.0;
	}
	return texelFetch(coverageTex, texel, 0).r;
}

// 1 where an allied jammer covers the radar cell, 0 with allied coverage off
float alliedAt(ivec2 cell) {
	if (alliedParams.x < 0.5 || any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, textureSize(alliedTex, 0)))) {
		return 0.0;
	}
	return step(0.5, texelFetch(alliedTex, cell, 0).r);
}

void main() {
	vec2 screenUV = (gl_FragCoord.xy - viewGeometry.zw) / viewGeometry.xy;
	float mapDepth = texture(mapDepths, screenUV).x;
	vec4 world = cameraViewProjInv * vec4(screenUV * 2.0 - 1.0, mapDepth, 1.0);
	vec3 worldPos = world.xyz / world.w;
	// over water the coverage lies on the water surface, where the view ray crosses y = 0
	vec3 camPos = cameraViewInv[3].xyz;
	if (worldPos.y < 0.0 && camPos.y > 0.0) {
		worldPos = mix(camPos, worldPos, camPos.y / (camPos.y - worldPos.y));
	}
	vec2 cellCoord = worldPos.xz / cellSize; // position in radar cells
	vec2 cellPixels = fwidth(cellCoord); // radar cells per pixel, taken before any discard

	if (mapDepth >= 0.999999) {
		discard; // sky
	}
#if MODEL_DEPTH_TEST
	if (texture(modelDepths, screenUV).x < mapDepth) {
		discard; // a unit or feature in front of the terrain
	}
#endif

	ivec2 cell = ivec2(floor(cellCoord));
	float own = previewCoverageAt(cell);
	float allied = alliedAt(cell);

	// spawn ripple: the previewed jammer's coverage spreads outward from its emitter when the preview appears
	float distN = length((vec2(cell) + 0.5) * cellSize - emitterXZ) / (max(previewParams.z, 1.0) * cellSize);
	float spawn = smoothstep(distN - 0.10, distN + 0.02, previewParams.w * spawnSpeed);

	// the previewed jammer's cells blend in over the muted allied coverage
	float weight = smoothstep(0.0, 0.5, own) * spawn;
	float fade = mix(allied * alliedParams.y * alliedAlpha, 1.0, weight);
	if (fade < minCoverage) {
		discard;
	}

	// outline on the nearer x and z side of the cell when it borders a cell the previewed jammer does not cover
	// (its own border, drawn even inside allied coverage) or that no jammer covers
	vec2 inCell = fract(cellCoord);
	vec2 nearSide = step(vec2(0.5), inCell); // 0 = the -x/-z side is nearer, 1 = the +x/+z side
	vec2 edgeDist = 0.5 - abs(inCell - 0.5); // distance to the nearer side, in cells
	ivec2 nx = cell + ivec2(int(nearSide.x) * 2 - 1, 0);
	ivec2 nz = cell + ivec2(0, int(nearSide.y) * 2 - 1);
	vec2 ownNeighbours = step(vec2(0.5), vec2(previewCoverageAt(nx), previewCoverageAt(nz)));
	vec2 alliedNeighbours = vec2(alliedAt(nx), alliedAt(nz));
	vec2 side = max(step(0.5, min(own, spawn)) * (1.0 - ownNeighbours), 1.0 - max(ownNeighbours, alliedNeighbours));
	vec2 px = max(cellPixels, vec2(1e-5)) * outlineWidth * viewGeometry.y / 1080.0;
	vec2 lineAmount = side * (1.0 - smoothstep(vec2(0.0), px, edgeDist));
	// no outline where the position jumps between pixels (terrain silhouettes) or cells shrink below a pixel
	float outline = (max(cellPixels.x, cellPixels.y) < 1.0) ? max(lineAmount.x, lineAmount.y) : 0.0;

	vec3 fillColor = mix(alliedColor, sheetColor, weight);
	fragColor = vec4(mix(fillColor, outlineColor, outline), mix(sheetAlpha, sheetOutlineAlpha, outline) * fade);
}
