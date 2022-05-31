#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)


//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000
uniform float iconDistance;
in DataGS {
	vec4 g_color;
	vec4 g_uv;
	vec4 g_params; // how to get tbnmatrix here?
	vec4 g_mapnormal;
};

uniform sampler2D miniMapTex;
uniform sampler2D atlasColorAlpha;
uniform sampler2D atlasHeights;
uniform sampler2D atlasNormals;
uniform sampler2D atlasORM;
out vec4 fragColor;

vec4 minimapAtWorldPos(vec2 w){
	vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy; 
	return textureLod(miniMapTex, uvhm, 0.0);
}

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

#line 31000
void main(void)
{
	vec4 tex1color = texture(atlasColorAlpha, g_uv.xy);
	vec4 tex2color = texture(atlasNormals, g_uv.xy);
	vec4 minimapcolor = minimapAtWorldPos( g_params.xy );
	fragColor.rgba = vec4(g_color.rgb * tex1color.rgb, tex1color.a );
	fragColor.rgba = vec4(minimapcolor.rgb* tex1color.r,  tex1color.g + g_params.z) ; 
	fragColor.rgb = tex1color.rgb * (minimapcolor.rgb * 2.0);
	fragColor.a = tex1color.a;

	//fragColor.rgba = vec4(g_uv.x, g_uv.y, 0.0, 0.6);
}