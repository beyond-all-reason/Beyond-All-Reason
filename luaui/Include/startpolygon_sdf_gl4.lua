--------------------------------------------------------------------------------
-- Baked start polygon distance field
--
-- Shared by gfx_norush_timer_gl4.lua and map_startbox.lua. Both draw a fullscreen pass
-- that needs the distance from every pixel to the start polygons. Walking the (spline
-- tessellated) polygon edges per pixel per frame cost more than the rest of the frame,
-- so the field is rendered once into a map-sized texture and the per-frame shaders
-- sample that instead.
--
-- Texel layout, one texel per TEXEL_ELMOS (see startpolygon_sdf_bake_gl4.frag.glsl):
--   x = signed distance to the closest polygon, negative inside
--   y = key of that polygon (whatever the caller stored in the SSBO: team or allyteam id)
--   z = distance to the edge of the containing polygon, negative outside
--   w = flags: bit 0 own allyteam box, bit 1 scav box, bit 2 raptor box,
--       bits 3+ number of enemy boxes (capped at 2)
--
-- Bake() issues gl.RenderToTexture, so it may only run from a world draw callin: the
-- engine restores framebuffer 0 afterwards, which would break the minimap texture pass.
--------------------------------------------------------------------------------

local TEXEL_ELMOS = 8
local MAX_TEXTURE_SIZE = 1024

local GL_TRIANGLES = GL.TRIANGLES
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local StartPolygonSDF = {}
StartPolygonSDF.__index = StartPolygonSDF

--- Creates the texture and the bake shader.
--- @param params table { format = GL.RG32F|GL.RGBA16F, shaderName = string,
---   shaderConfig = { NUM_POLYGONS, NUM_POINTS, SCAV_ALLYTEAM_ID?, RAPTOR_ALLYTEAM_ID? } }
--- @return table|nil sdf, string|nil error
function StartPolygonSDF.Create(params)
	local sizeX = math.min(MAX_TEXTURE_SIZE, math.ceil(Game.mapSizeX / TEXEL_ELMOS))
	local sizeY = math.min(MAX_TEXTURE_SIZE, math.ceil(Game.mapSizeZ / TEXEL_ELMOS))

	local texture = gl.CreateTexture(sizeX, sizeY, {
		format = params.format,
		min_filter = GL.NEAREST, -- the shaders filter by hand, see SampleStartPolygonSDF
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})
	if not texture then
		return nil, "could not allocate the start polygon distance field texture"
	end

	local shaderSourceCache = {
		vssrcpath = "LuaUI/Shaders/startpolygon_sdf_bake_gl4.vert.glsl",
		fssrcpath = "LuaUI/Shaders/startpolygon_sdf_bake_gl4.frag.glsl",
		uniformInt = {
			myAllyTeamID = -1,
		},
		uniformFloat = {},
		shaderName = params.shaderName,
		shaderConfig = params.shaderConfig,
	}
	local shader = gl.LuaShader.CheckShaderUpdates(shaderSourceCache)
	if not shader then
		gl.DeleteTexture(texture)
		return nil, "start polygon distance field bake shader failed to compile"
	end

	local self = setmetatable({}, StartPolygonSDF)
	self.texture = texture
	self.sizeX = sizeX
	self.sizeY = sizeY
	self.shader = shader
	self.shaderSourceCache = shaderSourceCache
	self.bakedAllyTeamID = nil
	return self
end

--- Renders the field. World draw callins only (see header).
--- @param polygonBuffer table SSBO of { key, numVertices, x, z } quads
--- @param rectVAO table fullscreen rect VAO from InstanceVBOTable.MakeTexRectVAO()
--- @param myAllyTeamID number|nil allyteam the flags channel treats as "own" (only matters
---   when the buffer keys are allyteam ids)
function StartPolygonSDF:Bake(polygonBuffer, rectVAO, myAllyTeamID)
	myAllyTeamID = myAllyTeamID or -1
	if not self.drawRect then
		self.drawRect = function()
			rectVAO:DrawArrays(GL_TRIANGLES)
		end
	end

	polygonBuffer:BindBufferRange(4)

	gl.Culling(false)
	gl.DepthTest(false)
	gl.DepthMask(false)
	gl.Blending(false) -- the channels are data, blending would corrupt them

	self.shader:Activate()
	self.shader:SetUniformInt("myAllyTeamID", myAllyTeamID)
	gl.RenderToTexture(self.texture, self.drawRect)
	self.shader:Deactivate()

	gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA) -- back to the callin default
	self.bakedAllyTeamID = myAllyTeamID
end

--- True once Bake() has run for this allyteam.
function StartPolygonSDF:IsBakedFor(myAllyTeamID)
	return self.bakedAllyTeamID == (myAllyTeamID or -1)
end

function StartPolygonSDF:Delete()
	if self.texture then
		gl.DeleteTexture(self.texture)
		self.texture = nil
	end
	if self.shader then
		self.shader:Delete()
		self.shader = nil
	end
end

return StartPolygonSDF
