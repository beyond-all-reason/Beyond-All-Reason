#version 420
#line 20000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview sheet, projected onto the terrain: drawn over the screen area of the coverage, each pixel rebuilds
// its world position from the map g-buffer depth and takes the coverage of its radar cell (the engine-cell coverage,
// see sensor_ranges_radar_preview_coverage.frag.glsl: the rounded cells follow the exact coverage, the fill fades with
// the smoothed one from _smooth.frag.glsl), with the rings and the sweep as
// smooth per-pixel gradients, outlined along the border with uncovered radar cells. Being the rendered terrain
// itself, it covers steep cliffs a sheet of per-cell quads cuts through. Over water it lies on the water surface;
// units and features in front of the terrain stay untinted.

#extension GL_ARB_shader_storage_buffer_object : require

//__DEFINES__

uniform sampler2D mapDepths;   // $map_gbuffer_zvaltex
#if MODEL_DEPTH_TEST
uniform sampler2D modelDepths; // $model_gbuffer_zvaltex
#endif
uniform sampler2D coverageTex;  // smoothed coverage of the previewed radar, one texel per radar cell of its disc
uniform sampler2D targetTex;    // its exact engine coverage (0/1), same layout
uniform sampler2D radarInfoTex; // allied radar coverage map, R = 1 where any allied radar covers the radar cell (only read when lookupParams.w = 1)
// Circle mode with allied coverage: per radar cell, the allied radar whose range circle reaches farthest past the cell
// among those covering its terrain, and the runner-up (level * ALLIED_CIRCLE_SLOTS + circle index, 0 = none;
// sensor_ranges_radar_preview_coverage.frag.glsl)
uniform sampler2D alliedWinnerTex;
uniform sampler2D alliedRunnerUpTex;
layout(std430, binding = 5) readonly buffer AlliedCircles {
	vec4 alliedCircles[]; // center x, center z, range (elmos) per allied radar
};

uniform vec4 radarcenter_range; // radar x, emitter height, radar z, effective range (elmo)
uniform vec4 lookupParams;      // emitter cell x, emitter cell y, radius in cells, allied coverage on (1) / off (0)
uniform vec4 animParams;        // time (s), seconds since the preview appeared, z = 1: rings and sweep on, w = 1: sweep on
// x = 1: circle mode (SensorPreviewCircles), y = the previewed radar's range (elmos)
uniform vec4 circleParams;

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

// coverage of the previewed radar at a radar cell, x exact (0/1) and y smoothed, -1 outside its disc
vec2 previewCoverageAt(ivec2 radarCell) {
	ivec2 texel = radarCell - ivec2(lookupParams.xy) + ivec2(int(lookupParams.z));
	if (any(lessThan(texel, ivec2(0))) || any(greaterThanEqual(texel, textureSize(coverageTex, 0)))) {
		return vec2(-1.0);
	}
	return vec2(texelFetch(targetTex, texel, 0).r, texelFetch(coverageTex, texel, 0).r);
}

// Circle mode: the previewed radar's coverage at a radar cell, with the cells past its disc (between the engine's
// staircase and the range circle) taking the coverage of the cell further in on the line from the emitter, so terrain
// shadows carry on to the circle. The coverage is 0 both off the disc and in shadow, so every empty cell farther out
// than the disc's radius counts as off it; shadowed cells there take their inner neighbour's shadow anyway.
vec2 circleCoverageAt(ivec2 radarCell) {
	vec2 coverage = previewCoverageAt(radarCell);
	vec2 offset = vec2(radarCell - ivec2(lookupParams.xy));
	float dist = length(offset);
	if (coverage.x <= 0.0 && dist > lookupParams.z) {
		ivec2 inner = ivec2(lookupParams.xy) + ivec2(floor(offset * ((lookupParams.z - 0.75) / dist) + 0.5));
		coverage = previewCoverageAt(inner);
	}
	return max(coverage, 0.0);
}

// 1 where an allied radar covers the radar cell (engine radar map or our union), 0 with allied coverage off
float alliedAt(ivec2 radarCell) {
	if (lookupParams.w < 0.5 || any(lessThan(radarCell, ivec2(0))) || any(greaterThanEqual(radarCell, textureSize(radarInfoTex, 0)))) {
		return 0.0;
	}
	return step(0.5, texelFetch(radarInfoTex, radarCell, 0).r);
}

// signed distance (elmos, > 0 inside) from worldXZ to the range circle of the allied radar in a texel of
// alliedWinnerTex / alliedRunnerUpTex
float packedCircleDist(float entry, vec2 worldXZ) {
	vec4 circle = alliedCircles[int(entry) % ALLIED_CIRCLE_SLOTS];
	return circle.z - distance(worldXZ, circle.xy);
}

// circle mode: signed distance (cells) from worldXZ to the range circles of the allied radars covering a radar cell's
// terrain (the two reaching farthest past it, which covers the cells where two circles cross), -1e6 for none
float cellCircleDist(ivec2 radarCell, vec2 worldXZ) {
	if (any(lessThan(radarCell, ivec2(0))) || any(greaterThanEqual(radarCell, textureSize(alliedWinnerTex, 0)))) {
		return -1e6;
	}
	float winner = texelFetch(alliedWinnerTex, radarCell, 0).r;
	if (winner < 0.5) {
		return -1e6;
	}
	float dist = packedCircleDist(winner, worldXZ);
	float runnerUp = texelFetch(alliedRunnerUpTex, radarCell, 0).r;
	if (runnerUp > 0.5) {
		dist = max(dist, packedCircleDist(runnerUp, worldXZ));
	}
	return dist / cellSize;
}

// Signed distance in cells to the local boundary, with convex corners cut back and concave
// corners filled. The half-cell radius limit keeps neighboring corners from overlapping.
float roundedBoundary(float covered, vec3 neighbours, vec2 edgeDist) {
	float radius = float(COVERAGE_CORNER_RADIUS);
	if (covered > 0.5) {
		vec2 sideDist = vec2(neighbours.x < 0.5 ? edgeDist.x : 1e6, neighbours.y < 0.5 ? edgeDist.y : 1e6);
		// The concave arc extends into the neighboring empty cell: its old straight edges
		// must also be replaced on this covered side of the cell boundary.
		if (neighbours.x < 0.5 && neighbours.y > 0.5 && neighbours.z > 0.5 && edgeDist.y < radius) {
			sideDist.x = length(vec2(edgeDist.x + radius, edgeDist.y - radius)) - radius;
		}
		if (neighbours.y < 0.5 && neighbours.x > 0.5 && neighbours.z > 0.5 && edgeDist.x < radius) {
			sideDist.y = length(vec2(edgeDist.x - radius, edgeDist.y + radius)) - radius;
		}
		float sdf = min(sideDist.x, sideDist.y);
		if (neighbours.x < 0.5 && neighbours.y < 0.5 && all(lessThan(edgeDist, vec2(radius)))) {
			sdf = radius - length(edgeDist - radius);
		}
		return sdf;
	}
	vec2 sideDist = vec2(neighbours.x > 0.5 ? edgeDist.x : 1e6, neighbours.y > 0.5 ? edgeDist.y : 1e6);
	// Outside a convex corner, antialias against the arc rather than the removed square edge.
	if (neighbours.x > 0.5 && neighbours.z < 0.5 && edgeDist.y < radius) {
		sideDist.x = length(vec2(edgeDist.x + radius, edgeDist.y - radius)) - radius;
	}
	if (neighbours.y > 0.5 && neighbours.z < 0.5 && edgeDist.x < radius) {
		sideDist.y = length(vec2(edgeDist.x - radius, edgeDist.y + radius)) - radius;
	}
	float sdf = -min(sideDist.x, sideDist.y);
	if (neighbours.x < 0.5 && neighbours.y < 0.5 && neighbours.z > 0.5) {
		sdf = radius - length(edgeDist + radius);
	}
	if (all(greaterThan(neighbours, vec3(0.5))) && all(lessThan(edgeDist, vec2(radius)))) {
		sdf = length(edgeDist - radius) - radius;
	}
	return sdf;
}

// x exact (0/1), y smoothed
vec2 boundaryCoverageAt(ivec2 cell, bool allied) {
	if (allied) {
		return vec2(alliedAt(cell));
	}
	return max(circleParams.x > 0.5 ? circleCoverageAt(cell) : previewCoverageAt(cell), 0.0);
}

// The rounded cells of the previewed radar's or the allied coverage at a pixel, shaped by the exact coverage so they move
// with the preview at once: returns the smoothed coverage of its cell (in an uncovered cell, that of its covered
// neighbours, which a filled concave corner borrows), with sdf the signed distance to their boundary in cells (> 0 inside)
float roundedCells(vec2 coord, bool allied, out float sdf) {
	ivec2 cell = ivec2(floor(coord));
	vec2 inCell = fract(coord);
	ivec2 direction = ivec2(step(vec2(0.5), inCell)) * 2 - 1;
	vec2 center = boundaryCoverageAt(cell, allied);
	vec2 nx = boundaryCoverageAt(cell + ivec2(direction.x, 0), allied);
	vec2 nz = boundaryCoverageAt(cell + ivec2(0, direction.y), allied);
	vec2 nd = boundaryCoverageAt(cell + direction, allied);
	vec3 neighbours = step(vec3(0.5), vec3(nx.x, nz.x, nd.x));
	sdf = roundedBoundary(step(0.5, center.x), neighbours, 0.5 - abs(inCell - 0.5));
	if (center.x > 0.5) {
		return center.y;
	}
	return max(nx.y * neighbours.x, max(nz.y * neighbours.y, nd.y * neighbours.z));
}

// Circle mode: signed distance (cells, > 0 inside) to the boundary of the allied coverage at a pixel. Cells near a range
// circle can belong to radars whose circles end short of this pixel, so a neighbouring cell counts as covered for the
// rounded cell boundary only where its own radars' circles reach the pixel; then this cell's coverage is clipped to its
// circles, and a filled concave corner to the neighbours'. Away from the cell sides (further than `reach`, cells) the
// neighbours change nothing visible and are skipped.
float alliedCircleCells(vec2 coord, vec2 worldXZ, float reach) {
	ivec2 cell = ivec2(floor(coord));
	vec2 inCell = fract(coord);
	vec2 edgeDist = 0.5 - abs(inCell - 0.5);
	float own = cellCircleDist(cell, worldXZ);
	if (all(greaterThan(edgeDist, vec2(reach)))) {
		return (own > -1e5) ? min(own, min(edgeDist.x, edgeDist.y)) : -1e6;
	}
	ivec2 direction = ivec2(step(vec2(0.5), inCell)) * 2 - 1;
	vec3 neighbourDist = vec3(
		cellCircleDist(cell + ivec2(direction.x, 0), worldXZ),
		cellCircleDist(cell + ivec2(0, direction.y), worldXZ),
		cellCircleDist(cell + direction, worldXZ));
	vec3 neighbours = vec3(greaterThan(neighbourDist, vec3(0.0)));
	float sdf = min(roundedBoundary(0.0, neighbours, edgeDist), max(neighbourDist.x, max(neighbourDist.y, neighbourDist.z)));
	if (own > -1e5) {
		sdf = max(sdf, min(roundedBoundary(1.0, neighbours, edgeDist), own));
	}
	return sdf;
}

// rings travelling outward from the radar (a bright leading edge with a tail fading inward) plus the rotating
// sweep, evaluated per pixel so the sheet shows them as continuous gradients rather than per-cell steps
float sheetGlow(vec2 fromCenter, float time) {
	float dist = length(fromCenter);
	float phase = fract((dist - time * pulseSpeed) / pulseSpacing); // 0 at a ring's center, 1 at the next ring
	// PULSE_SYMMETRIC: smooth bell that fades in and out around the ring, or a sharp front fading out behind it
	float ring = (pulseSymmetric > 0.5) ? pow(0.5 + 0.5 * cos(phase * 2.0 * PI), pulsePower) : pow(1.0 - phase, pulsePower);
	float glow = ring * sheetRingStrength;
	if (animParams.w > 0.5) { // RadarPreviewSweep
		float angle = atan(fromCenter.y, fromCenter.x) / (2.0 * PI) + 0.5;
		float behind = (1.0 - fract(angle - time * sweepSpeed)) * 360.0; // degrees behind the sweep's leading edge
		float trail = clamp(1.0 - behind / sweepTrail, 0.0, 1.0);
		glow += (trail * trail + (1.0 - smoothstep(0.0, sweepBeam, behind))) * sweepStrength;
	}
	return clamp(glow, 0.0, 1.0);
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

	ivec2 cell = ivec2(floor(cellCoord));
	bool circles = circleParams.x > 0.5;
	float pixelCells = max(max(cellPixels.x, cellPixels.y), 1e-5);
	// circle mode: the previewed radar's coverage ends at a circle at its range around it
	float circleSdf = circleParams.y - distance(worldPos.xz, radarcenter_range.xz);
	if (lookupParams.w < 0.5 && (circles ? circleSdf < -pixelCells * cellSize : previewCoverageAt(cell).x < 0.0)) {
		discard;
	}

	// The previewed radar's coverage and, with allied coverage on (lookupParams.w), that of all allied radars: each
	// its rounded cells, in circle mode clipped to the range circles, antialiased along the signed distance (cells)
	float ownBoundarySdf;
	float ownCoverage = roundedCells(cellCoord, false, ownBoundarySdf);
	if (circles) {
		ownBoundarySdf = min(ownBoundarySdf, circleSdf / cellSize);
	}
	ownCoverage *= clamp(ownBoundarySdf / pixelCells + 0.5, 0.0, 1.0);
	float ownWeight = smoothstep(0.0, 0.5, ownCoverage);
	float coverage = ownCoverage;

	// cells covered only by other allied radars are drawn too but stay static; the previewed radar's animation
	// applies in proportion to its own coverage
	float width = pixelCells * outlineWidth * viewGeometry.y / 1080.0; // outline width in cells
	float weight = 1.0;
	float alliedBoundarySdf = -1e6;
	float alliedCoverage = 0.0;
	if (lookupParams.w > 0.5) {
		weight = ownWeight;
		if (circles) {
			alliedBoundarySdf = alliedCircleCells(cellCoord, worldPos.xz, max(float(COVERAGE_CORNER_RADIUS), width + pixelCells));
			alliedCoverage = 1.0;
		} else {
			alliedCoverage = roundedCells(cellCoord, true, alliedBoundarySdf);
		}
		alliedCoverage *= clamp(alliedBoundarySdf / pixelCells + 0.5, 0.0, 1.0);
		coverage = max(coverage, alliedCoverage);
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
#if MODEL_DEPTH_TEST
	if (texture(modelDepths, screenUV).x < mapDepth) {
		discard; // a unit or feature in front of the terrain
	}
#endif
	float fade = spawn * smoothstep(0.0, 0.5, coverage) * mix(alliedAlpha, 1.0, weight);

	// outline along the previewed radar's own border (inside allied coverage too) and along the outer border of all
	// coverage; where they coincide they are the same line. None where a pixel spans several cells (far out, or where
	// the position jumps between pixels at terrain silhouettes).
	float outerSdf = max(ownCoverage >= minCoverage ? ownBoundarySdf : -1e6, alliedCoverage >= minCoverage ? alliedBoundarySdf : -1e6);
	float ownLine = (1.0 - smoothstep(0.0, width, ownBoundarySdf)) * ownWeight;
	float outline = pixelCells < 4.0 ? max(ownLine, 1.0 - smoothstep(0.0, width, outerSdf)) : 0.0;

	// only the previewed radar's own coverage animates (weight), cells of other allied radars stay still
	float glow = 0.0;
	if (weight > 0.0 && animParams.z > 0.5) {
		glow = sheetGlow(worldPos.xz - radarcenter_range.xz, animParams.x) * weight;
	}
	// allied-only cells muted, the rings blend it all the way to the pulse color
	vec3 tint = mix(alliedColor, sheetColor, weight);
	vec3 fillColor = mix(tint, sheetPulseColor, glow);
	float fillAlpha = min(sheetAlpha * (1.0 + glow), 1.0);
	fragColor = vec4(mix(fillColor, outlineColor, outline), mix(fillAlpha, sheetOutlineAlpha, outline) * fade);
}
