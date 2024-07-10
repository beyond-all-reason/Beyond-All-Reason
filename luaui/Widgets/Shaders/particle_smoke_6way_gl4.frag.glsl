#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000

uniform vec2 atlasSize;
uniform sampler2D atlasTexPlus;
uniform sampler2D atlasTexMinus;

in DataVS {
	vec4 v_worldPos; // needed later depth buffers, alpha is alpha
	vec4 v_uvs; // now and next
	vec4 v_worldNormal;
	vec4 v_emissivecolor; 
	vec4 v_params; // x is blend factor
};

out vec4 fragColor;

vec3 Temperature(float temperatureInKelvins)
{
	vec3 retColor;
	
	float coldness = clamp((temperatureInKelvins - 300)* 0.0005, 0.0, 1.0) ;
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
	retColor = mix( vec3(0.0),retColor, coldness);
	return retColor;
}



#line 31000
void main(void)
{
	fragColor.rgba = vec4(1.0);
	// sample the textures:
	vec4 texpluscolor  = mix(texture(atlasTexPlus, v_uvs.st), texture(atlasTexPlus, v_uvs.pq), v_params.x); // X+ is right
	vec4 texminuscolor = mix(texture(atlasTexMinus, v_uvs.st), texture(atlasTexMinus, v_uvs.pq), v_params.x);

	// We need to swizzle and invert some channels due to the way our sprites are packed:
	// texpluscolor.b points away from the viewer!
    texpluscolor.b *= -1.0;
    texminuscolor.b *= -1.0;



	//v_worldNormal.xyz POINTS TOWARDS THE CAMERA!!!!!!!

	// Shade according to these normals
	//fragColor.rgb = v_worldNormal.xyz * 0.5 + 0.5; return; // debug world normals
	//fragColor.rgb = cameraViewInv[2].xyz ; return;
	
	// calculate albedo:
	fragColor.a = texpluscolor.a;
	fragColor.rgb = vec3(0.5); 
	
	// Calculate lighting dirs
	vec3 plusdir = normalize(texpluscolor.rgb);
	vec3 minusdir = normalize(texminuscolor.rgb);
	vec3 fragmentNormal = normalize(v_worldNormal.xyz);
	vec3 cameraDir = normalize(v_worldPos.xyz);
	vec3 upDir = vec3(0,1,0);
	vec3 rightDir = normalize(cross(upDir, cameraDir));
	upDir = normalize(cross(cameraDir, rightDir));
	

	vec3 sundir = sunDir.xyz;

	mat3 rotationMatrix = mat3(fragmentNormal, upDir, cross(upDir, fragmentNormal));
	plusdir = normalize(rotationMatrix * plusdir);

	// light from the RIGHT:
	//fragColor.rgb = plusdir.xxx; return;
	minusdir = normalize(rotationMatrix * minusdir);
	
	// debug left-right normal, that seems easy:
	fragColor.rgb *= clamp((dot(plusdir, sundir) * 1.0), 0, 1);
	//fragColor.a = 1.0;
	// Calculate absorbtion:
	//fragColor.rgb = vec3(dot(fragmentNormal, sunDir.xyz));
	
	// Apply emissiveness
	float myTemperature = 4000 *  texminuscolor.a;
	//fragColor.rgb += v_emissivecolor.a * Temperature(myTemperature);
	
	//fragColor.rgba = texpluscolor.rgba;
}