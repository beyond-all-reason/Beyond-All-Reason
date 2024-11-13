#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000


in DataVS {
	flat vec4 v_worldPosRad;
	flat vec4 v_worldPosRad2;
	flat vec4 v_lightcolor;
	vec4 v_otherparams;
	vec4 v_noiseoffset; // contains wind data, very useful!
	noperspective vec2 v_screenUV; // i have no fucking memory as to why this is set as noperspective
};

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler3D noise3DCube;

uniform float pointbeamcone = 0;

// = 0; // 0 = point, 1 = beam, 2 = cone
uniform float radiusMultiplier = 1.0;
uniform float intensityMultiplier = 1.0;

out vec4 fragColor;

// Kinda useful debug macro:
// RED is the fractional part of the input
// GREEN is the square root of the floor of the input divided by 256
// Blue is for negative numbers
#define DEBUG(x) fragColor.rgba = vec4( fract(x), sqrt(floor(x) / 256.0),(x < 0,1,0),1.0); return;

// Given a beam between beamStart and beamEnd, returns the pos on the beam closest to desired Point
vec3 closestbeam(vec3 point, vec3 beamStart, vec3 beamEnd){
	vec3 beamvec = beamEnd -beamStart ;
	vec3 pointbeam = point - beamStart;
	float c1 = dot(pointbeam, beamvec);
	float c2 = dot(beamvec, beamvec);
	if (c1 <=0 ) return beamStart;
	if (c2 <=c1) return beamEnd;
	return beamStart + (c1/c2) * beamvec;
}
//https://iquilezles.org/articles/distfunctions/

// Given a ray origin and a direction, returns the closes point on the ray in xyz and the distance in w
vec4 closestlightlp_distance (vec3 ro, vec3 rd, vec3 P){
	float t0 = dot(rd, P - ro) / dot(rd, rd);
	vec3 intersectPoint = ro + t0 * rd;
	return vec4(intersectPoint, length(P - intersectPoint));
}


// https://gist.github.com/wwwtyro/beecc31d65d1004f5a9d
vec2 raySphereIntersect(vec3 rayOrigin, vec3 rayDirection, vec3 sphereCenter, float sphereRadius) {
    // - r0: ray origin
    // - rd: normalized ray direction
    // - s0: sphere center
    // - sr: sphere radius
    // - Returns distance from r0 to first intersection with sphere in X, and the distance to the second intersection in Y
    //   or -1.0 if no intersection.
    float a = dot(rayDirection, rayDirection);
    vec3 sphereCenter_to_rayOrigin = rayOrigin - sphereCenter;
    float b = 2.0 * dot(rayDirection, sphereCenter_to_rayOrigin);
    float c = dot(sphereCenter_to_rayOrigin, sphereCenter_to_rayOrigin) - (sphereRadius * sphereRadius);
	float disc = b * b - 4.0 * a* c;
    if (disc < 0.0) {
        return vec2(-1.0, -1.0);
    }else{
		disc = sqrt(disc);
		return vec2(-b - disc, -b + disc) / (2.0 * a);
	}
}

// Given a ray origin and a direction, returns the closes point on the ray in xyz and the distance in w
// marginally faster, about the cost as a single octave of perlin
vec4 ray_to_capsule_distance_squared(vec3 rayOrigin, vec3 rayDirection, vec3 cap1, vec3 cap2){ // point1, dir1, beamstart, beamend
	// returns the squared distance of the ray and the line segment in w
	// returns the closest point on beam in xyz
	float rd_dot_rd_inv = 1.0 / dot(rayDirection, rayDirection);
	
	float t1 = dot(rayDirection, cap1 - rayOrigin) * rd_dot_rd_inv;
	vec3 intersectPoint1 = rayOrigin + t1 * rayDirection;
	
	float t2 = dot(rayDirection, cap2 - rayOrigin) * rd_dot_rd_inv;
	vec3 intersectPoint2 = rayOrigin + t2 * rayDirection;
	
	vec3 cap2tocap1 = cap2 - cap1;

	vec3 interSectToC2 = cap2 - intersectPoint2;
	vec3 interSectToC1 = cap1 - intersectPoint1;	

	float angle1 = dot(cap2tocap1, interSectToC1);
	float angle2 = dot(cap2tocap1, interSectToC2);
	
	vec3 connectornormal = cross(rayDirection, cap2tocap1); // n is the normal of the line connecting them
	float dd = dot(connectornormal, rayOrigin - cap1); // this is the angle between the connector normal and 
	float sqdistline = dd*dd / dot(connectornormal, connectornormal); // sqdistline; 

	float distcap2 = dot(interSectToC2, interSectToC2) ;
	float distcap1 = dot(interSectToC1, interSectToC1) ;  //sqdistends
	
	vec3 closestpointbeam = cap1 + cap2tocap1 * sqrt(abs(distcap1 - sqdistline)/dot(cap2tocap1,cap2tocap1));
	vec4 finalposanddist = mix(vec4(cap1, distcap1) ,
		vec4(cap2, distcap2) ,
		step(distcap2, distcap1));
		
	if (angle1 < 0 && angle2 > 0){ // this means that our ray is hitting between the caps
		finalposanddist.w = sqdistline;
		finalposanddist.xyz = closestpointbeam;
	}
	finalposanddist.w = sqrt(finalposanddist.w);
	return finalposanddist;
}
//http://www.realtimerendering.com/intersections.html

//https://iquilezles.org/articles/intersectors/
// capsule defined by extremes pa and pb, and radious ra
// Note that only ONE of the two spherical caps is checked for intersections,
// which is a nice optimization
float capIntersect( in vec3 ro, in vec3 rd, in vec3 pa, in vec3 pb, in float ra )
{
    vec3  ba = pb - pa;
    vec3  oa = ro - pa;
    float baba = dot(ba,ba);
    float bard = dot(ba,rd);
    float baoa = dot(ba,oa);
    float rdoa = dot(rd,oa);
    float oaoa = dot(oa,oa);
    float a = baba      - bard*bard;
    float b = baba*rdoa - baoa*bard;
    float c = baba*oaoa - baoa*baoa - ra*ra*baba;
    float h = b*b - a*c;
    if( h >= 0.0 )
    {
        float t = (-b-sqrt(h))/a;
        float y = baoa + t*bard;
        // body
        if( y>0.0 && y<baba ) return t;
        // caps
        vec3 oc = (y <= 0.0) ? oa : ro - pb;
        b = dot(rd,oc);
        c = dot(oc,oc) - ra*ra;
        h = b*b - c;
        if( h>0.0 ) return -b - sqrt(h);
    }
    return -1.0;
}


//  Value Noise 3D Deriv
//  Return value range of 0.0->1.0, with format vec4( value, xderiv, yderiv, zderiv )
//
vec4 Value3D_Deriv( vec3 P )
{
    //  https://github.com/BrianSharpe/Wombat/blob/master/Value3D_Deriv.glsl

    // establish our grid cell and unit position
    vec3 Pi = floor(P);
    vec3 Pf = P - Pi;
    vec3 Pf_min1 = Pf - 1.0;

    // clamp the domain
    Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
    vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

    // calculate the hash
    vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
    Pt *= Pt;
    Pt = Pt.xzxz * Pt.yyww;
    vec2 hash_mod = vec2( 1.0 / ( 635.298681 + vec2( Pi.z, Pi_inc1.z ) * 48.500388 ) );
    vec4 hash_lowz = fract( Pt * hash_mod.xxxx );
    vec4 hash_highz = fract( Pt * hash_mod.yyyy );

    //	blend the results and return
    vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
    vec3 blendDeriv = Pf * Pf * (Pf * (Pf * 30.0 - 60.0) + 30.0);
    vec4 res0 = mix( hash_lowz, hash_highz, blend.z );
    vec4 res1 = mix( res0.xyxz, res0.zwyw, blend.yyxx );
    vec4 res3 = mix( vec4( hash_lowz.xy, hash_highz.xy ), vec4( hash_lowz.zw, hash_highz.zw ), blend.y );
    vec2 res4 = mix( res3.xz, res3.yw, blend.x );
    return vec4( res1.x, 0.0, 0.0, 0.0 ) + ( vec4( res1.yyw, res4.y ) - vec4( res1.xxz, res4.x ) ) * vec4( blend.x, blendDeriv );
}

vec4 curl3d( vec3 P )
{
	vec4 n1 =  Value3D_Deriv( P );
	vec4 n2 =  Value3D_Deriv( P * 1.72198 );
	return vec4( n1.x + n2.x, cross(n1.yzw, n2.yzw) );
}

#line 31000
void main(void)
{
	//fragColor.rgba = vec4(fract(gl_FragCoord.zzz * 1.0),1.0); return;
	
	
	float mapdepth = texture(mapDepths, v_screenUV).x;
	float modeldepth = texture(modelDepths, v_screenUV).x;
	float worlddepth = min(mapdepth, modeldepth);
	vec4 targetcolor = vec4(0); // target color of the surface
	float ismodel = 0;
	
	// Only query the textures if the backface of the volume is further than the world fragment
	if (gl_FragCoord.z > worlddepth) {
		if (modeldepth < mapdepth) { // We are processing a model fragment
			ismodel = 1;
			
		}else{
		}
	}
	
	vec4 fragWorldPos =  vec4( vec3(v_screenUV.xy * 2.0 - 1.0, worlddepth),  1.0);
	fragWorldPos = cameraViewProjInv * fragWorldPos;
	fragWorldPos.xyz = fragWorldPos.xyz / fragWorldPos.w; // YAAAY this works!
	
	vec3 camPos = cameraViewInv[3].xyz;

	float fragDistance = length(camPos - fragWorldPos.xyz);
	vec3 viewDirection = (camPos - fragWorldPos.xyz) / fragDistance; // vector pointing in the direction of the eye ray
	
	float lightRadius = v_worldPosRad.w;
	float lightRadiusInv = 1.0 / lightRadius;
	vec3 lightDirection = vec3(0); // the normalized vector from the light source to the fragment
	vec3 lightToWorld = vec3(0); // The vector pointing from light source to fragment world pos
	vec3 lightPosition = vec3(0); // This is the position of the light illuminating the fragment
	vec3 lightEmitPosition = vec3(0); // == lightPosition, except for beams, where the lightEmitPosition for a ray is different than for a world fragment
	
	vec4 closestpoint_dist = vec4(0); // the point that is closest to the light source (xyz) and the distance to it (w)
	
	// Lighting components we wish to collect along the way:
	float attenuation = 0; // Just the distance from the light source (multiplied with falloff for cones

	float volumetricFraction = 1.0; // The fraction of the ray that passes through the volume. 
	
	//fragColor.rgba = vec4(fract(fragWorldPos.xyz * 0.1),1.0); return; // Debug fragment world position
	
	#line 32000
	if (pointbeamcone < 0.5){ //point
		lightPosition = v_worldPosRad.xyz;
		lightEmitPosition = lightPosition;
		
		lightToWorld = fragWorldPos.xyz - lightPosition;
		lightDirection = normalize(lightToWorld);
		attenuation = clamp( 1.0 - length (lightToWorld) * lightRadiusInv, 0,1);
		closestpoint_dist = closestlightlp_distance(camPos, viewDirection, lightPosition);

		// Need to invert view direction as we need ray pointing from camera to sphere
		vec2 sphereDistances = raySphereIntersect(camPos, -1 * viewDirection, lightPosition, lightRadius);

		// If the fragment is inside the sphere, we need to calculate the volumetric fraction
		if (fragDistance < sphereDistances.y){
			// FUCK WHY THE 0.5? 
			volumetricFraction =1.0 -  clamp(0.5*abs(sphereDistances.y - fragDistance) / abs(sphereDistances.y - sphereDistances.x), .0, 1.0);
		}
		//fragColor.rgba = vec4(volumetricFraction,volumetricFraction,0, 1.0); return;

	#line 33000
	}else if (pointbeamcone > 1.5){ // cone
		lightPosition = v_worldPosRad.xyz;
		
		lightToWorld = fragWorldPos.xyz - lightPosition;
		lightDirection = normalize(lightToWorld);
		vec3 coneDirection = v_worldPosRad2.xyz;
	
		float lightandworldangle = dot(lightDirection, coneDirection);

		attenuation = clamp( 1.0 - length (lightToWorld) / lightRadius, 0,1) * 1.0;
		
		lightEmitPosition = lightPosition;
		closestpoint_dist = closestlightlp_distance(camPos, viewDirection, lightPosition);
		
		vec4 rayconedist = ray_to_capsule_distance_squared(camPos, viewDirection, lightPosition + coneDirection * lightRadius,lightPosition); // this now contains the point on ConeDirection 
		//closestpoint_dist.w = sqrt(rayconedist.w);
	
		
			
	#line 34000
	}else if (pointbeamcone < 1.5){ // beam 
		vec3 beamhalflength = v_worldPosRad2.xyz - v_worldPosRad.xyz; 
		vec3 beamstart = v_worldPosRad.xyz - beamhalflength;
		vec3 beamend = v_worldPosRad.xyz + beamhalflength;
		lightPosition = closestbeam(fragWorldPos.xyz, beamstart, beamend);
		
		lightToWorld = fragWorldPos.xyz - lightPosition;
		
		lightDirection = normalize(lightToWorld);
		attenuation =  clamp( 1.0 - length (lightToWorld) *lightRadiusInv, 0,1);
		
		float dtobeam = 0;
		dtobeam = capIntersect( camPos, viewDirection, beamstart, beamend, lightRadius);
		float dtobeam2 = capIntersect( camPos, -viewDirection, beamstart, beamend, lightRadius);
		
		closestpoint_dist = ray_to_capsule_distance_squared(camPos, viewDirection, beamstart, beamend);
		lightEmitPosition = closestpoint_dist.xyz;
		
		// how to tell, if lightEmitPosition is occluded?
		vec4 lightEmitScreenPosition = cameraViewProj * vec4(lightEmitPosition, 1.0);
		lightEmitScreenPosition.xyz /= lightEmitScreenPosition.w;
		
		float closedist =  capIntersect( camPos, -viewDirection, beamstart, beamend, lightRadius);
		float fardist = - capIntersect( camPos, viewDirection, beamstart, beamend, lightRadius);
		
		vec3 EntryPoint = (-viewDirection) * closedist + camPos;
		vec3 ExitPoint =  (-viewDirection) * fardist + camPos;

		//NOTE THAT CLOSESTPOINT_DIST IS COMPLETELY INCORRECT!
	}
	#line 35000
	//float relativedistancetolight = clamp(1.0 - 10* closestpoint_dist.w/lightRadius, 0.0, 1.0);
	
	attenuation = pow(attenuation, 1.0);
	
	//-------------------------
	// DISTORTION

	// Debugging check attenuations for each light source type:
	// Draw attenuation as a color Green
	float distortionAttenuation = 1.0; // start at max

	// Take into account relative distance of ray point closest to light source to the light source
	
	float lightRange = lightRadius;
	
	distortionAttenuation *=  closestpoint_dist.w / lightRange;

	distortionAttenuation *= volumetricFraction;


	//fragColor.rgba = vec4(0.6, distortionAttenuation, 0.0, 1.0); return;

	// Check if point would be occluded
	float distortionRange = lightRadius;

	// if the fragment is closer to the camera than the light source plus its radius, we can skip the distortion
	if (length(fragWorldPos.xyz - camPos) < ( length(lightPosition - camPos) -lightRadius)){
		fragColor.rgba = vec4(0.0);
		return;
	}

	if (length(closestpoint_dist.xyz - fragWorldPos.xyz) > lightRadius) {
		fragColor.rgba = vec4(0.0);
		//return;

	}

	// TODO: Ensure that the distortion is proportionate to the amount of "Hot" volume the ray passes through. 

	vec4 noiseSample = textureLod(noise3DCube, closestpoint_dist.xyz * 0.03 - vec3(0,timeInfo.x * 0.01,0), 0.0);

	// norm2snorm
	noiseSample = noiseSample * 2.0 - 1.0;

	// modulate the effect strength with the distance to the heat source:
	noiseSample *= clamp(300.0/ fragDistance, 0.0, 1.0);

	// snorm2norm
	noiseSample = noiseSample * 0.5 + 0.5;
	//DEBUG(closestpoint_dist.w);
	//modulate alpha part with the 
	float strength  = clamp(1.0 - length(closestpoint_dist.xyz - lightPosition)/ lightRadius, 0.0, 1.0) * (distortionAttenuation);
	fragColor.rgba = vec4(vec3(noiseSample.ra, 0.0) * 1.0 , strength);
	//fragColor.rgba = vec4(0,0,0,1.0);
	return;
	//-------------------------
	
}
