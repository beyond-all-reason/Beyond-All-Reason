local wiName = "Outline"
function widget:GetInfo()
	return {
		name      = wiName,
		desc      = "Displays small outline around units based on deferred g-buffer",
		author    = "ivand",
		date      = "2019",
		license   = "GNU GPL, v2 or later",
		layer     = math.huge,
		enabled   = false  --  loaded by default?
	}
end

-----------------------------------------------------------------
-- Constants
-----------------------------------------------------------------

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0

local GL_RGBA = 0x1908
--GL_DEPTH_COMPONENT32F is the default for deferred depth textures, but Lua API only works correctly with GL_DEPTH_COMPONENT32
local GL_DEPTH_COMPONENT32 = 0x81A7
local GL_TRIANGLES = GL.TRIANGLES


-----------------------------------------------------------------
-- Configuration Constants
-----------------------------------------------------------------

--[[
local MIN_FPS = 20
local MIN_FPS_DELTA = 10
local AVG_FPS_ELASTICITY = 0.2
local AVG_FPS_ELASTICITY_INV = 1.0 - AVG_FPS_ELASTICITY
]]--

local DILATE_SINGLE_PASS = false --true is slower on my system
local DILATE_HALF_KERNEL_SIZE = 1
local DILATE_PASSES = 1

local STRENGTH_MULT = 0.5

local OUTLINE_ZOOM_SCALE = true
local OUTLINE_COLOR = {0, 0, 0, 1.0}
local whiteColored = false
--local OUTLINE_COLOR = {0.0, 0.0, 0.0, 1.0}
local OUTLINE_STRENGTH_BLENDED = 1.0
local OUTLINE_STRENGTH_ALWAYS_ON = 0.6

local USE_MATERIAL_INDICES = true -- for future material indices based outline evaluation

-----------------------------------------------------------------
-- File path Constants
-----------------------------------------------------------------

local luaShaderDir = "LuaUI/Widgets/Include/"

-----------------------------------------------------------------
-- Shader Sources
-----------------------------------------------------------------

local vs = [[
#version 330
// full screen triangle

const vec2 vertices[3] = vec2[3](
	vec2(-1.0, -1.0),
	vec2( 3.0, -1.0),
	vec2(-1.0,  3.0)
);

void main()
{
	gl_Position = vec4(vertices[gl_VertexID], 0.0, 1.0);
}
]]

local fsShape = [[
#version 330

uniform sampler2D modelDepthTex;
uniform sampler2D mapDepthTex;
uniform sampler2D modelMiscTex;

uniform vec4 outlineColor;

out vec4 fragColor;

#define USE_MATERIAL_INDICES ###USE_MATERIAL_INDICES###

const float eps = 1e-4;
//layout(pixel_center_integer) in vec4 gl_FragCoord;
//layout(origin_upper_left) in vec4 gl_FragCoord;

void main() {
	ivec2 imageCoord = ivec2(gl_FragCoord.xy);

	float mapDepth = texelFetch(mapDepthTex, imageCoord, 0).r;
	float modelDepth = texelFetch(modelDepthTex, imageCoord, 0).r;
	//float modelDepth = texture(modelDepthTex, uv).r;
/*
	#if (USE_MATERIAL_INDICES == 1)
		bool cond = mapDepth + eps >= modelDepth;
	#else
		bool cond = mapDepth + eps >= modelDepth && modelDepth < 1.0;
	#endif
*/

	//bool cond = true;
	bool cond = (modelDepth < 1.0);
	//bool cond = mapDepth + eps >= modelDepth && modelDepth < 1.0;

	#if (USE_MATERIAL_INDICES == 1)
		#define MATERIAL_UNITS_MAX_INDEX 127
		#define MATERIAL_UNITS_MIN_INDEX 1

		if (cond) {
			int matIndices = int(texelFetch(modelMiscTex, imageCoord, 0).r * 255.0);
			cond = cond && (matIndices >= MATERIAL_UNITS_MIN_INDEX) && (matIndices <= MATERIAL_UNITS_MAX_INDEX);
		}
	#endif

	fragColor = mix(vec4(0.0, 0.0, 0.0, 0.0), outlineColor, vec4(cond));
	gl_FragDepth = mix(1.0, modelDepth, float(cond));
}
]]

local fsDilate = [[
#version 330

uniform sampler2D depthTex;
uniform sampler2D colorTex;

uniform mat4 projMatrix;
uniform int dilateHalfKernelSize = 1;
uniform vec2 viewPortSize;
uniform float strength = 1.0;

//layout(pixel_center_integer) in vec4 gl_FragCoord;
//layout(origin_upper_left) in vec4 gl_FragCoord;

#define DILATE_SINGLE_PASS ###DILATE_SINGLE_PASS###

#if 1 //Fuck AMD
	#define TEXEL_FETCH_OFFSET(t, c, l, o) texelFetch(t, c + o, l)
#else
	#define TEXEL_FETCH_OFFSET texelFetchOffset
#endif

out vec4 fragColor;

#if (DILATE_SINGLE_PASS == 1)
	void main(void)
	{
		ivec4 vpsMinMax = ivec4(0, 0, ivec2(viewPortSize));

		float minDepth = 1.0;
		vec4 maxColor = vec4(0.0);

		ivec2 thisCoord = ivec2(gl_FragCoord.xy);

		vec2 bnd = vec2(dilateHalfKernelSize - 1, dilateHalfKernelSize + 2) * strength;

		for (int x = -dilateHalfKernelSize; x <= dilateHalfKernelSize; ++x) {
			for (int y = -dilateHalfKernelSize; y <= dilateHalfKernelSize; ++y) {

				ivec2 offset = ivec2(x, y);
				/*
				ivec2 samplingCoord = thisCoord + offset;
				bool okCoords = ( all(bvec4(
					greaterThanEqual(samplingCoord, vpsMinMax.xy),
					lessThanEqual(samplingCoord, vpsMinMax.zw) ))
				);

				if (okCoords)*/ {
					minDepth = min(minDepth, TEXEL_FETCH_OFFSET( depthTex, thisCoord, 0, offset).r);
					vec4 thisColor = TEXEL_FETCH_OFFSET( colorTex, thisCoord, 0, offset);
					thisColor.a *= smoothstep(bnd.y, bnd.x, sqrt(float(x * x + y * y)));
					maxColor = max(maxColor, thisColor);
				}
			}
		}
		gl_FragDepth = minDepth;
		fragColor = maxColor;
	}
#else //separable vert/horiz passes
	uniform vec2 dir;
	void main(void)
	{
		ivec4 vpsMinMax = ivec4(0, 0, ivec2(viewPortSize));

		float minDepth = 1.0;
		vec4 maxColor = vec4(0.0);

		ivec2 thisCoord = ivec2(gl_FragCoord.xy);

		vec2 bnd = vec2(dilateHalfKernelSize - 1, dilateHalfKernelSize + 2) * strength;

		for (int i = -dilateHalfKernelSize; i <= dilateHalfKernelSize; ++i) {

			ivec2 offset = ivec2(i) * ivec2(dir);
			/*
			ivec2 samplingCoord = thisCoord + offset;
			bool okCoords = ( all(bvec4(
				greaterThanEqual(samplingCoord, vpsMinMax.xy),
				lessThanEqual(samplingCoord, vpsMinMax.zw) ))
			);

			if (okCoords)*/ {
				minDepth = min(minDepth, TEXEL_FETCH_OFFSET( depthTex, thisCoord, 0, offset).r);
				vec4 thisColor = TEXEL_FETCH_OFFSET( colorTex, thisCoord, 0, offset);
				thisColor.a *= smoothstep(bnd.y, bnd.x, abs(i));
				maxColor = max(maxColor, thisColor);
			}
		}

		gl_FragDepth = minDepth;
		fragColor = maxColor;
	}
#endif
]]

local fsApplication = [[
#version 330

uniform sampler2D dilatedDepthTex;
uniform sampler2D dilatedColorTex;
uniform sampler2D shapeDepthTex;
uniform sampler2D mapDepthTex;

uniform float strength = 1.0;
uniform float alwaysShowOutLine = 0.0;

const float eps = 1e-3;
//layout(pixel_center_integer) in vec4 gl_FragCoord;
//layout(origin_upper_left) in vec4 gl_FragCoord;

out vec4 fragColor;

void main() {
	ivec2 imageCoord = ivec2(gl_FragCoord.xy);

	vec4 dilatedColor = texelFetch(dilatedColorTex, imageCoord, 0);
	dilatedColor.a *= strength;

	float dilatedDepth = texelFetch(dilatedDepthTex, imageCoord, 0).r;
	float shapeDepth = texelFetch(shapeDepthTex, imageCoord, 0).r;
	float mapDepth = texelFetch(mapDepthTex, imageCoord, 0).r;

	bool cond = (shapeDepth == 1.0);
	float depthToWrite = mix(dilatedDepth, 0.0, alwaysShowOutLine);

	fragColor = mix(vec4(0.0), dilatedColor, float(cond));
	gl_FragDepth = mix(1.0, depthToWrite, float(cond));
}
]]

-----------------------------------------------------------------
-- Global Variables
-----------------------------------------------------------------

local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")

local vsx, vsy, vpx, vpy

local fullTexQuad

local shapeDepthTex
local shapeColorTex

local dilationDepthTexes = {}
local dilationColorTexes = {}

local shapeFBO
local dilationFBOs = {}

local shapeShader
local dilationShader
local applicationShader

local pingPongIdx = 1


-----------------------------------------------------------------
-- Local Functions
-----------------------------------------------------------------

local function GetZoomScale()
	local cs = Spring.GetCameraState()
	local gy = Spring.GetGroundHeight(cs.px, cs.pz)
	local cameraHeight
	if cs.name == "ta" then
		cameraHeight = cs.height - gy
	else
		cameraHeight = cs.py - gy
	end
	cameraHeight = math.max(1.0, cameraHeight)
	local scaleFactor = 250.0 / cameraHeight
	scaleFactor = math.min(math.max(0.5, scaleFactor), 1.0)
	--Spring.Echo(cameraHeight, scaleFactor)
	return scaleFactor
end

local show = true
local function PrepareOutline()
	if not show then
		return
	end

	local prevTest = gl.GetFixedState("depth")
	local prevFunc = GL.LEQUAL
	
	gl.DepthTest(true)
	gl.DepthTest(GL.ALWAYS)

	gl.ActiveFBO(shapeFBO, function()
		shapeShader:ActivateWith( function ()
			gl.Texture(2, "$model_gbuffer_zvaltex")
			if USE_MATERIAL_INDICES then
				gl.Texture(1, "$model_gbuffer_misctex")
			end
			gl.Texture(3, "$map_gbuffer_zvaltex")

			fullTexQuad:DrawArrays(GL_TRIANGLES, 3)

			--gl.Texture(1, false) --will reuse later
			if USE_MATERIAL_INDICES then
				gl.Texture(1, false)
			end
		end)
	end)


	gl.Texture(0, shapeDepthTex)
	gl.Texture(1, shapeColorTex)

	--Spring.Echo("DILATE_HALF_KERNEL_SIZE", DILATE_HALF_KERNEL_SIZE)

	for i = 1, DILATE_PASSES do
		dilationShader:ActivateWith( function ()
			local strength
			if OUTLINE_ZOOM_SCALE then
				strength = GetZoomScale()
			end
			dilationShader:SetUniformFloat("strength", strength)
			dilationShader:SetUniformInt("dilateHalfKernelSize", DILATE_HALF_KERNEL_SIZE)

			if DILATE_SINGLE_PASS then
				pingPongIdx = (pingPongIdx + 1) % 2
				gl.ActiveFBO(dilationFBOs[pingPongIdx + 1], function()
					fullTexQuad:DrawArrays(GL_TRIANGLES, 3)
				end)
				gl.Texture(0, dilationDepthTexes[pingPongIdx + 1])
				gl.Texture(1, dilationColorTexes[pingPongIdx + 1])

			else
				pingPongIdx = (pingPongIdx + 1) % 2
				dilationShader:SetUniform("dir", 1.0, 0.0) --horizontal dilation
				gl.ActiveFBO(dilationFBOs[pingPongIdx + 1], function()
					fullTexQuad:DrawArrays(GL_TRIANGLES, 3)
				end)
				gl.Texture(0, dilationDepthTexes[pingPongIdx + 1])
				gl.Texture(1, dilationColorTexes[pingPongIdx + 1])

				pingPongIdx = (pingPongIdx + 1) % 2
				dilationShader:SetUniform("dir", 0.0, 1.0) --vertical dilation
				gl.ActiveFBO(dilationFBOs[pingPongIdx + 1], function()
					fullTexQuad:DrawArrays(GL_TRIANGLES, 3)
				end)
				gl.Texture(0, dilationDepthTexes[pingPongIdx + 1])
				gl.Texture(1, dilationColorTexes[pingPongIdx + 1])
			end
		end)
	end

	gl.DepthTest(prevFunc)
	if not prevTest then
		gl.DepthTest(prevTest)
	end
end

local function DrawOutline(strength, loadTextures, alwaysVisible)
	if not show then
		return
	end

	if loadTextures then
		gl.Texture(0, dilationDepthTexes[pingPongIdx + 1])
		gl.Texture(1, dilationColorTexes[pingPongIdx + 1])
		gl.Texture(2, shapeDepthTex)
		gl.Texture(3, "$map_gbuffer_zvaltex")
	end

	local blendingEnabled = gl.GetFixedState("blending")
	if not blendingEnabled then
		gl.Blending(true)
	end

	applicationShader:ActivateWith( function ()
		applicationShader:SetUniformFloat("alwaysShowOutLine", (alwaysVisible and 1.0) or 0.0)
		applicationShader:SetUniformFloat("strength", strength * STRENGTH_MULT)
		fullTexQuad:DrawArrays(GL_TRIANGLES, 3)
	end)

	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
	gl.Texture(3, false)

	gl.DepthTest(not alwaysVisible)
	
	gl.Blending(blendingEnabled)
end

-----------------------------------------------------------------
-- Widget Functions
-----------------------------------------------------------------

function widget:ViewResize()
	widget:Shutdown()
	widget:Initialize()
end

function widget:Initialize()
	local canContinue = LuaShader.isDeferredShadingEnabled and LuaShader.GetAdvShadingActive()
	if not canContinue then
		Spring.Echo(string.format("Error in [%s] widget: %s", wiName, "Deferred shading is not enabled or advanced shading is not active"))
	end

	local configName = "AllowDrawModelPostDeferredEvents"
	if Spring.GetConfigInt(configName, 0) == 0 then
		Spring.SetConfigInt(configName, 1) --required to enable receiving DrawUnitsPostDeferred/DrawFeaturesPostDeferred
	end

	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()

	-- depth textures
	local commonTexOpts = {
		target = GL_TEXTURE_2D,
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,

		format = GL_DEPTH_COMPONENT32,

		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	}

	shapeDepthTex = gl.CreateTexture(vsx, vsy, commonTexOpts)
	for i = 1, 2 do
		dilationDepthTexes[i] = gl.CreateTexture(vsx, vsy, commonTexOpts)
	end

	-- color textures
	commonTexOpts.format = GL_RGBA
	shapeColorTex = gl.CreateTexture(vsx, vsy, commonTexOpts)
	for i = 1, 2 do
		dilationColorTexes[i] = gl.CreateTexture(vsx, vsy, commonTexOpts)
	end

	shapeFBO = gl.CreateFBO({
		depth = shapeDepthTex,
		color0 = shapeColorTex,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})

	if not gl.IsValidFBO(shapeFBO) then
		Spring.Echo(string.format("Error in [%s] widget: %s", wiName, "Invalid shapeFBO"))
	end

	for i = 1, 2 do
		dilationFBOs[i] = gl.CreateFBO({
			depth = dilationDepthTexes[i],
			color0 = dilationColorTexes[i],
			drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
		})
		if not gl.IsValidFBO(dilationFBOs[i]) then
			Spring.Echo(string.format("Error in [%s] widget: %s", wiName, string.format("Invalid dilationFBOs[%d]", i)))
		end
	end

	fsShape = fsShape:gsub("###USE_MATERIAL_INDICES###", tostring((USE_MATERIAL_INDICES and 1) or 0))

	shapeShader = LuaShader({
		vertex = vs,
		fragment = fsShape,
		uniformInt = {
			modelDepthTex = 2,
			modelMiscTex = 1,
			mapDepthTex = 3,
		},
		uniformFloat = {
			outlineColor = OUTLINE_COLOR,
			--viewPortSize = {vsx, vsy},
		},
	}, wiName..": Shape identification")
	shapeShader:Initialize()

	fsDilate = fsDilate:gsub("###DILATE_SINGLE_PASS###", tostring((DILATE_SINGLE_PASS and 1) or 0))

	dilationShader = LuaShader({
		vertex = vs,
		fragment = fsDilate,
		uniformInt = {
			depthTex = 0,
			colorTex = 1,
			dilateHalfKernelSize = DILATE_HALF_KERNEL_SIZE,
		},
		uniformFloat = {
			viewPortSize = {vsx, vsy},
		}
	}, wiName..": Dilation")
	dilationShader:Initialize()

	applicationShader = LuaShader({
		vertex = vs,
		fragment = fsApplication,
		uniformInt = {
			dilatedDepthTex = 0,
			dilatedColorTex = 1,
			shapeDepthTex = 2,
			mapDepthTex = 3,
		},
		uniformFloat = {
			viewPortSize = {vsx, vsy},
		},
	}, wiName..": Outline Application")
	applicationShader:Initialize()

	fullTexQuad = gl.GetVAO()

	WG['outline'] = {}
	WG['outline'].getWidth = function()
		return DILATE_HALF_KERNEL_SIZE
	end
	WG['outline'].setWidth = function(value)
		DILATE_HALF_KERNEL_SIZE = value
		widget:Shutdown()
		widget:Initialize()
	end
	WG['outline'].getMult = function()
		return STRENGTH_MULT
	end
	WG['outline'].setMult = function(value)
		STRENGTH_MULT = value
		widget:Shutdown()
		widget:Initialize()
	end
	WG['outline'].getColor = function()
		return whiteColored
	end
	WG['outline'].setColor = function(value)
		whiteColored = value
		if whiteColored then
			OUTLINE_COLOR = {0.75, 0.75, 0.75, 1.0}
		else
			OUTLINE_COLOR = {0, 0, 0, 1.0}
		end
		widget:Shutdown()
		widget:Initialize()
	end
end

function widget:Shutdown()
	if fullTexQuad then
		fullTexQuad:Delete()
	end

	gl.DeleteTexture(shapeDepthTex)
	gl.DeleteTexture(shapeColorTex)

	for i = 1, 2 do
		gl.DeleteTexture(dilationColorTexes[i])
		gl.DeleteTexture(dilationDepthTexes[i])
	end

	gl.DeleteFBO(shapeFBO)

	for i = 1, 2 do
		gl.DeleteFBO(dilationFBOs[i])
	end

	shapeShader:Finalize()
	dilationShader:Finalize()
	applicationShader:Finalize()

	WG['outline'] = nil
end

--[[
local accuTime = 0
local lastTime = 0
local averageFPS = MIN_FPS + MIN_FPS_DELTA

function widget:Update(dt)
	accuTime = accuTime + dt
	if accuTime >= lastTime + 1 then
		lastTime = accuTime
		averageFPS = AVG_FPS_ELASTICITY_INV * averageFPS + AVG_FPS_ELASTICITY * Spring.GetFPS()
		if averageFPS < MIN_FPS then
			show = false
		elseif averageFPS > MIN_FPS + MIN_FPS_DELTA then
			show = true
		end
	end
end
]]--


-- For debug
--[[
function widget:DrawScreenEffects()
	gl.Blending(false)

	gl.Texture(0, dilationDepthTexes[pingPongIdx + 1])
	gl.Texture(0, dilationColorTexes[pingPongIdx + 1])
	--gl.TexRect(0, 0, vsx, vsy, false, true)
	gl.Texture(0, false)
end
]]--


function widget:DrawWorld()
	DrawOutline(OUTLINE_STRENGTH_ALWAYS_ON, true, true)

end

function widget:DrawUnitsPostDeferred()
	PrepareOutline()
	DrawOutline(OUTLINE_STRENGTH_BLENDED, false, false)
end


function widget:GetConfigData()
	return {
		DILATE_HALF_KERNEL_SIZE = DILATE_HALF_KERNEL_SIZE,
		STRENGTH_MULT = STRENGTH_MULT,
		whiteColored = whiteColored
	}
end

function widget:SetConfigData(data)
	if data.DILATE_HALF_KERNEL_SIZE then DILATE_HALF_KERNEL_SIZE = data.DILATE_HALF_KERNEL_SIZE or DILATE_HALF_KERNEL_SIZE end
	if data.STRENGTH_MULT then STRENGTH_MULT = data.STRENGTH_MULT or STRENGTH_MULT end
	if data.whiteColored ~= nil then
		whiteColored = data.whiteColored
		if whiteColored then
			OUTLINE_COLOR = {0.75, 0.75, 0.75, 1.0}
		else
			OUTLINE_COLOR = {0, 0, 0, 1.0}
		end
	end
end
