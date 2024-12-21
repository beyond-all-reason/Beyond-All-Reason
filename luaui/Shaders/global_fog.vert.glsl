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
			
			// old approach which allowed odd sized halfsize textures
			//sampleUVs.zw = vec2(HSX*2.0/VSX, HSY*2.0/VSY) * sampleUVs.xy + vec2(-1.0/VSX, 1.0/VSY);

			// new approach which does not allow odd, half sized textures
			// on the X axis, we need to increase the size of the view, and offset it 
			// we must map the input 0-1 range.
			sampleUVs.z = sampleUVs.x * (HSX * 2.0 / VSX) - ((1.0+OFFSETX)/VSX);

			sampleUVs.w = sampleUVs.y * (HSY * 2.0 / VSY) + ((2 * HSY - VSY - 1.0 + OFFSETY) /VSY);
			/*
			
			#if ((2 * HSY - VSY) == 1) // we need it to be 1 bigger in Y, e.g. VSY = 7, HSY = 4 
				sampleUVs.w = sampleUVs.y * (HSY * 2.0 / VSY) + (0.0 /VSY);
			#endif

			#if ((2 * HSY - VSY) == 2) // we need it to be 2 bigger in Y, e.g. VSY = 6, HSY = 4 
				sampleUVs.w = sampleUVs.y * (HSY * 2.0 / VSY) + (-1.0 /VSY);
			#endif

			#if ((2 * HSY - VSY) == 2) // we need it to be 3 bigger in Y, e.g. VSY = 5, HSY = 4 
				sampleUVs.w = sampleUVs.y * (HSY * 2.0 / VSY) + (-2.0 /VSY);
			#endif

			#if ((2 * HSY - VSY) == 4) // we need it to be 3 bigger in Y, e.g. VSY = 4, HSY = 4 
				sampleUVs.w = sampleUVs.y * (HSY * 2.0 / VSY) + (-3.0 /VSY);
			#endif
			*/

			//sampleUVs.zw = vec2(HSX*2.0/VSX, HSY*2.0/VSY) * sampleUVs.xy + vec2(-1.0/VSX, 1.0/VSY);

		#endif
	#endif
}