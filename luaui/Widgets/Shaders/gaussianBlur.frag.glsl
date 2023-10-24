#version 150 compatibility

//__DEFINES__

uniform sampler2D tex;
uniform sampler2D unitStencilTex;

uniform float offsets[BLUR_HALF_KERNEL_SIZE];
uniform float weights[BLUR_HALF_KERNEL_SIZE];


#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

uniform vec2 dir;

uniform vec2 viewPortSize;

void main(void)
{
	//vec2 uv = gl_FragCoord.xy / viewPortSize;
	vec2 uv = gl_TexCoord[0].xy;

	#if USE_STENCIL == 1 
	if (texture(unitStencilTex, uv).r < 0.1) {
		gl_FragColor = vec4(0.9,0.9, 0.9, 1.0);
		return;
	}
	#endif



	#if 1
		// Allrighty, this is a completely novel implementation now, that will attempt to use a bilateral weighting!
		// tex contains normals, alpha contains occlusion
		// We will weight individual samples by dot-ing them.
		//new bilateral filter implementation
		vec4 texSample = texture( tex, uv );
		//	gl_FragColor.rgba = vec4(texSample.bbb ,1.0); return;// FOR DEBUGGING ONLY
		vec3 myNormal = NORM2SNORM(texSample.rgb);
		myNormal.z = texSample.z;

		//vec2 acc = texture( tex, uv ).ra * weights[0];
		//if (acc.x == 0) {gl_FragColor = vec4(1,1,1,1); return;} 
		float weightSum = weights[0];
		float howLit = texSample.a * weights[0];

		for (int i = 1; i < (BLUR_HALF_KERNEL_SIZE  ); ++i) { // THIS IS TAKING DOUBLE THE SAMPLES IT SHOULD!
			vec2 uvOff = offsets[i] * dir / vec2(HSX,HSY);
			vec2 uvP = uv + uvOff;
			vec2 uvN = uv - uvOff;

			float weightP = weights[i];
			float weightN = weights[i];

			// its clamped anyway!
			//okCoords = float( all(bvec4( greaterThanEqual(uvP, vec2(0.0)), lessThanEqual(uvP, vec2(1.0)) )) );
			//weightP *= okCoords;

			//okCoords = float( all(bvec4( greaterThanEqual(uvN, vec2(0.0)), lessThanEqual(uvN, vec2(1.0)) )) );
			//weightN *= okCoords;
			vec4 leftSample = texture( tex, uvP );
			float leftWeight = weightP * smoothstep(MINCOSANGLE, 1.0, dot(myNormal.xy, NORM2SNORM(leftSample.xy))) * step(abs(myNormal.z-leftSample.z),ZTHRESHOLD);
			weightSum += leftWeight;
			howLit += leftWeight*leftSample.a;

			vec4 rightSample = texture( tex, uvN );
			float rightWeight = weightN * smoothstep(MINCOSANGLE, 1.0, dot(myNormal.xy, NORM2SNORM(rightSample.xy)))* step(abs(myNormal.z-rightSample.z),ZTHRESHOLD);
			weightSum += rightWeight;
			howLit += rightWeight*rightSample.a;

			//acc += texture( tex, uvP ).ra * weightP;
			//acc += texture( tex, uvN ).ra * weightN;
		}
		howLit = howLit / weightSum;
		gl_FragColor = vec4(texSample.rgb, howLit);


		// this is completely stupid, but on last pass, only show howlit:

		// FINAL MIXDOWN:
		if (dir.y > 0.5) {
			//gl_FragColor.rgba = vec4(howLit*howLit);
			
			howLit = pow(howLit, BLUR_POWER);
			howLit = sqrt(howLit * howLit + BLUR_CLAMP);
			#if DEBUG_BLUR == 1 
				gl_FragColor.rgba = vec4(howLit);
			#endif
			gl_FragColor.rgba = vec4(pow(howLit, BLUR_POWER));
				gl_FragColor.rgba = vec4(howLit);
		};
		//gl_FragColor = vec4(acc.xxxy) ;
		// For debugging alpha channel too
		//gl_FragColor = vec4(acc.xy, 0, acc.y) ;
	#else
		vec2 acc = texture( tex, uv ).ra * weights[0];
		//gl_FragColor = texture( tex, uv ).rgba * 0.66; return;
		if (acc.x == 0) {gl_FragColor = vec4(1,1,1,1); return;} 
		float okCoords;

		for (int i = 1; i < (BLUR_HALF_KERNEL_SIZE ); ++i) { // THIS IS TAKING DOUBLE THE SAMPLES IT SHOULD!
			vec2 uvOff = offsets[i] * dir / vec2(HSX,HSY);
			vec2 uvP = uv + uvOff;
			vec2 uvN = uv - uvOff;

			float weightP = weights[i];
			float weightN = weights[i];

			// its clamped anyway!
			//okCoords = float( all(bvec4( greaterThanEqual(uvP, vec2(0.0)), lessThanEqual(uvP, vec2(1.0)) )) );
			//weightP *= okCoords;

			//okCoords = float( all(bvec4( greaterThanEqual(uvN, vec2(0.0)), lessThanEqual(uvN, vec2(1.0)) )) );
			//weightN *= okCoords;

			acc += texture( tex, uvP ).ra * weightP;
			acc += texture( tex, uvN ).ra * weightN;
		}
		//acc /= 1 + 2*BLUR_HALF_KERNEL_SIZE;
		gl_FragColor = vec4(acc.xxxy) ;
		// For debugging alpha channel too
		//gl_FragColor = vec4(acc.xy, 0, acc.y) ;
	#endif
}