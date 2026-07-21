-- P2.8: two-phase angle sorting (reference feedback round) — normal maps are
-- sorted by the geometric vertex normal, then the albedo is re-sorted by the
-- resulting pixel normal so color placement scatters along normal-map detail.
-- All look knobs are live uniforms — drag a slider, the map changes instantly.
-- Requires an engine with Engine.FeatureSupport.reliableLuaMapShaders (RecoilEngine PR #3127)
-- and the DrawGroundPre*/Post* barwidgets callins (included on this branch).
-- Layer textures are NOT in the repo — see LuaUI/Widgets/tileset_dev/README.md for downloads.

function widget:GetInfo()
	return {
		name    = "Tileset Terrain Prototype",
		desc    = "P2.10+: two-phase pixel-normal sorting + foothills + stagger mask + smart old-map blend (/tileset)",
		author  = "PtaQ",
		date    = "2026-07-14",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = false,
	}
end

local TEXDIR = "LuaUI/Widgets/tileset_dev/"

--------------------------------------------------------------------------------
-- knobs (defaults; live-tunable in-game via /tileset panel)
--------------------------------------------------------------------------------

local knobs = {
	scaleSoil      = 512.0,
	scaleRocky     = 512.0,
	scaleCliff     = 768.0,
	scalePlat      = 512.0,
	normalStrength = 0.65,
	cliffNormStrength = 1.0,
	cliffStartDeg  = 41.4,
	albedoSortMode = 0,   -- 0 pixel normal (the trick), 1 vertex normal (A/B comparison)
	foothillsSpanDeg = 10.0,  -- reference: intermediary band, degrees below cliffStartDeg
	footNormStrength = 2.0,   -- chunky by design
	scaleFoot      = 768.0,
	footFloor      = 0.0,     -- UE demo kept ~0.12 foothills residue on flats
	splatInfluence = 1.0,     -- terraform splat paint: 0 off, 1 full override where painted
	antiTileWarp   = 80.0,    -- domain-warp the flat layers (elmos) to curve the repeat grid
	macroVar       = 0.40,    -- large-scale tone/saturation drift so regions differ
	chunkyCliff    = 1,       -- quarry normal on the cliff too (reference: chunky on BOTH layers)
	staggerAmount  = 0.35,    -- height-lerp stagger strength (0 = plain smoothstep bands)
	maskScale1     = 1000.0,  -- stagger mask scale for the cliff lerp (elmos)
	maskScale2     = 3000.0,  -- stagger mask scale for the foothills lerp
	lumaBlend      = 0.65,
	curvHighlight  = 0.22,
	curvShadow     = 0.20,
	curvRadius     = 12.0,
	specStrength   = 0.30,
	hemiAmbient    = 0.5,     -- hemispheric ambient: cool sky above, warm bounce below (0 = flat)
	aoStrength     = 0.6,     -- how strongly AO occludes the ambient term (crevice depth)
	wetBand        = 12.0,
	smtBlend       = 0.0,
	oldCliffBlend  = 0.5,     -- pull tileset cliffs toward the ORIGINAL map's cliff palette
	shadowBias     = 0.0015,
	shadowMode     = 1,   -- 0 off, 1 depth-only, 2 + colored shadows
	debugView      = 0,   -- 0 off, 1 curv, 2 normals, 3 weights, 4 shadow, 5 shadow UV, 6 sort RGB, 7 mip footprint
	tintR          = 1.0,
	tintG          = 1.0,
	tintB          = 1.0,
	-- per-layer albedo tint (multiplies that layer's diffuse before compositing)
	soilTintR = 1.0, soilTintG = 1.0, soilTintB = 1.0,
	rockyTintR = 1.0, rockyTintG = 1.0, rockyTintB = 1.0,
	cliffTintR = 1.0, cliffTintG = 1.0, cliffTintB = 1.0,
	platTintR = 1.0, platTintG = 1.0, platTintB = 1.0,
}

-- snapshot of the shipped defaults for the panel's reset button
local DEFAULT_KNOBS = {}
for k, v in pairs(knobs) do
	DEFAULT_KNOBS[k] = v
end

-- bump when defaults/texture set change so stale saved slider values are discarded
local CONFIG_VERSION = 3

local SLIDERS = {
	{ key = "scaleSoil",      fmt = "%.0f" },
	{ key = "scaleRocky",     fmt = "%.0f" },
	{ key = "scaleCliff",     fmt = "%.0f" },
	{ key = "scalePlat",      fmt = "%.0f" },
	{ key = "normalStrength", fmt = "%.2f" },
	{ key = "cliffNormStrength", fmt = "%.2f" },
	{ key = "cliffStartDeg",  fmt = "%.1f" },
	{ key = "foothillsSpanDeg", fmt = "%.1f" },
	{ key = "footNormStrength", fmt = "%.2f" },
	{ key = "scaleFoot",      fmt = "%.0f" },
	{ key = "footFloor",      fmt = "%.2f" },
	{ key = "splatInfluence", fmt = "%.2f" },
	{ key = "antiTileWarp",   fmt = "%.0f" },
	{ key = "macroVar",       fmt = "%.2f" },
	{ key = "staggerAmount",  fmt = "%.2f" },
	{ key = "maskScale1",     fmt = "%.0f" },
	{ key = "maskScale2",     fmt = "%.0f" },
	{ key = "lumaBlend",      fmt = "%.2f" },
	{ key = "curvHighlight",  fmt = "%.2f" },
	{ key = "curvShadow",     fmt = "%.2f" },
	{ key = "curvRadius",     fmt = "%.0f" },
	{ key = "specStrength",   fmt = "%.2f" },
	{ key = "hemiAmbient",    fmt = "%.2f" },
	{ key = "aoStrength",     fmt = "%.2f" },
	{ key = "wetBand",        fmt = "%.0f" },
	{ key = "smtBlend",       fmt = "%.2f" },
	{ key = "oldCliffBlend",  fmt = "%.2f" },
	{ key = "shadowBias",     fmt = "%.4f" },
	{ key = "tintR",          fmt = "%.2f" },
	{ key = "tintG",          fmt = "%.2f" },
	{ key = "tintB",          fmt = "%.2f" },
	{ key = "soilTintR",  fmt = "%.2f" }, { key = "soilTintG",  fmt = "%.2f" }, { key = "soilTintB",  fmt = "%.2f" },
	{ key = "rockyTintR", fmt = "%.2f" }, { key = "rockyTintG", fmt = "%.2f" }, { key = "rockyTintB", fmt = "%.2f" },
	{ key = "cliffTintR", fmt = "%.2f" }, { key = "cliffTintG", fmt = "%.2f" }, { key = "cliffTintB", fmt = "%.2f" },
	{ key = "platTintR",  fmt = "%.2f" }, { key = "platTintG",  fmt = "%.2f" }, { key = "platTintB",  fmt = "%.2f" },
	{ key = "shadowMode",     fmt = "%d", int = true },
	{ key = "debugView",      fmt = "%d", int = true },
	{ key = "albedoSortMode", fmt = "%d", int = true },
	{ key = "chunkyCliff",    fmt = "%d", int = true },
}

local SLIDER_BY_KEY = {}
for _, s in ipairs(SLIDERS) do
	SLIDER_BY_KEY[s.key] = s
end

--------------------------------------------------------------------------------
-- shaders
--------------------------------------------------------------------------------

local GLSL_COMMON = [[
#version 130

#define SMF_INTENSITY_MULT (210.0 / 255.0)
#define SMF_SHALLOW_WATER_DEPTH     (10.0)
#define SMF_SHALLOW_WATER_DEPTH_INV (1.0 / SMF_SHALLOW_WATER_DEPTH)

uniform sampler2D diffuseTex;   // TU0  engine SMT tile
uniform sampler2D heightMapTex; // TU1
uniform sampler2D normalsTex;   // TU2  $normals (.ra = geometric normal xz)
uniform sampler2D soilDiff;     // TU3
uniform sampler2D soilNorm;     // TU4
uniform sampler2D soilArm;      // TU5
uniform sampler2D rockyDiff;    // TU6
uniform sampler2D rockyNorm;    // TU7
uniform sampler2D rockyArm;     // TU8
uniform sampler2D cliffDiff;    // TU9
uniform sampler2D cliffNorm;    // TU10
uniform sampler2D cliffArm;     // TU11
uniform sampler2D platDiff;     // TU12
uniform sampler2D platNorm;     // TU13
uniform sampler2D platArm;      // TU14
uniform sampler2DShadow shadowTex;      // TU15 $shadow
uniform sampler2D       shadowColorTex; // TU16 $shadow_color
uniform sampler2D       infoTex;        // TU17 $info
uniform sampler2D footNorm;     // TU18 foothills chunky normal (diffuse+ARM shared with cliff)
uniform sampler2D staggerTex;   // TU19 abstract grayscale stagger mask (terrain revamp reference)
uniform sampler2D splatDistrTex;// TU20 $ssmf_splat_distr — terraform splat paint (R=auto, GBA=talus/cliff/plat)

uniform vec2 specularTexGen;    // 1/mapSize (elmos)
uniform vec2 mapHeights;
uniform vec3 sunDir;
uniform vec3 sunAmbient;
uniform vec3 sunDiffuse;
uniform vec3 cameraPos;

uniform mat4 shadowMat;
uniform float groundShadowDensity;
uniform int shadowsEnabled;

uniform vec2 infoTexGen;
uniform float infoTexIntensityMul;
uniform int infoTexEnabled;

uniform vec3 waterMinColor;
uniform vec3 waterBaseColor;
uniform vec3 waterAbsorbColor;
uniform int waterEnabled;

// live tuning knobs
uniform float scaleSoil;
uniform float scaleRocky;
uniform float scaleCliff;
uniform float scalePlat;
uniform float normalStrength;
uniform float cliffNormStrength;
uniform float cliffStartDeg;
uniform int albedoSortMode;
uniform float foothillsSpanDeg;
uniform float footNormStrength;
uniform float scaleFoot;
uniform float footFloor;
uniform int footEnabled;
uniform float splatInfluence;
uniform float antiTileWarp;
uniform float macroVar;
uniform float pixelFootprint;   // 2*tan(fovY/2)/viewportY — pixel cone angle
uniform float staggerAmount;    // height-lerp stagger strength (0 = plain smoothstep)
uniform float maskScale1;       // stagger mask world scale for the cliff lerp
uniform float maskScale2;       // stagger mask world scale for the foothills lerp
uniform int staggerEnabled;
uniform float lumaBlend;
uniform float curvHighlight;
uniform float curvShadow;
uniform float curvRadius;
uniform float specStrength;
uniform float hemiAmbient;
uniform float aoStrength;
uniform float wetBand;
uniform float smtBlend;
uniform float oldCliffBlend;
uniform vec3 oldCliffGain;      // orig-map cliff avg / tileset cliff mean (1,1,1 = off)
uniform float shadowBias;
uniform int shadowMode;
uniform int debugView;
uniform vec3 biomeTint;
uniform vec3 soilTint;
uniform vec3 rockyTint;
uniform vec3 cliffTint;
uniform vec3 platTint;

in vec4 vertexWorldPos;
in vec2 diffuseTexCoords;
in float fogFactor;
in float viewDist;

// ---------------------------------------------------------------- noise ----
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	v += 0.50 * vnoise(p);
	v += 0.25 * vnoise(p * 2.03);
	v += 0.125 * vnoise(p * 4.09);
	return v / 0.875;
}

// ------------------------------------------------------------- sampling ----
vec3 getGeoNormal(vec2 wxz) {
	vec2 nxz = texture(normalsTex, wxz * specularTexGen).ra;
	return vec3(nxz.x, sqrt(max(0.0, 1.0 - dot(nxz, nxz))), nxz.y);
}

float heightAt(vec2 wxz) {
	const vec2 HM_TEXEL = vec2(8.0, 8.0);
	vec2 mapSize = vec2(1.0) / specularTexGen;
	wxz += -HM_TEXEL * (wxz * specularTexGen) + 0.5 * HM_TEXEL;
	vec2 uvhm = clamp(wxz, HM_TEXEL, mapSize - HM_TEXEL);
	return textureLod(heightMapTex, uvhm * specularTexGen, 0.0).x;
}

float curvatureAt(vec2 wxz, float hHere) {
	float e = curvRadius;
	float lap = heightAt(wxz + vec2(e, 0.0)) + heightAt(wxz - vec2(e, 0.0))
	          + heightAt(wxz + vec2(0.0, e)) + heightAt(wxz - vec2(0.0, e))
	          - 4.0 * hHere;
	return clamp(-lap / (e * 2.0), -1.0, 1.0);
}

vec4 detile(sampler2D sam, vec2 uv, float f, vec2 gx, vec2 gy) {
	vec4 base = textureGrad(sam, uv, gx, gy);
	if (f <= 0.01)
		return base;
	return mix(base, textureGrad(sam, uv * 0.3718 + vec2(11.7, 5.3), gx * 0.3718, gy * 0.3718), f);
}

vec4 biplanar(sampler2D sam, vec3 p, vec3 dpdx, vec3 dpdy, vec3 n, float k) {
	n = abs(n) + vec3(0.0001);
	ivec3 ma = (n.x > n.y && n.x > n.z) ? ivec3(0,1,2) : ((n.y > n.z) ? ivec3(1,2,0) : ivec3(2,0,1));
	ivec3 mi = (n.x < n.y && n.x < n.z) ? ivec3(0,1,2) : ((n.y < n.z) ? ivec3(1,2,0) : ivec3(2,0,1));
	ivec3 me = ivec3(3) - mi - ma;
	vec4 x = textureGrad(sam, vec2(p[ma.y], p[ma.z]),
	                     vec2(dpdx[ma.y], dpdx[ma.z]), vec2(dpdy[ma.y], dpdy[ma.z]));
	vec4 y = textureGrad(sam, vec2(p[me.y], p[me.z]),
	                     vec2(dpdx[me.y], dpdx[me.z]), vec2(dpdy[me.y], dpdy[me.z]));
	vec2 m = vec2(n[ma.x], n[me.x]);
	m = clamp((m - 0.5773) / (1.0 - 0.5773), 0.0, 1.0);
	m = pow(m, vec2(k / 8.0));
	return (x * m.x + y * m.y) / (m.x + m.y);
}

vec3 biplanarNormalDelta(sampler2D sam, vec3 p, vec3 dpdx, vec3 dpdy, vec3 n, float k) {
	vec3 an = abs(n) + vec3(0.0001);
	ivec3 ma = (an.x > an.y && an.x > an.z) ? ivec3(0,1,2) : ((an.y > an.z) ? ivec3(1,2,0) : ivec3(2,0,1));
	ivec3 mi = (an.x < an.y && an.x < an.z) ? ivec3(0,1,2) : ((an.y < an.z) ? ivec3(1,2,0) : ivec3(2,0,1));
	ivec3 me = ivec3(3) - mi - ma;
	vec3 x = textureGrad(sam, vec2(p[ma.y], p[ma.z]),
	                     vec2(dpdx[ma.y], dpdx[ma.z]), vec2(dpdy[ma.y], dpdy[ma.z])).xyz * 2.0 - 1.0;
	vec3 y = textureGrad(sam, vec2(p[me.y], p[me.z]),
	                     vec2(dpdx[me.y], dpdx[me.z]), vec2(dpdy[me.y], dpdy[me.z])).xyz * 2.0 - 1.0;
	vec2 m = vec2(an[ma.x], an[me.x]);
	m = clamp((m - 0.5773) / (1.0 - 0.5773), 0.0, 1.0);
	m = pow(m, vec2(k / 8.0));
	vec3 d = vec3(0.0);
	d[ma.y] += x.x * m.x;
	d[ma.z] += x.y * m.x;
	d[me.y] += y.x * m.y;
	d[me.z] += y.y * m.y;
	return d / (m.x + m.y);
}

// ---------------------------------------------------------- compositing ----
struct Surf {
	vec3 albedo;
	vec3 normal;
	float ao;
	float rough;
	float curv;
	vec4 weights;
	float wfoot;
	float trueH;   // heightmap-texture height, stable under retessellation
};

// The reference's height-lerp: shift the transition phase by the world-projected
// grayscale mask so layer borders break into staggered organic shapes
// instead of clean gradients; mask 0.5 = no shift, staggerAmount 0 = off
float stagger(float phase, float h) {
	return clamp(phase + (h - 0.5) * staggerAmount, 0.0, 1.0);
}

// One sort function, called twice: fed the vertex normal it places the normal
// maps; fed the pixel normal it places the albedo (the reference's two-phase trick).
// Everything slope-derived lives in here; normal-independent terms are passed in.
// Nested-lerp partition (UE reference): cliff mask first, then the foothills
// band carves the remainder, then plateau/talus/soil split the base group.
// Returns soil/rocky/cliff/plat in the vec4, foothills via the out param.
vec4 angleWeights(vec3 n, float hNorm, float cavity, float nPatch, float nField, vec4 luma, float mask1, float mask2, out float outFoot) {
	float slope = 1.0 - n.y;
	// the old noise dither fades out as the stagger mask takes over its job
	// (two independent perturbations on one threshold read as mush)
	float dither = (1.0 - staggerAmount) * (nPatch - 0.5);
	float cliffLo = 1.0 - cos(radians(cliffStartDeg));
	float mCliff = stagger(smoothstep(cliffLo, cliffLo + 0.20, slope + 0.08 * dither), mask1);

	// foothills: intermediary band rising over foothillsSpanDeg degrees below
	// the base/cliff meeting angle (reference), handed over as the cliff takes hold
	float degSlope = degrees(acos(clamp(n.y, 0.0, 1.0)));
	float mFoot = stagger(smoothstep(cliffStartDeg - max(foothillsSpanDeg, 0.1), cliffStartDeg,
	                                 degSlope + 6.5 * dither), mask2);
	mFoot = max(mFoot, footFloor) * float(footEnabled);

	float wCliff = mCliff;
	float wFoot  = (1.0 - mCliff) * mFoot;
	float gBase  = (1.0 - mCliff) * (1.0 - mFoot);

	float pf = smoothstep(0.60, 0.72, hNorm + 0.10 * (nPatch - 0.5));
	float wPlat  = gBase * pf;
	float talus = smoothstep(0.08, 0.30, slope)
	            + cavity * 1.5
	            + 0.9 * smoothstep(0.60, 0.80, nField);
	float avail  = gBase * (1.0 - pf);
	float wRocky = avail * clamp(talus, 0.0, 1.0);
	float wSoil  = avail - wRocky;

	vec4 ws = vec4(wSoil, wRocky, wCliff, wPlat);
	float wf = wFoot;
	ws = ws * ws * ws;
	wf = wf * wf * wf;
	ws *= mix(vec4(1.0), luma * 2.0, lumaBlend);
	wf *= mix(1.0, luma.z * 2.0, lumaBlend);   // shares the cliff diffuse, shares its luma
	float sum = ws.x + ws.y + ws.z + ws.w + wf + 0.0001;
	outFoot = wf / sum;
	return ws / sum;
}

// terraform-brush splat paint: the painter's canvas defaults to (1,0,0,0), so
// R = "leave automatic", G/B/A = force talus/cliff/plateau. Blend the sorted
// weights toward the painted layer(s) by how much G+B+A the artist laid down.
// The brush falloff is broken up by the stagger mask so a painted patch's edge
// reads as organic rock, not the brush's smooth circle (same mask, same look
// as the automatic layer transitions).
void applySplat(inout vec4 ws, inout float wf, vec4 splat, float mask) {
	float force = clamp(splat.g + splat.b + splat.a, 0.0, 1.0);
	if (force <= 0.001)
		return;
	// jitter the falloff midpoint by the mask, and sharpen with stagger — at
	// staggerAmount 0 this is a gentle S (pure blend-by-strength preserved)
	float c = clamp(0.5 - (mask - 0.5) * staggerAmount * 0.6, 0.25, 0.75);
	float w = mix(0.5, 0.22, clamp(staggerAmount, 0.0, 1.0));
	float ovr = smoothstep(c - w, c + w, force) * splatInfluence;
	if (ovr <= 0.001)
		return;
	vec4 forced = vec4(0.0, splat.g, splat.b, splat.a) / max(splat.g + splat.b + splat.a, 0.0001);
	ws = mix(ws, forced, ovr);
	wf *= (1.0 - ovr);
	float s = ws.x + ws.y + ws.z + ws.w + wf + 0.0001;
	ws /= s;
	wf /= s;
}

Surf composite() {
	vec2 wxz = vertexWorldPos.xz;
	// ROAM retessellation changes the interpolated vertex height between LOD
	// levels; anchor every height-derived shading term to the heightmap
	// texture instead so the surface pattern stays put when the mesh pops
	// (the geometric silhouette still moves — that part is the mesh drawer's)
	float hTrue = heightAt(wxz);
	vec3 geoN = getGeoNormal(wxz);
	float hNorm = clamp((hTrue - mapHeights.x) / max(1.0, mapHeights.y - mapHeights.x), 0.0, 1.0);

	float nPatch = fbm(wxz / 900.0);
	float nField = fbm(wxz / 1700.0 + 71.3);
	float nHue   = fbm(wxz / 2400.0 + 47.9);

	// curvature before the weights: talus/debris gathers in the concavities
	// at cliff feet, not in a thin slope-band ring
	float curv = curvatureAt(wxz, hTrue);
	float cavity = max(-curv, 0.0);

	// biplanar coords from the texture height: the projected y is what slides
	// on cliff walls when the mesh retessellates
	vec3 truePos = vec3(wxz.x, hTrue, wxz.y);
	vec3 pCliff = truePos / scaleCliff;
	vec3 pFoot = truePos / scaleFoot;

	// texture-sampling gradients, built analytically from the pixel ray cone
	// hitting the heightmap-true surface: raster dFdx would inherit the ROAM
	// mesh's triangle planes and make filtering breathe with tessellation
	vec3 viewVec = truePos - cameraPos;
	float vDist = max(length(viewVec), 1.0);
	vec3 vDir = viewVec / vDist;
	vec3 bX = normalize((abs(vDir.y) > 0.99) ? cross(vDir, vec3(1.0, 0.0, 0.0)) : cross(vDir, vec3(0.0, 1.0, 0.0)));
	vec3 bY = cross(bX, vDir);
	float denom = dot(vDir, geoN);
	// clamp near-grazing footprints (~12x stretch max, within hw aniso reach)
	float invDenom = 1.0 / ((abs(denom) < 0.08) ? ((denom < 0.0) ? -0.08 : 0.08) : denom);
	float fp = vDist * pixelFootprint;
	vec3 gPx = fp * (bX - vDir * (dot(bX, geoN) * invDenom));
	vec3 gPy = fp * (bY - vDir * (dot(bY, geoN) * invDenom));
	vec3 pcdx = gPx / scaleCliff;
	vec3 pcdy = gPy / scaleCliff;
	// foothills gradients likewise hoisted outside the wNf branch below
	// (explicit gradients are what make the branched textureGrad legal)
	vec3 pfdx = gPx / scaleFoot;
	vec3 pfdy = gPy / scaleFoot;

	// stage 1: sample + project every layer; projection (biplanar plane pick)
	// stays on the stable vertex normal — only the SORTING differs per output
	// stagger mask: one tap per angle-sort lerp (reference: scale1 -> cliff,
	// scale2 -> foothills) + one huge-scale tap for the macro tiling breakup
	// ("one mask, sampled per purpose, used everywhere")
	float mask1 = 0.5, mask2 = 0.5, mMacro = 0.5;
	if (staggerEnabled == 1) {
		mask1  = textureGrad(staggerTex, wxz / maskScale1, gPx.xz / maskScale1, gPy.xz / maskScale1).r;
		mask2  = textureGrad(staggerTex, wxz / maskScale2, gPx.xz / maskScale2, gPy.xz / maskScale2).r;
		mMacro = textureGrad(staggerTex, wxz / 9000.0, gPx.xz / 9000.0, gPy.xz / 9000.0).r;
	}

	// vDist (from the true surface) rather than the mesh-interpolated viewDist
	// varying — the last remaining tessellation-coupled input
	float dtf = 0.5 * smoothstep(1200.0, 3500.0, vDist);

	// domain-warp the planar-tiled layers: a low-frequency offset bends the
	// repeat grid so straight tiling seams curve away and hide. Gradients are
	// left unwarped (the warp is low-freq, its derivative ~1), and the warp
	// only touches the flat layers — geoN/curvature/splat stay on true wxz
	vec2 wxzT = wxz + (vec2(fbm(wxz / 1300.0 + 3.1), fbm(wxz / 1300.0 + 8.7)) - 0.5) * antiTileWarp;

	vec2 gSoilX = gPx.xz / scaleSoil,  gSoilY = gPy.xz / scaleSoil;
	vec2 gRckX  = gPx.xz / scaleRocky, gRckY  = gPy.xz / scaleRocky;
	vec2 gPltX  = gPx.xz / scalePlat,  gPltY  = gPy.xz / scalePlat;
	vec4 dSoil  = detile(soilDiff,  wxzT / scaleSoil, dtf, gSoilX, gSoilY);
	vec4 dRocky = detile(rockyDiff, wxzT / scaleRocky, dtf, gRckX, gRckY);
	vec4 dPlat  = detile(platDiff,  wxzT / scalePlat, dtf, gPltX, gPltY);
	vec4 dCliff = biplanar(cliffDiff, pCliff, pcdx, pcdy, geoN, 8.0);

	vec4 luma = vec4(
		dot(dSoil.rgb,  vec3(0.334)),
		dot(dRocky.rgb, vec3(0.334)),
		dot(dCliff.rgb, vec3(0.334)),
		dot(dPlat.rgb,  vec3(0.334)));

	// per-layer albedo tint (after luma so recolouring doesn't shift placement);
	// cliffTint also covers the foothills band, which shares the cliff diffuse
	dSoil.rgb  *= soilTint;
	dRocky.rgb *= rockyTint;
	dCliff.rgb *= cliffTint;
	dPlat.rgb  *= platTint;
	// pull the cliff toward the ORIGINAL map's cliff palette: a constant gain
	// (orig-map cliff average / this texture's own mean, extracted at init from
	// the baked minimap) so freshly terraformed cliffs match the map's native
	// rock color; the foothills band shares the cliff diffuse and follows along
	dCliff.rgb *= mix(vec3(1.0), oldCliffGain, oldCliffBlend);

	vec4 aSoil  = textureGrad(soilArm,  wxzT / scaleSoil, gSoilX, gSoilY);
	vec4 aRocky = textureGrad(rockyArm, wxzT / scaleRocky, gRckX, gRckY);
	vec4 aPlat  = textureGrad(platArm,  wxzT / scalePlat, gPltX, gPltY);
	vec4 aCliff = biplanar(cliffArm, pCliff, pcdx, pcdy, geoN, 8.0);

	vec3 dnSoil  = textureGrad(soilNorm,  wxzT / scaleSoil, gSoilX, gSoilY).xyz * 2.0 - 1.0;
	vec3 dnRocky = textureGrad(rockyNorm, wxzT / scaleRocky, gRckX, gRckY).xyz * 2.0 - 1.0;
	vec3 dnPlat  = textureGrad(platNorm,  wxzT / scalePlat, gPltX, gPltY).xyz * 2.0 - 1.0;
	vec3 dnCliff = biplanarNormalDelta(cliffNorm, pCliff, pcdx, pcdy, geoN, 8.0);

	// hand-painted splat override (same map-space UV as $normals); default
	// (1,0,0,0) leaves force=0 so untouched maps sort purely automatically
	vec4 splat = (splatInfluence > 0.0) ? texture(splatDistrTex, wxz * specularTexGen) : vec4(1.0, 0.0, 0.0, 0.0);

	// stage 2: sort the normal maps by the VERTEX normal, then build the
	// pixel normal (the UE PixelNormalWS equivalent)
	float wNf;
	vec4 wN = angleWeights(geoN, hNorm, cavity, nPatch, nField, luma, mask1, mask2, wNf);
	applySplat(wN, wNf, splat, mask1);
	vec3 dnFoot = vec3(0.0);
	if (wNf > 0.004)
		dnFoot = biplanarNormalDelta(footNorm, pFoot, pfdx, pfdy, geoN, 8.0);
	vec2 dpl = dnSoil.xy * wN.x + dnRocky.xy * wN.y + dnPlat.xy * wN.w;
	vec3 delta = vec3(dpl.x, 0.0, dpl.y);
	delta += dnCliff * (wN.z * cliffNormStrength);
	delta += dnFoot * (wNf * footNormStrength);
	vec3 pixelN = normalize(geoN + normalStrength * delta);

	// stage 3: sort the albedo by the PIXEL normal, so color placement
	// inherits the normal-map detail (mode 1 = vertex normal, the flat-band
	// counter-example, kept as the live A/B proof)
	vec3 sortN = (albedoSortMode == 1) ? geoN : pixelN;
	float wAf;
	vec4 wA = angleWeights(sortN, hNorm, cavity, nPatch, nField, luma, mask1, mask2, wAf);
	applySplat(wA, wAf, splat, mask1);

	// foothills shares the cliff's biplanar diffuse/ARM (reference: the layer is
	// "only there so that you can add a specific, intense normal to it")
	Surf s;
	s.albedo  = dSoil.rgb * wA.x + dRocky.rgb * wA.y + dCliff.rgb * (wA.z + wAf) + dPlat.rgb * wA.w;
	s.ao      = aSoil.r * wA.x + aRocky.r * wA.y + aCliff.r * (wA.z + wAf) + aPlat.r * wA.w;
	s.rough   = aSoil.g * wA.x + aRocky.g * wA.y + aCliff.g * (wA.z + wAf) + aPlat.g * wA.w;
	s.weights = wA;
	s.wfoot   = wAf;
	s.normal  = pixelN;

	// stage 4: flavor
	s.curv = curv;
	s.trueH = hTrue;
	float ndlGeo = clamp(dot(geoN, sunDir), 0.0, 1.0);
	s.albedo *= 1.0 + curvHighlight * max(curv, 0.0) * (0.4 + 0.6 * ndlGeo);
	s.albedo *= 1.0 - curvShadow * cavity;

	s.albedo *= biomeTint;

	// large-scale variation so no two regions read identical: two huge mask
	// scales drive brightness, a slower one drives saturation, plus the hue
	// drift — this is what stops the eye from locking onto the tile repeat
	float macro2 = (staggerEnabled == 1)
		? textureGrad(staggerTex, wxz / 3300.0 + 22.0, gPx.xz / 3300.0, gPy.xz / 3300.0).r
		: 0.5;
	s.albedo *= 1.0 + macroVar * ((mMacro - 0.5) * 0.6 + (macro2 - 0.5) * 0.4);
	float macroLum = dot(s.albedo, vec3(0.299, 0.587, 0.114));
	s.albedo = mix(vec3(macroLum), s.albedo, 1.0 + macroVar * (macro2 - 0.5) * 0.7);
	s.albedo *= vec3(1.0 + 0.10 * (nHue - 0.5), 1.0, 1.0 - 0.08 * (nHue - 0.5));

	vec3 gLow  = vec3(0.82, 0.62, 0.55);
	vec3 gMid  = vec3(1.00, 0.96, 0.92);
	vec3 gHigh = vec3(1.10, 1.06, 1.00);
	vec3 grade = mix(mix(gLow, gMid, smoothstep(0.0, 0.45, hNorm)), gHigh, smoothstep(0.45, 1.0, hNorm));
	s.albedo *= grade;

	if (waterEnabled == 1)
		s.albedo *= mix(0.6, 1.0, smoothstep(1.0, max(wetBand, 1.5), hTrue));

	if (smtBlend > 0.0) {
		vec3 smt = texture(diffuseTex, diffuseTexCoords).rgb;
		// flats only: the old diffuse is a valid per-pixel color reference where
		// the ground is flat, but on cliff/foothills pixels it would smear the
		// old flat-ground color over the rock (terraformed cliffs were flat in
		// the original bake) — those follow oldCliffGain instead
		float rockness = clamp(s.weights.z + s.wfoot, 0.0, 1.0);
		s.albedo = mix(s.albedo, s.albedo * (smt * 2.0), smtBlend * (1.0 - rockness));
	}

	// lighter flat AO on the albedo now that AO also occludes ambient in the
	// forward pass (keeps the deferred G-buffer grounded without double-dark)
	s.albedo *= mix(1.0, s.ao, 0.4);
	return s;
}

vec3 getShadeInt(float groundLightInt, vec3 groundShadowCoeff, float h, float ny, float ao) {
	// hemispheric ambient: cool sky from above, warm bounce from below; AO
	// occludes the ambient (crevices lose skylight — the between-layer depth
	// cue). Both knobs at 0 collapse back to the flat engine ambient.
	float hemi = 0.5 + 0.5 * ny;
	vec3 skyTint = mix(vec3(1.0), vec3(0.94, 0.99, 1.10), hemiAmbient);
	vec3 gndTint = mix(vec3(1.0), vec3(1.08, 0.98, 0.86), hemiAmbient);
	vec3 skyAmb  = sunAmbient * (1.0 + hemiAmbient * 0.50) * skyTint;
	vec3 gndAmb  = sunAmbient * (1.0 - hemiAmbient * 0.45) * gndTint;
	vec3 ambient = mix(gndAmb, skyAmb, hemi) * mix(1.0, ao, aoStrength);

	vec3 groundShadeInt = ambient + sunDiffuse * (groundLightInt * groundShadowCoeff);
	groundShadeInt *= SMF_INTENSITY_MULT;

	if (waterEnabled == 1 && h < 0.0 && mapHeights.x <= 0.0) {
		vec3 waterShadeInt = waterBaseColor;
		float waterShadeAlpha  = abs(h) * SMF_SHALLOW_WATER_DEPTH_INV;
		float waterShadeDecay  = 0.2 + (waterShadeAlpha * 0.1);
		float vertexStepHeight = min(1023.0, -h);
		float waterLightInt    = min(groundLightInt * 2.0 + 0.4, 1.0);

		waterShadeAlpha = min(1.0, waterShadeAlpha + float(h <= -SMF_SHALLOW_WATER_DEPTH));

		waterShadeInt -= (waterAbsorbColor * vertexStepHeight);
		waterShadeInt  = max(waterMinColor, waterShadeInt);
		waterShadeInt *= (SMF_INTENSITY_MULT * waterLightInt);
		waterShadeInt *= (1.0 - waterShadeDecay * (vec3(1.0) - groundShadowCoeff));

		return mix(groundShadeInt, waterShadeInt, waterShadeAlpha);
	}
	return groundShadeInt;
}

vec3 getShadowCoeff() {
	if (shadowMode == 0 || shadowsEnabled != 1)
		return vec3(1.0);
	vec4 vertexShadowPos = shadowMat * vertexWorldPos;
	// the drawing matrix outputs xy centered on 0; engine SMFFragProg recenters
	// into [0,1] the same way (the missing line that displaced all shadows)
	vertexShadowPos.xy += vec2(0.5);

	vec3 proj = vertexShadowPos.xyz / vertexShadowPos.w;
	if (proj.x < 0.0 || proj.x > 1.0 || proj.y < 0.0 || proj.y > 1.0 || proj.z > 1.0)
		return vec3(1.0);

	vertexShadowPos.z -= shadowBias * vertexShadowPos.w;

	float sh = shadow2DProj(shadowTex, vertexShadowPos).r;
	vec3 shadowColor = (shadowMode >= 2) ? texture(shadowColorTex, proj.xy).rgb : vec3(1.0);
	return mix(vec3(1.0), sh * shadowColor, groundShadowDensity);
}
]]

local GLSL_FWD_MAIN = [[
out vec4 fragColor;

void main() {
	Surf s = composite();

	if (debugView == 1) { fragColor = vec4(vec3(0.5 + s.curv * 0.5), 1.0); return; }
	if (debugView == 2) { fragColor = vec4(s.normal * 0.5 + 0.5, 1.0); return; }
	if (debugView == 3) { fragColor = vec4(s.weights.y, s.weights.z, s.weights.w, 1.0); return; }
	if (debugView == 4) { fragColor = vec4(getShadowCoeff(), 1.0); return; }        // white=lit, dark=shadowed
	if (debugView == 5) {                                                            // shadow-map UV as RG, blue=outside frustum
		vec4 sp = shadowMat * vertexWorldPos;
		sp.xy += vec2(0.5);
		vec3 proj = sp.xyz / sp.w;
		bool inside = proj.x >= 0.0 && proj.x <= 1.0 && proj.y >= 0.0 && proj.y <= 1.0;
		fragColor = inside ? vec4(proj.xy, 0.0, 1.0) : vec4(0.0, 0.0, 1.0, 1.0);
		return;
	}
	if (debugView == 6) {                                                            // reference demo: cliff=red, foothills=green, base=blue
		fragColor = vec4(s.weights.z, s.wfoot, s.weights.x + s.weights.y + s.weights.w, 1.0);
		return;
	}
	if (debugView == 7) {                                                            // raw splat sample: R=auto, G/B/A=talus/cliff/plateau paint
		fragColor = vec4(texture(splatDistrTex, vertexWorldPos.xz * specularTexGen).rgb, 1.0);
		return;
	}

	vec3 albedo = s.albedo;
	if (infoTexEnabled == 1) {
		vec2 infoTexCoords = vertexWorldPos.xz * infoTexGen;
		albedo += texture(infoTex, infoTexCoords).rgb * infoTexIntensityMul;
		albedo -= vec3(0.5) * float(infoTexIntensityMul == 1.0);
	}

	vec3 shadowCoeff = getShadowCoeff();
	float ndl = clamp(dot(s.normal, sunDir), 0.0, 1.0);
	vec3 lit = albedo * getShadeInt(ndl, shadowCoeff, s.trueH, s.normal.y, s.ao);

	vec3 viewDir = normalize(cameraPos - vertexWorldPos.xyz);
	vec3 halfDir = normalize(sunDir + viewDir);
	float gloss = 1.0 - s.rough;
	float spec = pow(clamp(dot(s.normal, halfDir), 0.0, 1.0), mix(8.0, 96.0, gloss * gloss)) * gloss;
	lit += sunDiffuse * (spec * specStrength * s.ao) * shadowCoeff;

	fragColor = vec4(mix(gl_Fog.color.rgb, lit, fogFactor), 1.0);
}
]]

local GLSL_DFR_MAIN = [[
out vec4 fragData[5];

void main() {
	Surf s = composite();
	fragData[0] = vec4((s.normal + 1.0) * 0.5, 1.0);
	fragData[1] = vec4(s.albedo, 1.0);
	fragData[2] = vec4(vec3((1.0 - s.rough) * 0.2), 1.0);
	fragData[3] = vec4(0.0);
	fragData[4] = vec4(0.0);
}
]]

local VERT_SRC = [[
#version 130
in vec3 vertexPos;

uniform ivec2 texSquare;
uniform vec2 specularTexGen;
uniform sampler2D heightMapTex; // TU1

out vec4 vertexWorldPos;
out vec2 diffuseTexCoords;
out float fogFactor;
out float viewDist;

const float SMF_TEXSQR_SIZE = 1024.0;

float HeightAtWorldPos(vec2 wxz) {
	const vec2 HM_TEXEL = vec2(8.0, 8.0);
	vec2 mapSize = vec2(1.0) / specularTexGen;
	wxz += -HM_TEXEL * (wxz * specularTexGen) + 0.5 * HM_TEXEL;
	vec2 uvhm = clamp(wxz, HM_TEXEL, mapSize - HM_TEXEL);
	uvhm *= specularTexGen;
	return textureLod(heightMapTex, uvhm, 0.0).x;
}

void main() {
	vertexWorldPos = vec4(vertexPos, 1.0);
	vertexWorldPos.xz += vec2(texSquare) * SMF_TEXSQR_SIZE;
	vertexWorldPos.y = HeightAtWorldPos(vertexWorldPos.xz);

	diffuseTexCoords = (vertexWorldPos.xz / SMF_TEXSQR_SIZE) - vec2(texSquare);

	gl_Position = gl_ModelViewProjectionMatrix * vertexWorldPos;
	gl_ClipVertex = gl_ModelViewMatrix * vertexWorldPos;

	float fogCoord = length(gl_ClipVertex.xyz);
	viewDist = fogCoord;
	fogFactor = clamp((gl_Fog.end - fogCoord) * gl_Fog.scale, 0.0, 1.0);
}
]]

-- minimap/grass top-down composite: run composite() over a fullscreen quad
-- where each texel = a world XZ column, producing an unlit albedo map that
-- the engine binds to $minimap (x $shading) and $grass (tints the blades)
local VERT_MM = [[
#version 130
uniform vec2 specularTexGen;    // 1/mapSize
uniform sampler2D heightMapTex; // TU1

out vec4 vertexWorldPos;
out vec2 diffuseTexCoords;
out float fogFactor;
out float viewDist;

float HeightAtWorldPos(vec2 wxz) {
	const vec2 HM_TEXEL = vec2(8.0, 8.0);
	vec2 mapSize = vec2(1.0) / specularTexGen;
	wxz += -HM_TEXEL * (wxz * specularTexGen) + 0.5 * HM_TEXEL;
	vec2 uvhm = clamp(wxz, HM_TEXEL, mapSize - HM_TEXEL);
	uvhm *= specularTexGen;
	return textureLod(heightMapTex, uvhm, 0.0).x;
}

void main() {
	vec2 uv = gl_MultiTexCoord0.st;         // [0,1] over the map
	vec2 wxz = uv / specularTexGen;         // world XZ
	vertexWorldPos = vec4(wxz.x, HeightAtWorldPos(wxz), wxz.y, 1.0);
	// the top-down pass binds the original-minimap snapshot to the diffuse
	// slot, so the old-map blend shows on the minimap/grass composite too
	diffuseTexCoords = uv;
	fogFactor = 1.0;
	viewDist = 100000.0;                    // past the detile distance fade
	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
]]

local GLSL_MM_MAIN = [[
out vec4 fragColor;

void main() {
	Surf s = composite();
	fragColor = vec4(s.albedo, 1.0);        // unlit; $shading supplies relief
}
]]

--------------------------------------------------------------------------------
-- shader management
--------------------------------------------------------------------------------

local fwdShader, dfrShader
local mmShader, mmUniforms = nil, {}
local mmTex, mmDirty, mmEnabled = nil, true, true
local mmRenderedOnce = false
local MM_RES = 1024

-- old-map palette: GPU-reduce the ORIGINAL map's baked minimap into its average
-- cliff albedo (slope-masked via a terrain snapshot); the ratio to the tileset
-- cliff texture's own mean becomes the constant oldCliffGain recolor uniform
local origMapTex, origTerrainTex, paletteTex
local snapShader, reduceShader, reduceCliffLoLoc
local paletteDirty, paletteLastRun = true, nil
local paletteGain = { 1.0, 1.0, 1.0 }
local paletteInfo = nil
local PALETTE_RES = 1024

local VERT_SNAP = [[
#version 130
out vec2 snapUV;
void main() {
	snapUV = gl_MultiTexCoord0.st;
	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
]]

-- terrain snapshot: slope + height per texel, taken once so re-extraction stays
-- consistent after terraform (the live $normals would misclassify new cliffs)
local FRAG_SNAP_TERRAIN = [[
#version 130
uniform sampler2D normalsSnap;  // $normals (.ra = geometric normal xz)
uniform sampler2D heightSnap;   // $heightmap
in vec2 snapUV;
out vec4 fragColor;
void main() {
	vec2 nxz = texture(normalsSnap, snapUV).ra;
	float ny = sqrt(max(0.0, 1.0 - dot(nxz, nxz)));
	fragColor = vec4(1.0 - ny, texture(heightSnap, snapUV).x, 0.0, 1.0);
}
]]

-- 3x1 reduction: pixel 0 = original-map cliff-average color (+ cliff fraction
-- of land in alpha), pixel 1 = flat average, pixel 2 = the tileset cliff
-- diffuse's own mean (its top mip) — read back once and turned into a gain
local FRAG_REDUCE = [[
#version 130
#define GRID 256
uniform sampler2D origMap;      // snapshot of the original $minimap
uniform sampler2D origTerrain;  // r = slope, g = height (elmos)
uniform sampler2D cliffDiffT;   // tileset cliff diffuse
uniform float cliffLo;
out vec4 fragColor;
void main() {
	int col = int(gl_FragCoord.x);
	if (col == 2) {
		fragColor = vec4(textureLod(cliffDiffT, vec2(0.5), 20.0).rgb, 1.0);
		return;
	}
	vec3 sum = vec3(0.0);
	float wSum = 0.0;
	float total = 0.0;
	for (int i = 0; i < GRID; i++)
	for (int j = 0; j < GRID; j++) {
		vec2 uv = (vec2(i, j) + 0.5) / float(GRID);
		vec2 st = textureLod(origTerrain, uv, 0.0).rg;
		// underwater texels carry the baked water tint, keep them out
		float land = (WATER_MAP == 1) ? smoothstep(0.0, 4.0, st.y) : 1.0;
		float wc = smoothstep(cliffLo, cliffLo + 0.20, st.x);
		float w = ((col == 0) ? wc : (1.0 - wc)) * land;
		sum   += textureLod(origMap, uv, 3.0).rgb * w;
		wSum  += w;
		total += land;
	}
	fragColor = vec4(sum / max(wSum, 0.001), wSum / max(total, 1.0));
}
]]
local fwdUniforms, dfrUniforms = {}, {}
local waterEnabled = 0
local footEnabled = 1
local staggerEnabled = 1

local KNOB_INT = { shadowMode = true, debugView = true, albedoSortMode = true, chunkyCliff = true }
-- knobs consumed on the Lua side (texture binds), not shader uniforms
local KNOB_LUA = { chunkyCliff = true }

-- The reference's chunky quarry normal (converted from TIF, green flipped DX->GL);
-- the chunkyCliff knob (or /tileset chunky) swaps it onto the cliff slot live
local CLIFF_NORM_DEFAULT = ":a:" .. TEXDIR .. "cliff_side_nor_gl_2k.jpg"
local CLIFF_NORM_CHUNKY  = ":a:" .. TEXDIR .. "quarry_cliff_chunky_nor_gl_2k.png"

local LAYER_TEXTURES = {
	-- one same-session collection (Poly Haven "namaqualand" red-rock desert)
	[3]  = ":a:" .. TEXDIR .. "sandy_gravel_02_diff_4k.jpg",  -- sand flats
	[4]  = ":a:" .. TEXDIR .. "sandy_gravel_02_nor_gl_2k.jpg",
	[5]  = ":a:" .. TEXDIR .. "sandy_gravel_02_arm_2k.jpg",
	[6]  = ":a:" .. TEXDIR .. "gravelly_sand_diff_4k.jpg",    -- gravel/talus
	[7]  = ":a:" .. TEXDIR .. "gravelly_sand_nor_gl_2k.jpg",
	[8]  = ":a:" .. TEXDIR .. "gravelly_sand_arm_2k.jpg",
	[9]  = ":a:" .. TEXDIR .. "cliff_side_diff_4k.jpg",       -- cliff walls (biplanar)
	[10] = CLIFF_NORM_DEFAULT,
	[11] = ":a:" .. TEXDIR .. "cliff_side_arm_2k.jpg",
	[12] = ":a:" .. TEXDIR .. "tiger_rock_diff_4k.jpg",       -- striated plateau tops
	[13] = ":a:" .. TEXDIR .. "tiger_rock_nor_gl_2k.jpg",
	[14] = ":a:" .. TEXDIR .. "tiger_rock_arm_2k.jpg",
	[16] = "$shadow_color",
	[17] = "$info",
	[18] = CLIFF_NORM_CHUNKY,                                 -- foothills chunky normal (diff/ARM shared with cliff)
	[19] = ":a:" .. TEXDIR .. "abstract_stagger_mask.png",    -- the reference's height-lerp stagger mask
	[20] = "$ssmf_splat_distr",                               -- terraform brush splat paint (RGBA)
}

local function nextPow2(n)
	local p = 1
	while p < n do p = p * 2 end
	return p
end

local function getWaterColor(key, dr, dg, db)
	local ok, r, g, b = pcall(gl.GetWaterRendering, key)
	if ok and r then return r, g, b end
	return dr, dg, db
end

local function makeShader(mainChunk, label, vertSrc)
	local pwr2x = nextPow2(Game.mapSizeX / 8)
	local pwr2z = nextPow2(Game.mapSizeZ / 8)
	local wminR, wminG, wminB = getWaterColor("minColor", 0.1, 0.2, 0.3)
	local wbasR, wbasG, wbasB = getWaterColor("baseColor", 0.4, 0.7, 0.8)
	local wabsR, wabsG, wabsB = getWaterColor("absorb", 0.004, 0.003, 0.002)

	local shader = gl.CreateShader({
		vertex   = vertSrc or VERT_SRC,
		fragment = GLSL_COMMON .. mainChunk,
		uniformInt = {
			diffuseTex = 0, heightMapTex = 1, normalsTex = 2,
			soilDiff = 3, soilNorm = 4, soilArm = 5,
			rockyDiff = 6, rockyNorm = 7, rockyArm = 8,
			cliffDiff = 9, cliffNorm = 10, cliffArm = 11,
			platDiff = 12, platNorm = 13, platArm = 14,
			shadowTex = 15, shadowColorTex = 16, infoTex = 17,
			footNorm = 18, staggerTex = 19, splatDistrTex = 20,
			waterEnabled = waterEnabled,
			footEnabled = footEnabled,
			staggerEnabled = staggerEnabled,
		},
		uniformFloat = {
			specularTexGen = { 1.0 / Game.mapSizeX, 1.0 / Game.mapSizeZ },
			infoTexGen = { 1.0 / (pwr2x * 8), 1.0 / (pwr2z * 8) },
			waterMinColor = { wminR, wminG, wminB },
			waterBaseColor = { wbasR, wbasG, wbasB },
			waterAbsorbColor = { wabsR, wabsG, wabsB },
		},
	})
	if not shader then
		Spring.Echo("[TilesetTerrain] " .. label .. " shader compile FAILED:")
		Spring.Echo(gl.GetShaderLog())
	end
	return shader
end

local UNIFORM_NAMES = {
	"mapHeights", "sunDir", "sunAmbient", "sunDiffuse", "cameraPos",
	"shadowMat", "groundShadowDensity", "shadowsEnabled",
	"infoTexEnabled", "infoTexIntensityMul", "biomeTint",
	"soilTint", "rockyTint", "cliffTint", "platTint",
	"pixelFootprint", "oldCliffGain",
}

local function cacheUniforms(shader, tbl)
	for _, name in ipairs(UNIFORM_NAMES) do
		tbl[name] = gl.GetUniformLocation(shader, name)
	end
	for key in pairs(knobs) do
		if not KNOB_LUA[key] then
			tbl[key] = gl.GetUniformLocation(shader, key)
		end
	end
end

local function setUniforms(uniforms)
	local minH, maxH = Spring.GetGroundExtremes()
	gl.Uniform(uniforms.mapHeights, minH, maxH)
	local sx, sy, sz = gl.GetSun("pos")
	gl.Uniform(uniforms.sunDir, sx, sy, sz)
	local ar, ag, ab = gl.GetSun("ambient", "ground")
	gl.Uniform(uniforms.sunAmbient, ar, ag, ab)
	local dr, dg, db = gl.GetSun("diffuse", "ground")
	gl.Uniform(uniforms.sunDiffuse, dr, dg, db)
	local cx, cy, cz = Spring.GetCameraPosition()
	gl.Uniform(uniforms.cameraPos, cx, cy, cz)

	-- pixel cone angle for the analytic (tessellation-blind) sampling footprint
	local _, vsy = gl.GetViewSizes()
	local fov = Spring.GetCameraFOV() or 45
	gl.Uniform(uniforms.pixelFootprint, 2.0 * math.tan(math.rad(fov * 0.5)) / math.max(1, vsy or 1))

	local haveShadows = Spring.HaveShadows()
	gl.UniformInt(uniforms.shadowsEnabled, haveShadows and 1 or 0)
	if haveShadows then
		gl.UniformMatrix(uniforms.shadowMat, "shadow")
		gl.Uniform(uniforms.groundShadowDensity, gl.GetSun("shadowDensity", "ground") or 1.0)
	end

	local drawMode = Spring.GetMapDrawMode()
	local infoOn = (drawMode ~= nil and drawMode ~= "normal")
	gl.UniformInt(uniforms.infoTexEnabled, infoOn and 1 or 0)
	if infoOn then
		gl.Uniform(uniforms.infoTexIntensityMul, (drawMode == "metal") and 2.0 or 1.0)
	end

	for key, value in pairs(knobs) do
		if not KNOB_LUA[key] then
			if KNOB_INT[key] then
				gl.UniformInt(uniforms[key], value)
			else
				gl.Uniform(uniforms[key], value)
			end
		end
	end
	gl.Uniform(uniforms.biomeTint, knobs.tintR, knobs.tintG, knobs.tintB)
	gl.Uniform(uniforms.soilTint,  knobs.soilTintR,  knobs.soilTintG,  knobs.soilTintB)
	gl.Uniform(uniforms.rockyTint, knobs.rockyTintR, knobs.rockyTintG, knobs.rockyTintB)
	gl.Uniform(uniforms.cliffTint, knobs.cliffTintR, knobs.cliffTintG, knobs.cliffTintB)
	gl.Uniform(uniforms.platTint,  knobs.platTintR,  knobs.platTintG,  knobs.platTintB)
	gl.Uniform(uniforms.oldCliffGain, paletteGain[1], paletteGain[2], paletteGain[3])
end

local function bindCommon(shader, uniforms)
	LAYER_TEXTURES[10] = (knobs.chunkyCliff >= 1) and CLIFF_NORM_CHUNKY or CLIFF_NORM_DEFAULT
	gl.Texture(1, "$heightmap")
	gl.Texture(2, "$normals")
	gl.Texture(15, "$shadow")
	for unit, tex in pairs(LAYER_TEXTURES) do
		gl.Texture(unit, tex)
	end
	-- the engine already bound this program (EnableRaw) before the callin;
	-- gl.ActiveShader restores the previous binding instead of unbinding to 0
	gl.ActiveShader(shader, setUniforms, uniforms)
end

local function unbindCommon()
	for unit = 1, 20 do
		gl.Texture(unit, false)
	end
	gl.Texture(0, false)
end

-- re-run the composite top-down into mmTex; bound once to $minimap + $grass so
-- re-rendering the same texture id refreshes both without rebinding
local function renderMinimapComposite()
	if not (mmShader and mmTex) then
		return
	end
	gl.RenderToTexture(mmTex, function()
		-- the ground drawer leaves GL_CULL_FACE on; without disabling it the
		-- fullscreen quad is back-face culled and the texture stays black
		gl.Culling(false)
		gl.DepthTest(false)
		gl.DepthMask(false)
		-- DIAGNOSTIC: if the minimap shows this dim magenta, RenderToTexture ran
		-- but the composite quad drew nothing; if it stays black, DrawGenesis is
		-- not firing / the RTT is not executing at all
		gl.Clear(GL.COLOR_BUFFER_BIT, 0.15, 0.0, 0.15, 1.0)
		gl.MatrixMode(GL.PROJECTION); gl.PushMatrix(); gl.LoadIdentity()
		gl.MatrixMode(GL.MODELVIEW);  gl.PushMatrix(); gl.LoadIdentity()

		gl.UseShader(mmShader)
		if origMapTex then
			gl.Texture(0, origMapTex)   -- old-map blend reference for the top-down pass
		end
		gl.Texture(1, "$heightmap")
		gl.Texture(2, "$normals")
		LAYER_TEXTURES[10] = (knobs.chunkyCliff >= 1) and CLIFF_NORM_CHUNKY or CLIFF_NORM_DEFAULT
		for unit, tex in pairs(LAYER_TEXTURES) do
			gl.Texture(unit, tex)
		end

		setUniforms(mmUniforms)
		-- override the view for a near-orthographic top-down sample: camera far
		-- above map centre so every column looks ~straight down, footprint set
		-- to one output texel so mip selection matches the minimap resolution
		local cx, cz = Game.mapSizeX * 0.5, Game.mapSizeZ * 0.5
		gl.Uniform(mmUniforms.cameraPos, cx, 1.0e6, cz)
		local worldTexel = math.max(Game.mapSizeX, Game.mapSizeZ) / MM_RES
		gl.Uniform(mmUniforms.pixelFootprint, worldTexel / 1.0e6)

		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)

		gl.UseShader(0)
		for unit = 1, 20 do
			gl.Texture(unit, false)
		end
		gl.Texture(0, false)

		gl.PopMatrix()
		gl.MatrixMode(GL.PROJECTION); gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
	end)
	gl.Culling(true)
	gl.DepthTest(true)

	if not mmRenderedOnce then
		mmRenderedOnce = true
		Spring.Echo("[TilesetTerrain] minimap+grass composite rendered (" .. MM_RES .. "x" .. MM_RES .. ")")
	end
end

-- snapshot the original minimap + terrain shape, reduce to the old map's cliff
-- palette, and turn it into the constant recolor gain; re-runnable at any time
-- because it only reads widget-owned snapshots (plus $minimap, un-overridden
-- for the duration of the copy)
local function runPaletteExtraction()
	-- while the composite override is bound, "$minimap" resolves to our own
	-- texture; revert, copy the map's original, then restore
	local restoreOverride = mmEnabled and mmTex ~= nil
	if restoreOverride then
		Spring.SetMapShadingTexture("$minimap", "")
	end
	gl.RenderToTexture(origMapTex, function()
		gl.Blending(false)
		gl.Culling(false)
		gl.DepthTest(false)
		gl.DepthMask(false)
		gl.MatrixMode(GL.PROJECTION); gl.PushMatrix(); gl.LoadIdentity()
		gl.MatrixMode(GL.MODELVIEW);  gl.PushMatrix(); gl.LoadIdentity()
		gl.Texture(0, "$minimap")
		-- explicit texcoords: TexRect's defaults V-flip, which would pair the
		-- reduction's slope taps with mirrored colors
		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		gl.Texture(0, false)
		gl.PopMatrix()
		gl.MatrixMode(GL.PROJECTION); gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
	end)
	if restoreOverride then
		Spring.SetMapShadingTexture("$minimap", mmTex)
	end
	if gl.GenerateMipmap then
		gl.GenerateMipmap(origMapTex)   -- the reduction area-averages via lod 3
	end

	gl.RenderToTexture(origTerrainTex, function()
		gl.Blending(false)
		gl.Culling(false)
		gl.DepthTest(false)
		gl.DepthMask(false)
		gl.MatrixMode(GL.PROJECTION); gl.PushMatrix(); gl.LoadIdentity()
		gl.MatrixMode(GL.MODELVIEW);  gl.PushMatrix(); gl.LoadIdentity()
		gl.UseShader(snapShader)
		gl.Texture(0, "$normals")
		gl.Texture(1, "$heightmap")
		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		gl.Texture(0, false)
		gl.Texture(1, false)
		gl.UseShader(0)
		gl.PopMatrix()
		gl.MatrixMode(GL.PROJECTION); gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
	end)

	local px
	gl.RenderToTexture(paletteTex, function()
		gl.Blending(false)
		gl.Culling(false)
		gl.DepthTest(false)
		gl.DepthMask(false)
		gl.MatrixMode(GL.PROJECTION); gl.PushMatrix(); gl.LoadIdentity()
		gl.MatrixMode(GL.MODELVIEW);  gl.PushMatrix(); gl.LoadIdentity()
		gl.UseShader(reduceShader)
		gl.Uniform(reduceCliffLoLoc, 1.0 - math.cos(math.rad(knobs.cliffStartDeg)))
		gl.Texture(0, origMapTex)
		gl.Texture(1, origTerrainTex)
		gl.Texture(2, LAYER_TEXTURES[9])
		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		gl.Texture(0, false)
		gl.Texture(1, false)
		gl.Texture(2, false)
		gl.UseShader(0)
		px = gl.ReadPixels(0, 0, 3, 1)   -- reads the RTT target we just wrote
		gl.PopMatrix()
		gl.MatrixMode(GL.PROJECTION); gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
	end)
	gl.Blending(true)
	gl.Culling(true)
	gl.DepthTest(true)

	paletteGain = { 1.0, 1.0, 1.0 }
	local cliff = px and px[1]
	local flat  = px and px[2]
	local mean  = px and px[3]
	-- need a meaningful amount of original cliff area, else keep gain neutral
	-- (a cliff-less map then degrades to plain tileset cliffs, no smearing)
	if cliff and flat and mean and cliff[4] and cliff[4] >= 0.005 then
		for c = 1, 3 do
			paletteGain[c] = math.min(4.0, math.max(0.2, cliff[c] / math.max(mean[c], 0.02)))
		end
		paletteInfo = string.format(
			"orig cliff (%.2f %.2f %.2f, %.1f%% of land) | orig flat (%.2f %.2f %.2f) | tileset cliff mean (%.2f %.2f %.2f) | gain %.2f %.2f %.2f",
			cliff[1], cliff[2], cliff[3], cliff[4] * 100, flat[1], flat[2], flat[3],
			mean[1], mean[2], mean[3], paletteGain[1], paletteGain[2], paletteGain[3])
	else
		paletteInfo = string.format(
			"no usable original cliffs (%.2f%% of land steep) — cliff recolor neutral",
			((cliff and cliff[4]) or 0) * 100)
	end
	Spring.Echo("[TilesetTerrain] old-map palette: " .. paletteInfo)
	mmDirty = true
end

--------------------------------------------------------------------------------
-- tuning panel (RmlUi, pattern lifted from the terraform suite)
--------------------------------------------------------------------------------

local MODEL_NAME = "tileset_knobs"
local RML_PATH = "LuaUI/Widgets/tileset_dev/tileset_panel.rml"

local panel = { shown = true }
local rmlContext, document

local function refreshNumbox(key)
	if not document then
		return
	end
	local el = document:GetElementById("nb-" .. key)
	if el then
		el.inner_rml = string.format(SLIDER_BY_KEY[key].fmt, knobs[key])
	end
end

local function dumpKnobs()
	Spring.Echo("[TilesetTerrain] current knobs:")
	for _, s in ipairs(SLIDERS) do
		Spring.Echo(string.format("	%s = %s,", s.key, string.format(s.fmt, knobs[s.key])))
	end
end

local syncPanelFromKnobs -- defined below, needed by onReset

local dataModel = {
	onKnob = function(ev, key)
		local v = tonumber(ev.parameters and ev.parameters.value)
		local s = SLIDER_BY_KEY[key]
		if v and s then
			if s.int then
				v = math.floor(v + 0.5)
			end
			knobs[key] = v
			refreshNumbox(key)
			mmDirty = true   -- keep the minimap/grass composite in sync with tuning
			if key == "cliffStartDeg" then
				paletteDirty = true   -- "what counts as a cliff" feeds the palette mask
			end
		end
	end,
	onClose = function()
		panel.shown = false
		if document then
			document:Hide()
		end
	end,
	onReset = function()
		for k, v in pairs(DEFAULT_KNOBS) do
			knobs[k] = v
		end
		syncPanelFromKnobs()
		mmDirty = true
		Spring.Echo("[TilesetTerrain] knobs reset to defaults")
	end,
}

syncPanelFromKnobs = function()
	if not document then
		return
	end
	for key in pairs(SLIDER_BY_KEY) do
		local sl = document:GetElementById("sl-" .. key)
		if sl then
			sl:SetAttribute("value", tostring(knobs[key]))
		end
		refreshNumbox(key)
	end
end

local function initPanel()
	if not RmlUi then
		Spring.Echo("[TilesetTerrain] RmlUi not available, no tuning panel")
		return
	end
	rmlContext = RmlUi.GetContext("shared") or RmlUi.CreateContext("shared")
	rmlContext:OpenDataModel(MODEL_NAME, dataModel, widget)
	document = rmlContext:LoadDocument(RML_PATH)
	if not document then
		Spring.Echo("[TilesetTerrain] tuning panel document failed to load: " .. RML_PATH)
		return
	end
	syncPanelFromKnobs()
	if panel.shown then
		document:Show()
	end
end

local function shutdownPanel()
	if document then
		document:Close()
		document = nil
	end
	if rmlContext then
		pcall(function() rmlContext:RemoveDataModel(MODEL_NAME) end)
		rmlContext = nil
	end
end

local function tilesetAction(_, line, words)
	local arg = (type(words) == "table") and words[1] or nil
	if arg == "dump" then
		dumpKnobs()
	elseif arg == "chunky" then
		knobs.chunkyCliff = (knobs.chunkyCliff >= 1) and 0 or 1
		syncPanelFromKnobs()
		mmDirty = true
		Spring.Echo("[TilesetTerrain] cliff normal: " .. ((knobs.chunkyCliff >= 1) and "CHUNKY quarry" or "namaqualand cliff_side"))
	elseif arg == "splat" then
		knobs.splatInfluence = (knobs.splatInfluence > 0.0) and 0.0 or 1.0
		syncPanelFromKnobs()
		mmDirty = true
		Spring.Echo("[TilesetTerrain] splat paint " .. ((knobs.splatInfluence > 0.0) and "ON (G/B/A force talus/cliff/plateau)" or "OFF"))
	elseif arg == "palette" then
		paletteDirty = true
		paletteLastRun = nil
		Spring.Echo("[TilesetTerrain] old-map palette re-extraction queued"
			.. (paletteInfo and (" | last: " .. paletteInfo) or ""))
	elseif arg == "minimap" then
		mmEnabled = not mmEnabled
		if mmEnabled then
			mmDirty = true
			if mmTex then
				Spring.SetMapShadingTexture("$minimap", mmTex)
				Spring.SetMapShadingTexture("$grass", mmTex)
			end
		else
			Spring.SetMapShadingTexture("$minimap", "")
			Spring.SetMapShadingTexture("$grass", "")
		end
		Spring.Echo("[TilesetTerrain] minimap+grass composite " .. (mmEnabled and "ON" or "OFF (engine default)"))
	elseif arg == "mat" then
		local m = { gl.GetMatrixData("shadow") }
		if #m == 16 then
			Spring.Echo("[TilesetTerrain] shadow matrix (column-major):")
			for c = 0, 3 do
				Spring.Echo(string.format("	col%d: %+.6f %+.6f %+.6f %+.6f", c, m[c*4+1], m[c*4+2], m[c*4+3], m[c*4+4]))
			end
			-- world-space extent that maps to shadow UV [0,1] (diag scale approx)
			if m[1] ~= 0 and m[6] ~= 0 then
				Spring.Echo(string.format("	=> approx world extent covered: x=%.0f y=%.0f elmos", math.abs(1.0 / m[1]), math.abs(1.0 / m[6])))
			end
		else
			Spring.Echo("[TilesetTerrain] gl.GetMatrixData('shadow') returned " .. tostring(#m) .. " values")
		end
		local cx, cy, cz = Spring.GetCameraPosition()
		Spring.Echo(string.format("	camera: %.0f %.0f %.0f | map %dx%d | HaveShadows=%s", cx, cy, cz, Game.mapSizeX, Game.mapSizeZ, tostring(Spring.HaveShadows())))
	else
		panel.shown = not panel.shown
		if document then
			if panel.shown then
				syncPanelFromKnobs()
				document:Show()
			else
				document:Hide()
			end
		end
		Spring.Echo("[TilesetTerrain] tuning panel " .. (panel.shown and "shown" or "hidden"))
	end
	return true
end

-- fallback path for handlers that route unknown slash commands here instead
function widget:TextCommand(command)
	if command == "tileset" or command:sub(1, 8) == "tileset " then
		tilesetAction(nil, command, { command:match("^tileset%s+(%S+)$") })
		return true
	end
	return false
end

function widget:GetConfigData()
	return { version = CONFIG_VERSION, knobs = knobs, shown = panel.shown }
end

function widget:SetConfigData(data)
	if type(data) == "table" then
		if data.version ~= CONFIG_VERSION then
			return
		end
		if type(data.knobs) == "table" then
			for k, v in pairs(data.knobs) do
				if knobs[k] ~= nil and type(v) == "number" then
					knobs[k] = v
				end
			end
		end
		if data.shown ~= nil then
			panel.shown = data.shown
		end
	end
end

--------------------------------------------------------------------------------

function widget:Initialize()
	if not gl.CreateShader then
		widgetHandler:RemoveWidget(self)
		return
	end

	-- the fixes in RecoilEngine PR #3127 are behavioral, so this flag is the only
	-- reliable signal; without them the forward shader never activates and program
	-- swaps corrupt terrain
	if not (Engine.FeatureSupport and Engine.FeatureSupport.reliableLuaMapShaders) then
		Spring.Echo("[TilesetTerrain] this engine cannot run Lua map shaders reliably (needs RecoilEngine PR #3127) — widget disabled")
		widgetHandler:RemoveWidget(self)
		return
	end

	local probe = gl.TextureInfo(LAYER_TEXTURES[3])
	if not (probe and probe.xsize and probe.xsize > 0) then
		Spring.Echo("[TilesetTerrain] layer textures not found — see LuaUI/Widgets/tileset_dev/README.md for the download list — widget disabled")
		widgetHandler:RemoveWidget(self)
		return
	end

	local minH = Spring.GetGroundExtremes()
	waterEnabled = (minH < 0) and 1 or 0

	-- graceful degrade: without the chunky normal the foothills band would be
	-- an invisible cliff-albedo extension, so disable it outright
	local ti = gl.TextureInfo(CLIFF_NORM_CHUNKY)
	if not (ti and ti.xsize and ti.xsize > 0) then
		footEnabled = 0
		Spring.Echo("[TilesetTerrain] WARNING: " .. CLIFF_NORM_CHUNKY .. " failed to load — foothills layer disabled")
	end
	local si = gl.TextureInfo(LAYER_TEXTURES[19])
	if not (si and si.xsize and si.xsize > 0) then
		staggerEnabled = 0
		Spring.Echo("[TilesetTerrain] WARNING: " .. LAYER_TEXTURES[19] .. " failed to load — stagger disabled (neutral 0.5)")
	end

	fwdShader = makeShader(GLSL_FWD_MAIN, "forward")
	dfrShader = makeShader(GLSL_DFR_MAIN, "deferred")

	if not fwdShader then
		widgetHandler:RemoveWidget(self)
		return
	end

	cacheUniforms(fwdShader, fwdUniforms)
	if dfrShader then
		cacheUniforms(dfrShader, dfrUniforms)
	end

	Spring.SetMapShader(fwdShader, dfrShader or 0)

	-- minimap + grass tint: one top-down composite bound to both map textures
	mmShader = makeShader(GLSL_MM_MAIN, "minimap", VERT_MM)
	if mmShader then
		cacheUniforms(mmShader, mmUniforms)
		mmTex = gl.CreateTexture(MM_RES, MM_RES, {
			target = GL.TEXTURE_2D, format = GL.RGBA8,
			min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		})
		if mmTex then
			Spring.SetMapShadingTexture("$minimap", mmTex)
			Spring.SetMapShadingTexture("$grass", mmTex)
			mmDirty = true
		else
			Spring.Echo("[TilesetTerrain] minimap/grass composite texture alloc failed")
		end
	end

	-- old-map palette extraction resources (runs in the first DrawGenesis)
	snapShader = gl.CreateShader({
		vertex = VERT_SNAP,
		fragment = FRAG_SNAP_TERRAIN,
		uniformInt = { normalsSnap = 0, heightSnap = 1 },
	})
	reduceShader = gl.CreateShader({
		vertex = VERT_SNAP,
		fragment = FRAG_REDUCE:gsub("#version 130", "#version 130\n#define WATER_MAP " .. waterEnabled),
		uniformInt = { origMap = 0, origTerrain = 1, cliffDiffT = 2 },
	})
	if snapShader and reduceShader then
		reduceCliffLoLoc = gl.GetUniformLocation(reduceShader, "cliffLo")
		local mipOK = (gl.GenerateMipmap ~= nil)
		origMapTex = gl.CreateTexture(PALETTE_RES, PALETTE_RES, {
			target = GL.TEXTURE_2D, format = GL.RGBA8,
			min_filter = mipOK and GL.LINEAR_MIPMAP_LINEAR or GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		})
		origTerrainTex = gl.CreateTexture(PALETTE_RES, PALETTE_RES, {
			target = GL.TEXTURE_2D, format = GL.RGBA16F,
			min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		})
		paletteTex = gl.CreateTexture(3, 1, {
			target = GL.TEXTURE_2D, format = GL.RGBA32F,
			min_filter = GL.NEAREST, mag_filter = GL.NEAREST,
			wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		})
	end
	if not (snapShader and reduceShader and origMapTex and origTerrainTex and paletteTex) then
		paletteDirty = false
		Spring.Echo("[TilesetTerrain] WARNING: old-map palette extraction unavailable — cliff recolor stays neutral")
		if not reduceShader then
			Spring.Echo(gl.GetShaderLog())
		end
	end

	widgetHandler:AddAction("tileset", tilesetAction, nil, "t")
	initPanel()
	Spring.Echo("[TilesetTerrain] P2.8 two-phase sort installed — /tileset panel, /tileset chunky swaps the cliff normal, /tileset minimap toggles the minimap+grass composite")
end

function widget:DrawGenesis()
	-- DrawGenesis is the RTT-safe callin (outside the ground pass), so UseShader
	-- resets here are harmless; regenerate the composite only when dirty
	-- palette first so the composite below picks up a fresh gain; throttled
	-- because ReadPixels forces a pipeline sync (slider drags queue many marks)
	if paletteDirty and reduceShader and origMapTex and origTerrainTex and paletteTex then
		local now = Spring.GetTimer()
		if (not paletteLastRun) or Spring.DiffTimers(now, paletteLastRun) > 0.4 then
			runPaletteExtraction()
			paletteLastRun = now
			paletteDirty = false
		end
	end
	if mmEnabled and mmDirty then
		renderMinimapComposite()
		mmDirty = false
	end
end

function widget:UnsyncedHeightMapUpdate()
	mmDirty = true   -- terraform changed slope/height → composite is stale
end

function widget:DrawGroundPreForward()
	bindCommon(fwdShader, fwdUniforms)
end

function widget:DrawGroundPostForward()
	unbindCommon()
end

function widget:DrawGroundPreDeferred()
	if dfrShader then
		bindCommon(dfrShader, dfrUniforms)
	end
end

function widget:DrawGroundPostDeferred()
	if dfrShader then
		unbindCommon()
	end
end

function widget:Shutdown()
	pcall(function() widgetHandler:RemoveAction("tileset", "t") end)
	shutdownPanel()
	Spring.SetMapShader(0, 0)
	-- empty name reverts $minimap/$grass to the map's own textures
	Spring.SetMapShadingTexture("$minimap", "")
	Spring.SetMapShadingTexture("$grass", "")
	if mmTex then gl.DeleteTexture(mmTex) end
	if origMapTex then gl.DeleteTexture(origMapTex) end
	if origTerrainTex then gl.DeleteTexture(origTerrainTex) end
	if paletteTex then gl.DeleteTexture(paletteTex) end
	if fwdShader then gl.DeleteShader(fwdShader) end
	if dfrShader then gl.DeleteShader(dfrShader) end
	if mmShader then gl.DeleteShader(mmShader) end
	if snapShader then gl.DeleteShader(snapShader) end
	if reduceShader then gl.DeleteShader(reduceShader) end
	Spring.Echo("[TilesetTerrain] map shader reset to engine default")
end
