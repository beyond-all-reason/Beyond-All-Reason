#version 420

// Reclaim field highlight: colour and alpha come from the vertex shader.

in vec4 vColor;
out vec4 fragColor;

void main() {
	fragColor = vColor;
}
