#version 430 core

// Instanced shield sphere. One draw call renders every visible shield of a
// geometry size; per-shield parameters arrive as instance attributes instead
// of uniforms (see gfx_unit_shield_effects.lua).

//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec3 vertexPos;      // unit sphere position
layout (location = 1) in vec4 instPosRadius;  // world position xyz, shield radius
layout (location = 2) in vec4 instRotMargin;  // yaw, margin, shieldFade, overlapScale
layout (location = 3) in vec4 instColor1;
layout (location = 4) in vec4 instColor2;
layout (location = 5) in vec4 instParams;     // effects bitmask, impact base index (vec4s), impact count, unused

out vec4 modelPos;
out vec4 worldPos;
out vec4 viewPos;
out float colormix;
out float normalizedFragDepth;
noperspective out vec2 v_screenUV;

flat out vec4 v_translationScale;
flat out vec4 v_color1;
flat out vec4 v_color2;
flat out vec2 v_fadeOverlap;  // shieldFade, overlapScale
flat out ivec4 v_params;      // effects bitmask, impact base index, impact count, flags (1 = scavenger palette)
flat out vec2 v_arcBreath;    // per-shield idle-field terms: arc burst gate, breathing brightness
flat out float v_cameraInside; // 1.0 when the camera sits inside this shield sphere

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

#define BITMASK_FIELD(value, pos) ((uint(value) & (1u << uint(pos))) != 0u)

const float PI = acos(0.0) * 2.0;

vec3 RotateY(vec3 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);

	//{x Cos[ang] + z Sin[ang], y, z Cos[ang] - x Sin[ang]}
	return vec3(p.x * c + p.z * s, p.y, p.z * c - p.x * s);
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

void main() {
	float gameFrame = timeInfo.x + timeInfo.w;
	int effects = int(instParams.x + 0.5);

	v_translationScale = instPosRadius;
	v_color1 = instColor1;
	v_color2 = instColor2;
	v_fadeOverlap = instRotMargin.zw;
	v_params = ivec4(effects, int(instParams.y + 0.5), int(instParams.z + 0.5), int(instParams.w + 0.5));

	// Idle-field terms that are constant across the whole shield: evaluate
	// them once per vertex instead of once per fragment.
	{
		const float ARC_BURST_FREQ = 0.013; // arc-flash frequency (per frame)
		const float BREATH_SPEED   = 0.018; // overall pulse speed

		float arcTime   = gameFrame * ARC_BURST_FREQ;
		float arcBucket = floor(arcTime);
		float arcFrac   = fract(arcTime);
		float arcSeedA  = Value3D(vec3(arcBucket,       instPosRadius.x * 0.07, instPosRadius.z * 0.11));
		float arcSeedB  = Value3D(vec3(arcBucket + 1.0, instPosRadius.x * 0.07, instPosRadius.z * 0.11));
		float arcSeed   = mix(arcSeedA, arcSeedB, smoothstep(0.0, 1.0, arcFrac));
		// Half-sine envelope across the bucket so even at peak seed the burst
		// fades in/out rather than ending abruptly.
		float arcEnvelope = sin(arcFrac * PI);
		v_arcBreath.x = smoothstep(0.78, 0.92, arcSeed) * arcEnvelope;

		// Slow breathing brightness modulation so idle shields feel alive
		v_arcBreath.y = 0.85 + 0.15 * SNORM2NORM(sin(gameFrame * BREATH_SPEED + instPosRadius.x * 0.13));
	}

	// When the camera is inside the sphere only the back faces are visible,
	// so they must get the full shading path (see fragment shader).
	vec3 cameraPos = cameraViewInv[3].xyz;
	v_cameraInside = (distance(cameraPos, instPosRadius.xyz) < instPosRadius.w * 1.02) ? 1.0 : 0.0;

	modelPos = vec4(vertexPos, 1.0);

	if (BITMASK_FIELD(effects, 6)) {
		float r = length(modelPos.xyz);
		float theta = acos(modelPos.z / r);
		float phi = atan(modelPos.y, modelPos.x);
		r += 0.010 * r * SNORM2NORM(sin( (2.0 * theta + instPosRadius.z  * 13.0 + 3.3 * cos(phi + instPosRadius.x * 17.0)) * 8.0 + gameFrame * 0.05));
		modelPos.xyz = vec3(r * sin(theta) * cos(phi), r * sin(theta) * sin(phi), r * cos(theta));
	}

	worldPos = vec4(instPosRadius.www * modelPos.xyz, 1.0);	//scaling
	worldPos.xyz  = RotateY(worldPos.xyz, instRotMargin.x);	//rotation around Yaw axis
	worldPos.xyz += instPosRadius.xyz;						//translation in world space

	viewPos = cameraView * worldPos;

	vec3 worldNormal = normalize(RotateY(modelPos.xyz, instRotMargin.x));
	vec3 viewNormal = mat3(cameraView) * worldNormal;

	colormix = dot(viewNormal, normalize(viewPos.xyz));
	colormix = pow(abs(colormix), instRotMargin.y);

	vec2 nearFar = cameraProj[3][2] / vec2(cameraProj[2][2] - 1.0, cameraProj[2][2] + 1.0);
	normalizedFragDepth = (-viewPos.z - nearFar.x) / (nearFar.y - nearFar.x);
	normalizedFragDepth = clamp(normalizedFragDepth, 0.0, 1.0);

	gl_Position = cameraProj * viewPos;
	v_screenUV = SNORM2NORM(gl_Position.xy / gl_Position.w);
}
