#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack : require

// Reclaim field highlight: fields as chunked geometry, per-chunk parameters in an SSBO, distance fade
// from the camera position. See luaui/Include/reclaim_field_renderer_gl4.lua for the layout.

//__DEFINES__

layout (location = 0) in vec4 posKind; // xyz world position, w: 0 inner fill, 1 outer gradient, 2 outline

// two vec4 per chunk: (centre.xyz, pulse scale), (alpha, type 0 metal / 1 energy, fade bypass, unused)
layout(std430, binding = SSBO_BINDING) readonly buffer ClusterParams {
	vec4 params[];
};

//__ENGINEUNIFORMBUFFERDEFS__

uniform int vertsPerChunk;
uniform vec2 toggles; // group fade of the metal and energy fields
uniform float yOffset;
uniform vec2 fadeDist; // start and end of the camera distance fade
uniform vec4 fillColorMetal; // rgb + fill alpha
uniform vec4 fillColorEnergy;
uniform vec4 edgeColorMetal; // rgb + outline alpha
uniform vec4 edgeColorEnergy;
uniform float gradientAlpha; // alpha at the outer edge of the ramp
uniform float energyOpacity; // multiplier on every energy field alpha

out vec4 vColor;

void main() {
	int chunk = gl_VertexID / vertsPerChunk;
	vec4 p0 = params[2 * chunk];
	vec4 p1 = params[2 * chunk + 1];

	bool energy = p1.y > 0.5;
	float alpha = p1.x * (energy ? toggles.y : toggles.x);

	vec3 pos = posKind.xyz;
	pos.xz = p0.xz + (pos.xz - p0.xz) * p0.w; // pulse scale about the field centre
	pos.y += yOffset;

	vec3 camPos = cameraViewInv[3].xyz;
	float dist = distance(camPos, p0.xyz);
	float fade = clamp(1.0 - (dist - fadeDist.x) / (fadeDist.y - fadeDist.x), 0.0, 1.0);
	fade = max(fade, p1.z); // bypass: always full strength

	vec4 fillCol = energy ? fillColorEnergy : fillColorMetal;
	vec4 edgeCol = energy ? edgeColorEnergy : edgeColorMetal;
	float kind = posKind.w;
	float baseAlpha = (kind < 0.5) ? fillCol.a : ((kind < 1.5) ? gradientAlpha : edgeCol.a);
	vec3 rgb = (kind < 1.5) ? fillCol.rgb : edgeCol.rgb;
	alpha *= baseAlpha * fade * (energy ? energyOpacity : 1.0);

	vColor = vec4(rgb, alpha);
	if (alpha <= 0.0005) {
		gl_Position = vec4(-2.0, -2.0, -2.0, 1.0); // invisible: clip the whole primitive
	} else {
		gl_Position = cameraViewProj * vec4(pos, 1.0);
	}
}
