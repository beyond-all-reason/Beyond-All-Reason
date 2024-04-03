#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

layout(points) in;
layout(triangle_strip, max_vertices = MAXVERTICES) out; // at least 1024/ numfloats output, and builtins like gl_Position counts as 4 floats towards this
// 128 max on my hw
#line 20013

uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;

uniform sampler2D unitPosTexture;

in DataVS {
	vec4 v_widthgrowthrisemaxvel;
	vec4 v_centerpos;
	vec4 v_emitoffsets;
	vec4 v_drawpos;
	ivec4 v_slot_start_step_segments;
} dataIn[];

out DataGS {
	vec4 g_centerpos;
	vec4 g_uv;
};

mat3 rotBillboard;
vec4 centerpos;
vec4 emitoffsets;

float rand(vec2 co){ // a pretty crappy random function
		return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
	}

void EmitHorizontalConnectingQuad(vec4 posrot1, vec4 posrot2, float width, float r, float g){
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



void EmitBillBoard(vec4 posrot1, vec3 emitoffset, vec2 lw, vec3 col, float progress){
	g_uv.rgb = col;
	g_uv.w = progress;
	
	vec3 p;
	mat3 rotmat;
	rotmat = rotation3dY(posrot1.w);
	//rotBillboard = rotmat;
	
	g_uv.xy = vec2(1,1);
	p = posrot1.xyz + (rotmat * emitoffset + rotBillboard * rotmat *  vec3(lw.x, 0, lw.y));
	g_centerpos = vec4(p, -1.0);
	gl_Position = cameraViewProj * vec4(  p , 1.0);
	EmitVertex();
	
	g_uv.xy = vec2(0,1);
	p = posrot1.xyz +  (rotmat * emitoffset + rotBillboard * rotmat * vec3(-lw.x, 0, lw.y));
	g_centerpos = vec4(p, 1.0);
	gl_Position = cameraViewProj * vec4(  p , 1.0);
	EmitVertex();
	
	
	g_uv.xy = vec2(1,0);
	p = posrot1.xyz + (rotmat * emitoffset + rotBillboard * rotmat * vec3(lw.x, 0, -lw.y));
	g_centerpos = vec4(p, -1.0);
	gl_Position = cameraViewProj * vec4(  p , 1.0);
	EmitVertex();
	
	g_uv.xy = vec2(0,0);
	p = posrot1.xyz + (rotmat * emitoffset + rotBillboard * rotmat * vec3(-lw.x, 0, -lw.y));
	g_centerpos = vec4(p, 1.0);
	gl_Position = cameraViewProj * vec4( p, 1.0);
	EmitVertex();
	EndPrimitive();
}



void EmitHorizontalSegment(vec4 posrot1, vec3 emitoffset, vec2 lw, vec3 col, float progress){
	g_uv.rgb = col;
	g_uv.w = progress;
	
	vec3 p;
	mat3 rotmat = rotation3dY(posrot1.w);
	
	p = posrot1.xyz +  (rotmat * ( emitoffset + vec3(-lw.x,0,-lw.y)));
	g_centerpos = vec4(p, 1.0);
	gl_Position = cameraViewProj * vec4(  p , 1.0);
	EmitVertex();
	
	p = posrot1.xyz +  (rotmat * ( emitoffset + vec3(lw.x,0,lw.y)));
	g_centerpos = vec4(p, -1.0);
	gl_Position = cameraViewProj * vec4(  p , 1.0);
	EmitVertex();
}

void GetVelPosXFramesAgo(ivec4 slot_start_step_segments, int timeback, out vec4 posrot, out vec4 velvalid){
		int slot = slot_start_step_segments.x;
		int startframe = slot_start_step_segments.y;
		int stepsize = slot_start_step_segments.z;
		int nowFrame = slot_start_step_segments.w;
		
		int desiredFrame = nowFrame - timeback;
		
		// Wrap small texIndex back around once
		int texIndex = desiredFrame + (TEXX/2);
		texIndex = texIndex - (TEXX/2) * (texIndex /(TEXX/2));
		
		// Make sure that even if our stepsize isnt 1, we dont jitter
		int modStepSize = texIndex - stepsize * (texIndex /stepsize);
		texIndex = texIndex - modStepSize;
		desiredFrame = desiredFrame - modStepSize;
		
		ivec2 sampleXY;
		sampleXY = ivec2(texIndex * 2, slot);
		posrot = texelFetch(unitPosTexture, sampleXY, 0); 
		sampleXY.x += 1;
		velvalid = texelFetch(unitPosTexture, sampleXY, 0); 

		// velocity.w is used as a sanity check to match if the gameframe was written as the value we want to get
		if (int(velvalid.w) == desiredFrame){
			velvalid.a = 1.0;
		}else{
			velvalid.w = 0.0;
		}
}


#line 22065
void main(){
	rotBillboard = mat3(cameraViewInv[0].xyz,cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz

	emitoffsets = dataIn[0].v_emitoffsets; // if an atlas is used, then use this, otherwise dont

	// Unpack parameters
	float width = dataIn[0].v_widthgrowthrisemaxvel.x ;
	float growth = dataIn[0].v_widthgrowthrisemaxvel.y;
	float rise = dataIn[0].v_widthgrowthrisemaxvel.z;
	float maxvel = dataIn[0].v_widthgrowthrisemaxvel.w;
	
	// Integer params
	ivec4 slot_start_step_gameframe = dataIn[0].v_slot_start_step_segments; 
	
	int slot = slot_start_step_gameframe.x;
	int start = slot_start_step_gameframe.y;
	int stepsize = slot_start_step_gameframe.z;	
	int numsegments = slot_start_step_gameframe.w;
	
	slot_start_step_gameframe.w = int(timeInfo.x);
	int gameframe = int(timeInfo.x);
	
	float rnd = rand(vec2(float(slot)));
	
	// Use a fake modulo operator to get the 
	//int nowFrameIndex = gameframe - (TEXX/2) * (gameframe / (TEXX/2));
	//int startFrameIndex = start - (TEXX/2) * ( start / (TEXX/2));
	
	// This is to ensure that quads dont 'snake' via a fake modulo operator
	// and for accurate 30+hz stuff
	float fracprogress = float(gameframe - stepsize * (gameframe / stepsize)) + timeInfo.w;
	
	// render order is in order of emission!


	
	
	#if 0
	// ------------- Simple horizontal ribbon: ----------------------
	vec4 currposrot = dataIn[0].v_drawpos;
	//Start by drawing one segment from currpos to previous known pos:
	// first two verts are at the unit itself
	EmitHorizontalSegment(currposrot, emitoffsets.xyz, vec2(width, 0), vec3(0), 1);
	
	// REPEAT UNTIL
	
	for (int i = 0; i < numsegments; i ++){
		vec4 nextposrot;
		vec4 velvalidat;
		
		GetVelPosXFramesAgo(slot_start_step_gameframe, i * stepsize, nextposrot, velvalidat);
		float progress = (float(i * stepsize) + fracprogress) / float(numsegments*stepsize);
	
		vec2 lw = vec2(width + ( progress) * growth , 0);
		
		nextposrot.y += (rise * progress) ;

		if (velvalidat.w > 0.5){
			EmitHorizontalSegment(nextposrot, emitoffsets.xyz, lw, vec3(1), progress);
			currposrot = nextposrot;
		}
	}
	EndPrimitive();
	#endif
	
	#if 0
	// ------------- Billboard ribbon: ----------------------
	
	vec4 currposrot = dataIn[0].v_drawpos;
	//Start by drawing one segment from currpos to previous known pos:
	// first two verts are at the unit itself
	EmitHorizontalSegment(currposrot, emitoffsets.xyz, vec2(width, 0), vec3(0), 1);
	
	// REPEAT UNTIL
	
	for (int i = 0; i < numsegments; i ++){
		vec4 nextposrot;
		vec4 velvalidat;
		
		GetVelPosXFramesAgo(slot_start_step_gameframe, i * stepsize, nextposrot, velvalidat);
		float progress = (float(i * stepsize) + fracprogress) / float(numsegments*stepsize);
		
		vec2 lw = vec2(width + ( progress) * growth , 0);
		
		nextposrot.y += (rise * progress) ;

		if (velvalidat.w > 0.5){
			EmitHorizontalSegment(nextposrot, emitoffsets.xyz, lw, vec3(0), progress);
			currposrot = nextposrot;
		}
	}
	EndPrimitive();
	#endif
	
	#if 1
	
	// ------------- Billboard puffs: ----------------------
	// MAXVERTICES / 4 billboards
	numsegments = min(numsegments, MAXVERTICES/4);
	
	vec4 currposrot = dataIn[0].v_drawpos;
	//Start by drawing one segment from currpos to previous known pos:
	// first two verts are at the unit itself
	//EmitHorizontalSegment(currposrot, emitoffsets.xyz, vec2(width, 0), vec3(0), 1);
	EmitBillBoard(currposrot, vec3(0), vec2(width, width), vec3(0), 1);
	// REPEAT UNTIL
	
	for (int i = 0; i < numsegments; i ++){
		vec4 nextposrot;
		vec4 velvalidat;
		
		GetVelPosXFramesAgo(slot_start_step_gameframe, i * stepsize, nextposrot, velvalidat);
		//float progress = (float(i * stepsize) + fracprogress) / float(numsegments*stepsize);
		float progress = (float(i * stepsize) + fracprogress) / float(numsegments*stepsize);
	
		vec2 lw = vec2(width)  + (progress) * growth;
		
		nextposrot.y += (rise * progress) * 0.1 ;

		if (velvalidat.w > 0.5){
			//EmitHorizontalSegment(nextposrot, emitoffsets.xyz, lw, vec3(0), progress);
			EmitBillBoard(currposrot, vec3(0), lw, vec3(rnd), progress);
			currposrot = nextposrot;
		}
	}
	//EndPrimitive();
	#endif
}




















