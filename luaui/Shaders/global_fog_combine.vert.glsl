#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

layout (location = 0) in vec4 posuv; // l w rot and maxalpha

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

uniform float resolution = 2.0;

out DataVS {
	//vec4 v_worldPos;
	vec4 sampleUVs; //xy contains [0,1], however zw contains the pixel adjusted locs 
};


void main(void)
{
	sampleUVs = posuv.zwzw;
	
	// upscale filter
	#if (HALFSHIFT == 0)
		// Correct for upsizing:
		sampleUVs.zw = vec2(VSX/(2.0*HSX), VSY/(2.0*HSY)) * sampleUVs.xy + vec2(0, 1.0*(2.0*HSY - VSY)/(VSY)) ;
	#else
		// This is for offsetting
		
		// below is correct when VSY is even
		sampleUVs.zw = vec2(VSX/(2.0*HSX), VSY/(2.0*HSY)) * sampleUVs.xy + vec2(1.0/VSX, 1.0/VSY) ;
		
		// When VSY is odd:
		sampleUVs.zw = vec2(VSX/(2.0*HSX), VSY/(2.0*HSY)) * sampleUVs.xy + vec2(1.0/VSX, - 1.0/VSY) ;
		
		// WTF WHY IS VSX ZERO? ARE QUADS STARTING SOMEWHERE ELSE?
		sampleUVs.zw = vec2(VSX/(2.0*HSX), VSY/(2.0*HSY)) * sampleUVs.xy + vec2(0.0/VSX, - 1.0/VSY) ;
		sampleUVs.zw = vec2(VSX/(2.0*HSX), VSY/(2.0*HSY)) * sampleUVs.xy + vec2(.0/VSX, - 1.0/VSY) ;

		
			// new approach which does not allow odd, half sized textures
			// on the X axis, we need to increase the size of the view, and offset it 
			// we must map the input 0-1 range.
		sampleUVs.z = sampleUVs.x * (VSX / (HSX * 2.0 ) ) + ((1.0 + OFFSETX)/VSX);

		//remainder = (2 * HSY - VSY - 1.0)
		
		sampleUVs.w = sampleUVs.y * (VSY / (HSY * 2.0 ) ) - ((2 * HSY - VSY - 1.0 + OFFSETY)/VSY);

		//
	#endif

	gl_Position.w = 1.0;
	gl_Position.xy    = posuv.xy;
	gl_Position.z  = 0.0; // Can change depth here? hue hue
} 