--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "Deferred rendering GL4",
		version = 3,
		desc = "Collects and renders cone, point and beam lights",
		author = "Beherith",
		date = "2022.06.10",
		license = "Lua code is GPL V2, GLSL is (c) Beherith",
		layer = -99999990,
		enabled = false
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
-- A spot light is a sphere?
-- A cone light is a cone
-- A beam light is a box
-- all prims should be back-face only rendered!


-- Separate VBO's for spheres, cones, beams
-- no geometry shader for now, its kinda pointless, might change my mind later

-- Sources of light
-- Projectiles
	-- beamlasers
		-- might get away with not updating their pos each frame?
		-- probably not, due to continuous lasers like beamer turret (though that one may be spawned every frame...)
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
	
-- Notes on self-point lights:
	-- these are probably best billboarded, then depth tested!

-- would be nice to have:
	-- full map-level dense atmosphere
	-- explosions should kick up dust
	-- simulate wind and other movements
	-- at a rez of 32 elmos, dsd would need:
	-- 256*256*16 voxels (1 million?) yeesh

-- preliminary perf:
	-- yeah raymarch is expensive!

local shaderConfig = {
	MIERAYLEIGHRATIO = 0.1,
	RAYMARCHSTEPS = 4, -- must be at least one
	USE3DNOISE = 1,
}

local noisetex3dcube =  "LuaUI/images/noise64_cube_3.dds"

local coneLightVBO = {}
local beamLightVBO = {}
local pointLightVBO = {}

local unitConeLightVBO = {}
local unitPointLightVBO = {}
local unitBeamLightVBO = {}

local featureConeLightVBO = {}
local featurePointLightVBO = {}

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local deferredLightShader = nil

local function goodbye(reason) 
	Spring.Echo('Exiting', reason)
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
					mapDiffuse = 6,
					modelDiffuse = 7,
					noise3DCube = 8,
					},
				uniformFloat = {
					pointbeamcone = 0,
					fadeDistance = 3000,
					attachedtounitID = 0,
					nightFactor = 1.0,
					
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

local function createLightInstanceVBO(vboLayout, vertexVBO, numVertices, indexVBO, VBOname, unitIDattribID)
	local targetLightVBO = makeInstanceVBOTable( vboLayout, 64, VBOname, unitIDattribID)
	if vertexVBO == nil or targetLightVBO == nil then goodbye("Failed to make "..VBOname) end 
	targetLightVBO.vertexVBO = vertexVBO
	targetLightVBO.numVertices = numVertices
	targetLightVBO.indexVBO = indexVBO
	targetLightVBO.VAO = makeVAOandAttach(targetLightVBO.vertexVBO, targetLightVBO.instanceVBO, targetLightVBO.indexVBO)
	return targetLightVBO
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
			{id = 6, name = 'modelfactor_specular_scattering_lensflare', size = 4},
			{id = 7, name = 'otherparams', size = 4},
			{id = 8, name = 'pieceIndex', size = 1, type = GL.UNSIGNED_INT},
			{id = 9, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
	}

	local pointVBO, numPointVertices, pointIndexVBO, numIndices = makeSphereVBO(8, 8, 1) 
	pointLightVBO 		= createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Point Light VBO")
	unitPointLightVBO 	= createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Unit Point Light VBO", 9)
	featurePointLightVBO = createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Feature Point Light VBO", 9)
	
	local coneVBO, numConeVertices = makeConeVBO(16, 1, 1)
	coneLightVBO 		= createLightInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Cone Light VBO")
	unitConeLightVBO 	= createLightInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Unit Cone Light VBO", 9)
	featureConeLightVBO = createLightInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Feature Cone Light VBO", 9)
	
	local beamVBO, numBeamVertices = makeBoxVBO(-1, -1, -1, 1, 1, 1)
	beamLightVBO 		= createLightInstanceVBO(vboLayout, beamVBO, numBeamVertices, nil, "Beam Light VBO")
	unitBeamLightVBO 	= createLightInstanceVBO(vboLayout, beamVBO, numBeamVertices, nil, "Unit Beam Light VBO", 9)
	
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
for i = 1, 25 do lightCacheTable[i] = 0 end 
lightCacheTable[13] = 1 --modelfactor_specular_scattering_lensflare
lightCacheTable[14] = 1
lightCacheTable[15] = 1
lightCacheTable[16] = 1


local function AddPointLight(px,py,pz,radius)
	lightCacheTable[1] = px
	lightCacheTable[2] = py
	lightCacheTable[3] = pz
	lightCacheTable[4] = radius
	return pushElementInstance(pointLightVBO, lightCacheTable)
end

local function AddUnitPointLight(unitID, pieceIndex, instanceID, px,py,pz,radius, r,g,b,a)
	lightCacheTable[1] = px
	lightCacheTable[2] = py
	lightCacheTable[3] = pz
	lightCacheTable[4] = radius
	lightCacheTable[9] = r
	lightCacheTable[10] = g
	lightCacheTable[11] = b
	lightCacheTable[12] = a
	
	
	lightCacheTable[21] = pieceIndex
	instanceID =  pushElementInstance(unitPointLightVBO, lightCacheTable, instanceID, true, nil, unitID)
	lightCacheTable[21] = 0
	return instanceID
end

local function AddUnitPointLightTable(unitID, instanceID, lightParamTable)
	Spring.Echo("AddUnitPointLightTable",unitID, instanceID, lightParamTable)
	return pushElementInstance(unitPointLightVBO, lightParamTable, instanceID, true, nil, unitID)
end

local function AddFeaturePointLight(featureID, px,py,pz,radius)
	lightCacheTable[1] = px
	lightCacheTable[2] = py
	lightCacheTable[3] = pz
	lightCacheTable[4] = radius
	local instanceID =  pushElementInstance(featurePointLightVBO, lightCacheTable, nil, true, nil, featureID)
	return instanceID
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

local function AddUnitBeamLight(unitID, pieceIndex, instanceID, px,py,pz,radius, sx, sy, sz, r,g,b,a)
	lightCacheTable[1] = px
	lightCacheTable[2] = py
	lightCacheTable[3] = pz
	lightCacheTable[4] = radius
	lightCacheTable[5] = sx
	lightCacheTable[6] = sy
	lightCacheTable[7] = sz
	lightCacheTable[8] = radius
	lightCacheTable[9] = r
	lightCacheTable[10] = g
	lightCacheTable[11] = b
	lightCacheTable[12] = a
	lightCacheTable[21] = pieceIndex
	instanceID = pushElementInstance(unitBeamLightVBO, lightCacheTable, instanceID, true, nil, unitID)
	lightCacheTable[21] = 0
	return instanceID
end

local function AddUnitBeamLightTable(unitID, instanceID, lightParamTable)
	Spring.Echo("AddUnitBeamLightTable",unitID, instanceID, lightParamTable)
	return pushElementInstance(unitBeamLightVBO, lightParamTable, instanceID, true, nil, unitID)
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

local function AddUnitConeLight(unitID, pieceIndex, instanceID, px,py,pz,height, dx, dy, dz, angle, r,g,b,a)
	lightCacheTable[1] = px
	lightCacheTable[2] = py
	lightCacheTable[3] = pz
	lightCacheTable[4] = height
	lightCacheTable[5] = dx
	lightCacheTable[6] = dy
	lightCacheTable[7] = dz
	lightCacheTable[8] = angle
	lightCacheTable[9] = r
	lightCacheTable[10] = g
	lightCacheTable[11] = b
	lightCacheTable[12] = a
	lightCacheTable[21] = pieceIndex
	instanceID =  pushElementInstance(unitConeLightVBO, lightCacheTable, instanceID, true, nil, unitID)
	lightCacheTable[21] = 0
	return instanceID
end

local function AddUnitConeLightTable(unitID, instanceID, lightParamTable)
	Spring.Echo("AddUnitConeLightTable",unitID, instanceID, lightParamTable)
	return pushElementInstance(unitConeLightVBO, lightParamTable, instanceID, true, nil, unitID)
end

local function AddFeatureConeLight(featureID, px,py,pz,height, dx, dy, dz, angle)
	lightCacheTable[1] = px
	lightCacheTable[2] = py
	lightCacheTable[3] = pz
	lightCacheTable[4] = height
	lightCacheTable[5] = dx
	lightCacheTable[6] = dy
	lightCacheTable[7] = dz
	lightCacheTable[8] = angle
	return pushElementInstance(unitConeLightVBO, lightCacheTable, nil, true, nil, featureID)
end

-- Hmm, how are we going to handle having multiple lights per unitDEF?
-- TODO: only one 'type' of light can be specified for each unitDef
-- This reeks of the same issues present in AirJets GL4
local unitDefLights = {
	[UnitDefNames['armpw'].id] = {
		initComplete = false, -- this is needed maybe?
		headlightpw = { -- this is the lightname
			lighttype = 'cone',
			px = 0,
			py = 0,
			pz = 0,
			height = 150,
			dx = 0, 
			dy = 0, 
			dz = -1, 
			angle = 1,
			pieceName = 'justattachtobase', -- invalid ones will attack to the worldpos of the unit
			lightParamTable = {0,23,7,150, --pos + radius
								0,-0.07,1, 0.4, -- dir + angle
								1,1,0.9,0.7, -- RGBA
								0.1,0.1,2,0.6, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		-- dicklight = {
		-- 	lighttype = 'point',
		-- 	px = 0,
		-- 	py = 0,
		-- 	pz = 0,
		-- 	height = 150,
		-- 	dx = 0, 
		-- 	dy = 0, 
		-- 	dz = -1, 
		-- 	angle = 1,
		-- 	pieceName = 'pelvis',
		-- 	lightParamTable = {50,10,4,100, --pos + radius
		-- 						0,0,0, 0, -- unused
		-- 						1,1,1,0, -- RGBA
		-- 						1,1,1,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- otherparams
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
		-- gunlight = {
		-- 	lighttype = 'beam',
		-- 	px = 0,
		-- 	py = 0,
		-- 	pz = 0,
		-- 	height = 150,
		-- 	dx = 0, 
		-- 	dy = 0, 
		-- 	dz = -1, 
		-- 	angle = 1,
		-- 	pieceName = 'lthigh',
		-- 	lightParamTable = {0,0,0,150, --pos + radius
		-- 						150,150,150, 0, -- endpos
		-- 						1,1,1,1, -- RGBA
		-- 						1,1,1,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- otherparams
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
	},
	[UnitDefNames['armrad'].id] = {
		initComplete = false, -- this is needed maybe?	
		-- upright = {
		-- 	lighttype = 'cone',
		-- 	px = 0,
		-- 	py = 0,
		-- 	pz = 0,
		-- 	height = 150,
		-- 	dx = 0, 
		-- 	dy = 0, 
		-- 	dz = -1, 
		-- 	angle = 0,
		-- 	pieceName = 'turret',
		-- 	lightParamTable = {0,72,0,200, --pos + radius
		-- 						0.001,1,0.001, 0.1, -- dir + angle
		-- 						0.5,3,0.5,1, -- RGBA
		-- 						1,1,1,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- otherparams
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
		-- searchlight = {
		-- 	lighttype = 'cone',
		-- 	px = 0,
		-- 	py = 0,
		-- 	pz = 0,
		-- 	height = 0,
		-- 	dx = 0, 
		-- 	dy = 0, 
		-- 	dz = -1, 
		-- 	angle = 1,
		-- 	pieceName = 'dish',
		-- 	lightParamTable = {0,0,0,70, --pos + radius
		-- 						0,0,-1, 0.2, -- dir + angle
		-- 						0.5,3,0.5,1, -- RGBA
		-- 						0.5,1,2,0, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- otherparams
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
		greenblob = {
				lighttype = 'point',
				px = 0,
				py = 0,
				pz = 0,
				height = 150,
				dx = 0, 
				dy = 0, 
				dz = -1, 
				angle = 1,
				pieceName = 'turret',
				lightParamTable = {0,72,0,20, --pos + radius
								0,0,0,0, -- unused
								0,1,0,0.9, -- RGBA
								0.8,0.9,1.5,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},

	[UnitDefNames['armllt'].id] = {
		initComplete = false, -- this is needed maybe?
		searchlightllt = {
			lighttype = 'cone',
			px = 0,
			py = 0,
			pz = 0,
			height = 150,
			dx = 0, 
			dy = 0, 
			dz = -1, 
			angle = 1,
			pieceName = 'sleeve',
			lightParamTable = {0,5,5.8,450, --pos + radius
								0,0,1,0.25, -- dir + angle
								1,1,1,1, -- RGBA
								0.5,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armrl'].id] = {
		initComplete = false, -- this is needed maybe?
		searchlightrl = {
			lighttype = 'cone',
			px = 0,
			py = 0,
			pz = 0,
			height = 150,
			dx = 0, 
			dy = 0, 
			dz = -1, 
			angle = 1,
			pieceName = 'sleeve',
			lightParamTable = {0,0,7,450, --pos + radius
								0,0,1,0.20, -- dir + angle
								1,1,1,1, -- RGBA
								1,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armjamt'].id] = {
		initComplete = false, -- this is needed maybe?
		-- searchlight = {
		-- 	lighttype = 'cone',
		-- 	px = 0,
		-- 	py = 0,
		-- 	pz = 0,
		-- 	height = 150,
		-- 	dx = 0, 
		-- 	dy = 0, 
		-- 	dz = -1, 
		-- 	angle = 1,
		-- 	pieceName = 'turret',
		-- 	lightParamTable = {0,0,3,65, --pos + radius
		-- 						0,-0.4,1, 1, -- dir + angle
		-- 						1.2,0.1,0.1,1.2, -- RGBA
		-- 						1,1,1,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- otherparams
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
		cloaklightred = {
				lighttype = 'point',
				px = 0,
				py = 0,
				pz = 0,
				height = 150,
				dx = 0, 
				dy = 0, 
				dz = -1, 
				angle = 1,
				pieceName = 'turret',
				lightParamTable = {0,30,0,35, --pos + radius
								0,0,1,0, -- unused
								1,0,0,0.5, -- RGBA
								0.5,0.5,1.5,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armack'].id] = {
		initComplete = false, -- this is needed maybe?
		beacon1 = { -- this is the lightname
			lighttype = 'cone',
			px = 0,
			py = 0,
			pz = 0,
			height = 150,
			dx = 0, 
			dy = 0, 
			dz = -1, 
			angle = 1,
			pieceName = 'beacon1',
			lightParamTable = {0,0,0,30, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,1.0,0.1,2, -- RGBA
								1,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		beacon2 = {
			lighttype = 'cone',
			px = 0,
			py = 0,
			pz = 0,
			height = 150,
			dx = 0, 
			dy = 0, 
			dz = -1, 
			angle = 1,
			pieceName = 'beacon2',
			lightParamTable = {0,0,0,30, --pos + radius
								-1,0,0, 0.99, -- dir + angle
								1.3,1.0,0.1,2, -- RGBA
								1,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armstump'].id] = {
		initComplete = false, -- this is needed maybe?
		searchlightstump = {
			lighttype = 'cone',
			px = 0,
			py = 0,
			pz = 0,
			height = 250,
			dx = 0, 
			dy = 0, 
			dz = -1, 
			angle = 1,
			pieceName = 'base',
			lightParamTable = {0,0,10,100, --pos + radius
								0,-0.08,1, 0.26, -- dir + angle
								1,1,1,1.2, -- RGBA
								1,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armbanth'].id] = {
		initComplete = false, -- this is needed maybe?
		searchlightbanth = {
			lighttype = 'cone',
			px = 0,
			py = 0,
			pz = 0,
			height = 250,
			dx = 0, 
			dy = 0, 
			dz = -1, 
			angle = 1,
			pieceName = 'turret',
			lightParamTable = {0,2,18,520, --pos + radius
								0,-0.12,1, 0.26, -- dir + angle
								1,1,1,1, -- RGBA
								0.1,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},	
	[UnitDefNames['armcom'].id] = {
		initComplete = false, -- this is needed maybe?
		headlightarmcom = {
			lighttype = 'cone',
			px = 0,
			py = 0,
			pz = 0,
			height = 250,
			dx = 0, 
			dy = 0, 
			dz = -1, 
			angle = 1,
			pieceName = 'head',
			lightParamTable = {0,0,10,420, --pos + radius
								0,-0.25,1, 0.26, -- dir + angle
								-1,1,1,1, -- RGBA
								1,2,3,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		-- lightsaber = {
		-- 	lighttype = 'beam',
		-- 	px = 0,
		-- 	py = 0,
		-- 	pz = 0,
		-- 	height = 250,
		-- 	dx = 0, 
		-- 	dy = 0, 
		-- 	dz = -1, 
		-- 	angle = 1,
		-- 	pieceName = 'dish',
		-- 	lightParamTable = {0,0,4,80, --pos + radius
		-- 						0,0, 300 , 40, -- pos2
		-- 						1,0,0,1, -- RGBA
		-- 						1,1,0.3,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- otherparams
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
	},
	[UnitDefNames['armcv'].id] = {
		initComplete = false, -- this is needed maybe?
		nanolightarmcv = {
			lighttype = 'cone',
			pieceName = 'nano1',
			lightParamTable = {3,0,-4,120, --pos + radius
								0,0,1, 0.3, -- pos2
								-1,0,0,1, -- RGBA
								0,1,3,0, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armca'].id] = {
		initComplete = false, -- this is needed maybe?
		nanolightarmca = {
			lighttype = 'cone',
			pieceName = 'nano',
			lightParamTable = {0,0,0,120, --pos + radius
								0,0,-1, 0.3, -- pos2
								-1,0,0,1, -- RGBA
								0,1,3,0, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armamd'].id] = {
		initComplete = false, -- this is needed maybe?
		-- readylight = {
		-- 	lighttype = 'beam',
		-- 	px = 0,
		-- 	py = 0,
		-- 	pz = 0,
		-- 	height = 250,
		-- 	dx = 0, 
		-- 	dy = 0, 
		-- 	dz = -1, 
		-- 	angle = 1,
		-- 	pieceName = 'antenna',
		-- 	lightParamTable = {0,0,4,25, --pos + radius
		-- 						0,0, -1, 0, -- pos2
		-- 						0,1,0,4, -- RGBA
		-- 						1,1,0.3,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- otherparams
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
		readylightamd = {
				lighttype = 'point',
				px = 0,
				py = 0,
				pz = 0,
				height = 150,
				dx = 0, 
				dy = 0, 
				dz = -1, 
				angle = 1,
				pieceName = 'antenna',
				lightParamTable = {0,1,0,20, --pos + radius
								0,0,0,0, -- unused
								0,1,0,1, -- RGBA
								1,1,1,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armaap'].id] = {
		initComplete = false, -- this is needed maybe?
		blinkaap = {
				lighttype = 'point',
				px = 0,
				py = 0,
				pz = 0,
				height = 150,
				dx = 0, 
				dy = 0, 
				dz = -1, 
				angle = 1,
				pieceName = 'base',
				lightParamTable = {-86,91,3,35, --pos + radius
								0,0,0,0, -- unused
								1,1,1,0.75, -- RGBA
								1,1,1,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- otherparams
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
}

local function AddStaticLightsForUnit(unitID, unitDefID, noupload)
	if unitDefLights[unitDefID] then
		local unitDefLight = unitDefLights[unitDefID]
		if unitDefLight.initComplete == false then  -- late init
			local pieceMap = Spring.GetUnitPieceMap(unitID)
			for lightname, lightParams in pairs(unitDefLight) do
				if lightname ~= 'initComplete' then
					if pieceMap[lightParams.pieceName] then -- if its not a real piece, it will default to the model!
						lightParams.pieceIndex = pieceMap[lightParams.pieceName] 
						lightParams.lightParamTable[21] = lightParams.pieceIndex
					end
					Spring.Echo(lightname, lightParams.pieceName, pieceMap[lightParams.pieceName])
				end
			end
		end
		for lightname, lightParams in pairs(unitDefLight) do
			if lightname ~= 'initComplete' then
				if lightParams.lighttype == 'point' then
					AddUnitPointLightTable(unitID, tostring(unitID) ..  lightname, lightParams.lightParamTable) 
				end
				if lightParams.lighttype == 'cone' then 
					AddUnitConeLightTable(unitID, tostring(unitID) ..  lightname, lightParams.lightParamTable) 
				
				end
				if lightParams.lighttype == 'beam' then 
					AddUnitBeamLightTable(unitID, tostring(unitID) ..  lightname, lightParams.lightParamTable) 
				end
			end
		end
	end
end

local function RemoveStaticLightsFromUnit(unitID, unitDefID)
	if unitDefLights[unitDefID] then 
		local unitDefLight = unitDefLights[unitDefID]
		for lightname, lightParams in pairs(unitDefLight) do
			if lightname ~= 'initComplete' then
				if lightParams.lighttype == 'point' then
					popElementInstance(unitPointLightVBO, tostring(unitID) ..  lightname) 
				end
				if lightParams.lighttype == 'cone' then 
					popElementInstance(unitConeLightVBO, tostring(unitID) ..  lightname)
				end
				if lightParams.lighttype == 'beam' then 
					popElementInstance(unitBeamLightVBO, tostring(unitID) ..  lightname)
				end
			end
		end
	end
end


function AddRandomLight(which)
	local gf = Spring.GetGameFrame()
	local radius = math.random() * 150 + 50
	local posx = Game.mapSizeX * math.random() * 1.0
	local posz = Game.mapSizeZ * math.random() * 1.0
	local posy = Spring.GetGroundHeight(posx, posz) + math.random() * 0.5 * radius
	-- randomize color
	lightCacheTable[9] = math.random() + 0.1 --r
	lightCacheTable[10] = math.random() + 0.1 --g 
	lightCacheTable[11] = math.random() + 0.1 --b
	lightCacheTable[12] = math.random() * 1.0 + 0.5 -- intensity or alpha
	
	lightCacheTable[13] = 1 -- modelfactor
	lightCacheTable[14] = 1 -- specular
	lightCacheTable[15] = 1 -- rayleigh-mie
	lightCacheTable[16] = 1 -- lensflare
	
	
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

local mapinfo = nil
local nightFactor = 0.33
local adjustfornight = {'unitAmbientColor', 'unitDiffuseColor', 'unitSpecularColor','groundAmbientColor', 'groundDiffuseColor', 'groundSpecularColor' }

function widget:Initialize()
	
	if Spring.GetConfigString("AllowDeferredMapRendering") == '0' or Spring.GetConfigString("AllowDeferredModelRendering") == '0' then
		Spring.Echo('Deferred Rendering (gfx_deferred_rendering.lua) requires  AllowDeferredMapRendering and AllowDeferredModelRendering to be enabled in springsettings.cfg!')
		widgetHandler:RemoveWidget()
		return
	end
	
	if initGL4() == false then return end
	
	local success, mapinfo = pcall(VFS.Include,"mapinfo.lua") -- load mapinfo.lua confs
	
	if nightFactor ~= 1 then 
		--Spring.Debug.TableEcho(mapinfo)
		local nightLightingParams = {}
		for _,v in ipairs(adjustfornight) do 
			nightLightingParams[v] = mapinfo.lighting[string.lower(v)]
			if nightLightingParams[v] ~= nil then 
				for k2, v2 in pairs(nightLightingParams[v]) do
					--Spring.Echo(v,k2,v2)
					if tonumber(v2) then nightLightingParams[v][k2] = v2 * nightFactor end
				end
			else
				Spring.Echo("Deferred Lights GL4: Warning: This map does not specify ",v, "in mapinfo.lua!")
			end
		end
		Spring.SetSunLighting(nightLightingParams)
	end 
	
	math.randomseed(1)
	for i=1, 12 do AddRandomLight(	math.random()) end   
	
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
	
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	AddStaticLightsForUnit(unitID, unitDefID, false, "VisibleUnitAdded")
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	
	clearInstanceTable(unitPointLightVBO) -- clear all instances
	clearInstanceTable(unitBeamLightVBO) -- clear all instances
	clearInstanceTable(unitConeLightVBO) -- clear all instances
	
	for unitID, unitDefID in pairs(extVisibleUnits) do
		AddStaticLightsForUnit(unitID, unitDefID, true, "VisibleUnitsChanged") -- add them with noUpload = true
	end
	uploadAllElements(unitPointLightVBO) -- upload them all
	uploadAllElements(unitBeamLightVBO) -- upload them all
	uploadAllElements(unitConeLightVBO) -- upload them all
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	--if debugmode then Spring.Debug.TraceEcho("remove",unitID,reason) end
	RemoveStaticLightsFromUnit(unitID, Spring.GetUnitDefID(unitID))

end


function widget:Shutdown()
	-- TODO: delete the VBOs like a good boy
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
	if pointLightVBO.usedElements > 0 or 
		unitpointLightVBO.usedElements > 0 or 
		beamLightVBO.usedElements > 0 or 
		unitConeLightVBO.usedElements > 0 or
		coneLightVBO.usedElements > 0 then 
	
	
		local alt, ctrl, meta, shft = Spring.GetModKeyState()
				
		local screenCopyTex = nil
		if WG['screencopymanager'] and WG['screencopymanager'].GetScreenCopy then
			--screenCopyTex = WG['screencopymanager'].GetScreenCopy() -- TODO DOESNT WORK? CRASHES THE GL PIPE
		end
		if screenCopyTex == nil then
			--glTexture(6, false)
		else 
			--glTexture(6, screenCopyTex)
		end
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
		glTexture(6, "$map_gbuffer_difftex")
		glTexture(7, "$model_gbuffer_difftex")
		glTexture(8, noisetex3dcube)

		--Spring.Echo(screenCopyTex)
		
		deferredLightShader:Activate()
		deferredLightShader:SetUniformFloat("nightFactor", nightFactor)
		deferredLightShader:SetUniformFloat("attachedtounitID", 0)
		
		-- Fixed worldpos lights
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
		
		
		
		-- Unit Attached Lights
		deferredLightShader:SetUniformFloat("attachedtounitID", 1)		
		
		if unitPointLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 0)
			unitPointLightVBO.VAO:DrawElements(GL.TRIANGLES, nil, 0, pointLightVBO.usedElements, 0)
		end
		
		if unitBeamLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 1)
			unitBeamLightVBO.VAO:DrawArrays(GL.TRIANGLES, nil, 0, unitBeamLightVBO.usedElements, 0)
		end
		
		if unitConeLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 2)
			unitConeLightVBO.VAO:DrawArrays(GL.TRIANGLES, nil, 0, unitConeLightVBO.usedElements, 0)
		end
	
		
		deferredLightShader:Deactivate()
		
		for i = 0, 8 do glTexture(i, false) end 
		gl.Culling(GL.BACK)
		gl.DepthTest(true)
		gl.DepthMask(true)
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
end
