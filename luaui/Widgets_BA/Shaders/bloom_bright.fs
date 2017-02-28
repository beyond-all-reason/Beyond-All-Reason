uniform sampler2D texture0;
uniform float illuminationThreshold;
uniform float inverseRX;
uniform float inverseRY;

void main(void) {
	vec2 C0 = vec2(gl_TexCoord[0]);
	vec3 color = vec3(texture2D(texture0, C0));
	float illum = dot(color, vec3(0.2990, 0.5870, 0.1140));
	vec3 luma = vec3(0.2990, 0.5870, 0.1140);

	if (illum > illuminationThreshold) {
		// tone mapping, because running blurs on HDR float textures would be expensive.
		color = color - color*(illuminationThreshold/max(illum, 0.00001));
		// color = vec3(1.0) - exp(-color * 1.5);
		// color = mix(vec3(dot(color, vec3(0.299, 0.587, 0.114))), color, 1.15); // increase saturation because exponential exposure reduces it.
		gl_FragColor = vec4(color, 1.0);
	} else {
		gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
	}
}
