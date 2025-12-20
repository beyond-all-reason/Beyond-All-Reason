#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

#line 10000

layout (location = 0) in vec4 circlepointposition;
layout (location = 1) in vec4 radius_params; //x is startradius, pos y is growstarttime, neg y is shrinkstarttime
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
	vec4 v_radius_circum_height;
	#ifndef STENCILPASS
		flat vec4 v_blendedcolor;
	#endif
};

#line 11000

float heightAtWorldPos(vec2 w){
	vec2 uvhm = heightmapUVatWorldPos(w);
	return textureLod(heightmapTex, uvhm, 0.0).x;
}


void main() {
	
	// Get the center position of each unit. 
	vec4 circleCenterWorldPos = vec4(uni[instData.y].drawPos.xyz, 1.0);

	float nowTime = timeInfo.x + timeInfo.w;
	float sizeFactor;
	if (radius_params.y < -1){ //negative means shrinking
		 sizeFactor = 15.0 - (nowTime + radius_params.y); // size factor is the time since shrink started divided by the shrink duration
	}else{
		 sizeFactor = nowTime - radius_params.y; // size factor is the time since shrink started divided by the shrink duration
	}
	sizeFactor = clamp(sizeFactor / 15.0, 0.0, 1.0); // clamp to [0,1] range
	float circleRadius = radius_params.x * sizeFactor;

	// Early bails if the circle is outside of the screen frustrum
	#ifdef VISIBILITYCULLING
		if (SphereInViewSignedDistance(circleCenterWorldPos.xyz, circleRadius) > 0.0){
			gl_Position = vec4(2.0, 0.0, 0.0, 1.0);
			return;
		}
	#endif

	circleCenterWorldPos.y = max(0.0, circleCenterWorldPos.y + 16.0); // add 16 to the height to avoid z-fighting with the ground

	vec4 circleVertexWorldPos = vec4(circleCenterWorldPos.xyz, 1.0);
	circleVertexWorldPos.xz += circlepointposition.xy * circleRadius;
	

	float groundHeight = heightAtWorldPos(circleVertexWorldPos.xz); //the y component of v_radius_circum_height
	circleVertexWorldPos.y = max(0.0, groundHeight + 16.0); // add the height offset to the vertex position

	#ifdef STENCILPASS
		// the circlepointposition is zero at the center vertex of the circle, and we will be using the these varyings as a distance from the center
		// for the fragment shader 
		// hack in the additional 16 radius 
		// TODO: why isnt this added BEFORE?


	    circleRadius += 16.0;		


		bool isCenterVertex = (dot(circlepointposition.xy, circlepointposition.xy) < 0.0001) ;
		if (!isCenterVertex) {
			// make the vector pointing from the center to the vertex exactly circleRadius longer! 
			
			vec3 dir = normalize(circleVertexWorldPos.xyz - circleCenterWorldPos.xyz);
			// this is the vector from the center to the vertex, which is now ABOUT circleRadius long, but we want it to be exactly circleRadius  + 16 long


			circleVertexWorldPos.xyz += dir.xyz * 16.0;
			v_radius_circum_height.x = 0;

		}else{
			v_radius_circum_height.x = circleRadius + 16.0; // the center vertex is always circleRadius + 16 long

		}
		
	#endif
	

	gl_Position = cameraViewProj * circleVertexWorldPos;
	#ifndef STENCILPASS // Circle Pass

		v_radius_circum_height.z = groundHeight; // store the ground height here for sonar and stuff
		// -- MAP OUT OF BOUNDS
		vec2 mymin = min(circleVertexWorldPos.xz,mapSize.xy - circleVertexWorldPos.xz);
		float inboundsness = min(mymin.x, mymin.y); // how distant the vertex is from the map edge
		inboundsness = 1.0 - clamp(inboundsness*(-0.02),0.0,1.0); // clamp to [0,1] range, and invert it so that the closer to the edge, the lower the value
		v_blendedcolor.rgb = rangeColor.rgb;
		#ifdef USE_TEAMCOLOR
			uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
			vec4 myTeamColor = teamColor[teamIndex];  // We can lookup the teamcolor right here
			v_blendedcolor.rgb = mix(v_blendedcolor.rgb, myTeamColor.rgb, teamColorMix);
		#endif
		v_blendedcolor.a = rangeColor.a ;
		//blendedcolor.a *= 1.0 - clamp(inboundsness*(-0.01),0.0,1.0);
		v_radius_circum_height.w = inboundsness;
		v_radius_circum_height.y = circleRadius * circlepointposition.z * 5.2345; // store the radius in the first component of v_radius_circum_height
	#endif
}
