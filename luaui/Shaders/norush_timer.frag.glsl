#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com), Licensed under the MIT License

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 20000

uniform int noRushTimer;
float noRushFramesLeft;

in DataVS {
	vec4 v_position;
};

uniform sampler2D mapDepths;
// Baked by startpolygon_sdf_bake_gl4.frag.glsl: x = signed distance, y = team id of the
// closest polygon. See luaui/Include/startpolygon_sdf_gl4.lua.
uniform sampler2D startPolygonSDF;

out vec4 fragColor;

#line 21000
void main(void)
{
	float mapdepth = texture(mapDepths, v_position.zw).x;
	// Transform screen-space depth to world-space position
	vec4 mapWorldPos =  vec4( vec3(v_position.xy, mapdepth),  1.0);
	mapWorldPos = cameraViewProjInv * mapWorldPos;
	mapWorldPos.xyz = mapWorldPos.xyz / mapWorldPos.w;

	// We are above or below the map by 4 or more elmost, discard
	if (mapWorldPos.y > (MAXY + 4) || mapWorldPos.y < (MINY - 4)){
		fragColor.rgba = vec4(0);
		return;
	}

	// We are out of the map, discard:
	if ((mapWorldPos.x < 0) || (mapWorldPos.x > mapSize.x) || (mapWorldPos.z < 0) || (mapWorldPos.z > mapSize.y)){
		fragColor.rgba = vec4(0);
		return;
	}

	// One bilinear tap of the baked field replaces walking every polygon edge per pixel.
	// The four texels are fetched by hand so the team colour blends with the same weights
	// instead of switching per texel along the boundary between two zones.
	ivec2 sdfSize = textureSize(startPolygonSDF, 0);
	vec2 tc = clamp(mapWorldPos.xz / mapSize.xy * vec2(sdfSize) - 0.5, vec2(0.0), vec2(sdfSize - 1));
	ivec2 i0 = ivec2(tc);
	ivec2 i1 = min(i0 + 1, sdfSize - 1);
	vec2 f = tc - vec2(i0);
	vec2 t00 = texelFetch(startPolygonSDF, i0, 0).xy;
	vec2 t10 = texelFetch(startPolygonSDF, ivec2(i1.x, i0.y), 0).xy;
	vec2 t01 = texelFetch(startPolygonSDF, ivec2(i0.x, i1.y), 0).xy;
	vec2 t11 = texelFetch(startPolygonSDF, i1, 0).xy;
	vec4 w = vec4((1.0 - f.x) * (1.0 - f.y), f.x * (1.0 - f.y), (1.0 - f.x) * f.y, f.x * f.y);

	// The field is signed, but everything below wants the outside distance and the inside
	// case is flattened to zero alpha anyway.
	float closestbox = max(dot(w, vec4(t00.x, t10.x, t01.x, t11.x)), 0.0);
	vec3 mycolor = w.x * teamColor[int(t00.y + 0.5)].rgb
	             + w.y * teamColor[int(t10.y + 0.5)].rgb
	             + w.z * teamColor[int(t01.y + 0.5)].rgb
	             + w.w * teamColor[int(t11.y + 0.5)].rgb;

	// First we color based on their distance
	noRushFramesLeft = (clamp((noRushTimer - timeInfo.x+30), 0, 300)/300);
	fragColor.rgba = vec4(mycolor * sin(closestbox*3 / (40/3.14)), 0.5);
	//fragColor.rgba = vec4(mycolor*0.5, 0.5);
	if (timeInfo.x < 150) {
		fragColor.a = (timeInfo.x/150) - clamp(1 - exp(-closestbox/400.0) * sin(closestbox*3 / (40/3.14)), 0, 1);
	}
	if (timeInfo.x >= 150) {
		fragColor.a = noRushFramesLeft - clamp(1 - exp(-closestbox/400.0) * sin(closestbox*3 / (40/3.14)), 0, 1);
	}
	// But if we are within a box, then we set the alpha to 0
	if (closestbox < 0.5) {
		fragColor.a = 0.0;
	}
}
