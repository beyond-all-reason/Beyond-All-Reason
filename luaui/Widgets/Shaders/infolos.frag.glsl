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
		off = (vec2(rand(p.st + off.st), rand(p.ts - off.ts)) * 2.0 - 1.0); 
		off = off / sizes;
		//off = (off * abs(off)) / sizes;
		c += texture2D(tex, p + off * RESOLUTION);
		// USE DFDX!
		
	}
	c *= 1.0/SAMPLES;
	return c;
	//return smoothstep(0.5, 1.0, c);
}


float getTexelF(in sampler2D tex, in vec2 p, in vec2 sizes)
{
	float c = 0.0;
	for (int i = 0; i<SAMPLES; i++) {
		vec2 off = vec2(time + float(i)*0.02);
		off = (vec2(rand(p.st + off.st), rand(p.ts - off.ts)) * 2.0 - 1.0); 
		off = off / sizes;
		//off = (off * abs(off)) / sizes;
		float t = texture2D(tex, p + off * RESOLUTION).r;
		//float tx = dFdx(t);
		//float ty = dFdy(t);
		//vec4 neighbours = vec4(t, t + tx, t + ty, t + tx + ty);
		c += t;
		//c += dot(vec4(0.5, 0.125, 0.125, 0.125), neighbours); 
		// USE DFDX!
		
	}
	c *= 1.0/SAMPLES;
	return smoothstep(0.0, 1.0, c);
}



void main() {
	fragColor  = vec4(0.0);

	float los = getTexelF(tex0, texCoord, vec2(LOSXSIZE,LOSYSIZE) * 2.5);
	float airlos = getTexelF(tex1, texCoord, vec2(AIRLOSXSIZE,AIRLOSYSIZE) * 2.5);
	vec2 radarJammer = getTexel(tex2, texCoord, vec2(RADARXSIZE,RADARYSIZE) * 2.5).rg;
	
	fragColor.r = 0.2 + 0.8 * los; // 0.4
	fragColor.g += 0.2 + 0.8 * airlos;
	
	fragColor.b = 0.2 + 0.8 * clamp(0.75 * radarJammer.r - 0.5 * (radarJammer.g - 0.5),0,1);
	//gl_FragColor.b += radarJammer.r;
	//gl_FragColor.b -= 2*radarJammer.g;
	fragColor.a = outputAlpha;
}