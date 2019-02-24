--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



function widget:GetInfo()
	return {
		name      = "AdvPlayersList",
		desc      = "Playerlist. Use tweakmode (ctrl+F11) to customize.",
		author    = "Marmoth. (spiced up by Floris)",
		date      = "25 april 2015",
		version   = "22.0",
		license   = "GNU GPL, v2 or later",
		layer     = -4,
		enabled   = true,  --  loaded by default?
	}
end

--Changelog
-- before v8.0 developed outside of BA by Marmoth
-- v9.0 (Bluestone): modifications to deal with twice as many players/specs; specs are rendered in a small font and cpu/ping does not show for them. 
-- v9.1 ([teh]decay): added notification about shared resources
-- v10  (Bluestone): Better use of opengl for a big speed increase & less spaghetti
-- v11  (Bluestone): Get take info from cmd_idle_players
-- v11.1 (Bluestone): Added TrueSkill column
-- v11.2 (Bluestone): Remove lots of hardcoded crap about module names/pictures
-- v11.3 (Bluestone): More cleaning up
-- v11.4 (Bluestone): Mute people with ctrl+click on their name
-- v12   (Floris): Restyled looks + added imageDirectory var + HD-ified rank and some other icons
-- v13   (Floris): Added scale buttons. Added grey cpu/ping icons for spectators. Resized elements. Textured bg. Spec label click to unfold/fold. Added guishader. Lockcamera on doubleclick. Ping in ms/sec/min. Shows dot icon in front of tracked player. HD-ified lots of other icons. Speccing/dead player keep their color. Improved e/m share gui responsiveness. + removed the m_spec option
-- v14   (Floris): Added country flags + Added camera icons for locked camera + specs show bright when they are broadcasting new lockcamera positions + bugfixed lockcamera for specs. Added small gaps between in tweakui icons. Auto scales with resolution changes.
-- v15   (Floris): Integrated LockCamers widget code
-- v16	 (Floris): Added chips next to gambling-spectators for betting system
-- v17	 (Floris): Added alliances display and button and /cputext option
-- v18	 (Floris): Player system shown on tooltip + added FPS counter + replaced allycursor data with activity gadget data (all these features need gadgets too)
-- v19   (Floris): added player resource bars
-- v20   (Floris): added /alwayshidespecs + fixed drawing when playerlist is at the leftside of the screen
-- v21   (Floris): toggles LoS and /specfullview when camera tracking a player
-- v22   (Floris): added auto collapse function

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local customScale			= 1
local customScaleStep		= 0.025
local pointDuration    		= 40
local cpuText				= false
local drawAlliesLabel = false
local alwaysHideSpecs = false
local lockcameraHideEnemies = true 			-- specfullview
local lockcameraLos = true					-- togglelos
local collapsable = false

--------------------------------------------------------------------------------
-- SPEED UPS
--------------------------------------------------------------------------------

local Spring_GetGameSeconds      = Spring.GetGameSeconds
local Spring_GetGameFrame	     = Spring.GetGameFrame
local Spring_GetAllyTeamList     = Spring.GetAllyTeamList
local Spring_GetTeamInfo         = Spring.GetTeamInfo
local Spring_GetTeamList         = Spring.GetTeamList
local Spring_GetPlayerInfo       = Spring.GetPlayerInfo
local Spring_GetPlayerList       = Spring.GetPlayerList
local Spring_GetTeamColor        = Spring.GetTeamColor
local Spring_GetLocalAllyTeamID  = Spring.GetLocalAllyTeamID
local Spring_GetLocalTeamID      = Spring.GetLocalTeamID
local Spring_GetLocalPlayerID    = Spring.GetLocalPlayerID
local Spring_ShareResources      = Spring.ShareResources
local Spring_GetTeamUnitCount    = Spring.GetTeamUnitCount
local Echo                       = Spring.Echo
local Spring_GetTeamResources    = Spring.GetTeamResources
local Spring_SendCommands        = Spring.SendCommands
local Spring_GetConfigInt        = Spring.GetConfigInt
local Spring_GetMouseState       = Spring.GetMouseState
local Spring_GetAIInfo           = Spring.GetAIInfo
local Spring_GetTeamRulesParam   = Spring.GetTeamRulesParam
local Spring_IsGUIHidden		 = Spring.IsGUIHidden
local Spring_GetDrawFrame		 = Spring.GetDrawFrame
local Spring_GetMyTeamID		 = Spring.GetMyTeamID
local Spring_AreTeamsAllied		 = Spring.AreTeamsAllied

local GetCameraState = Spring.GetCameraState
local SetCameraState = Spring.SetCameraState
local GetCameraNames = Spring.GetCameraNames

local gl_Texture		= gl.Texture
local gl_Rect			= gl.Rect
local gl_TexRect	 	= gl.TexRect
local gl_Color			= gl.Color
local gl_CreateList		= gl.CreateList
local gl_BeginEnd		= gl.BeginEnd
local gl_DeleteList		= gl.DeleteList
local gl_CallList		= gl.CallList
local gl_Text			= gl.Text
local gl_GetTextWidth	= gl.GetTextWidth
local gl_GetTextHeight	= gl.GetTextHeight

--------------------------------------------------------------------------------
-- IMAGES
--------------------------------------------------------------------------------

local imageDirectory  = ":n:LuaUI/Images/advplayerslist/"

local flagsDirectory  = imageDirectory.."flags/"

local bgcorner        = "LuaUI/Images/bgcorner.png"

local pics = {
	chipPic         = imageDirectory.."chip.dds",
	currentPic      = imageDirectory.."indicator.dds",
	unitsPic        = imageDirectory.."units.dds",
	energyPic       = imageDirectory.."energy.dds",
	metalPic        = imageDirectory.."metal.dds",
	notFirstPic     = imageDirectory.."notfirst.dds",
	notFirstPicWO   = imageDirectory.."notfirstwo.png",
	pingPic         = imageDirectory.."ping.dds",
	cpuPic          = imageDirectory.."cpu.dds",
	selectPic       = imageDirectory.."select.png",
	barPic          = imageDirectory.."bar.png",
	amountPic       = imageDirectory.."amount.png",
	pointPic        = imageDirectory.."point.dds",
	lowPic          = imageDirectory.."low.dds",
	arrowPic        = imageDirectory.."arrow.dds",
	arrowdPic       = imageDirectory.."arrowd.png",
	takePic         = imageDirectory.."take.dds",
	crossPic        = imageDirectory.."cross.dds",
	pointbPic       = imageDirectory.."pointb.png",
	takebPic        = imageDirectory.."takeb.png",
	seespecPic      = imageDirectory.."seespec.png",
	indentPic       = imageDirectory.."indent.png",
	cameraPic       = imageDirectory.."camera.dds",
	countryPic      = imageDirectory.."country.dds",
	readyTexture    = imageDirectory.."indicator.dds",
	drawPic         = imageDirectory.."draw.dds",
	allyPic         = imageDirectory.."ally.dds",
	resourcesPic    = imageDirectory.."res.png",
	resbarPic       = imageDirectory.."resbar.png",
	resbarBgPic     = imageDirectory.."resbarBg.png",
    barGlowCenterPic= imageDirectory.."barglow-center.png",
    barGlowEdgePic	= imageDirectory.."barglow-edge.png",

	cpuPingPic      = imageDirectory.."cpuping.dds",
	specPic         = imageDirectory.."spec.png",
	chatPic         = imageDirectory.."chat.dds",
	sidePic         = imageDirectory.."side.dds",
	sharePic        = imageDirectory.."share.dds",
	namePic         = imageDirectory.."name.dds",
	idPic           = imageDirectory.."id.dds",
	tsPic           = imageDirectory.."ts.dds",
	sizednPic       = imageDirectory.."sizedn.dds",
	sizeupPic       = imageDirectory.."sizeup.dds",
	
	rank0      = imageDirectory.."ranks/rank0.dds",
	rank1      = imageDirectory.."ranks/rank1.dds",
	rank2      = imageDirectory.."ranks/rank2.dds",
	rank3      = imageDirectory.."ranks/rank3.dds",
	rank4      = imageDirectory.."ranks/rank4.dds",
	rank5      = imageDirectory.."ranks/rank5.dds",
	rank6      = imageDirectory.."ranks/rank6.dds",
	rank7      = imageDirectory.."ranks/rank7.dds",
	rank8      = imageDirectory.."ranks/rank_unknown.dds",
}

local sidePics        = {}  -- loaded in SetSidePics function
local sidePicsWO      = {}  -- loaded in SetSidePics function
local originalColourNames = {} -- loaded in SetOriginalColourNames, format is originalColourNames['name'] = colourString

local apiAbsPosition = {0,0,0,0,1,1,false}

--------------------------------------------------------------------------------
-- Colors
--------------------------------------------------------------------------------

local pingCpuColors   = {
	[1] = {r = 0.11, g = 0.82, b = 0.11},
	[2] = {r = 0.4, g = 0.75, b = 0.2},
	[3] = {r = 0.72, g = 0.72, b = 0.2},
	[4] = {r = 0.82, g = 0.27, b = 0.18},
	[5] = {r = 1, g = 0.15, b = 0.3}
}

--------------------------------------------------------------------------------
-- Time Variables
--------------------------------------------------------------------------------

local blink           = true
local lastTime        = 0
local blinkTime       = 0
local now             = 0

local lastRequestTime = -1
local interRequestTime = 1 -- seconds

--------------------------------------------------------------------------------
-- LockCamera variables
--------------------------------------------------------------------------------

local transitionTime	= 0.6 --how long it takes the camera to move when trackign a player
local listTime			= 14 --how long back to look for recent broadcasters

local myPlayerID = Spring.GetMyPlayerID()
local lockPlayerID

local lastBroadcasts = {}
local recentBroadcasters = {}
local newBroadcaster = false
local totalTime = 0
local playerScores = {}

local aliveAllyTeams = {}

local myLastCameraState


--------------------------------------------------------------------------------
-- 
--------------------------------------------------------------------------------
local ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
local playSounds = true
local buttonclick = 'LuaUI/Sounds/buildbar_waypoint.wav'
local sliderdrag = 'LuaUI/Sounds/buildbar_rem.wav'

local lastActivity = {}
local lastFpsData = {}
local lastSystemData = {}
local lastGpuMemData = {}

--------------------------------------------------------------------------------
-- Tooltip
--------------------------------------------------------------------------------

local tipText

--------------------------------------------------------------------------------
-- Players counts and info
--------------------------------------------------------------------------------

-- local player info
local myAllyTeamID
local myTeamID
local mySpecStatus,fullView,_ = Spring.GetSpectatingState()

--General players/spectator count and tables
local player = {}
local playerSpecs = {}
local playerReadyState = {}
local numberOfSpecs = 0

--To determine faction at start
local sideOneDefID = UnitDefNames.armcom.id
local sideTwoDefID = UnitDefNames.corcom.id

local teamSideOne = "arm"
local teamSideTwo = "core"

--Name for absent/resigned players
local absentName = " --- "

--Did the game start yet?
local gameStarted = false
--------------------------------------------------------------------------------
-- Button check variable
--------------------------------------------------------------------------------

local clickToMove                  = nil    -- click detection for moving the widget
local moveStart                    = nil    -- position of the cursor before dragging the widget

local energyPlayer                 = nil    -- player to share energy with (nil when no energy sharing)
local metalPlayer                  = nil    -- player to share metal with(nil when no metal sharing)
local amountEM                     = 0      -- amount of metal/energy to share/ask
local amountEMMax                  = nil    -- max amount of metal/energy to share/ask
local sliderPosition               = 0      -- slider position in metal and energy sharing
local sliderOrigin                  = nil   -- position of the cursor before dragging the widget

local firstclick                   = 0		--

local dblclickPeriod = 0.4
local backgroundMargin = 7
local widgetRelRight = 0

local desiredLosmodeChanged = 0

--------------------------------------------------------------------------------
-- GEOMETRY VARIABLES
--------------------------------------------------------------------------------

local vsx,vsy  			= gl.GetViewSizes()

local widgetTop     	= 0
local widgetRight   	= 1
local widgetHeight  	= 0
local widgetWidth   	= 0
local widgetPosX    	= vsx-200
local widgetPosY    	= 0
local widgetScale		= 1

local expandDown    	= false
local expandLeft    	= true
local right

local activePlayers  	= {}
local labelOffset    	= 18
local separatorOffset	= 4
local playerOffset   	= 17
local specOffset 	 	= 12
local drawList       	= {}
local teamN	
local prevClickTime  	= os.clock()
local specListShow = true

local collapsed = false
local collapsedHeight = 42

--------------------------------------------------
-- Modules
--------------------------------------------------


local modules = {}
local modulesCount = 0
local m_indent;   modulesCount = modulesCount + 1
local m_rank;     modulesCount = modulesCount + 1
local m_side;     modulesCount = modulesCount + 1
local m_ID;       modulesCount = modulesCount + 1
local m_name;     modulesCount = modulesCount + 1
local m_share;    modulesCount = modulesCount + 1
local m_chat;     modulesCount = modulesCount + 1
local m_cpuping;  modulesCount = modulesCount + 1
local m_diplo;    modulesCount = modulesCount + 1
local m_sizedn;   modulesCount = modulesCount + 1
local m_sizeup;   modulesCount = modulesCount + 1

-- these are not considered as normal module since they dont take any place and wont affect other's position
-- (they have no module.width and are not part of modules)
local m_point;    modulesCount = modulesCount + 1  
local m_take;     modulesCount = modulesCount + 1
local m_seespec;  modulesCount = modulesCount + 1

local position = 1
m_indent = {
	name	  = "indent",
	spec      = true, --display for specs?
	play      = true, --display for players?
	active    = true, --display? (overrides above)
	default   = true, --display by default?
	width     = 9,
	position  = position,
	posX      = 0,
	pic       = pics["indentPic"],
	noPic     = true,
}
position = position + 1

m_ID = {
	name	  = "id",
	spec      = true,
	play      = true,
	active    = false,
	width     = 17,
	position  = position,
	posX      = 0,
	pic       = pics["idPic"],
}
position = position + 1

m_rank = {
	name	  = "rank",
	spec      = true, --display for specs?
	play      = true, --display for players?
	active    = true, --display? (overrides above)
	default   = false, --display by default?
	width     = 18,
	position  = position,
	posX      = 0,
	pic       = pics["rank6"],
}
position = position + 1

m_country = {
	name	  = "country",
	spec      = true,
	play      = true,
	active    = true,
	default   = true,
	width     = 20,
	position  = position,
	posX      = 0,
	pic       = pics["countryPic"],
}
position = position + 1

m_side = {
	name	  = "side",
	spec      = true,
	play      = true,
	active    = false,
	width     = 18,
	position  = position,
	posX      = 0,
	pic       = pics["sidePic"],
}
position = position + 1

m_skill = {
	name	  = "skill",
	spec      = true,
	play      = true,
	active    = true,
	width     = 18,
	position  = position,
	posX      = 0,
	pic       = pics["tsPic"],		
}
position = position + 1

m_name = {
	name      = "name",
	spec      = true,
	play      = true,
	active    = true,
	alwaysActive = true,
	width     = 10,
	position  = position,
	posX      = 0,
	pic       = pics["namePic"],
	noPic     = true,
	picGap    = 7,
}
position = position + 1

m_cpuping = {
	name 	  = "cpuping",
	spec      = true,
	play      = true,
	active    = true,
	width     = 24,
	position  = position,
	posX      = 0,
	pic       = pics["cpuPingPic"],
}
position = position + 1

m_resources = {
	name 	    = "resources",
	spec      = true,
	play      = true,
	active    = true,
	width     = 28,
	position  = position,
	posX      = 0,
	pic       = pics["resourcesPic"],
	picGap    = 7,
}
position = position + 1

m_share = {
	name 	  = "share",
	spec      = false,
	play      = true,
	active    = true,
	width     = 50,
	position  = position,
	posX      = 0,
	pic       = pics["sharePic"],
}
position = position + 1

m_chat = {
	name	  = "chat",
	spec      = false,
	play      = true,
    active    = false,
	width     = 18,
	position  = position,
	posX      = 0,
	pic       = pics["chatPic"],
}
position = position + 1

local fixedallies = tonumber(Spring.GetModOptions().fixedallies)
local drawAllyButton = (not fixedallies or fixedallies == 0)
m_alliance = {
	name 	  = "ally",
	spec      = false,
	play      = true,
	active    = true,
	width     = 16,
	position  = position,
	posX      = 0,
	pic       = pics["allyPic"],
	noPic     = false,
}
if not drawAllyButton then
	m_alliance.width = 0
end

position = position + 1

m_sizedn = {
	name	  = "sizedn", 
	spec      = true,
	play      = true,
	active    = true,
	alwaysActive = true,
	width     = 0,
	position  = position,
	posX      = 0,
	pic       = pics["sizednPic"],
}
position = position + 1

m_sizeup = {
	name	  = "sizeup", 
	spec      = true,
	play      = true,
	active    = true,
	alwaysActive = true,
	width     = 0,
	position  = position,
	posX      = 0,
	pic       = pics["sizeupPic"],
}
position = position + 1

modules = {
	m_indent,
	m_rank,
	m_country,
	m_ID,
	m_side,
	m_name,
	m_skill,
	m_resources,
	m_cpuping,
	m_alliance,
	m_share,
	m_chat,
	m_sizedn,
	m_sizeup,
}

m_point = {
	active = true,
	defaut = true,			-- defaults dont seem to be accesible on widget data load
	pic = pics["pointbPic"],
}

m_take = {
	active = true,
	default = true,
	pic = pics["takePic"],
}

m_seespec = {
	active = true,
	default = true,
	pic = pics["seespecPic"],
}


local specsLabelOffset = 0
local teamsizeVersusText = ""


---------------------------------------------------------------------------------------------------
--  Geometry
---------------------------------------------------------------------------------------------------

function SetModulesPositionX()
	m_name.width = SetMaxPlayerNameWidth()
	table.sort(modules, function(v1,v2)
		return v1.position < v2.position
	end)
	pos = 1
	for _,module in ipairs(modules) do
		module.posX = pos
		if module.active == true then
			if mySpecStatus == true then
				if module.spec == true then
					pos = pos + module.width
				end
			else
				if module.play == true then
					pos = pos + module.width	
				end
			end
		end
	
		widgetWidth = pos + 1
		if widgetWidth < 20 then
			widgetWidth = 20
		end
		
		if widgetWidth + widgetPosX > vsx then
		    widgetPosX = vsx - (widgetWidth * widgetScale) - widgetRelRight
		end
		if widgetRight - widgetWidth < 0 then
			widgetRight = widgetWidth
		end
		if expandLeft == true then
		    widgetPosX = vsx - (widgetWidth * widgetScale) - widgetRelRight
		else
			widgetRight = widgetPosX + widgetWidth  
		end
	end
end

function SetMaxPlayerNameWidth()
	-- determines the maximal player name width (in order to set the width of the widget)
	local t = Spring_GetPlayerList()
	local maxWidth = 14*gl_GetTextWidth(absentName) + 8 -- 8 is minimal width
	local name = ''
	local spec = false
	local version = ''
	local teamID = 0
	local nextWidth = 0
	for _,wplayer in ipairs(t) do
		name,_,spec,teamID = Spring_GetPlayerInfo(wplayer)
		if select(4,Spring_GetTeamInfo(teamID)) then -- is AI?
			_,_,_,_,name, version = Spring_GetAIInfo(teamID)
			if type(version) == "string" then
				name = "AI:" .. name .. "-" .. version
			else
				name = "AI:" .. name
			end
			if Spring.GetGameRulesParam(teamID, 'ainame') then
				name = Spring.GetGameRulesParam(teamID, 'ainame') .. ' (AI)'
			end
		end
		local charSize
		if spec then charSize = 11 else charSize = 14 end
		nextWidth = charSize*gl_GetTextWidth(name)+8
		if nextWidth > maxWidth then
			maxWidth = nextWidth
		end
	end
	return maxWidth
end

function GetNumberOfSpecs()
	local pList = Spring_GetPlayerList()
	local count = 0
	local name = ""
	for _,playerID in ipairs(pList) do
		_,active,spec = Spring_GetPlayerInfo(playerID)
		if spec and active then count = count + 1 end
	end
	return count
end

function GeometryChange()
	--check if disappeared off the edge of screen
	widgetRight = widgetWidth + widgetPosX
	if widgetRight > vsx-(backgroundMargin * widgetScale) then
		widgetRight = vsx - (backgroundMargin * widgetScale)
		widgetPosX = vsx - ((widgetWidth + backgroundMargin) * widgetScale) - widgetRelRight
	end
	if widgetPosX + widgetWidth/2 > vsx/2 then
		right = true
	else
		right = false
	end
end


local function UpdateAlliances()
	playerList = Spring_GetPlayerList()
	teamList = Spring_GetTeamList()
	for _,playerID in pairs (playerList) do
		if not player[playerID].spec then
			local alliances = {}
			for _,player2ID in pairs (playerList) do
				if not player[playerID].spec and not player[player2ID].spec and playerID ~= player2ID  and  player[playerID].team ~= nil and player[player2ID].team ~= nil and  player[playerID].allyteam ~= player[player2ID].allyteam  and  Spring_AreTeamsAllied(player[player2ID].team, player[playerID].team) then
					alliances[#alliances+1] = player2ID
				end
			end
			player[playerID].alliances = alliances
		end
	end
end

function toPixels(str)
	local chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ !@#$%^&*()_+-=[]{};:,./<>?~|`'\"\\"
	local pixels = {}
	for i=1, string.len(str) do
		if i%3 == 1 then
			pixels[#pixels+1] = {}
		end
		local char = string.sub(str,i,i)
		for ci=1, string.len(chars) do
			if char == string.sub(chars,ci,ci) then
				pixels[#pixels][#pixels[#pixels]+1] = (ci-1)/string.len(chars)
				break
			end
		end
	end
	return pixels
end

-- only being called for devs registered in gadget
function PlayerDataBroadcast(playerName, msg)
	local data = ''
	local count = 0
	local startPos = 0
	for i=1, string.len(msg) do
		if string.sub(msg, i, i) == ';' then
			count = count + 1
			if count == 1 then
				startPos = i+1
				playerName = string.sub(msg,1,i-1)
			elseif count == 2 then
				msgType = string.sub(msg,startPos,i-1)
				data = string.sub(msg, i+1)
				break
			end
		end
	end
	if data then
		if msgType == 'screenshot' then
			data = VFS.ZlibDecompress(data)
			count = 0
			for i=1, string.len(data) do
				if string.sub(data, i, i) == ';' then
					count = count + 1
					if count == 1 then
						local finished = string.sub(data,1,i-1)
						if finished == '1' then
							screenshotFinished = true
						else
							screenshotFinished = false
						end
						startPos = i+1
					elseif count == 2 then
						screenshotWidth = string.sub(data,startPos,i-1)
						startPos = i+1
					elseif count == 3 then
						screenshotHeight = string.sub(data,startPos,i-1)
						startPos = i+1
					elseif count == 4 then
						screenshotGameframe = tonumber(string.sub(data,startPos,i-1))
						if not screenshotData then
							screenshotData = string.sub(data, i+1)
						else
							screenshotData = screenshotData .. string.sub(data, i+1)
						end
						break
					end
				end
			end
			data = nil
			screenshotDataLast = totalTime

			if screenshotFinished or totalTime-4000 > screenshotDataLast then
				screenshotFinished = true
				local map = Game.mapName
				local datetable = os.date('*t')
				local frame = Spring.GetGameFrame()
				local minutes = math.floor((screenshotGameframe / 30 / 60))
				local seconds = math.floor((screenshotGameframe - ((minutes*60)*30)) / 30)
				if seconds == 0 then
					seconds = '00'
				elseif seconds < 10 then
					seconds = '0'..seconds
				end
				local time = minutes..':'..seconds
				local yyyy = datetable.year
				local m = datetable.month
				local d = datetable.day
				local h = datetable.hour
				local min = datetable.min
				local s = datetable.sec
				local yyyy = tostring(yyyy)
				local mm = ((m > 9 and tostring(m)) or (m <10 and ("0"..tostring(m))))
				local dd = ((d > 9 and tostring(d)) or (d <10 and ("0"..tostring(d))))
				local hh = ((h > 9 and tostring(h)) or (h <10 and ("0"..tostring(h))))
				local minmin = ((min > 9 and tostring(min)) or (min <10 and ("0"..tostring(min))))
				local ss = ((s > 9 and tostring(s)) or (s <10 and ("0"..tostring(s))))
				local engine = Engine.versionFull

				screenshotPixels = toPixels(screenshotData)
				screenshotPlayer = playerName
				screenshotFilename = yyyy..mm..dd.."_"..hh..minmin..ss.."_" ..minutes..'.'..seconds.."_"..playerName
				screenshotSaved = nil
				screenshotSaveQueued = true
				screenshotPosX = widgetPosX-(backgroundMargin+30+screenshotWidth*widgetScale)
				screenshotPosY = widgetPosY
				screenshotDlist = gl_CreateList(function()
					gl.PushMatrix()
					gl.Translate(screenshotPosX, screenshotPosY,0)
					gl.Scale(widgetScale,widgetScale,0)

					gl_Color(0,0,0,0.66)
					local margin = 2
					RectRound(-margin,-margin,screenshotWidth+margin+margin,screenshotHeight+15+margin+margin, 6, true)
					gl_Color(1,1,1,0.025)
					RectRound(0,0,screenshotWidth,screenshotHeight+12+margin+margin, 4.5, true)

					gl.Text(screenshotPlayer, 4, screenshotHeight+6.5, 11, "on")

					local row = 0
					local col = 0
					for p=1, #screenshotPixels do
						col = col + 1
						if p%screenshotWidth == 1 then
							row = row + 1
							col = 1
						end
						gl.Color(screenshotPixels[p][1], screenshotPixels[p][2], screenshotPixels[p][3], 1)
						gl.Rect(col, row, col+1, row+1)
					end
					gl.PopMatrix()

				end)
				screenshotPixels = nil
				screenshotData = nil
				screenshotFinished = nil
			end
		elseif msgType == 'infolog' or msgType == 'config' then
			local playerID
			for i=1, string.len(data) do
				if string.sub(data, i, i) == ';' then
					playerID = tonumber(string.sub(data,1,i-1))
					startPos = i+1
					data = string.sub(data, i+1)
					break
				end
			end
			if playerID == myPlayerID then
				local datetable = os.date('*t')
				local yyyy = datetable.year
				local m = datetable.month
				local d = datetable.day
				local h = datetable.hour
				local min = datetable.min
				local yyyy = tostring(yyyy)
				local mm = ((m > 9 and tostring(m)) or (m <10 and ("0"..tostring(m))))
				local dd = ((d > 9 and tostring(d)) or (d <10 and ("0"..tostring(d))))
				local hh = ((h > 9 and tostring(h)) or (h <10 and ("0"..tostring(h))))
				local minmin = ((min > 9 and tostring(min)) or (min <10 and ("0"..tostring(min))))

				local filename = 'playerdata_'..msgType..'s.txt'
				local filedata = ''
				if VFS.FileExists(filename) then
					filedata = tostring(VFS.LoadFile(filename))
				end
				local file = assert(io.open(filename, 'w'), 'Unable to save '..filename)
				file:write(filedata .. '-----------------------------------------------------\n----  '.. yyyy..'-'..mm..'-'..dd.."  "..hh..'.'..minmin .. '  ' .. playerName .. '\n-----------------------------------------------------\n' .. VFS.ZlibDecompress(data) .. "\n\n\n\n\n\n")
				file:close()
				Spring.Echo('Added '..msgType..' to '..filename)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
--  LockCamera stuff
---------------------------------------------------------------------------------------------------



local function UpdateRecentBroadcasters()
	recentBroadcasters = {}
	local i = 1
	for playerID, info in pairs(lastBroadcasts) do
		lastTime = info[1]
		if (totalTime - lastTime <= listTime or playerID == lockPlayerID) then
			if (totalTime - lastTime <= listTime) then
				recentBroadcasters[playerID] = totalTime - lastTime
			end
			i = i + 1
		end
	end
end

local function LockCamera(playerID)

	if playerID and playerID ~= myPlayerID and playerID ~= lockPlayerID then
		if lockcameraHideEnemies and not select(3,Spring_GetPlayerInfo(playerID)) then
			Spring.SendCommands("specteam "..select(4,Spring_GetPlayerInfo(playerID)))
			if not fullView then
				sceduledSpecFullView = 1	-- this is needed else the minimap/world doesnt update properly
				Spring.SendCommands("specfullview")
			else
				sceduledSpecFullView = 2	-- this is needed else the minimap/world doesnt update properly
				Spring.SendCommands("specfullview")
			end
			if lockcameraLos and mySpecStatus and Spring.GetMapDrawMode()~="los" then
				desiredLosmode = 'los'
				desiredLosmodeChanged = os.clock()
			end
		elseif lockcameraHideEnemies and select(3,Spring_GetPlayerInfo(playerID)) then
			if not fullView then
				Spring.SendCommands("specfullview")
			end
			desiredLosmode = 'normal'
			desiredLosmodeChanged = os.clock()
		end
		lockPlayerID = playerID
		myLastCameraState = myLastCameraState or GetCameraState()
		local info = lastBroadcasts[lockPlayerID]
		if info then
			SetCameraState(info[2], transitionTime)
		end
	else
		if myLastCameraState then
			SetCameraState(myLastCameraState, transitionTime)
			myLastCameraState = nil
		end
		if lockcameraHideEnemies and lockPlayerID and not select(3,Spring_GetPlayerInfo(lockPlayerID)) then
			if not fullView then
				Spring.SendCommands("specfullview")
			end
			if lockcameraLos and mySpecStatus and Spring.GetMapDrawMode()=="los" then
				desiredLosmode = 'normal'
				desiredLosmodeChanged = os.clock()
			end
		end
		lockPlayerID = nil
	end
	UpdateRecentBroadcasters()
end

function GpuMemEvent(playerID, percentage)
	lastGpuMemData[playerID] = percentage
end

function FpsEvent(playerID, fps)
	lastFpsData[playerID] = fps

	WG.playerFPS = WG.playerFPS or {}
	WG.playerFPS[playerID] = fps	
end
	
function SystemEvent(playerID, system)
  local lines, length = 0, 0
  local function helper(line) lines=lines+1; if string.len(line) then length = string.len(line) end return "" end
  helper((system:gsub("(.-)\r?\n", helper)))
  lastSystemData[playerID] = system

  WG.playerSystemData = WG.playerSystemData or {}
  WG.playerSystemData[playerID] = system
end

function ActivityEvent(playerID)
  lastActivity[playerID] = os.clock()
end

function CameraBroadcastEvent(playerID,cameraState)

	--if cameraState is empty then transmission has stopped
	if not cameraState then
		if lastBroadcasts[playerID] then
			lastBroadcasts[playerID] = nil
			newBroadcaster = true
		end
		if lockPlayerID == playerID then
			LockCamera()
		end
		return
	end
	
	if not lastBroadcasts[playerID] and not newBroadcaster then
		newBroadcaster = true
	end
	
	lastBroadcasts[playerID] = {totalTime, cameraState}
	
	if playerID == lockPlayerID then
		SetCameraState(cameraState, transitionTime)
	end
end

---------------------------------------------------------------------------------------------------
--  Init/GameStart (creating players)
---------------------------------------------------------------------------------------------------

function RecvPlayerScores(newPlayerScores)
	playerScores = newPlayerScores or {}
end

function widget:Initialize()
	widget:ViewResize(gl.GetViewSizes())

	widgetHandler:RegisterGlobal('getPlayerScoresAdvplayerslist', RecvPlayerScores)
	widgetHandler:RegisterGlobal('CameraBroadcastEvent', CameraBroadcastEvent)
	widgetHandler:RegisterGlobal('ActivityEvent', ActivityEvent)
	widgetHandler:RegisterGlobal('FpsEvent', FpsEvent)
	widgetHandler:RegisterGlobal('GpuMemEvent', GpuMemEvent)
	widgetHandler:RegisterGlobal('SystemEvent', SystemEvent)
	widgetHandler:RegisterGlobal('PlayerDataBroadcast', PlayerDataBroadcast)
	UpdateRecentBroadcasters()
	
	mySpecStatus,fullView,_ = Spring.GetSpectatingState()
	if Spring.GetGameFrame() <= 0 then
		if mySpecStatus and not alwaysHideSpecs then
			specListShow = true
		else
			specListShow = false
		end
	end
	if (Spring.GetConfigInt("ShowPlayerInfo")==1) then
		Spring.SendCommands("info 0")
	end
    
    if Spring.GetGameFrame()>0 then 
        gameStarted = true 
 	end 

	GeometryChange()	
	SetModulesPositionX() 
	SetSidePics() 
	InitializePlayers()
	SortList()
	
	WG['advplayerlist_api'] = {}
	WG['advplayerlist_api'].GetPosition = function()
		return apiAbsPosition
	end
	WG['advplayerlist_api'].GetCollapsable = function()
		return collapsable
	end
	WG['advplayerlist_api'].SetCollapsable = function(value)
		collapsable = value
		if not collapsable and collapsed then
			collapsed = false
			CreateBackground()
		end
	end

    WG['advplayerlist_api'].GetLockPlayerID = function()
        return lockPlayerID
    end
    WG['advplayerlist_api'].SetLockPlayerID = function(playerID)
		LockCamera(playerID)
	end
	WG['advplayerlist_api'].GetLockHideEnemies = function()
		return lockcameraHideEnemies
	end
	WG['advplayerlist_api'].SetLockHideEnemies = function(value)
		lockcameraHideEnemies = value
		if lockPlayerID and not select(3,Spring_GetPlayerInfo(lockPlayerID)) then
			if not lockcameraHideEnemies then
				if not fullView then
					Spring.SendCommands("specfullview")
					if lockcameraLos and mySpecStatus and Spring.GetMapDrawMode()=="los" then
						desiredLosmode = 'normal'
						desiredLosmodeChanged = os.clock()
						Spring.SendCommands("togglelos")
					end
				end
			else
				if fullView then
					Spring.SendCommands("specfullview")
					if lockcameraLos and mySpecStatus and Spring.GetMapDrawMode()~="los" then
						desiredLosmode = 'los'
						desiredLosmodeChanged = os.clock()
						Spring.SendCommands("togglelos")
					end
				end
			end
		end
	end
	WG['advplayerlist_api'].GetLockTransitionTime = function()
		return transitionTime
	end
	WG['advplayerlist_api'].SetLockTransitionTime = function(value)
		transitionTime = value
	end
	WG['advplayerlist_api'].GetLockLos = function()
		return lockcameraLos
	end
	WG['advplayerlist_api'].SetLockLos = function(value)
		lockcameraLos = value
		if lockcameraHideEnemies and mySpecStatus and lockPlayerID and not select(3,Spring_GetPlayerInfo(lockPlayerID)) then
			if lockcameraLos and Spring.GetMapDrawMode()~="los" then
				desiredLosmode = 'los'
				desiredLosmodeChanged = os.clock()
				Spring.SendCommands("togglelos")
			elseif not lockcameraLos and Spring.GetMapDrawMode()=="los" then
				desiredLosmode = 'normal'
				desiredLosmodeChanged = os.clock()
				Spring.SendCommands("togglelos")
			end
		end
	end
end

function widget:GameFrame(n)
	if n > 0 and not gameStarted and not collapsed then
		if mySpecStatus and not alwaysHideSpecs then
			specListShow = true
		else
			specListShow = false
		end

		gameStarted = true
		SetSidePics()
		InitializePlayers()
		SetOriginalColourNames()
		SortList()
	end
end


function widget:Shutdown()
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('advplayerlist')
		WG['guishader_api'].RemoveRect('advplayerlist_screenshot')
	end
	WG['advplayerlist_api'] = nil
	widgetHandler:DeregisterGlobal('CameraBroadcastEvent')
	widgetHandler:DeregisterGlobal('ActivityEvent')
	widgetHandler:DeregisterGlobal('FpsEvent')
	widgetHandler:DeregisterGlobal('GpuMemEvent')
	widgetHandler:DeregisterGlobal('SystemEvent')
	if ShareSlider then
		gl_DeleteList(ShareSlider)
	end
	if MainList then
		gl_DeleteList(MainList)
	end
	if Background then
		gl_DeleteList(Background)
	end
	if screenshotDlist then
		gl_DeleteList(screenshotDlist)
	end
	if lockPlayerID then
		LockCamera()
	end
end

function widget:GameOver()
	if lockPlayerID then
		LockCamera()
	end
end


function SetSidePics() 
	--record readyStates
	playerList = Spring.GetPlayerList()
	for _,playerID in pairs (playerList) do
		playerReadyState[playerID] = Spring.GetGameRulesParam("player_" .. tostring(playerID) .. "_readyState")
	end

	--set factions, from TeamRulesParam when possible and from initial info if not
	teamList = Spring_GetTeamList()
	for _, team in ipairs(teamList) do
		local teamSide
		if Spring_GetTeamRulesParam(team, 'startUnit') then
			local startunit = Spring_GetTeamRulesParam(team, 'startUnit')
			if startunit == sideOneDefID then 
				teamSide = teamSideOne
			end
			if startunit == sideTwoDefID then
				teamSide = teamSideTwo
			end
		else
			_,_,_,_,teamSide = Spring_GetTeamInfo(team)
		end
	
		if teamSide then
			sidePics[team] = imageDirectory..teamSide.."_default.png"
			sidePicsWO[team] = imageDirectory..teamSide.."wo_default.png"
		else
			sidePics[team] = imageDirectory.."default.png"
			sidePicsWO[team] = imageDirectory.."defaultwo.png"
		end
	end
end


function InitializePlayers()
	myPlayerID = Spring_GetLocalPlayerID()
	myTeamID = Spring_GetLocalTeamID()
	myAllyTeamID = Spring_GetLocalAllyTeamID()
	for i = 0, 128 do
		player[i] = {} 
	end
	GetAllPlayers()
end

function GetAllPlayers()
	local noplayer
	local tplayerCount = 0
	local allteams   = Spring_GetTeamList()
	teamN = table.maxn(allteams) - 1               --remove gaia
	for i = 0,teamN-1 do
		local teamPlayers = Spring_GetPlayerList(i, true)
		player[i + 64] = CreatePlayerFromTeam(i)
		for _,playerID in ipairs(teamPlayers) do
			player[playerID] = CreatePlayer(playerID)
			tplayerCount = tplayerCount + 1
		end

		local _,_,_,isAiTeam = Spring.GetTeamInfo(teamN)
		local isLuaAI = (Spring.GetTeamLuaAI(teamN) ~= "")
		if not (isAiTeam or isLuaAI) then
			if tplayerCount > 0 then
				playerSpecs[i] = true		-- (this isnt correct when team consists of only AI)
			end
			tplayerCount = 0
		end
	end
	specPlayers = Spring_GetTeamList()
	for _,playerID in ipairs(specPlayers) do
		local active,_,spec = Spring_GetPlayerInfo(playerID)
		if spec == true then
			if active == true then
				player[playerID] = CreatePlayer(playerID)
			end
		end
	end
end


function GetAliveAllyTeams()
	aliveAllyTeams = {}
	local allteams   = Spring_GetTeamList()
	teamN = table.maxn(allteams) - 1               --remove gaia
	for i = 0,teamN-1 do
		local _,_, isDead, _, _, tallyteam = Spring_GetTeamInfo(i)
		if not isDead then
			aliveAllyTeams[tallyteam] = true
		end
	end
end


function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function GetSkill(playerID)

	local customtable = select(11,Spring.GetPlayerInfo(playerID))
	local tsMu = customtable.skill
	local tsSigma = customtable.skilluncertainty
	local tskill = ""
	if tsMu then
		tskill = tsMu and tonumber(tsMu:match("%d+%.?%d*")) or 0
		tskill = round(tskill,0)
		if string.find(tsMu, ")") then
			tskill = "\255"..string.char(190)..string.char(140)..string.char(140) .. tskill -- ')' means inferred from lobby rank
		else
		
			-- show privacy mode
			local priv = ""
			if string.find(tsMu, "~") then -- '~' means privacy mode is on
				priv = "\255"..string.char(200)..string.char(200)..string.char(200) .. "*" 		
			end
			
			--show sigma
			if tsSigma then -- 0 is low sigma, 3 is high sigma
				tsSigma=tonumber(tsSigma)
				local tsRed, tsGreen, tsBlue 
				if tsSigma > 2 then
					tsRed, tsGreen, tsBlue = 190, 130, 130
				elseif tsSigma == 2 then
					tsRed, tsGreen, tsBlue = 140, 140, 140
				elseif tsSigma == 1 then
					tsRed, tsGreen, tsBlue = 195, 195, 195
				elseif tsSigma < 1 then
						tsRed, tsGreen, tsBlue = 250, 250, 250
				end
				tskill = priv .. "\255"..string.char(tsRed)..string.char(tsGreen)..string.char(tsBlue) .. tskill
			else
				tskill = priv .. "\255"..string.char(195)..string.char(195)..string.char(195) .. tskill --should never happen
			end
		end
	else
		tskill = "\255"..string.char(160)..string.char(160)..string.char(160) .. "?"
	end
	return tskill
end


function CreatePlayer(playerID)
	
	--generic player data
	local tname,_, tspec, tteam, tallyteam, tping, tcpu, tcountry, trank = Spring_GetPlayerInfo(playerID)
	local _,_,_,_, tside, tallyteam                                      = Spring_GetTeamInfo(tteam)
	local tred, tgreen, tblue  										     = Spring_GetTeamColor(tteam)
	
	--skill
	local tskill 
	tskill = GetSkill(playerID)
	
	--cpu/ping
	tpingLvl = GetPingLvl(tping)
	tcpuLvl  = GetCpuLvl(tcpu)
	tping    = tping * 1000 - ((tping * 1000) % 1)
	tcpu     = tcpu  * 100  - ((tcpu  *  100) % 1)
	
	-- resources
	local energy, energyStorage, energyIncome, metal, metalStorage, metalIncome = 0,1,0,1,0,0
	if aliveAllyTeams[tallyteam] ~= nil  and  (mySpecStatus or myAllyTeamID == tallyteam) then
		energy, energyStorage,_, energyIncome = Spring_GetTeamResources(tteam, "energy")
		metal, metalStorage,_, metalIncome = Spring_GetTeamResources(tteam, "metal")
		if energy then
			energy = math.floor(energy)
			metal = math.floor(metal)
			if energy < 0 then energy = 0 end
			if metal < 0 then metal = 0 end
		else
			energy = 0
			metal = 0
		end
	end
	
	return {
		rank             = trank,
		skill			 = tskill,
		name             = tname,
		team             = tteam,
		allyteam         = tallyteam,
		red              = tred,
		green            = tgreen,
		blue             = tblue,
		dark             = GetDark(tred,tgreen,tblue),
		side             = tside,
		pingLvl          = tpingLvl,
		cpuLvl           = tcpuLvl,
		ping             = tping,
		cpu              = tcpu,
		country          = tcountry,
		dead             = false,
		spec             = tspec,
		ai               = false,
		energy           = energy,
		energyStorage    = energyStorage,
		metal            = metal,
		metalStorage     = metalStorage,
	}
	
end



function CreatePlayerFromTeam(teamID) -- for when we don't have a human player occupying the slot, also when a player changes team (dies)
	
	local _,_, isDead, isAI, tside, tallyteam = Spring_GetTeamInfo(teamID)
	local tred, tgreen, tblue                 = Spring_GetTeamColor(teamID)
	local tname, ttotake, tskill
	local tdead = true

	if isAI then
	
		local version
		
		_,_,_,_, tname, version = Spring_GetAIInfo(teamID)
		
		if type(version) == "string" then
			tname = "AI:" .. tname .. "-" .. version
		else
			tname = "AI:" .. tname
		end
		if Spring.GetGameRulesParam('ainame_'..teamID) then
			tname = Spring.GetGameRulesParam('ainame_'..teamID)..' (AI)'
		end
		
		ttotake = false
		tdead = false
		tai = true
		
	else
	
		if Spring_GetGameSeconds() < 0.1 then
			tname = absentName
			ttotake = false
			tdead = false
		else
			ttotake = IsTakeable(teamID)
		end
		
		tai = false
	end
	
	if tname == nil then
		tname = absentName
	end
	
	tskill = ""
	
	-- resources
	local energy, energyStorage, energyIncome, metal, metalStorage, metalIncome = 0,1,0,1,0,0
	if aliveAllyTeams[tallyteam] ~= nil  and  (mySpecStatus or myAllyTeamID == tallyteam) then
		energy, energyStorage,_, energyIncome = Spring_GetTeamResources(teamID, "energy") or 0
		metal, metalStorage,_, metalIncome = Spring_GetTeamResources(teamID, "metal") or 0
		energy = math.floor(energy or 0)
		metal = math.floor(metal or 0)
		if energy < 0 then energy = 0 end
		if metal < 0 then metal = 0 end
	end
	
	return{
		rank             = 8, -- "don't know which" value
		skill			       = tskill,
		name             = tname,
		team             = teamID,
		allyteam         = tallyteam,
		red              = tred,
		green            = tgreen,
		blue             = tblue,
		dark             = GetDark(tred, tgreen, tblue),
		side             = tside,
		totake           = ttotake,
		dead             = tdead,
		spec             = false,
		ai 							 = tai,
		energy           = energy,
		energyStorage    = energyStorage,
		metal            = metal,
		metalStorage     = metalStorage,
	}
	
end

function UpdatePlayerResources()
	local energy, energyStorage, metal, metalStorage = 0, 1, 0 ,1
	for playerID,_ in pairs(player) do
		if player[playerID].name and not player[playerID].spec and player[playerID].team then
			if aliveAllyTeams[player[playerID].allyteam] ~= nil  and  (mySpecStatus or myAllyTeamID == player[playerID].allyteam) then
				energy, energyStorage,_, energyIncome = Spring_GetTeamResources(player[playerID].team, "energy")
				metal, metalStorage,_, metalIncome = Spring_GetTeamResources(player[playerID].team, "metal")
				if energy == nil then		-- need to be there for when you do /specfullview
					energy, energyStorage, energyIncome, metal, metalStorage, metalIncome = 0, 0, 0, 0, 0, 0
				else
					energy = math.floor(energy)
					metal = math.floor(metal)
					if energy < 0 then energy = 0 end
					if metal < 0 then metal = 0 end
				end
				player[playerID].energy = energy
				player[playerID].energyIncome = energyIncome
				player[playerID].energyStorage = energyStorage
				player[playerID].metal = metal
				player[playerID].metalIncome = metalIncome
				player[playerID].metalStorage = metalStorage
			end
		end
	end
end

function GetDark(red,green,blue)                  	
	-- Determines if the player color is dark (i.e. if a white outline for the sidePic is needed)
	if red + green*1.2 + blue*0.4 < 0.8 then return true end
	return false
end


function SetOriginalColourNames()
	-- Saves the original team colours associated to team teamID
	for playerID,_ in pairs(player) do
		if player[playerID].name then
			if player[playerID].spec then
				originalColourNames[playerID] = "\255\255\255\255"
			else
				originalColourNames[playerID] = colourNames(player[playerID].team)
			end
		end
	end
end



		
---------------------------------------------------------------------------------------------------
--  Sorting player data
-- note: SPADS ensures that order of playerIDs/teams/allyteams as appropriate reflects TS (mu) order
---------------------------------------------------------------------------------------------------


function SortList()
	local teamList
	local myOldSpecStatus = mySpecStatus
	
	_,_, mySpecStatus,_,_,_,_,_,_ = Spring_GetPlayerInfo(myPlayerID)
	
	-- checks if a team has died
	if mySpecStatus ~= myOldSpecStatus then
		if mySpecStatus == true then
			teamList = Spring_GetTeamList()
			for _, team in ipairs(teamList) do               --
				_,_, isDead = Spring_GetTeamInfo(team)
				if isDead == false then
					Spec(team)
					break
				end
			end
		end
	end
	
	myAllyTeamID = Spring_GetLocalAllyTeamID()
	myTeamID = Spring_GetLocalTeamID()
	
	drawList = {}
	drawListOffset = {}
	vOffset = 0
	
	-- calls the (cascade) sorting for players
	vOffset = SortAllyTeams(vOffset) 
	
	-- calls the sortings for specs if see spec is on
	--if m_chat.active == true then
		vOffset = SortSpecs(vOffset) 
	--end
	
	-- set the widget height according to space needed to show team
	widgetHeight = vOffset + 3
	
	
	-- move the widget if list is too long
	if widgetHeight + widgetPosY > vsy then
		widgetPosY = vsy - widgetHeight
	end
	
	if widgetTop - widgetHeight < 0 then
		--widgetTop = widgetHeight
	end
	
	-- set the widget Y position or the top of the widget according to expand direction
	if expandDown == true then
		widgetPosY = widgetTop - widgetHeight
	else
		widgetTop = widgetPosY + widgetHeight
	end
	
end


function SortAllyTeams(vOffset)
	-- adds ally teams to the draw list (own ally team first)
	-- (labels and separators are drawn)
	local allyTeamID
	local allyTeamList = Spring_GetAllyTeamList()
	local firstenemy = true
	local isFirstDrawnTeam = true
	allyTeamsCount = table.maxn(allyTeamList)-1
    
	--find own ally team
	vOffset = 12/2.66
	for allyTeamID = 0, allyTeamsCount - 1 do
		if allyTeamID == myAllyTeamID  then
			vOffset = vOffset + labelOffset - 3
			if drawAlliesLabel then
				drawListOffset[#drawListOffset+1] = vOffset
				drawList[#drawList+1] = -2  -- "Allies" label
			  vOffset = SortTeams(allyTeamID, vOffset)+2	-- Add the teams from the allyTeam
			else
			  vOffset = SortTeams(allyTeamID, vOffset-labelOffset)
			end	
			break
		end
	end
	
	
	-- add the others
	for allyTeamID = 0, allyTeamsCount-1 do
		if allyTeamID ~= myAllyTeamID then
			if firstenemy == true then
                vOffset = vOffset + 13
				
				vOffset = vOffset + labelOffset - 3
				drawListOffset[#drawListOffset+1] = vOffset
				drawList[#drawList+1] = -3 -- "Enemies" label
				firstenemy = false
			else
				vOffset = vOffset + separatorOffset
				drawListOffset[#drawListOffset+1] = vOffset
				drawList[#drawList+1] = -4 -- Enemy teams separator
			end
			vOffset = SortTeams(allyTeamID, vOffset)+2 -- Add the teams from the allyTeam 
		end
	end
	
	
	return vOffset
end

local deadPlayerHeightReduction = 10
function SortTeams(allyTeamID, vOffset)
	-- Adds teams to the draw list (own team first)
	--(teams are not visible as such unless they are empty or AI)
	local teamID
	local teamsList = Spring_GetTeamList(allyTeamID)
	
	--add teams 
	for _,teamID in ipairs(teamsList) do
		drawListOffset[#drawListOffset+1] = vOffset
		drawList[#drawList+1] = -1
		vOffset = SortPlayers(teamID,allyTeamID,vOffset) -- adds players form the team
		local _,_, isDead, _, _, _ = Spring_GetTeamInfo(teamID)
		if isDead then
			vOffset = vOffset - (deadPlayerHeightReduction/2)
		end
	end
	
	return vOffset
end

function SortPlayers(teamID,allyTeamID,vOffset)
	-- Adds players to the draw list (self first)
	
	local playersList       = Spring_GetPlayerList(teamID,true)
	local noPlayer          = true
	local _,_,_, isAi = Spring_GetTeamInfo(teamID)
	
	-- add own player (if not spec)
	if myTeamID == teamID then
		if player[myPlayerID].name ~= nil then
			if mySpecStatus == false then
				vOffset = vOffset + playerOffset
				drawListOffset[#drawListOffset+1] = vOffset
				drawList[#drawList+1] = myPlayerID -- new player (with ID)
				player[myPlayerID].posY = vOffset
				noPlayer = false
			end
		end
	end
	
	-- add other players (if not spec)
	for _,playerID in ipairs(playersList) do
		if playerID ~= myPlayerID then
			if player[playerID].name ~= nil then
				if player[playerID].spec ~= true then
					vOffset = vOffset + playerOffset
					drawListOffset[#drawListOffset+1] = vOffset
					drawList[#drawList+1] = playerID -- new player (with ID)
					player[playerID].posY = vOffset
					noPlayer = false
				end
			end
		end
	end
	
	-- add AI teams
	if isAi == true then
		vOffset = vOffset + playerOffset
		drawListOffset[#drawListOffset+1] = vOffset
		drawList[#drawList+1] = 64 + teamID -- new AI team (instead of players)
		player[64 + teamID].posY = vOffset
		noPlayer = false
	end
	
	-- add no player token if no player found in this team at this point
	if noPlayer == true then
		vOffset = vOffset + playerOffset - (deadPlayerHeightReduction/2)
		drawListOffset[#drawListOffset+1] = vOffset
		drawList[#drawList+1] = 64 + teamID  -- no players team
		player[64 + teamID].posY = vOffset
		if Spring_GetGameFrame() > 0 then
			player[64+teamID].totake = IsTakeable(teamID)
		end
	end
	
	return vOffset
end

function SortSpecs(vOffset)
	-- Adds specs to the draw list
	local playersList = Spring_GetPlayerList(-1,true)
	local noSpec = true
	for _,playerID in ipairs(playersList) do
		_,active,spec = Spring_GetPlayerInfo(playerID)
		if spec and active then
			if player[playerID].name ~= nil then
				
				-- add "Specs" label if first spec
				if noSpec == true then
					vOffset = vOffset + 13
					vOffset = vOffset + labelOffset - 2
					drawListOffset[#drawListOffset+1] = vOffset
					drawList[#drawList+1] = -5
					noSpec = false
					specJoinedOnce = true
					vOffset = vOffset + 4					
				end
				
				-- add spectator
				if specListShow == true then
					vOffset = vOffset + specOffset
					drawListOffset[#drawListOffset+1] = vOffset
					drawList[#drawList+1] = playerID
					player[playerID].posY = vOffset
					noPlayer = false
				end
			end
		end
	end
	
	-- add "Specs" label
	if specJoinedOnce and noSpec then
		vOffset = vOffset + 13
		vOffset = vOffset + labelOffset - 2
		drawListOffset[#drawListOffset+1] = vOffset
		drawList[#drawList+1] = -5
		vOffset = vOffset + 4
	end
	
	return vOffset
end



---------------------------------------------------------------------------------------------------
--  Draw control
---------------------------------------------------------------------------------------------------

local PrevGameFrame
local MainList
local Background
local ShareSlider


function widget:DrawScreen()

	if Spring_IsGUIHidden() then return end


	local scaleDiffX = -((widgetPosX*widgetScale)-widgetPosX)/widgetScale
	local scaleDiffY = -((widgetPosY*widgetScale)-widgetPosY)/widgetScale
	gl.Scale(widgetScale,widgetScale,0)
	gl.Translate(scaleDiffX,scaleDiffY,0)

	local mouseX,mouseY,mouseButtonL = Spring_GetMouseState()
	if collapsed then
		-- draws the background
		if Background then
			gl_CallList(Background)
		else
			CreateBackground()
		end
	else
		-- update lists frequently if there is mouse interaction
		local NeedUpdate = false
		if (mouseX > widgetPosX + m_name.posX + m_name.width - 5) and (mouseX < widgetPosX + widgetWidth) and (mouseY > widgetPosY - 16) and (mouseY < widgetPosY + widgetHeight) then
			local DrawFrame = Spring_GetDrawFrame()
			local CurGameFrame = Spring_GetGameFrame()
			if PrevGameFrame == nil then PrevGameFrame = CurGameFrame end
			if (DrawFrame%5==0) or (CurGameFrame>PrevGameFrame+1) then
				--Echo(DrawFrame)
				NeedUpdate = true
			end
		end

		if NeedUpdate then
			--Spring.Echo("DS APL update")
			CreateLists()
			PrevGameFrame = CurGameFrame
		end

		-- draws the background
		if Background then
			gl_CallList(Background)
		else
			CreateBackground()
		end

		-- draws the main list
		if MainList then
			gl_CallList(MainList)
		else
			CreateMainList()
		end

		-- draws share energy/metal sliders
		if ShareSlider then
			gl_CallList(ShareSlider)
		else
			CreateShareSlider()
		end
	end

	local scaleReset = widgetScale / widgetScale / widgetScale
	gl.Translate(-scaleDiffX,-scaleDiffY,0)
	gl.Scale(scaleReset,scaleReset,0)


	if screenshotDlist then
		gl_CallList(screenshotDlist)
		local margin = 1.9*widgetScale
		local left = screenshotPosX-margin
		local bottom = screenshotPosY-margin
		local width = (screenshotWidth*widgetScale)+margin+margin+margin
		local height = (screenshotHeight*widgetScale)+margin+margin+margin+(15*widgetScale)
		if screenshotSaveQueued then
			if (WG['guishader_api'] ~= nil) then
				WG['guishader_api'].InsertRect(left,bottom,left+width,bottom+height,'advplayerlist_screenshot')
				screenshotGuishader = true
			end
			if not screenshotSaved then
				screenshotSaved = 'next'
			elseif screenshotSaved == 'next' then
				screenshotSaved = 'done'
				local file = 'screenshots/'..screenshotFilename..'.png'
				gl.SaveImage(left,bottom,width,height,file)
				Spring.Echo('Screenshot saved to: '..file)
				screenshotSaveQueued = nil
			end
		end
		if screenshotWidth and IsOnRectPlain(mouseX,mouseY, screenshotPosX,screenshotPosY,screenshotPosX+(screenshotWidth*widgetScale),screenshotPosY+(screenshotHeight*widgetScale)) then
			if mouseButtonL then
				gl_DeleteList(screenshotDlist)
				if (WG['guishader_api'] ~= nil) then
					WG['guishader_api'].RemoveRect('advplayerlist_screenshot')
				end
				screenshotDlist = nil
			else
				gl.Color(0,0,0,0.25)
				RectRound(screenshotPosX,screenshotPosY,screenshotPosX+(screenshotWidth*widgetScale),screenshotPosY+(screenshotHeight*widgetScale), 2*widgetScale, true)				-- close button
				local size = (screenshotHeight*widgetScale)*1.2
				local width = size*0.011
				gl.Color(1,1,1,0.66)
				gl.PushMatrix()
				gl.Translate(screenshotPosX+((screenshotWidth*widgetScale)/2), screenshotPosY+((screenshotHeight*widgetScale)/2),0)
				gl.Rotate(-60,0,0,1)
				gl.Rect(-width,size/2,width,-size/2)
				gl.Rotate(120,0,0,1)
				gl.Rect(-width,size/2,width,-size/2)
				gl.PopMatrix()
			end
		end
	end
end


function CreateLists()

	CheckTime() --this also calls CheckPlayers
	
	UpdateRecentBroadcasters()
	UpdateAlliances()
	GetAliveAllyTeams()
	
	if m_resources.active then
		UpdateResources()
	end
	UpdatePlayerResources()
	
	--Create lists
	CreateBackground()
	CreateMainList()
	CreateShareSlider()
end

---------------------------------------------------------------------------------------------------
--  Background gllist
---------------------------------------------------------------------------------------------------

local function DrawRectRound(px,py,sx,sy,cs,ignoreBorder)
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
	
	-- top left
	if (py+((sy-py)*widgetScale) >= vsy-backgroundMargin or px <= backgroundMargin) and ignoreBorder == nil then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, sy-cs, 0)
	-- top right
	if (py+((sy-py)*widgetScale) >= vsy-backgroundMargin or (px+((sx-px)*widgetScale)) >= vsx-backgroundMargin) and ignoreBorder == nil  then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, py+cs, 0)
	-- bottom left
	if (py <= backgroundMargin or px <= backgroundMargin) and ignoreBorder == nil  then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom right
	if (py <= backgroundMargin or (px+((sx-px)*widgetScale)) >= vsx-backgroundMargin) and ignoreBorder == nil  then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, sy-cs, 0)
end
function RectRound(px,py,sx,sy,cs,ignoreBorder)		-- (coordinates work differently than the RectRound func in other widgets)
	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs,ignoreBorder)
	gl.Texture(false)
end

function CreateBackground()
	
	if Background then
		gl_DeleteList(Background)
	end
	local margin = backgroundMargin
	
	
	local BLcornerX = widgetPosX - margin
	local BLcornerY = widgetPosY - margin
	local TRcornerX = widgetPosX + widgetWidth + margin
	local TRcornerY = widgetPosY + widgetHeight - 1 + margin

	if collapsed then
		TRcornerY = widgetPosY - margin + collapsedHeight
	end

	local absLeft		= BLcornerX - ((widgetPosX - BLcornerX) * (widgetScale-1))
	local absBottom		= BLcornerY - ((widgetPosY - BLcornerY) * (widgetScale-1))
	local absRight		= TRcornerX - ((widgetPosX - TRcornerX) * (widgetScale-1))
	local absTop		= TRcornerY - ((widgetPosY - TRcornerY) * (widgetScale-1))
	apiAbsPosition = {absTop,absLeft,absBottom,absRight,widgetScale,right,collapsed}

	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(absLeft,absBottom,absRight,absTop,'advplayerlist')
	end
	Background = gl_CreateList(function()
		gl_Color(0,0,0,ui_opacity)
		RectRound(BLcornerX,BLcornerY,TRcornerX,TRcornerY,6)
		
		local padding = 2.75
		gl_Color(1,1,1,ui_opacity*0.04)
		RectRound(BLcornerX+padding,BLcornerY+padding,TRcornerX-padding,TRcornerY-padding,padding,true)

		if collapsed then
			local text = 'Playerlist'
			local yOffset = collapsedHeight*0.5
			local xOffset = collapsedHeight/6
			gl_Color(0,0,0,0.2)
			gl_Text(text, widgetPosX - 1 + xOffset, TRcornerY-padding -yOffset, 13, "")
			gl_Text(text, widgetPosX + 1 + xOffset, TRcornerY-padding -yOffset, 13, "")
			gl_Color(0.9,0.9,0.9,0.75)
			gl_Text(text, widgetPosX + xOffset, TRcornerY-padding -yOffset+0.8, 13, "n")
		end
		--DrawRect(BLcornerX,BLcornerY,TRcornerX,TRcornerY)
		-- draws highlight (top and left sides)
		--gl_Color(0.44,0.44,0.44,0.38)	
		--gl_Rect(widgetPosX-margin-1,					widgetPosY + widgetHeight +margin, 	widgetPosX + widgetWidth+margin, 			widgetPosY + widgetHeight-1+margin)
		--gl_Rect(widgetPosX-margin-1 , 					widgetPosY-margin, 					widgetPosX-margin, 							widgetPosY-margin + widgetHeight + 1  - 1+margin+margin)
		
		gl_Color(1,1,1,1)
	end)

end

---------------------------------------------------------------------------------------------------
--  Main (player) gllist
---------------------------------------------------------------------------------------------------


function UpdateResources()
	if energyPlayer ~= nil then
		if energyPlayer.team == myTeamID then
			local current,storage = Spring_GetTeamResources(myTeamID,"energy")
			amountEMMax = storage - current
			amountEM = amountEMMax*sliderPosition/39
			amountEM = amountEM-(amountEM%1)			
		else
			amountEMMax = Spring_GetTeamResources(myTeamID,"energy")
			amountEM = amountEMMax*sliderPosition/39
			amountEM = amountEM-(amountEM%1)
		end
	end
	if metalPlayer ~= nil then
		if metalPlayer.team == myTeamID then
			local current, storage = Spring_GetTeamResources(myTeamID,"metal")
			amountEMMax = storage - current
			amountEM = amountEMMax*sliderPosition/39
			amountEM = amountEM-(amountEM%1)			
		else
			amountEMMax = Spring_GetTeamResources(myTeamID,"metal")
			amountEM = amountEMMax*sliderPosition/39
			amountEM = amountEM-(amountEM%1)
		end
	end
end

function CheckTime()
	local period = 0.5
	now = os.clock()
	if  now > (lastTime + period) then
		lastTime = now
		CheckPlayersChange()
		if blink == true then 
			blink = false
		else
			blink = true
		end
		for playerID =0, 63 do
			if player[playerID] ~= nil then
				if player[playerID].pointTime ~= nil then
					if player[playerID].pointTime <= now then
						player[playerID].pointX = nil
						player[playerID].pointY = nil
						player[playerID].pointZ = nil
						player[playerID].pointTime = nil
					end
				end
			end
		end
	end 
end


function CreateMainList(tip)
	
	--Spring.Echo("List Updated")
	
	numberOfSpecs = GetNumberOfSpecs()
		
	local mouseX,mouseY = Spring_GetMouseState()
	local leader
	
	if MainList then
		gl_DeleteList(MainList)
	end
	MainList = gl_CreateList(function()
		drawTipText = nil
		for i, drawObject in ipairs(drawList) do
			if drawObject == -5 then
				specsLabelOffset = drawListOffset[i]
				local specAmount = numberOfSpecs
				if numberOfSpecs == 0 or (specListShow and numberOfSpecs < 10) then 
					specAmount = ""
				end
				DrawLabel(" Spectators  "..specAmount, drawListOffset[i], specListShow)
				if Spring.GetGameFrame() <= 0 then
					if specListShow then
						DrawLabelTip("(click to hide specs)", drawListOffset[i], 95)
					else
						DrawLabelTip("(click to show specs)", drawListOffset[i], 95)
					end
				end
			elseif drawObject == -4 then
				DrawSeparator(drawListOffset[i])
			elseif drawObject == -3 then
				DrawLabel(" Enemies", drawListOffset[i], true)
			elseif drawObject == -2 then
				DrawLabel(" Allies", drawListOffset[i], true)
				if Spring.GetGameFrame() <= 0 then
					DrawLabelTip("(dbl-click playername to track)", drawListOffset[i], 46)
				end
			elseif drawObject == -1 then
				leader = true
			else
				DrawPlayer(drawObject, leader, drawListOffset[i], mouseX, mouseY)
			end
			
			-- draw player tooltip later so they will be on top of players drawn below
			if tipText ~= nil then 
				drawTipText = tipText
				drawTipMouseX = mouseX
				drawTipMouseY = mouseY
			end
			
		end
		if drawTipText ~= nil then 
			tipText = drawTipText
			DrawTip(drawTipMouseX, drawTipMouseY)
		end
	end)
	
end

function DrawLabel(text, vOffset, drawSeparator)
	if widgetWidth < 67 then
		text = string.sub(text, 0, 1)
	end
	gl_Color(0,0,0,0.2)
	gl_Text(text, widgetPosX - 1, widgetPosY + widgetHeight -vOffset+6.6, 12, "")
	gl_Text(text, widgetPosX + 1, widgetPosY + widgetHeight -vOffset+6.6, 12, "")
	gl_Color(0.9,0.9,0.9,0.75)
	gl_Text(text, widgetPosX, widgetPosY + widgetHeight -vOffset+7.5, 12, "n")
	
	if drawSeparator then
		--DrawSeparator(vOffset)
	end
end

function DrawLabelTip(text, vOffset, xOffset)
	if widgetWidth < 67 then
		text = string.sub(text, 0, 1)
	end
	gl_Color(0,0,0,0.08)
	gl_Text(text, widgetPosX + xOffset - 1, widgetPosY + widgetHeight -vOffset+6.8, 10, "")
	gl_Text(text, widgetPosX + xOffset + 1, widgetPosY + widgetHeight -vOffset+6.8, 10, "")
	gl_Color(0.9,0.9,0.9,0.35)
	gl_Text(text, widgetPosX + xOffset, widgetPosY + widgetHeight -vOffset+7.5, 10, "n")
end

function DrawSeparator(vOffset)
	vOffset = vOffset - 2
	gl_Color(0.55,0.55,0.55,0.45)
	gl_Rect(widgetPosX+2, widgetPosY + widgetHeight -vOffset+(1/widgetScale), widgetPosX + widgetWidth-2, widgetPosY + widgetHeight -vOffset)
	gl_Color(0,0,0,0.3)
	gl_Rect(widgetPosX+2, widgetPosY + widgetHeight -vOffset, widgetPosX + widgetWidth-2, widgetPosY + widgetHeight -vOffset-(1/widgetScale))
	gl_Color(1,1,1)
end

function DrawLabelRightside(text, vOffset)
	local textLength = (gl_GetTextWidth(text)*12)*widgetScale
	gl_Color(1,1,1,0.13)
	gl_Text(text, widgetRight - textLength, widgetPosY + widgetHeight -vOffset+7.5, 12, "n")
end


function RecvPlayerBetList(newPlayerBetList)
	playerBetList = newPlayerBetList or {}
end

function DrawPlayer(playerID, leader, vOffset, mouseX, mouseY)
	tipY                 = nil
	local rank           = player[playerID].rank
	local skill	         = player[playerID].skill
	local name           = player[playerID].name
	local team           = player[playerID].team
	local allyteam       = player[playerID].allyteam
	local side           = player[playerID].side
	local red            = player[playerID].red
	local green          = player[playerID].green
	local blue           = player[playerID].blue
	local dark           = player[playerID].dark
	local pingLvl        = player[playerID].pingLvl
	local cpuLvl         = player[playerID].cpuLvl
	local ping           = player[playerID].ping
	local cpu            = player[playerID].cpu
	local country        = player[playerID].country
	local spec           = player[playerID].spec
	local totake         = player[playerID].totake
	local needm          = player[playerID].needm
	local neede          = player[playerID].neede
	local dead           = player[playerID].dead
	local ai	           = player[playerID].ai
	local alliances      = player[playerID].alliances
	local posY           = widgetPosY + widgetHeight - vOffset
	local tipPosY        = widgetPosY + ((widgetHeight - vOffset)*widgetScale)
	
	local alpha = 0.44-- alpha used to show inactivity for specs
	
	if WG['betfrontend'] ~= nil then
		playerScores = WG['betfrontend'].GetPlayerScores()
	end

	alpha = 0.33
	local alphaActivity = 0
	-- keyboard/mouse activity
	if lastActivity[playerID] ~= nil and type(lastActivity[playerID]) == "number" then
			alphaActivity = (8 - math.floor(now-lastActivity[playerID])) / 5.5
			if alphaActivity > 1 then alphaActivity = 1 end
			if alphaActivity < 0 then alphaActivity = 0 end
			alphaActivity = 0.33 + (alphaActivity*0.21)
			alpha = alphaActivity
	end
	-- camera activity
	if recentBroadcasters[playerID] ~= nil and type(recentBroadcasters[playerID]) == "number" then
		local alphaCam = (13 - math.floor(recentBroadcasters[playerID])) / 8.5
		if alphaCam > 1 then alphaCam = 1 end
		if alphaCam < 0 then alphaCam = 0 end
		alpha = 0.33 + (alphaCam*0.42)
		if alpha < alphaActivity then alpha = alphaActivity end
	end
	
	
	if mouseY >= tipPosY and mouseY <= tipPosY + (16*widgetScale) then tipY = true end
	
	
	if (lockPlayerID ~= nil and lockPlayerID == playerID) then -- active
		DrawCamera(posY, true)
	end

	if spec == false then --player
		if not dead and alliances ~= nil and #alliances > 0 then
			DrawAlliances(alliances, posY)
		end
		if leader == true then                              -- take / share buttons
			if mySpecStatus == false then
				if allyteam == myAllyTeamID then
					if m_take.active == true then
						if totake == true then
							DrawTakeSignal(posY)
							if tipY == true then TakeTip(mouseX) end
						end
					end
					if m_share.active == true and dead ~= true then
						DrawShareButtons(posY, needm, neede)
						if tipY == true then ShareTip(mouseX, playerID) end
					end
				end
				if drawAllyButton and dead ~= true then 
					if tipY == true then AllyTip(mouseX, playerID) end
				end
			else
				if m_indent.active == true and Spring_GetMyTeamID() == team then
					DrawDot(posY)
				end
			end
			gl_Color(red,green,blue,1)
			if m_ID.active == true then
				DrawID(team, posY, dark, dead)
			end
			if m_skill.active == true then
				DrawSkill(skill, posY, dark, name)
			end
		end
		gl_Color(red,green,blue,1)
		if m_rank.active == true then
			DrawRank(rank, posY)
		end
		if m_country.active == true and country ~= "" then
			DrawCountry(country, posY)
		end
		--gl_Color(red,green,blue,1)
		gl_Color(1,1,1,0.45)
		if name ~= absentName and m_side.active == true then
			DrawSidePic(team, playerID, posY, leader, dark, ai)
		end
		gl_Color(red,green,blue,1)
		if m_name.active == true then
			DrawName(name, team, posY, dark, playerID)
		end
		if m_alliance.active == true and drawAllyButton and not mySpecStatus and not dead and team ~= myTeamID then
			DrawAlly(posY, player[playerID].team)
		end
		
		if m_resources.active and aliveAllyTeams[allyteam] ~= nil and player[playerID].energy ~= nil then
			if mySpecStatus or myAllyTeamID == allyteam then
				local e = player[playerID].energy
				local es = player[playerID].energyStorage
				local ei = player[playerID].energyIncome
				local m = player[playerID].metal
				local ms = player[playerID].metalStorage
				local mi = player[playerID].metalIncome
				if es > 0 then
					DrawResources(e, es, m, ms, posY, dead)
					if tipY == true then ResourcesTip(mouseX, e, es, ei, m, ms, mi) end
				end
			end
		end
	else -- spectator
		gl_Color(1,1,1,1)
		if specListShow == true and m_name.active == true then
		
			if playerSpecs[playerID] ~= nil and (lockPlayerID ~= nil and lockPlayerID ~= playerID or lockPlayerID == nil) then 
				if recentBroadcasters[playerID] ~= nil and type(recentBroadcasters[playerID]) == "number" then
					DrawCamera(posY, false)
				end
			end
			if playerScores[playerID] ~= nil then
				DrawChips(playerID, posY)
			end
			DrawSmallName(name, team, posY, false, playerID, alpha)
		end		
		
	end
	
	if m_cpuping.active == true then
		if cpuLvl ~= nil then                              -- draws CPU usage and ping icons (except AI and ghost teams)
			DrawPingCpu(pingLvl,cpuLvl,posY,spec,1,cpu,lastFpsData[playerID])
			if tipY == true then PingCpuTip(mouseX, ping, cpu, lastFpsData[playerID], lastGpuMemData[playerID], lastSystemData[playerID], name) end
		end
	end
	
	gl_Color(1,1,1,1)
	if playerID < 64 then
	
		if m_chat.active == true and mySpecStatus == false and spec == false then
			if playerID ~= myPlayerID then
				DrawChatButton(posY)
			end
		end
		
		if m_point.active then
			if player[playerID].pointTime ~= nil then
				if player[playerID].allyteam == myAllyTeamID or mySpecStatus == true then
					--if blink == true then
						DrawPoint(posY, player[playerID].pointTime-now)
					--end
					if tipY == true then PointTip(mouseX) end
				end
			end
		end
		
	end
	leader = false
	gl_Texture(false)
end

function DrawTakeSignal(posY)

	if blink == true then -- Draws a blinking rectangle if the player of the same team left (/take option)
		if right then
			gl_Color(0.7,0.7,0.7)
			gl_Texture(pics["arrowPic"])
			DrawRect(widgetPosX - 14, posY, widgetPosX, posY + 16)
			gl_Color(1,1,1)
			gl_Texture(pics["takePic"])
			DrawRect(widgetPosX - 57, posY - 15, widgetPosX - 12, posY + 32)
		else
			local leftPosX = widgetPosX + widgetWidth
			gl_Color(0.7,0.7,0.7)
			gl_Texture(pics["arrowPic"])
			DrawRect(leftPosX + 14, posY, leftPosX, posY + 16)
			gl_Color(1,1,1)
			gl_Texture(pics["takePic"])
			DrawRect(leftPosX + 12, posY - 15, leftPosX + 57, posY + 32)
		end
	end	
end

function DrawShareButtons(posY, needm, neede)
	gl_Color(1,1,1,1)
	gl_Texture(pics["unitsPic"])                       -- Share UNIT BUTTON
	DrawRect(m_share.posX + widgetPosX  + 1, posY, m_share.posX + widgetPosX  + 17, posY + 16)
	gl_Texture(pics["energyPic"])                      -- share ENERGY BUTTON
	DrawRect(m_share.posX + widgetPosX  + 17, posY, m_share.posX + widgetPosX  + 33, posY + 16)
	gl_Texture(pics["metalPic"])                       -- share METAL BUTTON
	DrawRect(m_share.posX + widgetPosX  + 33, posY, m_share.posX + widgetPosX  + 49, posY + 16)
	gl_Texture(pics["lowPic"])
	if needm == true then
		DrawRect(m_share.posX + widgetPosX  + 33, posY, m_share.posX + widgetPosX  + 49, posY + 16)
	end
	if neede == true then
		DrawRect(m_share.posX + widgetPosX  + 17, posY, m_share.posX + widgetPosX  + 33, posY + 16)	
	end
	gl_Texture(false)
end


function DrawChatButton(posY)
	gl_Texture(pics["chatPic"])
	DrawRect(m_chat.posX + widgetPosX + 1, posY, m_chat.posX + widgetPosX + 17, posY + 16)	
end

function DrawResources(energy, energyStorage, metal, metalStorage, posY, dead)
	local paddingLeft = 2
	local paddingRight = 2
	local barWidth = m_resources.width - paddingLeft - paddingRight
	local y1Offset = 7
	local y2Offset = 5
	if dead then
		y1Offset = 7.4
		y2Offset = 6
	end
	gl_Color(1,1,1,0.14)
	gl_Texture(pics["resbarBgPic"])
	DrawRect(m_resources.posX + widgetPosX + paddingLeft, posY + y1Offset, m_resources.posX + widgetPosX + paddingLeft + barWidth, posY + y2Offset)
	gl_Color(1,1,1,1)
	gl_Texture(pics["resbarPic"])
	DrawRect(m_resources.posX + widgetPosX + paddingLeft, posY + y1Offset, m_resources.posX + widgetPosX + paddingLeft + ((barWidth/metalStorage)*metal), posY + y2Offset)

    if ((barWidth/metalStorage)*metal) > 0.8 then
        local glowsize = 10
        gl_Color(1,1,1.2,0.08)
        gl_Texture(pics["barGlowCenterPic"])
        DrawRect(m_resources.posX + widgetPosX + paddingLeft, posY + y1Offset+glowsize, m_resources.posX + widgetPosX + paddingLeft + ((barWidth/metalStorage)*metal), posY + y2Offset-glowsize)

        gl_Texture(pics["barGlowEdgePic"])
        DrawRect(m_resources.posX + widgetPosX + paddingLeft-(glowsize*1.8), posY + y1Offset+glowsize, m_resources.posX + widgetPosX + paddingLeft, posY + y2Offset-glowsize)
        DrawRect(m_resources.posX + widgetPosX + paddingLeft + ((barWidth/metalStorage)*metal)+(glowsize*1.8), posY + y1Offset+glowsize, m_resources.posX + widgetPosX + paddingLeft + ((barWidth/metalStorage)*metal), posY + y2Offset-glowsize)
    end

	if not dead then
		y1Offset = 11
		y2Offset = 9
	else
		y1Offset = 10
		y2Offset = 8.6
	end
    gl_Color(1,1,0,0.14)
	gl_Texture(pics["resbarBgPic"])
	DrawRect(m_resources.posX + widgetPosX + paddingLeft, posY + y1Offset, m_resources.posX + widgetPosX + paddingLeft + barWidth, posY + y2Offset)
	gl_Color(1,1,0,1)
	gl_Texture(pics["resbarPic"])
	DrawRect(m_resources.posX + widgetPosX + paddingLeft, posY + y1Offset, m_resources.posX + widgetPosX + paddingLeft + ((barWidth/energyStorage)*energy), posY + y2Offset)

    if ((barWidth/energyStorage)*energy) > 0.8 then
        local glowsize = 10
        gl_Color(1,1,0.2,0.08)
        gl_Texture(pics["barGlowCenterPic"])
        DrawRect(m_resources.posX + widgetPosX + paddingLeft, posY + y1Offset+glowsize, m_resources.posX + widgetPosX + paddingLeft + ((barWidth/energyStorage)*energy), posY + y2Offset-glowsize)

        gl_Texture(pics["barGlowEdgePic"])
        DrawRect(m_resources.posX + widgetPosX + paddingLeft-(glowsize*1.8), posY + y1Offset+glowsize, m_resources.posX + widgetPosX + paddingLeft, posY + y2Offset-glowsize)
        DrawRect(m_resources.posX + widgetPosX + paddingLeft + ((barWidth/energyStorage)*energy)+(glowsize*1.8), posY + y1Offset+glowsize, m_resources.posX + widgetPosX + paddingLeft + ((barWidth/energyStorage)*energy), posY + y2Offset-glowsize)
    end
end

function DrawChips(playerID, posY)
	local xPos = m_name.posX + widgetPosX - 6
	gl_Color(0.75,0.75,0.75,0.8)
	gl_Text(playerScores[playerID].score, xPos-5, posY+4, 9.5, "r")
	gl_Color(1,1,1,1)
	gl_Texture(pics["chipPic"])
	DrawRect(xPos+4, posY+3.5, xPos-2.5, posY + 10)
end

function DrawSidePic(team, playerID, posY, leader, dark, ai)
	if gameStarted then
		if leader == true then
			gl_Texture(sidePics[team])                       -- sets side image (for leaders)
		else
			gl_Texture(pics["notFirstPic"])                          -- sets image for not leader of team players
		end
		DrawRect(m_side.posX + widgetPosX  + 2, posY+1, m_side.posX + widgetPosX  + 16, posY + 15) -- draws side image
		--[[if dark == true then	-- draws outline if player color is dark
			gl_Color(1,1,1)
			if leader == true then
				gl_Texture(sidePicsWO[team])
			else
				gl_Texture(notFirstPicWO)
			end
			DrawRect(m_side.posX + widgetPosX + 2, posY+1,m_side.posX + widgetPosX + 16, posY + 15)
			gl_Texture(false)
		end
		]]--
		gl_Texture(false)
	else
		DrawState(playerID, m_side.posX + widgetPosX, posY)
	end
end

function DrawRank(rank, posY)
	if rank == 0 then
		DrawRankImage(pics["rank0"], posY)
	elseif rank == 1 then
		DrawRankImage(pics["rank1"], posY)
	elseif rank == 2 then
		DrawRankImage(pics["rank2"], posY)
	elseif rank == 3 then
		DrawRankImage(pics["rank3"], posY)
	elseif rank == 4 then
		DrawRankImage(pics["rank4"], posY)
	elseif rank == 5 then
		DrawRankImage(pics["rank5"], posY)
	elseif rank == 6 then
		DrawRankImage(pics["rank6"], posY)
	elseif rank == 7 then
		DrawRankImage(pics["rank7"], posY)
	else
		--DrawRankImage(rank8, posY)
	end
	gl_Color(1,1,1,1)
end

function DrawRankImage(rankImage, posY)
	gl_Color(1,1,1)
	gl_Texture(rankImage)
	DrawRect(m_rank.posX + widgetPosX + 3, posY+1, m_rank.posX + widgetPosX + 17, posY + 15)
end


local function RectQuad(px,py,sx,sy)
	local o = 0.008		-- texture offset, because else grey line might show at the edges
	gl.TexCoord(o,1-o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
end
function DrawRect(px,py,sx,sy)
	--local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	gl.BeginEnd(GL.QUADS, RectQuad, px,py,sx,sy)
end

function DrawAlly(posY, team)
	if Spring_AreTeamsAllied(team, myTeamID) then
		gl_Color(0,1,0, 0.44)
	else
		gl_Color(1,0,0, 0.44)
	end
	gl_Texture(pics["allyPic"])
	DrawRect(m_alliance.posX + widgetPosX + 3, posY+1, m_alliance.posX + widgetPosX + 17, posY + 15)
end

function DrawCountry(country, posY)
	if country ~= nil and country ~= "??" then
		gl_Texture(flagsDirectory..string.upper(country)..".dds")
		gl_Color(1,1,1)
		DrawRect(m_country.posX + widgetPosX + 3, posY+1, m_country.posX + widgetPosX + 17, posY + 15)
	end
end

function DrawDot(posY)
	gl_Color(1,1,1,0.70)
	gl_Texture(pics["currentPic"])
	DrawRect(m_indent.posX + widgetPosX-1 , posY+3, m_indent.posX + widgetPosX + 7, posY + 11)
end

function DrawCamera(posY,active)
	if active ~= nil and active then
		gl_Color(1,1,1,0.7)
	else
		gl_Color(1,1,1,0.13)
	end
	gl_Texture(pics["cameraPic"])
	DrawRect(m_indent.posX + widgetPosX-1.5 , posY+2, m_indent.posX + widgetPosX + 9, posY + 12.4)
end

function colourNames(teamID)
    	nameColourR,nameColourG,nameColourB,nameColourA = Spring_GetTeamColor(teamID)
		R255 = math.floor(nameColourR*255)  --the first \255 is just a tag (not colour setting) no part can end with a zero due to engine limitation (C)
        G255 = math.floor(nameColourG*255)
        B255 = math.floor(nameColourB*255)
        if ( R255%10 == 0) then
                R255 = R255+1
        end
        if( G255%10 == 0) then
                G255 = G255+1
        end
        if ( B255%10 == 0) then
                B255 = B255+1
        end
	return "\255"..string.char(R255)..string.char(G255)..string.char(B255) --works thanks to zwzsg
end 

function DrawState(playerID, posX, posY)
-- note that adv pl list uses a phantom pID for absent players, so this will always show unready for players not ingame
	local ready = (playerReadyState[playerID]==1) or (playerReadyState[playerID]==2) or (playerReadyState[playerID]==-1)
	local hasStartPoint = (playerReadyState[playerID]==4)
	if ai then
		gl_Color(0.1,0.1,0.97,1)
	else 
		if ready then
			gl_Color(0.1,0.95,0.2,1)
		else
			if hasStartPoint then
				gl_Color(1,0.65,0.1,1)
			else
				gl_Color(0.8,0.1,0.1,1)	
			end
		end
	end
	gl_Texture(pics["readyTexture"])
	DrawRect(posX, posY - 1 , posX + 16, posY + 16)
	gl_Color(1,1,1,1)
end

function DrawAlliances(alliances, posY)		-- still a problem is that teams with the same/similar color can be misleading
	local posX = widgetPosX + m_name.posX
	local width = m_name.width / #alliances
	local padding = 2
	for i,playerID in pairs(alliances) do
		if player[playerID] ~= nil and player[playerID].red ~= nil then
			gl_Color(0,0,0,0.25)
			RectRound(posX+(width*(i-1)), posY - 3 , posX + (width*i), posY + 19, 2)
			gl_Color(player[playerID].red, player[playerID].green, player[playerID].blue, 0.5)
			RectRound(posX+(width*(i-1)) + padding, posY - 3 + padding , posX + (width*i)- padding, posY + 19 - padding, 2)
		end
	end
	gl_Color(1,1,1,1)
end

function DrawName(name, team, posY, dark, playerID)
    local willSub = ""
	local ignored = WG.ignoredPlayers and WG.ignoredPlayers[name]
    if not gameStarted then 
        if playerID>=64 then
            willSub = (Spring.GetGameRulesParam("Player" .. (playerID-64) .. "willSub")==1) and " (sub)" or "" --pID-64 because apl uses dummy playerIDs for absent players
        else
            willSub = (Spring.GetGameRulesParam("Player" .. (playerID) .. "willSub")==1) and " (sub)" or "" 
        end
    end
    local nameText = name .. willSub  
	
    
    local nameColourR,nameColourG,nameColourB,nameColourA = Spring_GetTeamColor(team)
    local xPadding = 0
    
    -- includes readystate icon if factions arent shown
	if not gameStarted and not m_side.active then
		xPadding = 16
		DrawState(playerID, m_name.posX + widgetPosX, posY)
	end
	if (nameColourR + nameColourG*1.2 + nameColourB*0.4) < 0.8 then
		gl_Text(colourNames(team) .. nameText, m_name.posX + widgetPosX + 3 + xPadding, posY + 4, 14, "o") -- draws name
	else
		gl_Color(0,0,0,0.45)
		gl_Text(nameText, m_name.posX + widgetPosX + 2 + xPadding, posY + 3, 14, "n") -- draws name
		gl_Text(nameText, m_name.posX + widgetPosX + 4 + xPadding, posY + 3, 14, "n") -- draws name
		gl_Color(nameColourR,nameColourG,nameColourB,1)
		gl_Text(nameText, m_name.posX + widgetPosX + 3 + xPadding, posY + 4, 14, "n") -- draws name
	end
	if ignored then
		gl_Color(1,1,1,0.9)	
		local x = m_name.posX + widgetPosX + 2 + xPadding
		local y = posY + 7
		local w = gl_GetTextWidth(nameText) * 14 + 2
		local h = 2
		gl_Texture(false)
		DrawRect(x,y,x+w,y+h)
	end
	gl_Color(1,1,1)	
end


function DrawSmallName(name, team, posY, dark, playerID, alpha)
	if team == nil then
		return
	end
	
	local ignored = WG.ignoredPlayers and WG.ignoredPlayers[name]
	if originalColourNames[playerID] then
		name = originalColourNames[playerID] .. name
	end

	local textindent = 4
	local explayerindent = -3
	if m_indent.active or m_rank.active or m_side.active or m_ID.active then
		textindent = 0
	end
	local nameColourR,nameColourG,nameColourB,nameColourA = 1,1,1,1

	if playerSpecs[playerID] ~= nil then
		nameColourR,nameColourG,nameColourB,nameColourA = Spring_GetTeamColor(team)
		if (nameColourR + nameColourG*1.2 + nameColourB*0.4) < 0.8 then
			gl_Text(colourNames(team) .. name, m_name.posX + textindent + explayerindent + widgetPosX + 3, posY + 4, 11, "o")
		else
			gl_Color(0,0,0,0.3)
			gl_Text(name, m_name.posX + textindent + explayerindent + widgetPosX + 2, posY + 3.2, 11, "n") -- draws name
			gl_Text(name, m_name.posX + textindent + explayerindent + widgetPosX + 4, posY + 3.2, 11, "n") -- draws name
			gl_Color(nameColourR,nameColourG,nameColourB,0.78)
			gl_Text(name, m_name.posX + textindent + explayerindent + widgetPosX + 3, posY + 4, 11, "n")
		end
	else
		gl_Color(0,0,0,0.3)
		gl_Text(name, m_name.posX + textindent + widgetPosX + 2.2, posY + 3.3, 10, "n")
		gl_Text(name, m_name.posX + textindent + widgetPosX + 3.8, posY + 3.3, 10, "n")
		gl_Color(1,1,1,alpha)
		gl_Text(name, m_name.posX + textindent + widgetPosX + 3, posY + 4, 10, "n")
	end
	if ignored then
		gl_Color(1,1,1,0.7)	
		local x = m_name.posX + textindent + widgetPosX + 2.2
		local y = posY + 6
		local w = gl_GetTextWidth(name) * 10 + 2
		local h = 2
		gl_Texture(false)
		DrawRect(x,y,x+w,y+h)
	end
	gl_Color(1,1,1)
end

function DrawID(playerID, posY, dark, dead)
	local spacer = ""
	if playerID < 10 then
		spacer = " "
	end
	local fontSize = 11
	local deadspace = 0
	if dead then
		fontSize = 8
		deadspace = 1.5
		gl_Color(0,0,0,0.4)
	else
		gl_Color(0,0,0,0.6)
	end
	--gl_Text(colourNames(playerID) .. " ".. playerID .. "", m_ID.posX + widgetPosX+4.5, posY + 5, 11, "o")
	gl_Text(spacer .. playerID .. "", m_ID.posX + deadspace + widgetPosX+4.5, posY + 4.1, fontSize, "n")
	if dead then
		gl_Color(1,1,1,0.33)
	else
		gl_Color(1,1,1,0.5)
	end
	gl_Text(spacer .. playerID .. "", m_ID.posX + deadspace + widgetPosX+4.5, posY + 5, fontSize, "n")
	gl_Color(1,1,1)
end

function DrawSkill(skill, posY, dark)
	gl_Text(skill, m_skill.posX + widgetPosX + m_skill.width - 2, posY + 5.3, 9.5, "or")
	gl_Color(1,1,1)
end

function DrawPingCpu(pingLvl, cpuLvl, posY, spec, alpha, cpu, fps)
	gl_Texture(pics["pingPic"])
	if spec then
		local grayvalue = 0.3 + (pingLvl / 15)
		gl_Color(grayvalue,grayvalue,grayvalue,(0.2*pingLvl))
		DrawRect(m_cpuping.posX + widgetPosX  + 12, posY+1, m_cpuping.posX + widgetPosX  + 21, posY + 14)
	else
		gl_Color(pingCpuColors[pingLvl].r,pingCpuColors[pingLvl].g,pingCpuColors[pingLvl].b)
		DrawRect(m_cpuping.posX + widgetPosX  + 12, posY+1, m_cpuping.posX + widgetPosX  + 24, posY + 15)
	end
	
	grayvalue = 0.7 + (cpu/135)
	
	if cpuText ~= nil and cpuText then
		if type(cpu) == "number" then
			if cpu > 99 then
				cpu = 99
			end
			if spec then
				gl_Color(0,0,0,0.1+(grayvalue*0.4))
				gl_Text(cpu, m_cpuping.posX + widgetPosX+11, posY + 4.3, 9, "r")
				gl_Color(grayvalue,grayvalue,grayvalue,0.66*alpha*grayvalue)
				gl_Text(cpu, m_cpuping.posX + widgetPosX+11, posY + 5.3, 9, "r")
			else
				gl_Color(0,0,0,0.12+(grayvalue*0.44))
				gl_Text(cpu, m_cpuping.posX + widgetPosX+11, posY + 4.3, 9.5, "r")
				gl_Color(grayvalue,grayvalue,grayvalue,0.8*alpha*grayvalue)
				gl_Text(cpu, m_cpuping.posX + widgetPosX+11, posY + 5.3, 9.5, "r")
			end
			gl_Color(1,1,1)
		end
	else
	
		if fps ~= nil then
			if fps > 99 then
				fps = 99
			end
			grayvalue = 0.95 - (fps/195)
			if fps < 0 then
				fps = 0
				greyvalue = 1
			end
			if spec then
				gl_Color(0,0,0,0.1+(grayvalue*0.4))
				gl_Text(fps, m_cpuping.posX + widgetPosX+11, posY + 4.3, 9, "r")
				gl_Color(grayvalue,grayvalue,grayvalue,0.77*alpha*grayvalue)
				gl_Text(fps, m_cpuping.posX + widgetPosX+11, posY + 5.3, 9, "r")
			else
				gl_Color(0,0,0,0.12+(grayvalue*0.44))
				gl_Text(fps, m_cpuping.posX + widgetPosX+11, posY + 4.3, 9.5, "r")
				gl_Color(grayvalue,grayvalue,grayvalue,alpha*grayvalue)
				gl_Text(fps, m_cpuping.posX + widgetPosX+11, posY + 5.3, 9.5, "r")
			end
			gl_Color(1,1,1)
		else
			gl_Texture(pics["cpuPic"])
			if spec then
				gl_Color(grayvalue,grayvalue,grayvalue,0.1+(0.14*cpuLvl))
				DrawRect(m_cpuping.posX + widgetPosX + 2 , posY+1, m_cpuping.posX + widgetPosX  + 13, posY + 14)
			else
				gl_Color(pingCpuColors[cpuLvl].r,pingCpuColors[cpuLvl].g,pingCpuColors[cpuLvl].b)
				DrawRect(m_cpuping.posX + widgetPosX  + 1, posY+1, m_cpuping.posX + widgetPosX  + 14, posY + 15)
			end
		end
	end
end

function DrawPoint(posY,pointtime)
	if right == true then
		gl_Color(1,0,0,pointtime/pointDuration)
		gl_Texture(pics["arrowPic"])
		DrawRect(widgetPosX - 18, posY, widgetPosX - 2, posY+ 14)
		gl_Color(1,1,1,pointtime/pointDuration)
		gl_Texture(pics["pointPic"])
		DrawRect(widgetPosX - 33, posY-1, widgetPosX - 17, posY + 15)
	else
		leftPosX = widgetPosX + widgetWidth
		gl_Color(1,0,0,pointtime/pointDuration)
		gl_Texture(pics["arrowPic"])
		DrawRect(leftPosX + 18, posY, leftPosX + 2, posY + 14)
		gl_Color(1,1,1,pointtime/pointDuration)
		gl_Texture(pics["pointPic"])
		DrawRect(leftPosX + 33, posY-1, leftPosX + 17, posY + 15)
	end
	gl_Color(1,1,1,1)
end

function TakeTip(mouseX)
	if right == true then
		if mouseX >= widgetPosX - 57 * widgetScale  and  mouseX <= widgetPosX - 1 * widgetScale then
			tipText = "Click to take abandoned units"
		end
	else
		local leftPosX = widgetPosX + widgetWidth
		if mouseX >= leftPosX + 1 * widgetScale  and  mouseX <= leftPosX + 57 * widgetScale then
			tipText = "Click to take abandoned units"
		end		
	end
end

function ShareTip(mouseX, playerID)
	if playerID == myPlayerID then
		if mouseX >= widgetPosX + (m_share.posX  + 1) * widgetScale  and  mouseX <= widgetPosX + (m_share.posX + 17) * widgetScale then
			tipText = "Double click to ask for Unit support"
		elseif mouseX >= widgetPosX + (m_share.posX + 19) * widgetScale  and  mouseX <= widgetPosX + (m_share.posX + 35) * widgetScale then
			tipText = "Click and drag to ask for Energy"
		elseif mouseX >= widgetPosX + (m_share.posX + 37) * widgetScale  and  mouseX <= widgetPosX + (m_share.posX + 53) * widgetScale then
			tipText = "Click and drag to ask for Metal"
		end
	else
		if mouseX >= widgetPosX + (m_share.posX + 1) * widgetScale  and  mouseX <= widgetPosX + (m_share.posX + 17) * widgetScale then
			tipText = "Double click to share Units"
		elseif mouseX >= widgetPosX + (m_share.posX + 19) * widgetScale  and  mouseX <= widgetPosX + (m_share.posX + 35) * widgetScale then
			tipText = "Click and drag to share Energy"
		elseif mouseX >= widgetPosX + (m_share.posX + 37) * widgetScale  and  mouseX <= widgetPosX + (m_share.posX + 53) * widgetScale then
			tipText = "Click and drag to share Metal"
		end
	end
end


function AllyTip(mouseX, playerID)
	if mouseX >= widgetPosX + (m_alliance.posX  + 1) * widgetScale and mouseX <=  widgetPosX + (m_alliance.posX + 11) * widgetScale then		
		if Spring_AreTeamsAllied(player[playerID].team, myTeamID) then
			tipText = "Click to become enemy"
		else
			tipText = "Click to become ally"
		end
	end
end


function ResourcesTip(mouseX, e, es, ei, m, ms, mi)
	if mouseX >= widgetPosX + (m_resources.posX  + 1) * widgetScale and mouseX <=  widgetPosX + (m_resources.posX + m_resources.width) * widgetScale then	
		if e > 1000 then
			e = math.floor(e / 100) * 100
		else
			e = math.floor(e / 10) * 10
		end
		if m > 1000 then
			m = math.floor(m / 100) * 100
		else
			m = math.floor(m / 10) * 10
		end
		if ei == nil then
			ei = 0
			mi = 0
		end
		ei = math.floor(ei)
		mi = math.floor(mi)
		if ei > 1000 then
			ei = math.floor(ei / 100) * 100
		elseif ei > 100 then
			ei = math.floor(ei / 10) * 10
		end
		if mi > 200 then
			mi = math.floor(mi / 10) * 10
		end
		if e >= 10000 then e = math.floor(e/1000).."k" end
		if m >= 10000 then e = math.floor(m/1000).."k" end
		if ei >= 10000 then ei = math.floor(ei/1000).."k" end
		if mi >= 10000 then ei = math.floor(mi/1000).."k" end
		tipText = "\255\255\255\000+"..ei.."\n\255\255\255\000"..e.."\n\255\255\255\255"..m.."\n\255\255\255\255+"..mi
	end
end


function PingCpuTip(mouseX, pingLvl, cpuLvl, fps, gpumem, system, name)
	if mouseX >= widgetPosX + (m_cpuping.posX + 13) * widgetScale and mouseX <=  widgetPosX + (m_cpuping.posX + 23) * widgetScale  then
		if pingLvl < 2000 then
			pingLvl = pingLvl.." ms"
		elseif pingLvl >= 2000 and pingLvl < 60000 then
			pingLvl = round(pingLvl/1000,0).." sec"
		elseif pingLvl >= 60000 then
			pingLvl = round(pingLvl/60000,0).." min"
		end
		tipText = "Ping: "..pingLvl
	elseif mouseX >= widgetPosX + (m_cpuping.posX  + 1) * widgetScale and mouseX <=  widgetPosX + (m_cpuping.posX + 11) * widgetScale then	
		tipText = "Cpu: "..cpuLvl.."%"
		if fps ~= nil then 
			tipText = "FPS: "..fps.."    "..tipText
		end
		if gpumem ~= nil then
			tipText = tipText.."    Gpu mem: "..gpumem.."%"
		end
		if system ~= nil then 
			tipText = "\255\000\000\000"..name.."\n\255\233\180\180"..tipText.."\n\255\240\240\240"..system
		end
	end
end

function PointTip(mouseX)
	if right == true then
		if mouseX >= widgetPosX - 28 * widgetScale  and  mouseX <= widgetPosX - 1 * widgetScale then
			tipText = "Click to reach the last point set by the player"
		end
	else
		local leftPosX = widgetPosX + widgetWidth
		if mouseX >= leftPosX + 1 * widgetScale  and  mouseX <= leftPosX + 28 * widgetScale then
			tipText = "Click to reach the last point set by the player"
		end		
	end
end


function stringToLines(str)
  local t = {}
  local function helper(line) t[#t+1] = line return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

	
function DrawTip(mouseX, mouseY)
	
	local scaleDiffX = -((widgetPosX*widgetScale)-widgetPosX)/widgetScale
	local scaleDiffY = -((widgetPosY*widgetScale)-widgetPosY)/widgetScale
	local scaleReset = widgetScale / widgetScale / widgetScale
	gl.Translate(-scaleDiffX,-scaleDiffY,0)
	gl.Scale(scaleReset,scaleReset,0)
	
	text = tipText --this is needed because we're inside a gllist
	if text ~= nil then
		local fontSize = 14*widgetScale
		local tw = fontSize*gl_GetTextWidth(text) + (20*widgetScale)
		local _, lines = string.gsub(text, "\n", "")
		lines = lines + 1
		
		local lineHeight = fontSize + (fontSize/4.5)
		local th = lineHeight * lines + (fontSize*0.75)

		local oldWidgetScale = widgetScale
		widgetScale = 1

		local bottomY = mouseY-(th-(26*oldWidgetScale))
		local ycorrection = 0
		if bottomY < 0 then ycorrection = (15*widgetScale)-bottomY end
		
		local padding = -1.8*oldWidgetScale

		local xoffset = -15*oldWidgetScale
		if right then
			gl_Color(0.8,0.8,0.8,0.75)
			RectRound(mouseX-tw+padding+xoffset, bottomY+ycorrection+padding, mouseX+xoffset-padding, (mouseY+(26*oldWidgetScale)+ycorrection)-padding, 4.5*oldWidgetScale)

			padding = 0*oldWidgetScale
			gl_Color(0,0,0,0.28)
			RectRound(mouseX-tw+padding+xoffset, bottomY+ycorrection+padding, mouseX+xoffset-padding, (mouseY+(26*oldWidgetScale)+ycorrection)-padding, 3.5*oldWidgetScale)
		else
			xoffset = 22*oldWidgetScale
			gl_Color(0.8,0.8,0.8,0.75)
			RectRound(mouseX+padding+xoffset, bottomY+ycorrection+padding, mouseX+tw+xoffset-padding, (mouseY+(26*oldWidgetScale)+ycorrection)-padding, 4.5*oldWidgetScale)

			padding = 0*oldWidgetScale
			gl_Color(0,0,0,0.28)
			RectRound(mouseX+padding+xoffset, bottomY+ycorrection+padding, mouseX+tw+xoffset+padding, (mouseY+(26*oldWidgetScale)+ycorrection)-padding, 3.5*oldWidgetScale)
		end
		widgetScale = oldWidgetScale
	
		-- draw text
		local textLines = stringToLines(text)
		th = 0
		gl.BeginText()
		for i, line in ipairs(textLines) do

			if right then
				gl_Text('\255\244\244\244'..line, mouseX+xoffset+(8*widgetScale)-tw, mouseY+(8*widgetScale)+ycorrection+th, fontSize, "o")
			else
				gl_Text('\255\244\244\244'..line, mouseX+xoffset+(8*widgetScale), mouseY+(8*widgetScale)+ycorrection+th, fontSize, "o")
			end
			th = th - lineHeight
		end
		gl.EndText()
	end
	tipText = nil

	gl.Color(1,1,1,1)
	gl.Scale(widgetScale,widgetScale,0)
	gl.Translate(scaleDiffX,scaleDiffY,0)
end

---------------------------------------------------------------------------------------------------
--  Share slider gllist
---------------------------------------------------------------------------------------------------

function CreateShareSlider()

	if ShareSlider then
		gl_DeleteList(ShareSlider)
	end
	
	ShareSlider = gl_CreateList(function()

	local posY
	if energyPlayer ~= nil then
		posY = widgetPosY + widgetHeight - energyPlayer.posY
		gl_Texture(pics["barPic"])
		DrawRect(m_share.posX + widgetPosX  + 16,posY-3,m_share.posX + widgetPosX  + 34,posY+58)
		gl_Texture(pics["energyPic"])
		DrawRect(m_share.posX + widgetPosX  + 17,posY+sliderPosition,m_share.posX + widgetPosX  + 33,posY+16+sliderPosition)
		gl_Texture(pics["amountPic"])
		if right == true then
			DrawRect(m_share.posX + widgetPosX  - 28,posY-1+sliderPosition, m_share.posX + widgetPosX  + 19,posY+17+sliderPosition)
			gl_Texture(false)
			gl_Text(amountEM.."", m_share.posX + widgetPosX  - 5,posY+3+sliderPosition)
		else
			DrawRect(m_share.posX + widgetPosX  + 76,posY-1+sliderPosition, m_share.posX + widgetPosX  + 31,posY+17+sliderPosition)
			gl_Texture(false)
			gl_Text(amountEM.."", m_share.posX + widgetPosX  + 55,posY+3+sliderPosition)				
		end
	elseif metalPlayer ~= nil then
		posY = widgetPosY + widgetHeight - metalPlayer.posY
		gl_Texture(pics["barPic"])
		DrawRect(m_share.posX + widgetPosX  + 32,posY-3,m_share.posX + widgetPosX  + 50,posY+58)
		gl_Texture(pics["metalPic"])
		DrawRect(m_share.posX + widgetPosX  + 33, posY+sliderPosition,m_share.posX + widgetPosX  + 49,posY+16+sliderPosition)
		gl_Texture(pics["amountPic"])
		if right == true then
			DrawRect(m_share.posX + widgetPosX  - 12,posY-1+sliderPosition, m_share.posX + widgetPosX  + 35,posY+17+sliderPosition)
			gl_Texture(false)
			gl_Text(amountEM.."", m_share.posX + widgetPosX  + 11,posY+3+sliderPosition)
		else
			DrawRect(m_share.posX + widgetPosX  + 88,posY-1+sliderPosition, m_share.posX + widgetPosX  + 47,posY+17+sliderPosition)
			gl_Texture(false)
			gl_Text(amountEM.."", m_share.posX + widgetPosX  + 71,posY+3+sliderPosition)
		end
	end
	
	end)
end

function GetCpuLvl(cpuUsage)

	-- set the 5 cpu usage levels (green to red)

	if cpuUsage < 0.15 then return 1
	elseif cpuUsage < 0.3 then return 2
	elseif cpuUsage < 0.45 then return 3
	elseif cpuUsage < 0.65 then return 4
	else return 5
	end

end

function GetPingLvl(ping)

	-- set the 5 ping levels (green to red)

	if ping < 0.15 then return 1
	elseif ping < 0.3 then return 2
	elseif ping < 0.7 then return 3
	elseif ping < 1.5 then return 4
	else return 5
	end
end


---------------------------------------------------------------------------------------------------
--  Mouse 
---------------------------------------------------------------------------------------------------

local prevClickedName
local clickedName

function widget:MousePress(x,y,button) --super ugly code here

	if collapsed then return end

	local t = false       -- true if the object is a team leader
	local clickedPlayer
	local posY
	local clickTime = os.clock()
	if button == 1 then
		local alt,ctrl,meta,shift = Spring.GetModKeyState() 
		sliderPosition = 0
		amountEM = 0
		-- spectators label onclick
		posY = widgetPosY + widgetHeight - specsLabelOffset
		if numberOfSpecs > 0 and IsOnRect(x, y, widgetPosX + 2, posY+2, widgetPosX + widgetWidth - 2, posY+20) then
			specListShow = not specListShow
			SetModulesPositionX() --why?
			SortList()
			CreateLists()
			return true 
		end 
		
		for _,i in ipairs(drawList) do  -- i = object #
			if i > -1 then
				clickedPlayer = player[i]
				clickedPlayer.id = i
				clickedName = clickedPlayer.name
				posY = widgetPosY + widgetHeight - clickedPlayer.posY
			end
			
			if mySpecStatus == true then
				
				if i == -1 then
					t = true
				else
					t = false
					if m_point.active  then
						if i > -1 and i < 64 then
							if clickedPlayer.pointTime ~= nil then
								if right == true then
									if IsOnRect(x,y, widgetPosX - 33, posY - 2,widgetPosX - 17, posY + 16) then                           --point button
										Spring.SetCameraTarget(clickedPlayer.pointX,clickedPlayer.pointY,clickedPlayer.pointZ,1)          --                                       --
										return true                                                                                       --
									end                                                                                                   --
								else                                                                                                      --
									if IsOnRect(x,y, widgetPosX + widgetWidth + 17, posY-2,widgetPosX + widgetWidth + 33, posY + 16) then --
										Spring.SetCameraTarget(clickedPlayer.pointX,clickedPlayer.pointY,clickedPlayer.pointZ,1)                                                  --
										return true
									end
								end
							end
						end
					end
				end
				if i>-1 and i<64 then
					if m_name.active and clickedPlayer.name ~= absentName and IsOnRect(x, y, m_name.posX + widgetPosX +1, posY, m_name.posX + widgetPosX + m_name.width, posY+16) then
						if ctrl then 
							Spring_SendCommands{"toggleignore "..clickedPlayer.name} 
							return true 
						end

						if (mySpecStatus or player[i].allyteam == myAllyTeamID) and clickTime - prevClickTime < dblclickPeriod and clickedName == prevClickedName then 
							LockCamera(i)
							prevClickedName = ''
							SortList()
							CreateLists()
							return true
						end 
						prevClickedName = clickedName
					end
				end 
				
			else
				if t == true then
					if clickedPlayer.allyteam == myAllyTeamID then
						if m_take.active == true then
							if clickedPlayer.totake == true then
								if right == true then
									if IsOnRect(x,y, widgetPosX - 57, posY ,widgetPosX - 12, posY + 17) then                            --take button
										Take(clickedPlayer.team, clickedPlayer.name, i)                                                                                             --
										return true                                                                                        --
									end                                                                                                    --
								else                                                                                                       --
									if IsOnRect(x,y, widgetPosX + widgetWidth + 12, posY ,widgetPosX + widgetWidth + 57, posY + 17) then  --
										Take(clickedPlayer.team, clickedPlayer.name, i)                                                                                             --
										return true
									end
								end
							end
						end
						if m_share.active == true and clickedPlayer.dead ~= true then
							if IsOnRect(x, y, m_share.posX + widgetPosX +1, posY, m_share.posX + widgetPosX +17,posY+16) then       -- share units button
								if release ~= nil then                                                                                --
									if release >= now then                                                                            --
										if clickedPlayer.team == myTeamID then                                                        --
											Spring_SendCommands("say a: I need unit support!")                                        -- (ask)
										else                                                                                          --
											local suc = Spring.GetSelectedUnitsCount()
											Spring_SendCommands("say a: I gave "..suc.." units to "..clickedPlayer.name..".")
											local su = Spring.GetSelectedUnits()
											for _,uid in ipairs(su) do
												local ux,uy,uz = Spring.GetUnitPosition(uid)
												Spring.MarkerAddPoint(ux,uy,uz)
											end
											Spring_ShareResources(clickedPlayer.team, "units")                                                            --
										end
									end
									release = nil
								else	
									firstclick = now+1
								end
								return true
							end
							if IsOnRect(x, y, m_share.posX + widgetPosX +17, posY, m_share.posX + widgetPosX +33,posY+16) then      -- share energy button (initiates the slider)
								energyPlayer = clickedPlayer
								return true
							end
							if IsOnRect(x, y, m_share.posX + widgetPosX +33, posY, m_share.posX + widgetPosX +49,posY+16) then      -- share metal button (initiates the slider)
								metalPlayer = clickedPlayer
								return true
							end
						end
					end
				end
				if i == -1 then
					t = true
				else
					t = false
					if i > -1 and i < 64 then
						--chat button
						if m_chat.active == true then
							if IsOnRect(x, y, m_chat.posX + widgetPosX +1, posY, m_chat.posX + widgetPosX +17,posY+16) then
								Spring_SendCommands("chatall","pastetext /w "..clickedPlayer.name..' \1')
								return true 
							end
						end 
						--ally button
						if m_alliance.active == true and drawAllyButton and not mySpecStatus and player[i] ~= nil and player[i].dead ~= true and i ~= myPlayerID then    
							if IsOnRect(x, y, m_alliance.posX + widgetPosX +1, posY, m_alliance.posX + widgetPosX + m_alliance.width,posY+16) then
								if Spring_AreTeamsAllied(player[i].team, myTeamID) then
									Spring_SendCommands("ally "..player[i].allyteam.." 0")
								else
									Spring_SendCommands("ally "..player[i].allyteam.." 1")
								end
								return true 
							end
						end
						--point
						if m_point.active then
							if clickedPlayer.pointTime ~= nil then
								if clickedPlayer.allyteam == myAllyTeamID then
									if right == true then
										if IsOnRect(x,y, widgetPosX - 28, posY - 1,widgetPosX - 12, posY + 17) then
											Spring.SetCameraTarget(clickedPlayer.pointX,clickedPlayer.pointY,clickedPlayer.pointZ,1)
											return true
										end
									else
										if IsOnRect(x,y, widgetPosX + widgetWidth + 12, posY-1,widgetPosX + widgetWidth + 28, posY + 17) then
											Spring.SetCameraTarget(clickedPlayer.pointX,clickedPlayer.pointY,clickedPlayer.pointZ,1)
											return true
										end
									end
								end
							end
						end
						--name
						if m_name.active and clickedPlayer.name ~= absentName and IsOnRect(x, y, m_name.posX + widgetPosX +1, posY, m_name.posX + widgetPosX + m_name.width, posY+12)  then
							if ctrl then 
								Spring_SendCommands{"toggleignore "..clickedPlayer.name} 
								SortList()
								CreateLists()
								return true 
							end
							if (mySpecStatus or player[i].allyteam == myAllyTeamID) and clickTime - prevClickTime < dblclickPeriod and clickedName == prevClickedName then 
								LockCamera(clickedPlayer.team)
								prevClickedName = ''
								SortList()
								CreateLists()
								return true
							end 
							prevClickedName = clickedName
						end
					end
				end
			end
		end
	end
	prevClickTime = clickTime
end

local mouseX, mouseY = 0,0
function widget:MouseMove(x,y,dx,dy,button)

  if collapsed then return end

  mouseX, mouseY = x, y
  local moveStartX, moveStartY
	if energyPlayer ~= nil or metalPlayer ~= nil then                            -- move energy/metal share slider
		if sliderOrigin == nil then
			sliderOrigin = y
		end
		sliderPosition = (y-sliderOrigin) * (1/widgetScale)
		if sliderPosition < 0 then sliderPosition = 0 end
		if sliderPosition > 39 then sliderPosition = 39 end
        local prevAmountEM = amountEM
		UpdateResources()
        if playSounds and (lastSliderSound == nil or os.clock() - lastSliderSound > 0.05) and amountEM ~= prevAmountEM then
            lastSliderSound = os.clock()
            Spring.PlaySoundFile(sliderdrag, 0.3, 'ui')
        end
	end
end

function widget:MouseRelease(x,y,button)

	if collapsed then return end

	if button == 1 then
		if firstclick ~= nil then                                                  -- double click system for share units
			release = firstclick
			firstclick = nil
		else
			release = nil
		end
		if energyPlayer ~= nil then                                                -- share energy/metal mouse release
			if energyPlayer.team == myTeamID then
				if amountEM == 0 then
					Spring_SendCommands("say a: I need Energy!")
				else
					Spring_SendCommands("say a: I need "..amountEM.." Energy!")
				end
			elseif amountEM > 0 then
				Spring_ShareResources(energyPlayer.team, "energy", amountEM)
				Spring_SendCommands("say a: I sent "..amountEM.." energy to "..energyPlayer.name)
			end
			sliderOrigin = nil
			amountEMMax = nil
			sliderPosition = nil
			amountEM = nil
			energyPlayer = nil
		end
		
		if metalPlayer ~= nil then
			if metalPlayer.team == myTeamID then
				if amountEM == 0 then
					Spring_SendCommands("say a: I need Metal!")
				else
					Spring_SendCommands("say a: I need "..amountEM.." Metal!")
				end
			elseif amountEM > 0 then
				Spring_ShareResources(metalPlayer.team, "metal", amountEM)
				Spring_SendCommands("say a: I sent "..amountEM.." metal to "..metalPlayer.name)
			end
			sliderOrigin = nil
			amountEMMax = nil
			sliderPosition = nil
			amountEM = nil
			metalPlayer = nil
		end
	end
end

function Spec(teamID)
	Spring_SendCommands{"specteam "..teamID}
	specTarget = teamID
	SortList()
end


---------------------------------------------------------------------------------------------------
--  Tweak mode
---------------------------------------------------------------------------------------------------

function IsOnRectPlain(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	
	-- calc scale offset
	BLcornerX = BLcornerX - ((widgetPosX - BLcornerX) * (widgetScale-1))
	BLcornerY = BLcornerY - ((widgetPosY - BLcornerY) * (widgetScale-1))
	TRcornerX = TRcornerX - ((widgetPosX - TRcornerX) * (widgetScale-1))
	TRcornerY = TRcornerY - ((widgetPosY - TRcornerY) * (widgetScale-1))
	
	-- check if the mouse is in a rectangle
	return x >= BLcornerX and x <= TRcornerX
	                      and y >= BLcornerY
	                      and y <= TRcornerY
end

local function DrawGreyRect()
	gl_Color(0.2,0.2,0.2,0.25)
	gl_Rect(widgetPosX, widgetPosY, widgetPosX + widgetWidth, widgetPosY + widgetHeight)
	gl_Color(1,1,1,1)
end

local function DrawTweakButton(module,  localLeft, localOffset, localBottom)
	gl_Texture(module.pic)
	DrawRect(localLeft + localOffset, localBottom + 11, localLeft + localOffset + 16, localBottom + 27)
	if module.active ~= true and module.alwaysActive == nil then
		gl_Texture(pics["crossPic"])
		DrawRect(localLeft + localOffset, localBottom + 11, localLeft + localOffset + 16, localBottom + 27)
	end
end

local function DrawTweakButtons()
	
	local minSize = (modulesCount-1) * 16 + 2
	local localLeft     = widgetPosX
	local localBottom   = widgetPosY + widgetHeight - 28
	local localOffset   = 1 --see func above, these track how far right we've got TODO: pass values
	
	gl_Color(0,0,0,0.5)
	RectRound(localLeft-3, localBottom + 8, localLeft + widgetWidth+3, localBottom + 30, 5, true)
	
	gl_Color(1,1,1,1)
	--if localLeft + minSize > vsx then localLeft = vsx - minSize end 
	if localBottom < 0 then localBottom = 0 end
	
	for n,module in pairs(modules) do
		if module.noPic == nil or module.noPic == false then
			if mySpecStatus == false or mySpecStatus == true and module.spec then
				DrawTweakButton(module, localLeft, localOffset, localBottom)
				localOffset = localOffset + 16
			end
		end
		if module.picGap ~= nil then
			if mySpecStatus == false or mySpecStatus == true and module.spec then
				localOffset = localOffset + module.picGap
			end
		end
	end
	
end

local function DrawArrows()
	gl_Color(1,1,1,0.4)
	gl_Texture(pics["arrowdPic"])
	if expandDown == true then
		DrawRect(widgetPosX, widgetPosY - 15, widgetRight, widgetPosY - 1)
	else
		DrawRect(widgetPosX, widgetTop + 15, widgetRight, widgetTop + 1)
	end
		gl_Texture(pics["arrowPic"])
	if expandLeft == true then
		DrawRect(widgetPosX - 1, widgetPosY, widgetPosX - 15, widgetTop)
	else
		DrawRect(widgetRight + 1, widgetPosY, widgetRight + 15, widgetTop)
	end
	gl_Color(1,1,1,1)
	gl_Texture(false)
end

function widget:TweakDrawScreen()

	if collapsed then return end

	local scaleDiffX = -((widgetPosX*widgetScale)-widgetPosX)/widgetScale
	local scaleDiffY = -((widgetPosY*widgetScale)-widgetPosY)/widgetScale
	gl.Scale(widgetScale,widgetScale,0)
	gl.Translate(scaleDiffX,scaleDiffY,0)
	
	--DrawGreyRect()
	DrawTweakButtons()
	--DrawArrows()

	CreateMainList()
	CreateBackground()
	
	local scaleReset = widgetScale / widgetScale / widgetScale
	gl.Translate(-scaleDiffX,-scaleDiffY,0)
	gl.Scale(scaleReset,scaleReset,0)
end

function checkButton(module, x, y, localLeft, localOffset, localBottom)
	if IsOnRect(x, y, localLeft + localOffset, localBottom + 11, localLeft + localOffset + 16, localBottom + 27) then
		if module.alwaysActive == nil then
			module.active = not module.active
			SetModulesPositionX() --why?
			SortList()
			-- adjust because of widget scaling
			local widthDiff =  (module.width * widgetScale) - module.width
			if module.active then
				widgetRight = widgetRight - widthDiff
			else
				widgetRight = widgetRight + widthDiff
			end
		else
			if module.name == "sizedn" then
				customScaleDown()
			elseif module.name == "sizeup" then
				customScaleUp()
			end
		end
		CreateLists()
		return true
	else
		return false
	end
end

function widget:TweakMousePress(x,y,button)

	if collapsed then return end

	if button == 1 then
		local localLeft = widgetPosX
		local localBottom = widgetPosY + widgetHeight - 28
		local localOffset = 1 
		if localBottom < 0 then localBottom = 0 end
		--if localLeft + 181 > vsx then localLeft = vsx - 181 end
		
		for _,module in pairs(modules) do
			if module.noPic == nil or module.noPic == false then
				if mySpecStatus == false or mySpecStatus == true and module.spec then
					if checkButton(module,x,y,localLeft,localOffset,localBottom) then return true end
					localOffset = localOffset + 16
				end
			end
			if module.picGap ~= nil then
				if mySpecStatus == false or mySpecStatus == true and module.spec then
					localOffset = localOffset + module.picGap
				end
			end
		end
	elseif button == 2 or button == 3 then
		if IsOnRect(x, y, widgetPosX, widgetPosY, widgetPosX + widgetWidth, widgetPosY + widgetHeight) then
			clickToMove = true
			return true
		end
		
	end
end


function widget:TweakMouseMove(x,y,dx,dy,button)

	if collapsed then return end

	if clickToMove ~= nil then
		if moveStartX == nil then                                                      -- move widget on y axis
			moveStartX = x - widgetPosX
		end
		if moveStartY == nil then                                                      -- move widget on y axis
			moveStartY = y - widgetPosY
		end
		widgetPosX = widgetPosX + dx
		widgetPosY = widgetPosY + dy
				
		if widgetPosY <= (backgroundMargin*widgetScale) then
			widgetPosY = (backgroundMargin*widgetScale)
			expandDown = false --expandDown=false only if we are right on the bottom of the screen
		end
		if widgetPosY + (widgetHeight * widgetScale) >= vsy -(backgroundMargin*widgetScale) then
			widgetPosY = vsy - (widgetHeight * widgetScale) -(backgroundMargin*widgetScale)
			expandDown = true
		end
		if widgetPosX <= (backgroundMargin*widgetScale) then --expandLeft=false only when we are precisely on the left edge of the screen
			widgetPosX = (backgroundMargin*widgetScale)
			expandLeft = false
		end
		if widgetPosX + (widgetWidth * widgetScale) >= vsx-(backgroundMargin*widgetScale) then
			widgetPosX = vsx - (widgetWidth * widgetScale) - (backgroundMargin*widgetScale)
			expandLeft = true
		end
		widgetTop   = widgetPosY + widgetHeight
		widgetRight = widgetPosX + widgetWidth
		widgetRelRight = vsx - (widgetPosX + (widgetWidth*widgetScale))
		if widgetPosX + widgetWidth/2 > vsx/2 then
			right = true
		else
			right = false
		end
	end
end

function widget:TweakMouseRelease(x,y,button)

	if collapsed then return end

	clickToMove = nil                                              -- ends the share slider process
end

---------------------------------------------------------------------------------------------------
--  Save/load
---------------------------------------------------------------------------------------------------

function widget:GetConfigData(data)      -- save
	if m_side ~= nil then
		
		--put module.active into a table
		local m_active_Table = {}
		for n,module in pairs(modules) do
			m_active_Table[module.name] = module.active
		end
	
		local settings = {
			--view
			customScale        = customScale,
			vsx                = vsx,
			vsy                = vsy,
			widgetRelRight	   = widgetRelRight, 
			widgetPosX         = widgetPosX,
			widgetPosY         = widgetPosY,
			widgetRight        = widgetRight,
			widgetTop          = widgetTop,
			expandDown         = expandDown,
			expandLeft         = expandLeft,
			specListShow       = specListShow,
			m_pointActive      = m_point.active,
			m_takeActive       = m_take.active,
			m_seespecActive    = m_seespec.active,
			m_active_Table	   = m_active_Table,
			cpuText            = cpuText,
			lockPlayerID       = lockPlayerID,
			specListShow       = specListShow,
			gameFrame          = Spring.GetGameFrame(),
			lastSystemData     = lastSystemData,
			alwaysHideSpecs    = alwaysHideSpecs,
			collapsable        = collapsable,
			transitionTime     = transitionTime,
			lockcameraHideEnemies = lockcameraHideEnemies,
			lockcameraLos      = lockcameraLos,
		}
		
		return settings
	end
end

function widget:SetConfigData(data)      -- load
	if data.customScale ~= nil then
		customScale = data.customScale
	end

	if data.specListShow ~= nil then
		specListShow = data.specListShow
	end

	if data.alwaysHideSpecs ~= nil then
		alwaysHideSpecs = data.alwaysHideSpecs
	end

	if data.lockcameraHideEnemies ~= nil then
		lockcameraHideEnemies = data.lockcameraHideEnemies
	end

	if data.lockcameraLos ~= nil then
		lockcameraLos = data.lockcameraLos
	end

	if data.lockcameraLos ~= nil then
		transitionTime = data.transitionTime
	end

	if data.collapsable ~= nil then
		collapsable = data.collapsable
	end

	--view
	if data.expandDown ~= nil and data.widgetRight ~= nil then
		expandDown   = data.expandDown
		expandLeft   = data.expandLeft
		specListShow = data.specListShow
		local oldvsx = data.vsx
		local oldvsy = data.vsy
		if oldvsx == nil then
			oldvsx = vsx
			oldvsy = vsy		
		end
		local dx     = vsx - oldvsx
		local dy     = vsy - oldvsy
		if expandDown == true then
			widgetTop  = data.widgetTop + dy
			if widgetTop > vsy then
				widgetTop = vsy
			end
		else
			widgetPosY = data.widgetPosY
		end
		if expandLeft == true then
			widgetRelRight = data.widgetRelRight or 0
			widgetRight = vsx - (widgetWidth * (widgetScale-1)) - widgetRelRight --align right of widget to right of screen
			widgetPosX = widgetRight - (widgetWidth*widgetScale)
			if widgetRight > vsx then
				widgetRight = vsx
			end
		else
			widgetPosX  = data.widgetPosX --align left of widget to left of screen
		end
	end
	if data.lockPlayerID ~= nil and Spring.GetGameFrame()>0 then
		lockPlayerID = data.lockPlayerID
		if lockPlayerID and not select(3,Spring_GetPlayerInfo(lockPlayerID)) then
			if not lockcameraHideEnemies then
				if not fullView then
					Spring.SendCommands("specfullview")
					if lockcameraLos and mySpecStatus and Spring.GetMapDrawMode()=="los" then
						desiredLosmode = 'normal'
						desiredLosmodeChanged = os.clock()
					end
				end
			else
				if fullView then
					Spring.SendCommands("specfullview")
					if lockcameraLos and mySpecStatus and Spring.GetMapDrawMode()~="los" then
						desiredLosmode = 'los'
						desiredLosmodeChanged = os.clock()
					end
				end
			end
		end
	end
	if data.cpuText ~= nil then
		cpuText = data.cpuText
	end
	
	--not technically modules
	m_point.active = true -- m_point.default doesnt work
	if data.m_pointActive ~= nil then
		m_point.active = data.m_pointActive
	end
	m_take.active = true -- m_take.default doesnt work
	if data.m_takeActive ~= nil then
		m_take.active = data.m_takeActive
	end
	m_seespec.active = true -- m_seespec.default doesnt work
	if data.m_seespecActive ~= nil then
		m_seespec.active = data.m_seespecActive
	end
	--load module.active from table
	local m_active_Table = data.m_active_Table or {}
	for name,active in pairs(m_active_Table) do
		--find module with matching name 
		for _,module in pairs(modules) do
			if module.name == name then
				if name == "ally" then	-- needs to be always active (some aready stored it as false before, this makes sure its corrected)
					module.active = true
				else
					module.active = module.default
					if active ~= nil then
						module.active = active
					end
				end
			end
		end
	end

	SetModulesPositionX()
	
	if data.lastSystemData ~= nil and data.gameFrame ~= nil and data.gameFrame <= Spring.GetGameFrame() and data.gameFrame > Spring.GetGameFrame()-300 then
		lastSystemData = data.lastSystemData
	end
end

function widget:TextCommand(command)
	if (string.find(command, "cputext") == 1  and  string.len(command) == 7) then
		cpuText = not cpuText
	end
	if (string.find(command, "alwayshidespecs") == 1  and  string.len(command) == 15) then
		alwaysHideSpecs = not alwaysHideSpecs
		if alwaysHideSpecs then
			Spring.Echo("AdvPlayersList: always hiding specs")
			specListShow = false
		else
			Spring.Echo("AdvPlayersList: not always hiding specs")
		end
	end
end

---------------------------------------------------------------------------------------------------
--  Player related changes
---------------------------------------------------------------------------------------------------

function CheckPlayersChange()
	local sorting = false
	for i = 0,63 do
		local name,active,spec,teamID,allyTeamID,pingTime,cpuUsage, country, rank = Spring_GetPlayerInfo(i)
		if active == false then
			if player[i].name ~= nil then                                             -- NON SPEC PLAYER LEAVING
				if player[i].spec==false then
					if table.maxn(Spring_GetPlayerList(player[i].team,true)) == 0 then
						player[player[i].team + 64] = CreatePlayerFromTeam(player[i].team)
						sorting = true
					end
				end
				player[i].name = nil
				player[i] = {}
				sorting = true
			end
		elseif active == true and name ~= nil then
			if spec ~= player[i].spec then                                           -- PLAYER SWITCHING TO SPEC STATUS
				if spec == true then
					if table.maxn(Spring_GetPlayerList(player[i].team,true)) == 0 then   -- (update the no players team)
						player[player[i].team + 64] = CreatePlayerFromTeam(player[i].team)
					end
					player[i].team = nil                                                 -- remove team
				end
				player[i].spec = spec                                                  -- consider player as spec
				sorting = true
			end
			if teamID ~= player[i].team then                                               -- PLAYER CHANGING TEAM
				if table.maxn(Spring_GetPlayerList(player[i].team,true)) == 0 then           -- check if there is no more player in the team + update
					player[player[i].team + 64] = CreatePlayerFromTeam(player[i].team)         
				end
				player[i].team = teamID
				player[i].red, player[i].green, player[i].blue = Spring_GetTeamColor(teamID)
				player[i].dark = GetDark(player[i].red, player[i].green, player[i].blue)
				player[i].skill = GetSkill(i)
				sorting = true
			end
			if player[i].name == nil then
				player[i] = CreatePlayer(i)
			end
			if allyTeamID ~= player[i].allyteam then
				player[i].allyteam = allyTeamID
				updateTake(allyTeamID)
				sorting = true
			end
			
			-- Update stall / cpu / ping info for each player
			if player[i].spec == false then
				player[i].needm   = GetNeed("metal",player[i].team)
				player[i].neede   = GetNeed("energy",player[i].team)
				player[i].rank = rank
			else
				player[i].needm   = false
				player[i].neede   = false
			end
			player[i].pingLvl = GetPingLvl(pingTime)
			player[i].cpuLvl  = GetCpuLvl(cpuUsage)
			player[i].ping    = pingTime*1000-((pingTime*1000)%1)
			player[i].cpu     = cpuUsage*100-((cpuUsage*100)%1)
		end
		
		if teamID and Spring_GetGameFrame() > 0 then
			local totake = IsTakeable(teamID)
			player[i].totake = totake
			if totake then
				sorting = true	
			else
				player[i].name = name
			end
		end
	end

	if sorting == true and not collapsed then    -- sorts the list again if change needs it
		SortList()
		SetModulesPositionX()    -- change the X size if needed (change of widest name)
	end

end



function GetNeed(resType,teamID)
	local current, _, pull, income = Spring_GetTeamResources(teamID, resType)
		if current == nil then return false end
	local loss =  pull - income
	if loss > 0 then
		if loss*5 > current then
			return true
		end
	end
	return false
end

local reportTake = false
local tookTeamID
local tookTeamName
local tookFrame = -120

function updateTake(allyTeamID)
	for i = 0,teamN-1 do
		if player[i + 64].allyTeam == allyTeamID then
			player[i + 64] = CreatePlayerFromTeam(i)
		end
	end
end

function Take(teamID,name, i)

	-- sends the /take command to spring
	reportTake = true
	tookTeamID = teamID
	tookTeamName = name
	tookFrame = Spring.GetGameFrame()
	
	Spring_SendCommands("luarules take2 " .. teamID)
	return
end

function widget:TeamDied(teamID)
	player[teamID+64]        = CreatePlayerFromTeam(teamID)
	SortList()
end

---------------------------------------------------------------------------------------------------
--  Take related stuff
---------------------------------------------------------------------------------------------------

function IsTakeable(teamID)
	if Spring_GetTeamRulesParam(teamID, "numActivePlayers") == 0 then
		local units = Spring_GetTeamUnitCount(teamID)
		local energy = Spring_GetTeamResources(teamID,"energy")
		local metal = Spring_GetTeamResources(teamID,"metal")
		if units and energy and metal then
			if (units > 0) or (energy > 1000) or (metal > 100) then			
				return true
			end
		end
	else
		return false					
	end
end


function isInBox(mx, my, box)
	return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end

--timers
local timeCounter = 0
local updateRate = 0.75
local updateRatePreStart = 0.25
local lastTakeMsg = -120
local uiOpacitySec = 0.5
function widget:Update(delta) --handles takes & related messages

	uiOpacitySec = uiOpacitySec + delta
	if uiOpacitySec>0.5 then
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
			CreateBackground()
		end
	end

	if collapsable then
		local mx,my = Spring.GetMouseState()
		if collapsed and isInBox(mx, my, {apiAbsPosition[2]-1,apiAbsPosition[3]-1,apiAbsPosition[4]+1,apiAbsPosition[1]+1}) then
			collapsed = false
			CreateBackground()
		elseif not collapsed and not energyPlayer and not metalPlayer then
			local graceDistance = 85*widgetScale
			if not isInBox(mx, my, {apiAbsPosition[2]-graceDistance,apiAbsPosition[3]-graceDistance,apiAbsPosition[4]+graceDistance,apiAbsPosition[1]+graceDistance}) then
				collapsed = true
				CreateBackground()
			end
		end
	end

	if collapsed then return end

	totalTime = totalTime + delta 
	timeCounter = timeCounter + delta
	curFrame = Spring_GetGameFrame()
	mySpecStatus,fullView,_ = Spring.GetSpectatingState()

	if sceduledSpecFullView ~= nil then	-- this is needed else the minimap/world doesnt update properly
		Spring.SendCommands("specfullview")
		sceduledSpecFullView = sceduledSpecFullView - 1
		if sceduledSpecFullView == 0 then
			sceduledSpecFullView = nil
		end
	end
	if lockcameraLos then
		if desiredLosmodeChanged+1 > os.clock() then
			if lockPlayerID ~= nil then
				if desiredLosmode ~= Spring.GetMapDrawMode() then	-- this is needed else the minimap/world doesnt update properly
					Spring.SendCommands("togglelos")
				end
			elseif mySpecStatus and Spring.GetMapDrawMode() == 'los' then
				Spring.SendCommands("togglelos")
			end
		end
	end

	if lockPlayerID ~= nil then
		Spring.SetCameraState(Spring.GetCameraState(), transitionTime)
	end
	
	if energyPlayer ~= nil or metalPlayer ~= nil then
		CreateShareSlider()
	end
	
	if curFrame >= 30 + tookFrame then
		if lastTakeMsg + 120 < tookFrame and reportTake then 
			local teamID = tookTeamID
			local afterE = Spring_GetTeamResources(teamID,"energy")
			local afterM = Spring_GetTeamResources(teamID, "metal")
			local afterU = Spring_GetTeamUnitCount(teamID)
	
			local toSay = "say a: I took " .. tookTeamName .. ". "
		
			if afterE and afterM and afterU then
				if afterE > 1.0 or afterM > 1.0 or  afterU > 0 then
					toSay = toSay .. "Left  " .. math.floor(afterU) .. " units, " .. math.floor(afterE) .. " energy and " .. math.floor(afterM) .. " metal."
				end
			end
			
			Spring_SendCommands(toSay)
		
			for j = 0,127 do
				if player[j].allyteam == myAllyTeamID then
					if player[j].totake == true then
						player[j] = CreatePlayerFromTeam(player[j].team)
						SortList()
					end
				end
			end	

			lastTakeMsg = tookFrame
			reportTake = false
		else
			reportTake = false
		end
	end
	
	-- update lists to take account of allyteam faction changes before gamestart
	if not curFrame or curFrame <=0 then 
		if timeCounter < updateRatePreStart then
			return
		else
			timeCounter = 0
			SetSidePics() --if the game hasn't started, update factions
			CreateLists()
		end
	end
	
	-- update lists every now and then, just to make sure
	if timeCounter < updateRate then
		return
	else
		timeCounter = 0
		CreateLists()
	end
end


---------------------------------------------------------------------------------------------------
--  Other callins
---------------------------------------------------------------------------------------------------

function updateWidgetScale()
	if customScale < 0.6 then
		customScale = 0.6
	end
	widgetScale = (0.7 + (vsx*vsy / 5000000)) * customScale
end

function customScaleUp()
	widgetPosX		= widgetPosX - (widgetWidth*customScaleStep)
	widgetRight		= widgetPosX + widgetWidth  
	customScale		= customScale + customScaleStep
	updateWidgetScale()
end

function customScaleDown()
	widgetPosX		= widgetPosX + (widgetWidth*customScaleStep)
	widgetRight		= widgetPosX + widgetWidth  
	customScale		= customScale - customScaleStep
	updateWidgetScale()
end


function widget:ViewResize(viewSizeX, viewSizeY)
	local dx, dy = vsx - viewSizeX, vsy - viewSizeY
	vsx, vsy = viewSizeX, viewSizeY
	
	updateWidgetScale()
	
	if expandDown == true then
		widgetTop  = widgetTop - dy
		widgetPosY = widgetTop - widgetHeight
	end
	if expandLeft == true then
		widgetRight = widgetRight - dx
	    widgetPosX = vsx - (widgetWidth * widgetScale) - widgetRelRight
	end
end

function widget:MapDrawCmd(playerID, cmdType, px, py, pz)           -- get the points drawn (to display point indicator)
	if m_point.active then
		if cmdType == "point" then
			player[playerID].pointX = px
			player[playerID].pointY = py
			player[playerID].pointZ = pz
			player[playerID].pointTime = now + pointDuration
		end
	end
	
	local osClock = os.clock()
	if cmdType == 'line' then
		--mapDrawNicknameTime[playerID] = osClock
		--AddCommandSpotter('map_draw', x, y, z, osClock, false, playerID)
	end
end
