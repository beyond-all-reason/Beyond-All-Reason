-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local GetGameFrame=Spring.GetGameFrame
local GetUnitHealth=Spring.GetUnitHealth
local modulo=math.fmod
local glUniform=gl.Uniform
local sine =math.sin
local maximum=math.max
local GetUnitTeam = Spring.GetUnitTeam
local trackpos=0

local GADGET_DIR = "LuaRules/Configs/"
local etcLocIDs = {[0] = -2, [1] = -2}

local function DrawUnit(unitID, material,drawMode)
	local etcLocIdx = (drawMode == 5) and 1 or 0
	local curShader = (drawMode == 5) and material.deferredShader or material.standardShader

	if etcLocIDs[etcLocIdx] == -2 then
		etcLocIDs[etcLocIdx] = gl.GetUniformLocation(curShader, "etcLoc")
	end
	-- Spring.Echo('Arm Tanks drawmode',drawMode)
	--if (drawMode ==1)then -- we can skip setting the uniforms as they only affect fragment color, not fragment alpha or vertex positions, so they dont have an effect on shadows, and drawmode 2 is shadows, 1 is normal mode.
	--Spring.Echo('drawing',UnitDefs[Spring.GetUnitDefID(unitID)].name,GetGameFrame())
	--local  health,maxhealth=GetUnitHealth(unitID)
	--health= 2*maximum(0, (-2*health)/(maxhealth)+1) --inverse of health, 0 if health is 100%-50%, goes to 1 by 0 health
	local usx,usy,usz,speed = Spring.GetUnitVelocity(unitID)
	if speed > 0.01 then speed = 1 end
	local offset = (((GetGameFrame())%9) * (2.0/4096.0))*speed
	-- check if moving backwards
	local udx,udy,udz = Spring.GetUnitDirection(unitID)
	if udx > 0 and usx < 0  or  udx < 0 and usx > 0  or  udz > 0 and usz < 0  or  udz < 0 and usz > 0 then
		offset = 0 - offset
	end
	glUniform(etcLocIDs[etcLocIdx], 0.0,0.0,offset) --etcloc.z is the track offset pos.

	--end
  --// engine should still draw it (we just set the uniforms for the shader)
  return false
end

local function SunChanged(curShader)
	gl.Uniform(gl.GetUniformLocation(curShader, "shadowDensity"), gl.GetSun("shadowDensity" ,"unit"))

	gl.Uniform(gl.GetUniformLocation(curShader, "sunAmbient"), gl.GetSun("ambient" ,"unit"))
	gl.Uniform(gl.GetUniformLocation(curShader, "sunDiffuse"), gl.GetSun("diffuse" ,"unit"))
	gl.Uniform(gl.GetUniformLocation(curShader, "sunSpecular"), gl.GetSun("specular" ,"unit"))
	--gl.Uniform(gl.GetUniformLocation(curShader, "sunSpecularExp"), gl.GetSun("specularExponent" ,"unit"))
end


local default_lua = VFS.Include("materials/Shaders/default.lua")

local materials = {
	normalMappedS3O_arm_tank = {
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
			[3] = '$specular',
			[4] = '$reflection',
			[5] = '%NORMALTEX',
		},
		DrawUnit = DrawUnit,
		SunChanged = SunChanged,
   },
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Automated normalmap detection

local unitMaterials = {}


for i=1,#UnitDefs do
	local udef = UnitDefs[i]

	if (udef.customParams.arm_tank and udef.customParams.normaltex and VFS.FileExists(udef.customParams.normaltex)) then
		unitMaterials[udef.name] = {"normalMappedS3O_arm_tank", NORMALTEX = udef.customParams.normaltex}
		--Spring.Echo('armtank',udef.name)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
