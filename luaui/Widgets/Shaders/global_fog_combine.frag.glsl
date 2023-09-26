#version 150 compatibility

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D fogbase;
uniform sampler2D distortion;
uniform float gameframe;
uniform float distortionlevel;
uniform float resolution = 2.0;

//__DEFINES__
// https://github.com/libretro/common-shaders/blob/master/include/quad-pixel-communication.h 

vec2 quadVector;
vec4 get_quad_vector_naive(vec4 output_pixel_num_wrt_uvxy)
	{
		//  Requires:   Two measures of the current fragment's output pixel number
		//              in the range ([0, IN.output_size.x), [0, IN.output_size.y)):
		//              1.) output_pixel_num_wrt_uvxy.xy increase with uv coords.
		//              2.) output_pixel_num_wrt_uvxy.zw increase with screen xy.
		//  Returns:    Two measures of the fragment's position in its 2x2 quad:
		//              1.) The .xy components are its 2x2 placement with respect to
		//                  uv direction (the origin (0, 0) is at the top-left):
		//                  top-left     = (-1.0, -1.0) top-right    = ( 1.0, -1.0)
		//                  bottom-left  = (-1.0,  1.0) bottom-right = ( 1.0,  1.0)
		//                  You need this to arrange/weight shared texture samples.
		//              2.) The .zw components are its 2x2 placement with respect to
		//                  screen xy direction (IN.position); the origin varies.
		//                  quad_gather needs this measure to work correctly.
		//					left-top = (-1.0, 1.0), right-bottom = (1.0, -1.0)  
		//              Note: quad_vector.zw = quad_vector.xy * float2(
		//                      ddx(output_pixel_num_wrt_uvxy.x),
		//                      ddy(output_pixel_num_wrt_uvxy.y));
		//  Caveats:    This function assumes the GPU driver always starts 2x2 pixel
		//              quads at even pixel numbers.  This assumption can be wrong
		//              for odd output resolutions (nondeterministically so).
		vec4 pixel_odd = fract(output_pixel_num_wrt_uvxy * 0.5) * 2.0;
		vec4 quad_vector = pixel_odd * 2.0 - vec4(1.0);
		return quad_vector;
	}
// [-1,1] quad vector as per get_quad_vector_naive
vec2 quadGetQuadVector(vec2 screenCoords){
	vec2 quadVector =  fract(floor(screenCoords) * 0.5) * 4.0 - 1.0;
	vec2 odd_start_mirror = 0.5 * vec2(dFdx(quadVector.x), dFdy(quadVector.y));
	quadVector = quadVector * odd_start_mirror;
	return sign(quadVector);
}

// SEE global_fog.frag.glsl!!!!!
vec4 quadGetThreadMask(vec2 qv){ 
	vec4 threadMask =  step(vec4(qv.xy,0,0),vec4( 0,0,qv.xy));
	return threadMask.xzxz * threadMask.yyww;
}

vec4 quadGather(float input, vec2 qv){
		float inputadjx = input - dFdx(input) * quadVector.x;
		float inputadjy = input - dFdy(input) * quadVector.y;
		float inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return vec4(input, inputadjx, inputadjy, inputdiag);
}

// takes a gentype, and gathers and sums it from adjacent fragments
float quadGatherSumFloat(float input){
		float inputadjx = input - dFdx(input) * quadVector.x;
		float inputadjy = input - dFdy(input) * quadVector.y;
		float inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return dot( vec4(input, inputadjx, inputadjy, inputdiag), vec4(0.25));
}


vec2 quadGatherSum2D(vec2 input){
		vec2 inputadjx = input - dFdx(input) * quadVector.x;
		vec2 inputadjy = input - dFdy(input) * quadVector.y;
		vec2 inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return vec2(
			dot( vec4(input.x, inputadjx.x, inputadjy.x, inputdiag.x), vec4(1.0)),
			dot( vec4(input.y, inputadjx.y, inputadjy.y, inputdiag.y), vec4(1.0))
			);
}
vec4 quadGatherSum4D(vec4 input){
		vec4 inputadjx = input - dFdx(input) * quadVector.x;
		vec4 inputadjy = input - dFdy(input) * quadVector.y;
		vec4 inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return vec4(
			dot( vec4(input.x, inputadjx.x, inputadjy.x, inputdiag.x), vec4(1.0)),
			dot( vec4(input.y, inputadjx.y, inputadjy.y, inputdiag.y), vec4(1.0)),
			dot( vec4(input.z, inputadjx.z, inputadjy.z, inputdiag.z), vec4(1.0)),
			dot( vec4(input.w, inputadjx.w, inputadjy.w, inputdiag.w), vec4(1.0))
			);
}

vec4 debugQuad(vec2 qv){
	// Returns a checkerboard pattern of quads. Yay?
	vec2 sharedCoords = quadGatherSum2D(gl_FragCoord.xy);
	float quadAlpha = 0.0;
	if (fract((sharedCoords.x + sharedCoords.y) * 0.2) > 0.25) quadAlpha = 1.0;
	vec3 QVC = vec3(// [[BR],[GY]]
		qv.x > 0 ? 1: 0,
		qv.y < 0 ? 1: 0,
		(qv.x < 0 && qv.y >0) ? 1 : 0
	);
	return vec4(QVC,quadAlpha);
}

void main(void) {
	if (abs(resolution - 2.0) > 0.01){
		gl_FragColor = texture2D(fogbase, gl_TexCoord[0].st);
		//gl_FragColor = texelFetch(fogbase, ivec2(gl_TexCoord[0].st * (vec2(VSX,VSY) ) /int(resolution) ),0); return; // for debugging!
		
	}else{ // this part only works with half-rez!
		vec2 screenUVTexelCentered = gl_TexCoord[0].st; // This matches gl_FragCoord.xy/viewSizes, so it is texel centered
		
		quadVector = quadGetQuadVector(gl_FragCoord.xy);	
		//gl_FragColor.rgba = debugQuad(quadVector);return;
	  
		float mapdepth = texture(mapDepths, screenUVTexelCentered).x;
		float modeldepth = texture(modelDepths, screenUVTexelCentered).x;

		float screendepth = min(mapdepth, modeldepth);
		
		// Convert to approximate depth metric
		float ndc = screendepth * 2.0 - 1.0;   
		float near = 0.1; 
		float far  = 100.0; 
		float linearDepth = (2.0 * near * far) / (far + near - ndc * (far - near)) * 100;	// wow this is almost elmos resolution!
		
		// Calculate Derivatives
		float dx = dFdx(linearDepth); // positive if right pixel is bigger
		float dy = dFdy(linearDepth); // positive if top pixel is more
		
		// Indicators
		float ismodel = step(modeldepth + 0.00001, mapdepth);
		float modelpercent = quadGatherSumFloat(ismodel);
		float discontinuity = step(32,abs(dx) + abs(dy));
		
		// Define our "base" fog UV coords
		vec2 fogUV = gl_TexCoord[0].zw;
		//gl_FragColor = texture(fogbase, fogUV); return;
		
		// Try to gather all 4 neighbour fog alphas:
		vec2 quadShift = (0.5 / vec2(1*VSX, VSY)) * (quadVector * vec2(1.0, 1.0));
		vec4 quadFog = texture(fogbase, fogUV + quadShift);
		//gl_FragColor = quadFog; return;
		
		// get the local fog colors, linearly smoothed
		quadFog.rgb = texture(fogbase, fogUV).rgb;
		
		// what if, according to my own quad, we sampled once very far out per quad?
		// THIS IS THE GOLDEN SAMPLE!
		vec4 smoothcolor = quadGatherSum4D(texture(fogbase, fogUV + 3*quadShift)) * 0.25;
		quadFog.rgb = mix(smoothcolor.rgb, quadFog.rgb,  0.7 * discontinuity + 0.3);
		
		
		
		
		gl_FragColor = quadFog;
		//gl_FragColor = smoothcolor; return;
		
		vec4 gatherAlpha = quadGather(quadFog.a, quadVector);
		float minAlpha =  min(min(gatherAlpha.x,gatherAlpha.y),	min(gatherAlpha.z,gatherAlpha.w));
		float maxAlpha =  max(max(gatherAlpha.x,gatherAlpha.y),	max(gatherAlpha.z,gatherAlpha.w));
		
		// Proper bilinear smoothing vector:
		#define F 0.75
		vec4 smoothingvec = vec4(F*F, F*(1.0-F), F*(1.0-F), (1.0-F)*(1.0-F)); // F*F, F*(1.0-F), F*(1.0-F), (1-F)*(1-F)
		
		float localsmoothalpha = dot(gatherAlpha, smoothingvec);
		
		gl_FragColor.a = localsmoothalpha;


		if (discontinuity < 0.5){ // NOT discontinous
			if (modelpercent > 0.33) gl_FragColor.a = minAlpha;
			
			//gl_FragColor.a = (ismodel > 0.5 ? minAlpha :maxAlpha);
		}else{ // has a discontinuity
			//TODO: also modulate color!
			
			if (ismodel > 0.2) gl_FragColor.a = minAlpha;
			else{
			
				//if (dy * quadVector.y > 32 ) gl_FragColor.a = maxAlpha;
				//if (dy * quadVector.y < -32 ) gl_FragColor.a = minAlpha;
				
				//if (dx * quadVector.x > 32 ) gl_FragColor.a = maxAlpha;
				//if (dx * quadVector.x < -32 ) gl_FragColor.a = minAlpha;
				
				
				if (dx > 32) gl_FragColor.a = maxAlpha;
				if (dx < -32) gl_FragColor.a = minAlpha;
			
				//if (dx > 32) gl_FragColor.a = maxAlpha;
				//if (dx < -32) gl_FragColor.a = minAlpha;
			
			}
			//else gl_FragColor.a = maxAlpha;
			// Need to order fucking pixels within a quad? for fuck's sake
		}
		
		
		//gl_FragColor.r += step(modeldepth, mapdepth);
		gl_FragColor.a = min(gl_FragColor.a, 0.99) ;
		//gl_FragColor.a = gatherAlpha.a;
	}
}