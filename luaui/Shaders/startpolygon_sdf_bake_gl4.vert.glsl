#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// Fullscreen quad over the bake target; v_position.zw is the map-relative uv.

layout (location = 0) in vec4 position; // .xy is [-1, +1], .zw is [0, 1]

#line 10000

out DataVS {
	vec4 v_position;
};

void main()
{
	gl_Position = vec4(position.xy, 0.0, 1.0);
	v_position = position;
}
