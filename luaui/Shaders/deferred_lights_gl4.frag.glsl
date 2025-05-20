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
	flat vec4 v_modelfactor_specular_scattering_lensflare;
	vec4 v_depths_center_map_model_min;
	vec4 v_otherparams;
	vec4 v_lightcenter_gradient_height;
	vec4 v_position;
	vec4 v_noiseoffset;
	noperspective vec2 v_screenUV;
};

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D mapNormals;
uniform sampler2D modelNormals;
uniform sampler2D mapExtra;
uniform sampler2D modelExtra;
uniform sampler2D mapDiffuse;
uniform sampler2D modelDiffuse;
uniform sampler3D noise3DCube;
uniform sampler2D blueNoise;

uniform float pointbeamcone = 0;
uniform float nightFactor = 1.0;
// = 0; // 0 = point, 1 = beam, 2 = cone
uniform float radiusMultiplier = 1.0;
uniform float intensityMultiplier = 1.0;
uniform int screenSpaceShadows = 0;

out vec4 fragColor;

float smoothmin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5*(a-b)/k, 0.0, 1.0);
	return mix(a, b, h) - k*h*(1.0-h);
}

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

// Given a ray origin and a direction, returns the closes point on the ray in xyz and the squared distance in w
vec4 raypoint_sqrdistance(vec3 ro, vec3 rd, vec3 P){
	float t0 = dot(rd, P - ro) / dot(rd, rd);
	vec3 intersectPoint = ro + t0 * rd;
	return vec4(intersectPoint, dot(P - intersectPoint,P - intersectPoint));
}

// Given two rays, returns the minimum distance between them 
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

/// Given two rays, it returns the minimum squared distance between them
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


//Capsule / Line - exact

float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
  vec3 pa = p - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}

float distToCapsuleSqr( vec3 p, vec3 a, vec3 b, float r )
{
  vec3 pa = p - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  pa =  pa - ba*h;
  return dot(pa, pa) ;
}

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

// capsule defined by extremes pa and pb, and radious ra
// Note that only ONE of the two spherical caps is checked for intersections,
// which is a nice optimization
#line 30200
vec4 capIntersect2( in vec3 ro, in vec3 rd, in vec3 pa, in vec3 pb, in float ra )
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
	vec4 distances = vec4(-0.1);
    if( h >= 0.0 )
    {
		float sqrth = sqrt(h);
        float tclose = (-b-sqrth)/a;
        float tfar = (-b +sqrth)/a;
        float yclose = baoa + tclose * bard;
        float yfar = baoa + tfar * bard;
        // body
        if( yclose>0.0 && yclose<baba ) distances.x = tclose;
        if( yfar>0.0   && yfar<baba )   distances.y = tfar;
		
        // closecaps
		vec3 oc = (yclose <= 0.0) ? oa : ro - pb;
        b = dot(rd,oc);
        c = dot(oc,oc) - ra*ra;
        h = b*b - c;
        if( h>0.0 ) distances.x =  min(distances.x, -b - sqrt(h));
        else distances.w =  -b + sqrt(h);
		
		        // farcaps
		oc = (yfar > 0.0) ? oa : ro - pb;
        b = dot(rd,oc);
        c = dot(oc,oc) - ra*ra;
        h = b*b - c;
        if( h>0.0 ) distances.y =  min( -b - sqrt(h), distances.y);
        else distances.y =  max( -b + sqrt(h), distances.y);
		/*
		if (yclose <= 0.0) { //first cap
			vec3 oc = oa;
			b = dot(rd,oc);
			c = dot(oc,oc) - ra*ra;
			h = b*b - c;
			if( h>0.0 ) distances.z =  -b - sqrth;
			else distances.z =  -b + sqrth;
		}
		else
		{
			vec3 oc = ro - pb;
			b = dot(rd,oc);
			c = dot(oc,oc) - ra*ra;
			h = b*b - c;
			if( h>0.0 ) distances.w =  -b - sqrth;
			else distances.w =  -b + sqrth;
		}*/
    }
    return distances;
}

float dot2(vec3 a){ return dot(a,a);}
// cone defined by extremes pa and pb, and radious ra and rb
// Only one square root and one division is emplyed in the worst case. dot2(v) is dot(v,v)
vec4 coneIntersect( in vec3  ro, in vec3  rd, in vec3  pa, in vec3  pb, in float ra, in float rb )
{
    vec3  ba = pb - pa;
    vec3  oa = ro - pa;
    vec3  ob = ro - pb;
    float m0 = dot(ba,ba);
    float m1 = dot(oa,ba);
    float m2 = dot(rd,ba);
    float m3 = dot(rd,oa);
    float m5 = dot(oa,oa);
    float m9 = dot(ob,ba); 
    
    // caps
    if( m1<0.0 )
    {
        if( dot2(oa*m2-rd*m1)<(ra*ra*m2*m2) ) // delayed division
            return vec4(-m1/m2,-ba*inversesqrt(m0));
    }
    else if( m9>0.0 )
    {
    	float t = -m9/m2;                     // NOT delayed division
        if( dot2(ob+rd*t)<(rb*rb) )
            return vec4(t,ba*inversesqrt(m0));
    }
    
    // body
    float rr = ra - rb;
    float hy = m0 + rr*rr;
    float k2 = m0*m0    - m2*m2*hy;
    float k1 = m0*m0*m3 - m1*m2*hy + m0*ra*(rr*m2*1.0        );
    float k0 = m0*m0*m5 - m1*m1*hy + m0*ra*(rr*m1*2.0 - m0*ra);
    float h = k1*k1 - k2*k0;
    if( h<0.0 ) return vec4(-1.0); //no intersection
    float t = (-k1-sqrt(h))/k2;
    float y = m1 + t*m2;
    if( y<0.0 || y>m0 ) return vec4(-1.0); //no intersection
    return vec4(t, normalize(m0*(m0*(oa+t*rd)+rr*ba*ra)-ba*hy*y));
}

//https://www.symbolab.com/solver/definite-integral-calculator/%5Cint_%7B0%7D%5E%7B1%7D%5Cleft(1-%5Cfrac%7B%5Cleft(A_%7B2%7D%2BB_%7B2%7D%5Ccdot%20x%5Cright)%7D%7Bh%5E%7B2%7D%7D%20%5Cright)%5E%7B%20%7D%5Ccdot%5Cleft(1-%5Cfrac%7B%5Csqrt%7B%5Cleft(A_%7B1%7D%2BB_%7B1%7D%5Ccdot%20x%5Cright)%5E%7B2%7D%7D%7D%7B%5Cfrac%7B%5Cleft(A_%7B2%7D%2BB_%7B2%7D%5Ccdot%20x%5Cright)%5Ccdot%20r%7D%7Bh%7D%7D%5Cright)%20dx?or=input

// Defines the falloff function of scattered light one gets more distant from the light source
float scatterfalloff(float disttolight, float radius){
	float x = clamp(1.0 - disttolight/radius, 0.0, 1.0);
	return (-0.5*x*x+x)/(0.5*x*x-x+1);
}

// Integratates the scattering from closes to eye pos to most distant pos
float integratescatterocclusion(float depthratio){
	float x = clamp(depthratio, 0.0, 1.0);
	return (x*x)/ (2*x*x -2*x +1.0);
}

// cone defined by extremes pa and pb, and radious ra and rb
// Only one square root and one division is emplyed in the worst case. dot2(v) is dot(v,v)
// ra === 0
// returns the distance from the ray to the cone, and the normal vector of the cones surface at that point.
vec4 halfconeIntersect_IQ( in vec3  ro, in vec3  rd, in vec3  pa, in vec3  pb, in float ra, in float rb )
{
    vec3  ba = pb - pa;
    vec3  oa = ro - pa;
    vec3  ob = ro - pb;
    float m0 = dot(ba,ba);
    float m1 = dot(oa,ba);
    float m2 = dot(rd,ba);
    float m3 = dot(rd,oa);
    float m5 = dot(oa,oa);
    float m9 = dot(ob,ba); 
    
    // caps
    //if( m1<0.0 )
    //{
    //    if( dot2(oa*m2-rd*m1)< 0 ) // delayed division
    //        return vec4(-m1/m2,-ba*inversesqrt(m0));
    //}
    //else 
	if( m9>0.0 )
    {
    	float t = -m9/m2;                     // NOT delayed division
        if( dot2(ob+rd*t)<(rb*rb) )
            return vec4(t,ba*inversesqrt(m0));
    }
    
    // body
    float rr = - rb;
    float hy = m0 + rr*rr;
    float k2 = m0*m0    - m2*m2*hy;
    float k1 = m0*m0*m3 - m1*m2*hy ;
    float k0 = m0*m0*m5 - m1*m1*hy ;
    float h = k1*k1 - k2*k0;
    if( h<0.0 ) return vec4(-1.0); //no intersection
    float t = (-k1-sqrt(h))/k2;
    float y = m1 + t*m2;
    if( y<0.0 || y>m0 ) return vec4(-1.0); //no intersection
    return vec4(t, normalize(m0*(m0*(oa+t*rd))-ba*hy*y));
}

// Intersects a cone with a ray, with an optional occluding fragment distance
// Returns in xy the close and far distance cone intersection distances
// Note that the close one will be negative if the if the ray origin is inside the cone
// in z returns Rayleigh scattered light amount 
// in w returns Mie scattered light amount

#line 30400
vec4 halfconeIntersectScatter( in vec3  rayOrigin, in vec3 rayDirection, in vec3 coneTip, in vec3 coneDirection, in float coneHeight, in float bottomRadius, in float fragmentdistance)
{
	vec3  coneFlatEnd = coneTip + coneDirection * coneHeight;
	vec3  TipToEnd = coneFlatEnd - coneTip;
	vec3  TipToEye = rayOrigin - coneTip;
	vec3  EndToEye = rayOrigin - coneFlatEnd;
	float ConeHeightSqr = dot(TipToEnd, TipToEnd); 
	float EyeDotEnd = dot(TipToEye, TipToEnd);
	float RayDotEnd = dot(rayDirection, TipToEnd);
	float RayDotEye = dot(rayDirection, TipToEye);
	float TipToEyeSqr = dot(TipToEye, TipToEye);
	float TipDotEnd = dot(EndToEye, TipToEnd); 
	vec4 coneflatdistances = vec4(-1.0);

	// Bottom Cap collision, note that we still need to check this if we want the exit point too!
	// a ray can only collide with the end once!
	float distToFlat = - TipDotEnd / RayDotEnd;                     // NOT delayed division
	if( dot2(EndToEye+rayDirection*distToFlat)<=(bottomRadius*bottomRadius) )
		coneflatdistances.zw = vec2(distToFlat);
		// vec3 normal = TipToEnd*inversesqrt(ConeHeightSqr)
	
	// Test Cone Body intersections
	float CapeLengthSqr = ConeHeightSqr + bottomRadius * bottomRadius;
	float k2 = ConeHeightSqr * ConeHeightSqr - RayDotEnd * RayDotEnd * CapeLengthSqr;
	float k1 = ConeHeightSqr * ConeHeightSqr * RayDotEye - EyeDotEnd * RayDotEnd * CapeLengthSqr ;
	float k0 = ConeHeightSqr*ConeHeightSqr*TipToEyeSqr - EyeDotEnd * EyeDotEnd * CapeLengthSqr ;
	float h = k1*k1 - k2*k0;
	if( h<0.0 ) return vec4(-1.0, -1.0, 0.0, 0.0); //no intersection as we are _above_ the cone tip
	float sqrth = sqrt(max(0,h));
	float CloseDistToCone = (-k1-sqrth)/k2;
	float FarDistToCone = (-k1+sqrth)/k2;
	float CloseY = EyeDotEnd + CloseDistToCone * RayDotEnd;
	float FarY = EyeDotEnd + FarDistToCone * RayDotEnd;
	
	// if we are within the cone from the front
	if( CloseY >=0.0 && CloseY <= ConeHeightSqr ) coneflatdistances.x = CloseDistToCone;
	else {
		coneflatdistances.x = max(coneflatdistances.x,coneflatdistances.z);//no intersection, as we are below the bottom of the cone
	}
	// if we are within the cone from the back
	if( FarY >=0.0 && FarY <= ConeHeightSqr ) coneflatdistances.y = FarDistToCone; //no intersection, as we are below the bottom of the cone
	else {
		coneflatdistances.y = max(coneflatdistances.y,coneflatdistances.z);
	}
	 // vec3 normal =normalize(ConeHeightSqr*(ConeHeightSqr*(TipToEye+CloseDistToCone*rayDirection))-TipToEnd*CapeLengthSqr*y)
	// Bail early if we are not on the cone
	if (abs(coneflatdistances.y - coneflatdistances.x) < 0.1) return vec4(-1, -1, 0, 0);
	 
	// try to get some sort of falloff factor
	// calc angle between entry and exit
	vec3 EntryPoint = rayDirection * coneflatdistances.x + rayOrigin;
	vec3 ExitPoint =  rayDirection * coneflatdistances.y + rayOrigin;
	
	vec3 stepVec = rayDirection * ( coneflatdistances.y  - coneflatdistances.x) / RAYMARCHSTEPS;
	float stepVecSqr = dot(stepVec, stepVec);
	
	float cosTheta = sqrt(ConeHeightSqr / CapeLengthSqr);
	float oneminuscosThetainv = 1.0 / (1.0 - cosTheta);
	float ConeHeightSqrInv = 1.0 / ConeHeightSqr;
	float rayleighScatterSum = 0;
	float miescattersum = 0;

	for (int i = 1; i < RAYMARCHSTEPS; i++){
		// step the ray forward 
		vec3 marchPos = stepVec * i + EntryPoint;

		// Sample 3D noise if needed (noise should be 0.5 centered)
		#if (USE3DNOISE == 1 && RAYMARCHSTEPS >= 4)
			float noise = textureLod(noise3DCube, fract(marchPos * 0.005 + 0 / RAYMARCHSTEPS + v_noiseoffset.xyz), 0.0	).r * 2.0 ;
		#else
			float noise = 1.0;
		#endif
		
		// Calculate the distatten (which is squared)
		float distatten = clamp((1.0 - dot(marchPos - coneTip, marchPos - coneTip) * ConeHeightSqrInv), 0.0, 1.0);
		
		vec3 tiptomarchnorm = normalize(marchPos - coneTip);
		float falloffatten = clamp(1.0 - (1.0-dot(coneDirection, tiptomarchnorm))* oneminuscosThetainv, 0.0,1.0);
		
		float rayleighhere = distatten*falloffatten * noise;
		rayleighScatterSum += rayleighhere;
		// as mie mainly scatters forward, we will need to dot raydirection with lightdirection
		float miefactor = clamp(dot(-tiptomarchnorm, rayDirection) * 10.0 -9 , 0.0,1.0);
		//rayleighScatterSum += miefactor * falloffatten;
		miescattersum += rayleighhere * miefactor ;
	}
	
	// Simplest occlusion calculation just integrates scatter in between fragment distance and eye distance
	// cone close distance is negative if rayorigin is inside it
	float tofrag = integratescatterocclusion((fragmentdistance - coneflatdistances.x ) / (coneflatdistances.y - coneflatdistances.x));
	
	float fromeye = integratescatterocclusion( ( -coneflatdistances.x ) / (coneflatdistances.y - coneflatdistances.x));
	
	
	rayleighScatterSum = (tofrag - fromeye) * rayleighScatterSum / (RAYMARCHSTEPS - 1);
	miescattersum = (tofrag - fromeye) * miescattersum / (RAYMARCHSTEPS - 1);

	return vec4(coneflatdistances.x, coneflatdistances.y, rayleighScatterSum, miescattersum);
	
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
// This is the fast approx scattering useing a mierayleighratio, where 1.0 = Rayleigh, ~0.1 = Mie
// TODO: handle the case where viewpos is inside the volume!
float SlowSphereRayMarchedScattering(vec3 campos, vec3 viewdirection, vec3 lightposition, float lightradius, float fragmentdistance, float lightdistance, float mierayleighratio){
	vec2 closeandfardistance = raySphereIntersect(campos, -viewdirection,  lightposition, lightradius * mierayleighratio);
	
	float noise = 1.0;
	#if (USE3DNOISE == 1 && RAYMARCHSTEPS >= 4)
		vec3 EntryPoint = (-viewdirection) * closeandfardistance.x + campos;
		//vec3 ExitPoint =  (viewdirection) * closeandfardistance.y + campos;
		vec3 stepVec =  (-viewdirection) * ( closeandfardistance.y  -  closeandfardistance.x) / RAYMARCHSTEPS;
		for (int i = 1; i < RAYMARCHSTEPS; i++){
			vec3 marchPos = stepVec * i + EntryPoint;
			noise += textureLod(noise3DCube, fract(marchPos * 0.005 + i / RAYMARCHSTEPS + v_noiseoffset.xyz), 0.0).r * 2.0 ;
		}
		noise = noise / (RAYMARCHSTEPS -1);
	#endif
	
	float depthratio = clamp(0.5 * (fragmentdistance - closeandfardistance.x) / (lightradius * mierayleighratio), 0.0, 1.0);
	float tofrag = integratescatterocclusion(depthratio);
	float fromeye = integratescatterocclusion( ( -closeandfardistance.x ) / (closeandfardistance.y - closeandfardistance.x));
	return scatterfalloff(lightdistance, lightradius * mierayleighratio) * (tofrag - fromeye) * noise;
}

float FastApproximateScattering(vec3 campos, vec3 viewdirection, vec3 lightposition, float lightradius, float fragmentdistance, float lightdistance, float mierayleighratio){
	vec2 closeandfardistance = raySphereIntersect(campos, -viewdirection,  lightposition, lightradius * mierayleighratio);
	float depthratio = clamp(0.5 * (fragmentdistance - closeandfardistance.x) / (lightradius * mierayleighratio), 0.0, 1.0);
	float tofrag = integratescatterocclusion(depthratio);
	float fromeye = integratescatterocclusion( ( -closeandfardistance.x ) / (closeandfardistance.y - closeandfardistance.x));
	return scatterfalloff(lightdistance, lightradius * mierayleighratio) * (tofrag - fromeye);
}


// UNTESTED
vec3 ScreenToWorld(vec2 screen_uv, float depth){ // returns world XYZ from v_screenUV and depth
	vec4 fragToScreen =  vec4( vec3(screen_uv * 2.0 - 1.0, depth),  1.0);
	fragToScreen = cameraViewProjInv * fragToScreen;
	return fragToScreen.xyz / fragToScreen.w;
}

// UNTESTED!
vec3 WorldToScreen(vec3 worldCoords){ // returns screen UV and depth position
	vec4 screenPosition = cameraViewProj * vec4(worldCoords,1.0);
	return screenPosition.xyz / screenPosition.w;
}

// Additional notes and reading:
//https://andrew-pham.blog/2019/10/03/volumetric-lighting/ ???

#ifdef SCREENSPACESHADOWS
	// See Shader Amortization using Pixel Quad Message Passing
	vec2 quadVector = vec2(0); // REQUIRED, contains the [-1,1] mappings
	// one-hot encoding of thread ID
	vec4 threadMask = vec4(0); // contains the thread ID in one-hot
	#define selfWeightFactor 0.07
	vec4 selfWeights = vec4(0.25) + vec4(selfWeightFactor, selfWeightFactor/ -3.0, selfWeightFactor/ -3.0, selfWeightFactor/-3.0);

	vec4 quadGetThreadMask(vec2 qv){ 
		vec4 threadMask =  step(vec4(qv.xy,0,0),vec4( 0,0,qv.xy));
		return threadMask.xzxz * threadMask.yyww;
	}

	vec4 get_quad_vector_naive(vec4 output_pixel_num_wrt_uvxy)
	{
		//  Requires:   Two measures of the current fragment's output pixel number
		//              in the range ([0, IN.output_size.x), [0, IN.output_size.y)):
		//              1.) output_pixel_num_wrt_uvxy.xy increase with uv coords.
		//              2.) output_pixel_num_wrt_uvxy.zw increase with screen xy.
		//  Returns:    Two measures of the fragment's position in its 2x2 quad:
		//              1.) The .xy components are its 2x2 placement with respect to
		//                  uv direction (the origin (0, 0) is at the top-left):
		//                  top-left     = (-1.0, -1.0) top-right    = ( 1.0, -1.0)
		//                  bottom-left  = (-1.0,  1.0) bottom-right = ( 1.0,  1.0)
		//                  You need this to arrange/weight shared texture samples.
		//              2.) The .zw components are its 2x2 placement with respect to
		//                  screen xy direction (IN.position); the origin varies.
		//                  quad_gather needs this measure to work correctly.
		//              Note: quad_vector.zw = quad_vector.xy * float2(
		//                      ddx(output_pixel_num_wrt_uvxy.x),
		//                      ddy(output_pixel_num_wrt_uvxy.y));
		//  Caveats:    This function assumes the GPU driver always starts 2x2 pixel
		//              quads at even pixel numbers.  This assumption can be wrong
		//              for odd output resolutions (nondeterministically so).
		vec4 pixel_odd = fract(output_pixel_num_wrt_uvxy * 0.5) * 2.0;
		vec4 quad_vector = pixel_odd * 2.0 - vec4(1.0);
		return quad_vector;
	}

	vec4 get_quad_vector(vec4 output_pixel_num_wrt_uvxy)
	{
		//  Requires:   Same as get_quad_vector_naive() (see that first).
		//  Returns:    Same as get_quad_vector_naive() (see that first), but it's
		//              correct even if the 2x2 pixel quad starts at an odd pixel,
		//              which can occur at odd resolutions.
		vec4 quad_vector_guess =
			get_quad_vector_naive(output_pixel_num_wrt_uvxy);
		//  If quad_vector_guess.zw doesn't increase with screen xy, we know
		//  the 2x2 pixel quad starts at an odd pixel:
		vec2 odd_start_mirror = 0.5 * vec2(dFdx(quad_vector_guess.z),
													dFdy(quad_vector_guess.w));
		return quad_vector_guess * odd_start_mirror.xyxy;
	}

	// [-1,1] quad vector as per get_quad_vector_naive
	vec2 quadGetQuadVector(vec2 screenCoords){
		vec2 quadVector =  fract(floor(screenCoords) * 0.5) * 4.0 - 1.0;
		vec2 odd_start_mirror = 0.5 * vec2(dFdx(quadVector.x), dFdy(quadVector.y));
		quadVector = quadVector * odd_start_mirror;
		return sign(quadVector);
	}

	vec4 quadGather(float inputthis){
		float inputadjx = inputthis - dFdx(inputthis) * quadVector.x;
		float inputadjy = inputthis - dFdy(inputthis) * quadVector.y;
		float inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
		return vec4(inputthis, inputadjx, inputadjy, inputdiag);
	}

	float rand(vec2 co){
		return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
	}

#endif

#line 31000
void main(void)
{
	fragColor.rgba = vec4(fract(gl_FragCoord.zzz * 1.0),1.0);
	//return;
	
	float mapdepth = texture(mapDepths, v_screenUV).x;
	float modeldepth = texture(modelDepths, v_screenUV).x;
	float worlddepth = min(mapdepth, modeldepth);
	vec4 normals = vec4(0, 1, 0, 0); // points up by default
	vec4 extratex = vec4(0);
	vec4 targetcolor = vec4(0); // target color of the surface
	float ismodel = 0;
	
	// Only query the textures if the backface of the volume is further than the world fragment
	if (gl_FragCoord.z > worlddepth) {
		if (modeldepth < mapdepth) { // We are processing a model fragment
			ismodel = 1;
			normals =  texture(modelNormals, v_screenUV) * 2.0 - 1.0;
			extratex = texture(modelExtra  , v_screenUV);
			targetcolor = texture(modelDiffuse  , v_screenUV);
			
		}else{
			normals =  texture(mapNormals  , v_screenUV) * 2.0 - 1.0;
			extratex = texture(mapExtra    , v_screenUV);
			targetcolor = texture(mapDiffuse    , v_screenUV) * nightFactor;
		}
	}
	normals.xyz = normalize(normals.xyz);
	
	
	vec4 fragWorldPos =  vec4( vec3(v_screenUV.xy * 2.0 - 1.0, worlddepth),  1.0);
	fragWorldPos = cameraViewProjInv * fragWorldPos;
	fragWorldPos.xyz = fragWorldPos.xyz / fragWorldPos.w; // YAAAY this works!
	
	vec3 camPos = cameraViewInv[3].xyz;
	vec3 camForward;
	float fragDistance = length(camPos - fragWorldPos.xyz);
	vec3 viewDirection = (camPos - fragWorldPos.xyz) / fragDistance; // vector pointing in the direction of the eye ray
	
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
	
	float shadowedness = 0; // how much the light source is screen-space shadowed
	
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
		
		// example of exponential attenuation instead of clamped,
		//Use a smoother distance-falloff formula such as an exponential or inverse-square:
		//float dist = length(lightToWorld);
		//attenuation = exp(-dist * 0.5);
		
		closestpoint_dist = closestlightlp_distance(camPos, viewDirection, lightPosition);
		
		// Both scattering components
		scatteringRayleigh = SlowSphereRayMarchedScattering(camPos, viewDirection, lightPosition, lightRadius, fragDistance, closestpoint_dist.w, 1.0 );
		
		scatteringMie = FastApproximateScattering(camPos, viewDirection, lightPosition, lightRadius, fragDistance, closestpoint_dist.w, MIERAYLEIGHRATIO);
		
		lensFlare = step(v_depths_center_map_model_min.x, v_depths_center_map_model_min.w);
		lensFlare = lensFlare * clamp( lensFlare * LensFlareDistanceSqrt(closestpoint_dist.xyz, lightPosition,lightRadius) *(-10/(0.01+v_modelfactor_specular_scattering_lensflare.w)) + 1.0, 0, 1);

	#line 33000
	}else if (pointbeamcone > 1.5){ // cone
		lightPosition = v_worldPosRad.xyz;
		
		lightToWorld = fragWorldPos.xyz - lightPosition;
		lightDirection = normalize(lightToWorld);
		vec3 coneDirection = v_worldPosRad2.xyz;
		float lightCosTheta = v_worldPosRad2.w; // The cos of the half angle of the spot cone light
		float lightSinTheta = sin(acos(v_worldPosRad2.w)); // The cos of the half angle of the spot cone light
		
		float lightandworldangle = dot(lightDirection, coneDirection);
		//falloff = smoothstep(lightCosTheta, 1.0, lightandworldangle) ; // this is softer, but attenuates too much
		falloff = clamp(1.0 - (1.0-lightandworldangle)/ (1.0 - lightCosTheta), 0.0,1.0);

		attenuation = clamp( 1.0 - length (lightToWorld) / lightRadius, 0,1) * falloff;
		
		lightEmitPosition = lightPosition;
		closestpoint_dist = closestlightlp_distance(camPos, viewDirection, lightPosition);
		
		vec4 rayconedist = ray_to_capsule_distance_squared(camPos, viewDirection, lightPosition + coneDirection * lightRadius,lightPosition); // this now contains the point on ConeDirection 
		
		float localradius = max(0, lightSinTheta * length(rayconedist.xyz - lightPosition.xyz));
		//coneIntersect( in vec3  ro, in vec3  rd, in vec3  pa, in vec3  pb, in float ra, in float rb )
		vec4 iCone = halfconeIntersectScatter(camPos , -viewDirection, lightPosition, coneDirection , lightRadius,  lightRadius * lightSinTheta, fragDistance);
		
		scatteringRayleigh = iCone.z * 0.33;
		scatteringMie = iCone.w;

		lensFlare = step(v_depths_center_map_model_min.x, v_depths_center_map_model_min.w);
		lensFlare = lensFlare * clamp( lensFlare * LensFlareDistanceSqrt(closestpoint_dist.xyz, lightPosition,lightRadius) *(-15 / (0.01 +v_modelfactor_specular_scattering_lensflare.w)) +1, 0, 1);
		
		float lightandcameraangle = dot(coneDirection, viewDirection) + 1.0;
		//lensFlare *= smoothstep(lightCosTheta, 1.0, lightandcameraangle);
		lensFlare *= lightandcameraangle;
		//lensFlare = fract(localradius *0.02);
		//sourceVisible = smoothstep(v_depths_center_map_model_min.z -0.001, v_depths_center_map_model_min.z ,worlddepth);
		
	#line 34000
	}else if (pointbeamcone < 1.5){ // beam 
		vec3 beamhalflength = v_worldPosRad2.xyz - v_worldPosRad.xyz; 
		vec3 beamstart = v_worldPosRad.xyz - beamhalflength;
		vec3 beamend = v_worldPosRad.xyz + beamhalflength;
		lightPosition = closestbeam(fragWorldPos.xyz, beamstart, beamend);
		
		lightToWorld = fragWorldPos.xyz - lightPosition;
		
		lightDirection = normalize(lightToWorld);
		attenuation = clamp( 1.0 - length (lightToWorld) *lightRadiusInv, 0,1);
		
		dtobeam = capIntersect( camPos, viewDirection, beamstart, beamend, lightRadius);
		float dtobeam2 = capIntersect( camPos, -viewDirection, beamstart, beamend, lightRadius);
		vec4 alldist = capIntersect2( camPos, viewDirection, beamstart, beamend, lightRadius);
		
		closestpoint_dist = ray_to_capsule_distance_squared(camPos, viewDirection, beamstart, beamend);
		lightEmitPosition = closestpoint_dist.xyz;
		
		// how to tell, if lightEmitPosition is occluded?
		vec4 lightEmitScreenPosition = cameraViewProj * vec4(lightEmitPosition, 1.0);
		lightEmitScreenPosition.xyz /= lightEmitScreenPosition.w;
		
		if (lightEmitScreenPosition.z > worlddepth) sourceVisible = 0;
		
		sourceVisible = smoothstep(lightEmitScreenPosition.z - 0.1/lightEmitScreenPosition.w, lightEmitScreenPosition.z ,worlddepth);
		
		scatteringRayleigh = pow(max(0,1.0 - closestpoint_dist.w / lightRadius), 2);
		
		scatteringRayleigh = 0.0;
		scatteringMie = 0.0;
		lensFlare = 0.0;
		
		vec4 minmaxdist = alldist;
		float closedist =  capIntersect( camPos, -viewDirection, beamstart, beamend, lightRadius);
		float fardist = - capIntersect( camPos, viewDirection, beamstart, beamend, lightRadius);
		
		fragColor.rgb = vec3((vec3(fardist - closedist) * 0.001));
		
		vec3 EntryPoint = (-viewDirection) * closedist + camPos;
		vec3 ExitPoint =  (-viewDirection) * fardist + camPos;
		
		vec3 stepVec = - viewDirection * ( fardist  -  closedist) / RAYMARCHSTEPS;
		
		float rayleighScatterSum = 0;
		float miescattersum = 0;

		for (int i = 1; i < RAYMARCHSTEPS; i++){
			// step the ray forward 
			vec3 marchPos = stepVec * i + EntryPoint;

			// Sample 3D noise if needed (noise should be 0.5 centered)
			#if (USE3DNOISE == 1 && RAYMARCHSTEPS >= 4)
				float noise = textureLod(noise3DCube, fract(marchPos * 0.005 + i / RAYMARCHSTEPS + v_noiseoffset.xyz), 0.0).r * 2.0 ;
			#else
				float noise = 1.0;
			#endif
			
			float relativeclosenesstobeam = clamp(distToCapsuleSqr(marchPos, beamstart, beamend, lightRadius) * lightRadiusInv * lightRadiusInv, 0.0, 1.0) ;
			
			rayleighScatterSum +=  (1.0 - relativeclosenesstobeam) * noise;
			
			miescattersum += (max(0, 0.1 - relativeclosenesstobeam) * noise  * 10.0);
		}
		/*
		// LIGHTNING TESTER
		// march the worley noise in 128 steps and add it in!
		rayleighScatterSum = 0;
		miescattersum = 0;
		for (int i = 1; i < 128; i++){
			vec3 marchPos = stepVec * i + EntryPoint;

			float noise = textureLod(noise3DCube, fract(marchPos * 0.02 + i / RAYMARCHSTEPS + v_noiseoffset.xyz - vec3(0,timeInfo.x * 0.01,0)), 0.0).r * 2.0 ; 
			
			noise = 1000 * clamp(0.1 - abs(noise-1.0), 0, 1);
			
			float relativeclosenesstobeam = clamp(distToCapsuleSqr(marchPos, beamstart, beamend, lightRadius) * lightRadiusInv * lightRadiusInv, 0.0, 1.0) ;
			
			rayleighScatterSum +=  (1.0 - relativeclosenesstobeam) * noise;
			
			miescattersum += (max(0, 0.1 - relativeclosenesstobeam) * noise  * 10.0);
		
		}
		*/
		
		// Simplest occlusion calculation just integrates scatter in between fragment distance and eye distance
		// cone close distance is negative if rayorigin is inside it
		float tofrag = integratescatterocclusion((fragDistance - closedist ) / (fardist - closedist));
		
		float fromeye = integratescatterocclusion( ( -closedist ) / (fardist - closedist));
		
		rayleighScatterSum = (tofrag - fromeye) * rayleighScatterSum / (RAYMARCHSTEPS - 1);
		miescattersum = (tofrag - fromeye) * miescattersum / (RAYMARCHSTEPS - 1);

		scatteringMie = (miescattersum *miescattersum);
		scatteringRayleigh = rayleighScatterSum;

	}
	#line 35000
	float relativedistancetolight = clamp(1.0 - 10* closestpoint_dist.w/lightRadius, 0.0, 1.0);
	
	diffuse = clamp(dot(-lightDirection, normals.xyz), 0.0, 1.0);
	
	
	vec3 reflection = reflect(lightDirection, normals.xyz);
	specular = dot(reflection, viewDirection);
	specular = v_modelfactor_specular_scattering_lensflare.y * pow(max(0.0, specular), 8.0 * ( 1.0 + ismodel * v_modelfactor_specular_scattering_lensflare.x) ) * (1.0 + ismodel * v_modelfactor_specular_scattering_lensflare.x);
	attenuation = pow(attenuation, 1.0);

	//Give each light a unique blue noise sampling offset 
	vec2 blueNoiseUV = (gl_FragCoord.xy + float(v_noiseoffset.a)*7.0)/64.0;
	vec4 blueNoiseSample = textureLod(blueNoise, blueNoiseUV, 0.0);

	// Do screen-space sampling for shadowing because you are a silly boy:
	float unoccluded = 1.0;
	#ifdef SCREENSPACESHADOWS
		// But only for point and cone lights:
		// also assume that only models will shadow
		if ((v_otherparams.w) > 0.01 && (screenSpaceShadows > 0)) {
			const int sampleCount = screenSpaceShadows;
			// Initialize the quad vectors, so we can do Pixel Quad Message Passing
			quadVector = get_quad_vector(vec4(v_screenUV.xy, floor(gl_FragCoord.xy))).zw;
			threadMask = quadGetThreadMask(quadVector);

			// Split up a step evenly between the 4 threads in the quad
			vec4 threadOffset = vec4(0.125, 0.375, 0.625, 0.875);
			//vec4 threadOffset = vec4(0.5);

			// Generate a small, random offset to jiggle the samples a little bit, this provides a bit of noise to the shadowing
			//float randomOffset = rand(gl_FragCoord.xy * 0.013971639) * (- 0.25);
			float randomOffset = blueNoiseSample.a * (-0.25);
			// Collect occludedness in this variable
			float occludedness = 0.0;
			
			// Set up the raytracing variables
			vec3 rayStart = lightEmitPosition.xyz;
			vec3 rayEnd = fragWorldPos.xyz;
			vec3 rayStep = (rayEnd - rayStart) / (sampleCount);
			float rayStepLength = length(rayStep);
			float distanceToLight = 0; // squared distance to the light

			for (int i = 0; i < sampleCount; i++){
				float stepSize =  (float(i) + dot(threadMask, threadOffset) + randomOffset);
				distanceToLight = stepSize * rayStepLength;

				// Calculate the current ray position in both world and screenspace
				vec3 rayWorldPos = rayStart + rayStep * stepSize; 
				vec3 rayScreenPos = WorldToScreen(rayWorldPos);
				// Convert the NDC to UV space, and clamping is not needed because enabling it brings bad artifacts
				rayScreenPos.xy = rayScreenPos.xy * 0.5 + 0.5;
				
				float rayScreenDepthSample = texture(modelDepths, rayScreenPos.xy ).x;

				// Assume that any sample outside of the edges of the screen will not occlude
				if (any(lessThan(rayScreenPos.xy, vec2(0.001))) || any(greaterThan(rayScreenPos.xy, vec2(1.0-0.001)))) rayScreenDepthSample = 1.0;
				
				// Since modeldepth is zero where there is no model, we need to convert this to 1.0
				if (rayScreenDepthSample < 0.01) rayScreenDepthSample = 1.0;

				// we need to soften this, based on the squared world-space distance between the ray point and the sampled depth:
				
				// Recover the world position of the sample from the depth buffer, and calculate the distance to the ray
				vec3 sampleWorldPos = ScreenToWorld(rayScreenPos.xy, rayScreenDepthSample);
				float sampleDistance = length(rayWorldPos - sampleWorldPos);
				float sampleOcclusionStrength = 0.0;

				// Assume that a ray that hits exactly occludes 0.5
				if (rayScreenDepthSample < rayScreenPos.z) {
					// If the sample actually occludes, then softly occlude it based on the distance from the light
					if (sampleDistance > 48.0) // Very deep occluders dont occlude
						sampleOcclusionStrength = 1.0 -  clamp((sampleDistance - 48.0) / (rayStepLength * 0.05), 0.0, 1.0);
					else
						sampleOcclusionStrength = 0.5 + clamp(sampleDistance / (rayStepLength * 0.05), 0.0, 1.0) * 0.5;

				}else{
					// if the sample does not occlude, but is close to doing so, then softly occlude it based on the distance from the light	
					sampleOcclusionStrength = 0.5 - clamp(sampleDistance / (rayStepLength * 0.2), 0.0, 1.0) * 0.5;;
				}
			
				occludedness += sampleOcclusionStrength;
				
			}
			//printf(occludedness);

			float prob = 0.56;

			//vec4 weights = vec4(prob*prob, prob*(1.0-prob), (1.0-prob)*prob, (1.0-prob)*(1.0-prob));
			vec4 weights = vec4(prob, 1.0 - prob, 1.0 - prob, prob) * 0.5;
			vec4 gatheredunoccluded = quadGather(occludedness);
			float dotproduct = dot(gatheredunoccluded, vec4(4* weights)); // This will multiply by 4, effectively
			//dotproduct = occludedness;
			unoccluded = 1.0 - smoothstep(0.0, 0.25 * v_otherparams.w * float(screenSpaceShadows) , dotproduct);
			//unoccluded = 1.0;
			//printf(unoccluded);
		}	

		
	#endif
	fragColor.rgb = vec3(
			(diffuse) * attenuation + lensFlare,
			//relativedistancetolight * relativedistancetolight * selfglowfalloff * sourceVisible + 
			scatteringMie + 
			(specular) * attenuation,
			 scatteringRayleigh
			);
			
	fragColor.rgb = targetcolor.rgb;
	
	// light mixdown:
	targetcolor.rgb = max(vec3(0.2), targetcolor.rgb); // we shouldnt let the targetcolor be fully black, or else we will have a bad time blending onto it.
	
	float mintarg = 0.4;
	float targetbrightness =dot(targetcolor.rgb, vec3(0.375,0.5,0.125));
	
	targetcolor *= (1.0 -  step(mintarg,targetbrightness) * (targetbrightness -mintarg));
	// if brightness is > 0.5, start reducing it?
	
	
	// Sum up the additives of Rayleigh, Mie and LensFlare, colorize and alpha control them
	vec3 additivelights = ((scatteringRayleigh + scatteringMie) * v_modelfactor_specular_scattering_lensflare.z + lensFlare) * v_lightcolor.rgb * v_lightcolor.w * 0.4  ;

	// Sum up diffuse+specular and colorize the light
	vec3 blendedlights = (v_lightcolor.rgb * v_lightcolor.w) * (diffuse + specular) * unoccluded;

	// Modulate color with target color of the surface. 
	blendedlights = mix(blendedlights, blendedlights * targetcolor.rgb * 2.0, SURFACECOLORMODULATION);
	#if (VOIDWATER == 1) 
		if (fragWorldPos.y < 0) 
			blendedlights.rgb = vec3(0.0);
	#endif
	// Calculate attenuation and blend more lights onto models
	blendedlights *= attenuation * 2.0 * (1.0 + 2.0 * ismodel * v_modelfactor_specular_scattering_lensflare.x);
	
	// Estimate how 'lit' our target fragment is going to be, once we additively blend all light factors and the target surface color
	vec3 outlight_unclamped = targetcolor.rgb + blendedlights + additivelights;
	
	// The amount of light that will 'bleed', or overflow from that pixel is the sum of each channel that is over 1.0 according to our estimate
	float bleed = dot(max(vec3(0.0), outlight_unclamped - vec3(1.0)), vec3(1.0));
	
	// Square the bleed because why not
	bleed = bleed * bleed;
	
	// bleeding makes the other channels brighter when we 'overflow' with lighting
	fragColor.rgb = (blendedlights*0.9  + additivelights*0.5) + vec3(bleed)* BLEEDFACTOR; 
	
	fragColor.rgb *= intensityMultiplier;

	// Add a half a bit of blue noise to the color to prevent banding, especially with contrast adaptive sharpening:
	// Which should kinda be color dependent anyway, so lets find the max of all the color, and use that to ensure we get half a bit on the output:
	//v_lightcolor.rgb
	fragColor.rgb -=  (blueNoiseSample.rgb - 0.5) * (1.0 / 384.0);
	//fragColor.rgb *= v_lightcolor.a;
	//fragColor.rgb = vec3(bleed);
	//fragColor.rgb = vec3(targetcolor.rgb + blendedlights + additivelights);
	//fragColor.rgb = outlight_unclamped;
	//fragColor.rgb = vec3(scatteringRayleigh);
	//fragColor.rgb = vec3(dot(fragColor.rgb, vec3(1.0, 0.5, 0.5)));
	//fragColor.rgb += 0.5;
	//fragColor.rgb += clamp(0.25* vec3(pow(1.0-rcdsqr / (v_worldPosRad.w * v_worldPosRad.w),16)), 0.0, 1.0);
	//fragColor.rgb = vec3(rcdsqr / (v_worldPosRad.w * v_worldPosRad.w));
	//fragColor.rgb = vec3(abs(fract(v_depths_center_map_model_min.w*10)));
	//fragColor.rgb = vec3(pow(v_depths_center_map_model_min.z,8), pow(worlddepth, 8), 0);
	//fragColor.rgb = vec3((worlddepth - v_depths_center_map_model_min.z)* 100 + 0.5);
	//fragColor.rgb = (fract(lightEmitPosition*0.02));
	fragColor.a = 1.0;
	//fragColor.rgb = vec3(targetcolor);
	//fragColor.rgb = vec3(attenuation);
	//fragColor.rgb = fract(v_lightcenter_gradient_height.www*0.1);
	
}
