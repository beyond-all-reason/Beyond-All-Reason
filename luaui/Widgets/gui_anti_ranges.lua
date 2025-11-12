--------------------------------------------------------------------------------
local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name      = "Anti Ranges",
        desc      = "Draws circle to show anti defence ranges (options: /antiranges_fill, antiranges_fade)",
        author    = "[teh]decay, Floris",
        date      = "25 january 2015",
        license   = "GNU GPL, v2 or later",
        version   = 4,
        layer     = 5,
        enabled   = false
    }
end


-- Localized Spring API for performance

-- project page on github: https://github.com/jamerlan/gui_mobile_anti_defence_range

--Changelog
-- v2 [teh]decay:  Add water antinukes
-- v3 Floris:  added normal anti, changed widget name, optional glow, optional fadeout on closeup, changed line thickness and opacity, empty anti uses different color
-- v4 grotful: Removed hardcoded unit lists, added function to find anti-nuke units in unitDefs
-- v5 SuperKitowiec: Added /antiranges_fill option which highlights whole area covered by AN

--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

--/antiranges_fill		-- toggles a faint glow on the line
--/antiranges_fade		-- toggles hiding of ranges when zoomed in

--------------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------------

local opacityMultiplier			= 0.75
local multiStockpileColor		= {1,1,0}
local filledStockpileColor		= {1,0.75,0}
local unknownStockpileColor		= {1,0.54,1}
local emptyStockpileColor		= {1,0.33,0}
local unfinishedStockpileColor	= {1,0,0.75}
local empdStockpileColor		= {0.1,0,1}
local empdStockpileColor2		= {0.7,0,1}
local showFilledCircles 		= false
local fadeOnCloseup        		= true
local fadeStartDistance			= 3500
local circleDivs 				= 96

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local glColor					= gl.Color
local glDepthTest				= gl.DepthTest
local glLineWidth				= gl.LineWidth
local glDrawGroundCircle		= gl.DrawGroundCircle
local glPushMatrix				= gl.PushMatrix
local glTranslate				= gl.Translate
local glScale					= gl.Scale
local glVertex					= gl.Vertex
local glBeginEnd				= gl.BeginEnd
local glPopMatrix				= gl.PopMatrix
local glClear 					= gl.Clear
local glStencilTest 			= gl.StencilTest
local glStencilMask 			= gl.StencilMask
local glStencilOp 				= gl.StencilOp

local GL_TRIANGLE_FAN			= GL.TRIANGLE_FAN
local GL_STENCIL_BUFFER_BIT 	= GL.STENCIL_BUFFER_BIT
local GL_KEEP               	= 0x1E00 --GL.KEEP
local GL_REPLACE            	= GL.REPLACE

local spGetUnitDefID			= Spring.GetUnitDefID
local spGetUnitPosition			= Spring.GetUnitPosition
local spGetPositionLosState 	= Spring.GetPositionLosState
local spGetCameraPosition		= Spring.GetCameraPosition
local spGetUnitStockpile		= Spring.GetUnitStockpile
local spGetAllUnits    			= Spring.GetAllUnits
local spEcho 					= Spring.Echo
local spGetUnitIsStunned 		= Spring.GetUnitIsStunned

local antiInLos					= {}
local antiOutLos				= {}
local antiNukeDefs              = {}

local diag = math.diag

local chobbyInterface

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function widget:Initialize()
    identifyAntiNukeUnits()  -- Pre-process unit definitions
    checkAllUnits()
end

function identifyAntiNukeUnits()
    for unitDefID, unitDef in pairs(UnitDefs) do
        local weapons = unitDef.weapons
        for i=1, #weapons do
            local weaponDef = WeaponDefs[weapons[i].weaponDef]
            if weaponDef and weaponDef.interceptor and weaponDef.interceptor == 1 then
                antiNukeDefs[unitDefID] = weaponDef.coverageRange
                break
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------



function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

local function beginNoOverlap()
	glClear(GL_STENCIL_BUFFER_BIT)
	glStencilTest(true)
	glStencilMask(255)
	glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
end

local function endNoOverlap()
	glStencilTest(false)
	glStencilMask(255)
	glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)
	glClear(GL_STENCIL_BUFFER_BIT)
end

function widget:DrawWorldPreUnit()
	if chobbyInterface then return end
    if Spring.IsGUIHidden() then return end
	local camX, camY, camZ = spGetCameraPosition()

    for uID, pos in pairs(antiInLos) do
        local LosOrRadar, inLos, inRadar = spGetPositionLosState(pos[1], pos[2], pos[3])
        if not inLos then
            antiOutLos[uID] = pos
            antiInLos[uID] = nil
        end
    end

    glDepthTest(true)
	beginNoOverlap()
    for uID, pos in pairs(antiInLos) do
        local x, y, z = spGetUnitPosition(uID)
        if x ~= nil and y ~= nil and z ~= nil and Spring.IsSphereInView(x, y, z, pos[4]) then
			drawCircle(uID, pos[4], x, y, z, camX, camY, camZ)
        end
    end

    for uID, pos in pairs(antiOutLos) do
        local LosOrRadar, inLos, inRadar = spGetPositionLosState(pos[1], pos[2], pos[3])
        if inLos then
            antiOutLos[uID] = nil
            antiInLos[uID] = pos
        end
    end

    for uID, pos in pairs(antiOutLos) do
        if pos.x ~= nil and pos.y ~= nil and pos.z ~= nil then
			drawCircle(uID, pos[4], pos[1], pos[2], pos[3], camX, camY, camZ)
        end
    end
	endNoOverlap()
end

local function drawFilledCircle(x, y, z, radius)
	glPushMatrix()
	glDepthTest(false)
	glTranslate(x, y, z)
	glScale(radius, radius, radius)
	local function FilledUnitCircleVertices()
		glVertex(0, 0, 0)
		for i = 0, circleDivs do
			local theta = 2 * math.pi * i / circleDivs
			glVertex(math.cos(theta), 0, math.sin(theta))
		end
	end
	glBeginEnd(GL_TRIANGLE_FAN, FilledUnitCircleVertices)
	glDepthTest(true)
	glPopMatrix()
end

function drawCircle(uID, coverageRange, x, y, z, camX, camY, camZ)
	local camDistance = diag(camX-x, camY-y, camZ-z)

	local lineWidthMinus = (camDistance/fadeStartDistance)
	if lineWidthMinus > 2.2 then
		lineWidthMinus = 2.2
	end
	local lineOpacityMultiplier = 1
	if fadeOnCloseup then
		lineOpacityMultiplier = (camDistance - fadeStartDistance) / 1800
		if lineOpacityMultiplier > 1 then
			lineOpacityMultiplier = 1
		end
	end
	lineOpacityMultiplier = lineOpacityMultiplier * opacityMultiplier

	if lineOpacityMultiplier > 0 then
		local numStockpiled, numStockpileQued, stockpileBuild = spGetUnitStockpile(uID)
		local circleColor = emptyStockpileColor

		local _,stunned,inbuild = spGetUnitIsStunned(uID)
		if stunned then
			if os.clock()%0.66 > 0.33 then
				circleColor = empdStockpileColor
			else
				circleColor = empdStockpileColor2
			end
		elseif inbuild then
			circleColor = unfinishedStockpileColor
		else
			if numStockpiled == nil then
				circleColor = unknownStockpileColor
			elseif numStockpiled == 1 then
				circleColor = filledStockpileColor
			elseif numStockpiled > 1 then
				circleColor = multiStockpileColor
			end
		end

		glColor(circleColor[1],circleColor[2],circleColor[3], .55*lineOpacityMultiplier)
		glLineWidth(3.5-lineWidthMinus)
		glDrawGroundCircle(x, y, z, coverageRange, 128)

		if showFilledCircles then
			glColor(circleColor[1],circleColor[2],circleColor[3], .20*lineOpacityMultiplier)
			drawFilledCircle(x, y, z, coverageRange)
		end

	end
end

function processVisibleUnit(unitID)
    local unitDefID = spGetUnitDefID(unitID)
    local coverageRange = antiNukeDefs[unitDefID]
    if coverageRange then
        local x, y, z = spGetUnitPosition(unitID)
        local pos = { x, y, z, coverageRange }

        antiInLos[unitID] = pos
        antiOutLos[unitID] = nil
    end
end

function widget:UnitLeftLos(unitID)
    local unitDefID = spGetUnitDefID(unitID)
    local coverageRange = antiNukeDefs[unitDefID]
    if coverageRange then
        local x, y, z = spGetUnitPosition(unitID)
        local pos = {
            (x or antiInLos[unitID][1]),
            (y or antiInLos[unitID][2]),
            (z or antiInLos[unitID][3]),
            coverageRange
        }

        antiOutLos[unitID] = pos
        antiInLos[unitID] = nil
    end
end

function widget:UnitCreated(unitID, unitDefID, teamID, builderID)
    processVisibleUnit(unitID)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
    processVisibleUnit(unitID)
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
    processVisibleUnit(unitID)
end

function widget:GameFrame(n)
    for uID, _ in pairs(antiInLos) do
        if not spGetUnitDefID(uID) then
            antiInLos[uID] = nil -- has died
        end
    end
end

function widget:PlayerChanged(playerID)
	checkAllUnits()
end

function checkAllUnits()
	antiInLos				= {}
	antiOutLos				= {}

	local allUnits = spGetAllUnits()
    for i=1,#allUnits do
        processVisibleUnit(allUnits[i])
    end
end

--------------------------------------------------------------------------------

function widget:GetConfigData(data)
    return {
		showFilledCircles = showFilledCircles,
		fadeOnCloseup = fadeOnCloseup
	}
end

function widget:SetConfigData(data)
    if data.showFilledCircles ~= nil 		then  showFilledCircles 	= data.showFilledCircles end
    if data.fadeOnCloseup ~= nil 			then  fadeOnCloseup			= data.fadeOnCloseup end
end

function widget:TextCommand(command)
    if (string.find(command, "antiranges_fill", nil, true) == 1  and  string.len(command) == 15) then
		showFilledCircles = not showFilledCircles
		if showFilledCircles then
			spEcho("Anti Ranges:  Fill on")
		else
			spEcho("Anti Ranges:  Fill off")
		end
	end
    if (string.find(command, "antiranges_fade", nil, true) == 1  and  string.len(command) == 15) then
		fadeOnCloseup = not fadeOnCloseup
		if fadeOnCloseup then
			spEcho("Anti Ranges:  Fade-out on closeup enabled")
		else
			spEcho("Anti Ranges:  Fade-out on closeup disabled")
		end
	end
end
