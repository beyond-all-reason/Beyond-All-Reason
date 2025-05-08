#version 430 core
//__DEFINES__

//__ENGINEUNIFORMBUFFERDEFS__
uniform float time;
uniform float outputAlpha;
uniform vec2 losTexSize;
uniform vec2 airlosTexSize;
uniform vec2 radarTexSize;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform sampler2D tex2;

in DataVS {
    vec4 texCoord;
};
out vec4 fragColor;
/*
// from http://www.java-gaming.org/index.php?topic=35123.0
vec4 cubic(float v){
    vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 s = n * n * n;
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return vec4(x, y, z, w) * (1.0/6.0);
}

//https://stackoverflow.com/questions/13501081/efficient-bicubic-filtering-code-in-glsl
vec4 textureBicubic(sampler2D sampler, vec2 texCoords){

   vec2 texSize = textureSize(sampler, 0);
   vec2 invTexSize = 1.0 / texSize;
   
   texCoords = texCoords * texSize - 0.5;

   
    vec2 fxy = fract(texCoords);
    texCoords -= fxy;

    vec4 xcubic = cubic(fxy.x);
    vec4 ycubic = cubic(fxy.y);

    vec4 c = texCoords.xxyy + vec2 (-0.5, +1.5).xyxy;
    
    vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
    vec4 offset = c + vec4 (xcubic.yw, ycubic.yw) / s;
    
    offset *= invTexSize.xxyy;
    
    vec4 sample0 = texture(sampler, offset.xz);
    vec4 sample1 = texture(sampler, offset.yz);
    vec4 sample2 = texture(sampler, offset.xw);
    vec4 sample3 = texture(sampler, offset.yw);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix(
       mix(sample3, sample2, sx), mix(sample1, sample0, sx)
    , sy);
}

*/


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
		c += texture(tex, p + off * RESOLUTION);
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
		float t = texture(tex, p + off * RESOLUTION).r;
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

// This is the fake cubic blending function, which is extremely useful for upsizing without bilinear artifacts
// Could be done ass-backwards if needed
float gatherBlend(vec4 samples, vec2 coords, vec2 sizes)
{
	vec2 fracCoords = fract(coords * sizes + vec2(0.5));
	fracCoords = smoothstep(0.0, 1.0, fracCoords);	

	vec2 mixx = mix(samples.ra, samples.gb, fracCoords.x);
	float mixy = mix(mixx.y, mixx.x, fracCoords.y);
	
	//printf(fracCoords.xy);
	#define THRESHOLD 0.2
	return smoothstep(THRESHOLD, 1.0 - THRESHOLD, mixy);
}	


// These sampler functions are for smooth magnification via cubic blending, and are better than the gatherBlend approach, cause its way less samples

vec2 CubicSampler(vec2 uvsin, vec2 texdims){
    vec2 r = uvsin * texdims - 0.5;
    vec2 tf = fract(r);
    vec2 ti = r - tf;
    tf = tf * tf * (3.0 - 2.0 * tf);
    return (tf + ti + 0.5)/texdims;
}

vec2 QuinticSampler(vec2 uvsin, vec2 texdims){
    vec2 r = uvsin * texdims - 0.5;
    vec2 tf = fract(r);
    vec2 ti = r - tf;
    tf = tf * tf * tf * (tf * (6.0 * tf - 15.0) + 10.0);
    return (tf + ti + 0.5)/texdims;
}

vec2 OctalSampler(vec2 uvsin, vec2 texdims){
    vec2 r = uvsin * texdims - 0.5;
    vec2 tf = fract(r);
    vec2 ti = r - tf;
    tf = tf * tf * (3.0 - 2.0 * tf);
    tf = tf * tf * tf * (tf * (6.0 * tf - 15.0) + 10.0);
    return (tf + ti + 0.5)/texdims;
}

void main() {
	fragColor  = vec4(0.0);
	#if (EXACT == 0)
		float los = getTexelF(tex0, texCoord.xy, vec2(LOSXSIZE,LOSYSIZE) * 2.);
		float airlos = getTexelF(tex1, texCoord.xy, vec2(AIRLOSXSIZE,AIRLOSYSIZE) * 2.5);
		vec2 radarJammer = getTexel(tex2, texCoord.xy, vec2(RADARXSIZE,RADARYSIZE) * 2.5).rg;
		fragColor.r = 0.2 + 0.8 * los; // 0.4
		fragColor.g += 0.2 + 0.8 * airlos;
		
		fragColor.b = 0.2 + 0.8 * clamp(0.75 * radarJammer.r - 0.5 * (radarJammer.g - 0.5),0,1);
		//gl_FragColor.b += radarJammer.r;
		//gl_FragColor.b -= 2*radarJammer.g;
		fragColor.a = outputAlpha;
	#else
		// textureGather returns in rgba order, TL, TR, BR, BL
		/*
		vec4 los_samples = textureGather(tex0, texCoord.xy, 0);
		vec4 airlos_samples = textureGather(tex1, texCoord.xy, 0);
		vec4 radar_samples = textureGather(tex2, texCoord.xy, 0);
		vec4 jammer_samples = textureGather(tex2, texCoord.xy, 1);


		float smooth_los = gatherBlend(los_samples, texCoord.xy, vec2(LOSXSIZE,LOSYSIZE));
		float smooth_airlos = gatherBlend(airlos_samples, texCoord.xy, vec2(AIRLOSXSIZE,AIRLOSYSIZE));
		float smooth_radar = gatherBlend(radar_samples, texCoord.xy, vec2(RADARXSIZE,RADARYSIZE));
		float smooth_jammer = gatherBlend(jammer_samples, texCoord.xy, vec2(RADARXSIZE,RADARYSIZE));
		*/
		
		float smooth_los = textureLod(tex0, QuinticSampler(texCoord.xy, vec2(LOSXSIZE, LOSYSIZE)), 0).r;
		smooth_los = smoothstep(0.0, 1.0, smooth_los);
		float smooth_airlos = textureLod(tex1, CubicSampler(texCoord.xy, vec2(AIRLOSXSIZE, AIRLOSYSIZE)), 0).r;
		//smooth_los = smoothstep(0.0, 1.0, smooth_los);
		vec2 smooth_radars = textureLod(tex2, CubicSampler(texCoord.xy, vec2(RADARXSIZE, RADARYSIZE)), 0).rg;
		//smooth_radars = smoothstep(0.0, 1.0, smooth_radars);
		//fragColor.rgb = fract(texCoord.xyz * 10.0);
		//fragColor.rgb = vec3(smooth_los);

		fragColor.r = 0.2 + 0.8 * smooth_los; // 0.4
		fragColor.g += 0.2 + 0.8 * smooth_airlos;
		fragColor.b = 0.2 + 0.8 * clamp(0.75 * smooth_radars.r - 0.5 * (smooth_radars.g - 0.5),0,1);
		fragColor.a = outputAlpha;
		return;

	#endif
		//fragColor.rgb = fract(texCoord.xyz * 10.0);
		//fragColor.a = 1.0;
	
}