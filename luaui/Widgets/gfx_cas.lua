if gl.CreateShader == nil then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name	  = "Contrast Adaptive Sharpen",
		desc	  = "Spring port of AMD FidelityFX' Contrast Adaptive Sharpen (CAS)",
		author	  = "martymcmodding, ivand",
		layer	  = 2000,
		enabled   = true,
	}
end


-- Localized functions for performance

-- Localized Spring API for performance
local spEcho = Spring.Echo

-- Shameless port from https://gist.github.com/martymcmodding/30304c4bffa6e2bd2eb59ff8bb09d135

-----------------------------------------------------------------
-- Constants
-----------------------------------------------------------------

--local GL_RGBA8 = 0x8058

local SHARPNESS = 1.0
local version = 1.06

-----------------------------------------------------------------
-- Lua Shortcuts
-----------------------------------------------------------------

local glTexture		 = gl.Texture
local glBlending	 = gl.Blending

-----------------------------------------------------------------
-- File path Constants
-----------------------------------------------------------------

local luaShaderDir = "LuaUI/Include/"

-----------------------------------------------------------------
-- Shader Sources
-----------------------------------------------------------------

local vsCAS = [[
#version 330
// full screen triangle
uniform float viewPosX;
uniform float viewPosY;

const vec2 vertices[3] = vec2[3](
	vec2(-1.0, -1.0),
	vec2( 3.0, -1.0),
	vec2(-1.0,  3.0)
);

out vec2 viewPos;

void main()
{
	gl_Position = vec4(vertices[gl_VertexID], 0.0, 1.0);
	viewPos = vec2(viewPosX, viewPosY);
}
]]

local fsCAS = [[
#version 330
#line 20058

uniform sampler2D screenCopyTex;
uniform float sharpness;

#if 0 // in case AMD drivers refuse to compile the shader, though according to GLSL spec they shouldn't
	#define TEXEL_FETCH_OFFSET(t, c, l, o) texelFetch(t, c + o, l)
#else
	#define TEXEL_FETCH_OFFSET texelFetchOffset
#endif

in vec2 viewPos;
out vec4 fragColor;

#define SAMPLES 5 // 9 or 5

vec3 CASPass(ivec2 tc) {
	// fetch a 3x3 neighborhood around the pixel 'e',
	//  a b c
	//  d(e)f
	//  g h i
	vec3 b = TEXEL_FETCH_OFFSET(screenCopyTex, tc, 0, ivec2( 0, -1)).rgb;
	vec3 d = TEXEL_FETCH_OFFSET(screenCopyTex, tc, 0, ivec2(-1,  0)).rgb;
	vec3 e = TEXEL_FETCH_OFFSET(screenCopyTex, tc, 0, ivec2( 0,  0)).rgb;
	vec3 f = TEXEL_FETCH_OFFSET(screenCopyTex, tc, 0, ivec2( 1,  0)).rgb;
	vec3 h = TEXEL_FETCH_OFFSET(screenCopyTex, tc, 0, ivec2( 0,  1)).rgb;
	#if (SAMPLES == 9)
		vec3 a = TEXEL_FETCH_OFFSET(screenCopyTex, tc, 0, ivec2(-1, -1)).rgb;
		vec3 c = TEXEL_FETCH_OFFSET(screenCopyTex, tc, 0, ivec2( 1, -1)).rgb;
		vec3 g = TEXEL_FETCH_OFFSET(screenCopyTex, tc, 0, ivec2(-1,  1)).rgb;
		vec3 i = TEXEL_FETCH_OFFSET(screenCopyTex, tc, 0, ivec2( 1,  1)).rgb;
	#endif

	// Soft min and max.
	//  a b c			 b
	//  d e f * 0.5  +  d e f * 0.5
	//  g h i			 h
	// These are 2.0x bigger (factored out the extra multiply).
	vec3 mnRGB = min(min(min(d, e), min(f, b)), h);
	

	vec3 mxRGB = max(max(max(d, e), max(f, b)), h);
	#if (SAMPLES == 9)
		vec3 mnRGB2 = min(mnRGB, min(min(a, c), min(g, i)));
		mnRGB += mnRGB2;
		vec3 mxRGB2 = max(mxRGB, max(max(a, c), max(g, i))); 
		mxRGB += mxRGB2;
	#else
		mxRGB *= 2.0;
		mnRGB *= 2.0; 
	#endif 

	// Smooth minimum distance to signal limit divided by smooth max.
	vec3 rcpMRGB = vec3(1.0) / mxRGB;
	vec3 ampRGB = clamp(min(mnRGB, 2.0 - mxRGB) * rcpMRGB, vec3(0.0), vec3(1.0));

	// Shaping amount of sharpening.
	ampRGB = inversesqrt(ampRGB);

	float peak = 8.0 - 3.0 * sharpness;
	vec3 wRGB = vec3(-1.0) / (ampRGB * peak);

	vec3 rcpWeightRGB = vec3(1.0) / (1.0 + 4.0 * wRGB);

	//						  0 w 0
	//  Filter shape:		   w 1 w
	//						  0 w 0
	vec3 window = (b + d) + (f + h);
	vec3 outColor = clamp((window * wRGB + e) * rcpWeightRGB, vec3(0.0), vec3(1.0));

	return outColor;
}

void main() {
	fragColor = vec4(CASPass(ivec2(gl_FragCoord.xy - viewPos)), 1.0);
	//fragColor = vec4(1.0, 0.0, 0.0, 0.5);
}
]]

-----------------------------------------------------------------
-- Global Variables
-----------------------------------------------------------------

local LuaShader = gl.LuaShader

local vpx, vpy
local screenCopyTex
local casShader

local fullTexQuad

-----------------------------------------------------------------
-- Local Functions
-----------------------------------------------------------------


-----------------------------------------------------------------
-- Widget Functions
-----------------------------------------------------------------

local function UpdateShader()
	casShader:ActivateWith(function()
		casShader:SetUniform("sharpness", SHARPNESS)
		casShader:SetUniform("viewPosX", vpx)
		casShader:SetUniform("viewPosY", vpy)
	end)
end

function widget:Initialize()

	if gl.CreateShader == nil then
		spEcho("CAS: createshader not supported, removing")
		widgetHandler:RemoveWidget()
		return
	end

	_, _, vpx, vpy = Spring.GetViewGeometry()

	--local commonTexOpts = {
	--	target = GL_TEXTURE_2D,
	--	border = false,
	--	min_filter = GL.NEAREST,
	--	mag_filter = GL.NEAREST,

	--	wrap_s = GL.CLAMP_TO_EDGE,
	--	wrap_t = GL.CLAMP_TO_EDGE,
	--}

	--commonTexOpts.format = GL_RGBA8
	--screenCopyTex = gl.CreateTexture(vsx, vsy, commonTexOpts)

	casShader = LuaShader({
		vertex = vsCAS,
		fragment = fsCAS,
		uniformInt = {
			screenCopyTex = 0,
		},
	}, "Contrast Adaptive Sharpen")

	local shaderCompiled = casShader:Initialize()
	if not shaderCompiled then
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
	--gl.DeleteTexture(screenCopyTex)
	if casShader then
		casShader:Finalize()
	end
	if fullTexQuad then
		fullTexQuad:Delete()
	end
end

function widget:ViewResize()
	widget:Shutdown()
	widget:Initialize()
end

function widget:DrawScreenEffects()
	--glCopyToTexture(screenCopyTex, 0, 0, vpx, vpy, vsx, vsy)
	if WG['screencopymanager'] and WG['screencopymanager'].GetScreenCopy then
		screenCopyTex = WG['screencopymanager'].GetScreenCopy()
	else
		--glCopyToTexture(screenCopyTex, 0, 0, vpx, vpy, vsx, vsy)
		spEcho("Missing Screencopy Manager, exiting",  WG['screencopymanager'] )
		widgetHandler:RemoveWidget()
		return false
	end
	if screenCopyTex == nil then return end
	glTexture(0, screenCopyTex)
	glBlending(false)
	casShader:Activate()
	fullTexQuad:DrawArrays(GL.TRIANGLES, 3)
	casShader:Deactivate()
	glBlending(true)
	glTexture(0, false)
end

function widget:GetConfigData()
	return {
		version = version,
		SHARPNESS = SHARPNESS
	}
end

function widget:SetConfigData(data)
	if data.SHARPNESS ~= nil and data.version ~= nil and data.version == version then
		SHARPNESS = data.SHARPNESS
	end
end
