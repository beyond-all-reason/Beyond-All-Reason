#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

layout(points) in;
layout(triangle_strip, max_vertices = MAXVERTICES) out; // at least 1024/ numfloats output, and builtins like gl_Position counts as 4 floats towards this
#line 20000

uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;

uniform sampler2D unitPosTexture;

in DataVS {
	uint v_numvertices;
	float v_rotationY;
	vec4 v_color;
	vec4 v_lengthwidthcornerheight;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters;
} dataIn[];

out DataGS {
	vec4 g_centerpos;
	vec4 g_uv;
};

mat3 rotY;
vec4 centerpos;
vec4 uvoffsets;

void offsetVertex4(float x, float y, float z, float u, float v, float addRadiusCorr){
	g_uv.xy = vec2(u,v);
	vec3 primitiveCoords = vec3(x,y,z);
	vec3 vecnorm = normalize(primitiveCoords);
	PRE_OFFSET
	gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * (addRadius * addRadiusCorr * vecnorm + primitiveCoords ), 1.0);
	g_uv.zw = dataIn[0].v_parameters.zw;
	POST_GEOMETRY
	EmitVertex();
}

void EmitPair(vec3 center, float width, float rot){
	g_ux.xy = vec2(-1, 0);
	
	
	g_centerpos =
	gl_Position = cameraViewProj * 
	EmitVertex();
	
	
	g_ux.xy = vec2(-1, 0);
	
	g_centerpos = 
	EmitVertex();
}

#line 22000
void main(){
	uint numVertices = dataIn[0].v_numvertices;
	centerpos = dataIn[0].v_centerpos;
	#if (BILLBOARD == 1 )
		rotY = mat3(cameraViewInv[0].xyz,cameraViewInv[2].xyz, 
	#endif

	g_color = dataIn[0].v_color;

	uvoffsets = dataIn[0].v_uvoffsets; // if an atlas is used, then use this, otherwise dont

	float length = dataIn[0].v_lengthwidthcornerheight.x;
	float width = dataIn[0].v_lengthwidthcornerheight.y;
	float cs = dataIn[0].v_lengthwidthcornerheight.z;
	float height = dataIn[0].v_lengthwidthcornerheight.w;
	
	// render order is in order of emission
	
	// first two verts are at the unit itself
	vec3 unitmid = vec3(0);
	
	g_ux.xy = vec2(-1, 0);
	gl_Position = cameraViewProj
	
	
	

		if (numVertices == 4u){ // A quad
			offsetVertex4( width * 0.5, 0.0,  length * 0.5, 0.0, 1.0, 1.414);
			offsetVertex4( width * 0.5, 0.0, -length * 0.5, 0.0, 0.0, 1.414);
			offsetVertex4(-width * 0.5, 0.0,  length * 0.5, 1.0, 1.0, 1.414);
			offsetVertex4(-width * 0.5, 0.0, -length * 0.5, 1.0, 0.0, 1.414);
			EndPrimitive();
		}
}




















