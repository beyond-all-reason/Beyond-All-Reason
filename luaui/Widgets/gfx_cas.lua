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

-- RCAS from AMD FSR 1 instead of CAS: fewer color fringes along saturated edges, same cost
local USE_RCAS = true
-- with MSAA, scale each pixel's samples instead of overwriting them, so edges keep the driver's resolve
-- (gamma correct on NVIDIA); costs a framebuffer read
local PRESERVE_MSAA_EDGES = true
-- RCAS sharpens bright low-contrast terrain about twice as hard as CAS did, which shimmers when zoomed out.
-- Where the 5 taps span under GRAIN_GATE[1] luma levels the lobe follows CAS's shaping (the original look),
-- above GRAIN_GATE[2] RCAS takes over. GRAIN_NOISE (0..1) scales down one-pixel grain below the gate (isolated
-- pixels and one-pixel lines: minification moire), but only where the terrain is minified: none up to
-- GRAIN_NOISE_FOOTPRINT[1] ground elmos per screen pixel, full from [2], so play zoom keeps its texture detail.
-- /cas_footprint tints the screen red where the penalty applies, for tuning the footprint against the shimmer
local SHAPE_GRAIN = true
local GRAIN_GATE = { 4, 16 }
local GRAIN_NOISE = 0.3
local GRAIN_NOISE_FOOTPRINT = { 0.4, 1.0 }

-----------------------------------------------------------------
-- Lua Shortcuts
-----------------------------------------------------------------

local spGetCameraPosition = Spring.GetCameraPosition
local spTraceScreenRay = Spring.TraceScreenRay
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
#if GRAIN_NOISE_ON
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
//__ENGINEUNIFORMBUFFERDEFS__
#endif
#line 20077

uniform sampler2D screenCopyTex;
uniform ivec4 viewRect; // xy: view position in the window, zw: last texel of the screen copy
uniform float strength; // CAS: -1 / (8 - 3 * sharpness), RCAS: 5 / (8 - 3 * sharpness)
uniform float groundY; // terrain height at the camera target
uniform float debugFootprint; // 1: tint where the grain noise penalty applies

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
	float lobe = max(-0.1875, min(max(max(lobeRGB.r, lobeRGB.g), lobeRGB.b), 0.0));
#if SHAPE_GRAIN || GRAIN_NOISE_ON
	// luma of the taps, 0..2; grain = how far below the gate the local contrast sits
	const vec3 lw = vec3(0.5, 1.0, 0.5);
	float bL = dot(b, lw), dL = dot(d, lw), eL = dot(e, lw), fL = dot(f, lw), hL = dot(h, lw);
	float mnL = min(min(bL, dL), min(min(fL, hL), eL));
	float mxL = max(max(bL, dL), max(max(fL, hL), eL));
	float grain = 1.0 - smoothstep(GRAIN_LO, GRAIN_HI, mxL - mnL);
#endif
#if SHAPE_GRAIN
	// CAS's lobe shrinks as the neighborhood nears black or white; blend to it for grain
	float ampL = clamp(min(mnL, 2.0 - mxL) / max(mxL, 1.0e-5), 0.0, 1.0);
	lobe = max(lobe, mix(lobe, -0.2 * sqrt(ampL), grain));
#endif
#if GRAIN_NOISE_ON
	// one-pixel structure relative to the local contrast: 1 = isolated pixel or one-pixel line, 0.5 = edge, 0 = ramp
	float speck = max(abs((bL + hL) - 2.0 * eL), abs((dL + fL) - 2.0 * eL)) / max(2.0 * (mxL - mnL), 1.0e-5);
	// ground elmos under this pixel: the view ray against the plane at the camera target's height
	vec4 rayEnd = cameraViewProjInv * vec4((vec2(p) + 0.5) / vec2(viewRect.zw + 1) * 2.0 - 1.0, 1.0, 1.0);
	vec3 camPos = cameraViewInv[3].xyz;
	vec3 dir = normalize(rayEnd.xyz / rayEnd.w - camPos);
	float pixelAngle = 2.0 / (cameraProj[1][1] * viewGeometry.y);
	float footprint = (groundY - camPos.y) / min(dir.y, -1.0e-4) * pixelAngle;
	float minified = smoothstep(FOOT_LO, FOOT_HI, footprint);
	lobe *= 1.0 - GRAIN_NOISE * min(speck, 1.0) * grain * minified;
#endif
	lobe *= strength;
	vec3 outColor = (lobe * ((b + d) + (f + h)) + e) * (1.0 / (4.0 * lobe + 1.0));
#else
	// the negative lobe shrinks as the neighborhood approaches the signal limits
	vec3 mn = min(min(min(d, e), min(f, b)), h);
	vec3 mx = max(max(max(d, e), max(f, b)), h);
	vec3 amp = clamp(min(mn, 1.0 - mx) * (1.0 / max(mx, 1.0e-5)), 0.0, 1.0);
	vec3 w = sqrt(amp) * strength;
	vec3 outColor = clamp((((b + d) + (f + h)) * w + e) * (1.0 / (1.0 + 4.0 * w)), 0.0, 1.0);
#endif
#if RCAS && GRAIN_NOISE_ON
	outColor = mix(outColor, vec3(1.0, 0.0, 0.0), 0.5 * debugFootprint * minified);
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
local useRcas, preserveEdges, useNoise = false, false, false
local groundY, camX, camY, camZ = 0.0, nil, nil, nil
local debugFootprint, sentDebugFootprint = false, nil

local fullTexQuad
local fullTexQuadBuffers = {}

-----------------------------------------------------------------
-- Widget Functions
-----------------------------------------------------------------

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

local function UpdateShader()
	casShader:ActivateWith(function()
		-- the options slider (0.5..1.1) keeps the original CAS curve, 1 at sharpness 1
		local peak = 8 - 3 * SHARPNESS
		casShader:SetUniform("strength", useRcas and 5 / peak or -1 / peak)
		casShader:SetUniformInt("viewRect", vpx, vpy, vsx - 1, vsy - 1)
	end)
end

-- the noise term's footprint needs the terrain height the camera looks at: traced when the camera moved
local function UpdateNoiseUniforms(shader)
	local x, y, z = spGetCameraPosition()
	if x ~= camX or y ~= camY or z ~= camZ then
		camX, camY, camZ = x, y, z
		local _, pos = spTraceScreenRay(math.floor(vsx * 0.5), math.floor(vsy * 0.5), true, false, false, true)
		local hitY = pos and pos[2]
		if hitY then
			groundY = hitY
		end
		shader:SetUniform("groundY", groundY)
	end
	if debugFootprint ~= sentDebugFootprint then
		sentDebugFootprint = debugFootprint
		shader:SetUniform("debugFootprint", debugFootprint and 1 or 0)
	end
end

local function ToggleFootprintOverlay()
	debugFootprint = not debugFootprint
	spEcho("Contrast Adaptive Sharpen: footprint overlay " .. (debugFootprint and "on" or "off"))
end

local function CompileShader(rcas, preserve, noise)
	local defines = {
		"#define RCAS " .. (rcas and 1 or 0),
		"#define PRESERVE_MSAA_EDGES " .. (preserve and 1 or 0),
		"#define SHAPE_GRAIN " .. (SHAPE_GRAIN and 1 or 0),
		"#define GRAIN_NOISE_ON " .. (noise and 1 or 0),
		-- the shader's luma spans 0..2
		string.format("#define GRAIN_LO %.5f", GRAIN_GATE[1] * 2 / 255),
		string.format("#define GRAIN_HI %.5f", GRAIN_GATE[2] * 2 / 255),
		string.format("#define GRAIN_NOISE %.3f", GRAIN_NOISE),
		string.format("#define FOOT_LO %.3f", GRAIN_NOISE_FOOTPRINT[1]),
		string.format("#define FOOT_HI %.3f", GRAIN_NOISE_FOOTPRINT[2]),
	}
	local fragment = fsCAS:gsub("//__ENGINEUNIFORMBUFFERDEFS__", LuaShader.GetEngineUniformBufferDefs())
	local shader = LuaShader({
		vertex = vsCAS,
		fragment = fragment:gsub("//__DEFINES__", table.concat(defines, "\n")),
		uniformInt = {
			screenCopyTex = 0,
		},
	}, "Contrast Adaptive Sharpen")
	if shader:Initialize() then
		useRcas, preserveEdges, useNoise = rcas, preserve, noise
		camX, sentDebugFootprint = nil, nil
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
	local noise = USE_RCAS and GRAIN_NOISE > 0
	casShader = CompileShader(USE_RCAS, preserve, noise)
	if not casShader and noise then
		spEcho("Contrast Adaptive Sharpen: falling back to no grain noise term")
		casShader = CompileShader(USE_RCAS, preserve, false)
	end
	if not casShader and (USE_RCAS or preserve) then
		spEcho("Contrast Adaptive Sharpen: falling back to plain CAS")
		casShader = CompileShader(false, false, false)
	end
	if not casShader then
		spEcho("Failed to compile Contrast Adaptive Sharpen shader, removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	UpdateShader()

	fullTexQuad = CreateTriangleVAO()
	if fullTexQuad == nil then
		widgetHandler:RemoveWidget() --no fallback for potatoes
		return
	end

	widgetHandler:AddAction("cas_footprint", ToggleFootprintOverlay, nil, "t")

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
	widgetHandler:RemoveAction("cas_footprint", "t")
	if casShader then
		casShader:Finalize()
	end
	if fullTexQuad then
		fullTexQuad:Delete()
	end
	for _, vbo in ipairs(fullTexQuadBuffers) do
		vbo:Delete()
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
	if useNoise then
		UpdateNoiseUniforms(casShader)
	end
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
	-- a version only comes with what this widget saved itself; the options menu writes SHARPNESS alone
	if data.SHARPNESS ~= nil and (data.version == nil or data.version == version) then
		SHARPNESS = data.SHARPNESS
	end
end
