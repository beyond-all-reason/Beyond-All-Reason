#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

#line 5000

layout (location = 0) in vec4 lengthwidthrotation; // l w rot and maxalpha
layout (location = 1) in vec4 uvoffsets;
layout (location = 2) in vec4 alphastart_alphadecay_heatstart_heatdecay;
layout (location = 3) in vec4 worldPos; // w = also gameframe it was created on
layout (location = 4) in vec4 parameters; // x: BWfactor, y:glowsustain, z:glowadd, w: fadeintime

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

uniform float fadeDistance;
uniform sampler2D heightmapTex;

out DataVS {
	uint v_skipdraw;
	vec4 v_lengthwidthrotation;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters;
};

bool vertexClipped(vec4 clipspace, float tolerance) {
  return any(lessThan(clipspace.xyz, -clipspace.www * tolerance)) ||
         any(greaterThan(clipspace.xyz, clipspace.www * tolerance));
}
#line 11000
void main()
{
	// passthrough to geometry shader
	v_centerpos = worldPos;
	
	// texture sampling here is no longer really required, but might be needed in the future if heightmap under decal changes significantly...
	//v_centerpos.y = textureLod(heightmapTex, heightmapUVatWorldPos(v_centerpos.xz), 0.0).x;
	
	// Pass all params to Geo shader
	v_centerpos.w = 1.0;
	v_uvoffsets = uvoffsets;
	v_parameters = parameters;
	v_lengthwidthrotation = lengthwidthrotation;
	
	v_skipdraw = 0u;
	// Do a trick that makes decals < 48 sized only render a single quad
	if ((lengthwidthrotation.x < SINGLEQUADDECALSIZETHRESHOLD) && (lengthwidthrotation.y < SINGLEQUADDECALSIZETHRESHOLD)) v_skipdraw = 2u; 

	// Do visibility culling in the geometry shader, quite useful.
	float maxradius =  lengthwidthrotation.x + lengthwidthrotation.y;
	if (isSphereVisibleXY(vec4(v_centerpos), maxradius)) v_skipdraw = 1u; 

	// Calculate dynamic parameters for transparency
	float currentFrame = timeInfo.x + timeInfo.w;
	float lifetonow = currentFrame - worldPos.w;
	float alphastart = alphastart_alphadecay_heatstart_heatdecay.x;
	float alphadecay = alphastart_alphadecay_heatstart_heatdecay.y;
	// fade in the decal over 200 ms?
	
	float currentAlpha = min(1.0, (lifetonow / parameters.w))  * alphastart - lifetonow* alphadecay;
	currentAlpha = clamp(currentAlpha, 0.0, lengthwidthrotation.w);
	v_lengthwidthrotation.w = currentAlpha;
	if (currentAlpha < 0.01) v_skipdraw = 1u;
	
	// heatdecay is:
	float heatdecay = alphastart_alphadecay_heatstart_heatdecay.w;
	float heatstart = alphastart_alphadecay_heatstart_heatdecay.z;
	float heatsustain = parameters.y;
	float currentheat = heatstart * exp( -0.033 * step(heatsustain, lifetonow) * (lifetonow - heatsustain) * heatdecay);
	v_parameters.w = currentheat;

	vec3 toCamera = cameraViewInv[3].xyz - v_centerpos.xyz;
	//if (dot(toCamera, toCamera) >  fadeDistance * fadeDistance) v_skipdraw = 1u;
	
	
	gl_Position = cameraViewProj * v_centerpos;
}