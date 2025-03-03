#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)
#line 5000

layout (location = 0) in vec4 position; // xyz and etc garbage
//layout locations 1 and 2 contain primitive specific garbage and should not be used

layout (location = 3) in vec4 worldposrad;  // Centerpos
layout (location = 4) in vec4 worldposrad2; // velocity for points, beam end for beams, dir and theta for cones
layout (location = 5) in vec4 lightcolor; 
layout (location = 6) in vec4 modelfactor_specular_scattering_lensflare; // 
layout (location = 7) in vec4 otherparams; // spawnframe, lifetime, sustain, animtype
layout (location = 8) in vec4 color2; // 
layout (location = 9) in uint pieceIndex; // for piece type lights
layout (location = 10) in uvec4 instData; // matoffset, uniformoffset, teamIndex, drawFlags {id = 5, name = 'instData', size = 4, type = GL.UNSIGNED_INT},

			
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

    vec4 drawPos;
    vec4 speed;
    vec4[4] userDefined; //can't use float[16] because float in arrays occupies 4 * float space
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

uniform float windX = 0;
uniform float windZ = 0;

uniform float radiusMultiplier = 1.0;
uniform float intensityMultiplier = 1.0;

out DataVS {
	flat vec4 v_worldPosRad;
	flat vec4 v_worldPosRad2;
	flat vec4 v_lightcolor;
	flat vec4 v_modelfactor_specular_scattering_lensflare;
	vec4 v_depths_center_map_model_min;
	vec4 v_otherparams; 
	vec4 v_lightcenter_gradient_height;
	vec4 v_position;
	vec4 v_noiseoffset;
	noperspective vec2 v_screenUV;
};

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D heightmapTex;
uniform sampler2D mapnormalsTex;

#define SNORM2NORM(value) (value * 0.5 + 0.5)

vec4 depthAtWorldPos(vec4 worldPosition){ 
	// takes a point, transforms it to worldspace, and checks for occlusion against map, model buffer, and returns all the depths
	// x: light pos depth, y: map depth, z: model depth, w: min(map, model)
	vec4 screenPosition = cameraViewProj * worldPosition;
	screenPosition.xyz = screenPosition.xyz / screenPosition.w;
	// Transform from [-1,1] screen space into [0, 1] UV space
	vec2 screenUV = clamp(SNORM2NORM(screenPosition.xy), 0.001, 0.999);
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
	
	float lightRadius = worldposrad.w * radiusMultiplier;
	v_worldPosRad = worldposrad ;
	v_worldPosRad.w = lightRadius;
	
	
	mat4 placeInWorldMatrix = mat4(1.0); // this is unity for non-unitID tied stuff
	
	// Ok so here comes the fun part, where we if we have a unitID then fun things happen
	// v_worldposrad contains the incoming piece-level offset
	// v_worldPosRad should be after changing to unit-space
	// we have to transform BOTH the center of the light to piece-space
	// and the vertices of the light volume to piece-space
	// we need to go from light-space to world-space
	vec3 lightCenterPosition =  v_worldPosRad.xyz;
	v_lightcolor = lightcolor;
	if (attachedtounitID > 0){
		mat4 worldMatrix = mat[instData.x];
		placeInWorldMatrix = worldMatrix;
		if (pieceIndex > 0u) {
			mat4 pieceMatrix = mat[instData.x + pieceIndex];
			placeInWorldMatrix = placeInWorldMatrix * pieceMatrix;
		}
		//uint drawFlags = (instData.z & 0x0000100u);// >> 8 ; // hopefully this works
		//if (drawFlags == 0u)  placeInWorldMatrix = mat4(0.0); // disable if drawflag is set to 0
		// disable if drawflag is set to 0, note that we are exploiting the fact that these should be drawn even if unit is transparent, or if unit only has its shadows drawn. 
		// This is good because the tolerance for distant shadows is much greater
		if ((uni[instData.y].composite & 0x00001fu) == 0u )  placeInWorldMatrix = mat4(0.0); 

		uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
		vec4 teamCol = teamColor[teamIndex];
		if (any(lessThan(lightcolor.rgb, vec3(-0.01)))) v_lightcolor.rgb = teamCol.rgb;
	}
	float elapsedframes = time - otherparams.x;
	float lifetime = otherparams.y;
	float sustain = otherparams.z;
	if (lifetime > 0 ){ //lifetime alpha control
		if (sustain >1 ){ // sustain is positive, keep it up for sustain frames, then ramp it down
			v_lightcolor.a = clamp( v_lightcolor.a * ( lifetime - elapsedframes)/(lifetime - sustain ) , 0.0, v_lightcolor.a);
			
		}else{ // sustain is <1, use exp falloff
			v_lightcolor.a = clamp( v_lightcolor.a * exp( -sustain * (elapsedframes) * 100 ) , 0.0, v_lightcolor.a);
			
		}
	}
	
	v_worldPosRad2 = worldposrad2;

	v_modelfactor_specular_scattering_lensflare = modelfactor_specular_scattering_lensflare;
	v_depths_center_map_model_min = vec4(1.0); // just a sanity init
	v_otherparams = otherparams;
	
	vec4 worldPos = vec4(1.0);
	#line 11000
	if (pointbeamcone < 0.5){ // point
		//scale it and place it into the world
		//Make it a tiny bit bigger *(1.1) cause the blocky sphere is smaller than the actual radius
		// the -1 is for inverting it so we always see the back faces (great for occlusion testing!) (this should be exploited later on!
		
		// this is centered around the target positional offset, and scaled locally
		vec3 lightVertexPosition = lightCenterPosition + -1 * position.xyz * lightRadius * 1.1; 
		
		// tranform the vertices to world-space
		lightVertexPosition = (placeInWorldMatrix * vec4(lightVertexPosition, 1.0)).xyz; 
		
		// tranform the center to world-space
		lightCenterPosition = (placeInWorldMatrix * vec4(lightCenterPosition, 1.0)).xyz; 
		
		
		float colortime = color2.a; // Matches colortime in lightConf for point lights
		if  (attachedtounitID > 0.5) {
			// for point lights, if the colortime is anything sane (>0), then modulate the light with it.
			if (colortime >0.5){
				v_lightcolor.rgb = mix( color2.rgb, v_lightcolor.rgb, cos((elapsedframes * 6.2831853) / colortime ) * 0.5 + 0.5); }
				
		}else{
			if (colortime >0.0){
				
				float colormod = 0;
				if (colortime > 1.0) {
					colormod = clamp(elapsedframes/colortime , 0.0, 1.0);
				}
				else {
					colormod =  cos(elapsedframes * 6.2831853 * colortime ) * 0.5 + 0.5;
				}
				v_lightcolor.rgb = mix(v_lightcolor.rgb, color2.rgb, colormod); 
			}
			if (worldposrad2.w < 1.0) {
				lightCenterPosition += timeInfo.w * worldposrad2.xyz;
				lightVertexPosition += timeInfo.w * worldposrad2.xyz;
			}else{
				// Note: worldposrad2.w is an excellent place to add orbit-style world-placement light animations
				//vec3 lightWorldMovement = sin(time * 0.017453292 * worldposrad2.xyz) * worldposrad2.w;
				//lightCenterPosition += lightWorldMovement;
			}
		}
		

		v_worldPosRad.xyz = lightCenterPosition;
		v_depths_center_map_model_min = depthAtWorldPos(vec4(lightCenterPosition,1.0)); // 
		v_position = vec4( lightVertexPosition, 1.0);
	}
	#line 12000
	else if (pointbeamcone < 1.5){ // beam
		// we will tranform along this vector, where Y shall be the upvector
		// our null vector is +X
		vec3 centertoend = lightCenterPosition - worldposrad2.xyz;
		float halfbeamlength = length(centertoend);
		// Scale the box to correct size (along beam is Y dir)
		//if (attachedtounitID > 0){
			worldPos.xyz = position.xyz * vec3( lightRadius , step(position.y, 0) *halfbeamlength + lightRadius, lightRadius );
			//}
		//else{
			worldPos.xyz = position.xyz * vec3( lightRadius ,  step(position.y, 0) * halfbeamlength + lightRadius, lightRadius );
			//worldPos.xyz = position.xyz * vec3( lightRadius , halfbeamlength + lightRadius, lightRadius );
			//worldPos.xyz += vec3(50);
			//}
		
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
		
		// so we now have our rotated box, we need to place it not at the center, but where the piece matrix tells us to
		// or where the lightcenterpos tells us to
		

		// Place the box in the world
		worldPos.xyz += lightCenterPosition;
		
		v_depths_center_map_model_min = depthAtWorldPos(vec4(lightCenterPosition,1.0));
		
		v_worldPosRad2.xyz = (placeInWorldMatrix * vec4(v_worldPosRad2.xyz, 1.0)).xyz;;
		v_worldPosRad.xyz = (placeInWorldMatrix * vec4(lightCenterPosition.xyz, 1.0)).xyz;
		v_worldPosRad.xyz += (v_worldPosRad2.xyz - v_worldPosRad.xyz) * 0.5;
		v_position.xyz = (placeInWorldMatrix * vec4(worldPos.xyz, 1.0)).xyz;
	}
	#line 12000
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
			
		// if the cone is not attached to the unit, exploit that direction allows us to smoothen anim
		if (attachedtounitID < 0.5){
			lightCenterPosition += worldposrad2.xyz * timeInfo.w;
		}
		
		// rotate the cone, and place it into local space
		worldPos.xyz = rotmat * worldPos.xyz + lightCenterPosition;

		
		// move the cone into piece or world space:
		worldPos.xyz = (placeInWorldMatrix * vec4(worldPos.xyz, 1.0)).xyz;
		
		// set the center pos of the light:
		v_worldPosRad.xyz = (placeInWorldMatrix * vec4(lightCenterPosition.xyz, 1.0)).xyz;;
		v_depths_center_map_model_min = depthAtWorldPos(vec4(v_worldPosRad.xyz,1.0));
		
		// Clear out the translation from the cone direction, and turn the cone according to the piece matrix
		v_worldPosRad2.xyz = mat3(placeInWorldMatrix) * v_worldPosRad2.xyz;
		
		v_position =  worldPos;
	}
	#line 13000
	// Get the heightmap and the normal map at the center position of the light in v_worldPosRad.xyz
	
	vec2 uvhm = heightmapUVatWorldPos(v_worldPosRad.xz);
	v_lightcenter_gradient_height.w = textureLod(heightmapTex, uvhm, 0.0).x;
	
	vec4 mapnormals = textureLod(mapnormalsTex, uvhm, 0.0);
	mapnormals.g = sqrt( 1.0 - mapnormals.r * mapnormals.r - mapnormals.a * mapnormals.a);
	v_lightcenter_gradient_height.xyz = mapnormals.rga;
	
	//	vec4 windInfo; // windx, windy, windz, windStrength
	v_noiseoffset = vec4(windX, 0, windZ,0) * (-0.0156);
	//v_noiseoffset = vec4(0.0);
	//v_noiseoffset.y = windX + windZ;
	
	gl_Position = cameraViewProj * v_position;
	v_screenUV = SNORM2NORM(gl_Position.xy / gl_Position.w);
	
	// pass everything on to fragment shader:

	
}
