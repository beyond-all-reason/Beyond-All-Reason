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
			gl_FragColor = vec4(0.9,0.9, 0.9, 1.0);	return;
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

		float weightSum = weights[0];
		float howLit = texSample.a * weights[0];
		float unWeighted = howLit;

		float imground = step(dot(myNormal.xy, myNormal.xy), 0.1);

		// possibly better L1 cache locality via non expanding stepping?
		for (int i = 1; i < (BLUR_HALF_KERNEL_SIZE  ); ++i) { // i goes from 1 to BLUR_HALF_KERNEL_SIZE-1
			vec2 uvOff = offsets[i] * dir / vec2(HSX,HSY);
			vec2 uvP = uv + uvOff;
			vec2 uvN = uv - uvOff;

			float weightP = weights[i];
			float weightN = weights[i];

			vec4 leftSample = texture( tex, uvP );
			float zclosel = step(abs(myNormal.z - leftSample.z), ZTHRESHOLD);
			float dotclosel = smoothstep(MINCOSANGLE, 1.0, dot(myNormal.xy, NORM2SNORM(leftSample.xy)));
			dotclosel = max(dotclosel, imground);
			float leftWeight = weightP * dotclosel * zclosel;
			weightSum += leftWeight;
			howLit += leftWeight * leftSample.a;
			unWeighted += weightP * leftSample.a;

			vec4 rightSample = texture( tex, uvN );
			float zcloser = step(abs(myNormal.z - rightSample.z), ZTHRESHOLD);
			float dotcloser = smoothstep(MINCOSANGLE, 1.0, dot(myNormal.xy, NORM2SNORM(rightSample.xy)));
			dotcloser = max(dotclosel, imground);
			float rightWeight = weightN * dotcloser * zcloser;
			weightSum += rightWeight;
			howLit += rightWeight * rightSample.a;
			unWeighted += weightP * rightSample.a;
		}


		howLit = howLit / weightSum;		
		if (weightSum <= (weights[0] + MINSELFWEIGHT) ){
			howLit = mix(howLit,unWeighted, OUTLIERCORRECTIONFACTOR);

		};
		gl_FragColor = vec4(texSample.rgb, howLit);

		// FINAL MIXDOWN, vert pass last
		if (dir.y > 0.5) { 
			howLit = pow(howLit, BLUR_POWER);
			howLit = sqrt(howLit * howLit + BLUR_CLAMP);
			#if DEBUG_BLUR == 1 
				gl_FragColor.rgba = vec4(howLit);
			#endif
			gl_FragColor.rgba = vec4(howLit);
		};
}