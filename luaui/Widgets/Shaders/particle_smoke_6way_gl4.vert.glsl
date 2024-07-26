
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 5000

// per vertex attributes
layout (location = 0) in vec4 xy_idx_rand; // each vertex of the rectVBO, range [0,1]

// per instance attributes, hmm, 24 floats per instance....
layout (location = 1) in vec4 startpos_scale; // pos xyz, scale w
layout (location = 2) in vec4 motionvector; // dir xyz, growth w
layout (location = 3) in vec4 atlasuv;
layout (location = 4) in vec4 numTiles_lifestart_animspeed;
layout (location = 5) in vec4 emissivecolor;


vec2 GetSpriteSheetAtlasUVs(in vec2 billboardUV, float time){
	// Origin of DDS Image is bottom left
	// Each spritesheet's origin is top left, and and starts with the top row. 
	// Figure out from timing info where we need to be:
	// calculate which loop we are in
	int spritesX = int(numTiles_lifestart_animspeed.x) ;
	int spritesY = int(numTiles_lifestart_animspeed.y) ;
	
	
	int loopIndex = int(mod( int(time), spritesX * spritesY));
	
	int rowIndex = loopIndex / spritesX;
	int colIndex = int(mod(loopIndex , spritesX));
	
	vec2 spriteSize = 1.0 / numTiles_lifestart_animspeed.xy;
	
	// Calculate current offset
	vec2 spriteOffset = vec2(float(colIndex) * spriteSize.x, float(rowIndex) * spriteSize.y);
	
	// Adjust the UV coordinates to get the correct frame
	vec2 newUV = billboardUV * spriteSize + spriteOffset;
	return newUV;
}

// This function takes in a set of UV coordinates [0,1] and tranforms it to correspond to the correct UV slice of an atlassed texture
// uvoffsets is in the form of xXyY
vec2 transformUV(in vec2 inUV, in vec4 uvoffsets){// this is needed for atlassing
	//return vec2(uvoffsets.p * u + uvoffsets.q, uvoffsets.s * v + uvoffsets.t); old
	float a = uvoffsets.t - uvoffsets.s;
	float b = uvoffsets.q - uvoffsets.p;
	return vec2(uvoffsets.s + a * inUV.x, uvoffsets.p + b * inUV.y);
}

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

uniform vec2 atlasSize;
uniform sampler2D mytex1;

// We could do smoothing in the VS by sampling depth or heightfield?

out DataVS {
	vec4 v_worldPos; // needed later depth buffers, alpha is alpha
	vec4 v_uvs; // now and next
	vec4 v_worldNormal;
	vec4 v_emissivecolor; 
	vec4 v_params; // x is blend factor
};


#line 11000
void main()
{

	// Calculate timing info
	float nowTime = timeInfo.x + timeInfo.w;
	float aliveTime = nowTime - numTiles_lifestart_animspeed.z;
	float animTime = aliveTime * numTiles_lifestart_animspeed.w;
	
	// Place it into the world:
	vec3 vertexNormal = cameraViewInv[2].xyz; // camera Front direction
	vec4 vertexPos = vec4(0);
	vertexPos.w = 1.0;
	
	// Set up our base sizes
	vertexPos.xz = (xy_idx_rand.xy * 2.0 - 1.0) ;
	
	// Stretch non-square atlas elements:
	float particleStretch = (numTiles_lifestart_animspeed.y * (atlasuv.t - atlasuv.s)) / (numTiles_lifestart_animspeed.x * (atlasuv.q - atlasuv.p));
	vertexPos.x *= particleStretch;
	
	// Invert XZ because fuck if I know why:
	vertexPos.xz *= -1.0;
	
	// Expand the vertex to world scale as it grows
	vertexPos.xz *= (startpos_scale.w + motionvector.w * aliveTime);
	
	// Rotate it because its a billboard:
	mat3 billBoardMatrix = mat3(cameraViewInv[0].xyz,cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz
	vertexPos.xyz = billBoardMatrix * vertexPos.xyz;
	
	// Transform it to world coords:
	vertexPos.xyz += startpos_scale.xyz + motionvector.xyz * aliveTime;
	v_worldPos = vertexPos;

	
	// Calculate the normal of the billboard, which always points at the camera:
	vec3 camPos = cameraViewInv[3].xyz ;
	vertexNormal = normalize(camPos - vertexPos.xyz);
	v_worldNormal.xyz = vertexNormal;
	
	// Project it:
	gl_Position = cameraViewProj * vertexPos;
	
	
	// Calculate the UVS for now and for next frame
	vec2 baseUV = xy_idx_rand.xy;
	vec2 uvnow  = GetSpriteSheetAtlasUVs(baseUV, animTime);
	vec2 uvnext = GetSpriteSheetAtlasUVs(baseUV, animTime + 1);
	v_uvs.st = transformUV(uvnow, atlasuv);
	v_uvs.pq = transformUV(uvnext, atlasuv);
	
	
	// Pass through various params.
	v_emissivecolor = emissivecolor;
	
	// Interpolate between the two frames, but dont use smoothstep as that will result in a very choppy animation
	v_params.x = fract(animTime);
}