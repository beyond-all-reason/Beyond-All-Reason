#version 430
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.  

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
		flat vec4 v_blendedcolor;
		#if defined(STIPPLE_RATE) || defined(LINE_THIN_END)
			vec3 v_lineClipXYW;
		#endif
		#ifdef LINE_THIN_END
			float v_lineHalfWidth;
		#endif
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

		#ifdef LINE_THIN_END
			// thinner far from the camera: the line is rasterized at its full width, the part beyond the thinned half
			// width is dropped (discarded, so it doesn't mark the stencil that keeps overlapping circles from doubling up)
			vec2 thinCentrePx = (v_lineClipXYW.xy / v_lineClipXYW.z * 0.5 + 0.5) * vec2(VSX, VSY);
			float thinCoverage = clamp(v_lineHalfWidth + 0.5 - distance(gl_FragCoord.xy, thinCentrePx), 0.0, 1.0);
			if (thinCoverage <= 0.0) {
				discard;
			}
			fragColor.a *= thinCoverage;
		#endif

		#ifdef MAX_HEIGHT
			// if the height is above the max height, discard the pixel
			if (v_radius_circum_height.z > MAX_HEIGHT) {
				fragColor.a = 0.0;
			}
		#endif
			
		#ifdef STIPPLE_RATE
			float stipplePhase = v_radius_circum_height.y * STIPPLE_RATE + timeInfo.x*-0.2;
			float phasePerPixel = length(vec2(dFdx(stipplePhase), dFdy(stipplePhase)));
			// negative alpha is not clamped and tints the gaps magenta
			float stipple = max(3.0 * sin(stipplePhase), 0.0);
			// dashes under ~4 px per period alias into moire, so fade them to their mean (3/pi)
			fragColor.a *= mix(stipple, 0.9549297, smoothstep(1.5, 3.0, phasePerPixel));
			// thin the line to the dash length (half a period) when zoomed out, so dashes never turn into bars across it
			vec2 lineCentrePx = (v_lineClipXYW.xy / v_lineClipXYW.z * 0.5 + 0.5) * vec2(VSX, VSY);
			float maxOffsetPx = max(3.14159265 / phasePerPixel, 2.0);
			fragColor.a *= clamp(maxOffsetPx + 0.5 - distance(gl_FragCoord.xy, lineCentrePx), 0.0, 1.0);
		#endif
	#endif

}