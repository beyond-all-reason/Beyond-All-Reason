#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D fogbase;
uniform float gameframe;
uniform float resolution = 2.0;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__
// https://github.com/libretro/common-shaders/blob/master/include/quad-pixel-communication.h 

in DataVS {
	vec4 sampleUVs;
};
out vec4 fragColor;

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
float quadGatherMean(float input){
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
#define WF 0.56
//vec4 selfWeights = vec4(WEIGHTFACTOR*WEIGHTFACTOR, WEIGHTFACTOR*(1.0-WEIGHTFACTOR), WEIGHTFACTOR*(1.0-WEIGHTFACTOR), (1.0-WEIGHTFACTOR)*(1.0-WEIGHTFACTOR)); // F*F, F*(1.0-F), F*(1.0-F), (1-F)*(1-F)
vec4 selfWeights = vec4(WF*WF, WF*(1.0-WF), WF*(1.0-WF), (1.0-WF)*(1.0-WF)); // F*F, F*(1.0-F), F*(1.0-F), (1-F)*(1-F)

vec4 quadGatherWeighted4D(vec4 input){
		vec4 inputadjx = input - dFdx(input) * quadVector.x;
		vec4 inputadjy = input - dFdy(input) * quadVector.y;
		vec4 inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return vec4(
			dot( vec4(input.x, inputadjx.x, inputadjy.x, inputdiag.x), selfWeights),
			dot( vec4(input.y, inputadjx.y, inputadjy.y, inputdiag.y), selfWeights),
			dot( vec4(input.z, inputadjx.z, inputadjy.z, inputdiag.z), selfWeights),
			dot( vec4(input.w, inputadjx.w, inputadjy.w, inputdiag.w), selfWeights)
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


#define gamma 2.2
vec3 LINEARtoSRGB(vec3 c) {
	if (gamma == 1.0)
		return c;

	float invGamma = 1.0 / gamma;
	return pow(c, vec3(1.0 / 2.2));
}
vec3 Reinhard(const vec3 x) {
	// Reinhard et al. 2002, "Photographic Tone Reproduction for Digital Images", Eq. 3
	return pow((x / (1.0 + dot(vec3(0.2126, 0.7152, 0.0722), x))), vec3(1.0 / 2.2));
}



void main(void) {
	if (abs(resolution - 2.0) > 0.01){
		fragColor = texture2D(fogbase, sampleUVs.st);
		//fragColor = texelFetch(fogbase, ivec2(sampleUVs.st * (vec2(VSX,VSY) ) /int(resolution) ),0); return; // for debugging!
		
	}else{ // this part only works with half-rez!
		vec2 screenUVTexelCentered = sampleUVs.xy; // This matches gl_FragCoord.xy/viewSizes, so it is texel centered
		
		quadVector = quadGetQuadVector(gl_FragCoord.xy);	
		//fragColor.rgba = debugQuad(quadVector);return;
	  	
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
		float dd = dx - dFdy(dx);
		
		// Indicators
		float ismodel = step(modeldepth + 0.00001, mapdepth); // is 1 if we are processing a model fragment
		float modelpercent = quadGatherMean(ismodel); // [0-1] depending on #model fragments in quad
		float discontinuity = step(32,abs(dx) + abs(dy)); // 0 or 1 if we have any discontinuity here or in immediate neighbours. (NOTE THAT THIS IS NOT QUAD LEVEL, as diagonal is not taken into account!)
		
		//printf(modelpercent);
		
		vec2 fogUVLocal = sampleUVs.zw;
		// the quadshift vector points outward from each quad pixel, exactly to the center of the halfsize pixel
		vec2 quadShift = (0.5 / vec2(1*VSX, VSY)) * (quadVector * vec2(1.0, 1.0));

		if (discontinuity < 0.5){ // NOT discontinous // we can win a few hundred ms here
			if (modelpercent < 0.2) {
				// This is exploiting the hardware sampler in a very nasty fashion by the way...
				vec4 fogSampleLocal = texture(fogbase, fogUVLocal - 0.5*quadShift); 
				// THIS EARLY BAIL IS SUPER NICE, BUT DOES NOT SOLVE THE BILATERAL FILTERING PROBLEM!
				fragColor = vec4(fogSampleLocal.rgb * fogSampleLocal.a, fogSampleLocal.a); return;
			}
		}
		// Define our "base" fog UV coords, these are the UV coordinates that are not at precise halfsize texel centers, but interpolated at about 0.75 close to nearest halfsize texel
		//printf(discontinuity);
	
		vec4 fogSampleLocal = texture(fogbase, fogUVLocal); 

		// Debug base fog uv coords:
		//fragColor = vec4(fogSampleLocal.rgb * fogSampleLocal.a, fogSampleLocal.a); return;
		
		// QuadShift is a vector pointing from our texel center to the center of the nearest halfsize full texel center. 
		vec4 fogSampleNearestTexelCenter = texture(fogbase, fogUVLocal + quadShift);
		
		// Debug nearest texel center sample:
		//fragColor = vec4(fogSampleNearestTexelCenter.rgb * fogSampleNearestTexelCenter.a, fogSampleNearestTexelCenter.a); return;
		
		// what if, according to my own quad, we sampled once very far out per quad, essentially smoothing out 4 texels
		// THIS IS THE GOLDEN SAMPLE!
		vec4 fogSampleSmoothed = texture(fogbase, fogUVLocal + 3*quadShift);

		// Debug smoothed sample:
		//fragColor = vec4(fogSampleSmoothed.rgb * fogSampleSmoothed.a, fogSampleSmoothed.a); return;

		// Collect the smoothed sample, one by one:
		vec4 smoothWeights = selfWeights;
		vec4 fogSampleSmoothedAdjX = fogSampleSmoothed     - dFdx(fogSampleSmoothed) * quadVector.x;
		vec4 fogSampleSmoothedAdjY = fogSampleSmoothed     - dFdy(fogSampleSmoothed) * quadVector.y;
		vec4 fogSampleSmoothedDiag = fogSampleSmoothedAdjX - dFdy(fogSampleSmoothedAdjX) * quadVector.y;
		vec4 smoothcolor = vec4(
			dot( vec4(fogSampleSmoothed.x, fogSampleSmoothedAdjX.x, fogSampleSmoothedAdjY.x, fogSampleSmoothedDiag.x), smoothWeights),
			dot( vec4(fogSampleSmoothed.y, fogSampleSmoothedAdjX.y, fogSampleSmoothedAdjY.y, fogSampleSmoothedDiag.y), smoothWeights),
			dot( vec4(fogSampleSmoothed.z, fogSampleSmoothedAdjX.z, fogSampleSmoothedAdjY.z, fogSampleSmoothedDiag.z), smoothWeights),
			dot( vec4(fogSampleSmoothed.w, fogSampleSmoothedAdjX.w, fogSampleSmoothedAdjY.w, fogSampleSmoothedDiag.w), smoothWeights)
			);
		//fragColor = vec4(smoothcolor.rgb * smoothcolor.a, smoothcolor.a); return;
		
		// Mix the smoothed and unsmoothed based on discontinuity
		#define SF 0.75
		fogSampleNearestTexelCenter.rgb = mix(smoothcolor.rgb, fogSampleNearestTexelCenter.rgb, (1.0- SF) * discontinuity + SF );
		
		fragColor.rgb = fogSampleNearestTexelCenter.rgb;
		// Debug the mixture
		//fragColor = vec4(fogSampleNearestTexelCenter.rgb * fogSampleNearestTexelCenter.a, fogSampleNearestTexelCenter.a); return;

	
		vec4 gatherAlpha = quadGather(fogSampleNearestTexelCenter.a, quadVector);
		float minAlpha =  min(min(gatherAlpha.x,gatherAlpha.y),	min(gatherAlpha.z,gatherAlpha.w));
		float maxAlpha =  max(max(gatherAlpha.x,gatherAlpha.y),	max(gatherAlpha.z,gatherAlpha.w));
		
		// Proper bilinear smoothing vector:
		#define F 0.75
		vec4 smoothingvec = vec4(F*F, F*(1.0-F), F*(1.0-F), (1.0-F)*(1.0-F)); // F*F, F*(1.0-F), F*(1.0-F), (1-F)*(1-F)
		
		float localsmoothalpha = dot(gatherAlpha, smoothingvec);
		
		fragColor.a = localsmoothalpha;

		if (discontinuity < 0.5){ // NOT discontinous
			if (modelpercent > 0.33) fragColor.a = minAlpha;
			
			//fragColor.a = (ismodel > 0.5 ? minAlpha :maxAlpha);
		}else{ // has a discontinuity
			//TODO: also modulate color!
			
			if (modelpercent > 0.2) { // if any fragment in quad is a model fragment, the whole quad gets
				//fragColor.rgb = vec3(0,1,0);
				fragColor.rgb = fogSampleLocal.rgb;
				
				//fragColor.a = minAlpha;
				if (ismodel > 0.5){
					fragColor.a = minAlpha;
				}else{
					fragColor.a = fogSampleLocal.a;
				}
				}
			else{
			
				fragColor.rgb = fogSampleLocal.rgb;
				//if (dy * quadVector.y > 32 ) fragColor.a = maxAlpha;
				//if (dy * quadVector.y < -32 ) fragColor.a = minAlpha;
				
				//if (dx * quadVector.x > 32 ) fragColor.a = maxAlpha;
				//if (dx * quadVector.x < -32 ) fragColor.a = minAlpha;
				
				
				if (dx > 32) fragColor.a = maxAlpha;
				if (dx < -32) fragColor.a = minAlpha;

				// bunch of fucking debug statements:
				#if 0
					fragColor.rgba = vec4(1.0); // debug all goddamned pixels
					if (dy * quadVector.y > 32) fragColor = vec4(1,0,0,1);
					if (dy * quadVector.y < -32) fragColor = vec4(0,1,0,1);

					
					if (dx * quadVector.x > 32) fragColor = vec4(0,0,1,1);
					if (dx * quadVector.x < -32) fragColor = vec4(0,1,1,1);

				#endif
				//if (dy > 32) fragColor.a = minAlpha;
				//if (dy < -32) fragColor.a = maxAlpha; // very unlikely to happen
				//if (dx < -32) fragColor.a = minAlpha;
			
			}
			//else fragColor.a = maxAlpha;
			// Need to order fucking pixels within a quad? for fuck's sake
		}
		//fragColor.rgba = vec4(0);
		
		//fragColor.r += step(modeldepth, mapdepth);
		// handle Luma Bleed:
		// https://blog.demofox.org/2018/07/13/blending-an-hdr-color-into-a-u8-buffer/
		//Reinhard
		fragColor.a = min(fragColor.a, 0.99) ;
		fragColor.rgb *= fragColor.a;
		//fragColor.rgb = Reinhard(fragColor.rgb);
		//fragColor.a = gatherAlpha.a;
	}
}