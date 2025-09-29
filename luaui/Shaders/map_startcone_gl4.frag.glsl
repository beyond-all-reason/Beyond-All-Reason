#version 420
// This shader is (c) Beherith (mysterme@gmail.com), licensed under the MIT license

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000

//__ENGINEUNIFORMBUFFERDEFS__

//__DEFINES__


uniform float isMinimap = 0;

in DataVS {
	vec4 v_worldposrad;
	vec4 v_teamcolor;
};

out vec4 fragColor;

void main() {
	fragColor.rgba = v_teamcolor;
	//fragColor.rgba= vec4(1.0, 0.0, 0.0, 1.0);
}