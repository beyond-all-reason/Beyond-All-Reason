--------------------------------------------------------------------------------
local widget = widget ---@type Widget

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


-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spEcho = Spring.Echo

local spGetUnitTeam = Spring.GetUnitTeam




--------------------------------------------------------------------------------
-- Beherith's notes
--------------------------------------------------------------------------------
-- TODO:
-- [x] Add health-based brightening
-- [x] Add shield based darkening 
-- [ ] Optimize shader
-- [ ] Combine Effects of techniques
-- [x] LightningOrb() TOO EXPENSIVE!
	-- do multiple wraps, like 4 instead of 18 goddamn passes!
-- [ ] Ensure SphereVBO indices to triangles are ordered bottom to top!
-- [x] Draw order is incorrect, we are drawing after gadget's shield jitter

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

local corafust3ShieldSphere = table.merge(defaults, {
	pos = { 0, 120, 0 },
	size = 64,
	light = 8,
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

local armafust3ShieldSphere = table.merge(defaults, {
	pos = { 0, 120, 0 },
	size = 56,
	light = 8.5,
	--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
	--colormap2 = { {0.2, 0.2, 1, 0.7},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.7} },
})

local legafusShieldSphere = table.merge(defaults, {
	pos = { 0, 60, 0 },
	size = 36,
	light = 4.25,
	--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
	--colormap2 = { {0.2, 0.2, 1, 0.7},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.7} },
})

local legafust3ShieldSphere = table.merge(defaults, {
	pos = { 0, 120, 0 },
	size = 72,
	light = 8.5,
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

local legfusShieldSphere = table.merge(defaults, {
	pos = { 0, 10, 0 },
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
	isShield = true,
})

local corgatet3ShieldSphere = table.merge(defaults, {
	pos = { 0, 75, -1 },
	size = 18,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
	isShield = true,
})

local armjunoShieldSphere = table.merge(defaults, {
	pos = { 0, 72, 0 },
	size = 13,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.8, 0.2, 0.2, 0.4 }, { 0.8, 0.2, 0.2, 0.45 }, { 0.9, 0.2, 0.2, 0.45 }, { 0.9, 0.1, 0.2, 0.4 } },
})

local legjunoShieldSphere = table.merge(defaults, {
	pos = { 0, 69, 0 },
	size = 9,
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
	isShield = true, 
})

local armgatet3ShieldSphere = table.merge(defaults, {
	pos = { 0, 42, -6 },
	size = 20,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
	isShield = true, 
})
local leggatet3ShieldSphere = table.merge(defaults, {
	pos = { 0, 45, 0 },
	size = 18,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
	isShield = true, 
})

local legdeflectorShieldSphere = table.merge(defaults, {
	pos = { 0, 21, 0 },
	size = 12,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
	isShield = true,
})

local UnitEffects = {
	["armjuno"] = {
		{ class = 'ShieldSphere', options = armjunoShieldSphere },
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 72, 0 }, size = 14, precision = 22, repeatEffect = true } },
	},
	["legjuno"] = {
		{ class = 'ShieldSphere', options = legjunoShieldSphere },
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
	["legfus"] = {
		{ class = 'ShieldSphere', options = legfusShieldSphere },
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 19, 0 }, size = 23.5, precision = 22, repeatEffect = true } },
	},
	["armafus"] = {
		{ class = 'ShieldSphere', options = armafusShieldSphere },
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 60, 0 }, size = 28.5, precision = 22, repeatEffect = true } },
	},
	["legafus"] = {
		{ class = 'ShieldSphere', options = legafusShieldSphere },
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 60, 0 }, size = 38.5, precision = 22, repeatEffect = true } },
	},
	["armafust3"] = {
		{ class = 'ShieldSphere', options = armafust3ShieldSphere },
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 120, 0 }, size = 57, precision = 22, repeatEffect = true } },
	},
	["corafust3"] = {
		{ class = 'ShieldSphere', options = corafust3ShieldSphere },
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 120, 0 }, size = 65, precision = 22, repeatEffect = true } },
	},
	["legafust3"] = {
		{ class = 'ShieldSphere', options = legafust3ShieldSphere },
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 120, 0 }, size = 77, precision = 22, repeatEffect = true } },
	},
	["resourcecheat"] = {
		{ class = 'ShieldSphere', options = armafusShieldSphere },
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 60, 0 }, size = 28.5, precision = 22, repeatEffect = true } },
	},
	["corgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 42, 0 }, size = 12, precision = 22, repeatEffect = true , isShiedl } },
		{ class = 'ShieldSphere', options = corgateShieldSphere },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,42,0.0}, size=555, precision=0, strength= 0.001, repeatEffect=true}},
		--{class='ShieldJitter',options={life=math.huge, pos={0,42,0}, size=20, precision=2, repeatEffect=true}},
	},
	["corgatet3"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 75, 0 }, size = 18, precision = 22, repeatEffect = true , isShiedl } },
		{ class = 'ShieldSphere', options = corgatet3ShieldSphere },
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
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 20, -5 }, size = 15, precision = 22, repeatEffect = true } },
		{ class = 'ShieldSphere', options = armgateShieldSphere },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,23.5,-5}, size=555, precision=0, strength=0.001, repeatEffect=true}},
	},
	["armgatet3"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 37, -5 }, size = 21, precision = 22, repeatEffect = true } },
		{ class = 'ShieldSphere', options = armgatet3ShieldSphere },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,23.5,-5}, size=555, precision=0, strength=0.001, repeatEffect=true}},
	},
	["leggatet3"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 45, 0 }, size = 20, precision = 22, repeatEffect = true } },
		{ class = 'ShieldSphere', options = leggatet3ShieldSphere },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,23.5,-5}, size=555, precision=0, strength=0.001, repeatEffect=true}},
	},
	["armfgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 25, 0 }, size = 15, precision = 22, repeatEffect = true } },
		{ class = 'ShieldSphere', options = table.merge(armgateShieldSphere, { pos = { 0, 25, 0 } }) },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,25,0}, size=555, precision=0, strength= 0.001, repeatEffect=true}},
	},
	["legdeflector"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 20, -5 }, size = 15, precision = 22, repeatEffect = true } },
		{ class = 'ShieldSphere', options = legdeflectorShieldSphere },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,23.5,-5}, size=555, precision=0, strength=0.001, repeatEffect=true}},
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

local orbUnitDefs = {}


for unitname, effect in pairs(UnitEffects) do
	if UnitDefNames[unitname] then 
		for _, effectdef in ipairs(effect) do 
			if effectdef.class == "ShieldSphere" then 
				local attr = {} 
				local opts = effectdef.options
				--orbUnitDefs[UnitDefNames[unitname].id] = 
				attr[1], attr[2], attr[3] = unpack(opts.pos)
				attr[4] = opts.size
				
				attr[5] = 1 -- margin
				attr[6] = 0 -- precision
				attr[7] = (opts.isShield and 1) or 0  -- isShield
				attr[8] = 1 -- technique
				
				attr[ 9], attr[10], attr[11], attr[12] = unpack((opts.colormap1 and opts.colormap1[1]) or {-1,-1,-1,-1})
				attr[13], attr[14], attr[15], attr[16] = unpack((opts.colormap2 and opts.colormap2[1]) or {-1,-1,-1,-1})
				
				attr[17], attr[18], attr[19], attr[20] = 0, 0, 0, 0 -- padding for instData
				orbUnitDefs[UnitDefNames[unitname].id] =  attr
			end
		end
	end
end

UnitEffects = nil

--------------------------------------------------------------------------------
-- Variables
--------------------------------------------------------------------------------

local orbVBO = nil
local orbShader = nil

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local popElementInstance  = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance
local drawInstanceVBO     = InstanceVBOTable.drawInstanceVBO

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
layout (location = 4) in vec4 margin_teamID_shield_technique;
layout (location = 5) in vec4 color1;
layout (location = 6) in vec4 color2;
layout (location = 7) in uvec4 instData; // unitID, teamID, ??

out DataVS {
	vec4 color1_vs;
	//flat vec4 color2_vs;
	float unitID_vs;
	flat float gameFrame_vs;
	flat int technique_vs;
	float opac_vs;
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


uniform float reflectionPass = 0.0;

#line 10468
void main()
{
	if ((uni[instData.y].composite & 0x00000003u) < 1u ) { // not drawn
		// Ivand's recommendation is to place vertices outside of NDC space:
		gl_Position = vec4(2.0,2.0,2.0,1.0);
		return;
	}
	
	vec3 modelWorldPos = uni[instData.y].drawPos.xyz;// + vec3(100,100,100);
	unitID_vs = 0.1 + float(uni[instData.y].composite >> 16 ) / 256000.0;
	
	float modelRot = uni[instData.y].drawPos.w;
	mat3 rotY = rotation3dY(modelRot);
		
	vec4 vertexWorldPos = vec4(1);
	vec3 flippedPos = vec3(1,-1,1) * position.xzy;
	
	
	float radius = 0.99 * posrad.w;
	float startFrame = margin_teamID_shield_technique.x;
	//float lifeScale = clamp(((timeInfo.x + timeInfo.w) - startFrame) / 100.0, 0.001, 1.0);
	float lifeScale = 1.0 - exp(-0.10 * ((timeInfo.x + timeInfo.w) - startFrame));
	radius *= lifeScale;
	radius += (sin(timeInfo.z)) - 1.0;
	
	vertexWorldPos.xyz = rotY * ( flippedPos * (radius) + posrad.xyz + vec3(0,0,0) ) + modelWorldPos;
	if (reflectionPass < 0.5){
		gl_Position = cameraViewProj * vertexWorldPos;
	}else{
		gl_Position = reflectionViewProj * vertexWorldPos;
	}

	

	mat3 normalMatrix = mat3( cameraView[0].xyz, cameraView[1].xyz, cameraView[2].xyz);
	
	vec3 normal = (rotY * normals.xzy);
	normal.y *= -1;
	vec3 camPos = cameraViewInv[3].xyz;
	vec3 camToWorldPos = normalize(cameraViewInv[3].xyz  - vertexWorldPos.xyz);
	//vec3 vertex = vec3(gl_ModelViewMatrix * gl_Vertex);
	color1_vs.rgb = camToWorldPos.xyz;
	float angle = dot(normal,camToWorldPos); //*inversesqrt( dot(normal,normal)*dot(position,position) ); //dot(norm(n),norm(v))
	opac_vs = pow( abs( angle ) , 1.0);
	//opac_vs = 1.0;
	//color1_vs.rgb = vec3(angle);
	
	vec4 color2_vs;
	if (color1.r < 0) { // negative numbers mean teamcolor
		vec4 teamcolor = teamColor[int(margin_teamID_shield_technique.y)];
		//	ShieldSphereParticle.Default.colormap1 = {{(r*0.45)+0.3, (g*0.45)+0.3, (b*0.45)+0.3, 0.6}}
		//ShieldSphereParticle.Default.colormap2 = {{r*0.5, g*0.5, b*0.5, 0.66} }
		color1_vs = vec4(teamcolor.rgb, 0.5);
		color1_vs.rgb = color1_vs.rgb * 0.45 + 0.3;
		color2_vs = vec4(teamcolor.rgb, 0.66);
		color2_vs.rgb = color2_vs.rgb * 0.5;
	}else{ // base color
		color1_vs = color1;
		color2_vs = color2;
	}
	
	color1_vs = mix(color1_vs, color2_vs, opac_vs);
	
	if (margin_teamID_shield_technique.z > 0.5){
		float shieldPower = clamp(uni[instData.y].userDefined[0].z, 0, 1);
		color1_vs = mix(vec4(0.8,0.4, 0,1.0),color1_vs,  shieldPower);
	}
	
	float relHealth  = clamp(uni[instData.y].health/uni[instData.y].maxHealth, 0, 1);
	//color1_vs.rgb *= 1.0 + relHealth;
	
	
	modelPos_vs = vec4(position.xzy*posrad.w, 0);
	//modelPos_vs.z = fract(modelPos_vs.z * 10);
	modelPos_vs.w = relHealth;
	gameFrame_vs = timeInfo.z;
	
	technique_vs = int(floor(margin_teamID_shield_technique.w));
	
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

uniform float reflectionPass = 0.0;

#define DISTORTION 0.01
in DataVS {
	vec4 color1_vs;
	float unitID_vs;
	flat float gameFrame_vs;
	flat int technique_vs;
	float opac_vs;
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
		float a = hash13(vec3(ij + vec2(0.0, 0.0), unitID_vs));
		float b = hash13(vec3(ij + vec2(1.0, 0.0), unitID_vs));
		float c = hash13(vec3(ij + vec2(0.0, 1.0), unitID_vs));
		float d = hash13(vec3(ij + vec2(1.0, 1.0), unitID_vs));
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
		const float lacunarity = 1.8;
		const float gain = 0.80;

		float sum = 0.0;
		float amp = 0.8;
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
		 v += noise13(p * 25.05) * 0.124;
		 return v;
	}

	#define SNORM2NORM(value) (value * 0.5 + 0.5)
	#define NORM2SNORM(value) (value * 2.0 - 1.0)

	#define time gameFrame_vs

	vec3 LightningOrb(vec2 vUv, vec3 color) {
		vec2 uv = NORM2SNORM(vUv);

		const float strength = 0.01;
		const float dx = 0.2;

		float t = 0.0;

		for (int k = -4; k < 14; ++k) {
			vec2 thisUV = uv;
			thisUV.x -= dx * float(k);
			thisUV.y += float(k);
			t += abs(strength / ((thisUV.x + Fbm12( thisUV + time ))));
		}

		return color * t;
	}

float mirroredRepeat(float x, float repeats) {
    x *= repeats;
    float i = floor(x);
    float f = fract(x);
    // If i is odd, mirror the fractional part
    if (mod(i, 2.0) == 1.0) {
        f = 1.0 - f;
    }
    return f;
}

vec3 LightningOrb2(vec2 vUv, vec3 color) {

    // Example: NO fract(), but still repeating:
    // vUv.x *= 3.0;

    // Or: mirror repeat for 2 tiles
    vUv.x = mirroredRepeat(vUv.x, 2.0);

    // From here on, continue as you did before:
    vec2 uv = NORM2SNORM(vUv);

    float violence = (1 - modelPos_vs.w);
    const float strength = 0.08 + 0.4 * violence;
    const float dx = 0.225;

    float t = 0.1;
    for (int k = -4; k < 3; ++k) {
        vec2 thisUV = uv;
        thisUV.x -= dx * float(k);
        thisUV.y += 2.0 * float(k);
        vec2 fbmUV = vec2(thisUV.x * 1.0 + time, thisUV.y + 0.3 * time);

        // Your fract()-free or tiled/noise logic remains the same here:
        t += abs(strength / (thisUV.x + (3.0 * Fbm12(fbmUV) - 1.9)));
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

	// Returns the X coords (around the belly) as [0-1], the Y coords as down-up [0-1]
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
		float ra = -time * 0.5;
		mat4 tr = mat4(cos(ra), 0.0, sin(ra), 0.0,
					   0.0, 1.0, 0.0, 0.0,
					   -sin(ra), 0.0, cos(ra), 0.0,
					   0.0, 0.0, 0.0, 1.0);

		return (tr * vec4(p, 1.0)).xyz;
	}

void main(void)
{
	fragColor = color1_vs;
	
	//modelPos_vs contains the sphere's coords.

	if (technique_vs == 1) { // LightningOrb
		vec3 noiseVec = modelPos_vs.xyz;
		noiseVec = RotAroundY(noiseVec);
		vec2 vUv = (RadialCoords(noiseVec));
		vec3 col = LightningOrb2(vUv, fragColor.rgb);
		fragColor.rgba = vec4(col,1.0) * 1.2; return;
		//fragColor.rgb = max(fragColor.rgb, col * col);
		//fragColor.rgb = max(fragColor.rgb, col * 2);
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
	//fragColor.rgba = vec4(1.0);
	//fragColor.rgb = modelPos_vs.xyz;
	//fragColor.rgba = vec4(opac_vs,opac_vs, opac_vs, 1.0);
	//fragColor.rgb = color1_vs.rgb;
}
]]

local function goodbye(reason)
  spEcho("Lups Orb GL4 widget exiting with reason: "..reason)
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
		reflectionPass = 0.0,
      },
    },
    "orbShader GL4"
  )
  shaderCompiled = orbShader:Initialize()
  if not shaderCompiled then goodbye("Failed to compile orbShader GL4 ") end
  local sphereVBO, numVerts, sphereIndexVBO, numIndices = InstanceVBOTable.makeSphereVBO(24,16,1)
  --spEcho("SphereVBO has", numVerts, "vertices and ", numIndices,"indices")
  local orbVBOLayout = {
		  {id = 3, name = 'posrad', size = 4}, -- widthlength
		  {id = 4, name = 'margin_teamID_shield_technique', size = 4}, --  emit dir
		  {id = 5, name = 'color1', size = 4}, --- color
		  {id = 6, name = 'color2', size = 4}, --- color
		  {id = 7, name = 'instData', type = GL.UNSIGNED_INT, size= 4},
		}
  orbVBO = InstanceVBOTable.makeInstanceVBOTable(orbVBOLayout,256, "orbVBO", 7)
  orbVBO.numVertices = numIndices
  orbVBO.vertexVBO = sphereVBO
  orbVBO.VAO = InstanceVBOTable.makeVAOandAttach(orbVBO.vertexVBO, orbVBO.instanceVBO)
  orbVBO.primitiveType = GL.TRIANGLES
  orbVBO.indexVBO = sphereIndexVBO  
  orbVBO.VAO:AttachIndexBuffer(orbVBO.indexVBO)
end

--------------------------------------------------------------------------------
-- Draw Iteration
--------------------------------------------------------------------------------
local function DrawOrbs(reflectionPass)
	if orbVBO.usedElements > 0 then
		gl.DepthTest(true)
		gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove both state changes
		--gl.Culling(GL.FRONT)
		gl.Culling(false)
		orbShader:Activate()
		orbShader:SetUniform("reflectionPass", (reflectionPass and 1 ) or 0 )
		drawInstanceVBO(orbVBO)
		orbShader:Deactivate()
	end
end
--------------------------------------------------------------------------------
-- Widget Interface
--------------------------------------------------------------------------------
-- Note that we rely on VisibleUnitRemoved triggering right before VisibleUnitAdded on UnitFinished 
local shieldFinishFrames = {} -- unitID to gameframe

function widget:DrawWorldPreParticles(drawAboveWater, drawBelowWater, drawReflection, drawRefraction) 
	if next(shieldFinishFrames) then shieldFinishFrames = {} end
	-- NOTE: This is called TWICE per draw frame, once before water and once after, even if no water is present. 
	-- If water is present on the map, then it gets called again between the two for the refraction pass
	-- Solution is to draw it only on the first call, and draw reflections from widget:DrawWorldReflection
	
	if drawAboveWater and not drawReflection and not drawRefraction then
		DrawOrbs(false) 
	end
end

function widget:DrawWorldReflection()
	DrawOrbs(true)
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	initGL4()
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	else
		spEcho("Unit Tracker API unavailable, exiting Orb Lups GL4")
		widgetHandler:RemoveWidget()
		return
	end
end


function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam, noupload)
	--spEcho("widget:VisibleUnitAdded",unitID, unitDefID, unitTeam, noupload,shieldFinishFrames[unitID])
	if unitDefID and orbUnitDefs[unitDefID] then 

		unitTeam = unitTeam or spGetUnitTeam(unitID)
		
		local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
		if buildProgress < 1 then return end

		local instanceCache = orbUnitDefs[unitDefID]
		instanceCache[5] = shieldFinishFrames[unitID] or 0
		instanceCache[6] = unitTeam
		--instanceCache[7] = spGetGameFrame()
		shieldFinishFrames[unitID] = nil
		
		--spEcho("Added lups orb")
		pushElementInstance(orbVBO,
			instanceCache,
			unitID, --key
			true, -- updateExisting
			noupload,
			unitID -- unitID for uniform buffers
		)
	end 
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	if orbVBO.usedElements > 0 then 
		InstanceVBOTable.clearInstanceTable(orbVBO) 
	end
	for unitID, unitDefID in pairs(extVisibleUnits) do 
		widget:VisibleUnitAdded(unitID, unitDefID, nil, true)
	end
	InstanceVBOTable.uploadAllElements(orbVBO)
end

function widget:VisibleUnitRemoved(unitID)
	shieldFinishFrames[unitID] = spGetGameFrame()
	if orbVBO.instanceIDtoIndex[unitID] then
		popElementInstance(orbVBO, unitID)
	end
end

function widget:Shutdown()
	-- FIXME: clean up after thyself!
end
