#version 420
#line 33000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview smoothing pass. Eases the displayed coverage towards the freshly computed coverage
// every frame (ping-ponged between two textures), so the sheet fades smoothly while the radar
// is dragged around instead of popping in and out.
// The previous state is read with a texel shift, because when the emitter moves to another cell the
// same texel index refers to a different spot in the world.

//__DEFINES__

uniform sampler2D prevTex;   // previously displayed coverage
uniform sampler2D targetTex; // freshly computed coverage

uniform vec4 smoothParams; // texel shift x, texel shift y, lerp factor, reset flag (1 = ignore prevTex)

out vec4 fragColor;

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);
	float target = texelFetch(targetTex, texel, 0).r;

	ivec2 prevTexel = texel + ivec2(smoothParams.xy);
	ivec2 prevSize = textureSize(prevTex, 0);
	float prev = 0.0;
	if (smoothParams.w < 0.5 && all(greaterThanEqual(prevTexel, ivec2(0))) && all(lessThan(prevTexel, prevSize))) {
		prev = texelFetch(prevTex, prevTexel, 0).r;
	}

	fragColor = vec4(mix(prev, target, smoothParams.z), 0.0, 0.0, 1.0);
}
