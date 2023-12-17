#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

#line 5000

layout (location = 0) in vec4 height_timers;
layout (location = 1) in uvec4 bartype_index_ssboloc;
layout (location = 2) in vec4 mincolor;
layout (location = 3) in vec4 maxcolor;
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

#line 10000

uniform float iconDistance;
uniform float cameraDistanceMult;
uniform float cameraDistanceMultGlyph;

out DataVS {
	uint v_numvertices;
	vec4 v_mincolor;
	vec4 v_maxcolor;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters;
	vec2 v_sizemodifiers;
	uvec4 v_bartype_index_ssboloc;
};

bool vertexClipped(vec4 clipspace, float tolerance) {
  return any(lessThan(clipspace.xyz, -clipspace.www * tolerance)) ||
         any(greaterThan(clipspace.xyz, clipspace.www * tolerance));
}
#define UNITUNIFORMS uni[instData.y]
#define UNIFORMLOC bartype_index_ssboloc.z
#define BARTYPE bartype_index_ssboloc.x

#define BITUSEOVERLAY 1u
#define BITSHOWGLYPH 2u
#define BITPERCENTAGE 4u
#define BITTIMELEFT 8u
#define BITINTEGERNUMBER 16u
#define BITGETPROGRESS 32u
#define BITFLASHBAR 64u
#define BITCOLORCORRECT 128u

void main()
{
	vec4 drawPos = vec4(UNITUNIFORMS.drawPos.xyz, 1.0); // Models world pos and heading (.w) . Changed to use always available drawpos instead of model matrix.

	gl_Position = cameraViewProj * drawPos; // We transform this vertex into the center of the model

	v_centerpos = drawPos; // We are going to pass the centerpoint to the GS
	v_numvertices = 4u;
	if (vertexClipped(gl_Position, CLIPTOLERANCE)) v_numvertices = 0; // Make no primitives on stuff outside of screen

	// this sets the num prims to 0 for units further from cam than iconDistance
	float cameraDistance = length((cameraViewInv[3]).xyz - v_centerpos.xyz);
	
	// Calculate bar alpha
	v_parameters.y = (clamp(cameraDistance * cameraDistanceMult, BARFADESTART, BARFADEEND) - BARFADESTART)/ ( BARFADEEND-BARFADESTART);
	v_parameters.y = 1.0 - clamp(v_parameters.y, 0.0, 1.0);
	
	// Calculate glyph alpha
	v_parameters.z = (clamp(cameraDistance * cameraDistanceMult * cameraDistanceMultGlyph, BARFADESTART, BARFADEEND) - BARFADESTART)/ ( BARFADEEND-BARFADESTART);
	v_parameters.z = 1.0 - clamp(v_parameters.z, 0.0, 1.0);

	#ifdef DEBUGSHOW
		v_parameters.y = 1.0;
		v_parameters.z = 1.0;
	#endif

	v_parameters.w = height_timers.w;
	v_sizemodifiers = height_timers.yz;
	
	if (length((cameraViewInv[3]).xyz - v_centerpos.xyz) >  iconDistance){
		//v_parameters.yz = vec2(0.0); // No longer needed
	}


	if (dot(v_centerpos.xyz, v_centerpos.xyz) < 1.0) v_numvertices = 0; // if the center pos is at (0,0,0) then we probably dont have the matrix yet for this unit, because it entered LOS but has not been drawn yet.

	v_centerpos.y += HEIGHTOFFSET; // Add some height to ensure above groundness
	v_centerpos.y += height_timers.x; // Add per-instance height offset

	// This is not needed since the switch to .drawPos
	//if ((UNITUNIFORMS.composite & 0x00000003u) < 1u ) v_numvertices = 0u; // this checks the drawFlag of wether the unit is actually being drawn (this is ==1 when then unit is both visible and drawn as a full model (not icon))


	v_bartype_index_ssboloc = bartype_index_ssboloc;
	float relativehealth = UNITUNIFORMS.health / UNITUNIFORMS.maxHealth;
	v_parameters.x = UNITUNIFORMS.health / UNITUNIFORMS.maxHealth;
	if (UNIFORMLOC < 20u)
	{
		uint i = uint(mod(timeInfo.x, 20)*0.05);
		//v_parameters.x =  UNITUNIFORMS.userDefined[uint(i / 5u)][uint(mod(i,4u))];
		v_parameters.x =  UNITUNIFORMS.userDefined[0].y;

	}else{ // this is a health bar, dont draw it if the unit is being built and its health doesnt really differ from the full health
		// TODO: this is kinda buggy, as buildprogess in the the unit uniforms is somehow lagging behind health.
		float buildprogress = UNITUNIFORMS.userDefined[0].x; // this is -1.0 for fully built units
		#ifndef DEBUGSHOW
			if (abs(buildprogress - relativehealth )< 0.03) v_numvertices = 0u;
		#endif
	}
	if (UNIFORMLOC < 4u) v_parameters.x = UNITUNIFORMS.userDefined[0][bartype_index_ssboloc.z ];
	if (UNIFORMLOC == 0u) { //building
		// dont draw if health = buildProgress
		//v_parameters.x = UNITUNIFORMS.userDefined[0].x;
		//if (abs(v_parameters.x - relativehealth )< 0.02) v_numvertices = 0u;
	}
	if (UNIFORMLOC == 1u) v_parameters.x = UNITUNIFORMS.userDefined[0].y; //hmm featureresurrect or timeleft?
	if (UNIFORMLOC == 2u) v_parameters.x = UNITUNIFORMS.userDefined[0].z; // shield/reloadstart/stockpile / buildtimeleft?
	if (UNIFORMLOC == 4u) v_parameters.x = UNITUNIFORMS.userDefined[1].x; //emp damage and paralyze
	if (UNIFORMLOC == 5u) v_parameters.x = UNITUNIFORMS.userDefined[1].y; //capture

	if ((BARTYPE & BITGETPROGRESS) > 0u) { // reload bar progress is calced from nowtime-shottime / (endtime - shottime)
		v_parameters.x =
			((timeInfo.x + timeInfo.w) - UNITUNIFORMS.userDefined[0].z ) /
			(UNITUNIFORMS.userDefined[0].w - UNITUNIFORMS.userDefined[0].z);
		v_parameters.x = clamp(v_parameters.x * 1.0, 0.0, 1.0);
	}

	v_mincolor = mincolor;
	v_maxcolor = maxcolor;
}