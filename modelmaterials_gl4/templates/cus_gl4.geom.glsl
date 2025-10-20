//version and extension added by cus_gl4.lua

// Geometry shader that takes each input triangle and subdivides it into 4 smaller triangles.
// Subdivision pattern: original verts a,b,c -> midpoints m01, m12, m20 ->
//  Triangles: (a, m01, m20), (m01, b, m12), (m20, m12, c), (m01, m12, m20)
// All non-flat varyings are linearly interpolated; flat varyings are copied from vertex 0.

layout(triangles) in;
layout(triangle_strip, max_vertices = 12) out;

in Data {
	vec4 pieceVertexPosOrig; // .w contains model maxY
	vec4 worldVertexPos; //.w contains cloakTime
	vec3 worldTangent_VS;
	vec3 worldNormal_VS;
	vec4 uvCoords;
	flat vec4 teamCol; // .a contains selectedness
	vec4 shadowVertexPos; // w contains construction progress 0-1
	vec4 aoterm_fogFactor_selfIllumMod_healthFraction;
} v_in[];

out Data {
	vec4 pieceVertexPosOrig; // .w contains model maxY
	vec4 worldVertexPos; //.w contains cloakTime
	vec3 worldTangent_VS;
	vec3 worldNormal_VS;
	vec4 uvCoords;
	flat vec4 teamCol; // .a contains selectedness
	vec4 shadowVertexPos; // w contains construction progress 0-1
	vec4 aoterm_fogFactor_selfIllumMod_healthFraction;
} g_out;

// Helper to emit a vertex given barycentric weights (w0,w1,w2)
void EmitSubVertex(float w0, float w1, float w2) {
	// Interpolate attributes linearly
	g_out.pieceVertexPosOrig = v_in[0].pieceVertexPosOrig * w0 + v_in[1].pieceVertexPosOrig * w1 + v_in[2].pieceVertexPosOrig * w2;
	g_out.worldVertexPos     = v_in[0].worldVertexPos     * w0 + v_in[1].worldVertexPos     * w1 + v_in[2].worldVertexPos     * w2;
	vec3 tanInterp = v_in[0].worldTangent_VS * w0 + v_in[1].worldTangent_VS * w1 + v_in[2].worldTangent_VS * w2;
	vec3 norInterp = v_in[0].worldNormal_VS  * w0 + v_in[1].worldNormal_VS  * w1 + v_in[2].worldNormal_VS  * w2;
	g_out.worldTangent_VS = normalize(tanInterp);
	g_out.worldNormal_VS  = normalize(norInterp);
	g_out.uvCoords = v_in[0].uvCoords * w0 + v_in[1].uvCoords * w1 + v_in[2].uvCoords * w2;
	g_out.teamCol = v_in[0].teamCol; // flat
	g_out.shadowVertexPos = v_in[0].shadowVertexPos * w0 + v_in[1].shadowVertexPos * w1 + v_in[2].shadowVertexPos * w2;
	g_out.aoterm_fogFactor_selfIllumMod_healthFraction =
		v_in[0].aoterm_fogFactor_selfIllumMod_healthFraction * w0 +
		v_in[1].aoterm_fogFactor_selfIllumMod_healthFraction * w1 +
		v_in[2].aoterm_fogFactor_selfIllumMod_healthFraction * w2;

	gl_Position = gl_in[0].gl_Position * w0 + gl_in[1].gl_Position * w1 + gl_in[2].gl_Position * w2;
#ifdef GL_ARB_clip_distance
	gl_ClipDistance[0] = gl_in[0].gl_ClipDistance[0] * w0 + gl_in[1].gl_ClipDistance[0] * w1 + gl_in[2].gl_ClipDistance[0] * w2;
#endif
	EmitVertex();
}

void main() {
	// Corner weights
	// a = (1,0,0); b = (0,1,0); c = (0,0,1)
	// Midpoints
	// m01 = (0.5,0.5,0)
	// m12 = (0,0.5,0.5)
	// m20 = (0.5,0,0.5)

	// Triangle 0: a, m01, m20
	EmitSubVertex(1.0, 0.0, 0.0);
	EmitSubVertex(0.5, 0.5, 0.0);
	EmitSubVertex(0.5, 0.0, 0.5);
	EndPrimitive();

	// Triangle 1: m01, b, m12
	EmitSubVertex(0.5, 0.5, 0.0);
	EmitSubVertex(0.0, 1.0, 0.0);
	EmitSubVertex(0.0, 0.5, 0.5);
	EndPrimitive();

	// Triangle 2: m20, m12, c
	EmitSubVertex(0.5, 0.0, 0.5);
	EmitSubVertex(0.0, 0.5, 0.5);
	EmitSubVertex(0.0, 0.0, 1.0);
	EndPrimitive();

	// Triangle 3 (center): m01, m12, m20
	EmitSubVertex(0.5, 0.5, 0.0);
	EmitSubVertex(0.0, 0.5, 0.5);
	EmitSubVertex(0.5, 0.0, 0.5);
	EndPrimitive();
}
