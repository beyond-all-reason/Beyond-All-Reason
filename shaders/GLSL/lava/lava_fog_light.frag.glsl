#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is Copyright (c) 2024 Beherith (mysterme@gmail.com) and licensed under the MIT License

#line 20000

uniform float lavaHeight;
uniform float heatdistortx;
uniform float heatdistortz;

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D lavaDistortion;
//uniform sampler2D mapNormals;
//uniform sampler2D modelNormals;

in DataVS {
	vec4 worldPos;
	vec4 worldUV;
	float inboundsness;
	noperspective vec2 v_screenUV;
};

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

vec2 inverseMapSize = 1.0 / mapSize.xy;

out vec4 fragColor;

#line 22000
void main() {

	vec4 camPos = cameraViewInv[3];

	// We shift the distortion texture camera-upwards according to the uniforms that got passed in
	vec2 camshift =  vec2(heatdistortx, heatdistortz) * 0.01;

	//Get the fragment depth
	// note that WE CANT GO LOWER THAN THE ACTUAL LAVA LEVEL!

	vec2 screenUV = clamp(v_screenUV, 1.0/(viewGeometry.xy), 1.0 - 1.0/ (viewGeometry.xy));

	// Sample the depth buffers, and choose whichever is closer to the screen
	float mapdepth = texture(mapDepths, screenUV).x;
	float modeldepth = texture(modelDepths, screenUV).x;
	mapdepth = min(mapdepth, modeldepth);

	// the W weight factor here is incorrect, as it comes from the depth buffers, and not the fragments own depth.

	// Convert to normalized device coordinates, and calculate inverse view projection
	vec4 mapWorldPos =  vec4(  vec3(screenUV.xy * 2.0 - 1.0, mapdepth),  1.0);
	mapWorldPos = cameraViewProjInv * mapWorldPos;
	mapWorldPos.xyz = mapWorldPos.xyz/ mapWorldPos.w; // YAAAY this works!
	float trueFragmentHeight = mapWorldPos.y;

	float fogAboveLava = 1.0;

	// clip mapWorldPos according to true lava height
	if (mapWorldPos.y< lavaHeight - FOGHEIGHTABOVELAVA - HEIGHTOFFSET) {
		// we need to make a vector from cam to fogplane position
		vec3 camtofogplane = mapWorldPos.xyz - camPos.xyz;

		// and scale it to make it
		camtofogplane = FOGHEIGHTABOVELAVA * camtofogplane /abs(camtofogplane.y);
		mapWorldPos.xyz = worldPos.xyz + camtofogplane;
		fogAboveLava = FOGABOVELAVA;
	}

	// Calculate how long the vector from top of foglightplane to lava or world pos actually is
	float actualfogdepth = length(mapWorldPos.xyz - worldPos.xyz) ;
	float fogAmount = 1.0 - exp2(- FOGFACTOR * FOGFACTOR * actualfogdepth  * 0.5);
	fogAmount *= fogAboveLava;

	// sample the distortiontexture according to camera shift and scale it down
	vec4 distortionTexture = texture(lavaDistortion, (worldUV.xy * 22.0  + camshift)) ;
	float fogdistort = (FOGLIGHTDISTORTION + distortionTexture.x + distortionTexture.y)/ FOGLIGHTDISTORTION ;


	// apply some distortion to the fog
	fogAmount *= fogdistort;


	// lets add some extra brigtness near the coasts, by finding the distance of the lavaplane to the coast
	float disttocoast = abs(trueFragmentHeight- (lavaHeight - FOGHEIGHTABOVELAVA - HEIGHTOFFSET));

	float extralightcoast =  clamp(1.0 - disttocoast * (1.0 / COASTWIDTH), 0.0, 1.0);
	extralightcoast = pow(extralightcoast, 3.0) * EXTRALIGHTCOAST;

	fogAmount += extralightcoast;

	fragColor.rgb = FOGCOLOR;
	fragColor.a = fogAmount;

	// fade out the foglightplane if it is far out of bounds
	fragColor.a *= clamp(  inboundsness * 2.0 +2.0, 0.0, 1.0);
	SWIZZLECOLORS
}
