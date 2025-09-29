#if (GL_ARB_conservative_depth == 1)
	layout(depth_unchanged) out float gl_FragDepth;
#endif

uniform vec4 alphaCtrl = vec4(0.5, 1.0, 0.0, 0.0); // < 0.5
layout(binding = 0) uniform sampler2D tex2;

in Data {
	vec4 uvCoord;
};

bool AlphaDiscard(float a) {
	float alphaTestGT = float(a > alphaCtrl.x) * alphaCtrl.y;
	float alphaTestLT = float(a < alphaCtrl.x) * alphaCtrl.z;

	return ((alphaTestGT + alphaTestLT + alphaCtrl.w) == 0.0);
}

void main() {
	if (AlphaDiscard(texture(tex2, uvCoord.xy).a))
		discard;
}
