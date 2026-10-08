if gl.CreateShader == nil then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Contrast Adaptive Sharpen",
		desc = "Spring port of AMD FidelityFX' Contrast Adaptive Sharpen (CAS)",
		author = "martymcmodding, ivand",
		layer = 2000,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spEcho = Spring.Echo

-- Shameless port from https://gist.github.com/martymcmodding/30304c4bffa6e2bd2eb59ff8bb09d135

-----------------------------------------------------------------
-- Constants
-----------------------------------------------------------------

local SHARPNESS = 1.0
local version = 1.06

-- RCAS from AMD FSR 1 instead of CAS: sharper, fewer color fringes along saturated edges, same cost
local USE_RCAS = true
-- with MSAA, scale each pixel's samples instead of overwriting them, so edges keep the driver's resolve
-- (gamma correct on NVIDIA); costs a framebuffer read
local PRESERVE_MSAA_EDGES = true

-----------------------------------------------------------------
-- Lua Shortcuts
-----------------------------------------------------------------

local glTexture = gl.Texture
local glBlending = gl.Blending
local GL_TRIANGLES = GL.TRIANGLES
local GL_ONE = GL.ONE
local GL_SRC1_COLOR = 0x88F9

-----------------------------------------------------------------
-- Shader Sources
-----------------------------------------------------------------

local vsCAS = [[
#version 330
// full screen triangle
const vec2 vertices[3] = vec2[3](vec2(-1.0, -1.0), vec2(3.0, -1.0), vec2(-1.0, 3.0));

void main() {
	gl_Position = vec4(vertices[gl_VertexID], 0.0, 1.0);
}
]]

local fsCAS = [[
#version 330
//__DEFINES__
#line 20063

uniform sampler2D screenCopyTex;
uniform ivec4 viewRect; // xy: view position in the window, zw: last texel of the screen copy
uniform float strength; // CAS: -1 / (8 - 3 * sharpness), RCAS: lobe scale

#if PRESERVE_MSAA_EDGES
// dual source blending: every sample of the pixel becomes offset + sample * scale
layout(location = 0, index = 0) out vec4 fragColor;
layout(location = 0, index = 1) out vec4 fragScale;
#else
out vec4 fragColor;
#endif

void main() {
	ivec2 p = ivec2(gl_FragCoord.xy) - viewRect.xy;
	// fetches outside the texture are undefined, so the edge texels repeat
	ivec2 lo = max(p - 1, ivec2(0));
	ivec2 hi = min(p + 1, viewRect.zw);

	//   b
	// d e f
	//   h
	vec3 b = texelFetch(screenCopyTex, ivec2(p.x, lo.y), 0).rgb;
	vec3 d = texelFetch(screenCopyTex, ivec2(lo.x, p.y), 0).rgb;
	vec3 e = texelFetch(screenCopyTex, p, 0).rgb;
	vec3 f = texelFetch(screenCopyTex, ivec2(hi.x, p.y), 0).rgb;
	vec3 h = texelFetch(screenCopyTex, ivec2(p.x, hi.y), 0).rgb;

#if RCAS
	// the strongest negative lobe that clips no channel, one for all channels
	vec3 mn4 = min(min(b, d), min(f, h));
	vec3 mx4 = max(max(b, d), max(f, h));
	vec3 hitMin = min(mn4, e) / (4.0 * mx4);
	vec3 hitMax = (1.0 - max(mx4, e)) / (4.0 * mn4 - 4.0);
	// an all black or all white ring cannot clip on that side (0/0 above)
	hitMin = mix(hitMin, vec3(1.0e4), equal(mx4, vec3(0.0)));
	hitMax = mix(hitMax, vec3(-1.0e4), equal(mn4, vec3(1.0)));
	vec3 lobeRGB = max(-hitMin, hitMax);
	float lobe = max(-0.1875, min(max(max(lobeRGB.r, lobeRGB.g), lobeRGB.b), 0.0)) * strength;
	vec3 outColor = (lobe * ((b + d) + (f + h)) + e) * (1.0 / (4.0 * lobe + 1.0));
#else
	// the negative lobe shrinks as the neighborhood approaches the signal limits
	vec3 mn = min(min(min(d, e), min(f, b)), h);
	vec3 mx = max(max(max(d, e), max(f, b)), h);
	vec3 amp = clamp(min(mn, 1.0 - mx) * (1.0 / max(mx, 1.0e-5)), 0.0, 1.0);
	vec3 w = sqrt(amp) * strength;
	vec3 outColor = clamp((((b + d) + (f + h)) * w + e) * (1.0 / (1.0 + 4.0 * w)), 0.0, 1.0);
#endif

#if PRESERVE_MSAA_EDGES
	// e is the average of the samples: scale them toward white or black until it lands on outColor
	outColor = clamp(outColor, 0.0, 1.0);
	bvec3 up = greaterThanEqual(outColor, e);
	vec3 scale = mix(outColor, 1.0 - outColor, up) / max(mix(e, 1.0 - e, up), 1.0e-5);
	fragColor = vec4(mix(vec3(0.0), 1.0 - scale, up), 1.0);
	fragScale = vec4(scale, 0.0);
#else
	fragColor = vec4(outColor, 1.0);
#endif
}
]]

-----------------------------------------------------------------
-- Global Variables
-----------------------------------------------------------------

local LuaShader = gl.LuaShader

local vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
local screenCopyTex
local casShader
local useRcas, preserveEdges = false, false

local fullTexQuad

-----------------------------------------------------------------
-- Widget Functions
-----------------------------------------------------------------

local function UpdateShader()
	casShader:ActivateWith(function()
		casShader:SetUniform("strength", useRcas and SHARPNESS or -1 / (8 - 3 * SHARPNESS))
		casShader:SetUniformInt("viewRect", vpx, vpy, vsx - 1, vsy - 1)
	end)
end

local function CompileShader(rcas, preserve)
	local defines = "#define RCAS " .. (rcas and 1 or 0) .. "\n#define PRESERVE_MSAA_EDGES " .. (preserve and 1 or 0)
	local shader = LuaShader({
		vertex = vsCAS,
		fragment = fsCAS:gsub("//__DEFINES__", defines),
		uniformInt = {
			screenCopyTex = 0,
		},
	}, "Contrast Adaptive Sharpen")
	if shader:Initialize() then
		useRcas, preserveEdges = rcas, preserve
		return shader
	end
end

function widget:Initialize()
	if gl.CreateShader == nil then
		spEcho("CAS: createshader not supported, removing")
		widgetHandler:RemoveWidget()
		return
	end

	local preserve = PRESERVE_MSAA_EDGES and Spring.GetConfigInt("MSAALevel", 0) > 0
	casShader = CompileShader(USE_RCAS, preserve)
	if not casShader and (USE_RCAS or preserve) then
		spEcho("Contrast Adaptive Sharpen: falling back to plain CAS")
		casShader = CompileShader(false, false)
	end
	if not casShader then
		spEcho("Failed to compile Contrast Adaptive Sharpen shader, removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	UpdateShader()

	fullTexQuad = gl.GetVAO()
	if fullTexQuad == nil then
		widgetHandler:RemoveWidget() --no fallback for potatoes
		return
	end

	WG.cas = {}
	WG.cas.setSharpness = function(value)
		SHARPNESS = value
		UpdateShader()
	end
	WG.cas.getSharpness = function()
		return SHARPNESS
	end
end

function widget:Shutdown()
	if casShader then
		casShader:Finalize()
	end
	if fullTexQuad then
		fullTexQuad:Delete()
	end
end

function widget:ViewResize()
	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	UpdateShader()
end

function widget:DrawScreenEffects()
	if WG.screencopymanager and WG.screencopymanager.GetScreenCopy then
		screenCopyTex = WG.screencopymanager.GetScreenCopy()
	else
		spEcho("Missing Screencopy Manager, exiting", WG.screencopymanager)
		widgetHandler:RemoveWidget()
		return false
	end
	if screenCopyTex == nil then
		return
	end
	glTexture(0, screenCopyTex)
	if preserveEdges then
		glBlending(GL_ONE, GL_SRC1_COLOR)
	else
		glBlending(false)
	end
	casShader:Activate()
	fullTexQuad:DrawArrays(GL_TRIANGLES, 3)
	casShader:Deactivate()
	if preserveEdges then
		glBlending("alpha")
	else
		glBlending(true)
	end
	glTexture(0, false)
end

function widget:GetConfigData()
	return {
		version = version,
		SHARPNESS = SHARPNESS,
	}
end

function widget:SetConfigData(data)
	if data.SHARPNESS ~= nil and data.version ~= nil and data.version == version then
		SHARPNESS = data.SHARPNESS
	end
end
