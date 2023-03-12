#version 150 compatibility
void main(void)
{
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position    = gl_Vertex;
	gl_Position.z  = 0.0; // Can change depth here? hue hue
} 