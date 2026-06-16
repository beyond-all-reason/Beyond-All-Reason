-------------------------------------------------
-- Alternative shader path for the DrawPrimitiveAtUnit pattern that does not
-- use a geometry-shader stage. Useful for backends that lack a geometry-
-- shader stage. Each instance is expanded into the target primitive via
-- gl_VertexID in an instanced vertex shader, drawn as GL_TRIANGLES.
--
-- The per-unit data is bound as an INSTANCE buffer (divisor 1) and the
-- vertex shader expands each instance into the target primitive (triangle,
-- quad, cornerrect, or circle) via gl_VertexID. Widgets draw with:
--   VBO.VAO:DrawArrays(GL.TRIANGLES, VBO.numVerts, 0, VBO.usedElements)
--
-- Same public surface as DrawPrimitiveAtUnit.lua so a widget can opt in at
-- load time by switching the VFS.Include path (and its draw call). Widgets
-- that do not opt in continue using the geometry-shader-based
-- DrawPrimitiveAtUnit infrastructure unchanged.
-- License: GNU GPL V2
-------------------------------------------------

local DrawPrimitiveAtUnit = {}

-- shaderConfig: per-key documentation. Keys mirror DrawPrimitiveAtUnit.lua so
-- a widget can move between the two paths by changing only the VFS.Include
-- path. Differences from the GS variant are called out below.
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
	USETEXTURE = 1, -- 1 if you want to use textures (atlasses too!), 0 if not
	BILLBOARD = 0, -- 1 if you want camera facing billboards, 0 is flat on ground
	-- POST_ANIM / POST_VERTEX / PRE_OFFSET / POST_GEOMETRY: GLSL injection
	-- points inside the vertex shader, identical to the GS variant by name and
	-- by the locals they may read/write (v_color, v_lengthwidthcornerheight,
	-- v_parameters, v_centerpos, v_uvoffsets, v_numvertices, ...).
	-- IMPORTANT SEMANTIC DIFFERENCE: in the GS variant these run ONCE per
	-- instance (inside the VS, which then feeds the GS). In this NoGS variant
	-- the expansion is inside the VS itself, so each injection runs ONCE per
	-- OUTPUT VERTEX (up to (MAXVERTICES-2)*3 times per instance). All injection
	-- bodies must be idempotent pure writes; do not put counters, RNG advances
	-- or accumulators here.
	POST_ANIM = " ", -- what you want to do in the animation post function (glsl snippet, see shader source)
	POST_VERTEX = " ", -- noop
	ZPULL = 256.0, -- how much to pull the z (depth) value towards the camera, 256 is about 16 elmos
	POST_GEOMETRY = "", -- per-vertex post-emit snippet; in the GS variant this was per-emit inside the GS, here it is per output vertex inside the VS
	POST_SHADING = "fragColor.rgba = fragColor.rgba;", -- noop
	-- MAXVERTICES: max number of strip vertices a primitive can have (tris 3,
	-- quads 4, cornerrect 8, circle up to 64). In this NoGS variant it ALSO
	-- determines the fixed per-instance draw count: (MAXVERTICES-2)*3 vertices
	-- are emitted via glDrawArraysInstanced and unused ones become degenerate
	-- (off-screen) vertices. Keep it as low as your largest primitive needs.
	MAXVERTICES = 64,
	USE_CIRCLES = 1, -- set to nil if you dont want circles
	USE_CORNERRECT = 1, -- set to nil if you dont want cornerrect
	USE_TRIANGLES = 1, -- set to nil if you dont want to use tris
	USE_QUADS = 1, -- set to nil if you dont want to use quads
	FULL_ROTATION = 0, -- the primitive is fully rotated in the units plane
	DISCARD = 0, -- Enable alpha threshold to discard fragments below 0.01
	ROTATE_CIRCLES = 1, -- Set to 0 if you dont want circles to be rotated
	PRE_OFFSET = "", -- vertex-shader snippet run just before the gl_Position write; same name as in the GS variant, but per-output-vertex here
	USEQUATERNIONS = Engine.FeatureSupport.transformsInGL4 and "1" or "0", -- use quaternion-based unit transforms when supported by the engine
}

---- GL4 Backend Stuff----
local DrawPrimitiveAtUnitVBO = nil
local DrawPrimitiveAtUnitShader = nil

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local vsSrcPath = "LuaUI/Shaders/DrawPrimitiveAtUnitNoGS.vert.glsl"
local fsSrcPath = "LuaUI/Shaders/DrawPrimitiveAtUnitNoGS.frag.glsl"

local shaderSourceCache = {
		vssrcpath = vsSrcPath,
		fssrcpath = fsSrcPath,
		shaderName = "DrawPrimitiveAtUnitNoGS",
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
	-- NoGS: per-unit data advances per INSTANCE (divisor 1), and the VS emits
	-- (MAXVERTICES-2)*3 vertices/instance via gl_VertexID. (The GS variant
	-- uses AttachVertexBuffer + GL.POINTS instead.)
	DrawPrimitiveAtUnitVAO:AttachInstanceBuffer(DrawPrimitiveAtUnitVBO.instanceVBO)
	DrawPrimitiveAtUnitVBO.VAO = DrawPrimitiveAtUnitVAO
	-- Vertices per instance = the triangle-list size of a (MAXVERTICES)-vertex
	-- triangle strip. Widgets draw with:
	--   VBO.VAO:DrawArrays(GL.TRIANGLES, VBO.numVerts, 0, VBO.usedElements)
	DrawPrimitiveAtUnitVBO.numVerts = (math.max(3, shaderConfig.MAXVERTICES or 4) - 2) * 3
	return  DrawPrimitiveAtUnitVBO, DrawPrimitiveAtUnitShader
end

return {InitDrawPrimitiveAtUnit = InitDrawPrimitiveAtUnit, shaderConfig = shaderConfig}
