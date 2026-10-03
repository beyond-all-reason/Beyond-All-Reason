#version 430 core

// Template mesh vertex carries one integer slot index (0..27), uploaded as a
// float because the engine VBO API convention uses float template attributes.
layout(location = 0) in float vertexSlot;

layout(location = 1) in vec4 spawnPosAndSize;   // xyz=spawnPos, w=packed(sizeMult,fadeFrames)
layout(location = 2) in vec4 velAndSpawnFrame;  // xyz=velocity (elmos/frame), w=spawnFrame
layout(location = 3) in vec4 instColor;         // rgb + alpha
layout(location = 4) in vec4 rotData;           // x=rotVal0, y=rotVel0, z=rotAcc (deg/frame²), w=deathFrame

//__ENGINEUNIFORMBUFFERDEFS__

uniform float drag;
uniform vec3  gravity;
uniform float fadeInFrames;
uniform float wobbleAmp;
uniform float wobbleFreq;
uniform float wobbleVar;
uniform float wobbleFreqVar;
uniform float wobbleRampFrames;
uniform float drawRadius;
uniform int   u_shape;
uniform float glowScale;
uniform float glowIntensity;
uniform float glowFalloff;
uniform float coreBoost;
uniform float hueJitter;
uniform float cubeNoiseScale;
uniform float glowBreath;
uniform float glowBreathFreq;
uniform float glowBreathVar;
uniform float glowBreathFreqVar;

// Same outputs as the geometry shader path (gsSrc in gfx_energy_explosion_particles_gl4.lua).
flat out vec4 g_color; // shape: rgb * hue tint * coreBoost, alpha; halo: premultiplied centre colour
out vec3 g_normal;     // shape: face normal; halo: (uv, 2.0)
out vec3 g_worldPos;   // shape only
out vec3 g_noisePos;   // shape only: localPos * cubeNoiseScale + per-particle seed

// Halo contributions under this round away in the RGBA8 framebuffer (sources clamp to [0, 1]),
// so each halo quad is cut to the radius where its falloff drops below it.
const float GLOW_CUTOFF = 0.25 / 255.0;

// Corner signs per template slot in the geometry shader's emit order:
// cube = 6 faces x 4 (strips), octahedron = 8 triangles x 3.
const vec3 CUBE_CORNERS[24] = vec3[24](
	vec3( 1,-1,-1), vec3( 1, 1,-1), vec3( 1,-1, 1), vec3( 1, 1, 1),
	vec3(-1,-1,-1), vec3(-1,-1, 1), vec3(-1, 1,-1), vec3(-1, 1, 1),
	vec3(-1, 1,-1), vec3(-1, 1, 1), vec3( 1, 1,-1), vec3( 1, 1, 1),
	vec3(-1,-1,-1), vec3( 1,-1,-1), vec3(-1,-1, 1), vec3( 1,-1, 1),
	vec3(-1,-1, 1), vec3( 1,-1, 1), vec3(-1, 1, 1), vec3( 1, 1, 1),
	vec3(-1,-1,-1), vec3(-1, 1,-1), vec3( 1,-1,-1), vec3( 1, 1,-1)
);
const vec3 CUBE_NORMALS[6] = vec3[6](
	vec3(1, 0, 0), vec3(-1, 0, 0), vec3(0, 1, 0), vec3(0, -1, 0), vec3(0, 0, 1), vec3(0, 0, -1)
);
const vec3 OCTA_CORNERS[24] = vec3[24](
	vec3(0, 1, 0), vec3(0, 0, 1), vec3(1, 0, 0),
	vec3(0, 1, 0), vec3(-1, 0, 0), vec3(0, 0, 1),
	vec3(0, 1, 0), vec3(0, 0, -1), vec3(-1, 0, 0),
	vec3(0, 1, 0), vec3(1, 0, 0), vec3(0, 0, -1),
	vec3(0, -1, 0), vec3(1, 0, 0), vec3(0, 0, 1),
	vec3(0, -1, 0), vec3(0, 0, 1), vec3(-1, 0, 0),
	vec3(0, -1, 0), vec3(-1, 0, 0), vec3(0, 0, -1),
	vec3(0, -1, 0), vec3(0, 0, -1), vec3(1, 0, 0)
);
const vec3 OCTA_NORMALS[8] = vec3[8](
	vec3( 1,  1,  1), vec3(-1,  1,  1), vec3(-1,  1, -1), vec3( 1,  1, -1),
	vec3( 1, -1,  1), vec3(-1, -1,  1), vec3(-1, -1, -1), vec3( 1, -1, -1)
);
const vec2 GLOW_CORNERS[4] = vec2[4](vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0));

float hash11(float x) {
	return fract(sin(x) * 43758.5453);
}

mat3 rotXYZ(vec3 a) {
	float cx = cos(a.x), sx = sin(a.x);
	float cy = cos(a.y), sy = sin(a.y);
	float cz = cos(a.z), sz = sin(a.z);
	mat3 Rx = mat3(1,0,0, 0,cx,sx, 0,-sx,cx);
	mat3 Ry = mat3(cy,0,-sy, 0,1,0, sy,0,cy);
	mat3 Rz = mat3(cz,sz,0, -sz,cz,0, 0,0,1);
	return Rz * Ry * Rx;
}

void main() {
	// Dead particles and skipped halos collapse off-screen.
	gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
	g_color = vec4(0.0);
	g_normal = vec3(0.0);
	g_worldPos = vec3(0.0);
	g_noisePos = vec3(0.0);

	float currentFrame = timeInfo.x + timeInfo.w;
	float spawnFrame   = velAndSpawnFrame.w;
	float deathFrame   = rotData.w;
	if (currentFrame >= deathFrame) return;

	int slot = int(vertexSlot);
	bool isGlow = slot >= 24;
	if (isGlow && !(glowIntensity > 0.0 && glowScale > 1.001)) return;

	float t = max(currentFrame - spawnFrame, 0.0);

	float tCap   = (drag > 0.0001) ? (1.0 / drag) : 1.0e6;
	float tClamp = min(t, tCap);
	vec3 worldPos = spawnPosAndSize.xyz
	              + velAndSpawnFrame.xyz * tClamp * (1.0 - 0.5 * drag * tClamp)
	              + 0.5 * gravity * t * t;

	if (wobbleAmp > 0.0001) {
		float wobbleT   = max(currentFrame - spawnFrame, 0.0);
		float totalLife = max(deathFrame - spawnFrame, 1.0);
		float bell      = sin(3.14159265 * wobbleT / totalLife);
		if (wobbleRampFrames > 0.5)
			bell *= min(1.0, wobbleT / wobbleRampFrames);
		vec3 vdir = velAndSpawnFrame.xyz;
		vec3 ref, axA, axB;
		float refAngle = rotData.x * 0.01745329;
		float s1 = sin(refAngle), c1 = cos(refAngle);
		float s2 = sin(refAngle * 2.19), c2 = cos(refAngle * 2.19);
		if (abs(vdir.y) < 0.95) {
			ref = normalize(vec3(s1, c1, s2));
		} else {
			ref = normalize(vec3(c1, s2, c2));
		}
		float h1 = fract(sin(rotData.x * 12.9898 + rotData.y * 78.233) * 43758.5453);
		float h2 = fract(sin(rotData.x * 23.1451 + rotData.y * 34.567) * 65432.0987);
		axA = normalize(vec3(
			sin(h1 * 6.28318),
			sin(h2 * 6.28318),
			cos(h1 * 3.14159 + h2 * 3.14159)
		));
		axB = cross(axA, ref);
		if (dot(axB, axB) > 0.001) {
			axB = normalize(axB);
		} else {
			axB = cross(axA, (abs(axA.x) < 0.9) ? vec3(1, 0, 0) : vec3(0, 1, 0));
			axB = normalize(axB);
		}
		float phaseOff = radians(rotData.x);
		float hash     = fract(sin(rotData.x * 12.9898 + rotData.y * 78.233) * 43758.5453);
		float freqScale = max(0.0, 1.0 + wobbleFreqVar * (2.0 * hash - 1.0));
		float dirSign  = (fract(hash * 7.31) < 0.5) ? -1.0 : 1.0;
		float hash2    = fract(hash * 113.7 + 0.317);
		float ampScale = max(0.0, 1.0 + wobbleVar * (2.0 * hash2 - 1.0));
		float ph = currentFrame * wobbleFreq * freqScale * dirSign * (6.2831853 / 30.0) + phaseOff;
		worldPos += (axA * cos(ph) + axB * sin(ph)) * (wobbleAmp * ampScale * bell);
	}

	float packedW    = abs(spawnPosAndSize.w);
	float fadeFrames = floor(packedW / 1024.0);
	float sizeMult   = (packedW - fadeFrames * 1024.0) / 256.0;

	float fadeOut = (fadeFrames > 0.5)
		? clamp((deathFrame - currentFrame) / fadeFrames, 0.0, 1.0)
		: 1.0;
	float fadeIn  = (fadeInFrames > 0.5)
		? clamp(t / fadeInFrames, 0.0, 1.0)
		: 1.0;
	float fade    = fadeOut * fadeIn;

	vec3 center = worldPos;
	vec4 col = instColor * fade;
	float size  = drawRadius * sizeMult;

	vec3 phaseSeed = vec3(rotData.x, rotData.y, rotData.x + rotData.y);
	float seed = radians(phaseSeed.x);

	vec3 tint = vec3(1.0);
	if (hueJitter > 0.0001) {
		tint = vec3(1.0) + hueJitter * vec3(
			sin(seed),
			sin(seed + 2.094),
			sin(seed + 4.188));
	}

	if (!isGlow) {
		float rotVel = rotData.y;
		float rotAcc = rotData.z;
		float rotVal = rotData.x + rotVel * t + 0.5 * rotAcc * t * t;

		vec3 noiseSeed = phaseSeed * 137.0 + vec3(11.0, 47.0, 83.0);
		float h  = dot(phaseSeed, vec3(0.123, 0.456, 0.789));
		vec3 phase = vec3(hash11(h), hash11(h+1.7), hash11(h+3.3)) * 6.2831853;
		float r = radians(rotVal);
		vec3 ang = phase + vec3(r * 1.0, r * 1.3, r * 0.7);
		mat3 R = rotXYZ(ang);

		vec3 s, n;
		if (u_shape == 1) {
			s = OCTA_CORNERS[slot];
			n = R * (OCTA_NORMALS[slot / 3] * 0.57735027);
		} else {
			s = CUBE_CORNERS[slot];
			n = R * CUBE_NORMALS[slot / 4];
		}
		vec3 lp = s.x * (R * vec3(size, 0, 0)) + s.y * (R * vec3(0, size, 0)) + s.z * (R * vec3(0, 0, size));
		g_color = vec4(col.rgb * tint * coreBoost, col.a);
		g_normal = n;
		g_worldPos = center + lp;
		g_noisePos = lp * cubeNoiseScale + noiseSeed;
		gl_Position = cameraViewProj * vec4(g_worldPos, 1.0);
		return;
	}

	// Halo: same per-particle colour and cut radius as the geometry shader path.
	float totalLifeBR = max(deathFrame - spawnFrame, 1.0);
	float lifeFrac    = clamp(t / totalLifeBR, 0.0, 1.0);
	float breathScale = 1.0 - smoothstep(0.5, 1.0, lifeFrac);

	float gI = glowIntensity;
	if (glowBreath > 0.0001) {
		float hAmp  = fract(sin(seed * 91.7253 + 17.31) * 43758.5453);
		float hFreq = fract(sin(seed * 33.1117 + 43.93) * 27183.4500);
		float ampScale  = max(0.0, 1.0 + glowBreathVar     * (2.0 * hAmp  - 1.0));
		float freqScale = max(0.0, 1.0 + glowBreathFreqVar * (2.0 * hFreq - 1.0));
		float ph = (timeInfo.x + timeInfo.w) * glowBreathFreq * freqScale * (6.2831853 / 30.0) + seed;
		gI *= max(1.0 + glowBreath * breathScale * ampScale * sin(ph), 0.35);
	}
	vec3  glowTint = col.rgb / max(max(col.r, max(col.g, col.b)), 0.001);
	float gLuma    = dot(glowTint, vec3(0.2126, 0.7152, 0.0722));
	const float GLOW_LUMA_TARGET = 0.55;
	const float GLOW_BOOST_MAX   = 5.0;
	float glowBoost = min(GLOW_LUMA_TARGET / max(gLuma, 0.001), GLOW_BOOST_MAX);
	vec4 glowCol = vec4(glowTint * tint * (gI * glowBoost * col.a), gI * col.a);
	float peak = max(max(glowCol.r, glowCol.g), max(glowCol.b, glowCol.a));
	if (peak <= GLOW_CUTOFF) return;

	float extent = min(1.0 - pow(GLOW_CUTOFF / peak, 1.0 / max(glowFalloff, 0.01)), 1.0);
	vec2 uv = GLOW_CORNERS[slot - 24] * extent;
	float halfSize = size * glowScale;
	g_color = glowCol;
	g_normal = vec3(uv, 2.0);
	g_worldPos = center;
	g_noisePos = vec3(0.0);
	gl_Position = cameraViewProj * vec4(center + (cameraViewInv[0].xyz * uv.x + cameraViewInv[1].xyz * uv.y) * halfSize, 1.0);
}
