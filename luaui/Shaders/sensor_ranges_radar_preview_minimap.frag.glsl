#version 420
#line 35000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview minimap pass: a flat fill of the radar coverage on the minimap (RadarPreviewMinimap setting),
// outlined along the border with uncovered radar cells like the background sheet in the world.
// The fill fades with the same smoothed per-radar-cell coverage the cubes use (_smooth.frag.glsl); the outline
// is taken from the exact engine coverage (_coverage.frag.glsl) instead, so it is the same at any instant.
// This matters for the engine minimap, whose texture is refreshed from Game::Update at 15-60 Hz and would
// otherwise freeze the smoothing pass mid-way, with cells easing in or out showing up as stray outlines.

//__DEFINES__

uniform sampler2D coverageTex;  // smoothed coverage of the previewed radar, R = coverage, one texel per radar cell of its disc
uniform sampler2D radarInfoTex; // allied radar coverage map, R = 1 where any allied radar covers the radar cell (only read when discParams.w = 1)
uniform sampler2D targetTex;    // exact engine coverage of the previewed radar (0/1), same layout as coverageTex
uniform vec4 discParams;        // emitter cell x, emitter cell y, radius in cells, allied coverage on (1) / off (0)
uniform vec4 mapParams;         // map width in radar cells, map height in radar cells, minimap rotation (0..3 quarter turns clockwise), outline width in pixels

in vec2 minimapUV;

out vec4 fragColor;

const vec3 baseColor = BASE_COLOR;
const vec3 alliedColor = ALLIED_COLOR;
const vec3 outlineColor = OUTLINE_COLOR;
const float alliedAlpha = float(ALLIED_ALPHA);
const float fillAlpha = float(MINIMAP_ALPHA);
const float outlineAlpha = float(MINIMAP_OUTLINE_ALPHA);
const float alliedOutlineAlpha = float(MINIMAP_ALLIED_OUTLINE_ALPHA);

// texel of the previewed radar's disc textures for a radar cell, or (-1, -1) outside the disc
ivec2 discTexel(ivec2 cell) {
	int radius = int(discParams.z);
	ivec2 texel = cell - ivec2(discParams.xy) + ivec2(radius);
	if (any(lessThan(texel, ivec2(0))) || any(greaterThanEqual(texel, ivec2(2 * radius + 1)))) {
		return ivec2(-1);
	}
	return texel;
}

// smoothed coverage of the previewed radar at a radar cell (0 outside its disc)
float smoothedAt(ivec2 cell) {
	ivec2 texel = discTexel(cell);
	return (texel.x < 0) ? 0.0 : texelFetch(coverageTex, texel, 0).r;
}

// exact engine coverage of the previewed radar at a radar cell (0 outside its disc)
float ownAt(ivec2 cell) {
	ivec2 texel = discTexel(cell);
	return (texel.x < 0) ? 0.0 : step(0.5, texelFetch(targetTex, texel, 0).r);
}

// 1 where another allied radar covers the radar cell
float alliedAt(ivec2 cell) {
	if (discParams.w < 0.5 || any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, textureSize(radarInfoTex, 0)))) {
		return 0.0;
	}
	return step(0.5, texelFetch(radarInfoTex, cell, 0).r);
}

void main() {
	// minimap (y up) -> normalized world x/z, the inverse of the world -> minimap mapping the other
	// GL4 minimap overlays use (gui_buildsquare_gl4, map_startpolygon_gl4)
	int rotation = int(mapParams.z);
	vec2 world;
	if (rotation == 0) {
		world = vec2(minimapUV.x, 1.0 - minimapUV.y);
	} else if (rotation == 1) {
		world = vec2(minimapUV.y, minimapUV.x);
	} else if (rotation == 2) {
		world = vec2(1.0 - minimapUV.x, minimapUV.y);
	} else {
		world = vec2(1.0 - minimapUV.y, 1.0 - minimapUV.x);
	}
	vec2 cellPos = world * mapParams.xy; // position in radar cells
	ivec2 cell = ivec2(floor(cellPos));

	float smoothed = smoothedAt(cell);
	float own = ownAt(cell);
	float allied = alliedAt(cell);
	float fill = max(smoothed, allied * alliedAlpha);

	// outline: the sides of this cell that border a cell the previewed radar does not cover (its own coverage
	// border, drawn even inside allied coverage) or that nobody covers. fwidth gives the cell size in pixels
	// for any minimap size, rotation or PIP zoom.
	vec2 inCell = fract(cellPos);
	vec2 nearSide = step(vec2(0.5), inCell); // 0 = the -x/-z side is nearer, 1 = the +x/+z side
	vec2 edgeDist = 0.5 - abs(inCell - 0.5); // distance to the nearer side, in cells
	ivec2 nx = cell + ivec2(int(nearSide.x) * 2 - 1, 0);
	ivec2 nz = cell + ivec2(0, int(nearSide.y) * 2 - 1);
	float ownNx = ownAt(nx);
	float ownNz = ownAt(nz);
	vec2 side = vec2(
		max(own * (1.0 - ownNx), 1.0 - max(ownNx, alliedAt(nx))),
		max(own * (1.0 - ownNz), 1.0 - max(ownNz, alliedAt(nz))));
	vec2 px = max(fwidth(cellPos), vec2(1e-5)) * mapParams.w;
	vec2 lineAmount = side * (1.0 - smoothstep(vec2(0.0), px, edgeDist));
	// only covered cells are outlined; a cell the previewed radar just started covering fades its outline in
	// with its fill. Allied-only cells use their own outline opacity.
	float previewWeight = own * smoothstep(0.0, 0.5, smoothed);
	float outline = max(lineAmount.x, lineAmount.y) * max(previewWeight, allied);
	float outlineA = mix(alliedOutlineAlpha, outlineAlpha, previewWeight);

	float alpha = mix(fill * fillAlpha, outlineA, outline);
	if (alpha < 0.002) {
		discard;
	}
	vec3 color = mix(alliedColor, baseColor, smoothed);
	fragColor = vec4(mix(color, outlineColor, outline), alpha);
}
