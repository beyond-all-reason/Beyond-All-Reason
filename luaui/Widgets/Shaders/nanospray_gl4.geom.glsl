#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
//(c) Beherith (mysterme@gmail.com)
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__
layout(points) in;
layout(triangle_strip, max_vertices = 4) out;
#line 20000

uniform float iconDistance = 20000.0;

in DataVS {
	uint v_numvertices;
	float v_rotationY;
	vec4 v_color;
	vec4 v_lengthwidthcornerheight;
	vec4 v_centerpos;
	vec4 v_parameters;
	#if (FULL_ROTATION == 1)
		mat3 v_fullrotation;
	#endif
} dataIn[];

out DataGS {
	vec4 g_uv;
	vec4 g_pos;
	flat vec4 g_color;
};

mat3 rotY;
vec4 centerpos;
vec4 uvoffsets;
mat2 rotBillboard;

// CUSTOM DEFINES

#define ROTATIONSPEED 0.05

vec2 rotate2D(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, -s, s, c);
	return m * v;
}

void offsetVertex4( float x, float y, float z, float u, float v){
	g_uv.xy = vec2(u,v);
	vec3 primitiveCoords = vec3(x,y,z);
	primitiveCoords.xz = rotBillboard * primitiveCoords.xz;
	vec4 g_pos = vec4(centerpos.xyz + rotY * (primitiveCoords ), 1.0);
	gl_Position = cameraViewProj * g_pos; 
	g_pos.w = max(abs(x),abs(z));
	g_uv.zw = dataIn[0].v_parameters.zw;
	EmitVertex();
}

void main(){
	uint numVertices = dataIn[0].v_numvertices;
	centerpos = dataIn[0].v_centerpos;
	
	rotY = mat3(cameraViewInv[0].xyz,cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz

	g_color = dataIn[0].v_color;

	float length = dataIn[0].v_lengthwidthcornerheight.x;
	float width = dataIn[0].v_lengthwidthcornerheight.y;
	float cs = dataIn[0].v_lengthwidthcornerheight.z;
	float height = dataIn[0].v_lengthwidthcornerheight.w;

		if (numVertices == uint(4)){ // A quad
			float r = 6*dataIn[0].v_parameters.z  + timeInfo.x * ROTATIONSPEED;
			rotBillboard = mat2(cos(r), -sin(r), sin(r), cos(r));
			
			offsetVertex4( width * 0.5, 0.0,  length * 0.5, 0.0, 1.0);
			offsetVertex4( width * 0.5, 0.0, -length * 0.5, 0.0, 0.0);
			offsetVertex4(-width * 0.5, 0.0,  length * 0.5, 1.0, 1.0);
			offsetVertex4(-width * 0.5, 0.0, -length * 0.5, 1.0, 0.0);
			EndPrimitive();
		}
}