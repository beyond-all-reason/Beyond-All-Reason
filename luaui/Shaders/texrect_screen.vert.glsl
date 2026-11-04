#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com), licensed under the MIT license

layout (location = 0) in vec4 position_texcoords; // .xy is [-1, +1], uv is [0, 1]

//__DEFINES__

#ifdef TILE_CULL
	// Instanced: position_texcoords.xy is a corner of the unit quad, scaled onto this TILE_PX sized tile of the screen
	layout (location = 1) in vec2 tile;
	uniform sampler2D unitStencilTex; // TILE_TEXELS texels per tile
#endif

#ifdef CUSTOM_TEXRECT
	//__ENGINEUNIFORMBUFFERDEFS__
#endif

#line 10000

out DataVS {
	vec4 vs_position_texcoords; // .xy is [-1, +1], uv is [0, 1]
};

void main()
{
	// fix issue for amd/linux when drawing to DrawWorldPreParticles
	// https://github.com/beyond-all-reason/RecoilEngine/issues/2791
	gl_ClipDistance[0] = 1.0;
	gl_ClipDistance[1] = 1.0;
	gl_ClipDistance[2] = 1.0;

	#ifdef CUSTOM_TEXRECT
		TEXRECT_PRE_VERTEX
	#endif
	#ifdef TILE_CULL
		// The tile is drawn when the stencil has coverage in it or within 2 texels: the passes' stencil lookups round
		// to at most 1 texel outside their tile, and the half res composite's bilinear tap reaches 1 further
		const int gathers = TILE_TEXELS / 2 + 2;
		vec2 texelSize = 1.0 / vec2(textureSize(unitStencilTex, 0));
		vec2 first = tile * float(TILE_TEXELS) - 1.0;
		float coverage = 0.0;
		for (int y = 0; y < gathers; ++y) {
			for (int x = 0; x < gathers; ++x) {
				vec4 texels = textureGather(unitStencilTex, (first + 2.0 * vec2(x, y)) * texelSize, 0);
				coverage = max(coverage, max(max(texels.x, texels.y), max(texels.z, texels.w)));
			}
		}
		vec2 ndc = (tile + position_texcoords.xy) * (2.0 * float(TILE_PX) / vec2(VSX, VSY)) - 1.0;
		vs_position_texcoords = vec4(ndc, ndc * 0.5 + 0.5);
		// the stencil users test >= 0.1; a tile without coverage collapses outside the clip volume
		gl_Position = (coverage >= 0.1) ? vec4(ndc, 0.0, 1.0) : vec4(2.0, 2.0, 2.0, 1.0);
	#else
		// output the screen-space position exactly as a fullscreen quad, at a depth of 0
		gl_Position = vec4(position_texcoords.xy, 0.0, 1.0);
		vs_position_texcoords = position_texcoords;
	#endif
	#ifdef CUSTOM_TEXRECT
		TEXRECT_POST_VERTEX
	#endif
}