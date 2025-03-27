//map_startcone_gl4.vert.glsl

#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com), licensed under the MIT license

#line 5000
layout (location = 0) in vec4 position; // xyz and etc garbage
//layout locations 1 and 2 contain primitive specific garbage and should not be used
layout (location = 3) in vec4 worldposrad; // l w rot and maxalpha
layout (location = 4) in vec4 teamcolor;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

uniform float isMinimap = 0;
uniform int flipMiniMap = 0;
uniform float startPosScale = 0.0005;

out DataVS {
	vec4 v_worldposrad;
	vec4 v_teamcolor;
};


#line 11000
void main()
{
	v_teamcolor = teamcolor;
	vec4 worldPos = vec4(position.xyz, 1.0);
	
	if (isMinimap < 0.5) { // world
		worldPos.xyz = worldPos.xyz + worldposrad.xyz;
		v_worldposrad = vec4(worldPos.xyz, worldposrad.w);
		gl_Position = cameraViewProj * worldPos;
	}else{
		//vec2 ndcxy = normalize(position.xz);//  * 100/256.0;
		//if (length(position.xz) < 1e3) { ndcxy = vec2(0);}
		vec2 ndcxy = position.xz * startPosScale;
		ndcxy.y *= mapSize.x/mapSize.y;

		vec2 xz = worldposrad.xz;
		ndcxy = (xz / mapSize.xy + ndcxy) * 2.0 - 1.0;
		if (flipMiniMap < 1) {
			ndcxy.y *= -1;
		}else{
			ndcxy.x *= -1;
		}
		gl_Position = vec4(ndcxy, 0.0, 1.0);
	}
}