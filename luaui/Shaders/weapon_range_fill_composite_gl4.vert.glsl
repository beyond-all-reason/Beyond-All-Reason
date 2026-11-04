#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// Screen-space pass that paints the merged fill of the attack range rings from the
// coverage mask built by gui_attackrange_gl4.lua, with one screen-sized quad.

//__DEFINES__

layout (location = 0) in vec4 position; // .xy is [-1, +1], .zw is [0, 1]

#line 10000

void main()
{
	gl_Position = vec4(position.xy, 0.0, 1.0);
}
