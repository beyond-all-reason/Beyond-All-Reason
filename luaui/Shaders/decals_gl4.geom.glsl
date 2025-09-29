#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

layout(points) in;
layout(triangle_strip, max_vertices = 40) out;
#line 20000

uniform float fadeDistance;
uniform sampler2D heightmapTex;
uniform sampler2D miniMapTex;
uniform sampler2D mapNormalsTex;

in DataVS {
	uint v_skipdraw;
	vec4 v_lengthwidthrotation;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters; // x: BWfactor, y:glowsustain, z:glowadd,
} dataIn[];

out DataGS {
	//vec4 g_color;
	vec4 g_uv;
	vec4 g_position; // how to get tbnmatrix here?
	vec4 g_parameters; // x: BWfactor, y:glowsustain, z:glowadd,
	mat3 tbnmatrix;
};

mat3 rotY;
vec3 decalDimensions; // length, height, widgth
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
	vec3 primitiveCoords = vec3(x,y,z) * decalDimensions;
	//vec3 vecnorm = normalize(primitiveCoords);// AHA zero case!
	vec4 worldPos = vec4(centerpos.xyz + rotY * ( primitiveCoords ), 1.0);
	
	vec2 uvhm = heightmapUVatWorldPos(worldPos.xz);
	worldPos.y = textureLod(heightmapTex, uvhm, 0.0).x + HEIGHTOFFSET;
	gl_Position = cameraViewProj * worldPos;
	gl_Position.z = (gl_Position.z) - 512.0 / (gl_Position.w); // send 16 elmos forward in Z
	//g_uv.zw = dataIn[0].v_parameters.zw; //unused
	g_position.xyz = worldPos.xyz;
	g_position.w = dataIn[0].v_lengthwidthrotation.w;
	//g_mapnormal = textureLod(mapNormalsTex, uvhm, 0.0).raaa;
	//g_mapnormal.g = sqrt( 1.0 - dot( g_mapnormal.ra, g_mapnormal.ra));
	//g_mapnormal.xyz = g_mapnormal.rga;
	// the tangent of the UV goes in the +U direction
	// we _kinda_ need to know the Y rot, and the normal dir for this
	// assume that tangent points "right" (+U)
	
	vec3 Nup = vec3(0.0, 1.0, 0.0);
	vec3 Trot = rotY * vec3(1.0, 0.0, 0.0);
	//vec3 Brot = rotY * vec3(0.0, 0.0, 1.0);
	vec3 Brot = cross(Nup,Trot);
	tbnmatrix = (mat3(Trot, Brot, Nup));
	
	EmitVertex();
}
#line 22000
void main(){
	if (dataIn[0].v_skipdraw == 1u) return; //bail

	centerpos = dataIn[0].v_centerpos;
	rotY = rotation3dY(dataIn[0].v_lengthwidthrotation.z); // Create a rotation matrix around Y from the unit's rotation
	//rotY = mat3(1.0);
	uvoffsets = dataIn[0].v_uvoffsets; // if an atlas is used, then use this, otherwise dont
	decalDimensions = vec3(dataIn[0].v_lengthwidthrotation.x * 0.5, 0.0, dataIn[0].v_lengthwidthrotation.y * 0.5);
	g_parameters = dataIn[0].v_parameters;
	g_uv.zw = dataIn[0].v_parameters.zw;
	//g_color.a = dataIn[0].v_lengthwidthrotation.w;
	
	// for a simple quad
	if (dataIn[0].v_skipdraw == 2u) { // pack single quad emission into negative heatstart
			offsetVertex4( 1.0, 0.0,  1.0, 1.0 , 1.0); // 2
			offsetVertex4( 1.0, 0.0, -1.0, 1.0 , 0.0); // 1
			offsetVertex4(-1.0, 0.0,  1.0, 0.0 , 1.0); // 4
			offsetVertex4(-1.0, 0.0, -1.0, 0.0,  0.0); // 3
			EndPrimitive();
	}else{
	// for a 4x4 quad
		for (int i = 0; i<4; i++){ //draw from bottom (front) to back
			float v = float(i)*0.25; // [0-2]
			// draw 4 strips of 9 verts
			//10 8 6 4 2
			// 9 7 5 3 1
			float striptop = (2.0*v - 0.5);
			float stripbot = (2.0*v - 1.0);
			
			offsetVertex4( 1.0, 0.0, striptop, 1.0 , v + 0.25); // 2
			offsetVertex4( 1.0, 0.0, stripbot, 1.0 , v       ); // 1
			offsetVertex4( 0.5, 0.0, striptop, 0.75, v + 0.25); // 4
			offsetVertex4( 0.5, 0.0, stripbot, 0.75, v       ); // 3
			offsetVertex4( 0.0, 0.0, striptop, 0.5, v + 0.25); // 6
			offsetVertex4( 0.0, 0.0, stripbot, 0.5, v ); // 5
			offsetVertex4(-0.5, 0.0, striptop, 0.25, v + 0.25); // 8
			offsetVertex4(-0.5, 0.0, stripbot, 0.25, v ); // 7
			offsetVertex4(-1.0, 0.0, striptop, 0.0, v + 0.25); // 10
			offsetVertex4(-1.0, 0.0, stripbot, 0.0, v ); // 8
			
			EndPrimitive();
		}
	}
}