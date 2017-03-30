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


local customScale			= 1
local bgcorner				= ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"
local customPanelWidth 		= 46
local customPanelHeight 	= 39
local xRelPos, yRelPos		= 0.81, 0.963


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

local vsx, vsy				= gl.GetViewSizes()
local xPos, yPos            = xRelPos*vsx, yRelPos*vsy
local widgetScale			= customScale
local panelWidth 			= customPanelWidth
local panelHeight 			= customPanelHeight
local check1x, check1y		= 6, 28
local check2x, check2y		= 6, 6
local allyComs				= 0
local enemyComs				= 0 -- if we are counting ourselves because we are a spec
local enemyComCount			= 0 -- if we are receiving a count from the gadget part (needs modoption on)
local prevEnemyComCount		= 0
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

function widget:Shutdown()
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('comcounter')
	end
	
	if displayList ~= nil then
		glDeleteList(displayList)
	end
end

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
end

function widget:GameStart()
    inProgress = true
	CheckStatus()
	Recount()
end

function widget:GameFrame(n)
	-- turn on if not already (workaround for http://imolarpg.dyndns.org/trac/balatest/ticket/845#comment:3)
    if not inProgress then
        inProgress = true
		CheckStatus()
		Recount()        
    end
    
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
    widgetHandler:RemoveWidget(self)
end

---------------------------------------------------------------------------------------------------
--  GUI
---------------------------------------------------------------------------------------------------


local function DrawRectRound(px,py,sx,sy,cs)
	gl.TexCoord(0.8,0.8)
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)
	
	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)
	
	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)
	
	local offset = 0.05		-- texture offset, because else gaps could show
	local o = offset
	
	-- top left
	if py <= 0 or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, py+cs, 0)
	-- top right
	if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom left
	if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, sy-cs, 0)
	-- bottom right
	if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, sy-cs, 0)
end

function RectRound(px,py,sx,sy,cs)
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
	gl.Texture(false)
end


function widget:DrawScreen()
	if not inProgress then
    --    return
    end
	
	local flickerState = allyComs == 1 and flashIcon and flicker()
	if countChanged or flickerLastState ~= flickerState then
		countChanged = false
		CheckStatus()
		
		glDeleteList(displayList)
		-- regenerate the display list
		displayList = glCreateList( function()
			glColor(0, 0, 0, 0.66)
			RectRound(xPos, yPos, xPos+panelWidth, yPos+panelHeight, 6*widgetScale)
			
			local borderPadding = 3.5*widgetScale
			glColor(1,1,1,0.025)
			RectRound(xPos+borderPadding, yPos+borderPadding, xPos+panelWidth-borderPadding, yPos+panelHeight-borderPadding, 6*widgetScale)
			
			glTranslate(xPos, yPos, 0)
			--background
			--glColor(0, 0, 0, 0.5)
			--glRect(0, 0, panelWidth, panelHeight)
			
			
			if (WG['guishader_api'] ~= nil) then
				WG['guishader_api'].InsertRect(xPos,yPos,xPos+panelWidth,yPos+panelHeight,'comcounter')
			end

			--com pic
			if flickerState then
				glColor(1,0.6,0,0.6)
			else
				glColor(1,1,1,0.3)
			end
			if VFSFileExists('LuaUI/Images/comIcon.png') then
				glTexture('LuaUI/Images/comIcon.png')
			end
			
			local iconsize = math.min(panelWidth, panelHeight) * 0.7
			--glTexRect(panelWidth/2-34/2, 5, panelWidth/2+34/2, 5+40)
			glTexRect((panelWidth/2)-(iconsize/2), (panelHeight/2)-(iconsize/2), (panelWidth/2)+(iconsize/2), (panelHeight/2)+(iconsize/2))
			glTexture(false)
			if inProgress then
				--ally coms
				local textsize = iconsize*0.65
				if allyComs >0 then	
					local text = tostring(allyComs)
					local width = glGetTextWidth(text)*textsize
					glText('\255\001\255\001'..text, (panelWidth/2)-(width/2), (panelHeight/2)-(textsize/4), textsize, 'o')
				end
				--enemy coms
				glColor(1,0,0,1)
				textsize = textsize/1.35
				if amISpec then
					text = tostring(enemyComs)
					width = glGetTextWidth(text)*(panelWidth/3.5)
					glText(text, panelWidth-width-(textsize/3), (textsize/3), textsize)	
				elseif receiveCount then
					text = tostring(enemyComCount)
					width = glGetTextWidth(text)*(panelWidth/3.5)
					glText(text, panelWidth-width-(textsize/3), (textsize/3), textsize)	
				else
					text = 2
					width = glGetTextWidth(text)*(panelWidth/3.5)
					glText(text, panelWidth-width-(textsize/3), (textsize/3), textsize)			
				end
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
	
	local frame = Spring.GetGameFrame()
	if widget:IsAbove(mx,my) then
		if button == 1 and markers and frame > lastMarkerFrame + 2.5*30 then --prevent marker spam
			lastMarkerFrame = frame
			MarkComs()
		end
	end
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

function widget:TweakMousePress(mx, my, mb)
    if widgetHandler:InTweakMode() and widget:IsAbove(mx,my) then
		if mb == 1 then 
			if mx > xPos+check1x and my > yPos+check1y and mx < (xPos+check1x+16) and my < (yPos+check1y+16) then
				markers = not markers
			elseif mx > xPos+check2x and my > yPos+check2y and mx < (xPos+check2x+16) and my < (yPos+check2y+16) then
				flashIcon = not flashIcon
			end
		elseif mb == 2 or mb == 3 then
			return true
		end
	end
end


function widget:TweakMouseMove(mx, my, dx, dy)
    if xPos + dx >= -1 and xPos + panelWidth + dx - 1 <= vsx then 
		xRelPos = xRelPos + dx/vsx
	end
    if yPos + dy >= -1 and yPos + panelHeight + dy - 1<= vsy then 
		yRelPos = yRelPos + dy/vsy
	end
	xPos, yPos = xRelPos * vsx,yRelPos * vsy
	countChanged = true
end

function widget:GetTooltip(mx, my)
	if widget:IsAbove(mx,my) then
		return string.format("In CTRL+F11 mode: Hold \255\255\255\1middle mouse button\255\255\255\255 to drag the this display.\n\n"..
			"Small number in bottom right is enemy commander count.")
	end
end

function widget:ViewResize(newX,newY)
	vsx, vsy = newX, newY
	xPos, yPos = xRelPos * vsx,yRelPos * vsy
	countChanged = true
	
	widgetScale = (0.60 + (vsx*vsy / 5000000)) * customScale
	panelWidth 	= customPanelWidth * widgetScale
	panelHeight	= customPanelHeight * widgetScale
end

function widget:GetConfigData()
	return {xRelPos = xRelPos, yRelPos = yRelPos, markers = markers, flashIcon = flashIcon}
end

function widget:SetConfigData(data)
	xRelPos = data.xRelPos or xRelPos
	yRelPos = data.yRelPos or yRelPos
	xPos = xRelPos * vsx
	yPos = yRelPos * vsy
	markers = data.markers or markers
	flashIcon = data.flashIcon or flashIcon
end
