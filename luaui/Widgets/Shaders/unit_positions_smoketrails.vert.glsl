#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

#line 5000

layout (location = 0) in vec4 widthgrowthrisemaxvel;
layout (location = 1) in ivec4 slot_start_step_segments; // lifestart, ismine
layout (location = 2) in vec4 emitoffsets; // this is optional, for using an Atlas
layout (location = 3) in uvec4 instData;

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

#line 10041

uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;

out DataVS {
	vec4 v_widthgrowthrisemaxvel;
	vec4 v_centerpos;
	vec4 v_emitoffsets;
	vec4 v_drawpos;
	ivec4 v_slot_start_step_segments;
};

layout(std140, binding=0) readonly buffer MatrixBuffer {
	mat4 UnitPieces[];
};


bool vertexClipped(vec4 clipspace, float tolerance) {
  return any(lessThan(clipspace.xyz, -clipspace.www * tolerance)) ||
         any(greaterThan(clipspace.xyz, clipspace.www * tolerance));
}

void main()
{
	uint baseIndex = instData.x; // this tells us which unit matrix to find
	mat4 modelMatrix = UnitPieces[baseIndex]; // This gives us the models  world pos and rot matrix

	gl_Position = cameraViewProj * vec4(modelMatrix[3].xyz, 1.0); // We transform this vertex into the center of the model
	v_emitoffsets = emitoffsets;
	v_slot_start_step_segments = slot_start_step_segments;
	//v_parameters = parameters;
	//v_color = teamColor[teamID];  // We can lookup the teamcolor right here
	v_centerpos = vec4( modelMatrix[3].xyz, 1.0); // We are going to pass the centerpoint to the GS
	v_widthgrowthrisemaxvel = widthgrowthrisemaxvel;

	int v_numvertices = 32;
	if (vertexClipped(gl_Position,1.1)) v_numvertices = 0; // Make no primitives on stuff outside of screen
	// TODO: take into account size of primitive before clipping

	// this sets the num prims to 0 for units further from cam than iconDistance
	float cameraDistance = length((cameraViewInv[3]).xyz - v_centerpos.xyz);
	if (cameraDistance > iconDistance) v_numvertices = 0;

	v_centerpos.y += widthgrowthrisemaxvel.w; // Add per-instance height offset
	
	v_drawpos = uni[instData.y].drawPos; 

	if ((uni[instData.y].composite & 0x00000003u) < 1u ) v_numvertices = 0; // this checks the drawFlag of wether the unit is actually being drawn (this is ==1 when then unit is both visible and drawn as a full model (not icon)) 
	// TODO: allow overriding this check, to draw things even if unit (like a building) is not drawn
	
	v_slot_start_step_segments.w = min(v_numvertices, v_slot_start_step_segments.w);
}
