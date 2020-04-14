#version 150 compatibility

uniform sampler2D viewPosTex;
uniform sampler2D viewNormalTex;

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
	vec2 uv = gl_FragCoord.xy / viewPortSize;

	#if (USE_MATERIAL_INDICES == 1)
		#define TREEMAT_INDEX_B 128
		#define TREEMAT_INDEX_E 130
		int matIndex = int(texture(miscTex, uv).r * 255.0);
		if (matIndex >= TREEMAT_INDEX_B && matIndex <= TREEMAT_INDEX_E)
			discard;
	#endif

	vec4 viewPosition = vec4( texture(viewPosTex, uv).xyz, 1.0 );
	vec3 viewNormal = texture(viewNormalTex, uv).xyz;

	float fragDistFactor = smoothstep( SSAO_FADE_DIST_0, SSAO_FADE_DIST_1, -viewPosition.z );

	gl_FragColor = vec4(1.0, 1.0, 1.0, 0.0);

	if ( dot(viewNormal, viewNormal) > 0.0 && fragDistFactor > 0.0 ) {
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
		float occlusion = 0.0;


		for (int i = 0; i < SSAO_KERNEL_SIZE; ++i) {
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

			#if 0
				float occlusionCondition = float(delta >= SSAO_MIN && delta <= SSAO_MAX);
			#else
				float occlusionCondition = float(delta >= SSAO_MIN) * smoothstep(SSAO_MAX, 0.5 * SSAO_MAX, delta);
			#endif

			occlusion += occlusionCondition;
		}

		occlusion *= fragDistFactor;

		// No occlusion gets white, full occlusion gets black.
		occlusion = 1.0 - occlusion / float(SSAO_KERNEL_SIZE);

		float occlusionAlpha = occlusion;
		occlusionAlpha = pow(occlusionAlpha, SSAO_ALPHA_POW);

		occlusionAlpha = clamp(1.0 - occlusionAlpha, 0.0, 1.0);
		//occlusionAlpha = 1.0;

		gl_FragColor = vec4(vec3(shadowDensity * occlusion), occlusionAlpha);
	}
}