#version 150 compatibility

#define DEPTH_CLIP01 ###DEPTH_CLIP01###
#define MAX_POINTS ###MAX_POINTS###

uniform sampler2D mapDepthTex;
uniform sampler2D modelsDepthTex;
uniform sampler2D airLosTex;

uniform int effects;

uniform vec4 color1;
uniform vec4 color2;

#if 1
	uniform mat4 projMat;
#else
	#define projMat gl_ProjectionMatrix
#endif

uniform float gameFrame;

uniform vec4 translationScale;
uniform float mapSizeX;
uniform float mapSizeZ;
uniform float enemyLOSClip;
uniform float enemyLOSAlpha; // per-unit smooth fade [0..1], lerped on CPU each render frame

// 0..1 fade-in/out driven by gadget when shield turns on/depletes
uniform float shieldFade;
uniform float overlapScale; // [0..1] dims when overlapping other shields

// Art-tweakable parameters – driven by gui_shield_editor widget via WG.ShieldEditorParams
uniform float uMaxAlpha;
uniform float uBlueTintR;
uniform float uBlueTintG;
uniform float uBlueTintB;
uniform float uRimSharpness;
uniform float uRimAlpha;
uniform float uRimColorGain;
uniform float uChromaSplit;
uniform float uBloomStrength;
uniform float uBloomAlpha;
uniform float uHexScale;
uniform float uHexOpacity;
uniform float uHexFireProb;
uniform float uHexFireGain;
uniform float uRefractSplit;
uniform float uRefractRimAmp;
uniform float uHexTintR;
uniform float uHexTintG;
uniform float uHexTintB;
uniform float uFlowScale;
uniform float uFlowSpeed;
uniform float uFlowIntensity;
uniform float uImpactWaveSpeed;
uniform float uImpactWaveStrength;
uniform float uBreathSpeed;
uniform float uArcBurstFreq;
uniform float uArcBurstGain;
uniform float uRotYSpeed;
uniform float uRotZSpeed;
uniform float uZoomNear;
uniform float uZoomFar;
uniform float uZoomMinMult;
uniform float uZoomCurve;

struct ImpactInfo {
	int count;
	vec4 impactInfoArray[MAX_POINTS];
};
uniform ImpactInfo impactInfo;

in Data {
	vec4 modelPos;
	vec4 worldPos;
	vec4 viewPos;

	float colormix;
	float normalizedFragDepth;

	noperspective vec2 v_screenUV;
};

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)


//Lua limitations only allow to send 24 bits. Should be enough :)
#define BITMASK_FIELD(value, pos) ((uint(value) & (1u << uint(pos))) != 0u)

float GetViewSpaceDepth(float depthNDC) {
	return -projMat[3][2] / (projMat[2][2] + depthNDC);
}

mat4 CalculateLookAtMatrix(vec3 eye, vec3 center, vec3 up) {
	vec3 zaxis = normalize(center - eye); //from center towards eye vector
	vec3 xaxis = normalize(cross(zaxis, up));
	vec3 yaxis = cross(xaxis, zaxis);

	mat4 lookAtMatrix;

	lookAtMatrix[0] = vec4(xaxis.x, yaxis.x, zaxis.x, 0.0);
	lookAtMatrix[1] = vec4(xaxis.y, yaxis.y, zaxis.y, 0.0);
	lookAtMatrix[2] = vec4(xaxis.z, yaxis.z, zaxis.z, 0.0);
	lookAtMatrix[3] = vec4(dot(xaxis, -eye), dot(yaxis, -eye), dot(zaxis, -eye), 1.0);

	return lookAtMatrix;
}

mat4 CalculateLookAtMatrix(vec3 eye, vec3 center, float roll) {
	return CalculateLookAtMatrix(eye, center, vec3(sin(roll), cos(roll), 0.0));
}

float Value3D( vec3 P ) {
	vec3 Pi = floor(P);
	vec3 Pf = P - Pi;
	vec3 Pf_min1 = Pf - 1.0;

	Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
	vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

	vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
	Pt *= Pt;
	Pt = Pt.xzxz * Pt.yyww;
	vec2 hash_mod = vec2( 1.0 / ( 635.298681 + vec2( Pi.z, Pi_inc1.z ) * 48.500388 ) );
	vec4 hash_lowz = fract( Pt * hash_mod.xxxx );
	vec4 hash_highz = fract( Pt * hash_mod.yyyy );

	vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
	vec4 res0 = mix( hash_lowz, hash_highz, blend.z );
	vec4 blend2 = vec4( blend.xy, vec2( 1.0 - blend.xy ) );
	return dot( res0, blend2.zxzx * blend2.wwyy );
}

float SimplexPerlin3D( vec3 P ) {
    const float SKEWFACTOR = 1.0/3.0;
    const float UNSKEWFACTOR = 1.0/6.0;
    const float SIMPLEX_CORNER_POS = 0.5;
    const float SIMPLEX_TETRAHADRON_HEIGHT = 0.70710678118654752440084436210485;

    P *= SIMPLEX_TETRAHADRON_HEIGHT;
    vec3 Pi = floor( P + dot( P, vec3( SKEWFACTOR) ) );

    vec3 x0 = P - Pi + dot(Pi, vec3( UNSKEWFACTOR ) );
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 Pi_1 = min( g.xyz, l.zxy );
    vec3 Pi_2 = max( g.xyz, l.zxy );
    vec3 x1 = x0 - Pi_1 + UNSKEWFACTOR;
    vec3 x2 = x0 - Pi_2 + SKEWFACTOR;
    vec3 x3 = x0 - SIMPLEX_CORNER_POS;

    vec4 v1234_x = vec4( x0.x, x1.x, x2.x, x3.x );
    vec4 v1234_y = vec4( x0.y, x1.y, x2.y, x3.y );
    vec4 v1234_z = vec4( x0.z, x1.z, x2.z, x3.z );

    Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
    vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

    vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
    Pt *= Pt;
    vec4 V1xy_V2xy = mix( Pt.xyxy, Pt.zwzw, vec4( Pi_1.xy, Pi_2.xy ) );
    Pt = vec4( Pt.x, V1xy_V2xy.xz, Pt.z ) * vec4( Pt.y, V1xy_V2xy.yw, Pt.w );
    const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
    const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
    vec3 lowz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi.zzz * ZINC.xyz ) );
    vec3 highz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi_inc1.zzz * ZINC.xyz ) );
    Pi_1 = ( Pi_1.z < 0.5 ) ? lowz_mods : highz_mods;
    Pi_2 = ( Pi_2.z < 0.5 ) ? lowz_mods : highz_mods;
    vec4 hash_0 = fract( Pt * vec4( lowz_mods.x, Pi_1.x, Pi_2.x, highz_mods.x ) ) - 0.49999;
    vec4 hash_1 = fract( Pt * vec4( lowz_mods.y, Pi_1.y, Pi_2.y, highz_mods.y ) ) - 0.49999;
    vec4 hash_2 = fract( Pt * vec4( lowz_mods.z, Pi_1.z, Pi_2.z, highz_mods.z ) ) - 0.49999;

    vec4 grad_results = inversesqrt( hash_0 * hash_0 + hash_1 * hash_1 + hash_2 * hash_2 ) * ( hash_0 * v1234_x + hash_1 * v1234_y + hash_2 * v1234_z );

    const float FINAL_NORMALIZATION = 37.837227241611314102871574478976;

    vec4 kernel_weights = v1234_x * v1234_x + v1234_y * v1234_y + v1234_z * v1234_z;
    kernel_weights = max(0.5 - kernel_weights, 0.0);
    kernel_weights = kernel_weights*kernel_weights*kernel_weights;

    return dot( kernel_weights, grad_results ) * FINAL_NORMALIZATION;
}

// Hex grid on sphere: returns ~1 on cell edges, 0 inside.
float ShieldHexPattern(vec2 p, float hexScale, float edgeWidth) {
	p *= hexScale;
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 hC = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h  = vec4(p - hC.xy * s, p - (hC.zw + 0.5) * s);
	vec2 cell = (dot(h.xy, h.xy) < dot(h.zw, h.zw)) ? h.xy : h.zw;
	cell = abs(cell);
	float d = max(dot(cell, s * 0.5), cell.x);
	return smoothstep(0.5 - edgeWidth, 0.5, d);
}

// Per-cell id for independent flicker.
vec2 ShieldHexCellId(vec2 p, float hexScale) {
	p *= hexScale;
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 hC = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h  = vec4(p - hC.xy * s, p - (hC.zw + 0.5) * s);
	return (dot(h.xy, h.xy) < dot(h.zw, h.zw)) ? hC.xy : hC.zw + 0.5;
}

// Random per-cell flash.
float ShieldCellFlash(vec2 cellId, float time, float flashSpeed, float flashIntensity) {
	float rnd   = fract(sin(dot(cellId, vec2(127.1, 311.7))) * 43758.5453);
	float phase = rnd * 6.2831;
	float speed = 0.5 + rnd * 1.5;
	return smoothstep(0.6, 1.0, sin(time * flashSpeed * speed + phase)) * flashIntensity;
}

float Hexagon2D(vec2 p, float edge0, float edge1) {
	p.x *= 0.57735 * 2.0;
	p.y += mod(floor(p.x), 2.0) * 0.5;
	p = abs((mod(p, 1.0) - 0.5));
	float val = abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
	return smoothstep(edge0, edge1, val);
}

vec2 GetRippleOffset(vec3 thisPoint, vec3 impactPoint, float magMult) {
	vec2 dir = thisPoint.xy - impactPoint.xy;
	float dist = dot(thisPoint, impactPoint);
	vec2 offset = dir * SNORM2NORM( sin(-dist * 1024.0 + gameFrame * 0.5) ) * 1.0 * magMult;
	return offset;
}

const mat3 RGB2YCBCR = mat3(
	0.2126, -0.114572, 0.5,
	0.7152, -0.385428, -0.454153,
	0.0722, 0.5, -0.0458471);

const mat3 YCBCR2RGB = mat3(
	1.0, 1.0, 1.0,
	0.0, -0.187324, 1.8556,
	1.5748, -0.468124, -5.55112e-17);

const float PI = acos(0.0) * 2.0;
const float PI8 = PI * 8.0;

void main() {

	vec4 color;
	color = mix(color1, color2, colormix);

	// Rotate pattern-sampling position (Y-axis primary, Z-axis secondary tilt)
	float ROT_Y_SPEED = uRotYSpeed;
	float ROT_Z_SPEED = uRotZSpeed;
	float rmp_cy = cos(gameFrame * ROT_Y_SPEED), rmp_sy = sin(gameFrame * ROT_Y_SPEED);
	float rmp_cz = cos(gameFrame * ROT_Z_SPEED), rmp_sz = sin(gameFrame * ROT_Z_SPEED);
	vec3 rmp = vec3(
		rmp_cy * modelPos.x + rmp_sy * modelPos.z,
		modelPos.y,
		-rmp_sy * modelPos.x + rmp_cy * modelPos.z
	);
	rmp = vec3(
		rmp_cz * rmp.x - rmp_sz * rmp.y,
		rmp_sz * rmp.x + rmp_cz * rmp.y,
		rmp.z
	);

	// Contact effect accumulators, filled in the depth-intersection block below
	vec3  contactHotBoost = vec3(0.0);
	float contactHotAlpha = 0.0;

	// Weapon-impact feedback: filled in the effects-bit-3 block, consumed later by
	// the rim/hex block. An outward-traveling wavefront makes the hex cells near a
	// blocked shot flash brighter/more opaque and then fade as the energy spreads
	// across the dome.
	float impactHexBoost = 0.0; // local hex opacity/brightness flash (rides the wavefront)
	float impactWarp     = 0.0; // outward-traveling lattice distortion magnitude

	const float valueNoiseMovePace = 0.25;

	vec3 valueNoiseVec = rmp * translationScale.www;
	valueNoiseVec.y += gameFrame * valueNoiseMovePace;
	float valueNoise = Value3D(valueNoiseVec);

	if (BITMASK_FIELD(effects, 1) || BITMASK_FIELD(effects, 2)) {
		const float outlineEffectSize = 30.0;

		float minDepth = 1.0;
		if (BITMASK_FIELD(effects, 1)) { // terrain outline
			minDepth = min(minDepth, texture( mapDepthTex, v_screenUV ).r);
		}
		if (BITMASK_FIELD(effects, 2)) { // units outline
			minDepth = min(minDepth, texture( modelsDepthTex, v_screenUV ).r);
		}

		#if (DEPTH_CLIP01 == 1)
			// Nothing. NDC and window/texture space are same for depth
		#else
			minDepth = NORM2SNORM(minDepth);
		#endif

		float minDepthView = GetViewSpaceDepth( minDepth );
		float contactDist  = abs(viewPos.z - minDepthView);

		float outlineFactor = smoothstep( 0.0, contactDist, outlineEffectSize * valueNoise );
		outlineFactor *= mix(0.25, 1.0, SNORM2NORM(sin(0.1*gameFrame + 5.0*(rmp.x + rmp.z + rmp.y))));

		// Crackle noise along the contact edge
		const float OUTLINE_CRACKLE_SCALE  = 130.0;
		const float OUTLINE_CRACKLE_SPEED  = 0.110;
		const float OUTLINE_CRACKLE_AMOUNT = 0.25;
		vec3 outlineCrackleP = rmp * OUTLINE_CRACKLE_SCALE;
		outlineCrackleP.y -= gameFrame * OUTLINE_CRACKLE_SPEED;
		outlineCrackleP.x += gameFrame * OUTLINE_CRACKLE_SPEED * 0.37;
		float outlineCrackle = SNORM2NORM(SimplexPerlin3D(outlineCrackleP));
		outlineFactor *= mix(1.0 - OUTLINE_CRACKLE_AMOUNT, 1.0 + OUTLINE_CRACKLE_AMOUNT, outlineCrackle);
		outlineFactor = clamp(outlineFactor, 0.0, 1.0);

		// Contact intersection: ground light projection + scrolling rings + arc spikes
		const float CONTACT_INNER = 7.0;
		const float CONTACT_OUTER = 100.0;
		float contactCore = smoothstep(CONTACT_INNER * 2.2, 0.0, contactDist);
		float contactZone = smoothstep(CONTACT_OUTER, 0.0, contactDist);
		const float POOL_RADIUS = 55.0;
		float poolMask = smoothstep(POOL_RADIUS, 5.0, contactDist);

		// Scrolling ripple rings
		const float RING_SPACING = 16.0;
		const float RING_SPEED   = 0.018;
		const float RING_DUTY    = 0.14;
		float ringPhase = contactDist / RING_SPACING - gameFrame * RING_SPEED;
		float ringT     = fract(ringPhase);
		float ring      = smoothstep(0.0, RING_DUTY, ringT)
		                * smoothstep(RING_DUTY * 2.2, RING_DUTY, ringT);
		ring *= contactZone;
		const float RING2_SPACING = 7.0;
		const float RING2_SPEED   = 0.032;
		const float RING2_DUTY    = 0.10;
		float ring2T  = fract(contactDist / RING2_SPACING - gameFrame * RING2_SPEED);
		float ring2   = smoothstep(0.0, RING2_DUTY, ring2T)
		              * smoothstep(RING2_DUTY * 2.0, RING2_DUTY, ring2T);
		ring2 *= contactCore * 0.8;

		// Arc spikes at the seam edge
		vec3 arcNoiseP = rmp * 310.0;
		arcNoiseP.y -= gameFrame * 0.22;
		arcNoiseP.z += gameFrame * 0.09;
		float arcNoise2 = SNORM2NORM(SimplexPerlin3D(arcNoiseP));
		float arcSpike  = pow(max(outlineCrackle, 0.0), 3.5) * contactCore;
		float arcSpike2 = pow(max(arcNoise2, 0.0), 4.0) * contactCore * 1.6;
		float arc       = arcSpike + arcSpike2;

		// Charge-aware tint: teal (healthy) -> orange (damaged)
		float contactWarmness   = clamp(color1.r - color1.b * 0.8, 0.0, 1.0);
		const vec3 CONTACT_COOL = vec3(0.08, 1.05, 1.70);
		const vec3 CONTACT_WARM = vec3(1.60, 0.55, 0.05);
		vec3 contactTint = mix(CONTACT_COOL, CONTACT_WARM, contactWarmness);
		vec3 contactCoreColor = mix(contactTint, vec3(1.6, 2.0, 2.8), contactCore * 0.7);

		// Make shield transparent in the pool zone so ground shows through
		const float outlineAlpha = 0.45;
		color.a = mix(color.a, outlineAlpha * shieldFade, outlineFactor);
		color.a *= mix(1.0, 0.55, poolMask * shieldFade);

		// Post-tonemap: wide ambient pool + seam ring + rings + arcs
		contactHotBoost += contactTint * contactZone * 0.55 * shieldFade;
		contactHotAlpha += contactZone * 0.08 * shieldFade;
		// Bright seam ring and scrolling pulse rings
		contactHotBoost += contactCoreColor * contactCore * 1.60 * outlineFactor * shieldFade;
		contactHotBoost += contactTint * ring  * 1.20 * shieldFade;
		contactHotBoost += contactTint * ring2 * 1.60 * shieldFade;
		contactHotBoost += contactTint * arc   * 1.80 * shieldFade;
		contactHotAlpha += contactCore * 0.45 * outlineFactor * shieldFade;
		contactHotAlpha += ring  * 0.28 * shieldFade;
		contactHotAlpha += ring2 * 0.36 * shieldFade;
		contactHotAlpha += arc   * 0.32 * shieldFade;
	}

	if (BITMASK_FIELD(effects, 3)) { // weapon-impact feedback (blocked-shot reaction)
		vec3 worldVec = normalize(worldPos.xyz - translationScale.xyz);

		vec2 cameraDistanceFactors = vec2(1.0);
		if (BITMASK_FIELD(effects, 7)) { // impactScaleWithDistance
			cameraDistanceFactors = vec2(1.0 + 1.0 * normalizedFragDepth, 1.0 + 6.0 * normalizedFragDepth);
		}

		// Charge-aware tint, sharing the rim's teal(healthy)->orange(damaged) language
		float impactWarm = clamp(color1.r - color1.b * 0.8, 0.0, 1.0);
		const vec3 IMPACT_COOL = vec3(0.25, 1.15, 1.75);
		const vec3 IMPACT_WARM = vec3(1.80, 0.62, 0.12);
		vec3 impactTint = mix(IMPACT_COOL, IMPACT_WARM, impactWarm);

		float glow  = 0.0; // post-tonemap brightness from the strike
		float coreA = 0.0; // body alpha boost at the strike
		for (int i = 0; i < impactInfo.count; ++i) {
			vec3  impVec = normalize(impactInfo.impactInfoArray[i].xyz);
			float aoe    = impactInfo.impactInfoArray[i].w;
			if (aoe <= 0.0) continue;

			float angleDist = acos(clamp(dot(worldVec, impVec), -1.0, 1.0));
			float life      = clamp(aoe / 0.40, 0.0, 1.0); // aoe shrinks as the hit ages: 1=fresh, 0=old
			float age       = 1.0 - life;                  // 0=fresh, 1=old

			// Damage strength: aoe is a log-compressed function of dmg/capacity, so
			// scale the whole reaction by it to separate light (e.g. armvang) from
			// heavy (e.g. armstump) hits. Floored so small shots still register.
			float dmgStrength = mix(0.35, 1.0, smoothstep(0.06, 0.40, aoe));

			// Energy dissipates outward: a wavefront expands from the impact point as
			// the hit ages, sweeping over the hex cells it passes.
			const float MAX_SPREAD = 1.15;  // how far (radians) the ripple travels over its life
			const float BAND_W     = 0.26;  // wavefront thickness
			float impactWaveSpeed = max(uImpactWaveSpeed, 0.001);
			float impactWaveStrength = max(uImpactWaveStrength, 0.0);
			float front = age * MAX_SPREAD * impactWaveSpeed;
			float ring  = exp(-pow((angleDist - front) / BAND_W, 2.0)); // soft band riding the front

			// Region already swept by the front stays briefly energized, then settles.
			float disc  = smoothstep(front + BAND_W, front - BAND_W * 0.5, angleDist);

			// Initial hot point right where the shot landed (collapses as it spreads out).
			float coreFall = max(1.0 - angleDist / max(aoe * cameraDistanceFactors.x, 1e-4), 0.0);
			float core     = pow(coreFall, 3.0) * life;

			float wave = ring * life; // travelling flash, fades as it spreads

			// Hex cells flash opaque on the wavefront and in the freshly-swept disc.
			impactHexBoost += (wave * 1.1 + disc * 0.3 * life + core * 0.6) * dmgStrength * impactWaveStrength;
			// Lattice warp is concentrated on the moving front so the distortion travels.
			impactWarp     += (wave * 0.8 + core * 0.3) * dmgStrength * impactWaveStrength;

			glow  += (core * 0.7 + wave * 0.25) * dmgStrength * impactWaveStrength;
			coreA += (core * 0.5 + wave * 0.18) * dmgStrength * impactWaveStrength;
		}

		glow  = min(glow, 5.0);
		coreA = min(coreA, 2.0);

		// Route the flash through the post-tonemap accumulators so it stays saturated
		contactHotBoost += impactTint * glow * 1.3 * shieldFade;
		contactHotAlpha += coreA * 0.35 * shieldFade;
		color.a         += coreA * 0.14 * shieldFade;
	}

	// --- Rim energy field ---
	vec3  rimHotBoost  = vec3(0.0); // post-tonemap accumulator
	float rimHotAlpha  = 0.0;
	{
		float RIM_SHARPNESS  = uRimSharpness;   // higher = thinner edge band
		float RIM_ALPHA      = uRimAlpha;        // peak alpha contribution at silhouette
		float RIM_COLOR_GAIN = uRimColorGain;   // how much rim brightens (lower = more saturated)
		const float HEX_SCALE_U    = 1.6;   // hex pattern density around belly
		const float HEX_SCALE_V    = 3.0;   // hex pattern density vertically
		const float HEX_DRIFT_U    = 0.0014;// horizontal drift speed
		const float HEX_DRIFT_V    = 0.0006;// vertical drift speed
		const float SWEEP_FREQ     = 5.0;   // vertical scanline density (higher = more bands on the shield at once)
		const float SWEEP_SPEED    = 0.005; // scanline upward speed (animation speed of each band)
		const float SWEEP_SHARP    = 28.0;  // shape exponent (higher = narrower, more subtle peaks)
		float BREATH_SPEED   = uBreathSpeed; // overall pulse speed
		const float CRACKLE_SCALE  = 100.0;  // micro-noise frequency on rim
		const float CRACKLE_SPEED  = 0.170; // micro-noise scroll speed
		const float CRACKLE_AMOUNT = 0.03;  // crackle modulation strength
		float HEX_FIRE_PROB  = uHexFireProb;  // fraction of "charged" hex cells
		float HEX_FIRE_GAIN  = uHexFireGain;   // brightness boost on charged cells
		float ARC_BURST_FREQ = uArcBurstFreq; // arc-flash frequency (per frame)
		float ARC_BURST_GAIN = uArcBurstGain;   // arc-flash brightness peak
		float CHROMA_SPLIT   = uChromaSplit;  // cyan-positive split at extreme rim
		const float HOT_ESCAPE     = 0.85;  // fraction of rim color to keep post-tonemap

		float rim = 1.0 - clamp(colormix, 0.0, 1.0);
		rim = pow(rim, RIM_SHARPNESS);

		// Hex cells on sphere surface via spherical UV
		vec2 hexUV;
		hexUV.x = atan(rmp.x, rmp.z) * (1.0 / PI) * HEX_SCALE_U;
		hexUV.y = rmp.y * HEX_SCALE_V;
		hexUV  += vec2(gameFrame * HEX_DRIFT_U, gameFrame * HEX_DRIFT_V);
		float hex = 1.0 - Hexagon2D(hexUV, 0.30, 0.55);

		// Per-cell charge flicker: cross-fade between time buckets for smooth flash
		float cellTime  = gameFrame * 0.020;
		float cellBucket = floor(cellTime);
		float cellBlend  = smoothstep(0.0, 1.0, fract(cellTime));
		vec3 cellIdA = vec3(floor(hexUV * 1.7), cellBucket);
		vec3 cellIdB = vec3(floor(hexUV * 1.7), cellBucket + 1.0);
		float cellHash = mix(Value3D(cellIdA), Value3D(cellIdB), cellBlend);
		float cellFire = smoothstep(1.0 - HEX_FIRE_PROB, 1.0, cellHash);
		hex *= mix(1.0, HEX_FIRE_GAIN, cellFire);

		float sweepRaw = SNORM2NORM(sin(rmp.y * SWEEP_FREQ - gameFrame * SWEEP_SPEED));
		float sweep = pow(sweepRaw, SWEEP_SHARP);

		// Occasional arc-burst: randomised per-shield, half-sine envelope
		float arcTime   = gameFrame * ARC_BURST_FREQ;
		float arcBucket = floor(arcTime);
		float arcFrac   = fract(arcTime);
		float arcSeedA  = Value3D(vec3(arcBucket,       translationScale.x * 0.07, translationScale.z * 0.11));
		float arcSeedB  = Value3D(vec3(arcBucket + 1.0, translationScale.x * 0.07, translationScale.z * 0.11));
		float arcSeed   = mix(arcSeedA, arcSeedB, smoothstep(0.0, 1.0, arcFrac));
		float arcEnvelope = sin(arcFrac * PI);
		float arcGate   = smoothstep(0.78, 0.92, arcSeed) * arcEnvelope;
		float arcLocal  = SNORM2NORM(sin(rmp.y * SWEEP_FREQ * 2.2 - gameFrame * SWEEP_SPEED * 5.0));
		arcLocal = pow(arcLocal, SWEEP_SHARP);
		float arc = arcLocal * arcGate * ARC_BURST_GAIN;

		float breath = 0.85 + 0.15 * SNORM2NORM(sin(gameFrame * BREATH_SPEED + translationScale.x * 0.13));

		vec3 crackleP = rmp * CRACKLE_SCALE;
		crackleP.y -= gameFrame * CRACKLE_SPEED;
		float crackle = SNORM2NORM(SimplexPerlin3D(crackleP));
		float crackleMod = mix(1.0 - CRACKLE_AMOUNT, 1.0 + CRACKLE_AMOUNT, crackle);

		float idle = rim * (0.45 + 0.25 * hex) * breath + arc;

		// Rim color: teal (healthy) -> orange (damaged)
		const vec3 RIM_COOL_COLOR = vec3(0.10, 0.95, 1.20);
		const vec3 RIM_WARM_COLOR = vec3(1.40, 0.45, 0.10);
		float warmness = clamp(color1.r - color1.b * 0.8, 0.0, 1.0);
		vec3 rimTarget = mix(RIM_COOL_COLOR, RIM_WARM_COLOR, warmness);
		vec3 rimTint   = mix(color1.rgb * 0.5, rimTarget, pow(rim, 0.6));

		// Hex grid via triplanar projection, flow noise, per-cell flash
		float fxAlpha        = 0.0;
		vec3  fxColor        = vec3(0.0);
		vec3  fxHexPostTonemap = vec3(0.0);
		float fxHexAlpha     = 0.0;
		{
			float HEX_SCALE       = uHexScale;
			const float EDGE_WIDTH      = 0.06;
			const float FRESNEL_POWER   = 1.8;
			const float FRESNEL_STR     = 1.75;
			float HEX_OPACITY     = uHexOpacity;
			const float FLASH_SPEED     = 0.6;
			const float FLASH_INTENSITY = 0.11;
			float FLOW_SCALE      = uFlowScale;
			float FLOW_SPEED      = uFlowSpeed;
			float FLOW_INTENSITY  = uFlowIntensity;
			const float FADE_START      = -0.35;
			const float TIME_SCALE      = 1.0 / 30.0;

			float time   = gameFrame * TIME_SCALE;
			vec3  normPos = normalize(rmp);

			// Fresnel: colormix encodes |dot(n,v)|, so 1-colormix is the rim term
			float ndv     = clamp(colormix, 0.0, 1.0);
			float fresnel = pow(1.0 - ndv, FRESNEL_POWER) * FRESNEL_STR;

			// Two simplex octaves scrolling in different directions
			float t   = time * FLOW_SPEED;
			float fn1 = SimplexPerlin3D(normPos * FLOW_SCALE       + vec3(t,      t * 0.6, t * 0.4));
			float fn2 = SimplexPerlin3D(normPos * FLOW_SCALE * 2.1 + vec3(-t*0.5, t * 0.9, t * 0.3));
			float flowNoise = (fn1 * 0.6 + fn2 * 0.4) * 0.5 + 0.5;

			// Triplanar hex: pick dominant cube face, fade seams
			vec3  absN      = abs(normPos);
			float dominance = max(absN.x, max(absN.y, absN.z));
			float hexFade   = smoothstep(0.65, 0.85, dominance);

			vec2 faceUV;
			if (absN.x >= absN.y && absN.x >= absN.z) {
				faceUV = normPos.yz;
			} else if (absN.y >= absN.z) {
				faceUV = normPos.xz;
			} else {
				faceUV = normPos.xy;
			}

			// Electromagnetic perturbations: localized grid distortions showing field lines
			const float PERTURB_SCALE   = 3.2;
			const float PERTURB_AMOUNT  = 0.022;
			const float PERTURB_SPEED   = 0.06;
			vec3 perturbP = normPos * PERTURB_SCALE + vec3(time * PERTURB_SPEED, time * PERTURB_SPEED * 0.7, time * PERTURB_SPEED * 0.4);
			float perturb1 = SimplexPerlin3D(perturbP);
			float perturb2 = SimplexPerlin3D(perturbP * 0.6 + vec3(1.5, 2.3, 0.8));
			vec2 perturbOffset = vec2(perturb1, perturb2) * PERTURB_AMOUNT;

			// Weapon-impact reaction: a wavefront of energy travels outward from the
			// blocked shot. On the front, shove the lattice UVs with a turbulent warp so
			// the hex grid visibly ripples outward, and lift Fresnel/flow so it glows.
			if (impactWarp > 0.0) {
				float warp = min(impactWarp, 2.5);
				vec3  iwP  = normPos * 6.0 + vec3(time * 0.8, -time * 0.6, time * 0.5);
				vec2  impWarp = vec2(SimplexPerlin3D(iwP), SimplexPerlin3D(iwP + vec3(11.3, 4.1, 7.7)));
				perturbOffset += impWarp * warp * 0.025;
				fresnel        = fresnel * (1.0 + impactHexBoost * 0.45);
				flowNoise      = clamp(flowNoise * (1.0 + impactHexBoost * 0.25), 0.0, 1.0);
			}

			vec2  hexBaseUV = faceUV + perturbOffset;
			float hex   = ShieldHexPattern(hexBaseUV, HEX_SCALE, EDGE_WIDTH) * hexFade;
			vec2  cId   = ShieldHexCellId(hexBaseUV, HEX_SCALE);
			float flash = ShieldCellFlash(cId, time, FLASH_SPEED, FLASH_INTENSITY) * hexFade;

			// Hex cells near a fresh impact flash brighter and more opaque.
			float impactCell = clamp(impactHexBoost, 0.0, 3.0);
			float hexTerm   = hex * HEX_OPACITY * (0.3 + fresnel * 0.7) * (1.0 + impactCell * 1.0);
			float intensity = hexTerm + fresnel * 0.4 + flash + hex * impactCell * 0.3;

			vec3 lColor = color1.rgb;

			fxColor  = lColor * (intensity - hexTerm) * 2.0;
			fxColor += lColor * (flowNoise * fresnel * FLOW_INTENSITY);
			fxAlpha  = intensity;

			// --- Hex-edge refraction (chromatic dispersion) ---
			// Treat each hex seam as a refractive edge: build the edge normal from
			// the pattern gradient, then split the R and B channels in opposite
			// directions across it so the lattice bends light like glass. The split
			// is amplified at the Fresnel rim so the dispersion lives on the edges.
			const float REFRACT_EPS    = 0.0016; // gradient probe distance (faceUV)
			float REFRACT_SPLIT  = uRefractSplit;  // base chromatic separation
			float REFRACT_RIMAMP = uRefractRimAmp;    // extra split toward the silhouette
			float hexGu = ShieldHexPattern(hexBaseUV + vec2(REFRACT_EPS, 0.0), HEX_SCALE, EDGE_WIDTH) * hexFade;
			float hexGv = ShieldHexPattern(hexBaseUV + vec2(0.0, REFRACT_EPS), HEX_SCALE, EDGE_WIDTH) * hexFade;
			vec2  edgeNormal = vec2(hexGu - hex, hexGv - hex); // points across the cell edge
			float edgeLen    = length(edgeNormal);
			vec2  refrDir    = (edgeLen > 1e-5) ? edgeNormal / edgeLen : vec2(0.0);
			vec2  refrOffset = refrDir * REFRACT_SPLIT * (0.35 + fresnel * REFRACT_RIMAMP);
			float hexR = ShieldHexPattern(hexBaseUV + refrOffset, HEX_SCALE, EDGE_WIDTH) * hexFade;
			float hexB = ShieldHexPattern(hexBaseUV - refrOffset, HEX_SCALE, EDGE_WIDTH) * hexFade;

			// Hex lines routed post-tonemap so saturated colour survives luma clamp.
			// Per-channel offsets give a blue body with red/cyan fringing on the edges.
			vec3 HEX_TINT  = vec3(uHexTintR, uHexTintG, uHexTintB); // per-channel gain (blue body + dispersion fringe)
			vec3  hexRGB     = vec3(hexR, hex, hexB) * (0.40 + fresnel * 0.60);
			// Light up the hex edges on the travelling wavefront.
			hexRGB *= (1.0 + impactCell * 1.2);
			fxHexPostTonemap = hexRGB * HEX_TINT * 1.1;
			fxHexAlpha       = max(max(hexRGB.r, hexRGB.g), hexRGB.b) * 0.33;

			// Dissolve toward the ground pole
			float bottomFade = smoothstep(-1.0, FADE_START, normPos.y);
			fxColor          *= bottomFade;
			fxAlpha          *= bottomFade;
			fxHexPostTonemap *= bottomFade;
			fxHexAlpha       *= bottomFade;
		}

		// Chromatic dispersion at the extreme silhouette: bias toward the
		// rim target's dominant channel so the brightest hot edge keeps its
		// hue (cool when healthy, warm when damaged) instead of clipping.
		float chromaMask = pow(rim, 4.0);
		vec3 chromaDir   = mix(vec3(-1.0, 0.4, 1.0), vec3(1.0, -0.2, -0.8), warmness);
		vec3 chromaSplit = chromaDir * CHROMA_SPLIT * chromaMask * idle;

		vec3 rimColor = rimTint * idle * RIM_COLOR_GAIN + chromaSplit;
		float rimA    = idle * RIM_ALPHA * crackleMod;

		rimColor *= shieldFade;
		rimA     *= shieldFade;

		// Lerp toward rimTint (avoids additive clamp going white)
		float replaceWeight = clamp(idle * 1.2, 0.0, 1.0) * shieldFade;
		color.rgb = mix(color.rgb, rimTint, replaceWeight);
		vec3 hotAdd = rimTint * idle * (RIM_COLOR_GAIN - 1.0) * shieldFade + chromaSplit;
		color.rgb += hotAdd * (1.0 - HOT_ESCAPE) * 0.4;
		color.a   += rimA;

		rimHotBoost = hotAdd * HOT_ESCAPE * 0.4;
		rimHotAlpha = rimA * 0.35;

		// Edge bloom: wide Fresnel halo post-tonemap
		const float BLOOM_SHARPNESS = 0.35;
		float BLOOM_STRENGTH  = uBloomStrength;
		float BLOOM_ALPHA     = uBloomAlpha;
		float bloomFresnel = pow(1.0 - clamp(colormix, 0.0, 1.0), BLOOM_SHARPNESS);
		float bloomBreath  = 0.78 + 0.22 * SNORM2NORM(sin(gameFrame * BREATH_SPEED * 0.7 + translationScale.z * 0.09));
		vec3  bloomColor   = rimTarget * bloomFresnel * BLOOM_STRENGTH * bloomBreath * shieldFade;
		float bloomAlpha   = bloomFresnel * BLOOM_ALPHA * bloomBreath * shieldFade;
		rimHotBoost += bloomColor;
		rimHotAlpha += bloomAlpha;

		rimHotBoost += contactHotBoost;
		rimHotAlpha += contactHotAlpha;

		// Flow-shield hex layer (additive)
		color.rgb   += fxColor * shieldFade * 0.33;
		color.a     += fxAlpha * shieldFade * 0.55;
		rimHotBoost += fxColor * shieldFade * 0.63;
		rimHotAlpha += fxAlpha * 0.15 * shieldFade;
		rimHotBoost += fxHexPostTonemap * 0.75 * shieldFade;
		rimHotAlpha += fxHexAlpha * 0.75 * shieldFade;
	}

	//poor man's tonemapping
	const float maxLuma = 0.8;
	vec3 ycbcrColor = RGB2YCBCR * color.rgb;
	ycbcrColor.x = min(ycbcrColor.x, maxLuma);
	color.rgb = YCBCR2RGB * ycbcrColor;

	color.rgb += rimHotBoost;
	color.a   += rimHotAlpha;

	float maxAlpha = uMaxAlpha;
	color.a = min(color.a, maxAlpha);

	color.a *= shieldFade;
	color.a *= overlapScale;

	// Enemy shields: clip to airLOS footprint.
	// losMask gives per-fragment spatial visibility; enemyLOSAlpha is a per-unit
	// scalar that lerps 0→1 on the CPU when the shield enters LOS, giving a
	// smooth fade-in rather than an instant pop.
	if (enemyLOSClip > 0.5) {
		vec2 losUV = clamp(worldPos.xz / vec2(mapSizeX, mapSizeZ), vec2(0.0), vec2(1.0));
		// Multi-sample cross blur (4-tile step) to turn the hard tile-resolution
		// LOS boundary into a wide gradient instead of a snapping edge.
		// textureSize gives us exact texel size without needing an extra uniform.
		vec2 ts = 4.0 / vec2(textureSize(airLosTex, 0));
		float airLOS = texture(airLosTex, losUV                       ).r * 0.333
		             + texture(airLosTex, losUV + vec2( ts.x,    0.0 )).r * 0.167
		             + texture(airLosTex, losUV + vec2(-ts.x,    0.0 )).r * 0.167
		             + texture(airLosTex, losUV + vec2(  0.0,  ts.y  )).r * 0.167
		             + texture(airLosTex, losUV + vec2(  0.0, -ts.y  )).r * 0.167;
		// Wide smoothstep: the blurred average sits anywhere between the
		// out-of-LOS floor (~0.15) and the in-LOS ceiling (~1.0), giving a
		// smooth gradient several tiles wide at every LOS edge.
		float losMask = smoothstep(0.12, 0.88, airLOS);
		color.a *= losMask * enemyLOSAlpha;
	}

	// Fade opacity with camera distance: transparent when zoomed in, solid when pulled back
	float camDist = length(viewPos.xyz);
	float zoomT    = smoothstep(uZoomNear, uZoomFar, camDist);
	float zoomMask = mix(uZoomMinMult, 1.0, pow(zoomT, uZoomCurve));
	color.a *= zoomMask;

	// Blue plasma tint driven by art editor
	color.rgb *= vec3(uBlueTintR, uBlueTintG, uBlueTintB);

	gl_FragColor = color;
}
