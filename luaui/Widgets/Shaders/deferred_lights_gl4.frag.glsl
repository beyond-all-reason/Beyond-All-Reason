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
	vec4 v_falloff_dense_scattering;
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


//https://iquilezles.org/articles/intersectors/
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
	
	vec4 fragWorldPos =  vec4( vec3(screenUV.xy * 2.0 - 1.0, worlddepth),  1.0);
	fragWorldPos = cameraViewProjInv * fragWorldPos;
	fragWorldPos.xyz = fragWorldPos.xyz / fragWorldPos.w; // YAAAY this works!
	
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
		lightDirection = normalize(lightToWorld);
		attenuation = clamp( 1.0 - length (lightToWorld) / v_worldPosRad.w, 0,1);
		
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
	specular = pow(max(0.0, specular), 8.0) * 3;
	
	fragColor.rgb = vec3(attenuation, diffuse, specular);
	
	fragColor.rgb = vec3(1.0) * attenuation * (diffuse + specular);
	fragColor.rgb += vec3(pow(distancetolight,8) * falloff);
}