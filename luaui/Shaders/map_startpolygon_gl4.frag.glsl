#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com), Licensed under the MIT License

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 20000

uniform int isMiniMap = 0;
uniform int myAllyTeamID = -1;
uniform int rotationMiniMap = 0;
uniform vec4 startBoxes[NUM_BOXES]; // all in xyXY format
uniform int noRushTimer;
uniform vec4 pingData; // x,y,z = ping pos, w = ping time
float noRushFramesLeft;


layout (std430, binding = 4) buffer startPolygonBuffer {
	//-- Triplets of :teamID, numVertices, x, z
	// total NUM_POLYGONS count!
	vec4 polyVerts[];
};

in DataVS {
	vec4 v_position;
};

uniform sampler2D mapDepths;
uniform sampler2D mapNormals;
uniform sampler2D heightMapTex;
#ifdef SCAV_ALLYTEAM_ID
	uniform sampler2D scavTexture;
#endif
#ifdef RAPTOR_ALLYTEAM_ID
	uniform sampler2D raptorTexture;
#endif

out vec4 fragColor;

float distanceToBox(vec2 point, vec4 box_xyXY) {
	vec2 closestPointInAABB = clamp(point, box_xyXY.xy, box_xyXY.zw);
	vec2 distance = point - closestPointInAABB;
	return length(distance);
}

// Really should be:
//https://www.shadertoy.com/view/wdBXRW
float dot2( in vec2 v ) { return dot(v,v); }
float cross2d( in vec2 v0, in vec2 v1) { return v0.x*v1.y - v0.y*v1.x; }

float sdPolygon2( in vec2 p, in int startOffset, in int numVertices)
{
    const int num = numVertices;
    float d = dot(p - polyVerts[startOffset].zw, p - polyVerts[startOffset].zw);
    float s = 1.0;
    for( int i=0, j=num-1; i<num; j=i, i++ )
    {
        // distance
		int newj = startOffset + j;
		int newi = startOffset + i;
        vec2 e = polyVerts[newj].zw - polyVerts[newi].zw;
        vec2 w =    p - polyVerts[newi].zw;
        vec2 b = w - e*clamp( dot(w,e)/dot(e,e), 0.0, 1.0 );
        d = min( d, dot(b,b) );

        // winding number from http://geomalgorithms.com/a03-_inclusion.html
        bvec3 cond = bvec3( p.y>=polyVerts[newi].w, 
                            p.y <polyVerts[newj].w, 
                            e.x*w.y>e.y*w.x );
        if( all(cond) || all(not(cond)) ) s=-s;  
    }
    
    return s*sqrt(d);
}


// exponential
float smin( float a, float b, float k )
{
    k *= 1.0;
    float r = exp2(-a/k) + exp2(-b/k);
    return -k*log2(r);
}

//
//  Wombat
//  An efficient texture-free GLSL procedural noise library
//  Source: https://github.com/BrianSharpe/Wombat
//  Derived from: https://github.com/BrianSharpe/GPU-Noise-Lib
//
//  I'm not one for copyrights.  Use the code however you wish.
//  All I ask is that credit be given back to the blog or myself when appropriate.
//  And also to let me know if you come up with any changes, improvements, thoughts or interesting uses for this stuff. :)
//  Thanks!
//
//  Brian Sharpe
//  brisharpe CIRCLE_A yahoo DOT com
//  http://briansharpe.wordpress.com
//  https://github.com/BrianSharpe
//

//
//  This represents a modified version of Stefan Gustavson's work at http://www.itn.liu.se/~stegu/GLSL-cellular
//  The noise is optimized to use a 2x2x2 search window instead of 3x3x3
//  Modifications are...
//  - faster random number generation
//  - analytical final normalization
//  - random point offset is restricted to prevent artifacts
//

//
//  Cellular Noise 3D
//  produces a range of 0.0->1.0
//
float Cellular3D(vec3 P)
{
    //	establish our grid cell and unit position
    vec3 Pi = floor(P);
    vec3 Pf = P - Pi;

    // clamp the domain
    Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
    vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

    // calculate the hash ( over -1.0->1.0 range )
    vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
    Pt *= Pt;
    Pt = Pt.xzxz * Pt.yyww;
    const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
    const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
    vec3 lowz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi.zzz * ZINC ) );
    vec3 highz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi_inc1.zzz * ZINC ) );
    vec4 hash_x0 = fract( Pt * lowz_mod.xxxx ) * 2.0 - 1.0;
    vec4 hash_x1 = fract( Pt * highz_mod.xxxx ) * 2.0 - 1.0;
    vec4 hash_y0 = fract( Pt * lowz_mod.yyyy ) * 2.0 - 1.0;
    vec4 hash_y1 = fract( Pt * highz_mod.yyyy ) * 2.0 - 1.0;
    vec4 hash_z0 = fract( Pt * lowz_mod.zzzz ) * 2.0 - 1.0;
    vec4 hash_z1 = fract( Pt * highz_mod.zzzz ) * 2.0 - 1.0;

    //  generate the 8 point positions
    const float JITTER_WINDOW = 0.166666666;	// 0.166666666 will guarentee no artifacts.
    hash_x0 = ( ( hash_x0 * hash_x0 * hash_x0 ) - sign( hash_x0 ) ) * JITTER_WINDOW + vec4( 0.0, 1.0, 0.0, 1.0 );
    hash_y0 = ( ( hash_y0 * hash_y0 * hash_y0 ) - sign( hash_y0 ) ) * JITTER_WINDOW + vec4( 0.0, 0.0, 1.0, 1.0 );
    hash_x1 = ( ( hash_x1 * hash_x1 * hash_x1 ) - sign( hash_x1 ) ) * JITTER_WINDOW + vec4( 0.0, 1.0, 0.0, 1.0 );
    hash_y1 = ( ( hash_y1 * hash_y1 * hash_y1 ) - sign( hash_y1 ) ) * JITTER_WINDOW + vec4( 0.0, 0.0, 1.0, 1.0 );
    hash_z0 = ( ( hash_z0 * hash_z0 * hash_z0 ) - sign( hash_z0 ) ) * JITTER_WINDOW + vec4( 0.0, 0.0, 0.0, 0.0 );
    hash_z1 = ( ( hash_z1 * hash_z1 * hash_z1 ) - sign( hash_z1 ) ) * JITTER_WINDOW + vec4( 1.0, 1.0, 1.0, 1.0 );

    //	return the closest squared distance
    vec4 dx1 = Pf.xxxx - hash_x0;
    vec4 dy1 = Pf.yyyy - hash_y0;
    vec4 dz1 = Pf.zzzz - hash_z0;
    vec4 dx2 = Pf.xxxx - hash_x1;
    vec4 dy2 = Pf.yyyy - hash_y1;
    vec4 dz2 = Pf.zzzz - hash_z1;
    vec4 d1 = dx1 * dx1 + dy1 * dy1 + dz1 * dz1;
    vec4 d2 = dx2 * dx2 + dy2 * dy2 + dz2 * dz2;
    d1 = min(d1, d2);
    d1.xy = min(d1.xy, d1.wz);
    return min(d1.x, d1.y) * ( 9.0 / 12.0 ); // return a value scaled to 0.0->1.0
}


float expSustainedImpulse( float x, float f, float k )
{
    float s = max(x-f,0.0);
    return min( x*x/(f*f), 1.0+(2.0/f)*s*exp(-k*s));
}

// This sampler is great for upscaling operations, as it uses cubic interpolation instead of linear
vec2 CubicSampler(vec2 uvsin, vec2 texdims){
    vec2 r = uvsin * texdims - 0.5;
    vec2 tf = fract(r);
    vec2 ti = r - tf;
    tf = tf * tf * (3.0 - 2.0 * tf);
    return (tf + ti + 0.5)/texdims;
}
#line 21129
void main(void)
{
	vec4 mapWorldPos = vec4(1);
	float mapdepth = texture(mapDepths, v_position.zw).x;
	// Transform screen-space depth to world-space position
	if (isMiniMap == 1) {
		mapWorldPos.y = (MINY + MAXY) * 0.5;
		mapWorldPos.xz = (v_position.xy * 0.5 + 0.5);
		if (rotationMiniMap == 0){
			mapWorldPos.z = 1.0 - mapWorldPos.z;
		}else if (rotationMiniMap == 1){
			mapWorldPos.xz = mapWorldPos.zx;
		}else if (rotationMiniMap == 2){
			mapWorldPos.x = 1.0 - mapWorldPos.x;
		}else if (rotationMiniMap == 3){
			mapWorldPos.z = 1.0 - mapWorldPos.x;
			mapWorldPos.x = 1.0 - mapWorldPos.x;
		}
		mapWorldPos.xz *= mapSize.xy;
		
		fragColor.rgba = vec4(0.5);
		//return;	
	}else{
		mapWorldPos =  vec4( vec3(v_position.xy, mapdepth),  1.0);
		mapWorldPos = cameraViewProjInv * mapWorldPos;
		mapWorldPos.xyz = mapWorldPos.xyz / mapWorldPos.w; 

		// We are above or below the map by 4 or more elmost, discard
		if (mapWorldPos.y > (MAXY) || mapWorldPos.y < (MINY)){
			fragColor.rgba = vec4(0);
			return;
		}

		// We are out of the map, discard:
		if ((mapWorldPos.x < 0) || (mapWorldPos.x > mapSize.x) || (mapWorldPos.z < 0) || (mapWorldPos.z > mapSize.y)){
			fragColor.rgba = vec4(0);
			return;
		}
	}
	// Status Indicators
	float closestbox = 1e6;
	float furthestbox = 0;
	float smoothDistance = max(mapSize.x, mapSize.y);
	float anyBoxEdgeDistance = 1e6;

	int numEnemyBoxes = 0;
	int inAllyBox = 0;
	
	#ifdef SCAV_ALLYTEAM_ID
		int inScavBox = 0;
	#endif
	#ifdef RAPTOR_ALLYTEAM_ID
		int inRaptorBox = 0;
	#endif
	bool isPassable = false;
	vec3 mycolor = vec3(0,0,0);
	#if 0
	for (int i = 0; i < NUM_BOXES; i++) {
		float dist = distanceToBox(mapWorldPos.xz, startBoxes[i]);
		if (closestbox > dist){
			closestbox = dist;
			mycolor = teamColor[i].rgb;
		}
		furthestbox = max(furthestbox, dist);
	}
	#else
		int startpoint = 0;
		int teamID = int(polyVerts[startpoint].x);
		int endpoint = 2;
		// fair warning: there is probably a bug here that causes an infinite loop if the last box is the same team as the first box
		// also, its not very efficient
		// Whoever reads this code, I'm sorry :'(
		for (int i = 0; i < NUM_POLYGONS; i = i + 1){
			while (int(polyVerts[endpoint].x) == teamID){
				endpoint = endpoint + 1;
				if (endpoint == NUM_POINTS){
					break;
				}
			}

			float signedDistance = sdPolygon2(mapWorldPos.xz, startpoint, endpoint - startpoint);

			closestbox = min(closestbox, signedDistance);

			// Check if this is _our_ box
			if (signedDistance < 0){
				anyBoxEdgeDistance = min(anyBoxEdgeDistance, -signedDistance);
				if (teamID == myAllyTeamID + 0){
					mycolor.g = 0.7;
					inAllyBox = 1;
				}else{
					numEnemyBoxes = numEnemyBoxes + 1;
					mycolor.r = 1.0;
				}
				
				#ifdef SCAV_ALLYTEAM_ID
					if (teamID == SCAV_ALLYTEAM_ID){
						inScavBox = 1;
					}
				#endif
				#ifdef RAPTOR_ALLYTEAM_ID
					if (teamID == RAPTOR_ALLYTEAM_ID){
						inRaptorBox = 1;
					}
				#endif
			}else{
				smoothDistance = smin(smoothDistance, signedDistance, 50.0);

			}
			// Advance pointer
			startpoint = endpoint;
			teamID = int(polyVerts[startpoint].x);
		}
	#endif

	// Define the colors for the individual cases: 

	if (inAllyBox == 1){ // my box
		if (numEnemyBoxes > 0){ // has enemy boxes
			mycolor = vec3(0.5, 0.7, 0.0);
		}else{ // solo my box
			mycolor = vec3(0.0, 0.7, 0.0);
		}
	}else{ // not my box
		if (numEnemyBoxes <= 1){ // solo enemy box
			mycolor = vec3(1.0, 0.0, 0.0);
			#ifdef RAPTOR_ALLYTEAM_ID
				if (inRaptorBox == 1){
					mycolor = vec3(1.0, 0.45, 0.0);
				}
			#endif
				
			#ifdef SCAV_ALLYTEAM_ID
				if (inScavBox == 1){
					mycolor = vec3(0.6, 0.0, 1.0);
				}
			#endif

		}else{ // shared enemy box
			mycolor = vec3(1.0, 0.2, 0.0);
			
			#ifdef RAPTOR_ALLYTEAM_ID
				if (inRaptorBox == 1){
					mycolor = vec3(1.0, 0.4, 0.0);
				}
			#endif
			
			#ifdef SCAV_ALLYTEAM_ID
				if (inScavBox == 1){
					mycolor = vec3(1.0, 0.3, 1.0);
				}
			#endif
		}
	}


	// Note that now we have the distance to the closest box in closestbox
	// and the distance to the most distant box in furthestbox

	// Debug color based on their distance from the closest box
	// fragColor.rgba = vec4(mycolor * sin(closestbox*3 / (40/3.14)), 0.5);

	// But if we are within a box, then we set the alpha to 0
	vec2 uvhm = heightmapUVatWorldPos(mapWorldPos.xz);
	//uvhm = CubicSampler(uvhm, (mapSize.xy * 0.125) + 1.0);
	vec3 mapnormal = textureLod(mapNormals, uvhm, 0.0).raa; // seems to be in the [-1, 1] range!, raaa is its true return
	mapnormal.g = sqrt( 1.0 - dot( mapnormal.rb, mapnormal.rb)); // reconstruct Y from it

	if (mapnormal.y < MAX_STEEPNESS){
		isPassable = true;
	}

	// Generate a build grid (matching the usual 64+32 elmo subgrid)
	vec2 fragSize = fwidth(mapWorldPos.xz);
	float fragSizeFactor = 1.0/  dot(vec2(1.0),fragSize);

	fragSize *= 1.5;

	vec2 buildGrid16 = abs(fract(mapWorldPos.xz/16.0 - 0.5) - 0.5) * (16)/fragSize;
	float grid16 = 0.25* clamp(1.0 - min(buildGrid16.x, buildGrid16.y), 0.0, 1.0);

	vec2 buildGrid32 = abs(fract(mapWorldPos.xz/48.0 - 0.5) - 0.5) * (32)/fragSize;
	float grid32 = 0.5*clamp(1.0 - min(buildGrid32.x, buildGrid32.y), 0.0, 1.0);

	vec2 buildGrid64 = abs(fract(mapWorldPos.xz/192.0 - 0.5) - 0.5) * (192)/fragSize;
	float grid64 = clamp(1.0 - min(buildGrid64.x, buildGrid64.y), 0.0, 1.0);

	float gridmerge = fragSizeFactor * dot(vec3(grid16, grid32, grid64), vec3(0.5, 0.75, 2.0));
	//fragColor.rgba = vec4(vec3(gridmerge), 0.2); return;

	if (closestbox < 0.0) {
		// we are in at least 1 box

		// get edge factor in this case:
		// but make it anti aliased
		float edgeFactor = 1.0 - clamp((anyBoxEdgeDistance / 16.0) + clamp (1.0 - anyBoxEdgeDistance * 0.5,0,1), 0.0, 1.0);

		fragColor.a = 0.25; 
		fragColor.rgb = mycolor;
		//float anim =  Cellular3D(0.01* vec3(mapWorldPos.xz, dot (mapWorldPos.xz, vec2(1.0)) * 0.1 + timeInfo.y * 50));
		float cellNoise =  Cellular3D((1.0/2048.0)* vec3(mapWorldPos.xz, closestbox * 0.5 - timeInfo.y * 190));

		// absclamplify the cellnoise:
		cellNoise += smoothstep( 0.0, 1.0, (1.0 - abs(cellNoise -0.5 ) * 10.0)) * 0.25;
		// zero the cellnoise where you shouldnt be building:
		cellNoise *= smoothstep(0.95, 1.0, mapnormal.y);

		// float expboxedge = 0.5 * expSustainedImpulse(-1* closestbox, 32.0, (1/32.0));
		cellNoise = 0.1 + 1.15 * cellNoise;

		fragColor.a = cellNoise *(gridmerge + 0.45);
		//fragColor.a = clamp(expboxedge , 0.4 * anim, 0.5);		
		if (isMiniMap > 0.5){
			edgeFactor = 1.0 - clamp((1.0*anyBoxEdgeDistance * fragSizeFactor), 0.0, 1.0);

			// disable noise on minimap
			fragColor.a = 0.2;
			
			fragColor.rgba += edgeFactor * 0.5;
			return;
		}

		if (1 == 1){
			float smoothwidth = 0.05 / fragSizeFactor;
			float diagonalstriping = smoothstep(0.5-smoothwidth, 0.5+smoothwidth, abs(fract((mapWorldPos.x + mapWorldPos.z) / 16) -0.5)*2) ;
			vec4 impassableColor = vec4(mycolor.rgb * diagonalstriping, 0.66);

			//fragColor.a = 0.5;
			//fragColor.g = smoothstep(0.48, 0.52, fract((mapWorldPos.x + mapWorldPos.z) / 16));
			float impassablewidth = 0.05;
			fragColor = mix(fragColor, impassableColor, 
			smoothstep(-1 * impassablewidth,impassablewidth, MAX_STEEPNESS - mapnormal.y) * 0.5);
		}
		
		#ifdef SCAV_ALLYTEAM_ID
			if (inScavBox == 1 && inAllyBox == 0){
				vec4 scavTex = texture(scavTexture, mapWorldPos.xz / 1024.0);
				float whiteness = dot(vec3(1.0/3.0), scavTex.rgb);
				float scavalpha = 1.0 - whiteness;
				fragColor.rgba = vec4(vec3(1.0, 0.1, 0.7), scavalpha);
				//fragColor.rgba = scavTex;
				fragColor.a += cellNoise;
			}
		#endif

		#ifdef RAPTOR_ALLYTEAM_ID
			if (inRaptorBox == 1 && inAllyBox == 0){
				vec4 raptorTex = texture(raptorTexture, mapWorldPos.xz / 1024.0);
				float whiteness = dot(vec3(1.0/3.0), raptorTex.rgb);
				float raptoralpha = 1.0 - whiteness;
				fragColor.rgba = vec4(vec3(1.0, 0.68, 0.12), raptoralpha);
				//fragColor.rgba = raptorTex;
				fragColor.a += cellNoise;
			}
		#endif

		//fragColor.a = sin( closestbox * 0.02 + timeInfo.y * 0.1);
		//fragColor.a *= Cellular3D(0.01* vec3(mapWorldPos.xz, timeInfo.y));
		fragColor.rgba += edgeFactor * 0.33;
	}else{
		//fragColor.a = clamp(sin(smoothDistance * 0.2) * 0.05, 0.0,1.0);
		fragColor.rgba = vec4(0.0);
	}
	//fragColor.rgba = vec4(mapnormal * 0.5 + 0.5, 1.0);
}