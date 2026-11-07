--------------------------------------------------------------------------------
-- Shared range coverage mask targets
--
-- Used by gui_attackrange_gl4.lua and gui_defenserange_gl4.lua. Both merge overlapping
-- range discs into one outline. Filling every disc into the stencil buffer of the main
-- framebuffer costs the summed disc areas at full multisampled resolution, tens of times
-- the screen for a few hundred rings. Instead the discs are drawn into this private,
-- single-sample FBO and the depth test does the merging: the first disc drawn wins per
-- pixel and the hierarchical depth test rejects the overlapping ones before they are
-- rasterized. The 8-bit red channel holds one bit per ring class (additive blend), so a
-- widget can clip its outlines per class by reading the texture.
--
-- The targets are shared through WG so the widgets pay for one set of screen-sized
-- textures. A widget has to finish reading the mask within the draw callin that filled
-- it, the next user overwrites it.
--------------------------------------------------------------------------------

local GL_R8 = GL.R8 or 0x8229
local GL_DEPTH_COMPONENT16 = GL.DEPTH_COMPONENT16 or 0x81A5
local GL_COLOR_ATTACHMENT0 = GL.COLOR_ATTACHMENT0 or 0x8CE0

local RangeCoverageMask = {}

local function sharedState()
	WG.rangeCoverageMaskGL4 = WG.rangeCoverageMaskGL4 or { users = 0, sizeX = 0, sizeY = 0 }
	return WG.rangeCoverageMaskGL4
end

local function deleteTargets(state)
	if state.fbo then
		gl.DeleteFBO(state.fbo)
		state.fbo = nil
	end
	if state.texture then
		gl.DeleteTexture(state.texture)
		state.texture = nil
	end
	if state.depthTexture then
		gl.DeleteTexture(state.depthTexture)
		state.depthTexture = nil
	end
	state.sizeX, state.sizeY = 0, 0
end

local function createTargets(state, vsx, vsy)
	deleteTargets(state)
	local texOpts = {
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		format = GL_R8,
	}
	state.texture = gl.CreateTexture(vsx, vsy, texOpts)
	texOpts.format = GL_DEPTH_COMPONENT16
	state.depthTexture = gl.CreateTexture(vsx, vsy, texOpts)
	if state.texture and state.depthTexture then
		state.fbo = gl.CreateFBO({
			color0 = state.texture,
			depth = state.depthTexture,
			drawbuffers = { GL_COLOR_ATTACHMENT0 },
		})
	end
	if not (state.fbo and gl.IsValidFBO(state.fbo)) then
		deleteTargets(state)
		state.failedSizeX, state.failedSizeY = vsx, vsy
		Spring.Echo("Range coverage mask: could not create the FBO targets, range widgets use their stencil path")
		return false
	end
	state.failedSizeX, state.failedSizeY = nil, nil
	state.sizeX, state.sizeY = vsx, vsy
	return true
end

--- Registers a user of the shared targets. Call once from widget:Initialize and pair it
--- with Release in widget:Shutdown; the targets are freed with the last user.
function RangeCoverageMask.Acquire()
	local state = sharedState()
	state.users = state.users + 1
end

function RangeCoverageMask.Release()
	local state = sharedState()
	state.users = math.max(0, state.users - 1)
	if state.users == 0 then
		deleteTargets(state)
	end
end

--- Returns the FBO and its R8 colour texture, sized to the current world view, or nil when
--- they cannot be created. Call from a draw callin; the targets are (re)created on demand.
function RangeCoverageMask.Get()
	local state = sharedState()
	local vsx, vsy = Spring.GetViewGeometry()
	if state.fbo and state.sizeX == vsx and state.sizeY == vsy then
		return state.fbo, state.texture
	end
	if state.failedSizeX == vsx and state.failedSizeY == vsy then
		return nil -- already failed at this size, do not retry every frame
	end
	if not createTargets(state, vsx, vsy) then
		return nil
	end
	return state.fbo, state.texture
end

return RangeCoverageMask
