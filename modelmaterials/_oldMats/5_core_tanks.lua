-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local GetGameFrame=Spring.GetGameFrame
local GetFrameTimeOffset=Spring.GetFrameTimeOffset
local GetUnitHealth=Spring.GetUnitHealth

local GADGET_DIR = "LuaRules/Configs/"

local function DrawUnit(unitID, unitDefID, material, drawMode, luaShaderObj)
	-- Spring.Echo('Arm Tanks drawmode',drawMode)
	--if (drawMode ==1)then -- we can skip setting the uniforms as they only affect fragment color, not fragment alpha or vertex positions, so they dont have an effect on shadows, and drawmode 2 is shadows, 1 is normal mode.
	--Spring.Echo('drawing',UnitDefs[Spring.GetUnitDefID(unitID)].name,GetGameFrame())
	--local  health,maxhealth=GetUnitHealth(unitID)
	--health= 2*maximum(0, (-2*health)/(maxhealth)+1) --inverse of health, 0 if health is 100%-50%, goes to 1 by 0 health

	local usx, usy, usz, speed = Spring.GetUnitVelocity(unitID)
	if speed > 0.01 then speed = 1 end
	local offset = (((GetGameFrame()+GetFrameTimeOffset()) % 10) * (8.0 / 2048.0)) * speed
	-- check if moving backwards
	local udx, udy, udz = Spring.GetUnitDirection(unitID)
	if udx > 0 and usx < 0  or  udx < 0 and usx > 0  or  udz > 0 and usz < 0  or  udz < 0 and usz > 0 then
		offset = -offset
	end

	luaShaderObj:SetUniformAlways("etcLoc", 0.0, 0.0, -offset)

	--end
	--// engine should still draw it (we just set the uniforms for the shader)
	return false
end

local default_aux = VFS.Include("materials/Shaders/default_aux.lua")
local default_lua = VFS.Include("materials/Shaders/default.lua")

local matTemplate = {
	shaderDefinitions = {
		"#define use_normalmapping",
		"#define deferred_mode 0",
		"#define flashlights",
		"#define use_vertex_ao",
		"#define use_treadoffset_core",

		"#define SHADOW_SOFTNESS SHADOW_SOFT",

		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		--"#define ROUGHNESS_PERTURB_NORMAL 0.025",
		--"#define ROUGHNESS_PERTURB_COLOR 0.07",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		--"#define GAMMA 2.2",
		"#define TONEMAP(c) CustomTM(c)",
	},
	deferredDefinitions = {
		"#define use_normalmapping",
		"#define deferred_mode 1",
		"#define flashlights",
		"#define use_vertex_ao",
		"#define use_treadoffset_core",

		"#define SHADOW_SOFTNESS SHADOW_HARD",

		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		--"#define ROUGHNESS_PERTURB_NORMAL 0.025",
		--"#define ROUGHNESS_PERTURB_COLOR 0.05",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		--"#define GAMMA 2.2",
		"#define TONEMAP(c) CustomTM(c)",

		"#define MAT_IDX 5",
	},
	shaderPlugins = default_aux.scavDisplacementPlugin,
	shader    = default_lua,
	deferred  = default_lua,
	usecamera = false,
	force = true,
	culling = GL.BACK,
	predl  = nil,
	postdl = nil,
	texunits  = {
		[0] = "%TEX1",
		[1] = "%TEX2",
		[2] = "$shadow",
		[3] = "$reflection",
		[4] = "%NORMALTEX",
		[5] = "$info",
		[6] = GG.GetBrdfTexture(),
		[7] = GG.GetEnvTexture(),

	},
	DrawUnit = DrawUnit,
	SunChanged = default_aux.SunChanged,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Automated normalmap detection

local materials = {}
local unitMaterials = {}

for i = 1, #UnitDefs do
	local udef = UnitDefs[i]
	local udefCM = udef.customParams

	if (string.sub(udef.name, 1, 3) == 'cor' and udef.modCategories['tank'] and udefCM.normaltex and VFS.FileExists(udefCM.normaltex)) then
		default_aux.FillMaterials(unitMaterials, materials, matTemplate, "normalMappedS3O_core_tank", i)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
