#version 430 core

// Template mesh vertex carries one integer slot index (0..27), uploaded as a
// float because the engine VBO API convention uses float template attributes.
layout(location = 0) in float vertexSlot;

// Instance attributes shifted up by one because the template uses location 0.
layout(location = 1) in vec4 spawnPosAndSize;   // xyz=spawnPos, w=packed(sizeMult,fadeFrames)
layout(location = 2) in vec4 velAndSpawnFrame;  // xyz=velocity, w=spawnFrame
layout(location = 3) in vec4 instColor;
layout(location = 4) in vec4 rotData;           // x=rotVal0, y=rotVel0, z=wobbleStartFrame, w=deathFrame

//__ENGINEUNIFORMBUFFERDEFS__

uniform float wobbleAmp;
uniform float wobbleFreq;
uniform float wobbleVar;
uniform float wobbleFreqVar;
uniform float wobbleRampFrames;
uniform float drawRadius;
uniform int   u_shape;
uniform float glowScale;
uniform float glowIntensity;

out vec4 g_color;
out vec3 g_normal;
out vec3 g_worldPos;
out vec3 g_localPos;
out vec3 g_noiseSeed;
out vec2 g_glowUV;
out float g_isGlow;
out float g_seed;

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

void emitShapeVertex(int slot, vec3 localPos, vec3 normal, vec3 center, vec4 col, vec3 noiseSeed, float seed) {
	g_color = col;
	g_normal = normal;
	g_noiseSeed = noiseSeed;
	g_isGlow = 0.0;
	g_glowUV = vec2(0.0);
	g_seed = seed;
	g_localPos = localPos;
	g_worldPos = center + localPos;
	gl_Position = cameraViewProj * vec4(g_worldPos, 1.0);
}

void emitGlowVertex(int slot, vec3 localPos, vec2 glowUV, vec3 center, vec4 col, float seed) {
	g_color = col;
	g_normal = vec3(0.0, 1.0, 0.0);
	g_noiseSeed = vec3(0.0);
	g_localPos = vec3(0.0);
	g_isGlow = 1.0;
	g_seed = seed;
	g_glowUV = glowUV;
	g_worldPos = center + localPos;
	gl_Position = cameraViewProj * vec4(g_worldPos, 1.0);
}

void main() {
	float currentFrame = timeInfo.x + timeInfo.w;
	float spawnFrame   = velAndSpawnFrame.w;
	float deathFrame   = rotData.w;

	if (currentFrame >= deathFrame) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		g_color = vec4(0.0);
		g_normal = vec3(0.0);
		g_worldPos = vec3(0.0);
		g_localPos = vec3(0.0);
		g_noiseSeed = vec3(0.0);
		g_glowUV = vec2(0.0);
		g_isGlow = 0.0;
		g_seed = 0.0;
		return;
	}

	float t = currentFrame - spawnFrame;
	if (t < 0.0) t = 0.0;

	vec3 worldPos = spawnPosAndSize.xyz + velAndSpawnFrame.xyz * t;

	if (wobbleAmp > 0.0001) {
		float wobbleT   = max(currentFrame - rotData.z, 0.0);
		float totalLife = max(deathFrame - rotData.z, 1.0);
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

	float fade = (fadeFrames > 0.5)
		? clamp((deathFrame - currentFrame) / fadeFrames, 0.0, 1.0)
		: 1.0;

	float rotVel = rotData.y;
	float rotVal = rotData.x + rotVel  * t;

	vec3 center = worldPos;
	vec4 col = instColor * fade;
	float size  = drawRadius * sizeMult * (0.5 + 0.5 * fade);

	vec3 phaseSeed = vec3(rotData.x, rotData.y, rotData.x + rotData.y);
	vec3 noiseSeed = phaseSeed * 137.0 + vec3(11.0, 47.0, 83.0);
	float h  = dot(phaseSeed, vec3(0.123, 0.456, 0.789));
	vec3 phase = vec3(hash11(h), hash11(h+1.7), hash11(h+3.3)) * 6.2831853;
	float r = radians(rotVal);
	vec3 ang = phase + vec3(r * 1.0, r * 1.3, r * 0.7);
	mat3 R = rotXYZ(ang);
	float seed = radians(phaseSeed.x);

	int slot = int(vertexSlot);

	// The geometry shader only emits the glow quad when glow is actually enabled.
	// The template mesh always contains the 4 glow slots, so move them off-screen
	// when disabled to avoid wasted fragment shader work.
	bool emitGlow = (glowIntensity > 0.001) && (glowScale > 1.001);
	if (slot >= 24 && !emitGlow) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		g_color = vec4(0.0);
		g_normal = vec3(0.0);
		g_worldPos = vec3(0.0);
		g_localPos = vec3(0.0);
		g_noiseSeed = vec3(0.0);
		g_glowUV = vec2(0.0);
		g_isGlow = 0.0;
		g_seed = 0.0;
		return;
	}

	if (u_shape == 1) {
		// ---- OCTAHEDRON ---- 24 shape verts (8 tris * 3) then 4 glow verts.
		if (slot < 24) {
			vec3 X = R * vec3(size, 0, 0); vec3 nX = -X;
			vec3 Y = R * vec3(0, size, 0); vec3 nY = -Y;
			vec3 Z = R * vec3(0, 0, size); vec3 nZ = -Z;
			float k = 0.57735027;
			vec3 n[8];
			n[0] = R * vec3( k,  k,  k);
			n[1] = R * vec3(-k,  k,  k);
			n[2] = R * vec3(-k,  k, -k);
			n[3] = R * vec3( k,  k, -k);
			n[4] = R * vec3( k, -k,  k);
			n[5] = R * vec3(-k, -k,  k);
			n[6] = R * vec3(-k, -k, -k);
			n[7] = R * vec3( k, -k, -k);
			vec3 corners[8][3];
			corners[0][0] = Y;  corners[0][1] = Z;  corners[0][2] = X;
			corners[1][0] = Y;  corners[1][1] = nX; corners[1][2] = Z;
			corners[2][0] = Y;  corners[2][1] = nZ; corners[2][2] = nX;
			corners[3][0] = Y;  corners[3][1] = X;  corners[3][2] = nZ;
			corners[4][0] = nY; corners[4][1] = X;  corners[4][2] = Z;
			corners[5][0] = nY; corners[5][1] = Z;  corners[5][2] = nX;
			corners[6][0] = nY; corners[6][1] = nX; corners[6][2] = nZ;
			corners[7][0] = nY; corners[7][1] = nZ; corners[7][2] = X;
			int tri = slot / 3;
			int ci  = slot - tri * 3;
			emitShapeVertex(slot, corners[tri][ci], n[tri], center, col, noiseSeed, seed);
		} else {
			vec3 right = cameraViewInv[0].xyz * (size * glowScale);
			vec3 up    = cameraViewInv[1].xyz * (size * glowScale);
			int gi = slot - 24;
			if (gi == 0) emitGlowVertex(slot, -right - up, vec2(-1.0, -1.0), center, col, seed);
			else if (gi == 1) emitGlowVertex(slot,  right - up, vec2( 1.0, -1.0), center, col, seed);
			else if (gi == 2) emitGlowVertex(slot, -right + up, vec2(-1.0,  1.0), center, col, seed);
			else              emitGlowVertex(slot,  right + up, vec2( 1.0,  1.0), center, col, seed);
		}
	} else {
		// ---- CUBE (default) ---- 24 shape verts (6 quads * 4) then 4 glow verts.
		if (slot < 24) {
			vec3 X = R * vec3(size, 0, 0);
			vec3 Y = R * vec3(0, size, 0);
			vec3 Z = R * vec3(0, 0, size);
			vec3 nXp =  R[0]; vec3 nXm = -R[0];
			vec3 nYp =  R[1]; vec3 nYm = -R[1];
			vec3 nZp =  R[2]; vec3 nZm = -R[2];
			vec3 corners[6][4];
			vec3 normals[6];
			corners[0][0] =  X-Y-Z; corners[0][1] =  X+Y-Z; corners[0][2] =  X-Y+Z; corners[0][3] =  X+Y+Z; normals[0] = nXp;
			corners[1][0] = -X-Y-Z; corners[1][1] = -X-Y+Z; corners[1][2] = -X+Y-Z; corners[1][3] = -X+Y+Z; normals[1] = nXm;
			corners[2][0] = -X+Y-Z; corners[2][1] = -X+Y+Z; corners[2][2] =  X+Y-Z; corners[2][3] =  X+Y+Z; normals[2] = nYp;
			corners[3][0] = -X-Y-Z; corners[3][1] =  X-Y-Z; corners[3][2] = -X-Y+Z; corners[3][3] =  X-Y+Z; normals[3] = nYm;
			corners[4][0] = -X-Y+Z; corners[4][1] =  X-Y+Z; corners[4][2] = -X+Y+Z; corners[4][3] =  X+Y+Z; normals[4] = nZp;
			corners[5][0] = -X-Y-Z; corners[5][1] = -X+Y-Z; corners[5][2] =  X-Y-Z; corners[5][3] =  X+Y-Z; normals[5] = nZm;
			int quad = slot / 4;
			int ci   = slot - quad * 4;
			emitShapeVertex(slot, corners[quad][ci], normals[quad], center, col, noiseSeed, seed);
		} else {
			vec3 right = cameraViewInv[0].xyz * (size * glowScale);
			vec3 up    = cameraViewInv[1].xyz * (size * glowScale);
			int gi = slot - 24;
			if (gi == 0) emitGlowVertex(slot, -right - up, vec2(-1.0, -1.0), center, col, seed);
			else if (gi == 1) emitGlowVertex(slot,  right - up, vec2( 1.0, -1.0), center, col, seed);
			else if (gi == 2) emitGlowVertex(slot, -right + up, vec2(-1.0,  1.0), center, col, seed);
			else              emitGlowVertex(slot,  right + up, vec2( 1.0,  1.0), center, col, seed);
		}
	}
}
