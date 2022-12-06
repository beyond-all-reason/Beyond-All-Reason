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
layout (location = 4) in vec4 parameters; // x con

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
	v_centerpos = worldPos;
	v_centerpos.y = textureLod(heightmapTex, heighmapUVatWorldPos(v_centerpos.xz), 0.0).x;
	v_centerpos.w = 1.0;
	v_uvoffsets = uvoffsets;
	
	v_parameters = alphastart_alphadecay_heatstart_heatdecay;
	
	//v_parameters.zw = alphastart_alphadecay_heatstart_heatdecay.xz - alphastart_alphadecay_heatstart_heatdecay.yw * timeInfo.x * 0.03333;
	
	//v_parameters.x = 0.0;
	float maxradius =  max(lengthwidthrotation.x, lengthwidthrotation.y);
	
	v_lengthwidthrotation = lengthwidthrotation;

	v_skipdraw = 0u;
	if (isSphereVisibleXY(vec4(v_centerpos), 1.0* maxradius)) v_skipdraw = 1u; // yay for visiblity culling!

	float currentFrame = timeInfo.x + timeInfo.w;
	float lifetonow = currentFrame - worldPos.w;
	float alphastart = alphastart_alphadecay_heatstart_heatdecay.x;
	float alphadecay = alphastart_alphadecay_heatstart_heatdecay.y;
	// fade in the decal over 200 ms?
	
	float currentAlpha = min(1.0, (lifetonow / FADEINTIME))  * alphastart - lifetonow* alphadecay;
	currentAlpha = min(currentAlpha, lengthwidthrotation.w);
	v_lengthwidthrotation.w = currentAlpha;
	// heatdecay is:
	float heatdecay = alphastart_alphadecay_heatstart_heatdecay.w;
	v_parameters.w = exp(- 0.033 * lifetonow * alphastart_alphadecay_heatstart_heatdecay.w);


	vec3 toCamera = cameraViewInv[3].xyz - v_centerpos.xyz;
	if (dot(toCamera, toCamera) >  fadeDistance * fadeDistance) v_skipdraw = 1u;
	gl_Position = cameraViewProj * v_centerpos;
}