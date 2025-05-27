-------------------------------------------------
-- An API wrapper to draw simple graphical primitives at units extremely efficiently
-- License: Lua code GPL V2, GLSL shader code: (c) Beherith (mysterme@gmail.com)
-------------------------------------------------

local DrawPrimitiveAtUnit = {}

local shaderConfig = {
	TRANSPARENCY = 0.2, -- transparency of the stuff drawn
	HEIGHTOFFSET = 1, -- Additional height added to everything
	ANIMATION = 1, -- set to 0 if you dont want animation
	INITIALSIZE = 0.66, -- What size the stuff starts off at when spawned
	GROWTHRATE = 4, -- How fast it grows to full size
	BREATHERATE = 30.0, -- how fast it periodicly grows
	BREATHESIZE = 0.05, -- how much it periodicly grows
	TEAMCOLORIZATION = 1.0, -- not used yet
	CLIPTOLERANCE = 1.1, -- At 1.0 it wont draw at units just outside of view (may pop in), 1.1 is a good safe amount
	USETEXTURE = 1, -- 1 if you want to use textures (atlasses too!) , 0 if not
	BILLBOARD = 0, -- 1 if you want camera facing billboards, 0 is flat on ground
	POST_ANIM = " ", -- what you want to do in the animation post function (glsl snippet, see shader source)
	POST_VERTEX = "v_color = v_color;", -- noop
	ZPULL = 256.0, -- how much to pull the z (depth) value towards the camera , 256 is about 16 elmos
	POST_GEOMETRY = "",	--"g_uv.zw = dataIn[0].v_parameters.xy;", -- noop
	POST_SHADING = "fragColor.rgba = fragColor.rgba;", -- noop
	MAXVERTICES = 64, -- The max number of vertices we can emit, make sure this is consistent with what you are trying to draw (tris 3, quads 4, corneredrect 8, circle 64
	USE_CIRCLES = 1, -- set to nil if you dont want circles
	USE_CORNERRECT = 1, -- set to nil if you dont want cornerrect
	USE_TRIANGLES = 1, -- set to nil if you dont want to use tris
	USE_QUADS = 1, -- set to nil if you dont want to use quads
	FULL_ROTATION = 0, -- the primitive is fully rotated in the units plane
	DISCARD = 0, -- Enable alpha threshold to discard fragments below 0.01
	ROTATE_CIRCLES = 1, -- Set to 0 if you dont want circles to be rotated
	PRE_OFFSET = "",
}

---- GL4 Backend Stuff----
local DrawPrimitiveAtUnitVBO = nil
local DrawPrimitiveAtUnitShader = nil

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable


local vsSrcPath = "LuaUI/Shaders/DrawPrimitiveAtUnit.vert.glsl"
local gsSrcPath = "LuaUI/Shaders/DrawPrimitiveAtUnit.geom.glsl"
local fsSrcPath = "LuaUI/Shaders/DrawPrimitiveAtUnit.frag.glsl"

local shaderSourceCache = {
		vssrcpath = vsSrcPath,
		fssrcpath = fsSrcPath,
		gssrcpath = gsSrcPath,
		shaderName = "DrawPrimitiveAtUnit",
		uniformInt = {},
		uniformFloat = {
			addRadius = 0.0,
			iconDistance = 20000.0,
		  },
		shaderConfig = shaderConfig,
	}

local function InitDrawPrimitiveAtUnit(shaderConfig, DPATname)
	if shaderConfig.USETEXTURE then 
		shaderSourceCache.uniformInt = {DrawPrimitiveAtUnitTexture = 0,}
	end
	
	shaderSourceCache.shaderName = DPATname .. "Shader GL4"
	
	DrawPrimitiveAtUnitShader =  LuaShader.CheckShaderUpdates(shaderSourceCache) or DrawPrimitiveAtUnitShader

	if not DrawPrimitiveAtUnitShader then 
		Spring.Echo("Failed to compile shader for ", DPATname)
		return nil
	end

	DrawPrimitiveAtUnitVBO = InstanceVBOTable.makeInstanceVBOTable(
		{
			{id = 0, name = 'lengthwidthcorner', size = 4},
			{id = 1, name = 'teamID', size = 1, type = GL.UNSIGNED_INT},
			{id = 2, name = 'numvertices', size = 1, type = GL.UNSIGNED_INT},
			{id = 3, name = 'parameters', size = 4},
			{id = 4, name = 'uvoffsets', size = 4},
			{id = 5, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
		},
		64, -- maxelements
		DPATname .. "VBO", -- name
		5  -- unitIDattribID (instData)
	)
	if DrawPrimitiveAtUnitVBO == nil then 
		Spring.Echo("Failed to create DrawPrimitiveAtUnitVBO for ", DPATname) 
		return nil
	end

	local DrawPrimitiveAtUnitVAO = gl.GetVAO()
	DrawPrimitiveAtUnitVAO:AttachVertexBuffer(DrawPrimitiveAtUnitVBO.instanceVBO)
	DrawPrimitiveAtUnitVBO.VAO = DrawPrimitiveAtUnitVAO
	return  DrawPrimitiveAtUnitVBO, DrawPrimitiveAtUnitShader
end

return {InitDrawPrimitiveAtUnit = InitDrawPrimitiveAtUnit, shaderConfig = shaderConfig}
