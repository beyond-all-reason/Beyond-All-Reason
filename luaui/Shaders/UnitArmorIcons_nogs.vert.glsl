#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// Unit armor icon outlines, fallback path for hardware without geometry shaders: an instanced quad per unit,
// expanded here exactly as UnitArmorIcons.geom.glsl expands a point.

#line 5000

layout (location = 0) in vec4 position_xy_uv;
layout (location = 1) in vec4 uvrect; // x0, y0, x1, y1 in the icon atlas
layout (location = 2) in vec4 params; // icon size multiplier, state (0 icon only), atlas page, draw order
layout (location = 3) in vec4 midoffset; // from the unit's draw position to its mid position
layout (location = 4) in uvec4 instData;

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
uniform float borderWidth;
uniform float iconZoomDist;
uniform vec2 iconFade; // start, vanish
uniform vec4 armoredColor;
uniform vec4 brokenColor;
uniform float iconsSortedByDepth;
uniform float compositePass;

// Named and laid out as the geometry shader's output, so both paths share one fragment shader.
out DataGS {
	vec2 g_uv;
	flat vec4 g_rect; // min.xy, max.xy of the icon in the atlas
	flat vec4 g_line; // one screen pixel in atlas coordinates, line width in pixels, atlas page
	flat vec4 g_color;
	flat vec2 g_depth; // layer depth of the icon, and of its outline
	flat float g_outlined;
	flat float g_owner; // marks the layer pixels this icon wrote
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

	bool outlined = params.y > 0.5;

	// Icons without an outline only cover the outlines under them, so they have nothing to composite.
	if (alpha <= 0.0 || clipPos.w <= 0.0 || abs(clipPos.z) > clipPos.w || (!outlined && compositePass > 0.5)) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		g_uv = vec2(0.0);
		g_rect = vec4(0.0);
		g_line = vec4(0.0);
		g_color = vec4(0.0);
		g_depth = vec2(0.0);
		g_outlined = 0.0;
		g_owner = 0.0;
		return;
	}

	// The engine sorts icons by draw order, then draws the nearest last, so outlines stack the same way.
	float cameraDist = distance(cameraViewInv[3].xyz, midPos);
	float layer = 15.0 - clamp(floor(params.w + 0.5), 0.0, 15.0);
	float layerDist = cameraDist / (cameraDist + 8192.0);

	// Without the distance sort the sequence is unknown, so icons cover the outlines in their draw order.
	vec2 layerDepth = vec2(layer + layerDist * iconsSortedByDepth, layer + layerDist) / 16.0;

	bool broken = params.y > 1.5;
	float width = outlined ? (broken ? outlineWidth.y : outlineWidth.x) : 0.0;
	float halfSize = iconSizeBase * 0.5 * sizeMult;
	float padded = halfSize + width + borderWidth + 1.0;
	vec2 offset = position_xy_uv.xy;

	vec2 iconPos = offset * (padded / halfSize) * 0.5 + 0.5;
	g_uv = vec2(mix(uvrect.x, uvrect.z, iconPos.x), mix(uvrect.w, uvrect.y, iconPos.y));
	g_rect = vec4(min(uvrect.xy, uvrect.zw), max(uvrect.xy, uvrect.zw));
	g_line = vec4(abs(uvrect.zw - uvrect.xy) / (2.0 * halfSize), width, params.z);
	g_color = broken ? brokenColor : armoredColor;
	g_color.a *= alpha;
	g_depth = layerDepth;
	g_outlined = outlined ? 1.0 : 0.0;
	g_owner = float(instData.y) + 1.0;

	gl_Position = vec4(clipPos.xy / clipPos.w + offset * padded * 2.0 / viewGeometry.xy, 0.0, 1.0);
}
