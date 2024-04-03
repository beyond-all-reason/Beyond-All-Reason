#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

layout(points) in;
layout(triangle_strip, max_vertices = MAXVERTICES) out; // at least 1024/ numfloats output, and builtins like gl_Position counts as 4 floats towards this
#line 20013

uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;

uniform sampler2D unitPosTexture;

in DataVS {
	uint v_numvertices;
	vec4 v_widthgrowthrisemaxvel;
	vec4 v_centerpos;
	vec4 v_emitoffsets;
	vec4 v_slot_start_step_gf;
	vec4 v_drawpos;
} dataIn[];

out DataGS {
	vec4 g_centerpos;
	vec4 g_uv;
};

mat3 rotBillboard;
vec4 centerpos;
vec4 emitoffsets;


void EmitQuad(vec4 posrot1, vec4 posrot2, float width, float r, float g){
	g_uv.rgb = vec3 (r,0,g);
	//g_uv.r = posrot1.w;
	//g_uv.g = posrot2.w;
	
	vec3 p;
	mat3 rotmat;
	rotmat = rotation3dY(posrot1.w);
	
	p = posrot1.xyz + rotmat * vec3(width, 0,0);
	gl_Position = cameraViewProj * vec4(  p , 1.0);
	EmitVertex();
	
	
	p = posrot1.xyz + rotmat * vec3(-width, 0,0);
	gl_Position = cameraViewProj * vec4(  p , 1.0);
	EmitVertex();
	
	
	rotmat = rotation3dY(posrot2.w);
	
	p = posrot2.xyz + rotmat * vec3(width, 0,0);
	gl_Position = cameraViewProj * vec4(  p , 1.0);
	EmitVertex();
	
	
	p = posrot2.xyz + rotmat * vec3(-width, 0,0);
	gl_Position = cameraViewProj * vec4( p, 1.0);
	EmitVertex();
	EndPrimitive();
	
}

void EmitSegment(vec4 posrot1, vec2 lw, vec3 col, float progress){
	g_uv.rgb = col;
	g_uv.w = progress;
	//g_uv.r = posrot1.w;
	//g_uv.g = posrot2.w;
	
	vec3 p;
	mat3 rotmat;
	rotmat = rotation3dY(posrot1.w);
	mat3 rot2 = rotation3dZ(0);
	//rotmat = rotation3dY(0);
	

	
	p = posrot1.xyz +  (rotmat * vec3(-lw.x,0,-lw.y));
	g_centerpos = vec4(p, 1.0);
	gl_Position = cameraViewProj * vec4(  p , 1.0);
	EmitVertex();
	
	p = posrot1.xyz +  (rotmat * vec3(lw.x,0,lw.y));
	g_centerpos = vec4(p, -1.0);
	gl_Position = cameraViewProj * vec4(  p , 1.0);
	EmitVertex();
	
}

void GetVelPosXFramesAgo(ivec4 slot_start_step_gf, int timeback, out vec4 posrot, out vec4 velvalid){
		int slot = slot_start_step_gf.x;
		int startframe = slot_start_step_gf.y;
		int stepsize = slot_start_step_gf.z;
		int nowFrame = slot_start_step_gf.w;
		
		int desiredFrame = nowFrame - timeback;
		
		// Wrap small texIndex back around once
		int texIndex = desiredFrame + (TEXX/2);
		texIndex = texIndex - (TEXX/2) * (texIndex /(TEXX/2));
		
		int modStepSize = texIndex - stepsize * (texIndex /stepsize);
		texIndex = texIndex - modStepSize;
		desiredFrame = desiredFrame - modStepSize;
		
		//int fracprogress = nowFrame - stepsize * (nowFrame / stepsize);
		//progress = float(i * stepsize + fracprogress) / float(steps*step);

		
		ivec2 sampleXY;
		sampleXY = ivec2(texIndex * 2, slot);
		posrot = texelFetch(unitPosTexture, sampleXY, 0); 
		sampleXY.x += 1;
		velvalid = texelFetch(unitPosTexture, sampleXY, 0); 

		if (int(velvalid.w) == desiredFrame){
			velvalid.a = 1.0;
		}else{
		//if (desiredFrame < startframe)
		//	velvalid.a = 0.0;
			velvalid.w = 0.0;
		
		}

}


#line 22065
void main(){
	uint numVertices = dataIn[0].v_numvertices;
	centerpos = dataIn[0].v_drawpos;
	#if (BILLBOARD == 1 )
		rotBillboard = mat3(cameraViewInv[0].xyz,cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz
	#endif

	//g_color = dataIn[0].v_color;

	emitoffsets = dataIn[0].v_emitoffsets; // if an atlas is used, then use this, otherwise dont

	float width = dataIn[0].v_widthgrowthrisemaxvel.x;
	float growth = dataIn[0].v_widthgrowthrisemaxvel.y;
	float rise = dataIn[0].v_widthgrowthrisemaxvel.z;
	float maxvel = dataIn[0].v_widthgrowthrisemaxvel.w;
	
	// render order is in order of emission
	
	// first two verts are at the unit itself
	
	g_uv.xy = vec2(-1, 0);
	gl_Position = cameraViewProj * centerpos;

	// UNIT TRAILS:
	
	ivec4 iparams = ivec4(dataIn[0].v_slot_start_step_gf); 
	
	int slot = iparams.x;
	int start = iparams.y;
	int step = iparams.z;	
	int gameframe = iparams.w;
	int numSamples = TEXX/2;

	int nowFrameIndex = gameframe - numSamples * (gameframe / numSamples);
	int startFrameIndex = start - numSamples * ( start / numSamples);
	
	
	//Start by drawing one segment from currpos to previous known pos:
	
	vec4 currposrot = dataIn[0].v_drawpos;
	vec4 nextposrot = vec4(0);
	EmitSegment(currposrot, vec2(width, 0), vec3(0), 1);
	
	// REPEAT UNTIL
	int steps = 40;
	
	vec3 left = currposrot.xyz;
	vec3 right = currposrot.xyz;
	for (int i = 0; i < steps; i ++){
		vec4 nextposrot;
		vec4 velvalidat;
		
		GetVelPosXFramesAgo(iparams, i * step, nextposrot, velvalidat );
		int fracprogress = gameframe - step * (gameframe / step);
		float progress = (float(i * step + fracprogress) + timeInfo.w) / float(steps*step);
	
		vec2 lw = vec2(width + ( progress) * growth , 0);
		
		nextposrot.y += (rise * progress) ;

		
		vec4 posrot1  = nextposrot;
		g_uv.w = velvalidat.w;
		g_uv.g = velvalidat.w;
		g_uv.rgw = vec3(progress);
		
		vec3 p;
		mat3 rotmat = rotation3dY(posrot1.w);
		
		if (velvalidat.w > 0.5){
		
			p = posrot1.xyz +  (rotmat * vec3(-lw.x,0,-lw.y));
			g_centerpos = vec4(p, 1.0);
			gl_Position = cameraViewProj * vec4(  p , 1.0);
			EmitVertex();
			
			p = posrot1.xyz +  (rotmat * vec3(lw.x,0,lw.y));
			g_centerpos = vec4(p, -1.0);
			gl_Position = cameraViewProj * vec4(  p , 1.0);
			EmitVertex();
			
			currposrot = nextposrot;
		}
	
	}
	
	EndPrimitive();

}




















