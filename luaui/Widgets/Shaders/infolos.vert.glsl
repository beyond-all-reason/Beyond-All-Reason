#version 130

// (C) 2022 Beherith (mysterme@gmail.com)
// Licenced under the MIT licence

varying vec2 texCoord;
void main() {
	texCoord = gl_MultiTexCoord0.st;
	gl_Position = vec4(gl_Vertex.xyz, 1.0);
}