#version 150 compatibility

uniform sampler2D tex;
uniform sampler2D unitStencilTex;

uniform float offsets[###BLUR_HALF_KERNEL_SIZE###];
uniform float weights[###BLUR_HALF_KERNEL_SIZE###];


#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

uniform vec2 dir;

uniform vec2 viewPortSize;

void main(void)
{
	vec2 uv = gl_FragCoord.xy / viewPortSize;

	if (texture(unitStencilTex, uv).r < 0.1) {
		gl_FragColor = vec4(1.0,1.0, 1.0, 1.0);
		return;
	}



	#if 1 
		// Allrighty, this is a completely novel implementation now, that will attempt to use a bilateral weighting!
		// tex contains normals, alpha contains occlusion
		// We will weight individual samples by dot-ing them.
		//new bilateral filter implementation
		const float minCosAngle = 0.5;
		const float zthreshold = 1.5/255.0;
		vec4 texSample = texture( tex, uv );
		//gl_FragColor.rgba = vec4( texSample.a); return;// FOR DEBUGGING ONLY
		vec3 myNormal = NORM2SNORM(texSample.rgb);
		myNormal.z = texSample.z;

		//vec2 acc = texture( tex, uv ).ra * weights[0];
		//if (acc.x == 0) {gl_FragColor = vec4(1,1,1,1); return;} 
		float weightSum = weights[0];
		float howLit = texSample.a * weights[0];

		for (int i = 1; i < (###BLUR_HALF_KERNEL_SIZE###  ); ++i) { // THIS IS TAKING DOUBLE THE SAMPLES IT SHOULD!
			vec2 uvOff = offsets[i] * dir / viewPortSize;
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
			float leftWeight = weightP * smoothstep(minCosAngle, 1.0, dot(myNormal.xy, NORM2SNORM(leftSample.xy))) * step(abs(myNormal.z-leftSample.z),zthreshold);
			weightSum += leftWeight;
			howLit += leftWeight*leftSample.a;

			vec4 rightSample = texture( tex, uvN );
			float rightWeight = weightN * smoothstep(minCosAngle, 1.0, dot(myNormal.xy, NORM2SNORM(rightSample.xy)))* step(abs(myNormal.z-rightSample.z),zthreshold);
			weightSum += rightWeight;
			howLit += rightWeight*rightSample.a;

			//acc += texture( tex, uvP ).ra * weightP;
			//acc += texture( tex, uvN ).ra * weightN;
		}
		howLit = howLit / weightSum;
		gl_FragColor = vec4(texSample.rgb, howLit);

		// this is completely stupid, but on last pass, only show howlit:

		// FINAL MIXDOWN:
		if (dir.y > 0.5) gl_FragColor.rgba = vec4(howLit*howLit);
		//gl_FragColor = vec4(acc.xxxy) ;
		// For debugging alpha channel too
		//gl_FragColor = vec4(acc.xy, 0, acc.y) ;
	#else
		vec2 acc = texture( tex, uv ).ra * weights[0];
		//if (acc.x == 0) {gl_FragColor = vec4(1,1,1,1); return;} 
		float okCoords;

		for (int i = 1; i < (###BLUR_HALF_KERNEL_SIZE###  ); ++i) { // THIS IS TAKING DOUBLE THE SAMPLES IT SHOULD!
			vec2 uvOff = offsets[i] * dir / viewPortSize;
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
		gl_FragColor = vec4(acc.xxxy) ;
		// For debugging alpha channel too
		//gl_FragColor = vec4(acc.xy, 0, acc.y) ;
	#endif
}