#version 150 compatibility

#define DEPTH_CLIP01 ###DEPTH_CLIP01###
#define MERGE_MISC ###MERGE_MISC###

uniform sampler2D modelDepthTex;
uniform sampler2D mapDepthTex;
uniform sampler2D modelDiffTex;

uniform sampler2D modelNormalTex;
uniform sampler2D mapNormalTex;

uniform sampler2D modelMiscTex;
uniform sampler2D mapMiscTex;

uniform vec2 viewPortSize;

uniform mat4 invProjMatrix;
uniform mat4 viewMatrix;

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

// Calculate out of the fragment in screen space the view space position.
vec4 GetViewPos(vec2 texCoord, float sampledDepth) {
	vec4 projPosition = vec4(0.0, 0.0, 0.0, 1.0);

	//texture space [0;1] to NDC space [-1;1]
	#if (DEPTH_CLIP01 == 1)
		//don't transform depth as it's in the same [0;1] space
		projPosition.xyz = vec3(NORM2SNORM(texCoord), sampledDepth);
	#else
		projPosition.xyz = NORM2SNORM(vec3(texCoord, sampledDepth));
	#endif

	vec4 viewPosition = invProjMatrix * projPosition;
	viewPosition /= viewPosition.w;

	return viewPosition;
}

void main() {
	vec2 uv = gl_FragCoord.xy / viewPortSize;

	float modelAlpha = texture(modelDiffTex, uv, 0).a;
	float validFragment = step(1.0 / 255.0, modelAlpha); //agressive approach

	float modelDepth = texture(modelDepthTex, uv).r;
	float mapDepth = texture(mapDepthTex, uv).r;

	float modelOccludesMap = float(modelDepth < mapDepth);
	float depth = mix(mapDepth, modelDepth, modelOccludesMap);

	vec4 viewPosition = GetViewPos(uv, depth);

	vec3 modelNormal = texture(modelNormalTex, uv).rgb;
	vec3 mapNormal = texture(mapNormalTex, uv).rgb;

	vec3 viewNormal = mix(mapNormal, modelNormal, modelOccludesMap);
	float validNormal = step(0.2, length(viewNormal)); //empty spaces in g-buffer will have vec3(0.0) normals

	viewNormal = NORM2SNORM(viewNormal);
	viewNormal = normalize(viewNormal);
	viewNormal = vec3(viewMatrix * vec4(viewNormal, 0.0)); //transform world-->view space

	#if (MERGE_MISC == 1)
		vec4 modelMiscInfo = texture(modelMiscTex, uv);
		vec4 mapMiscInfo = texture(mapMiscTex, uv);
		vec4 miscInfo = mix(mapMiscInfo, modelMiscInfo, modelOccludesMap);
	#endif

	// MRT output:
	//[0] = gbuffFuseViewPosTex
	//[1] = gbuffFuseViewNormalTex
	//[2] = gbuffFuseMiscTex (conditional to MERGE_MISC == 1)
	gl_FragData[0].xyz = mix( vec3(0.0), viewPosition.xyz, validFragment);
	gl_FragData[1].xyz = mix( vec3(0.0), viewNormal.xyz, validNormal * validFragment);
	#if (MERGE_MISC == 1)
		gl_FragData[2] = miscInfo;
	#endif
}