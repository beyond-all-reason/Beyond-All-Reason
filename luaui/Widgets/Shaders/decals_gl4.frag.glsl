#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)


//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

// TODO: maybe sample SSMF mapnormals too?

#line 30000
uniform float iconDistance;
in DataGS {
	vec4 g_color;
	vec4 g_uv;
	vec4 g_position; // how to get tbnmatrix here?
	vec4 g_mapnormal;
	vec4 g_tangent;
	vec4 g_bitangent;
	mat3 tbnmatrix; // this currently contains the Z-up world-rotated orthogonal coords of each vertex
	mat3 tbninverse;
};

uniform sampler2D miniMapTex;
uniform sampler2D mapNormalsTex;
uniform sampler2D atlasColorAlpha;
uniform sampler2D atlasHeights;
uniform sampler2D atlasNormals;
uniform sampler2D atlasORM;
out vec4 fragColor;



vec3 Temperature(float temperatureInKelvins)
{
	vec3 retColor;
	
	temperatureInKelvins = clamp(temperatureInKelvins, 1000.0, 40000.0) / 100.0;
	
	if (temperatureInKelvins <= 66.0)
	{
		retColor.r = 1.0;
		retColor.g = 0.39008157876901960784 * log(temperatureInKelvins) - 0.63184144378862745098;
	}
	else
	{
		float t = temperatureInKelvins - 60.0;
		retColor.r = 1.29293618606274509804 * pow(t, -0.1332047592);
		retColor.g = 1.12989086089529411765 * pow(t, -0.0755148492);
	}
	
	if (temperatureInKelvins >= 66.0)
		retColor.b = 1.0;
	else if(temperatureInKelvins <= 19.0)
		retColor.b = 0.0;
	else
		retColor.b = 0.54320678911019607843 * log(temperatureInKelvins - 10.0) - 1.19625408914;

	retColor = clamp(retColor,0.0,1.0);
	return retColor;
}

// RNM func from: https://blog.selfshadow.com/publications/blending-in-detail/
vec3 ReOrientNormalPacked(vec3 basenormal, vec3 detailnormal){ // for normals packed to [0,1], z-up
	vec3 t = basenormal.xyz   * vec3( 2.0,  2.0, 2.0) + vec3(-1.0, -1.0,  0.0);
	vec3 u = detailnormal.xyz * vec3(-2.0, -2.0, 2.0) + vec3( 1.0,  1.0, -1.0);
	vec3 r = t * dot(t, u) - u * t.z;
	return normalize(r);
}
vec3 ReOrientNormalUnpacked(vec3 basenormal, vec3 detailnormal){ // for unpacked [-1,1] normals, only works when Z is up
	vec3 t = basenormal.xyz + vec3(0.0, 0.0,  1.0);
	vec3 u = detailnormal.xyz * vec3(-1.0, -1.0, 1.0);
	vec3 r = t * dot(t, u)/t.z - u;
	return normalize(r);
}


#line 31000
void main(void)
{
	
	vec3 camtoworld = 
	vec4 tex3color = texture(atlasHeights, g_uv.xy);
	float height = 
	
	vec2 parallaxUV = g_uv.xy + 
	// do parallax here !
	
	vec4 tex1color = texture(atlasColorAlpha, g_uv.xy);
	vec4 tex2color = texture(atlasNormals, g_uv.xy);
	vec4 tex4color = texture(atlasORM, g_uv.xy);
	vec3 fragNormal = tex2color.rgb * 2.0 - 1.0;
	vec2 uvhm = heighmapUVatWorldPos(g_params.xz);
	vec4 minimapcolor = textureLod(miniMapTex, uvhm, 0.0);
	fragColor.rgba = vec4(g_color.rgb * tex1color.rgb, tex1color.a );
	fragColor.rgba = vec4(minimapcolor.rgb* tex1color.r,  tex1color.g ) ; 
	vec3 blendedcolor = tex1color.rgb * (minimapcolor.rgb * 2.0);

	fragColor.a = tex1color.a * tex1color.a;
	//return;
	fragColor.rgb = g_mapnormal.rgb;// * 0.5 + 0.5;
	
	vec3 mapnormal = textureLod(mapNormalsTex, uvhm, 0.0).raa; // seems to be in the [-1, 1] range!, raaa is its true return
	mapnormal.g = sqrt( 1.0 - dot( mapnormal.rb, mapnormal.rb));
	fragColor.rgb = fract((g_mapnormal.rgb * 0.5 + 0.5));
	fragColor.a = 1.0;
	fragColor.rgb = g_bitangent.rgb;
	//fragColor.rgba = vec4(g_uv.x, g_uv.y, 0.0, 0.6);
	vec3 worldspacenormal = tbnmatrix * fragNormal.rgb;
	
	vec3 reorientedNormal = ReOrientNormalUnpacked(mapnormal.xzy, worldspacenormal.xzy).xzy;
	 fragColor.rgb = mapnormal.rgb;
	fragColor.rgb = worldspacenormal.rgb;
	fragColor.rgb = reorientedNormal.rgb * 0.5 + 0.5;
	//fragColor.rgb = fragNormal.rgb;
	fragColor.a = tex1color.a ;
	fragColor.rgb = blendedcolor;
}