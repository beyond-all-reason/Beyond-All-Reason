#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.
//
// Alternative shader path for DrawPrimitiveAtUnit that does not use a
// geometry-shader stage, for backends without a GS stage. The per-unit data
// is bound as an INSTANCE buffer (divisor 1) and this VS expands each
// instance into the same primitive the GS would have, using gl_VertexID.
// The instance is drawn as a fixed triangle LIST of (MAXVERTICES-2)*3
// vertices via glDrawArraysInstanced(GL_TRIANGLES, 0, (MAXVERTICES-2)*3, N).
//
// The GS variant emits triangle_strips of a variable count K (triangle=3,
// quad=4, cornerrect=8, circle=numvertices). We reproduce that strip as a
// triangle list: for triangle t, strip indices are (t,t+1,t+2) with the
// first two swapped on odd t to keep winding. getStripVertex() returns the
// i-th strip vertex for the active primitive (selected at compile time by
// the USE_* defines and at runtime by numvertices); it returns false past
// the primitive's own vertex count, and we emit a degenerate (off-screen)
// vertex for those (and for culled instances).

#line 5000

// Per-instance attributes (divisor 1; attached via VAO:AttachInstanceBuffer).
layout (location = 0) in vec4 lengthwidthcornerheight;
layout (location = 1) in uint teamID;
layout (location = 2) in uint numvertices;
layout (location = 3) in vec4 parameters; // lifestart, ismine
layout (location = 4) in vec4 uvoffsets;  // optional atlas slice
layout (location = 5) in uvec4 instData;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

struct SUniformsBuffer {
    uint composite; //     u8 drawFlag; u8 unused1; u16 id;
    uint unused2;
    uint unused3;
    uint unused4;
    float maxHealth;
    float health;
    float unused5;
    float unused6;
    vec4 drawPos;
    vec4 speed;
    vec4[4] userDefined;
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
    SUniformsBuffer uni[];
};

#define UNITID (uni[instData.y].composite >> 16)

#line 10000

uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;

out PrimData {
	vec4 g_color;
	vec4 g_uv;
};

#if USEQUATERNIONS == 0
	layout(std140, binding=0) readonly buffer MatrixBuffer {
		mat4 UnitPieces[];
	};
#else
	//__QUATERNIONDEFS__
#endif

bool vertexClipped(vec4 clipspace, float tolerance) {
  return any(lessThan(clipspace.xyz, -clipspace.www * tolerance)) ||
         any(greaterThan(clipspace.xyz, clipspace.www * tolerance));
}

// Atlas UV remap, identical to the GS transformUV().
vec2 transformUV(vec4 uvoff, float u, float v){
	float a = uvoff.t - uvoff.s;
	float b = uvoff.q - uvoff.p;
	return vec2(uvoff.s + a * u, uvoff.p + b * v);
}

// Returns the si-th triangle-strip vertex (position offset, UV, radius
// correction) for the primitive selected by nverts. Returns false when si is
// past this primitive's strip length. Mirrors DrawPrimitiveAtUnit.geom.glsl.
bool getStripVertex(int si, uint nverts, float w, float l, float cs,
                    out vec3 off, out vec2 uv, out float corr) {
	off = vec3(0.0); uv = vec2(0.0); corr = 1.0;

#ifdef USE_TRIANGLES
	if (nverts == 3u) {
		corr = 2.0;
		if (si == 0) { off = vec3(0.0, 0.0, l);            uv = vec2(0.5, 1.0); return true; }
		if (si == 1) { off = vec3(-0.866 * w, 0.0, -0.5 * l); uv = vec2(0.0, 0.0); return true; }
		if (si == 2) { off = vec3( 0.866 * w, 0.0, -0.5 * l); uv = vec2(1.0, 0.0); return true; }
		return false;
	}
#endif
#ifdef USE_QUADS
	if (nverts == 4u) {
		corr = 1.414;
		if (si == 0) { off = vec3( w * 0.5, 0.0,  l * 0.5); uv = vec2(0.0, 1.0); return true; }
		if (si == 1) { off = vec3( w * 0.5, 0.0, -l * 0.5); uv = vec2(0.0, 0.0); return true; }
		if (si == 2) { off = vec3(-w * 0.5, 0.0,  l * 0.5); uv = vec2(1.0, 1.0); return true; }
		if (si == 3) { off = vec3(-w * 0.5, 0.0, -l * 0.5); uv = vec2(1.0, 0.0); return true; }
		return false;
	}
#endif
#ifdef USE_CORNERRECT
	if (nverts == 2u) {
		float csuv = (cs / (l + w)) * 2.0;
		corr = 1.1;
		if (si == 0) { off = vec3(-w * 0.5,      0.0, -l * 0.5 + cs); uv = vec2(0.0, csuv);       return true; }
		if (si == 1) { off = vec3(-w * 0.5,      0.0,  l * 0.5 - cs); uv = vec2(0.0, 1.0 - csuv); return true; }
		if (si == 2) { off = vec3(-w * 0.5 + cs, 0.0, -l * 0.5);      uv = vec2(csuv, 0.0);       return true; }
		if (si == 3) { off = vec3(-w * 0.5 + cs, 0.0,  l * 0.5);      uv = vec2(csuv, 1.0);       return true; }
		if (si == 4) { off = vec3( w * 0.5 - cs, 0.0, -l * 0.5);      uv = vec2(1.0 - csuv, 0.0); return true; }
		if (si == 5) { off = vec3( w * 0.5 - cs, 0.0,  l * 0.5);      uv = vec2(1.0 - csuv, 1.0); return true; }
		if (si == 6) { off = vec3( w * 0.5,      0.0, -l * 0.5 + cs); uv = vec2(1.0, csuv);       return true; }
		if (si == 7) { off = vec3( w * 0.5,      0.0,  l * 0.5 - cs); uv = vec2(1.0 - csuv, 1.0); return true; }
		return false;
	}
#endif
#ifdef USE_CIRCLES
	if (nverts > 5u) {
		uint nv = min(nverts, 64u);
		int numSides = int(nv) / 2;
		float internalAngle = float(nv - 2u) * radians(180.0) / float(nv);
		corr = 1.0 / sin(internalAngle / 2.0);
		if (si == 0)            { off = vec3(-w * 0.5, 0.0, 0.0); uv = vec2(0.0, 0.5); return true; }
		if (si == int(nv) - 1)  { off = vec3( w * 0.5, 0.0, 0.0); uv = vec2(1.0, 0.5); return true; }
		if (si >= 1 && si <= 2 * (numSides - 1)) {
			int i = (si + 1) / 2;            // pair index 1..numSides-1
			bool first = ((si & 1) == 1);    // odd si: first of pair (+cos)
			float phi = ((float(i) * 3.141592) / float(numSides)) - 1.5707963;
			float sinphi = sin(phi);
			float cosphi = cos(phi);
			if (first) { off = vec3(w * 0.5 * sinphi, 0.0,  l * 0.5 * cosphi); uv = vec2(sinphi * 0.5 + 0.5, cosphi * 0.5 + 0.5); }
			else       { off = vec3(w * 0.5 * sinphi, 0.0, -l * 0.5 * cosphi); uv = vec2(sinphi * 0.5 + 0.5, cosphi * (-0.5) + 0.5); }
			return true;
		}
		return false;
	}
#endif
	return false;
}

void main()
{
	// ---- per-unit setup (mirrors DrawPrimitiveAtUnit.vert.glsl). The GS
	// variant's VS->GS varyings are kept as locals (v_color, v_rotationY, ...)
	// so that widget-injected GLSL (POST_ANIM/POST_VERTEX/PRE_OFFSET/
	// POST_GEOMETRY), which references those names, compiles here unchanged.
	// ----
	//
	// SEMANTIC CHANGE vs the VS+GS pipeline: in the GS pipeline these
	// injection points ran ONCE per instance (in the VS) and the result was
	// passed to the GS via VS->GS varyings. Here they run ONCE per OUTPUT VERTEX
	// (up to (MAXVERTICES-2)*3 times per instance), because the expansion is
	// inside this VS. All current injection bodies in BAR are idempotent pure
	// writes (e.g. `v_lengthwidthcornerheight.xy *= scale`, `v_parameters.w = x`)
	// so the per-vertex re-evaluation is harmless. DO NOT add an injection that
	// has side effects (counter increment, RNG advance, accumulator) without
	// either making it idempotent or hoisting it out of main(); it will run N
	// times per instance and produce wrong results.
	uint baseIndex = instData.x;
	#if USEQUATERNIONS == 0
		mat4 modelMatrix = UnitPieces[baseIndex];
	#else
		Transform modelWorldTX = GetModelWorldTransform(instData.x);
		mat4 modelMatrix = TransformToMatrix(modelWorldTX);
	#endif

	float v_rotationY = atan(modelMatrix[0][2], modelMatrix[0][0]);
	vec4  v_uvoffsets = uvoffsets;
	vec4  v_parameters = parameters;
	vec4  v_color = teamColor[teamID];
	vec4  v_centerpos = vec4(modelMatrix[3].xyz, 1.0);
	vec4  v_lengthwidthcornerheight = lengthwidthcornerheight;
	#if (ANIMATION == 1)
		float animation = clamp(((timeInfo.x + timeInfo.w) - parameters.x)/GROWTHRATE + INITIALSIZE, INITIALSIZE, 1.0) + sin((timeInfo.x)/BREATHERATE)*BREATHESIZE;
		v_lengthwidthcornerheight.xy *= animation;
	#endif
	POST_ANIM

	uint v_numvertices = numvertices;
	vec4 centerClip = cameraViewProj * vec4(v_centerpos.xyz, 1.0);
	if (vertexClipped(centerClip, CLIPTOLERANCE)) v_numvertices = 0u;

	float cameraDistance = length((cameraViewInv[3]).xyz - v_centerpos.xyz);
	if (cameraDistance > iconDistance) v_numvertices = 0u;

	if (dot(v_centerpos.xyz, v_centerpos.xyz) < 1.0) v_numvertices = 0u;

	v_centerpos.y += HEIGHTOFFSET;
	v_centerpos.y += lengthwidthcornerheight.w;

	#if (FULL_ROTATION == 1)
		mat3 v_fullrotation = mat3(modelMatrix);
	#endif

	if ((uni[instData.y].composite & 0x00000003u) < 1u) v_numvertices = 0u;
	POST_VERTEX

	// ---- orientation (mirrors the GS) ----
	mat3 rotY;
	#if (BILLBOARD == 1)
		rotY = mat3(cameraViewInv[0].xyz, cameraViewInv[2].xyz, cameraViewInv[1].xyz);
	#else
		#if (FULL_ROTATION == 1)
			rotY = v_fullrotation;
		#else
			#if (ROTATE_CIRCLES == 1)
				rotY = rotation3dY(-1.0 * v_rotationY);
			#else
				if (v_numvertices > 5u) rotY = mat3(1.0);
				else rotY = rotation3dY(-1.0 * v_rotationY);
			#endif
		#endif
	#endif

	// ---- strip(K) -> triangle-list expansion via gl_VertexID ----
	int v = gl_VertexID;
	int t = v / 3;       // triangle index within the instance
	int k = v % 3;       // corner within the triangle
	int si;              // strip-vertex index
	if ((t & 1) == 0) {
		si = t + k;
	} else {
		si = (k == 0) ? (t + 1) : ((k == 1) ? (t + 0) : (t + 2));
	}

	float w  = v_lengthwidthcornerheight.x;
	float l  = v_lengthwidthcornerheight.y;
	float cs = v_lengthwidthcornerheight.z;

	vec3 primitiveCoords;
	vec2 uv;
	float addRadiusCorr;
	bool ok = (v_numvertices >= 2u) && getStripVertex(si, v_numvertices, w, l, cs, primitiveCoords, uv, addRadiusCorr);

	if (!ok) {
		// culled, past this primitive's strip, or unsupported count: degenerate.
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		g_color = vec4(0.0);
		g_uv = vec4(0.0);
		return;
	}

	// ---- per-vertex body (mirrors the GS offsetVertex4()) ----
	g_color = v_color;
	g_uv.xy = transformUV(v_uvoffsets, uv.x, uv.y);
	vec3 vecnorm = normalize(primitiveCoords);
	PRE_OFFSET
	gl_Position = cameraViewProj * vec4(v_centerpos.xyz + rotY * (addRadius * addRadiusCorr * vecnorm + primitiveCoords), 1.0);
	#ifdef ZPULL
		gl_Position.z = gl_Position.z - ZPULL / gl_Position.w;
	#endif
	g_uv.zw = v_parameters.zw;
	POST_GEOMETRY
}
