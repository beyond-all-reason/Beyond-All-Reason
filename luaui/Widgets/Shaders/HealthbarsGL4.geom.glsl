#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__
layout(points) in;
layout(triangle_strip, max_vertices = MAXVERTICES) out;
#line 20000

uniform float iconDistance;
uniform float skipGlyphsNumbers; // <0.5 means none, <1.5 means percent only, >1.5 means nothing, just bars

in DataVS { // I recall the sane limit for cache coherence is like 48 floats per vertex? try to stay under that!
	uint v_numvertices;
	vec4 v_mincolor;
	vec4 v_maxcolor;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters;
	vec2 v_sizemodifiers;
	uvec4 v_bartype_index_ssboloc;
} dataIn[];

out DataGS {
	vec4 g_color; // pure rgba
	vec4 g_uv; // xy is trivially uv coords, z is texture blend factor, w means nothing yet
};

mat3 rotY;
vec4 centerpos;
vec4 uvoffsets;
float zoffset;
float depthbuffermod;
float sizemultiplier = dataIn[0].v_sizemodifiers.x;
#define HALFPIXEL 0.0019765625

#define BARTYPE dataIn[0].v_bartype_index_ssboloc.x
#define BARALPHA dataIn[0].v_parameters.y
#define GLYPHALPHA dataIn[0].v_parameters.z
#define UVOFFSET dataIn[0].v_parameters.w
#define UNIFORMLOC dataIn[0].v_bartype_index_ssboloc.z

#define BITUSEOVERLAY 1u
#define BITSHOWGLYPH 2u
#define BITPERCENTAGE 4u
#define BITTIMELEFT 8u
#define BITINTEGERNUMBER 16u
#define BITGETPROGRESS 32u
#define BITFLASHBAR 64u
#define BITCOLORCORRECT 128u

void emitVertexBG(in vec2 pos){
	g_uv.xy = vec2(0.0,0.0);
	vec3 primitiveCoords = vec3(pos.x,0.0,pos.y - zoffset) * BARSCALE *sizemultiplier;
	gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * ( primitiveCoords ), 1.0);
	gl_Position.z += depthbuffermod;
	g_uv.z = 0.0; // this tells us to use color
	float extracolor = 0.0;
	if (((BARTYPE & BITFLASHBAR) > 0u) && (mod(timeInfo.x, 10.0) > 4.0)){
		extracolor = 0.5;
	}
	g_color = mix(BGBOTTOMCOLOR + extracolor, BGTOPCOLOR + extracolor, pos.y);
	g_color.a *= dataIn[0].v_parameters.y; // blend with bar fade alpha
	EmitVertex();
}

void emitVertexBarBG(in vec2 pos, in vec4 botcolor, in float bartextureoffset){
	g_uv.x =  pos.x * 1.0/ (2.0 * (BARWIDTH - BARCORNER)); // map U to [-1, 1] x [0,1]
	g_uv.x = g_uv.x + 0.5; // map UVS to [0,1]x[0,1]
	g_uv.y = (pos.y - BARCORNER) / (BARHEIGHT - 2 * BARCORNER);
	vec2 uv01 = g_uv.xy*3.0;
	g_uv.xy = g_uv.xy * vec2(ATLASSTEP * 9, ATLASSTEP) + vec2(3 * ATLASSTEP, bartextureoffset); // map uvs to the bar texture
	g_uv.y = -1.0 * g_uv.y;
	//vec3 primitiveCoords = vec3( (pos.x - sign(pos.x) * BARCORNER),0.0, (pos.y - sign(pos.y - 0.5) * BARCORNER - zoffset)) * BARSCALE;
	vec3 primitiveCoords = vec3( pos.x,0.0, pos.y - zoffset) * BARSCALE *sizemultiplier;
	gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * ( primitiveCoords ), 1.0);
	gl_Position.z += depthbuffermod;
	g_uv.z = clamp(10000 * bartextureoffset, 0, 1); // this tells us to use color if we are using bartextureoffset
	g_color = botcolor;
	//g_color = vec4(g_uv.x, g_uv.y, 0.0, 1.0);
	g_color.a *= dataIn[0].v_parameters.y; // blend with bar fade alpha
	//g_color.a = 1.0;
	//	g_uv.y -= ATLASSTEP * 8;
	EmitVertex();
}
void emitVertexGlyph(in vec2 pos, in vec2 uv){
	g_uv.xy = vec2(uv.x, 1.0 - uv.y);
	vec3 primitiveCoords = vec3(pos.x,0.0,pos.y - zoffset) * BARSCALE *sizemultiplier;
	gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * ( primitiveCoords ), 1.0);
	g_uv.z = 1.0; // this tells us to use texture
	g_color = vec4(1.0);
	g_color.a *= dataIn[0].v_parameters.z; // blend with text/icon fade alpha
	EmitVertex();
}

void emitGlyph(vec2 bottomleft, vec2 uvbottomleft, vec2 uvsizes){
	#define GROWSIZE 0.2
	emitVertexGlyph(vec2(bottomleft.x, bottomleft.y), vec2(uvbottomleft.x + HALFPIXEL, uvbottomleft.y + HALFPIXEL));
	emitVertexGlyph(vec2(bottomleft.x, bottomleft.y + BARHEIGHT), vec2(uvbottomleft.x + HALFPIXEL, uvbottomleft.y + uvsizes.y - HALFPIXEL));
	emitVertexGlyph(vec2(bottomleft.x + BARHEIGHT, bottomleft.y), vec2(uvbottomleft.x + uvsizes.x - HALFPIXEL, uvbottomleft.y + HALFPIXEL));
	emitVertexGlyph(vec2(bottomleft.x + BARHEIGHT, bottomleft.y + BARHEIGHT), vec2(uvbottomleft.x + uvsizes.x -HALFPIXEL, uvbottomleft.y + uvsizes.y-HALFPIXEL));
	EndPrimitive();
}


#line 22000
void main(){
	// bail super early like scum if simple bar with >0.99 value
	//if (v_bartype_index_ssboloc.y < 32u){ // for paralyze and emp bars, which should always go above regular health bar
		zoffset =  1.15 * BARHEIGHT *  float(dataIn[0].v_bartype_index_ssboloc.y);
	//}else{
	//	zoffset =  1.15 * BARHEIGHT *  -1.0;
	//}

	centerpos = dataIn[0].v_centerpos;

	rotY = mat3(cameraViewInv[0].xyz,cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz,

	g_color = vec4(1.0, 0.0, 1.0, 1.0); // a very noticeable default color

	uvoffsets = dataIn[0].v_uvoffsets; // if an atlas is used, then use this, otherwise dont

	float health = dataIn[0].v_parameters.x;
	if (BARALPHA < MINALPHA) return; // Dont draw below 50% transparency

	// All the early bail conditions to not draw full/empty bars
	#ifndef DEBUGSHOW
		if (health < 0.001) return;
		if ((BARTYPE & BITPERCENTAGE) > 0u) { // for percentage bars
			if (health > 0.995) return;
		}else{
			if ((BARTYPE & BITGETPROGRESS) > 0u) { // reload bar?
				if (health > 0.995) return;
			}
			if ((BARTYPE & BITUSEOVERLAY) > 0u){ // for textured percentage bars bars
			//	if (health > 0.995) return;
			//	if (health < 0.005) return;
			}
		}
	#endif
	if (dataIn[0].v_numvertices == 0u) return; // for hiding the build bar when full health


	// STOCKPILE BAR:  128*numStockpileQued + numStockpiled + stockpileBuild
	uint numStockpiled = 0u;
	uint numStockpileQueued = 0u;
	if ((BARTYPE & BITINTEGERNUMBER) > 0u){
		float oldhealth = health;
		health = fract(oldhealth);
		oldhealth = floor(oldhealth);
		numStockpiled = uint(floor( mod (oldhealth, 128)));
		numStockpileQueued = uint(floor(oldhealth/128));
	}

	//EMIT BAR BACKGROUND!
	//     /-4----------6-\
	//   2 |              | 8
	//     |              |
	//   1 |              | 7
	//     \-3----------5-/
	//start in bottom leftmost of this shit.

		depthbuffermod = 0.001;
		emitVertexBG(vec2(-BARWIDTH            , BARCORNER            )); //1
		emitVertexBG(vec2(-BARWIDTH            , BARHEIGHT - BARCORNER)); //2
		emitVertexBG(vec2(-BARWIDTH + BARCORNER, 0                    )); //3
		emitVertexBG(vec2(-BARWIDTH + BARCORNER, BARHEIGHT            )); //4
		emitVertexBG(vec2( BARWIDTH - BARCORNER, 0                    )); //5
		emitVertexBG(vec2( BARWIDTH - BARCORNER, BARHEIGHT            )); //6
		emitVertexBG(vec2( BARWIDTH            , BARCORNER            )); //7
		emitVertexBG(vec2( BARWIDTH            , BARHEIGHT - BARCORNER)); //8
		EndPrimitive();

	// EMIT THE COLORED BACKGROUND
	// for this to work, we need the true color of the bar?

		vec4 topcolor = BGTOPCOLOR;
		vec4 botcolor = BGBOTTOMCOLOR;
		vec4 truecolor = mix(dataIn[0].v_mincolor, dataIn[0].v_maxcolor, health);

		truecolor.a = 0.2;
		topcolor = truecolor;

		topcolor.rgb *= BOTTOMDARKENFACTOR;
		depthbuffermod = 0.000;
		emitVertexBarBG(vec2(-BARWIDTH + BARCORNER, SMALLERCORNER + BARCORNER), truecolor, 0.0); //1
		emitVertexBarBG(vec2(-BARWIDTH + BARCORNER, BARHEIGHT - SMALLERCORNER - BARCORNER), topcolor,  0.0); //2
		emitVertexBarBG(vec2(-BARWIDTH + SMALLERCORNER + BARCORNER, BARCORNER            ), truecolor, 0.0); //3
		emitVertexBarBG(vec2(-BARWIDTH + SMALLERCORNER + BARCORNER, BARHEIGHT -BARCORNER ), topcolor,  0.0); //4
		emitVertexBarBG(vec2( BARWIDTH - SMALLERCORNER - BARCORNER, BARCORNER            ), truecolor, 0.0); //5
		emitVertexBarBG(vec2( BARWIDTH - SMALLERCORNER - BARCORNER, BARHEIGHT - BARCORNER), topcolor,  0.0); //6
		emitVertexBarBG(vec2( BARWIDTH - BARCORNER, SMALLERCORNER + BARCORNER            ), truecolor, 0.0); //7
		emitVertexBarBG(vec2( BARWIDTH - BARCORNER, BARHEIGHT - SMALLERCORNER - BARCORNER), topcolor,  0.0); //8
		EndPrimitive();


	// EMIT BAR FOREGROUND, ok this is harder than i thought

		float healthbasedpos = (2*(BARWIDTH -  BARCORNER) - 2 * SMALLERCORNER) * health  ;
		if ((BARTYPE & BITTIMELEFT) > 0u) healthbasedpos =  (2*(BARWIDTH -  BARCORNER) - 2 * SMALLERCORNER); // full bar for timer based shit
		if ((BARTYPE & BITCOLORCORRECT) > 0u) { truecolor.rgb = truecolor.rgb/max(truecolor.r, truecolor.g); } // color correction for health
		truecolor.a = 1.0;
		botcolor = truecolor;
		botcolor.rgb *= BOTTOMDARKENFACTOR;
		float bartextureoffset = 0;
		if ((BARTYPE & BITUSEOVERLAY) > 0u) bartextureoffset = UVOFFSET; // if the bar type is a textured bar, we have a lot of work to do

		depthbuffermod = -0.001;
		emitVertexBarBG(vec2(-BARWIDTH + BARCORNER,                                  SMALLERCORNER + BARCORNER            ), botcolor,  bartextureoffset); //1
		emitVertexBarBG(vec2(-BARWIDTH + BARCORNER,                                  BARHEIGHT - BARCORNER - SMALLERCORNER), truecolor, bartextureoffset); //2
		emitVertexBarBG(vec2(-BARWIDTH + BARCORNER + SMALLERCORNER,                  BARCORNER                            ), botcolor,  bartextureoffset); //3
		emitVertexBarBG(vec2(-BARWIDTH + BARCORNER + SMALLERCORNER,                  BARHEIGHT - BARCORNER               ), truecolor, bartextureoffset); //4


		emitVertexBarBG(vec2(-BARWIDTH + BARCORNER + SMALLERCORNER + healthbasedpos, BARCORNER                            ), botcolor,  bartextureoffset); //5
		emitVertexBarBG(vec2(-BARWIDTH + BARCORNER + SMALLERCORNER + healthbasedpos, BARHEIGHT - BARCORNER                ), truecolor, bartextureoffset); //6
		emitVertexBarBG(vec2(-BARWIDTH + BARCORNER + 2 *SMALLERCORNER + healthbasedpos,                 BARCORNER + SMALLERCORNER            ), botcolor,  bartextureoffset); //7
		emitVertexBarBG(vec2(-BARWIDTH + BARCORNER + 2 *SMALLERCORNER + healthbasedpos,                 BARHEIGHT - BARCORNER - SMALLERCORNER), truecolor, bartextureoffset); //8
		EndPrimitive();

	// try to emit text?

	if (GLYPHALPHA < MINALPHA) return; // dont display glyphs below 50% transparency

	if (skipGlyphsNumbers > 1.5) return;

	float currentglyphpos = 1.0;

	if (skipGlyphsNumbers < 0.5 ){
		if ((BARTYPE & BITSHOWGLYPH) > 0u){
			emitGlyph(vec2(- BARWIDTH - currentglyphpos * BARHEIGHT , 0), vec2(ATLASSTEP, UVOFFSET), vec2(ATLASSTEP, ATLASSTEP));	//glyph icon
		}
	}else{
		currentglyphpos = 0.0;
	}

	if ((BARTYPE & BITINTEGERNUMBER) > 0u){ // STOCKPILE FONTS THEN EH? xx/yy
		vec4 numbers = vec4(numStockpiled, numStockpiled, numStockpileQueued, numStockpileQueued);
		numbers = numbers * vec4(1.0, 0.1, 1.0, 0.1);
		numbers = floor(mod(numbers, 10.0)) * ATLASSTEP;
		float glyphpctsecatlas = 11 * ATLASSTEP; // TODO: slash sign in texture
		// go right to left

		emitGlyph(vec2(-BARWIDTH - (currentglyphpos + 1.0) * BARHEIGHT  , 0), vec2(0, numbers.x ), vec2(ATLASSTEP, ATLASSTEP)); // lsb of numqueued
		if (numbers.y > 0 ){
			emitGlyph(vec2(-BARWIDTH - (currentglyphpos + 2.0) * BARHEIGHT + BARHEIGHT * 0.4 , 0), vec2(0, numbers.y ), vec2(ATLASSTEP, ATLASSTEP)); // msb of numqueued
		}
	}


	if ((BARTYPE & (BITTIMELEFT | BITPERCENTAGE))  > 0u){
		float lsb ;
		float msb ;
		float glyphpctsecatlas;
		if ((BARTYPE & BITTIMELEFT) > 0u){ //display time
			health = (health - 1.0) / (1.0/40.0);
			lsb = abs(floor(mod(health, 10.0)));
			msb = abs( floor(mod(health*0.1, 10.0)));
			glyphpctsecatlas = 14.0; // seconds
		}else{
			lsb = floor(mod(health*100.0, 10.0));
			msb = floor(mod(health*10.0, 10.0));
			glyphpctsecatlas = 11.0; // percent
		}
		emitGlyph(vec2(-BARWIDTH - (currentglyphpos + 1.0) * BARHEIGHT , 0), vec2(0, glyphpctsecatlas * ATLASSTEP), vec2(ATLASSTEP, ATLASSTEP)); // %
		emitGlyph(vec2(-BARWIDTH - (currentglyphpos + 2.0) * BARHEIGHT + BARHEIGHT * 0.2 , 0), vec2(0,  lsb * ATLASSTEP ), vec2(ATLASSTEP, ATLASSTEP)); // lsb
		if (msb > 0){
			emitGlyph(vec2(-BARWIDTH - (currentglyphpos + 3.0) * BARHEIGHT + BARHEIGHT * 0.5 , 0), vec2(0,  msb * ATLASSTEP), vec2(ATLASSTEP, ATLASSTEP)); //msb
		}
	}
}