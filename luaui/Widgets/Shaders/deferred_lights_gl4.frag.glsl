#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)
// Notes:
// texelFetch is hardly faster but has banding artifacts, do not use!

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000

uniform int pointbeamcone = 0; // 0 = point, 1 = beam, 2 = cone

in DataVS {
	vec4 v_worldPosRad;
	vec4 v_worldPosRad2;
	vec4 v_lightcolor;
	vec4 v_falloff_dense_scattering;
	vec4 v_otherparams;
	vec4 v_position;
	vec4 v_debug;
};

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D mapNormals;
uniform sampler2D modelNormals;
uniform sampler2D mapExtra;
uniform sampler2D modelExtra;

out vec4 fragColor;

float frequency;


float smoothmin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5*(a-b)/k, 0.0, 1.0);
	return mix(a, b, h) - k*h*(1.0-h);
}

#line 31000
void main(void)
{
	// corresponding screenspace pos:
	vec2 screenUV = gl_FragCoord.xy / viewGeometry.xy;
	
	float mapdepth = texture(mapDepths, screenUV).x;
	float modeldepth = texture(modelDepths, screenUV).x;
	mapdepth = min(mapdepth, modeldepth);
	
	vec4 mapWorldPos =  vec4( vec3(screenUV.xy * 2.0 - 1.0, mapdepth),  1.0);
	mapWorldPos = cameraViewProjInv * mapWorldPos;
	mapWorldPos.xyz = mapWorldPos.xyz / mapWorldPos.w; // YAAAY this works!
	
	fragColor.rgba = vec4(fract(mapWorldPos.xyz * 0.01),1.0);
}