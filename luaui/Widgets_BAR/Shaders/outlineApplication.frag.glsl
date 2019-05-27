#version 150 compatibility

uniform sampler2D tex;
uniform sampler2D modelDepthTex;
uniform sampler2D mapDepthTex;

uniform float strength = 1.0;

void main() {
	ivec2 imageCoord = ivec2(gl_FragCoord.xy);

	vec4 color = texelFetch(tex, imageCoord, 0);
	float modelDepth = texelFetch(modelDepthTex, imageCoord, 0).r;
	float mapDepth = texelFetch(mapDepthTex, imageCoord, 0).r;

	gl_FragColor = mix(vec4(0.0), color, vec4(strength));
	gl_FragDepth = mix(modelDepth, mapDepth, 2.0);	//bullshit but works somehow
}