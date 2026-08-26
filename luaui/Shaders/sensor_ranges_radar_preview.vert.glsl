#version 420
#line 10000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview cube pass: one instance per grid cell, drawn as a small cube (or slab / flat tile).
// Coverage comes from the smoothed engine-cell coverage texture (one texel per radar cell, see
// sensor_ranges_radar_preview_coverage.frag.glsl / _smooth.frag.glsl), so per vertex this is a
// few tiny texture reads plus cheap animation math.

//__DEFINES__

layout (location = 0) in vec4 cubeVertex; // unit cube corner: x,z in [-0.5, 0.5], y in [0, 1]

uniform vec4 radarcenter_range; // cube grid center x, emitter height, cube grid center z, effective range (elmo)
uniform vec4 gridParams;        // radar cell size (elmo), coverage texels per side, cube spacing (elmo), cubes per radar cell edge
uniform vec4 lookupParams;      // emitter cell x, emitter cell y, radius in cells, allied coverage on (1) / off (0)
uniform vec4 shapeParams;       // cube width, cube height (0 = flat tile), sink below ground, lift of the top above ground
uniform vec4 animParams;        // time (s), seconds since the preview appeared, lod blend (0 = fine grid, 1 = double spacing), conform (1 = top follows terrain)
uniform vec4 windowParams;      // first cube index x, first cube index z, cubes per row, index stride (1 or 2)

uniform sampler2D heightmapTex;
uniform sampler2D coverageTex;
uniform sampler2D radarInfoTex; // allied radar coverage map, R = 1 where any allied radar covers the radar cell (only read when lookupParams.w = 1)

out DataVS {
	vec3 localPos;       // position on the unit cube, for per-face shading and edge lines
	vec4 fx;             // coverage, glow, beam, spawn
	float previewWeight; // 1 = covered by the previewed radar, 0 = only by other allied radars
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000

const float PI = 3.1415927;
const float minCoverage = float(MIN_COVERAGE);
const float sweepSpeed = float(SWEEP_SPEED);
const float sweepTrail = max(float(SWEEP_TRAIL), 0.01); // degrees
const float sweepBeam = max(float(SWEEP_BEAM), 0.01);   // degrees
const float sweepStrength = float(SWEEP_STRENGTH);
const float spawnSpeed = float(SPAWN_SPEED);
const float spawnBump = float(SPAWN_BUMP);
const float pulseFreq = 2.0 * PI / float(PULSE_SPACING);
const float pulseSpeed = 2.0 * PI * float(PULSE_SPEED) / float(PULSE_SPACING);
const float pulsePower = float(PULSE_POWER);
const float pulseStrength = float(PULSE_STRENGTH);
const float edgeStrength = float(EDGE_STRENGTH); // glow of cubes at the coverage boundary (0 = off)
const float rimStrength = float(RIM_STRENGTH);   // glow of the outermost ring of cubes (0 = off)
const float tileMaxTilt = tan(radians(float(TILE_MAX_TILT)));      // slope (rise/run) of the steepest tile tilt
const float tileCliffStart = tan(radians(float(TILE_CLIFF_START))); // terrain slope where tiles start flattening
const float tileCliffEnd = tan(radians(float(TILE_CLIFF_END)));     // terrain slope where tiles are flat again

float heightAtWorldPos(vec2 w) {
	vec2 uvhm = vec2(clamp(w.x, 8.0, mapSize.x - 8.0), clamp(w.y, 8.0, mapSize.y - 8.0)) / mapSize.xy;
	return max(0.0, textureLod(heightmapTex, uvhm, 0.0).x);
}

// Every corner lands on the same clip-space point: zero area, nothing gets rasterized.
void cullInstance() {
	gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
	localPos = vec3(0.0);
	fx = vec4(0.0);
	previewWeight = 0.0;
}

void main() {
	int stride = int(windowParams.w);
	int rowLength = int(windowParams.z);
	// absolute cube grid index: the spacing divides the radar cell size, so with center = (index + 0.5) * spacing
	// every radar cell holds an NxN block of cubes centered inside it
	ivec2 cell = ivec2(windowParams.xy) + ivec2(gl_InstanceID % rowLength, gl_InstanceID / rowLength) * stride;

	// optional far LOD: cells with an odd index shrink away, the remaining ones grow to keep the visual density
	float lodBlend = animParams.z;
	float isFine = float((cell.x | cell.y) & 1);
	float lodScale = 1.0 - isFine * lodBlend;

	float range = radarcenter_range.w;
	vec2 cellXZ = (vec2(cell) + 0.5) * gridParams.z;
	vec2 fromCenter = cellXZ - radarcenter_range.xz;
	float dist = length(fromCenter);

	// which radar cell is this cube in, relative to the emitter's cell
	float radarCell = gridParams.x;
	int radius = int(lookupParams.z);
	ivec2 worldCell = ivec2(floor(cellXZ / radarCell));
	ivec2 off = worldCell - ivec2(lookupParams.xy);
	bool inPreviewDisc = all(lessThanEqual(abs(off), ivec2(radius)));

	// coverage of the previewed radar: R = smoothed coverage, G = boundary factor (covered cell next to an
	// uncovered one); texel center = radar cell center, nearest or bilinear depending on the texture's filter
	vec2 coverageState = vec2(0.0);
	if (inPreviewDisc) {
		vec2 coverageUV = (cellXZ / radarCell - lookupParams.xy + float(radius)) / gridParams.y;
		coverageState = texture(coverageTex, coverageUV).rg;
	}
	float coverage = coverageState.r;

	// with allied coverage enabled (lookupParams.w), cubes covered only by other allied radars are drawn too but
	// stay static; the previewed radar's animation applies in proportion to its own coverage
	float weight = 1.0;
	if (lookupParams.w > 0.5) {
		float allied = 0.0;
		if (all(greaterThanEqual(worldCell, ivec2(0))) && all(lessThan(worldCell, textureSize(radarInfoTex, 0)))) {
			allied = step(0.5, texelFetch(radarInfoTex, worldCell, 0).r);
		}
		weight = smoothstep(0.0, 0.5, coverage);
		coverage = max(coverage, allied);
	} else if (!inPreviewDisc) {
		cullInstance();
		return;
	}

	float distN = dist / range;
	float time = animParams.x;

	// spawn ripple: an expanding ring raises the cubes when the preview appears; they overshoot, then settle.
	// Cubes of other allied radars simply fade in.
	float front = animParams.y * spawnSpeed;
	float spawn = mix(min(animParams.y * 4.0, 1.0), smoothstep(distN - 0.10, distN + 0.02, front), weight);
	float bump = sin(clamp((front - distN) / spawnBump, 0.0, 1.0) * PI) * weight;

	if (coverage < minCoverage || lodScale < 0.02 || spawn < 0.01) {
		cullInstance();
		return;
	}

	// rotating radar sweep: a bright leading edge SWEEP_BEAM degrees wide, with a trail fading out over
	// SWEEP_TRAIL degrees behind it
	float angle = atan(fromCenter.y, fromCenter.x) / (2.0 * PI) + 0.5;
	float behind = (1.0 - fract(angle - time * sweepSpeed)) * 360.0; // degrees behind the leading edge
	float trail = clamp(1.0 - behind / sweepTrail, 0.0, 1.0);
	float sweep = trail * trail * sweepStrength * weight;
	float beam = (1.0 - smoothstep(0.0, sweepBeam, behind)) * sweepStrength * weight;

	// the main animation: rings travelling outward from the radar
	float ring = pow(0.5 + 0.5 * sin(dist * pulseFreq - time * pulseSpeed), pulsePower) * weight;

	// highlight cells at the coverage boundary (an uncovered radar cell next door) and the outer rim (EDGE_STRENGTH, RIM_STRENGTH)
	float edge = coverageState.g;
	float rim = smoothstep(range - 1.5 * radarCell, range - 0.25 * radarCell, dist) * weight;

	float glow = clamp(sweep + beam + edge * edgeStrength + rim * rimStrength + ring * 0.6 * pulseStrength + bump * 0.7, 0.0, 1.5);

	float height = shapeParams.y * (0.35 + 0.65 * coverage) * spawn
		* (1.0 + 0.5 * sweep + pulseStrength * ring + 0.6 * bump);
	float width = shapeParams.x * (0.85 + 0.15 * coverage) * (0.6 + 0.4 * spawn)
		* (1.0 + 0.15 * pulseStrength * ring + 0.1 * bump);
	float coarseGrow = lodBlend * (1.0 - isFine);
	height *= lodScale * (1.0 + 0.5 * coarseGrow);
	width *= lodScale * (1.0 + 0.9 * coarseGrow);

	// Cubes are rigid: every corner uses the cell center height, so slopes and cliffs never stretch or
	// shear them (the uphill side sinks into the slope, the downhill side hovers a little; the bottom face
	// covers that). Flat tiles (conform = 1) get a planar tilt from the terrain gradient around their
	// center, capped at TILE_MAX_TILT degrees and fading back to flat on cliffs, where tilted tiles look odd.
	float centerGround = heightAtWorldPos(cellXZ);

	vec2 vertexXZ = cellXZ + cubeVertex.xz * width;
	float tilt = 0.0;
	if (animParams.w > 0.0) {
		float halfW = 0.5 * width;
		vec2 grad = vec2(
			heightAtWorldPos(cellXZ + vec2(halfW, 0.0)) - heightAtWorldPos(cellXZ - vec2(halfW, 0.0)),
			heightAtWorldPos(cellXZ + vec2(0.0, halfW)) - heightAtWorldPos(cellXZ - vec2(0.0, halfW))) / width;
		float slope = length(grad);
		float tiltScale = min(1.0, tileMaxTilt / max(slope, 1e-4)) * (1.0 - smoothstep(tileCliffStart, tileCliffEnd, slope));
		tilt = dot(grad * tiltScale, cubeVertex.xz * width) * animParams.w;
	}
	float base = centerGround + tilt - shapeParams.z;
	float top = centerGround + tilt + shapeParams.w + height;
	vec3 worldPos = vec3(vertexXZ.x, mix(base, top, cubeVertex.y), vertexXZ.y);

	localPos = cubeVertex.xyz;
	fx = vec4(coverage, glow, beam, spawn);
	previewWeight = weight;
	gl_Position = cameraViewProj * vec4(worldPos, 1.0);
}
