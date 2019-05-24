#version 150 compatibility

uniform sampler2D tex;
uniform sampler2D modelDepthTex;

void main() {
	ivec2 imageCoord = ivec2(gl_FragCoord.xy);

	vec4 color = texelFetch(tex, imageCoord, 0);
	float modelDepth = texelFetch(modelDepthTex, imageCoord, 0).r;

	vec4 mixVal = vec4(modelDepth == 1.0); //outside of any existing model shapes

	gl_FragColor = mix(vec4(0.0), color, mixVal);
}