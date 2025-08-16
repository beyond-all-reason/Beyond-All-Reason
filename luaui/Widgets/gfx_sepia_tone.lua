local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name      = "Sepia Tone",
      desc      = "Gives that warm, urine like color we all love from 2000s era games.",
      author    = "Beherith",
      date      = "2023.01.05",
      license   = "GNU GPL, v2 or later",
      layer     = 200000,
      enabled   = false
   }
end

---------------------------------------

local GL_RGBA8 = 0x8058

local params = {gamma = 0.5, saturation = 0.5, contrast = 0.5, sepia = 0, shadeUI = false}

-- skip draw if this matches:
local defaultParams = {gamma = 0.5, saturation = 0.5, contrast = 0.5, sepia = 0.0}

local luaShaderDir = "LuaUI/Include/"

-----------------------------------------------------------------
-- Shader Sources
-----------------------------------------------------------------

local vsSepia = [[
#version 330
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

local fsSepia = [[
#version 330

uniform sampler2D screenCopyTex;

uniform vec4 params; //{gamma = 0.5, saturation = 0.5, contrast = 0.5, sepia = 0.0}

in vec2 viewPos;
out vec4 fragColor;

// See: https://www.shadertoy.com/view/XdcXzn
mat4 contrastMatrix( float contrast )
{
	float t = ( 1.0 - contrast ) / 2.0;
    return mat4( contrast, 0, 0, 0,
                 0, contrast, 0, 0,
                 0, 0, contrast, 0,
                 t, t, t, 1 );
}

mat4 saturationMatrix( float saturation )
{
    vec3 luminance = vec3( 0.3086, 0.6094, 0.0820 );
    
    float oneMinusSat = 1.0 - saturation;
    
    vec3 red = vec3( luminance.x * oneMinusSat );
    red+= vec3( saturation, 0, 0 );
    
    vec3 green = vec3( luminance.y * oneMinusSat );
    green += vec3( 0, saturation, 0 );
    
    vec3 blue = vec3( luminance.z * oneMinusSat );
    blue += vec3( 0, 0, saturation );
    
    return mat4( red,     0,
                 green,   0,
                 blue,    0,
                 0, 0, 0, 1 );
}

mat4 sepiaMatrix()
{
	return mat4( 0.393,  0.349, 0.272, 0,
                 0.769,  0.686, 0.534, 0,
                 0.189, 0.168, 0.131, 0,
                 0, 0, 0, 1 );
}

void main()
{
    vec4 color = texelFetch(screenCopyTex,ivec2(gl_FragCoord.xy + viewPos),0);
	fragColor.rgb = pow(color.rgb, vec3(params.x + 0.5));
    
	fragColor =	contrastMatrix( params.z + 0.5 ) * 
        		saturationMatrix( params.y + 0.5 ) *
        		fragColor;
	fragColor.rgb = mix(fragColor.rgb, (sepiaMatrix() * fragColor).rgb, params.w);
	fragColor.a = 1.0;
}
]]


-----------------------------------------------------------------
-- Global Variables
-----------------------------------------------------------------

local LuaShader = gl.LuaShader

local vsx, vsy, vpx, vpy
local screenCopyTex
local sepiaShader

local fullTexQuad

local function UpdateShader()
	sepiaShader:ActivateWith(function()
		sepiaShader:SetUniform("viewPosX", vpx)
		sepiaShader:SetUniform("viewPosY", vpy)
	end)
end

function widget:Initialize()
	if gl.CreateShader == nil then
		Spring.Echo("Sepia: createshader not supported, removing")
		widgetHandler:RemoveWidget()
		return
	end

	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()

	local commonTexOpts = {
		target = GL.TEXTURE_2D,
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,

		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	}

	commonTexOpts.format = GL_RGBA8
	screenCopyTex = gl.CreateTexture(vsx, vsy, commonTexOpts)

	sepiaShader = LuaShader({
		vertex = vsSepia,
		fragment = fsSepia,
		uniformInt = {
			screenCopyTex = 0,
		},
		uniformFloat = {
			viewPosX = vpx,
			viewPosY = vpy,
			params = { params.gamma, params.saturation, params.contrast, params.sepia} --{gamma = 0.5, saturation = 0.5, contrast = 0.5, sepia = 0.0}
			}
	}, ": Sepia")

	local shaderCompiled = sepiaShader:Initialize()
	if not shaderCompiled then
			Spring.Echo("Failed to compile Sepia shader, removing widget")
			widgetHandler:RemoveWidget()
			return
	end

	UpdateShader()

	fullTexQuad = gl.GetVAO()
	if fullTexQuad == nil then
		widgetHandler:RemoveWidget() --no fallback for potatoes
		return
	end

	WG.sepia = {}
	WG.sepia.setGamma = function(value)
		params.gamma = value
		UpdateShader()
	end
	WG.sepia.getGamma = function()
		return params.gamma
	end
	WG.sepia.setSaturation = function(value)
		params.saturation = value
		UpdateShader()
	end
	WG.sepia.getSaturation = function()
		return params.saturation
	end
	WG.sepia.setContrast = function(value)
		params.contrast = value
		UpdateShader()
	end
	WG.sepia.getContrast = function()
		return params.contrast
	end
	WG.sepia.setSepia = function(value)
		params.sepia = value
		UpdateShader()
	end
	WG.sepia.getSepia = function()
		return params.sepia
	end
	WG.sepia.setShadeUI = function(value)
		params.shadeUI = value
		UpdateShader()
	end
	WG.sepia.getShadeUI = function()
		return params.shadeUI
	end

end

function widget:Shutdown()
	gl.DeleteTexture(screenCopyTex)
	screenCopyTex = nil
	if sepiaShader then
		sepiaShader:Finalize()
	end
	if fullTexQuad then
		fullTexQuad:Delete()
	end
end

function widget:ViewResize()
	widget:Shutdown()
	widget:Initialize()
end

local function DoSepia()
	local alldefault = true
	for k,v in pairs(defaultParams) do 
		if math.abs(params[k] - v) > 0.001 then 
			alldefault = false
		end
	end
	if alldefault then return end
	
	gl.CopyToTexture(screenCopyTex, 0, 0, vpx, vpy, vsx, vsy)
	if screenCopyTex == nil then return end
	gl.Texture(0, screenCopyTex)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	sepiaShader:Activate()
	sepiaShader:SetUniform("params", params.gamma, params.saturation, params.contrast, params.sepia)
	fullTexQuad:DrawArrays(GL.TRIANGLES, 3)
	sepiaShader:Deactivate()
	gl.Blending(true)
	gl.Texture(0, false)
end


function widget:DrawScreenEffects()
	if params.shadeUI == false then DoSepia() end 
end

function widget:DrawScreenPost()
	if params.shadeUI == true then DoSepia() end 
end

function widget:TextCommand(command)
	if string.find(command,"sepiatone", nil, true ) == 1 then
		local s = string.split(command, ' ') 
		Spring.Echo("/luaui sepiatone gamma saturation contrast sepia shadeUI")
		Spring.Echo(command) 
		params.gamma = tonumber(s[2]) or params.gamma
		params.saturation = tonumber(s[3]) or params.saturation
		params.contrast = tonumber(s[4]) or params.contrast
		params.sepia = tonumber(s[5]) or params.sepia
		if s[6] ~= nil then 
			params.shadeUI = s[6]  == 'true'
		end
	end
end

function widget:GetConfigData()
	return params
end

function widget:SetConfigData(data)
	for k,v in pairs(data) do
		params[k] = data[k] or v
	end
end
