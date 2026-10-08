#version 420
#line 20000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview sheet, projected onto the terrain: drawn over the screen area of the coverage, each pixel rebuilds
// its world position from the map g-buffer depth and takes the coverage of its radar cell (the smoothed engine-cell
// coverage, see sensor_ranges_radar_preview_coverage.frag.glsl / _smooth.frag.glsl), with the rings and the sweep as
// smooth per-pixel gradients, outlined along the border with uncovered radar cells. Being the rendered terrain
// itself, it covers steep cliffs a sheet of per-cell quads cuts through. Over water it lies on the water surface;
// units and features in front of the terrain stay untinted.

//__DEFINES__

uniform sampler2D mapDepths;   // $map_gbuffer_zvaltex
#if MODEL_DEPTH_TEST
uniform sampler2D modelDepths; // $model_gbuffer_zvaltex
#endif
uniform sampler2D coverageTex;
uniform sampler2D radarInfoTex; // allied radar coverage map, R = 1 where any allied radar covers the radar cell (only read when lookupParams.w = 1)

uniform vec4 radarcenter_range; // radar x, emitter height, radar z, effective range (elmo)
uniform vec4 lookupParams;      // emitter cell x, emitter cell y, radius in cells, allied coverage on (1) / off (0)
uniform vec4 animParams;        // time (s), seconds since the preview appeared, z = 1: rings and sweep on, w = 1: sweep on

//__ENGINEUNIFORMBUFFERDEFS__

#line 21000

out vec4 fragColor;

const float cellSize = float(RADAR_CELL_SIZE);
const float minCoverage = float(MIN_COVERAGE);
const float spawnSpeed = float(SPAWN_SPEED);
const float alliedAlpha = float(ALLIED_ALPHA);
const vec3 alliedColor = ALLIED_COLOR;
const vec3 outlineColor = OUTLINE_COLOR;
const float outlineWidth = float(OUTLINE_WIDTH); // pixels at 1080p, scaled with the vertical resolution

const float PI = 3.1415927;
const float pulseSymmetric = float(PULSE_SYMMETRIC); // ring profile: 1 = bell (fade in/out), 0 = sharp front, fade out
const vec3 sheetColor = SHEET_COLOR;
const vec3 sheetPulseColor = SHEET_PULSE_COLOR;
const float sheetAlpha = float(SHEET_ALPHA);
const float sheetOutlineAlpha = float(SHEET_OUTLINE_ALPHA);
const float sheetRingStrength = float(SHEET_RING_STRENGTH);
const float pulseSpacing = float(PULSE_SPACING); // elmos between rings
const float pulseSpeed = float(PULSE_SPEED);     // elmos per second the rings travel outward
const float pulsePower = float(PULSE_POWER);     // higher = shorter tail behind a ring's leading edge
const float sweepSpeed = float(SWEEP_SPEED);
const float sweepTrail = max(float(SWEEP_TRAIL), 0.01); // degrees
const float sweepBeam = max(float(SWEEP_BEAM), 0.01);   // degrees
const float sweepStrength = float(SWEEP_STRENGTH);

// smoothed coverage of the previewed radar at a radar cell, -1 outside its disc
float previewCoverageAt(ivec2 radarCell) {
	ivec2 texel = radarCell - ivec2(lookupParams.xy) + ivec2(int(lookupParams.z));
	if (any(lessThan(texel, ivec2(0))) || any(greaterThanEqual(texel, textureSize(coverageTex, 0)))) {
		return -1.0;
	}
	return texelFetch(coverageTex, texel, 0).r;
}

// 1 where another allied radar covers the radar cell, 0 with allied coverage off
float alliedAt(ivec2 radarCell) {
	if (lookupParams.w < 0.5 || any(lessThan(radarCell, ivec2(0))) || any(greaterThanEqual(radarCell, textureSize(radarInfoTex, 0)))) {
		return 0.0;
	}
	return step(0.5, texelFetch(radarInfoTex, radarCell, 0).r);
}

// rings travelling outward from the radar (a bright leading edge with a tail fading inward) plus the rotating
// sweep, evaluated per pixel so the sheet shows them as continuous gradients rather than per-cell steps
float sheetGlow(vec2 fromCenter, float time) {
	float dist = length(fromCenter);
	float phase = fract((dist - time * pulseSpeed) / pulseSpacing); // 0 at a ring's center, 1 at the next ring
	// PULSE_SYMMETRIC: smooth bell that fades in and out around the ring, or a sharp front fading out behind it
	float ring = (pulseSymmetric > 0.5) ? pow(0.5 + 0.5 * cos(phase * 2.0 * PI), pulsePower) : pow(1.0 - phase, pulsePower);
	float angle = atan(fromCenter.y, fromCenter.x) / (2.0 * PI) + 0.5;
	float behind = (1.0 - fract(angle - time * sweepSpeed)) * 360.0; // degrees behind the sweep's leading edge
	float trail = clamp(1.0 - behind / sweepTrail, 0.0, 1.0);
	float sweep = (trail * trail + (1.0 - smoothstep(0.0, sweepBeam, behind))) * sweepStrength * animParams.w; // RadarPreviewSweep
	return clamp(ring * sheetRingStrength + sweep, 0.0, 1.0);
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
	float ownCoverage = previewCoverageAt(cell);
	bool inPreviewDisc = ownCoverage >= 0.0;
	ownCoverage = max(ownCoverage, 0.0);
	float coverage = ownCoverage;

	// with allied coverage enabled (lookupParams.w), cells covered only by other allied radars are drawn too but
	// stay static; the previewed radar's animation applies in proportion to its own coverage
	float weight = 1.0;
	if (lookupParams.w > 0.5) {
		weight = smoothstep(0.0, 0.5, coverage);
		coverage = max(coverage, alliedAt(cell));
	} else if (!inPreviewDisc) {
		discard;
	}

	// spawn ripple: the sheet spreads outward from the radar when the preview appears; cells of other
	// allied radars simply fade in
	vec2 cellXZ = (vec2(cell) + 0.5) * cellSize;
	float distN = length(cellXZ - radarcenter_range.xz) / radarcenter_range.w;
	float front = animParams.y * spawnSpeed;
	float spawn = mix(min(animParams.y * 4.0, 1.0), smoothstep(distN - 0.10, distN + 0.02, front), weight);

	if (coverage < minCoverage || spawn < 0.01) {
		discard;
	}
	float fade = spawn * smoothstep(0.0, 0.5, coverage) * mix(alliedAlpha, 1.0, weight);

	// outline on the nearer x and z side of the cell when it borders a cell the previewed radar does not cover
	// (its own coverage border, drawn even inside allied coverage) or that no radar covers
	vec2 inCell = fract(cellCoord);
	vec2 nearSide = step(vec2(0.5), inCell); // 0 = the -x/-z side is nearer, 1 = the +x/+z side
	vec2 edgeDist = 0.5 - abs(inCell - 0.5); // distance to the nearer side, in cells
	ivec2 nx = cell + ivec2(int(nearSide.x) * 2 - 1, 0);
	ivec2 nz = cell + ivec2(0, int(nearSide.y) * 2 - 1);
	ivec2 nd = ivec2(nx.x, nz.y); // diagonally across the nearer corner
	vec3 ownNeighbours = step(vec3(0.5), vec3(previewCoverageAt(nx), previewCoverageAt(nz), previewCoverageAt(nd)));
	vec3 anyNeighbours = max(ownNeighbours, vec3(alliedAt(nx), alliedAt(nz), alliedAt(nd)));
	vec3 side = max(step(0.5, ownCoverage) * (1.0 - ownNeighbours), 1.0 - anyNeighbours); // x side, z side, diagonal
	vec2 px = max(cellPixels, vec2(1e-5)) * outlineWidth * viewGeometry.y / 1080.0;
	vec2 edge = 1.0 - smoothstep(vec2(0.0), px, edgeDist);
	// at a concave corner only the diagonal cell is outside and neither side's line reaches the corner: this cell's
	// corner square closes the outline there
	float corner = (1.0 - side.x) * (1.0 - side.y) * side.z * min(edge.x, edge.y);
	float line = max(max(side.x * edge.x, side.y * edge.y), corner);
	// no outline where the position jumps between pixels (terrain silhouettes) or cells shrink below a pixel
	float outline = (max(cellPixels.x, cellPixels.y) < 1.0) ? line : 0.0;

	// only the previewed radar's own coverage animates (weight), cells of other allied radars stay still
	float glow = sheetGlow(worldPos.xz - radarcenter_range.xz, animParams.x) * weight * animParams.z;
	// allied-only cells muted, the rings blend it all the way to the pulse color
	vec3 tint = mix(alliedColor, sheetColor, weight);
	vec3 fillColor = mix(tint, sheetPulseColor, glow);
	float fillAlpha = min(sheetAlpha * (1.0 + glow), 1.0);
	fragColor = vec4(mix(fillColor, outlineColor, outline), mix(fillAlpha, sheetOutlineAlpha, outline) * fade);
}
