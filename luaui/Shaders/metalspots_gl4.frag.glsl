#version 420
#line 20000
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.  

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__


uniform sampler2D textAtlas;
#ifdef MAP_REGIONS
	uniform vec4 regionBounds; // x0, z0, x1, z1 of the viewed region; zero width disables clipping
#endif

in DataVS {
	float circlealpha;
	vec4 v_targetcolor;
	vec4 v_uvcoords;
	#ifdef MAP_REGIONS
		vec2 v_worldXZ;
	#endif
};

out vec4 fragColor;

void main(void)
{
	#ifdef MAP_REGIONS
		// Rings of spots near the region edge must not draw over the separating strip.
		if (regionBounds.z > regionBounds.x &&
			(any(lessThan(v_worldXZ, regionBounds.xy)) ||
			 any(greaterThanEqual(v_worldXZ, regionBounds.zw)))) discard;
	#endif

	fragColor = vec4(v_targetcolor.rgb,circlealpha); //debug!
	if (v_uvcoords.x > -0.5){
		vec4 atlascolor = texture(textAtlas, v_uvcoords.xy);
		fragColor.rgba = vec4(atlascolor.rgba);
	}
	//fragColor.rgba = vec4(1,1,1,0.5);
}