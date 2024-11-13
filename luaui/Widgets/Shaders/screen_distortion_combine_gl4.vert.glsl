#version 150 compatibility

//__DEFINES__

void main(void)	{
    gl_TexCoord[0] = vec4(gl_Vertex.zwzw);
    gl_Position    = vec4(gl_Vertex.xy * 1.0, 0.00, 1);	
}