#version 120
// gl.GhostRaw supplies static geometry through compatibility attributes on both renderers.
uniform mat4 viewInverse;
varying vec3 worldNormal;
varying float worldHeight;
varying vec2 uv;
varying float fogFactor;
void main()
{
	vec4 eyePos = gl_ModelViewMatrix * gl_Vertex;
	worldHeight = (viewInverse * eyePos).y;
	worldNormal = mat3(viewInverse) * gl_NormalMatrix * gl_Normal;
	uv = gl_MultiTexCoord0.st;
	fogFactor = clamp((gl_Fog.end - length(eyePos.xyz)) * gl_Fog.scale, 0.0, 1.0);
	gl_Position = gl_ProjectionMatrix * eyePos;
}
