function widget:GetInfo()
    return {
        name      = "EMP + decloak range",
        desc      = "When spy or gremlin is selected, it displays its decloack range (orange) and emp range (blue)",
        author    = "[teh]decay aka [teh]undertaker",
        date      = "14 feb 2015",
        license   = "The BSD License",
        layer     = 0,
        version   = 5,
        enabled   = true  -- loaded by default
    }
end

-- project page on github: https://github.com/jamerlan/spy_range

--Changelog
-- v2 [teh]decay Don't draw circles when GUI is hidden
-- v3 [teh]decay Added gremlin decloack range + set them on hold fire and hold pos
-- v4 Floris Added fade on camera distance changed to thicker and more transparant line style + options + onlyDrawRangeWhenSelected
-- v5 Floris: Renamed to EMP + decloack range and disabled autocloack


--------------------------------------------------------------------------------
-- OPTIONS
--------------------------------------------------------------------------------

local onlyDrawRangeWhenSelected	= true
local fadeOnCameraDistance		= true
local showLineGlow 				= true		-- a ticker but faint 2nd line will be drawn underneath	
local opacityMultiplier			= 1.3
local fadeMultiplier			= 1.2		-- lower value: fades out sooner
local circleDivs				= 64		-- detail of range circle
local autoCloackSpy				= false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local glColor 				= gl.Color
local glLineWidth 			= gl.LineWidth
local glDepthTest			= gl.DepthTest
local glDrawGroundCircle	= gl.DrawGroundCircle
local GetUnitDefID			= Spring.GetUnitDefID
local lower                 = string.lower
local spGetAllUnits			= Spring.GetAllUnits
local spGetSpectatingState	= Spring.GetSpectatingState
local spGetMyPlayerID		= Spring.GetMyPlayerID
local spGetPlayerInfo		= Spring.GetPlayerInfo
local spGiveOrderToUnit		= Spring.GiveOrderToUnit
local spIsGUIHidden			= Spring.IsGUIHidden
local spGetCameraPosition 	= Spring.GetCameraPosition
local spValidUnitID			= Spring.ValidUnitID
local spGetUnitPosition		= Spring.GetUnitPosition
local spIsSphereInView		= Spring.IsSphereInView
local spIsUnitSelected		= Spring.IsUnitSelected

local CMD_MOVE_STATE		= CMD.MOVE_STATE
local cmdFireState			= CMD.FIRE_STATE

local diag					= math.diag

local weapNamTab			= WeaponDefNames
local weapTab				= WeaponDefs
local udefTab				= UnitDefs

local selfdTag = "selfDExplosion"
local aoeTag = "damageAreaOfEffect"

local coreSpy = UnitDefNames["corspy"]
local armSpy = UnitDefNames["armspy"]
local armGremlin = UnitDefNames["armst"]

local coreSpyId = coreSpy.id
local armSpyId = armSpy.id
local armGremlinId = armGremlin.id

local units = {}

local spectatorMode = false
local notInSpecfullmode = false

local cmdCloak = 37382

function cloackSpy(unitID)
    spGiveOrderToUnit(unitID, cmdCloak, { 1 }, {})
end

function processGremlin(unitID)
    spGiveOrderToUnit(unitID, cmdCloak, { 1 }, {})
    spGiveOrderToUnit(unitID, CMD_MOVE_STATE, { 0 }, {}) -- 0 == hold pos
    spGiveOrderToUnit(unitID, cmdFireState, { 0 }, {}) -- hold fire
end

function isSpy(unitDefID)
    if unitDefID == coreSpyId or armSpyId == unitDefID then
        return true
    end
    return false
end

function isGremlin(unitDefID)
    if unitDefID == armGremlinId then
        return true
    end
    return false
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    if isSpy(unitDefID) then
		addSpy(unitID, unitDefID)
		if autoCloackSpy then
			cloackSpy(unitID)
		end
    end

    if isGremlin(unitDefID) then
		addGremlin(unitID, unitDefID)
        processGremlin(unitID)
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    if units[unitID] then
        units[unitID] = nil
    end
end

function widget:UnitEnteredLos(unitID, unitTeam)
    if not spectatorMode then
        local unitDefID = GetUnitDefID(unitID)
        if isSpy(unitDefID) then
			addSpy(unitID, unitDefID)
        end

        if isGremlin(unitDefID) then
			addGremlin(unitID, unitDefID)
        end
    end
end


function addSpy(unitID, unitDefID)
	
	local udef = udefTab[unitDefID]
	local selfdBlastId = weapNamTab[lower(udef[selfdTag])].id
	local selfdBlastRadius = weapTab[selfdBlastId][aoeTag]
	units[unitID] = {udef["decloakDistance"],selfdBlastRadius}
end

function addGremlin(unitID, unitDefID)
	
	local udef = udefTab[unitDefID]
	units[unitID] = {udef["decloakDistance"],0}
end

function widget:UnitCreated(unitID, unitDefID, teamID, builderID)
	if not spValidUnitID(unitID) then return end --because units can be created AND destroyed on the same frame, in which case luaui thinks they are destroyed before they are created
		
    if isSpy(unitDefID) then
		addSpy(unitID, unitDefID)
        cloackSpy(unitID)
    end

    if isGremlin(unitDefID) then
		addGremlin(unitID, unitDefID)
        processGremlin(unitID)
    end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
    if isSpy(unitDefID) then
		addSpy(unitID, unitDefID)
        cloackSpy(unitID)
    end

    if isGremlin(unitDefID) then
		addGremlin(unitID, unitDefID)
        processGremlin(unitID)
    end
end


function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
    if isSpy(unitDefID) then
		addSpy(unitID, unitDefID)
        cloackSpy(unitID)
    end

    if isGremlin(unitDefID) then
		addGremlin(unitID, unitDefID)
        processGremlin(unitID)
    end
end

function widget:UnitLeftLos(unitID, unitDefID, unitTeam)
    if not spectatorMode then
        if units[unitID] then
            units[unitID] = nil
        end
    end
end

function widget:DrawWorldPreUnit()
    local _, specFullView, _ = spGetSpectatingState()

    if not specFullView then
        notInSpecfullmode = true
    else
        if notInSpecfullmode then
            detectSpectatorView()
        end
        notInSpecfullmode = false
    end

    if spIsGUIHidden() then return end

	local camX, camY, camZ = spGetCameraPosition()
	
    glDepthTest(true)

    for unitID, property in pairs(units) do
        local x,y,z = spGetUnitPosition(unitID)
		if ((onlyDrawRangeWhenSelected and spIsUnitSelected(unitID)) or onlyDrawRangeWhenSelected == false) and spIsSphereInView(x,y,z,math.max(property[1],property[2])) then
			local camDistance = diag(camX-x, camY-y, camZ-z) 
			
			local lineWidthMinus = (camDistance/2000)
			if lineWidthMinus > 2 then
				lineWidthMinus = 2
			end
			local lineOpacityMultiplier = 0.9
			if fadeOnCameraDistance then
				lineOpacityMultiplier = (1100/camDistance)*fadeMultiplier
				if lineOpacityMultiplier > 1 then
					lineOpacityMultiplier = 1
				end
			end
			if lineOpacityMultiplier > 0.15 then
				if showLineGlow then
					glLineWidth(10)
					if property[1] > 0 then
						glColor(1, .6, .3, .03*lineOpacityMultiplier*opacityMultiplier)
						glDrawGroundCircle(x, y, z, property[1], circleDivs)
					end
					if property[2] > 0 then
						glColor(0, 0, 1, .03*lineOpacityMultiplier*opacityMultiplier)
						glDrawGroundCircle(x, y, z, property[2], circleDivs)
					end
				end
				glLineWidth(2.2-lineWidthMinus)
				if property[1] > 0 then
					glColor(1, .6, .3, .44*lineOpacityMultiplier*opacityMultiplier)
					glDrawGroundCircle(x, y, z, property[1], circleDivs)
				end
				if property[2] > 0 then
					glColor(0, 0, 1, .44*lineOpacityMultiplier*opacityMultiplier)
					glDrawGroundCircle(x, y, z, property[2], circleDivs)
				end
			end
		end
    end

    glDepthTest(false)
end

function widget:PlayerChanged(playerID)
    detectSpectatorView()
    return true
end

function widget:Initialize()
    detectSpectatorView()
    return true
end

function detectSpectatorView()
    local _, _, spec, teamId = spGetPlayerInfo(spGetMyPlayerID())

    if spec then
        spectatorMode = true
    end

    units = {}

    local visibleUnits = spGetAllUnits()
    if visibleUnits ~= nil then
        for _, unitID in ipairs(visibleUnits) do
            local unitDefID = GetUnitDefID(unitID)
            if unitDefID ~= nil then
                if isSpy(unitDefID) then
					addSpy(unitID, unitDefID)
                end

                if isGremlin(unitDefID) then
					addGremlin(unitID, unitDefID)
                end
            end
        end
    end
end
