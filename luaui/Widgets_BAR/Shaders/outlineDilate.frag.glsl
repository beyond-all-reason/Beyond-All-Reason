#version 150 compatibility

uniform sampler2D depthTex;
uniform sampler2D colorTex;

uniform mat4 projMatrix;

#define DILATE_SINGLE_PASS ###DILATE_SINGLE_PASS###

uniform int dilateHalfKernelSize = 1;

uniform vec2 viewPortSize;
uniform float strength = 1.0;
//layout(pixel_center_integer) in vec4 gl_FragCoord;
//layout(origin_upper_left) in vec4 gl_FragCoord;


#if (DILATE_SINGLE_PASS == 1)
	void main(void)
	{
		ivec4 vpsMinMax = ivec4(0, 0, ivec2(viewPortSize));

		float minDepth = 1.0;
		vec4 maxColor = vec4(0.0);

		ivec2 thisCoord = ivec2(gl_FragCoord.xy);

		vec2 bnd = vec2(dilateHalfKernelSize - 1, dilateHalfKernelSize + 2) * strength;

		for (int x = -dilateHalfKernelSize; x <= dilateHalfKernelSize; ++x) {
			for (int y = -dilateHalfKernelSize; y <= dilateHalfKernelSize; ++y) {

				ivec2 offset = ivec2(x, y);
				/*
				ivec2 samplingCoord = thisCoord + offset;
				bool okCoords = ( all(bvec4(
					greaterThanEqual(samplingCoord, vpsMinMax.xy),
					lessThanEqual(samplingCoord, vpsMinMax.zw) ))
				);

				if (okCoords)*/ {
					minDepth = min(minDepth, texelFetchOffset( depthTex, thisCoord, 0, offset).r);
					vec4 thisColor = texelFetchOffset( colorTex, thisCoord, 0, offset);
					thisColor.a *= smoothstep(bnd.y, bnd.x, sqrt(float(x * x + y * y)));
					maxColor = max(maxColor, thisColor);
				}
			}
		}
		gl_FragDepth = minDepth;
		gl_FragColor = maxColor;
	}
#else //separable vert/horiz passes
	uniform vec2 dir;
	void main(void)
	{
		ivec4 vpsMinMax = ivec4(0, 0, ivec2(viewPortSize));

		float minDepth = 1.0;
		vec4 maxColor = vec4(0.0);

		ivec2 thisCoord = ivec2(gl_FragCoord.xy);

		vec2 bnd = vec2(dilateHalfKernelSize - 1, dilateHalfKernelSize + 2) * strength;

		for (int i = -dilateHalfKernelSize; i <= dilateHalfKernelSize; ++i) {

			ivec2 offset = ivec2(i) * ivec2(dir);
			/*
			ivec2 samplingCoord = thisCoord + offset;
			bool okCoords = ( all(bvec4(
				greaterThanEqual(samplingCoord, vpsMinMax.xy),
				lessThanEqual(samplingCoord, vpsMinMax.zw) ))
			);

			if (okCoords)*/ {
				minDepth = min(minDepth, texelFetchOffset( depthTex, thisCoord, 0, offset).r);
				vec4 thisColor = texelFetchOffset( colorTex, thisCoord, 0, offset);
				thisColor.a *= smoothstep(bnd.y, bnd.x, abs(i));
				maxColor = max(maxColor, thisColor);
			}
		}

		gl_FragDepth = minDepth;
		gl_FragColor = maxColor;
	}
#endif