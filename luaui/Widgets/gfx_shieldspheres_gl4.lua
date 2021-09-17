--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--https://gist.github.com/lhog/77f3fb10fed0c4e054b6c67eb24efeed#file-test_unitshape_instancing-lua-L177-L178

--------------------------------------------OLD AIRJETS---------------------------
function widget:GetInfo()
	return {
		name = "ShieldSpheres GL4",
		desc = "The spheres that glow above fusions and junos",
		author = "jK, Beherith",
		date = "2021.09.16",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true,
	}
end

-- GL4 notes
-- Needs an atlassed PBR input?
-- Always a square, maybe with 4 cardinal direction possible rotations?
-- Should be able to output at least an 8x8 subdivided decal
-- Decals should have a lifetime param, with a table tracking their expected deaths
-- 'permanent' decals assigned to units too
-- Nice normal maps too
-- since we have 1024 elements in geom shader output, use those wisely (8x8 square)
-- Depth test should be less deep than other shit
-- should it write to map deferred buffer? (would be best if it did)
-- maybe position could be assigned to track units
-- how to deal with multiple, overlapping scars? additional Z sort by lifetime?
-- add some Z in fragment shader to hack around depth testing? Do double transforms and lift it up?
-- This should probably be a gadget tbh
-- Each decal should have a:
-- A. diffuse texture with teamcolor in alpha
-- An (optional) glow, metalness, roughness, transparency
-- A normal map (with optional alpha)? 
-- geometry shader is needed for faster occlusion culling!

-- we ideally should be using the new atlas texture framework for this!

-- Decal Attributes
-- vec4 Center XYZ, radius (or width)
-- rotation (only around Y)
-- fade in rate, fadeout start time, fadeout rate, lifetime
-- texture offsets (for atlasses, this should be 3 vec4's (ugh)
-- additional vec4 custom stuff:
	-- Rotate rate
	-- fade period
	-- colormod RGBA (multiply) 
-- 

-- VS to GS passthrough:
-- Everything above

-- GS to FS passthrough:
-- worldpos XYZW
-- normal XYZW
-- TEXCOORD 0, 1, 2
-- entire fucking TBN matrix?
-- colormod * fade
-- This is 4+4+4+6 ~ 20 out of 1024? ugh we may need to pack more for 64 verts?
-- ugh 1024 floats is max? thats shit
-- for a 6x6 we need like 50 verts :/
 

local decaldefs = { -- the only real 
	scar1 = { 
		tex1 = "bitmaps/scars/scar1.bmp",
		tex2 = "bitmaps/scars/scar1.bmp",
		normals = "bitmaps/scars/scar1.bmp",
		texsize = 256, -- this is needed so that the atlas knows how big it should get
		rotstart = 0.2, 
		size = 250,
		fadein = 0.1,
		fadeoutstart = 1000,
		fadeoutrate = 0.01,
		lifetime = 5000,
		rotationrate = 0.01,
		fadeperiod = 0.07,
		colormod = {1.0, 1.0, 1.0, 1.0},
	}
}

--------------------------------------------------------------------------------
-- Configuration

local shieldSphereInstanceVBO = nil
local shieldSphereShader = nil

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local vsSrc =  
[[
#version 420
#line 10000

//__DEFINES__

layout (location = 0) in vec4 position; // from sphereVBO
layout (location = 1) in vec4 texcoord;
layout (location = 2) in vec4 normals;


layout (location = 3) in vec4 positionradius;
layout (location = 4) in vec4 color1;
layout (location = 5) in vec4 color2;
layout (location = 6) in vec4 others;  // margin, technique, gameFrame, self.unit/65k

//uniform float circleopacity; 

//uniform sampler2D heightmapTex;

out DataVS {
	vec4 worldPos; // pos and radius
	vec4 blendedcolor;
	float opac;
	vec4 vscolor1;
	vec4 vscolor2;
	vec4 modelPos;
	float unitID;
	flat int technique;
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000
#define pos positionradius.xyz
#define margin others.x
#define size vec4(positionradius.www, 1.0)

//	glMultiTexCoord(1, color[1], color[2], color[3], color[4] or 1)
//	color = self.color2
//	glMultiTexCoord(2, color[1], color[2], color[3], color[4] or 1)
//	local pos = self.pos
//	glMultiTexCoord(3, pos[1], pos[2], pos[3], self.technique or 0)
//	glMultiTexCoord(4, self.margin, self.size, gameFrame, self.unit / 65535.0)

void main()
{

	unitID = others.w;
	modelPos = position;

	technique = int(floor(others.y));

	gl_Position = cameraViewProj * (modelPos * size + vec4(pos, 0.0));
	
	gl_Position = cameraViewProj * (vec4(position.xyz * positionradius.w, 1.0) + vec4(positionradius.xyz,0.0));
	//vec3 normalMatrix = transpose(inverse(cameraView))
	//vec3 normal = gl_NormalMatrix * normals.xyz;
	vec3 normal = normals.xyz;
	//normal = (cameraViewProj * vec4(normals.xyz,1.0)).xyz;
	vec3 vertex = vec3(cameraView * position.xyzw).xyz;
	float angle = dot(normal,vertex)*inversesqrt( dot(normal,normal)*dot(vertex,vertex) ); //dot(norm(n),norm(v))
	opac = pow( abs( angle ) , margin);

	vscolor1 = color1;
	vscolor2 = color2;
}

]]

local fsSrc =
[[
#version 420
#line 20000
uniform sampler2D noiseMap;
uniform sampler2D mask;

//__ENGINEUNIFORMBUFFERDEFS__

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

in DataVS {
	vec4 worldPos; // pos and radius
	vec4 blendedcolor;
	float opac;
	vec4 vscolor1;
	vec4 vscolor2;
	vec4 modelPos;
	float unitID;
	flat int technique;
};

out vec4 fragColor;

			const float PI = acos(0.0) * 2.0;

			float hash13(vec3 p3) {
				const float HASHSCALE1 = 44.38975;
				p3  = fract(p3 * HASHSCALE1);
				p3 += dot(p3, p3.yzx + 19.19);
				return fract((p3.x + p3.y) * p3.z);
			}

			float noise12(vec2 p){
				vec2 ij = floor(p);
				vec2 xy = fract(p);
				xy = 3.0 * xy * xy - 2.0 * xy * xy * xy;
				//xy = 0.5 * (1.0 - cos(PI * xy));
				float a = hash13(vec3(ij + vec2(0.0, 0.0), unitID));
				float b = hash13(vec3(ij + vec2(1.0, 0.0), unitID));
				float c = hash13(vec3(ij + vec2(0.0, 1.0), unitID));
				float d = hash13(vec3(ij + vec2(1.0, 1.0), unitID));
				float x1 = mix(a, b, xy.x);
				float x2 = mix(c, d, xy.x);
				return mix(x1, x2, xy.y);
			}

			float noise13( vec3 P ) {
				//  https://github.com/BrianSharpe/Wombat/blob/master/Perlin3D.glsl

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
				const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
				const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
				vec3 lowz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi.zzz * ZINC ) );
				vec3 highz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi_inc1.zzz * ZINC ) );
				vec4 hashx0 = fract( Pt * lowz_mod.xxxx );
				vec4 hashx1 = fract( Pt * highz_mod.xxxx );
				vec4 hashy0 = fract( Pt * lowz_mod.yyyy );
				vec4 hashy1 = fract( Pt * highz_mod.yyyy );
				vec4 hashz0 = fract( Pt * lowz_mod.zzzz );
				vec4 hashz1 = fract( Pt * highz_mod.zzzz );

				// calculate the gradients
				vec4 grad_x0 = hashx0 - 0.49999;
				vec4 grad_y0 = hashy0 - 0.49999;
				vec4 grad_z0 = hashz0 - 0.49999;
				vec4 grad_x1 = hashx1 - 0.49999;
				vec4 grad_y1 = hashy1 - 0.49999;
				vec4 grad_z1 = hashz1 - 0.49999;
				vec4 grad_results_0 = inversesqrt( grad_x0 * grad_x0 + grad_y0 * grad_y0 + grad_z0 * grad_z0 ) * ( vec2( Pf.x, Pf_min1.x ).xyxy * grad_x0 + vec2( Pf.y, Pf_min1.y ).xxyy * grad_y0 + Pf.zzzz * grad_z0 );
				vec4 grad_results_1 = inversesqrt( grad_x1 * grad_x1 + grad_y1 * grad_y1 + grad_z1 * grad_z1 ) * ( vec2( Pf.x, Pf_min1.x ).xyxy * grad_x1 + vec2( Pf.y, Pf_min1.y ).xxyy * grad_y1 + Pf_min1.zzzz * grad_z1 );

				// Classic Perlin Interpolation
				vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
				vec4 res0 = mix( grad_results_0, grad_results_1, blend.z );
				vec4 blend2 = vec4( blend.xy, vec2( 1.0 - blend.xy ) );
				float final = dot( res0, blend2.zxzx * blend2.wwyy );
				return ( final * 1.1547005383792515290182975610039 );  // scale things to a strict -1.0->1.0 range  *= 1.0/sqrt(0.75)
			}

			float Fbm12(vec2 P) {
				const int octaves = 2;
				const float lacunarity = 1.5;
				const float gain = 0.49;

				float sum = 0.0;
				float amp = 1.0;
				vec2 pp = P;

				int i;

				for(i = 0; i < octaves; ++i)
				{
					amp *= gain;
					sum += amp * noise12(pp);
					pp *= lacunarity;
				}
				return sum;
			}

			float Fbm31Magic(vec3 p) {
				 float v = 0.0;
				 v += noise13(p * 1.0) * 2.200;
				 v -= noise13(p * 4.0) * 3.125;
				 return v;
			}

			float Fbm31Electro(vec3 p) {
				 float v = 0.0;
				 v += noise13(p * 0.9) * 0.99;
				 v += noise13(p * 3.99) * 0.49;
				 v += noise13(p * 8.01) * 0.249;
				 v += noise13(p * 15.05) * 0.124;
				 return v;
			}

			#define SNORM2NORM(value) (value * 0.5 + 0.5)
			#define NORM2SNORM(value) (value * 2.0 - 1.0)

			#define time (timeInfo.x * 0.03333333)

			vec3 LightningOrb(vec2 vUv, vec3 color) {
				vec2 uv = NORM2SNORM(vUv);

				const float strength = 0.01;
				const float dx = 0.1;

				float t = 0.0;

				for (int k = -4; k < 14; ++k) {
					vec2 thisUV = uv;
					thisUV.x -= dx * float(k);
					thisUV.y += float(k);
					t += abs(strength / ((thisUV.x + Fbm12( thisUV + time ))));
				}

				return color * t;
			}

			vec3 MagicOrb(vec3 noiseVec, vec3 color) {
				float t = 0.0;

				for( int i = 1; i < 2; ++i ) {
					t = abs(2.0 / ((noiseVec.y + Fbm31Magic( noiseVec + 0.5 * time / float(i)) ) * 75.0));
					t += 1.3 * float(i);
				}
				return color * t;
			}

			vec3 ElectroOrb(vec3 noiseVec, vec3 color) {
				float t = 0.0;

				for( int i = 0; i < 5; ++i ) {
					noiseVec = noiseVec.zyx;
					t = abs(2.0 / (Fbm31Electro(noiseVec + vec3(0.0, time / float(i + 1), 0.0)) * 120.0));
					t += 0.2 * float(i + 1);
				}

				return color * t;
			}

			vec2 RadialCoords(vec3 a_coords)
			{
				vec3 a_coords_n = normalize(a_coords);
				float lon = atan(a_coords_n.z, a_coords_n.x);
				float lat = acos(a_coords_n.y);
				vec2 sphereCoords = vec2(lon, lat) / PI;
				return vec2(sphereCoords.x * 0.5 + 0.5, 1.0 - sphereCoords.y);
			}

			vec3 RotAroundY(vec3 p)
			{
				float ra = -time * 1.5;
				mat4 tr = mat4(cos(ra), 0.0, sin(ra), 0.0,
							   0.0, 1.0, 0.0, 0.0,
							   -sin(ra), 0.0, cos(ra), 0.0,
							   0.0, 0.0, 0.0, 1.0);

				return (tr * vec4(p, 1.0)).xyz;
			}


void main(void)
{
fragColor = mix(vscolor1, vscolor2, opac);

if (technique == 1) { // LightningOrb
	vec3 noiseVec = modelPos.xyz;
	noiseVec = RotAroundY(noiseVec);
	vec2 vUv = (RadialCoords(noiseVec));
	vec3 col = LightningOrb(vUv, fragColor.rgb);
	fragColor.rgb = max(fragColor.rgb, col * col);
}
else if (technique == 2) { // MagicOrb
	vec3 noiseVec = modelPos.xyz;
	noiseVec = RotAroundY(noiseVec);
	vec3 col = MagicOrb(noiseVec, fragColor.rgb);
	fragColor.rgb = max(fragColor.rgb, col * col);
}
else if (technique == 3) { // ElectroOrb
	vec3 noiseVec = modelPos.xyz;
	noiseVec = RotAroundY(noiseVec);
	vec3 col = ElectroOrb(noiseVec, fragColor.rgb);
	fragColor.rgb = max(fragColor.rgb, col * col);
}

fragColor.a = length(fragColor.rgb);
//fragColor = vec4(1.0);
}

]]
	
	


local function goodbye(reason)
  Spring.Echo("Airjet GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end


local function initGL4()

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	shieldSphereShader =  LuaShader(
    {
      vertex = vsSrc,
      fragment = fsSrc,
      --geometry = gsSrc, no geom shader for now
      uniformInt = {
        noiseMap = 0,
        mask = 1,
        },
	uniformFloat = {
        shieldSphereuniforms = {1,1,1,1}, --unused
      },
    },
    "shieldSphereShader GL4"
  )
  shaderCompiled = shieldSphereShader:Initialize()
  if not shaderCompiled then goodbye("Failed to compile shieldSphereShader GL4 ") end
  local sphereVBO,numVertices = makeSphereVBO(0,0,0,1,32) --centerx, centery, centerz, radius, precision
  local shieldSphereInstanceVBOLayout = {
		  {id = 3, name = 'positionradius', size = 4}, -- posradius
		  {id = 4, name = 'color1', size = 4}, --  color1
		  {id = 5, name = 'color2', size = 4}, --- color2
		  {id = 6, name = 'others',  size= 4}, -- margin, technique, gameFrame, self.unit/65k
		}
  shieldSphereInstanceVBO = makeInstanceVBOTable(shieldSphereInstanceVBOLayout,256, "shieldSphereInstanceVBO")
  shieldSphereInstanceVBO.numVertices = numVertices
  shieldSphereInstanceVBO.vertexVBO = sphereVBO
  shieldSphereInstanceVBO.VAO = makeVAOandAttach(shieldSphereInstanceVBO.vertexVBO, shieldSphereInstanceVBO.instanceVBO)
  shieldSphereInstanceVBO.primitiveType = GL.TRIANGLES
  shieldSphereInstanceVBO.primitiveType = GL.TRIANGLE_STRIP
  
  
	local foobar = 1
	local i = 0
	repeat
		local k, v = debug.getlocal(2, i)
		--if k then
			Spring.Echo(k, v)
			i = i + 1
		--end
	until nil == k
	--Spring.Echo(i,1)
end



--------------------------------------------------------------------------------
-- Draw Iteration
--------------------------------------------------------------------------------


function widget:DrawWorld()
	-- validate unitID buffer
	if shieldSphereInstanceVBO.usedElements > 0 then
		--Spring.Echo("Drawing shieldspheres",shieldSphereInstanceVBO.usedElements)
		--gl.DepthTest(true)
		gl.AlphaTest(true)
		gl.Culling(GL.FRONT)
		gl.DepthMask(false)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

		--glBlending(GL_ONE, GL_ONE)
		shieldSphereShader:Activate()
		
		drawInstanceVBO(shieldSphereInstanceVBO)
		
		shieldSphereShader:Deactivate()


		--glAlphaTest(false)
		--glDepthTest(false)
	end
	
end


	

--------------------------------------------------------------------------------
-- Widget Interface
--------------------------------------------------------------------------------

function widget:Update(dt)
	if shieldSphereInstanceVBO.usedElements < 50 then
	
		local x = 3000*math.random()
		local z =  3000*math.random()
		local y = Spring.GetGroundHeight(x,z) + math.random()*100
		pushElementInstance(
			shieldSphereInstanceVBO,
			{
				x,y,z,200*math.random(),
				math.random(),math.random(),math.random(),math.random(),
				math.random(),math.random(),math.random(),math.random(),
				1, math.floor(math.random()*3), 1, 0.5, --// margin, technique, gameFrame, self.unit/65k
				-- this is needed to keep the lua copy of the vbo the correct size
			},
			nil, -- key, use unitID!
			true -- update exisiting
			)
	end
end


function widget:Initialize()
	--shaders = CreateShader()
	
	initGL4()
	
	math.randomseed(1)
	pushElementInstance(
		shieldSphereInstanceVBO,
		{
			200,200,200,200,
			1,1,1,1,
			1,1,1,1,
			1, 1, 1, 0.5, --// margin, technique, gameFrame, self.unit/65k
			-- this is needed to keep the lua copy of the vbo the correct size
		},
		nil, -- key, use unitID!
		true -- update exisiting
		)
	for i=1, 50 do
	
		local x = 3000*math.random()
		local z =  3000*math.random()
		local y = Spring.GetGroundHeight(x,z) + math.random()*100
		pushElementInstance(
			shieldSphereInstanceVBO,
			{
				x,y,z,200*math.random(),
				math.random(),math.random(),math.random(),math.random(),
				math.random(),math.random(),math.random(),math.random(),
				1, math.floor(math.random()*3), 1, 0.5, --// margin, technique, gameFrame, self.unit/65k
				-- this is needed to keep the lua copy of the vbo the correct size
			},
			nil, -- key, use unitID!
			true -- update exisiting
			)
	end

	--[[
	WG['airjets'].removeAirJet =  function (airjetkey) ---- for WG external calls
		return popElementInstance(jetInstanceVBO,airjetkey)
	end
	]]--
end


