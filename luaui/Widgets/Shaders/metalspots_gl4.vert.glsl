#version 420

uniform sampler2D heightMap;

uniform vec4 visibilitycontrols;
// This shader is (c) Beherith (mysterme@gmail.com)

layout (location = 0) in vec4 localpos_dir_angle;
layout (location = 1) in vec4 worldpos_radius;
layout (location = 2) in vec4 visibility; // notoccupied, gameframewhenithappened
layout (location = 3) in vec4 uvcoords; // notoccupied, gameframewhenithappened

out DataVS {
	float circlealpha;
	vec4 v_targetcolor;
	vec4 v_uvcoords;
};

//__ENGINEUNIFORMBUFFERDEFS__
#line 10090

float heightAtWorldPos(vec2 w){
	vec2 uvhm = vec2(clamp(w.x, 8.0, mapSize.x - 8.0), clamp(w.y, 8.0, mapSize.y - 8.0)) / mapSize.xy;
	return textureLod(heightMap, uvhm, 0.0).x;
}

#define ROTDIR localpos_dir_angle.z
#define VERTEXTYPE localpos_dir_angle.w

#define NOTOCCUPIED visibility.x
#define GAMEFRAMECHANGED visibilty.y

#define TEXTWIDTH visibility.z
#define TEXTHEIGHT visibility.w


void main()
{
	// Bail early for out-of-view stuff
	if (isSphereVisibleXY(vec4(worldpos_radius.xyz,1.0),128.0)) {
		gl_Position = cameraViewProj * vec4(-1000,-1000,-1000,1);
		return;
	}

	// rotate for animation:
	vec3 vertexWorldPos = vec3(localpos_dir_angle.x,0,localpos_dir_angle.y);

	float s = sign(ROTDIR);
	mat3 roty = rotation3dY(s * (timeInfo.x + timeInfo.w) * 0.005);
	vertexWorldPos.x *= s;

	vertexWorldPos = roty * vertexWorldPos;

	// scale the circle and move to world pos:
	vec3 worldXYZ = vec3(worldpos_radius.x, heightAtWorldPos(worldpos_radius.xz), worldpos_radius.z);
	vertexWorldPos = vertexWorldPos * (12.0 + ROTDIR) * 2.0 * worldpos_radius.w + worldXYZ;

	//dump to FS:
	gl_Position = cameraViewProj * vec4(vertexWorldPos,1.0);

	circlealpha = mix(
		0.5 - ((timeInfo.x + timeInfo.w)- visibility.y) / 30.0, // turned unoccipied, fading into visibility
		      ((timeInfo.x + timeInfo.w) - visibility.y) / 30.0, // going into occupied, so fade out from visibility.y
		step(0.5, visibility.x)            // 1.0 if visibility is > 0.5
	);
	circlealpha = clamp(circlealpha, 0.0, 0.5);
	v_targetcolor = vec4(vec3(1),circlealpha);
	
	v_uvcoords = vec4(-1);
	
	// Handle alternate cases of localpos_dir_angle.w being > 0:
	if (VERTEXTYPE == 1.0) {
		if (ROTDIR != 0)  circlealpha = 0;
		if (NOTOCCUPIED > 0.5){ // free is cyan
			v_targetcolor = vec4(0,1,0.5,1);
		} else{ // taken is red
			v_targetcolor = vec4(1,0,0,1);
		}
	
	}
	
	if (VERTEXTYPE == 2.0){
		v_uvcoords = uvcoords;
		// Make a silly ass billboard
		circlealpha= 1.0;
		vec4 bbpos = vec4(TEXTWIDTH * localpos_dir_angle.x, 0, 2*TEXTHEIGHT * localpos_dir_angle.y ,  1.0) ;
		mat3 rotY = mat3(cameraViewInv[0].xyz,cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz
		bbpos.xyz =  (rotY * bbpos.xyz * 0.25 + worldXYZ) ;
		gl_Position = cameraViewProj * bbpos;
		// interpolate the goddamned uvs here:
		if (localpos_dir_angle.x <= 0) v_uvcoords.x = uvcoords.x;
		else v_uvcoords.x = uvcoords.y;
		if (localpos_dir_angle.y <= 0) v_uvcoords.y = uvcoords.z;
		else v_uvcoords.y = uvcoords.w	;
	}
	
}