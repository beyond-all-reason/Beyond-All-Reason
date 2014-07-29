function widget:GetInfo()
    return {
        name      = "Comblast & Dgun Range",
        desc      = "Shows the range of commander death explosion and dgun ranges",
        author    = "Bluestone, based on similar widgets by vbs, tfc, decay",
        date      = "11/2013",
        license   = "GPL v3 or later",
        layer     = 0,
        enabled   = false  -- loaded by default
    }
end

-- locals --

local pairs					= pairs
local sqrt                  = math.sqrt
local min                   = math.min
local max                   = math.max

local spGetUnitPosition     = Spring.GetUnitPosition
local spGetUnitDefID 		= Spring.GetUnitDefID
local spGetAllUnits			= Spring.GetAllUnits
local spGetSpectatingState 	= Spring.GetSpectatingState
local spGetMyPlayerID		= Spring.GetMyPlayerID
local spGetPlayerInfo		= Spring.GetPlayerInfo
local spGetGroundHeight		= Spring.GetGroundHeight
local spIsSphereInView		= Spring.IsSphereInView
local spValidUnitID			= Spring.ValidUnitID
local spIsGUIHidden         = Spring.IsGUIHidden
local spGetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local spGetUnitPosition     = Spring.GetUnitPosition


local glDepthTest 			= gl.DepthTest
local glDrawGroundCircle 	= gl.DrawGroundCircle
local glColor				= gl.Color
local GL_ALWAYS				= GL.ALWAYS

local circleDivs = 32
local blastRadius = 360 -- com explosion
local dgunRange = WeaponDefNames["armcom_arm_disintegrator"].range + 2*WeaponDefNames["armcom_arm_disintegrator"].damageAreaOfEffect

local comCenters = {}
local drawList
local amSpec = false
local inSpecFullView = false


-- track coms --

function widget:Initialize()
    widgetHandler:RegisterGlobal('SetOpacity_Comblast_DGun_Range', SetOpacity)

    checkComs()
	checkSpecView()
    return true
end

function addCom(unitID)
	if not spValidUnitID(unitID) then return end --because units can be created AND destroyed on the same frame, in which case luaui thinks they are destroyed before they are created
	local x,y,z = Spring.GetUnitPosition(unitID)
	comCenters[unitID] = {x,y,z,false,0}
end

function removeCom(unitID)
	comCenters[unitID] = nil
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    if UnitDefs[unitDefID].customParams.iscommander == "1" then
        addCom(unitID)
    end
end

function widget:UnitCreated(unitID, unitDefID, teamID, builderID)
    if UnitDefs[unitDefID].customParams.iscommander == "1" then
        addCom(unitID)
    end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
    if UnitDefs[unitDefID].customParams.iscommander == "1" then
        addCom(unitID)
    end
end


function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
    if UnitDefs[unitDefID].customParams.iscommander == "1" then
        addCom(unitID)
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    if comCenters[unitID] then
        removeCom(unitID)
    end
end

function widget:UnitEnteredLos(unitID, unitTeam)
    if not amSpec then
        local unitDefID = spGetUnitDefID(unitID)
        if UnitDefs[unitDefID].customParams.iscommander == "1" then
            addCom(unitID)
        end
    end
end

function widget:UnitLeftLos(unitID, unitDefID, unitTeam)
    if not amSpec then
        if comCenters[unitID] then
            removeCom(unitID)
        end
    end
end

function widget:PlayerChanged(playerID)
    checkSpecView()
    return true
end

function widget:GameOver()
    widgetHandler:DeregisterGlobal('SetOpacity_Comblast_DGun_Range', SetOpacity)
	widgetHandler:RemoveWidget()
end

function checkSpecView()
	--check if we became a spec
    local _,_,spec,_ = spGetPlayerInfo(spGetMyPlayerID())
    if spec ~= amSpec then
        amSpec = spec 
		checkComs()
    end
end

function checkComs()
	--remake list of coms
	for k,_ in pairs(comCenters) do
		comCenters[k] = nil
	end
	
    local visibleUnits = spGetAllUnits()
    if visibleUnits ~= nil then
        for _, unitID in ipairs(visibleUnits) do
            local unitDefID = spGetUnitDefID(unitID)
            if unitDefID and UnitDefs[unitDefID].customParams.iscommander == "1" then
                addCom(unitID)
            end
        end
    end
end


-- draw -- 
 
-- map out what to draw
function widget:GameFrame(n)
	-- check if we are in spec full view
	local _, specFullView, _ = spGetSpectatingState()
    if specFullView ~= inSpecFullView then
		checkComs()
		inSpecFullView = specFullView
    end

	-- check com movement
	for unitID in pairs(comCenters) do
		local x,y,z = spGetUnitPosition(unitID)
		if x then
			local yg = spGetGroundHeight(x,z) 
			local draw = true
            local opacity 
            local wantedOpacity
            -- check if there is an enemy unit nearby
            local enemyUnitID = spGetUnitNearestEnemy(unitID,2*blastRadius,false)
			if enemyUnitID then
				local ex,ey,ez = spGetUnitPosition(enemyUnitID)
				local distance = sqrt((x-ex)^2 + (y-ey)^2 + (z-ez)^2)
                wantedOpacity = 0.8 - 0.8*max(distance-blastRadius,0)/blastRadius
            else
                wantedOpacity = 0
            end
            opacity = comCenters[unitID][5]*(29/30) +  wantedOpacity*(1/30) --change gently
			-- check if com is off the ground
			if y-yg>10 then 
				draw = false
			-- check if is in view
			elseif not spIsSphereInView(x,y,z,blastRadius) then
				draw = false
			end
			comCenters[unitID] = {x,y,z,draw,opacity}
		else
			--couldn't get position, check if its still a unit 
			if not spValidUnitID(unitID) then
				removeCom(unitID)
			end
		end
	end	
end

-- opacity control
local darkOpacity = 0
local lightOpacity = 0
function SetOpacity(dark, light)
    darkOpacity = dark
    lightOpacity = light
end

-- draw circles
function widget:DrawWorldPreUnit()
    if spIsGUIHidden() then return end
	glDepthTest(true)
	for _,center in pairs(comCenters) do
		if center[4] then
			glColor(1, 0.8, 0, min(center[5],lightOpacity))
			glDrawGroundCircle(center[1], center[2], center[3], dgunRange, circleDivs)
			glColor(1, 0, 0, min(center[5],darkOpacity))
			glDrawGroundCircle(center[1], center[2], center[3], blastRadius, circleDivs)
		end
	end
	glDepthTest(false)
end
