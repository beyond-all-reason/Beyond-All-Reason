#version 420
#line 10000

// This shader is (c) Beherith (mysterme@gmail.com), Licensed under the MIT License

//__DEFINES__

layout (location = 0) in vec2 xyworld_xyfract; // [0;1]
uniform vec4 unitcenter_range;  // x y z range
uniform vec4 builddata;  // x,z, anglediff, waterline
uniform int resolution;

uniform sampler2D heightmapTex;

out DataVS {
	vec4 worldPos; // pos and radius
	vec4 blendedcolor;
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11022

float heightAtWorldPos(vec2 w){
	vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy;
	return max(0.0, textureLod(heightmapTex, uvhm, 0.0).x);
}

void main() {
	// transform the point to the center of the unitcenter_range

	vec4 pointWorldPos = vec4(1.0);

	pointWorldPos.xz = (unitcenter_range.xz +  (xyworld_xyfract.xy ) * GRIDSIZE * 8); // transform it out in XZ
	pointWorldPos.y = heightAtWorldPos(pointWorldPos.xz); // get the world height at that point

	int xsize = int(builddata.x) /2;
	int zsize = int(builddata.y)/2;
	float maxHeightDif = builddata.z;
	float waterline = builddata.w;


	float minHeight = 1000000.0;
	float maxHeight = -1000000.0;
	float avgHeight = 0.0;
	float sumBorderSquareHeight = 0.0;
	float numBorderSquares = 0.001;

	for (int x = (-1 * xsize); x <= xsize; x++) {
		for (int z = (-1 * zsize); z <= zsize; z++) {
			vec2 currPos = pointWorldPos.xz + vec2(x,z) * 16;
			float currHeight = heightAtWorldPos(currPos);

			if (x == (-1*xsize) || x == xsize || z == (-1*zsize) || z == zsize) {
				sumBorderSquareHeight += currHeight;
				numBorderSquares += 1.0;
			}
			// restrict the range of {min}
			minHeight = max(minHeight, currHeight - maxHeightDif);
			maxHeight = min(maxHeight, currHeight + maxHeightDif);
			avgHeight += currHeight;
		}
	}
	avgHeight = sumBorderSquareHeight / numBorderSquares;


	//avgHeight = clamp(avgHeight, minHeight + 0.01, maxHeight - 0.01);

	if (avgHeight < 0.01) {
		avgHeight = -1* waterline;
	}

	worldPos = vec4(pointWorldPos);
	blendedcolor = vec4(minHeight,maxHeight,avgHeight,pointWorldPos.y);

	pointWorldPos.y += 0.1;
	worldPos = pointWorldPos;
	gl_Position = cameraViewProj * vec4(pointWorldPos.xyz, 1.0);
}