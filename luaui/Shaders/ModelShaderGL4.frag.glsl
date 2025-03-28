layout(binding = 0) uniform sampler2D tex1;
layout(binding = 1) uniform sampler2D tex2;

#if (USE_SHADOWS == 1)
	layout(binding = 2) uniform sampler2DShadow shadowTex;
#endif

layout(binding = 3) uniform samplerCube reflectTex;

layout(std140, binding = 1) uniform UniformParamsBuffer {
	vec3 rndVec3; //new every draw frame.
	uint renderCaps; //various render booleans

	vec4 timeInfo;     //gameFrame, gameSeconds, drawFrame, frameTimeOffset
	vec4 viewGeometry; //vsx, vsy, vpx, vpy
	vec4 mapSize;      //xz, xzPO2
	vec4 mapHeight;    //height minCur, maxCur, minInit, maxInit

	vec4 fogColor;  //fog color
	vec4 fogParams; //fog {start, end, 0.0, scale}

	vec4 sunDir;

	vec4 sunAmbientModel;
	vec4 sunAmbientMap;
	vec4 sunDiffuseModel;
	vec4 sunDiffuseMap;
	vec4 sunSpecularModel;
	vec4 sunSpecularMap;

	vec4 shadowDensity; // {ground, units, 0.0, 0.0}

	vec4 windInfo; // windx, windy, windz, windStrength
	vec2 mouseScreenPos; //x, y. Screen space.
	uint mouseStatus; // bits 0th to 32th: LMB, MMB, RMB, offscreen, mmbScroll, locked
	uint mouseUnused;
	vec4 mouseWorldPos; //x,y,z; w=0 -- offmap. Ignores water, doesn't ignore units/features under the mouse cursor

	vec4 teamColor[255]; //all team colors
};


in Data {
	vec4 uvCoord;
	vec4 teamCol;

	vec4 worldPos;
	vec3 worldNormal;
	
	vec4 modelVertexPos;
	vec4 pieceVertexPosOrig;
	vec4 worldVertexPos;
	// TBN matrix components
	vec3 worldTangent;
	vec3 worldBitangent;
	// main light vector(s)
	vec3 worldCameraDir;

	// shadowPosition
	vec4 shadowVertexPos;

	// auxilary varyings
	float aoTerm;
	float selfIllumMod;
	float fogFactor;
};

uniform vec4 alphaCtrl = vec4(0.0, 0.0, 0.0, 1.0); //always pass
uniform vec4 colorMult = vec4(1.0);
uniform vec4 nanoColor = vec4(0.0);

bool AlphaDiscard(float a) {
	float alphaTestGT = float(a > alphaCtrl.x) * alphaCtrl.y;
	float alphaTestLT = float(a < alphaCtrl.x) * alphaCtrl.z;

	return ((alphaTestGT + alphaTestLT + alphaCtrl.w) == 0.0);
}

float GetShadowMult(vec3 shadowCoord, float NdotL) {
	#if (USE_SHADOWS == 1)
		const float cb = 5e-5;
		float bias = cb * tan(acos(NdotL));
		bias = clamp(bias, 0.0, 5.0 * cb);

		shadowCoord.z -= bias;

		return texture(shadowTex, shadowCoord).r;
	#else
		return 1.0;
	#endif
}

#if (DEFERRED_MODE == 1)
	out vec4 fragColor[GBUFFER_ZVALTEX_IDX];
#else
	out vec4 fragColor;
#endif

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

void main(void)
{
	float lodbias = -0.5;
	vec4 texColor1 = texture(tex1, uvCoord.xy, lodbias);
	vec4 texColor2 = texture(tex2, uvCoord.xy, lodbias);

	float alpha = teamCol.a * texColor2.a;
	if (AlphaDiscard(alpha))
		discard;

	texColor1.rgb = mix(texColor1.rgb, teamCol.rgb, texColor1.a);

	vec3 L = normalize(sunDir.xyz);
	vec3 V = normalize(worldCameraDir);
	vec3 H = normalize(L + V); //half vector
	vec3 N = normalize(worldNormal);
	vec3 R = -reflect(V, N);

	vec3 reflColor = texture(reflectTex, R).rgb;

	float NdotL = clamp(dot(N, L), 0.0, 1.0);
	float HdotN = clamp(dot(N, H), 0.0, 1.0);

	float shadowMult = mix(1.0, GetShadowMult(shadowVertexPos.xyz / shadowVertexPos.w, NdotL), shadowDensity.y);

	vec3 light = sunAmbientModel.rgb + (NdotL * sunDiffuseModel.rgb);

	// A general rule of thumb is to set Blinn-Phong exponent between 2 and 4 times the Phong shininess exponent.
	vec3 specular = sunSpecularModel.rgb * min(pow(HdotN, 2.5 * sunSpecularModel.a) + 0.3 * pow(HdotN, 2.0 * 3.0), 1.0);
	specular *= (texColor2.g * 4.0);

	// no highlights if in shadow; decrease light to ambient level
	specular *= shadowMult;

	light = mix(sunAmbientModel.rgb, light, shadowMult);
	light = mix(light, reflColor, texColor2.g); // reflection
	light += texColor2.rrr; // self-illum

	vec3 finalColor = texColor1.rgb * light + specular;


	#if (DEFERRED_MODE == 1)
		vec4 diffColor = colorMult * vec4(mix(texColor1.rgb, nanoColor.rgb, nanoColor.a), alpha);
		fragColor[GBUFFER_NORMTEX_IDX] = vec4(SNORM2NORM(worldNormal), 1.0);
		fragColor[GBUFFER_DIFFTEX_IDX] = diffColor;
		fragColor[GBUFFER_SPECTEX_IDX] = vec4(texColor2.rgb, alpha);
		fragColor[GBUFFER_EMITTEX_IDX] = vec4(0.0, 0.0, 0.0, 0.0);
		fragColor[GBUFFER_MISCTEX_IDX] = vec4(0.0, 0.0, 0.0, 0.0);
	#else
		fragColor.rgb = mix( fogColor.rgb, finalColor.rgb, fogFactor  );
		fragColor.rgb = mix(fragColor.rgb,  nanoColor.rgb, nanoColor.a);
		fragColor.a   = alpha;
		fragColor *= colorMult;
		fragColor.rgb *= vec3(2.0, 1.0, 1.0);
		//fragColor.rgb = texColor1.rgb;
	#endif
}