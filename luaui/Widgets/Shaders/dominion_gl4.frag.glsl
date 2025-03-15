#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com), Licensed under the MIT License

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 20000

uniform int isMiniMap = 0;
uniform int myAllyTeamID = -1;
uniform int flipMiniMap = 0;
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
		if (flipMiniMap == 0){
			mapWorldPos.z = 1.0 - mapWorldPos.z;
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
	float closestBox = 1e6;
	float anyBoxEdgeDistance = 1e6;

	int numEnemyBoxes = 0;
	int inAllyBox = 0;
	
	vec3 myColor = vec3(0,0,0);

	int startpoint = 0;
	int teamID = int(polyVerts[startpoint].x);
	int endpoint = 2;
	
	for (int i = 0; i < NUM_POLYGONS; i = i + 1){
		while (int(polyVerts[endpoint].x) == teamID){
			endpoint = endpoint + 1;
			if (endpoint == NUM_POINTS){
				break;
			}
		}

		float signedDistance = sdPolygon2(mapWorldPos.xz, startpoint, endpoint - startpoint);

		closestBox = min(closestBox, signedDistance);

		// Check if this is _our_ box
		if (signedDistance < 0){
			anyBoxEdgeDistance = min(anyBoxEdgeDistance, -signedDistance);
			if (teamID == myAllyTeamID + 0){
				myColor.g = 0.7;
				inAllyBox = 1;
			}else{
				numEnemyBoxes = numEnemyBoxes + 1;
				myColor.r = 1.0;
			}
		}
		
		// Advance pointer
		startpoint = endpoint;
		teamID = int(polyVerts[startpoint].x);
	}

	// Define the colors for the individual cases
	if (inAllyBox == 1){ // my box
		if (numEnemyBoxes > 0){ // has enemy boxes
			myColor = vec3(0.5, 0.7, 0.0);
		}else{ // solo my box
			myColor = vec3(0.0, 0.7, 0.0);
		}
	}else{ // not my box
		if (numEnemyBoxes <= 1){ // solo enemy box
			myColor = vec3(1.0, 0.0, 0.0);
		}else{ // shared enemy box
			myColor = vec3(1.0, 0.2, 0.0);
		}
	}

	// Simplified rendering logic
	if (closestBox < 0.0) {
		// We are in at least one box
		float edgeFactor = 1.0 - clamp((anyBoxEdgeDistance / 16.0), 0.0, 1.0);
		
		// Base color and alpha
		fragColor.rgb = myColor;
		fragColor.a = 0.25;
		
		// Only add edge highlighting
		if (edgeFactor > 0.0) {
			fragColor.a += edgeFactor * 0.33;
		}
		
		// Simplified minimap handling
		if (isMiniMap > 0.5) {
			vec2 fragSize = fwidth(mapWorldPos.xz);
			float fragSizeFactor = 1.0 / dot(vec2(1.0), fragSize);
			edgeFactor = 1.0 - clamp((1.0 * anyBoxEdgeDistance * fragSizeFactor), 0.0, 1.0);
			
			fragColor.a = 0.2;
			fragColor.rgba += edgeFactor * 0.5;
		}
	} else {
		// Outside all boxes
		fragColor.rgba = vec4(0.0);
	}
}