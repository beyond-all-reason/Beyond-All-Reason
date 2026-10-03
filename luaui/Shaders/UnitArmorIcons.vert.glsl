#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// Unit armor icon outlines, geometry shader path: one point per unit, expanded to a quad in the geometry shader.

#line 5000

layout (location = 0) in vec4 uvrect; // x0, y0, x1, y1 in the icon atlas
layout (location = 1) in vec4 params; // icon size multiplier, state, atlas page
layout (location = 2) in vec4 midoffset; // from the unit's draw position to its mid position
layout (location = 3) in uvec4 instData;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

struct SUniformsBuffer {
	uint composite; // u8 drawFlag; u8 unused1; u16 id;

	uint unused2;
	uint unused3;
	uint unused4;

	float maxHealth;
	float health;
	float unused5;
	float unused6;

	vec4 drawPos;
	vec4 speed;
	vec4[4] userDefined;
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
	SUniformsBuffer uni[];
};

#line 10000

uniform float iconSizeBase;
uniform vec2 outlineWidth; // armored, broken
uniform float iconZoomDist;
uniform vec2 iconFade; // start, vanish
uniform vec4 armoredColor;
uniform vec4 brokenColor;

out DataVS {
	vec4 v_uvrect;
	vec4 v_color;
	vec4 v_sizes; // icon half size in pixels, line width in pixels, atlas page, visible
};

void main() {
	// Icon-only units get no matrix updates, so the uniforms buffer is the only current position.
	vec3 midPos = uni[instData.y].drawPos.xyz + midoffset.xyz;
	vec4 clipPos = cameraViewProj * vec4(midPos, 1.0);

	float sizeMult = params.x;
	float zoom = iconZoomDist / sizeMult;
	float alpha = 1.0;

	// Icons fade out while zooming in, between the fade start and vanish distances.
	if (zoom < iconFade.y) {
		alpha = 0.0;
	} else if (iconFade.y < iconFade.x && zoom < iconFade.x) {
		alpha = (64.0 + 191.0 * (zoom - iconFade.y) / (iconFade.x - iconFade.y)) / 255.0;
	}

	bool visible = alpha > 0.0 && clipPos.w > 0.0 && abs(clipPos.z) <= clipPos.w;
	bool broken = params.y > 1.5;

	v_uvrect = uvrect;
	v_color = broken ? brokenColor : armoredColor;
	v_color.a *= alpha;
	v_sizes = vec4(
		iconSizeBase * 0.5 * sizeMult,
		broken ? outlineWidth.y : outlineWidth.x,
		params.z,
		visible ? 1.0 : 0.0
	);

	gl_Position = vec4(clipPos.xy / max(clipPos.w, 0.0001), 0.0, 1.0);
}
