#version 150 compatibility

uniform vec4 translationScale;
uniform vec4 rotMargin;

uniform int effects;

uniform float gameFrame;

uniform mat4 viewMat;
#if 1
	uniform mat4 projMat;
#else
	#define projMat gl_ProjectionMatrix
#endif

out Data {
	vec4 modelPos;
	vec4 worldPos;
	vec4 viewPos;

	float colormix;
	float normalizedFragDepth;

	noperspective vec2 v_screenUV;
};

#define SNORM2NORM(value) (value * 0.5 + 0.5)

vec4 RotationQuat(vec3 axis, float angle) {
	//axis = normalize(axis);
	float c = cos(0.5 * angle);
	float s = sqrt(1.0 - c * c);
	return vec4(axis.x * s, axis.y * s, axis.z * s, c);
}

vec3 Rotate(vec3 p, vec4 q) {
	return p + 2.0 * cross(q.xyz, cross(q.xyz, p) + q.w * p);
}

vec3 Rotate(vec3 p, vec3 axis, float angle) {
	return Rotate(p, RotationQuat(axis, angle));
}

vec3 RotateY(vec3 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);

	//{x Cos[ang] + z Sin[ang], y, z Cos[ang] - x Sin[ang]}
	return vec3(p.x * c + p.z * s, p.y, p.z * c - p.x * s);
}

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

#define BITMASK_FIELD(value, pos) ((uint(value) & (1u << uint(pos))) != 0u)

void main() {

	modelPos = gl_Vertex;

	if (BITMASK_FIELD(effects, 6)) {
		float r = length(modelPos.xyz);
		float theta = acos(modelPos.z / r);
		float phi = atan(modelPos.y, modelPos.x);
		r += 0.010 * r * SNORM2NORM(sin( (2.0 * theta + translationScale.z  * 13.0 + 3.3 * cos(phi + translationScale.x * 17.0)) * 8.0 + gameFrame * 0.05));
		modelPos.xyz = vec3(r * sin(theta) * cos(phi), r * sin(theta) * sin(phi), r * cos(theta));
	}

	worldPos = vec4(translationScale.www * modelPos.xyz, 1.0);				//scaling
	//worldPos.xyz = Rotate(worldPos.xyz, vec3(0.0, 1.0, 0.0), rotMargin.y);	//rotation around Yaw axis
	worldPos.xyz  = RotateY(worldPos.xyz, rotMargin.y);
	worldPos.xyz += translationScale.xyz;									//translation in world space

	viewPos = viewMat * worldPos;

	//vec3 worldNormal = normalize(Rotate(modelPos.xyz, vec3(0.0, 1.0, 0.0), rotMargin.y));
	vec3 worldNormal = normalize(RotateY(modelPos.xyz, rotMargin.y));
	vec3 viewNormal = mat3(viewMat) * worldNormal;

	colormix = dot(viewNormal, normalize(viewPos.xyz));
	colormix = pow(abs(colormix), rotMargin.w);

	vec2 nearFar = projMat[3][2] / vec2(projMat[2][2] - 1.0, projMat[2][2] + 1.0);
	normalizedFragDepth = (-viewPos.z - nearFar.x) / (nearFar.y - nearFar.x);
	normalizedFragDepth = clamp(normalizedFragDepth, 0.0, 1.0);

	gl_Position = projMat * viewPos;
	v_screenUV = SNORM2NORM(gl_Position.xy / gl_Position.w);
}
