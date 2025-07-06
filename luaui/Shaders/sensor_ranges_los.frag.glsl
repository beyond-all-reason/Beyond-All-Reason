#version 430
// This shader is (c) Beherith (mysterme@gmail.com)

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000

#ifdef STENCILPASS

#else
	uniform sampler2D losStencilTexture;
#endif 

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in DataVS {
	vec4 v_radius_circum_height;
	#ifndef STENCILPASS
		vec4 v_blendedcolor;
	#endif
};

out vec4 fragColor;

void main() {
	// sample the stencil texture to determine if this pixel is visible
	#ifdef STENCILPASS
		// if we are in stencil pass, we just output the blended color
		fragColor.rgba = vec4(vec3(v_radius_circum_height.x / 32), 1.0);
	#else
		//vec2 stencilUV = fract((v_uv_camdist_radius.xy * vec2(1.0/VSX, 1.0/ VSY) - 0.5)); // adjust UV coordinates if needed
		vec2 stencilUV = gl_FragCoord.xy * vec2(1.0/VSX, 1.0/ VSY); // adjust UV coordinates if needed
		float stencilValue = texture(losStencilTexture, stencilUV ).r;
		
		// if the stencil value is less than 0.5, this pixel is not visible
		//float smoothstenc = 1.0 - smoothstep(0.47, 0.477, stencilValue);
		float smoothstenc = 1.0 - smoothstep(0.49, 0.51, stencilValue);
		fragColor.rgba = vec4(v_blendedcolor.rgb,v_blendedcolor.a *( smoothstenc)  );
		fragColor.a *= v_radius_circum_height.w; // inboundsness

		#ifdef MAX_HEIGHT
			// if the height is above the max height, discard the pixel
			if (v_radius_circum_height.z > MAX_HEIGHT) {
				fragColor.a = 0.0;
			}
		#endif
			
		#ifdef STIPPLE_RATE
			fragColor.a *= 3.0 * sin(v_radius_circum_height.y * STIPPLE_RATE + timeInfo.x*-0.2); // PERFECT STIPPLING!
		#endif
	#endif

}