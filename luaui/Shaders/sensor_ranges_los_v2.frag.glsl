#version 330
// This shader is (c) Beherith (mysterme@gmail.com)

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000

#ifdef STENCILPASS

#else
	uniform sampler2D losStencilTexture;
#endif 

//__DEFINES__

in DataVS {
	flat vec4 blendedcolor;
	vec4 v_uv;
};

out vec4 fragColor;

	void main() {
	// sample the stencil texture to determine if this pixel is visible
	#ifdef STENCILPASS
		// if we are in stencil pass, we just output the blended color
		fragColor.rgba = vec4(vec3(v_uv.w/32), 1.0);
	#else
		//vec2 stencilUV = fract((v_uv.xy * vec2(1.0/VSX, 1.0/ VSY) - 0.5)); // adjust UV coordinates if needed
		vec2 stencilUV = gl_FragCoord.xy * vec2(1.0/VSX, 1.0/ VSY); // adjust UV coordinates if needed
		float stencilValue = texture(losStencilTexture, stencilUV ).r;
		if (stencilValue > 0.5) {
			// if the stencil value is less than 0.5, this pixel is not visible
			fragColor = vec4(1.0, 0.0, 0.0, 1.0 - stencilValue);

		}else{

			fragColor = vec4(1.0);

		}
		float flatstenc = step(stencilValue* 1.0 , 0.48);
		float smoothstenc = 1.0 - smoothstep(0.47, 0.48, stencilValue);
		fragColor.rgba = vec4(1.0,  flatstenc, 0.0, 1.0);
		//fragColor.rgba = vec4(v_uv.xyz / 1024.0, 1.0);
		fragColor.rgba = vec4(vec3(1.0), 0.5* smoothstenc);
	#endif


}