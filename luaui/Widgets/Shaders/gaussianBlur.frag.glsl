#version 150 compatibility

uniform sampler2D tex;

uniform float offsets[###BLUR_HALF_KERNEL_SIZE###];
uniform float weights[###BLUR_HALF_KERNEL_SIZE###];

uniform vec2 dir;

uniform vec2 viewPortSize;

void main(void)
{
	vec2 uv = gl_FragCoord.xy / viewPortSize;
	vec4 acc = texture( tex, uv ) * weights[0];
	float okCoords;

	for (int i = 1; i < ###BLUR_HALF_KERNEL_SIZE###; ++i) {
		vec2 uvOff = offsets[i] * dir / viewPortSize;
		vec2 uvP = uv + uvOff;
		vec2 uvN = uv - uvOff;

		float weightP = weights[i];
		float weightN = weights[i];

		okCoords = float( all(bvec4( greaterThanEqual(uvP, vec2(0.0)), lessThanEqual(uvP, vec2(1.0)) )) );
		weightP *= okCoords;

		okCoords = float( all(bvec4( greaterThanEqual(uvN, vec2(0.0)), lessThanEqual(uvN, vec2(1.0)) )) );
		weightN *= okCoords;

		acc += texture( tex, uvP ) * weightP;
		acc += texture( tex, uvN ) * weightN;
	}

	gl_FragColor = acc;
}