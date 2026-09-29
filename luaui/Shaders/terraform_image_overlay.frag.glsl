#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// Terraform Brush IMAGE overlay: projects a user image onto the terrain through
// the map gbuffer depth (same reconstruction as infolos_view / fog_diaglines),
// so it hugs the ground at any map size for one fullscreen pass. Units and
// features draw after this pass and cover it; the sky (depth 1) is discarded.

uniform sampler2D mapDepths;   // $map_gbuffer_zvaltex
uniform sampler2D overlayTex;  // the user image

// x = opacity, y = scale (1 = image spans the map), z/w = offset in map fractions
uniform vec4 params1 = vec4(1.0, 1.0, 0.0, 0.0);
// xy = aspect-fit divisors (1,1 = stretch), z = flip H, w = flip V
uniform vec4 params2 = vec4(1.0, 1.0, 0.0, 0.0);

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	vec2 screenUV;
};

out vec4 fragColor;

void main(void) {
	float mapdepth = texture(mapDepths, screenUV).x;
	if (mapdepth >= 0.999999) discard; // sky / nothing drawn

	vec4 worldPos = vec4(vec3(screenUV * 2.0 - 1.0, mapdepth), 1.0);
	worldPos = cameraViewProjInv * worldPos;
	worldPos.xyz /= worldPos.w;

	// 0..1 across the playable map; the engine's out-of-map extension lands
	// outside this range and is discarded below.
	vec2 mapUV = worldPos.xz / mapSize.xy;

	// Centre-relative placement: shift, then scale, then aspect fit.
	vec2 p = (mapUV - 0.5 - params1.zw) / max(params1.y, 1e-4);
	p /= params2.xy;
	vec2 uv = p + 0.5;

	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) discard;

	if (params2.z > 0.5) uv.x = 1.0 - uv.x;
	if (params2.w > 0.5) uv.y = 1.0 - uv.y;

	vec4 img = texture(overlayTex, uv);
	fragColor = vec4(img.rgb, img.a * params1.x);
}
