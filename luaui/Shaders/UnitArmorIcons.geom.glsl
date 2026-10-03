#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// Unit armor icon outlines, geometry shader path: expands each unit's point to a screen-space quad around its icon.

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

layout(points) in;
layout(triangle_strip, max_vertices = 4) out;

#line 20000

uniform float borderWidth;

in DataVS {
	vec4 v_uvrect;
	vec4 v_color;
	vec4 v_sizes; // icon half size in pixels, line width in pixels, atlas page, visible
} dataIn[];

out DataGS {
	vec2 g_uv;
	flat vec4 g_rect; // min.xy, max.xy of the icon in the atlas
	flat vec4 g_line; // one screen pixel in atlas coordinates, line width in pixels, atlas page
	flat vec4 g_color;
};

void corner(vec2 offset) {
	vec4 uvrect = dataIn[0].v_uvrect;
	float halfSize = dataIn[0].v_sizes.x;
	float width = dataIn[0].v_sizes.y;
	float padded = halfSize + width + borderWidth + 1.0;

	vec2 iconPos = offset * (padded / halfSize) * 0.5 + 0.5;
	g_uv = vec2(mix(uvrect.x, uvrect.z, iconPos.x), mix(uvrect.w, uvrect.y, iconPos.y));
	g_rect = vec4(min(uvrect.xy, uvrect.zw), max(uvrect.xy, uvrect.zw));
	g_line = vec4(abs(uvrect.zw - uvrect.xy) / (2.0 * halfSize), width, dataIn[0].v_sizes.z);
	g_color = dataIn[0].v_color;

	gl_Position = vec4(gl_in[0].gl_Position.xy + offset * padded * 2.0 / viewGeometry.xy, 0.0, 1.0);
	EmitVertex();
}

void main() {
	if (dataIn[0].v_sizes.w < 0.5) {
		return;
	}

	corner(vec2(-1.0, -1.0));
	corner(vec2(1.0, -1.0));
	corner(vec2(-1.0, 1.0));
	corner(vec2(1.0, 1.0));
	EndPrimitive();
}
