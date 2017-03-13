--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
	name      = "Deferred rendering",
	version   = 3,
	desc      = "Collects and renders point and beam lights",
	author    = "beherith, aeonios",
	date      = "2015 Sept.",
	license   = "GPL V2",
	layer     = -1000000000,
	enabled   = true
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local glBeginEnd             = gl.BeginEnd
local glBillboard            = gl.Billboard
local glBlending             = gl.Blending
local glCallList             = gl.CallList
local glClear								 = gl.Clear
local glColor                = gl.Color
local glCreateList           = gl.CreateList
local glCreateShader         = gl.CreateShader
local glCreateTexture        = gl.CreateTexture
local glDeleteShader         = gl.DeleteShader
local glDeleteTexture        = gl.DeleteTexture
local glDepthMask            = gl.DepthMask
local glDepthTest            = gl.DepthTest
local glGetShaderLog         = gl.GetShaderLog
local glGetUniformLocation   = gl.GetUniformLocation
local glGetViewSizes         = gl.GetViewSizes
local glPopMatrix            = gl.PopMatrix
local glPushMatrix           = gl.PushMatrix
local glTexCoord             = gl.TexCoord
local glTexture              = gl.Texture
local glTexRect              = gl.TexRect
local glRect                 = gl.Rect
local glRenderToTexture      = gl.RenderToTexture
local glUniform              = gl.Uniform
local glUniformInt           = gl.UniformInt
local glUniformMatrix        = gl.UniformMatrix
local glUseShader            = gl.UseShader
local glVertex               = gl.Vertex
local glTranslate            = gl.Translate
local spEcho                 = Spring.Echo
local spGetCameraPosition    = Spring.GetCameraPosition
local spWorldToScreenCoords  = Spring.WorldToScreenCoords


local glowImg			= ":n:"..LUAUI_DIRNAME.."Images/glow.dds"
local beamGlowImg = LUAUI_DIRNAME.."Images/barglow-center.dds"
local beamGlowEndImg = LUAUI_DIRNAME.."Images/barglow-edge.dds"

local GLSLRenderer = true

local vsx, vsy
local ivsx = 1.0 
local ivsy = 1.0 
local screenratio = 1.0

-- dynamic light shaders
local depthPointShader = nil
local depthBeamShader = nil

-- shader uniforms
local lightposlocPoint = nil
local lightcolorlocPoint = nil
local lightparamslocPoint = nil
local uniformEyePosPoint
local uniformViewPrjInvPoint

local lightposlocBeam  = nil
local lightpos2locBeam  = nil
local lightcolorlocBeam  = nil
local lightparamslocBeam  = nil
local uniformEyePosBeam 
local uniformViewPrjInvBeam

--------------------------------------------------------------------------------
--Light falloff functions: http://gamedev.stackexchange.com/questions/56897/glsl-light-attenuation-color-and-intensity-formula
--------------------------------------------------------------------------------

local verbose = false
local function VerboseEcho(...)
	if verbose then
		Spring.Echo(...) 
	end
end

local collectionFunctions = {}
local collectionFunctionCount = 0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()
	ivsx = 1.0 / vsx --we can do /n here!
	ivsy = 1.0 / vsy
	if (Spring.GetMiniMapDualScreen() == 'left') then
		vsx = vsx / 2
	end
	if (Spring.GetMiniMapDualScreen() == 'right') then
		vsx = vsx / 2
	end
	screenratio = vsy / vsx --so we dont overdraw and only always draw a square
end

widget:ViewResize()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local vertSrc = [[
  void main(void)
  {
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position    = gl_Vertex;
  }
]]
local fragSrc = [[
	//This code authored by Peter Sarkozy aka Beherith (mysterme@gmail.com )
	//License is GPL V2
	// old version with calced normals is 67 fps for 10 beamers full screen at 1440p
	// new version with buffered normals is 88 fps for 10 beamers full screen at 1440p


	//#define DEBUG

	#define LIGHTRADIUS lightpos.w
	uniform sampler2D modelnormals;
	uniform sampler2D modeldepths;
	uniform sampler2D mapnormals;
	uniform sampler2D mapdepths;
	uniform sampler2D modelExtra;

	uniform vec3 eyePos;
	uniform vec4 lightpos;
	#ifdef BEAM_LIGHT
		uniform vec4 lightpos2;
	#endif
	uniform vec4 lightcolor;
	uniform mat4 viewProjectionInv;

	float attentuate(float dist, float radius)
		{
			//float att = clamp ( constant-linear * dist / radius - squared * dist * dist / (radius*radius),0.0,.5);
			float att = clamp(0.7 - 0.3 * dist / radius - 1.0 * dist * dist / (radius * radius), 0.0, 1.0);
			att *= att;
			return att;
		}

	void main(void)
	{
		vec4 mappos4   = vec4(vec3(gl_TexCoord[0].st, texture2D(mapdepths,   gl_TexCoord[0].st).x) * 2.0 - 1.0, 1.0);
		vec4 modelpos4 = vec4(vec3(gl_TexCoord[0].st, texture2D(modeldepths, gl_TexCoord[0].st).x) * 2.0 - 1.0, 1.0);
		vec4 map_normals4   = texture2D(mapnormals,   gl_TexCoord[0].st) * 2.0 - 1.0;
		vec4 model_normals4 = texture2D(modelnormals, gl_TexCoord[0].st) * 2.0 - 1.0;
		vec4 model_extra4 = texture2D(modelExtra, gl_TexCoord[0].st) * 2.0 - 1.0;
		float specularHighlight = 1.0;
		float model_lighting_multiplier = 1.0; //models recieve additional lighting, looks better.
		if ((mappos4.z-modelpos4.z) > 0.0) { // this means we are processing a model fragment, not a map fragment
			if (model_extra4.a > 0.5){
			map_normals4 = model_normals4;
			mappos4 = modelpos4;
			model_lighting_multiplier=1.5;
			specularHighlight= specularHighlight + 2.0*model_extra4.g;
			}
		}
		mappos4 = viewProjectionInv * mappos4;
		mappos4.xyz = mappos4.xyz / mappos4.w;
		vec3 light_direction;
		#ifndef BEAM_LIGHT
			float dist_light_here = length(lightpos.xyz - mappos4.xyz);
			light_direction = normalize(lightpos.xyz - mappos4.xyz);
			float cosphi = max(0.0 , dot (normalize(map_normals4.xyz), normalize(lightpos.xyz - mappos4.xyz)));
			float attentuation=attentuate(dist_light_here,LIGHTRADIUS);
		#endif
		#ifdef BEAM_LIGHT
			//def dist(x1,y1, x2,y2, x3,y3): # x3,y3 is the point
			/*distance( Point P,  Segment P0:P1 ) // http://geomalgorithms.com/a02-_lines.html
			{
				v = P1 - P0
				w = P - P0
				if ( (c1 = w dot v) <= 0 )  // before P0
					return d(P, P0)
				if ( (c2 = v dot v) <= c1 ) // after P1
					return d(P, P1)
				b = c1 / c2
				Pb = P0 + bv
				return d(P, Pb)
			}
			*/

			vec3 v = lightpos2.xyz - lightpos.xyz;
			vec3 w = mappos4.xyz   - lightpos.xyz;
			float c1 = dot(v, w);
			float c2 = dot(v, v);
			if (c1 <= 0.0){
				v = mappos4.xyz;
				w = lightpos.xyz;
			}else if (c2 < c1){
				v = mappos4.xyz;
				w = lightpos2.xyz;
			}else{
				w = lightpos.xyz + (c1 / c2) * v;
				v = mappos4.xyz;
			}
			float dist_light_here = length(v - w);
			light_direction = normalize(w.xyz - mappos4.xyz);
			float cosphi = max(0.0 , dot (normalize(map_normals4.xyz), light_direction));
			//float attentuation = max(0.0, (1.0 * LIGHT_CONSTANT - LIGHT_SQUARED * (dist_light_here * dist_light_here) / (LIGHTRADIUS * LIGHTRADIUS) - LIGHT_LINEAR * (dist_light_here) / (LIGHTRADIUS)));
			float attentuation = attentuate(dist_light_here, LIGHTRADIUS);
		#endif
		

		vec3 viewDirection = normalize(vec3(eyePos - mappos4.xyz));
		
		if (dot(map_normals4.xyz, light_direction) > 0.02) // light source on the wrong side?
		{
			vec3 reflection = reflect(-1.0 * light_direction, map_normals4.xyz);
			float highlight = pow(max(0.0, dot( reflection, viewDirection)), 8.0);
			specularHighlight = specularHighlight * (0.5* highlight);
		}else{
			specularHighlight = 0.0;
		}
		//OK, our blending func is the following: Rr=Lr*Dr+1*Dr
		float lightalpha = cosphi * attentuation + attentuation * specularHighlight;
		//dont light underwater:
		lightalpha = clamp(lightalpha, 0.0, lightalpha * ((mappos4.y + 50.0)* (0.02)));
		gl_FragColor = vec4(lightcolor.rgb * lightalpha * model_lighting_multiplier, 1.0);
		#ifdef DEBUG
			gl_FragColor = vec4(map_normals4.xyz, 1.0); //world normals debugging
			gl_FragColor = vec4(fract(modelpos4.z * 0.01),sign(mappos4.z - modelpos4.z), 0.0, 1.0); //world pos debugging, very useful
			if (length(lightcolor.rgb * lightalpha * model_lighting_multiplier) < (1.0 / 256.0)){ //shows light boudaries
				gl_FragColor=vec4(vec3(0.5, 0.0, 0.5), 0.0);
			}
		#endif
		return;
	}
]]

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DeferredLighting_RegisterFunction(func)
	collectionFunctionCount = collectionFunctionCount + 1
	collectionFunctions[collectionFunctionCount] = func
end

function widget:Initialize()
	
	if (glCreateShader == nil) then
		Spring.Echo('Deferred Rendering requires shader support!') 
		widgetHandler:RemoveWidget()
		return
	end
	
	Spring.SetConfigInt("AllowDeferredMapRendering", 1)
	Spring.SetConfigInt("AllowDeferredModelRendering", 1)

	if (Spring.GetConfigString("AllowDeferredMapRendering") == '0' or Spring.GetConfigString("AllowDeferredModelRendering") == '0') then
		Spring.Echo('Deferred Rendering (gfx_deferred_rendering.lua) requires  AllowDeferredMapRendering and AllowDeferredModelRendering to be enabled in springsettings.cfg!') 
		widgetHandler:RemoveWidget()
		return
	end
	if ((not forceNonGLSL) and Spring.GetMiniMapDualScreen() ~= 'left') then --FIXME dualscreen
		if (not glCreateShader) then
			spEcho("gfx_deferred_rendering.lua: Shaders not found, removing self.")
			GLSLRenderer = false
			widgetHandler:RemoveWidget()
		else
			depthPointShader = depthPointShader or glCreateShader({
				vertex = vertSrc,
				fragment = fragSrc,
				uniformInt = {
					modelnormals = 0,
					modeldepths = 1,
					mapnormals = 2,
					mapdepths = 3,
					modelExtra = 4,
				},
			})

			if (not depthPointShader) then
				spEcho(glGetShaderLog())
				spEcho("gfx_deferred_rendering.lua: Bad depth point shader, removing self.")
				GLSLRenderer = false
				widgetHandler:RemoveWidget()
			else
				lightposlocPoint       = glGetUniformLocation(depthPointShader, "lightpos")
				lightcolorlocPoint     = glGetUniformLocation(depthPointShader, "lightcolor")
				uniformEyePosPoint     = glGetUniformLocation(depthPointShader, 'eyePos')
				uniformViewPrjInvPoint = glGetUniformLocation(depthPointShader, 'viewProjectionInv')
			end
			fragSrc = "#define BEAM_LIGHT \n" .. fragSrc
			depthBeamShader = depthBeamShader or glCreateShader({
				vertex = vertSrc,
				fragment = fragSrc,
				uniformInt = {
					modelnormals = 0,
					modeldepths = 1,
					mapnormals = 2,
					mapdepths = 3,
					modelExtra = 4,
				},
			})

			if (not depthBeamShader) then
				spEcho(glGetShaderLog())
				spEcho("gfx_deferred_rendering.lua: Bad depth beam shader, removing self.")
				GLSLRenderer = false
				widgetHandler:RemoveWidget()
			else
				lightposlocBeam       = glGetUniformLocation(depthBeamShader, 'lightpos')
				lightpos2locBeam      = glGetUniformLocation(depthBeamShader, 'lightpos2')
				lightcolorlocBeam     = glGetUniformLocation(depthBeamShader, 'lightcolor')
				uniformEyePosBeam     = glGetUniformLocation(depthBeamShader, 'eyePos')
				uniformViewPrjInvBeam = glGetUniformLocation(depthBeamShader, 'viewProjectionInv')
			end
			
			WG.DeferredLighting_RegisterFunction = DeferredLighting_RegisterFunction
		end
		screenratio = vsy / vsx --so we dont overdraw and only always draw a square
	else
		GLSLRenderer = false
	end
	
	widget:ViewResize()
end

function widget:Shutdown()
	if (GLSLRenderer) then
		if (glDeleteShader) then
			glDeleteShader(depthPointShader)
			glDeleteShader(depthBeamShader)
		end
	end
end

local function DrawLightType(lights, lightsCount, lighttype) -- point = 0 beam = 1
	--Spring.Echo('Camera FOV = ', Spring.GetCameraFOV()) -- default TA cam fov = 45
	--set uniforms:
	local cpx, cpy, cpz = spGetCameraPosition()
	if lighttype == 0 then --point
		glUseShader(depthPointShader)
		glUniform(uniformEyePosPoint, cpx, cpy, cpz)
		glUniformMatrix(uniformViewPrjInvPoint,  "viewprojectioninverse")
	else --beam
		glUseShader(depthBeamShader)
		glUniform(uniformEyePosBeam, cpx, cpy, cpz)
		glUniformMatrix(uniformViewPrjInvBeam,  "viewprojectioninverse")
	end

	glTexture(0, "$model_gbuffer_normtex")
	glTexture(1, "$model_gbuffer_zvaltex")
	glTexture(2, "$map_gbuffer_normtex")
	glTexture(3, "$map_gbuffer_zvaltex")
	glTexture(4, "$model_gbuffer_spectex")
	
	local cx, cy, cz = spGetCameraPosition()
	for i = 1, lightsCount do
		local light = lights[i]
		local param = light.param
		if verbose then
			VerboseEcho('gfx_deferred_rendering.lua: Light being drawn:', i)
			Spring.Utilities.TableEcho(light)
		end
		if lighttype == 0 then -- point
			local lightradius = param.radius
			--Spring.Echo("Drawlighttype position = ", light.px, light.py, light.pz)
			local sx, sy, sz = spWorldToScreenCoords(light.px, light.py, light.pz) -- returns x, y, z, where x and y are screen pixels, and z is z buffer depth.
			sx = sx/vsx
			sy = sy/vsy --since FOV is static in the Y direction, the Y ratio is the correct one
			local dist_sq = (light.px-cx)^2 + (light.py-cy)^2 + (light.pz-cz)^2
			local ratio = lightradius / math.sqrt(dist_sq) * 1.5
			glUniform(lightposlocPoint, light.px, light.py, light.pz, param.radius) --in world space
			glUniform(lightcolorlocPoint, param.r * light.colMult, param.g * light.colMult, param.b * light.colMult, 1) 
			glTexRect(
				math.max(-1 , (sx-0.5)*2-ratio*screenratio), 
				math.max(-1 , (sy-0.5)*2-ratio), 
				math.min( 1 , (sx-0.5)*2+ratio*screenratio), 
				math.min( 1 , (sy-0.5)*2+ratio), 
				math.max( 0 , sx - 0.5*ratio*screenratio), 
				math.max( 0 , sy - 0.5*ratio), 
				math.min( 1 , sx + 0.5*ratio*screenratio),
				math.min( 1 , sy + 0.5*ratio)
			) -- screen size goes from -1, -1 to 1, 1; uvs go from 0, 0 to 1, 1
		end 
		if lighttype == 1 then -- beam
			local lightradius = 0
			local px = light.px+light.dx*0.5
			local py = light.py+light.dy*0.5
			local pz = light.pz+light.dz*0.5
			local lightradius = param.radius + math.sqrt(light.dx^2 + light.dy^2 + light.dz^2)*0.5
			VerboseEcho("Drawlighttype position = ", light.px, light.py, light.pz)
			local sx, sy, sz = spWorldToScreenCoords(px, py, pz) -- returns x, y, z, where x and y are screen pixels, and z is z buffer depth.
			sx = sx/vsx
			sy = sy/vsy --since FOV is static in the Y direction, the Y ratio is the correct one
			local dist_sq = (px-cx)^2 + (py-cy)^2 + (pz-cz)^2
			local ratio = lightradius / math.sqrt(dist_sq)
			ratio = ratio*2

			glUniform(lightposlocBeam, light.px, light.py, light.pz, param.radius) --in world space
			glUniform(lightpos2locBeam, light.px+light.dx, light.py+light.dy+24, light.pz+light.dz, param.radius) --in world space, the magic constant of +24 in the Y pos is needed because of our beam distance calculator function in GLSL
			glUniform(lightcolorlocBeam, param.r * light.colMult, param.g * light.colMult, param.b * light.colMult, 1) 
			--TODO: use gl.Shape instead, to avoid overdraw
			glTexRect(
				math.max(-1 , (sx-0.5)*2-ratio*screenratio), 
				math.max(-1 , (sy-0.5)*2-ratio), 
				math.min( 1 , (sx-0.5)*2+ratio*screenratio), 
				math.min( 1 , (sy-0.5)*2+ratio), 
				math.max( 0 , sx - 0.5*ratio*screenratio), 
				math.max( 0 , sy - 0.5*ratio), 
				math.min( 1 , sx + 0.5*ratio*screenratio),
				math.min( 1 , sy + 0.5*ratio)
			) -- screen size goes from -1, -1 to 1, 1; uvs go from 0, 0 to 1, 1
		end
	end
	glUseShader(0)
end

local function renderToTextureFunc(tex, s, t)
	glTexture(tex)
	glTexRect(-1 * s, -1 * t,  1 * s, 1 * t)
	glTexture(false)
end

local function mglRenderToTexture(FBOTex, tex, s, t)
	glRenderToTexture(FBOTex, renderToTextureFunc, tex, s, t)
end
	
local beamLights = {}
local beamLightCount = 0
local pointLights = {}
local pointLightCount = 0
function widget:Update()
	beamLights = {}
	beamLightCount = 0
	pointLights = {}
	pointLightCount = 0
	for i = 1, collectionFunctionCount do
		beamLights, beamLightCount, pointLights, pointLightCount = collectionFunctions[i](beamLights, beamLightCount, pointLights, pointLightCount)
	end
end

-- adding a glow to the projectile
function widget:DrawWorld()

	local lights = pointLights
	glBlending(GL.SRC_ALPHA, GL.ONE)
	gl.Texture(glowImg)
	for i = 1, pointLightCount do
		local light = lights[i]
		local param = light.param
		if param.gib == nil and param.type == "Cannon"then
			size = param.radius * 0.25
			gl.PushMatrix()
				local colorMultiplier = 1 / math.max(param.r, param.g, param.b)
				gl.Color(param.r*colorMultiplier, param.g*colorMultiplier, param.b*colorMultiplier, size/17000)
				gl.Translate(light.px, light.py, light.pz)
				gl.Billboard(true)
				gl.TexRect(-(size/2), -(size/2), (size/2), (size/2))
			gl.PopMatrix()
		end
	end
	
	---- dont know how to do this yet, or if it will look satisfying enough
	--lights = beamLights
	--gl.Texture(beamGlowImg)
	--for i = 1, beamLightCount do
	--	local light = lights[i]
	--	local param = light.param
	--	size = param.radius/2
	--	--local dist_sq = (light.px-(light.px+light.dx))^2 + (light.py-(light.py+light.dy))^2 + (light.pz-(light.pz+light.dz))^2
	--	gl.PushMatrix()
	--		gl.Color(param.r*4, param.g*4, param.b*4, 0.5)		-- '*4' still needs to be changed to proper values
	--		gl.Translate(light.px, light.py, light.pz)
	--		--gl.Billboard(true)
	--		gl.BeginEnd(GL.QUADS, function()
	--			gl.Vertex(0,-(size/2),0)
	--			gl.Vertex(0,(size/2),0)
	--			gl.Vertex(light.px, light.py-(size/2), light.pz)
	--			gl.Vertex(light.px, light.py+(size/2), light.pz)
	--		end)
	--	gl.PopMatrix()
	--end
	
	gl.Billboard(false)
	gl.Texture(false)
	glBlending(false)
end


function widget:DrawScreenEffects()
	if not (GLSLRenderer) then
		Spring.Echo('Removing deferred rendering widget: failed to use GLSL shader')
		widgetHandler:RemoveWidget()
		return
	end
	
	--glBlending(GL.DST_COLOR, GL.ONE) -- Set add blending mode
	glBlending(GL.SRC_ALPHA, GL.ONE)
	
	if beamLightCount > 0 then
		DrawLightType(beamLights, beamLightCount, 1)
	end
	if pointLightCount > 0 then
		DrawLightType(pointLights, pointLightCount, 0)
	end
	
	glBlending(false)
end