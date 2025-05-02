#version 420 

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

uniform sampler2D viewPosTex;
uniform sampler2D viewNormalTex;

uniform sampler2D unitStencilTex;

uniform sampler2D modelDepthTex;
uniform sampler2D mapDepthTex;

uniform sampler2D modelNormalTex;


#if (USE_MATERIAL_INDICES == 1)
	uniform sampler2D miscTex;
#endif

uniform vec2 viewPortSize;

//uniform float shadowDensity;

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

#define HASHSCALE3 vec3(.1031, .1030, .0973)

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
	p3 += dot(p3, p3.yxz+19.19);
	return fract((p3.xxy+p3.yzz)*p3.zyx);
}

uniform float testuniform = 0.5;

in DataVS {
	vec4 vs_position_texcoords;
};

out vec4 fragColor;
//----------------------------------------------------------------------------------------
const int kernelSize = SSAO_KERNEL_SIZE;
uniform vec3 samplingKernel[kernelSize];

// Returns 0 in alpha if its a null-normal (invalid)
vec4 GetModelNormalCameraSpace(vec2 uv){
	vec4 modelNormal = texture(modelNormalTex, uv);
	modelNormal.a = step(0.1, dot(modelNormal,modelNormal));
	modelNormal.xyz = normalize(NORM2SNORM(modelNormal.xyz));
	modelNormal.xyz = vec3(cameraView * vec4(modelNormal.xyz, 0.0));
	return modelNormal;
}

// Returns 0 in alpha if 
vec4 GetViewPos(vec2 texCoord) {
	float mapDepth = texture(mapDepthTex, texCoord).r;
	float modelDepth =  texture(modelDepthTex, texCoord).r;

	float modelOccludesMap = float(modelDepth < mapDepth);
	float depth = min(mapDepth, modelDepth);

	vec4 projPosition = vec4(0.0, 0.0, 0.0, 1.0);

	//texture space [0;1] to NDC space [-1;1]
	#if (DEPTH_CLIP01 == 1)
		//don't transform depth as it's in the same [0;1] space
		projPosition.xyz = vec3(NORM2SNORM(texCoord), depth);
	#else
		projPosition.xyz = NORM2SNORM(vec3(texCoord, depth));
	#endif

	vec4 viewPosition = cameraProjInv * projPosition;
	viewPosition /= viewPosition.w;
	viewPosition.w = modelOccludesMap;
	return viewPosition;
}

// generally follow https://github.com/McNopper/OpenGL/blob/master/Example28/shader/ssao.frag.glsl
void main() {

	vec2 texelSize = 0.5 / vec2(VSX,VSY);
	vec2 uv = gl_FragCoord.xy * DOWNSAMPLE / vec2(VSX,VSY);

	#if USE_STENCIL == 1 
		if (texture(unitStencilTex, uv).r < 0.1) { fragColor = vec4(1,0,1,1) ; return;}
	#endif

	#if NOFUSE == 1 
		vec4 viewNormalSample = GetModelNormalCameraSpace(uv);
		float validFragment =viewNormalSample.a;
		vec3 viewNormal = viewNormalSample.xyz * validFragment;

		vec4 viewPosition = GetViewPos(uv) ;
		validFragment *= viewPosition.w;

	#else
		vec4 viewPosition = vec4( texture(viewPosTex, uv).xyz, 1.0 );
		vec4 viewNormalSample = GetModelNormalCameraSpace(uv);
		vec3 viewNormal = viewNormalSample.xyz;
		float validFragment = viewNormalSample.a * step(viewPosition.z,0.0);
	#endif

	//fragColor = vec4(fract(viewPosition.xyz * 0.02) , 1.0); return;
	//--------------------------- DEBUG---------------

	vec4 collectedNormal = vec4(viewNormal, 1.0);
	vec2 collectedDistance = vec2(abs(viewPosition.z), 1.0);
	float fragDistFactor = smoothstep( SSAO_FADE_DIST_0 * 1.0, SSAO_FADE_DIST_1 * 1.0, -viewPosition.z );
	//gl_FragColor = vec4(fract(viewPosition.xyz * 0.1), 1.0); return;

	//fragColor = vec4(SNORM2NORM(normalize(collectedNormal.xy)), (abs(viewPosition.z) / (SSAO_FADE_DIST_0)), 1.0); return;
	
	// Indicate that we are sampling a ground position, so pass zero vector as normal in RG
	// Also pass distance in B channel, and no occlusion (1.0) in alpha
	fragColor = vec4(vec2(0.5), (abs(viewPosition.z) / (SSAO_FADE_DIST_0)), 1.0);

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
			#if ((OFFSET == 1) && (DOWNSAMPLE> 1 ))
				if ( (i % (SSAO_KERNEL_SIZE/4)) == (SSAO_KERNEL_SIZE/4 - 1) ){
					vec2 newUV = uv;
					if (i == SSAO_KERNEL_SIZE/4 - 1) newUV.x += texelSize.x;
					
					if (i == 2* SSAO_KERNEL_SIZE/4 - 1) newUV.y += texelSize.y;
					
					if (i == 3 * SSAO_KERNEL_SIZE/4 - 1) newUV.xy += texelSize.xy;

					viewNormalSample = GetModelNormalCameraSpace( newUV);
					if (dot(viewNormalSample.xyz, viewNormalSample.xyz) > 0.1  && viewNormalSample.a > 0.5){
						viewNormal = viewNormalSample.xyz;
						#if NOFUSE == 1 
							viewPosition = GetViewPos(uv) ;
						#else
							viewPosition = vec4( texture(viewPosTex, newUV).xyz, 1.0 );
						#endif
						viewTangent = normalize(randomVector - dot(randomVector, viewNormal) * viewNormal);
						viewBitangent = cross(viewNormal, viewTangent);
						kernelMatrix = mat3(viewTangent, viewBitangent, viewNormal);
					}
					collectedNormal+= vec4(viewNormal, 1.0);
					collectedDistance += vec2(abs(viewPosition.z), 1.0);
				}
			#endif

			// Reorient sample vector in view space ...
			vec3 viewSampleVector = kernelMatrix * samplingKernel[i];

			// ... and calculate sample point.
			vec4 viewTestPosition = viewPosition + SSAO_RADIUS * vec4(viewSampleVector, 0.0);

			// projection
			vec4 ndcTestPosition = cameraProj * viewTestPosition;
			// perspecitive division
			ndcTestPosition /= ndcTestPosition.w;

			// [-1;1] to [0;1]
			vec2 texSampingPoint = SNORM2NORM(ndcTestPosition.xy);

			// Get sample viewPos from the viewPosTex texture
			float viewPositionSampledZ;
			#if NOFUSE == 1 
				viewPositionSampledZ = GetViewPos(texSampingPoint).z;
			#else
				viewPositionSampledZ = -1 * abs(texture(viewPosTex, texSampingPoint).z);
			#endif
			// Delta is how much deeper our ray is compared to sample, in elmos
			// negative numbers mean ray is in front of sample, no occulsion
			// positive means ray is behind sample, thus occlusion
			float delta = viewPositionSampledZ - viewTestPosition.z;

			float occlusionCondition = float(delta >= SSAO_MIN); 
			// longer rays should occlude less 
			float myraylen = 1;//1.3 - dot(viewSampleVector, viewSampleVector); // 1-0;

			// smaller delta hits should occlude less
			float occlDelta = smoothstep(0,1,delta);

			// hits further thay the rays length shouldnt occlude either

			float toofar = 1.0 - smoothstep (SSAO_RADIUS * 0.75, SSAO_RADIUS * 1.25, delta);

			occlusionCondition *= myraylen * occlDelta *toofar;
			// old method:
			//float occlusionCondition = float(delta >= SSAO_MIN) * (1.0 - smoothstep(SSAO_RADIUS * 0.75, SSAO_RADIUS * 1.0, delta) );

			occlusion += occlusionCondition;
		}

		occlusion *= fragDistFactor ; //more distance fragments are less occluded

		// TODO: Shadow Density!

		occlusion = occlusion / float(SSAO_KERNEL_SIZE);// normalize by sample count

		float fullylit = clamp(1.0 - occlusion, 0.0, 1.0);

		fullylit = pow(fullylit, SSAO_OCCLUSION_POWER);

		#if DEBUG_SSAO == 1
			fragColor = vec4(vec3( fullylit ), 1.0 );
			return;
		#endif
		// Finally, we pass the normalized XY coords of the normals packed into RG
		// We also pass the distance of the fragment up to far distance in B channel
		// And pass the occlusion level in alpha
		collectedNormal.xyz /= collectedNormal.w;
		collectedDistance.x /= collectedDistance.y;
		fragColor = vec4(vec3(SNORM2NORM(normalize(collectedNormal.xy)), (abs(collectedDistance.x )/ (SSAO_FADE_DIST_0)) ), fullylit);
	}
}