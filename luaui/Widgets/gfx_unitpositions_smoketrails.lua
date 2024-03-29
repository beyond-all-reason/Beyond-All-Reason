function widget:GetInfo()
   return {
      name      = "Unit Positions Smoke Trails GL4",
      desc      = "Smoke Trails",
      author    = "Beherith",
      date      = "2024.03.28",
      license   = "MINE",
      layer     = -5000, -- after the api!
			-- handler   = true,
      enabled   = true
   }
end


local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

-------------------------------------------------
-- An API wrapper to draw simple graphical primitives at units extremely efficiently
-- License: Lua code GPL V2, GLSL shader code: (c) Beherith (mysterme@gmail.com)
-------------------------------------------------


local myvisibleUnits = {} -- table of unitID : unitDefID
local unitIDtoSlot
local unitPosTexture

local autoreload = false

local unitPosSmoke = {}

local shaderConfig = {
	TRANSPARENCY = 0.2, -- transparency of the stuff drawn
	INITIALSIZE = 0.66, -- What size the stuff starts off at when spawned
	GROWTHRATE = 4, -- How fast it grows to full size
	BREATHERATE = 30.0, -- how fast it periodicly grows
	BREATHESIZE = 0.05, -- how much it periodicly grows
	TEAMCOLORIZATION = 1.0, -- not used yet
	USETEXTURE = 1, -- 1 if you want to use textures (atlasses too!) , 0 if not
	BILLBOARD = 1, -- 1 if you want camera facing billboards, 0 is flat on ground
	POST_GEOMETRY = "gl_Position.z = (gl_Position.z) - 256.0 / (gl_Position.w);",	--"g_uv.zw = dataIn[0].v_parameters.xy;", -- noop
	POST_SHADING = "fragColor.rgba = fragColor.rgba;", -- noop
	MAXVERTICES = 80, -- The max number of vertices we can emit,  at least 1024/ numfloats output, and builtins like gl_Position counts as 4 floats towards this
}

---- GL4 Backend Stuff----
local unitPosSmokeVBO = nil
local unitPosSmokeShader = nil

local noisetex3dcube =  "LuaUI/images/noisetextures/worley_rgbnorm_01_asum_128_v1_mip.dds"

local vsSrcPath = "LuaUI/Widgets/Shaders/unit_positions_smoketrails.vert.glsl"
local gsSrcPath = "LuaUI/Widgets/Shaders/unit_positions_smoketrails.geom.glsl"
local fsSrcPath = "LuaUI/Widgets/Shaders/unit_positions_smoketrails.frag.glsl"

local shaderSourceCache = {
		vssrcpath = vsSrcPath,
		fssrcpath = fsSrcPath,
		gssrcpath = gsSrcPath,
		shaderName = "unitPosSmoke",
		uniformInt = {
			unitPosTexture = 0,
			noisetex3dcube = 1,
			},
		uniformFloat = {
			iconDistance = 20000.0,
		  },
		shaderConfig = shaderConfig,
	}

local function InitunitPosSmoke(DPATname)
	
	shaderSourceCache.shaderName = DPATname .. "Shader GL4"
	
	unitPosSmokeShader =  LuaShader.CheckShaderUpdates(shaderSourceCache)

	if not unitPosSmokeShader then 
		Spring.Echo("Failed to compile shader for ", DPATname)
		return nil
	end

	unitPosSmokeVBO = makeInstanceVBOTable(
		{
			{id = 0, name = 'lengthwidthcorner', size = 4},
			{id = 1, name = 'parameters', size = 4},
			{id = 2, name = 'uvoffsets', size = 4},
			{id = 3, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
		},
		64, -- maxelements
		DPATname .. "VBO", -- name
		3  -- unitIDattribID (instData)
	)
	if unitPosSmokeVBO == nil then 
		Spring.Echo("Failed to create unitPosSmokeVBO for ", DPATname) 
		return nil
	end

	local unitPosSmokeVAO = gl.GetVAO()
	unitPosSmokeVAO:AttachVertexBuffer(unitPosSmokeVBO.instanceVBO)
	unitPosSmokeVBO.VAO = unitPosSmokeVAO
	return  unitPosSmokeVBO, unitPosSmokeShader
end

local texture = "luaui/images/solid.png"

local function initGL4()
	InitunitPosSmoke(shaderConfig, "unitpos smoke ")
	if unitPosSmokeVBO == nil then 
		widgetHandler:RemoveWidget()
	end
end


function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	if not unitIDtoSlot[unitID] then return end
	Spring.Echo("widget:VisibleUnitAdded",unitID, unitDefID, unitTeam)
	local teamID = Spring.GetUnitTeam(unitID) or 0 
	local gf = Spring.GetGameFrame()
	myvisibleUnits[unitID] = unitDefID
	local slot = unitIDtoSlot[unitID]
	pushElementInstance(
		unitPosSmokeVBO, -- push into this Instance VBO Table
		{
			96, 96, 8, 8,  -- lengthwidthcornerheight
			slot, gf, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			0, 1, 0, 1, -- These are our default UV atlas tranformations
			0, 0, 0, 0 -- these are just padding zeros, that will get filled in
		},
		unitID, -- this is the key inside the VBO TAble,
		true, -- update existing element
		nil, -- noupload, dont use unless you know what you are doing
		unitID -- last one should be UNITID?
	)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	Spring.Echo("widget:VisibleUnitsChanged",extVisibleUnits, extNumVisibleUnits)
	clearInstanceTable(unitPosSmokeVBO)
	for unitID, unitDefID in pairs(extVisibleUnits) do 
		widget:VisibleUnitAdded(unitID, unitDefID, Spring.GetUnitTeam(unitID))
	end
end

function widget:VisibleUnitRemoved(unitID)
	Spring.Echo("widget:VisibleUnitRemoved",unitID)
	if unitPosSmokeVBO.instanceIDtoIndex[unitID] then 
		popElementInstance(unitPosSmokeVBO, unitID)
		myvisibleUnits[unitID] = nil
	end
end

function widget:DrawWorldPreUnit()
	if Spring.IsGUIHidden() then
		return
	end
	
	if autoreload then
		unitPosSmokeShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or unitPosSmokeShader
	end
	
	if unitPosSmokeVBO.usedElements > 0 then
		gl.Texture(0, unitPosTexture)
		gl.Texture(1, noisetex3dcube)
		unitPosSmokeShader:Activate()
		unitPosSmokeShader:SetUniform("iconDistance", 99999) -- pass
		gl.DepthTest(true)
		gl.DepthMask(false)
		unitPosSmokeVBO.VAO:DrawArrays(GL.POINTS, unitPosSmokeVBO.usedElements)
		unitPosSmokeShader:Deactivate()
		gl.Texture(0, false)
		gl.Texture(1, false)
	end
end

function widget:Initialize()
	initGL4()
	
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
	
	unitIDtoSlot = WG['unitPosAPI'].unitIDtoSlot
	unitPosTexture = WG['unitPosAPI'].GetUnitPosTexture()
end
