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

local shader
local uniforms = {}

function widget:Initialize()
	if not gl.GhostRaw then
		widgetHandler:RemoveWidget(self)
		return
	end
	local fragment = VFS.LoadFile("luaui/Shaders/ghost_hover.frag.glsl")
	fragment = fragment:gsub("//__HOVER_SHIMMER__", function()
		return VFS.LoadFile("modelmaterials_gl4/templates/hover_shimmer.glsl")
	end)
	shader = gl.CreateShader({
		vertex = VFS.LoadFile("luaui/Shaders/ghost_hover.vert.glsl"),
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
	gl.Uniform(uniforms.ghostColor, unpack(info.color))
	gl.Uniform(uniforms.teamColor, unpack(info.teamColor))
	gl.Uniform(uniforms.sunDir, gl.GetSun("pos"))
	gl.Uniform(uniforms.sunAmbient, gl.GetSun("ambient", "unit"))
	gl.Uniform(uniforms.sunDiffuse, gl.GetSun("diffuse", "unit"))
	gl.Uniform(uniforms.simFrame, Spring.GetGameFrame() + Spring.GetFrameTimeOffset())
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
