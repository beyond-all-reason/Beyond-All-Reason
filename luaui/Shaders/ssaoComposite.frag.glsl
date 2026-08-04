#version 430 core

// Final SSAO composite shader.
//
// Two responsibilities:
//   1. Sample blurred SSAO and (optionally) joint-bilaterally upsample it
//      from half-res using a full-res view-pos depth reference.
//   2. Output gl_FragDepth = closest gbuffer surface depth (model min map),
//      so an LEQUAL depth test on the FB depth buffer rejects any pixel
//      where something has been drawn on top of the original ground/unit
//      surface (foliage/grass, decals, particles, etc.). This prevents
//      SSAO from darkening grass/foliage that was rendered after the
//      gbuffer was captured.

//__DEFINES__

uniform sampler2D tex;             // SSAO blur output (slot 0)
uniform sampler2D modelDepthTex;   // $model_gbuffer_zvaltex (slot 1)
uniform sampler2D mapDepthTex;     // $map_gbuffer_zvaltex   (slot 4)
#if (DOWNSAMPLE > 1) && (NOFUSE == 0)
uniform sampler2D viewPosTex;      // gbuffFuseViewPosTex     (slot 5)
#endif

in DataVS {
	vec4 vs_position_texcoords; // .zw is uv in [0,1]
};

out vec4 fragColor;

void main(void)
{
	vec2 uv = vs_position_texcoords.zw;

#if (DOWNSAMPLE > 1) && (NOFUSE == 0)
	// ---- Joint bilateral upsample path (half-res -> full-res) ----
	float refZ = texture(viewPosTex, uv).z;

	vec2 halfTexel = 0.5 / vec2(HSX, HSY);
	const vec2 OFFS[4] = vec2[4](
		vec2(-1.0, -1.0),
		vec2( 1.0, -1.0),
		vec2(-1.0,  1.0),
		vec2( 1.0,  1.0)
	);

	vec2 hres = vec2(HSX, HSY);
	vec2 frac_ = fract(uv * hres - 0.5);
	float bw[4];
	bw[0] = (1.0 - frac_.x) * (1.0 - frac_.y);
	bw[1] =        frac_.x  * (1.0 - frac_.y);
	bw[2] = (1.0 - frac_.x) *        frac_.y;
	bw[3] =        frac_.x  *        frac_.y;

	float zScale = 1.0 / max(1.0, abs(refZ) * 0.05);

	vec4 acc = vec4(0.0);
	float wSum = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 sUV = uv + OFFS[i] * halfTexel;
		float sZ = texture(viewPosTex, sUV).z;
		float w = bw[i] * exp(-abs(sZ - refZ) * zScale);
		acc  += w * texture(tex, sUV);
		wSum += w;
	}
	fragColor = (wSum < 1e-4) ? texture(tex, uv) : (acc / wSum);
#else
	// ---- Single tap (full-res, or no fuse texture available) ----
	fragColor = texture(tex, uv);
#endif

	// Depth-rejection mask via gl_FragDepth + LEQUAL test.
	// Take the closest of model/map gbuffer depths (the surface SSAO was
	// computed against) and write it as our fragment depth. With LEQUAL,
	// any grass/foliage/particle drawn in front (smaller FB depth) will
	// cause the test to fail and the SSAO contribution to be discarded.
	float dM = texture(modelDepthTex, uv).r;
	float dG = texture(mapDepthTex,   uv).r;
	float gbufDepth = min(dM, dG);

	// Tiny bias compensates for any FP imprecision between the gbuffer
	// pass and the live framebuffer depth attachment. Smaller is safer
	// against false-positives (i.e. SSAO leaking through grass), larger
	// is safer against false-negatives (i.e. SSAO not appearing on the
	// original surface). 1e-5 is well below grass thickness in NDC.
	gl_FragDepth = gbufDepth - 1e-5;
}
