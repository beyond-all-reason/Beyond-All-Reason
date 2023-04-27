#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__
layout(points) in;
layout(triangle_strip, max_vertices = MAXVERTICES) out;
#line 20000

uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;

in DataVS {
	uint v_numvertices;
	float v_rotationY;
	vec4 v_color;
	vec4 v_lengthwidthcornerheight;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters;
	#if (FULL_ROTATION == 1)
		mat3 v_fullrotation;
	#endif
} dataIn[];

out DataGS {
	vec4 g_color;
	vec4 g_uv;
};

mat3 rotY;
vec4 centerpos;
vec4 uvoffsets;

// This function takes in a set of UV coordinates [0,1] and tranforms it to correspond to the correct UV slice of an atlassed texture
vec2 transformUV(float u, float v){// this is needed for atlassing
	//return vec2(uvoffsets.p * u + uvoffsets.q, uvoffsets.s * v + uvoffsets.t); old
	float a = uvoffsets.t - uvoffsets.s;
	float b = uvoffsets.q - uvoffsets.p;
	return vec2(uvoffsets.s + a * u, uvoffsets.p + b * v);
}

void offsetVertex4( float x, float y, float z, float u, float v){
	g_uv.xy = transformUV(u,v);
	vec3 primitiveCoords = vec3(x,y,z);
	vec3 vecnorm = normalize(primitiveCoords);
	PRE_OFFSET
	gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * ( addRadius * vecnorm + primitiveCoords ), 1.0);
	g_uv.zw = dataIn[0].v_parameters.zw;
	POST_GEOMETRY
	EmitVertex();
}
#line 22000
void main(){
	uint numVertices = dataIn[0].v_numvertices;
	centerpos = dataIn[0].v_centerpos;
	#if (BILLBOARD == 1 )
		rotY = mat3(cameraViewInv[0].xyz,cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz
	#else
		#if (FULL_ROTATION == 1)
			rotY = dataIn[0].v_fullrotation; // Use the units true rotation
		#else
			#if (ROTATE_CIRCLES == 1)
				rotY = rotation3dY(-1*dataIn[0].v_rotationY); // Create a rotation matrix around Y from the unit's rotation
			#else
				if (numVertices > uint(5)) rotY = mat3(1.0) ;
				else rotY = rotation3dY(-1*dataIn[0].v_rotationY);
			#endif
		#endif
	#endif

	g_color = dataIn[0].v_color;

	uvoffsets = dataIn[0].v_uvoffsets; // if an atlas is used, then use this, otherwise dont

	float length = dataIn[0].v_lengthwidthcornerheight.x;
	float width = dataIn[0].v_lengthwidthcornerheight.y;
	float cs = dataIn[0].v_lengthwidthcornerheight.z;
	float height = dataIn[0].v_lengthwidthcornerheight.w;
	
	#ifdef USE_TRIANGLES
		if (numVertices == uint(3)){ // triangle pointing "forward"
			offsetVertex4(0.0, 0.0, length, 0.5, 1.0); // xyz uv
			offsetVertex4(-0.866 * width, 0.0, -0.5 * length, 0.0, 0.0);
			offsetVertex4(0.866* width, 0.0, -0.5 * length, 1.0, 0.0);
			EndPrimitive();
		}
	#endif
	
	#ifdef USE_QUADS
		if (numVertices == uint(4)){ // A quad
			offsetVertex4( width * 0.5, 0.0,  length * 0.5, 0.0, 1.0);
			offsetVertex4( width * 0.5, 0.0, -length * 0.5, 0.0, 0.0);
			offsetVertex4(-width * 0.5, 0.0,  length * 0.5, 1.0, 1.0);
			offsetVertex4(-width * 0.5, 0.0, -length * 0.5, 1.0, 0.0);
			EndPrimitive();
		}
	#endif
	
	#ifdef USE_CORNERRECT
		if (numVertices == uint(2)){ // A quad with chopped off corners
			float csuv = (cs / (length + width))*2.0;
			offsetVertex4( - width * 0.5 , 0.0,  - length * 0.5 + cs, 0, csuv); // bottom left
			offsetVertex4( - width * 0.5 , 0.0,  + length * 0.5 - cs, 0, 1.0 - csuv); // top left
			offsetVertex4( - width * 0.5 + cs, 0.0,  - length * 0.5 , csuv, 0); // bottom left
			offsetVertex4( - width * 0.5 + cs, 0.0,  + length * 0.5, csuv, 1.0); // top left
			offsetVertex4( + width * 0.5 - cs, 0.0,  - length * 0.5 , 1.0 - csuv, 0.0); // bottom right
			offsetVertex4( + width * 0.5 - cs, 0.0,  + length * 0.5 ,1.0 - csuv, 1.0 ); // top right
			offsetVertex4( + width * 0.5 , 0.0,  - length * 0.5 + cs , 1.0 , csuv ); // bottom right
			offsetVertex4( + width * 0.5 , 0.0,  + length * 0.5 - cs , 1.0 -csuv , 1.0 ); // top right
			EndPrimitive();
		}
	#endif
	
	#ifdef USE_CIRCLES
		if (numVertices > uint(5)) { //A circle with even subdivisions
			numVertices = min(numVertices,62u); // to make sure that we dont emit more than 64 vertices
			//left most vertex
			offsetVertex4(- width * 0.5, 0.0,  0, 0.0, 0.5);
			int numSides = int(numVertices) / 2;
			//for each phi in (-PI/2, Pi/2) omit the first and last one
			for (int i = 1; i < numSides; i++){
				float phi = ((i * 3.141592) / numSides) -  1.5707963;
				float sinphi = sin(phi);
				float cosphi = cos(phi);
				offsetVertex4( width * 0.5 * sinphi, 0.0,  length * 0.5 * cosphi, sinphi*0.5 + 0.5, cosphi * 0.5 + 0.5);
				offsetVertex4( width * 0.5 * sinphi, 0.0,  -length * 0.5 * cosphi, sinphi*0.5 + 0.5, cosphi *(-0.5) + 0.5);
			}
			// add right most vertex
			offsetVertex4(width * 0.5, 0.0,  0, 1.0, 0.5);
			EndPrimitive();
		}
	#endif
}