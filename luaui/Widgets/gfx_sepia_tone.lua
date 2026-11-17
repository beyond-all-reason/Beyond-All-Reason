local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Sepia Tone",
		desc = "Gives that warm, urine like color we all love from 2000s era games.",
		author = "Beherith",
		date = "2023.01.05",
		license = "GNU GPL, v2 or later",
		layer = 200000,
		enabled = false,
	}
end

-- Localized Spring API for performance
local spEcho = Spring.Echo

local glTexture = gl.Texture
local glBlending = gl.Blending
local GL_TRIANGLES = GL.TRIANGLES

---------------------------------------

---@type { gamma: number, saturation: number, contrast: number, sepia: number, shadeUI: boolean }
local params = { gamma = 0.5, saturation = 0.5, contrast = 0.5, sepia = 0, shadeUI = false }

-- skip draw if this matches:
local defaultParams = { gamma = 0.5, saturation = 0.5, contrast = 0.5, sepia = 0.0 }

local LUMINANCE = { 0.3086, 0.6094, 0.0820 } ---@type table<integer, number>
---@type table<integer, table<integer, number>>
local SEPIA = { { 0.393, 0.769, 0.189 }, { 0.349, 0.686, 0.168 }, { 0.272, 0.534, 0.131 } }
local COLOR_ROWS = { "colorR", "colorG", "colorB" } ---@type table<integer, string>

-----------------------------------------------------------------
-- Shader Sources
-----------------------------------------------------------------

local vsSepia = [[
#version 330
// full screen triangle
const vec2 vertices[3] = vec2[3](vec2(-1.0, -1.0), vec2(3.0, -1.0), vec2(-1.0, 3.0));

void main() {
	gl_Position = vec4(vertices[gl_VertexID], 0.0, 1.0);
}
]]

local fsSepia = [[
#version 330

uniform sampler2D screenCopyTex;
uniform ivec2 viewPos;
uniform float gamma;
// rows of the color matrix: contrast * saturation, blended toward sepia
uniform vec3 colorR;
uniform vec3 colorG;
uniform vec3 colorB;

out vec4 fragColor;

void main() {
	vec3 color = pow(texelFetch(screenCopyTex, ivec2(gl_FragCoord.xy) - viewPos, 0).rgb, vec3(gamma));
	fragColor = vec4(dot(colorR, color), dot(colorG, color), dot(colorB, color), 1.0);
}
]]

-----------------------------------------------------------------
-- Global Variables
-----------------------------------------------------------------

local LuaShader = gl.LuaShader

local sepiaShader ---@type LuaShader

local fullTexQuad ---@type VAO
local fullTexQuadBuffers = {}

-- the triangle comes from gl_VertexID; the unused buffers are attached because engines without the
-- LuaVAO keep-partial fix (RecoilEngine #3446) rebuild a VAO every draw unless it has all three kinds
local function CreateTriangleVAO()
	local vao = gl.GetVAO()
	local vertexVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	local indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	local instanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if not (vao and vertexVBO and indexVBO and instanceVBO) then
		return nil
	end
	vertexVBO:Define(3, { { id = 0, name = "unused", size = 1 } })
	vertexVBO:Upload({ 0, 0, 0 })
	indexVBO:Define(3)
	indexVBO:Upload({ 0, 1, 2 })
	instanceVBO:Define(1, { { id = 1, name = "unusedInstance", size = 1 } })
	instanceVBO:Upload({ 0 })
	vao:AttachVertexBuffer(vertexVBO)
	vao:AttachIndexBuffer(indexVBO)
	vao:AttachInstanceBuffer(instanceVBO)
	fullTexQuadBuffers = { vertexVBO, indexVBO, instanceVBO }
	return vao
end

-- set by the param setters, ViewResize and Initialize, none of which may touch GL; uploaded at the next draw
local uniformsDirty = true

local function UploadUniforms()
	uniformsDirty = false
	local _, _, vpx, vpy = Spring.GetViewGeometry()
	-- the old shader's contrast offset was scaled by its unwritten output alpha (0 on NVIDIA), so contrast
	-- scales from black
	local contrast, saturation, sepia = params.contrast + 0.5, params.saturation + 0.5, params.sepia
	local cs = {}
	for i = 1, 3 do
		cs[i] = {}
		for j = 1, 3 do
			cs[i][j] = contrast * (LUMINANCE[j] * (1 - saturation) + (i == j and saturation or 0))
		end
	end

	sepiaShader:SetUniformInt("viewPos", vpx, vpy)
	sepiaShader:SetUniform("gamma", params.gamma + 0.5)
	for i = 1, 3 do
		local row, s = {}, SEPIA[i]
		for j = 1, 3 do
			local toned = s[1] * cs[1][j] + s[2] * cs[2][j] + s[3] * cs[3][j]
			row[j] = cs[i][j] + (toned - cs[i][j]) * sepia
		end
		sepiaShader:SetUniform(COLOR_ROWS[i], row[1], row[2], row[3])
	end
end

-- only the callin that draws the effect stays registered, none while the params are at the default
local function UpdateParams()
	local active = false
	for k, v in pairs(defaultParams) do
		if math.abs(params[k] - v) > 0.001 then
			active = true
		end
	end
	if active and params.shadeUI == true then
		widgetHandler:RemoveCallIn("DrawScreenEffects")
		widgetHandler:UpdateCallIn("DrawScreenPost")
	elseif active then
		widgetHandler:UpdateCallIn("DrawScreenEffects")
		widgetHandler:RemoveCallIn("DrawScreenPost")
	else
		widgetHandler:RemoveCallIn("DrawScreenEffects")
		widgetHandler:RemoveCallIn("DrawScreenPost")
	end
	uniformsDirty = true
end

local function sepiatoneCmd(_, line)
	local s = string.split(line or "", " ")
	spEcho("/luaui sepiatone gamma saturation contrast sepia shadeUI")
	spEcho("sepiatone " .. (line or ""))
	params.gamma = tonumber(s[1]) or params.gamma
	params.saturation = tonumber(s[2]) or params.saturation
	params.contrast = tonumber(s[3]) or params.contrast
	params.sepia = tonumber(s[4]) or params.sepia
	if s[5] ~= nil then
		params.shadeUI = s[5] == "true"
	end
	UpdateParams()
	return true
end

function widget:Initialize()
	if gl.CreateShader == nil then
		spEcho("Sepia: createshader not supported, removing")
		widgetHandler:RemoveWidget()
		return
	end

	sepiaShader = LuaShader({
		vertex = vsSepia,
		fragment = fsSepia,
		uniformInt = {
			screenCopyTex = 0,
		},
	}, ": Sepia")

	local shaderCompiled = sepiaShader:Initialize()
	if not shaderCompiled then
		spEcho("Failed to compile Sepia shader, removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	local vao = CreateTriangleVAO()
	if vao == nil then
		widgetHandler:RemoveWidget() --no fallback for potatoes
		return
	end
	fullTexQuad = vao

	widgetHandler:AddAction("sepiatone", sepiatoneCmd, nil, "t")
	UpdateParams()

	WG.sepia = {}
	WG.sepia.setGamma = function(value)
		params.gamma = value
		UpdateParams()
	end
	WG.sepia.getGamma = function()
		return params.gamma
	end
	WG.sepia.setSaturation = function(value)
		params.saturation = value
		UpdateParams()
	end
	WG.sepia.getSaturation = function()
		return params.saturation
	end
	WG.sepia.setContrast = function(value)
		params.contrast = value
		UpdateParams()
	end
	WG.sepia.getContrast = function()
		return params.contrast
	end
	WG.sepia.setSepia = function(value)
		params.sepia = value
		UpdateParams()
	end
	WG.sepia.getSepia = function()
		return params.sepia
	end
	WG.sepia.setShadeUI = function(value)
		params.shadeUI = value
		UpdateParams()
	end
	WG.sepia.getShadeUI = function()
		return params.shadeUI
	end
end

function widget:Shutdown()
	widgetHandler:RemoveAction("sepiatone", "t")
	WG.sepia = nil
	if sepiaShader then
		sepiaShader:Finalize()
	end
	if fullTexQuad then
		fullTexQuad:Delete()
	end
	for _, vbo in ipairs(fullTexQuadBuffers) do
		vbo:Delete()
	end
end

function widget:ViewResize()
	uniformsDirty = true
end

-- the shared screen copy instead of an own full-screen texture; the drawing has to invalidate it
local function DoSepia(screenCopyManager)
	local screenCopyTex = screenCopyManager.GetScreenCopy()
	if screenCopyTex == nil then
		return
	end
	glTexture(0, screenCopyTex)
	glBlending(false) -- the shader writes alpha 1, blending would only read the screen back
	sepiaShader:Activate()
	if uniformsDirty then
		UploadUniforms()
	end
	fullTexQuad:DrawArrays(GL_TRIANGLES, 3)
	sepiaShader:Deactivate()
	glBlending("alpha")
	glTexture(0, false)
	screenCopyManager.InvalidateScreenCopy() -- later readers (CAS, guishader) need the toned screen
end

function widget:DrawScreenEffects()
	local screenCopyManager = WG.screencopymanager ---@type table?
	if screenCopyManager then
		DoSepia(screenCopyManager)
	end
end

function widget:DrawScreenPost()
	local screenCopyManager = WG.screencopymanager ---@type table?
	if screenCopyManager then
		screenCopyManager.InvalidateScreenCopy() -- this frame's copy was taken before the UI drew
		DoSepia(screenCopyManager)
	end
end

function widget:GetConfigData()
	return params
end

function widget:SetConfigData(data)
	for k, v in pairs(data) do
		params[k] = data[k] or v
	end
end
