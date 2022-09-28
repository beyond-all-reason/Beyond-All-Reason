#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)
#line 5000

layout (location = 0) in vec4 positionxy_xyfract; // l w rot and maxalpha

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

uniform sampler2D heightmapTex;

out DataVS {
	vec4 v_worldPos;
	vec4 v_uvs;
	vec4 v_fragWorld;
};

void main()
{
	float time = (timeInfo.x + timeInfo.w) * 0.1;
	
	vec4 vertexPos = vec4(1.0);
	vertexPos.xz = (positionxy_xyfract.xy + mapSize.xy) * 0.5;
	vec2 uvhm = heighmapUVatWorldPos(vertexPos.xz);
	float hmaptexlod = -0.0;
	// get height around here:
	vertexPos.y  = textureLod(heightmapTex, uvhm, hmaptexlod).x ;
	
	//get height nearby too:
	float sampledist = 64;
	vec2 nearby = sampledist / mapSize.xy;
	int numSamples = 4;
	
	float avgheight = 0.0;
	for (int x = -numSamples; x <=  numSamples; x++){
		for (int z = -numSamples; z <=  numSamples; z++){
			avgheight += textureLod(heightmapTex, uvhm + nearby * vec2(x,z), hmaptexlod).x;
		}
	}
	vertexPos.y = avgheight / (numSamples*numSamples *4);
	//vertexPos.y = max(vertexPos.y, textureLod(heightmapTex, uvhm + nearby, hmaptexlod).x);
	//vertexPos.y = max(vertexPos.y, textureLod(heightmapTex, uvhm - nearby, hmaptexlod).x);
	
	vertexPos.y += 64;
	vertexPos.y += 32 * sin(time * 0.1 + uvhm.x * 20);
	vertexPos.y += 32 * sin(time * 0.109293842 + uvhm.y * 22);
	
	
	+ 32 * sin(time * 0.1 + vertexPos.x);
	//vertexPos.y  = textureLod(heightmapTex, uvhm, 0.0).x;// * (-10) + 164 + 32 * sin(time * 0.1 + vertexPos.x);
	
	
	v_worldPos = vertexPos;
	gl_Position = cameraViewProj * vertexPos;
	
	v_uvs.xy = uvhm;
	v_uvs.zw = positionxy_xyfract.zw;
	
	v_fragWorld = gl_Position;
}