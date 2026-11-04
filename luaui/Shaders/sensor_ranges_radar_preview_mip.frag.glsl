#version 420
#line 34000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview: rebuilds the engine's mip-level radar heightmap on the GPU. The engine averages
// 2x2 blocks per mip level starting from the square-center heightmap (itself the mean of a square's
// four corners), so a radar cell's height is a weighted mean of the (squares+1)^2 corner heights
// covering it, with corner weights 1-2-2-...-2-1 along each axis. Runs once a second while the
// preview is shown (terraform), one texel per radar cell.

//__DEFINES__

uniform sampler2D heightmapTex; // engine corner heightmap, one texel per 8 elmo
uniform vec4 mipParams;         // heightmap squares per radar cell (8 for mip level 3), unused x3

out vec4 fragColor;

void main() {
	int squares = int(mipParams.x);
	ivec2 origin = ivec2(gl_FragCoord.xy) * squares;
	ivec2 maxTexel = textureSize(heightmapTex, 0) - 1;

	float sum = 0.0;
	for (int j = 0; j <= squares; j++) {
		float wj = (j == 0 || j == squares) ? 1.0 : 2.0;
		for (int i = 0; i <= squares; i++) {
			float wi = (i == 0 || i == squares) ? 1.0 : 2.0;
			sum += wi * wj * texelFetch(heightmapTex, min(origin + ivec2(i, j), maxTexel), 0).r;
		}
	}
	fragColor = vec4(sum / float(4 * squares * squares), 0.0, 0.0, 1.0);
}
