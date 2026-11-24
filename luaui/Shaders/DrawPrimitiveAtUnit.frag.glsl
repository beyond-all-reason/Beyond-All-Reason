#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.  

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000
uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;
uniform float transparency = TRANSPARENCY; // set it to change the opacity without recompiling
uniform float teamcolorization = TEAMCOLORIZATION; // for POST_SHADING snippets, same idea
in DataGS {
	vec4 g_color;
	vec4 g_uv;
};

uniform sampler2D DrawPrimitiveAtUnitTexture;
#if (USE_SECONDARY_TEXTURE == 1)
	uniform sampler2D DrawPrimitiveAtUnitTexture2;
	flat in uint g_atlasIndex;
#endif
out vec4 fragColor;

void main(void)
{
	vec4 texcolor = vec4(1.0);
	#if (USETEXTURE == 1)
		#if (USE_SECONDARY_TEXTURE == 1)
			// Compute gradients before the branch: adjacent primitives can use
			// different atlases, making implicit derivatives inside it undefined.
			vec2 uvDx = dFdx(g_uv.xy);
			vec2 uvDy = dFdy(g_uv.xy);
			if (g_atlasIndex == 1u) {
				texcolor = textureGrad(DrawPrimitiveAtUnitTexture2, g_uv.xy, uvDx, uvDy);
			} else {
				texcolor = textureGrad(DrawPrimitiveAtUnitTexture, g_uv.xy, uvDx, uvDy);
			}
		#else
			texcolor = texture(DrawPrimitiveAtUnitTexture, g_uv.xy);
		#endif
	#endif
	fragColor.rgba = vec4(g_color.rgb * texcolor.rgb + addRadius, texcolor.a * transparency + addRadius);
	POST_SHADING
	//fragColor.rgba = vec4(1.0);
	#if (DISCARD == 1)
		if (fragColor.a < 0.01) discard;
	#endif
}
