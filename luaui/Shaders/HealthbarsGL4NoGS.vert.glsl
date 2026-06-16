#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.
//
// Geometry-shader-free Healthbars GL4 vertex shader. For backends without a
// GS stage, this VS folds HealthbarsGL4.geom.glsl's point->bars expansion
// into the vertex shader. The per-unit data is bound as an INSTANCE buffer
// (divisor 1) and each instance is drawn as a fixed triangle LIST of
// VERTSPERINSTANCE verts via gl_VertexID:
//   VAO:DrawArrays(GL.TRIANGLES, 90, 0, usedElements)
//
// Vertex budget per instance (must match the widget's draw count):
//   3 octagons (background, colored background, foreground bar)
//     = 3 * (8-vertex triangle_strip -> 6 triangles) = 3 * 18 = 54 verts
//   6 glyph slots (icon, stockpile lsb/msb, percent-or-time sign/lsb/msb)
//     = 6 * (4-vertex quad strip -> 2 triangles)      = 6 *  6 = 36 verts
//   total = 90 verts. Inactive sub-primitives emit degenerate (off-screen)
//   vertices, exactly mirroring the GS's conditional EmitVertex/return paths.

#line 5000

layout (location = 0) in vec4 height_timers;
layout (location = 1) in uvec4 bartype_index_ssboloc;
layout (location = 2) in vec4 mincolor;
layout (location = 3) in vec4 maxcolor;
layout (location = 4) in uvec4 instData;

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

#line 10000

uniform float iconDistance;
uniform float cameraDistanceMult;
uniform float cameraDistanceMultGlyph;
uniform float skipGlyphsNumbers; // <0.5 all, <1.5 numbers only, >1.5 just bars

out DataGS {
	vec4 g_color;
	vec4 g_uv;
};

bool vertexClipped(vec4 clipspace, float tolerance) {
  return any(lessThan(clipspace.xyz, -clipspace.www * tolerance)) ||
         any(greaterThan(clipspace.xyz, clipspace.www * tolerance));
}

#define UNITUNIFORMS uni[instData.y]

#define BITUSEOVERLAY 1u
#define BITSHOWGLYPH 2u
#define BITPERCENTAGE 4u
#define BITTIMELEFT 8u
#define BITINTEGERNUMBER 16u
#define BITGETPROGRESS 32u
#define BITFLASHBAR 64u
#define BITCOLORCORRECT 128u

#define HALFPIXEL 0.0019765625

// Layout (must match the DrawArrays count in the widget).
const int OCT_TRIS    = 6;   // 8-vertex strip -> 6 triangles
const int OCT_VERTS   = 18;  // OCT_TRIS * 3
const int NUM_OCT     = 3;
const int GLYPH_VERTS = 6;   // 4-vertex strip -> 2 triangles
const int NUM_GLYPHS  = 6;
const int OCT_TOTAL   = NUM_OCT * OCT_VERTS; // 54

// strip(8) -> triangle-list strip index for octagons.
int octStripIndex(int local) {
	int to = local / 3;
	int k  = local % 3;
	if ((to & 1) == 0) return to + k;
	return (k == 0) ? (to + 1) : ((k == 1) ? to : (to + 2));
}

// strip(4) -> triangle-list strip index for quad glyphs.
int quadStripIndex(int local) {
	int qt = local / 3; // 0 or 1
	int k  = local % 3;
	if (qt == 0) return k;                                // (0,1,2)
	return (k == 0) ? 2 : ((k == 1) ? 1 : 3);             // (2,1,3)
}

void degenerate() {
	gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
	g_color = vec4(0.0);
	g_uv = vec4(0.0);
}

void main()
{
	// =========================================================================
	// Per-unit setup (mirrors HealthbarsGL4.vert.glsl). Recomputed per output
	// vertex; cheap relative to the GS interface it replaces.
	// =========================================================================
	vec4 drawPos = vec4(UNITUNIFORMS.drawPos.xyz, 1.0);
	vec4 centerpos = drawPos;

	uint v_numvertices = 4u;
	if (vertexClipped(cameraViewProj * drawPos, CLIPTOLERANCE)) v_numvertices = 0u;

	float cameraDistance = length((cameraViewInv[3]).xyz - centerpos.xyz);

	float BARALPHA = (clamp(cameraDistance * cameraDistanceMult, BARFADESTART, BARFADEEND) - BARFADESTART) / (BARFADEEND - BARFADESTART);
	BARALPHA = 1.0 - clamp(BARALPHA, 0.0, 1.0);

	float GLYPHALPHA = (clamp(cameraDistance * cameraDistanceMult * cameraDistanceMultGlyph, BARFADESTART, BARFADEEND) - BARFADESTART) / (BARFADEEND - BARFADESTART);
	GLYPHALPHA = 1.0 - clamp(GLYPHALPHA, 0.0, 1.0);

	#ifdef DEBUGSHOW
		BARALPHA = 1.0;
		GLYPHALPHA = 1.0;
	#endif

	float UVOFFSET = height_timers.w;
	float sizemultiplier = height_timers.y;

	if (dot(centerpos.xyz, centerpos.xyz) < 1.0) v_numvertices = 0u;

	centerpos.y += HEIGHTOFFSET;
	centerpos.y += height_timers.x;

	uint BARTYPE   = bartype_index_ssboloc.x;
	uint UNIFORMLOC = bartype_index_ssboloc.z;

	float relativehealth = UNITUNIFORMS.health / UNITUNIFORMS.maxHealth;
	float health = relativehealth;
	if (UNIFORMLOC < 20u) {
		health = UNITUNIFORMS.userDefined[0].y;
	} else {
		float buildprogress = UNITUNIFORMS.userDefined[0].x;
		#ifndef DEBUGSHOW
			if (abs(buildprogress - relativehealth) < 0.03) v_numvertices = 0u;
		#endif
	}
	if (UNIFORMLOC < 4u) health = UNITUNIFORMS.userDefined[0][UNIFORMLOC];
	if (UNIFORMLOC == 1u) health = UNITUNIFORMS.userDefined[0].y;
	if (UNIFORMLOC == 2u) health = UNITUNIFORMS.userDefined[0].z;
	if (UNIFORMLOC == 4u) health = UNITUNIFORMS.userDefined[1].x;
	if (UNIFORMLOC == 5u) health = UNITUNIFORMS.userDefined[1].y;

	if ((BARTYPE & BITGETPROGRESS) > 0u) {
		health =
			((timeInfo.x + timeInfo.w) - UNITUNIFORMS.userDefined[0].z) /
			(UNITUNIFORMS.userDefined[0].w - UNITUNIFORMS.userDefined[0].z);
		health = clamp(health, 0.0, 1.0);
	}

	vec4 v_mincolor = mincolor;
	vec4 v_maxcolor = maxcolor;

	// =========================================================================
	// GS main() scope: billboard, bail conditions, stockpile decode.
	// =========================================================================
	float zoffset = 1.15 * BARHEIGHT * float(bartype_index_ssboloc.y);
	mat3 rotY = mat3(cameraViewInv[0].xyz, cameraViewInv[2].xyz, cameraViewInv[1].xyz); // billboard (xz swizzle)

	bool mainBail = (v_numvertices == 0u);
	if (BARALPHA < MINALPHA) mainBail = true;
	#ifndef DEBUGSHOW
		if (health < 0.00001) mainBail = true;
		if ((BARTYPE & BITPERCENTAGE) > 0u) {
			if (health > 0.999) mainBail = true;
		} else {
			if ((BARTYPE & BITGETPROGRESS) > 0u) {
				if (health > 0.999) mainBail = true;
			}
		}
	#endif

	// STOCKPILE decode (mutates health for INTEGERNUMBER bars, like the GS).
	uint numStockpiled = 0u;
	if ((BARTYPE & BITINTEGERNUMBER) > 0u) {
		float oldhealth = health;
		health = fract(oldhealth);
		oldhealth = floor(oldhealth);
		numStockpiled = uint(floor(mod(oldhealth, 128.0)));
	}

	int gid = gl_VertexID;

	// =========================================================================
	// OCTAGONS (gid 0..53): background, colored background, foreground bar.
	// =========================================================================
	if (gid < OCT_TOTAL) {
		if (mainBail) { degenerate(); return; }

		int oct   = gid / OCT_VERTS;       // 0,1,2
		int local = gid - oct * OCT_VERTS; // 0..17
		int si    = octStripIndex(local);  // 0..7

		bool odd = (si & 1) == 1;

		vec2 pos;
		vec4 color;
		float bartextureoffset = 0.0;
		float depthbuffermod = 0.0;
		int uvmode = 0; // 0 = BG (flat color), 1 = bar (atlas uv)

		if (oct == 0) {
			// ---- background octagon (emitVertexBG) ----
			depthbuffermod = 0.001;
			uvmode = 0;
			if      (si == 0) pos = vec2(-BARWIDTH,             BARCORNER);
			else if (si == 1) pos = vec2(-BARWIDTH,             BARHEIGHT - BARCORNER);
			else if (si == 2) pos = vec2(-BARWIDTH + BARCORNER, 0.0);
			else if (si == 3) pos = vec2(-BARWIDTH + BARCORNER, BARHEIGHT);
			else if (si == 4) pos = vec2( BARWIDTH - BARCORNER, 0.0);
			else if (si == 5) pos = vec2( BARWIDTH - BARCORNER, BARHEIGHT);
			else if (si == 6) pos = vec2( BARWIDTH,             BARCORNER);
			else              pos = vec2( BARWIDTH,             BARHEIGHT - BARCORNER);

			float extracolor = (((BARTYPE & BITFLASHBAR) > 0u) && (mod(timeInfo.x, 10.0) > 4.0)) ? 0.5 : 0.0;
			color = mix(BGBOTTOMCOLOR + extracolor, BGTOPCOLOR + extracolor, pos.y);
		} else {
			// shared colour for the two bar octagons
			vec4 truecolor = mix(v_mincolor, v_maxcolor, health);
			truecolor.a = 0.2;
			uvmode = 1;

			if (oct == 1) {
				// ---- colored background octagon (truecolor/topcolor) ----
				depthbuffermod = 0.0;
				vec4 topcolor = truecolor;
				topcolor.rgb *= BOTTOMDARKENFACTOR;
				color = odd ? topcolor : truecolor;

				if      (si == 0) pos = vec2(-BARWIDTH + BARCORNER,                 SMALLERCORNER + BARCORNER);
				else if (si == 1) pos = vec2(-BARWIDTH + BARCORNER,                 BARHEIGHT - SMALLERCORNER - BARCORNER);
				else if (si == 2) pos = vec2(-BARWIDTH + SMALLERCORNER + BARCORNER, BARCORNER);
				else if (si == 3) pos = vec2(-BARWIDTH + SMALLERCORNER + BARCORNER, BARHEIGHT - BARCORNER);
				else if (si == 4) pos = vec2( BARWIDTH - SMALLERCORNER - BARCORNER, BARCORNER);
				else if (si == 5) pos = vec2( BARWIDTH - SMALLERCORNER - BARCORNER, BARHEIGHT - BARCORNER);
				else if (si == 6) pos = vec2( BARWIDTH - BARCORNER,                 SMALLERCORNER + BARCORNER);
				else              pos = vec2( BARWIDTH - BARCORNER,                 BARHEIGHT - SMALLERCORNER - BARCORNER);
			} else {
				// ---- foreground bar octagon (botcolor/truecolor, health-scaled) ----
				depthbuffermod = -0.001;
				float healthbasedpos = (2.0 * (BARWIDTH - BARCORNER) - 2.0 * SMALLERCORNER) * health;
				if ((BARTYPE & BITTIMELEFT) > 0u) healthbasedpos = (2.0 * (BARWIDTH - BARCORNER) - 2.0 * SMALLERCORNER);
				if ((BARTYPE & BITCOLORCORRECT) > 0u) truecolor.rgb = truecolor.rgb / max(truecolor.r, truecolor.g);
				truecolor.a = 1.0;
				vec4 botcolor = truecolor;
				botcolor.rgb *= BOTTOMDARKENFACTOR;
				color = odd ? truecolor : botcolor;
				if ((BARTYPE & BITUSEOVERLAY) > 0u) bartextureoffset = UVOFFSET;

				if      (si == 0) pos = vec2(-BARWIDTH + BARCORNER,                                    SMALLERCORNER + BARCORNER);
				else if (si == 1) pos = vec2(-BARWIDTH + BARCORNER,                                    BARHEIGHT - BARCORNER - SMALLERCORNER);
				else if (si == 2) pos = vec2(-BARWIDTH + BARCORNER + SMALLERCORNER,                    BARCORNER);
				else if (si == 3) pos = vec2(-BARWIDTH + BARCORNER + SMALLERCORNER,                    BARHEIGHT - BARCORNER);
				else if (si == 4) pos = vec2(-BARWIDTH + BARCORNER + SMALLERCORNER + healthbasedpos,   BARCORNER);
				else if (si == 5) pos = vec2(-BARWIDTH + BARCORNER + SMALLERCORNER + healthbasedpos,   BARHEIGHT - BARCORNER);
				else if (si == 6) pos = vec2(-BARWIDTH + BARCORNER + 2.0 * SMALLERCORNER + healthbasedpos, BARCORNER + SMALLERCORNER);
				else              pos = vec2(-BARWIDTH + BARCORNER + 2.0 * SMALLERCORNER + healthbasedpos, BARHEIGHT - BARCORNER - SMALLERCORNER);
			}
		}

		// ---- shading (emitVertexBG / emitVertexBarBG) ----
		if (uvmode == 0) {
			g_uv = vec4(0.0);
		} else {
			float ux = pos.x * (1.0 / (2.0 * (BARWIDTH - BARCORNER))) + 0.5;
			float uy = (pos.y - BARCORNER) / (BARHEIGHT - 2.0 * BARCORNER);
			vec2 uvxy = vec2(ux, uy) * vec2(ATLASSTEP * 9.0, ATLASSTEP) + vec2(3.0 * ATLASSTEP, bartextureoffset);
			uvxy.y = -uvxy.y;
			g_uv = vec4(uvxy, clamp(10000.0 * bartextureoffset, 0.0, 1.0), 0.0);
		}
		color.a *= BARALPHA;
		g_color = color;

		vec3 primitiveCoords = vec3(pos.x, 0.0, pos.y - zoffset) * BARSCALE * sizemultiplier;
		gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * primitiveCoords, 1.0);
		gl_Position.z += depthbuffermod;
		return;
	}

	// =========================================================================
	// GLYPHS (gid 54..89): 6 fixed slots. Mirrors the GS glyph emit order.
	//   slot 0 icon, 1 stockpile-lsb, 2 stockpile-msb,
	//   3 percent/time sign, 4 percent/time lsb, 5 percent/time msb.
	// =========================================================================
	int glocal = gid - OCT_TOTAL;
	int slot   = glocal / GLYPH_VERTS;     // 0..5
	int gsi    = quadStripIndex(glocal % GLYPH_VERTS); // 0..3

	// glyph-wide bail conditions (mirror the GS returns before the glyph block)
	if (mainBail || (GLYPHALPHA < MINALPHA) || (skipGlyphsNumbers > 1.5)) { degenerate(); return; }

	float currentglyphpos = (skipGlyphsNumbers < 0.5) ? 1.0 : 0.0;

	bool glyphActive = false; // note: 'active' is a reserved word in GLSL
	vec2 bottomleft = vec2(0.0);
	vec2 uvbl = vec2(0.0);
	vec2 uvsizes = vec2(ATLASSTEP, ATLASSTEP);

	if (slot == 0) {
		// icon
		glyphActive = (skipGlyphsNumbers < 0.5) && ((BARTYPE & BITSHOWGLYPH) > 0u);
		bottomleft = vec2(-BARWIDTH - currentglyphpos * BARHEIGHT, 0.0);
		uvbl = vec2(ATLASSTEP, UVOFFSET);
	} else if (slot == 1 || slot == 2) {
		// stockpile xx
		vec4 numbers = vec4(numStockpiled) * vec4(1.0, 0.1, 1.0, 0.1);
		numbers = floor(mod(numbers, 10.0)) * ATLASSTEP;
		if (slot == 1) {
			glyphActive = ((BARTYPE & BITINTEGERNUMBER) > 0u);
			bottomleft = vec2(-BARWIDTH - (currentglyphpos + 1.0) * BARHEIGHT, 0.0);
			uvbl = vec2(0.0, numbers.x);
		} else {
			glyphActive = ((BARTYPE & BITINTEGERNUMBER) > 0u) && (numbers.y > 0.0);
			bottomleft = vec2(-BARWIDTH - (currentglyphpos + 2.0) * BARHEIGHT + BARHEIGHT * 0.4, 0.0);
			uvbl = vec2(0.0, numbers.y);
		}
	} else {
		// percent / time-left digits
		bool wantNumber = ((BARTYPE & (BITTIMELEFT | BITPERCENTAGE)) > 0u);
		float lsb, msb, glyphpctsecatlas;
		if ((BARTYPE & BITTIMELEFT) > 0u) {
			float h = (health - 1.0) / (1.0 / 40.0);
			lsb = abs(floor(mod(h, 10.0)));
			msb = abs(floor(mod(h * 0.1, 10.0)));
			glyphpctsecatlas = 14.0;
		} else {
			lsb = floor(mod(health * 100.0, 10.0));
			msb = floor(mod(health * 10.0, 10.0));
			glyphpctsecatlas = 11.0;
		}
		if (slot == 3) {
			glyphActive = wantNumber;
			bottomleft = vec2(-BARWIDTH - (currentglyphpos + 1.0) * BARHEIGHT, 0.0);
			uvbl = vec2(0.0, glyphpctsecatlas * ATLASSTEP);
		} else if (slot == 4) {
			glyphActive = wantNumber;
			bottomleft = vec2(-BARWIDTH - (currentglyphpos + 2.0) * BARHEIGHT + BARHEIGHT * 0.2, 0.0);
			uvbl = vec2(0.0, lsb * ATLASSTEP);
		} else {
			glyphActive = wantNumber && (msb > 0.0);
			bottomleft = vec2(-BARWIDTH - (currentglyphpos + 3.0) * BARHEIGHT + BARHEIGHT * 0.5, 0.0);
			uvbl = vec2(0.0, msb * ATLASSTEP);
		}
	}

	if (!glyphActive) { degenerate(); return; }

	// emitGlyph strip vertex -> (pos, uv)
	vec2 pos;
	vec2 uv;
	if      (gsi == 0) { pos = vec2(bottomleft.x,             bottomleft.y);             uv = vec2(uvbl.x + HALFPIXEL,             uvbl.y + HALFPIXEL); }
	else if (gsi == 1) { pos = vec2(bottomleft.x,             bottomleft.y + BARHEIGHT); uv = vec2(uvbl.x + HALFPIXEL,             uvbl.y + uvsizes.y - HALFPIXEL); }
	else if (gsi == 2) { pos = vec2(bottomleft.x + BARHEIGHT, bottomleft.y);             uv = vec2(uvbl.x + uvsizes.x - HALFPIXEL, uvbl.y + HALFPIXEL); }
	else               { pos = vec2(bottomleft.x + BARHEIGHT, bottomleft.y + BARHEIGHT); uv = vec2(uvbl.x + uvsizes.x - HALFPIXEL, uvbl.y + uvsizes.y - HALFPIXEL); }

	g_uv = vec4(uv.x, 1.0 - uv.y, 1.0, 0.0); // z=1 -> sample texture
	g_color = vec4(1.0);
	g_color.a *= GLYPHALPHA;

	vec3 primitiveCoords = vec3(pos.x, 0.0, pos.y - zoffset) * BARSCALE * sizemultiplier;
	gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * primitiveCoords, 1.0);
}
