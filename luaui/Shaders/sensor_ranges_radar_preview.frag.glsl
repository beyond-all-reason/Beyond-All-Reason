#version 420
#line 20000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview sheet pass, fragment stage: the coverage fill with the rings and the sweep as smooth
// per-pixel gradients, outlined along the border with uncovered radar cells.

//__DEFINES__

in DataVS {
	vec2 cellPos;        // position in the radar cell
	float fade;          // opacity of the cell: spawn ripple, smoothed coverage, allied-only cells muted
	float previewWeight; // 1 = covered by the previewed radar, 0 = only by other allied radars
	flat vec4 outlineSides; // 1 where this cell's -x, +x, -z, +z side is on the previewed radar's own coverage border
	flat vec4 unionOutlineSides; // 1 where that side borders a radar cell not covered by anyone
	vec2 worldXZ;        // world x/z, for the per-pixel rings and sweep
};

uniform vec4 radarcenter_range; // radar x, emitter height, radar z, effective range (elmo)
uniform vec4 animParams;        // time (s), seconds since the preview appeared, z = 1: rings and sweep on, w = 1: sweep on

// Occlusion is tested against the deferred g-buffer depths instead of the regular depth buffer, so
// terrain (and units) hide the sheet but things drawn into the depth buffer by widgets, like grass, don't.
#if TERRAIN_DEPTH_TEST
uniform sampler2D mapDepths; // $map_gbuffer_zvaltex
#endif
#if MODEL_DEPTH_TEST
uniform sampler2D modelDepths; // $model_gbuffer_zvaltex
#endif

//__ENGINEUNIFORMBUFFERDEFS__

#line 21000

out vec4 fragColor;

const vec3 alliedColor = ALLIED_COLOR;
const vec3 outlineColor = OUTLINE_COLOR;
const float outlineWidth = float(OUTLINE_WIDTH); // pixels at 1080p, scaled with the vertical resolution
const float depthBias = 1e-6; // window-space depth tolerance (a few elmo far away, sub-elmo up close)

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
#if TERRAIN_DEPTH_TEST
	vec2 screenUV = (gl_FragCoord.xy - viewGeometry.zw) / viewGeometry.xy;
	float sceneDepth = texture(mapDepths, screenUV).x;
	#if MODEL_DEPTH_TEST
	sceneDepth = min(sceneDepth, texture(modelDepths, screenUV).x);
	#endif
	if (gl_FragCoord.z > sceneDepth + depthBias) {
		discard;
	}
#endif

	// outline on the sides that border uncovered radar cells
	vec2 edgeDist = 0.5 - abs(cellPos);
	float outlinePixels = outlineWidth * viewGeometry.y / 1080.0;
	vec2 px = max(fwidth(cellPos), vec2(1e-5)) * outlinePixels;
	vec2 nearSide = step(vec2(0.0), cellPos);
	vec2 side = max(mix(outlineSides.xz, outlineSides.yw, nearSide), mix(unionOutlineSides.xz, unionOutlineSides.yw, nearSide));
	vec2 lineAmount = side * (1.0 - smoothstep(vec2(0.0), px, edgeDist));
	float outline = max(lineAmount.x, lineAmount.y);

	// only the previewed radar's own coverage animates (previewWeight), cells of other allied radars stay still
	float glow = sheetGlow(worldXZ - radarcenter_range.xz, animParams.x) * previewWeight * animParams.z;
	// allied-only cells muted, the rings blend it all the way to the pulse color
	vec3 tint = mix(alliedColor, sheetColor, previewWeight);
	vec3 fillColor = mix(tint, sheetPulseColor, glow);
	float fillAlpha = min(sheetAlpha * (1.0 + glow), 1.0);
	fragColor = vec4(mix(fillColor, outlineColor, outline), mix(fillAlpha, sheetOutlineAlpha, outline) * fade);
}
