#version 420
#line 31000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview coverage pass: replicates the engine's radar LOS (rts/Sim/Misc/LosMap.cpp) on the
// GPU, one texel per radar cell (8 << radarMipLevel elmos) around the emitter's cell.
// The engine casts a fixed set of rays (to the disk perimeter plus fill-in rays, see
// CLosTableHelper::GetLosRays) in four 90 degree rotations, and a cell stays visible only if no ray
// through it finds it blocked (CastLos angle test with LOS_BONUS_HEIGHT on the mip-level heightmap).
// The widget precomputes, per first-quadrant cell, the targets of all rays through it; this shader
// walks each of those rays up to the cell. Only re-rendered when the emitter cell or height changes.

#extension GL_ARB_shading_language_420pack : require
#extension GL_ARB_shader_storage_buffer_object : require

//__DEFINES__

uniform sampler2D mipHeightTex; // radar-cell heightmap (sensor_ranges_radar_preview_mip.frag.glsl)
uniform vec4 losParams;         // emitter cell x, emitter cell y, radius in cells, emitter height (bucketed)
// 0: the target texture is the (2 * radius + 1)^2 disc around the emitter (texel = cell offset + radius)
// 1: the target texture is the whole map (texel = absolute radar cell), used to union allied radars
uniform float coverageAbsolute = 0.0;
// 0: the coverage (0/1). Allied circle passes, MAX-blended over the allied radars into map-sized textures: 1, per radar
// cell the radar whose range circle reaches farthest past the cell center among those covering the cell's terrain,
// packed as (distance level, circle index); 2, the runner-up, the same leaving out the radar of pass 1.
uniform float alliedCirclePass = 0.0;
uniform vec4 alliedCircle = vec4(0.0); // circle passes: center x, center z, range (elmos), index into the circle list
uniform sampler2D alliedWinnerTex;     // pass 2: the result of pass 1

// per first-quadrant cell (y * (radius + 1) + x): (offset, count); then per ray through a cell: (targetX, targetY)
layout(std430, binding = 5) buffer RayData {
	vec4 rayData[];
};

out vec4 fragColor;

const float LOS_BONUS_HEIGHT = 5.0;

// (height - emitter + bonus) / distance like the engine's raycastAngles; off-map cells never block
float cellAngle(ivec2 cell, ivec2 off, float losHeight) {
	if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, textureSize(mipHeightTex, 0)))) {
		return -1e8;
	}
	float h = max(0.0, texelFetch(mipHeightTex, cell, 0).r);
	return (h - losHeight + LOS_BONUS_HEIGHT) * inversesqrt(float(off.x * off.x + off.y * off.y));
}

// the engine casts each first-quadrant ray as s, -s, (s.y, -s.x) and (-s.y, s.x)
ivec2 rotateOut(ivec2 p, int rot) {
	return (rot == 0) ? p : (rot == 1) ? -p : (rot == 2) ? ivec2(p.y, -p.x) : ivec2(-p.y, p.x);
}

ivec2 rotateIn(ivec2 c, int rot) {
	return (rot == 0) ? c : (rot == 1) ? -c : (rot == 2) ? ivec2(-c.y, c.x) : ivec2(c.y, -c.x);
}

// CastLos along the ray to `target` (first-quadrant coordinates) up to step `steps`, in rotation `rot`
bool visibleAlongRay(ivec2 target, int steps, int rot, ivec2 base, float losHeight) {
	bool xMajor = target.x > target.y;
	float slope = xMajor ? float(target.y) / float(target.x) : float(target.x) / float(target.y);
	float prvAngle = -1e7;
	float maxAngle = -1e7;
	bool vis = true;
	for (int i = 1; i <= steps; i++) {
		int minor = int(floor(slope * float(i) + 0.5));
		ivec2 o = rotateOut(xMajor ? ivec2(i, minor) : ivec2(minor, i), rot);
		float angle = cellAngle(base + o, o, losHeight);

		vis = true;
		if (angle < maxAngle) {
			vis = false;
		} else {
			if (angle < prvAngle) {
				maxAngle = prvAngle - LOS_BONUS_HEIGHT * inversesqrt(float(o.x * o.x + o.y * o.y));
				if (angle < maxAngle) {
					vis = false;
				}
			}
			if (vis) {
				prvAngle = angle;
			}
		}
	}
	return vis;
}

float engineCoverage(ivec2 off) {
	int radius = int(losParams.z);
	ivec2 base = ivec2(losParams.xy);
	float losHeight = losParams.w;

	if (any(greaterThan(abs(off), ivec2(radius)))) {
		return 0.0;
	}
	if (off == ivec2(0)) {
		return 1.0;
	}

	int stride = radius + 1;
	bool onDisk = false;
	bool visible = true;
	// cells on an axis belong to two rotations, so check all four
	for (int rot = 0; rot < 4 && visible; rot++) {
		ivec2 q = rotateIn(off, rot);
		if (q.x < 0 || q.y < 0 || q.x > radius || q.y > radius) {
			continue;
		}
		vec4 head = rayData[q.y * stride + q.x];
		int listOffset = int(head.x);
		int count = int(head.y);
		if (count > 0) {
			onDisk = true;
		}
		int steps = max(q.x, q.y); // rays step along their major axis, so this is q's index on every ray through it
		for (int k = 0; k < count && visible; k++) {
			ivec2 target = ivec2(rayData[listOffset + k].xy);
			visible = visibleAlongRay(target, steps, rot, base, losHeight);
		}
	}

	return (onDisk && visible) ? 1.0 : 0.0;
}

void main() {
	ivec2 base = ivec2(losParams.xy);
	ivec2 off = ivec2(gl_FragCoord.xy) - ((coverageAbsolute > 0.5) ? base : ivec2(int(losParams.z)));
	if (alliedCirclePass < 0.5) {
		fragColor = vec4(engineCoverage(off), 0.0, 0.0, 1.0);
		return;
	}

	// distance from the cell center to the range circle (elmos, > 0 inside); cells past the band record nothing
	float band = float(ALLIED_CIRCLE_BAND);
	float sdf = alliedCircle.z - distance(gl_FragCoord.xy * float(RADAR_CELL_SIZE), alliedCircle.xy);
	if (sdf <= -band) {
		discard;
	}
	float coverage = engineCoverage(off);
	// past the disc the perimeter's terrain shadow carries on outward, as the sheet's circleCoverage does
	float dist = length(vec2(off));
	if (coverage <= 0.0 && dist > losParams.z) {
		coverage = engineCoverage(ivec2(floor(vec2(off) * (max(losParams.z - 0.75, 0.0) / dist) + 0.5)));
	}
	if (coverage <= 0.0) {
		discard;
	}
	// level 1.. (0 = no radar) above the index: MAX blending keeps the largest distance, and the packed value stays an
	// integer below 2^24, exact in the R32F target
	float slots = float(ALLIED_CIRCLE_SLOTS);
	float levels = 16777216.0 / slots;
	float level = 1.0 + floor(clamp(sdf / (2.0 * band) + 0.5, 0.0, 1.0) * (levels - 2.0) + 0.5);
	float entry = level * slots + alliedCircle.w;
	if (alliedCirclePass > 1.5 && texelFetch(alliedWinnerTex, ivec2(gl_FragCoord.xy), 0).r == entry) {
		discard;
	}
	fragColor = vec4(entry, 0.0, 0.0, 1.0);
}
