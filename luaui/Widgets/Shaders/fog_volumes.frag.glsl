#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000
uniform float iconDistance;
in DataVS {
	vec4 v_worldPosRad;
	vec4 v_colordensity;
	vec4 v_spawnframe_frequency_riserate_windstrength;
	vec2 v_uvs;
	vec3 v_fragWorld;
	float currfade;
};

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D heightmapTex;
uniform sampler2D infoTex;
uniform sampler2DShadow shadowTex;
uniform sampler3D noise64cube;
uniform sampler2D dithernoise2d;
uniform sampler3D worley3D;

out vec4 fragColor;

float frequency;

// https://gist.github.com/wwwtyro/beecc31d65d1004f5a9d
vec2 raySphereIntersect(vec3 r0, vec3 rd, vec3 s0, float sr) {
    // - r0: ray origin
    // - rd: normalized ray direction
    // - s0: sphere center
    // - sr: sphere radius
    // - Returns distance from r0 to first intersection with sphere,
    //   or -1.0 if no intersection.
    float a = dot(rd, rd);
    vec3 s0_r0 = r0 - s0;
    float b = 2.0 * dot(rd, s0_r0);
    float c = dot(s0_r0, s0_r0) - (sr * sr);
	float disc = b * b - 4.0 * a* c;
    if (disc < 0.0) {
        return vec2(-1.0, -1.0);
    }else{
		disc = sqrt(disc);
		return vec2(-b - disc, -b + disc) / (2.0 * a);
	}
}

float shadowAtWorldPos(vec3 worldPos){
		vec4 shadowVertexPos = shadowView * vec4(worldPos,1.0);
		shadowVertexPos.xy += vec2(0.5);
		return clamp(textureProj(shadowTex, shadowVertexPos), 0.0, 1.0);
}

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5*(a-b)/k, 0.0, 1.0);
	return mix(a, b, h) - k*h*(1.0-h);
}

vec4 raymarch(vec3 startpoint, vec3 endpoint, float steps, vec4 sphereposrad, vec2 screenuv, float noisethreshold){
	float noisescale = 0.002 * v_spawnframe_frequency_riserate_windstrength.y;
	float fulldist = length((startpoint - endpoint));
	float stepsize = fulldist / steps; // this is number of elmos per sample
	float interval = 1.0/ steps; // step interval
	
	float fogaccum = 1.0; 
	float shadowamount = 0.0;
	
	// we need a better way to accumulate, kind of like how much light is let through
	float currenttime = timeInfo.x+ timeInfo.w;
	vec4 dithernoise = textureLod(dithernoise2d, startpoint.xz, 0.0);
	vec3 noiseoffset;
	noiseoffset.y = -0.3 * currenttime * v_spawnframe_frequency_riserate_windstrength.z; 
	noiseoffset.xz = -0.0001 * currenttime * (windInfo.xz*windInfo.w) * v_spawnframe_frequency_riserate_windstrength.w;
	
	float totaldensity = 0.0;
	vec3 tolight = sunDir.xyz;

	float meanZ = 0.0;
	float weightZ = 0.0;
	float maxDensity = 0;
	float maxZ = 0;
	float truesteps = 1.0;
	for (float f = dithernoise.x*interval*0.0; f < 1.0; f = f + interval){
		// Interpolate the position between start and end
		vec3 currpos = mix(startpoint, endpoint, f);
		vec3 noisepos = currpos + noiseoffset;
		noisepos += noiseoffset;
		
		
		//float justnoiseval = (textureLod(noise64cube, fract(noisepos * noisescale), 0.0).r * 2.0 - 1.0);
		vec4 justnoiseval = (textureLod(worley3D, fract(noisepos * noisescale), 0.0) * 2.0 - 1.0);
		//float justnoiseval = (texelFetch(worley3D, ivec3(fract(noisepos * noisescale)*127.0),0).r * 2.0 - 1.0); // fetch is hardly faster but has banding artifacts
		justnoiseval.a = pow(justnoiseval.a, 0.5); //sharpen
		float localdensity =  max(justnoiseval.a + noisethreshold + sin(currenttime *0.01) * 0.15, 0.0) * stepsize * interval;
		
		totaldensity += localdensity / interval;
		fogaccum = fogaccum  * (1.0 -  clamp(localdensity  * 5, 0.0, 0.8));
		meanZ += f * totaldensity;
		weightZ += totaldensity;
		
		shadowamount += dot(clamp(justnoiseval.xyz, -1.0, 1.0), vec3(1,-1,-1));
		
		if (totaldensity> maxDensity){
			maxZ = f;
			maxDensity = totaldensity;
		}
		
		//shadowamount = shadowamount - 1.0* 4 * max(localdensity, 0.0);
		#if USESHADOWS == 1 
			if (localdensity > 0) {
				
				truesteps +=1.0;
				shadowamount = shadowamount + shadowAtWorldPos(currpos); // yes this can help reduce overhead
			}
		#endif
	}
	
	shadowamount = shadowamount / truesteps;
	shadowamount = pow(shadowamount, 1.0);
	#if USESHADOWS == 0
		shadowamount = 1.0;
	#endif
	//if (shadowamount < 0.01) shadowamount = 0.0; // DEBUG FOR NO SHADOWS
	meanZ = meanZ/weightZ;
	maxZ = smin(meanZ, maxZ, 4.0); // NIIIICE
	
	vec4 surfaceNoise = texture(worley3D, fract((mix(startpoint, endpoint, (maxZ)) + noiseoffset*0.2) * noisescale * 40.0)) * 2.0 - 1;
	
	surfaceNoise = max(surfaceNoise, 0);
	
	return vec4(fogaccum, shadowamount, max(0.0,totaldensity + maxDensity*surfaceNoise.a *0.05), meanZ);
}


#line 31000
void main(void)
{
	frequency = v_spawnframe_frequency_riserate_windstrength.y;
	vec3 camPos = cameraViewInv[3].xyz ;
	vec3 camDir = normalize(camPos-v_fragWorld);
	const float radiusmult = 0.98; //0.98;
	float internalradius = radiusmult * v_worldPosRad.w;
	
	// Determine the close and far distances of the sphere from the camera point
	vec2 closeandfarsphere = raySphereIntersect(camPos, -1.0 * normalize(camDir), v_worldPosRad.xyz, internalradius);
	
	vec2 screenUV = gl_FragCoord.xy * RESOLUTION / viewGeometry.xy;
	#if USEDEFERREDBUFFERS == 1
		// Sample the depth buffers, and choose whichever is closer to the screen
		float mapdepth = texture(mapDepths, screenUV).x;
		float modeldepth = texture(modelDepths, screenUV).x;
		mapdepth = min(mapdepth, modeldepth);
		
		// Transform screen-space depth to world-space position
		vec4 mapWorldPos =  vec4( vec3(screenUV.xy * 2.0 - 1.0, mapdepth),  1.0);
		mapWorldPos = cameraViewProjInv * mapWorldPos;
		mapWorldPos.xyz = mapWorldPos.xyz / mapWorldPos.w; // YAAAY this works!
		
		//If the terrain is closer than the far point, we take its minimum
		float distancetoeye = length(camPos - mapWorldPos.xyz);
		closeandfarsphere.y = min(closeandfarsphere.y, distancetoeye);
		
		// if the terrain is closer than the near point, we must discard the fragment altogether
		if (distancetoeye <= closeandfarsphere.x) discard;
	#endif
	
	// 3D coords of the close and the far points
	vec3 close_spherepoint = -1 * camDir * closeandfarsphere.x  + camPos;
	vec3 far_spherepoint   = -1 * camDir * closeandfarsphere.y  + camPos;
	
	// The actual relative distance of the ray through the sphere
	float distthroughsphere = clamp((closeandfarsphere.y - closeandfarsphere.x )/ (2 * internalradius), 0.0, 1.0);
		
	float distancetosphere = length(camPos - v_worldPosRad.xyz);
	if (distancetosphere < internalradius) { // This handles the case when the camera is _inside_ the sphere
		close_spherepoint = camPos;
		far_spherepoint = -1 * camDir * max(closeandfarsphere.x, closeandfarsphere.y)  + camPos;
		distthroughsphere = clamp(length(camPos - far_spherepoint) / (2 * internalradius), 0.0, 1.0);
		fragColor.rgba = vec4( vec3(distthroughsphere), 1.0);
	}

	// Debug distance through sphere, and the far sphere points position:
	//fragColor.rgba = vec4( vec3(distthroughsphere), 1.0); return;
	//fragColor.rgba = vec4( fract(far_spherepoint * 0.01), 1.0); return;
	
	if (distthroughsphere<=0) discard;	
	float fogamout = max(0.0,pow(distthroughsphere ,3.5));
	//fragColor.rgba = vec4(vec3(1.0), sqrt(distthroughsphere)); return;// if we only wanted a plain even fog then this would be it
	

	vec4 rm = raymarch(far_spherepoint, close_spherepoint, 128.0, v_worldPosRad, screenUV, -0.0);
	fragColor.rgba = vec4(vec3(rm.rgb), 1.0);
	rm.r = clamp(rm.r, 0.0, 1.0);
	fragColor.rgba = vec4(vec3(rm.g), (1.0 - rm.r) * fogamout);
	fragColor.rgba = vec4(vec3(rm.g),1.0 -  exp(-rm.b * 0.05));
	fragColor.rgba = vec4(vec3(rm.g),1.0 -  exp(-rm.b * 0.05 * fogamout));
	
	//fragColor.a *= fogamout;
	// colorize the fog accordingly:
	//fragColor.rgb *= v_colordensity.rgb;
	
	//fragColor.rgba = vec4( fract(far_spherepoint * 0.02), 1.0);
	//fragColor.a = 1.0;
}