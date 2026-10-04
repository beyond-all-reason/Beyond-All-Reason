#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com), Licensed under the MIT License

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 20000

uniform vec4 startBoxes[NUM_BOXES]; // all in xyXY format
uniform int noRushTimer;
float noRushFramesLeft;

in DataVS {
	vec4 v_position;
};

uniform sampler2D mapDepths;

out vec4 fragColor;

float distanceToBox(vec2 point, vec4 box_xyXY) {
	vec2 closestPointInAABB = clamp(point, box_xyXY.xy, box_xyXY.zw);
	vec2 distance = point - closestPointInAABB;
	return length(distance);
}

#line 21000
void main(void)
{
	float mapdepth = texture(mapDepths, v_position.zw).x;
	// Transform screen-space depth to world-space position
	vec4 mapWorldPos =  vec4( vec3(v_position.xy, mapdepth),  1.0);
	mapWorldPos = cameraViewProjInv * mapWorldPos;
	mapWorldPos.xyz = mapWorldPos.xyz / mapWorldPos.w; 

	// We are above or below the map by 4 or more elmost, discard
	if (mapWorldPos.y > (MAXY + 4) || mapWorldPos.y < (MINY - 4)){
		fragColor.rgba = vec4(0);
		return;
	}

	// We are out of the map, discard:
	if ((mapWorldPos.x < 0) || (mapWorldPos.x > mapSize.x) || (mapWorldPos.z < 0) || (mapWorldPos.z > mapSize.y)){
		fragColor.rgba = vec4(0);
		return;
	}

	float closestbox = 1e6;
	float furthestbox = 0;
	vec3 mycolor = vec3(1);
	for (int i = 0; i < NUM_BOXES; i++) {
		float dist = distanceToBox(mapWorldPos.xz, startBoxes[i]);
		if (closestbox > dist){
			closestbox = dist;
			mycolor = teamColor[i].rgb;
		}
		furthestbox = max(furthestbox, dist);
	}
	// Note that now we have the distance to the closest box in closestbox
	// and the distance to the most distant box in furthestbox

	// First we color based on their distance
	noRushFramesLeft = (clamp((noRushTimer - timeInfo.x+30), 0, 300)/300);
	fragColor.rgba = vec4(mycolor * sin(closestbox*3 / (40/3.14)), 0.5);
	//fragColor.rgba = vec4(mycolor*0.5, 0.5);
	if (timeInfo.x < 150) {
		fragColor.a = (timeInfo.x/150) - clamp(1 - exp(-closestbox/400.0) * sin(closestbox*3 / (40/3.14)), 0, 1);
	}
	if (timeInfo.x >= 150) {
		fragColor.a = noRushFramesLeft - clamp(1 - exp(-closestbox/400.0) * sin(closestbox*3 / (40/3.14)), 0, 1);
	}
	// But if we are within a box, then we set the alpha to 0
	if (closestbox < 0.5) {
		fragColor.a = 0.0;
	}
}