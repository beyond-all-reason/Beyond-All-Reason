#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Non-geometry-shader fallback for DrawPrimitiveAtUnit.
// The original pipeline used a geometry shader to expand a single point per
// instance into a triangle/quad/cornerrect/circle. Hardware/drivers without
// geometry shader support instead draw an instanced triangle-fan template mesh
// (see DrawPrimitiveAtUnit.lua), and this vertex shader performs the exact same
// point->primitive expansion per-vertex that the geometry shader used to do.

#line 5000

layout (location = 0) in float vinfo; // per-vertex perimeter slot index (0 .. numSlots-1)
layout (location = 1) in vec4 lengthwidthcornerheight;
layout (location = 2) in uint teamID;
layout (location = 3) in uint numvertices;
layout (location = 4) in vec4 parameters; // lifestart, ismine
layout (location = 5) in vec4 uvoffsets; // this is optional, for using an Atlas
layout (location = 6) in uvec4 instData;

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
    vec4[4] userDefined; //can't use float[16] because float in arrays occupies 4 * float space
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
    SUniformsBuffer uni[];
};

#define UNITID (uni[instData.y].composite >> 16)

#line 10000

uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;

// Output interface block, identical to the geometry shader's output so that the
// existing fragment shader (which reads `in DataGS { ... }`) works unchanged.
out DataGS {
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

// Compatibility shim so geometry-shader style POST_GEOMETRY snippets that
// reference dataIn[0].v_xxx still compile in this vertex shader.
struct DataInCompat {
	uint v_numvertices;
	float v_rotationY;
	vec4 v_color;
	vec4 v_lengthwidthcornerheight;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters;
};
DataInCompat dataIn[1];

vec4 uvoffsetsG;
// This function takes in a set of UV coordinates [0,1] and transforms it to the correct UV slice of an atlassed texture
vec2 transformUV(float u, float v){
	float a = uvoffsetsG.t - uvoffsetsG.s;
	float b = uvoffsetsG.q - uvoffsetsG.p;
	return vec2(uvoffsetsG.s + a * u, uvoffsetsG.p + b * v);
}

bool vertexClipped(vec4 clipspace, float tolerance) {
  return any(lessThan(clipspace.xyz, -clipspace.www * tolerance)) ||
         any(greaterThan(clipspace.xyz, clipspace.www * tolerance));
}

// Computes the local-space position + uv + addRadius correction factor for a
// perimeter vertex of the requested primitive shape, matching the geometry shader.
// shape: 0 = triangle, 1 = quad, 2 = cornerrect, 3 = circle
void ringPoint(int shape, uint P, int i, float length, float width, float cs,
               out vec3 localpos, out vec2 uv, out float addRadiusCorr) {
	if (shape == 0) { // triangle pointing "forward"
		addRadiusCorr = 2.000;
		if (i == 0)      { localpos = vec3(0.0, 0.0, length);                  uv = vec2(0.5, 1.0); }
		else if (i == 1) { localpos = vec3(-0.866 * width, 0.0, -0.5 * length); uv = vec2(0.0, 0.0); }
		else             { localpos = vec3( 0.866 * width, 0.0, -0.5 * length); uv = vec2(1.0, 0.0); }
	} else if (shape == 1) { // a quad, ring order A,B,D,C
		addRadiusCorr = 1.414;
		if (i == 0)      { localpos = vec3( width * 0.5, 0.0,  length * 0.5); uv = vec2(0.0, 1.0); } // A
		else if (i == 1) { localpos = vec3( width * 0.5, 0.0, -length * 0.5); uv = vec2(0.0, 0.0); } // B
		else if (i == 2) { localpos = vec3(-width * 0.5, 0.0, -length * 0.5); uv = vec2(1.0, 0.0); } // D
		else             { localpos = vec3(-width * 0.5, 0.0,  length * 0.5); uv = vec2(1.0, 1.0); } // C
	} else if (shape == 2) { // a quad with chopped off corners, convex ring of 8 points
		addRadiusCorr = 1.1; // matches the geometry shader fudge factor
		float csuv = (cs / (length + width)) * 2.0;
		if (i == 0)      { localpos = vec3(-width * 0.5 + cs, 0.0, -length * 0.5     ); uv = vec2(csuv,       0.0       ); } // p3
		else if (i == 1) { localpos = vec3(-width * 0.5,      0.0, -length * 0.5 + cs); uv = vec2(0.0,        csuv      ); } // p1
		else if (i == 2) { localpos = vec3(-width * 0.5,      0.0,  length * 0.5 - cs); uv = vec2(0.0,        1.0 - csuv); } // p2
		else if (i == 3) { localpos = vec3(-width * 0.5 + cs, 0.0,  length * 0.5     ); uv = vec2(csuv,       1.0       ); } // p4
		else if (i == 4) { localpos = vec3( width * 0.5 - cs, 0.0,  length * 0.5     ); uv = vec2(1.0 - csuv, 1.0       ); } // p6
		else if (i == 5) { localpos = vec3( width * 0.5,      0.0,  length * 0.5 - cs); uv = vec2(1.0,        1.0 - csuv); } // p8
		else if (i == 6) { localpos = vec3( width * 0.5,      0.0, -length * 0.5 + cs); uv = vec2(1.0,        csuv      ); } // p7
		else             { localpos = vec3( width * 0.5 - cs, 0.0, -length * 0.5     ); uv = vec2(1.0 - csuv, 0.0       ); } // p5
	} else { // circle with even subdivisions
		float internalAngle = float(P - 2u) * radians(180.0) / float(P);
		addRadiusCorr = 1.0 / sin(internalAngle / 2.0);
		float angle = 2.0 * 3.14159265 * float(i) / float(P);
		float sa = sin(angle);
		float ca = cos(angle);
		localpos = vec3(width * 0.5 * sa, 0.0, length * 0.5 * ca);
		uv = vec2(sa * 0.5 + 0.5, ca * 0.5 + 0.5);
	}
}

void main()
{
	uint baseIndex = instData.x; // this tells us which unit matrix to find
	#if USEQUATERNIONS == 0
		mat4 modelMatrix = UnitPieces[baseIndex]; // This gives us the models world pos and rot matrix
	#else
		Transform modelWorldTX = GetModelWorldTransform(instData.x);
		mat4 modelMatrix = TransformToMatrix(modelWorldTX);
	#endif

	vec4 centerClip = cameraViewProj * vec4(modelMatrix[3].xyz, 1.0); // center of the model
	float v_rotationY = atan(modelMatrix[0][2], modelMatrix[0][0]); // euler Y rot of the model
	vec4 v_uvoffsets = uvoffsets;
	vec4 v_parameters = parameters;
	vec4 v_color = teamColor[teamID]; // lookup the teamcolor
	vec4 v_centerpos = vec4(modelMatrix[3].xyz, 1.0);
	vec4 v_lengthwidthcornerheight = lengthwidthcornerheight;
	#if (ANIMATION == 1)
		float animation = clamp(((timeInfo.x + timeInfo.w) - parameters.x)/GROWTHRATE + INITIALSIZE, INITIALSIZE, 1.0) + sin((timeInfo.x)/BREATHERATE)*BREATHESIZE;
		v_lengthwidthcornerheight.xy *= animation; // modulate it with animation factor
	#endif
	POST_ANIM
	uint v_numvertices = numvertices;

	bool culled = false;
	if (vertexClipped(centerClip, CLIPTOLERANCE)) culled = true; // Cull stuff outside of screen

	// cull units further from cam than iconDistance
	float cameraDistance = length((cameraViewInv[3]).xyz - v_centerpos.xyz);
	if (cameraDistance > iconDistance) culled = true;

	// if the center pos is at (0,0,0) then we probably dont have the matrix yet
	if (dot(v_centerpos.xyz, v_centerpos.xyz) < 1.0) culled = true;

	v_centerpos.y += HEIGHTOFFSET; // Add some height to ensure above groundness
	v_centerpos.y += lengthwidthcornerheight.w; // Add per-instance height offset
	#if (FULL_ROTATION == 1)
		mat3 v_fullrotation = mat3(modelMatrix);
	#endif
	// drawFlag check (==1 when unit is visible and drawn as a full model, not an icon)
	if ((uni[instData.y].composite & 0x00000003u) < 1u ) culled = true;
	POST_VERTEX

	if (v_numvertices == 0u) culled = true;

	// Determine the primitive shape and its perimeter point count P from numvertices
	uint K = v_numvertices;
	int shape = -1;
	uint P = 0u;
	#ifdef USE_TRIANGLES
		if (K == 3u) { shape = 0; P = 3u; }
	#endif
	#ifdef USE_QUADS
		if (K == 4u) { shape = 1; P = 4u; }
	#endif
	#ifdef USE_CORNERRECT
		if (K == 2u) { shape = 2; P = 8u; }
	#endif
	#ifdef USE_CIRCLES
		if (K > 5u) { shape = 3; P = min(K, 64u); }
	#endif
	if (shape < 0) culled = true;

	if (culled) {
		// Collapse the whole instance into a degenerate, offscreen primitive
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		g_color = vec4(0.0);
		g_uv = vec4(0.0);
		return;
	}

	// Build the rotation matrix exactly as the geometry shader did
	mat3 rotY;
	#if (BILLBOARD == 1 )
		rotY = mat3(cameraViewInv[0].xyz, cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz
	#else
		#if (FULL_ROTATION == 1)
			rotY = v_fullrotation; // Use the units true rotation
		#else
			#if (ROTATE_CIRCLES == 1)
				rotY = rotation3dY(-1.0 * v_rotationY);
			#else
				if (K > 5u) rotY = mat3(1.0);
				else rotY = rotation3dY(-1.0 * v_rotationY);
			#endif
		#endif
	#endif

	uvoffsetsG = v_uvoffsets;
	g_color = v_color;

	float plength = v_lengthwidthcornerheight.x;
	float pwidth  = v_lengthwidthcornerheight.y;
	float pcs     = v_lengthwidthcornerheight.z;

	// Map this vertex's template slot to a clamped perimeter ring index, so that
	// slots beyond P collapse onto the last real vertex (zero-area triangles).
	int slot = int(vinfo);
	int ri = min(slot, int(P) - 1);

	vec3 primitiveCoords;
	vec2 uv;
	float addRadiusCorr;
	ringPoint(shape, P, ri, plength, pwidth, pcs, primitiveCoords, uv, addRadiusCorr);

	g_uv.xy = transformUV(uv.x, uv.y);
	vec3 vecnorm = normalize(primitiveCoords);

	// Fill the compatibility struct before any POST_GEOMETRY snippet runs
	dataIn[0].v_numvertices = v_numvertices;
	dataIn[0].v_rotationY = v_rotationY;
	dataIn[0].v_color = v_color;
	dataIn[0].v_lengthwidthcornerheight = v_lengthwidthcornerheight;
	dataIn[0].v_centerpos = v_centerpos;
	dataIn[0].v_uvoffsets = v_uvoffsets;
	dataIn[0].v_parameters = v_parameters;

	PRE_OFFSET
	gl_Position = cameraViewProj * vec4(v_centerpos.xyz + rotY * (addRadius * addRadiusCorr * vecnorm + primitiveCoords), 1.0);
	#ifdef ZPULL
		// Hack to draw the geometry in front of (or behind) the unit. Value is approximately elmos squared.
		gl_Position.z = (gl_Position.z) - ZPULL / (gl_Position.w);
	#endif
	g_uv.zw = v_parameters.zw;
	POST_GEOMETRY
}
