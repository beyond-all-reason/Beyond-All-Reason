local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Ghost Hover",
		desc = "Render highlighted remembered models with BAR's shared hover shimmer",
		author = "BAR contributors",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

---@type integer?
local shader
---@type table<string, GL>
local uniforms = {}

function widget:Initialize()
	if not gl.GhostRaw then
		widgetHandler:RemoveWidget(self)
		return
	end
	local fragment = VFS.LoadFile("luaui/Shaders/ghost_hover.frag.glsl")
	local vertex = VFS.LoadFile("luaui/Shaders/ghost_hover.vert.glsl")
	local shimmer = VFS.LoadFile("modelmaterials_gl4/templates/hover_shimmer.glsl")
	if not (fragment and vertex and shimmer) then
		Spring.Echo("[Ghost Hover] Missing shader source; keeping engine rendering")
		widgetHandler:RemoveWidget(self)
		return
	end
	fragment = fragment:gsub("//__HOVER_SHIMMER__", function()
		return shimmer
	end)
	shader = gl.CreateShader({
		vertex = vertex,
		fragment = fragment,
		uniformInt = { diffuseTex = 0, shadingTex = 1 },
	})
	if not shader then
		Spring.Echo("[Ghost Hover] Shader compilation failed: " .. gl.GetShaderLog())
		widgetHandler:RemoveWidget(self)
		return
	end
	for _, name in ipairs({ "viewInverse", "ghostColor", "teamColor", "sunDir", "sunAmbient", "sunDiffuse", "simFrame" }) do
		uniforms[name] = gl.GetUniformLocation(shader, name)
	end
end

---@param info GhostDrawInfo
---@return boolean
function widget:DrawGhost(info)
	if not shader or (info.state ~= "ghostHighlight" and info.state ~= "radarGhostHighlight") then
		return false
	end
	gl.UseShader(shader)
	gl.UniformMatrix(uniforms.viewInverse, "viewinverse")
	gl.Uniform(uniforms.ghostColor, info.color[1], info.color[2], info.color[3], info.color[4])
	gl.Uniform(uniforms.teamColor, info.teamColor[1], info.teamColor[2], info.teamColor[3], info.teamColor[4])
	local sunDirX, sunDirY, sunDirZ = gl.GetSun("pos", "unit")
	gl.Uniform(uniforms.sunDir, assert(sunDirX), assert(sunDirY), assert(sunDirZ))
	local sunAmbientR, sunAmbientG, sunAmbientB = gl.GetSun("ambient", "unit")
	gl.Uniform(uniforms.sunAmbient, assert(sunAmbientR), assert(sunAmbientG), assert(sunAmbientB))
	local sunDiffuseR, sunDiffuseG, sunDiffuseB = gl.GetSun("diffuse", "unit")
	gl.Uniform(uniforms.sunDiffuse, assert(sunDiffuseR), assert(sunDiffuseG), assert(sunDiffuseB))
	gl.Uniform(uniforms.simFrame, Spring.GetGameFrame() + (Spring.GetFrameTimeOffset() or 0))
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.GhostRaw()
	gl.UseShader(0)
	return true
end

function widget:Shutdown()
	if shader then
		gl.DeleteShader(shader)
		shader = nil
	end
end
