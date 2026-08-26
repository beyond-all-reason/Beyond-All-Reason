#version 420
#line 33000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview smoothing pass. Eases the displayed coverage towards the freshly computed coverage
// every frame (ping-ponged between two textures), so cubes rise and sink smoothly while the radar
// is dragged around instead of popping in and out.
// R = smoothed coverage, G = smoothed boundary factor (a covered cell next to an uncovered one),
// computed here once per radar cell instead of once per cube vertex.
// The previous state is read with a texel shift, because when the emitter moves to another cell the
// same texel index refers to a different spot in the world.

//__DEFINES__

uniform sampler2D prevTex;   // previously displayed coverage (R) and boundary factor (G)
uniform sampler2D targetTex; // freshly computed coverage

uniform vec4 smoothParams; // texel shift x, texel shift y, lerp factor, reset flag (1 = ignore prevTex)

out vec4 fragColor;

float targetAt(ivec2 texel, ivec2 size) {
	if (any(lessThan(texel, ivec2(0))) || any(greaterThanEqual(texel, size))) {
		return 0.0;
	}
	return texelFetch(targetTex, texel, 0).r;
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);
	ivec2 size = textureSize(targetTex, 0);
	float target = texelFetch(targetTex, texel, 0).r;
	float neighbourMin = min(
		min(targetAt(texel + ivec2(1, 0), size), targetAt(texel - ivec2(1, 0), size)),
		min(targetAt(texel + ivec2(0, 1), size), targetAt(texel - ivec2(0, 1), size)));
	vec2 targetState = vec2(target, clamp(target - neighbourMin, 0.0, 1.0));

	ivec2 prevTexel = texel + ivec2(smoothParams.xy);
	ivec2 prevSize = textureSize(prevTex, 0);
	vec2 prev = vec2(0.0);
	if (smoothParams.w < 0.5 && all(greaterThanEqual(prevTexel, ivec2(0))) && all(lessThan(prevTexel, prevSize))) {
		prev = texelFetch(prevTex, prevTexel, 0).rg;
	}

	fragColor = vec4(mix(prev, targetState, smoothParams.z), 0.0, 1.0);
}
