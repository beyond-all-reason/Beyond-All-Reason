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
	vec2 worldUV;
	float inboundsness;
	noperspective vec2 v_screenUV;
};
//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

#line 11000

#define SNORM2NORM(value) (value * 0.5 + 0.5)

vec2 inverseMapSize = 1.0 / mapSize.xy;

void main() {
	// mapSize.xy is the actual map size,
	//place the vertices into the world:
	worldPos.y = lavaHeight;
	worldPos.w = 1.0;
	worldPos.xz =  (1.5 * planePos +0.5) * mapSize.xy;

	// pass the world-space UVs out
	float mapratio = mapSize.y / mapSize.x;
	worldUV = (1.5 * planePos +0.5);
	worldUV.y *= mapratio;

	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(worldPos.xz, mapSize.xy  - worldPos.xz) * inverseMapSize;
	inboundsness = min(mymin.x, mymin.y);

	// Assign world position:
	gl_Position = cameraViewProj * worldPos;
	v_screenUV = SNORM2NORM(gl_Position.xy / gl_Position.w);
}
