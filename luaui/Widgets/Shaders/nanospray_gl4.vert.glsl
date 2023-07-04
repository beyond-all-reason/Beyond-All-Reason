#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//(c) Beherith (mysterme@gmail.com)

#line 5000

layout (location = 0) in vec4 vertexData;
layout (location = 1) in vec4 worldposrad; // -- target world pos and radius
layout (location = 2) in vec4 otherparams; // -- startframe, endframe, count, intensity
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

void main()
{
	uint baseIndex = instData.x; // this tells us which unit matrix to find
	mat4 worldMatrix = mat[instData.x];
	if (pieceIndex > 0u) {
		mat4 pieceMatrix = mat[instData.x + pieceIndex];
		worldMatrix = worldMatrix * pieceMatrix;
	}
	
	vec4 piecePos = worldMatrix * vec4(0,0,0,1);
	
	float time = (timeInfo.x + timeInfo.w);
	
	float dt = fract(time /130 + vertexData.w);
	
	
	piecePos.xyz = mix(piecePos.xyz, piecePos.xyz + worldposrad.xyz + (vertexData.xyz -0.5) * worldposrad.w*1, dt);
	
	float pidt = dt * 3.1425 * 2;
	
	float sindt = sin(dt * 3.1425);
	
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
	
	vec4 lengthwidthcornerheight = vec4(3,3,16,16);

	gl_Position = cameraViewProj * piecePos; // We transform this vertex into the center of the model
	v_rotationY = 0;//atan(modelMatrix[0][2], modelMatrix[0][0]); // we can get the euler Y rot of the model from the model matrix
	v_parameters = otherparams;
	uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
	v_color = teamColor[teamIndex];  // We can lookup the teamcolor right here
	v_color.a *= 1.5 + sintimes.w ;
	v_centerpos = vec4( piecePos.xyz, 1.0); // We are going to pass the centerpoint to the GS
	v_lengthwidthcornerheight = lengthwidthcornerheight;

		float animation = clamp(((timeInfo.x + timeInfo.w) - otherparams.x)/GROWTHRATE + INITIALSIZE, INITIALSIZE, 1.0) + sin((timeInfo.x)/BREATHERATE)*BREATHESIZE;
		//v_lengthwidthcornerheight.xy *= animation; // modulate it with animation factor

	v_numvertices = 4;
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
	if ((uni[instData.y].composite & 0x00000003u) < 1u ) v_numvertices = 0u; // this checks the drawFlag of wether the unit is actually being drawn (this is ==1 when then unit is both visible and drawn as a full model (not icon)) 
	// TODO: allow overriding this check, to draw things even if unit (like a building) is not drawn
}
