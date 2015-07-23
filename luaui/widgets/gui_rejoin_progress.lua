function widget:GetInfo()
  return {
    name      = "Rejoin Progress Bar",
    desc      = "v1.132 Show the progress of rejoining and temporarily turn-off Text-To-Speech while rejoining",
    author    = "msafwan (use UI from KingRaptor's Chili-Vote) ",
    date      = "Oct 10, 2012",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    experimental = false,
    enabled   = true, --  loaded by default?
	--handler = true, -- allow this widget to use 'widgetHandler:FindWidget()'
  }
end

local customScale			= 1
local bgcorner				= ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"
local barbg					= ":n:"..LUAUI_DIRNAME.."Images/resbar.dds"

local bgmargin				= 0.22

local customPanelWidth 		= 105
local customPanelHeight 	= 39

local xRelPos, yRelPos		= 0.92, 0.963
local vsx, vsy				= gl.GetViewSizes()
local widgetScale			= customScale
local panelWidth 			= customPanelWidth
local panelHeight 			= customPanelHeight
local xPos, yPos            = xRelPos*vsx, yRelPos*vsy

--------------------------------------------------------------------------------
--Crude Documentation-----------------------------------------------------------
--How it meant to work:
--1) GameProgress return serverFrame --> IF I-am-behind THEN activate chili UI ELSE de-activate chili UI --> Update the estimated-time-of-completion every second.
--2) LuaRecvMsg return timeDifference --> IF I-am-behind THEN activate chili UI ELSE nothing ---> Update the estimated-time-of-completion every second.
--3) at GameStart send LuaMsg containing GameStart's UTC.

--Others: some tricks to increase efficiency, bug fix, ect
--------------------------------------------------------------------------------
--Localize Spring function------------------------------------------------------
local spGetSpectatingState = Spring.GetSpectatingState
--------------------------------------------------------------------------------
--Chili Variable----------------------------------------------------------------- ref: gui_chili_vote.lua by KingRaptor
local Chili
local Button
local Label
local Window
local Panel
local TextBox
local Image
local Progressbar
local Control
local Font

-- elements
local window, stack_main, label_title
local stack_vote, label_vote, button_vote, progress_vote

local voteCount, voteMax

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
--------------------------------------------------------------------------------
--Calculator Variable------------------------------------------------------------
local serverFrameRate_G = 30 --//constant: assume server run at x1.0 gamespeed. 
local serverFrameNum1_G = nil --//variable: get the latest server's gameFrame from GameProgress() and do work with it.  
local oneSecondElapsed_G = 0 --//variable: a timer for 1 second, used in Update(). Update UI every 1 second.
local myGameFrame_G = 0 --//variable: get latest my gameFrame from GameFrame() and do work with it.
local myLastFrameNum_G = 0 --//variable: used to calculate local game-frame rate.
local ui_active_G = false --//variable:indicate whether UI is shown or hidden.
local averageLocalSpeed_G = {sumOfSpeed= 0, sumCounter= 0} --//variable: store the local-gameFrame speeds so that an average can be calculated. 
local defaultAverage_G = 30 --//constant: Initial/Default average is set at 30gfps (x1.0 gameSpeed)
local simpleMovingAverageLocalSpeed_G = {storage={},index = 1, runningAverage=defaultAverage_G} --//variable: for calculating rolling average. Initial/Default average is set at 30gfps (x1.0 gameSpeed)
--------------------------------------------------------------------------------
--Variable for fixing GameProgress delay at rejoin------------------------------
local myTimestamp_G = 0 --//variable: store my own timestamp at GameStart
local serverFrameNum2_G = nil --//variable: the expected server-frame of current running game
local submittedTimestamp_G = {} --//variable: store all timestamp at GameStart submitted by original players (assuming we are rejoining)
local functionContainer_G = function(x) end --//variable object: store a function 
local myPlayerID_G = 0
local gameProgressActive_G = false --//variable: signal whether GameProgress has been updated.
local iAmReplay_G = false
--------------------------------------------------------------------------------
--For testing GUI---------------------------------------------------------------
local forceDisplay = nil
--------------------------------------------------------------------------------
 

function RectRound(px,py,sx,sy,cs)
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	glRect(px+cs, py, sx-cs, sy)
	glRect(sx-cs, py+cs, sx, sy-cs)
	glRect(px+cs, py+cs, px, sy-cs)
	
	if py <= 0 or px <= 0 then glTexture(false) else glTexture(bgcorner) end
	glTexRect(px, py+cs, px+cs, py)		-- top left
	
	if py <= 0 or sx >= vsx then glTexture(false) else glTexture(bgcorner) end
	glTexRect(sx, py+cs, sx-cs, py)		-- top right
	
	if sy >= vsy or px <= 0 then glTexture(false) else glTexture(bgcorner) end
	glTexRect(px, sy-cs, px+cs, sy)		-- bottom left
	
	if sy >= vsy or sx >= vsx then glTexture(false) else glTexture(bgcorner) end
	glTexRect(sx, sy-cs, sx-cs, sy)		-- bottom right
	
	glTexture(false)
end

local function ActivateGUI_n_TTS (frameDistanceToFinish, ui_active, altThreshold)
	if frameDistanceToFinish >= (altThreshold or 120) then
		if not ui_active then
			--screen0:AddChild(window)
			ui_active = true
		end
	elseif frameDistanceToFinish < (altThreshold or 120) then
		if ui_active then
			--screen0:RemoveChild(window)
			ui_active = false
		end
	end
	return ui_active
end

function widget:GameProgress(serverFrameNum) --this function run 3rd. It read the official serverFrameNumber
	local myGameFrame = myGameFrame_G
	local ui_active = ui_active_G
	-----localize--

	local serverFrameNum1 = serverFrameNum
	local frameDistanceToFinish = serverFrameNum1-myGameFrame
	ui_active = ActivateGUI_n_TTS (frameDistanceToFinish, ui_active)
	
	-----return--
	serverFrameNum1_G = serverFrameNum1
	ui_active_G = ui_active
	gameProgressActive_G = true
end

function widget:Update(dt) --this function run 4th. It update the progressBar
	if ui_active_G then
		oneSecondElapsed_G = oneSecondElapsed_G + dt
		if oneSecondElapsed_G >= 1 then --wait for 1 second period
			-----var localize-----
			local serverFrameNum1 = serverFrameNum1_G
			local serverFrameNum2 = serverFrameNum2_G
			local oneSecondElapsed = oneSecondElapsed_G
			local myLastFrameNum = myLastFrameNum_G
			local serverFrameRate = serverFrameRate_G
			local myGameFrame = myGameFrame_G		
			local simpleMovingAverageLocalSpeed = simpleMovingAverageLocalSpeed_G
			-----localize
			
			local serverFrameNum = serverFrameNum1 or serverFrameNum2 --use FrameNum from GameProgress if available, else use FrameNum derived from LUA_msg.
			serverFrameNum = serverFrameNum + serverFrameRate*oneSecondElapsed -- estimate Server's frame number after each widget:Update() while waiting for GameProgress() to refresh with actual value.
			local frameDistanceToFinish = serverFrameNum-myGameFrame

			local myGameFrameRate = (myGameFrame - myLastFrameNum) / oneSecondElapsed
			--Method1: simple average
			--[[
			averageLocalSpeed_G.sumOfSpeed = averageLocalSpeed_G.sumOfSpeed + myGameFrameRate -- try to calculate the average of local gameFrame speed.
			averageLocalSpeed_G.sumCounter = averageLocalSpeed_G.sumCounter + 1
			myGameFrameRate = averageLocalSpeed_G.sumOfSpeed/averageLocalSpeed_G.sumCounter -- using the average to calculate the estimate for time of completion.
			--]]
			--Method2: simple moving average
			myGameFrameRate = SimpleMovingAverage(myGameFrameRate, simpleMovingAverageLocalSpeed) -- get our average frameRate
			
			local timeToComplete = frameDistanceToFinish/myGameFrameRate -- estimate the time to completion.
			local timeToComplete_string = "?/?"
			
			local minute, second = math.modf(timeToComplete/60) --second divide by 60sec-per-minute, then saperate result from its remainder
			second = 60*second --multiply remainder with 60sec-per-minute to get second back.
			timeToComplete_string = string.format ("Time Remaining: %d:%02d" , minute, second)
		
			--progress_vote:SetCaption(timeToComplete_string)
			--rogress_vote:SetValue(myGameFrame/serverFrameNum)
			
			oneSecondElapsed = 0
			myLastFrameNum = myGameFrame
			
			if serverFrameNum1 then serverFrameNum1 = serverFrameNum --update serverFrameNum1 if value from GameProgress() is used,
			else serverFrameNum2 = serverFrameNum end --update serverFrameNum2 if value from LuaRecvMsg() is used.
			-----return
			serverFrameNum1_G = serverFrameNum1
			serverFrameNum2_G = serverFrameNum2
			oneSecondElapsed_G = oneSecondElapsed
			myLastFrameNum_G = myLastFrameNum
			simpleMovingAverageLocalSpeed_G = simpleMovingAverageLocalSpeed
		end
	end
end

local function RemoveLUARecvMsg(n)
	if n > 150 then
		iAmReplay_G = nil
		spGetSpectatingState = nil --de-reference the function so that garbage collector can clean it up.
		widgetHandler:RemoveCallIn("RecvLuaMsg") --remove unused method for increase efficiency after frame> timestampLimit (150frame or 5 second).
		functionContainer_G = function(x) end --replace this function with an empty function/method
	end 
end

function widget:GameFrame(n)
	myGameFrame_G = n
	functionContainer_G(n) --function that are able to remove itself. Reference: gui_take_reminder.lua (widget by EvilZerggin, modified by jK)
end

function widget:DrawScreen()
	 if ui_active_G and myGameFrame_G ~= nil and myGameFrame_G > 1 and serverFrameNum1_G ~= nil then
		glPushMatrix()
			glColor(0,0,0,0.6)
			glCallList(backgroundList)
			local progress = myGameFrame_G / serverFrameNum1_G
			if progress < 0 then 
				progress = 0
			end
			glTexture(barbg)
			glColor(1,1,1,0.13)
			glTexRect(math.floor(xPos+(panelHeight*bgmargin*2)+((panelWidth*(1-bgmargin)))), math.floor(yPos+(panelHeight*(1-bgmargin))), math.floor(xPos+(panelHeight*bgmargin)), math.floor(yPos+(panelHeight/2.1+(panelHeight*bgmargin))))
			glColor(0.18,1,0.18,0.95)
			glTexRect(math.floor(xPos+(panelHeight*bgmargin)), math.floor(yPos+(panelHeight/2.1+(panelHeight*bgmargin))), math.floor(xPos+(panelHeight*bgmargin*2)+((panelWidth*(1-bgmargin))*progress)), math.floor(yPos+(panelHeight*(1-bgmargin))))
		glPopMatrix()
	elseif (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('rejoinprogress')
	end
end

--//thanks to Rafal[0K] for pointing to the rolling average idea.
function SimpleMovingAverage(myGameFrameRate, simpleMovingAverageLocalSpeed)
	--//remember current frameRate, and advance table index by 1
	local index = (simpleMovingAverageLocalSpeed.index) --retrieve current index.
	simpleMovingAverageLocalSpeed.storage[index] = myGameFrameRate --remember current frameRate at current index.
	simpleMovingAverageLocalSpeed.index = simpleMovingAverageLocalSpeed.index +1 --advance index by 1.
	--//wrap table index around. Create a circle
	local poolingSize = 10 --//number of sample. note: simpleMovingAverage() is executed every second, so the value represent an average spanning 10 second.
	if (simpleMovingAverageLocalSpeed.index == (poolingSize + 2)) then --when table out-of-bound:
		simpleMovingAverageLocalSpeed.index = 1 --wrap the table index around (create a circle of 150 + 1 (ie: poolingSize plus 1 space) entry).
	end
	--//update averages
	index = (simpleMovingAverageLocalSpeed.index) --retrieve an index advanced by 1.
	local oldAverage = (simpleMovingAverageLocalSpeed.storage[index] or defaultAverage_G) --retrieve old average or use initial/default average as old average.
	simpleMovingAverageLocalSpeed.runningAverage = simpleMovingAverageLocalSpeed.runningAverage + myGameFrameRate/poolingSize - oldAverage/poolingSize --calculate average: add new value, remove old value. Ref: http://en.wikipedia.org/wiki/Moving_average#Simple_moving_average
	local avgGameFrameRate = simpleMovingAverageLocalSpeed.runningAverage -- replace myGameFrameRate with its average value.

	return avgGameFrameRate, simpleMovingAverageLocalSpeed
end

function createBackgroundList()
	if backgroundList ~= nil then
		glDeleteList(backgroundList)
	end
	backgroundList = glCreateList( function()
		RectRound(xPos,yPos,xPos+panelWidth,yPos+panelHeight,6)
		local text = 'Catching up...'
		local width = glGetTextWidth(text)*(panelHeight/3)
		glText('\255\255\255\255'..text, xPos+(panelHeight*bgmargin), yPos+(panelHeight*bgmargin), panelHeight/3, 'o')
	end)
end

----------------------------------------------------------
--Chili--------------------------------------------------
function widget:Initialize()
	functionContainer_G = RemoveLUARecvMsg
	myPlayerID_G = Spring.GetMyPlayerID()
	iAmReplay_G = Spring.IsReplay()
	
	createBackgroundList()
	--[[ setup Chili
	Chili = WG.Chili
	Button = Chili.Button
	Label = Chili.Label
	Colorbars = Chili.Colorbars
	Window = Chili.Window
	StackPanel = Chili.StackPanel
	Image = Chili.Image
	Progressbar = Chili.Progressbar
	Control = Chili.Control
	screen0 = Chili.Screen0
	]]--
	--create main Chili elements
	-- local height = tostring(math.floor(screenWidth/screenHeight*0.35*0.35*100)) .. "%"
	-- local y = tostring(math.floor((1-screenWidth/screenHeight*0.35*0.35)*100)) .. "%"
	local screenWidth, screenHeight = Spring.GetWindowGeometry()
	local y = screenWidth*2/11 + 32
	-- local labelHeight = 24
	-- local fontSize = 16
--[[
	window = Window:New{
		--parent = screen0,
		name   = 'rejoinProgress';
		color = {0, 0, 0, 0},
		width = 260,
		height = 60,
		left = 2, --dock left?
		y = y, --halfway on screen?
		dockable = true,
		draggable = false, --disallow drag to avoid capturing mouse click
		resizable = false,
		tweakDraggable = true,
		tweakResizable = true,
		minWidth = MIN_WIDTH, 
		minHeight = MIN_HEIGHT,
		padding = {0, 0, 0, 0},
		savespace = true, --probably could save space?
		--itemMargin  = {0, 0, 0, 0},
	}
	stack_main = StackPanel:New{
		parent = window,
		resizeItems = true;
		orientation   = "vertical";
		height = "100%";
		width =  "100%";
		padding = {0, 0, 0, 0},
		itemMargin  = {0, 0, 0, 0},
	}
	label_title = Label:New{
		parent = stack_main,
		autosize=false;
		align="center";
		valign="top";
		caption = '';
		height = 16,
		width = "100%";
	}
	progress_vote = Progressbar:New{
		parent = stack_main,
		x		= "0%",
		y 		= '40%', --position at 40% of the window's height
		width   = "100%"; --maximum width
		height	= "100%",
		max     = 1;
		caption = "?/?";
		color   =  {0.9,0.15,0.2,1}; --Red, {0.2,0.9,0.3,1} --Green
	}
	progress_vote:SetValue(0)
	voteCount = 0
	voteMax = 1	-- protection against div0
	label_title:SetCaption("Catching up.. Please Wait")
	]]--
	
	if forceDisplay then
		ActivateGUI_n_TTS (1, false, false, 0) --force GUI to display for testing
		return
	end	
end

----------------------------------------------------------
--fix for Game Progress delay-----------------------------
function widget:RecvLuaMsg(bigMsg, playerID) --this function run 2nd. It read the LUA timestamp
	if forceDisplay then
		ActivateGUI_n_TTS (1, false, false, 0) --force GUI to display for testing
		return
	end
	
	if gameProgressActive_G or iAmReplay_G then --skip LUA message if gameProgress is already active OR game is a replay
		return false 
	end

	local iAmSpec = spGetSpectatingState()
	local myMsg = (playerID == myPlayerID_G)
	if (myMsg or iAmSpec) then
		if bigMsg:sub(1,9) == "rejnProg " then --check for identifier
			-----var localize-----
			local ui_active = ui_active_G
			local submittedTimestamp = submittedTimestamp_G
			local myTimestamp = myTimestamp_G
			-----localize
			
			local timeMsg = bigMsg:sub(10) --saperate time-message from the identifier
			local systemSecond = tonumber(timeMsg)
			--Spring.Echo(systemSecond ..  " B")
			submittedTimestamp[#submittedTimestamp +1] = systemSecond --store all submitted timestamp from each players
			local sumSecond= 0
			for i=1, #submittedTimestamp,1 do
				sumSecond = sumSecond + submittedTimestamp[i]
			end
			--Spring.Echo(sumSecond ..  " C")
			local avgSecond = sumSecond/#submittedTimestamp
			--Spring.Echo(avgSecond ..  " D")
			local secondDiff = myTimestamp - avgSecond
			--Spring.Echo(secondDiff ..  " E")
			local frameDiff = secondDiff*30
			
			local serverFrameNum2 = frameDiff --this value represent the estimate difference in frame when everyone was submitting their timestamp at game start. Therefore the difference in frame will represent how much frame current player are ahead of us.
			ui_active = ActivateGUI_n_TTS (frameDiff, ui_active, 1800)
			
			-----return
			ui_active_G = ui_active
			serverFrameNum2_G = serverFrameNum2
			submittedTimestamp_G = submittedTimestamp
		end
	end
end

function widget:GameStart() --this function run 1st, before any other function. It send LUA timestamp
	--local format = "%H:%M" 
	local currentTime = os.date("!*t") --ie: clock on "gui_epicmenu.lua" (widget by CarRepairer), UTC & format: http://lua-users.org/wiki/OsLibraryTutorial
	local systemSecond = currentTime.hour*3600 + currentTime.min*60 + currentTime.sec
	local myTimestamp = systemSecond
	--Spring.Echo(systemSecond ..  " A")
	local timestampMsg = "rejnProg " .. systemSecond --currentTime --create a timestamp message
	Spring.SendLuaUIMsg(timestampMsg) --this message will remain in server's cache as a LUA message which rejoiner can intercept. Thus allowing the game to leave a clue at game start for latecomer.  The latecomer will compare the previous timestamp with present and deduce the catch-up time.

	------return
	myTimestamp_G = myTimestamp
end


function widget:GetTooltip(mx, my)
	if widget:IsAbove(mx,my) then
		return string.format("Hold \255\255\255\1middle mouse button\255\255\255\255 to drag this display.\n\n"..
			"Displays where in the game you are.\n\n"..
			"Only shows for games that are still being played.")
	end
end


function widget:ViewResize(newX,newY)
	vsx, vsy = newX, newY
	xPos, yPos = xRelPos * vsx,yRelPos * vsy
	countChanged = true
	
	widgetScale = (0.60 + (vsx*vsy / 5000000)) * customScale
	panelWidth 	= customPanelWidth * widgetScale
	panelHeight	= customPanelHeight * widgetScale
	
	createBackgroundList()
end

function processGuishader()
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(xPos, yPos, xPos+panelWidth, yPos+panelHeight, 'rejoinprogress')
	end
end

function widget:Shutdown()
	if backgroundList ~= nil then
		glDeleteList(backgroundList)
	end
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('rejoinprogress')
	end
end


function widget:IsAbove(mx, my)
	return mx > xPos and my > yPos and mx < xPos + panelWidth and my < yPos + panelHeight
end

function widget:MousePress(mx, my, button)
	if ui_active_G then
		if widget:IsAbove(mx,my) then
			if button == 2 then
				return true
			else 
				return false
			end
		end
	end
end

function widget:MouseMove(mx, my, dx, dy)
    if xPos + dx >= 0 and xPos + panelWidth + dx <= vsx then 
		xRelPos = xRelPos + dx/vsx
	end
    if yPos + dy >= 0 and yPos + panelHeight + dy <= vsy then 
		yRelPos = yRelPos + dy/vsy
	end
	xPos, yPos = xRelPos * vsx,yRelPos * vsy
	processGuishader()
	createBackgroundList()
end


function widget:GetConfigData()
	return {xRelPos = xRelPos, yRelPos = yRelPos}
end

function widget:SetConfigData(data)
	xRelPos = data.xRelPos or xRelPos
	yRelPos = data.yRelPos or yRelPos
	xPos = xRelPos * vsx
	yPos = yRelPos * vsy
end
