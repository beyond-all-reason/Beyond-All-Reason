#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com), Licensed under the MIT License

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 20000

uniform int noRushTimer;
float noRushFramesLeft;

layout (std430, binding = 4) buffer startPolygonBuffer {
	//-- Quads of: teamID, numVertices, x, z. NUM_POLYGONS blocks, NUM_POINTS vertices total.
	vec4 polyVerts[];
};

in DataVS {
	vec4 v_position;
};

uniform sampler2D mapDepths;

out vec4 fragColor;

// Signed distance to a polygon ring, negative inside. Lifted from
// map_startpolygon_gl4.frag.glsl so both overlays measure startboxes the same way.
float sdPolygon2( in vec2 p, in int startOffset, in int numVertices)
{
	const int num = numVertices;
	float d = dot(p - polyVerts[startOffset].zw, p - polyVerts[startOffset].zw);
	float s = 1.0;
	for( int i=0, j=num-1; i<num; j=i, i++ )
	{
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
	vec3 mycolor = vec3(1);
	int startpoint = 0;
	for (int i = 0; i < NUM_POLYGONS; i++) {
		if (startpoint >= NUM_POINTS) {
			break;
		}

		int vertexCount = max(int(polyVerts[startpoint].y), 0);
		int endpoint = min(startpoint + vertexCount, NUM_POINTS);
		if ((endpoint - startpoint) < 3) {
			startpoint = endpoint;
			continue;
		}

		float dist = sdPolygon2(mapWorldPos.xz, startpoint, endpoint - startpoint);
		if (closestbox > dist){
			closestbox = dist;
			mycolor = teamColor[i].rgb;
		}
		startpoint = endpoint;
	}
	// sdPolygon2 is signed, but everything below wants the outside distance and the inside
	// case is flattened to zero alpha anyway, so clamp here and leave that code untouched.
	closestbox = max(closestbox, 0.0);

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