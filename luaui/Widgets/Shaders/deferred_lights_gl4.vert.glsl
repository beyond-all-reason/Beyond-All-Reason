#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)
#line 5000

layout (location = 0) in vec4 position; // xyz and etc garbage
//layout locations 1 and 2 contain primitive specific garbage and should not be used

layout (location = 3) in vec4 worldposrad; 
layout (location = 4) in vec4 worldposrad2; 
layout (location = 5) in vec4 lightcolor; 
layout (location = 6) in vec4 falloff_dense_scattering_sourceocclusion; // 
layout (location = 7) in vec4 otherparams; // 
layout (location = 8) in uint pieceIndex; // for piece type lights
layout (location = 9) in uvec4 instData; // matoffset, uniformoffset, teamIndex, drawFlags {id = 5, name = 'instData', size = 4, type = GL.UNSIGNED_INT},

			
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

layout(std140, binding = 0) readonly buffer MatrixBuffer {
	mat4 mat[];
};

struct SUniformsBuffer {
	uint composite; //     u8 drawFlag; u8 unused1; u16 id;

	uint unused2;
	uint unused3;
	uint unused4;

	float maxHealth;
	float health;
	float unused5;
	float unused6;

	vec4 speed;
	vec4[5] userDefined; //can't use float[20] because float in arrays occupies 4 * float space
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
	SUniformsBuffer uni[];
};

#line 10000

uniform float pointbeamcone = 0;// = 0; // 0 = point, 1 = beam, 2 = cone


// this uniform needs some extra. If it is 1, then the primitives should point in the -Z direction, and be moved and rotated with the unit itself
// If the unit is not being drawn, it must be switched off
// One should still be able to specify an offset for this. 
// our overdraw additional offsets become a problem possibly for this 

uniform float attachedtounitID = 0;

out DataVS {
	flat vec4 v_worldPosRad;
	flat vec4 v_worldPosRad2;
	flat vec4 v_lightcolor;
	flat vec4 v_falloff_dense_scattering_sourceocclusion;
	flat mat3 v_conerotinv;
	vec4 v_depths_center_map_model_min;
	vec4 v_otherparams; // this could be anything 
	vec4 v_position;
	vec4 v_debug;
};

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;

vec4 depthAtWorldPos(vec4 worldPosition){ 
	// takes a point, transforms it to worldspace, and checks for occlusion against map, model buffer, and returns all the depths
	// x: light pos depth, y: map depth, z: model depth, w: min(map, model)
	vec4 screenPosition = cameraViewProj * worldPosition;
	screenPosition.xyz = screenPosition.xyz / screenPosition.w;
	// Transform from [-1,1] screen space into [0, 1] UV space
	vec2 screenUV = clamp((screenPosition.xy * 0.5) +0.5, 0.001, 0.999);
	vec4 depths;
	
	depths.x = screenPosition.z ;
	float mapdepth = texture(mapDepths, screenUV).x;
	float modeldepth = texture(modelDepths, screenUV).x;
	depths.y = mapdepth;
	depths.z = modeldepth;
	depths.w = min(mapdepth, modeldepth);
	return depths; 
}

void main()
{
	float time = timeInfo.x + timeInfo.w;
	
	v_worldPosRad = worldposrad ;
	float lightRadius = worldposrad.w;
	v_worldPosRad.xyz += 48 * sin(time * vec3(0.01, 0.011, 0.012) + v_worldPosRad.xyz );
	
	// Ok so here comes the fun part, where we if we have a unitID then fun things happen
	// We 
	if (attachedtounitID > 0){
		v_worldPosRad.xyz;
		mat4 pieceMatrix = mat[instData.x + pieceIndex + 1u];
		mat4 worldMatrix = mat[instData.x];
		mat4 worldPieceMatrix = worldMatrix * pieceMatrix; // for the below
	}
	
	
	vec3 lightCenterPosition = v_worldPosRad.xyz;
	v_worldPosRad2 = worldposrad2;
	v_lightcolor = lightcolor;
	v_falloff_dense_scattering_sourceocclusion = falloff_dense_scattering_sourceocclusion;
	v_depths_center_map_model_min = vec4(1.0); // just a sanity init
	v_otherparams = otherparams;
	v_debug = vec4(0.0);
	
	vec4 worldPos = vec4(1.0);
	if (pointbeamcone < 0.5){ // point
	
		//scale it and place it into the world
		//Make it a tiny bit bigger *(1.1) cause the blocky sphere is smaller than the actual radius
		// the -1 is for inverting it so we always see the back faces (great for occlusion testing!)
		worldPos.xyz = lightCenterPosition + -1 * position.xyz * lightRadius * 1.1;
		v_depths_center_map_model_min = depthAtWorldPos(vec4(lightCenterPosition,1.0));
		//v_depths_center_map_model_min.w = depthAtWorldPos(vec4(worldPos.xyz,1.0)); // for per-pixel stuff
		//
	}
	else if (pointbeamcone < 1.5){ // beam
		// we will tranform along this vector, where Y shall be the upvector
		// our null vector is +X
		vec3 centertoend = lightCenterPosition - worldposrad2.xyz;
		float halfbeamlength = length(centertoend);
		// Scale the box to correct size (along beam is X dir)
		worldPos.xyz = position.xyz * vec3( lightRadius , halfbeamlength + lightRadius, lightRadius );
		
		// TODO rotate this box
		vec3 oldfw = vec3(0,1,0); // The old forward direction is -y
		vec3 newfw = normalize(centertoend); // the new forward direction shall be the normal that we want
		vec3 newright = normalize(cross(newfw, oldfw)); // the new right direction shall be the vector perpendicular to old and new forward
		vec3 newup = normalize(cross(newright, newfw)); // the new up direction shall be the vector perpendicular to new right and new forward
		// TODO: handle the two edge cases where newfw == (oldfw or -1*oldfw)
		mat3 rotmat = mat3( // assemble the rotation matrix
				newup,
				newfw, 
				newright 
			);
		worldPos.xyz = rotmat * worldPos.xyz;
		
		v_conerotinv = transpose(rotmat);
		
		// Place the box in the world
		worldPos.xyz += lightCenterPosition;
		
		v_depths_center_map_model_min = depthAtWorldPos(vec4(lightCenterPosition,1.0));
	}
	else if (pointbeamcone > 1.5){ // cone
		// input cone that has pointy end up, (y = 1), with radius =1, flat on Y=0 plane
		// make it so that cone tip is at 0 and the opening points to -y
		worldPos.xyz = position.xyz;
		worldPos.x *= -1.0; // flip the cone inside out
		worldPos.y = (worldPos.y*1.1 - 1.) * -1;
		//worldPos.y *= 1;
	
		worldPos.xz *= tan(worldposrad2.w); // Scale the flat of the cone by the half-angle of its opening
		v_worldPosRad2.w = cos(worldposrad2.w); // pass through the cosine to avoid this calc later on
		v_worldPosRad2.xyz = normalize(worldposrad2.xyz); // normalize this here for sanity
		worldPos.xyz *= lightRadius * 1.05; // scale it all by the height of the cone, and a bit of extra 
		
		// Now our cone is opening forward towards  -y, but we want it to point into the worldposrad2.xyz
		vec3 oldfw = vec3(0, -1,0); // The old forward direction is -y
		vec3 newfw = normalize(worldposrad2.xyz); // the new forward direction shall be the normal that we want
		vec3 newright = normalize(cross(newfw, oldfw)); // the new right direction shall be the vector perpendicular to old and new forward
		vec3 newup = normalize(cross(newright, newfw)); // the new up direction shall be the vector perpendicular to new right and new forward
		// TODO: handle the two edge cases where newfw == (oldfw or -1*oldfw)
		mat3 rotmat = mat3( // assemble the rotation matrix
				newup,
				newfw, 
				newright 
			);
		worldPos.xyz = rotmat * worldPos.xyz;
		
		// move it to world:
		worldPos.xyz += lightCenterPosition;
		
		
		v_depths_center_map_model_min = depthAtWorldPos(vec4(lightCenterPosition,1.0));
	}
	gl_Position = cameraViewProj * worldPos;
	
	// pass everything on to fragment shader:
	v_position = worldPos;

	
}