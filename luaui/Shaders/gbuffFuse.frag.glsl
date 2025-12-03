#version 430 core

//__DEFINES__

uniform sampler2D modelDepthTex;
uniform sampler2D mapDepthTex;

uniform sampler2D unitStencilTex;

uniform mat4 invProjMatrix;


in DataVS {
	vec4 vs_position_texcoords;
};

out vec4 fragColor;

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
	
	vec2 uv = gl_FragCoord.xy * vec2(1.0/VSX, 1.0/VSY);
	//vec2 uv = gl_TexCoord[0].xy * vec2(2,-2) + vec2(0,2.0);
	//fragColor = vec4(uv.xy, 0.0, 1.0); return;
	#if USE_STENCIL == 1 
		if (texture(unitStencilTex, uv).r < 0.1) {
			fragColor = vec4(0,0,0,0) ; 
			return;
		}
	#endif

	float modelDepth = texture(modelDepthTex, uv).r;
	float mapDepth = texture(mapDepthTex, uv).r;

	float modelOccludesMap = float(modelDepth < mapDepth);
	float depth = mix(mapDepth, modelDepth, modelOccludesMap);

	vec4 viewPosition = GetViewPos(uv, depth);

	if (modelOccludesMap < 0.5) viewPosition.z *= -1.0;
	fragColor.xyz = viewPosition.xyz;

}