#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

#line 5000


layout (location = 0) in vec2 xyworld_xyfract; // xz and uv
layout (location = 1) in vec4 lengthwidthrotation; // l w rot and maxalpha
layout (location = 2) in vec4 uvoffsets;
layout (location = 3) in vec4 alphastart_alphadecay_heatstart_heatdecay;
layout (location = 4) in vec4 worldPos; // also gameframe it was created on
layout (location = 5) in vec4 parameters; // x: BWfactor, y:glowsustain, z:glowadd, w: fadeintime
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

uniform float fadeDistance;
uniform sampler2D heightmapTex;


out DataGS {
	//vec4 g_color;
	vec4 g_uv;
	vec4 g_position; // how to get tbnmatrix here?
	vec4 g_parameters;
	mat3 tbnmatrix;
};

// This function takes in a set of UV coordinates [0,1] and tranforms it to correspond to the correct UV slice of an atlassed texture
vec2 transformUV(float u, float v){// this is needed for atlassing
	//return vec2(uvoffsets.p * u + uvoffsets.q, uvoffsets.s * v + uvoffsets.t); old
	float a = uvoffsets.t - uvoffsets.s;
	float b = uvoffsets.q - uvoffsets.p;
	return vec2(uvoffsets.s + a * u, uvoffsets.p + b * v);
}
/*
void offsetVertex4( float x, float y, float z, float u, float v){
	g_uv.xy = transformUV(u,v);
	vec3 primitiveCoords = vec3(x,y,z) * decalDimensions;
	//vec3 vecnorm = normalize(primitiveCoords);// AHA zero case!
	vec4 worldPos = vec4(centerpos.xyz + rotY * ( primitiveCoords ), 1.0);
	
	vec2 uvhm = heightmapUVatWorldPos(worldPos.xz);
	worldPos.y = textureLod(heightmapTex, uvhm, 0.0).x + 0.01;
	gl_Position = cameraViewProj * worldPos;
	gl_Position.z = (gl_Position.z) - 512.0 / (gl_Position.w); // send 16 elmos forward in Z
	g_uv.zw = dataIn[0].v_parameters.zw;
	g_position.xyz = worldPos.xyz;
	g_position.w = length(vec2(x,z));
	//g_mapnormal = textureLod(mapNormalsTex, uvhm, 0.0).raaa;
	//g_mapnormal.g = sqrt( 1.0 - dot( g_mapnormal.ra, g_mapnormal.ra));
	//g_mapnormal.xyz = g_mapnormal.rga;
	// the tangent of the UV goes in the +U direction
	// we _kinda_ need to know the Y rot, and the normal dir for this
	// assume that tangent points "right" (+U)
	
	vec3 Nup = vec3(0.0, 1.0, 0.0);
	vec3 Trot = rotY * vec3(1.0, 0.0, 0.0);
	vec3 Brot = rotY * vec3(0.0, 0.0, 1.0);
	tbnmatrix = mat3(Trot, Brot, Nup);

	EmitVertex();
}
*/

#line 11000
void main()
{
	// take the vertex, scale it to size, and rotate it around 0,0
	
	#if 0
		//if (isSphereVisibleXY(vec4(worldPos.xyz,1.0), 1.0* max(lengthwidthrotation.x, lengthwidthrotation.y))) {
		//	gl_Position= vec4(-100,-100,-100,1);
		//	return; // yay for useless visiblity culling!
		//}
	#endif
	
	vec4 vertexPos = vec4(xyworld_xyfract.x, 0.0, xyworld_xyfract.y, 1.0);
	vertexPos.xz *= lengthwidthrotation.xy * 0.5;
	
	// make a rotation matrix:
	mat3 rotY = rotation3dY(lengthwidthrotation.z);
	// rotate it into the world
	vertexPos.xyz = rotY * vertexPos.xyz;

	// set the UVS
	g_uv.xy = transformUV(xyworld_xyfract.x * 0.5 + 0.5, xyworld_xyfract.y * 0.5 + 0.5);
	
	// rotate the normals into the world
	vec3 Nup = vec3(0.0, 1.0, 0.0);
	vec3 Trot = rotY * vec3(1.0, 0.0, 0.0);
	//vec3 Brot = rotY * vec3(0.0, 0.0, 1.0);
	vec3 Brot = cross(Nup,Trot);
	tbnmatrix = mat3(Trot, Brot, Nup);
	
	// offset it into the world
	vertexPos.xz += worldPos.xz;
	
	// get the height here:
	vertexPos.y  = textureLod(heightmapTex, heightmapUVatWorldPos(vertexPos.xz), 0.0).x + HEIGHTOFFSET;
	
	// Output it to the FS
	gl_Position = cameraViewProj * vertexPos;
	gl_Position.z = (gl_Position.z) - 512.0 / (gl_Position.w); // send 16 elmos forward in Z
	
	// passthrough the rest of the data:
	g_position = vertexPos;
	g_parameters = parameters;
	
	// Calc alphadecay
	float currentFrame = timeInfo.x + timeInfo.w;
	float lifetonow = (timeInfo.x + timeInfo.w) - worldPos.w;
	float alphastart = alphastart_alphadecay_heatstart_heatdecay.x;
	float alphadecay = alphastart_alphadecay_heatstart_heatdecay.y;
	float currentAlpha = min(1.0, (lifetonow / parameters.w))  * alphastart - lifetonow* alphadecay;
	currentAlpha = clamp(currentAlpha, 0.0, lengthwidthrotation.w);
	g_position.w = currentAlpha;
	
	// heatdecay is:
	float heatdecay = alphastart_alphadecay_heatstart_heatdecay.w;
	float heatstart = alphastart_alphadecay_heatstart_heatdecay.z;
	float heatsustain = parameters.y;
	float currentheat = heatstart * exp( -0.033 * step(heatsustain, lifetonow) * (lifetonow - heatsustain) * heatdecay);
	g_parameters.w = currentheat ;
}