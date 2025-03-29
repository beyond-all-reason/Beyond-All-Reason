
local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Volumetric Clouds",
    version   = 6,
    desc      = "Fog/Dust clouds that scroll with wind along the map's surface. Requires GLSL, expensive even with.",
    author    = "Anarchid, consulted and optimized by jK",
    date      = "november 2014",
    license   = "GNU GPL, v2 or later",
    layer     = -1,
    enabled   = false
  }
end

local enabled = true

local opacityMult = 1

local noiseTex = ":l:LuaUI/Images/rgbnoise.png"
--local noiseTex = "LuaUI/Images/noisetextures/uniformnoise_128_rgba_1pixoffset.tga"
local noiseTex3D = "LuaUI/Images/noisetextures/worley_rgbnorm_01_asum_128_v1.dds"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local CloudDefs = {
	speed = 0.5, -- multiplier for speed of scrolling with wind
	--color    = {0.46, 0.32, 0.2}, -- diffuse color of the fog
	color    = {0.6,0.7,0.8}, -- diffuse color of the fog

	-- all altitude values can be either absolute, in percent, or "auto"
	height   = 4800, -- opacity of fog above and at this altitude will be zero
	bottom = 1200, -- no fog below this altitude
	fade_alt = 2500, -- fog will linearly fade away between this and "height", should be between height and bottom
	scale = 700, -- how large will the clouds be
	opacity = 0.65, -- what it says
	clamp_to_map = false, -- whether fog volume is sliced to fit map, or spreads to horizon
	sun_penetration = 50, -- how much does the sun penetrate the fog
}

local mapcfg = VFS.Include("mapinfo.lua")
if mapcfg and mapcfg.custom and mapcfg.custom.clouds then
	for k,v in pairs(mapcfg.custom.clouds) do
		CloudDefs[k] = v
	end
else
	--error("<Volumetric Clouds>: no custom defined mapinfo.lua cloud settings found")
end

local gnd_min, gnd_max = Spring.GetGroundExtremes()

local function convertAltitude(input, default)
	local result = input
	if input == nil or input == "auto" then
		result = default
	elseif type(input) == "string" and input:match("(%d+)%%") then
		local percent = input:match("(%d+)%%")
		result = gnd_max * (percent / 100)
	end
	--Spring.Echo(result)
	return result
end

CloudDefs.height = convertAltitude(CloudDefs.height, gnd_max*0.9)
CloudDefs.bottom = convertAltitude(CloudDefs.bottom, 0)
CloudDefs.fade_alt = convertAltitude(CloudDefs.fade_alt, gnd_max*0.8)

local cloudsHeight    = CloudDefs.height
local cloudsBottom    = CloudDefs.bottom or gnd_min
local cloudsColor     = CloudDefs.color
local cloudsScale     = CloudDefs.scale
local cloudsClamp     = CloudDefs.clamp_to_map or false
local speed    		  = CloudDefs.speed
local opacity    	  = CloudDefs.opacity or 0.3
local sunPenetration  = CloudDefs.sun_penetration or (-40.0)
local fade_alt    	  = CloudDefs.fade_alt
local fr,fg,fb        = unpack(cloudsColor)
local sunDir = {0,0,0}
local sunCol = {1,0,0}

assert(type(sunPenetration) == "number")
assert(type(cloudsClamp) == "boolean")
assert(type(cloudsHeight) == "number")
assert(type(cloudsBottom) == "number")
assert(type(fr) == "number")
assert(type(fg) == "number")
assert(type(fb) == "number")
assert(type(opacity) == "number")
assert(type(fade_alt) == "number")
assert(type(cloudsScale) == "number")
assert(type(speed) == "number")


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Automatically generated local definitions

local GL_NEAREST             = GL.NEAREST
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA           = GL.SRC_ALPHA
local glBlending             = gl.Blending
local glCopyToTexture        = gl.CopyToTexture
local glCreateShader         = gl.CreateShader
local glCreateTexture        = gl.CreateTexture
local glDeleteShader         = gl.DeleteShader
local glDeleteTexture        = gl.DeleteTexture
local glGetShaderLog         = gl.GetShaderLog
local glGetUniformLocation   = gl.GetUniformLocation
local glTexture              = gl.Texture
local glUniform              = gl.Uniform
local glUniformMatrix        = gl.UniformMatrix
local glUseShader            = gl.UseShader
local spGetCameraPosition    = Spring.GetCameraPosition
local spGetWind              = Spring.GetWind

local function spEcho(words)
	Spring.Echo('<Volumetric Clouds> '..words)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Extra GL constants
--

local GL_DEPTH_COMPONENT24 = 0x81A6

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (gnd_min < 0) then gnd_min = 0 end
if (gnd_max < 0) then gnd_max = 0 end
local vsx, vsy, vpx, vpy

local depthShader
local depthTexture
local fogTexture

local uniformEyePos
local uniformViewPrjInv
local uniformOffset
local uniformSundir
local uniformSunColor
local uniformTime

local offsetX = 0
local offsetY = 0
local offsetZ = 0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:ViewResize()
	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()

	if depthTexture then
		glDeleteTexture(depthTexture)
	end

	if fogTexture then
		glDeleteTexture(fogTexture)
	end

	depthTexture = glCreateTexture(vsx, vsy, {
		format = GL_DEPTH_COMPONENT24,
		min_filter = GL_NEAREST,
		mag_filter = GL_NEAREST,
	})

	fogTexture = glCreateTexture(vsx / 4, vsy / 4, {
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})


	if depthTexture == nil then
		spEcho("Removing fog widget, bad depth texture")
		widgetHandler:RemoveWidget()
	end
end

widget:ViewResize()


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local vertSrc = [[
#version 150 compatibility
const vec4 frustumCorners[8] = vec4[](
	vec4(-1.0,  1.0, -1.0, 1.0),
	vec4( 1.0,  1.0, -1.0, 1.0),
	vec4( 1.0, -1.0, -1.0, 1.0),
	vec4(-1.0, -1.0, -1.0, 1.0),
	vec4(-1.0,  1.0,  1.0, 1.0),
	vec4( 1.0,  1.0,  1.0, 1.0),
	vec4( 1.0, -1.0,  1.0, 1.0),
	vec4(-1.0, -1.0,  1.0, 1.0)
);

struct AABB {
	vec3 Min;
	vec3 Max;
};

uniform mat4 viewProjectionInv;

out AABB aabbCamera;

const float BIG_NUM = 1e+20;

void main(void)
{
	aabbCamera.Min = vec3( BIG_NUM);
	aabbCamera.Max = vec3(-BIG_NUM);

	for (int i = 0; i < 8; ++i) {
		vec4 frustumCorner = frustumCorners[i];
		vec4 frustumCornersWS = viewProjectionInv * frustumCorner;
		frustumCornersWS /= frustumCornersWS.w;

		aabbCamera.Min = min(aabbCamera.Min, frustumCornersWS.xyz);
		aabbCamera.Max = max(aabbCamera.Max, frustumCornersWS.xyz);
	}

	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position    = gl_Vertex;
}
]]

local fragSrc = [[
#version 150 compatibility
#line 10272
const float noiseScale = 1. / float(%f);
const float fogHeight = float(%f);
const float fogBottom = float(%f);
const float fogThicknessInv = 1. / (fogHeight - fogBottom);
const vec3 fogColor   = vec3(%f, %f, %f);
const float mapX = float(%f);
const float mapZ = float(%f);
const float fadeAltitude = float(%f);
const float opacity = float(%f);

const float sunPenetrationDepth = float(%f);

const float shadowOpacity = 0.6;
const float sunDiffuseStrength = float(6.0);
const float noiseTexSizeInv = 1.0 / 256.0;
const float noiseCloudness = float(0.7) * 0.5; // TODO: configurable

#define DEPTH_CLIP01 ###DEPTH_CLIP01###
#define CLAMP_TO_MAP ###CLAMP_TO_MAP###

#if CLAMP_TO_MAP
	const vec3 vAA = vec3(  1.,fogBottom,  1.);
	const vec3 vBB = vec3(mapX-1.,fogHeight,mapZ-1.);
#else
	const vec3 vAA = vec3(-300000.0, fogBottom, -300000.0);
	const vec3 vBB = vec3( 300000.0, fogHeight,  300000.0);
#endif

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform sampler3D tex2;

uniform vec3 eyePos;
uniform mat4 viewProjectionInv;
uniform vec3 offset;
uniform vec3 sundir;
uniform vec3 suncolor;
uniform float time;

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

struct Ray {
	vec3 Origin;
	vec3 Dir;
};

struct AABB {
	vec3 Min;
	vec3 Max;
};


in AABB aabbCamera;

//float sunSpecularColor = suncolor; //FIXME
const float sunSpecularExponent = float(100.0);

float noise_old(in vec3 x)
{
	vec3 p = floor(x);
	vec3 f = fract(x);
	f = f*f*(3.0-2.0*f);
	vec2 uv = (p.xz + vec2(37.0,17.0)*p.y) + f.xz;
	vec2 rg = texture2D( tex1, (uv + 0.5) * noiseTexSizeInv).yx;
	return smoothstep(0.5 - noiseCloudness, 0.5 + noiseCloudness, mix( rg.x, rg.y, f.y ));
}

/*
float noise(in vec3 x)
{
	vec3 p = floor(x);
	vec3 f = fract(x);
	f = f*f*(3.0-2.0*f);
	vec2 uv = (p.xz + vec2(37.0,17.0)*p.y) + f.xz;
	vec2 rg = texture2D( tex1, (uv + 0.5) * noiseTexSizeInv).yx;
	return smoothstep(0.5 - noiseCloudness, 0.5 + noiseCloudness, mix( rg.x, rg.y, f.y ));
}
*/

float noise(in vec3 x)
{
	return texture3D( tex2, x * 0.2).r;
}

bool IntersectBox(in Ray r, in AABB aabb, out float t0, out float t1)
{
	vec3 invR = 1.0 / r.Dir;
	vec3 tbot = invR * (aabb.Min - r.Origin);
	vec3 ttop = invR * (aabb.Max - r.Origin);
	vec3 tmin = min(ttop, tbot);
	vec3 tmax = max(ttop, tbot);
	vec2 t = max(tmin.xx, tmin.yz);
	t0 = max(0.,max(t.x, t.y));
	t  = min(tmax.xx, tmax.yz);
	t1 = min(t.x, t.y);
	//return (t0 <= t1) && (t1 >= 0.);
	return (abs(t0) <= t1);
}



const mat3 m = mat3( 0.00,  0.80,  0.60,
                    -0.80,  0.36, -0.48,
                    -0.60, -0.48,  0.64 ) * 2.01;


float MapClouds(in vec3 p)
{
	float factor = 1.0 - smoothstep(fadeAltitude, fogHeight, p.y);

	p += offset;
	p *= noiseScale;

	p += time * 0.07;

	float f = noise( p );
	p = m * p + time * 0.3;
	f += 0.4 * noise( 1.01 * p );
	p = m * p - time * 0.6;
	f += 0.2 * noise( 1.03 * p );

    f = mix(0.0, f, factor);

	return f;
}

vec4 RaymarchClouds(in vec3 start, in vec3 end, float op)
{
	float l = length(end - start);
	const float numsteps = 10.0;
	const float tstep = 1. / numsteps;
	float depth = min(l * fogThicknessInv, 1.5);

	float fogContrib = 0.;
	float sunContrib = 0.;
	float alpha = 0.;

	for (float t=0.0; t<=1.0; t+=tstep) {
		vec3  pos = mix(start, end, t);
		float fog = MapClouds(pos);
		fogContrib += fog;

		vec3  lightPos = sundir * sunPenetrationDepth + pos;
		float lightFog = MapClouds(lightPos);
		float sunVisibility = clamp((fog - lightFog), 0.0, 1.0 ) * sunDiffuseStrength;
		sunContrib += sunVisibility;

		float b = smoothstep(1.0, 0.7, abs((t - 0.5) * 2.0));
		alpha += b;
	}

	fogContrib *= tstep;
	sunContrib *= tstep;
	alpha      *= tstep * op * depth;

	vec3 ndir = (end - start) / l;
	float sun = pow( clamp( dot(sundir, ndir), 0.0, 1.0 ), sunSpecularExponent );
	sunContrib += sun * clamp(1. - fogContrib * alpha, 0.2, 1.) * 1.0;

	vec4 col;
	col.rgb = sunContrib * suncolor + fogColor;
	col.a   = fogContrib * alpha;
	return col;
}

vec3 GetWorldPos(in float z, in vec2 screenpos)
{
	vec4 ppos;
	#ifdef DEPTH_CLIP01
		ppos.xyz = vec3(NORM2SNORM(screenpos), z);
	#else
		ppos.xyz = NORM2SNORM(vec3(screenpos, z));
	#endif

	ppos.a = 1.;
	vec4 worldPos4 = viewProjectionInv * ppos;
	worldPos4.xyz /= worldPos4.w;

	if (z == 1.0) {
		vec3 forward = normalize(worldPos4.xyz - eyePos);
		float a = max(fogHeight - eyePos.y, eyePos.y - fogBottom) / forward.y;
		return eyePos + forward.xyz * abs(a);
	}

	return worldPos4.xyz;
}

vec4 Blend(in vec4 Src, in vec4 Dst)
{
	//alpha blending
	//vec4 Out = Src * Src.a + Dst * (1.0 - Src.a);
	//Out.a = max(Src.a, Dst.a);
	vec4 Out;

	//alpha blending - shit
	//Out = Src * Src.a + Dst * (1.0 - Src.a);

	Out.rgb = Src.rgb * Src.a + Dst.rgb * Dst.a;
	//Out.a = max(Src.a, Dst.a);
	Out.a = Src.a + Dst.a;

	return Out;
}

void main()
{
	// reconstruct worldpos from depthbuffer
	float z = texture2D(tex0, gl_TexCoord[0].st).x;
	vec3 worldPos = GetWorldPos(z, gl_TexCoord[0].st);

	gl_FragColor = vec4(0.0);

	#if 0
	{
		if (z != 1.0) {
			//vec4 sunPos = vec4(sundir * fogHeight / dot(sundir, vec3(0, 1, 0)), 1.0);
			vec3 sunPos = sundir * 50000.0;

			// clamp ray in boundary box
			Ray r;
			r.Origin = worldPos;
			r.Dir = sunPos - worldPos;
			AABB box;

			box = aabbCamera;

			box.Min = max(box.Min, vAA);
			box.Max = min(box.Max, vBB);

			float t1, t2;

			// TODO: find a way to do this when eye is inside volume
			if (IntersectBox(r, box, t1, t2)) {
				t1 = clamp(t1, 0.0, 1.0);
				t2 = clamp(t2, 0.0, 1.0);
				vec3 startPos = r.Dir * t1 + r.Origin;
				vec3 endPos   = r.Dir * t2 + r.Origin;

				// finally raymarch the volume
				vec4 rmColor = RaymarchClouds(startPos, endPos, shadowOpacity);
				gl_FragColor.a = pow(1.5 * rmColor.a, 3.0);
			}
		}
	}
	#endif
	#if 1
	{
		// clamp ray in boundary box
		Ray r;
		r.Origin = eyePos;
		r.Dir = worldPos - eyePos;
		AABB box;
		//box.Min = vAA;
		//box.Max = vBB;
		box = aabbCamera;

		box.Min = max(box.Min, vAA);
		box.Max = min(box.Max, vBB);

		float t1, t2;

		// TODO: find a way to do this when eye is inside volume
		if (IntersectBox(r, box, t1, t2)) {
			t1 = clamp(t1, 0.0, 1.0);
			t2 = clamp(t2, 0.0, 1.0);
			vec3 startPos = r.Dir * t1 + r.Origin;
			vec3 endPos   = r.Dir * t2 + r.Origin;

			// finally raymarch the volume
			vec4 rmColor = RaymarchClouds(startPos, endPos, opacity);
			gl_FragColor = Blend(gl_FragColor, rmColor);
			#ifndef CLAMP_TO_MAP
				// blend with distance to make endless fog have smooth horizon
				gl_FragColor.a *= smoothstep(gl_Fog.end * 10.0, gl_Fog.start, length(worldPos - eyePos));
			#endif
		}
	}
	#endif
}

]]

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetConfigData()
	return {opacityMult = opacityMult}
end

function widget:SetConfigData(data)
	if data.opacityMult ~= nil then
		opacityMult = data.opacityMult
	end
end


local function init()

	if depthShader then
		glDeleteShader(depthShader)
	end

	fragSrc = fragSrc:format(
		cloudsScale, cloudsHeight, cloudsBottom,
		cloudsColor[1], cloudsColor[2], cloudsColor[3],
		Game.mapSizeX, Game.mapSizeZ,
		fade_alt, opacity*opacityMult, sunPenetration
	)

	fragSrc = fragSrc:gsub("###DEPTH_CLIP01###", tostring((Platform.glSupportClipSpaceControl and 1) or 0))
	fragSrc = fragSrc:gsub("###CLAMP_TO_MAP###", tostring((cloudsClamp and 1) or 0))

	if enabled then
		depthShader = glCreateShader({
			vertex = vertSrc,
			fragment = fragSrc,
			uniformInt = {
				tex0 = 0,
				tex1 = 1,
				tex2 = 2,
			},
		})

		spEcho(glGetShaderLog())
		if not depthShader then
			spEcho("Bad shader, reverting to non-GLSL widget.")
			enabled = false
		else
			uniformEyePos       = glGetUniformLocation(depthShader, 'eyePos')
			uniformViewPrjInv   = glGetUniformLocation(depthShader, 'viewProjectionInv')
			uniformOffset       = glGetUniformLocation(depthShader, 'offset')
			uniformSundir       = glGetUniformLocation(depthShader, 'sundir')
			uniformSunColor     = glGetUniformLocation(depthShader, 'suncolor')
			uniformTime         = glGetUniformLocation(depthShader, 'time')
		end
	end
end


function widget:Initialize()

	WG['clouds'] = {}
	WG['clouds'].getOpacity = function()
		return opacityMult
	end
	WG['clouds'].setOpacity = function(value)
		opacityMult = value
		init()
	end

	if not glCreateShader then
		enabled = false
	end

	init()

	if not enabled then
		widgetHandler:RemoveWidget()
		return
	end

	if Game.windMax < 5 then
		widgetHandler:RemoveWidget()
		return
	end
end


function widget:Shutdown()
	glDeleteTexture(depthTexture)
	glDeleteTexture(fogTexture)
	if glDeleteShader then
		glDeleteShader(depthShader)
	end
	glDeleteTexture(noiseTex)
end


local function renderToTextureFunc()
	-- render a full screen quad
	glTexture(0, depthTexture)
	glTexture(0, false)
	glTexture(1, noiseTex)
	glTexture(1, false)
	glTexture(2, noiseTex3D)
	glTexture(2, false)

	gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
end

local function DrawFogNew()
	-- copy the depth buffer
	glCopyToTexture(depthTexture, 0, 0, vpx, vpy, vsx, vsy) --FIXME scale down?

	-- setup the shader and its uniform values
	glUseShader(depthShader)

	-- set uniforms
	glUniform(uniformEyePos, spGetCameraPosition())
	glUniform(uniformOffset, offsetX, offsetY, offsetZ)

	glUniform(uniformSundir, sunDir[1], sunDir[2], sunDir[3])
	glUniform(uniformSunColor, sunCol[1], sunCol[2], sunCol[3])

	glUniform(uniformTime, Spring.GetGameSeconds() * speed)

	glUniformMatrix(uniformViewPrjInv,  "viewprojectioninverse")

	-- TODO: completely reset the texture before applying shader
	-- TODO: figure out why it disappears in some places
	-- maybe add a switch to make it high-res direct-render
	gl.RenderToTexture(fogTexture, renderToTextureFunc)

	glUseShader(0)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GameFrame()
	local dx,dy,dz = spGetWind()
	offsetX = offsetX-dx*speed
	offsetY = offsetY-0.25-dy*0.25*speed
	offsetZ = offsetZ-dz*speed

	sunDir = {gl.GetSun('pos')}
	sunCol = {gl.GetSun('specular')}
end

local function DrawClouds()
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	gl.MatrixMode(GL.MODELVIEW)
	gl.PushMatrix()
	gl.LoadIdentity()

		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()

			glTexture(fogTexture)
			gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
			glTexture(false)

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()

	gl.MatrixMode(GL.MODELVIEW)
	gl.PopMatrix()
end

--[[
function widget:DrawScreen()
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA) -- in theory not needed but sometimes evil widgets disable it w/o reenabling it
	glTexture(fogTexture)
	gl.TexRect(0,0,vsx,vsy,0,0,1,1)
	glTexture(false)
end
]]--

function widget:DrawWorld()
	DrawClouds()
end

function widget:DrawWorldPreUnit()
	glBlending(false)
	DrawFogNew()
	--DrawClouds()
	glBlending(true)
end
