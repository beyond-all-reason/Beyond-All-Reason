#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// macOS NoGS adaptation of BAR's HealthbarsGL4 vertex+geometry pipeline.
// Keeps the official instance attributes and fragment shader contract.
#line 5000

layout (location = 0) in vec4 height_timers;
layout (location = 1) in uvec4 bartype_index_ssboloc;
layout (location = 2) in vec4 mincolor;
layout (location = 3) in vec4 maxcolor;
layout (location = 4) in uvec4 instData;
layout (location = 5) in float shapeIndex;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

struct SUniformsBuffer {
	uint composite;

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
uniform float skipGlyphsNumbers;
uniform float globalSizeMult;

out DataGS {
	vec4 g_color;
	vec4 g_uv;
};

#define UNITUNIFORMS uni[instData.y]
#define UNIFORMLOC bartype_index_ssboloc.z
#define BARTYPE bartype_index_ssboloc.x

#define BITUSEOVERLAY 1u
#define BITSHOWGLYPH 2u
#define BITPERCENTAGE 4u
#define BITTIMELEFT 8u
#define BITINTEGERNUMBER 16u
#define BITGETPROGRESS 32u
#define BITFLASHBAR 64u
#define BITCOLORCORRECT 128u

#define HALFPIXEL 0.0019765625

bool vertexClipped(vec4 clipspace, float tolerance)
{
	return any(lessThan(clipspace.xyz, -clipspace.www * tolerance)) ||
	       any(greaterThan(clipspace.xyz, clipspace.www * tolerance));
}

void HideVertex()
{
	gl_Position = vec4(0.0, 0.0, 2.0, 1.0);
	g_color = vec4(0.0);
	g_uv = vec4(0.0);
}

int StripIndexForTriangleVertex(int i)
{
	if (i == 0) return 0;
	if (i == 1) return 1;
	if (i == 2) return 2;
	if (i == 3) return 2;
	if (i == 4) return 1;
	if (i == 5) return 3;
	if (i == 6) return 2;
	if (i == 7) return 3;
	if (i == 8) return 4;
	if (i == 9) return 4;
	if (i == 10) return 3;
	if (i == 11) return 5;
	if (i == 12) return 4;
	if (i == 13) return 5;
	if (i == 14) return 6;
	if (i == 15) return 6;
	if (i == 16) return 5;
	return 7;
}

int QuadIndexForTriangleVertex(int i)
{
	if (i == 0) return 0;
	if (i == 1) return 1;
	if (i == 2) return 2;
	if (i == 3) return 2;
	if (i == 4) return 1;
	return 3;
}

vec2 BackgroundPos(int s)
{
	if (s == 0) return vec2(-BARWIDTH, BARCORNER);
	if (s == 1) return vec2(-BARWIDTH, BARHEIGHT - BARCORNER);
	if (s == 2) return vec2(-BARWIDTH + BARCORNER, 0.0);
	if (s == 3) return vec2(-BARWIDTH + BARCORNER, BARHEIGHT);
	if (s == 4) return vec2(BARWIDTH - BARCORNER, 0.0);
	if (s == 5) return vec2(BARWIDTH - BARCORNER, BARHEIGHT);
	if (s == 6) return vec2(BARWIDTH, BARCORNER);
	return vec2(BARWIDTH, BARHEIGHT - BARCORNER);
}

vec2 BarBackgroundPos(int s)
{
	if (s == 0) return vec2(-BARWIDTH + BARCORNER, SMALLERCORNER + BARCORNER);
	if (s == 1) return vec2(-BARWIDTH + BARCORNER, BARHEIGHT - SMALLERCORNER - BARCORNER);
	if (s == 2) return vec2(-BARWIDTH + SMALLERCORNER + BARCORNER, BARCORNER);
	if (s == 3) return vec2(-BARWIDTH + SMALLERCORNER + BARCORNER, BARHEIGHT - BARCORNER);
	if (s == 4) return vec2(BARWIDTH - SMALLERCORNER - BARCORNER, BARCORNER);
	if (s == 5) return vec2(BARWIDTH - SMALLERCORNER - BARCORNER, BARHEIGHT - BARCORNER);
	if (s == 6) return vec2(BARWIDTH - BARCORNER, SMALLERCORNER + BARCORNER);
	return vec2(BARWIDTH - BARCORNER, BARHEIGHT - SMALLERCORNER - BARCORNER);
}

vec2 BarForegroundPos(int s, float healthbasedpos)
{
	if (s == 0) return vec2(-BARWIDTH + BARCORNER, SMALLERCORNER + BARCORNER);
	if (s == 1) return vec2(-BARWIDTH + BARCORNER, BARHEIGHT - BARCORNER - SMALLERCORNER);
	if (s == 2) return vec2(-BARWIDTH + BARCORNER + SMALLERCORNER, BARCORNER);
	if (s == 3) return vec2(-BARWIDTH + BARCORNER + SMALLERCORNER, BARHEIGHT - BARCORNER);
	if (s == 4) return vec2(-BARWIDTH + BARCORNER + SMALLERCORNER + healthbasedpos, BARCORNER);
	if (s == 5) return vec2(-BARWIDTH + BARCORNER + SMALLERCORNER + healthbasedpos, BARHEIGHT - BARCORNER);
	if (s == 6) return vec2(-BARWIDTH + BARCORNER + 2.0 * SMALLERCORNER + healthbasedpos, BARCORNER + SMALLERCORNER);
	return vec2(-BARWIDTH + BARCORNER + 2.0 * SMALLERCORNER + healthbasedpos, BARHEIGHT - BARCORNER - SMALLERCORNER);
}

vec4 ProjectBarVertex(vec2 pos, vec4 centerpos, mat3 rotY, float zoffset, float sizemultiplier, float depthbuffermod)
{
	vec3 primitiveCoords = vec3(pos.x, 0.0, pos.y - zoffset) * BARSCALE * sizemultiplier;
	vec4 clip = cameraViewProj * vec4(centerpos.xyz + rotY * primitiveCoords, 1.0);
	clip.z += depthbuffermod;
	return clip;
}

void EmitBackgroundVertex(vec2 pos, vec4 centerpos, mat3 rotY, float zoffset, float sizemultiplier, float barAlpha, uint bartype)
{
	g_uv.xy = vec2(0.0);
	g_uv.z = 0.0;
	float extracolor = 0.0;
	if (((bartype & BITFLASHBAR) > 0u) && (mod(timeInfo.x, 10.0) > 4.0)) {
		extracolor = 0.5;
	}
	g_color = mix(BGBOTTOMCOLOR + extracolor, BGTOPCOLOR + extracolor, pos.y);
	g_color.a *= barAlpha;
	gl_Position = ProjectBarVertex(pos, centerpos, rotY, zoffset, sizemultiplier, 0.001);
}

void EmitBarVertex(vec2 pos, vec4 color, float bartextureoffset, vec4 centerpos, mat3 rotY, float zoffset, float sizemultiplier, float barAlpha, float depthbuffermod)
{
	g_uv.x = pos.x * 1.0 / (2.0 * (BARWIDTH - BARCORNER));
	g_uv.x = g_uv.x + 0.5;
	g_uv.y = (pos.y - BARCORNER) / (BARHEIGHT - 2.0 * BARCORNER);
	g_uv.xy = g_uv.xy * vec2(ATLASSTEP * 9.0, ATLASSTEP) + vec2(3.0 * ATLASSTEP, bartextureoffset);
	g_uv.y = -1.0 * g_uv.y;
	g_uv.z = clamp(10000.0 * bartextureoffset, 0.0, 1.0);
	g_color = color;
	g_color.a *= barAlpha;
	gl_Position = ProjectBarVertex(pos, centerpos, rotY, zoffset, sizemultiplier, depthbuffermod);
}

void EmitGlyphVertex(vec2 bottomleft, vec2 uvbottomleft, vec2 uvsizes, int triangleVertex, vec4 centerpos, mat3 rotY, float zoffset, float sizemultiplier, float glyphAlpha)
{
	int q = QuadIndexForTriangleVertex(triangleVertex);
	vec2 pos = bottomleft;
	vec2 uv = uvbottomleft;
	if (q == 1) {
		pos.y += BARHEIGHT;
		uv.y += uvsizes.y;
	} else if (q == 2) {
		pos.x += BARHEIGHT;
		uv.x += uvsizes.x;
	} else if (q == 3) {
		pos += vec2(BARHEIGHT, BARHEIGHT);
		uv += uvsizes;
	}

	vec2 halfAdjust = vec2((q == 2 || q == 3) ? -HALFPIXEL : HALFPIXEL, (q == 1 || q == 3) ? -HALFPIXEL : HALFPIXEL);
	g_uv.xy = vec2(uv.x + halfAdjust.x, 1.0 - (uv.y + halfAdjust.y));
	g_uv.z = 1.0;
	g_color = vec4(1.0);
	g_color.a *= glyphAlpha;
	gl_Position = ProjectBarVertex(pos, centerpos, rotY, zoffset, sizemultiplier, 0.0);
}

void main()
{
	int idx = int(shapeIndex + 0.5);

	vec4 drawPos = vec4(UNITUNIFORMS.drawPos.xyz, 1.0);
	vec4 centerpos = drawPos;
	uint numvertices = 4u;
	vec4 centerClip = cameraViewProj * drawPos;
	if (vertexClipped(centerClip, CLIPTOLERANCE)) {
		numvertices = 0u;
	}

	float cameraDistance = length(cameraViewInv[3].xyz - centerpos.xyz);
	vec4 parameters = vec4(0.0);
	parameters.y = (clamp(cameraDistance * cameraDistanceMult, BARFADESTART, BARFADEEND) - BARFADESTART) / (BARFADEEND - BARFADESTART);
	parameters.y = 1.0 - clamp(parameters.y, 0.0, 1.0);
	parameters.z = (clamp(cameraDistance * cameraDistanceMult * cameraDistanceMultGlyph, BARFADESTART, BARFADEEND) - BARFADESTART) / (BARFADEEND - BARFADESTART);
	parameters.z = 1.0 - clamp(parameters.z, 0.0, 1.0);

	#ifdef DEBUGSHOW
		parameters.y = 1.0;
		parameters.z = 1.0;
	#endif

	parameters.w = height_timers.w;
	vec2 sizemodifiers = height_timers.yz;

	if (dot(centerpos.xyz, centerpos.xyz) < 1.0) {
		numvertices = 0u;
	}

	centerpos.y += HEIGHTOFFSET;
	centerpos.y += height_timers.x;

	float relativehealth = UNITUNIFORMS.health / UNITUNIFORMS.maxHealth;
	parameters.x = relativehealth;
	if (UNIFORMLOC < 20u) {
		parameters.x = UNITUNIFORMS.userDefined[0].y;
	} else {
		float buildprogress = UNITUNIFORMS.userDefined[0].x;
		#ifndef DEBUGSHOW
			if (abs(buildprogress - relativehealth) < 0.03) {
				numvertices = 0u;
			}
		#endif
	}

	if (UNIFORMLOC < 4u) parameters.x = UNITUNIFORMS.userDefined[0][UNIFORMLOC];
	if (UNIFORMLOC == 1u) parameters.x = UNITUNIFORMS.userDefined[0].y;
	if (UNIFORMLOC == 2u) parameters.x = UNITUNIFORMS.userDefined[0].z;
	if (UNIFORMLOC == 4u) parameters.x = UNITUNIFORMS.userDefined[1].x;
	if (UNIFORMLOC == 5u) parameters.x = UNITUNIFORMS.userDefined[1].y;

	if ((BARTYPE & BITGETPROGRESS) > 0u) {
		parameters.x = ((timeInfo.x + timeInfo.w) - UNITUNIFORMS.userDefined[0].z) /
			(UNITUNIFORMS.userDefined[0].w - UNITUNIFORMS.userDefined[0].z);
		parameters.x = clamp(parameters.x, 0.0, 1.0);
	}

	float health = parameters.x;
	float barAlpha = parameters.y;
	float glyphAlpha = parameters.z;
	float uvoffset = parameters.w;
	float sizemultiplier = sizemodifiers.x * globalSizeMult;
	float zoffset = 1.15 * BARHEIGHT * float(bartype_index_ssboloc.y);
	mat3 rotY = mat3(cameraViewInv[0].xyz, cameraViewInv[2].xyz, cameraViewInv[1].xyz);

	if (numvertices == 0u || barAlpha < MINALPHA) {
		HideVertex();
		return;
	}

	#ifndef DEBUGSHOW
		if (health < 0.00001) {
			HideVertex();
			return;
		}
		if ((BARTYPE & BITPERCENTAGE) > 0u) {
			if (health > 0.999) {
				HideVertex();
				return;
			}
		} else if ((BARTYPE & BITGETPROGRESS) > 0u) {
			if (health > 0.999) {
				HideVertex();
				return;
			}
		}
	#endif

	uint numStockpiled = 0u;
	uint numStockpileQueued = 0u;
	if ((BARTYPE & BITINTEGERNUMBER) > 0u) {
		float oldhealth = health;
		health = fract(oldhealth);
		oldhealth = floor(oldhealth);
		numStockpiled = uint(floor(mod(oldhealth, 128.0)));
		numStockpileQueued = uint(floor(oldhealth / 128.0));
	}

	if (idx < 18) {
		int s = StripIndexForTriangleVertex(idx);
		EmitBackgroundVertex(BackgroundPos(s), centerpos, rotY, zoffset, sizemultiplier, barAlpha, BARTYPE);
		return;
	}

	vec4 truecolor = mix(mincolor, maxcolor, health);

	if (idx < 36) {
		int s = StripIndexForTriangleVertex(idx - 18);
		truecolor.a = 0.2;
		vec4 topcolor = truecolor;
		topcolor.rgb *= BOTTOMDARKENFACTOR;
		vec4 color = ((s == 1) || (s == 3) || (s == 5) || (s == 7)) ? topcolor : truecolor;
		EmitBarVertex(BarBackgroundPos(s), color, 0.0, centerpos, rotY, zoffset, sizemultiplier, barAlpha, 0.0);
		return;
	}

	float healthbasedpos = (2.0 * (BARWIDTH - BARCORNER) - 2.0 * SMALLERCORNER) * health;
	if ((BARTYPE & BITTIMELEFT) > 0u) {
		healthbasedpos = 2.0 * (BARWIDTH - BARCORNER) - 2.0 * SMALLERCORNER;
	}
	if ((BARTYPE & BITCOLORCORRECT) > 0u) {
		truecolor.rgb = truecolor.rgb / max(truecolor.r, truecolor.g);
	}
	truecolor.a = 1.0;
	vec4 botcolor = truecolor;
	botcolor.rgb *= BOTTOMDARKENFACTOR;
	float bartextureoffset = 0.0;
	if ((BARTYPE & BITUSEOVERLAY) > 0u) {
		bartextureoffset = uvoffset;
	}

	if (idx < 54) {
		int s = StripIndexForTriangleVertex(idx - 36);
		vec4 color = ((s == 1) || (s == 3) || (s == 5) || (s == 7)) ? truecolor : botcolor;
		EmitBarVertex(BarForegroundPos(s, healthbasedpos), color, bartextureoffset, centerpos, rotY, zoffset, sizemultiplier, barAlpha, -0.001);
		return;
	}

	if (glyphAlpha < MINALPHA || skipGlyphsNumbers > 1.5) {
		HideVertex();
		return;
	}

	float currentglyphpos = 1.0;
	bool drawGlyphIcon = false;
	if (skipGlyphsNumbers < 0.5) {
		drawGlyphIcon = ((BARTYPE & BITSHOWGLYPH) > 0u);
	} else {
		currentglyphpos = 0.0;
	}

	if (idx < 60) {
		if (!drawGlyphIcon) {
			HideVertex();
			return;
		}
		EmitGlyphVertex(vec2(-BARWIDTH - currentglyphpos * BARHEIGHT, 0.0), vec2(ATLASSTEP, uvoffset), vec2(ATLASSTEP, ATLASSTEP), idx - 54, centerpos, rotY, zoffset, sizemultiplier, glyphAlpha);
		return;
	}

	if ((BARTYPE & BITINTEGERNUMBER) > 0u) {
		vec4 numbers = vec4(numStockpiled, numStockpiled, numStockpileQueued, numStockpileQueued);
		numbers = numbers * vec4(1.0, 0.1, 1.0, 0.1);
		numbers = floor(mod(numbers, 10.0)) * ATLASSTEP;

		if (idx < 66) {
			EmitGlyphVertex(vec2(-BARWIDTH - (currentglyphpos + 1.0) * BARHEIGHT, 0.0), vec2(0.0, numbers.x), vec2(ATLASSTEP, ATLASSTEP), idx - 60, centerpos, rotY, zoffset, sizemultiplier, glyphAlpha);
			return;
		}
		if (idx < 72 && numbers.y > 0.0) {
			EmitGlyphVertex(vec2(-BARWIDTH - (currentglyphpos + 2.0) * BARHEIGHT + BARHEIGHT * 0.4, 0.0), vec2(0.0, numbers.y), vec2(ATLASSTEP, ATLASSTEP), idx - 66, centerpos, rotY, zoffset, sizemultiplier, glyphAlpha);
			return;
		}
		HideVertex();
		return;
	}

	if ((BARTYPE & (BITTIMELEFT | BITPERCENTAGE)) > 0u) {
		float lsb;
		float msb;
		float glyphpctsecatlas;
		if ((BARTYPE & BITTIMELEFT) > 0u) {
			health = (health - 1.0) / (1.0 / 40.0);
			lsb = abs(floor(mod(health, 10.0)));
			msb = abs(floor(mod(health * 0.1, 10.0)));
			glyphpctsecatlas = 14.0;
		} else {
			lsb = floor(mod(health * 100.0, 10.0));
			msb = floor(mod(health * 10.0, 10.0));
			glyphpctsecatlas = 11.0;
		}

		if (idx < 66) {
			EmitGlyphVertex(vec2(-BARWIDTH - (currentglyphpos + 1.0) * BARHEIGHT, 0.0), vec2(0.0, glyphpctsecatlas * ATLASSTEP), vec2(ATLASSTEP, ATLASSTEP), idx - 60, centerpos, rotY, zoffset, sizemultiplier, glyphAlpha);
			return;
		}
		if (idx < 72) {
			EmitGlyphVertex(vec2(-BARWIDTH - (currentglyphpos + 2.0) * BARHEIGHT + BARHEIGHT * 0.2, 0.0), vec2(0.0, lsb * ATLASSTEP), vec2(ATLASSTEP, ATLASSTEP), idx - 66, centerpos, rotY, zoffset, sizemultiplier, glyphAlpha);
			return;
		}
		if (idx < 78 && msb > 0.0) {
			EmitGlyphVertex(vec2(-BARWIDTH - (currentglyphpos + 3.0) * BARHEIGHT + BARHEIGHT * 0.5, 0.0), vec2(0.0, msb * ATLASSTEP), vec2(ATLASSTEP, ATLASSTEP), idx - 72, centerpos, rotY, zoffset, sizemultiplier, glyphAlpha);
			return;
		}
	}

	HideVertex();
}
