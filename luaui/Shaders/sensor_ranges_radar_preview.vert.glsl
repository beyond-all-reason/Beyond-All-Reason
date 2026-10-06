#version 420
#line 10000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview sheet pass: one instance per radar cell, its corners placed on the terrain, so neighbouring
// cells form a seamless sheet. Coverage comes from the smoothed engine-cell coverage texture (one texel per
// radar cell, see sensor_ranges_radar_preview_coverage.frag.glsl / _smooth.frag.glsl), so per vertex this
// is a few tiny texture reads.

//__DEFINES__

layout (location = 0) in vec2 cellVertex; // cell corner, x and z in [-0.5, 0.5]

uniform vec4 radarcenter_range; // radar x, emitter height, radar z, effective range (elmo)
uniform vec4 lookupParams;      // emitter cell x, emitter cell y, radius in cells, allied coverage on (1) / off (0)
uniform vec4 animParams;        // time (s), seconds since the preview appeared, z = 1: rings and sweep on, w = 1: sweep on
uniform vec4 windowParams;      // first cell x, first cell z, cells per row, radar cell size (elmo)
uniform float sheetLift;        // elmos the sheet floats above the terrain

uniform sampler2D heightmapTex;
uniform sampler2D coverageTex;
uniform sampler2D radarInfoTex; // allied radar coverage map, R = 1 where any allied radar covers the radar cell (only read when lookupParams.w = 1)

out DataVS {
	vec2 cellPos;        // position in the radar cell, for the outline
	float fade;          // opacity of the cell: spawn ripple, smoothed coverage, allied-only cells muted
	float previewWeight; // 1 = covered by the previewed radar, 0 = only by other allied radars
	flat vec4 outlineSides; // 1 where this cell's -x, +x, -z, +z side is on the previewed radar's own coverage border
	flat vec4 unionOutlineSides; // 1 where that side borders a radar cell not covered by anyone
	vec2 worldXZ;        // world x/z of the vertex, for the per-pixel rings and sweep
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000

const float minCoverage = float(MIN_COVERAGE);
const float spawnSpeed = float(SPAWN_SPEED);
const float alliedAlpha = float(ALLIED_ALPHA);

float heightAtWorldPos(vec2 w) {
	vec2 uvhm = vec2(clamp(w.x, 8.0, mapSize.x - 8.0), clamp(w.y, 8.0, mapSize.y - 8.0)) / mapSize.xy;
	return max(0.0, textureLod(heightmapTex, uvhm, 0.0).x);
}

// smoothed coverage of the previewed radar at a radar cell, -1 outside its disc
float previewCoverageAt(ivec2 radarCell) {
	ivec2 texel = radarCell - ivec2(lookupParams.xy) + ivec2(int(lookupParams.z));
	if (any(lessThan(texel, ivec2(0))) || any(greaterThanEqual(texel, textureSize(coverageTex, 0)))) {
		return -1.0;
	}
	return texelFetch(coverageTex, texel, 0).r;
}

// is the radar cell covered by the previewed radar (and, with includeAllied and allied coverage enabled, any allied radar)?
float coveredAt(ivec2 radarCell, bool includeAllied) {
	float c = previewCoverageAt(radarCell);
	if (includeAllied && lookupParams.w > 0.5 && all(greaterThanEqual(radarCell, ivec2(0))) && all(lessThan(radarCell, textureSize(radarInfoTex, 0)))) {
		c = max(c, texelFetch(radarInfoTex, radarCell, 0).r);
	}
	return step(0.5, c);
}

// Every corner lands on the same clip-space point: zero area, nothing gets rasterized.
void cullInstance() {
	gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
	cellPos = vec2(0.0);
	fade = 0.0;
	previewWeight = 0.0;
	outlineSides = vec4(0.0);
	unionOutlineSides = vec4(0.0);
	worldXZ = vec2(0.0);
}

void main() {
	int rowLength = int(windowParams.z);
	ivec2 cell = ivec2(windowParams.xy) + ivec2(gl_InstanceID % rowLength, gl_InstanceID / rowLength);
	float cellSize = windowParams.w;
	vec2 cellXZ = (vec2(cell) + 0.5) * cellSize;

	float ownCoverage = previewCoverageAt(cell);
	bool inPreviewDisc = ownCoverage >= 0.0;
	ownCoverage = max(ownCoverage, 0.0);
	float coverage = ownCoverage;

	// with allied coverage enabled (lookupParams.w), cells covered only by other allied radars are drawn too but
	// stay static; the previewed radar's animation applies in proportion to its own coverage
	float weight = 1.0;
	if (lookupParams.w > 0.5) {
		float allied = 0.0;
		if (all(greaterThanEqual(cell, ivec2(0))) && all(lessThan(cell, textureSize(radarInfoTex, 0)))) {
			allied = step(0.5, texelFetch(radarInfoTex, cell, 0).r);
		}
		weight = smoothstep(0.0, 0.5, coverage);
		coverage = max(coverage, allied);
	} else if (!inPreviewDisc) {
		cullInstance();
		return;
	}

	// spawn ripple: the sheet spreads outward from the radar when the preview appears; cells of other
	// allied radars simply fade in
	float distN = length(cellXZ - radarcenter_range.xz) / radarcenter_range.w;
	float front = animParams.y * spawnSpeed;
	float spawn = mix(min(animParams.y * 4.0, 1.0), smoothstep(distN - 0.10, distN + 0.02, front), weight);

	if (coverage < minCoverage || spawn < 0.01) {
		cullInstance();
		return;
	}

	// outlineSides: the previewed radar's own coverage border (always drawn, even inside allied coverage);
	// unionOutlineSides: the border of all coverage with uncovered cells
	ivec2 west = cell + ivec2(-1, 0);
	ivec2 east = cell + ivec2(1, 0);
	ivec2 north = cell + ivec2(0, -1);
	ivec2 south = cell + ivec2(0, 1);
	vec4 ownNeighbours = vec4(coveredAt(west, false), coveredAt(east, false), coveredAt(north, false), coveredAt(south, false));
	vec4 anyNeighbours = vec4(coveredAt(west, true), coveredAt(east, true), coveredAt(north, true), coveredAt(south, true));
	outlineSides = step(0.5, ownCoverage) * (1.0 - ownNeighbours);
	unionOutlineSides = 1.0 - anyNeighbours;

	// per-corner terrain heights: neighbouring cells share their corners, so the sheet has no seams
	vec2 vertexXZ = cellXZ + cellVertex * cellSize;
	vec3 worldPos = vec3(vertexXZ.x, heightAtWorldPos(vertexXZ) + sheetLift, vertexXZ.y);

	cellPos = cellVertex;
	fade = spawn * smoothstep(0.0, 0.5, coverage) * mix(alliedAlpha, 1.0, weight);
	previewWeight = weight;
	worldXZ = vertexXZ;
	gl_Position = cameraViewProj * vec4(worldPos, 1.0);
}
