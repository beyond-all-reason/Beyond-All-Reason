#version 120

uniform vec4 u_color;
varying vec4 worldPos;
varying vec4 vColor;

void main() {
    // 1. Pass the raw world position to the fragment shader
    worldPos = gl_Vertex;

    // 2. Pass the color
    vColor = u_color;

    // 3. Transform position for the camera
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
