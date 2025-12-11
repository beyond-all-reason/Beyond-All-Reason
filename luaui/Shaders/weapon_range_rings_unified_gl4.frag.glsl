#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com), released under the MIT license

//__DEFINES__

#line 20000

uniform float selUnitCount = 1.0;
uniform float selBuilderCount = 1.0;
uniform float drawAlpha = 1.0;
uniform float drawMode = 0.0;
#if (DEBUG == 1)

//__ENGINEUNIFORMBUFFERDEFS__

#endif

in DataVS {
	flat vec4 v_blendedcolor;
	#if (DEBUG == 1)
		vec4 v_debug;
	#endif
};

out vec4 fragColor;

void main() {

	fragColor = v_blendedcolor;
	// For testing:
	#if (DEBUG == 1)
		if (fract(gl_FragCoord.x * 0.125) < 0.4) {
			#if (STATICUNITS == 0)
				fragColor.rgba *= 0.0;
			#endif
		}else{
			#if(STATICUNITS == 1)
				fragColor.rgba *= 0.0;
			#endif
		}
		
	#endif
}