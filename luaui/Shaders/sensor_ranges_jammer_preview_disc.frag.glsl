#version 420
#line 31000

// Jammer preview disc pass: the engine's jammer coverage of one emitter, one texel per radar cell
// (8 << radarMipLevel elmos). Terrain plays no part: CLosMap::AddCircle (rts/Sim/Misc/LosMap.cpp) fills a midpoint
// circle line by line around the emitter's cell, clipped to the map. Uncovered texels are discarded, so the target
// is cleared first and several emitters can be drawn into one map-sized target.

//__DEFINES__

uniform vec4 discParams; // emitter cell x, emitter cell z, radius in cells, 1 = the target is the whole map (texel = radar cell), 0 = the (2 * radius + 1)^2 disc around the emitter

out vec4 fragColor;

// widest half line MidpointCircleAlgoPerLine fills at a row (0..radius) of a filled circle, -1 for none
int halfWidth(int radius, int row) {
	int x = radius;
	int y = 0;
	int decisionOver2 = 1 - radius;
	int width = -1;
	while (x >= y) {
		if (y == row) {
			width = max(width, x); // func(x, y)
		}
		if (decisionOver2 <= 0) {
			y++;
			decisionOver2 += 2 * y + 1;
		} else {
			if (x != y && x == row) {
				width = max(width, y); // func(y, x)
			}
			y++;
			x--;
			decisionOver2 += 2 * (y - x) + 1;
		}
	}
	return width;
}

void main() {
	int radius = int(discParams.z);
	ivec2 base = ivec2(discParams.xy);
	ivec2 texel = ivec2(gl_FragCoord.xy);
	ivec2 off = texel - ((discParams.w > 0.5) ? base : ivec2(radius));
	ivec2 cell = base + off;

	bool onMap = all(greaterThanEqual(cell, ivec2(0))) && all(lessThan(cell, ivec2(MAP_CELLS_X, MAP_CELLS_Z)));
	int row = abs(off.y);
	if (!onMap || row > radius || abs(off.x) > halfWidth(radius, row)) {
		discard;
	}
	fragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
