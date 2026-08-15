#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

#line 5000

layout (location = 0) in vec2 quadPos; // x,y in [0,1]
layout (location = 2) in vec4 height_timers;
layout (location = 3) in uvec4 bartype_index_ssboloc;
layout (location = 4) in vec4 mincolor;
layout (location = 5) in vec4 maxcolor;
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
    vec4[4] userDefined; // can't use float[16] because float in arrays occupies 4 * float space
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
    SUniformsBuffer uni[];
};

#line 10000

uniform float iconDistance;
uniform float cameraDistanceMult;
uniform float skipGlyphsNumbers;

out DataVS {
    vec4 g_color;
    vec2 g_uv;
    float g_value;
    float g_rawvalue;
    float g_uvoffset;
    float g_useOverlay;
    float g_showIcon;
    float g_showText;
    float g_bartype;
};

#define UNITUNIFORMS uni[instData.y]
#define UNIFORMLOC bartype_index_ssboloc.z
#define BARTYPE bartype_index_ssboloc.x

#define BITPERCENTAGE 4u
#define BITTIMELEFT 8u
#define BITINTEGERNUMBER 16u
#define BITGETPROGRESS 32u
#define BITFLASHBAR 64u
#define BITCOLORCORRECT 128u
#define BITUSEOVERLAY 1u
#define BITSHOWGLYPH 2u

bool vertexClipped(vec4 clipspace, float tolerance) {
  return any(lessThan(clipspace.xyz, -clipspace.www * tolerance)) ||
         any(greaterThan(clipspace.xyz, clipspace.www * tolerance));
}

void main()
{
    vec4 centerpos = vec4(UNITUNIFORMS.drawPos.xyz, 1.0);
    centerpos.y += HEIGHTOFFSET;
    centerpos.y += height_timers.x; // per-instance height offset

    vec4 clipPos = cameraViewProj * centerpos;
    if (vertexClipped(clipPos, CLIPTOLERANCE)) {
        gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
        g_color = vec4(0.0);
        g_uv = vec2(0.0);
        g_value = 0.0;
        g_rawvalue = 0.0;
        g_uvoffset = 0.0;
        g_useOverlay = 0.0;
        g_showIcon = 0.0;
        g_showText = 0.0;
        g_bartype = 0.0;
        return;
    }

    float cameraDistance = length((cameraViewInv[3]).xyz - centerpos.xyz);
    float barAlpha = (clamp(cameraDistance * cameraDistanceMult, BARFADESTART, BARFADEEND) - BARFADESTART) / (BARFADEEND - BARFADESTART);
    barAlpha = 1.0 - clamp(barAlpha, 0.0, 1.0);

    float value = UNITUNIFORMS.health / max(UNITUNIFORMS.maxHealth, 0.001);
    if (UNIFORMLOC < 20u) {
        value = UNITUNIFORMS.userDefined[0][UNIFORMLOC];
    }
    if ((BARTYPE & BITGETPROGRESS) > 0u) {
        value = ((timeInfo.x + timeInfo.w) - UNITUNIFORMS.userDefined[0].z) /
                max(UNITUNIFORMS.userDefined[0].w - UNITUNIFORMS.userDefined[0].z, 0.001);
    }
    float rawvalue = value;
    value = clamp(value, 0.0, 1.0);

    // Keep stockpile bars visible (integer count packed in value).
    if ((BARTYPE & BITINTEGERNUMBER) > 0u) {
        value = clamp(fract(value), 0.0, 1.0);
    }

    if ((BARTYPE & BITTIMELEFT) > 0u) {
        value = clamp(1.0 - value, 0.0, 1.0);
    }

    #ifndef DEBUGSHOW
        if (value < 0.00001) {
            gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
            g_color = vec4(0.0);
            g_uv = vec2(0.0);
            g_value = value;
            g_rawvalue = rawvalue;
            g_uvoffset = 0.0;
            g_useOverlay = 0.0;
            g_showIcon = 0.0;
            g_showText = 0.0;
            g_bartype = 0.0;
            return;
        }

        if ((BARTYPE & BITPERCENTAGE) > 0u) {
            if (value > 0.999) {
                gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
                g_color = vec4(0.0);
                g_uv = vec2(0.0);
                g_value = value;
                g_rawvalue = rawvalue;
                g_uvoffset = 0.0;
                g_useOverlay = 0.0;
                g_showIcon = 0.0;
                g_showText = 0.0;
                g_bartype = 0.0;
                return;
            }
        } else {
            if ((BARTYPE & BITGETPROGRESS) > 0u) {
                if (value > 0.999) {
                    gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
                    g_color = vec4(0.0);
                    g_uv = vec2(0.0);
                    g_value = value;
                    g_rawvalue = rawvalue;
                    g_uvoffset = 0.0;
                    g_useOverlay = 0.0;
                    g_showIcon = 0.0;
                    g_showText = 0.0;
                    g_bartype = 0.0;
                    return;
                }
            }
        }
    #endif

    if (barAlpha < MINALPHA) {
        gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
        g_color = vec4(0.0);
        g_uv = vec2(0.0);
        g_value = value;
        g_rawvalue = rawvalue;
        g_uvoffset = 0.0;
        g_useOverlay = 0.0;
        g_showIcon = 0.0;
        g_showText = 0.0;
        g_bartype = 0.0;
        return;
    }

    vec4 fillColor = mix(mincolor, maxcolor, value);
    if ((BARTYPE & BITCOLORCORRECT) > 0u) {
        float m = max(fillColor.r, fillColor.g);
        if (m > 0.0001) {
            fillColor.rgb = fillColor.rgb / m;
        }
    }

    float zoffset = 1.15 * BARHEIGHT * float(bartype_index_ssboloc.y);

    // Expand the fallback quad with a left glyph lane (icon + text), matching GS layout better.
    const float GLYPH_PAD_TILES = 4.5;
    float glyphPad = BARHEIGHT * GLYPH_PAD_TILES;
    float primitiveX = mix(-BARWIDTH - glyphPad, BARWIDTH, quadPos.x);
    vec3 primitiveCoords = vec3(primitiveX, 0.0, quadPos.y * BARHEIGHT - zoffset) * BARSCALE * height_timers.y;

    mat3 rotY = mat3(cameraViewInv[0].xyz, cameraViewInv[2].xyz, cameraViewInv[1].xyz);
    vec4 worldPos = vec4(centerpos.xyz + rotY * primitiveCoords, 1.0);

    gl_Position = cameraViewProj * worldPos;

    g_uv = quadPos;
    g_value = value;
    g_rawvalue = rawvalue;
    g_color = vec4(fillColor.rgb, barAlpha);
    g_uvoffset = height_timers.w;
    g_useOverlay = ((BARTYPE & BITUSEOVERLAY) > 0u) ? 1.0 : 0.0;
    g_showIcon = (((BARTYPE & BITSHOWGLYPH) > 0u) && (skipGlyphsNumbers < 0.5)) ? 1.0 : 0.0;
    g_showText = (skipGlyphsNumbers < 1.5) ? 1.0 : 0.0;
    g_bartype = float(BARTYPE);
}
