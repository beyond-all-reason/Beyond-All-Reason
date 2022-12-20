#version 130
//__DEFINES__

uniform float time;
uniform float outputAlpha;
uniform vec2 losTexSize;
uniform vec2 airlosTexSize;
uniform vec2 radarTexSize;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform sampler2D tex2;
in vec2 texCoord;
out vec4 fragColor;


//! source: http://www.ozone3d.net/blogs/lab/20110427/glsl-random-generator/
float rand(const in vec2 n)
{
	return fract(sin(dot(n, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 getTexel(in sampler2D tex, in vec2 p, in vec2 sizes)
{
	vec4 c = vec4(0.0);
	for (int i = 0; i<SAMPLES; i++) {
		vec2 off = vec2(time + float(i)*0.02);
		off = (vec2(rand(p.st + off.st), rand(p.ts - off.ts)) * 2.0 - 1.0) / sizes;
		c += texture2D(tex, p + off * RESOLUTION);
	}
	c *= 1.0/SAMPLES;
	return c;
	//return smoothstep(0.5, 1.0, c);
}


void main() {
	fragColor  = vec4(0.0);

	float los = getTexel(tex0, texCoord, vec2(LOSXSIZE,LOSYSIZE)).r;
	float airlos = getTexel(tex1, texCoord, vec2(AIRLOSXSIZE,AIRLOSYSIZE)).r;
	vec2 radarJammer = getTexel(tex2, texCoord, vec2(RADARXSIZE,RADARYSIZE)).rg;
	
	fragColor.r = los;
	fragColor.g += airlos * 0.33;
	fragColor.b = 0.5;
	fragColor.b += radarJammer.r;
	fragColor.b -= 2*radarJammer.g;
	fragColor.a = outputAlpha;
}