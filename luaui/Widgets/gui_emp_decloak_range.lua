local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name      = "EMP + decloak range",
        desc      = "When spy or gremlin is selected, it displays its decloak range (orange) and emp range (blue)",
        author    = "[teh]decay",
        date      = "14 feb 2015",
        license   = "The BSD License",
        layer     = 0,
        version   = 5,
        enabled   = true
    }
end

-- project page on github: https://github.com/jamerlan/spy_range

--Changelog
-- v2 [teh]decay Don't draw circles when GUI is hidden
-- v3 [teh]decay Added gremlin decloak range + set them on hold fire and hold pos
-- v4 Floris Added fade on camera distance changed to thicker and more transparant line style + options + onlyDrawRangeWhenSelected
-- v5 Floris: Renamed to EMP + decloak range and disabled autocloak

--------------------------------------------------------------------------------
-- OPTIONS
--------------------------------------------------------------------------------

local onlyDrawRangeWhenSelected	= true
local fadeOnCameraDistance		= true
local showLineGlow 				= true		-- a ticker but faint 2nd line will be drawn underneath
local opacityMultiplier			= 1.3
local fadeMultiplier			= 1.2		-- lower value: fades out sooner
local circleDivs				= 64		-- detail of range circle

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local glColor 				= gl.Color
local glLineWidth 			= gl.LineWidth
local glDepthTest			= gl.DepthTest
local glDrawGroundCircle	= gl.DrawGroundCircle
local GetUnitDefID			= Spring.GetUnitDefID
local lower                 = string.lower
local spGetAllUnits			= Spring.GetAllUnits
local spGiveOrderToUnit		= Spring.GiveOrderToUnit
local spGetCameraPosition 	= Spring.GetCameraPosition
local spValidUnitID			= Spring.ValidUnitID
local spGetUnitPosition		= Spring.GetUnitPosition
local spIsSphereInView		= Spring.IsSphereInView
local spIsUnitSelected		= Spring.IsUnitSelected

local CMD_MOVE_STATE		= CMD.MOVE_STATE
local cmdFireState			= CMD.FIRE_STATE

local diag					= math.diag

local spec, fullview = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()

local units = {}

local chobbyInterface

local isSpy = {}
local isGremlin = {}
for udid, ud in pairs(UnitDefs) do
    if string.find(ud.name, 'spy') then
        local selfdBlastId = WeaponDefNames[lower(ud['selfDExplosion'])].id
        isSpy[udid] = {
            ud.decloakDistance,
            WeaponDefs[selfdBlastId]['damageAreaOfEffect']
        }
    end
    if string.find(ud.name, 'armgremlin') then
        isGremlin[udid] = ud.decloakDistance
    end
end

local function addSpy(unitID, unitDefID)
	units[unitID] = { isSpy[unitDefID][1], isSpy[unitDefID][2] }  -- decloakdistance, selfdblastradius
end

local function addGremlin(unitID, unitDefID)
	units[unitID] = { isGremlin[unitDefID], 0 }   -- decloakdistance, 0
end

local function processGremlin(unitID)
    spGiveOrderToUnit(unitID, CMD_MOVE_STATE, { 0 }, 0) -- 0 == hold pos
    spGiveOrderToUnit(unitID, cmdFireState, { 0 }, 0) -- hold fire
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    if isSpy[unitDefID] then
		addSpy(unitID, unitDefID)
    end
    if isGremlin[unitDefID] then
		addGremlin(unitID, unitDefID)
        processGremlin(unitID)
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
    if units[unitID] then
        units[unitID] = nil
    end
end

function widget:UnitEnteredLos(unitID, unitTeam)
    if not fullview then
        local unitDefID = GetUnitDefID(unitID)
        if isSpy[unitDefID] then
			addSpy(unitID, unitDefID)
        end
        if isGremlin[unitDefID] then
			addGremlin(unitID, unitDefID)
        end
    end
end

function widget:UnitCreated(unitID, unitDefID, teamID, builderID)
	if not spValidUnitID(unitID) then return end --because units can be created AND destroyed on the same frame, in which case luaui thinks they are destroyed before they are created

    if isSpy[unitDefID] then
		addSpy(unitID, unitDefID)
    end
    if isGremlin[unitDefID] then
		addGremlin(unitID, unitDefID)
        processGremlin(unitID)
    end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
    if isSpy[unitDefID] then
		addSpy(unitID, unitDefID)
    end
    if isGremlin[unitDefID] then
		addGremlin(unitID, unitDefID)
        processGremlin(unitID)
    end
end


function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
    if isSpy[unitDefID] then
		addSpy(unitID, unitDefID)
    end
    if isGremlin[unitDefID] then
		addGremlin(unitID, unitDefID)
        processGremlin(unitID)
    end
end

function widget:UnitLeftLos(unitID, unitDefID, unitTeam)
    if not fullview then
        if units[unitID] then
            units[unitID] = nil
        end
    end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorldPreUnit()
	if chobbyInterface then return end
    if Spring.IsGUIHidden() then return end

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

local function resetUnits()
	units = {}
	local visibleUnits = spGetAllUnits()
	if visibleUnits ~= nil then
		for i=1,#visibleUnits do
			local unitID = visibleUnits[i]
			local unitDefID = GetUnitDefID(unitID)
			if isSpy[unitDefID] then
				addSpy(unitID, unitDefID)
			end
			if isGremlin[unitDefID] then
				addGremlin(unitID, unitDefID)
			end
		end
	end
end

function widget:PlayerChanged(playerID)
    local prevTeamID = myTeamID
    local prevFullview = fullview
    myTeamID = Spring.GetMyTeamID()
    myPlayerID = Spring.GetMyPlayerID()
    spec, fullview = Spring.GetSpectatingState()
    if playerID == myPlayerID and (fullview ~= prevFullview or myTeamID ~= prevTeamID) then
        resetUnits()
    end
end

function widget:Initialize()
    resetUnits()
end
