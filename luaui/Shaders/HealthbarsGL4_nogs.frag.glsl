#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in DataVS {
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

uniform sampler2D healthbartexture;

out vec4 fragColor;

#define BITPERCENTAGE 4
#define BITTIMELEFT 8
#define BITINTEGERNUMBER 16

vec4 sampleAtlasGlyph(float col, float row, vec2 uv01)
{
    vec2 atlasUV = vec2(
        (col + uv01.x) * ATLASSTEP,
        1.0 - ((row + uv01.y) * ATLASSTEP)
    );
    return texture(healthbartexture, atlasUV);
}

vec4 over(vec4 under, vec4 top)
{
    float a = top.a + under.a * (1.0 - top.a);
    vec3 rgb = top.rgb * top.a + under.rgb * under.a * (1.0 - top.a);
    if (a > 0.0001) {
        rgb /= a;
    }
    return vec4(rgb, a);
}

void drawGlyph(inout vec4 accum, vec2 guv, float x0, float x1, float y0, float y1, float col, float row, float alphaMul)
{
    float m = step(x0, guv.x) * (1.0 - step(x1, guv.x)) * step(y0, guv.y) * (1.0 - step(y1, guv.y));
    if (m <= 0.0) return;

    vec2 uv = vec2((guv.x - x0) / max(x1 - x0, 0.001), (guv.y - y0) / max(y1 - y0, 0.001));
    vec4 t = sampleAtlasGlyph(col, row, uv);
    float a = smoothstep(0.15, 0.85, t.a) * alphaMul * m;
    accum = over(accum, vec4(t.rgb, a));
}

void main(void)
{
    if (g_color.a <= 0.0) {
        discard;
    }

    const float GLYPH_PAD_TILES = 4.5;
    float glyphPad = BARHEIGHT * GLYPH_PAD_TILES;
    float uBarStart = glyphPad / (2.0 * BARWIDTH + glyphPad);

    float inBar = step(uBarStart, g_uv.x);
    float barU = clamp((g_uv.x - uBarStart) / max(1.0 - uBarStart, 0.001), 0.0, 1.0);

    // Outer rounded-ish bar silhouette (bar region only).
    float edgeY = min(g_uv.y, 1.0 - g_uv.y);
    float outerMask = smoothstep(0.0, 0.08, edgeY) * inBar;

    vec3 bgBottom = BGBOTTOMCOLOR.rgb;
    vec3 bgTop = BGTOPCOLOR.rgb;
    vec3 bgColor = mix(bgBottom, bgTop, g_uv.y);

    vec3 fillTop = g_color.rgb;
    vec3 fillBottom = g_color.rgb * BOTTOMDARKENFACTOR;
    vec3 fillColor = mix(fillBottom, fillTop, g_uv.y);

    // Inset fill so the background remains visible as an outline.
    // Bias Y inset upward for wide bars so top/bottom border stays readable.
    const float borderX = 0.03;
    float borderY = borderX * (BARWIDTH / BARHEIGHT) * 2.0;
    borderY = clamp(borderY, 0.14, 0.45);
    float innerX = smoothstep(borderX, borderX + 0.01, barU) * (1.0 - smoothstep(1.0 - borderX - 0.01, 1.0 - borderX, barU));
    float innerY = smoothstep(borderY, borderY + 0.02, g_uv.y) * (1.0 - smoothstep(1.0 - borderY - 0.02, 1.0 - borderY, g_uv.y));
    float innerMask = innerX * innerY;

    float fill = step(barU, g_value) * innerMask;

    // Bar texture overlay (same atlas strip concept as GS path).
    vec2 innerUV = vec2(
        clamp((barU - borderX) / max(1.0 - 2.0 * borderX, 0.001), 0.0, 1.0),
        clamp((g_uv.y - borderY) / max(1.0 - 2.0 * borderY, 0.001), 0.0, 1.0)
    );

    // Try both GS-like flipped Y and direct Y row mapping; combine for robustness
    // across atlas content differences.
    vec2 barAtlasUVNeg = fract(vec2(
        3.0 * ATLASSTEP + innerUV.x * (ATLASSTEP * 9.0),
        -(g_uvoffset + innerUV.y * ATLASSTEP)
    ));
    vec2 barAtlasUVPos = fract(vec2(
        3.0 * ATLASSTEP + innerUV.x * (ATLASSTEP * 9.0),
        (g_uvoffset + innerUV.y * ATLASSTEP)
    ));
    vec4 barTexNeg = texture(healthbartexture, barAtlasUVNeg);
    vec4 barTexPos = texture(healthbartexture, barAtlasUVPos);
    vec4 barTex = max(barTexNeg, barTexPos);
    vec3 overlayFillColor = fillColor;
    if (g_useOverlay > 0.5) {
        // GS path effectively uses atlas texture color directly for overlay bars.
        // Keep a small tint bias so team-color readability isn't fully lost.
        vec3 texRgb = barTex.rgb;
        float patt = max(barTex.a, dot(texRgb, vec3(0.3333)));
        overlayFillColor = mix(texRgb, fillColor, 0.15) * (0.45 + 1.35 * patt);
    }

    // Layering: translucent background, mostly-opaque fill.
    float bgAlpha = g_color.a * outerMask * 0.7;
    float fillAlpha = g_color.a * fill * 0.95;
    vec4 outCol = vec4(bgColor, bgAlpha);
    outCol = over(outCol, vec4(overlayFillColor, fillAlpha));

    // Glyph lane: always reserved icon slot on left, text immediately right.
    vec2 guv = vec2(clamp(g_uv.x / max(uBarStart, 0.001), 0.0, 1.0), g_uv.y);
    float glyphAlphaMul = clamp(g_color.a * 1.45, 0.0, 1.0);

    if (g_showIcon > 0.5) {
        // Reserve icon just to the left of the bar, after the text block.
        float iconX0 = 0.76;
        float iconX1 = 0.98;
        float iconY0 = 0.00;
        float iconY1 = 0.94;
        drawGlyph(outCol, guv, iconX0, iconX1, iconY0, iconY1, 1.0, g_uvoffset / ATLASSTEP, glyphAlphaMul);
    }

    int bartype = int(g_bartype + 0.5);
    bool drawPct = (g_showText > 0.5) && ((bartype & BITPERCENTAGE) != 0 || (bartype & BITTIMELEFT) != 0);
    bool drawInt = (g_showText > 0.5) && ((bartype & BITINTEGERNUMBER) != 0);

    float y0 = 0.02;
    float y1 = 0.98;
    float w = 0.23;
    float gap = -0.05;
    float textStart = 0.0;

    if (drawPct) {
        int pct = int(floor(clamp(g_value, 0.0, 1.0) * 100.0 + 0.5));
        int d0 = pct % 10;
        int d1 = (pct / 10) % 10;
        int d2 = pct / 100;

        float xD2_0 = textStart;
        float xD1_0 = xD2_0 + w + gap;
        float xD0_0 = xD1_0 + w + gap;
        float xPercent0 = xD0_0 + w + gap;

        drawGlyph(outCol, guv, xPercent0, xPercent0 + w, y0, y1, 0.0, 11.0, glyphAlphaMul);
        drawGlyph(outCol, guv, xD0_0, xD0_0 + w, y0, y1, 0.0, float(d0), glyphAlphaMul);
        drawGlyph(outCol, guv, xD1_0, xD1_0 + w, y0, y1, 0.0, float(d1), glyphAlphaMul);
        if (d2 > 0) drawGlyph(outCol, guv, xD2_0, xD2_0 + w, y0, y1, 0.0, float(d2), glyphAlphaMul);
    }

    if (drawInt) {
        int n = max(0, int(floor(g_rawvalue + 0.001)));
        int d0 = n % 10;
        int d1 = (n / 10) % 10;
        int d2 = (n / 100) % 10;

        float xD2_0 = textStart;
        float xD1_0 = xD2_0 + w + gap;
        float xD0_0 = xD1_0 + w + gap;

        drawGlyph(outCol, guv, xD0_0, xD0_0 + w, y0, y1, 0.0, float(d0), glyphAlphaMul);
        if (d1 > 0 || d2 > 0) drawGlyph(outCol, guv, xD1_0, xD1_0 + w, y0, y1, 0.0, float(d1), glyphAlphaMul);
        if (d2 > 0) drawGlyph(outCol, guv, xD2_0, xD2_0 + w, y0, y1, 0.0, float(d2), glyphAlphaMul);
    }

    fragColor = outCol;
    if (fragColor.a < 0.05) {
        discard;
    }
}
