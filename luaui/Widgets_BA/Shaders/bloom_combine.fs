uniform sampler2D texture0;
uniform sampler2D texture1;
uniform float fragMaxBrightness;
uniform int useBloom;

vec3 toneMapEXP(vec3 color){
	return vec3(1.0) - exp(-color * 1.4);
}

vec3 toneMapReinhard(vec3 color){
	// float whitePoint = 1.0/exposure;
	const float whitePoint = 1.0;
	float lum = dot(color, vec3(0.2990, 0.5870, 0.1140));
	float ilum = (lum * (1.0 + (lum/(whitePoint * whitePoint))))/(lum + 1.0);
	return color * ilum/lum;
}

vec3 levelsControl(vec3 color, float blackPoint, float whitePoint){
	return min(max(color - vec3(blackPoint), vec3(0.0)) / (vec3(whitePoint) - vec3(blackPoint)), vec3(1.0));
}

vec3 saturate(vec3 color, float saturation){
	return mix(vec3(dot(color, vec3(0.299, 0.587, 0.114))), color, saturation);
}

void main(void) {
	vec2 C0 = vec2(gl_TexCoord[0]);
	vec4 hdr = bool(useBloom) ? texture2D(texture0, C0) + (texture2D(texture1, C0) * fragMaxBrightness) : texture2D(texture0, C0);

	// white point correction
	// give super bright lights a white shift
	const float whiteStart = 1.0; // the minimum color intensity for starting white point transition
	const float whiteMax = 0.85; // the maximum amount of white shifting applied
	const float whiteScale = 10.0; // the rate at which to transition to white
	
	float mx = max(hdr.r, max(hdr.g, hdr.b));
	if (mx > whiteStart) {
		hdr.rgb = mix(hdr.rgb, vec3(mx), (mx - whiteStart)/(((mx - whiteStart) * whiteScale) + 1.0));
	}

	// tone mapping and color correction
	hdr.rgb = toneMapReinhard(hdr.rgb);
	
	//Experimental exponential exposure tone mapping. It produces much smoother lighting 
	// but causes HSV shifting in the resulting color which is difficult to correct and impossible to correct completely.
	//hdr.rgb = toneMapEXP(hdr.rgb);
	//hdr.rgb = levelsControl(hdr.rgb, 0.15, 0.85);
	//hdr.rgb = saturate(hdr.rgb, 1.05);

	vec4 map = vec4(hdr.rgb, 1.0);
					
	gl_FragColor = map;
}
