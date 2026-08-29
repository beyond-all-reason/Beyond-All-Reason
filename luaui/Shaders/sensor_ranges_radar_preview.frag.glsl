#version 420
#line 20000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview cube pass, fragment stage: per-face shading and zoom-independent edge lines.

//__DEFINES__

in DataVS {
	vec3 localPos;       // position on the unit cube
	vec4 fx;             // coverage, glow, beam, spawn
	float previewWeight; // 1 = covered by the previewed radar, 0 = only by other allied radars
	flat vec4 outlineSides; // background pass: 1 where this cell's -x, +x, -z, +z side is on the previewed radar's own coverage border
	flat vec4 unionOutlineSides; // background pass: 1 where that side borders a radar cell not covered by anyone
	vec2 worldXZ;        // world x/z, for the sheet-only style's per-pixel rings and sweep
};

uniform vec4 modeParams;        // x = 1: background pass, y = 1: sheet-only style (RadarPreviewStyle 1)
uniform vec4 radarcenter_range; // cube grid center x, emitter height, cube grid center z, effective range (elmo)
uniform vec4 animParams;        // time (s), seconds since the preview appeared, lod blend, conform

// Occlusion is tested against the deferred g-buffer depths instead of the regular depth buffer, so
// terrain (and units) hide the cubes but things drawn into the depth buffer by widgets, like grass, don't.
#if TERRAIN_DEPTH_TEST
uniform sampler2D mapDepths; // $map_gbuffer_zvaltex
#endif
#if MODEL_DEPTH_TEST
uniform sampler2D modelDepths; // $model_gbuffer_zvaltex
#endif

//__ENGINEUNIFORMBUFFERDEFS__

#line 21000

out vec4 fragColor;

const vec3 baseColor = BASE_COLOR;
const vec3 highlightColor = HIGHLIGHT_COLOR;
const vec3 alliedColor = ALLIED_COLOR;
const float alliedAlpha = float(ALLIED_ALPHA);
const vec3 backgroundColor = BACKGROUND_COLOR;
const float backgroundAlpha = float(BACKGROUND_ALPHA);
const vec3 outlineColor = OUTLINE_COLOR;
const float outlineAlpha = float(OUTLINE_ALPHA);
const float outlineWidth = float(OUTLINE_WIDTH); // pixels at 1080p, scaled with the vertical resolution
const float baseAlpha = float(BASE_ALPHA);
const float lineAlpha = float(LINE_ALPHA);
const float depthBias = 1e-6; // window-space depth tolerance (a few elmo far away, sub-elmo up close)

// sheet-only style: the sheet carries the animation itself, as smooth per-pixel gradients
const float PI = 3.1415927;
const vec3 sheetColor = SHEET_COLOR;
const vec3 sheetPulseColor = SHEET_PULSE_COLOR;
const float sheetBackgroundAlpha = float(SHEET_BACKGROUND_ALPHA);
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
	float phase = fract((dist - time * pulseSpeed) / pulseSpacing); // 0 at a ring's leading edge, 1 just inside the next ring
	float ring = pow(1.0 - phase, pulsePower);
	float angle = atan(fromCenter.y, fromCenter.x) / (2.0 * PI) + 0.5;
	float behind = (1.0 - fract(angle - time * sweepSpeed)) * 360.0; // degrees behind the sweep's leading edge
	float trail = clamp(1.0 - behind / sweepTrail, 0.0, 1.0);
	float sweep = (trail * trail + (1.0 - smoothstep(0.0, sweepBeam, behind))) * sweepStrength;
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

	if (modeParams.x > 0.5) {
		// background sheet: flat fill, plus an outline on the sides that border uncovered radar cells
		vec2 edgeDist = 0.5 - abs(localPos.xz);
		float outlinePixels = outlineWidth * viewGeometry.y / 1080.0;
		vec2 px = max(fwidth(localPos.xz), vec2(1e-5)) * outlinePixels;
		vec2 nearSide = step(vec2(0.0), localPos.xz);
		vec2 side = max(mix(outlineSides.xz, outlineSides.yw, nearSide), mix(unionOutlineSides.xz, unionOutlineSides.yw, nearSide));
		vec2 lineAmount = side * (1.0 - smoothstep(vec2(0.0), px, edgeDist));
		float outline = max(lineAmount.x, lineAmount.y);
		float fade = fx.w * smoothstep(0.0, 0.5, fx.x) * mix(alliedAlpha, 1.0, previewWeight);
		vec3 fillColor = backgroundColor;
		float fillAlpha = backgroundAlpha;
		float borderAlpha = outlineAlpha;
		if (modeParams.y > 0.5) {
			// sheet-only style: more opaque, and animated by the rings and the sweep. Like the cubes, only the
			// previewed radar's own coverage animates (previewWeight), cells of other allied radars stay still.
			float glow = sheetGlow(worldXZ - radarcenter_range.xz, animParams.x) * previewWeight;
			// the cubes' vivid tint (allied-only cells muted like allied cubes), the rings blend it all the way to the pulse color
			vec3 tint = mix(alliedColor, sheetColor, previewWeight);
			fillColor = mix(tint, sheetPulseColor, glow);
			fillAlpha = min(sheetBackgroundAlpha * (1.0 + glow), 1.0);
			borderAlpha = sheetOutlineAlpha;
		}
		fragColor = vec4(mix(fillColor, outlineColor, outline), mix(fillAlpha, borderAlpha, outline) * fade);
		return;
	}

	// which face are we on? the largest |coordinate| of the centered cube decides
	vec3 centered = vec3(localPos.x, localPos.y - 0.5, localPos.z);
	vec3 a = abs(centered);
	vec3 normal;
	vec2 facePos;
	if (a.y >= a.x && a.y >= a.z) {
		normal = vec3(0.0, sign(centered.y), 0.0);
		facePos = centered.xz;
	} else if (a.x >= a.z) {
		normal = vec3(sign(centered.x), 0.0, 0.0);
		facePos = centered.yz;
	} else {
		normal = vec3(0.0, 0.0, sign(centered.z));
		facePos = centered.xy;
	}

	// lit top, sides shaded by the map's sun direction
	vec2 sunXZ = normalize(sunDir.xz + vec2(1e-4, 0.0));
	float shade = (normal.y > 0.5) ? 1.0 : 0.5 + 0.3 * (0.5 + 0.5 * dot(normal.xz, sunXZ));

	// ~1 px anti-aliased edge lines regardless of zoom level; LINE_ALPHA <= 0 disables them entirely
	float line = 0.0;
	if (lineAlpha > 0.0) {
		float edgeDist = min(0.5 - abs(facePos.x), 0.5 - abs(facePos.y));
		float lineWidth = fwidth(edgeDist) * 1.2 + 0.01;
		line = 1.0 - smoothstep(0.0, lineWidth, edgeDist);
	}

	float coverage = fx.x;
	float glow = min(fx.y, 1.0);
	float beam = fx.z;
	float spawn = fx.w;

	// cubes covered only by other allied radars use the muted allied look
	vec3 tint = mix(alliedColor, baseColor, previewWeight);
	vec3 color = mix(tint * shade, highlightColor, glow * 0.55);
	color = mix(color, highlightColor, line * 0.6);
	color += highlightColor * beam * 0.25;

	float alpha = (baseAlpha + 0.3 * glow) * (0.8 + 0.2 * coverage);
	alpha = max(alpha, line * lineAlpha) * mix(alliedAlpha, 1.0, previewWeight);
	fragColor = vec4(color, alpha * spawn);
}
