#version 330

// (C) 2023 Beherith (mysterme@gmail.com)
// Licenced under the MIT licence

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000

//__ENGINEUNIFORMBUFFERDEFS__

//__DEFINES__

in DataVS {
	flat vec4 blendedcolor;
	#ifdef USE_STIPPLE
		float worldscale_circumference;
	#endif
};

out vec4 fragColor;

void main() {
	fragColor.rgba = blendedcolor.rgba;
}