//This code authored by Peter Sarkozy aka Beherith (mysterme@gmail.com )
//License is GPL V2
// old version with calced normals is 67 fps for 10 beamers full screen at 1440p
// new version with buffered normals is 88 fps for 10 beamers full screen at 1440p


//#define DEBUG

#define LIGHTRADIUS lightpos.w
uniform sampler2D modelnormals;
uniform sampler2D modeldepths;
uniform sampler2D mapnormals;
uniform sampler2D mapdepths;
uniform sampler2D modelExtra;

uniform vec3 eyePos;
uniform vec4 lightpos;
#ifdef BEAM_LIGHT
	uniform vec4 lightpos2;
#endif
uniform vec4 lightcolor;
uniform mat4 viewProjectionInv;

float attentuate(float dist, float radius)
	{
		//float att = clamp ( constant-linear * dist / radius - squared * dist * dist / (radius*radius),0.0,.5);
		float att = clamp(0.7 - 0.3 * dist / radius - 1.0 * dist * dist / (radius * radius), 0.0, 1.0);
		att *= att;
		return att;
	}

void main(void)
{
	vec4 mappos4   = vec4(vec3(gl_TexCoord[0].st, texture2D(mapdepths,   gl_TexCoord[0].st).x) * 2.0 - 1.0, 1.0);
	vec4 modelpos4 = vec4(vec3(gl_TexCoord[0].st, texture2D(modeldepths, gl_TexCoord[0].st).x) * 2.0 - 1.0, 1.0);
	vec4 map_normals4   = texture2D(mapnormals,   gl_TexCoord[0].st) * 2.0 - 1.0;
	vec4 model_normals4 = texture2D(modelnormals, gl_TexCoord[0].st) * 2.0 - 1.0;
	vec4 model_extra4 = texture2D(modelExtra, gl_TexCoord[0].st) * 2.0 - 1.0;
	float specularHighlight = 1.0;
	float model_lighting_multiplier = 1.0; //models recieve additional lighting, looks better.
	if ((mappos4.z-modelpos4.z) > 0.0) { // this means we are processing a model fragment, not a map fragment
		if (model_extra4.a > 0.5){
		map_normals4 = model_normals4;
		mappos4 = modelpos4;
		model_lighting_multiplier=1.5;
		specularHighlight= specularHighlight + 2.0*model_extra4.g;
		}
	}
	mappos4 = viewProjectionInv * mappos4;
	mappos4.xyz = mappos4.xyz / mappos4.w;
	vec3 light_direction;
	#ifndef BEAM_LIGHT
		float dist_light_here = length(lightpos.xyz - mappos4.xyz);
		light_direction = normalize(lightpos.xyz - mappos4.xyz);
		float cosphi = max(0.0 , dot (normalize(map_normals4.xyz), normalize(lightpos.xyz - mappos4.xyz)));
		float attentuation=attentuate(dist_light_here,LIGHTRADIUS);
	#endif
	#ifdef BEAM_LIGHT
		//def dist(x1,y1, x2,y2, x3,y3): # x3,y3 is the point
		/*distance( Point P,  Segment P0:P1 ) // http://geomalgorithms.com/a02-_lines.html
		{
			v = P1 - P0
			w = P - P0
			if ( (c1 = w dot v) <= 0 )  // before P0
				return d(P, P0)
			if ( (c2 = v dot v) <= c1 ) // after P1
				return d(P, P1)
			b = c1 / c2
			Pb = P0 + bv
			return d(P, Pb)
		}
		*/

		vec3 v = lightpos2.xyz - lightpos.xyz;
		vec3 w = mappos4.xyz   - lightpos.xyz;
		float c1 = dot(v, w);
		float c2 = dot(v, v);
		if (c1 <= 0.0){
			v = mappos4.xyz;
			w = lightpos.xyz;
		}else if (c2 < c1){
			v = mappos4.xyz;
			w = lightpos2.xyz;
		}else{
			w = lightpos.xyz + (c1 / c2) * v;
			v = mappos4.xyz;
		}
		float dist_light_here = length(v - w);
		light_direction = normalize(w.xyz - mappos4.xyz);
		float cosphi = max(0.0 , dot (normalize(map_normals4.xyz), light_direction));
		//float attentuation = max(0.0, (1.0 * LIGHT_CONSTANT - LIGHT_SQUARED * (dist_light_here * dist_light_here) / (LIGHTRADIUS * LIGHTRADIUS) - LIGHT_LINEAR * (dist_light_here) / (LIGHTRADIUS)));
		float attentuation = attentuate(dist_light_here, LIGHTRADIUS);
	#endif
	

	vec3 viewDirection = normalize(vec3(eyePos - mappos4.xyz));
	
	if (dot(map_normals4.xyz, light_direction) > 0.02) // light source on the wrong side?
	{
		vec3 reflection = reflect(-1.0 * light_direction, map_normals4.xyz);
		float highlight = pow(max(0.0, dot( reflection, viewDirection)), 8.0);
		specularHighlight = specularHighlight * (0.5* highlight);
	}else{
		specularHighlight = 0.0;
	}
	//OK, our blending func is the following: Rr=Lr*Dr+1*Dr
	float lightalpha = cosphi * attentuation + attentuation * specularHighlight;
	//dont light underwater:
	lightalpha = clamp(lightalpha, 0.0, lightalpha * ((mappos4.y + 50.0)* (0.02)));
	gl_FragColor = vec4(lightcolor.rgb * lightalpha * model_lighting_multiplier, 1.0);
	#ifdef DEBUG
		gl_FragColor = vec4(map_normals4.xyz, 1.0); //world normals debugging
		gl_FragColor = vec4(fract(modelpos4.z * 0.01),sign(mappos4.z - modelpos4.z), 0.0, 1.0); //world pos debugging, very useful
		if (length(lightcolor.rgb * lightalpha * model_lighting_multiplier) < (1.0 / 256.0)){ //shows light boudaries
			gl_FragColor=vec4(vec3(0.5, 0.0, 0.5), 0.0);
		}
	#endif
	return;
}