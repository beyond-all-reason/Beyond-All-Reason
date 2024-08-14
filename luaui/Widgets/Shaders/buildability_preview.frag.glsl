#version 420
// This shader is (c) Beherith (mysterme@gmail.com), Licensed under the MIT License

#line 20000


uniform sampler2D heightmapTex;

//__ENGINEUNIFORMBUFFERDEFS__

//__DEFINES__
in DataVS {
	vec4 worldPos; // pos and radius
	vec4 blendedcolor;
};

out vec4 fragColor;

void main() {
	fragColor.rgb = fract(blendedcolor.rgb * 0.05);
	fragColor.a = 1.0;
}