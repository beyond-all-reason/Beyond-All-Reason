#version 130


varying vec2 texCoord;
void main() {
	texCoord = gl_MultiTexCoord0.st;
	gl_Position = vec4(gl_Vertex.xyz, 1.0);
}