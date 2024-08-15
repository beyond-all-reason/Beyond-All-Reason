#version 420
// This shader is (c) Beherith (mysterme@gmail.com), Licensed under the MIT License

#line 20000


uniform sampler2D heightmapTex;

//__ENGINEUNIFORMBUFFERDEFS__

//__DEFINES__
in DataVS {
	vec4 worldPos; // pos and radius
	vec4 blendedcolor;
};

out vec4 fragColor;

void main() {
	fragColor.rgb = vec3(0,0,0);
	//fragColor.rgb = vec3(0,1,0);
	if (abs(blendedcolor.w - blendedcolor.z) > worldPos.w){
		fragColor.rgb = vec3(1,0,0);
	}
	//fragColor.b = abs(blendedcolor.w - blendedcolor.z) * 0.1;
	//fragColor.b = blendedcolor.z * 0.001;
	//if (abs)
	fragColor.a = 0.5;
} 