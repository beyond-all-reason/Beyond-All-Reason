function widget:GetInfo()
	return {
		name      = "Sensor Ranges Sonar",
		desc      = "Shows ranges of all ally sonar. (GL4)",
		author    = "Kev, Beherith GL4",
		date      = "2021.06.20",
		license   = "Lua: GPLv2, GLSL: (c) Beherith (mysterme@gmail.com)",
		layer     = 0,
		enabled   = true
	}
end

-------   Configurables: -------------------
local rangeLineWidth = 3.5 -- (note: will end up larger for larger vertical screen resolution size)
local minSonarDistance = 250

local gaiaTeamID = Spring.GetGaiaTeamID()
local rangeColor = { 0.5, 0.7, 0.9, 0.17 } -- default range color
local usestipple = 1 -- 0 or 1resolution size)
local opacity = 0.17


local circleSegments = 64
------- GL4 NOTES -----
--only update every 15th frame, and interpolate pos in shader!
--Each instance has:
	-- startposrad
	-- endposrad
	-- color
-- TODO: draw ally ranges in diff color!

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local circleShader = nil
local circleInstanceVBO = nil


local vsSrc = [[
#version 420
#line 10000

//__DEFINES__

layout (location = 0) in vec4 circlepointposition;
layout (location = 1) in vec4 startposrad;
layout (location = 2) in vec4 endposrad;
layout (location = 3) in vec4 color;
uniform float circleopacity;

uniform sampler2D heightmapTex;

out DataVS {
	vec4 worldPos; // pos and radius
	vec4 blendedcolor;
	float worldscale_circumference;
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000

float heightAtWorldPos(vec2 w){
	vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy;
	return textureLod(heightmapTex, uvhm, 0.0).x;
}

void main() {
	// blend start to end on mod gf%15
	float timemix = mod(timeInfo.x,15)*0.06666;
	vec4 circleWorldPos = mix(startposrad, endposrad, timemix);
	circleWorldPos.xz = circlepointposition.xy * circleWorldPos.w +  circleWorldPos.xz;

	// get heightmap

	float worldheight = heightAtWorldPos(circleWorldPos.xz);
	circleWorldPos.y = 8.0; //max(-64,heightAtWorldPos(circleWorldPos.xz))+32.0; // always display on water surface


	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(circleWorldPos.xz,mapSize.xy - circleWorldPos.xz);
	float inboundsness = min(mymin.x, mymin.y);

	// dump to FS
	worldscale_circumference = startposrad.w * circlepointposition.z * 5.2345;
	worldPos = circleWorldPos;
	blendedcolor = color;
	blendedcolor.a = 1.0; // opacity override!
	blendedcolor.a *= 1.0 - clamp(inboundsness*(-0.03),0.0,1.0);
	if (worldheight > -5) blendedcolor.a = 0; // No display outside of water
	gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);
}
]]

local fsSrc =  [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require


#line 20000

uniform float circleopacity;

uniform sampler2D heightmapTex;

//__ENGINEUNIFORMBUFFERDEFS__

//__DEFINES__
in DataVS {
	vec4 worldPos; // w = range
	vec4 blendedcolor;
	float worldscale_circumference;
};

out vec4 fragColor;

void main() {
	fragColor.rgba = blendedcolor.rgba;
	fragColor.a *= circleopacity;
	#if USE_STIPPLE > 0
		fragColor.a *= 2.0 * sin(worldscale_circumference + timeInfo.x*0.2); // PERFECT STIPPLING!
	#endif
}
]]


local function goodbye(reason)
  Spring.Echo("DefenseRange GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

local function initgl4()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	circleShader =  LuaShader(
    {
      vertex = vsSrc:gsub("//__DEFINES__", "#define MYGRAVITY "..tostring(Game.gravity+0.1)),
	  fragment = fsSrc:gsub("//__DEFINES__", "#define USE_STIPPLE ".. tostring(usestipple) ),
      --geometry = gsSrc, no geom shader for now
      uniformInt = {
        heightmapTex = 0,
        },
      uniformFloat = {
        circleopacity = {1},
      },
    },
    "sonarrange shader GL4"
  )
  shaderCompiled = circleShader:Initialize()
  if not shaderCompiled then goodbye("Failed to compile sonarrange shader GL4 ") end
  local circleVBO,numVertices = makeCircleVBO(circleSegments)
  local circleInstanceVBOLayout = {
		  {id = 1, name = 'startposrad', size = 4}, -- the start pos + radius
		  {id = 2, name = 'endposrad', size = 4}, --  end pos + radius
		  {id = 3, name = 'color', size = 4}, --- color
		}
  circleInstanceVBO = makeInstanceVBOTable(circleInstanceVBOLayout,32, "sonarrangeVBO")
  circleInstanceVBO.numVertices = numVertices
  circleInstanceVBO.vertexVBO = circleVBO
  circleInstanceVBO.VAO = makeVAOandAttach(circleInstanceVBO.vertexVBO, circleInstanceVBO.instanceVBO)
end

-- Functions shortcuts
local spGetSpectatingState  = Spring.GetSpectatingState
local spGetUnitIsActive 	= Spring.GetUnitIsActive
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitPosition     = Spring.GetUnitPosition
local spIsGUIHidden 		= Spring.IsGUIHidden
local spIsUnitAllied		= Spring.IsUnitAllied
local glColor               = gl.Color
local glColorMask           = gl.ColorMask
local glDepthTest           = gl.DepthTest
local glLineWidth           = gl.LineWidth
local glStencilFunc         = gl.StencilFunc
local glStencilOp           = gl.StencilOp
local glStencilTest         = gl.StencilTest
local GL_ALWAYS             = GL.ALWAYS
local GL_EQUAL              = GL.EQUAL
local GL_LINE_LOOP          = GL.LINE_LOOP
local GL_KEEP               = 0x1E00 --GL.KEEP
local GL_REPLACE            = GL.REPLACE
local GL_TRIANGLE_FAN       = GL.TRIANGLE_FAN

-- Globals
local vsx, vsy = Spring.GetViewGeometry()
local lineScale = 1
local unitList = {} -- all ally units and their coordinates and radar ranges
local activeUnits = {}
local spec, fullview = spGetSpectatingState()
local allyTeamID = Spring.GetMyAllyTeamID()

local chobbyInterface

-- find all unit types with radar in the game and place ranges into unitRange table
local unitRange = {} -- table of unit types with their radar ranges
local isBuilding = {} -- unitDefID keys
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.sonarRadius and unitDef.sonarRadius > minSonarDistance then	-- save perf by excluding low radar range units
		if not unitRange[unitDefID] then unitRange[unitDefID] = {} end
		unitRange[unitDefID]['range'] = unitDef.sonarRadius

		if unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0 then
			isBuilding[unitDefID] = true
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:PlayerChanged()
	local prevFullview = fullview
	local myPrevAllyTeamID = allyTeamID
	spec, fullview = spGetSpectatingState()
	allyTeamID = Spring.GetMyAllyTeamID()
	if fullview ~= prevFullview or allyTeamID ~= myPrevAllyTeamID then
		widget:Initialize()
	end
end

function widget:ViewResize(newX,newY)
	vsx, vsy = Spring.GetViewGeometry()
	lineScale = vsy+500 / 1300
end

-- collect data about the unit and store it into unitList
local function processUnit(unitID, unitDefID, noUpload)
	if (not (spec and fullview )) and ( not spIsUnitAllied(unitID)) then return end -- display mode for specs

	local unitDefID = spGetUnitDefID(unitID)

    if not unitRange[unitDefID] then
        return
    end

	local teamID = Spring.GetUnitTeam(unitID)
	if teamID == gaiaTeamID then return end -- no gaia units

	local x, y, z = spGetUnitPosition(unitID)

    local range = unitRange[unitDefID]['range']
    local height = unitRange[unitDefID]['height']

    unitList[unitID] = unitDefID
	activeUnits[unitID] = false
	-- shall we jam it straight into the table?
	pushElementInstance(circleInstanceVBO,{x,y,z,0, x,y,z,0,rangeColor[1],rangeColor[2],rangeColor[3],rangeColor[4] },unitID, true, noUpload)

end


function widget:Initialize()
	WG.sonarrange = {}
	WG.sonarrange.getOpacity = function()
		return opacity
	end

	WG.sonarrange.setOpacity = function(value)
		opacity = value
	end

	initgl4()
	widget:ViewResize()
	unitList = {}
    local units = Spring.GetAllUnits()
	for i=1,#units do
		processUnit( units[i], spGetUnitDefID(units[i]), true)
    end
	uploadAllElements(circleInstanceVBO) --upload initialized at once
end

function widget:Shutdown()
	WG.sonarrange = nil
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  if 	unitList[unitID] then
    unitList[unitID] = nil
	activeUnits[unitID] = nil
    popElementInstance(circleInstanceVBO,unitID)
  end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	processUnit( unitID, unitDefID )
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	processUnit( unitID, unitDefID )
end

function widget:UnitFinished( unitID,  unitDefID,  unitTeam)
	processUnit( unitID, unitDefID )
end



function widget:GameFrame(n)
	if spec and fullview then return end
	if n % 15 == 0 then -- this 15 frames is important, as the vertex shader is interpolating at this rate too!
		local instanceData = circleInstanceVBO.instanceData -- ok this is so nasty that it makes all my prev pop-push work obsolete
		for unitID, unitDefID in pairs(unitList) do
			local instanceDataOffset = (circleInstanceVBO.instanceIDtoIndex[unitID] - 1)* circleInstanceVBO.instanceStep
			if not isBuilding[unitDefID] then
				local x, y, z = spGetUnitPosition(unitID)


				for i=instanceDataOffset + 1, instanceDataOffset+4 do
					instanceData[i] = instanceData[i+4]
				end
				instanceData[instanceDataOffset+5] = x
				instanceData[instanceDataOffset+6] = y
				instanceData[instanceDataOffset+7] = z

			end


			local range = unitRange[unitDefID]['range']
			local active = spGetUnitIsActive(unitID)
			if active then
				instanceData[instanceDataOffset+8] = range
			else
				instanceData[instanceDataOffset+8] = 0
			end
			if activeUnits[unitID] then
				instanceData[instanceDataOffset+4] = range
			else
				instanceData[instanceDataOffset+4] = 0
			end
			activeUnits[unitID] = active


			--pushElementInstance(circleInstanceVBO,instanceData,unitID, true, true) -- overwrite data and dont upload!, but i am scum and am directly modifying the table
		end
		uploadAllElements(circleInstanceVBO)
	end
end

function widget:DrawWorld()
    if chobbyInterface then return end
    if spec and fullview then return end
    if spIsGUIHidden() or (WG['topbar'] and WG['topbar'].showingQuit()) then return end

	if circleInstanceVBO.usedElements == 0 then return end


	if opacity < 0.01 then return end
	glColorMask(false, false, false, false)
	glStencilTest(true)
	glDepthTest(false)

	gl.Texture(0, "$heightmap")
	circleShader:Activate()
	circleShader:SetUniform("circleopacity", opacity)

	-- Draw outer circles into stencil buffer
		glStencilFunc(GL_ALWAYS, 1, 1) -- Always Passes, 1 Bit Plane, 1 As Mask
		glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon
		glLineWidth(rangeLineWidth + 1.0)
		circleInstanceVBO.VAO:DrawArrays(GL_LINE_LOOP,circleInstanceVBO.numVertices,0,circleInstanceVBO.usedElements,0)

	-- Draw inverse inner circles into stencil buffer
		glStencilFunc(GL_ALWAYS, 0, 0) -- Always Passes, 0 Bit Plane, 0 As Mask
		glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 0 Where Draw Any Polygon
		circleInstanceVBO.VAO:DrawArrays(GL_TRIANGLE_FAN,circleInstanceVBO.numVertices,0,circleInstanceVBO.usedElements,0)


	glColorMask(true, true, true, true)

	glDepthTest(true)
	glStencilFunc(GL_EQUAL, 1, 1)
	glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)

	-- Render outer circles using resulting stencil
		glColor( rangeColor[1], rangeColor[2], rangeColor[3], rangeColor[4])
		glLineWidth(rangeLineWidth * lineScale)
		circleInstanceVBO.VAO:DrawArrays(GL_LINE_LOOP,circleInstanceVBO.numVertices,0,circleInstanceVBO.usedElements,0)

	circleShader:Deactivate()
	gl.Texture(0, false)

	glStencilTest(false)

	glDepthTest(true)
	glColor( 1.0, 1.0, 1.0, 1.0 ) --reset like a nice boi
	glLineWidth( 1.0 )

	gl.Clear( GL.STENCIL_BUFFER_BIT)
end

function widget:GetConfigData(data)
	return {
		opacity = opacity,
	}
end

function widget:SetConfigData(data)
	if data.opacity ~= nil then
		opacity = data.opacity
	end
end
