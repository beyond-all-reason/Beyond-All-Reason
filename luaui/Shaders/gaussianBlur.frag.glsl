#version 430 core


//__DEFINES__

uniform sampler2D tex;
uniform sampler2D unitStencilTex;

uniform float offsets[BLUR_HALF_KERNEL_SIZE];
uniform float weights[BLUR_HALF_KERNEL_SIZE];


#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

uniform vec2 dir;
uniform float strengthMult;

uniform vec2 viewPortSize;


in DataVS {
	vec4 vs_position_texcoords;
};

out vec4 fragColor;

#line 1018
void main(void)
{
	//vec2 uv = gl_FragCoord.xy / viewPortSize;

	vec2 uv = gl_FragCoord.xy / vec2(HSX,HSY);


	#if USE_STENCIL == 1 
		if (texture(unitStencilTex, uv).r < 0.1) {
			fragColor = vec4(0.0,0.0, 0.0, 1.0);	return;
		}
	#endif

		// Allrighty, this is a completely novel implementation now, that will attempt to use a bilateral weighting!
		// tex contains normals, alpha contains occlusion
		// We will weight individual samples by dot-ing them.
		//new bilateral filter implementation

		// TODO: ground has null vector normals, use that
		// implement outlier detection too 
		// MORE GROUND EFFECT! USE UNIFORM KERNEL FOR GROUND!

		vec4 texSample = texture( tex, uv );
		vec3 myNormal = NORM2SNORM(texSample.rgb);
		myNormal.z = texSample.z;

		float imground =step(dot(myNormal.xy, myNormal.xy), 0.1);
		
		float weightSum = weights[0];
		if (imground > 0.5) {
			//weightSum = 1.0/(2 * BLUR_HALF_KERNEL_SIZE-1);
		}
		float howLit = texSample.a * weightSum;
		float unWeighted = howLit;
		float myDistance = myNormal.z; // 1 at full distance, 0 at camera
		vec2 texelOffset = dir / vec2(HSX,HSY);

		// possibly better L1 cache locality via non expanding stepping?
		for (int i = 1; i < (BLUR_HALF_KERNEL_SIZE  ); ++i) { // i goes from 1 to BLUR_HALF_KERNEL_SIZE-1
			vec2 uvOff = offsets[i] * texelOffset ;
			vec2 uvP = uv + uvOff;
			vec2 uvN = uv - uvOff;

			float weightP = weights[i];
			float weightN = weights[i];
			if (imground > 0.5) {
				//weightP = 1.0/(2 * BLUR_HALF_KERNEL_SIZE-1);
				//weightN = 1.0/(2* BLUR_HALF_KERNEL_SIZE-1);
				//uvP = uv + 2*float(i) *  dir / vec2(HSX,HSY);
				//uvN = uv - 2*float(i) *  dir / vec2(HSX,HSY);
			}


			vec4 leftSample = texture( tex, uvP );
			float zclosel = step(abs(myDistance - leftSample.z), ZTHRESHOLD);
			float dotclosel = smoothstep(MINCOSANGLE, 1.0, dot(myNormal.xy, NORM2SNORM(leftSample.xy)));
			dotclosel = max(dotclosel, imground);
			float leftWeight = weightP * dotclosel * zclosel;
			weightSum += leftWeight;
			howLit += leftWeight * leftSample.a;
			unWeighted += weightP * leftSample.a;

			vec4 rightSample = texture( tex, uvN );
			float zcloser = step(abs(myDistance - rightSample.z), ZTHRESHOLD);
			float dotcloser = smoothstep(MINCOSANGLE, 1.0, dot(myNormal.xy, NORM2SNORM(rightSample.xy)));
			dotcloser = max(dotclosel, imground);
			float rightWeight = weightN * dotcloser * zcloser;
			weightSum += rightWeight;
			howLit += rightWeight * rightSample.a;
			unWeighted += weightP * rightSample.a;
		}

		howLit = howLit / weightSum;		
		if (weightSum < (weights[0] + MINSELFWEIGHT) ){
			howLit = mix(howLit,unWeighted, OUTLIERCORRECTIONFACTOR);

		};
		//if (imground > 0.5) {howLit = unWeighted;}
		fragColor = vec4(texSample.rgb, howLit);

		// FINAL MIXDOWN, vert pass last
		if (dir.y > 0.5) { 
			if (imground > 0.5) howLit = howLit * howLit;
			howLit = pow(howLit, BLUR_POWER);
			howLit = sqrt(howLit * howLit + BLUR_CLAMP);
			#if DEBUG_BLUR == 1 
				fragColor.rgba = vec4(howLit);
			#else
				fragColor.rgba = vec4(howLit);
				#if (BRIGHTEN != 0) 
					if (imground < 0.5) {  // is model fragment
						float distRatio = SSAO_FADE_DIST_1/(1.0 * SSAO_FADE_DIST_0);
						float distFactor = 1.0 - smoothstep(0, distRatio, myDistance - distRatio ); // 0 at far distance, 1 at near distance

						float brightenFactor = (BRIGHTEN/255.0) * howLit * distFactor;
						fragColor.rgb = vec3(brightenFactor);
					}else{
						fragColor.rgb = vec3(0);

					}
				#endif
				fragColor.rgb *= strengthMult;
				fragColor.a = 1.0 - ((1.0 - fragColor.a) * strengthMult );
			#endif

		};
}