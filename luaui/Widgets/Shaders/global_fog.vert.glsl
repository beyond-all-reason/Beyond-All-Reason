#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

layout (location = 0) in vec4 positionxy_xyfract; // l w rot and maxalpha

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

out DataVS {
	//vec4 v_worldPos;
	vec4 sampleUVs; //xy contains [0,1], however zw contains the pixel adjusted locs 
};

void main()
{
	vec2 screenPos = positionxy_xyfract.xy ;
	gl_Position =  vec4( screenPos.x, screenPos.y, 0.5, 1);
	
	sampleUVs.xy = (screenPos.xy + 1.0 ) * 0.5;
	#if (RESOLUTION == 2)
		#if (HALFSHIFT == 0)
			// Below is correct for halfsizing:
			sampleUVs.zw = vec2(HSX*2.0/VSX, HSY*2.0/VSY) * sampleUVs.xy + vec2(0.0, -(2.0*HSY - VSY)/(VSY)) ;
		#else
			// This is for offsetting
			sampleUVs.zw = vec2(HSX*2.0/VSX, HSY*2.0/VSY) * sampleUVs.xy + vec2(-1.0/VSX, 1.0/VSY);
		#endif
	#endif
}