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

uniform float teamColorMix = 1.0;
uniform vec4 rangeColor;

uniform sampler2D heightmapTex;

out DataVS {
	flat vec4 blendedcolor;
	vec4 v_uv_camdist_radius;
};

#line 11000

float heightAtWorldPos(vec2 w){
	vec2 uvhm =   heightmapUVatWorldPos(w);
	return textureLod(heightmapTex, uvhm, 0.0).x;
}

//  sdScreenSphere
//  Signed distance from a world-space sphere to the X-Y NDC box.
//  Z (near/far) is ignored.
//  Returns:
//      < 0  – sphere at least partially inside the X-Y clip box
//      = 0  – sphere exactly touches at least one edge
//      > 0  – sphere is more distance from the edge of frustrum by that many NDC units
//
float SphereInViewSignedDistance(vec3 centerWS,  float radiusWS)
{
    // 1.  centre → clip space
    vec4 clipC = cameraViewProj * vec4(centerWS, 1.0);
    if (clipC.w <= 0.0)           // behind the eye? treat as inside
        return -1.0;

    // 2.  NDC centre (one perspective divide, reused later)
    vec2  ndc   = clipC.xy / clipC.w;        // = clipC.xy / clipC.w

    // 3.  Project world-space +X displacement
    //     M * (p + (r,0,0,0)) = (M*p) + r*M*Xcol
    vec4 deltaClip = radiusWS * cameraViewProj[0];   // first column of matrix
    vec4 clipX     = clipC + deltaClip;

    // 4.  Radius in NDC (second perspective divide only once)
    float ndcRadius = length((clipX.xy / clipX.w) - ndc);

    // 5.  Four signed distances, keep the worst (Chebyshev / max)
    float dLeft   = -(ndc.x + 1.0) - ndcRadius;
    float dRight  =  (ndc.x - 1.0) - ndcRadius;
    float dBottom = -(ndc.y + 1.0) - ndcRadius;
    float dTop    =  (ndc.y - 1.0) - ndcRadius;

    return max(max(dLeft, dRight), max(dBottom, dTop));
}



void main() {
	
	// Get the center position of each unit. 
	vec4 circleCenterWorldPos = vec4(uni[instData.y].drawPos.xyz, 1.0);
	float circleRadius = radius_params.x;

	// Early bails if the circle is outside of the screen frustrum

	if (SphereInViewSignedDistance(circleCenterWorldPos.xyz, circleRadius) > 0.0){
		gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	#ifdef STENCILPASS
	    circleRadius += 16.0;
	#endif
	
	
  	// the circlepointposition is zero at the center vertex of the circle, and we will be using the these varyings as a distance from the center
	// for the fragment shader 
	v_uv_camdist_radius.w = 0;
	if (dot(circlepointposition.xy, circlepointposition.xy) < 0.0001) {	v_uv_camdist_radius.w = radius_params.x; }

	vec4 circleVertexWorldPos = vec4(circleCenterWorldPos.xyz, 1.0);

	circleVertexWorldPos.xz += circlepointposition.xy * circleRadius;
	
	// get heightmap
	circleVertexWorldPos.y = max(0.0,heightAtWorldPos(circleVertexWorldPos.xz))+16.0;

	gl_Position = cameraViewProj * circleVertexWorldPos;
	v_uv_camdist_radius.xy = gl_Position.xy;
	#ifndef STENCILPASS
		// -- MAP OUT OF BOUNDS
		vec2 mymin = min(circleVertexWorldPos.xz,mapSize.xy - circleVertexWorldPos.xz);
		float inboundsness = min(mymin.x, mymin.y); // how distance the vertex is from the map edge
		inboundsness = 1.0 - clamp(inboundsness*(-0.02),0.0,1.0); // clamp to [0,1] range, and invert it so that the closer to the edge, the lower the value

		
		uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
		vec4 myTeamColor = teamColor[teamIndex];  // We can lookup the teamcolor right here
		blendedcolor.rgb = mix(rangeColor.rgb, myTeamColor.rgb, teamColorMix);
		blendedcolor.a = rangeColor.a ;
		//blendedcolor.a *= 1.0 - clamp(inboundsness*(-0.01),0.0,1.0);
		v_uv_camdist_radius.z = inboundsness;
	#endif
}
