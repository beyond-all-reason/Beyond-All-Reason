function widget:GetInfo()
	return {
		name      = "Radar Range",
		desc      = "Shows ranges of all ally radars.",
		author    = "Kev",
		date      = "2020.11.14",
		license   = "CC BY-NC",
		layer     = 0,
		enabled   = true
	}
end

-- Constants (kinda)
local circleSplitCount = 96 -- level of circle's detail
local circleSplits = {} -- precalculated sin and cos values
local shapeHover = 3.0 -- circle elevation over ground (probably not needed since rendering is depth-unaware)
local updateInterval = 0.125 -- 8 times per second is good middle ground between look and performance
local rangeColor = { 0.0, 1.0, 0.0, 0.18 }
local rangeLineWidth = 4.0 -- use UI Scale factor?

-- precalculate needed sin and cos values
-- taking values from table is hundreds of times faster (yes, really)
for i = 1, circleSplitCount do
    local rad = 2 * math.pi * i / (circleSplitCount-1)
    circleSplits[i] = { sin = math.sin(rad), cos = math.cos(rad) }
end

-- Functions shortcuts
local spGetGameSeconds      = Spring.GetGameSeconds
local spGetGroundHeight 	= Spring.GetGroundHeight
local spGetSpectatingState  = Spring.GetSpectatingState
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitPosition     = Spring.GetUnitPosition
local spIsGUIHidden 		= Spring.IsGUIHidden
local spIsSphereInView  	= Spring.IsSphereInView
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
local rangeShapeList = {} -- table of coordinates lists for range circles

local unitRange = {} -- table of unit types with their radar ranges
local spec, fullview = spGetSpectatingState()

-- find all unit types with radar in the game and place ranges into unitRange table
function fillUnitRanges()
    for unitDefID, unitDef in pairs(UnitDefs) do
        if unitDef.radarRadius and unitDef.radarRadius > 0 then
            if not unitRange[unitDefID] then unitRange[unitDefID] = {} end
            unitRange[unitDefID]['range'] = unitDef.radarRadius
        end
    end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:PlayerChanged()
	spec, fullview = spGetSpectatingState()
end

function widget:ViewResize(newX,newY)
	vsx, vsy = Spring.GetViewGeometry()
	lineScale = vsy+500 / 1300
end

function widget:Initialize()
	widget:ViewResize()
    fillUnitRanges()
    local units = Spring.GetAllUnits()
	for i=1,#units do
		processUnit( units[i] )
    end
end

function widget:Shutdown()
	if rangeCircleList then
		glDeleteList(rangeCircleList)
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	processUnit( unitID )
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	processUnit( unitID )
end

function widget:UnitFinished( unitID,  unitDefID,  unitTeam)
	processUnit( unitID )
end

function widget:UnitEnteredLos(unitID, allyTeam)
	processUnit( unitID )
end

-- collect data about the unit and store it into unitList
function processUnit(unitId)
	local unitDefId = spGetUnitDefID(unitId)

    if not unitRange[unitDefId] then
        return
    end

	local x, y, z = spGetUnitPosition(unitId)

    local range = unitRange[unitDefId]['range']
    local height = unitRange[unitDefId]['height']

    unitList[unitId] = { unitId = unitId, x = x, y = y, z = z, range = range, height = height }
end

-- (re)creates 'rangeCircleList' gl command list for rendering radar ranges
function updateRangeShapes()
    if rangeCircleList then
		glDeleteList(rangeCircleList)
	end

    rangeCircleList = glCreateList(function()
        drawRangesOutline()
		resetGl()
	end)
end

-- resets gl color and line width to default values
function resetGl()
	glColor( { 1.0, 1.0, 1.0, 1.0 } )
	glLineWidth( 1.0 )
end

-- builds gl vertex list from provided coordinates table
local buildVertexList = function (verts)
	for i, vert in pairs(verts) do
		glVertex(vert)
	end
end

-- draws all ranges as outlines of intersecting circles (clutterless)
function drawRangesOutline()
    glColorMask(false, false, false, false)
    glStencilTest(true)
    glDepthTest(false)

    -- Draw outer circles into stencil buffer
    for unitId, rangeShape in pairs(rangeShapeList) do
        glStencilFunc(GL_ALWAYS, 1, 1) -- Always Passes, 1 Bit Plane, 1 As Mask
        glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon
        glLineWidth(rangeLineWidth + 1.0)
        glBeginEnd(GL_LINE_LOOP, buildVertexList, rangeShape['shape'])
    end

    -- Draw inverse inner circles into stencil buffer
    for unitId, rangeShape in pairs(rangeShapeList) do
        glStencilFunc(GL_ALWAYS, 0, 0) -- Always Passes, 0 Bit Plane, 0 As Mask
        glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 0 Where Draw Any Polygon
        glBeginEnd(GL_TRIANGLE_FAN, buildVertexList, rangeShape['shape'])
    end

    glColorMask(true, true, true, true)
    glStencilFunc(GL_EQUAL, 1, 1)
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)

    -- Render outer circles using resulting stencil
    for unitId, rangeShape in pairs(rangeShapeList) do
        glColor( rangeColor[1], rangeColor[2], rangeColor[3], rangeColor[4])
        glLineWidth(rangeLineWidth * lineScale)
        glBeginEnd(GL_LINE_LOOP, buildVertexList, rangeShape['shape'] )
    end

    glStencilTest(false)
end

function widget:GameFrame(frame)
    -- unitList[unitId] { unitId, x, y, z, range, height } -> rangeShapeList[unitId] { height, shape }
    local timef = spGetGameSeconds()
    if timef < 5 then return end -- otherwise GL_KEEP or GL_REPLACE is nil for some reason...
    if frame % 2 == 0 then return end -- save some CPU time...

    -- check for dead units and update units data
    for id, unit in pairs(unitList) do
        if not spGetUnitDefID(id) then
            unitList[id] = nil
            rangeShapeList[id] = nil
        end
    end

    -- prepare coordinates lists for radar ranges
    local shape
    for id, unit in pairs(unitList) do
        local x, y, z = spGetUnitPosition(id)
        if not rangeShapeList[id] or unit.x ~= x or unit.y ~= y or unit.z ~= z then -- update only if positions is changed
            unitList[id].x = x
            unitList[id].y = y
            unitList[id].z = z

            if not rangeShapeList[id] then
                rangeShapeList[id] = { height = unit.height, shape = {} }
            end

            shape = rangeShapeList[id].shape

             -- center of the circle is needed since it's been rendered as triangle fan
            if not shape[0] then
                shape[0] = {x, spGetGroundHeight( x, z ), z}
            else
                shape[0][1] = x
                shape[0][2] = spGetGroundHeight( x, z )
                shape[0][3] = z
            end

            for i = 1, #circleSplits do
                local shx = x + circleSplits[i].sin * unit.range
                local shz = z + circleSplits[i].cos * unit.range
                local shy = spGetGroundHeight( shx, shz ) + shapeHover
                if shy < 0 then shy = 0 end

                if not shape[i] then
                    shape[i] = { shx, shy, shz }
                else
                    shape[i][1] = shx
                    shape[i][2] = shy
                    shape[i][3] = shz
                end
            end
        end
    end

    updateRangeShapes()
end

function widget:DrawWorld()
    if chobbyInterface then return end
    if spec and fullview then return end
    if spIsGUIHidden() or (WG['topbar'] and WG['topbar'].showingQuit()) then return end

    if not rangeCircleList then
        updateRangeShapes()
    end

    if rangeCircleList then
        glCallList(rangeCircleList)
    end
end
