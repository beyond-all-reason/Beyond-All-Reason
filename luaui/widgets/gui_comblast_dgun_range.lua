function widget:GetInfo()
    return {
        name      = "Comblast & Dgun Range",
        desc      = "Shows the range of commander death explosion and dgun ranges",
        author    = "Bluestone, based on similar widgets by vbs, tfc, decay  (made fancy by Floris)",
        date      = "14 february 2015",
        license   = "GPL v3 or later",
        layer     = 0,
        enabled   = false  -- loaded by default
    }
end

--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

--/comranges_glow				-- toggles a faint glow on the line
--/comranges_nearbyenemy		-- toggles hiding of ranges when enemy is nearby

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local pairs					= pairs

local spGetUnitPosition     = Spring.GetUnitPosition
local spGetUnitDefID 		= Spring.GetUnitDefID
local spGetAllUnits			= Spring.GetAllUnits
local spGetSpectatingState 	= Spring.GetSpectatingState
local spGetMyPlayerID		= Spring.GetMyPlayerID
local spGetPlayerInfo		= Spring.GetPlayerInfo
local spGetGroundHeight		= Spring.GetGroundHeight
local spIsSphereInView		= Spring.IsSphereInView
local spValidUnitID			= Spring.ValidUnitID
local spGetCameraPosition	= Spring.GetCameraPosition
local spGetUnitNearestEnemy	= Spring.GetUnitNearestEnemy
local spIsGUIHidden			= Spring.IsGUIHidden

local glDepthTest 			= gl.DepthTest
local glDrawGroundCircle 	= gl.DrawGroundCircle
local glLineWidth 			= gl.LineWidth
local glColor				= gl.Color
local glTranslate			= gl.Translate
local glRotate				= gl.Rotate
local glText				= gl.Text
local glBlending			= gl.Blending

local GL_ALWAYS					= GL.ALWAYS
local GL_SRC_ALPHA				= GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA	= GL.ONE_MINUS_SRC_ALPHA

local comCenters = {}
local drawList
local amSpec = false
local inSpecFullView = false
local dgunRange	= WeaponDefNames["armcom_arm_disintegrator"].range + 2*WeaponDefNames["armcom_arm_disintegrator"].damageAreaOfEffect

--------------------------------------------------------------------------------
-- OPTIONS
--------------------------------------------------------------------------------

local hideOnDistantEnemy	= true
local fadeOnCameraDistance	= true
local opacityMultiplier		= 1
local fadeMultiplier		= 1.5		-- lower value: fades out sooner
local circleDivs			= 64		-- circle detail, when fading out it will lower this aswell (minimum always will be 40 anyway)
local blastRadius			= 360		-- com explosion
local showLineGlow 			= true		-- a ticker but faint 2nd line will be drawn underneath	
local showOnEnemyDistance	= 660
local fadeInDistance		= 360
local smoothoutTime			= 2			-- time to smoothout sudden changes (value = time between max and zero opacity)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



-- track coms --

function widget:Initialize()
    checkComs()
	checkSpecView()
    return true
end

function addCom(unitID)
	if not spValidUnitID(unitID) then return end --because units can be created AND destroyed on the same frame, in which case luaui thinks they are destroyed before they are created
	local x,y,z = Spring.GetUnitPosition(unitID)
    local teamID = Spring.GetUnitTeam(unitID)
    if x and teamID then
		comCenters[unitID] = {x,y,z}
    end
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
			local osClock = os.clock()
			local yg = spGetGroundHeight(x,z) 
			local draw = true
			local opacityMultiplier = 1
			oldOpacityMultiplier = opacityMultiplier
			-- check if com is off the ground
			if y-yg>10 then 
				draw = false
			-- check if is in view
			elseif not spIsSphereInView(x,y,z,blastRadius) then
				draw = false
			end
			if draw and hideOnDistantEnemy then
				local nearestEnemyUnitID = spGetUnitNearestEnemy(unitID,showOnEnemyDistance+fadeInDistance)
				if nearestEnemyUnitID then
					local ex,ey,ez = spGetUnitPosition(nearestEnemyUnitID)
					local xDifference = x - ex
					local yDifference = y - ey
					local zDifference = z - ez
					local distance = math.sqrt(xDifference*xDifference + yDifference*yDifference + zDifference*zDifference)
					if distance < blastRadius + showOnEnemyDistance then
						draw = true
						opacityMultiplier = 1 - (distance - showOnEnemyDistance) / fadeInDistance
						if opacityMultiplier > 1 then
							opacityMultiplier = 1
						elseif opacityMultiplier < 0 then
							opacityMultiplier = 0
						end
						oldOpacityMultiplier = opacityMultiplier
					end
				else
					opacityMultiplier = 0
					oldOpacityMultiplier = opacityMultiplier
					draw = false
				end
				
				-- smooth out sudden changes of enemy unit distance
				if comCenters[unitID] and comCenters[unitID][4] and comCenters[unitID][7] and opacityMultiplier ~= comCenters[unitID][7] and comCenters[unitID][6] and (osClock - comCenters[unitID][6]) < smoothoutTime then
					draw = true
					
					local opacityDifference = comCenters[unitID][7] - opacityMultiplier
					local opacityAddition = (1 - ((osClock - comCenters[unitID][6]) / smoothoutTime)) * opacityDifference
					
					opacityMultiplier = oldOpacityMultiplier + opacityAddition
					if opacityMultiplier > 1 then
						opacityMultiplier = 1
					elseif opacityMultiplier < 0 then
						opacityMultiplier = 0
						draw = false
					end
					oldOpacityMultiplier = comCenters[unitID][7]	-- keep old
					osClock = comCenters[unitID][6]					-- keep old
				end
			end
			comCenters[unitID] = {x,y,z,draw,opacityMultiplier,osClock,oldOpacityMultiplier}
		else
			--couldn't get position, check if its still a unit 
			if not spValidUnitID(unitID) then
				removeCom(unitID)
			end
		end
	end	
end

-- draw circles
function widget:DrawWorldPreUnit()
    if spIsGUIHidden() then return end
  
	local camX, camY, camZ = spGetCameraPosition()
	glDepthTest(true)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	for _,center in pairs(comCenters) do
		if center[4] then
			local xDifference = camX - center[1]
			local yDifference = camY - center[2]
			local zDifference = camZ - center[3]
			local camDistance = math.sqrt(xDifference*xDifference + yDifference*yDifference + zDifference*zDifference)
			
			local lineWidthMinus = (camDistance/2000)
			if lineWidthMinus > 2 then
				lineWidthMinus = 2
			end
			local lineOpacityMultiplier = 0.85
			if fadeOnCameraDistance then
				lineOpacityMultiplier = (1100/camDistance)*fadeMultiplier
				if lineOpacityMultiplier > 1 then
					lineOpacityMultiplier = 1
				end
			end
			if center[5] then
				lineOpacityMultiplier = lineOpacityMultiplier * center[5]
			end
			if lineOpacityMultiplier > 0.05 then
				
				local usedCircleDivs = math.floor(circleDivs*lineOpacityMultiplier)
				if usedCircleDivs < 48 then
					usedCircleDivs = 48
				end
				
				-- draw lines
				if showLineGlow then
					glLineWidth(10)
					glColor(1, 0.8, 0, .02*lineOpacityMultiplier*opacityMultiplier)
					glDrawGroundCircle(center[1], center[2], center[3], dgunRange, usedCircleDivs)
					
					glColor(1, 0, 0, .033*lineOpacityMultiplier*opacityMultiplier)
					glDrawGroundCircle(center[1], center[2], center[3], blastRadius, math.floor(usedCircleDivs*1.2))
				end
				glLineWidth(2.5-lineWidthMinus)
				glColor(1, 0.8, 0, .22*lineOpacityMultiplier*opacityMultiplier)
				glDrawGroundCircle(center[1], center[2], center[3], dgunRange, usedCircleDivs)
				
				glLineWidth(2.7-lineWidthMinus)
				glColor(1, 0, 0, .38*lineOpacityMultiplier*opacityMultiplier)
				glDrawGroundCircle(center[1], center[2], center[3], blastRadius, math.floor(usedCircleDivs*1.2))
			end
		end
	end
	glLineWidth(1)
	glDepthTest(false)
end

function widget:GetConfigData(data)
    savedTable = {}
    savedTable.showLineGlow			= showLineGlow
    savedTable.hideOnDistantEnemy	= hideOnDistantEnemy
    return savedTable
end

function widget:SetConfigData(data)
    if data.showLineGlow ~= nil 		then  showLineGlow			= data.showLineGlow end
    if data.hideOnDistantEnemy ~= nil 	then  hideOnDistantEnemy	= data.hideOnDistantEnemy end
end

function widget:TextCommand(command)
    if (string.find(command, "comranges_glow") == 1  and  string.len(command) == 14) then 
		showLineGlow = not showLineGlow
		if showLineGlow then
			Spring.Echo("Comblast & Dgun Range:  Glow enabled")
		else
			Spring.Echo("Comblast & Dgun Range:  Glow disabled")
		end
	end
    if (string.find(command, "comranges_nearbyenemy") == 1  and  string.len(command) == 21) then 
		hideOnDistantEnemy = not hideOnDistantEnemy
		if hideOnDistantEnemy then
			Spring.Echo("Comblast & Dgun Range:  Hides ranges when enemy is nearby")
		else
			Spring.Echo("Comblast & Dgun Range:  Shows ranges regardless of enemy distance ")
		end
	end
end
