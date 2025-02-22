#version 420
#line 10000

// This shader is (c) Beherith (mysterme@gmail.com)

//__DEFINES__

layout (location = 0) in vec2 xyworld_xyfract;
uniform vec4 radarcenter_range;  // x y z range
uniform float resolution;  // how many steps are done

uniform sampler2D heightmapTex;

out DataVS {
	vec4 worldPos; // pos and radius
	vec4 centerposrange;
	vec4 blendedcolor;
	float worldscale_circumference;
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11009

float heightAtWorldPos(vec2 w){
	vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy;
	return max(0.0, textureLod(heightmapTex, uvhm, 0.0).x);
}

void main() {
	// transform the point to the center of the radarcenter_range

	vec4 pointWorldPos = vec4(0.0);

	vec3 radarMidPos = radarcenter_range.xyz + vec3(16.0, 0.0, 16.0);
	pointWorldPos.xz = (radarcenter_range.xz +  (xyworld_xyfract.xy * radarcenter_range.w)); // transform it out in XZ
	pointWorldPos.y = heightAtWorldPos(pointWorldPos.xz); // get the world height at that point

	vec3 toradarcenter = vec3(radarcenter_range.xyz - pointWorldPos.xyz);
	float dist_to_center = length(toradarcenter.xyz);

	// get closer to the center in N mip steps, and if that point is obscured at any time, remove it

	vec3 smallstep =  toradarcenter / resolution;
	float obscured = 0.0;

	//for (float i = 0.0; i < mod(timeInfo.x/3,resolution); i += 1.0 ) {
	for (float i = 0.0; i < resolution; i += 1.0 ) {
		vec3 raypos = pointWorldPos.xyz + (smallstep) * i;
		float heightatsample = heightAtWorldPos(raypos.xz);
		obscured = max(obscured, heightatsample - raypos.y);
		if (obscured >= 2.0)	break;
	}

	worldscale_circumference = 1.0; //startposrad.w * circlepointposition.z * 5.2345;
	worldPos = vec4(pointWorldPos);
	blendedcolor = vec4(0.0);
	blendedcolor.a = 0.5;
	//if (dist_to_center > radarcenter_range.w) blendedcolor.a = 0.0;  // do this in fs instead

	blendedcolor.g = 1.0-clamp(obscured*0.5,0.0,1.0);

	blendedcolor.a = min(blendedcolor.g,blendedcolor.a);
	blendedcolor.g = 1.0;

	pointWorldPos.y += 0.1;
	worldPos = pointWorldPos;
	gl_Position = cameraViewProj * vec4(pointWorldPos.xyz, 1.0);
	centerposrange = vec4(radarMidPos, radarcenter_range.w);
}