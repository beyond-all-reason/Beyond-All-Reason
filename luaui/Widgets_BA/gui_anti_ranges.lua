--------------------------------------------------------------------------------
function widget:GetInfo()
    return {
        name      = "Anti Ranges",
        desc      = "Draws circle to show anti defence ranges (options: /antiranges_glow, antiranges_fade)",
        author    = "[teh]decay, Floris",
        date      = "25 january 2015",
        license   = "GNU GPL, v2 or later",
        version   = 3,
        layer     = 5,
        enabled   = true  --  loaded by default?
    }
end

-- project page on github: https://github.com/jamerlan/gui_mobile_anti_defence_range

--Changelog
-- v2 [teh]decay:  Add water antinukes
-- v3 Floris:  added normal anti, changed widget name, optional glow, optional fadeout on closeup, changed line thickness and opacity, empty anti uses different color


--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

--/antiranges_glow		-- toggles a faint glow on the line
--/antiranges_fade		-- toggles hiding of ranges when zoomed in

--------------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------------

local opacityMultiplier			= 0.85
local multiStockpileColor		= {1,1,0}
local filledStockpileColor		= {1,0.75,0}
local unknownStockpileColor		= {1,0.54,1}
local emptyStockpileColor		= {1,0.33,0}
local unfinishedStockpileColor	= {1,0,0.75}
local empdStockpileColor		= {0.1,0,1}
local empdStockpileColor2		= {0.7,0,1}
local showLineGlow2				= false
local fadeOnCloseup        		= true
local fadeStartDistance			= 3300

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local arm_anti					= UnitDefNames.armamd.id
local arm_mobile_anti			= UnitDefNames.armscab.id
local arm_mobile_anti_water		= UnitDefNames.armcarry.id
local core_anti					= UnitDefNames.corfmd.id
local core_mobile_anti			= UnitDefNames.cormabm.id
local core_mobile_anti_water	= UnitDefNames.corcarry.id

local glColor					= gl.Color
local glDepthTest				= gl.DepthTest
local glLineWidth				= gl.LineWidth
local glDrawGroundCircle		= gl.DrawGroundCircle
local glDrawListAtUnit          = gl.DrawListAtUnit


local spGetMyPlayerID			= Spring.GetMyPlayerID
local spGetPlayerInfo			= Spring.GetPlayerInfo
local spGetUnitDefID			= Spring.GetUnitDefID
local spGetUnitPosition			= Spring.GetUnitPosition
local spGetPositionLosState 	= Spring.GetPositionLosState
local spGetCameraPosition		= Spring.GetCameraPosition
local spGetUnitStockpile		= Spring.GetUnitStockpile
local spGetAllUnits    			= Spring.GetAllUnits
local GetUnitIsStunned     		= Spring.GetUnitIsStunned

local antiInLos					= {}
local antiOutLos				= {}


local coverageRangeArmStatic	= WeaponDefs[UnitDefNames.armamd.weapons[1].weaponDef].coverageRange
local coverageRangeCoreStatic	= WeaponDefs[UnitDefNames.corfmd.weapons[1].weaponDef].coverageRange
local coverageRangeArm			= WeaponDefs[UnitDefNames.armscab.weapons[1].weaponDef].coverageRange
local coverageRangeCore			= WeaponDefs[UnitDefNames.cormabm.weapons[1].weaponDef].coverageRange
local coverageRangeArmWater		= WeaponDefs[UnitDefNames.armcarry.weapons[1].weaponDef].coverageRange
local coverageRangeCoreWater	= WeaponDefs[UnitDefNames.corcarry.weapons[1].weaponDef].coverageRange

local diag = math.diag

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------



function widget:DrawWorldPreUnit()
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
    local unitDefId = spGetUnitDefID(unitID);
    if unitDefId == arm_anti or unitDefId == core_anti or unitDefId == arm_mobile_anti or unitDefId == core_mobile_anti
            or unitDefId == arm_mobile_anti_water or unitDefId == core_mobile_anti_water then
        local x, y, z = spGetUnitPosition(unitID)
        local pos = {x,y,z}

        if unitDefId == arm_mobile_anti then
            pos[4] = coverageRangeArm
        elseif unitDefId == arm_anti then
            pos[4] = coverageRangeArmStatic
        elseif unitDefId == core_anti then
            pos[4] = coverageRangeCoreStatic
        elseif unitDefId == arm_mobile_anti_water then
            pos[4] = coverageRangeArmWater
        elseif unitDefId == core_mobile_anti then
            pos[4] = coverageRangeCore
        else
            pos[4] = coverageRangeCoreWater
        end

        antiInLos[unitID] = pos
        antiOutLos[unitID] = nil
    end
end

function widget:UnitLeftLos(unitID)
    local unitDefId = spGetUnitDefID(unitID);
    if unitDefId == arm_anti or unitDefId == core_anti or unitDefId == arm_mobile_anti or unitDefId == core_mobile_anti or unitDefId == arm_mobile_anti_water or unitDefId == core_mobile_anti_water then
        local x, y, z = spGetUnitPosition(unitID)
        local pos = {(x or antiInLos[unitID][1]), (y or antiInLos[unitID][2]), (z or antiInLos[unitID][3])}

        if unitDefId == arm_mobile_anti then
            pos[4] = coverageRangeArm
        elseif unitDefId == arm_mobile_anti_water then
            pos[4] = coverageRangeArmWater
        elseif unitDefId == core_mobile_anti then
            pos[4] = coverageRangeCore
        else
            pos[4] = coverageRangeCoreWater
        end

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

function widget:Initialize()
	checkAllUnits()
end

function widget:PlayerChanged(playerID)
	checkAllUnits()
end


function checkAllUnits()
    local _, _, spec, teamId = spGetPlayerInfo(spGetMyPlayerID())

	antiInLos				= {}
	antiOutLos				= {}
	
	local allUnits = spGetAllUnits()
    for _, unitID in ipairs(allUnits) do
        processVisibleUnit(unitID)
    end
end

--------------------------------------------------------------------------------

function widget:GetConfigData(data)
    savedTable = {}
    savedTable.showLineGlow2			= showLineGlow2
    savedTable.fadeOnCloseup		= fadeOnCloseup
    return savedTable
end

function widget:SetConfigData(data)
    if data.showLineGlow2 ~= nil 		then  showLineGlow2			= data.showLineGlow2 end
    if data.fadeOnCloseup ~= nil 		then  fadeOnCloseup			= data.fadeOnCloseup end
end

function widget:TextCommand(command)
    if (string.find(command, "antiranges_glow") == 1  and  string.len(command) == 15) then 
		showLineGlow2 = not showLineGlow2
		if showLineGlow2 then
			Spring.Echo("Anti Ranges:  Glow on")
		else
			Spring.Echo("Anti Ranges:  Glow off")
		end
	end
    if (string.find(command, "antiranges_fade") == 1  and  string.len(command) == 15) then 
		fadeOnCloseup = not fadeOnCloseup
		if fadeOnCloseup then
			Spring.Echo("Anti Ranges:  Fade-out on closeup enabled")
		else
			Spring.Echo("Anti Ranges:  Fade-out on closeup disabled")
		end
	end
end
