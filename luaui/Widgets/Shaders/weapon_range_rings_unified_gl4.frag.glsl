#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com), released under the MIT license

//_DEFINES__

#line 20000

uniform float selUnitCount = 1.0;
uniform float selBuilderCount = 1.0;
uniform float drawAlpha = 1.0;
uniform float drawMode = 0.0;

//_ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	flat vec4 v_blendedcolor;
};

out vec4 fragColor;

void main() {

	fragColor = v_blendedcolor;
	// For testing:
	if (fract(gl_FragCoord.x * 0.25) < 0.4) {
		fragColor.rgb *= 0.0;
	}
	//fragColor.rgb *= (fract(gl_FragCoord.x * 0.25 ) * 4.0);
}