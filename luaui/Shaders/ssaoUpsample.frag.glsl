#version 430 core

// Joint bilateral upsample for half-res SSAO -> full-res screen blit.
// Uses full-res view-space depth (gbuffFuseViewPosTex) as the edge-stopping
// reference. This preserves AO boundaries across depth discontinuities that
// a naive bilinear upsample would smear.
//
// Designed to be a drop-in replacement for texrect_screen.frag.glsl when
// DOWNSAMPLE > 1 and the gbuffFuse pass is active (NOFUSE == 0).

//__DEFINES__

uniform sampler2D tex;        // half-res blurred SSAO (rgb=brighten factor, a=occlusion)
uniform sampler2D viewPosTex; // full-res view-space position (z is negative camera-space depth)

in DataVS {
	vec4 vs_position_texcoords; // .zw is uv in [0,1]
};

out vec4 fragColor;

void main(void)
{
	vec2 uv = vs_position_texcoords.zw;

	// Full-res reference depth at this fragment.
	float refZ = texture(viewPosTex, uv).z;

	// Sampling pattern: 4 nearest half-res taps. Half-res texel size in normalized UV.
	vec2 halfTexel = 0.5 / vec2(HSX, HSY);

	// 4 corner offsets around the fragment (half-res grid neighbours).
	const vec2 OFFS[4] = vec2[4](
		vec2(-1.0, -1.0),
		vec2( 1.0, -1.0),
		vec2(-1.0,  1.0),
		vec2( 1.0,  1.0)
	);

	// Bilinear weights derived from sub-texel position within the half-res grid.
	vec2 hres = vec2(HSX, HSY);
	vec2 frac = fract(uv * hres - 0.5);
	float bw[4];
	bw[0] = (1.0 - frac.x) * (1.0 - frac.y);
	bw[1] =        frac.x  * (1.0 - frac.y);
	bw[2] = (1.0 - frac.x) *        frac.y;
	bw[3] =        frac.x  *        frac.y;

	// Edge-stop scale: tighter near the camera, looser at distance, matching
	// the precision and density of view-space coordinates.
	float zScale = 1.0 / max(1.0, abs(refZ) * 0.05);

	vec4 acc = vec4(0.0);
	float wSum = 0.0;

	for (int i = 0; i < 4; i++) {
		vec2 sUV = uv + OFFS[i] * halfTexel;
		float sZ = texture(viewPosTex, sUV).z;
		// Joint bilateral weight: bilinear * exp(-|dz| * zScale).
		float w = bw[i] * exp(-abs(sZ - refZ) * zScale);
		acc  += w * texture(tex, sUV);
		wSum += w;
	}

	// All 4 neighbours rejected as outliers (edge case at depth cliffs):
	// fall back to the nearest half-res tap to avoid a black pixel.
	if (wSum < 1e-4) {
		fragColor = texture(tex, uv);
	} else {
		fragColor = acc / wSum;
	}
}
