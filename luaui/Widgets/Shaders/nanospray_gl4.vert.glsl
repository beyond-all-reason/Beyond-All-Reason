#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//(c) Beherith (mysterme@gmail.com)

#line 5000

layout (location = 0) in vec4 vertexData;
layout (location = 1) in vec4 worldposrad; // -- target world pos and radius
layout (location = 2) in vec4 otherparams; // -- startframe, endframe, count, direction
layout (location = 3) in uint pieceIndex;
layout (location = 4) in uvec4 instData;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

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

#line 10000

uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;

out DataVS {
	uint v_numvertices;
	float v_rotationY;
	vec4 v_color;
	vec4 v_lengthwidthcornerheight;
	vec4 v_centerpos;
	vec4 v_parameters;
	#if (FULL_ROTATION == 1)
		mat3 v_fullrotation;
	#endif
};

layout(std140, binding=0) readonly buffer MatrixBuffer {
	mat4 mat[];
};


bool vertexClipped(vec4 clipspace, float tolerance) {
  return any(lessThan(clipspace.xyz, -clipspace.www * tolerance)) ||
         any(greaterThan(clipspace.xyz, clipspace.www * tolerance));
}


#define GROWTHRATE 1.0
#define INITIALSIZE 1.0
#define BREATHERATE 1.0
#define BREATHESIZE 1.0
#define CLIPTOLERANCE 1.1
#define TRAVELTIME 130.0
#define SPEEDPOWER 0.5

void main()
{
	uint baseIndex = instData.x; // this tells us which unit matrix to find
	mat4 worldMatrix = mat[instData.x];
	if (pieceIndex > 0u) {
		mat4 pieceMatrix = mat[instData.x + pieceIndex];
		worldMatrix = worldMatrix * pieceMatrix;
	}
	
	v_numvertices = 4;
	vec4 piecePos = worldMatrix * vec4(0,0,0,1);
	
	if ((uni[instData.y].composite & 0x00000003u) < 1u ) {
		//v_numvertices = 0u; 
		// this checks the drawFlag of wether the unit is actually being drawn 
		// (this is ==1 when then unit is both visible and drawn as a full model (not icon)) 
		// in this case, fall  back to drawPos
		piecePos.xyz = uni[instData.y].drawPos.xyz;
	};
	
	float time = (timeInfo.x + timeInfo.w);
	
	float randSeeded = fract(UNITID / 32768.0 + vertexData.w);
	
	float deltaTime = fract(time /TRAVELTIME + randSeeded);
	
	if ((time/TRAVELTIME) < (otherparams.x /TRAVELTIME + deltaTime)){
		v_numvertices = 0;
	}
	// Only show ones after the time?
	
	
	
	float distanceToTarget = length(piecePos.xyz- worldposrad.xyz);
	
	float direction = otherparams.w; // 1 forward, -1 reverse, 0 bidirectoinal
	
	float positionModifier = deltaTime;
	if (direction > 0.5 ){// forward
		positionModifier = pow(deltaTime, SPEEDPOWER);
	}else if (direction < -0.5) { //reverse
		positionModifier = 1.0 - pow(deltaTime, SPEEDPOWER);
	}else {
		if (vertexData.y > 0.5) { // half reverse
			positionModifier = 1.0 - pow(deltaTime, SPEEDPOWER);
		}else{
			positionModifier = pow(deltaTime, SPEEDPOWER);
		}
	
	}
	
	
	
	//float positionModifier = pow(deltaTime, clamp(1500/distanceToTarget, 0.2, 0.8));
	
	piecePos.xyz = mix(piecePos.xyz + (vertexData.xyz -0.5) * 2, worldposrad.xyz + (vertexData.xyz -0.5) * (worldposrad.w*1.3+1), positionModifier);

	float pidt = deltaTime * 3.1425 * 2;
	
	float sindt = sin(deltaTime * 3.1425);
	
	vec3 randopos = worldposrad.w* (-vertexData.xyz +0.5);

	//piecePos.xyz = mix(piecePos.xyz, piecePos.xyz + randopos, sindt);
	//piecePos.y += 100 *sindt;
	//
	
	vec4 periods = vec4(1,2,3,12);
	vec4 offsets = vec4(vertexData.xzyy);
	vec4 amplitudes = vec4(10,10,10,1) * 0.3;
	
	vec4 sintimes = sin(pidt * (periods + 6.28*offsets));
	
	piecePos.xyz = mix(piecePos.xyz, piecePos.xyz + (sintimes.xyz * amplitudes.xyz), sindt);
	
	//piecePos.x += 10 *sin(5*pidt + vertexData.x * 6.28);
	
	//piecePos.xyz += worldposrad.w* (vertexData.xyz -0.5) * sindt;
	
	vec4 lengthwidthcornerheight = vec4(5,5,16,16);

	gl_Position = cameraViewProj * piecePos; // We transform this vertex into the center of the model
	v_rotationY = 0;//atan(modelMatrix[0][2], modelMatrix[0][0]); // we can get the euler Y rot of the model from the model matrix
	v_parameters = otherparams;
	uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
	v_color = teamColor[teamIndex];  // We can lookup the teamcolor right here
	v_color.a *= 1.5 + sintimes.w ;
	v_centerpos = vec4( piecePos.xyz, 1.0); // We are going to pass the centerpoint to the GS
	v_lengthwidthcornerheight = lengthwidthcornerheight;
	v_parameters.zw = vertexData.yz; // some useful randoms 

		float animation = clamp(((timeInfo.x + timeInfo.w) - otherparams.x)/GROWTHRATE + INITIALSIZE, INITIALSIZE, 1.0) + sin((timeInfo.x)/BREATHERATE)*BREATHESIZE;
		//v_lengthwidthcornerheight.xy *= animation; // modulate it with animation factor


	if (vertexClipped(gl_Position, CLIPTOLERANCE)) v_numvertices = 0; // Make no primitives on stuff outside of screen
	// TODO: take into account size of primitive before clipping

	// this sets the num prims to 0 for units further from cam than iconDistance
	float cameraDistance = length((cameraViewInv[3]).xyz - v_centerpos.xyz);
	if (cameraDistance > iconDistance) v_numvertices = 0;

	if (dot(v_centerpos.xyz, v_centerpos.xyz) < 1.0) v_numvertices = 0; // if the center pos is at (0,0,0) then we probably dont have the matrix yet for this unit, because it entered LOS but has not been drawn yet.

	v_centerpos.y += 0; // Add some height to ensure above groundness
	//v_centerpos.y += lengthwidthcornerheight.w; // Add per-instance height offset
	#if (FULL_ROTATION == 1)
		v_fullrotation = mat3(modelMatrix);
	#endif

	// TODO: allow overriding this check, to draw things even if unit (like a building) is not drawn
	// NOCLIP:
	
}
