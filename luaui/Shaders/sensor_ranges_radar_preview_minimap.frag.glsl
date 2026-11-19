#version 420
#line 35000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview minimap pass: a flat fill of the radar coverage on the minimap (RadarPreviewMinimap setting),
// outlined along the border with uncovered radar cells like the sheet in the world.
// The fill fades with the same smoothed per-radar-cell coverage the sheet uses (_smooth.frag.glsl); the outline
// is taken from the exact engine coverage (_coverage.frag.glsl) instead, so it is the same at any instant.
// This matters for the engine minimap, whose texture is refreshed from Game::Update at 15-60 Hz and would
// otherwise freeze the smoothing pass mid-way, with cells easing in or out showing up as stray outlines.

//__DEFINES__

#ifndef COVERAGE_CORNER_RADIUS
#define COVERAGE_CORNER_RADIUS 0.0
#endif

uniform sampler2D coverageTex;  // smoothed coverage of the previewed radar, R = coverage, one texel per radar cell of its disc
uniform sampler2D radarInfoTex; // allied radar coverage map, R = 1 where any allied radar covers the radar cell (only read when discParams.w = 1)
uniform sampler2D targetTex;    // exact engine coverage of the previewed radar (0/1), same layout as coverageTex
uniform vec4 discParams;        // emitter cell x, emitter cell y, radius in cells, allied coverage on (1) / off (0)
uniform vec3 inactiveParams;    // 0 while the previewed emitter works, 1 while it does not (eased in between); its fill and outline opacity then, relative to a working one's. Unset it always works.
uniform vec4 mapParams;         // map width in radar cells, map height in radar cells, minimap rotation (0..3 quarter turns clockwise), outline width in pixels

in vec2 minimapUV;

out vec4 fragColor;

const vec3 sheetColor = SHEET_COLOR;
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
	// an inactive preview covers nothing: it is drawn fainter, and allied cells under it show as they are
	float inactive = inactiveParams.x;
	float fill = max(smoothed * mix(1.0, inactiveParams.y, inactive), allied * alliedAlpha);

	// outline: the sides of this cell that border a cell the previewed radar does not cover (its own coverage
	// border, drawn even inside allied coverage) or that nobody covers. fwidth gives the cell size in pixels
	// for any minimap size, rotation or PIP zoom.
	vec2 inCell = fract(cellPos);
	vec2 nearSide = step(vec2(0.5), inCell); // 0 = the -x/-z side is nearer, 1 = the +x/+z side
	vec2 edgeDist = 0.5 - abs(inCell - 0.5); // distance to the nearer side, in cells
	ivec2 nx = cell + ivec2(int(nearSide.x) * 2 - 1, 0);
	ivec2 nz = cell + ivec2(0, int(nearSide.y) * 2 - 1);
	ivec2 nd = ivec2(nx.x, nz.y); // diagonally across the nearer corner
	vec3 ownN = vec3(ownAt(nx), ownAt(nz), ownAt(nd));
	vec3 alliedN = vec3(alliedAt(nx), alliedAt(nz), alliedAt(nd));
	float covered = 1.0 - inactive * (1.0 - allied);
	vec3 side = max(own * (1.0 - ownN), covered * (1.0 - max(ownN * (1.0 - inactive), alliedN))); // x side, z side, diagonal
	vec2 px = max(fwidth(cellPos), vec2(1e-5)) * mapParams.w;
	vec2 edge = 1.0 - smoothstep(vec2(0.0), px, edgeDist);
	// at a concave corner only the diagonal cell is outside: this cell's corner square closes the outline there
	float corner = (1.0 - side.x) * (1.0 - side.y) * side.z * min(edge.x, edge.y);
	// only covered cells are outlined; a cell the previewed radar just started covering fades its outline in
	// with its fill. Allied-only cells use their own outline opacity.
	float previewWeight = own * smoothstep(0.0, 0.5, smoothed);
	float outline = max(max(side.x * edge.x, side.y * edge.y), corner) * max(previewWeight, allied);
	float outlineA = mix(alliedOutlineAlpha, outlineAlpha * mix(1.0, inactiveParams.z, inactive), previewWeight);

	float boundaryMask = 1.0;
	if (float(COVERAGE_CORNER_RADIUS) > 0.0) {
		float ownSdf = roundedBoundary(own, ownN, edgeDist);
		float alliedSdf = roundedBoundary(allied, alliedN, edgeDist);
		float pixelCells = max(max(fwidth(cellPos).x, fwidth(cellPos).y), 1e-5);
		float ownMask = clamp(ownSdf / pixelCells + 0.5, 0.0, 1.0);
		float alliedMask = clamp(alliedSdf / pixelCells + 0.5, 0.0, 1.0);
		// Concave rounding borrows the neighboring cells' fade rather than appearing fully opaque.
		float ownStrength = own > 0.5 ? smoothed : max(smoothedAt(nx), max(smoothedAt(nz), smoothedAt(nd)));
		smoothed = ownStrength * ownMask;
		allied = max(allied, max(alliedN.x, max(alliedN.y, alliedN.z))) * alliedMask;
		fill = max(smoothed * mix(1.0, inactiveParams.y, inactive), allied * alliedAlpha);
		previewWeight = ownMask * smoothstep(0.0, 0.5, smoothed);
		// the previewed radar's own border (inside allied coverage too) and the outer border of all coverage
		float width = pixelCells * mapParams.w;
		float outerSdf = max(smoothed > 0.00001 ? ownSdf : -1e6, allied > 0.00001 ? alliedSdf : -1e6);
		float ownLine = (1.0 - smoothstep(0.0, width, ownSdf)) * previewWeight;
		outline = max(ownLine, (1.0 - smoothstep(0.0, width, outerSdf)) * max(previewWeight, allied));
		outlineA = mix(alliedOutlineAlpha, outlineAlpha * mix(1.0, inactiveParams.z, inactive), previewWeight);
		boundaryMask = max(ownMask * step(0.00001, smoothed), alliedMask * step(0.00001, allied));
	}

	float alpha = mix(fill * fillAlpha, outlineA, outline);
	alpha *= boundaryMask;
	if (alpha < 0.002) {
		discard;
	}
	vec3 color = mix(alliedColor, sheetColor, smoothed * (1.0 - inactive * allied));
	fragColor = vec4(mix(color, outlineColor, outline), alpha);
}
