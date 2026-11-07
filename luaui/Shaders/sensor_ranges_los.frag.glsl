#version 430
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.  

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#if !defined(STENCILPASS) && !defined(EXACT_CIRCLES)
	uniform sampler2D losStencilTexture;
#endif

#ifdef EXACT_CIRCLES
	// Every circle of this widget, to clip the lines exactly where they enter another circle: the low resolution
	// stencil texture blurs the corner where two circles cross, cutting a gap into both lines when zoomed out.
	struct SUniformsBuffer {
		uint composite; //     u8 drawFlag; u8 unused1; u16 id;

		uint unused2;
		uint unused3;
		uint unused4;

		float maxHealth;
		float health;
		float unused5;
		float unused6;

		vec4 drawPos;
		vec4 speed;
		vec4[4] userDefined; //can't use float[16] because float in arrays occupies 4 * float space
	};

	layout(std140, binding=1) readonly buffer UniformsBuffer {
		SUniformsBuffer uni[];
	};

	struct SensorCircle {
		vec4 radius_params; // as the vertex shader's instance attributes
		uvec4 instData;
	};

	layout(std430, binding=CIRCLE_SSBO_BINDING) readonly buffer SensorCircles {
		SensorCircle circles[];
	};

	uniform int circleCount;
#endif

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

#ifdef EXACT_CIRCLES
	// 0 inside any circle, 1 outside all of them. The circles are the CIRCLE_SEGMENTS-gons the lines are drawn as,
	// centred and sized like in the vertex shader, with the stencil texture's cut: its fan reaches 16 elmos past the
	// circle and fades over 32, which puts the edge 256 / (radius + 32) elmos outside, softened over 0.64 elmos.
	// So zoomed in the lines look as before; the edge is never softer than a pixel.
	float OutsideCircles() {
		// this pixel on the ground (the line's height), along the camera ray
		vec2 ndc = (gl_FragCoord.xy - viewGeometry.zw) / viewGeometry.xy * 2.0 - 1.0;
		vec4 rayEnd = cameraViewProjInv * vec4(ndc, 1.0, 1.0);
		vec3 camPos = cameraViewInv[3].xyz;
		vec3 rayDir = rayEnd.xyz / rayEnd.w - camPos;
		float lineHeight = max(0.0, v_radius_circum_height.z);
		vec2 pos = (camPos + rayDir * ((lineHeight - camPos.y) / rayDir.y)).xz;
		float pixelSize = max(length(dFdx(pos)), length(dFdy(pos))); // elmos

		float nowTime = timeInfo.x + timeInfo.w;
		float segment = 6.2831853 / float(CIRCLE_SEGMENTS);
		float nearest = 1.0; // distance to the nearest circle edge in edge widths, positive outside
		for (int i = 0; i < circleCount; i++) {
			vec4 radius_params = circles[i].radius_params;
			vec4 drawPos = uni[circles[i].instData.y].drawPos;
			// cheap reject: well outside even at full size and the largest mid offset
			float reach = radius_params.x + length(radius_params.zw) + pixelSize + 8.0;
			vec2 toUnit = pos - drawPos.xz;
			if (dot(toUnit, toUnit) > reach * reach) {
				continue;
			}
			vec2 front = vec2(sin(drawPos.w), cos(drawPos.w));
			vec2 center = drawPos.xz + front * radius_params.w + vec2(-front.y, front.x) * radius_params.z;
			float sizeFactor = (radius_params.y < -1.0) ? 15.0 - (nowTime + radius_params.y) : nowTime - radius_params.y;
			float radius = radius_params.x * clamp(sizeFactor / 15.0, 0.0, 1.0);
			vec2 toPos = pos - center;
			// the polygon's radius in this direction; vertices sit at (sin, cos) of multiples of `segment`
			float local = mod(atan(toPos.x, toPos.y), segment) - 0.5 * segment;
			float edgeRadius = (radius + 256.0 / (radius + 32.0)) * cos(0.5 * segment) / cos(local);
			float edgeWidth = max(pixelSize, 0.64 * (radius + 16.0) / (radius + 32.0));
			nearest = min(nearest, (length(toPos) - edgeRadius) / edgeWidth);
		}
		return smoothstep(-0.5, 0.5, nearest);
	}
#endif

void main() {
	// sample the stencil texture to determine if this pixel is visible
	#ifdef STENCILPASS
		// if we are in stencil pass, we just output the blended color
		fragColor.rgba = vec4(vec3(v_radius_circum_height.x / 32), 1.0);
	#else
		#ifdef EXACT_CIRCLES
			float smoothstenc = OutsideCircles();
		#else
			//vec2 stencilUV = fract((v_uv_camdist_radius.xy * vec2(1.0/VSX, 1.0/ VSY) - 0.5)); // adjust UV coordinates if needed
			vec2 stencilUV = gl_FragCoord.xy * vec2(1.0/VSX, 1.0/ VSY); // adjust UV coordinates if needed
			float stencilValue = texture(losStencilTexture, stencilUV ).r;

			// if the stencil value is less than 0.5, this pixel is not visible
			//float smoothstenc = 1.0 - smoothstep(0.47, 0.477, stencilValue);
			float smoothstenc = 1.0 - smoothstep(0.49, 0.51, stencilValue);
		#endif
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

		// fully transparent (clipped, thinned away, between dashes): don't let it mark the stencil that keeps overlapping
		// lines from doubling up, or it cuts a gap into the lines drawn later where they cross this one
		if (fragColor.a <= 0.0) {
			discard;
		}
	#endif

}