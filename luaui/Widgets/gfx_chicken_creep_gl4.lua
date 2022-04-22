function widget:GetInfo()
	return {
		name = "Chicken Creep GL4",
		desc = "Draws creep with global overlap texturing",
		author = "Beherith",
		date = "2022.04.20",
		license = "Lua code: GNU GPL, v2 or later, Shader GLSL code: (c) Beherith (mysterme@gmail.com)",
		layer = -1,
		enabled = false,
	}
end

-- TODO:
	-- stencil test for overlap like teamplatters does
	-- expanding - contracting radius param
	-- use a relatively highres image
	-- maybe even use parallax
	-- add a moving distortion texture
	-- also right to deferred buffers maybe?
	

-- Some configurables:

local texcolorheight = "LuaUI/images/alien_guts_colorheight.dds"
local texnormalspec =  "LuaUI/images/alien_guts_normalspec.dds"
local texdistortion =  "LuaUI/images/lavadistortion.png"
local resolution = 32

local creepVBO = nil
local creepShader = nil
local luaShaderDir = "LuaUI/Widgets/Include/"

local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local GL_BACK = GL.BACK
local GL_LEQUAL = GL.LEQUAL
local glStencilFunc         = gl.StencilFunc
local glStencilOp           = gl.StencilOp
local glStencilTest         = gl.StencilTest
local glStencilMask         = gl.StencilMask
local glDepthTest           = gl.DepthTest
local glClear               = gl.Clear
local GL_ALWAYS             = GL.ALWAYS
local GL_NOTEQUAL           = GL.NOTEQUAL
local GL_KEEP               = 0x1E00 --GL.KEEP
local GL_STENCIL_BUFFER_BIT = GL.STENCIL_BUFFER_BIT
local GL_REPLACE            = GL.REPLACE
local GL_POINTS				= GL.POINTS

local shaderConfig = {
	SPECULAREXPONENT = 64.0,  -- the specular exponent of the lava plane
	SPECULARSTRENGTH = 1.0, -- The peak brightness of specular highlights
	
	LOSDARKNESS = 0.5, -- how much to darken the out-of-los areas of the lava plane
	SHADOWSTRENGTH = 0.4, -- how much light a shadowed fragment can recieve
	CREEPTEXREZ = 0.003,
	JIGGLEAMPLITUDE = 0.2,
}

---- GL4 Backend Stuff----

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local vsSrc =  [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 5000

layout (location = 0) in vec4 xyworld_xyfract; // l w rot and maxalpha
layout (location = 1) in vec4 worldposradius; // xyz and radius
layout (location = 2) in vec4 lifeparams; // lifestart, growthrate, unused, unused;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

//uniform float fadeDistance;
uniform sampler2D heightmapTex;
uniform sampler2D mapnormalsTex;

out DataVS {
	vec4 v_worldPosRad;
	vec4 v_localxz;
	vec4 v_worldUV; 
	vec4 v_lifeparams;
	vec4 v_mapnormals;
	float v_trueradius;
};

float rand(vec2 co){ // a pretty crappy random function
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

#line 11000
void main()
{
	v_worldPosRad = worldposradius;
	v_lifeparams = lifeparams;
	v_localxz = xyworld_xyfract;
	// Transform the [-1, 1] rect into world space
	vec4 mapPos = vec4(worldposradius.xyz, 1.0); 
	mapPos.xz += xyworld_xyfract.xy *  worldposradius.w;
	
	// Sample the heightmap to get reasonable world depth
	vec2 uvhm = heighmapUVatWorldPos(mapPos.xz);
	mapPos.y = textureLod(heightmapTex, uvhm, 0.0).x + 2.0;
	
	// sample the map normals and pass it on for later use:
	v_mapnormals = textureLod(mapnormalsTex, uvhm, 0.0);
	
	v_worldUV =  mapPos.xyzw;
	
	float time = timeInfo.x + timeInfo.w;
	
	v_worldUV.x += JIGGLEAMPLITUDE * sin(time * 0.1 + 100*rand(v_worldUV.xy));
	v_worldUV.z += JIGGLEAMPLITUDE * sin(time * 0.1 + 100*rand(v_worldUV.zy));
	
	if (lifeparams.y > 0.0) {
		v_trueradius = clamp (lifeparams.y * (time - lifeparams.x), 0.0,  v_worldPosRad.w);
	}
	else{
		v_trueradius = clamp (v_worldPosRad.w + lifeparams.y * (time - lifeparams.x), 0.0, v_worldPosRad.w) ;
	}
	//mapPos.y += fract( 10 * (time - lifeparams.x) * 0.001) * 100;

	gl_Position = cameraViewProj * mapPos;
}
]]

local fsSrc =
[[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000
uniform float iconDistance;
in DataVS {
	vec4 v_worldPosRad;
	vec4 v_localxz;
	vec4 v_worldUV; 
	vec4 v_lifeparams;
	vec4 v_mapnormals;
	float v_trueradius;
};

uniform sampler2D heightmapTex;
uniform sampler2D mapnormalsTex;
uniform sampler2D infoTex;
uniform sampler2DShadow shadowTex;
uniform sampler2D colorheight;
uniform sampler2D normalspec;
uniform sampler2D distortion;

out vec4 fragColor;

vec4 shadowMapUVAtWorldPos(vec3 worldPos){
		vec4 shadowVertexPos = shadowView * vec4(worldPos,1.0);
		shadowVertexPos.xy += vec2(0.5);
		return shadowVertexPos;
		//return clamp(textureProj(shadowTex, shadowVertexPos), 0.0, 1.0);
}

// RNM func from: https://blog.selfshadow.com/publications/blending-in-detail/
vec3 ReOrientNormal(vec3 basenormal, vec3 detailnormal){
	vec3 t = basenormal.xyz * vec3( 2,  2, 2) + vec3(-1, -1,  0);
	vec3 u = detailnormal.xyz* vec3(-2, -2, 2) + vec3( 1,  1, -1);
	vec3 r = t*dot(t, u) - u*t.z;
	return normalize(r);
}


#line 31000
void main(void)
{
	if (any(lessThan(vec4(v_worldUV.xz, mapSize.xy - v_worldUV.xz) , vec4(0.0) ))) discard; // Discard out-of-map fragments
	float time = timeInfo.x+timeInfo.w;

	float internalradius = length (v_localxz.xy) ; //dot(v_localxz.xy, v_localxz.xy);
	float radialgrowth = v_trueradius/v_worldPosRad.w;
	// discard outside of current radius
	if (internalradius> radialgrowth) discard; // bail before any texture fetches
	vec4 texdistort = texture(distortion, v_worldUV.xz * CREEPTEXREZ * 1.0);
	float radialCreep = smoothstep(radialgrowth - 0.15, radialgrowth, internalradius + 0.1 * texdistort.x );
	if (radialCreep > 0.7) discard;

	vec4 texcolorheight= texture(colorheight, v_worldUV.xz * CREEPTEXREZ, -0.5);
	vec4 texnormalspec = texture(normalspec, v_worldUV.xz* CREEPTEXREZ, - 0.5);
	vec4 texdistort2 = texture(distortion, v_worldUV.xz * CREEPTEXREZ * 2.0 + vec2(sin(time * 0.0002))) * 0.5 + 0.5;
	
	vec3 fragNormal = (texnormalspec.xzy * 2.0 -1.0);
	
	vec4 camPos = cameraViewInv[3];
	vec3 worldtocam = camPos.xyz - v_worldUV.xyz;
	
	float shadow = clamp(textureProj(shadowTex, shadowMapUVAtWorldPos(v_worldUV.xyz)), SHADOWSTRENGTH, 1.0);
	
	vec2 losUV = clamp(v_worldUV.xz, vec2(0.0), mapSize.xy ) / mapSize.zw;
	float loslevel = dot(vec3(0.33), texture(infoTex, losUV).rgb) ; // lostex is PO2
	loslevel = clamp(loslevel * 4.0 - 1.0, LOSDARKNESS, 1.0);
	
	// this is the actually correct way of blending according to 
	// Whiteout blending https://blog.selfshadow.com/publications/blending-in-detail/
	fragNormal.xz += v_mapnormals.ra;
	vec3 normal = normalize(fragNormal.xyz);//  + texdistort2.xzy);
	//normal = vec3(0.0, 1.0, 0.0);
	
	// calculate direct lighting
	float lightamount = clamp(dot(sunDir.xyz, normal), 0.3, 1.0) * max(SHADOWSTRENGTH, shadow);
	
	// Specular Color
	vec3 reflvect = reflect(normalize(-1.0 * sunDir.xyz), normal);
	float specular = clamp(pow(clamp(dot(normalize(worldtocam), normalize(reflvect)), 0.0, 1.0), SPECULAREXPONENT), 0.0, SPECULARSTRENGTH);// * shadow;
	//float specular = clamp(dot(normalize(worldtocam), normalize(reflvect)), 0.0, 1.0);// * shadow;
	fragColor.rgb += fragColor.rgb * specular;
	
	vec3 outcolor = texcolorheight.rgb;
	
	outcolor = outcolor * (  loslevel * (lightamount ) * 0.5) + outcolor * specular * shadow;
	fragColor.rgba = vec4(outcolor, 1.0 );
	
	// do hermitian interpolation on 0.1 of this shit
	
	
	// darken outside

	fragColor.a = 1.0 - radialCreep*3;
	fragColor.rgb *= ((fragColor.a  -0.3)*2.0) ;
	
	

}
]]

local function goodbye(reason)
  Spring.Echo("Creep GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

local function initGL4(shaderConfig, DPATname)
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	creepShader =  LuaShader(
		{
		  vertex = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		  fragment = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		  uniformInt = {
			heightmapTex = 0,
			mapnormalsTex = 1, 
			infoTex = 2, 
			shadowTex = 3, 
			colorheight = 4,
			normalspec = 5,
			distortion = 6, 
			},
		uniformFloat = {
			--fadeDistance = 3000,
		  },
		},
		DPATname .. "Shader"
	  )
	local shaderCompiled = creepShader:Initialize()
	if not shaderCompiled then goodbye("Failed to compile ".. DPATname .." GL4 ") end

	creepVBO = makeInstanceVBOTable(
		{
			{id = 1, name = 'worldposradius', size = 4}, -- xpos, ypos, zpos, radius
			{id = 2, name = 'lifeparams', size = 4}, -- lifestart, lifeend, growthrate, unused
		},
		64, -- maxelements
		DPATname .. "VBO" -- name
	)
	if creepVBO == nil then goodbye("Failed to create creepVBO") end
	
	local planeVBO, numVertices = makePlaneVBO(1,1,resolution,resolution)
	local planeIndexVBO, numIndices =  makePlaneIndexVBO(resolution,resolution)
	
	creepVBO.vertexVBO = planeVBO
	creepVBO.indexVBO = planeIndexVBO
	
	creepVBO.VAO = makeVAOandAttach(
		creepVBO.vertexVBO, 
		creepVBO.instanceVBO, 
		creepVBO.indexVBO)
	
end

local creepIndex = 0
local creepTimes = {} -- maps instanceID to expected fadeout timeInfo
local creepRemoveQueue = {} -- maps gameframes to list of creeps that will be removed
local creeps = {} -- table of {posx = 123, posz = 123, radius = 123, spawnframe = 0, growthrate = -1.0} -- in elmos per sec
local creepBins = {} -- a table keyed with (posx / 1024) + 1024 + (posz/1024), values are tables of creepindexes that can overlap that bin

local sqrt = math.sqrt
local floor = math.floor
local max = math.max
local min = math.min
local spGetGroundHeight = Spring.GetGroundHeight 
local spGetGameFrame = Spring.GetGameFrame
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local boundary = 32 -- how many elmos closer to the center of the creep than the actual edge of the creep the unit must be to be considered on the creep

local function GetMapSquareKey(posx, posz)
	if posx < 0 or posz < 0 or posx > mapSizeX or posz > mapSizeZ then return nil end
	return (floor(posx*0.0009765625) * 1024 + floor(posz* 0.0009765625))
end

for x= 0, math.ceil(mapSizeX/1024) do 
	for z = 0, math.ceil(mapSizeZ/1024) do 
		creepBins[x*1024+z] = {}
	end
end

-- This checks wether the unit is under any creep 
-- 
local function IsPosInCreep(unitx,unity, unitz)
	-- out of bounds check, no creep outside of map bounds
	if unitx < 0 or unitz < 0 or unitx > mapSizeX or unitz > mapSizeZ then return nil end
	-- underwater creep doesnt count for hovers, ships
	if unity > -1 and spGroundHeight(unitx, unitz) < 0 then return nil end 
	
	-- Empty bins also return 
	local creepBinID = GetMapSquareKey(unitx, unitz)
	if creepBinID == nil or creepBins[creepBinID] == nil then return end 
	local gf = spGetGameFrame()
	
	for creepID, creep in pairs(creepBins[creepBinID]) do 
		local dx = (unitx - creep.posx)
		local dz = (unitz - creep.posz)
		local sqrdistance = (dx*dx + dz*dz)
		local creepradius = creep.radius
		if sqrdistance < (creepradius * creepradius) then 
			local currentcreepradius 
			local growthrate = creep.growthrate
			if growthrate > 0 then 
				currentcreepradius = min(creepradius,(creep.spawnframe-gf) * growthrate)
			else
				currentcreepradius = max(0,creepradius (creep.spawnframe-gf) * growthrate)
			end
			if currentcreepradius  - sqrt(sqrdistance) > boundary then 
				return creepID
			end
		end
	end
	return nil
end

local function UpdateBins(creepID, removeCreep)
	local creepTable = creeps[creepID]
	local posx = creepTable.posx
	local posz = creepTable.posz
	local radius = creepTable.radius
	
	if removeCreep then 
		creepTable = nil
		creeps[creepID] = nil
	end
	
	local binID = GetMapSquareKey(posx, posz)
	if binID then creepBins[binID][creepID] = creepTable end
	binID = GetMapSquareKey(posx + radius, posz + radius)
	if binID then creepBins[binID][creepID] = creepTable end
	binID = GetMapSquareKey(posx - radius, posz + radius)
	if binID then creepBins[binID][creepID] = creepTable end
	binID = GetMapSquareKey(posx + radius, posz - radius)
	if binID then creepBins[binID][creepID] = creepTable end
	binID = GetMapSquareKey(posx - radius, posz - radius)
	if binID then creepBins[binID][creepID] = creepTable end
end

-- growthrate is in elmos per frame, negative for shrinking creeps
local function AddCreep(posx, posy, posz, radius, growthrate, creepID)
	-- if creepID is supplied, we are updateing an existing creep instance!

	local gf = Spring.GetGameFrame()
	posy = posy or Spring.GetGroundHeight(posx, posz)
	
	-- thus we need to make a new creep, and register it in our creepBins
	if creepID == nil or creepVBO.instanceIDtoIndex[creepID] == nil then 
		creepIndex = creepIndex + 1
		creepID = creepIndex
		local newCreepTable = {posx = posx, posz = posz, radius = radius, spawnframe = gf, growthrate = growthrate, creepID = creepID}
		creeps[creepID] = newCreepTable
		UpdateBins(creepID)
	end
	--Spring.Echo(creepID, growthrate, radius, gf)
	pushElementInstance(
		creepVBO, -- push into this Instance VBO Table
			{posx, posy, posz, radius ,  -- 
			gf,  growthrate, 0, 0, -- alphastart_alphadecay_heatstart_heatdecay
			},
		creepID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		false) -- noupload, dont use unless you know what you want to batch push/pop
	
	
	if growthrate < 0 then 
		local deathtime = gf - radius / growthrate
		if creepRemoveQueue[deathtime] == nil then 
			creepRemoveQueue[deathtime] = {creepID}
		else
			creepRemoveQueue[deathtime][#creepRemoveQueue[deathtime] + 1 ] = creepID
		end
	end
	return creepID
end

local usestencil = false

function widget:DrawWorldPreUnit()
	if creepVBO.usedElements > 0 then
		local disticon = 27 * Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		--Spring.Echo(creepVBO.usedElements)
		--glCulling(GL_BACK)
		glCulling(false)
		glDepthTest(GL_LEQUAL)
		--glDepthTest(false)
		--gl.DepthMask(true)
		glTexture(0, '$heightmap')
		glTexture(1, '$normals')
		glTexture(2, "$info")-- Texture file
		glTexture(3, "$shadow")-- Texture file
		glTexture(4, texcolorheight)
		glTexture(5, texnormalspec)
		glTexture(6, texdistortion)-- Texture file
		creepShader:Activate()
		
		if usestencil then 
			gl.StencilTest(true) --https://learnopengl.com/Advanced-OpenGL/Stencil-testing
			gl.DepthTest(true)
			glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon		this to the shader
			glClear(GL_STENCIL_BUFFER_BIT) -- set stencil buffer to 0

			glStencilFunc(GL_NOTEQUAL, 1, 1) -- use NOTEQUAL instead of ALWAYS to ensure that overlapping transparent fragments dont get written multiple times
			glStencilMask(1)
		end
		
		--creepShader:SetUniform("fadeDistance",disticon * 1000)
		creepVBO.VAO:DrawElements(GL.TRIANGLES,nil,0,creepVBO.usedElements, 0)
		creepShader:Deactivate()
		if usestencil then 
			glStencilMask(1)
			glStencilFunc(GL_ALWAYS, 1, 1)
			gl.StencilTest(false) 
			glClear(GL_STENCIL_BUFFER_BIT) -- set stencil buffer to 0
			glStencilMask(0)
		end
		for i = 0, 6 do glTexture(i, false) end 
		glCulling(false)
		--glDepthTest(false)
	end
end

local function RemoveCreep(instanceID)
	if creeps[instanceID] then 
		UpdateBins(instanceID, true)
	end
	if creepVBO.instanceIDtoIndex[instanceID] then
		popElementInstance(creepVBO, instanceID)
	end
	creepTimes[instanceID] = nil
end

function widget:GameFrame(n)
	if creepRemoveQueue[n] then 
		for i=1, #creepRemoveQueue[n] do
			RemoveCreep(creepRemoveQueue[n][i])
		end
		creepRemoveQueue[n] = nil
	end
end

function widget:Initialize()
	--shaderConfig.MAXVERTICES = 4
	initGL4(shaderConfig, "creep")
	math.randomseed(1)
	if true then 
		for i= 1, 100 do 
			local posx  = Game.mapSizeX * math.random() * 1
			local posz  = Game.mapSizeZ * math.random() * 1
			local posy  = Spring.GetGroundHeight(posx, posz)
			local radius = math.random() * 256
			local lifetime = math.random() * 1025
			local deathtime = lifetime * 2
			local growthrate = math.random() * 3 -- in elmos per frame
			AddCreep(
					posx,
					posy,
					posz,
					radius,
					growthrate
					)
		end
	end
end

function widget:ShutDown()
end
