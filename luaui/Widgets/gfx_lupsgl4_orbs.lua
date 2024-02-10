--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--https://gist.github.com/lhog/77f3fb10fed0c4e054b6c67eb24efeed#file-test_unitshape_instancing-lua-L177-L178

--------------------------------------------OLD AIRJETS---------------------------
function widget:GetInfo()
	return {
		name = "LUPS Orb GL4",
		desc = "Pretty orbs for Fusions, Shields and Junos",
		author = "Beherith, Shader by jK",
		date = "2024.02.10",
		license = "GNU GPL v2",
		layer = -1,
		enabled = true,
	}
end

local spGetUnitPieceInfo = Spring.GetUnitPieceInfo
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitPieceMap = Spring.GetUnitPieceMap
local spGetUnitIsActive = Spring.GetUnitIsActive
local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitTeam = Spring.GetUnitTeam
local glBlending = gl.Blending
local glTexture = gl.Texture

local GL_GREATER = GL.GREATER
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE = GL.ONE

local glAlphaTest = gl.AlphaTest
local glDepthTest = gl.DepthTest

local spValidUnitID = Spring.ValidUnitID

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
local defaults = {
	layer = -35,
	life = 600,
	light = 2.5,
	repeatEffect = true,
}

local corafusShieldSphere = table.merge(defaults, {
	pos = { 0, 60, 0 },
	size = 32,
	light = 4,
	--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
	--colormap2 = { {0.2, 0.2, 1, 0.7},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.7} },
})

local armafusShieldSphere = table.merge(defaults, {
	pos = { 0, 60, 0 },
	size = 28,
	light = 4.25,
	--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
	--colormap2 = { {0.2, 0.2, 1, 0.7},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.7} },
})

local corfusShieldSphere = table.merge(defaults, {
	pos = { 0, 51, 0 },
	size = 23,
	light = 3.25,
	--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
	--colormap2 = { {0.2, 0.6, 0.2, 0.4},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.4} },
})

local corgateShieldSphere = table.merge(defaults, {
	pos = { 0, 42, 0 },
	size = 11,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
})

local armjunoShieldSphere = table.merge(defaults, {
	pos = { 0, 72, 0 },
	size = 13,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.8, 0.2, 0.2, 0.4 }, { 0.8, 0.2, 0.2, 0.45 }, { 0.9, 0.2, 0.2, 0.45 }, { 0.9, 0.1, 0.2, 0.4 } },
})

local corjunoShieldSphere = table.merge(defaults, {
	pos = { 0, 72, 0 },
	size = 13,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.8, 0.2, 0.2, 0.4 }, { 0.8, 0.2, 0.2, 0.45 }, { 0.9, 0.2, 0.2, 0.45 }, { 0.9, 0.1, 0.2, 0.4 } },
})

local armgateShieldSphere = table.merge(defaults, {
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
	["resourcecheat"] = {
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
		{ class = 'ShieldSphere', options = table.merge(armgateShieldSphere, { pos = { 0, 25, 0 } }) },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,25,0}, size=555, precision=0, strength= 0.001, repeatEffect=true}},
	},
	["lootboxbronze"] = {
		{ class = 'ShieldSphere', options = table.merge(corfusShieldSphere,  {pos = { 0, 34, 0 }, size = 10} ) },
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 34, 0 }, size = 10.5, precision = 22, repeatEffect = true } },
	},
	["lootboxsilver"] = {
		{ class = 'ShieldSphere', options = table.merge(corfusShieldSphere,  {pos = { 0, 52, 0 }, size = 15} ) },
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 52, 0 }, size = 15.5, precision = 22, repeatEffect = true } },
	},
	["lootboxgold"] = {
		{ class = 'ShieldSphere', options = table.merge(corfusShieldSphere,  {pos = { 0, 69, 0 }, size = 20} ) },
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 69, 0 }, size = 20.5, precision = 22, repeatEffect = true } },
	},
	["lootboxplatinum"] = {
		{ class = 'ShieldSphere', options = table.merge(corfusShieldSphere,  {pos = { 0, 87, 0 }, size = 25} ) },
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 87, 0 }, size = 25.5, precision = 22, repeatEffect = true } },
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

local texture1 = "bitmaps/GPL/Lups/perlin_noise.jpg"    -- noise texture
--local texture1 = "luaui/images/perlin_noise_rgba_512.png"    -- noise texture
local texture2 = ":c:bitmaps/gpl/lups/jet2.bmp"        -- shape
local texture3 = ":c:bitmaps/GPL/Lups/jet.bmp"        -- jitter shape

for name, effects in pairs(effectDefs) do
end

--------------------------------------------------------------------------------
-- Variables
--------------------------------------------------------------------------------


local sphereVBO = nil
local orbVBO = nil
local orbShader = nil

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local vsSrc =
[[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normals;
layout (location = 2) in vec2 uvs;

layout (location = 3) in vec4 posrad; // time is gameframe spawned :D
layout (location = 4) in vec4 light_precision_gf_technique;
layout (location = 5) in vec4 color1;
layout (location = 6) in vec4 color2;
layout (location = 7) in uvec4 instData; // unitID, teamID, ??

out DataVS {
	flat vec4 color1_vs;
	flat vec4 color2_vs;
	flat float unitID_vs;
	flat float opac_vs;
	flat float gameFrame_vs;
	flat int technique_vs;
	vec4 modelPos_vs;
};

//__ENGINEUNIFORMBUFFERDEFS__

struct SUniformsBuffer {
    uint composite; //     u8 drawFlag; u8 unused1; u16 id;

    uint unused2;
    uint unused3;
    uint unused4;

    float maxHealth;
    float health;
    float unused5;
    float unused6;

    vec4 drawPos;
    vec4 speed;
    vec4[4] userDefined; //can't use float[16] because float in arrays occupies 4 * float space
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
    SUniformsBuffer uni[];
};


#line 10468
void main()
{
	vec3 modelWorldPos = uni[instData.y].drawPos.xyz;
	float modelRot = uni[instData.y].drawPos.w;
	mat3 rotY = rotation3dY(modelRot);
	
	vec4 vertexWorldPos = vec4(1);
	vertexWorldPos.xyz = rotY * ( position * posrad.w + posrad.xyz) + modelWorldPos;
	
	gl_Position = cameraViewProj * vertexWorldPos;
	
	color1_vs = color1;
	color2_vs = color2;
	modelPos_vs = modelWorldPos;
	
	technique_vs = int(floor(light_precision_gf_technique.w));
	
}
]]

local fsSrc =
[[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000
uniform sampler2D noiseMap;
uniform sampler2D mask;

//__ENGINEUNIFORMBUFFERDEFS__

uniform int reflectionPass = 0;

#define DISTORTION 0.01
in DataVS {
	flat vec4 color1_vs;
	flat vec4 color2_vs;
	flat float unitID_vs;
	flat float opac_vs;
	flat float gameFrame_vs;
	flat int technique_vs;
	vec4 modelPos_vs;
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

			#define time (gameFrame_vs * 0.03333333)

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
				fragColor = mix(color1_vs, color2_vs, opac_vs);

				if (technique_vs == 1) { // LightningOrb
					vec3 noiseVec = modelPos_vs.xyz;
					noiseVec = RotAroundY(noiseVec);
					vec2 vUv = (RadialCoords(noiseVec));
					vec3 col = LightningOrb(vUv, fragColor.rgb);
					fragColor.rgb = max(fragColor.rgb, col * col);
				}
				else if (technique_vs == 2) { // MagicOrb
					vec3 noiseVec = modelPos_vs.xyz;
					noiseVec = RotAroundY(noiseVec);
					vec3 col = MagicOrb(noiseVec, fragColor.rgb);
					fragColor.rgb = max(fragColor.rgb, col * col);
				}
				else if (technique_vs == 3) { // ElectroOrb
					vec3 noiseVec = modelPos_vs.xyz;
					noiseVec = RotAroundY(noiseVec);
					vec3 col = ElectroOrb(noiseVec, fragColor.rgb);
					fragColor.rgb = max(fragColor.rgb, col * col);
				}

				fragColor.a = length(fragColor.rgb);
				if (reflectionPass > 0) fragColor.rgba *= 3.0;
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
	orbShader =  LuaShader(
    {
      vertex = vsSrc,
      fragment = fsSrc,
      uniformInt = {
        noiseMap = 0,
        mask = 1,
        },
	uniformFloat = {
      },
    },
    "orbShader GL4"
  )
  shaderCompiled = orbShader:Initialize()
  if not shaderCompiled then goodbye("Failed to compile orbShader GL4 ") end
  local sphereVBO, numVerts, sphereIndexVBO, VBODataSize = makeSphereVBO(24,16,1)
  local orbVBOLayout = {
		  {id = 3, name = 'posrad', size = 4}, -- widthlength
		  {id = 4, name = 'light_precision_gf_technique', size = 4}, --  emit dir
		  {id = 5, name = 'color1', size = 4}, --- color
		  {id = 6, name = 'color2', size = 4}, --- color
		  {id = 7, name = 'instData', type = GL.UNSIGNED_INT, size= 4},
		}
  orbVBO = makeInstanceVBOTable(orbVBOLayout,256, "orbVBO", 5)
  orbVBO.numVertices = numVerts
  orbVBO.vertexVBO = sphereVBO
  orbVBO.VAO = makeVAOandAttach(orbVBO.vertexVBO, orbVBO.instanceVBO)
  orbVBO.primitiveType = GL.TRIANGLES
  orbVBO.indexVBO = sphereIndexVBO
  orbVBO.VAO:AttachIndexBuffer(orbVBO.indexVBO)
end

--------------------------------------------------------------------------------
-- Draw Iteration
--------------------------------------------------------------------------------
local function DrawOrbs(isReflection)
	if orbVBO.usedElements > 0 then
		
		gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove both state changes
		gl.Culling(false)
		orbShader:Activate()
		--orbShader:SetUniformInt("reflectionPass", ((isReflection == true) and 1) or 0)
		drawInstanceVBO(orbVBO)
		orbShader:Deactivate()
	end
end

--------------------------------------------------------------------------------
-- Unit Handling
--------------------------------------------------------------------------------

local function FinishInitialization(unitID, effectDef)
	local pieceMap = spGetUnitPieceMap(unitID)
	for i = 1, #effectDef do
		local fx = effectDef[i]
		if fx.piece then
			--Spring.Echo("FinishInitialization", fx.piece, pieceMap[fx.piece])
			fx.piecenum = pieceMap[fx.piece]
		end
		fx.width = fx.width*1.2
		fx.length = fx.length*1.4
	end
	effectDef.finishedInit = true
end

--------------------------------------------------------------------------------
-- Widget Interface
--------------------------------------------------------------------------------

function widget:DrawWorld()
	DrawOrbs(false)
end

function widget:DrawWorldReflection()
	--DrawOrbs(true)
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	initGL4()
	reInitialize()
end

local instanceCache = {}
for i =1,20 do instanceCache[i] = 0 end
function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam, noupload)
	--Spring.Echo("widget:VisibleUnitAdded",unitID, unitDefID, unitTeam, noupload)
	unitTeam = unitTeam or spGetUnitTeam(unitID)
	
	local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
	if buildProgress < 1 then return end

	instanceCache[1] =  unitRange[unitDefID] 
		pushElementInstance(circleInstanceVBO,
		instanceCache,
		unitID, --key
		true, -- updateExisting
		noupload,
		unitID -- unitID for uniform buffers
	)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	-- Note that this unit uses its own VisibleUnitsChanged, to handle the case where we go into fullview.
	--InitializeUnits()
end

function widget:VisibleUnitRemoved(unitID)
	if circleInstanceVBO.instanceIDtoIndex[unitID] then
		popElementInstance(circleInstanceVBO, unitID)
	end
end

function widget:Shutdown()
	for unitID, unitDefID in pairs(activePlanes) do
		RemoveUnit(unitID, unitDefID, spGetUnitTeam(unitID))
	end
end
