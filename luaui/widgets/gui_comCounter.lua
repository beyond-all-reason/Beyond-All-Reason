function widget:GetInfo()
	return {
		name		= "Com Counter",
		desc		= "Shows the number of coms left",
		author		= "BD,Bluestone",
		date		= "Feb, 2014",
		license		= "GNU GPL, v2 or later",
		layer		= 0,
		enabled		= true
	}
end

---------------------------------------------------------------------------------------------------
--  Declarations
---------------------------------------------------------------------------------------------------

local flashIcon				= true
local markers				= false

local VFSFileExists = VFS.FileExists

local armcomDefID = UnitDefNames.armcom.id
local corcomDefID = UnitDefNames.corcom.id

local spGetMyTeamID			= Spring.GetMyTeamID
local spGetGameFrame		= Spring.GetGameFrame

local glTranslate			= gl.Translate
local glColor				= gl.Color
local glPushMatrix			= gl.PushMatrix
local glPopMatrix			= gl.PopMatrix
local glTexture				= gl.Texture
local glRect				= gl.Rect
local glTexRect				= gl.TexRect
local glText				= gl.Text
local glGetTextWidth		= gl.GetTextWidth
local glCreateList			= gl.CreateList
local glCallList			= gl.CallList
local glDeleteList			= gl.DeleteList

local textSize				= 12
local xPos, yPos
local xRelPos, yRelPos		= 0.80, 0.85
local vsx, vsy				= gl.GetViewSizes()
local check1x, check1y		= 6, 28
local check2x, check2y		= 6, 6
local allyComs				= 0
local enemyComs				= 0 -- if we are counting ourselves because we are a spec
local enemyComCount			= 0 -- if we are receiving a count from the gadget part (needs modoption on)
local prevEnemyComCount		= 0
local panelWidth 			= 47
local panelHeight 			= 50
local amISpec				= Spring.GetSpectatingState()
local myTeamID 				= spGetMyTeamID()
local myAllyTeamID			= Spring.GetMyAllyTeamID()
local inProgress			= spGetGameFrame() > 0
local countChanged			= true
local displayList			= nil
local flickerLastState		= nil
local is1v1					= Spring.GetTeamList() == 3 -- +1 because of gaia
local receiveCount			= (tostring(Spring.GetModOptions().mo_enemycomcount) == "1") or false
local comMarkers			= {}
local removeMarkerFrame		= -1
local lastMarkerFrame		= -1

---------------------------------------------------------------------------------------------------
--  Counting
---------------------------------------------------------------------------------------------------

function isCom(unitID,unitDefID)
	if not unitDefID and unitID then
		unitDefID =  Spring.GetUnitDefID(unitID)
	end
	if not unitDefID or not UnitDefs[unitDefID] or not UnitDefs[unitDefID].customParams then
		return false
	end
	return UnitDefs[unitDefID].customParams.iscommander ~= nil
end

function CheckStatus()
	--update my identity
	amISpec	= Spring.GetSpectatingState()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	myTeamID = Spring.GetMyTeamID()
end

function flicker()
	return spGetGameFrame() % 12 < 6
end 

function Recount()
	-- recount my own ally team coms
	allyComs = 0
	local myAllyTeamList = Spring.GetTeamList(myAllyTeamID)
	for _,teamID in ipairs(myAllyTeamList) do
		allyComs = allyComs + Spring.GetTeamUnitDefCount(teamID, armcomDefID) + Spring.GetTeamUnitDefCount(teamID, corcomDefID)
	end
	countChanged = true
	
	if amISpec then
		-- recount enemy ally team coms
		enemyComs = 0
		local allyTeamList = Spring.GetAllyTeamList()
		for _,allyTeamID in ipairs(allyTeamList) do
			if allyTeamID ~= myAllyTeamID then
				local teamList = Spring.GetTeamList(allyTeamID)
				for _,teamID in ipairs(teamList) do
					enemyComs = enemyComs + Spring.GetTeamUnitDefCount(teamID, armcomDefID) + Spring.GetTeamUnitDefCount(teamID, corcomDefID)
				end
			end
		end
	end
	
end

--------------------------------------------------------------------------------

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if not isCom(unitID,unitDefID) then
		return
	end
	
	--record com created
	local _,_,_,_,_,allyTeamID = Spring.GetTeamInfo(unitTeam)
	if allyTeamID == myAllyTeamID then
		allyComs = allyComs + 1
	elseif amISpec then
		enemyComs = enemyComs + 1
	end
	countChanged = true
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if not isCom(unitID,unitDefID) then
		return
	end
	
	--record com died
	local _,_,_,_,_,allyTeamID = Spring.GetTeamInfo(unitTeam)
	if allyTeamID == myAllyTeamID then
		allyComs = allyComs - 1
	elseif amISpec then
		enemyComs = enemyComs - 1
	end
	countChanged = true
end

-- BA does not allow sharing to enemy, so no need to check Given, Taken, etc

function widget:Initialize()
	--recount needed in case GameStart not called
	if Spring.GetGameFrame() > 0 then
		Recount()
	end
    
    --set position if it wasn't in config
    if not xPos or not yPos then
        xPos = 0.80
        yPos = 0.85
    end
end

function widget:GameStart()
	inProgress = true
	CheckStatus()
	Recount()
end

function widget:GameFrame(n)
	-- check if the team that we are spectating changed
	if amISpec and myTeamID ~= spGetMyTeamID() then
		CheckStatus()
		Recount()
	end
	
	-- check if we have received a TeamRulesParam from the gadget part
	if not amISpec and receiveCount then
		enemyComCount = Spring.GetTeamRulesParam(myTeamID, "enemyComCount")
		if enemyComCount ~= prevEnemyComCount then
			countChanged = true
			prevEnemyComCount = enemyComCount
		end
	end
	
	-- remove all markers
	if markers and n == removeMarkerFrame then
		for i=1,#comMarkers do
			Spring.MarkerErasePosition(comMarkers[i][1], comMarkers[i][2], comMarkers[i][3])
			comMarkers[i] = nil
		end
	end
end

function widget:PlayerChanged()
	-- probably not needed but meh, its cheap
	CheckStatus()
	Recount()
end

function widget:GameOver()
	inProgress = false
end

---------------------------------------------------------------------------------------------------
--  GUI
---------------------------------------------------------------------------------------------------

function widget:DrawScreen()
	if widgetHandler:InTweakMode() then
		return
	end
	if not inProgress then
		return
	end
	
	local flickerState = allyComs == 1 and flashIcon and flicker()
	if countChanged or flickerLastState ~= flickerState then
		countChanged = false
		CheckStatus()
		
		glDeleteList(displayList)
		-- regenerate the display list
		displayList = glCreateList( function()
			glTranslate(xPos, yPos, 0)
			--background
			glColor(0, 0, 0, 0.5)
			glRect(0, 0, panelWidth, panelHeight)
			--com pic
			if flickerState then
				glColor(1,0.6,0,0.6)
			else
				glColor(1,1,1,0.3)
			end
			if VFSFileExists('LuaUI/Images/comIcon.png') then
				glTexture('LuaUI/Images/comIcon.png')
			end
			glTexRect(panelWidth/2-34/2, 5, panelWidth/2+34/2, 5+40)
			glTexture(false)
			--ally coms
			if allyComs >0 then
				glColor(0,1,0,1)	
				local text = tostring(allyComs)
				local width = glGetTextWidth(text)*22
				glText(text, panelWidth/2 - width/2 + 1, 20, 22)
			end
			--enemy coms
			glColor(1,0,0,1)
			if amISpec then
				text = tostring(enemyComs)
				width = glGetTextWidth(text)*14
				glText(text, panelWidth - width - 3, 3, 14)
			elseif receiveCount then
				text = tostring(enemyComCount)
				width = glGetTextWidth(text)*14
				glText(text, panelWidth - width - 3, 3, 14)			
			end
		end)
		flickerLastState = flickerState
	end
	
	glPushMatrix()
	glCallList(displayList)
	glPopMatrix()
	
end

---------------------------------------------------------------------------------------------------
-- Tweak mode, settings, mouse stuff
---------------------------------------------------------------------------------------------------

function widget:TweakDrawScreen()
	glPushMatrix()
		glTranslate(xPos, yPos, 0)
		glColor(0, 0, 0, 0.5)
		glRect(0, 0, 100, panelHeight)
		drawCheckbox(check1x, check1y, markers, "Place Markers") 
		drawCheckbox(check2x, check2y, flashIcon, "Flashing Icon")
	glPopMatrix()
end

function drawCheckbox(x, y, state, text)
	glPushMatrix()
		glTranslate(x, y, 0)
		glColor(1, 1, 1, 0.2)
		glRect(0, 0, 16, 16)
		glColor(1, 1, 1, 1)
		if state then
			if VFSFileExists('LuaUI/Images/tick.png') then
				glTexture('LuaUI/Images/tick.png')
			end
			glTexRect(0, 0, 16, 16)
			glTexture(false)
		end
		glText(text, 20, 4, 9, "n")
	glPopMatrix()
end

function widget:IsAbove(mx, my)
	return mx > xPos and my > yPos and mx < xPos + panelWidth and my < yPos + panelHeight
end

function widget:MousePress(mx, my, button)
	if not widget:IsAbove(mx,my) then
		return false
	end
	
	local frame = Spring.GetGameFrame()
	if markers and frame > lastMarkerFrame + 2.5*30 then --prevent marker spam
		lastMarkerFrame = frame
		MarkComs()
	end
	return true
end

function MarkComs()
	local units = Spring.GetAllUnits()
	-- place a mark on each com
	for i=1,#units do
		if Spring.GetUnitAllyTeam(units[i]) == myAllyTeamID then
			if isCom(units[i],_) then
				local x,y,z = Spring.GetUnitPosition(units[i])
				Spring.MarkerAddPoint(x,y,z,"",true)
				comMarkers[#comMarkers+1] = {x,y,z}
				removeMarkerFrame = Spring.GetGameFrame() + 30*5
			end
		end
	end
end

function widget:TweakMousePress(mx, my)
	if widget:IsAbove(mx,my) then
		if mx > xPos+check1x and my > yPos+check1y and mx < (xPos+check1x+16) and my < (yPos+check1y+16) then
			markers = not markers
		elseif mx > xPos+check2x and my > yPos+check2y and mx < (xPos+check2x+16) and my < (yPos+check2y+16) then
			flashIcon = not flashIcon
		end
		return true
	end
end

function widget:TweakMouseMove(mx, my, dx, dy)
	xRelPos = xRelPos + dx/vsx
	yRelPos = yRelPos + dy/vsy
	xPos, yPos = xRelPos * vsx,yRelPos * vsy
	countChanged = true
end

function widget:ViewResize(newX,newY)
	vsx, vsy = newX, newY
	xPos, yPos = xRelPos * vsx,yRelPos * vsy
	countChanged = true
end

function widget:GetConfigData()
	return {xRelPos = xRelPos, yRelPos = yRelPos, markers = markers, flashIcon = flashIcon}
end

function widget:SetConfigData(data)
	xRelPos = data.xRelPos or xRelPos
	yRelPos = data.yRelPos or yRelPos
	xPos = yRelPos * vsx
	yPos = yRelPos * vsy
	markers = data.markers or markers
	flashIcon = data.flashIcon or flashIcon
end
