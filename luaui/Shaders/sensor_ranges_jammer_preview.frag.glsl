#version 420
#line 20000

// Jammer preview, projected onto the terrain: drawn over the screen area of the coverage, each pixel rebuilds its
// world position from the map g-buffer depth and takes the coverage of its radar cell, outlined along the border
// with uncovered radar cells. Being the rendered terrain itself, it covers steep cliffs a sheet of per-cell quads
// cuts through. Over water it lies on the water surface; units and features in front of the terrain stay untinted.

//__DEFINES__

uniform sampler2D mapDepths;   // $map_gbuffer_zvaltex
#if MODEL_DEPTH_TEST
uniform sampler2D modelDepths; // $model_gbuffer_zvaltex
#endif
uniform sampler2D coverageTex; // smoothed coverage of the previewed jammer, one texel per radar cell of its disc
uniform sampler2D alliedTex;   // R = 1 where an allied jammer covers the radar cell, one texel per radar cell of the map
uniform sampler2D targetTex;   // exact engine coverage of the previewed jammer (0/1), same layout as coverageTex

uniform vec4 previewParams; // previewed jammer's emitter cell x, cell z, radius in cells (-1: nothing previewed), seconds since the preview appeared
uniform float previewInactive; // 0 while the previewed jammer jams, 1 while it does not (off, stunned, paused or unpaid), eased in between
uniform float stippleOffset; // radar cells the outline's stipple has travelled clockwise around the coverage
uniform vec2 emitterXZ;     // world x, z of the previewed jammer's emitter, where the spawn ripple starts
uniform vec2 alliedParams;  // allied coverage on (1) / off (0), its opacity

//__ENGINEUNIFORMBUFFERDEFS__

#line 21000

out vec4 fragColor;

const float cellSize = float(RADAR_CELL_SIZE);
const vec3 sheetColor = SHEET_COLOR;
const vec3 alliedColor = ALLIED_COLOR;
const vec3 outlineColor = OUTLINE_COLOR;
const float sheetAlpha = float(SHEET_ALPHA);
const float sheetOutlineAlpha = float(SHEET_OUTLINE_ALPHA);
const float outlineGapAlpha = float(OUTLINE_GAP_ALPHA);
const float outlineWidth = float(OUTLINE_WIDTH); // pixels at 1080p, scaled with the vertical resolution
const float outlineWorldWidth = float(OUTLINE_WORLD_WIDTH); // elmos
const float outlineDashes = float(OUTLINE_DASHES); // per radar cell side
const float alliedAlpha = float(ALLIED_ALPHA);
const float inactiveAlpha = float(INACTIVE_ALPHA);
const float inactiveOutlineAlpha = float(INACTIVE_OUTLINE_ALPHA);
const float minCoverage = float(MIN_COVERAGE);
const float spawnSpeed = float(SPAWN_SPEED);

// texel of the previewed jammer's disc textures for a radar cell, (-1, -1) outside its disc
ivec2 discTexel(ivec2 cell) {
	int radius = int(previewParams.z);
	ivec2 texel = cell - ivec2(previewParams.xy) + ivec2(radius);
	if (radius < 0 || any(lessThan(texel, ivec2(0))) || any(greaterThanEqual(texel, ivec2(2 * radius + 1)))) {
		return ivec2(-1);
	}
	return texel;
}

// smoothed coverage of the previewed jammer at a radar cell, 0 outside its disc
float previewCoverageAt(ivec2 cell) {
	ivec2 texel = discTexel(cell);
	return (texel.x < 0) ? 0.0 : texelFetch(coverageTex, texel, 0).r;
}

// exact engine coverage of the previewed jammer at a radar cell (0/1)
float previewTargetAt(ivec2 cell) {
	ivec2 texel = discTexel(cell);
	return (texel.x < 0) ? 0.0 : step(0.5, texelFetch(targetTex, texel, 0).r);
}

// 1 where an allied jammer covers the radar cell, 0 with allied coverage off
float alliedAt(ivec2 cell) {
	if (alliedParams.x < 0.5 || any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, textureSize(alliedTex, 0)))) {
		return 0.0;
	}
	return step(0.5, texelFetch(alliedTex, cell, 0).r);
}

// Opacity of the stipple along a border at `coord` (radar cells), `rate` cells per pixel along it: OUTLINE_DASHES
// dashes per cell side, centred on the cell corners so the steps of the border stay readable. Anti-aliased, and
// blurred into an even line once the dashes shrink below a few pixels.
float stipple(float coord, float rate) {
	float periodsPerPixel = max(rate * outlineDashes, 1e-4);
	float dashes = smoothstep(0.5 - periodsPerPixel, 0.5 + periodsPerPixel, abs(fract(coord * outlineDashes) - 0.5) * 2.0);
	dashes = mix(dashes, 0.5, smoothstep(0.25, 0.5, periodsPerPixel));
	return mix(outlineGapAlpha, 1.0, dashes);
}

// Stipples of the cell's near x and z side lines and of their corner, travelled `offset` cells clockwise around the
// coverage (x sides run along z, z sides along x). The pattern is symmetric around the corners, so it flows round them.
void stipplesAt(vec2 cellCoord, vec2 nearSide, vec2 pixelCells, float offset, out vec2 sides, out float corner) {
	sides = vec2(
		stipple(cellCoord.y - (nearSide.x * 2.0 - 1.0) * offset, pixelCells.y),
		stipple(cellCoord.x + (nearSide.y * 2.0 - 1.0) * offset, pixelCells.x));
	corner = stipple(offset, max(pixelCells.x, pixelCells.y));
}

// A border's line in a cell: along its near x and z sides that face outside (`sides`), plus the square where those
// sides meet. That square belongs to both lines at a convex corner and to neither at a concave one (only the diagonal
// cell outside), so it is drawn once there, with the stipple of the corner itself.
float borderLine(vec2 sides, float diagonalOut, vec2 edge, vec2 stipples, float cornerStipple) {
	float line = max(sides.x * edge.x * stipples.x, sides.y * edge.y * stipples.y);
	float corner = min(edge.x, edge.y) * max(sides.x * sides.y, (1.0 - sides.x) * (1.0 - sides.y) * diagonalOut);
	return mix(line, cornerStipple, corner);
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
	// radar cells per pixel across x and across z: the width of the borders running along z and x, and the stipple rate
	// of the ones running along x and z
	vec2 xGrad = vec2(dFdx(cellCoord.x), dFdy(cellCoord.x));
	vec2 zGrad = vec2(dFdx(cellCoord.y), dFdy(cellCoord.y));
	vec2 pixelCells = max(vec2(length(xGrad), length(zGrad)), vec2(1e-5));

	if (mapDepth >= 0.999999) {
		discard; // sky
	}
#if MODEL_DEPTH_TEST
	if (texture(modelDepths, screenUV).x < mapDepth) {
		discard; // a unit or feature in front of the terrain
	}
#endif

	ivec2 cell = ivec2(floor(cellCoord));
	float own = previewCoverageAt(cell);
	float allied = alliedAt(cell);
	float inactive = previewInactive;

	// spawn ripple: the previewed jammer's coverage spreads outward from its emitter when the preview appears
	float distN = length((vec2(cell) + 0.5) * cellSize - emitterXZ) / (max(previewParams.z, 1.0) * cellSize);
	float spawn = smoothstep(distN - 0.10, distN + 0.02, previewParams.w * spawnSpeed);

	// the previewed jammer's cells blend in over the muted allied coverage. An inactive one jams nothing: it is a
	// faint hint where no allied jammer covers the cell, allied cells show as they are.
	float weight = smoothstep(0.0, 0.5, own) * spawn;
	float alliedFade = allied * alliedParams.y * alliedAlpha;
	float fillFade = mix(mix(alliedFade, 1.0, weight), max(alliedFade, weight * inactiveAlpha), inactive);
	// the outline follows the exact coverage instead, so a moving jammer's old border doesn't linger
	float ownIn = step(0.5, min(previewTargetAt(cell), spawn));
	float jammedFade = max(alliedFade, ownIn * weight * (1.0 - inactive)); // how strongly a jammer covers the cell
	float ownLineFade = ownIn * weight * mix(1.0, inactiveOutlineAlpha, inactive);
	if (max(fillFade, max(jammedFade, ownLineFade)) < minCoverage) {
		discard;
	}

	// stippled outline on the nearer x and z side of the cell when it borders a cell the previewed jammer does not
	// cover (its own border, drawn even inside allied coverage and faint while inactive) or that no jammer covers
	vec2 inCell = fract(cellCoord);
	vec2 nearSide = step(vec2(0.5), inCell); // 0 = the -x/-z side is nearer, 1 = the +x/+z side
	vec2 edgeDist = 0.5 - abs(inCell - 0.5); // distance to the nearer side, in cells
	ivec2 nx = cell + ivec2(int(nearSide.x) * 2 - 1, 0);
	ivec2 nz = cell + ivec2(0, int(nearSide.y) * 2 - 1);
	ivec2 nd = ivec2(nx.x, nz.y); // diagonally across the nearer corner
	vec3 ownNeighbours = vec3(previewTargetAt(nx), previewTargetAt(nz), previewTargetAt(nd));
	vec3 alliedNeighbours = vec3(alliedAt(nx), alliedAt(nz), alliedAt(nd));
	// x side, z side and diagonal facing outside the previewed jammer's coverage, and outside all jammed cells
	vec3 ownOut = ownIn * (1.0 - ownNeighbours);
	vec3 coveredOut = 1.0 - max(ownNeighbours * (1.0 - inactive), alliedNeighbours);
	// OUTLINE_WIDTH pixels plus OUTLINE_WORLD_WIDTH elmos, so it gets a little thicker when zoomed in; crisp, with a
	// pixel of anti-aliasing on its inner edge
	vec2 width = pixelCells * outlineWidth * viewGeometry.y / 1080.0 + outlineWorldWidth / cellSize;
	vec2 edge = 1.0 - smoothstep(width - pixelCells, width, edgeDist);
	// corners sit in the middle of a dash; an inactive jammer's border stands still
	vec2 stipples, ownStipples;
	float cornerStipple, ownCornerStipple;
	stipplesAt(cellCoord, nearSide, pixelCells, stippleOffset, stipples, cornerStipple);
	stipplesAt(cellCoord, nearSide, pixelCells, stippleOffset * (1.0 - inactive), ownStipples, ownCornerStipple);
	// no outline where the position jumps between pixels (terrain silhouettes) or cells shrink below a pixel
	float outlineOn = (max(cellPixels.x, cellPixels.y) < 1.0) ? sheetOutlineAlpha : 0.0;
	float ownLine = borderLine(ownOut.xy, ownOut.z, edge, ownStipples, ownCornerStipple) * ownLineFade;
	float coveredLine = borderLine(coveredOut.xy, coveredOut.z, edge, stipples, cornerStipple) * jammedFade;
	float lineAlpha = max(ownLine, coveredLine) * outlineOn;

	// the outline over the fill
	vec3 fillColor = mix(alliedColor, sheetColor, weight * (1.0 - inactive * allied));
	float fillAlpha = sheetAlpha * fillFade * (1.0 - lineAlpha);
	float alpha = lineAlpha + fillAlpha;
	fragColor = vec4((outlineColor * lineAlpha + fillColor * fillAlpha) / max(alpha, 1e-4), alpha);
}
