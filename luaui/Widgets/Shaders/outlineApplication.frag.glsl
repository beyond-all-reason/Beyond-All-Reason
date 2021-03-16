#version 150 compatibility

uniform sampler2D dilatedDepthTex;
uniform sampler2D dilatedColorTex;
uniform sampler2D shapeDepthTex;
uniform sampler2D mapDepthTex;

uniform float strength = 1.0;
uniform float alwaysShowOutLine = 0.0;

const float eps = 1e-3;
//layout(pixel_center_integer) in vec4 gl_FragCoord;
//layout(origin_upper_left) in vec4 gl_FragCoord;

void main() {
	ivec2 imageCoord = ivec2(gl_FragCoord.xy);

	vec4 dilatedColor = texelFetch(dilatedColorTex, imageCoord, 0);
	dilatedColor.a *= strength;

	float dilatedDepth = texelFetch(dilatedDepthTex, imageCoord, 0).r;
	float shapeDepth = texelFetch(shapeDepthTex, imageCoord, 0).r;
	float mapDepth = texelFetch(mapDepthTex, imageCoord, 0).r;

	bool cond = (shapeDepth == 1.0);
	float depthToWrite = mix(dilatedDepth, 0.0, alwaysShowOutLine);

	gl_FragColor = mix(vec4(0.0), dilatedColor, float(cond));
	gl_FragDepth = mix(1.0, depthToWrite, float(cond));
}
