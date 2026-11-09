#version 430 core

// Bakes the procedural terms of the shield surface that do not depend on the
// individual shield. All shields read this one octahedral map, once per
// fragment, instead of evaluating the noise themselves.
// R: fourth root of the body noise / 1.4953, G: hex energy cells / 1.8, B: crackle

uniform vec2 bakeParams; // game frame, texture size

out vec4 fragColor;

const float PI = acos(0.0) * 2.0;

float Value3D( vec3 P ) {
	//  https://github.com/BrianSharpe/Wombat/blob/master/Value3D.glsl

	// establish our grid cell and unit position
	vec3 Pi = floor(P);
	vec3 Pf = P - Pi;

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

float StrangeSurface(vec3 snormPos, float mult, float time) {
	const float MAX_ITER = 1.5;

	vec2 p = snormPos.xz*(1.5 - abs(snormPos.y)) * mult;

	vec2 i = p;
	float c = 0.0;
	float inten = 0.07;
	float r = length(p + vec2(sin(time), sin(time * 0.433 + 2.0)) * 3.0);

	for (float n = 0.0; n < MAX_ITER; n++) {
		float t = r - time / (n + 0.6);
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
	return clamp(c, -1.0, 1.0);
}

float Hexagon2D(vec2 p, float edge0, float edge1) {
	p.x *= 0.57735 * 2.0;
	p.y += mod(floor(p.x), 2.0) * 0.5;
	p = abs((mod(p, 1.0) - 0.5));
	float val = abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
	return smoothstep(edge0, edge1, val);
}

vec3 OctDecode(vec2 uv) {
	vec2 p = uv * 2.0 - 1.0;
	vec3 n = vec3(p.x, 1.0 - abs(p.x) - abs(p.y), p.y);
	if (n.y < 0.0) {
		vec2 s = vec2(n.x >= 0.0 ? 1.0 : -1.0, n.z >= 0.0 ? 1.0 : -1.0);
		n.xz = (1.0 - abs(n.zx)) * s;
	}
	return normalize(n);
}

void main() {
	const float PERLIN_MOVE_PACE = 0.0025;
	const float HEX_SCALE_U      = 1.6;    // hex pattern density around belly
	const float HEX_SCALE_V      = 3.0;    // hex pattern density vertically
	const float HEX_DRIFT_U      = 0.0014; // horizontal drift speed
	const float HEX_DRIFT_V      = 0.0006; // vertical drift speed
	const float HEX_FIRE_PROB    = 0.18;   // fraction of "charged" hex cells
	const float HEX_FIRE_GAIN    = 1.8;    // brightness boost on charged cells
	const float CRACKLE_SCALE    = 100.0;  // micro-noise frequency on the rim
	const float CRACKLE_SPEED    = 0.170;  // micro-noise scroll speed

	float gameFrame = bakeParams.x;
	vec3 dir = OctDecode(gl_FragCoord.xy / bakeParams.y);

	float perlin = 5.0 * abs(StrangeSurface(dir, 4.0, gameFrame * PERLIN_MOVE_PACE));

	vec2 hexUV;
	hexUV.x = atan(dir.x, dir.z) * (1.0 / PI) * HEX_SCALE_U;
	hexUV.y = dir.y * HEX_SCALE_V;
	hexUV  += vec2(gameFrame * HEX_DRIFT_U, gameFrame * HEX_DRIFT_V);

	// Hexagon2D returns 1 in gaps, 0 inside cells; lit cells want the inverse.
	float hex = 1.0 - Hexagon2D(hexUV, 0.30, 0.55);

	// Time is the third noise axis, so cells charge and discharge smoothly.
	float cellHash = Value3D(vec3(floor(hexUV * 1.7), gameFrame * 0.020));
	float cellFire = smoothstep(1.0 - HEX_FIRE_PROB, 1.0, cellHash);
	hex *= mix(1.0, HEX_FIRE_GAIN, cellFire);

	vec3 crackleP = dir * CRACKLE_SCALE;
	crackleP.y -= gameFrame * CRACKLE_SPEED;
	float crackle = Value3D(crackleP);

	fragColor = vec4(sqrt(sqrt(perlin)) / 1.4953, hex / HEX_FIRE_GAIN, crackle, 1.0);
}
