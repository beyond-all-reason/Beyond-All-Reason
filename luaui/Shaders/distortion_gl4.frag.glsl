#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000


in DataVS {
	flat vec4 v_worldPosRad; // center, radius
	flat vec4 v_worldPosRad2; // direction, theta
	flat vec4 v_baseparams; // lifeStrength, effectStrength, unused, unused
	flat vec4 v_universalParams; // noiseStrength, noiseScaleSpace, distanceFalloff, onlyModelMap
	flat vec4 v_lifeParams;  // spawnFrame, lifeTime, rampUp, decay
	flat vec4 v_effectParams; // effectparam1, effectparam2, windAffected, effectType
	#ifdef UNIFORMSBUFFERCOPY
		flat vec4 v_unibuffercopy;
	#endif
	noperspective vec2 v_screenUV; // i have no fucking memory as to why this is set as noperspective
};

#define LIFESTRENGTH v_baseparams.x
#define EFFECTSTRENGTH v_baseparams.y
#define STARTRADIUS	v_baseparams.z

#define NOISESTRENGTH v_universalParams.x
#define NOISESCALESPACE v_universalParams.y
#define DISTANCEFALLOFF v_universalParams.z
#define ONLYMODELMAP v_universalParams.w

#define SPAWNFRAME v_lifeParams.x
#define LIFETIME   v_lifeParams.y
#define RAMPUP     v_lifeParams.z
#define DECAY      v_lifeParams.w	

#define EFFECTPARAM1 v_effectParams.x
#define EFFECTPARAM2 v_effectParams.y
#define WINDAFFECTED v_effectParams.z
#define EFFECTTYPE   v_effectParams.w


uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler3D noise3DCube;

uniform float pointbeamcone = 0;

// = 0; // 0 = point, 1 = beam, 2 = cone
uniform float radiusMultiplier = 1.0;
uniform float intensityMultiplier = 1.0;

uniform vec2 windXZ = vec2(0.0, 0.0);

out vec4 fragColor;

// Kinda useful debug macro:
// RED is the fractional part of the input (clamped a little bit to ensure that [0-1] is clearly visible)
// GREEN is the square root of the floor of the input divided by 256
// Blue is for negative numbers
#define DEBUG(x) fragColor.rgba = vec4( fract(x*0.999 + 0.0001), sqrt(floor(x) / 256.0),(x < 0? 1 : 0),1.0); return;

// Shows the fract of 1/10th of the input 3d vector
#define DEBUGPOS(x) fragColor.rgba = vec4(fract(x * 0.1 + 0.0001),1.0); return;

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
vec4 closestdistortionlp_distance (vec3 ro, vec3 rd, vec3 P){
	float t0 = dot(rd, P - ro) / dot(rd, rd);
	vec3 intersectPoint = ro + t0 * rd;
	return vec4(intersectPoint, length(P - intersectPoint));
}

// Given two rays, returns the minimum distance between them 
//https://math.stackexchange.com/questions/2213165/find-shortest-distance-between-lines-in-3d
float distancebetweenlines(vec3 r1, vec3 e1, vec3 r2, vec3 e2){ // point1, dir1, point2, dir2
	//todo handle the case where e1 == e2
	vec3 n = cross(e1, e2); // n is the normal of the line connecting them
	float distance = dot ( n, r1-r2) / length(n);
	return distance;
}

// Given a ray origin and direction, and a line segment start and end point, which point on the ray is closest to the line segment?
vec3 ray_linesegment_closestpoint(vec3 rayOrigin, vec3 rayDirection, vec3 lineStart, vec3 lineEnd){

	vec3 lineDir = lineEnd - lineStart;
	vec3 rayToLineStart = lineStart - rayOrigin;
	vec3 rayToLineEnd = lineEnd - rayOrigin;

	float t1 = dot(rayToLineStart, rayDirection);
	float t2 = dot(rayToLineEnd, rayDirection);

	vec3 closestPointOnRayToLineStart = rayOrigin + t1 * rayDirection;
	vec3 closestPointOnRayToLineEnd = rayOrigin + t2 * rayDirection;

	float distToLineStart = length(closestPointOnRayToLineStart - lineStart);
	float distToLineEnd = length(closestPointOnRayToLineEnd - lineEnd);

	if (distToLineStart < distToLineEnd) {
		return closestPointOnRayToLineStart;
	} else {
		return closestPointOnRayToLineEnd;
	}
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
vec4 ray_to_capsule_distance_squared(vec3 rayOrigin, vec3 rayDirection, vec3 cap1, vec3 cap2){ // point1, dir1, beamStart, beamEnd
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


vec3 plane_point_dir_to_normal(vec3 point, vec3 planeDir, vec3 viewDirection){
	vec3 planeTangent = normalize(cross(planeDir, viewDirection)); // this is now tangential to the plane
	return normalize(cross(planeTangent, planeDir));
}

vec4 ray_to_plane_intersection_point( vec3 ro, vec3 rd, vec3 planeNormal, vec3 planePoint){
	float d = dot(planeNormal, planePoint);
	float t = (d - dot(planeNormal, ro)) / dot(planeNormal, rd);
	return vec4(ro + t * rd, t);
}
//http://www.realtimerendering.com/intersections.html


// The neat thing about this approach is that its quite generic in the sense of trivially being identical for spheres and beams
// Given a ray defined by rayOrigin and rayDirection, and a line segment defined with lineStart and lineEnd,
// Which point on the ray is closest to the line segment, and which point on the line segment is closest to the ray?
// Returns the closest point on the ray in XYZ and the distance to the line segment in W
// Also places the closest point on the line segment in the XYZ and the distance in W of out vec4 lineClosestPoint
// Write a GLSL function to solve the above problem by continuing the GLSL function definition below:
// THIS IS THE ONLY CORRECT IMLPEMENTATION!!!!!!!
vec4 ray_line_segment_closestpoint_on_ray_and_segment2(in vec3 rayOrigin, in vec3 rayDirection,
                                  in vec3 lineStart, in vec3 lineEnd,
                                  out vec4 closestPointOnSegment) {
    vec3 lineStartToEnd = lineEnd - lineStart;       // Direction vector of segment
    vec3 originToStart = lineStart - rayOrigin;

    float lineLenSQR = dot(lineStartToEnd, lineStartToEnd);                // Squared length of segment
    float dotRayLine = dot(rayDirection, lineStartToEnd);
    float d = dot(rayDirection, originToStart);
    float e = dot(lineStartToEnd, originToStart);

    float D = lineLenSQR - dotRayLine * dotRayLine;            // Denominator for s and t parameters
    float sN, sD = D;
    float tN, tD = D;

    // Check if lines are almost parallel
    if (abs(D) < 1e-8) {
        sN = 0.0;                       // Force s to zero
        sD = 1.0;                       // Prevent division by zero
        tN = d;
        tD = 1.0;
    } else {
        sN = (dotRayLine * d - e);
        tN = (lineLenSQR * d - dotRayLine * e);
    }

    // Compute the closest point parameter s on the segment [0,1]
    float s = sN / sD;
    s = clamp(s, 0.0, 1.0);
	float t;
    // Recompute t for the closest point on the ray
    if (abs(D) < 1e-8) {
        t = 0.0;
    } else {
        t = (dotRayLine * s + d) ;
    }

    // Ensure t is non-negative (since the ray extends from the origin in the positive direction)
    t = max(t, 0.0);

    // Compute the closest points on the segment and the ray
    closestPointOnSegment.xyz = lineStart + s * lineStartToEnd;
    vec3 closestPointOnRay = rayOrigin + t * rayDirection;

    // Compute the distance between the closest points
    float distance = length(closestPointOnSegment.xyz - closestPointOnRay);
	closestPointOnSegment.w = distance; 

    return vec4(closestPointOnRay, distance);
}

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


//Write me a glsl function that gives the distances to the intersection points between a ray, given a vec3 rayPos and vec3 rayDir and cone rounded on both ends given with vec3 pointA, vec3 pointB, float radiusA, float radiusB
vec2 intersectRoundedCone(vec3 rayPos, vec3 rayDir, vec3 pointA, vec3 pointB, float radiusA, float radiusB) {
    // Compute the cone axis and its length
    vec3 ba = pointB - pointA;
    float h = length(ba);
    vec3 ba_norm = ba / h;  // Normalize the cone axis

    // Compute rate of change of radius along the cone axis
    float m0 = (radiusB - radiusA) / h;
    float n0 = radiusA;  // Starting radius at pointA

    // Vector from pointA to ray origin
    vec3 oa = rayPos - pointA;

    // Projections onto the cone axis
    float dd = dot(rayDir, ba_norm);
    float oc = dot(oa, ba_norm);

    // Components perpendicular to the cone axis
    vec3 w = rayDir - ba_norm * dd;
    vec3 u = oa - ba_norm * oc;

    // Quadratic coefficients for intersection with the cone
    float m = m0 * dd;
    float n = m0 * oc + n0;

    float A = dot(w, w) - m * m;
    float B = 2.0 * (dot(w, u) - m * n);
    float C = dot(u, u) - n * n;

    // Solve the quadratic equation A*t^2 + B*t + C = 0
    float discriminant = B * B - 4.0 * A * C;
    vec2 tCone = vec2(-1.0);
    if (discriminant >= 0.0) {
        float sqrtDisc = sqrt(discriminant);
        float t0 = (-B - sqrtDisc) / (2.0 * A);
        float t1 = (-B + sqrtDisc) / (2.0 * A);

        // Check if intersection points are within the valid height of the cone
        float y0 = oc + t0 * dd;
        if (t0 >= 0.0 && y0 >= 0.0 && y0 <= h) {
            tCone[0] = t0;
        }

        float y1 = oc + t1 * dd;
        if (t1 >= 0.0 && y1 >= 0.0 && y1 <= h) {
            tCone[1] = t1;
        }
    }

    // Intersection with sphere at pointA
    float A_sphereA = dot(rayDir, rayDir);
    float B_sphereA = 2.0 * dot(oa, rayDir);
    float C_sphereA = dot(oa, oa) - radiusA * radiusA;

    discriminant = B_sphereA * B_sphereA - 4.0 * A_sphereA * C_sphereA;
    vec2 tSphereA = vec2(-1.0);
    if (discriminant >= 0.0) {
        float sqrtDisc = sqrt(discriminant);
        float t0 = (-B_sphereA - sqrtDisc) / (2.0 * A_sphereA);
        float t1 = (-B_sphereA + sqrtDisc) / (2.0 * A_sphereA);
        if (t0 >= 0.0) tSphereA[0] = t0;
        if (t1 >= 0.0) tSphereA[1] = t1;
    }

    // Intersection with sphere at pointB
    vec3 ob = rayPos - pointB;
    float A_sphereB = dot(rayDir, rayDir);
    float B_sphereB = 2.0 * dot(ob, rayDir);
    float C_sphereB = dot(ob, ob) - radiusB * radiusB;

    discriminant = B_sphereB * B_sphereB - 4.0 * A_sphereB * C_sphereB;
    vec2 tSphereB = vec2(-1.0);
    if (discriminant >= 0.0) {
        float sqrtDisc = sqrt(discriminant);
        float t0 = (-B_sphereB - sqrtDisc) / (2.0 * A_sphereB);
        float t1 = (-B_sphereB + sqrtDisc) / (2.0 * A_sphereB);
        if (t0 >= 0.0) tSphereB[0] = t0;
        if (t1 >= 0.0) tSphereB[1] = t1;
    }

    // Collect all valid intersection distances
    float tMin = 1e20;
    float tMax = -1.0;
    float tValues[6] = float[6](tCone[0], tCone[1], tSphereA[0], tSphereA[1], tSphereB[0], tSphereB[1]);

    for (int i = 0; i < 6; ++i) {
        float t = tValues[i];
        if (t >= 0.0) {
            tMin = min(tMin, t);
            tMax = max(tMax, t);
        }
    }

    if (tMin > tMax || tMin == 1e20) {
        // No valid intersection
        return vec2(-1.0);
    } else {
        return vec2(tMin, tMax);
    }
}

// https://iquilezles.org/articles/distfunctions
float dot2(in vec3 v ) { return dot(v,v); }
float sdRoundCone(vec3 p, vec3 a, vec3 b, float r1, float r2)
{
    // sampling independent computations (only depend on shape)
    vec3  ba = b - a;
    float l2 = dot(ba,ba);
    float rr = r1 - r2;
    float a2 = l2 - rr*rr;
    float il2 = 1.0/l2;
    
    // sampling dependant computations
    vec3 pa = p - a;
    float y = dot(pa,ba);
    float z = y - l2;
    float x2 = dot2( pa*l2 - ba*y );
    float y2 = y*y*l2;
    float z2 = z*z*l2;

    // single square root!
    float k = sign(rr)*rr*rr*x2;
    if( sign(z)*a2*z2 > k ) return  sqrt(x2 + z2)        *il2 - r2;
    if( sign(y)*a2*y2 < k ) return  sqrt(x2 + y2)        *il2 - r1;
                            return (sqrt(x2*a2*il2)+y*rr)*il2 - r1;
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

// shockwave UV Displacement
// Calculate how much the UV coordinates should be displaced at currentpos in world space of the screen copy texture to simulate a shockwave starting from position centerpos, with the camera looking at viewdirections. 
// The maximum radius of the shockwave is given in shockwaveRadius, and the timeFraction goes from 0 to 1 to simulate the shockwave expanding over time.
// Ensure that the UV displacement is correctly rotated given the angle between the viewDirection and the direction of the shockwave starting from centerpos

vec3 shockWaveDisplacement2(vec3 centerpos, vec3 currentpos, vec3 viewDirection, float shockwaveRadius, float timeFraction) {
	vec3 displacement = vec3(0.0);
	vec3 toCenter = currentpos - centerpos;
	float distance = length(toCenter);
	float normalizedDistance = distance / shockwaveRadius;

	if (normalizedDistance < 1.0) {
		float wave = sin(normalizedDistance * 3.14159 * 2.0 - timeFraction * 3.14159 * 2.0);
		float attenuation = 1.0 - normalizedDistance;
		displacement = viewDirection * wave * attenuation;
	}

	return displacement;
}

vec3 shockWaveDisplacement(vec3 centerpos, vec3 currentpos, vec3 viewDirection, float shockwaveRadius, float timeFraction) {
    // Calculate direction vector from center to current position
    vec3 dir = currentpos - centerpos;

    // Define the up vector (assuming Y-up coordinate system)
    vec3 up = vec3(0.0, 1.0, 0.0);

    // Calculate the camera's right and up vectors
    vec3 right = normalize(cross(viewDirection, up));
    vec3 cameraUp = normalize(cross(right, viewDirection));

    // Transform the direction vector into the camera's coordinate space
    vec3 dirInCameraSpace;
    dirInCameraSpace.x = dot(dir, right);
    dirInCameraSpace.y = dot(dir, cameraUp);
    dirInCameraSpace.z = dot(dir, -viewDirection);

    // Compute the 2D distance from the center in camera space
    float distance = length(dirInCameraSpace.xy);
    // Calculate the current radius of the shockwave
    float currentRadius = shockwaveRadius * timeFraction;
    // Compute the difference between the distance and the shockwave's current radius
    float diff = distance - currentRadius;

    // Define the width and amplitude of the shockwave effect
    float width = 100.1;    // Controls the width of the shockwave ring
    float amplitude = 0.1; // Maximum displacement amount

    // Calculate the displacement amount using a Gaussian function
    float displacementAmount = amplitude * exp(-diff * diff / (2.0 * width * width));

    // Normalize the direction in camera space
    vec2 dirNormalized = dirInCameraSpace.xy / distance;

    // Compute the displacement vector in 2D
    vec2 displacement = dirNormalized * displacementAmount;

    // Return the displacement vector with zero z-component
    return vec3(displacement * 10, 0.0);
}

// returns the Screen UV coordinates [0-1] and estimated depth of a given world position
vec3 worldToScreenUVZ(vec3 worldPosition){
	vec4 screenPos = cameraViewProj * vec4(worldPosition, 1.0);
	screenPos.xyz = screenPos.xyz / screenPos.w;
	screenPos.xyz = screenPos.xyz * 0.5 + 0.5;
	return screenPos.xyz;
}		

// Parabola (try it in graphtoy.com) A nice choice to remap the 0..1 interval into 0..1, such that the corners are mapped to 0 and the center to 1. You can then rise the parabolar to a power k to control its shape.
// https://iquilezles.org/articles/functions/
float parabola( float x, float k )
{
    return pow( 4.0*x*(1.0-x), k );
}

// Power Curve This is a generalization of the Parabola() above. It also maps the 0..1 interval into 0..1 by keeping the corners mapped to 0. But in this generalziation you can control the shape one either side of the curve, which comes handy when creating leaves, eyes, and many other interesting shapes.
// https://iquilezles.org/articles/functions/
// Play with it here: https://www.desmos.com/calculator/2gecekm83w
float pcurve( float x, float a, float b )
{
    float k = pow(a+b,a+b)/(pow(a,a)*pow(b,b));
    return k*pow(x,a)*pow(1.0-x,b);
}

// The precomputed scaling factor version
// Precompute K with the calculator here: https://www.desmos.com/calculator/2gecekm83w
float pcurve_k( float x, float a, float b, float k )
{
    return k*pow(x,a)*pow(1.0-x,b);
}

#line 31000
void main(void)
{
	//-------------------------- BEGIN SHARED SECTION ---------------------
	int effectType = int(round(EFFECTTYPE));
	
	// TODO: Get the view vector before fetching texels for speedups, we cant really bail on all that many fragments...
	float mapdepth = texture(mapDepths, v_screenUV).x;
	float modeldepth = texture(modelDepths, v_screenUV).x;

	float worlddepth = min(mapdepth, modeldepth);
	// TODO: isnt modeldepth 0 where there is no model fucking up everything later on?

	float ismodel = 0;
	// Only query the textures if the backface of the volume is further than the world fragment

	// We are processing a model fragment
	if (modeldepth < mapdepth) { 
		ismodel = 1;
	}
	
	vec4 fragWorldPos =  vec4( vec3(v_screenUV.xy * 2.0 - 1.0, worlddepth),  1.0);

	// reconstruct view position from depth and camera view proj inv:

	fragWorldPos = cameraViewProjInv * fragWorldPos;
	fragWorldPos.xyz = fragWorldPos.xyz / fragWorldPos.w; // YAAAY this works!
	//DEBUGPOS(fragWorldPos.xyz * 0.1); // Debug fragment world position
	
	vec3 camPos = cameraViewInv[3].xyz;
	vec3 cameraDir = -1.0 * vec3(cameraView[0].z,cameraView[1].z,cameraView[2].z);

	float fragDistance = length(camPos - fragWorldPos.xyz);
	vec3 viewDirection = (camPos - fragWorldPos.xyz) / fragDistance; // vector pointing in the direction of the eye ray

	vec3 viewDirFromDepth = viewDirection;
	
	vec4 viewDirWithoutDepth = vec4( vec3(v_screenUV.xy * 2.0 - 1.0, 0.0),  1.0);
	viewDirWithoutDepth = cameraViewProjInv * viewDirWithoutDepth;
	viewDirWithoutDepth.xyz = viewDirWithoutDepth.xyz/viewDirWithoutDepth.w;
	viewDirWithoutDepth.xyz = normalize(camPos - viewDirWithoutDepth.xyz);
	
	float distortionRadius = v_worldPosRad.w;
	float distortionRadiusInv = 1.0 / distortionRadius;

	vec3 distortionToWorld = vec3(0); // The vector pointing from distortion source to fragment world pos
	vec3 distortionPosition = vec3(0); // This is the position of the distortion illuminating the fragment
	vec4 distortionEmitPosition = vec4(0); // == distortionPosition, except for beams, where the distortionEmitPosition for a ray is different than for a world fragment
	vec3 EntryPoint = vec3(0); // Point of entry into the distortion volume from the camera
	vec3 ExitPoint =  vec3(0); // point of exit from the distortion volume away from the camera
	vec3 MidPoint = vec3(0); // midpoint between entry and exit points
	vec2 nearFarDistances = vec2(0); // the distances to the nearest and farthest points on the distortion source

	vec4 closestPointOnRay = vec4(0); // the point on the ray that is closest to the distortion source (xyz) and the distance to it (w)
	
	// In frames of course, plus timeOffset
	float currentTime = timeInfo.x + timeInfo.w;
	
	// Distortioning components we wish to collect along the way:
	float distance_attenuation = 0; // Just the distance from the distortion source (multiplied with falloff for cones

	float relativeDensity = 1.0;
	//fragColor.rgba = vec4(fract(fragWorldPos.xyz * 0.1),1.0); return; // Debug fragment world position

	#line 32000
	if (pointbeamcone < 0.5){ //point
		distortionPosition = v_worldPosRad.xyz;
		distortionEmitPosition.xyz = distortionPosition;
		
		distortionToWorld = fragWorldPos.xyz - distortionPosition;
		closestPointOnRay = closestdistortionlp_distance(camPos, viewDirection, distortionPosition);
		distortionEmitPosition.w = closestPointOnRay.w;

		// Need to invert view direction as we need ray pointing from camera to sphere
		nearFarDistances = raySphereIntersect(camPos, -1 * viewDirection, distortionPosition, distortionRadius);
		EntryPoint = camPos + nearFarDistances.x * -viewDirection;
		ExitPoint = camPos + nearFarDistances.y * -viewDirection;
		MidPoint = (EntryPoint + ExitPoint) * 0.5;
		distance_attenuation = clamp( 1.0 - length (distortionPosition - MidPoint) * distortionRadiusInv, 0, 1);	
		relativeDensity = clamp(length(EntryPoint- ExitPoint) / (2*distortionRadius), 0.0, 1.0);

	#line 33000
	}else if (pointbeamcone < 1.5){ // beam 
		vec3 beamHalfLength = v_worldPosRad2.xyz - v_worldPosRad.xyz; 
		vec3 beamStart = v_worldPosRad.xyz - beamHalfLength;
		vec3 beamEnd = v_worldPosRad.xyz + beamHalfLength;
		distortionPosition = closestbeam(fragWorldPos.xyz, beamStart, beamEnd);
		
		distortionToWorld = fragWorldPos.xyz - distortionPosition;

		closestPointOnRay = ray_line_segment_closestpoint_on_ray_and_segment2(camPos, -viewDirection, beamStart, beamEnd, distortionEmitPosition);
	
		// Find the close and far distances to the beam volume
		nearFarDistances.x =  capIntersect( camPos, -viewDirection, beamStart, beamEnd, distortionRadius);
		nearFarDistances.y = - capIntersect( camPos, viewDirection, beamStart, beamEnd, distortionRadius);
		
		EntryPoint = (-viewDirection) * nearFarDistances.x + camPos;
		ExitPoint =  (-viewDirection) * nearFarDistances.y + camPos;
		MidPoint = (EntryPoint + ExitPoint) * 0.5;
		distance_attenuation =  clamp( 1.0 - closestPointOnRay.w *distortionRadiusInv, 0,1);
		relativeDensity = clamp(length(EntryPoint- ExitPoint) / (2*distortionRadius), 0.0, 1.0);

	#line 34000
	}else if (pointbeamcone > 1.5){ // cone
		distortionPosition = v_worldPosRad.xyz;
		
		distortionToWorld = fragWorldPos.xyz - distortionPosition;

		vec3 coneDirection = normalize(v_worldPosRad2.xyz);
	
		float coneAngleCosine = v_worldPosRad2.w;
		float coneHalfAngleSine = sqrt(1.0 - coneAngleCosine * coneAngleCosine);

		//Cone maximizing sphere: http://mathcentral.uregina.ca/QQ/database/QQ.09.07/s/juan1.html
		float coneHeight = distortionRadius;
		float coneWidth = distortionRadius * coneHalfAngleSine;
		float coneSideLengthInv = inversesqrt(coneHeight * coneHeight + coneWidth * coneWidth);
		float biggestradius = coneHeight * coneWidth * coneSideLengthInv / ( 1 + coneWidth * coneSideLengthInv);
		vec3 endPoint = distortionPosition  + coneDirection * (distortionRadius - biggestradius);
		nearFarDistances = intersectRoundedCone(camPos, -viewDirection, distortionPosition, endPoint , biggestradius * 0.11, biggestradius) ;

		EntryPoint = camPos + nearFarDistances.x * -viewDirection;
		ExitPoint = camPos + nearFarDistances.y * -viewDirection;
		MidPoint = (EntryPoint + ExitPoint) * 0.5;

		// Calculate the closest point on the view ray to the cone
		closestPointOnRay = ray_line_segment_closestpoint_on_ray_and_segment2(camPos, -viewDirection, distortionPosition, endPoint, distortionEmitPosition);
	
		distance_attenuation = clamp( 1.0 - length(MidPoint - distortionPosition)  / coneHeight, 0,1) * 1.0;
		float distortionAngleCosine  = dot(coneDirection, normalize(MidPoint - distortionPosition));
		float coneEdgeFactor = clamp((distortionAngleCosine - coneAngleCosine) / (1.0 - coneAngleCosine), 0.0, 1.0);
		coneEdgeFactor = sqrt(	coneEdgeFactor) * 4;
		relativeDensity = clamp(length(EntryPoint- ExitPoint) / (2*biggestradius), 0.0, 1.0);
	}

	#line 35000
	// If the fragment is inside the volume, we need to calculate the volumetric fraction
	float volumetricFraction = 1.0; // The fraction of the ray that passes through the volume. 
	if (fragDistance < nearFarDistances.y) {
		volumetricFraction = 1.0 - clamp( abs(nearFarDistances.y - fragDistance) / abs(nearFarDistances.y - nearFarDistances.x), 0.0, 1.0);
	}
	if (fragDistance < nearFarDistances.x || nearFarDistances.x < 0.0) {
		fragColor.rgba = vec4(0.0);
		return;
	}

	// Check if the volume is occluded, bail if yes!
	// if ((fragDistance < nearFarDistances.x) || (nearFarDistances.y - nearFarDistances.x < 1e-6)){ fragColor.rgba = vec4(0.0); return; }
	// TODO: sample noise here, as most effects need the noise sample, and it should be a shared path along the branches


	//-------------------------- END SHARED SECTION ---------------------


	// ------------------------ BEGIN AIR SHOCKWAVE ---------------- 
	if (effectType == 1){
		// Create an air shockwave displacement based on the distance to the distortion source:
		// Bend the distortion beam as many times as it goes through the sphere!
			// Lifetime goes from 0 to 1
			float lifeStart = SPAWNFRAME;
			float lifeTime = LIFETIME;
			//float timeFraction = clamp((currentTime - lifeStart) / lifeTime, 0.0, 1.0);
			float elapsedframes = currentTime - lifeStart;

			// From 0 to 1 over the lifetime of the airshockwave
			float timeFraction = fract((currentTime - lifeStart) / lifeTime);

			// which direction is the effect going in in world coords?, always points towards us!
			vec3 shockDirection = normalize(EntryPoint.xyz - distortionEmitPosition.xyz);
			
			// Parabolic mapping of 0-1 to [0-1-0] with a parabola on timeFraction
			float parabolicStrength = pcurve_k(timeFraction, 0.5, 2.0, 3.5);
			
			// Falloff due to distance from camera
			float distanceToCameraFactor =  clamp(300.0/ fragDistance, 0.0, 1.0);

			// Screen-space position of the center of the shockwave:
			vec4 DistortionScreenPosition = cameraViewProj * vec4(distortionEmitPosition.xyz, 1.0);
			DistortionScreenPosition.xyz = DistortionScreenPosition.xyz / DistortionScreenPosition.w;

			// the normal of the shockwave sphere
			// Get the noise sample:
			vec3 noisePosition = fragWorldPos.xyz;
			
			if (NOISESCALESPACE < 0.0){
				noisePosition -= v_worldPosRad.xyz;
			}

			// Scale the noise position with the noise scale
			noisePosition *= abs(NOISESCALESPACE) * 0.03;

			
			// Add the time offset and wind offsets to the noise position
			vec3 noiseOffset = vec3(0.0); //vec3(windXZ.x * 0.1, currentTime * 0.01, windXZ.y * 0.1 ) * (1.0 + vec3(WINDAFFECTED, EFFECTPARAM1, WINDAFFECTED));
			
			// Normalize the noise sample at noisePosition - noiseOffset
			vec4 noiseSampleNorm = (textureLod(noise3DCube, noisePosition - noiseOffset, 0.0) )* 2.0 - 1.0;


			float refractiveIndex = EFFECTPARAM2 + (noiseSampleNorm.r + 0.5) * NOISESTRENGTH * 0.25 ;

			//Use Snell's law
			float cosTheta1 = dot(-viewDirection, shockDirection);
			float sinTheta1 = sqrt(1.0 - cosTheta1 * cosTheta1);
			float sinTheta2 = sinTheta1 / refractiveIndex;

			float rayBendElmos = 0;
			rayBendElmos = sin(asin(sinTheta1) - asin(sinTheta2));

			// At extremely oblique angles, the refraction can be so strong that the ray bends back towards the camera
			// This can be avoided, by softening the refraction at the edges
			// So shockWidth should reduce rayBendElmos when abs(cosTheta) is near 0
			float shockWidth = EFFECTPARAM1;
			float shockWaveEdgeSoften = pow(distance_attenuation, abs(shockWidth));
			rayBendElmos *= shockWaveEdgeSoften;

			// fragment we are checking is occluding the sphere
			if (fragDistance < nearFarDistances.x){
				fragColor.rgba = vec4(0.0 );
				return;
			}

			// fragment is behind the sphere
			if ((fragDistance > nearFarDistances.y) && shockWidth > 0.0){
				rayBendElmos *= 2.0;
			}

			// The displacement is proportional to the distance of the fragment from the intersections of the sphere

			// screen-space direction of the shockwave
			vec2 displacementScreen = normalize((DistortionScreenPosition.xy * 0.5 + 0.5) - v_screenUV);
			float overallStrength = 10 * rayBendElmos *  distanceToCameraFactor * parabolicStrength * LIFESTRENGTH;
			vec2 displacementAmount = displacementScreen * overallStrength;
			
			fragColor.rgba = vec4(displacementAmount * EFFECTSTRENGTH, 0.0, 1.0 );
	}

	
	//------------------------- BEGIN GROUND SHOCKWAVE -------------------------
	else if (effectType == 2){
		// Create a ground shockwave displacement that only displaces ground fragments based on the distance to the distortion source:
		// TODO: instead of using radius here, adjust radius in the vertex shader!

		// Get the noise sample:
		vec3 noisePosition = fragWorldPos.xyz;
		
		if (NOISESCALESPACE < 0.0){
			noisePosition -= v_worldPosRad.xyz;
		}

		// Scale the noise position with the noise scale
		noisePosition *= abs(NOISESCALESPACE) * 0.03;
		
		// Add the time offset and wind offsets to the noise position
		//vec3 noiseOffset = vec3(0.0); //vec3(windXZ.x * 0.1, currentTime * 0.01, windXZ.y * 0.1 ) * (1.0 + vec3(WINDAFFECTED, EFFECTPARAM1, WINDAFFECTED));
		vec3 noiseOffset = vec3(windXZ.x * 0.1, 0.1,  windXZ.y * 0.1 ) * ( vec3(WINDAFFECTED, 5,  WINDAFFECTED));
		
		// Normalize the noise sample at noisePosition - noiseOffset
		vec4 noiseSampleNorm = (textureLod(noise3DCube, noisePosition - noiseOffset, 0.0) )* 2.0 - 1.0;

		// Lifetime goes from 0 to 1
		float timeFraction = clamp((currentTime - SPAWNFRAME) / LIFETIME, 0.0, 1.0);

		#define COMPRESSION 0.9
		float currentDist =  COMPRESSION * distortionRadius + 10 * NOISESTRENGTH * noiseSampleNorm.r;
		// TODO : Parameterize out width in elmos
		float width = EFFECTPARAM1;

		float groundDistanceToShockCenter = length(fragWorldPos.xyz - distortionPosition.xyz);
		
		// Effect strength and direction should be abs width'd
		// But it should be wider on the rarefaction side than the compression side
		// First term is the compression factor, second term is the rarefaction factor
		float compressionFactor = max((groundDistanceToShockCenter - currentDist) * COMPRESSION, (currentDist - groundDistanceToShockCenter) * (1.0 - COMPRESSION));

		float effectStrength =  clamp( 1.0 - abs(compressionFactor/ width), 0.0, 1.0);
		effectStrength = pow(effectStrength, 3.0);

		// Parabolic mapping of 0-1 to [0-1-0] with a parabola on timeFraction
		float parabolicStrength = pcurve_k(timeFraction, 0.5, 2.0, 3.5);
		parabolicStrength= 1.0;
		
		// Falloff due to distance from camera
		// TODO: this should really not be based on fragDistance, but on the distance to the distortion source
		float distanceToCameraFactor =  clamp(1000.0/ fragDistance, 0.0, 1.0);

		// Screen-space position of the center of the shockwave:
		
		vec4 DistortionScreenPosition = cameraViewProj * vec4(distortionEmitPosition.xyz, 1.0);
		DistortionScreenPosition.xyz = DistortionScreenPosition.xyz / DistortionScreenPosition.w;


		// screen-space direction of the shockwave
		vec2 displacementScreen = normalize((DistortionScreenPosition.xy * 0.5 + 0.5) - v_screenUV);
		float overallStrength = effectStrength * distanceToCameraFactor * parabolicStrength * LIFESTRENGTH;
		
		vec2 displacementAmount = displacementScreen * overallStrength;
		fragColor.rgba = vec4(displacementAmount * EFFECTSTRENGTH, 0.0, 0.5 * step(0.005,overallStrength) );
	}

	
	//------------------------- BEGIN AIRJET -------------------------
	else if (effectType == 3){

	}

	//------------------------- BEGIN GRAVITYLENS -------------------------
	else if (effectType == 4){

	}

	//------------------------- BEGIN FUSIONSPHERE -------------------------
	else if (effectType == 5){

	}
	
	//------------------------- BEGIN CLOAKDISTORTION -------------------------
	else if (effectType == 6){

	}

	//------------------------- BEGIN SHIELDSPHERE -------------------------
	else if (effectType == 7){
		float distortionAttenuation = 1.0; // start at max for the center

		
		// This should only highlight the very edge of the shield sphere

		float shieldEdgeFactor = clamp(0.9 - abs(length(distortionEmitPosition.xyz - closestPointOnRay.xyz) - distortionRadius +10) * 0.10, 0.0, 1.0);
		//shieldEdgeFactor = pcurve_k(shieldEdgeFactor, 0.7, 100.0, 17.0);
		shieldEdgeFactor = smoothstep(0.1, 1.0, shieldEdgeFactor);
		if (fragDistance < ( length(distortionPosition - camPos) -distortionRadius)){
			fragColor.rgba = vec4(0.0);
			return;
		}

		//D
		distortionAttenuation *= shieldEdgeFactor;
		// 

		// TODO: Ensure that the distortion is proportionate to the amount of "Hot" volume the ray passes through. 
		// Get the noise sample:
		vec3 noisePosition = MidPoint.xyz;
		
		if (NOISESCALESPACE < 0.0){
			noisePosition -= v_worldPosRad.xyz;
		}

		// Scale the noise position with the noise scale
		noisePosition *= abs(NOISESCALESPACE) * 0.03;
		
		// Add the time offset and wind offsets to the noise position
		vec3 noiseOffset = vec3(windXZ.x * 0.1, currentTime * 0.01, windXZ.y * 0.1 ) * (1.0 + vec3(WINDAFFECTED, EFFECTPARAM1, WINDAFFECTED));
		
		// Normalize the noise sample at noisePosition - noiseOffset
		vec4 noiseSampleNorm = (textureLod(noise3DCube, noisePosition - noiseOffset, 0.0) )* 2.0 - 1.0;


		// modulate the effect strength with the distance to the heat source:
		float distanceToCameraFactor =  clamp(300.0/ length(camPos.xyz - MidPoint.xyz), 0.0, 1.0);
		noiseSampleNorm *= distanceToCameraFactor * LIFESTRENGTH;

		// Modulate alpha with the distortionAttenuation
		noiseSampleNorm *= NOISESTRENGTH;
		fragColor.rgba = vec4(noiseSampleNorm.ra * EFFECTSTRENGTH, 0.0,  distortionAttenuation);
	}
	
	//------------------------- BEGIN MAGNIFIER -------------------------
	else if (effectType == 8){
		// Calculate the view-space vector that points from from distortion center to the view ray
		vec3 magnifierDir = normalize(MidPoint - distortionPosition);
		vec3 magnifierNormal = normalize(magnifierDir);

		vec3 DistortionScreenPosition = worldToScreenUVZ(distortionEmitPosition.xyz); 

		vec3 MagnifierScreenPosition = worldToScreenUVZ(MidPoint);

		vec3 dirInCameraSpace2 = normalize(MagnifierScreenPosition - DistortionScreenPosition);
		float relativeDistance = clamp(1.0 - length(MidPoint - distortionEmitPosition.xyz) / distortionRadius, 0.0, 1.0);
		dirInCameraSpace2 *= 1.0 - sqrt(relativeDistance);
		dirInCameraSpace2 *= -3.0;
		
		float distanceToCameraFactor =  clamp(300.0/ length(camPos - distortionEmitPosition.xyz), 0.0, 1.0);
		dirInCameraSpace2 *= distanceToCameraFactor * EFFECTPARAM1;
		//printf(EFFECTPARAM1);
		fragColor.rgba = vec4(dirInCameraSpace2.xy * EFFECTSTRENGTH, 0.0, 1.0);
	}
	
	//------------------------- BEGIN Motion Blur -------------------------
	else if (effectType == 11){
		vec3 unittravelDirection = normalize(v_worldPosRad2.xyz);

		vec3 unitUV = worldToScreenUVZ(v_worldPosRad.xyz);
		vec3 unitUV2 = worldToScreenUVZ(v_worldPosRad.xyz + v_worldPosRad2.xyz);
		vec3 travelDirectionScreen = unitUV2 - unitUV;
		if (length(travelDirectionScreen) < 0.001) {fragColor.rgba = vec4(0.0); return;}
		travelDirectionScreen = normalize(travelDirectionScreen);

		float travelSpeedMult = clamp((v_worldPosRad2.w - EFFECTPARAM1) * EFFECTPARAM2, 0.0, 1.0);

		fragColor.rgba = vec4(travelDirectionScreen.xy * EFFECTSTRENGTH, -10.0, 1.0);

		if (fragDistance > nearFarDistances.y){
			fragColor.rgba = vec4(0.0);
		}
	}

	//------------------------- BEGIN TACHYON BEAM -------------------------
	else if (effectType == 12){
		float distortionAttenuation = 1.0; // start at max for the center

		
		// This should only highlight the very edge of the shield sphere

		float shieldEdgeFactor = clamp(1.0 - abs(length(distortionEmitPosition.xyz - closestPointOnRay.xyz) - distortionRadius +6) * 0.12, 0.0, 1.0);
		//shieldEdgeFactor = pcurve_k(shieldEdgeFactor, 0.1, 100.0, 75.0);
		shieldEdgeFactor = smoothstep(0.2, 1.5, shieldEdgeFactor);
		if (fragDistance < ( length(distortionPosition - camPos) -distortionRadius)){
			fragColor.rgba = vec4(0.0);
			return;
		}

		//D
		distortionAttenuation *= shieldEdgeFactor;
		// 

		// TODO: Ensure that the distortion is proportionate to the amount of "Hot" volume the ray passes through. 
		// Get the noise sample:
		vec3 noisePosition = MidPoint.xyz;
		
		if (NOISESCALESPACE < 0.0){
			noisePosition -= v_worldPosRad.xyz;
		}

		// Scale the noise position with the noise scale
		noisePosition *= abs(NOISESCALESPACE) * 0.035;
		
		// Add the time offset and wind offsets to the noise position
		vec3 noiseOffset = vec3(windXZ.x * 0.1, currentTime * 0.01, windXZ.y * 0.1 ) * (1.0 + vec3(WINDAFFECTED, EFFECTPARAM1, WINDAFFECTED));
		
		// Normalize the noise sample at noisePosition - noiseOffset
		vec4 noiseSampleNorm = (textureLod(noise3DCube, noisePosition - noiseOffset, 0.0) )* 2.0 - 1.0;


		// modulate the effect strength with the distance to the heat source:
		float distanceToCameraFactor =  clamp(300.0/ length(camPos.xyz - MidPoint.xyz), 0.0, 1.0);
		noiseSampleNorm *= distanceToCameraFactor * LIFESTRENGTH;

		// Modulate alpha with the distortionAttenuation
		noiseSampleNorm *= NOISESTRENGTH;
		fragColor.rgba = vec4(noiseSampleNorm.ra * EFFECTSTRENGTH, 0.0,  distortionAttenuation);
	}

// ------------------------ BEGIN FILLED DISTORTION CIRCLE (Updated ONLYMODELMAP & Y-Offset) ----------------
else if (effectType == 13) { // Keeping type 13
    // Simulates an expanding circle using noise displacement within a static max radius.
    // Expansion controlled by timeFraction/STARTRADIUS. Intensity affected by RAMPUP and DISTANCEFALLOFF.
    // Optionally restricted to model/map geometry via ONLYMODELMAP. Includes Y-offset for noise.

    // --- Lifetime & Timing ---
    float lifeStart = SPAWNFRAME;
    float lifeTime = LIFETIME;
    // Calculate elapsed time fraction (0 to 1 over lifetime), clamped.
    float timeFraction = clamp((currentTime - lifeStart) / lifeTime, 0.0, 1.0);

    // Ramp-up factor based on elapsed time vs RAMPUP uniform (0 to 1 over ramp-up duration)
    float elapsed = currentTime - lifeStart;
    float rampFactor = 1.0;
    if (RAMPUP > 0.0) {
        rampFactor = clamp(elapsed / RAMPUP, 0.0, 1.0);
    }

    // --- Check Max Radius & Calculate Distance ---
    // Use distortionRadius as the static maximum world-space radius for the effect volume.
    float maxRadius = distortionRadius; // Make sure distortionRadius is correctly defined/passed

    // Calculate the world-space distance from the fragment to the emission center
    float distWorld = distance(fragWorldPos.xyz, distortionEmitPosition.xyz);

    // If fragment is outside the maximum possible radius, exit early.
    if (distWorld > maxRadius || maxRadius <= 0.0) { // Added check for maxRadius > 0
        fragColor.rgba = vec4(0.0);
        return;
    }

    // --- ONLYMODELMAP Check ---
    // Apply filtering based on ONLYMODELMAP setting compared against model depths.
    // ONLYMODELMAP > 0.5: Show only on map (discard model fragments)
    // ONLYMODELMAP < -0.5: Show only on models (discard map fragments)
    // Otherwise: Show on both
    if (abs(ONLYMODELMAP) > 0.5) { // Check if filtering is active
        // Sample the model depth map at the fragment's screen UV
        float modelDepthValue = texture(modelDepths, v_screenUV).r;

        // --- CRITICAL: Depth Linearization ---
        // Ensure fragDistance and modelDepthValue are comparable (linear depth).
        // Replace 'LinearizeDepth' with your actual depth linearization function.
        // float linearModelDepth = LinearizeDepth(modelDepthValue, cameraNearPlane, cameraFarPlane);
        float linearModelDepth = modelDepthValue; // Placeholder: Assumes comparable linear depth
        // --- End Depth Linearization Note ---

        // Define epsilon for depth comparison tolerance
        float depthEpsilon = 0.1; // Adjust based on world scale and depth precision

        if (ONLYMODELMAP > 0.5) { // Only show on MAP (discard if fragment IS model)
            // Discard if the fragment's depth is very close to the model's depth
            if (abs(fragDistance - linearModelDepth) < depthEpsilon) {
                fragColor.rgba = vec4(0.0);
                return; // Fragment is part of the model surface, discard
            }
        } else { // ONLYMODELMAP < -0.5: Only show on MODEL (discard if fragment IS map/background)
            // Discard if the fragment's depth is significantly further than the model's depth
            // (This logic seemed to work according to the user, keeping it)
            if (fragDistance > linearModelDepth + depthEpsilon) {
                fragColor.rgba = vec4(0.0);
                return; // Fragment is behind the model's surface, discard
            }
        }
    }
    // --- END ONLYMODELMAP Check ---


    // --- Intensity based on Simulated Expansion (Time) ---
    // Use the existing STARTRADIUS define (v_baseparams.z), assumed percentage (0.0 to 1.0).
    // Intensity starts increasing *after* timeFraction passes STARTRADIUS.
    float expansionIntensity = smoothstep(STARTRADIUS, 1.0, timeFraction); // Using STARTRADIUS define

    // --- Intensity based on Distance Falloff ---
    // Calculate normalized distance (0 at center, 1 at edge)
    float normalizedDist = distWorld / maxRadius; // Already checked maxRadius > 0
    // Base distance attenuation (1.0 at center, smoothly falling to 0.0 at edge)
    float baseDistAtten = 1.0 - smoothstep(0.0, 1.0, normalizedDist);
    // Apply the DISTANCEFALLOFF logic (similar to effectType 0)
    float distanceFalloffFactor = baseDistAtten;
    if (DISTANCEFALLOFF >= 0.0) {
        // Positive DISTANCEFALLOFF acts as an exponent, shaping the falloff curve
        distanceFalloffFactor = pow(baseDistAtten, DISTANCEFALLOFF);
    } else {
        // Negative DISTANCEFALLOFF uses a p-curve to make center weak and edge stronger (inverted effect)
        float dist_from_edge = baseDistAtten;
        float dist_from_center = 1.0 - dist_from_edge;
        distanceFalloffFactor = pow(dist_from_center, -DISTANCEFALLOFF) * dist_from_edge;
        distanceFalloffFactor = clamp(distanceFalloffFactor, 0.0, 1.0);
    }

    // --- Combine Attenuations & Check ---
    // Combine time-based expansion, ramp-up, and distance-based falloff
    float distortionAttenuation = expansionIntensity * rampFactor * distanceFalloffFactor;

    // If the effect hasn't expanded/ramped up enough, or is fully attenuated by distance, exit.
    if (distortionAttenuation <= 0.0) { // Check combined attenuation
        fragColor.rgba = vec4(0.0);
        return;
    }

    // --- Noise Calculation (Adapted from effectType 0 / previous version) ---
    vec3 noisePosition = MidPoint.xyz; // Using MidPoint like heat distortion

    // <<< ADDED Y-OFFSET >>>
    noisePosition += vec3(0.0, 5.0, 0.0); // Apply 5-unit Y offset before scaling/offsetting

    if (NOISESCALESPACE < 0.0) {
        noisePosition -= v_worldPosRad.xyz; // Apply offset if needed
    }
    noisePosition *= abs(NOISESCALESPACE) * 0.03; // Apply noise scale
    vec3 noiseOffset = vec3(windXZ.x * 0.1, currentTime * 0.01, windXZ.y * 0.1 ) * (1.0 + vec3(WINDAFFECTED, EFFECTPARAM1, WINDAFFECTED));
    vec4 noiseSampleNorm = (textureLod(noise3DCube, noisePosition - noiseOffset, 0.0)) * 2.0 - 1.0; // Range [-1, 1]
    float distanceToCameraFactor = clamp(300.0 / length(camPos.xyz - MidPoint.xyz), 0.0, 1.0);
    noiseSampleNorm *= distanceToCameraFactor * LIFESTRENGTH * NOISESTRENGTH;
    // --- End Noise Calculation ---

    // --- Occlusion Check (Standard Scene Depth) ---
    // This check remains relevant even with ONLYMODELMAP, ensuring the effect
    // doesn't draw in front of closer scene objects that might occlude the effect volume.
    if (fragDistance < nearFarDistances.x) {
        fragColor.rgba = vec4(0.0); // Hard cut for now
        return;
    }
    // --- End Occlusion Check ---

    // --- Final Displacement & Output ---
    vec2 displacementAmount = noiseSampleNorm.ra * EFFECTSTRENGTH;

    // Output: rg = displacement, a = combined attenuation
    fragColor.rgba = vec4(displacementAmount, 0.0, distortionAttenuation);
}
// ------------------------ END FILLED DISTORTION CIRCLE (Updated ONLYMODELMAP & Y-Offset) ------------------



	//------------------------- BEGIN HEAT DISTORTION -------------------------
	// Debugging check attenuations for each distortion source type:
	// Draw attenuation as a color Green

	else if (effectType == 0){

		float distortionAttenuation = 1.0; // start at max for the center

		// Attenuate with distance, distance attenuation is inverse of distance
        distortionAttenuation *= distance_attenuation;
        
        // plug in custom distortion falloff power
        if (DISTANCEFALLOFF >= 0.0){
            distortionAttenuation = pow(distortionAttenuation, DISTANCEFALLOFF); 
        } else
		{ // use a p-curve for negative values of DISTANCEFALLOFF to have no distortion at the center
            float dist = 1.0 - distortionAttenuation;
            // This is a parabolic curve that goes from 0 to 1 at the center
            distortionAttenuation = pow(dist,-1 * DISTANCEFALLOFF)*(1.0-dist);
        }
		
		// Multiply the relative volume density:
		distortionAttenuation *= relativeDensity;

		// Attenuate with distance:
		distortionAttenuation *= distance_attenuation;
		
		// TODO: plug in custom distoriton falloff power
		distortionAttenuation = pow(distortionAttenuation, DISTANCEFALLOFF); 

		// Take into account relative distance of ray point closest to distortion source to the distortion source
		distortionAttenuation *= volumetricFraction;

		// if the fragment is closer to the camera than the distortion source plus its radius, we can completely skip the distortion
		if (fragDistance < ( length(distortionPosition - camPos) -distortionRadius)){
			fragColor.rgba = vec4(0.0);
			return;
		}

		// --- ADD THE RAMPUP LOGIC HERE ---
		float elapsed = currentTime - SPAWNFRAME; // how many frames (or time units) since spawn
		// For safety, if RAMPUP <= 0, this means "immediate" or avoid dividing by zero
		float rampFactor = 1.0;
		if (RAMPUP > 0.0) {
			rampFactor = clamp(elapsed / RAMPUP, 0.0, 1.0);
		}

		// Now multiply the distortionAttenuation by rampFactor for the fade-in
		distortionAttenuation *= rampFactor;
		
		// TODO: Ensure that the distortion is proportionate to the amount of "Hot" volume the ray passes through. 
		// Get the noise sample:
		vec3 noisePosition = MidPoint.xyz;
		
		if (NOISESCALESPACE < 0.0){
			noisePosition -= v_worldPosRad.xyz;
		}

		// Scale the noise position with the noise scale
		noisePosition *= abs(NOISESCALESPACE) * 0.03;
		
		// Add the time offset and wind offsets to the noise position
		vec3 noiseOffset = vec3(windXZ.x * 0.1, currentTime * 0.01, windXZ.y * 0.1 ) * (1.0 + vec3(WINDAFFECTED, EFFECTPARAM1, WINDAFFECTED));

		// Normalize the noise sample at noisePosition - noiseOffset
		vec4 noiseSampleNorm = (textureLod(noise3DCube, noisePosition - noiseOffset, 0.0) )* 2.0 - 1.0;

		// modulate the effect strength with the distance to the heat source:
		float distanceToCameraFactor =  clamp(300.0/ length(camPos.xyz - MidPoint.xyz), 0.0, 1.0);
		noiseSampleNorm *= distanceToCameraFactor * LIFESTRENGTH;

		// Modulate alpha with the distortionAttenuation
		noiseSampleNorm *= NOISESTRENGTH;
		
		fragColor.rgba = vec4(vec3(noiseSampleNorm.ra, 0.0) * EFFECTSTRENGTH ,  distortionAttenuation);

	}else{
		fragColor.rgba = vec4(1.0);// default fallthrough, should never EVER appear
	}
	
	// is a model fragment and we only want to affect map
	if ((ismodel > 0.5) && (ONLYMODELMAP > 0.5)) fragColor.a = 0.0; 

	 // is map fragment and we only want to to affect models
	if ((ismodel < 0.5) && (ONLYMODELMAP < -0.5)) fragColor.a = 0.0;
	// final scaling:
}
