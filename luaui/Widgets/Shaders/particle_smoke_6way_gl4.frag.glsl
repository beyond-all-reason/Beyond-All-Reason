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
	// sample and blend the textures over time:
	vec4 texpluscolor  = mix(texture(atlasTexPlus, v_uvs.st), texture(atlasTexPlus, v_uvs.pq), v_params.x); // X+ is right
	vec4 texminuscolor = mix(texture(atlasTexMinus, v_uvs.st), texture(atlasTexMinus, v_uvs.pq), v_params.x);

	// We need to swizzle and invert some channels due to the way our sprites are packed:
	// texpluscolor.b points away from the viewer!
	// See: https://unity.com/blog/engine-platform/realistic-smoke-with-6-way-lighting-in-vfx-graph
	// lightmap texture format
	// As Z faces us
	vec3 plusdir  = (vec3(texpluscolor.x, texpluscolor.y, texminuscolor.z));
	vec3 minusdir = -1 * (vec3(texminuscolor.x, texminuscolor.y, texpluscolor.z));
	float density = texpluscolor.a;
	float temperature = texminuscolor.a;

	//v_worldNormal.xyz POINTS TOWARDS THE CAMERA!!!!!!!

	// Shade according to these normals
	//fragColor.rgb = v_worldNormal.xyz * 0.5 + 0.5; return; // debug world normals
	//fragColor.rgb = cameraViewInv[2].xyz ; return;
	
	// calculate albedo:
	fragColor.a = texpluscolor.a;
	fragColor.rgb = vec3(0.5); 
	
	// Calculate lighting dirs
	vec3 fragmentNormal = normalize(v_worldNormal.xyz); // world-space fragment normal

	vec3 sundir = normalize(sunDir.xyz);
	
	// Figure out our rotations, our up vector is the camera's up vector:
	vec3 upDir = vec3(cameraViewInv[1].xyz);

	// Using the right-handed coordinate system, the tangent points to the right
	vec3 rightTangent = normalize(cross(upDir,fragmentNormal)); //points to the right

	// The use right handed coord for finding the new Up bitangent
	vec3 upBitangent = normalize(cross(fragmentNormal, rightTangent)); //points up
	
	// The two crosses above ensure an orthogonal basis
	mat3 TBN = mat3(rightTangent, upBitangent, fragmentNormal);

	
	//fragColor.rgba = texpluscolor.rgba;
	if (density<0.001) {
		//fragColor.rgba = vec4(normalize(fragmentNormal) * 0.5 + 0.5, 1.0); // DEBUGGER
		fragColor.rgba = vec4(0.0);
	}else{
		
		fragColor.rgba = vec4((TBN * plusdir) * 0.5 + 0.5, 1.0); // DEBUGGER
		//fragColor.rgba = vec4(texpluscolor.rgb , 1.0); // DEBUGGER
		// uplight
		vec3 testnorm = normalize(texpluscolor.rgb * 2.0 - 1.0);
		fragColor.rgb = vec3((TBN * testnorm)  * 0.5 + 0.5);
		float uplight =  clamp(dot(TBN * plusdir, sundir),0,1);
		float downlight = clamp(dot(TBN * minusdir, sundir), 0,1);
		fragColor.rgb = vec3((uplight + downlight) * 0.5);
		fragColor.a = density;


		// Try fixed angles
		//plusdir = normalize(vec3(0,1,0)); // 1,0,0 points right, 0,1,0 points up, 0,0,1 points toward the camera
		vec3 newdir = TBN*plusdir;
		fragColor.rgb = vec3(newdir) * 0.5 + 0.5;

		vec3 plusdir_rotated = TBN * plusdir;
		vec3 minusdir_rotated = TBN * minusdir;

		vec3 pluslight = vec3(0.0);
		pluslight.x = clamp(dot(plusdir_rotated, sundir), 0, 1);
		
		vec3 minuslight = vec3(0.0);
		minuslight.x = clamp(dot(minusdir_rotated, sundir), 0, 1);

		fragColor.rgb = vec3(pluslight.xxx+minuslight.xxx) * v_emissivecolor.rgb;

		float absorbFactor = (pluslight.x+minuslight.x)*0.5;//  * (1.0 - density);



		vec3 absorbColor = mix(v_emissivecolor.rgb, vec3(1.0),smoothstep(0.0, 1.0, absorbFactor));
		absorbColor = mix(vec3(0.0),absorbColor.rgb, smoothstep(0.0, 0.5, absorbFactor));


		fragColor.rgb = absorbColor;
		fragColor.a = density;

	}
	//fragColor.rgb = vec3(cameraViewInv[1].xyz * 0.5 + 0.5);

	// Apply emissiveness
	float myTemperature = 4000 *  texminuscolor.a;
	fragColor.rgb += v_emissivecolor.a * Temperature(myTemperature);
}
