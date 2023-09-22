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
		
		//gl_FragColor = texelFetch(fogbase, ivec2(gl_TexCoord[0].st * (vec2(VSX,VSY) ) /int(resolution) ),0); // for debugging!
		
	}else{ // this part only works with half-rez!
    vec2 screenUVTexelCentered = gl_TexCoord[0].st; // This matches gl_FragCoord.xy/viewSizes, so it is texel centered
	
	#if 1
		screenUVTexelCentered = gl_TexCoord[0].st;
		//gl_FragColor = vec4(screenUVTexelCentered.x , screenUVTexelCentered.y, 0, 1); return;
	#endif
    
    quadVector = quadGetQuadVector( gl_FragCoord.xy);	
	//quadVector.y *= -1;
	
	vec3 QVC = vec3(// [[BR],[GY]]
		quadVector.x > 0 ? 1: 0,
		quadVector.y < 0 ? 1: 0,
		(quadVector.x < 0 && quadVector.y >0) ? 1 : 0
	);
	//gl_FragColor.rgba = debugQuad(quadVector);return;
	
  
    float mapdepth = texture(mapDepths, screenUVTexelCentered).x;
    float modeldepth = texture(modelDepths, screenUVTexelCentered).x;

	float screendepth = min(mapdepth, modeldepth);
    
    
    float ndc = screendepth * 2.0 - 1.0;   
    float near = 0.1; 
    float far  = 100.0; 
    float linearDepth = (2.0 * near * far) / (far + near - ndc * (far - near)) * 100;	// wow this is almost elmos resolution!
    
    vec4 my_and_neighbour_depth = quadGather(linearDepth, quadVector.xy);
    
    gl_FragColor = vec4(fract(my_and_neighbour_depth.x - my_and_neighbour_depth.y),0.0,0.0,1.0);
    //gl_FragColor = vec4(quadVector.xy,0.0,1.0);
    
    
    float dx = dFdx(linearDepth); // positive if right pixel is bigger
    float dy = dFdy(linearDepth); // positive if top pixel is more
    vec2 fogUV = gl_TexCoord[0].zw;
    gl_FragColor = texture2D(fogbase, fogUV);
	//gl_FragColor.a = min(gl_FragColor.a, 0.5);
	//return;
	
    vec2 pixelShift = 2.0 / vec2(VSX, VSY);

    bool smoothed = false;
    if (abs(dx) > 32.0){ // left-right depth discontinuity of 32 elmos
       smoothed = true;
       fogUV.x += sign(quadVector.x - 0.5) * pixelShift.x; // move right pixels right, left pixels left
    }

    if (abs(dy) > 32.0){ // up-down depth discontinuity of 32 elmos
        smoothed = true;
        fogUV.y += sign(quadVector.y - 0.5) * pixelShift.y; // move top pixels up, buttom pixels down
    }
    //fogUV = screenUVTexelCentered;
	//fogUV = gl_TexCoord[0].zw + 0.25 * quadVector.xy * pixelShift;
    vec4 fogRGBA = texture2D(fogbase, fogUV);
    fogRGBA = texture2D(fogbase, gl_TexCoord[0].zw);
    //gl_FragColor = vec4(gl_TexCoord[0].xy,0.0,1.0);return;
    gl_FragColor = vec4(fogRGBA.rgb, fogRGBA.a); // smooth where it should be smooth
	//gl_FragColor.ba += smoothed ? 1 : 0;
    vec2 qV_uvCorrect = quadVector.xy * vec2(1,-1);
    float offset = 0.33;
    vec2 fogUVquad = screenUVTexelCentered + qV_uvCorrect * pixelShift *offset - pixelShift * 0.5;
    vec4 fogQuadColor = texture2D(fogbase, fogUVquad);
    vec4 fogAlphaNeighbours = quadGather(fogQuadColor.a, quadVector.xy);
    float blendedFog = dot(vec4(0.5, 0.2, 0.2, 0.1), fogAlphaNeighbours);
    if (smoothed == false && fract(gl_FragCoord.x * 0.01)< 0.5 ){
      //gl_FragColor = vec4(0.96 * fogRGBA.rgb, blendedFog); // smooth where it should be smooth
    }
	
	//
	vec4 dbgColor = debugQuad(quadVector);
	
	
	// Try to gather all 4 neighbour fog alphas:
	vec2 quadShift = (0.5 / vec2(VSX, VSY)) * (quadVector * vec2(1.0, 1.0));
	vec4 quadFog = texture2D(fogbase, gl_TexCoord[0].zw + quadShift);
	
	gl_FragColor = quadFog;

	
	vec4 gatherAlpha = quadGather(quadFog.a, quadVector);
	float minAlpha =  min(min(gatherAlpha.x,gatherAlpha.y),	min(gatherAlpha.z,gatherAlpha.w));
	float maxAlpha =  max(max(gatherAlpha.x,gatherAlpha.y),	max(gatherAlpha.z,gatherAlpha.w));
	
	// Proper bilinear smoothing vector:
	#define F 0.75
	vec4 smoothingvec = vec4(F*F, F*(1.0-F), F*(1.0-F), (1.0-F)*(1.0-F)); // F*F, F*(1.0-F), F*(1.0-F), (1-F)*(1-F)
	
	float localsmoothalpha = dot(gatherAlpha, smoothingvec);
	
	gl_FragColor.a = localsmoothalpha;
	if (dx < -32.0 ){
		//gl_FragColor.a = minAlpha;
	}
	
	if (dx > 32.0){
		//gl_FragColor.a = maxAlpha;
	}
	float ismodel = step(modeldepth + 0.00001, mapdepth);
	float allmodel = quadGatherSumFloat(ismodel);
	float discontinuity = step(32,abs(dx) + abs(dy));
	if (discontinuity < 0.5){ // NOT discontinous
		if (allmodel > 0.33) gl_FragColor.a = minAlpha;
		//gl_FragColor.a = (ismodel > 0.5 ? minAlpha :maxAlpha);
	}else{ // has a discont
		if (ismodel > 0.2) gl_FragColor.a = minAlpha;
		else gl_FragColor.a = maxAlpha;
		//if (allmodel > 0.45) gl_FragColor.a = minAlpha;
		//gl_FragColor.a = minAlpha;
		//gl_FragColor.a = (ismodel > 0.5 ? minAlpha :maxAlpha);
		//if (dx < -32.0) gl_FragColor.a = maxAlpha;
		//if (dx >  32.0) gl_FragColor.a = maxAlpha;
		//if (dy < -32.0) gl_FragColor.a = minAlpha;
		//if (dy >  32.0) gl_FragColor.a = minAlpha;
		// Need to order fucking pixels within a quad? for fuck's sake
	}
	
	if (abs(dx) > 32.0){
		//gl_FragColor.a = gatherAlpha.y;
	}
	//if (dbgColor.a < 0.1){
	//}
	
	//gl_FragColor.r += step(modeldepth, mapdepth);
	gl_FragColor.a = min(gl_FragColor.a, 0.99) ;
	//gl_FragColor.a *= dbgColor.a;
	//gl_FragColor.a = gatherAlpha.a;
	
// ----------------------------------- END ----------------------
// ----------------------------------- END ----------------------
// ----------------------------------- END ----------------------
    
    #if 0
        //vec2 distUV = gl_TexCoord[0].st * 4 + vec2(0, - gameframe*4);
        //distUV = vec2(0.0);
        //vec4 dist = (texture2D(distortion, distUV) * 2.0 - 1.0) * distortionlevel;
        //vec4 dx = dFdx(dist);
        //vec4 dy = dFdy(dist);
      vec2 screenUVTexelCentered = gl_TexCoord[0].st; // This matches gl_FragCoord.xy/viewSizes, so it is texel centered
       
      vec2 viewSizes = vec2(VSX,VSY);
      // These are centered upon texel centers, with 0.5s, e.g. 87.5
      vec2 fragCoords = gl_FragCoord.xy; 
      vec2 texelCenterUV = gl_FragCoord.xy/viewSizes;
      //gl_FragColor.rgba = vec4(100*abs(gl_FragCoord.xy - uv*viewSizes),0,1); return;
      
      //gl_FragColor.rgba = vec4(fragCoords.x, fragCoords.y, 0,1); return;
          
      //gl_FragColor = texelFetch(fogbase, ivec2(gl_TexCoord[0].st * (vec2(VSX,VSY) ) /int(resolution) ),0); // for debugging!
      
      float mapdepth = texture(mapDepths, screenUVTexelCentered).x;
      float modeldepth = texture(modelDepths, screenUVTexelCentered).x;
      mapdepth = min(mapdepth, modeldepth);
      
      float ndc = mapdepth * 2.0 - 1.0; 
      float near = 0.1; 
      float far  = 100.0; 
      float linearDepth = (2.0 * near * far) / (far + near - ndc * (far - near)) * 100;	// wow this is almost elmos resolution!
      
      // http://www.aclockworkberry.com/shader-derivative-functions/
      float dx = dFdx(linearDepth); // positive if right pixel is bigger
      float dy = dFdy(linearDepth); // positive if top pixel is more
      
      // z is X, w is Y
      vec4 quadvector = get_quad_vector_naive(vec4(uv, gl_FragCoord.xy)); 
      
      float pixelShift = 0.7;
      
      uv = gl_TexCoord[0].st;

      bool smoothed = false;
      if (abs(dx) > 32.0){ // left-right depth discontinuity of 32 elmos
        smoothed = true;
        uv.x += sign(quadvector.z - 0.5) * pixelShift/VSX; // move right pixels right, left pixels left
      }
      
      if (abs(dy) > 32.0){ // up-down depth discontinuity of 32 elmos
        smoothed = true;
        uv.y += sign(quadvector.w - 0.5) * pixelShift/VSY; // move top pixels up, buttom pixels down
      }
      gl_FragColor = texture2D(fogbase, screenUVTexelCentered); // smooth where it should be smooth

      gl_FragColor = texelFetch(fogbase, ivec2(screenUVTexelCentered * (vec2(VSX,VSY) ) /2 ),0);

      //gl_FragColor.rgba = vec4(fract(linearDepth * 0.001));
    #endif
		#if 0 // debug
			if (abs(gl_FragCoord.x - VSX/2 + 0.5) < 0.1){
				gl_FragColor.rgb = vec3(quadvector.w);
			}
			if (smoothed){ // TOP KEKS CAS is eating my gains!
					//uv += 0.55/vec2(VSX,VSY);
					gl_FragColor = vec4(1.0,0.0,0.0,0.3);
			}
			
			if (gl_FragCoord.x > VSX/2){ // keep right half unsmoothed
				uv = gl_TexCoord[0].st;
				gl_FragColor = texture2D(fogbase, uv);
			}

			
			if (abs(gl_FragCoord.x - VSX/2 + 0.5) < 0.1){
				gl_FragColor.rgb = vec3(quadvector.w);
			}
			
			if (abs(dy) > 60){
				if (quadvector.z > 0)
					gl_FragColor.ra = vec2(1.0);
				
			}
		
			if (gl_FragCoord.y > VSY * 0.75){
				gl_FragColor.rgb = vec3(quadvector.z, quadvector.w,0) * 0.1;
				gl_FragColor.b = float(abs(dy) > 10);
				gl_FragColor.a = 1.0;
			}
		#endif
		//gl_FragColor.rgb = fract(gl_FragCoord.xyx);
		//gl_FragColor.rgb = fract(gl_FragCoord.xyx);
		//gl_FragColor.a = 1.0;
	}
}