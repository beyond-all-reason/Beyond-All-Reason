uniform sampler2D texture0;
uniform float inverseRX;
uniform float fragKernelRadius;
float bloomSigma = fragKernelRadius / 2.0;

void main(void) {
	vec2 C0 = vec2(gl_TexCoord[0]);

	vec4 S = texture2D(texture0, C0);
	float weight = 1.0 / (2.50663 * bloomSigma);
	float total_weight = weight;
	S *= weight;
	for (float r = 1.5; r < fragKernelRadius; r += 2.0)
	{
		weight = exp(-((r*r)/(2.0 * bloomSigma * bloomSigma)))/(2.50663 * bloomSigma);
		S += texture2D(texture0, C0 - vec2(r * inverseRX, 0.0)) * weight;
		S += texture2D(texture0, C0 + vec2(r * inverseRX, 0.0)) * weight;

		total_weight += 2*weight;
	}

	gl_FragColor = vec4(S.rgb/total_weight, 1.0);
}