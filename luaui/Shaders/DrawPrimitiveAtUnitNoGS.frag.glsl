#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.
//
// Fragment stage for the geometry-shader-free DrawPrimitiveAtUnit variant,
// an alternative shader path for backends without a geometry-shader stage.
// Identical shading to the GS variant; only the interface block it reads
// from changed (now fed by the VS directly instead of a geometry shader).

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000
uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;
in PrimData {
	vec4 g_color;
	vec4 g_uv;
};

uniform sampler2D DrawPrimitiveAtUnitTexture;
out vec4 fragColor;

void main(void)
{
	vec4 texcolor = vec4(1.0);
	#if (USETEXTURE == 1)
		texcolor = texture(DrawPrimitiveAtUnitTexture, g_uv.xy);
	#endif
	fragColor.rgba = vec4(g_color.rgb * texcolor.rgb + addRadius, texcolor.a * TRANSPARENCY + addRadius);
	POST_SHADING
	#if (DISCARD == 1)
		if (fragColor.a < 0.01) discard;
	#endif
}
