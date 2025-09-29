#version 150 compatibility

void main() {
	//gl_Position = gl_Vertex;
	gl_Position = vec4(gl_Vertex.xy,0,1);
	gl_TexCoord[0] = gl_MultiTexCoord0;
}
