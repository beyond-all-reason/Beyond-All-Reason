#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com), released under the MIT license

//__DEFINES__

#ifndef MASKPASS
	#define MASKPASS 0 // 1: coverage mask pass, see gui_attackrange_gl4.lua
#endif

#line 20000

uniform float selUnitCount = 1.0;
uniform float selBuilderCount = 1.0;
uniform float drawAlpha = 1.0;
uniform float drawMode = 0.0;

// Range coverage mask, see gui_attackrange_gl4.lua: bit (1 << class) of the 8-bit red
// channel is set where a filled range disc of that class covers the pixel.
#if (MASKPASS == 1)
	uniform float maskWriteValue = 0.0; // class bit / 255, additively blended into the mask
#else
	uniform sampler2D maskTex;
	uniform float maskClip = 0.0; // 1.0: hide fragments inside the mask (outer rings)
	uniform float maskChannelBit = 1.0; // class bit to test
#endif

//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	flat vec4 v_blendedcolor;
	#if (DEBUG == 1)
		vec4 v_debug;
	#endif
};

out vec4 fragColor;

void main() {
#if (MASKPASS == 1)
	fragColor = vec4(maskWriteValue);
#else
	fragColor = v_blendedcolor;
	if (maskClip > 0.5) {
		// The mask covers the world viewport, gl_FragCoord is relative to the window.
		ivec2 texel = ivec2(gl_FragCoord.xy - viewGeometry.zw);
		int bits = int(texelFetch(maskTex, texel, 0).r * 255.0 + 0.5);
		if ((bits & int(maskChannelBit)) != 0) {
			fragColor.a = 0.0; // inside the merged area of this class, not part of its outline
		}
	}
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
#endif
}
