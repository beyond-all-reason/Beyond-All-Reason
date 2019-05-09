#version 150 compatibility

uniform sampler2D tex;

uniform float offsets[###HALF_KERNEL_SIZE###];
uniform float weights[###HALF_KERNEL_SIZE###];

uniform vec2 dir;

uniform vec2 viewPortSize;

void main(void)
{
	vec2 uv = gl_FragCoord.xy / viewPortSize;
	vec4 acc = texture( tex, uv ) * weights[0];
	float okCoords;

	for (int i = 1; i < ###HALF_KERNEL_SIZE###; ++i) {
		vec2 uvOff = offsets[i] * dir / viewPortSize;
		vec2 uvP = uv + uvOff;
		vec2 uvN = uv - uvOff;

		okCoords = float( all(bvec4( greaterThanEqual(uvP, vec2(0.0)), lessThanEqual(uvP, vec2(1.0)) )) );
		acc += texture( tex, uvP ) * weights[i] * okCoords;

		okCoords = float( all(bvec4( greaterThanEqual(uvN, vec2(0.0)), lessThanEqual(uvN, vec2(1.0)) )) );
		acc += texture( tex, uvN ) * weights[i] * okCoords;
	}

	gl_FragColor = acc;
}