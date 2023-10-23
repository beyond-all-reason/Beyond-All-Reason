#version 150 compatibility

uniform sampler2D viewPosTex;
uniform sampler2D viewNormalTex;

uniform sampler2D unitStencilTex;

#define USE_MATERIAL_INDICES ###USE_MATERIAL_INDICES###

#if (USE_MATERIAL_INDICES == 1)
	uniform sampler2D miscTex;
#endif

uniform vec2 viewPortSize;

uniform float shadowDensity;

uniform mat4 projMatrix;

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

#define HASHSCALE3 vec3(.1031, .1030, .0973)

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
	p3 += dot(p3, p3.yxz+19.19);
	return fract((p3.xxy+p3.yzz)*p3.zyx);
}

//----------------------------------------------------------------------------------------

#define SSAO_KERNEL_SIZE ###SSAO_KERNEL_SIZE###

#define SSAO_RADIUS ###SSAO_RADIUS###
#define SSAO_MIN ###SSAO_MIN###
#define SSAO_MAX ###SSAO_MAX### * SSAO_RADIUS

#define SSAO_FADE_DIST_1 800.0
#define SSAO_FADE_DIST_0 3.0 * SSAO_FADE_DIST_1

#define SSAO_ALPHA_POW ###SSAO_ALPHA_POW###

//----------------------------------------------------------------------------------------

uniform vec3 samplingKernel[SSAO_KERNEL_SIZE];

// generally follow https://github.com/McNopper/OpenGL/blob/master/Example28/shader/ssao.frag.glsl
void main() {
	
	vec2 texelSize = 0.25 / viewPortSize;
	vec2 uv = gl_FragCoord.xy / viewPortSize - texelSize;
	//vec2 uv = gl_TexCoord[0].xy * vec2(2,-2) + vec2(0,2.0);
	//gl_FragColor = vec4(uv.xy, 0.0, 1.0); return;

	
	if (texture(unitStencilTex, uv).r < 0.1) { gl_FragColor = vec4(1,1,1,1) ; return;}

	#if (USE_MATERIAL_INDICES == 1)
		#define TREEMAT_INDEX_B 128
		#define TREEMAT_INDEX_E 130
		int matIndex = int(texture(miscTex, uv).r * 255.0);
		if (matIndex >= TREEMAT_INDEX_B && matIndex <= TREEMAT_INDEX_E)
			discard;
	#endif

	

	vec4 viewPosition = vec4( texture(viewPosTex, uv).xyz, 1.0 );
	vec4 viewNormalSample = texture(viewNormalTex, uv);
	vec3 viewNormal = viewNormalSample.xyz;
	float validFragment = viewNormalSample.a;
	vec4 collectedNormal = vec4(viewNormal, 1.0);
	vec2 collectedDistance = vec2(viewPosition.z, 1.0);
	float fragDistFactor = smoothstep( SSAO_FADE_DIST_0, SSAO_FADE_DIST_1, -viewPosition.z );

	gl_FragColor = vec4(SNORM2NORM(normalize(collectedNormal.xy)), (-collectedDistance.x / (SSAO_FADE_DIST_0)), 1.0);

	if ( dot(viewNormal, viewNormal) > 0.1 && fragDistFactor > 0.0 && (validFragment > 0.5) ) {
		// Calculate the rotation matrix for the kernel.
		vec3 randomVector = normalize( NORM2SNORM(hash32(gl_FragCoord.xy)) );

		// Using Gram-Schmidt process to get an orthogonal vector to the normal vector.
		// The resulting tangent is on the same plane as the random and normal vector.
		// see http://en.wikipedia.org/wiki/Gram%E2%80%93Schmidt_process
		// Note: No division by <u,u> needed, as this is for normal vectors 1.
		vec3 viewTangent = normalize(randomVector - dot(randomVector, viewNormal) * viewNormal);

		vec3 viewBitangent = cross(viewNormal, viewTangent);

		// Final matrix to reorient the kernel depending on the normal and the random vector.
		// TBN matrix. Transforms from tangent space to view space
		mat3 kernelMatrix = mat3(viewTangent, viewBitangent, viewNormal);

		// Go through the kernel samples and create occlusion factor.
		float occlusion = 0.0; // higher numbers mean more occlusion


		for (int i = 0; i < SSAO_KERNEL_SIZE; ++i) {
			// silly resample:
			#if 1
				if ( (i % (SSAO_KERNEL_SIZE/4)) == (SSAO_KERNEL_SIZE/4 - 1) ){
					vec2 newUV = uv;
					if (i == SSAO_KERNEL_SIZE/4 - 1) newUV.x += texelSize.x;
					
					if (i == 2* SSAO_KERNEL_SIZE/4 - 1) newUV.y += texelSize.y;
					
					if (i == 3 * SSAO_KERNEL_SIZE/4 - 1) newUV.xy += texelSize.xy;

					viewNormalSample =texture(viewNormalTex, newUV);
					if (dot(viewNormalSample.xyz, viewNormalSample.xyz) > 0.1  && viewNormalSample.a > 0.5){
						viewNormal = viewNormalSample.xyz;
						
						viewPosition = vec4( texture(viewPosTex, newUV).xyz, 1.0 );
						viewTangent = normalize(randomVector - dot(randomVector, viewNormal) * viewNormal);
						viewBitangent = cross(viewNormal, viewTangent);
						kernelMatrix = mat3(viewTangent, viewBitangent, viewNormal);
					
					
					}
					collectedNormal+= vec4(viewNormal, 1.0);
					
					collectedDistance += vec2(viewPosition.z, 1.0);
				}
			#endif


			// Reorient sample vector in view space ...
			vec3 viewSampleVector = kernelMatrix * samplingKernel[i];

			// ... and calculate sample point.
			vec4 viewTestPosition = viewPosition + SSAO_RADIUS * vec4(viewSampleVector, 0.0);

			// projection
			vec4 ndcTestPosition = projMatrix * viewTestPosition;
			// perspecitive division
			ndcTestPosition /= ndcTestPosition.w;

			// [-1;1] to [0;1]
			vec2 texSampingPoint = SNORM2NORM(ndcTestPosition.xy);

			// Get sample viewPos from the viewPosTex texture
			vec3 viewPositionSampled = texture(viewPosTex, texSampingPoint).xyz;

			float delta = viewPositionSampled.z - viewTestPosition.z;

			#if 1
				float occlusionCondition = float(delta >= SSAO_MIN && delta <= SSAO_MAX);
			#else
				float occlusionCondition = float(delta >= SSAO_MIN) * smoothstep(SSAO_MAX, 0.5 * SSAO_MAX, delta);//Results are /undefined if edge0 ≥ edge1. 
				//float occlusionCondition = float(delta >= SSAO_MIN) * smoothstep(0.5 * SSAO_MAX, SSAO_MAX,  delta);//Results are undefined if edge0 ≥ edge1. 
				
				//float occlusionCondition = float(delta >= SSAO_MIN) * smoothstep(SSAO_MIN, SSAO_RADIUS* SSAO_MAX,  abs(delta)	);//Results are undefined if edge0 ≥ edge1. 
				//occlusionCondition = step(SSAO_MIN, delta) * step(delta, SSAO_RADIUS) * smoothstep(SSAO_MIN,SSAO_RADIUS, delta ) ;
			#endif

			occlusion += occlusionCondition;
		}

		occlusion *= fragDistFactor ; //more distance fragments are less occluded

		// No occlusion gets white, full occlusion gets black.

		//occlusion *= shadowDensity; // High shadow density allows for more occlusion


		occlusion = occlusion / float(SSAO_KERNEL_SIZE);// normalize by sample count

		//
		float fullylit = clamp(1.0 - occlusion, 0.0, 1.0);

		fullylit = fullylit * fullylit * fullylit * fullylit * fullylit * fullylit;
		

		occlusion = occlusion * occlusion; // darken a range of it



		float occlusionAlpha = occlusion;
		//occlusionAlpha = pow(occlusionAlpha, SSAO_ALPHA_POW);
		occlusionAlpha = occlusionAlpha * occlusionAlpha;

		occlusionAlpha = clamp(1.0 - occlusionAlpha, 0.0, 1.0);
		//occlusionAlpha = 1.0;
		fullylit *= max(1.0, shadowDensity);

		gl_FragColor = vec4(vec3(fullylit,viewNormal.xy ), 1.0);

		//passing through RG should be more than enough.
		// How to pack depth into z?
		collectedNormal.xyz /= collectedNormal.w;
		collectedDistance.x /= collectedDistance.y;
		gl_FragColor = vec4(vec3(SNORM2NORM(normalize(collectedNormal.xy)), (-collectedDistance.x / (SSAO_FADE_DIST_0)) ), fullylit);
	}
}