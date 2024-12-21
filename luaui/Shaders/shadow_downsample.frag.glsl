#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)
// Notes:
// texelFetch is hardly faster but has banding artifacts, do not use!

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000
in DataVS {
	vec2 uv;
};

uniform sampler2D shadowTex;

out float shadowDownsampled;

void main() {
    shadowDownsampled = texture(shadowTex, uv).r;
}