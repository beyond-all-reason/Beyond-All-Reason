#version 430 core

#define DEPTH_CLIP01 ###DEPTH_CLIP01###

//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D mapDepthTex;
uniform sampler2D modelsDepthTex;

// Impact points of every visible shield this frame, packed back to back.
// Each shield reads v_params.z entries starting at v_params.y.
layout (std430, binding = ###IMPACT_SSBO_BINDING###) readonly buffer ImpactBuffer {
	vec4 impacts[]; // xyz = normalized impact direction, w = aoe
};

in vec4 modelPos;
in vec4 worldPos;
in vec4 viewPos;
in float colormix;
in float normalizedFragDepth;
noperspective in vec2 v_screenUV;

flat in vec4 v_translationScale;
flat in vec4 v_color1;
flat in vec4 v_color2;
flat in vec2 v_fadeOverlap;   // shieldFade, overlapScale
flat in ivec3 v_params;       // effects bitmask, impact base index, impact count
flat in vec2 v_arcBreath;     // arc burst gate, breathing brightness (per shield, from VS)
flat in float v_cameraInside; // 1.0 when the camera is inside this shield

out vec4 fragColor;

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

//Lua limitations only allow to send 24 bits. Should be enough :)
#define BITMASK_FIELD(value, pos) ((uint(value) & (1u << uint(pos))) != 0u)

float GetViewSpaceDepth(float depthNDC) {
	return -cameraProj[3][2] / (cameraProj[2][2] + depthNDC);
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
	//  https://github.com/BrianSharpe/Wombat/blob/master/Value3D.glsl

	// establish our grid cell and unit position
	vec3 Pi = floor(P);
	vec3 Pf = P - Pi;
	vec3 Pf_min1 = Pf - 1.0;

	// clamp the domain
	Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
	vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

	// calculate the hash
	vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
	Pt *= Pt;
	Pt = Pt.xzxz * Pt.yyww;
	vec2 hash_mod = vec2( 1.0 / ( 635.298681 + vec2( Pi.z, Pi_inc1.z ) * 48.500388 ) );
	vec4 hash_lowz = fract( Pt * hash_mod.xxxx );
	vec4 hash_highz = fract( Pt * hash_mod.yyyy );

	//	blend the results and return
	vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
	vec4 res0 = mix( hash_lowz, hash_highz, blend.z );
	vec4 blend2 = vec4( blend.xy, vec2( 1.0 - blend.xy ) );
	return dot( res0, blend2.zxzx * blend2.wwyy );
}

float SimplexPerlin3D( vec3 P ) {
    //  https://github.com/BrianSharpe/Wombat/blob/master/SimplexPerlin3D.glsl

    //  simplex math constants
    const float SKEWFACTOR = 1.0/3.0;
    const float UNSKEWFACTOR = 1.0/6.0;
    const float SIMPLEX_CORNER_POS = 0.5;
    const float SIMPLEX_TETRAHADRON_HEIGHT = 0.70710678118654752440084436210485;    // sqrt( 0.5 )

    //  establish our grid cell.
    P *= SIMPLEX_TETRAHADRON_HEIGHT;    // scale space so we can have an approx feature size of 1.0
    vec3 Pi = floor( P + dot( P, vec3( SKEWFACTOR) ) );

    //  Find the vectors to the corners of our simplex tetrahedron
    vec3 x0 = P - Pi + dot(Pi, vec3( UNSKEWFACTOR ) );
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 Pi_1 = min( g.xyz, l.zxy );
    vec3 Pi_2 = max( g.xyz, l.zxy );
    vec3 x1 = x0 - Pi_1 + UNSKEWFACTOR;
    vec3 x2 = x0 - Pi_2 + SKEWFACTOR;
    vec3 x3 = x0 - SIMPLEX_CORNER_POS;

    //  pack them into a parallel-friendly arrangement
    vec4 v1234_x = vec4( x0.x, x1.x, x2.x, x3.x );
    vec4 v1234_y = vec4( x0.y, x1.y, x2.y, x3.y );
    vec4 v1234_z = vec4( x0.z, x1.z, x2.z, x3.z );

    // clamp the domain of our grid cell
    Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
    vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

    //	generate the random vectors
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

    //	evaluate gradients
    vec4 grad_results = inversesqrt( hash_0 * hash_0 + hash_1 * hash_1 + hash_2 * hash_2 ) * ( hash_0 * v1234_x + hash_1 * v1234_y + hash_2 * v1234_z );

    //	Normalization factor to scale the final result to a strict 1.0->-1.0 range
    //	http://briansharpe.wordpress.com/2012/01/13/simplex-noise/#comment-36
    const float FINAL_NORMALIZATION = 37.837227241611314102871574478976;

    //  evaluate the kernel weights ( use (0.5-x*x)^3 instead of (0.6-x*x)^4 to fix discontinuities )
    vec4 kernel_weights = v1234_x * v1234_x + v1234_y * v1234_y + v1234_z * v1234_z;
    kernel_weights = max(0.5 - kernel_weights, 0.0);
    kernel_weights = kernel_weights*kernel_weights*kernel_weights;

    //	sum with the kernel and return
    return dot( kernel_weights, grad_results ) * FINAL_NORMALIZATION;
}

float StrangeSurface(vec3 snormPos, float mult, float time) {
	const float MAX_ITER = 1.5;

	vec2 p = snormPos.xz*(1.5 - abs(snormPos.y)) * mult;

	vec2 i = p;
	float c = 0.0;
	float inten = 0.07;
	float r = length(p + vec2(sin(time), sin(time * 0.433 + 2.0)) * 3.0);

	for (float n = 0.0; n < MAX_ITER; n++) {
		float t = r - time * (1.0 - (1.9 / (n + 1.0)));
		      t = r - time / (n + 0.6);
		i -= p + vec2(
			cos(t - i.x - r) + sin(t + i.y),
			sin(t - i.y) + cos(t + i.x) + r
		);
		c += 1.0/length(vec2(
			(sin(i.x + t) / inten),
			(cos(i.y + t) / inten)
			)
		);

	}

	c /= MAX_ITER;
	c = clamp(c, -1.0, 1.0);
	return c;
}

float Hexagon2D(vec2 p, float edge0, float edge1) {
	p.x *= 0.57735 * 2.0;
	p.y += mod(floor(p.x), 2.0) * 0.5;
	p = abs((mod(p, 1.0) - 0.5));
	float val = abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
	return smoothstep(edge0, edge1, val);
}

vec2 GetRippleOffset(vec3 thisPoint, vec3 impactPoint, float magMult, float gameFrame) {
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

void main() {
	float gameFrame = timeInfo.x + timeInfo.w;
	int effects = v_params.x;
	vec4 color1 = v_color1;
	vec4 color2 = v_color2;
	vec4 translationScale = v_translationScale;
	float shieldFade = v_fadeOverlap.x;
	float overlapScale = v_fadeOverlap.y;

	// A shield sphere is drawn double sided. Seen from outside, the back face is
	// a second, nearly identical layer under the front face: it only adds the
	// localized effects (contact outline, impacts) and its share of the rim is
	// folded into the front face's alpha instead. With the camera inside the
	// sphere only back faces exist, so they take the full path.
	bool cameraInside = v_cameraInside > 0.5;
	bool fullPath = gl_FrontFacing || cameraInside;

	vec4 color;
	color = mix(color1, color2, colormix);
	if (!fullPath) {
		color.a = 0.0; // body layer is only drawn once (front face)
	}

	// --- Contact outline: cheap depth proximity test first -----------------
	const float outlineEffectSize = 30.0;
	const float outlineAlpha = 0.45;
	// The outline factor is smoothstep(0, depthDiff, size * noise): it has a
	// long soft tail. In the tail the noise is frozen at its mean, so the glow
	// is negligible (< 0.5%) beyond this distance and the tail costs no noise.
	const float OUTLINE_TAIL_RANGE = 300.0;
	const float OUTLINE_TAIL_NOISE = 0.5;
	// The animated crackle is only worth its cost in the bright core of the
	// band; it fades out between these two distances so no seam is visible.
	const float OUTLINE_CRACKLE_FADE_START = 30.0;
	const float OUTLINE_CRACKLE_FADE_END = 90.0;
	bool doOutline = BITMASK_FIELD(effects, 1) || BITMASK_FIELD(effects, 2);
	float depthDiff = 1.0e9;
	if (doOutline) {
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
		depthDiff = abs(viewPos.z - minDepthView);
	}
	bool contactCore = doOutline && (depthDiff < OUTLINE_CRACKLE_FADE_END); // bright part of the band
	// The faint tail is only drawn on the front face; the back face's tail sits
	// under the front face's fill and is not worth keeping those fragments alive.
	bool nearContact = contactCore || (doOutline && fullPath && (depthDiff < OUTLINE_TAIL_RANGE));

	// --- Rim mask: also gates the (expensive) idle field ---------------------
	const float RIM_SHARPNESS = 1.5;   // higher = thinner edge band
	const float RIM_EPS = 0.005;       // below this the rim alpha is invisible
	float rim = 1.0 - clamp(colormix, 0.0, 1.0);
	rim = pow(rim, RIM_SHARPNESS);
	bool doRim = fullPath && (rim > RIM_EPS);

	int impactCount = BITMASK_FIELD(effects, 3) ? v_params.z : 0;

	// Back face away from any contact and without impacts: nothing to draw.
	if (!fullPath && !nearContact && impactCount == 0) {
		discard;
	}

	const float valueNoiseMovePace = 0.25;
	float valueNoise = 0.0;
	if (contactCore || impactCount > 0) {
		vec3 valueNoiseVec = modelPos.xyz * translationScale.www;
		valueNoiseVec.y += gameFrame * valueNoiseMovePace;
		valueNoise = Value3D(valueNoiseVec);
	}

	// Body colour feeds the outline, so back faces need it only in the bright core.
	if (BITMASK_FIELD(effects, 6) && (fullPath || contactCore)) {
		const float perlinNoiseMovePace = 0.0025;
		float waveFront = mod(-gameFrame * 0.0020, 0.5);

		vec3 perlinNoiseVec = modelPos.xyz;
		//perlinNoiseVec.y += gameFrame * perlinNoiseMovePace;

		//float perlin = 0.33 * abs(SimplexPerlin3D(perlinNoiseVec * 50.0)) + 0.5 * abs(SimplexPerlin3D(perlinNoiseVec * 0.5));
		float perlin = 5 * abs(StrangeSurface(modelPos.xyz, 4.0, gameFrame * perlinNoiseMovePace));

		float band = SNORM2NORM(cos((modelPos.y - waveFront) * PI * 4.0));

		float pb = pow( clamp(perlin * band, 0.0, 0.8), 0.25 );

		color = pow(color, vec4(1.3 - pb));
	}

	if (nearContact) {
		// Noise modulates the band width in the core; blend to its mean towards
		// the tail so the tail needs no noise evaluation and stays seamless.
		float outlineNoise = mix(valueNoise, OUTLINE_TAIL_NOISE, smoothstep(OUTLINE_CRACKLE_FADE_START, OUTLINE_CRACKLE_FADE_END, depthDiff));
		float outlineFactor = smoothstep( 0.0, depthDiff, outlineEffectSize * outlineNoise );
		outlineFactor *= mix(0.25, 1.0, SNORM2NORM(sin(0.1*gameFrame + 5.0*(modelPos.x + modelPos.z +  modelPos.y))));

		// Animated crackle on the outline edge so where the shield meets terrain/units
		// it shimmers like a contact arc rather than a static halo. Only evaluated
		// in the bright core of the band, fading out so the tail stays seamless.
		if (contactCore) {
			const float OUTLINE_CRACKLE_SCALE = 130.0;  // noise frequency along the edge
			const float OUTLINE_CRACKLE_SPEED = 0.110; // scroll speed
			const float OUTLINE_CRACKLE_AMOUNT = 0.25; // modulation depth (0 = off, 1 = full flicker)
			float crackleAmount = OUTLINE_CRACKLE_AMOUNT * (1.0 - smoothstep(OUTLINE_CRACKLE_FADE_START, OUTLINE_CRACKLE_FADE_END, depthDiff));
			vec3 outlineCrackleP = modelPos.xyz * OUTLINE_CRACKLE_SCALE;
			outlineCrackleP.y -= gameFrame * OUTLINE_CRACKLE_SPEED;
			outlineCrackleP.x += gameFrame * OUTLINE_CRACKLE_SPEED * 0.37;
			float outlineCrackle = SNORM2NORM(SimplexPerlin3D(outlineCrackleP));
			outlineFactor *= mix(1.0 - crackleAmount, 1.0 + crackleAmount, outlineCrackle);
		}
		outlineFactor = clamp(outlineFactor, 0.0, 1.0);

		// Scale by shieldFade so outline alpha fades with the rest of the shield
		color.a = mix(color.a, outlineAlpha * shieldFade, outlineFactor);
	}

	if (impactCount > 0) { // impact animation
		const vec4 impactColor = vec4(0.35);

		vec3 worldVec = normalize(worldPos.xyz - translationScale.xyz);

		vec2 cameraDistanceFactors = vec2(1.0);
		if (BITMASK_FIELD(effects, 7)) { // impactScaleWithDistance
			cameraDistanceFactors = vec2(1.0 + 1.0 * normalizedFragDepth, 1.0 + 6.0 * normalizedFragDepth);
		}

		vec4 impactFactor = vec4(0.0);
		int impactBase = v_params.y;
		for (int i = 0; i < impactCount; ++i) {
			vec4 impactInfo = impacts[impactBase + i];
			vec3 worldImpactVec = normalize(impactInfo.xyz);
			float angleDist = acos( dot(worldVec, worldImpactVec) );
			float impactRadius = impactInfo.w * cameraDistanceFactors.x;
			if (angleDist >= impactRadius) {
				continue; // outside this impact's footprint: its factor would be 0
			}
			vec3 thisImpactFactor = vec3(smoothstep( impactRadius, 0.0, angleDist ));

			float centerFactor = pow(thisImpactFactor.r, 6.0 / cameraDistanceFactors.y);

			//-- swirl a bit
			float impactRoll = 0.35 * PI * centerFactor;
			impactRoll *= float(BITMASK_FIELD(effects, 5));

			mat4 worldImpactMat = CalculateLookAtMatrix(worldImpactVec, vec3(0.0), impactRoll);
			vec3 impactNoiseVec = mat3(worldImpactMat) * worldVec;

			if (BITMASK_FIELD(effects, 8)) { // impactRipples
				vec2 rippleOffset = GetRippleOffset(impactNoiseVec, vec3(0.0, 0.0, 1.0), thisImpactFactor.r, gameFrame);
				impactNoiseVec.xy += rippleOffset;
				thisImpactFactor *= 1.0 + length(rippleOffset) * 1.0;
			}

			impactNoiseVec *= 36.0 / cameraDistanceFactors.x;

			vec2 noiseVecOffset = 0.8 * centerFactor * vec2( sin(gameFrame * PI * 0.15), cos(gameFrame * PI * 0.15) );
			noiseVecOffset *= vec2(BITMASK_FIELD(effects, 4));

			// Make chromatic aberration effect around the impact point
			thisImpactFactor.r *= Hexagon2D(impactNoiseVec.xy + vec2(noiseVecOffset.x, noiseVecOffset.y), 0.2, 0.2);
			thisImpactFactor.g *= Hexagon2D(impactNoiseVec.xy + vec2(-noiseVecOffset.x, -noiseVecOffset.y), 0.2, 0.2);
			thisImpactFactor.b *= Hexagon2D(impactNoiseVec.xy + vec2(noiseVecOffset.x * noiseVecOffset.y, 0.0), 0.2, 0.2);

			thisImpactFactor *= mix(0.6, 1.0, valueNoise);
			impactFactor.rgb += thisImpactFactor.rgb;
			impactFactor.a = 0.333333 * (impactFactor.r + impactFactor.g + impactFactor.b);
		}

		// Scale by shieldFade so impact flashes fade with the shield
		color += impactColor * impactFactor * shieldFade;
	}

	// --- Idle rim energy field ----------------------------------------------
	// Always-on enhancement that gives shields a visible, animated silhouette
	// without obstructing the units inside. Fresnel acts as the master mask:
	// rim ~= 0 head-on, ~= 1 at the silhouette, so the interior stays clear
	// even when many shields overlap.
	vec3  rimHotBoost  = vec3(0.0); // applied AFTER tonemap to keep saturation
	float rimHotAlpha  = 0.0;
	if (doRim) {
		const float RIM_ALPHA      = 0.45;  // peak alpha contribution at silhouette
		const float RIM_COLOR_GAIN = 2.2;   // how much rim brightens (lower = more saturated)
		const float HEX_SCALE_U    = 1.6;   // hex pattern density around belly
		const float HEX_SCALE_V    = 3.0;   // hex pattern density vertically
		const float HEX_DRIFT_U    = 0.0014;// horizontal drift speed
		const float HEX_DRIFT_V    = 0.0006;// vertical drift speed
		const float SWEEP_FREQ     = 5.0;   // vertical scanline density (higher = more bands on the shield at once)
		const float SWEEP_SPEED    = 0.040; // scanline upward speed (animation speed of each band)
		const float SWEEP_SHARP    = 5.0;   // shape exponent (2 = smooth breathe, 5 = narrow peaks)
		const float CRACKLE_SCALE  = 100.0;  // micro-noise frequency on rim
		const float CRACKLE_SPEED  = 0.170; // micro-noise scroll speed
		const float CRACKLE_AMOUNT = 0.44;  // crackle modulation strength
		const float HEX_FIRE_PROB  = 0.18;  // fraction of "charged" hex cells
		const float HEX_FIRE_GAIN  = 1.8;   // brightness boost on charged cells
		const float ARC_BURST_GAIN = 2.2;   // arc-flash brightness peak
		const float CHROMA_SPLIT   = 0.5;  // cyan-positive split at extreme rim
		const float HOT_ESCAPE     = 0.85;  // fraction of rim color to keep post-tonemap

		// Hex energy cells drifting around the sphere; spherical UV from modelPos
		vec2 hexUV;
		hexUV.x = atan(modelPos.x, modelPos.z) * (1.0 / PI) * HEX_SCALE_U;
		hexUV.y = modelPos.y * HEX_SCALE_V;
		hexUV  += vec2(gameFrame * HEX_DRIFT_U, gameFrame * HEX_DRIFT_V);
		// Hexagon2D returns 1 in gaps, 0 inside cells; we want lit cells -> invert
		float hex = 1.0 - Hexagon2D(hexUV, 0.30, 0.55);

		// Per-cell randomization: use floor(hexUV) as cell id, hash with Value3D
		// to pick which cells "fire" brighter. Time is the third noise axis, so
		// Value3D's own fade curve cross-fades between adjacent time buckets and
		// cells charge/discharge smoothly with a single noise evaluation.
		float cellTime  = gameFrame * 0.020;
		float cellHash = Value3D(vec3(floor(hexUV * 1.7), cellTime));
		float cellFire = smoothstep(1.0 - HEX_FIRE_PROB, 1.0, cellHash);
		hex *= mix(1.0, HEX_FIRE_GAIN, cellFire);

		// Vertical scanline sweep traveling up the shield. Use pow(sin, 2) for
		// a smooth breathe shape that still ranges 0..1 (so shield body
		// stays visible between bands). Lower SWEEP_SHARP for wider/softer
		// bands; higher for narrower peaks.
		float sweepRaw = SNORM2NORM(sin(modelPos.y * SWEEP_FREQ - gameFrame * SWEEP_SPEED));
		float sweep = pow(sweepRaw, SWEEP_SHARP);

		// Occasional arc-burst: a brighter, faster sweep band that swells
		// irregularly. The gate (randomness + envelope) is per shield and comes
		// from the vertex shader.
		float arcGate   = v_arcBreath.x;
		float arcLocal  = SNORM2NORM(sin(modelPos.y * SWEEP_FREQ * 2.2 - gameFrame * SWEEP_SPEED * 5.0));
		arcLocal = pow(arcLocal, SWEEP_SHARP);
		float arc = arcLocal * arcGate * ARC_BURST_GAIN;

		// Slow breathing brightness modulation so idle shields feel alive (per shield, from VS)
		float breath = v_arcBreath.y;

		// High-freq crackle noise modulating only the rim alpha for that
		// "containment field" feel (no color contribution -> stays cheap).
		// Value noise (already 0..1) instead of simplex: roughly a third of the cost.
		vec3 crackleP = modelPos.xyz * CRACKLE_SCALE;
		crackleP.y -= gameFrame * CRACKLE_SPEED;
		float crackle = Value3D(crackleP);
		float crackleMod = mix(1.0 - CRACKLE_AMOUNT, 1.0 + CRACKLE_AMOUNT, crackle);

		// Combine: rim is the master mask, hex/sweep/arc are texture, breath modulates
		float idle = rim * (0.45 + 0.25 * hex + 0.75 * sweep + arc) * breath;

		// Rim color follows shield charge state. We derive a "warmness" from
		// color1 itself (high R, low B = damaged orange/red), and blend the
		// rim target between cool teal (healthy) and a hot orange (damaged).
		// This way the rim still announces low-charge urgency.
		const vec3 RIM_COOL_COLOR = vec3(0.10, 0.95, 1.20); // teal/cyan, healthy
		const vec3 RIM_WARM_COLOR = vec3(1.40, 0.45, 0.10); // orange/red, damaged
		float warmness = clamp(color1.r - color1.b * 0.8, 0.0, 1.0);
		vec3 rimTarget = mix(RIM_COOL_COLOR, RIM_WARM_COLOR, warmness);
		vec3 rimTint   = mix(color1.rgb * 0.5, rimTarget, pow(rim, 0.6));

		// Chromatic dispersion at the extreme silhouette: bias toward the
		// rim target's dominant channel so the brightest hot edge keeps its
		// hue (cool when healthy, warm when damaged) instead of clipping.
		float chromaMask = pow(rim, 4.0);
		vec3 chromaDir   = mix(vec3(-1.0, 0.4, 1.0), vec3(1.0, -0.2, -0.8), warmness);
		vec3 chromaSplit = chromaDir * CHROMA_SPLIT * chromaMask * idle;

		vec3 rimColor = rimTint * idle * RIM_COLOR_GAIN + chromaSplit;
		float rimA    = idle * RIM_ALPHA * crackleMod;

		// Apply global fade so rim disappears when shield turns off / depletes
		rimColor *= shieldFade;
		rimA     *= shieldFade;

		// Replace (lerp) rather than add: additive + tonemap clamp was making
		// both G and B channels clip to 1.0 and the rim went white. By lerping
		// toward rimTint weighted by idle, the silhouette adopts the rim hue.
		float replaceWeight = clamp(idle * 1.2, 0.0, 1.0) * shieldFade;
		color.rgb = mix(color.rgb, rimTint, replaceWeight);
		// Small additive contribution for "hot" brightness, limited so it
		// does not push channels into the white clamp.
		vec3 hotAdd = rimTint * idle * (RIM_COLOR_GAIN - 1.0) * shieldFade + chromaSplit;
		color.rgb += hotAdd * (1.0 - HOT_ESCAPE) * 0.4;

		// Post-tonemap: add the remaining hot contribution so saturated hue
		// survives the YCbCr luma clamp.
		rimHotBoost = hotAdd * HOT_ESCAPE * 0.4;
		rimHotAlpha = rimA * 0.35;

		// Seen from outside, the back face used to draw the same rim as a
		// second blended layer. Fold that layer in: a + a * (1 - a).
		if (!cameraInside) {
			rimA        = rimA * (2.0 - rimA);
			rimHotAlpha = rimHotAlpha * (2.0 - rimHotAlpha);
		}
		color.a += rimA;
	}

	//poor man's tonemapping ahead
	const float maxLuma = 0.8;
	vec3 ycbcrColor = RGB2YCBCR * color.rgb;
	ycbcrColor.x = min(ycbcrColor.x, maxLuma);
	color.rgb = YCBCR2RGB * ycbcrColor;

	// Apply rim hot-boost AFTER tonemap so the silhouette keeps its color
	color.rgb += rimHotBoost;
	color.a   += rimHotAlpha;

	const float maxAlpha = 0.6;
	color.a = min(color.a, maxAlpha);

	// Final safeguard: multiply by shieldFade so the shield can never leave
	// residual opacity behind when it fades out (covers any contribution that
	// doesn't individually scale with shieldFade).
	color.a *= shieldFade;

	// Overlap dimming: when many shields stack on the same screen volume the
	// scene becomes unreadable. Each shield is given a per-frame opacity
	// scalar by the gadget based on how many other shields it overlaps and
	// whether it sits in front of or behind them. We dim only alpha so the
	// rim/glow color stays correct and shields just become more transparent.
	color.a *= overlapScale;

	fragColor = color;
}
