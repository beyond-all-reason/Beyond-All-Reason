#version 150 compatibility

uniform sampler2D viewPosTex;
uniform sampler2D viewNormalTex;

uniform vec2 viewPortSize;

uniform mat4 projMatrix;

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

vec3 hash33(vec3 p) {
	const uint k = 1103515245U;

	uvec3 x = uvec3(p);

    x = ((x >> 8U) ^ x.yzx) * k;
    x = ((x >> 8U) ^ x.yzx) * k;
    x = ((x >> 8U) ^ x.yzx) * k;

    return vec3(x) * (1.0 / float(0xFFFFFFFFU));
}

vec3 hash32(vec2 p) {
	const uint k = 1103515245U;

	uvec3 x = uvec3(p.xy, 0U);
	x.z = (x.y >> 1U) ^ x.x;

    x = ((x >> 8U) ^ x.yzx) * k;
    x = ((x >> 8U) ^ x.yzx) * k;
    x = ((x >> 8U) ^ x.yzx) * k;

    return vec3(x) * (1.0 / float(0xFFFFFFFFU));
}

//----------------------------------------------------------------------------------------

#define SSAO_KERNEL_SIZE ###SSAO_KERNEL_SIZE###

#define SSAO_RADIUS ###SSAO_RADIUS###
#define SSAO_MIN 0.1 * SSAO_RADIUS
#define SSAO_MAX 1.0 * SSAO_RADIUS

#define SSAO_FADE_DIST 1000.0

#define SSAO_ALPHA_POW 1.5
#define SSAO_COLOR vec3(0.5)

//----------------------------------------------------------------------------------------

flat in vec3 samplingKernel[SSAO_KERNEL_SIZE];

// generally follow https://github.com/McNopper/OpenGL/blob/master/Example28/shader/ssao.frag.glsl
void main() {
	vec2 uv = gl_FragCoord.xy / viewPortSize;

	vec4 viewPosition = vec4( texture(viewPosTex, uv).xyz, 1.0 );
	vec3 viewNormal = texture(viewNormalTex, uv).xyz;

	gl_FragColor = vec4(1.0, 1.0, 1.0, 0.0);

	if ( dot(viewNormal, viewNormal) > 0.0 ) {
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
		//float occlusionSamples = 0.0;
		
		float fragDistFactor = 1.0 - smoothstep( SSAO_FADE_DIST, 2.0 * SSAO_FADE_DIST, -viewPosition.z );
		fragDistFactor = 1.0;

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
			
			float sampleProjDistanceFactor = smoothstep(0.0, 3.0, distance(texSampingPoint * viewPortSize, gl_FragCoord.xy));
			
			// Get sample viewPos from the viewPosTex texture
			vec3 viewPositionSampled = texture(viewPosTex, texSampingPoint).xyz;

			float delta = viewPositionSampled.z - viewTestPosition.z;

			float occlusionCondition = float(delta >= SSAO_MIN && delta <= SSAO_MAX);

			occlusion += occlusionCondition * fragDistFactor * sampleProjDistanceFactor;
		}

		// No occlusion gets white, full occlusion gets black.
		occlusion = 1.0 - occlusion / float(SSAO_KERNEL_SIZE);

		float occlusionAlpha = occlusion;
		occlusionAlpha = pow(occlusionAlpha, SSAO_ALPHA_POW);

		occlusionAlpha = clamp(1.0 - occlusionAlpha, 0.0, 1.0);
		//occlusionAlpha = 1.0;

		gl_FragColor = vec4(SSAO_COLOR * vec3(occlusion), occlusionAlpha);
		//gl_FragColor.rgba = vec4(fragDistFactor);
		//gl_FragColor = vec4(0.0);
		//gl_FragColor.xyz = viewNormal.xyz;
		//gl_FragColor.xyz = vec3(-viewPosition.z / 8000.0);
		//gl_FragColor.xyz = vec3(viewPosition.z);
	}
	//gl_FragColor.rgba = vec4(1.0);
	//gl_FragColor.xyz = viewNormal.xyz;
}