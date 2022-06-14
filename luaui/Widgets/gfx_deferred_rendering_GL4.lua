--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "Deferred rendering GL4",
		version = 3,
		desc = "Collects and renders cone, point and beam lights",
		author = "Beherith",
		date = "2022.06.10",
		license = "GPL V2",
		layer = -99999990,
		enabled = true
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local glBeginEnd = gl.BeginEnd
local glBillboard = gl.Billboard
local glBlending = gl.Blending
local glCallList = gl.CallList
local glClear = gl.Clear
local glColor = gl.Color
local glCreateList = gl.CreateList
local glCreateShader = gl.CreateShader
local glCreateTexture = gl.CreateTexture
local glDeleteShader = gl.DeleteShader
local glDeleteTexture = gl.DeleteTexture
local glDepthMask = gl.DepthMask
local glDepthTest = gl.DepthTest
local glGetShaderLog = gl.GetShaderLog
local glGetUniformLocation = gl.GetUniformLocation
local glGetViewSizes = gl.GetViewSizes
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTexCoord = gl.TexCoord
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glRect = gl.Rect
local glRenderToTexture = gl.RenderToTexture
local glUniform = gl.Uniform
local glUniformInt = gl.UniformInt
local glUniformMatrix = gl.UniformMatrix
local glUseShader = gl.UseShader
local glVertex = gl.Vertex
local glTranslate = gl.Translate
local spEcho = Spring.Echo
local spGetCameraPosition = Spring.GetCameraPosition
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetGroundHeight = Spring.GetGroundHeight

local math_sqrt = math.sqrt
local math_min = math.min
local math_max = math.max

local glowImg = "LuaUI/Images/glow2.dds"
local beamGlowImg = ":n:LuaUI/Images/barglow-center.png"
local beamGlowEndImg = ":n:LuaUI/Images/barglow-edge.png"

local GLSLRenderer = true

local vsx, vsy, chobbyInterface, forceNonGLSL
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

local lightposlocBeam = nil
local lightpos2locBeam = nil
local lightcolorlocBeam = nil
local lightparamslocBeam = nil
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


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()
	ivsx = 1.0 / vsx --we can do /n here!
	ivsy = 1.0 / vsy
	if Spring.GetMiniMapDualScreen() == 'left' then
		vsx = vsx / 2
	end
	if Spring.GetMiniMapDualScreen() == 'right' then
		vsx = vsx / 2
	end
	screenratio = vsy / vsx --so we dont overdraw and only always draw a square
end

widget:ViewResize()

-- GL4 notes:
-- A sphere light should be an icosahedrong
-- A cone light should be a cone
-- A beam light should be a cylinder
-- all prims should be back-face only rendered!


-- Separate VBO's for spheres, cones, beams
-- no geometry shader for now, its kinda pointless, might change my mind later

-- Sources of light
-- Projectiles
	-- beamlasers
		-- might get away with not updating their pos each frame?
		-- probably not, due to continuous lasers like beamer turret
	-- lightning
		-- these move too?
	-- plasma balls
		-- these are actually easy to sim, but might not be worth it
	-- missiles
		-- unsimable, must be queried
	-- rockets
		-- hard to sim
	-- gibs
		-- hard to sim
-- Explosions
	-- actually spawn once, reasonably easy (separate vbotable for them?) 
	-- always spherical, should be able to override a param with them
	-- 
-- mapdefined lights
	-- animating them might be a challenge
-- headlights
	-- would rock, needs their own vbo for position maybe?
	-- or just extend
-- piecelights
	-- for thrusters, would be truly epic!
	-- fusion lights

-- would be nice to have:
	-- full map-level dense atmosphere
	-- explosions should kick up dust
	-- simulate wind and other movements
	-- at a rez of 32 elmos, dsd would need:
	-- 256*256*16 voxels (1 million?) yeesh

local shaderConfig = {
	TRANSPARENCY = 0.2, 
}

local coneLightVBO
local beamLightVBO
local pointLightVBO

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local deferredLightShader = nil

local function goodbye(reason) 
	Spring.Echo(reason)
	widgetHandler:RemoveWidget()
end

local vsSrcPath = "LuaUI/Widgets/Shaders/deferred_lights_gl4.vert.glsl"
local fsSrcPath = "LuaUI/Widgets/Shaders/deferred_lights_gl4.frag.glsl"

local lastshaderupdate = nil
local shaderSourceCache = {}
local function checkShaderUpdates(vssrcpath, fssrcpath, gssrcpath, shadername, delaytime)
	if lastshaderupdate == nil or 
		Spring.DiffTimers(Spring.GetTimer(), lastshaderupdate) > (delaytime or 0.25) then 
		lastshaderupdate = Spring.GetTimer()
		local vsSrcNew = vssrcpath and VFS.LoadFile(vssrcpath)
		local fsSrcNew = fssrcpath and VFS.LoadFile(fssrcpath)
		local gsSrcNew = gssrcpath and VFS.LoadFile(gssrcpath)
		if  vsSrcNew == shaderSourceCache.vsSrc and 
			fsSrcNew == shaderSourceCache.fsSrc and 
			gsSrcNew == shaderSourceCache.gsSrc then 
			--Spring.Echo("No change in shaders")
			return nil
		else
			local compilestarttime = Spring.GetTimer()
			shaderSourceCache.vsSrc = vsSrcNew
			shaderSourceCache.fsSrc = fsSrcNew
			shaderSourceCache.gsSrc = gsSrcNew
			
			local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
			if vsSrcNew then 
				vsSrcNew = vsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				vsSrcNew = vsSrcNew:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig))
			end
			if fsSrcNew then 
				fsSrcNew = fsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				fsSrcNew = fsSrcNew:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig))
			end
			if gsSrcNew then 
				gsSrcNew = gsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				gsSrcNew = gsSrcNew:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig))
			end
			local reinitshader =  LuaShader(
				{
				vertex = vsSrcNew,
				fragment = fsSrcNew,
				geometry = gsSrcNew,
				uniformInt = {
					mapDepths = 0,
					modelDepths = 1,
					mapNormals = 2,
					modelNormals = 3,
					mapExtra = 4, 
					modelExtra = 5,
					},
				uniformFloat = {
					pointbeamcone = 0,
					fadeDistance = 3000,
				  },
				},
				shadername
			)
			local shaderCompiled = reinitshader:Initialize()
			
			Spring.Echo(shadername, " recompiled in ", Spring.DiffTimers(Spring.GetTimer(), compilestarttime, true), "ms at", Spring.GetGameFrame(), "success", shaderCompiled or false)
			if shaderCompiled then 
				return reinitshader
			else
				return nil
			end
		end
	end
	return nil
end

local function initGL4()
	-- init the VBO
	local vboLayout = {
			{id = 3, name = 'worldposrad', size = 4}, 
				-- for spot, this is center.xyz and radius
				-- for cone, this is center.xyz and height
				-- for beam this is center.xyz and radiusleft
			{id = 4, name = 'worldposrad2', size = 4},
				-- for spot, this is 0
				-- for cone, this is direction.xyz and angle in radians
				-- for beam this is end.xyz and radiusright
			{id = 5, name = 'lightcolor', size = 4},
				-- this is light color rgba for all
			{id = 6, name = 'falloff_dense_scattering', size = 4},
			{id = 7, name = 'otherparams', size = 4},
	}
	
	local coneVBO, numConeVertices = makeConeVBO(16, 1, 1)
	coneLightVBO = makeInstanceVBOTable( vboLayout, 64, "Cone Light VBO")
	if coneVBO == nil or coneLightVBO == nil then goodbye("Failed to make VBO") end 
	coneLightVBO.vertexVBO = coneVBO
	coneLightVBO.numVertices = numConeVertices
	coneLightVBO.VAO = makeVAOandAttach(coneLightVBO.vertexVBO, coneLightVBO.instanceVBO)
	
	local beamVBO, numBeamVertices = makeBoxVBO(-1, -1, -1, 1, 1, 1)
	beamLightVBO = makeInstanceVBOTable(vboLayout, 64, "Beam Light VBO")
	if beamVBO == nil or beamLightVBO == nil then goodbye("Failed to make VBO") end 
	beamLightVBO.vertexVBO = beamVBO
	beamLightVBO.numVertices = numBeamVertices
	beamLightVBO.VAO = makeVAOandAttach(beamLightVBO.vertexVBO, beamLightVBO.instanceVBO)
	
	local pointVBO, numPointVertices, pointIndexVBO, numIndices = makeSphereVBO(8, 8, 1) 
	pointLightVBO = makeInstanceVBOTable(vboLayout, 64, "Beam Light VBO")
	if pointVBO == nil or pointLightVBO == nil then goodbye("Failed to make VBO") end 
	pointLightVBO.vertexVBO = pointVBO
	pointLightVBO.indexVBO = pointIndexVBO
	pointLightVBO.VAO = makeVAOandAttach(pointLightVBO.vertexVBO, pointLightVBO.instanceVBO, pointLightVBO.indexVBO)
	
	deferredLightShader =  checkShaderUpdates(vsSrcPath, fsSrcPath, nil, "Deferred Lights GL4")
	if not deferredLightShader then goodbye("Failed to compile Deferred Lights GL4 shader") end 
end



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
#if (BEAM_LIGHT == 1)
	uniform vec4 lightpos2;
#endif
uniform vec4 lightcolor;


in 

uniform mat4 viewProjectionInv;

float attenuate(float dist, float radius) {
	// float raw = constant-linear * dist / radius - squared * dist * dist / (radius * radius);
	// float att = clamp(raw, 0.0, 0.5);
	float raw = 0.7 - 0.3 * dist / radius - lightcolor.a * dist * dist / (radius * radius);
	float att = clamp(raw, 0.0, 1.0);
	return (att * att);
}

void main(void)
{
	float mapDepth = texture2D(  mapdepths, gl_TexCoord[0].st).x;
	float mdlDepth = texture2D(modeldepths, gl_TexCoord[0].st).x;

	#if (CLIP_CONTROL == 1)
	vec4 mappos4   = vec4(  vec3(gl_TexCoord[0].st * 2.0 - 1.0, mapDepth),  1.0);
	vec4 modelpos4 = vec4(  vec3(gl_TexCoord[0].st * 2.0 - 1.0, mdlDepth),  1.0);
	#else
	vec4 mappos4   = vec4(  vec3(gl_TexCoord[0].st, mapDepth) * 2.0 - 1.0,  1.0);
	vec4 modelpos4 = vec4(  vec3(gl_TexCoord[0].st, mdlDepth) * 2.0 - 1.0,  1.0);
	#endif

	vec4 map_normals4   = texture2D(mapnormals  , gl_TexCoord[0].st) * 2.0 - 1.0;
	vec4 model_normals4 = texture2D(modelnormals, gl_TexCoord[0].st) * 2.0 - 1.0;
	vec4 model_extra4   = texture2D(modelExtra  , gl_TexCoord[0].st) * 2.0 - 1.0;


	float specularHighlight = 1.0;
	float model_lighting_multiplier = 1.0; //models recieve additional lighting, looks better.


	if ((mappos4.z - modelpos4.z) > 0.0) {
		// this means we are processing a model fragment, not a map fragment
		if (model_extra4.a > 0.5) {
			map_normals4 = model_normals4;
			mappos4 = modelpos4;
			model_lighting_multiplier = 1.85;
			specularHighlight = specularHighlight + 2.5 * model_extra4.g;
		}
	}


	mappos4 = viewProjectionInv * mappos4;
	mappos4.xyz = mappos4.xyz / mappos4.w;

	vec3 light_direction;

	#if (BEAM_LIGHT == 0)
		light_direction = normalize(lightpos.xyz - mappos4.xyz);

		float dist_light_here = dot(lightpos.xyz - mappos4.xyz, light_direction);
		float cosphi = max(0.0, dot(normalize(map_normals4.xyz), light_direction));
		float attenuation = attenuate(dist_light_here, LIGHTRADIUS);

	#else

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
		} else if (c2 < c1) {
			v = mappos4.xyz;
			w = lightpos2.xyz;
		} else {
			w = lightpos.xyz + (c1 / c2) * v;
			v = mappos4.xyz;
		}

		light_direction = normalize(w.xyz - v.xyz);

		float dist_light_here = dot(w - v, light_direction);
		float cosphi = max(0.0, dot(normalize(map_normals4.xyz), light_direction));
		// float attenuation = max(0.0, (1.0 * LIGHT_CONSTANT - LIGHT_SQUARED * (dist_light_here * dist_light_here) / (LIGHTRADIUS * LIGHTRADIUS) - LIGHT_LINEAR * (dist_light_here) / (LIGHTRADIUS)));
		float attenuation = attenuate(dist_light_here, LIGHTRADIUS);
	#endif

	vec3 viewDirection = normalize(vec3(eyePos - mappos4.xyz));

	// light source on the wrong side?
	if (dot(map_normals4.xyz, light_direction) > 0.02) {
		vec3 reflection = reflect(-1.0 * light_direction, map_normals4.xyz);

		float glossiness = dot(reflection, viewDirection);
		float highlight = pow(max(0.0, glossiness), 8.0);

		specularHighlight *= (0.5 * highlight);
	} else {
		specularHighlight = 0.0;
	}


	//OK, our blending func is the following: Rr=Lr*Dr+1*Dr
	float lightalpha = cosphi * attenuation + attenuation * specularHighlight;
	//dont light underwater:
	lightalpha = clamp(lightalpha, 0.0, lightalpha * ((mappos4.y + 50.0) * (0.02)));

	gl_FragColor = vec4(lightcolor.rgb * lightalpha * model_lighting_multiplier, 1.0);

	#ifdef DEBUG
		gl_FragColor = vec4(map_normals4.xyz, 1.0); //world normals debugging
		gl_FragColor = vec4(fract(modelpos4.z * 0.01),sign(mappos4.z - modelpos4.z), 0.0, 1.0); //world pos debugging, very useful
		if (length(lightcolor.rgb * lightalpha * model_lighting_multiplier) < (1.0 / 256.0)){ //shows light boudaries
			gl_FragColor=vec4(vec3(0.5, 0.0, 0.5), 0.0);
		}
	#endif
}

]]
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--[[
local function DeferredLighting_RegisterFunction(func)
	collectionFunctionCount = collectionFunctionCount + 1
	collectionFunctions[collectionFunctionCount] = func
	return collectionFunctionCount
end

local function DeferredLighting_UnRegisterFunction(functionID)
	collectionFunctions[functionID] = nil
end
]]--
local lightCacheTable = {}
for i = 1, 20 do lightCacheTable[i] = 0 end 

local function AddPointLight(px,py,pz,radius)
	lightCacheTable[1] = px
	lightCacheTable[2] = py
	lightCacheTable[3] = pz
	lightCacheTable[4] = radius
	return pushElementInstance(pointLightVBO, lightCacheTable)
end

local function AddBeamLight(px,py,pz,radius, sx, sy, sz)
	lightCacheTable[1] = px
	lightCacheTable[2] = py
	lightCacheTable[3] = pz
	lightCacheTable[4] = radius
	lightCacheTable[5] = sx
	lightCacheTable[6] = sy
	lightCacheTable[7] = sz
	lightCacheTable[8] = radius
	return pushElementInstance(beamLightVBO, lightCacheTable)
end

local function AddConeLight(px,py,pz,height, dx, dy, dz, angle)
	lightCacheTable[1] = px
	lightCacheTable[2] = py
	lightCacheTable[3] = pz
	lightCacheTable[4] = height
	lightCacheTable[5] = dx
	lightCacheTable[6] = dy
	lightCacheTable[7] = dz
	lightCacheTable[8] = angle
	return pushElementInstance(coneLightVBO, lightCacheTable)
end

function AddRandomLight(which)
	local gf = Spring.GetGameFrame()
	local radius = math.random() * 150 + 150
	local posx = Game.mapSizeX * math.random() * 1.0
	local posz = Game.mapSizeZ * math.random() * 1.0
	local posy = Spring.GetGroundHeight(posx, posz) + math.random() * 0.5 * radius
	if which < 0.33 then -- point
		AddPointLight(posx, posy, posz, radius)
	elseif which < 0.66 then -- beam
		local s =  (math.random() - 0.5) * 500
		local t =  (math.random() + 0.5) * 100
		local u =  (math.random() - 0.5) * 500
		AddBeamLight(posx, posy , posz, radius, posx + s, posy + t, posz + u)
	else -- cone
		local s =  (math.random() - 0.5) * 2
		local t =  (math.random() + 0.0) * -1
		local u =  (math.random() - 0.5) * 2
		local lenstu = 1.0 / math.sqrt(s*s + t*t + u*u)
		local theta = math.random() * 0.9 
		AddConeLight(posx, posy + radius, posz, 3* radius, s * lenstu, t * lenstu, u * lenstu, theta)
	end
	
end


function widget:Initialize()
	
	if Spring.GetConfigString("AllowDeferredMapRendering") == '0' or Spring.GetConfigString("AllowDeferredModelRendering") == '0' then
		Spring.Echo('Deferred Rendering (gfx_deferred_rendering.lua) requires  AllowDeferredMapRendering and AllowDeferredModelRendering to be enabled in springsettings.cfg!')
		widgetHandler:RemoveWidget()
		return
	end
	
	if initGL4() == false then return end
	
	math.randomseed(1)
	for i=1, 100 do AddRandomLight(	math.random()) end 
end

function widget:Shutdown()
end

local function DrawLightType(lights, lightsCount, lighttype)
	-- point = 0 beam = 1
	--Spring.Echo('Camera FOV = ', Spring.GetCameraFOV()) -- default TA cam fov = 45
	--set uniforms:
	local cpx, cpy, cpz = spGetCameraPosition()
	if lighttype == 0 then
		--point
		glUseShader(depthPointShader)
		glUniform(uniformEyePosPoint, cpx, cpy, cpz)
		glUniformMatrix(uniformViewPrjInvPoint, "viewprojectioninverse")
	else
		--beam
		glUseShader(depthBeamShader)
		glUniform(uniformEyePosBeam, cpx, cpy, cpz)
		glUniformMatrix(uniformViewPrjInvBeam, "viewprojectioninverse")
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
			Spring.Debug.TableEcho(light)
		end
		if lighttype == 0 then
			-- point
			local lightradius = param.radius
			local falloffsquared = param.falloffsquared or 1.0
			--Spring.Echo("Drawlighttype position = ", light.px, light.py, light.pz)
			local groundheight = math_max(0, spGetGroundHeight(light.px, light.pz))
			local sx, sy, sz = spWorldToScreenCoords(light.px, groundheight, light.pz) -- returns x, y, z, where x and y are screen pixels, and z is z buffer depth.
			sx = sx / vsx
			sy = sy / vsy --since FOV is static in the Y direction, the Y ratio is the correct one
			--local dist_sq = (light.px-cx)^2 + (groundheight-cy)^2 + (light.pz-cz)^2
			local dist_sq = (light.px - cx) ^ 2 + (groundheight - cy) ^ 2 + (light.pz - cz) ^ 2
			local ratio = lightradius / math_sqrt(dist_sq) * 1.5
			glUniform(lightposlocPoint, light.px, light.py, light.pz, param.radius) --in world space
			glUniform(lightcolorlocPoint, param.r * light.colMult, param.g * light.colMult, param.b * light.colMult, falloffsquared)
			local tx1 = (sx - 0.5) * 2 - ratio * screenratio
			local ty1 = (sy - 0.5) * 2 - ratio
			local tx2 = (sx - 0.5) * 2 + ratio * screenratio
			local ty2 = (sy - 0.5) * 2 + ratio
			--PtaQ uncomment this if you want to debug:
			--Spring.Echo(string.format("sx=%.4f sy = %.4f dist_sq=%.1f ratio = %.4f, {%.4f : %.4f}-{%.4f :  %.4f}",sx,sy,dist_sq,ratio,tx1,ty1,tx2,ty2))

			glTexRect(
				math_max(-1, tx1),
				math_max(-1, ty1),
				math_min(1, tx2),
				math_min(1, ty2),
				math_max(0, sx - 0.5 * ratio * screenratio),
				math_max(0, sy - 0.5 * ratio),
				math_min(1, sx + 0.5 * ratio * screenratio),
				math_min(1, sy + 0.5 * ratio)
			) -- screen size goes from -1, -1 to 1, 1; uvs go from 0, 0 to 1, 1

		end
		if lighttype == 1 then
			-- beam
			local lightradius = 0

			local falloffsquared = param.falloffsquared or 1.0
			local px = light.px + light.dx * 0.5
			local py = light.py + light.dy * 0.5
			local pz = light.pz + light.dz * 0.5
			local lightradius = param.radius + math_sqrt(light.dx * light.dx + light.dy * light.dy + light.dz * light.dz) * 0.5
			VerboseEcho("Drawlighttype position = ", light.px, light.py, light.pz)
			local sx, sy, sz = spWorldToScreenCoords(px, py, pz) -- returns x, y, z, where x and y are screen pixels, and z is z buffer depth.
			sx = sx / vsx
			sy = sy / vsy --since FOV is static in the Y direction, the Y ratio is the correct one
			local dist_sq = (px - cx) ^ 2 + (py - cy) ^ 2 + (pz - cz) ^ 2
			local ratio = lightradius / math_sqrt(dist_sq)
			ratio = ratio * 2

			glUniform(lightposlocBeam, light.px, light.py, light.pz, param.radius) --in world space
			glUniform(lightpos2locBeam, light.px + light.dx, light.py + light.dy + 24, light.pz + light.dz, param.radius) --in world space, the magic constant of +24 in the Y pos is needed because of our beam distance calculator function in GLSL
			glUniform(lightcolorlocBeam, param.r * light.colMult, param.g * light.colMult, param.b * light.colMult, falloffsquared)
			--TODO: use gl.Shape instead, to avoid overdraw
			glTexRect(
				math_max(-1, (sx - 0.5) * 2 - ratio * screenratio),
				math_max(-1, (sy - 0.5) * 2 - ratio),
				math_min(1, (sx - 0.5) * 2 + ratio * screenratio),
				math_min(1, (sy - 0.5) * 2 + ratio),
				math_max(0, sx - 0.5 * ratio * screenratio),
				math_max(0, sy - 0.5 * ratio),
				math_min(1, sx + 0.5 * ratio * screenratio),
				math_min(1, sy + 0.5 * ratio)
			) -- screen size goes from -1, -1 to 1, 1; uvs go from 0, 0 to 1, 1
		end
	end
	glUseShader(0)
	glTexture(0, false)
	glTexture(1, false)
	glTexture(2, false)
	glTexture(3, false)
	glTexture(4, false)
end

local function renderToTextureFunc(tex, s, t)
	glTexture(tex)
	glTexRect(-1 * s, -1 * t, 1 * s, 1 * t)
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
	--[[
	beamLights = {}
	beamLightCount = 0
	pointLights = {}
	pointLightCount = 0
	for i = 1, collectionFunctionCount do
		if collectionFunctions[i] then
			beamLights, beamLightCount, pointLights, pointLightCount = collectionFunctions[i](beamLights, beamLightCount, pointLights, pointLightCount)
		end
	end
	]]--
end

-- adding a glow to Cannon projectiles
--function widget:DrawWorld()
	--[[
	local lights = pointLights
	gl.DepthMask(false)
	glBlending(GL.SRC_ALPHA, GL.ONE)
	gl.Texture(glowImg)
	local size = 1
	for i = 1, pointLightCount do
		local light = lights[i]
		local param = light.param
		if param.gib == nil and param.type == "Cannon" then
			size = param.glowradius * 0.44
			gl.PushMatrix()
			local colorMultiplier = 1 / math_max(param.r, param.g, param.b)
			gl.Color(param.r * colorMultiplier, param.g * colorMultiplier, param.b * colorMultiplier, 0.015 + (size / 4000))
			gl.Translate(light.px, light.py, light.pz)
			gl.Billboard(true)
			gl.TexRect(-(size / 2), -(size / 2), (size / 2), (size / 2))
			gl.PopMatrix()
		end
	end
	gl.Billboard(false)
	gl.Texture(false)
	gl.DepthMask(true)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	]]--
--end

function widget:DrawWorld() -- We are drawing in world space, probably a bad idea but hey
	--glBlending(GL.DST_COLOR, GL.ONE) -- Set add blending mode
	deferredLightShader = checkShaderUpdates(vsSrcPath, fsSrcPath, nil, "Deferred Lights GL4") or deferredLightShader
	if pointLightVBO.usedElements > 0 or beamLightVBO.usedElements > 0 or coneLightVBO.usedElements > 0 then 
	
	
		local alt, ctrl, meta, shft = Spring.GetModKeyState()
		
		if ctrl then
			glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		else
			glBlending(GL.SRC_ALPHA, GL.ONE)
		end
		
		gl.Culling(GL.BACK)
		gl.DepthTest(false)
		gl.DepthMask(false)
		glTexture(0, "$map_gbuffer_zvaltex")
		glTexture(1, "$model_gbuffer_zvaltex")
		glTexture(2, "$map_gbuffer_normtex")
		glTexture(3, "$model_gbuffer_normtex")
		glTexture(4, "$map_gbuffer_spectex")
		glTexture(5, "$model_gbuffer_spectex")
		
		deferredLightShader:Activate()
		
		if pointLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 0)
			pointLightVBO.VAO:DrawElements(GL.TRIANGLES, nil, 0, pointLightVBO.usedElements, 0)
		end
		if beamLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 1)
			beamLightVBO.VAO:DrawArrays(GL.TRIANGLES, nil, 0, beamLightVBO.usedElements, 0)
		end
		if coneLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 2)
			coneLightVBO.VAO:DrawArrays(GL.TRIANGLES, nil, 0, coneLightVBO.usedElements, 0)
		end
		deferredLightShader:Deactivate()
		
		
		for i = 0, 5 do glTexture(i, false) end 
		gl.Culling(GL.BACK)
		gl.DepthTest(true)
		gl.DepthMask(true)
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
end
