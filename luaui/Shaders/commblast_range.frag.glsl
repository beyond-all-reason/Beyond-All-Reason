#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000
uniform float iconDistance;
in DataVS {
	flat vec3 v_centerpos; // xyz and radius?
	flat vec4 v_teamcolor; // red or teamcolor, and alpha modifier
	noperspective vec2 v_screenUV;
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
	float mapdepth = texture(mapDepths, v_screenUV).x;
	// Transform screen-space depth to world-space position
	vec4 mapWorldPos =  vec4( vec3(v_screenUV.xy * 2.0 - 1.0, mapdepth),  1.0);
	mapWorldPos = cameraViewProjInv * mapWorldPos;
	mapWorldPos.xyz = mapWorldPos.xyz / mapWorldPos.w; // YAAAY this works!

	vec3 mapToComm = v_centerpos.xyz - mapWorldPos.xyz;
	distancetocomm = length(mapToComm);
	

	if (distancetocomm > BLASTRADIUS) fragColor.a = 0.0	;
	
	fragColor.rgba = vec4(1.0, 0.0, 0.0, 0.0);
	fragColor.rgb = v_teamcolor.rgb;
	fragColor.a += lineblast(DGUNRANGE + ((BLASTRADIUS - DGUNRANGE) * 0.37), 3, 0.5);
	fragColor.a += lineblast(DGUNRANGE + ((BLASTRADIUS - DGUNRANGE) * 0.475), 2, 0.25);
	fragColor.a += lineblast(DGUNRANGE + ((BLASTRADIUS - DGUNRANGE) * 0.652), 2, 0.185);
	fragColor.a += lineblast(DGUNRANGE + ((BLASTRADIUS - DGUNRANGE) * 0.83), 2, 0.13);
	fragColor.a += lineblast(BLASTRADIUS                                   , 2, 0.085);
	
	fragColor.a *= OPACITYMULTIPLIER;
	fragColor.a *= v_teamcolor.a;
}
