--------------------------------------------------------------------------------
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
-- TODO: gl_NormalMatrix seems wrong
-- Load stuff on init
-- on playerchanged shit dont reload for specs
--
 
local TESTSPHERES = false

--------------------------------------------------------------------------------
-- Configuration

local function MergeTable(table1, table2)
	local result = {}
	for i, v in pairs(table2) do
		if type(v) == 'table' then
			result[i] = MergeTable(v, {})
		else
			result[i] = v
		end
	end
	for i, v in pairs(table1) do
		if result[i] == nil then
			if type(v) == 'table' then
				if type(result[i]) ~= 'table' then
					result[i] = {}
				end
				result[i] = MergeTable(v, result[i])
			else
				result[i] = v
			end
		end
	end
	return result
end

local defaults = {
	layer = -35,
	life = 20,
	light = 2,
	repeatEffect = true,
}

local corafusShieldSphere = MergeTable(defaults, {
	pos = { 0, 60, 0 },
	size = 32,
	light = 3.25,
	--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
	--colormap2 = { {0.2, 0.2, 1, 0.7},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.7} },
})

local armafusShieldSphere = MergeTable(defaults, {
	pos = { 0, 60, 0 },
	size = 28,
	light = 3.5,
	--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
	--colormap2 = { {0.2, 0.2, 1, 0.7},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.7} },
})

local corfusShieldSphere = MergeTable(defaults, {
	pos = { 0, 51, 0 },
	size = 23,
	light = 2.75,
	--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
	--colormap2 = { {0.2, 0.6, 0.2, 0.4},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.4} },
})

local corgateShieldSphere = MergeTable(defaults, {
	pos = { 0, 42, 0 },
	size = 11,
	light = 2.5,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
})

local armjunoShieldSphere = MergeTable(defaults, {
	pos = { 0, 72, 0 },
	size = 13,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.8, 0.2, 0.2, 0.4 }, { 0.8, 0.2, 0.2, 0.45 }, { 0.9, 0.2, 0.2, 0.45 }, { 0.9, 0.1, 0.2, 0.4 } },
})

local corjunoShieldSphere = MergeTable(defaults, {
	pos = { 0, 72, 0 },
	size = 13,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.8, 0.2, 0.2, 0.4 }, { 0.8, 0.2, 0.2, 0.45 }, { 0.9, 0.2, 0.2, 0.45 }, { 0.9, 0.1, 0.2, 0.4 } },
})

local armgateShieldSphere = MergeTable(defaults, {
	pos = { 0, 23.5, -5 },
	size = 14.5,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
})

local corgateShieldSphere = MergeTable(defaults, {
	pos = { 0, 42, 0 },
	size = 11,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
})

local armjunoShieldSphere = MergeTable(defaults, {
	pos = { 0, 72, 0 },
	size = 13,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.8, 0.2, 0.2, 0.4 }, { 0.8, 0.2, 0.2, 0.45 }, { 0.9, 0.2, 0.2, 0.45 }, { 0.9, 0.1, 0.2, 0.4 } },
})

local corjunoShieldSphere = MergeTable(defaults, {
	pos = { 0, 72, 0 },
	size = 13,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.8, 0.2, 0.2, 0.4 }, { 0.8, 0.2, 0.2, 0.45 }, { 0.9, 0.2, 0.2, 0.45 }, { 0.9, 0.1, 0.2, 0.4 } },
})

local armgateShieldSphere = MergeTable(defaults, {
	pos = { 0, 23.5, -5 },
	size = 14.5,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
})

local UnitEffects = {
	["armjuno"] = {
		{ class = 'ShieldSphere', options = armjunoShieldSphere },
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 72, 0 }, size = 14, precision = 22, repeatEffect = true } },
	},
	["corjuno"] = {
		{ class = 'ShieldSphere', options = corjunoShieldSphere },
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 72, 0 }, size = 14, precision = 22, repeatEffect = true } },
	},

	--// FUSIONS //--------------------------
	["corafus"] = {
		{ class = 'ShieldSphere', options = corafusShieldSphere },
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 60, 0 }, size = 32.5, precision = 22, repeatEffect = true } },
	},
	["corfus"] = {
		{ class = 'ShieldSphere', options = corfusShieldSphere },
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 50, 0 }, size = 23.5, precision = 22, repeatEffect = true } },
	},
	["armafus"] = {
		{ class = 'ShieldSphere', options = armafusShieldSphere },
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 60, 0 }, size = 28.5, precision = 22, repeatEffect = true } },
	},
	["corgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 42, 0 }, size = 12, precision = 22, repeatEffect = true } },
		{ class = 'ShieldSphere', options = corgateShieldSphere },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,42,0.0}, size=555, precision=0, strength= 0.001, repeatEffect=true}},
		--{class='ShieldJitter',options={life=math.huge, pos={0,42,0}, size=20, precision=2, repeatEffect=true}},
	},
	["corfgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 42, 0 }, size = 12, precision = 22, repeatEffect = true } },
		{ class = 'ShieldSphere', options = corgateShieldSphere },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,42,0.0}, size=555, precision=0, strength= 0.001, repeatEffect=true}},
		--{class='ShieldJitter',options={life=math.huge, pos={0,42,0}, size=20, precision=2, repeatEffect=true}},
	},
	["armgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 23.5, -5 }, size = 15, precision = 22, repeatEffect = true } },
		{ class = 'ShieldSphere', options = armgateShieldSphere },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,23.5,-5}, size=555, precision=0, strength=0.001, repeatEffect=true}},
	},
	["armfgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 25, 0 }, size = 15, precision = 22, repeatEffect = true } },
		{ class = 'ShieldSphere', options = MergeTable(armgateShieldSphere, { pos = { 0, 25, 0 } }) },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,25,0}, size=555, precision=0, strength= 0.001, repeatEffect=true}},
	},

}

local scavEffects = {}
if UnitDefNames['armcom_scav'] then
	for k, effect in pairs(UnitEffects) do
		scavEffects[k .. '_scav'] = effect
		if scavEffects[k .. '_scav'].options then
			if scavEffects[k .. '_scav'].options.color then
				scavEffects[k .. '_scav'].options.color = { 0.92, 0.32, 1.0 }
			end
			if scavEffects[k .. '_scav'].options.colormap then
				scavEffects[k .. '_scav'].options.colormap = { { 0.92, 0.32, 1.0 } }
			end
			if scavEffects[k .. '_scav'].options.colormap1 then
				scavEffects[k .. '_scav'].options.colormap1 = { { 0.92, 0.32, 1.0 } }
			end
			if scavEffects[k .. '_scav'].options.colormap2 then
				scavEffects[k .. '_scav'].options.colormap2 = { { 0.92, 0.32, 1.0 } }
			end
		end
	end
	for k, effect in pairs(scavEffects) do
		UnitEffects[k] = effect
	end
	scavEffects = nil
end

local newEffects = {}
for unitname, effect in pairs(UnitEffects) do
	newEffects[UnitDefNames[unitname].id] = effect
end
UnitEffects = newEffects
newEffects = nil

local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local mySpec, fullview = Spring.GetSpectatingState()

local abs = math.abs
local spGetSpectatingState = Spring.GetSpectatingState
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitIsActive = Spring.GetUnitIsActive
local IsUnitInLos = Spring.IsUnitInLos
local IsPosInLos = Spring.IsPosInLos
local GetUnitPosition = Spring.GetUnitPosition

local particleIDs = {}
local lightIDs = {} -- maps unitID to lightID
--------------------------------------------------------------------------------

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

		gl.AlphaTest(true)
		gl.DepthMask(false)
		gl.DepthTest(true)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

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
	-- TODO: periodically check if still active?
end


local function TeamColorizeShieldSphere(unitID)
	-- apply teamcoloring for default
	local r,g,b = Spring.GetTeamColor(Spring.GetUnitTeam(unitID))
	local c1 = {(r*0.45)+0.3, (g*0.45)+0.3, (b*0.45)+0.3, 0.6}
	local c2 = {r*0.5, g*0.5, b*0.5, 0.66} 
	return c1, c2
end

local function addUnit(unitID, unitDefID)
	if UnitEffects[unitDefID] == nil then return end
	for _, fx in ipairs(UnitEffects[unitDefID]) do
		local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth( unitID)
		if buildProgress >= 1 then
			if fx.class == "ShieldSphere" then
				
				local c1, c2 = TeamColorizeShieldSphere(unitID)
				
				local x,y,z  = Spring.GetUnitPosition(unitID)
				x = x + fx.options.pos[1] + 10
				y = y + fx.options.pos[2] + 0 -- TODO: REMOVE THIS FOR DEBUGGING
				z = z + fx.options.pos[3] + 10
				
				if fx.options.colormap1 and fx.options.colormap1[1] then
					c1 = fx.options.colormap1[1]
				end
				
				if fx.options.colormap2 and fx.options.colormap2[1] then
					c2 = fx.options.colormap2[1]
				end
				
				pushElementInstance(
					shieldSphereInstanceVBO,
					{
						x,y,z,fx.options.size,
						c1[1], c1[2], c1[3], c1[4],
						c2[1], c2[2], c2[3], c2[4],
						1, 1, Spring.GetGameFrame(), unitID/65000, --// margin, technique, gameFrame, unitID/65k
					},
					unitID, -- key, use unitID!
					true -- update exisiting
				)
				
				-- add blinkies: 
				if WG['lighteffects'] and WG['lighteffects'].createLight and fx.options.light and (lightIDs[unitID] == nil) then
					c2[4] = fx.options.light * 0.66 
					local lightID = WG['lighteffects'].createLight('shieldsphere',x,y,z, fx.options.size*6, c2)
					lightIDs[unitID] = lightID
				end 
			end
		end
	end
end

local function CheckForExistingUnits()
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = Spring.GetUnitDefID(unitID)
		addUnit(unitID, unitDefID)
	end
end

function widget:Initialize()
	initGL4()

	if TESTSPHERES then
		
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
	
		math.randomseed(1)
		for i=1, 500 do
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
	
	CheckForExistingUnits()
end


local function AddFxs(unitID, fxID)
	if not particleIDs[unitID] then
		particleIDs[unitID] = {}
	end
	particleIDs[unitID][#particleIDs[unitID] + 1] = fxID
end


function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if UnitEffects[unitDefID] then
		addUnit(unitID, unitDefID)
	end
end

function widget:UnitDestroyed(unitID, unitDefID)
	if UnitEffects[unitDefID] then
		popElementInstance(shieldSphereInstanceVBO, unitID)
	end
	if lightIDs[unitID] and WG['lighteffects'] and WG['lighteffects'].removeLight then
		WG['lighteffects'].removeLight(lightIDs[unitID])
		lightIDs[unitID] = nil
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	widget:UnitDestroyed(unitID, unitDefID, oldTeam)
	widget:UnitFinished(unitID, unitDefID, newTeam)
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	widget:UnitDestroyed(unitID, unitDefID, oldTeam)
	widget:UnitFinished(unitID, unitDefID, newTeam)
end

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if UnitEffects[unitDefID] then
		addUnit(unitID, unitDefID)
	end
end

function widget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	if UnitEffects[unitDefID] then
		widget:UnitDestroyed(unitID,unitDefID)
	end
end

local function removeParticles()
	clearInstanceTable(shieldSphereInstanceVBO)
end

function widget:PlayerChanged(playerID)
	if playerID == myPlayerID then
		myTeamID = Spring.GetMyTeamID()
		if fullview ~= select(2, Spring.GetSpectatingState()) then
			mySpec, fullview = Spring.GetSpectatingState()
			removeParticles()
			CheckForExistingUnits()
		end
	end
end

function widget:Shutdown()
	removeParticles()
end

