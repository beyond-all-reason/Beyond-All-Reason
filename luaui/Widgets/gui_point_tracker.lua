
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Point Tracker",
		desc = "Tracks recently placed map points.",
		author = "Beherith",
		date = "20211020",
		license = "GNU GPL, v2 or later",
		layer = 20, -- below most GUI elements, which generally go up to 10
		enabled = true
	}
end

local timeToLive = 330
local lineWidth = 1.0

local getMiniMapFlipped = VFS.Include("luaui/Include/minimap_utils.lua").getMiniMapFlipped

----------------------------------------------------------------
--speedups
----------------------------------------------------------------

local ArePlayersAllied = Spring.ArePlayersAllied
local GetPlayerInfo = Spring.GetPlayerInfo
local GetTeamColor = Spring.GetTeamColor
local GetSpectatingState = Spring.GetSpectatingState

local glLineWidth = gl.LineWidth
local GL_LINES = GL.LINES

----------------------------------------------------------------
--vars
----------------------------------------------------------------

local mapPoints = {}
local myPlayerID
local enabled = true
local instanceIDgen = 1
----------------------------------------------------------------
--local functions
----------------------------------------------------------------

local function GetPlayerColor(playerID)
	local _, _, isSpec, teamID = GetPlayerInfo(playerID, false)
	if isSpec then
		return GetTeamColor(Spring.GetGaiaTeamID())
	end
	if not teamID then
		return nil
	end
	return GetTeamColor(teamID)
end

-- GL4 Notes --
-- We arent going to use triangles to point, nor are we going to apply names to points
-- but what we are going to do, is clamp the center of the crosshair to screen space
-- and clamp the size of it to always be screensized
-- GL4 Stuff --

local mapMarkInstanceVBO = nil
local mapMarkShader= nil

local luaShaderDir = "LuaUI/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local function ClearPoints()
	mapPoints = {}
  clearInstanceTable(mapMarkInstanceVBO)
end

local shaderParams = {
    MAPMARKERSIZE = 0.035,
    LIFEFRAMES = timeToLive,
  }
local vsSrc =
[[
#version 420

layout (location = 0) in vec2 position;
layout (location = 1) in vec4 worldposradius;
layout (location = 2) in vec4 colorlife;

uniform float isMiniMap;
uniform float cameraFlipped;

out DataVS {
	vec4 blendedcolor;
};

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

#line 10000
void main()
{
  // project into view space
  vec4 worldPosInCamSpace;

  float viewratio = 1.0;
  if (isMiniMap > 0.5) {
    if (cameraFlipped > 0.5) {
      worldPosInCamSpace  = mmDrawViewProj * vec4(mapSize.x - worldposradius.x, worldposradius.y, mapSize.y - worldposradius.z, 1.0);
    } else {
      worldPosInCamSpace  = mmDrawViewProj * vec4(worldposradius.xyz, 1.0);
    }
    viewratio = mapSize.x / mapSize.y;
  } else {
    worldPosInCamSpace  = cameraViewProj * vec4(worldposradius.xyz, 1.0);
    viewratio = viewGeometry.x / viewGeometry.y;
  }
  // Note that the W component of the worldPosInCamSpace contains the normalization factor for camera into clip space

  //stretch to square:
  vec2 stretched;

  stretched = vec2(position.x , position.y * viewratio);

  // NDC into clip space
  vec3 clipspaceposition = worldPosInCamSpace.xyz / worldPosInCamSpace.w;

  // Ensure that it will always be in clip space
  clipspaceposition.xy = clamp(clipspaceposition.xy , -1.0, 1.0);

  // De normalize back into view space
  worldPosInCamSpace.xy = clipspaceposition.xy * worldPosInCamSpace.w;

  // And transform the points in clip space, but adding the verts for the points
  worldPosInCamSpace.xy += stretched.xy * MAPMARKERSIZE * worldPosInCamSpace.w;

  gl_Position = worldPosInCamSpace;

  //blendedcolor = vec4((gl_Position.rg/ gl_Position.w), 0.0, 1.0); //1.0 - (timeInfo.x - colorlife.w)/1000);
  blendedcolor = vec4(colorlife.rgb, 1.0 - ((timeInfo.x + timeInfo.w) - colorlife.w) / LIFEFRAMES);
}
]]

local fsSrc =
[[
#version 420
#line 20000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

//#extension GL_ARB_uniform_buffer_object : require
//#extension GL_ARB_shading_language_420pack: require

in DataVS {	vec4 blendedcolor; };

out vec4 fragColor;
void main(void) { fragColor = vec4(blendedcolor.rgba); }
]]

local function goodbye(reason)
  Spring.Echo("Point Tracker GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

function makeMarkerVBO()
	-- makes points with xyzw GL.LINES
	local markerVBO = gl.GetVBO(GL.ARRAY_BUFFER,false)
	if markerVBO == nil then return nil end

	local VBOLayout = {	 {id = 0, name = "position_xy", size = 2}, 	}

	local VBOData = { -- A CROSSHAIR, each set of 4 points in a line in XY space
    -1, -1,    -1, 1,
    -1,  1,     1, 1,
    1, 1,     1, -1,
    1, -1 , -1, -1 ,
    0, -0.75,    0, -1.25,
    0.75, 0,   1.25, 0,
    0, 0.75, 0, 1.25,
    -0.75, 0,   -1.25, 0,
    0, 0.01,  0, -0.01,
    0.01,0,  -0.01,0,
	}
	markerVBO:Define(	#VBOData/2,	VBOLayout)
	markerVBO:Upload(VBOData)
	return markerVBO, #VBOData/2
end

local function initGL4()

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	mapMarkShader =  LuaShader(
    {
      vertex = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderParams)),
      fragment = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderParams)),
      uniformInt = {
        },
	uniformFloat = {
        isMiniMap = 0,
        cameraFlipped = 0,
      },
    },
    "mapMarkShader GL4"
  )
  shaderCompiled = mapMarkShader
  mapMarkShader:Initialize()
  if not shaderCompiled then goodbye("Failed to compile mapMarkShader GL4 ") end
  local markerVBO,numVertices = makeMarkerVBO() --xyzw
  local mapMarkInstanceVBOLayout = {
		  {id = 1, name = 'posradius', size = 4}, -- posradius
		  {id = 2, name = 'colorlife', size = 4}, --  color + startgameframe
		}
  mapMarkInstanceVBO = makeInstanceVBOTable(mapMarkInstanceVBOLayout,32, "mapMarkInstanceVBO")
  mapMarkInstanceVBO.numVertices = numVertices
  mapMarkInstanceVBO.vertexVBO = markerVBO
  mapMarkInstanceVBO.VAO = makeVAOandAttach(mapMarkInstanceVBO.vertexVBO, mapMarkInstanceVBO.instanceVBO)
  mapMarkInstanceVBO.primitiveType = GL.LINES

  if false then -- testing
    pushElementInstance(mapMarkInstanceVBO,	{	200, 400, 200, 2000, 1, 0, 1, 1000000 },	nil, true)
  end
end

--------------------------------------------------------------------------------
-- Draw Iteration
--------------------------------------------------------------------------------
function DrawMapMarksWorld(isMiniMap)
  if mapMarkInstanceVBO.usedElements > 0 then
    --Spring.Echo("DrawMapMarksWorld",isMiniMap, Spring.GetGameFrame(), mapMarkInstanceVBO.usedElements)
	  glLineWidth(lineWidth)
		mapMarkShader:Activate()
		mapMarkShader:SetUniform("isMiniMap",isMiniMap)
		mapMarkShader:SetUniform("cameraFlipped", getMiniMapFlipped() and 1 or 0)

		drawInstanceVBO(mapMarkInstanceVBO)

		mapMarkShader:Deactivate()
	end
end
----------------------------------------------------------------
--callins
----------------------------------------------q------------------

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
  initGL4()
	myPlayerID = Spring.GetMyPlayerID()
	WG.PointTracker = {
		ClearPoints = ClearPoints,
	}
end

function widget:Shutdown()
	WG.PointTracker = nil
end



function widget:DrawScreen()
	if not enabled then
		return
	end
  DrawMapMarksWorld(0)
end

function widget:MapDrawCmd(playerID, cmdType, px, py, pz, label)

	local spectator, fullView = GetSpectatingState()
	local _, _, _, playerTeam = GetPlayerInfo(playerID, false)
	if label == "Start " .. playerTeam
		or cmdType ~= "point"
		or not (ArePlayersAllied(myPlayerID, playerID) or (spectator and fullView)) then
		return
	end
  instanceIDgen= instanceIDgen + 1
	local r, g, b = GetPlayerColor(playerID)
  local gf = Spring.GetGameFrame()

  pushElementInstance(
			mapMarkInstanceVBO,
			{
        px, py, pz, 1.0,
				r, g, b, gf
			},
      instanceIDgen, -- key, generate me one if nil
      true -- update exisiting
		)
  if mapPoints[gf] then
    mapPoints[gf][#mapPoints[gf] + 1]= instanceIDgen
  else
    mapPoints[gf] = {instanceIDgen}
  end
end

function widget:GameFrame(n)
  if mapPoints[n-timeToLive] then
    for i, instanceID in ipairs(mapPoints[n-timeToLive]) do
      popElementInstance(mapMarkInstanceVBO,instanceID)
    end
  end
end

function widget:DrawInMiniMap(sx, sy)
	if not enabled then return	end
	-- this fixes drawing on only 1 quadrant of minimap as pwe
  gl.ClipDistance ( 1, false)
  gl.ClipDistance ( 3, false)
  DrawMapMarksWorld(1)
end

function widget:ClearMapMarks()
	ClearPoints()
end
