#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000


in DataVS {
	vec4 v_worldPosRad;
	vec4 v_worldPosRad2;
	vec4 v_lightcolor;
	vec4 v_falloff_dense_scattering_sourceocclusion;
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
float ray_to_capsule_distance_squared(vec3 rayOrigin, vec3 rayDirection, vec3 cap1, vec3 cap2){ // point1, dir1, beamstart, beamend
	// returns the squared distance of the ray and the line segment
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

	float closestcap =  min( dot(interSectToC2, interSectToC2), dot(interSectToC1, interSectToC1) );  //sqdistends

	if (angle1 < 0 && angle2 > 0){ // this means that our ray is hitting between the caps
		closestcap = sqdistline;
	}
	return closestcap;
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




#line 31000
void main(void)
{
	// corresponding screenspace pos:
	vec2 screenUV = gl_FragCoord.xy / viewGeometry.xy;
	
	
	float mapdepth = texture(mapDepths, screenUV).x;
	float modeldepth = texture(modelDepths, screenUV).x;
	vec4 normals = vec4(1);
	vec4 extratex = vec4(0);
	float ismodel = 0;
	
	if (modeldepth+mapdepth < 1.9999) { // this actually hit something, otherwise we hit nothing in both mapdepth and modeldepth
		if (modeldepth < mapdepth) { // We are processing a model fragment
			ismodel = 1;
			normals =  texture2D(modelNormals, screenUV) * 2.0 - 1.0;
			extratex = texture2D(modelExtra  , screenUV) * 2.0 - 1.0;
		}else{
			normals =  texture2D(mapNormals  , screenUV) * 2.0 - 1.0;
			extratex = texture2D(mapExtra    , screenUV) * 2.0 - 1.0;
		}
	}
	
	
	float worlddepth = min(mapdepth, modeldepth);
	
	//if (gl_FragCoord.z > worlddepth) discard;
	
	vec4 fragWorldPos =  vec4( vec3(screenUV.xy * 2.0 - 1.0, worlddepth),  1.0);
	fragWorldPos = cameraViewProjInv * fragWorldPos;
	fragWorldPos.xyz = fragWorldPos.xyz / fragWorldPos.w; // YAAAY this works!
	
	//if fragWorldPos
	
	vec3 camPos = cameraViewInv[3].xyz;
	
	vec3 viewDirection = normalize(camPos - fragWorldPos.xyz);
	vec3 lightDirection = vec3(1); // the normalized vector from the light source to the fragment
	vec3 lightToWorld = vec3(0); // The vector pointing from light source to fragment world pos
	vec3 lightPosition = vec3(0);
	
	vec4 closestpoint_dist = vec4(0); // the point that is closest to the light source (xyz) and the distance to it (w)
	
	// Lighting components we wish to collect along the way:
	
	float attenuation = 0; // Just the distance from the light source
	float falloff = 1; // only cone light have this
	float scattering = 0; // the integration of the light reflected into the eye from the eye ray through the volume
	float distancetolight = 0;
	float diffuse = 0; // The amount of diffuse reflection from the world-hitting fragment
	float specular = 0; // The amount of specular reflection from the world-hitting fragment
	float dtobeam = 0;
	
	vec4 rcd = vec4 (0.0);
	
	float rcdsqr = 1000000.0;
	
	fragColor.rgba = vec4(fract(fragWorldPos.xyz * 0.1),1.0);
	
	if (pointbeamcone < 0.5){ //point
		lightPosition = v_worldPosRad.xyz;
		
		lightToWorld = fragWorldPos.xyz - lightPosition;
		lightDirection = normalize(lightToWorld);
		attenuation = clamp( 1.0 - length (lightToWorld) / v_worldPosRad.w, 0,1);
	
		//fragColor.rgb = vec3(attenuation);
	}else if (pointbeamcone < 1.5){ // beam 
		vec3 beamhalflength = v_worldPosRad2.xyz - v_worldPosRad.xyz; 
		vec3 beamstart = v_worldPosRad.xyz - beamhalflength;
		vec3 beamend = v_worldPosRad.xyz + beamhalflength;
		lightPosition = closestbeam(fragWorldPos.xyz, beamstart, beamend);
		
		lightToWorld = fragWorldPos.xyz - lightPosition;
		
		//lightPosition = closestlightlp_distance(camPos, viewDirection, beamstart, beamend);
		
		lightDirection = normalize(lightToWorld);
		attenuation = clamp( 1.0 - length (lightToWorld) / v_worldPosRad.w, 0,1);
		
		dtobeam = capIntersect( camPos, viewDirection, beamstart, beamend, v_worldPosRad.w);
		
		dtobeam = distancebetweenlines(beamstart, normalize(beamstart-beamend), camPos,viewDirection).x;
		rcd = ray_to_capsule_distance(camPos, viewDirection, beamstart, beamend);
		rcdsqr = ray_to_capsule_distance_squared(camPos, viewDirection, beamstart, beamend);
		falloff = 0;
	}else if (pointbeamcone > 1.5){ // cone
		lightPosition = v_worldPosRad.xyz;
		
		lightToWorld = fragWorldPos.xyz - lightPosition;
		lightDirection = normalize(lightToWorld);
		
		float lightandworldangle = dot(-lightDirection, v_worldPosRad2.xyz);
		float lightspotfalloff = smoothstep(v_worldPosRad2.w, 1.0, lightandworldangle) ;
		falloff = lightspotfalloff;
		attenuation = clamp( 1.0 - length (lightToWorld) / v_worldPosRad.w, 0,1) * lightspotfalloff;
		//attenuation = lightspotfalloff ;
	}
	
	closestpoint_dist = closestlightlp_distance(camPos, viewDirection, lightPosition);
	distancetolight = clamp(1.0 - closestpoint_dist.w/v_worldPosRad.w, 0.0, 1.0);
	
	diffuse = clamp(dot(-lightDirection, normals.xyz), 0.0, 1.0);
	diffuse = diffuse*diffuse;
	
	
	
	vec3 reflection = reflect(lightDirection, normals.xyz);
	specular = dot(reflection, viewDirection);
	specular = pow(max(0.0, specular), 32.0) * 0.5;
	attenuation = attenuation * attenuation;
	
	fragColor.rgb = vec3(attenuation, diffuse, specular);
	
	fragColor.rgb = vec3(1.0) * attenuation * (diffuse + specular);
	if (v_falloff_dense_scattering_sourceocclusion.z < worlddepth) {fragColor.rgb += vec3(pow(distancetolight,12) * falloff);
	}
	else{
		//fragColor.rgb = vec3(0);
	}
	
	//fragColor.rgb = vec3(distancetolight);
	//fragColor.rgb = vec3(fract(lightPosition.xyz * 0.025));
	//fragColor.rgb = vec3(fract(dtobeam * 0.001));
	
	//calc from rcd
	float fuck = 0;
	float beamlength = 2*length(v_worldPosRad2.xyz - v_worldPosRad.xyz);
	
	
	
	
	fragColor.rgb += clamp(0.25* vec3(pow(1.0-rcdsqr / (v_worldPosRad.w * v_worldPosRad.w),16)), 0.0, 1.0);
	//fragColor.rgb = vec3(rcdsqr / (v_worldPosRad.w * v_worldPosRad.w));
	//fragColor.rgb = vec3(abs(fract(v_falloff_dense_scattering_sourceocclusion.w*10)));
	//fragColor.rgb = v_falloff_dense_scattering_sourceocclusion.zzz;
}