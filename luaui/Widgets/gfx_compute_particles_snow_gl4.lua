function widget:GetInfo()
  return {
    name      = "Compute Particles Snow",
    version   = "v0.1",
    desc      = "Compute Particles",
    author    = "ivand, Beherith",
    date      = "2021.11.28 - 2025.06.09",
    license   = "GPL V2, Shader Code (c) Beherith (mysterme@gmail.com)",
    layer     = 0,
    enabled   = true,
  }
end

--https://github.com/MauriceGit/Partikel_accelleration_on_GPU/tree/master/src


local LuaShader = gl.LuaShader

local vao

local particleShader, cmpShader

local DEBUG = 1

-- particle params:
	-- position.xyz + size
	-- velocity.xyz + life


-- MAH FIZZIKS SIMULAYSHUN
	-- Gravity pulls them down
	-- They bounce on ground
	-- If they hit water they die
	-- they must sample normals, and bounce in normals directoin
	-- non-elastic bounce (0.X)
	-- air resistance slows them too - dependent on size
	-- air cools them at speed dependent on size

-- colorization:
	-- init from mapcolor
	-- also take into account temperature


-- Initialize particlebatch
	-- po2 size
	-- list of {offset, size} free spaces?
	-- sample minimap (maybe precompute this?)
	-- temperature is a params
	-- initial velocity is a params


-- geometry shader job:
-- make a billboard from each one
	-- stretch with velocity vector 
	-- this has to be apparent camera-space velocity
	-- and temperature dependent

-- The Vertex Shader just places the particles into world space, and forwards their velocity and color to geo shader

--[[
-- 2025.06.06 
-- TODO :
-- - [ ] Fix billboards
-- - [ ] Fix bounce logic
-- - [ ] better random
-- - [ ] Curl noise for perturbation
-- - [ ] more varied snowflake textures 
-- - [ ] rot snowflakes 
-- - [ ] wind dir 
-- - [ ] Rework lifetime calculation, it should set to 0 when it bounces, and then allowed to go negative while fading out 
-- - [ ] Do a block-based apporach to the particles for geoshader optimality 
-- - [ ] Store the original position of the particle ( or write a function to recalc it from the index!)
-- - [ ] Use a single struct for mem locality within the compute shader
-- - [ ] Use quadgather to recalc the actual intersection with the ground 
]]--
local vsSrc = [[
#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// =================================================               ================================================
// ================================================= VERTEX SHADER ===============================================
// =================================================               ================================================
#line 10000

layout (location = 3) in uint vertexIndex;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

/*
struct SnowFlake{
	vec4 posrot; // position and rotation
	vec4 velsize; // velocity and size
	vec4 origpos_life_idx; // xzposition, life, index
	vec4 origpos_life_idx2; // xzposition, life, index
};
layout (std140, binding = 4) readonly buffer SnowFlakeBuffer { SnowFlake snowflakes[]; };
*/


layout (std430, binding = 4) buffer PositionBuffer {
	vec4 posrot[];
};
layout (std430, binding = 5) buffer VelocityBuffer {
	vec4 velsize[];
};
layout (std430, binding = 6) buffer OrigBuffer {
	vec4 origpos_life_idx[];
};



uniform float shadowpass = 0;

out DataVS {
	vec4 v_posrot;
	vec4 v_velsize;
	vec4 v_origpos_life_idx;
	#if DEBUG == 1		
		vec4 v_debug;
	#endif
};

#line 11000
void main(){ 
	v_posrot = posrot[vertexIndex];
	v_velsize = velsize[vertexIndex];
	v_origpos_life_idx = origpos_life_idx[vertexIndex];
	//gl_Position =  cameraViewProj * vec4(v_posrot.xyz, 1.0); 
	//v_posrot = vec4(v_origpos_life_idx.x, 500, v_origpos_life_idx.y, 1.0);
	v_posrot = vec4(v_posrot.xyz, 1.0);
	gl_Position =  cameraViewProj * vec4(v_origpos_life_idx.x, 500, v_origpos_life_idx.y, 1.0); // i dont think this ever gets used really.
	v_debug.x = float(vertexIndex);
	v_debug.y = v_origpos_life_idx.w;
	v_debug.zw = v_origpos_life_idx.xy;
}
]]

-- The Geometry shader takes the input points, and spawns billboards at them, stretched by velocity, and forwards color info
local gsSrc = [[
#version 330
// =================================================                 ================================================
// ================================================= GEOMETRY SHADER ===============================================
// =================================================                 ================================================
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
layout(points) in;
layout(triangle_strip, max_vertices = 4) out;
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__
#line 40000

uniform float shadowpass = 0;

uniform sampler2DShadow shadowTex;

in DataVS {
	vec4 v_posrot;
	vec4 v_velsize;
	vec4 v_origpos_life_idx;
	#if DEBUG == 1		
		vec4 v_debug;
	#endif
} dataIn[];

out DataGS {
	vec4 g_color;
	vec4 g_uv;
	
	#if DEBUG == 1		
		vec4 g_debug;
	#endif
};

bool vertexClipped(vec4 clipspace, float tolerance) {
  return any(lessThan(clipspace.xyz, -clipspace.www * tolerance)) ||
         any(greaterThan(clipspace.xyz, clipspace.www * tolerance));
}

void main(){
	g_uv.w = dataIn[0].v_origpos_life_idx.y ; // Life
	float life = dataIn[0].v_origpos_life_idx.z;
	vec4 centerpos = dataIn[0].v_posrot;
	float particlesize = dataIn[0].v_velsize.w * 1;
	centerpos.w = 1.0;
	//centerpos.x += fract(float(dataIn[0].v_index) * 0.01) * 2.0;
	
	if (vertexClipped(cameraViewProj * centerpos, 1.0)) return; // bail on out of view 

	
	vec3 velocity = dataIn[0].v_velsize.xyz;
	vec3 pointToCamera = cameraViewInv[3].xyz - centerpos.xyz;
	float disttoCameraSquared = dot(pointToCamera, pointToCamera);
	//if (disttoCameraSquared > MAXDISTANCE) return; // more than 3000 pixels away
	//if (disttoCameraSquared < MINDISTANCE) return; // less than 75 pixels away
	
	mat3 rotYregular = mat3(cameraViewInv[0].xyz, // right  // this is perfectly fine
					cameraViewInv[2].xyz,  // up 
					cameraViewInv[1].xyz); // depth,swizzle cause we use xz // billboard!
	
	// how to do we do temperature and viewport dependant stretch?
	vec3 vel_norm = normalize(velocity);
	mat3 rotY = mat3( // I HAVE NO IDEA WHAT IM DOING HERE, but im trying to rotate into the normal vector
					vel_norm, // right 
					cameraViewInv[2].xyz,  // up 
					normalize(cross(cameraViewInv[2].xyz, vel_norm)) // depth,
	); 

	g_color = vec4(1.0); 
	
    float shadowSample =  clamp(textureProj(shadowTex, shadowView * vec4(centerpos.xyz + vec3(0,particlesize,0),1.0) + vec4(0.5, 0.5, 0, 0)), 0.5, 1.0);
	g_color.rgb *= shadowSample; // shadow sample
	
	// once life goes to negative -5 fade it out complete
	g_color.a *=  clamp(1.0 + life/MELTTIME, 0.0, 1.0);

	// Make particles close to camera transparent
	g_color.a *= clamp((disttoCameraSquared  - 15000) / 25000, 0.0, 1.0);

	// Make freshly created particles transparent:
	g_color.a *= 1.0 - clamp(( life - (LIFESTART- FADEINTIME)) / (FADEINTIME), 0.0, 1.0);
	
	// this is for spin, and stationary particles shouldnt spin:
	g_uv.z = clamp(dot(velocity, velocity) * 0.001 - 0.1, 0.0, 2.0) / particlesize; //Size * velocity
	float len = particlesize;
	float extrawidth = 0.0; //length(velocity) * STRETCHFACTOR * clamp(temperature/3000, 0.0, 1.0);
	extrawidth = min(extrawidth, 1000.0* STRETCHFACTOR);
	float rotmix = 0.25;
	rotY[0] = mix(rotYregular[0], rotY[0], clamp(extrawidth*rotmix, 0.0, 1.0))	;
	rotY[1] = mix(rotYregular[1], rotY[1], clamp(extrawidth*rotmix, 0.0, 1.0))	;
	rotY[2] = mix(rotYregular[2], rotY[2], clamp(extrawidth*rotmix, 0.0, 1.0))	;

	float partID = float(dataIn[0].v_origpos_life_idx.w) * 0.01;
	float time = timeInfo.z;
	float rotangle = partID * 0.01 + time * 3.8; // rotate around Y axis

	if (life < -1.0){
		rotangle = partID * 0.01;
	}

	float rotcos = cos(rotangle);
	float rotsin = sin(rotangle);

	
	mat3 spinaroundY = mat3(rotcos, 0.0, rotsin,
											0.0, 1.0, 0.0,
											-rotsin, 0.0, rotcos);

	// A quad

	// the UV space is a 4x4 atlas, so lets get an X and Y offset for the UV space based on the dataIn[0].v_index


	//vec2 base_uv = vec2(0.25 * fract(float(dataIn[0].v_index) * 0.01), 0.25 * floor(float(dataIn[0].v_index) * 0.01));
	int idx = int(dataIn[0].v_origpos_life_idx.w);
	
	// 4x4 atlas, so we can use modulo and division to get the UV offset

	vec2 base_uv = vec2( idx  % 4, (idx / 4)% 4) * 0.25; 
	
	g_debug = dataIn[0].v_debug; //dataIn[0].v_velsize;
	g_debug.w = disttoCameraSquared;
	if (shadowpass < 0.5) {
		float width =  particlesize + extrawidth;
		g_uv.xy = vec2(0.0, 0.0) + base_uv;
		gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * (spinaroundY * vec3(-width, 0.0, - len)), 1.0); EmitVertex();
		g_uv.xy = vec2(0.25, 0.0) + base_uv;
		gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * spinaroundY * vec3( width, 0.0, - len), 1.0); EmitVertex();
		g_uv.xy = vec2(0.0, 0.25) + base_uv;
		gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * spinaroundY * vec3(-width, 0.0,  len), 1.0); EmitVertex();
		g_uv.xy = vec2(0.25, 0.25) + base_uv;
		gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * spinaroundY * vec3( width, 0.0,  len), 1.0); EmitVertex();
		EndPrimitive();
	}
}
]]

-- The fragment shader colors the billboards
local fsSrc = [[
#version 430 core 
// =================================================                ================================================
// ================================================= FRAGMENT SHADER ===============================================
// =================================================                ================================================
#line 20000
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in DataGS {
	vec4 g_color;
	vec4 g_uv;
	#if DEBUG == 1		
		vec4 g_debug;
	#endif
};

out vec4 fragColor;
uniform float shadowpass = 0;

uniform sampler2D particleTex;

#line 22000


void main(){

	vec4 texColor = texture(particleTex, g_uv.xy);
	
	fragColor.rgba = texColor * g_color;
	//printf(texColor.xyzw);
	//printf(g_debug.xyzw);
}
]]

-- The compute shader is reponsible for updating the position, velocity, and color of each particle 
local cmpSrc = [[
#version 430 core
// =================================================                ================================================
// ================================================= COMPUTE SHADER =================================================
// =================================================                ================================================
#line 30000
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

// Process particles in blocks of 128

layout (std430, binding = 4) buffer PositionBuffer {
	vec4 posrot[];
};
layout (std430, binding = 5) buffer VelocityBuffer {
	vec4 velsize[];
};
layout (std430, binding = 6) buffer OrigBuffer {
	vec4 origpos_life_idx[];
};


/*
struct SnowFlake{
	vec4 posrot; // position and rotation
	vec4 velsize; // velocity and size
	vec4 origpos_life_idx; // xzposition, life, index
	vec4 origpos_life_idx2; // xzposition, life, index
};
layout (std430, binding = 4) buffer SnowFlakeBuffer { SnowFlake snowflakes[]; };
*/
uniform sampler2D heightmapTex;
uniform sampler2D normalTex;
uniform sampler2D minimapTex;

uniform float frameTime = 0.0000;

#line 30500

// utility functions:
#if 1
	// a pretty bad, but reasonably quick random number generator
	highp float rand(vec2 co)
	{
		highp float a = 12.9898;
		highp float b = 78.233;
		highp float c = 43758.5453;
		highp float dt= dot(co.xy ,vec2(a,b));
		highp float sn= mod(dt,3.14);
		return fract(sin(sn) * c);
	}

	highp vec3 rand3(vec3 seed)
	{
		highp vec3 c = vec3(12.89898, 78.2333, 18.9823);
		highp float e = 43338.5453;
		highp vec3 dt = vec3(dot(seed.yyy, c.xyz), dot(seed.xzy, c.zyx), dot(seed.zxy, c.yzx));
		highp vec3 sn = mod(dt,3.14);
		
		return fract(sin(sn) * e);
	}

	float PHI = 1.61803398874989484820459;  // Φ = Golden Ratio   

	float gold_noise(in vec2 xy, in float seed){
		return fract(tan(distance(xy*PHI, xy)*seed)*xy.x);
	}

	vec3 gold_noise3d(vec3 xy, vec3 seed){
		return fract(tan(distance(xy*PHI, xy)*seed.xzy)*xy.xzy);
	}

	vec3 normalAtWorldPos(vec2 uvhm){
		vec4 nt = textureLod(normalTex, uvhm, 0.0).rgba; // X is R channel, Z is A channel, THANK YOU!
		float reconstructZ = sqrt(1.0 - (dot(nt.ra, nt.ra)));
		return vec3(nt.r, reconstructZ, nt.a);
	}

	vec3 Value2D_Deriv( vec2 P ){
		//  https://github.com/BrianSharpe/Wombat/blob/master/Value2D_Deriv.glsl

		//	establish our grid cell and unit position
		vec2 Pi = floor(P);
		vec2 Pf = P - Pi;

		//	calculate the hash.
		vec4 Pt = vec4( Pi.xy, Pi.xy + 1.0 );
		Pt = Pt - floor(Pt * ( 1.0 / 71.0 )) * 71.0;
		Pt += vec2( 26.0, 161.0 ).xyxy;
		Pt *= Pt;
		Pt = Pt.xzxz * Pt.yyww;
		vec4 hash = fract( Pt * ( 1.0 / 951.135664 ) );

		//	blend the results and return
		vec4 blend = Pf.xyxy * Pf.xyxy * ( Pf.xyxy * ( Pf.xyxy * ( Pf.xyxy * vec2( 6.0, 0.0 ).xxyy + vec2( -15.0, 30.0 ).xxyy ) + vec2( 10.0, -60.0 ).xxyy ) + vec2( 0.0, 30.0 ).xxyy );
		vec4 res0 = mix( hash.xyxz, hash.zwyw, blend.yyxx );
		return vec3( res0.x, 0.0, 0.0 ) + ( res0.yyw - res0.xxz ) * blend.xzw;
	}

	vec4 Value3D_Deriv( vec3 P ){ // returns noise in x, derivs in yzw
		//  https://github.com/BrianSharpe/Wombat/blob/master/Value3D_Deriv.glsl

		// establish our grid cell and unit position
		vec3 Pi = floor(P);
		vec3 Pf = P - Pi;
		vec3 Pf_min1 = Pf - 1.0;

		// clamp the domain
		Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
		vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

		// calculate the hash
		vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
		Pt *= Pt;
		Pt = Pt.xzxz * Pt.yyww;
		vec2 hash_mod = vec2( 1.0 / ( 635.298681 + vec2( Pi.z, Pi_inc1.z ) * 48.500388 ) );
		vec4 hash_lowz = fract( Pt * hash_mod.xxxx );
		vec4 hash_highz = fract( Pt * hash_mod.yyyy );

		//	blend the results and return
		vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
		vec3 blendDeriv = Pf * Pf * (Pf * (Pf * 30.0 - 60.0) + 30.0);
		vec4 res0 = mix( hash_lowz, hash_highz, blend.z );
		vec4 res1 = mix( res0.xyxz, res0.zwyw, blend.yyxx );
		vec4 res3 = mix( vec4( hash_lowz.xy, hash_highz.xy ), vec4( hash_lowz.zw, hash_highz.zw ), blend.y );
		vec2 res4 = mix( res3.xz, res3.yw, blend.x );
		return vec4( res1.x, 0.0, 0.0, 0.0 ) + ( vec4( res1.yyw, res4.y ) - vec4( res1.xxz, res4.x ) ) * vec4( blend.x, blendDeriv );
	}

	vec2 heighmapUVatWorldPos(vec2 worldpos){
		vec2 inverseMapSize = vec2(1.0) / mapSize.xy;
		// Some texel magic to make the heightmap tex perfectly align:
		vec2 heightmaptexel = vec2(8.0, 8.0);
		worldpos +=  vec2(-8.0, -8.0) * (worldpos * inverseMapSize) + vec2(4.0, 4.0) ;
		vec2 uvhm = clamp(worldpos, heightmaptexel, mapSize.xy - heightmaptexel);
		uvhm = uvhm	* inverseMapSize;
		return uvhm;
	}
#endif

#line 31000
void main(void)
{
	float deltaTime = frameTime; // 
	uint index = gl_GlobalInvocationID.x;
	uint lindex = gl_LocalInvocationID.x;
	float findex = float(index);
	
	vec4 position = posrot[index];
	vec4 velocity = velsize[index];
	vec4 originalpos_life_idx = origpos_life_idx[index];
	float particlesize = velocity.w;
	float life = originalpos_life_idx.z;
	
	// Gravity pulldown: this is definitely causing some instability at low frame rates, forcing landed particles to gather momentum
	velocity.y -= deltaTime * GRAVITY;
	 
	//Calculate the UV coordinates used for looking up heightmap, normal map and minimap color
	vec2 UVatWorldPos = heighmapUVatWorldPos(position.xz);
	// ********************************************************************
	// *****************************SNOW*********************************** 
	
	// move the particle with wind direction
	// prospectively check if it would collide with terrain


	
	// Gather the heightmap texels near the particle position
	vec4 heightMapNearby = textureGather(heightmapTex, UVatWorldPos, 0);
	// Calculate normal from the gathered heightmap texels

	// Assume texel offsets for dFdx/dFdy: left/right/up/down
	// textureGather returns: [left, right, up, down] (implementation-dependent, but this is common)
	float hL = heightMapNearby[0];
	float hR = heightMapNearby[1];
	float hU = heightMapNearby[2];
	float hD = heightMapNearby[3];

	// Compute texel size in world units
	vec2 texelSize = 1.0 / textureSize(heightmapTex, 0);

	// Calculate gradients
	float dHx = (hR - hL) / (2.0 * texelSize.x);
	//float dHz = (hU - hD) / (2.0 * texelSize.y);
	float dHz = (heightMapNearby[0] - heightMapNearby[3]) / (2.0 * texelSize.y);

	// Normal in tangent space (Y up)
	vec3 gatheredNormal = normalize(vec3(-dHx, 1.0, -dHz));
	// Calculate the ground height from the gathered texels, the texsize and the particle position:
	// Bilinear interpolation of the four gathered texels based on the particle's sub-texel position
	vec2 texCoord = UVatWorldPos * textureSize(heightmapTex, 0);
	vec2 f = fract(texCoord);

	// textureGather returns [left, right, up, down]
	// We'll treat [0]=left, [1]=right, [2]=up, [3]=down
	// Interpolate horizontally
	float h0 = mix(hL, hR, f.x);
	float h1 = mix(hD, hU, f.x);
	// Interpolate vertically
	float groundheight = mix(h0, h1, f.y) + particlesize;;
	
	//Calculate the ground height and height above ground
	
	float newheight = position.y + deltaTime * velocity.y;

	// Wind stuff

	// Make wind stronger near the ground?
	float heightAboveGround = max(0.0, position.y - max(groundheight, 0.0));

	float h = (0.01) *heightAboveGround;
    float proxwind = 0.2 + h*exp(1.0-h) * 1;


	vec3 windSpeed = vec3(windInfo.x * sqrt(windInfo.w), 0.0, windInfo.x * sqrt(windInfo.w)) * WINDSTRENGTH * proxwind;

	vec4 noise3DSample = Value3D_Deriv(position.xyz * NOISESCALE + timeInfo.z*0.01);
	
	windSpeed += noise3DSample.yzw * NOISESTRENGTH;
	
	// wind should be modulated by mapnormals at a low LOD:
	
	velocity.xz += windSpeed.xz * deltaTime* 10;	
	
	// Air resistance
	float velocitysquared = dot(velocity.xyz, velocity.xyz);
	velocity.xyz *= (1.0 - deltaTime * AIRRESISTANCE * velocitysquared / particlesize);
	

	
	// How much of the travel in this frame happens below ground 
	// to calculate pre-bounce travel
	float postbouncefraction = clamp(max(0, groundheight - newheight) / (position.y - newheight), 0.0, 1.0);
	
	position.xyz += deltaTime * velocity.xyz * (1.0 - postbouncefraction);
	
	
	// Fractional bounces should be handled

	
	//float groundheight =  textureLod(heightmapTex, UVatWorldPos, 0.0).x + 0.5;
	//Check if we are above the ground or not
	if (postbouncefraction > 0.01 ) { // This means that we will, at some point bounce into the ground now
			// If below ground, calculate the normal of the ground
			vec3 reflectdir = reflect(normalize(velocity.xyz), normalize(gatheredNormal.xyz + noise3DSample.yzw *0.25));
			//reflectdir = vec3(1*gatheredNormal.x,1,1*gatheredNormal.z);
			//vec3 reflectdir = normalize(gatheredNormal.xyz + noise3DSample.yzw *0.5);
			// Reflect our velocity direction along it, and reduce velocity due to non-elastic bounce
			velocity.xyz = reflectdir * length(velocity.xyz) * (0.1 + BOUNCEFACTOR) * max(noise3DSample.x, 0.0);
			position.xyz += deltaTime * velocity.xyz * postbouncefraction;
			//velocity.y += deltaTime * 1000;
			if (life > 0 ) life = 0.0; // reset life to 0, so it can fade out
	}else{
		// Above ground, but below water cool the particle and slow it down to a plonk
		if ( (position.y < 0 )){
			velocity.xyz = vec3(0, -20.0, 0); // drop down at a fixed -20 elmos per sec
			if (life > 0 ) life = -0.5 * MELTTIME; // reset life to 0, so it can fade out
		}
	}
	float heightabovemaporwater =  min((position.y - groundheight), groundheight);
	

	// With out updated velocity, move the particle
	//position.xyz += deltaTime * velocity.xyz;
	velocitysquared = dot(velocity.xyz, velocity.xyz);
	
	//If the particle slows down, or goes under ground or water, then bring it back to life with new parameters
	//if (((velocitysquared < 1.0) && (heightabovemaporwater < 4.0)) || (position.y < -150.0) || (life < 0.0)) {
	if ((life < (-1* MELTTIME)) || (position.y < -100.0) ||( position.y >  2.1 * STARTHEIGHT)) {
	
		life = LIFESTART;

		velocity.xyz = vec3(0.0);
		
		position.xz = originalpos_life_idx.xy;
		position.y = STARTHEIGHT* (1.0 + noise3DSample.x);
		//position.y = min(position.y, 600);
	}
	life = life - deltaTime;
	if (life > -1.0 * BOUNCETIME ){
		posrot[index]  = vec4(position.xyz, position.w );
		velsize[index] = vec4(velocity.xyz, particlesize);
	}
	origpos_life_idx[index] = vec4(originalpos_life_idx.xy, life, originalpos_life_idx.w); 
}
]]

local particleIndexVAO
-- one million snowflakes is indeed a hefty load, but we can do it!
local batchsize  = 512 -- smallest number of particles per emission
local patchsize = 512
local maxbatches = (Game.mapSizeX  / patchsize  + 2) * ( Game.mapSizeZ / patchsize + 2) -- 512x512 patches
local numParticles = batchsize*maxbatches
Spring.Echo("Snow particles: ", numParticles, " in ", maxbatches, " batches of ", batchsize, " particles each")

-- All these SSBOS are vec4's
local position_buffer 
local velocity_buffer
local origpos_life_idx_buffer
local position_index_buffer 

local snowflakes_buffer
 
-- ================================================= SHADER CONFIG =================================================
-- Collect all the lovely magic constants!
-- All timing factors are in seconds, and all distances are in elmos
local shaderConfig = {
	-- Compute Shader:
	AIRRESISTANCE = 0.0001,
	BOUNCEFACTOR = 0.5,
	GRAVITY = 90.0,
	NUMPARTICLES = numParticles,
	WINDSTRENGTH = 0.2, 
	NOISESCALE = 0.05,
	NOISESTRENGTH = 5.0,
	MELTTIME = 5.0, -- how long does it take for a particle to melt away
	LIFESTART = 60.0, -- initial life of a particle
	FADEINTIME = 3.0, -- how long does it take for a particle to fade in
	STARTHEIGHT = 2048,
	BOUNCETIME = 2.0, -- how long can aparticl bounce before it melts away

	-- Vertex Shader: what is your purpose? you pass vertices
	
	-- Geometry Shader:
	MAXDISTANCE = 1e8,
	MINDISTANCE = 5000,
	STRETCHFACTOR = 0.005,
	
	-- FRAGMENT Shader:
	SPINRATE = 0.1,
	DEBUG = DEBUG,
}

local random = math.random

-- We need to initialize the particles in blocks, so that the culling within the geometry shader runs efficiently in the right blocks as well .
-- We want to place blocks of particles in the map grid
-- Specifying the density of particles per grid 
-- We need to pad the edge of the map with grids as well, so we dont lose any extra 

local structSize = 16


local myt = 0
local function fillPosBuffer(data, px, py, pz )
	local tile = math.floor(math.sqrt(batchsize))
	myt = myt+ 1
	for i = 0, (batchsize-1) do 
		local x0 = px + random() * patchsize 
		local z0 = pz + random() * patchsize 
		--local x0 = px + (i % tile) 
		--local z0 = pz + math.floor(i / tile)
		local h0 = Spring.GetGroundHeight(x0, z0) 
		data[4* i + 1] = x0 
		data[4* i + 2] = h0 + 2* random() * py
		data[4* i + 3] = z0 
		data[4* i + 4] = i -- rot
	end
	return data
end

local function fillVelBuffer(data, size)
	local tile = math.floor(math.sqrt(batchsize))
	for i = 0, (batchsize-1) do 
		data[4* i + 1] = 0 
		data[4* i + 2] = 0
		data[4* i + 3] = 0
		data[4* i + 4] = size + random() * size -- size
	end
	return data
end


local function fillOrigBuffer(data)
	local tile = math.floor(math.sqrt(batchsize))
	for i = 0, (batchsize-1) do 
		data[4* i + 2] = data[4* i + 3]
		data[4* i + 3] = (shaderConfig.LIFESTART - shaderConfig.FADEINTIME) -- life
		data[4* i + 4] = i
	end
	return data
end

local function printt4(t)
	for i = 1, #t -3, 4 do
		Spring.Echo(i, ':', t[i], t[i+1], t[i+2], t[i+3])
	end
end
function widget:Initialize()
	--math.randomseed(1)

	local nx = Game.mapSizeX / patchsize
   	local nz = Game.mapSizeZ / patchsize

	local numParticles = batchsize * (nx + 2) * (nz + 2)
	
	position_buffer = gl.GetVBO(GL.SHADER_STORAGE_BUFFER)
	velocity_buffer = gl.GetVBO(GL.SHADER_STORAGE_BUFFER)
	origpos_life_idx_buffer = gl.GetVBO(GL.SHADER_STORAGE_BUFFER)
	position_index_buffer = gl.GetVBO(GL.ARRAY_BUFFER)

	
	position_buffer = gl.GetVBO(GL.SHADER_STORAGE_BUFFER)
	position_buffer:Define(numParticles, {{id = 4, name = "posrot"}} )
	velocity_buffer:Define(numParticles, {{id = 5, name = "velsize", size = 1, type = GL.FLOAT_VEC4}} )
	origpos_life_idx_buffer:Define(numParticles, {{id = 6, name = "origpos_life_idx", size = 1, type = GL.FLOAT_VEC4}} )
	position_index_buffer:Define(numParticles, {{id = 3, name = "posindex", size = 1, type = GL.UNSIGNED_INT}} )

	local dt = {}
	local i = 0
	local indices = {}
	for px = -1, nx , 1 do
		for pz = -1, nz ,1 do
			dt = fillPosBuffer(dt, px * patchsize, shaderConfig.STARTHEIGHT, pz * patchsize) 
			position_buffer:Upload(dt, nil, batchsize * i)

			dt = fillOrigBuffer(dt)
			origpos_life_idx_buffer:Upload(dt, nil, batchsize * i)

			dt = fillVelBuffer(dt, 1.0)
			velocity_buffer:Upload(dt, nil, batchsize * i)


			for j = 0, (batchsize-1) do indices[j+1] = i * batchsize + j  end 

			--Spring.Echo("Filling position buffer at patch ", #dt, #indices)
			position_index_buffer:Upload(indices, nil, batchsize * i)

			i = i + 1
		end
	end
	
	Spring.Echo("Done Uploading")

	--dl = position_buffer:Download()
	--Spring.Echo("position_buffer Downloaded: ", #dl, " elements")
	--printt4(dl)

	--dl = position_index_buffer:Download()
	--Spring.Echo("position_index_buffer Downloaded: ", #dl, " elements", 'compare to' , #indices )
	--printt4(dl)

	
	--[[
	local pcache = {}
	
	for i = 0,  (maxbatches-1) do 
		pcache = fillPosData(nil, nil, nil, 3.0, pcache)
		position_buffer:Upload(pcache, nil, batchsize * i)
	end
	position_buffer:BindBufferRange(4)
	
	velocity_buffer = gl.GetVBO(GL.SHADER_STORAGE_BUFFER)
	for i = 0,  (maxbatches-1) do 
		velocity_buffer:Upload(veldata, nil, batchsize * i)
	end
	velocity_buffer:BindBufferRange(5)
	
	
	VBO:Upload(iT.instanceData, -- The lua mirrored VBO data
		nil, -- the attribute index, nil for all attributes
		startElementIndex, -- vboOffset optional, , what ELEMENT offset of the VBO to start uploading into, 0 based
		startElementIndex * iT.instanceStep + 1, --  luaStartIndex, default 1, what element of the lua array to start uploading from. 1 is the 1st element of a lua table.
		endElementIndex * iT.instanceStep --] luaEndIndex, default #{array}, what element of the lua array to upload up to, inclusively
	)
   

   
   Spring.Echo("Initializing snow particles, this may take a while...", GL.FLOAT_MAT4)

   local nx = 2
   local ny = 2
	snowflakes_buffer = gl.GetVBO(GL.SHADER_STORAGE_BUFFER)
	--snowflakes_buffer:Define(batchsize*nx*ny, {{id = 6, name = "snowflakes1", size = 4},{id = 7, name = "snowflakes2", size = 4},{id = 8, name = "snowflakes3", size = 4},{id = 9, name = "snowflakes4", size = 4}} )
	snowflakes_buffer:Define(batchsize*nx*ny, {{id = 0, name = "snowflakes1", type = GL.FLOAT_MAT4, size = 16}})
	local batchNum = 0
	local bx = Game.mapSizeX / patchsize
	local bz = Game.mapSizeZ / patchsize



	for px = 0, nx - 1, 1 do
		for pz = 0, ny - 1,1 do
			--Spring.Echo("Filling snowflake buffer at patch ", px, pz)
			local sflakes = fillSnowflakeBuffer(px * patchsize,600,pz * patchsize, 10, 3.0)
				--Spring.Echo("VboData", vbodata)
				snowflakes_buffer:Upload(sflakes, nil, 
				batchNum * batchsize, -- VBOoffset, 0 based
				1,  -- luaStartIndex
				structSize* batchsize ) --luaEndIndex
			--snowflakes_buffer:Upload(sflakes, nil, (px/patchsize * (Game.mapSizeZ/patchsize) + pz/patchsize) * batchsize)
			batchNum = batchNum + 1
		end
	end
	truecount = batchNum * batchsize
	Spring.Echo("Snowflakes buffer filled with ", batchNum, " batches of ", batchsize, " particles each")
	snowflakes_buffer:BindBufferRange(4)

	
	local position_index_buffer = gl.GetVBO(GL.ARRAY_BUFFER)
	position_index_buffer:Define(batchsize*batchNum, {{id = 3, name = "posindex", size = 1, type = GL.UNSIGNED_INT}} )
	local posdata = {}
	for i= 0, batchNum -1 do
		for j = 0,  batchsize-1 do posdata[j] = i * batchsize + j end
		position_index_buffer:Upload(posdata, nil, i * batchsize)
		--Spring.Echo(i*batchsize)
	end
	]]--
	particleIndexVAO = gl.GetVAO()
	particleIndexVAO:AttachVertexBuffer(position_index_buffer) 
 
	local shaderSourceCache = {
		shaderName = 'Snow Shader',
		vsSrc = vsSrc,
		fsSrc = fsSrc,
		gsSrc = gsSrc,

		shaderConfig = shaderConfig,
		uniformInt = {
			particleTex = 0,
			shadowTex = 1, 
		},
		uniformFloat = {
			shadowpass = 0,
		},
		forceupdate = true,
	}

	particleShader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	
	if not particleShader then widgetHandler:RemoveWidget() end
	
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	
	local shaderDefinesString = LuaShader.CreateShaderDefinesString(shaderConfig)

	cmpSrc = cmpSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	cmpShader = LuaShader({
		compute = cmpSrc:gsub("//__DEFINES__", shaderDefinesString),
		uniformInt = {
			heightmapTex = 0,
			normalTex = 1,
			minimapTex = 2,
		},
		uniformFloat = {
			frameTime = 0.0000,
		}
	}, "Snow Compute Shader")
	
	local shaderCompiled = cmpShader:Initialize()
	Spring.Echo("Snow compute ready ", shaderCompiled)
	if not shaderCompiled then widgetHandler:RemoveWidget() end
end

function widget:Shutdown()
	if particleShader then	particleShader:Finalize() end
	if cmpShader then	cmpShader:Finalize()	end
	if position_buffer then position_buffer:Delete() end
	if velocity_buffer then velocity_buffer:Delete() end
	if particleIndexVAO then particleIndexVAO:Delete() end
	if snowflakes_buffer then snowflakes_buffer:Delete() end
	if position_index_buffer then position_index_buffer:Delete() end
	if origpos_life_idx_buffer then origpos_life_idx_buffer:Delete() end
end

local lastCmpFrame = Spring.GetGameFrame() + Spring.GetFrameTimeOffset() - 1

local FIRSTCOMPUTE = nil
local function RunCompute()

	position_buffer:BindBufferRange(4) -- dunno why, but if we dont, it gets lost after a few seconds
	velocity_buffer:BindBufferRange(5)
	origpos_life_idx_buffer:BindBufferRange(6)
	
	local nowt = Spring.GetGameFrame() + Spring.GetFrameTimeOffset()
	local deltat = (nowt - lastCmpFrame) / 30.0
	lastCmpFrame = nowt
	if not FIRSTCOMPUTE then
		Spring.Echo("Snow compute frame time: ", deltat)
		FIRSTCOMPUTE = true
		deltat= 0
	end	
	--Spring.Echo("Snow compute frame time: ", deltat)
	-- this is the compute part
	gl.Texture(0, '$heightmap')
	gl.Texture(1, '$normals')
	gl.Texture(2, '$minimap')
	gl.Texture(3, '$model_gbuffer_normtex')
	cmpShader:Activate()
	cmpShader:SetUniform("frameTime", math.min(1.0, math.max(deltat, 0.00001))) 
	gl.DispatchCompute((numParticles/32), 1, 1)
	--gl.DispatchCompute(numParticles/64, 1, 1)
	cmpShader:Deactivate()
end

function widget:DrawWorldPreParticles(drawAboveWater, drawBelowWater, drawReflection, drawRefraction)
	if drawAboveWater and not drawBelowWater and not drawReflection and not drawRefraction then
		return -- only draw on the first pass!
	end

	position_buffer:BindBufferRange(4) -- dunno why, but if we dont, it gets lost after a few seconds
	velocity_buffer:BindBufferRange(5)
	origpos_life_idx_buffer:BindBufferRange(6)
	

	-- this is the draw part
	--gl.DepthTest(true)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) --YES
	gl.DepthMask(false)	
	gl.Culling(false)
	gl.Texture(0, 'luaui/images/noisetextures/snowflake_4x4.png')
    gl.Texture(1, "$shadow")
	particleShader:Activate()
	particleShader:SetUniform("shadowpass",0)
	particleIndexVAO:DrawArrays(GL.POINTS)--, 2 * batchsize)
	particleShader:Deactivate()
	gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA) --YES
	
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthMask(false) --"BK OpenGL state resets", already commented out
	gl.DepthTest(true) --"BK OpenGL state resets", already commented out
end

function widget:DrawGenesis()
	RunCompute() -- pretty hefty, at about 50 watts for 1 million particles
end

function widget:DrawScreen()
	if particleShader.DrawPrintf then particleShader.DrawPrintf() end
end