#version 420
#line 20000
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__


uniform sampler2D textAtlas;

in DataVS {
	float circlealpha;
	vec4 v_targetcolor;
	vec4 v_uvcoords;
};

out vec4 fragColor;

void main(void)
{

	fragColor = vec4(v_targetcolor.rgb,circlealpha); //debug!
	if (v_uvcoords.x > -0.5){
		vec4 atlascolor = texture2D(textAtlas, v_uvcoords.xy);
		fragColor.rgba = vec4(atlascolor.rgba);
	}
	//fragColor.rgba = vec4(1,1,1,0.5);
}