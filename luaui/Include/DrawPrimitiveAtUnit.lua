-------------------------------------------------
-- An API wrapper to draw simple graphical primitives at units extremely efficiently
-- License: GNU GPL V2
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
	USEQUATERNIONS = Engine.FeatureSupport.transformsInGL4 and "1" or "0",
}

---- GL4 Backend Stuff----
local DrawPrimitiveAtUnitVBO = nil
local DrawPrimitiveAtUnitShader = nil

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

-- Use the geometry shader pipeline when supported, otherwise fall back to an
-- instanced triangle-fan template mesh that expands each unit point into a
-- primitive inside the vertex shader. Set to false to force-test the fallback.
local useGeometryShader = LuaShader.isGeometryShaderSupported

local vsSrcPath = "LuaUI/Shaders/DrawPrimitiveAtUnit.vert.glsl"
local gsSrcPath = "LuaUI/Shaders/DrawPrimitiveAtUnit.geom.glsl"
local fsSrcPath = "LuaUI/Shaders/DrawPrimitiveAtUnit.frag.glsl"
local vsFallbackSrcPath = "LuaUI/Shaders/DrawPrimitiveAtUnit_nogs.vert.glsl"

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

local fallbackShaderSourceCache = {
		vssrcpath = vsFallbackSrcPath,
		fssrcpath = fsSrcPath,
		shaderName = "DrawPrimitiveAtUnit (NoGS)",
		uniformInt = {},
		uniformFloat = {
			addRadius = 0.0,
			iconDistance = 20000.0,
		  },
		shaderConfig = shaderConfig,
	}

local function InitDrawPrimitiveAtUnit(shaderConfig, DPATname)
	local uniformInt = shaderConfig.USETEXTURE and {DrawPrimitiveAtUnitTexture = 0,} or {}

	shaderSourceCache.shaderName = DPATname .. "Shader GL4"
	shaderSourceCache.shaderConfig = shaderConfig
	shaderSourceCache.uniformInt = uniformInt

	fallbackShaderSourceCache.shaderName = DPATname .. "Shader GL4 (NoGS)"
	fallbackShaderSourceCache.shaderConfig = shaderConfig
	fallbackShaderSourceCache.uniformInt = uniformInt

	local useGeometryShaderForThisShader = useGeometryShader
	local compiledShader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	if not compiledShader then
		useGeometryShaderForThisShader = false
		compiledShader = LuaShader.CheckShaderUpdates(fallbackShaderSourceCache)
	end

	DrawPrimitiveAtUnitShader = compiledShader or DrawPrimitiveAtUnitShader

	if not DrawPrimitiveAtUnitShader then
		Spring.Echo("Failed to compile shader for ", DPATname)
		return nil
	end

	-- In the geometry shader path each instance is a single vertex (a point), so
	-- the instance attributes live at locations 0..5. In the fallback path we draw
	-- a template mesh whose vertex attribute occupies location 0, so the instance
	-- attributes are shifted up to locations 1..6.
	local instanceLayout
	local unitIDattribID
	if useGeometryShaderForThisShader then
		instanceLayout = {
			{id = 0, name = 'lengthwidthcorner', size = 4},
			{id = 1, name = 'teamID', size = 1, type = GL.UNSIGNED_INT},
			{id = 2, name = 'numvertices', size = 1, type = GL.UNSIGNED_INT},
			{id = 3, name = 'parameters', size = 4},
			{id = 4, name = 'uvoffsets', size = 4},
			{id = 5, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
		}
		unitIDattribID = 5
	else
		instanceLayout = {
			{id = 1, name = 'lengthwidthcorner', size = 4},
			{id = 2, name = 'teamID', size = 1, type = GL.UNSIGNED_INT},
			{id = 3, name = 'numvertices', size = 1, type = GL.UNSIGNED_INT},
			{id = 4, name = 'parameters', size = 4},
			{id = 5, name = 'uvoffsets', size = 4},
			{id = 6, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
		}
		unitIDattribID = 6
	end

	DrawPrimitiveAtUnitVBO = InstanceVBOTable.makeInstanceVBOTable(
		instanceLayout,
		64, -- maxelements
		DPATname .. "VBO", -- name
		unitIDattribID  -- unitIDattribID (instData)
	)
	if DrawPrimitiveAtUnitVBO == nil then
		Spring.Echo("Failed to create DrawPrimitiveAtUnitVBO for ", DPATname)
		return nil
	end

	if useGeometryShaderForThisShader then
		local DrawPrimitiveAtUnitVAO = gl.GetVAO()
		DrawPrimitiveAtUnitVAO:AttachVertexBuffer(DrawPrimitiveAtUnitVBO.instanceVBO)
		DrawPrimitiveAtUnitVBO.VAO = DrawPrimitiveAtUnitVAO
	else
		-- Build a template triangle-fan mesh whose perimeter slots are expanded
		-- per primitive inside the fallback vertex shader. numSlots must cover the
		-- largest perimeter the widget can draw (circles up to 64, cornerrect 8).
		local numSlots = math.max(shaderConfig.MAXVERTICES or 64, 8)

		local templateVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
		templateVBO:Define(numSlots, {{id = 0, name = 'vinfo', size = 1}})
		local vertexData = {}
		for s = 0, numSlots - 1 do
			vertexData[#vertexData + 1] = s
		end
		templateVBO:Upload(vertexData)

		local indexData = {}
		for i = 1, numSlots - 2 do -- fan from slot 0
			indexData[#indexData + 1] = 0
			indexData[#indexData + 1] = i
			indexData[#indexData + 1] = i + 1
		end
		local indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
		indexVBO:Define(#indexData)
		indexVBO:Upload(indexData)

		local realVAO = InstanceVBOTable.makeVAOandAttach(templateVBO, DrawPrimitiveAtUnitVBO.instanceVBO, indexVBO)
		if realVAO == nil then
			Spring.Echo("Failed to create fallback VAO for ", DPATname)
			return nil
		end

		-- Wrap the real VAO so existing consumers can keep calling
		-- VBO.VAO:DrawArrays(GL.POINTS, usedElements); under the hood we draw the
		-- template mesh instanced once per element.
		local indexCount = #indexData
		DrawPrimitiveAtUnitVBO.VAO = {
			realVAO = realVAO,
			indexCount = indexCount,
			DrawArrays = function(self, _primitiveType, instanceCount)
				if instanceCount and instanceCount > 0 then
					self.realVAO:DrawElements(GL.TRIANGLES, self.indexCount, 0, instanceCount)
				end
			end,
			Delete = function(self)
				self.realVAO:Delete()
			end,
		}
	end
	return  DrawPrimitiveAtUnitVBO, DrawPrimitiveAtUnitShader
end

return {InitDrawPrimitiveAtUnit = InitDrawPrimitiveAtUnit, shaderConfig = shaderConfig}
