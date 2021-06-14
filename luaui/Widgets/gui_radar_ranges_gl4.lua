function widget:GetInfo()
	return {
		name      = "Radar Range GL4",
		desc      = "Shows ranges of all ally radars.",
		author    = "Kev, Beherith GL4",
		date      = "2020.11.14",
		license   = "CC BY-NC",
		layer     = 0,
		enabled   = true
	}
end
 
local myrangeColor = { 0.0, 1.0, 1.0, 0.98 }
local rangeColor = { 0.0, 1.0, 0.0, 0.19 }
local allyrangeColor = { 0.25, 0.75, 1.0, 0.98 }
local rangeLineWidth = 2.0 -- (note: will end up larger for larger vertical screen resolution size)
local minRadarDistance = 500


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
local circleSegments = 128


local vsSrc = [[
#version 420
#line 10000

//__DEFINES__

layout (location = 0) in vec4 circlepointposition;
layout (location = 1) in vec4 startposrad;
layout (location = 2) in vec4 endposrad;
layout (location = 3) in vec4 color; 
uniform vec4 circleuniforms; // none yet

uniform sampler2D heightmapTex;

out DataVS {
	vec4 worldPos; // pos and radius
	vec4 blendedcolor;
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
	circleWorldPos.y = max(0.0,heightAtWorldPos(circleWorldPos.xz))+32.0;
	
	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(circleWorldPos.xz,mapSize.xy - circleWorldPos.xz);
	float inboundsness = min(mymin.x, mymin.y);
	
	// dump to FS
	worldPos = circleWorldPos;
	blendedcolor = color;
	blendedcolor.a *= 1.0 - clamp(inboundsness*(-0.003),0.0,1.0);
	gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);
}
]]

local fsSrc =  [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__DEFINES__

#line 20000

uniform vec4 circleuniforms; 

uniform sampler2D heightmapTex;

//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	vec4 worldPos; // w = range
	vec4 blendedcolor;
};

out vec4 fragColor;

void main() {
	fragColor.rgba = blendedcolor.rgba;
	fragColor.a *= sin((worldPos.x+worldPos.z)*0.06	- timeInfo.z*0.012);
	//fragColor.a = min(fragColor.a, 0.8);	 // alpha of the line
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
      fragment = fsSrc,
      --geometry = gsSrc, no geom shader for now
      uniformInt = {
        heightmapTex = 0,
        },
      uniformFloat = {
        circleuniforms = {1,1,1,1},
      },
    },
    "circleShader GL4"
  )
  shaderCompiled = circleShader:Initialize()
  if not shaderCompiled then goodbye("Failed to compile circleShader GL4 ") end
  local circleVBO,numVertices = makeCircleVBO(circleSegments)
  local circleInstanceVBOLayout = {
		  {id = 1, name = 'startposrad', size = 4}, -- the start pos + radius
		  {id = 2, name = 'endposrad', size = 4}, --  end pos + radius
		  {id = 3, name = 'color', size = 4}, --- color
		}
  circleInstanceVBO = makeInstanceVBOTable(circleInstanceVBOLayout,12, "circleInstanceVBO")
  circleInstanceVBO.numVertices = numVertices
  circleInstanceVBO.vertexVBO = circleVBO
  circleInstanceVBO.VAO = makeVAOandAttach(circleInstanceVBO.vertexVBO, circleInstanceVBO.instanceVBO)
end

-- Functions shortcuts
local spGetGameSeconds      = Spring.GetGameSeconds
local spGetGroundHeight 	= Spring.GetGroundHeight
local spGetSpectatingState  = Spring.GetSpectatingState
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitPosition     = Spring.GetUnitPosition
local spIsGUIHidden 		= Spring.IsGUIHidden
local spIsSphereInView  	= Spring.IsSphereInView
local spIsUnitAllied		= Spring.IsUnitAllied
local glBeginEnd            = gl.BeginEnd
local glCallList		 	= gl.CallList
local glColor               = gl.Color
local glColorMask           = gl.ColorMask
local glCreateList			= gl.CreateList
local glDeleteList			= gl.DeleteList
local glDepthTest           = gl.DepthTest
local glLineWidth           = gl.LineWidth
local glStencilFunc         = gl.StencilFunc
local glStencilOp           = gl.StencilOp
local glStencilTest         = gl.StencilTest
local glTranslate           = gl.Translate
local glVertex              = gl.Vertex
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
local spec, fullview = spGetSpectatingState()
local allyTeamID = Spring.GetMyAllyTeamID()

local chobbyInterface

-- find all unit types with radar in the game and place ranges into unitRange table
local unitRange = {} -- table of unit types with their radar ranges
local isBuilding = {} -- unitDefID keys
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.radarRadius and unitDef.radarRadius > minRadarDistance then	-- save perf by excluding low radar range units
		if not unitRange[unitDefID] then unitRange[unitDefID] = {} end
		unitRange[unitDefID]['range'] = unitDef.radarRadius

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
local function processUnit(unitID, unitDefID)
	if not spIsUnitAllied(unitID) then return end

	local unitDefID = spGetUnitDefID(unitID)

    if not unitRange[unitDefID] then
        return
    end

	local x, y, z = spGetUnitPosition(unitID)

    local range = unitRange[unitDefID]['range']
    local height = unitRange[unitDefID]['height']
	
    unitList[unitID] = unitDefID
	-- shall we jam it straight into the table?
	pushElementInstance(circleInstanceVBO,{x,y,z,range, x,y,z,range,rangeColor[1],rangeColor[2],rangeColor[3],rangeColor[4] },unitID)
end


function widget:Initialize()
	initgl4()
	widget:ViewResize()
	unitList = {}
    local units = Spring.GetAllUnits()
	for i=1,#units do
		processUnit( units[i], spGetUnitDefID(units[i]))
    end
end

function widget:Shutdown()
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  if 	unitList[unitID] then
    unitList[unitID] = nil
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



-- resets gl color and line width to default values
local function resetGl()
	glColor( 1.0, 1.0, 1.0, 1.0 )
	glLineWidth( 1.0 )
end

function widget:GameFrame(n)
	if spec and fullview then return end
	if n % 15 == 0 then -- this 15 frames is important, as the vertex shader is interpolating at this rate too!
		local instanceData = circleInstanceVBO.instanceData -- ok this is so nasty that it makes all my prev pop-push work obsolete
		for unitID, unitDefID in pairs(unitList) do
				if not isBuilding[unitDefID] then 
				local x, y, z = spGetUnitPosition(unitID)
				
				local instanceDataOffset = (circleInstanceVBO.instanceIDtoIndex[unitID] - 1)* circleInstanceVBO.instanceStep
				
				for i=instanceDataOffset + 1, instanceDataOffset+4 do
					instanceData[i] = instanceData[i+4]
				end
				instanceData[instanceDataOffset+5] = x
				instanceData[instanceDataOffset+6] = y
				instanceData[instanceDataOffset+7] = z
		
			end
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
	
	--if true then return end
	glColorMask(false, false, false, false)
	glStencilTest(true)
	glDepthTest(false)

	gl.Texture(0, "$heightmap")
	circleShader:Activate()
	
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
	glStencilFunc(GL_EQUAL, 1, 1)
	glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)

	-- Render outer circles using resulting stencil
		glColor( rangeColor[1], rangeColor[2], rangeColor[3], rangeColor[4])
		glLineWidth(rangeLineWidth * lineScale)
		circleInstanceVBO.VAO:DrawArrays(GL_LINE_LOOP,circleInstanceVBO.numVertices,0,circleInstanceVBO.usedElements,0)

	circleShader:Deactivate()
	gl.Texture(0, false)
	
	glStencilTest(false)
	
	resetGl()
end
