#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com), Licensed under the MIT License

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 20000

uniform vec4 startBoxes[NUM_BOXES]; // all in xyXY format
uniform int noRushTimer;
float noRushFramesLeft;


layout (std430, binding = 4) buffer startPolygonBuffer {
	//-- Triplets of :teamID, numVertices, x, z
	// total NUM_POLYGONS count!
	vec4 polyVerts[];
};

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

// Really should be:
//https://www.shadertoy.com/view/wdBXRW
float dot2( in vec2 v ) { return dot(v,v); }
float cross2d( in vec2 v0, in vec2 v1) { return v0.x*v1.y - v0.y*v1.x; }

float sdPolygon2( in vec2 p, in int startOffset, in int numVertices)
{
    const int num = numVertices;
    float d = dot(p - polyVerts[startOffset].zw, p - polyVerts[startOffset].zw);
    float s = 1.0;
    for( int i=0, j=num-1; i<num; j=i, i++ )
    {
        // distance
		int newj = startOffset + j;
		int newi = startOffset + i;
        vec2 e = polyVerts[newj].zw - polyVerts[newi].zw;
        vec2 w =    p - polyVerts[newi].zw;
        vec2 b = w - e*clamp( dot(w,e)/dot(e,e), 0.0, 1.0 );
        d = min( d, dot(b,b) );

        // winding number from http://geomalgorithms.com/a03-_inclusion.html
        bvec3 cond = bvec3( p.y>=polyVerts[newi].w, 
                            p.y <polyVerts[newj].w, 
                            e.x*w.y>e.y*w.x );
        if( all(cond) || all(not(cond)) ) s=-s;  
    }
    
    return s*sqrt(d);
}


#line 21129
void main(void)
{
	float mapdepth = texture(mapDepths, v_position.zw).x;
	// Transform screen-space depth to world-space position
	vec4 mapWorldPos =  vec4( vec3(v_position.xy, mapdepth),  1.0);
	mapWorldPos = cameraViewProjInv * mapWorldPos;
	mapWorldPos.xyz = mapWorldPos.xyz / mapWorldPos.w; 

	// We are above or below the map by 4 or more elmost, discard
	if (mapWorldPos.y > (MAXY) || mapWorldPos.y < (MINY)){
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
	#if 0
	for (int i = 0; i < NUM_BOXES; i++) {
		float dist = distanceToBox(mapWorldPos.xz, startBoxes[i]);
		if (closestbox > dist){
			closestbox = dist;
			mycolor = teamColor[i].rgb;
		}
		furthestbox = max(furthestbox, dist);
	}
	#else
		int startpoint = 0;
		int teamID = int(polyVerts[startpoint].x);
		int endpoint = 2;
		// fair warning: there is probably a bug here that causes an infinet loop if the last box is the same team as the first box
		// also, its not very efficient
		for (int i = 0; i < NUM_POLYGONS; i = i + 1){
			while (int(polyVerts[endpoint].x) == teamID){
				endpoint = endpoint + 1;
			}

			float sd = sdPolygon2(mapWorldPos.xz, startpoint, endpoint - startpoint);

			closestbox = min(closestbox, sd);

			startpoint = endpoint;
			teamID = int(polyVerts[startpoint].x);
		}
	#endif
	// Note that now we have the distance to the closest box in closestbox
	// and the distance to the most distant box in furthestbox

	// First we color based on their distance
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
		fragColor.rgb = vec3(0,1,0);
	}else{
		fragColor.rgb = vec3(fract(closestbox * 0.01))	;
	}
	fragColor.a = 0.5; 
}