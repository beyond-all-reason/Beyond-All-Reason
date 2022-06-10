#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)
#line 5000

layout (location = 0) in vec4 position; // xyz and etc garbage
//layout (location = 1) in vec3 normals; // unused
//layout (location = 2) in vec2 uvs;  // unused

layout (location = 3) in vec4 worldposrad; 
layout (location = 4) in vec4 worldposrad2; 
layout (location = 5) in vec4 lightcolor; 
layout (location = 6) in vec4 falloff_dense_scattering;
layout (location = 7) in vec4 otherparams;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000
uniform int pointbeamcone = 0; // 0 = point, 1 = beam, 2 = cone

out DataVS {
	vec4 v_worldPosRad;
	vec4 v_worldPosRad2;
	vec4 v_lightcolor;
	vec4 v_falloff_dense_scattering;
	vec4 v_otherparams;
	vec4 v_position;
	vec4 v_debug;
};

void main()
{
	float time = timeInfo.x + timeInfo.w;
	
	vec4 worldPos = vec4(1.0);
	if (pointbeamcone == 0){ // point
		worldPos.xyz = worldposrad.xyz + position.xyz * worldposrad.w;
	}
	else if (pointbeamcone == 1){ // beam
		// we will tranform along this vector, where Y shall be the upvector
		// our null vector is +X
		vec3 centertoend = worldposrad.xyz - worldposrad2.xyz;
		float halfbeamlength = length(centertoend);
		// Scale the box to correct size (along beam is X dir)
		worldPos.xyz = position.xyz * vec3(halfbeamlength + worldposrad.w , worldposrad.w, worldposrad.w );
		// TODO rotate this box
		// Place the box in the world
		worldPos.xyz += worldposrad.xyz;
	}
	else if (pointbeamcone == 2){ //cone that points up, (y = 1), with radius =1, bottom flat on Y=0 plane
		// make it so that cone is at 0 and the opening points to y is up
		worldPos.xyz = position.xyz;
		worldPos.y = 1.0 - worldPos.y;
		worldPos.z *= -1;
		// now scale it
		float conewidth = atan(worldposrad2.w);
		worldPos.xyz *= vec3(1.0, conewidth, 1.0) * worldposrad.w;
		
		// ROTATE IT?
		
		// move it to world:
		worldPos.xyz += worldposrad.xyz;
	}
	v_position = worldPos;
	gl_Position = cameraViewProj * worldPos;

	v_worldPosRad = worldposrad;
	v_worldPosRad2 = worldposrad2;
	v_lightcolor = lightcolor;
	v_falloff_dense_scattering = falloff_dense_scattering;
	v_otherparams = otherparams;
	v_debug = vec4(0.0);
	
}