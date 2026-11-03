#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is Copyright (c) 2024 Beherith (mysterme@gmail.com) and licensed under the MIT License

#line 10000
layout (location = 0) in vec2 planePos;

uniform float lavaHeight;

out DataVS {
	vec4 worldPos;
	vec4 worldUV;
	float inboundsness;
};
//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

#line 11000

vec2 inverseMapSize = 1.0 / mapSize.xy;

float rand(vec2 co){ // a pretty crappy random function
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
	// mapSize.xy is the actual map size,
	//place the vertices into the world:
	worldPos.y = lavaHeight;
	worldPos.w = 1.0;
	worldPos.xz =  (1.5 * planePos +0.5) * mapSize.xy;

	// pass the world-space UVs out
	float mapratio = mapSize.y / mapSize.x;
	worldUV.xy = (1.5 * planePos +0.5);
	worldUV.y *= mapratio;

	float gametime = (timeInfo.x + timeInfo.w) * SWIRLFREQUENCY;

	vec2 randpervertex = vec2(rand(worldPos.xz), rand(worldPos.xz * vec2(17.876234, 9.283)));
	worldUV.zw = sin(randpervertex + gametime * (0.5 + randpervertex));

	// global rotatemove, has 2 params, globalrotateamplitude, globalrotatefrequency
	// Spin the whole texture around slowly
	float worldRotTime = (timeInfo.x + timeInfo.w) ;
	worldUV.xy += vec2( sin(worldRotTime * GLOBALROTATEFREQUENCY), cos(worldRotTime * GLOBALROTATEFREQUENCY)) * GLOBALROTATEAMPLIDUE;

	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(worldPos.xz, mapSize.xy  - worldPos.xz) * inverseMapSize;
	inboundsness = min(mymin.x, mymin.y);

	// Assign world position:
	gl_Position = cameraViewProj * worldPos;
}
