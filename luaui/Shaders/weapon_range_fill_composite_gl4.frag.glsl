#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// Screen-space pass that paints the merged fill of the attack range rings from the
// coverage mask built by gui_attackrange_gl4.lua.
// The mask's 8-bit red channel holds one bit per range class (1 = ground/cannon,
// 2 = nano, 4 = AA, 8 = separate cannon); a set bit means a filled range disc of
// that class covers the pixel.

//__DEFINES__

#line 20000

uniform sampler2D maskTex;
// .rgb = fill colour, .a = fill alpha of the class stored in mask bit 1 << i
uniform vec4 fillColor0 = vec4(0.0);
uniform vec4 fillColor1 = vec4(0.0);
uniform vec4 fillColor2 = vec4(0.0);
uniform vec4 fillColor3 = vec4(0.0);

//__ENGINEUNIFORMBUFFERDEFS__

out vec4 fragColor;

// Premultiplied "over": later classes are painted on top of earlier ones, like the
// per-class fill passes did.
void blendOver(inout vec4 acc, vec4 fill)
{
	acc = acc * (1.0 - fill.a) + vec4(fill.rgb * fill.a, fill.a);
}

void main()
{
	// The mask covers the world viewport, gl_FragCoord is relative to the window.
	ivec2 texel = ivec2(gl_FragCoord.xy) - ivec2(viewGeometry.zw);
	int bits = int(texelFetch(maskTex, texel, 0).r * 255.0 + 0.5);
	if (bits == 0) {
		discard;
	}
	vec4 acc = vec4(0.0);
	if ((bits & 1) != 0) blendOver(acc, fillColor0);
	if ((bits & 2) != 0) blendOver(acc, fillColor1);
	if ((bits & 4) != 0) blendOver(acc, fillColor2);
	if ((bits & 8) != 0) blendOver(acc, fillColor3);
	// premultiplied output, blended with (GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
	fragColor = acc;
}
