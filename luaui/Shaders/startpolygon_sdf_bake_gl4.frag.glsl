#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// Bakes the start polygon signed distance field into a map-sized texture, once.
//
// The norush timer and start box overlays are fullscreen passes. Walking every
// tessellated polygon edge per screen pixel every frame is what made them cost more
// than the rest of the frame, so that walk happens here, over map texels, and the
// per-frame shaders sample the result instead. See luaui/Include/startpolygon_sdf_gl4.lua
// for the texel layout and the sampling helper both overlays use.

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 20000

uniform int myAllyTeamID = -1;

layout (std430, binding = 4) readonly buffer startPolygonBuffer {
	//-- Quads of: key (team or allyteam id, whatever the widget stored), numVertices, x, z. NUM_POLYGONS blocks.
	vec4 polyVerts[];
};

in DataVS {
	vec4 v_position;
};

out vec4 fragColor;

// Distances are clamped so a half-float target stays finite: filtering between a finite
// and an infinite texel yields NaN.
#define SDF_CLAMP 30000.0

// Signed distance to a polygon ring, negative inside.
float sdPolygon2(in vec2 p, in int startOffset, in int numVertices)
{
	float d = dot(p - polyVerts[startOffset].zw, p - polyVerts[startOffset].zw);
	float s = 1.0;
	for (int i = 0, j = numVertices - 1; i < numVertices; j = i, i++) {
		int newj = startOffset + j;
		int newi = startOffset + i;
		vec2 e = polyVerts[newj].zw - polyVerts[newi].zw;
		vec2 w = p - polyVerts[newi].zw;
		vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
		d = min(d, dot(b, b));

		// winding number from http://geomalgorithms.com/a03-_inclusion.html
		bvec3 cond = bvec3(p.y >= polyVerts[newi].w,
		                   p.y < polyVerts[newj].w,
		                   e.x * w.y > e.y * w.x);
		if (all(cond) || all(not(cond))) s = -s;
	}

	return s * sqrt(d);
}

#line 21000
void main(void)
{
	// The quad's uv spans the whole map, so each texel centre lands on a map position.
	vec2 p = v_position.zw * mapSize.xy;

	float closestbox = SDF_CLAMP;
	float closestKey = 0.0;
	// Least-inside signed distance among the polygons containing p; stays at the sentinel
	// when none does.
	float maxInsideDistance = -SDF_CLAMP;
	bool insideAny = false;
	int numEnemyBoxes = 0;
	int inAllyBox = 0;
	int inScavBox = 0;
	int inRaptorBox = 0;

	int startpoint = 0;
	for (int i = 0; i < NUM_POLYGONS; i++) {
		if (startpoint >= NUM_POINTS) {
			break;
		}

		int key = int(polyVerts[startpoint].x);
		int vertexCount = max(int(polyVerts[startpoint].y), 0);
		int endpoint = min(startpoint + vertexCount, NUM_POINTS);
		if ((endpoint - startpoint) < 3) {
			startpoint = endpoint;
			continue;
		}

		float signedDistance = sdPolygon2(p, startpoint, endpoint - startpoint);
		if (signedDistance < closestbox) {
			closestbox = signedDistance;
			closestKey = float(key);
		}

		if (signedDistance < 0.0) {
			insideAny = true;
			maxInsideDistance = max(maxInsideDistance, signedDistance);
			if (key == myAllyTeamID) {
				inAllyBox = 1;
			} else {
				numEnemyBoxes = numEnemyBoxes + 1;
			}
			#ifdef SCAV_ALLYTEAM_ID
				if (key == SCAV_ALLYTEAM_ID) {
					inScavBox = 1;
				}
			#endif
			#ifdef RAPTOR_ALLYTEAM_ID
				if (key == RAPTOR_ALLYTEAM_ID) {
					inRaptorBox = 1;
				}
			#endif
		}

		startpoint = endpoint;
	}

	// Distance to the edge of the containing polygon, positive inside. Outside it continues
	// as -closestbox so the field is continuous across the edge and filters cleanly.
	float edgeDistance = -(insideAny ? maxInsideDistance : closestbox);

	int flags = inAllyBox | (inScavBox << 1) | (inRaptorBox << 2) | (min(numEnemyBoxes, 2) << 3);

	fragColor = vec4(
		clamp(closestbox, -SDF_CLAMP, SDF_CLAMP),
		closestKey,
		clamp(edgeDistance, -SDF_CLAMP, SDF_CLAMP),
		float(flags)
	);
}
