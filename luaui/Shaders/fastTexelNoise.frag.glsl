
uniform sampler2D offsetPixelNoise;

// for a texture size of 255, this is actually the best!

// return t * t * (3.0 - 2.0 * t);

float samplenoise(vec2 worldpos){
	#define texSizeMinus1 127
	vec2 interp254 = fract(worldpos) * texSizeMinus1;
	vec2 interp = fract(interp254);
	ivec2 nuv = ivec2(interp254);

	vec4 neighbours = texelFetch(offsetPixelNoise, nuv, 0);
	
	// interpolate in 1st dirs
	vec2 smooth2 = smoothstep(neighbours.rg, neighbours.ba, interp.xx); // 
	return smoothstep(smooth2.x, smooth2.y, interp.y); // 

}