--------------------------------------------------------------------------------
local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name      = "Anti Ranges",
        desc      = "Draws circle to show anti defence ranges (options: /antiranges_glow, antiranges_fade)",
        author    = "[teh]decay, Floris",
        date      = "25 january 2015",
        license   = "GNU GPL, v2 or later",
        version   = 4,
        layer     = 5,
        enabled   = false
    }
end

-- project page on github: https://github.com/jamerlan/gui_mobile_anti_defence_range

--Changelog
-- v2 [teh]decay:  Add water antinukes
-- v3 Floris:  added normal anti, changed widget name, optional glow, optional fadeout on closeup, changed line thickness and opacity, empty anti uses different color
-- v4 grotful: Removed hardcoded unit lists, added function to find anti-nuke units in unitDefs


--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

--/antiranges_glow		-- toggles a faint glow on the line
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
local showLineGlow2				= false
local fadeOnCloseup        		= true
local fadeStartDistance			= 3500

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local glColor					= gl.Color
local glDepthTest				= gl.DepthTest
local glLineWidth				= gl.LineWidth
local glDrawGroundCircle		= gl.DrawGroundCircle

local spGetUnitDefID			= Spring.GetUnitDefID
local spGetUnitPosition			= Spring.GetUnitPosition
local spGetPositionLosState 	= Spring.GetPositionLosState
local spGetCameraPosition		= Spring.GetCameraPosition
local spGetUnitStockpile		= Spring.GetUnitStockpile
local spGetAllUnits    			= Spring.GetAllUnits
local GetUnitIsStunned     		= Spring.GetUnitIsStunned

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

		local _,stunned,inbuild = GetUnitIsStunned(uID)
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

		--[[
		if showLineGlow2 then
			glLineWidth(10)
			glColor(circleColor[1],circleColor[2],circleColor[3], .016*lineOpacityMultiplier)
			glDrawGroundCircle(x, y, z, coverageRange, 128)
		end]]--
		glColor(circleColor[1],circleColor[2],circleColor[3], .55*lineOpacityMultiplier)
		glLineWidth(3.5-lineWidthMinus)
		glDrawGroundCircle(x, y, z, coverageRange, 128)
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
		showLineGlow2 = showLineGlow2,
		fadeOnCloseup = fadeOnCloseup
	}
end

function widget:SetConfigData(data)
    if data.showLineGlow2 ~= nil 		then  showLineGlow2			= data.showLineGlow2 end
    if data.fadeOnCloseup ~= nil 		then  fadeOnCloseup			= data.fadeOnCloseup end
end

function widget:TextCommand(command)
    if (string.find(command, "antiranges_glow", nil, true) == 1  and  string.len(command) == 15) then
		showLineGlow2 = not showLineGlow2
		if showLineGlow2 then
			Spring.Echo("Anti Ranges:  Glow on")
		else
			Spring.Echo("Anti Ranges:  Glow off")
		end
	end
    if (string.find(command, "antiranges_fade", nil, true) == 1  and  string.len(command) == 15) then
		fadeOnCloseup = not fadeOnCloseup
		if fadeOnCloseup then
			Spring.Echo("Anti Ranges:  Fade-out on closeup enabled")
		else
			Spring.Echo("Anti Ranges:  Fade-out on closeup disabled")
		end
	end
end
