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
layout (location = 5) in vec4 baseparams;  // yoffset, effectStrength, startRadius, unused
layout (location = 6) in vec4 universalParams; // noiseStrength, noiseScaleSpace, distanceFalloff, onlyModelMap
layout (location = 7) in vec4 lifeParams; // spawnFrame, lifeTime, rampUp, decay
layout (location = 8) in vec4 effectParams; // effectparam1, effectparam2, windAffected, effectType
layout (location = 9) in uint pieceIndex; // for piece type distortions
layout (location = 10) in uvec4 instData; // matoffset, uniformoffset, teamIndex, drawFlags {id = 5, name = 'instData', size = 4, type = GL.UNSIGNED_INT},

#define YOFFSET baseparams.x
#define EFFECTSTRENGTH baseparams.y
#define STARTRADIUS baseparams.z

#define SPAWNFRAME lifeParams.x
#define LIFETIME   lifeParams.y
#define RAMPUP     lifeParams.z
#define DECAY      lifeParams.w
			
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

#define UNITID (uni[instData.y].composite >> 16)

#ifdef UNIFORMSBUFFERCOPY
	// Note that this is an incorrect copy of the uniformsbuffer, and is computed via a compute shader, so its _HIGHLY EXPERIMENTAL_
	layout(std140, binding=4) buffer UniformsBufferCopy {
		SUniformsBuffer uniCopy[];
	};
#endif

#line 10000

uniform float pointbeamcone = 0;// = 0; // 0 = point, 1 = beam, 2 = cone

// this uniform needs some extra. If it is 1, then the primitives should point in the -Z direction, and be moved and rotated with the unit itself
// If the unit is not being drawn, it must be switched off

uniform float attachedtounitID = 0;

uniform float windX = 0;
uniform float windZ = 0;

uniform float radiusMultiplier = 1.0;
uniform float intensityMultiplier = 1.0;

out DataVS {
	flat vec4 v_worldPosRad;
	flat vec4 v_worldPosRad2;
	flat vec4 v_baseparams;   // lifeStrength, effectStrength, startRadius, unused
	flat vec4 v_universalParams; // noiseStrength, noiseScaleSpace, distanceFalloff, onlyModelMap
	flat vec4 v_lifeParams; // spawnFrame, lifeTime, rampUp, decay
	flat vec4 v_effectParams; // effectparam1, effectparam2, windAffected, effectType
	#ifdef UNIFORMSBUFFERCOPY
		flat vec4 v_unibuffercopy;
	#endif
	noperspective vec2 v_screenUV;
};

#define NOISESTRENGTH v_universalParams.x;

#define SNORM2NORM(value) (value * 0.5 + 0.5)

void main()
{
	float time = timeInfo.x + timeInfo.w;
	int effectType = int(round(effectParams.w));
	float elapsedframes = time - SPAWNFRAME;
	float lifeFraction = 1.0;
	if (LIFETIME > 1) lifeFraction = clamp(elapsedframes / LIFETIME, 0.0, 1.0);

	float distortionRadius = worldposrad.w;

	// Modulate distortion radius over the lifetime of the distortion
	distortionRadius = STARTRADIUS + (distortionRadius - STARTRADIUS) * lifeFraction;

	// Output to the fragment shader
	v_worldPosRad = worldposrad ;
	v_worldPosRad.w = distortionRadius;
	v_worldPosRad2 = worldposrad2;
	v_lifeParams = lifeParams;

	vec4 vertexPosition = vec4(1.0);
	
	mat4 placeInWorldMatrix = mat4(1.0); // this is unity for non-unitID tied stuff
	
	// Ok so here comes the fun part, where we if we have a unitID then fun things happen
	// v_worldPosRad contains the incoming piece-level offset
	// v_worldPosRad should be after changing to unit-space
	// we have to transform BOTH the center of the distortion to piece-space
	// and the vertices of the distortion volume to piece-space
	// we need to go from distortion-space to world-space
	vec3 distortionCenterPosition =  v_worldPosRad.xyz;
	v_baseparams = baseparams;
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
		

		#ifdef UNIFORMSBUFFERCOPY
			v_unibuffercopy = uni[instData.y].speed - uniCopy[instData.y].speed;
		#endif

		uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
		vec4 teamCol = teamColor[teamIndex];
	}
	
	vec4 worldPos = vec4(1.0);
	#line 11000
	if (pointbeamcone < 0.5){ // point
		// Scale it and place it into the world
		// Make it a tiny bit bigger *(1.1) cause the blocky sphere is smaller than the actual radius
		// The -1 is for inverting it so we always see the back faces (great for occlusion testing!) (this should be exploited later on!
		
		// this is centered around the target positional offset, and scaled locally
		vec3 distortionVertexPosition = distortionCenterPosition + -1 * position.xyz * distortionRadius * 1.15; // 1.15 is a magic number that makes the sphere actually fit inside the sphere-ish geometry
		
		// tranform the vertices to world-space
		distortionVertexPosition = (placeInWorldMatrix * vec4(distortionVertexPosition, 1.0)).xyz; 
		
		// tranform the center to world-space
		distortionCenterPosition = (placeInWorldMatrix * vec4(distortionCenterPosition, 1.0)).xyz; 
		
		
		// Projectile-attached distortions need their own positional smoothing based on the velocity of the projectile and timeOffset (timeInfo.w)
		if  (attachedtounitID > 0.5) {
			// Distortions attached to unitID's need no positional correction
		}else{
			// Distortions attached to projectiles need to be smoothed out
			if (worldposrad2.w < 1.0) { // We indicate that this is a projectile by setting the w component of worldposrad2 to < 1
				distortionCenterPosition += timeInfo.w * worldposrad2.xyz;
				distortionVertexPosition += timeInfo.w * worldposrad2.xyz;
			}else{

			}
		}
		
		v_worldPosRad.xyz = distortionCenterPosition;
		vertexPosition = vec4( distortionVertexPosition, 1.0);
	}
	#line 12000
	else if (pointbeamcone < 1.5){ // beam
		// we will tranform along this vector, where Y shall be the upvector
		// our null vector is +X
		vec3 centertoend = distortionCenterPosition - worldposrad2.xyz;
		float halfbeamlength = length(centertoend);

		// Scale the box to correct size (along beam is Y dir)
		worldPos.xyz = position.xyz * vec3( distortionRadius , step(position.y, 0) * halfbeamlength + distortionRadius, distortionRadius );

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
		// or where the distortioncenterpos tells us to
		
		// Place the box in the world
		worldPos.xyz += distortionCenterPosition;
		
		// Copy the parameters to the fragment shader varyings and place the vertex
		v_worldPosRad2.xyz = (placeInWorldMatrix * vec4(v_worldPosRad2.xyz, 1.0)).xyz;;
		v_worldPosRad.xyz = (placeInWorldMatrix * vec4(distortionCenterPosition.xyz, 1.0)).xyz;
		v_worldPosRad.xyz += (v_worldPosRad2.xyz - v_worldPosRad.xyz) * 0.5;
		vertexPosition.xyz = (placeInWorldMatrix * vec4(worldPos.xyz, 1.0)).xyz;

	}
	#line 12000
	else if (pointbeamcone > 1.5){ // cone
		// Input cone that has pointy end up, (y = 1), with radius =1, flat on Y=0 plane
		// Make it so that cone tip is at 0 and the opening points to -y
		worldPos.xyz = position.xyz;
		worldPos.x *= -1.0; // flip the cone inside out
		worldPos.y = (worldPos.y*1.1 - 1.) * -1;
	
		worldPos.xz *= tan(worldposrad2.w); // Scale the flat of the cone by the half-angle of its opening
		v_worldPosRad2.w = cos(worldposrad2.w); // pass through the cosine to avoid this calc later on
		v_worldPosRad2.xyz = normalize(worldposrad2.xyz); // normalize this here for sanity

		// if the cone is not attached to the unit, exploit that direction allows us to smoothen anim
		if (attachedtounitID < 0.5){
			distortionCenterPosition += worldposrad2.xyz * timeInfo.w;
			// if its projectile slaved, then flip its direction
			v_worldPosRad2.xyz *= -1.0;
		}
		
		worldPos.xyz *= distortionRadius * 1.05; // scale it all by the height of the cone, and a bit of extra 
		
		// Now our cone is opening forward towards  -y, but we want it to point into the worldposrad2.xyz
		vec3 oldfw = vec3(0.001, -1, 0.001); // The old forward direction is -y, plus a tiny bit to avoid singularity in vector cross products
		vec3 newfw = normalize(v_worldPosRad2.xyz); // the new forward direction shall be the normal that we want
		vec3 newright = normalize(cross(newfw, oldfw)); // the new right direction shall be the vector perpendicular to old and new forward
		vec3 newup = normalize(cross(newright, newfw)); // the new up direction shall be the vector perpendicular to new right and new forward

		mat3 rotmat = mat3( // assemble the rotation matrix
				newup,
				newfw, 
				newright 
			);
			
		vec3 rotOffset = rotmat * vec3(0,YOFFSET,0);
		distortionCenterPosition += rotOffset;
		// rotate the cone, and place it into local space
		worldPos.xyz = rotmat * worldPos.xyz + distortionCenterPosition;

		// move the cone into piece or world space:
		worldPos.xyz = (placeInWorldMatrix * vec4(worldPos.xyz, 1.0)).xyz;
		
		// set the center pos of the distortion:
		v_worldPosRad.xyz = (placeInWorldMatrix * vec4(distortionCenterPosition.xyz, 1.0)).xyz;
		
		// Clear out the translation from the cone direction, and turn the cone according to the piece matrix
		v_worldPosRad2.xyz = mat3(placeInWorldMatrix) * v_worldPosRad2.xyz;
		
		vertexPosition =  worldPos;
	}
	#line 13000
	
	//-------------------------- BEGIN SHARED SECTION ---------------------
	// This section is shared between all distortion shapes

	if (effectType == 11){
		v_worldPosRad2 = uni[instData.y].speed;
	}

	// Initialze the distortion strength multiplier
	v_baseparams.x = 1.0;
	// if the distortion is attached to a unit, and the lifeTime is 0, and the decay is nonzero, then modulate the strength with the units selfillummod
	if ((attachedtounitID > 0.5) && (LIFETIME == 0) && (DECAY < 0)){
		float selfIllumMod = max(-0.2, sin(time * 2.0/30.0 + float(UNITID) * 0.1 - 0.5)) + 0.2;
		selfIllumMod *= selfIllumMod * (2.0 - selfIllumMod); //Almost Unit Identity 
		// Almost 
    	selfIllumMod = mix(1.0, selfIllumMod, -1.0 / DECAY);
		v_baseparams.x *= selfIllumMod;
	}

	// If a lifeParams.z rampup is specified, then 
	// >1 : how many frames to linearly ramp up to full power
	// 0< z <1: use a power curve with exponent Z to ramp up
	// Note that rampup can also be used for infinite lifetime distortions to ramp up the distortion strength
	if (RAMPUP > 0.0){
		v_baseparams.x *= clamp(elapsedframes / RAMPUP, 0.0, 1.0);
	}

	if (LIFETIME > 1){ // Decay only makes sense if lifetime is > 1
		// If a lifeParams.w decay is specified, then 
		// >1 : how many frames to linearly decay to zero
		// 0< z <1: use a power curve with exponent Z to decay
		if (DECAY > 0.0){
			if (DECAY > 1) {
				// How much life it still has left:
				float decayfraction = (LIFETIME - elapsedframes) / DECAY;
				v_baseparams.x *= clamp(decayfraction, 0.0, 1.0);
			}
			else {
				float lifeFraction = (LIFETIME - elapsedframes) / LIFETIME;
				v_baseparams.x *= clamp(pow(lifeFraction, 10.0 * DECAY),0.0, 1.0);
			}
		}
	}

	// pass everything else on to fragment shader varyings
	v_universalParams = universalParams;
	v_effectParams = effectParams;
	gl_Position = cameraViewProj * vertexPosition;
	v_screenUV = SNORM2NORM(gl_Position.xy / gl_Position.w);
}