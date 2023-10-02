#version 150 compatibility

//__DEFINES__

uniform float resolution = 2.0;

void main(void)
{
	gl_TexCoord[0] = gl_MultiTexCoord0;
	
	// upscale filter
	#if (HALFSHIFT == 0)
		// Correct for upsizing:
		gl_TexCoord[0].zw = vec2(VSX/(2.0*HSX), VSY/(2.0*HSY)) * gl_TexCoord[0].xy + vec2(0, 1.0*(2.0*HSY - VSY)/(VSY)) ;
	#else
		// This is for offsetting
		
		// below is correct when VSY is even
		gl_TexCoord[0].zw = vec2(VSX/(2.0*HSX), VSY/(2.0*HSY)) * gl_TexCoord[0].xy + vec2(1.0/VSX, 1.0/VSY) ;
		
		// When VSY is odd:
		gl_TexCoord[0].zw = vec2(VSX/(2.0*HSX), VSY/(2.0*HSY)) * gl_TexCoord[0].xy + vec2(1.0/VSX, - 1.0/VSY) ;
		
		// WTF WHY IS VSX ZERO? ARE QUADS STARTING SOMEWHERE ELSE?
		gl_TexCoord[0].zw = vec2(VSX/(2.0*HSX), VSY/(2.0*HSY)) * gl_TexCoord[0].xy + vec2(0.0/VSX, - 1.0/VSY) ;
		gl_TexCoord[0].zw = vec2(VSX/(2.0*HSX), VSY/(2.0*HSY)) * gl_TexCoord[0].xy + vec2(1.0/VSX, - 0.0/VSY) ;
	#endif

	
	gl_Position    = gl_Vertex;
	gl_Position.z  = 0.0; // Can change depth here? hue hue
} 