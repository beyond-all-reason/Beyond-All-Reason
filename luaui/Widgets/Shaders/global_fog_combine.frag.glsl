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
void main(void) {
	if (abs(resolution - 2.0) > 0.01){
		gl_FragColor = texture2D(fogbase, gl_TexCoord[0].st);
		
		//gl_FragColor = texelFetch(fogbase, ivec2(gl_TexCoord[0].st * (vec2(VSX,VSY) ) /int(resolution) ),0); // for debugging!
		
	}else{ // this part only works with half-rez!
		vec2 distUV = gl_TexCoord[0].st * 4 + vec2(0, - gameframe*4);
		//distUV = vec2(0.0);
		vec4 dist = (texture2D(distortion, distUV) * 2.0 - 1.0) * distortionlevel;
		//vec4 dx = dFdx(dist);
		//vec4 dy = dFdy(dist);
		vec2 uv = gl_TexCoord[0].st;
		
		float mapdepth = texture(mapDepths, uv).x;
		float modeldepth = texture(modelDepths, uv).x;
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
		gl_FragColor = texture2D(fogbase, uv); // smooth where it should be smooth

		//gl_FragColor = texelFetch(fogbase, ivec2(uv * (vec2(VSX,VSY) ) /2 ),0);


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