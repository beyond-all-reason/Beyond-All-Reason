local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Ghost Hover",
		desc = "Render highlighted remembered models with BAR's shared hover shimmer",
		author = "BAR contributors",
		license = "GNU GPL, v2 or later",
		layer = 0,
		handler = true,
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

local hoverCommands = {
	[CMD.ATTACK] = true,
	[GameCMD.UNIT_SET_TARGET] = true,
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = true,
}

---@type integer?
local hoveredTargetID

local function getHoveredGhost()
	local _, command = Spring.GetActiveCommand()
	if not hoverCommands[command] then
		return
	end
	local x, y, left, middle, _, offscreen, panning = Spring.GetMouseState()
	if
		left
		or middle
		or offscreen
		or panning
		or Spring.IsGUIHidden()
		or Spring.IsAboveMiniMap(x, y)
		or not widgetHandler:ModalAllows(widget)
	then
		return
	end
	local trace = Spring.TraceScreenRay ---@type GhostTraceScreenRay
	local kind, target = trace(x, y, false, false, false, false, 0, true)
	if kind == "ghost" then
		return target --[[@as integer]]
	end
end

-- The handler registers DrawGhost when it inserts the widget.
local drawActive = true
function widget:Update()
	hoveredTargetID = getHoveredGhost()
	local active = hoveredTargetID ~= nil
	if active == drawActive then
		return
	end
	drawActive = active
	if active then
		widgetHandler:UpdateCallIn("DrawGhost")
	else
		widgetHandler:RemoveCallIn("DrawGhost")
	end
end

---@param info GhostDrawInfo
---@return boolean
function widget:DrawGhost(info)
	if not shader or not hoveredTargetID then
		return false
	end
	if info.ghostID ~= hoveredTargetID then
		if hoveredTargetID >= Game.maxUnits or select(4, Spring.GetGhostPosition(info.ghostID)) ~= hoveredTargetID then
			return false
		end
	end
	gl.UseShader(shader)
	gl.UniformMatrix(uniforms.viewInverse, "viewinverse")
	gl.Uniform(uniforms.ghostColor, 1.0, 0.85, 0.45, 0.55)
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
