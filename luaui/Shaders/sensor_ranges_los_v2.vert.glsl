#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

#line 10000

layout (location = 0) in vec4 circlepointposition;
layout (location = 1) in vec4 radius_params; //x is startradius, y is starttime, z is endradius, w is endtime
layout (location = 2) in uvec4 instData;

//__ENGINEUNIFORMBUFFERDEFS__

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

layout(std140, binding=5) readonly buffer coveredSSBO {
	vec4 coveredness[];
};

#define UNITID (uni[instData.y].composite >> 16)

uniform float teamColorMix = 1.0;
uniform vec4 rangeColor;
uniform sampler2D heightmapTex;


out DataVS {
	//vec4 worldPos; // pos and radius
	flat vec4 blendedcolor;
	vec4 v_uv;
};

#line 11000

float heightAtWorldPos(vec2 w){
	vec2 uvhm =   heightmapUVatWorldPos(w);
	return textureLod(heightmapTex, uvhm, 0.0).x;
}

void main() {
	// blend start to end on mod gf%10
	//float timemix = clamp((mod(timeInfo.x, 10) + timeInfo.w) * (0.1), 0.0, 1.0);

	vec4 circleWorldPos = vec4(uni[instData.y].drawPos.xyz, 1.0);
	float circleRadius = radius_params.x;

	bool isclipped = isSphereVisibleXY(vec4(circleWorldPos.xyz,1.0), circleRadius * 1.1);
	if (isclipped){
		// Note: this is a little aggressive :/

		gl_Position = cameraViewProj * vec4(-10000,-1000,-10000,1.0);
		v_uv = gl_Position;
		return;
	}

	circleWorldPos.xz = circlepointposition.xy * circleRadius +  circleWorldPos.xz;
	// get heightmap
	circleWorldPos.y = max(0.0,heightAtWorldPos(circleWorldPos.xz))+16.0;

	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(circleWorldPos.xz,mapSize.xy - circleWorldPos.xz);
	float inboundsness = min(mymin.x, mymin.y);

	// dump to FS
	//worldPos = circleWorldPos;
	
	uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
	vec4 myTeamColor = teamColor[teamIndex];  // We can lookup the teamcolor right here
	blendedcolor.rgb = mix(rangeColor.rgb, myTeamColor.rgb, teamColorMix);
	blendedcolor.a *= rangeColor.a;
	blendedcolor.a *= 1.0 - clamp(inboundsness*(-0.02),0.0,1.0);
	//blendedcolor.rgb = coveredness[gl_InstanceID].rgb * blendedcolor.rgba;
	gl_Position = cameraViewProj * circleWorldPos;
	v_uv = gl_Position;
}