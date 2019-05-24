-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local GetGameFrame=Spring.GetGameFrame
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
	local offset = (((GetGameFrame()) % 9) * (2.0 / 4096.0)) * speed
	-- check if moving backwards
	local udx, udy, udz = Spring.GetUnitDirection(unitID)
	if udx > 0 and usx < 0  or  udx < 0 and usx > 0  or  udz > 0 and usz < 0  or  udz < 0 and usz > 0 then
		offset = -offset
	end

	luaShaderObj:SetUniformAlways("etcLoc", 0.0, 0.0, offset)

	--end
	--// engine should still draw it (we just set the uniforms for the shader)
	return false
end

local function SunChanged(curShaderObj)
	curShaderObj:SetUniformAlways("shadowDensity", gl.GetSun("shadowDensity" ,"unit"))

	curShaderObj:SetUniformAlways("sunAmbient", gl.GetSun("ambient" ,"unit"))
	curShaderObj:SetUniformAlways("sunDiffuse", gl.GetSun("diffuse" ,"unit"))
	curShaderObj:SetUniformAlways("sunSpecular", gl.GetSun("specular" ,"unit"))
	--gl.Uniform(gl.GetUniformLocation(curShader, "sunSpecularExp"), gl.GetSun("specularExponent" ,"unit"))
end

local default_lua = VFS.Include("materials/Shaders/default.lua")

local matTemplate = {
	shaderDefinitions = {
		"#define use_normalmapping",
		"#define deferred_mode 0",
		"#define use_treadoffset",
		"#define flashlights",
		"#define use_vertex_ao",
		"#define SPECULARMULT 8.0",
	},
	deferredDefinitions = {
		"#define use_normalmapping",
		"#define deferred_mode 1",
		"#define use_treadoffset",
		"#define flashlights",
		--"#define use_vertex_ao",
		"#define SPECULARMULT 8.0",
		"#define MAT_IDX 2",
	},

	shader    = default_lua,
	deferred  = default_lua,
	usecamera = false,
	culling   = GL.BACK,
	predl  = nil,
	postdl = nil,
	texunits  = {
		[0] = '%%UNITDEFID:0',
		[1] = '%%UNITDEFID:1',
		[2] = '$shadow',
		[4] = '$reflection',
		[5] = '%NORMALTEX',
	},
	DrawUnit = DrawUnit,
	SunChanged = SunChanged,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Automated normalmap detection

local materials = {}
local unitMaterials = {}

for i = 1, #UnitDefs do
	local udef = UnitDefs[i]
	local udefCM = udef.customParams

	if (udefCM.arm_tank and udefCM.normaltex and VFS.FileExists(udefCM.normaltex)) then
		local lm = tonumber(udefCM.lumamult) or 1
		local matName = string.format("%s(lumamult=%f)", "normalMappedS3O_arm_tank", lm)
		if not materials[matName] then
			materials[matName] = Spring.Utilities.CopyTable(matTemplate, true)
			if lm ~= 1 then
				local lmLM = string.format("#define LUMAMULT %f", lm)
				table.insert(materials[matName].shaderDefinitions, lmLM)
				table.insert(materials[matName].deferredDefinitions, lmLM)
			end
		end

		unitMaterials[udef.name] = {matName, NORMALTEX = udefCM.normaltex}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
