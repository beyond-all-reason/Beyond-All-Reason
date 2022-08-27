#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000
uniform float iconDistance;
in DataVS {
	vec4 v_worldPosRad;
	vec4 v_params;
	vec3 v_centerpos;
	vec4 v_fragWorld;
};

uniform sampler2D mapDepths;

out vec4 fragColor;
float distancetocomm = 0;
float lineblast( float radius, float width, float strength){
	float linestrength = clamp(width - abs(distancetocomm-radius),0,1);
	return linestrength * strength;
}

#line 31000
void main(void)
{
	vec2 screenUV = gl_FragCoord.xy  / viewGeometry.xy;
	float mapdepth = texture(mapDepths, screenUV).x;
	// Transform screen-space depth to world-space position
	vec4 mapWorldPos =  vec4( vec3(screenUV.xy * 2.0 - 1.0, mapdepth),  1.0);
	mapWorldPos = cameraViewProjInv * mapWorldPos;
	mapWorldPos.xyz = mapWorldPos.xyz / mapWorldPos.w; // YAAAY this works!


	vec3 mapToComm = v_centerpos.xyz - mapWorldPos.xyz;
	distancetocomm = length(mapToComm);
	
	
	
	fragColor.rgb = vec3(fract(distancetocomm * 0.01));
	fragColor.a = 0.5;
	if (distancetocomm > BLASTRADIUS) fragColor.a = 0.03	;
	
	fragColor.rgba = vec4(1.0, 0.0, 0.0, 0.0);
	fragColor.a += lineblast(DGUNRANGE + ((BLASTRADIUS - DGUNRANGE) * 0.37), 3, 0.5);
	fragColor.a += lineblast(DGUNRANGE + ((BLASTRADIUS - DGUNRANGE) * 0.475), 2, 0.25);
	fragColor.a += lineblast(DGUNRANGE + ((BLASTRADIUS - DGUNRANGE) * 0.652), 2, 0.185);
	fragColor.a += lineblast(DGUNRANGE + ((BLASTRADIUS - DGUNRANGE) * 0.83), 2, 0.13);
	fragColor.a += lineblast(BLASTRADIUS                                   , 2, 0.085);
	
}