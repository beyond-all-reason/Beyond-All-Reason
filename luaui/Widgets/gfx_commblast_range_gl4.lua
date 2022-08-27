function widget:GetInfo()
	return {
		name = "Commblast Range GL4",
		desc = "Draws the spherical commblast range onto the ground",
		author = "Beherith",
		date = "2022.08.27",
		license = "Lua code: GNU GPL, v2 or later, Shader GLSL code: (c) Beherith (mysterme@gmail.com)",
		layer = -1,
		enabled = false,
	}
end

local commblastSphereVBO = nil
local commblastSphereShader = nil
local luaShaderDir = "LuaUI/Widgets/Include/"

local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local GL_BACK = GL.BACK
local GL_LEQUAL = GL.LEQUAL

---- Config stuff ------------------
local commanders = {}
local commDefIds = { [UnitDefNames['corcom'].id] = true, [UnitDefNames['armcom'].id] = true}
local dgunRange	= WeaponDefNames["armcom_disintegrator"].range + WeaponDefNames["armcom_disintegrator"].damageAreaOfEffect

local blastRadius			= 380		-- com explosion
local showOnEnemyDistance	= 570
---- GL4 Config stuff ----------------


local shaderConfig = {
	FULLRADIUS = 400,
	SPHERESEGMENTS = 16,
	BLASTRADIUS = blastRadius,
	DGUNRANGE = dgunRange,
	OPACITYMULTIPLIER = 1
}

---- Object intersection test http://www.realtimerendering.com/intersections.html

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local commblastSphereVBO = nil 

local fogTexture
local vsx, vsy
local combineShader

local shaderSourceCache = {
		vssrcpath = "LuaUI/Widgets/Shaders/commblast_range.vert.glsl",
		fssrcpath = "LuaUI/Widgets/Shaders/commblast_range.frag.glsl",
		--gssrcpath = gsSrcPath,
		uniformInt = {
			mapDepths = 0,
		},
		uniformFloat = {
			fadeDistance = 300000,
		},
		shaderName = "Commblast Range GL4",
		shaderConfig = shaderConfig
	}

local function goodbye(reason)
  Spring.Echo("Fog Volumes GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

function widget:Update()
	-- checks if a shader code has changed on disk, if yes, then it tries to recompile, and on success, it will return the new shader object 
	commblastSphereShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or commblastSphereShader
end

local function initFogGL4(shaderConfig, DPATname)
	widget:Update()
	if not commblastSphereShader then 
		goodbye("Failed to compile ".. DPATname .." GL4 ") 
		return
	end

	local sphereVBO, numVertices, sphereIndexVBO, numIndices = makeSphereVBO(shaderConfig.SPHERESEGMENTS, shaderConfig.SPHERESEGMENTS/2, 1)

	DrawPrimitiveAtUnitVBO = makeInstanceVBOTable(
		{
			{id = 3, name = 'params_alpha_health', size = 4},
			{id = 4, name = 'instData', type = GL.UNSIGNED_INT, size = 4},
		},
		64, -- maxelements
		DPATname .. "VBO", -- name,
		4 --unitIDattribID
	)
	if DrawPrimitiveAtUnitVBO == nil then 
		goodbye("Failed to create DrawPrimitiveAtUnitVBO") 
		return
	end
	
	DrawPrimitiveAtUnitVBO:makeVAOandAttach(sphereVBO,DrawPrimitiveAtUnitVBO.instanceVBO, sphereIndexVBO)
	return DrawPrimitiveAtUnitVBO, commblastSphereShader
end


local function AddBlastSphere(unitID, unitDefID)
	if commDefIds[unitDefID] then 
		commanders[unitID] = true
		Spring.Echo("Added a unit")
		return pushElementInstance(commblastSphereVBO, 
			{1,1,1,1,0,0,0,0},
			unitID, true, nil, unitID)
	end
end


function widget:DrawWorldPreUnit()
	if commblastSphereShader.shaderObj ~= nil and commblastSphereVBO.usedElements > 0 then
		--Spring.Echo(commblastSphereVBO.usedElements)
		glCulling(GL.FRONT)
		glDepthTest(GL.LEQUAL)
		glDepthTest(false)
		gl.DepthMask(false)
		gl.Texture(0, "$map_gbuffer_zvaltex")
		
		commblastSphereShader:Activate()

		commblastSphereVBO:Draw()
	
		commblastSphereShader:Deactivate()
		glTexture(0, false)

		glDepthTest(false)
	end
end

--- Look how easy api_unit_tracker is to use! 
function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)

		Spring.Echo("VisibleUnitAdded",	unitID, unitDefID, unitTeam)
	AddBlastSphere(unitID, unitDefID)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	clearInstanceTable(commblastSphereVBO) -- clear all instances
	for unitID, unitDefID in pairs(extVisibleUnits) do
		AddBlastSphere(unitID, unitDefID,  "VisibleUnitsChanged") -- add them with noUpload = true
	end
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	if debugmode then Spring.Debug.TraceEcho("remove",unitID,reason) end
	commanders[unitID] = nil
	if commblastSphereVBO.instanceIDtoIndex[unitID] then
		popElementInstance(commblastSphereVBO, unitID)
	end
end

function widget:GameFrame(n) 
	-- This is where we update the alphas of the spheres
	-- also based on health!
end

function widget:Initialize()
	commblastSphereVBO, commblastSphereShader = initFogGL4(shaderConfig, "commblastSpheres")
	Spring.Echo(Spring.HaveShadows(),"advshad",Spring.HaveAdvShading())
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
end
