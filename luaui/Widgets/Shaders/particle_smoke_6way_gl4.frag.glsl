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

#line 31000
void main(void)
{
	fragColor.rgba = vec4(1.0);
	// sample the textures:
	vec4 texpluscolor  = mix(texture(atlasTexPlus, v_uvs.st), texture(atlasTexPlus, v_uvs.pq), v_params.x);
	vec4 texminuscolor = mix(texture(atlasTexMinus, v_uvs.st), texture(atlasTexMinus, v_uvs.pq), v_params.x);


	// Shade according to these normals
	//fragColor.rgb = v_worldNormal.xyz * 0.5 + 0.5; return; // debug world normals
	//fragColor.rgb = cameraViewInv[2].xyz ; return;
	
	// calculate albedo:
	fragColor.a = texpluscolor.a;
	fragColor.rgb = vec3(0.5); 
	
	// Calculate lighting dirs
	vec3 plusdir = normalize(texpluscolor.rgb);
	vec3 minusdir = normalize(texminuscolor.rgb);
	vec3 sundir = sunDir.xyz;
	fragColor.rgb *= (dot(plusdir, sundir) * 0.5 + 0.5);
	
	// Calculate absorbtion:
	
	// Apply emissiveness
	
	//fragColor.rgba = texpluscolor.rgba;
}