#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// Unit armor icon outlines: a thin line that follows the silhouette of the unit's icon in the engine icon atlas.

//__DEFINES__

#line 30000

uniform sampler2D iconAtlas0;
uniform sampler2D iconAtlas1;
uniform float borderWidth;

in DataGS {
	vec2 g_uv;
	flat vec4 g_rect; // min.xy, max.xy of the icon in the atlas
	flat vec4 g_line; // one screen pixel in atlas coordinates, line width in pixels, atlas page
	flat vec4 g_color;
	flat vec2 g_depth; // layer depth of the icon, and of its outline
};

out vec4 fragColor;

vec2 uvdx;
vec2 uvdy;

float iconAlpha(vec2 uv) {
	// The quad extends past the icon, and the atlas holds other icons there.
	if (any(lessThan(uv, g_rect.xy)) || any(greaterThan(uv, g_rect.zw))) {
		return 0.0;
	}
	return (g_line.w < 0.5) ? textureGrad(iconAtlas0, uv, uvdx, uvdy).a : textureGrad(iconAtlas1, uv, uvdx, uvdy).a;
}

const vec2 taps[8] = vec2[8](
	vec2(1.0, 0.0), vec2(0.7071, 0.7071), vec2(0.0, 1.0), vec2(-0.7071, 0.7071),
	vec2(-1.0, 0.0), vec2(-0.7071, -0.7071), vec2(0.0, -1.0), vec2(0.7071, -0.7071)
);

void main() {
	uvdx = dFdx(g_uv);
	uvdy = dFdy(g_uv);

	// To cover the outlines under it, the icon writes depth with no color to its inner opaque area.
	float alpha = iconAlpha(g_uv);
	if (alpha > 0.99) {
		fragColor = vec4(0.0);
		gl_FragDepth = g_depth.x;
		return;
	}

	float dilated = 0.0;
	float reached = 0.0;
	for (int i = 0; i < 8; i++) {
		vec2 tap = taps[i] * g_line.xy;
		dilated = max(dilated, iconAlpha(g_uv + tap * g_line.z));
		reached = max(reached, iconAlpha(g_uv + tap * (g_line.z + borderWidth)));
	}
	float inside = smoothstep(0.05, 0.5, alpha);
	dilated = smoothstep(0.05, 0.5, dilated);
	reached = smoothstep(0.05, 0.5, reached);

	// The icon's edge pixels are partly transparent; black fills them so no ground shows inside the line.
	// A second black border outside the line keeps it readable against any ground.
	float border = inside * (1.0 - alpha) + reached * (1.0 - dilated);
	float line = dilated * (1.0 - inside);
	float outline = border + line;
	if (outline < 0.01) {
		discard;
	}

	// Premultiplied, because the layer is composited onto the screen afterwards.
	fragColor = vec4(g_color.rgb * line, outline) * g_color.a;
	gl_FragDepth = (inside > 0.5) ? g_depth.x : g_depth.y;
}
