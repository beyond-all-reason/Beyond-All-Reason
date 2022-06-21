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
	flat vec4 v_falloff_dense_scattering_sourceocclusion;
	vec4 v_depths_center_map_model_min;
	vec4 v_otherparams;
	vec4 v_position;
	vec4 v_debug;
};

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D mapNormals;
uniform sampler2D modelNormals;
uniform sampler2D mapExtra;
uniform sampler2D modelExtra;

uniform float pointbeamcone = 0;
// = 0; // 0 = point, 1 = beam, 2 = cone
out vec4 fragColor;

float smoothmin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5*(a-b)/k, 0.0, 1.0);
	return mix(a, b, h) - k*h*(1.0-h);
}

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

vec4 closestlightlp_distance (vec3 ro, vec3 rd, vec3 P){
	float t0 = dot(rd, P - ro) / dot(rd, rd);
	vec3 intersectPoint = ro + t0 * rd;
	return vec4(intersectPoint, length(P - intersectPoint));
}

vec4 raypoint_sqrdistance(vec3 ro, vec3 rd, vec3 P){
	float t0 = dot(rd, P - ro) / dot(rd, rd);
	vec3 intersectPoint = ro + t0 * rd;
	return vec4(intersectPoint, dot(P - intersectPoint,P - intersectPoint));
}

//https://math.stackexchange.com/questions/2213165/find-shortest-distance-between-lines-in-3d
vec4 distancebetweenlines(vec3 r1, vec3 e1, vec3 r2, vec3 e2){ // point1, dir1, point2, dir2
	//todo handle the case where e1 == e2
	vec3 n = cross(e1, e2); // n is the normal of the line connecting them
	float distance = dot ( n, r1-r2) / length(n);
	return vec4(distance);
}


// Lens flare effect
float LensFlareDistanceSqrt(vec3 pointpos, vec3 lightpos, float radius){
	float sqrtsum = dot(sqrt(abs(pointpos - lightpos)), vec3(1.0));
	return (sqrtsum * sqrtsum) / radius;
}

// Slower, but more tuneable lens flare effect
float LensFlareDistancePow(vec3 pointpos, vec3 lightpos, float radius, float power){ 
	return pow(dot(pow(abs(pointpos - lightpos), vec3(power)), vec3(1.0)), 1.0 /power)/radius;
}



float distancebetweenlinessquared(vec3 r1, vec3 e1, vec3 r2, vec3 e2){ // point1, dir1, point2, dir2
	//todo handle the case where e1 == e2
	vec3 n = cross(e1, e2); // n is the normal of the line connecting them
	float dd = dot ( n, r1-r2);
	return dd*dd / dot(n,n);
}

vec4 ray_to_capsule_distance(vec3 ro, vec3 rd, vec3 c1, vec3 c2){ // point1, dir1, beamstart, beamend
	float sqdistline = distancebetweenlinessquared(ro, rd, c1, c2-c1);
	
	vec4 sqdistc1 = raypoint_sqrdistance(ro, rd, c1);
	vec4 sqdistc2 = raypoint_sqrdistance(ro, rd, c2);
	
	vec4 regulardist = sqrt(vec4(sqdistline, sqdistc1.w, sqdistc2.w, 1.0));

	float angle1 = dot(c1-c2, c1 - sqdistc1.xyz);
	float angle2 = dot(c2-c1, c2 - sqdistc2.xyz);
	
	float truth = min(regulardist.y, regulardist.z);
	if (angle1 > 0 && angle2 >0){
		truth = min(truth,regulardist.x);
	}
	return sqrt(vec4(sqdistline, sqdistc1.w, sqdistc2.w, truth));
}

// this implementation below is somehow slower?
#if 0
float ray_to_capsule_distance_squared(vec3 rayOrigin, vec3 rayDirection, vec3 cap1, vec3 cap2){ // point1, dir1, beamstart, beamend
	// returns the squared distance of the ray and the line segment
	float rd_dot_rd_inv = 1.0 / dot(rayDirection, rayDirection);
	
	float t1 = dot(rayDirection, cap1 - rayOrigin) * rd_dot_rd_inv;
	vec3 intersectPoint1 = rayOrigin + t1 * rayDirection;
	
	float t2 = dot(rayDirection, cap2 - rayOrigin) * rd_dot_rd_inv;
	vec3 intersectPoint2 = rayOrigin + t2 * rayDirection;
	
	vec3 cap2tocap1 = cap2 - cap1;
	
	float angle1 = dot(cap2tocap1, intersectPoint1 - cap1);
	float angle2 = dot(cap2tocap1, cap2 - intersectPoint2);
	
	if (angle1 > 0 && angle2 > 0){
		vec3 connectornormal = cross(rayDirection, cap2tocap1); // n is the normal of the line connecting them
		float dd = dot(connectornormal, rayOrigin - cap1);
		return dd*dd / dot(connectornormal, connectornormal); // sqdistline; 
	}else {
		vec3 interSectToC2 = cap2 - intersectPoint2;
		vec3 interSectToC1 = cap1 - intersectPoint1;
		return min( dot(interSectToC2, interSectToC2), dot(interSectToC1, interSectToC1) );  //sqdistends
	}
}
#else
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
	
	vec3 closestpointbeam = cap1 + cap2tocap1 * sqrt((distcap2 - sqdistline)/dot(cap2tocap1,cap2tocap1));
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
#endif
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


// we need a ray-segment distance calculator!
//https://www.codefull.net/2015/06/intersection-of-a-ray-and-a-line-segment-in-3d/


//Integrate[Power[\(40)1.0 - Sqrt[Power[\(40)P_1+A_1*x\(41),2]+Power[\(40)P_2+A_2*x\(41),2]+Power[\(40)P_3+A_3*x\(41),2]]\(41),2],{x,0,1}]
//https://www.wolframalpha.com/input?i2d=true&i=Integrate%5BPower%5B%5C%2840%291.0+-+Sqrt%5BPower%5B%5C%2840%29P_1%2BA_1*x%5C%2841%29%2C2%5D%2BPower%5B%5C%2840%29P_2%2BA_2*x%5C%2841%29%2C2%5D%2BPower%5B%5C%2840%29P_3%2BA_3*x%5C%2841%29%2C2%5D%5D%5C%2841%29%2C2%5D%2Cx%5D

//Integrate[x,{x,0,1}]Integrate[Power[\(40)1.0 - Sqrt[Power[\(40)P_1+A_1*x\(41),2]+Power[\(40)P_2+A_2*x\(41),2]+Power[\(40)P_3+A_3*x\(41),2]]\(41),2],x]
float integrateLight(vec3 A, vec3 P, float R, float x){ // inside unit-sphere space
	float AdotP = dot(A,P);
	float Psqr = dot(P,P);
	float Asqr = dot(A,A);
	vec3 AxA = A * A;
	vec3 PxP = P * P;
	float x2 = x*x;
	/*
	float result = x2*AdotP +
			sqrt(2*AdotP + x2*Asqr + Psqr) * ( -1 * AdotP/Asqr - x) -
			1.0 / pow(Asqr, 3.0/2.0) * 
			(A.x*A.x *(P.y*P.y + P.z*P.z) - 2*A.z*A.x*P.x*P.z + A.z*A.z * (P.x*P.x + P.y*P.y) + A.y*P.y *(-2*A.x*P.x - 2*A.z*P.z) + A.y*A.y *(P.x*P.x + P.z*P.z)) *
			log( sqrt(Asqr) * sqrt(2*AdotP*x + Asqr*x2 + Psqr) + AdotP + Asqr*x) +
			0.333333 * Asqr * x*x*x + (Psqr + 1) * x;

	float result2 = x2*AdotP +
			sqrt(2*AdotP + x2*Asqr + Psqr) * ( -1 * AdotP/Asqr - x) -
			1.0 / pow(Asqr, 3.0/2.0) * 
				(A.x*A.x *(P.y*P.y + P.z*P.z) + 
				 A.y*A.y *(P.x*P.x + P.z*P.z) + 
				 A.z*A.z * (P.x*P.x + P.y*P.y) // The above three are AxA *(PxP.yzx + PxP*zxy)
				 -2*A.z*A.x*P.x*P.z  + 
				 -2*A.x*A.y*P.y*P.x 
				 -2*A.y*A.z*P.z*P.y // The above three are -2 * (A.zxy * A.xyz * P.xyz * P.zxy)
				 ) *
			log( sqrt(Asqr) * sqrt(2*AdotP*x + Asqr*x2 + Psqr) + AdotP + Asqr*x) +
			0.333333 * Asqr * x*x*x + (Psqr + 1) * x;

	
	// Sub the above simplifiactions:
	float result2 = x2*AdotP +
			sqrt(2*AdotP + x2*Asqr + Psqr) * ( -1 * AdotP/Asqr - x) -
			1.0 / pow(Asqr, 3.0/2.0) * 
				(AxA *(PxP.yzx + PxP*zxy) -2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
			log( sqrt(Asqr) * sqrt(2*AdotP*x + Asqr*x2 + Psqr) + AdotP + Asqr*x) +
			0.333333 * Asqr * x*x*x + (Psqr + 1) * x;
	
	// where X is 0 
	float result3_x0 = 
			sqrt(2*AdotP + Psqr) * ( -1 * AdotP/Asqr) -
			1.0 / pow(Asqr, 3.0/2.0) * 
				(AxA *(PxP.yzx + PxP*zxy) -2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
			log( sqrt(Asqr) * sqrt(Psqr) + AdotP);
			
	// where X is 1 
	float result3_x1 = AdotP +
			sqrt(2*AdotP + Asqr + Psqr) * ( -1 * AdotP/Asqr - 1) -
			1.0 / pow(Asqr, 3.0/2.0) * 
				(AxA *(PxP.yzx + PxP*zxy) -2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
			log( sqrt(Asqr) * sqrt(2*AdotP + Asqr + Psqr) + AdotP + Asqr) +
			0.333333 * Asqr + (Psqr + 1);
			
	// difference
	float result3_x1_x0 = AdotP +
			sqrt(2*AdotP + Asqr + Psqr) * ( -1 * AdotP/Asqr - 1) -
			(1.0 / pow(Asqr, 3.0/2.0)) * 
				(AxA *(PxP.yzx + PxP*zxy) -2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
			log( sqrt(Asqr) * sqrt(2*AdotP + Asqr + Psqr) + AdotP + Asqr) +
			0.333333 * Asqr + (Psqr + 1)
			-
			(sqrt(2*AdotP + Psqr) * ( -1 * AdotP/Asqr) -
			(1.0 / pow(Asqr, 3.0/2.0)) * 
				(AxA *(PxP.yzx + PxP*zxy) -2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
			log( sqrt(Asqr) * sqrt(Psqr) + AdotP))
			;
	// LOL psqr ===1
	float result4_x1_x0 = AdotP +
			sqrt(2*AdotP + Asqr + 1) * ( -1 * AdotP/Asqr - 1) -
			(1.0 / pow(Asqr, 3.0/2.0)) * 
				(AxA *(PxP.yzx + PxP*zxy) -2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
			log( sqrt(Asqr) * sqrt(2*AdotP + Asqr + 1) + AdotP + Asqr) +
			0.333333 * Asqr + (1 + 1)
			-
			(sqrt(2*AdotP + 1) * ( -1 * AdotP/Asqr) -
			(1.0 / pow(Asqr, 3.0/2.0)) * 
				(AxA *(PxP.yzx + PxP*zxy) -2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
			log( sqrt(Asqr) + AdotP))
			;
	
	// reorder
	float result5_x1_x0 = AdotP +
			sqrt(2*AdotP + Asqr + 1) * ( -1 * AdotP/Asqr - 1) 
			- sqrt(2*AdotP + 1) * ( -1 * AdotP/Asqr) 
			
			- (1.0 / pow(Asqr, 3.0/2.0)) * 
				(AxA *(PxP.yzx + PxP*zxy) -2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
				log( sqrt(Asqr) * sqrt(2*AdotP + Asqr + 1) + AdotP + Asqr) 
			+ (1.0 / pow(Asqr, 3.0/2.0)) * 
				(AxA *(PxP.yzx + PxP*zxy) -2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
				log( sqrt(Asqr) + AdotP)
			
			+ 0.333333 * Asqr + (1 + 1)
			;
	
	// try to extract parts
	float result6_x1_x0 = AdotP +
			- sqrt(2*AdotP + Asqr + 1) * (AdotP/Asqr + 1) 
			+ sqrt(2*AdotP + 1) * (AdotP/Asqr) 
			
			-1 * (1.0 / pow(Asqr, 3.0/2.0)) * 
				(AxA *(PxP.yzx + PxP*zxy) -2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
				log( sqrt(Asqr) * sqrt(2*AdotP + Asqr + 1) + AdotP + Asqr) 
			+ (1.0 / pow(Asqr, 3.0/2.0)) * 
				(AxA *(PxP.yzx + PxP*zxy) -2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
				log( sqrt(Asqr) + AdotP)
			
			+ 0.333333 * Asqr + 2
			;
		
	// try to extract parts
	float result7_x1_x0 = AdotP +
			- sqrt(2*AdotP + Asqr + 1) * (AdotP/Asqr + 1) 
			+ sqrt(2*AdotP + 1) * (AdotP/Asqr) 
			
			+ (1.0 / pow(Asqr, 3.0/2.0)) * (AxA *(PxP.yzx + PxP*zxy) -2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
				log( sqrt(Asqr) + AdotP)			
			+ (1.0 / pow(Asqr, 3.0/2.0)) * (AxA *(PxP.yzx + PxP*zxy) -2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
				(-1 * log( sqrt(Asqr) * sqrt(2*AdotP + Asqr + 1) + AdotP + Asqr) )

			+ 0.333333 * Asqr + 2
			;		
	// try to extract parts
	float result8_x1_x0 = AdotP +
			- sqrt(2*AdotP + Asqr + 1) * (AdotP/Asqr + 1) 
			+ sqrt(2*AdotP + 1) * (AdotP/Asqr) 
			
			+ (1.0 / pow(Asqr, 3.0/2.0)) * 
				(AxA *(PxP.yzx + PxP*zxy) - 2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
				(log(sqrt(Asqr) + AdotP) - log(sqrt(Asqr) * sqrt(2*AdotP + Asqr + 1) + AdotP + Asqr) ) 
			+ 0.333333 * Asqr + 2
			;	
			
	// merge log into division

	float result9_x1_x0 = AdotP +
			- sqrt(2*AdotP + Asqr + 1) * (AdotP/Asqr + 1) 
			+ sqrt(2*AdotP + 1) * (AdotP/Asqr) 
			
			+ (1.0 / pow(Asqr, 3.0/2.0)) * 
				(AxA *(PxP.yzx + PxP*zxy) - 2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
				(log((sqrt(Asqr) + AdotP) / sqrt(Asqr)* sqrt((2*AdotP + Asqr + 1)) + AdotP + Asqr) ) 
			+ 0.333333 * Asqr + 2
			;
	*/
	// futhrer group things
	#line 30500
	/*
	float Alen = sqrt(Asqr);
	float Asqrplus2AdotPplus1sqrt =  sqrt(2*AdotP + Asqr + 1);
	float result10_x1_x0 = AdotP +
			- Asqrplus2AdotPplus1sqrt * (AdotP/Asqr + 1) 
			+ sqrt(2*AdotP + 1) * (AdotP/Asqr) 
			
			+ (1.0 / pow(Asqr, 3.0/2.0)) * 
				(AxA *(PxP.yzx + PxP.zxy) - 2 * (A.zxy * A.xyz * P.xyz * P.zxy) ) *
				(log((Alen + AdotP) / Alen* Asqrplus2AdotPplus1sqrt + AdotP + Asqr) ) + 
			0.333333 * Asqr + 2			;
	return result10_x1_x0;
	*/
	return 0;

	
	
//https://www.integral-calculator.com/ 
//(1.0 -sqrt((P1+A1*x)^2 +(P2+A2*x)^2+(P3+A3*x)^2))^2
}

float integrateLightUnitSphere(vec3 A, vec3 P, float R, float x){ // inside unit-sphere space
	float AdotP = dot(A,P);
	float Psqr = dot(P,P);
	float Asqr = dot(A,A);
	vec3 AxA = A * A;
	vec3 PxP = P * P;
	float x2 = x*x;
	// Integrate[Power[\(40)1.0 - Sqrt[Power[\(40)P_1+A_1*x\(41),2]+Power[\(40)P_2\(41),2]+Power[\(40)P_3\(41),2]]\(41),2],x] 
	
	float Pyzsqr = dot(P.yz,P.yz);
	float AxtimexplusPx = (A.x * x + P.x);
	float disttocenter = sqrt(AxtimexplusPx * AxtimexplusPx + Pyzsqr);
	float disttostart = sqrt(Psqr);
	
	float indefinite_x = 1/A.x * (
		0.333333 * pow(A.x + P.x,3) 
		+ (Pyzsqr + 1)* AxtimexplusPx
		- disttocenter * AxtimexplusPx 
		- Pyzsqr * log(disttocenter  +  AxtimexplusPx ));
	
	
	float indefinite_x0 = 1/A.x * ( // for the x = case
		0.333333 * pow(A.x + P.x,3) 
		+ (Pyzsqr + 1)* P.x
		- disttostart * P.x 
		- Pyzsqr * log(disttostart +  P.x ));
		
	float xminusx0 = 1/A.x * (
		0.333333 * pow(A.x + P.x,3) 
		+ (Pyzsqr + 1)* AxtimexplusPx
		- disttocenter * AxtimexplusPx 
		- Pyzsqr * log(disttocenter  +  AxtimexplusPx ))
		
		- 1/A.x * ( // for the x = case
		0.333333 * pow(A.x + P.x,3) 
		+ (Pyzsqr + 1)* P.x
		- disttostart * P.x 
		- Pyzsqr * log(disttostart +  P.x ));
		
		
	return 0;
}


float scatterfalloff(float disttolight, float radius){
	float x = clamp(1.0 - disttolight/radius, 0.0, 1.0);
	return (-0.5*x*x+x)/(0.5*x*x-x+1);
}

float integratescatterocclusion(float depthratio){
	float x = depthratio;
	return clamp((x*x)/ (2*x*x -2*x +1.0), 0.0, 1.0);
}

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

//Integrate[Power[\(40)1.0 - Sqrt[Power[\(40)P_1+A_1*x\(41),2]+Power[\(40)P_2+A_2*x\(41),2]+Power[\(40)P_3+A_3*x\(41),2]]\(41),2],{x,0,1}]
	
	
//https://andrew-pham.blog/2019/10/03/volumetric-lighting/ ???


vec3 ScreenToWorld(vec2 screen_uv, float depth){ // returns world XYZ from screenUV and depth
	vec4 fragToScreen =  vec4( vec3(screen_uv * 2.0 - 1.0, depth),  1.0);
	fragToScreen = cameraViewProjInv * fragToScreen;
	return fragToScreen.xyz / fragToScreen.w;
}

vec3 WorldToScreen(vec3 worldCoords){ // returns screen UV and depth position
	vec4 screenPosition = cameraViewProj * vec4(worldCoords,1.0);
	return screenPosition.xyz / screenPosition.w;
}

#line 31000
void main(void)
{
	// corresponding screenspace pos:
	vec2 screenUV = gl_FragCoord.xy / viewGeometry.xy;
	
	
	float mapdepth = texture(mapDepths, screenUV).x;
	float modeldepth = texture(modelDepths, screenUV).x;
	vec4 normals = vec4(0, 1, 0, 0); // points up by default
	vec4 extratex = vec4(0);
	float ismodel = 0;
	
	if (modeldepth+mapdepth < 1.9999) { // this actually hit something, otherwise we hit nothing in both mapdepth and modeldepth
		if (modeldepth < mapdepth) { // We are processing a model fragment
			ismodel = 1;
			normals =  texture2D(modelNormals, screenUV) * 2.0 - 1.0;
			extratex = texture2D(modelExtra  , screenUV);
		}else{
			normals =  texture2D(mapNormals  , screenUV) * 2.0 - 1.0;
			extratex = texture2D(mapExtra    , screenUV);
		}
	}
	
	
	float worlddepth = min(mapdepth, modeldepth);
	
	//if (gl_FragCoord.z > worlddepth) discard;
	
	vec4 fragWorldPos =  vec4( vec3(screenUV.xy * 2.0 - 1.0, worlddepth),  1.0);
	fragWorldPos = cameraViewProjInv * fragWorldPos;
	fragWorldPos.xyz = fragWorldPos.xyz / fragWorldPos.w; // YAAAY this works!
	
	//if fragWorldPos
	
	vec3 camPos = cameraViewInv[3].xyz;
	
	vec3 viewDirection = normalize(camPos - fragWorldPos.xyz); // vector pointing in the direction of the eye ray
	
	float lightRadius = v_worldPosRad.w;
	float lightRadiusInv = 1.0 / lightRadius;
	vec3 lightDirection = vec3(0); // the normalized vector from the light source to the fragment
	vec3 lightToWorld = vec3(0); // The vector pointing from light source to fragment world pos
	vec3 lightPosition = vec3(0); // This is the position of the light illuminating the fragment
	vec3 lightEmitPosition = vec3(0); // == lightPosition, except for beams, where the lightEmitPosition for a ray is different than for a world fragment
	
	float raytolightdistance = 0;
	vec4 closestpoint_dist = vec4(0); // the point that is closest to the light source (xyz) and the distance to it (w)
	
	// Lighting components we wish to collect along the way:
	float attenuation = 0; // Just the distance from the light source (multiplied with falloff for cones
	float falloff = 1; // only cone light have this
	float selfglow = v_depths_center_map_model_min.w; // How much the emission point glows here
	float selfglowfalloff = 1; // only for cones
	float sourceVisible = 1; // if the world-pos of the source of this fragments scattering light is visible
		// Note that for cones and beams, this is calced in the vertex shader, for beams its done in the fragment shader
	float lensFlare = 0;
	
	float scatteringRayleigh = 0; // the integration of the light reflected into the eye from the eye ray through the volume
	
	float scatteringMie = 0; // the integration of the light reflected into the eye from the eye ray through a size-reduced volume
	float diffuse = 0; // The amount of diffuse reflection from the world-hitting fragment
	float specular = 0; // The amount of specular reflection from the world-hitting fragment
	float dtobeam = 0;
	
	vec4 rcd = vec4 (0.0);
	
	float rcdsqr = 1000000.0;
	
	fragColor.rgba = vec4(fract(fragWorldPos.xyz * 0.1),1.0);
	
	#line 32000
	if (pointbeamcone < 0.5){ //point
		lightPosition = v_worldPosRad.xyz;
		lightEmitPosition = lightPosition;
		
		lightToWorld = fragWorldPos.xyz - lightPosition;
		lightDirection = normalize(lightToWorld);
		attenuation = clamp( 1.0 - length (lightToWorld) * lightRadiusInv, 0,1);
		closestpoint_dist = closestlightlp_distance(camPos, viewDirection, lightPosition);
		
		
		sourceVisible = smoothstep(v_depths_center_map_model_min.w -0.01, v_depths_center_map_model_min.w ,worlddepth);
		lensFlare = step(v_depths_center_map_model_min.x, v_depths_center_map_model_min.w);// 0 for light behind geometry, 1 for light in front
		//selfbloom = step(v_depths_center_map_model_min.y, worlddepth);
		//sourceVisible = v_depths_center_map_model_min.x;
		// For scattering, take the 
		//scattering = pow(1.0 - closestpoint_dist.w / lightRadius, 2);
		
		scatteringRayleigh = scatterfalloff(closestpoint_dist.w, lightRadius);
		
		vec2 closeandfardistance = raySphereIntersect(camPos, -viewDirection,  lightPosition, lightRadius);
		float fragDistance = length(fragWorldPos.xyz - camPos);
		float depthratio = clamp(0.5 * (fragDistance - closeandfardistance.x) * lightRadiusInv, 0.0, 1.0);
		scatteringRayleigh = scatteringRayleigh * integratescatterocclusion(depthratio);
		
		scatteringMie = scatterfalloff( closestpoint_dist.w, lightRadius * MIERAYLEIGHRATIO);
		closeandfardistance = raySphereIntersect(camPos, -viewDirection,  lightPosition, lightRadius  * MIERAYLEIGHRATIO);
		fragDistance = length(fragWorldPos.xyz - camPos);
		depthratio = clamp(0.5 * (fragDistance - closeandfardistance.x) * (lightRadiusInv * (1.0 /MIERAYLEIGHRATIO)) , 0.0, 1.0);
		scatteringMie = scatteringMie * integratescatterocclusion(depthratio);
		
		
		
		lensFlare = lensFlare * clamp( lensFlare * LensFlareDistanceSqrt(closestpoint_dist.xyz, lightPosition,lightRadius) *(-10) +1, 0, 1);
		//if (fragDistance > closeandfardistance.y ) scattering = 1.0;
		//else scattering = 0.0;
		//scattering = smoothstep(closeandfardistance.x, closeandfardistance.y, -fragDistance*1);
		//scattering = fract((closeandfardistance.y - fragDistance)/100);
		//scattering = -closeandfardistance.y + closeandfardistance.x;
	#line 33000
	}else if (pointbeamcone > 1.5){ // cone
		lightPosition = v_worldPosRad.xyz;
		
		lightToWorld = fragWorldPos.xyz - lightPosition;
		lightDirection = normalize(lightToWorld);
		
		float lightandworldangle = dot(lightDirection, v_worldPosRad2.xyz);
		falloff = smoothstep(v_worldPosRad2.w, 1.0, lightandworldangle) ;

		attenuation = clamp( 1.0 - length (lightToWorld) / lightRadius, 0,1) * falloff;
		lightEmitPosition = lightPosition;
		closestpoint_dist = closestlightlp_distance(camPos, viewDirection, lightPosition);
		
		selfglowfalloff = dot(normalize(closestpoint_dist.xyz - lightPosition) , v_worldPosRad2.xyz) / v_worldPosRad2.w;
		
		float scatterangle = smoothstep(v_worldPosRad2.w, 1.0, - dot(normalize(lightPosition - closestpoint_dist.xyz),v_worldPosRad2.xyz)); 
		scatteringRayleigh = pow(1.0 - closestpoint_dist.w / lightRadius, 2) *scatterangle;

		
		sourceVisible = smoothstep(v_depths_center_map_model_min.z -0.001, v_depths_center_map_model_min.z ,worlddepth);
		
	#line 34000
	}else if (pointbeamcone < 1.5){ // beam 
		vec3 beamhalflength = v_worldPosRad2.xyz - v_worldPosRad.xyz; 
		vec3 beamstart = v_worldPosRad.xyz - beamhalflength;
		vec3 beamend = v_worldPosRad.xyz + beamhalflength;
		lightPosition = closestbeam(fragWorldPos.xyz, beamstart, beamend);
		
		lightToWorld = fragWorldPos.xyz - lightPosition;
		
		//lightPosition = closestlightlp_distance(camPos, viewDirection, beamstart, beamend);
		
		lightDirection = normalize(lightToWorld);
		attenuation = clamp( 1.0 - length (lightToWorld) / lightRadius, 0,1);
		
		dtobeam = capIntersect( camPos, viewDirection, beamstart, beamend, lightRadius);
		
		dtobeam = distancebetweenlines(beamstart, normalize(beamstart-beamend), camPos,viewDirection).x;
		//rcd = ray_to_capsule_distance(camPos, viewDirection, beamstart, beamend);
		closestpoint_dist = ray_to_capsule_distance_squared(camPos, viewDirection, beamstart, beamend);
		lightEmitPosition = closestpoint_dist.xyz;
		
		// how to tell, if lightEmitPosition is occluded?
		vec4 lightEmitScreenPosition = cameraViewProj * vec4(lightEmitPosition, 1.0);
		lightEmitScreenPosition.xyz /= lightEmitScreenPosition.w;
		
		if (lightEmitScreenPosition.z > worlddepth) sourceVisible = 0;
		
		sourceVisible = smoothstep(lightEmitScreenPosition.z - 0.1/lightEmitScreenPosition.w, lightEmitScreenPosition.z ,worlddepth);
		
		scatteringRayleigh = pow(max(0,1.0 - closestpoint_dist.w / lightRadius), 2);

	}
	#line 35000
	float relativedistancetolight = clamp(1.0 - 10* closestpoint_dist.w/lightRadius, 0.0, 1.0);
	
	diffuse = clamp(dot(-lightDirection, normals.xyz), 0.0, 1.0);
	
	
	
	vec3 reflection = reflect(lightDirection, normals.xyz);
	specular = dot(reflection, viewDirection);
	specular = pow(max(0.0, specular), 16.0) * 1.5;
	attenuation = attenuation;// * attenuation;
	
	fragColor.rgb = vec3(attenuation, diffuse, specular);
	
	fragColor.rgb = vec3(1.0) * attenuation * (diffuse + specular);
	

	if (v_depths_center_map_model_min.z < worlddepth){
		//sourceVisible = 0;
		//{fragColor.rgb += vec3(pow(relativedistancetolight,12) * falloff);
	}

	//fragColor.rgb = vec3(distancetolight);
	//fragColor.rgb = vec3(fract(lightPosition.xyz * 0.025));
	//fragColor.rgb = vec3(fract(dtobeam * 0.001));
	
	//calc from rcd
	float fuck = 0;
	float beamlength = 2*length(v_worldPosRad2.xyz - v_worldPosRad.xyz);
	

	fragColor.rgb = vec3(
			(diffuse ) * attenuation + lensFlare,
			//relativedistancetolight * relativedistancetolight * selfglowfalloff * sourceVisible + 
			scatteringMie + 
			(specular) * attenuation,
			 scatteringRayleigh
			);
	//fragColor.rgb = vec3(sourceVisible);
	//fragColor.rgb = vec3(dot(fragColor.rgb, vec3(1.0, 0.5, 0.5)));
	//fragColor.rgb += 0.5;
	//fragColor.rgb += clamp(0.25* vec3(pow(1.0-rcdsqr / (v_worldPosRad.w * v_worldPosRad.w),16)), 0.0, 1.0);
	//fragColor.rgb = vec3(rcdsqr / (v_worldPosRad.w * v_worldPosRad.w));
	//fragColor.rgb = vec3(abs(fract(v_depths_center_map_model_min.w*10)));
	//fragColor.rgb = vec3(pow(v_depths_center_map_model_min.z,8), pow(worlddepth, 8), 0);
	//fragColor.rgb = vec3((worlddepth - v_depths_center_map_model_min.z)* 100 + 0.5);
	//fragColor.rgb = (fract(lightEmitPosition*0.02));
}