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
		desc      = "Players list with useful information / shortcuts. Use tweakmode (ctrl+F11) to customize.",
		author    = "Marmoth.",
		date      = "January 16, 2011",
		version   = "8.0",
		license   = "GNU GPL, v2 or later",
		layer     = -4,
		enabled   = true,  --  loaded by default?
		handler   = true,
	}
end

--------------------------------------------------------------------------------
-- SPEED UPS
--------------------------------------------------------------------------------

local Spring_GetGameSeconds      = Spring.GetGameSeconds
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

local GetTextWidth        = fontHandler.GetTextWidth
local UseFont             = fontHandler.UseFont
local TextDraw            = fontHandler.Draw
local TextDrawCentered    = fontHandler.DrawCentered
local TextDrawRight       = fontHandler.DrawRight

local gl_Texture          = gl.Texture
local gl_Rect             = gl.Rect
local gl_TexRect          = gl.TexRect
local gl_Color            = gl.Color

--------------------------------------------------------------------------------
-- IMAGES
--------------------------------------------------------------------------------

local unitsPic        = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/units.png"
local energyPic       = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/energy.png"
local metalPic        = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/metal.png"
local notFirstPic     = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/notfirst.png"
local notFirstPicWO   = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/notfirstWO.png"
local pingPic         = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/ping.png"
local cpuPic          = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/cpu.png"
local specPic         = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/spec.png"
local selectPic       = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/select.png"
local barPic          = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/bar.png"
local amountPic       = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/amount.png"
local cpuPingPic      = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/cpuping.png"
local sharePic        = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/share.png"
local namePic         = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/name.png"
local IDPic           = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/ID.png"
local pointPic        = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/point.png"
local chatPic         = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/chat.png"
local lowPic          = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/low.png"
local settingsPic     = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/settings.png"
local sidePic         = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/side.png"
local rankPic         = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/ranks.png"
local arrowPic        = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/arrow.png"
local arrowdPic       = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/arrowd.png"
local takePic         = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/take.png"
local crossPic        = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/cross.png"
local pointbPic       = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/pointb.png"
local takebPic        = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/takeb.png"
local seespecPic      = ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/seespec.png"

local rank0      = "LuaUI/Images/advplayerslist/Ranks/rank0.png"
local rank1      = "LuaUI/Images/advplayerslist/Ranks/rank1.png"
local rank2      = "LuaUI/Images/advplayerslist/Ranks/rank2.png"
local rank3      = "LuaUI/Images/advplayerslist/Ranks/rank3.png"
local rank4      = "LuaUI/Images/advplayerslist/Ranks/rank4.png"
local rank5      = "LuaUI/Images/advplayerslist/Ranks/rank5.png"
local rank6      = "LuaUI/Images/advplayerslist/Ranks/rank6.png"
local rank7      = "LuaUI/Images/advplayerslist/Ranks/rank7.png"
local rank8      = "LuaUI/Images/advplayerslist/Ranks/rank_unknown.png"

local sidePics        = {}  -- loaded in Sem_sidePics function
local sidePicsWO      = {}  -- loaded in Sem_sidePics function

--------------------------------------------------------------------------------
-- Fonts
--------------------------------------------------------------------------------

local font            = "LuaUI/Fonts/FreeSansBold_14"
local fontWOutline    = "LuaUI/Fonts/FreeSansBoldWOutline_14"     -- White outline for font (special font set)


--------------------------------------------------------------------------------
-- Colors
--------------------------------------------------------------------------------

local pingCpuColors   = {}


--------------------------------------------------------------------------------
-- Time Variables
--------------------------------------------------------------------------------


local blink           = true
local lastTime        = 0
local blinkTime       = 0
local now             = 0


--------------------------------------------------------------------------------
-- Tooltip
--------------------------------------------------------------------------------

local tipIdleTime = 1000     -- last time mouse moved (for tip)
local tipText                -- text of the tip
local oldMouseX,oldMouseY    -- used to determine idle status (mouse moved or not)

--------------------------------------------------------------------------------
-- Players counts and info
--------------------------------------------------------------------------------

-- local player info
local myAllyTeamID                           
local myTeamID			
local myPlayerID
local mySpecStatus = false

--General players/spectator count and tables
local player = {}



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
local doubleClick                  = false  -- deals with double click


--------------------------------------------------------------------------------
-- GEOMETRY VARIABLES
--------------------------------------------------------------------------------

local vsx,vsy                                    = gl.GetViewSizes()

local openClose                                  = 0
local widgetTop                                  = 0
local widgetRight                                = 1
local widgetHeight                               = 0
local widgetWidth                                = 0
local widgetPosX                                 = vsx-200
local widgetPosY                                 = 0

local expandDown                                 = false
local expandLeft                                 = false
local right
local localOffset    -- used by different functions to pass values
local localLeft      -- used by different functions to pass values
local localBottom    -- used by different functions to pass values

local activePlayers   = {}
local labelOffset     = 20
local separatorOffset = 3
local playerOffset    = 19
local drawList        = {}
local teamN


--------------------------------------------------
-- Modules
--------------------------------------------------


local modules = {}
local modulesCount = 0
local m_rank;     modulesCount = modulesCount + 1
local m_side;     modulesCount = modulesCount + 1
local m_ID;       modulesCount = modulesCount + 1
local m_name;     modulesCount = modulesCount + 1
local m_share;    modulesCount = modulesCount + 1
local m_chat;     modulesCount = modulesCount + 1
local m_cpuping;  modulesCount = modulesCount + 1
local m_diplo;    modulesCount = modulesCount + 1
local m_spec;     modulesCount = modulesCount + 1

local m_point;    modulesCount = modulesCount + 1  -- those 3 are not considered as normal module since they dont take any place and wont affect other's position
local m_take;     modulesCount = modulesCount + 1
local m_seespec;  modulesCount = modulesCount + 1


m_rank = {
	spec      = true,
	play      = true,
	active    = true,
	width     = 18,
	position  = 2,
	posX      = 0,
	pic       = rank8,
}

m_side = {
	spec      = true,
	play      = true,
	active    = true,
	width     = 18,
	position  = 3,
	posX      = 0,
	pic       = sidePic,
}

m_ID = {
	spec      = true,
	play      = true,
	active    = false,
	width     = 22,
	position  = 4,
	posX      = 0,
	pic       = IDPic,
}

m_name = {
	spec      = true,
	play      = true,
	active    = true,
	width     = 0,
	position  = 5,
	posX      = 0,
	pic       = namePic,
}

m_cpuping = {
	spec      = true,
	play      = true,
	active    = true,
	width     = 24,
	position  = 6,
	posX      = 0,
	pic       = cpuPingPic,
}

m_share = {
	spec      = false,
	play      = true,
	active    = true,
	width     = 50,
	position  = 7,
	posX      = 0,
	pic       = sharePic,
}
	
m_chat = {
	spec      = false,
	play      = true,
  active    = true,
	width     = 18,
	position  = 8,
	posX      = 0,
	pic       = chatPic,
}

m_spec = {
	spec      = true,
	play      = false,
	active    = true,
	width     = 18,
	position  = 9,
	posX      = 0,
	pic       = specPic,
}

--[[m_diplo = {
	spec      = false,
	play      = true,
	active    = false,
	width     = 18,
	position  = 10,
	posX      = 0,
	pic       = diplomacyPic,		
}]]

modules = {
	m_rank,
	m_ID,
	m_side,
	m_name,
	m_cpuping,
	m_share,
	m_spec,
	m_chat,
--	m_diplo,
}

m_point = {
	active = true,
	pic = pointbPic,
}

m_take = {
	active = true,
	pic = takePic,
}

m_seespec = {
	active = true,
	pic = seespecPic,
}




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
	end
	widgetWidth = pos + 1
	if widgetWidth < 20 then
		widgetWidth = 20
	end
	if widgetWidth + widgetPosX > vsx then
	  widgetPosX = vsx - widgetWidth
	end
	if widgetRight - widgetWidth < 0 then
		widgetRight = widgetWidth
	end
	if expandLeft == true then
		widgetPosX  = widgetRight - widgetWidth
	else
		widgetRight = widgetPosX + widgetWidth
	end
end

function SetMaxPlayerNameWidth()

	-- determines the maximal player name width (in order to set the width of the widget)

	local t = Spring_GetPlayerList()
	local maxWidth = GetTextWidth("- aband. units -")+4 -- minimal width = minimal standard text width
	local name = ""
	local nextWidth = 0
	UseFont(font)
	for _,wplayer in ipairs(t) do
		name = Spring_GetPlayerInfo(wplayer)
		nextWidth = GetTextWidth(name)+4
		if nextWidth > maxWidth then
			maxWidth = nextWidth
		end
	end
  return maxWidth
end

function GeometryChange()
	widgetRight = widgetWidth + widgetPosX
	if widgetRight > vsx then
		widgetRight = vsx
		widgetPosX = widgetRight - widgetWidth
	end
	if widgetPosX + widgetWidth/2 > vsx/2 then
		right = true
	else
		right = false
	end
end


function InitializePlayers()
	myPlayerID = Spring_GetLocalPlayerID()
	myTeamID = Spring_GetLocalTeamID()
	myAllyTeamID = Spring_GetLocalAllyTeamID()
	for i = 0, 64 do
		player[i] = {} 
	end
	GetAllPlayers()
end

function GetAllPlayers()
	local noplayer
	local allteams   = Spring_GetTeamList()
	teamN = table.maxn(allteams) - 1               --remove gaia
	for i = 0,teamN-1 do
		local teamPlayers = Spring_GetPlayerList(i, true)
		player[i + 32] = CreatePlayerFromTeam(i)
		for _,playerID in ipairs(teamPlayers) do
			player[playerID] = CreatePlayer(playerID)
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

function Init()
	SetSidePics()
	SetPingCpuColors()
	InitializePlayers()
	SortList()
	SetModulesPositionX()
	GeometryChange()
end

function widget:Initialize()
	Init()
end

function CreatePlayer(playerID)

	local tname,_, tspec, tteam, tallyteam, tping, tcpu, tcountry, trank = Spring_GetPlayerInfo(playerID)
	local _,_,_,_, tside, tallyteam                                      = Spring_GetTeamInfo(tteam)
	local tred, tgreen, tblue                                            = Spring_GetTeamColor(tteam)

	tpingLvl = GetPingLvl(tping)
	tcpuLvl  = GetCpuLvl(tcpu)
	tping    = tping * 1000 - ((tping * 1000) % 1)
	tcpu     = tcpu  * 100  - ((tcpu  *  100) % 1)
	
	return {
		rank             = trank,
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
		tdead            = false,
		spec             = tspec,
	}
	
end

function CreatePlayerFromTeam(teamID)

	local _,_, isDead, isAI, tside, tallyteam = Spring_GetTeamInfo(teamID)
	local tred, tgreen, tblue                 = Spring_GetTeamColor(teamID)
	local tname, ttotake, tdead
	
	if isAI then
	
		local version
		
		_,_,_,_, tname, version = Spring_GetAIInfo(teamID)
		
		if type(version) == "string" then
			tname = "AI:" .. tname .. "-" .. version
		else
			tname = "AI:" .. tname
		end
		
		ttotake = false
		tdead = false
		
	else
	
		if Spring_GetGameSeconds() < 0.1 then
		
			tname = "no player yet"
			ttotake = false
			tdead = false
		
		else
		
			if Spring_GetTeamUnitCount(teamID) > 0  then
				tname = "- aband. units -"
				ttotake = true
				tdead = false
			else
				tname = "- dead team -"
				ttotake = false
				tdead = true
			end
		
		end
	end
	
	return{
		rank             = 8, -- "don't know which" value
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
	}
	
end

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
	if m_seespec.active == true then
		vOffset = SortSpecs(vOffset) 
	end
	
	-- set the widget height according to space needed to show team
	widgetHeight = vOffset + 3
	
	
	-- move the widget if list is too long
	if widgetHeight + widgetPosY > vsy then
		widgetPosY = vsy - widgetHeight
	end
	
	if widgetTop - widgetHeight < 0 then
		widgetTop = widgetHeight
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
	local firstEnnemy = true
	allyTeamsCount = table.maxn(allyTeamList)-1
	
	-- find own ally team
	for allyTeamID = 0, allyTeamsCount - 1 do
		if allyTeamID == myAllyTeamID  then
			vOffset = vOffset + labelOffset
			table.insert(drawListOffset, vOffset)
			table.insert(drawList, -2)  -- "Allies" label
			vOffset = SortTeams(allyTeamID, vOffset)	-- Add the teams from the allyTeam		
			break
		end
	end
	
	-- add the others
	for allyTeamID = 0, allyTeamsCount-1 do
		if allyTeamID ~= myAllyTeamID then
			if firstEnnemy == true then
				vOffset = vOffset + labelOffset
				table.insert(drawListOffset, vOffset)
				table.insert(drawList, -3) -- "Ennemies" label
				firstEnnemy = false
			else
				vOffset = vOffset + separatorOffset
				table.insert(drawListOffset, vOffset)
				table.insert(drawList, -4) -- Ennemy teams separator
			end
			vOffset = SortTeams(allyTeamID, vOffset) -- Add the teams from the allyTeam 
		end
	end
	
	return vOffset
end

function SortTeams(allyTeamID, vOffset)
	-- Adds teams to the draw list (own team first)
	--(teams are not visible as such unless they are empty or AI)
	local teamID
	local teamsList = Spring_GetTeamList(allyTeamID)
	
	-- add own team first (if in own ally team)
	if myAllyTeamID == allyTeamID then
		table.insert(drawListOffset, vOffset)
		table.insert(drawList, -1)
		vOffset = SortPlayers(myTeamID,allyTeamID,vOffset) -- adds players from the team	
	end
	
	-- add other teams
	for _,teamID in ipairs(teamsList) do
		if teamID ~= myTeamID then
			table.insert(drawListOffset, vOffset)
			table.insert(drawList, -1)
			vOffset = SortPlayers(teamID,allyTeamID,vOffset) -- adds players form the team
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
				table.insert(drawListOffset, vOffset)
				table.insert(drawList, myPlayerID) -- new player (with ID)
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
					table.insert(drawListOffset, vOffset)
					table.insert(drawList, playerID) -- new player (with ID)
					player[playerID].posY = vOffset
					noPlayer = false
				end
			end
		end
	end
	
	-- add AI teams
	if isAi == true then
		vOffset = vOffset + playerOffset
		table.insert(drawListOffset, vOffset)
		table.insert(drawList, 32 + teamID) -- new AI team (instead of players)
		player[32 + teamID].posY = vOffset
		noPlayer = false
	end
	
	-- ad no player token if no player found in this team at this point
	if noPlayer == true then
		vOffset = vOffset + playerOffset
		table.insert(drawListOffset, vOffset)
		table.insert(drawList, 32 + teamID)  -- no players team
		player[32 + teamID].posY = vOffset
	end
	return vOffset
end

function SortSpecs(vOffset)
	-- Adds specs to the draw list
	
	local playersList = Spring_GetPlayerList(_,true)
	local noSpec = true
	
	for _,playerID in ipairs(playersList) do
		_,active,spec = Spring_GetPlayerInfo(playerID)
		if spec == true then
			if player[playerID].name ~= nil then
				
				-- add "Specs" label if first spec
				if noSpec == true then
					vOffset = vOffset + labelOffset
					table.insert(drawListOffset, vOffset)
					table.insert(drawList, -5)
					noSpec = false
				end
				
				-- add spectator
				vOffset = vOffset + playerOffset
				table.insert(drawListOffset, vOffset)
				table.insert(drawList, playerID)
				player[playerID].posY = vOffset
				noPlayer = false
			end
		end
	end
	return vOffset
end



---------------------------------------------------------------------------------------------------
--  Draw
---------------------------------------------------------------------------------------------------

function widget:DrawScreen()

	local vOffset                 = 0         -- position of the next object to draw
	local firstDrawnPlayer, firstEnemy, previousAllyTeam = true, true, nil
	local tip                     = GetTipIdle()
	local mouseX,mouseY           = Spring_GetMouseState()

	-- sets font
	UseFont(font)
	
	-- updates ressources for the sharing
	UpdateRessources()
	CheckTime()
	
	-- cancels the drawing if GUI is hidden
	if Spring.IsGUIHidden() then
		return
	end
	
	-- draws the background
	DrawBackground()
	
	-- draws the main list
	DrawList()

	-- draws share energy/metal sliders
	DrawShareSlider()
end

function UpdateRessources()
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
	local period = 0.4
	now = os.clock()
	if  now > (lastTime + period) then
		lastTime = now
		CheckPlayersChange()
		if blink == true then
			blink = false
		else
			blink = true
		end
		for playerID =0, 31 do
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

function DrawBackground()
	
	-- draws background rectangle
	gl_Color(0,0,0,0.3)                              
	gl_Rect(widgetPosX,widgetPosY, widgetPosX + widgetWidth, widgetPosY + widgetHeight - 1)
	
	-- draws black border
	gl_Color(0,0,0,1)
	gl_Rect(widgetPosX,widgetPosY, widgetPosX + widgetWidth, widgetPosY+1)
	gl_Rect(widgetPosX,widgetPosY + widgetHeight  - 2, widgetPosX + widgetWidth, widgetPosY + widgetHeight  - 1)
	gl_Rect(widgetPosX , widgetPosY, widgetPosX + 1, widgetPosY + widgetHeight  - 1)
	gl_Rect(widgetPosX + widgetWidth - 1, widgetPosY, widgetPosX + widgetWidth, widgetPosY + widgetHeight  - 1)
	gl_Color(1,1,1,1)
end

function DrawList()

	local mouseX,mouseY = Spring_GetMouseState()
	local leader

	if tip == false then
		for i, drawObject in ipairs(drawList) do
			if drawObject == -5 then
				DrawLabel("SPECS", drawListOffset[i])
			elseif drawObject == -4 then
				DrawSeparator(drawListOffset[i])
			elseif drawObject == -3 then
				DrawLabel("ENEMIES", drawListOffset[i])
			elseif drawObject == -2 then
				DrawLabel("ALLIES", drawListOffset[i])
			elseif drawObject == -1 then
				leader = true
			else
				DrawPlayer(drawObject, leader, drawListOffset[i])
			end
		end
	else
		for i, drawObject in ipairs(drawList) do
			if drawObject == -5 then
				DrawLabel("SPECS", drawListOffset[i])
			elseif drawObject == -4 then
				DrawSeparator(drawListOffset[i])
			elseif drawObject == -3 then
				DrawLabel("ENEMIES", drawListOffset[i])
			elseif drawObject == -2 then
				DrawLabel("ALLIES", drawListOffset[i])
			elseif drawObject == -1 then
				leader = true
			else
				DrawPlayerTip(drawObject, leader, drawListOffset[i], mouseX, mouseY)
				leader = false
			end
		end
		DrawTip(mouseX, mouseY)
	end
end

function DrawLabel(text, vOffset)
	if widgetWidth < 67 then
		text = string.sub(text, 0, 1)
	end
	TextDraw(text, widgetPosX + 2, widgetPosY + widgetHeight -vOffset+1)
	gl_Color(1,1,1,0.5)
	gl_Rect(widgetPosX+1, widgetPosY + widgetHeight -vOffset-1, widgetPosX + widgetWidth-1, widgetPosY + widgetHeight -vOffset-2)
	gl_Color(0,0,0,0.5)
	gl_Rect(widgetPosX+1, widgetPosY + widgetHeight -vOffset-2, widgetPosX + widgetWidth-1, widgetPosY + widgetHeight -vOffset-3)
	gl_Color(1,1,1)
end

function DrawSeparator(vOffset)
	gl_Rect(widgetPosX+1, widgetPosY + widgetHeight -vOffset-1, widgetPosX + widgetWidth-1, widgetPosY + widgetHeight -vOffset-2)
	gl_Color(0,0,0)
	gl_Rect(widgetPosX+1, widgetPosY + widgetHeight -vOffset-2, widgetPosX + widgetWidth-1, widgetPosY + widgetHeight -vOffset-3)
	gl_Color(1,1,1)
end

function DrawPlayer(playerID, leader, vOffset)
	local rank     = player[playerID].rank
	local name     = player[playerID].name
	local team     = player[playerID].team
	local allyteam = player[playerID].allyteam
	local side     = player[playerID].side
	local red      = player[playerID].red
	local green    = player[playerID].green
	local blue     = player[playerID].blue
	local dark     = player[playerID].dark
	local pingLvl  = player[playerID].pingLvl
	local cpuLvl   = player[playerID].cpuLvl
	local spec     = player[playerID].spec
	local totake   = player[playerID].totake
	local needm    = player[playerID].needm
	local neede    = player[playerID].neede
	local dead     = player[playerID].dead
	local posY     = widgetPosY + widgetHeight - vOffset

	if spec == false then
		if leader == true then -- take / share buttons
			if mySpecStatus == false then
				if allyteam == myAllyTeamID then
					if totake == true then
						DrawTakeSignal(posY)
					end
					if m_share.active == true and dead ~= true then
						DrawShareButtons(posY, needm, neede)
					end
				end
			else
				if m_spec.active == true then
					DrawSpecButton(team,posY)                           -- spec button
				end
			end
			gl_Color(red,green,blue,1)
			if m_ID.active == true then
				--if playerID < 32 then
					DrawID(team, posY, dark)
				--end
			end
		end
		gl_Color(red,green,blue,1)
		if m_side.active == true then
			DrawSidePic(team, posY, leader, dark)   
		end
		gl_Color(red,green,blue,1)
		if m_rank.active == true then
			DrawRank(rank, posY, dark)
		end
	else
		gl_Color(1,1,1,1)	
		if m_name.active == true then
			DrawName(name, posY, false)
		end		
	end
	if m_cpuping.active == true then
		if cpuLvl ~= nil then                              -- draws CPU usage and ping icons (except AI and ghost teams)
			DrawCpuPing(pingLvl,cpuLvl,posY)
		end
	end
	gl_Color(1,1,1,1)
	if playerID < 32 then
		if m_chat.active == true and mySpecStatus == false then
			if playerID ~= myPlayerID then
				DrawChatButton(posY)
			end
		end
		if m_point.active == true then
			if player[playerID].pointTime ~= nil then
				if player[playerID].allyteam == myAllyTeamID or mySpecStatus == true then
					if blink == true then
						DrawPoint(posY)
					end
				end
			end
		end
	end
	leader = false
	gl_Texture(false)
end

function DrawPlayerTip(playerID, leader, vOffset, mouseX, mouseY)
	tipY           = nil
	local rank     = player[playerID].rank
	local name     = player[playerID].name
	local team     = player[playerID].team
	local allyteam = player[playerID].allyteam
	local side     = player[playerID].side
	local red      = player[playerID].red
	local green    = player[playerID].green
	local blue     = player[playerID].blue
	local dark     = player[playerID].dark
	local pingLvl  = player[playerID].pingLvl
	local cpuLvl   = player[playerID].cpuLvl
	local ping     = player[playerID].ping
	local cpu      = player[playerID].cpu    
	local spec     = player[playerID].spec
	local totake   = player[playerID].totake
	local needm    = player[playerID].needm
	local neede    = player[playerID].neede
	local dead     = player[playerID].dead
	local posY     = widgetPosY + widgetHeight - vOffset
	
	if mouseY >= posY and mouseY <= posY + 16 then tipY = true end
	
	if spec == false then
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
			else
				if m_spec.active == true then
					DrawSpecButton(team, posY)                           -- spec button
					if tipY == true then SpecTip(mouseX) end
				end
			end
			gl_Color(red,green,blue,1)	
			if m_rank.active == true then
			--	if playerID < 32 then
					DrawRank(rank, posY, dark)
			--	end
			end
			if m_ID.active == true then
			--	if playerID < 32 then
					DrawID(team, posY, dark)
			--	end
			end
		end
		gl_Color(red,green,blue,1)
		if m_rank.active == true then                        
			DrawRank(rank, posY, leader, dark)   
		end
		gl_Color(red,green,blue,1)
		if m_side.active == true then                        
			DrawSidePic(team, posY, leader, dark)   
		end
		gl_Color(red,green,blue,1)	
		if m_name.active == true then
			DrawName(name, posY, dark)
		end
	else
		gl_Color(1,1,1,1)	
		if m_name.active == true then
			DrawName(name, posY, false)
		end		
	end

	if m_cpuping.active == true then
		if cpuLvl ~= nil then                              -- draws CPU usage and ping icons (except AI and ghost teams)
			DrawPingCpu(pingLvl,cpuLvl,posY)
			if tipY == true then PingCpuTip(mouseX, ping, cpu) end
		end
	end
	
	gl_Color(1,1,1,1)
	if playerID < 32 then
	
		if m_chat.active == true and mySpecStatus == false then
			if playerID ~= myPlayerID then
				DrawChatButton(posY)
			end
		end
		
		if m_point.active == true then
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
		if right == true then
			gl_Color(1,0.95,0)
			gl_Texture(arrowPic)
			gl_TexRect(widgetPosX - 11, posY, widgetPosX - 1, posY + 16)
			gl_Color(1,1,1)
			gl_Texture(takePic)
			gl_TexRect(widgetPosX - 57, posY - 1, widgetPosX - 12, posY + 17)			
		else
			local leftPosX = widgetPosX + widgetWidth
			gl_Color(1,0.95,0)
			gl_Texture(arrowPic)
			gl_TexRect(leftPosX + 11, posY, leftPosX + 1, posY + 16)
			gl_Color(1,1,1)
			gl_Texture(takePic)
			gl_TexRect(leftPosX + 12, posY - 1, leftPosX + 57, posY + 17)	
		end
	end	
end

function DrawShareButtons(posY, needm, neede)
	gl_Texture(unitsPic)                       -- Share UNIT BUTTON
	gl_TexRect(m_share.posX + widgetPosX  + 1, posY, m_share.posX + widgetPosX  + 17, posY + 16)
	gl_Texture(energyPic)                      -- share ENERGY BUTTON
	gl_TexRect(m_share.posX + widgetPosX  + 17, posY, m_share.posX + widgetPosX  + 33, posY + 16)
	gl_Texture(metalPic)                       -- share METAL BUTTON
	gl_TexRect(m_share.posX + widgetPosX  + 33, posY, m_share.posX + widgetPosX  + 49, posY + 16)
	gl_Texture(lowPic)
	if needm == true then
		gl_TexRect(m_share.posX + widgetPosX  + 33, posY, m_share.posX + widgetPosX  + 49, posY + 16)
	end
	if neede == true then
		gl_TexRect(m_share.posX + widgetPosX  + 17, posY, m_share.posX + widgetPosX  + 33, posY + 16)	
	end
	gl_Texture(false)
end

function DrawSpecButton(team, posY)
	gl_Texture(specPic)
	gl_TexRect(m_spec.posX + widgetPosX  + 1, posY, m_spec.posX + widgetPosX  + 17, posY + 16)
	if specTarget == team then 
		gl_Texture(selectPic)
		gl_TexRect(m_spec.posX + widgetPosX  + 1, posY, m_spec.posX + widgetPosX  + 17, posY + 16)
	end
	gl_Texture(false)
end

function DrawChatButton(posY)
	gl_Texture(chatPic)
	gl_TexRect(m_chat.posX + widgetPosX  + 1, posY, m_chat.posX + widgetPosX  + 17, posY + 16)	
end

function DrawSidePic(team, posY, leader, dark)
	if leader == true then
		gl_Texture(sidePics[team])                       -- sets side image (for leaders)
	else
		gl_Texture(notFirstPic)                          -- sets image for not leader of team players
	end
	gl_TexRect(m_side.posX + widgetPosX  + 1, posY, m_side.posX + widgetPosX  + 17, posY + 16) -- draws side image
	if dark == true then	-- draws outline if player color is dark
		gl_Color(1,1,1)
		if leader == true then
			gl_Texture(sidePicsWO[team])
		else
			gl_Texture(notFirstPicWO)
		end
		gl_TexRect(m_side.posX + widgetPosX +1, posY,m_side.posX + widgetPosX +17, posY + 16)
		gl_Texture(false)
	end
	gl_Texture(false)	
end

function DrawRank(rank, posY, dark)
	if rank == 0 then
		DrawRankImage(rank0, posY)
	elseif rank == 1 then
		DrawRankImage(rank1, posY)
	elseif rank == 2 then
		DrawRankImage(rank2, posY)
	elseif rank == 3 then
		DrawRankImage(rank3, posY)
	elseif rank == 4 then
		DrawRankImage(rank4, posY)
	elseif rank == 5 then
		DrawRankImage(rank5, posY)
	elseif rank == 6 then
		DrawRankImage(rank6, posY)
	elseif rank == 7 then
		DrawRankImage(rank7, posY)
	else
		DrawRankImage(rank8, posY)
	end
	gl_Color(1,1,1,1)
end

function DrawRankImage(rankImage, posY)
		gl_Color(1,1,1)
		gl_Texture(rankImage)
		gl_TexRect(widgetPosX + 2, posY, widgetPosX + 18, posY + 16)
end

function DrawName(name, posY, dark)
	TextDraw(name, m_name.posX + widgetPosX + 3, posY + 3) -- draws name
	if dark == true then                                   -- draws outline if player color is dark
		gl_Color(1,1,1)
		UseFont(fontWOutline)
		TextDraw(name, m_name.posX + widgetPosX + 3, posY + 3)
		UseFont(font)
	end
	gl_Color(1,1,1)
end

function DrawID(playerID, posY, dark)
	TextDrawCentered(playerID..".", m_ID.posX + widgetPosX + 10, posY + 3) -- draws name
	if dark == true then                                  -- draws outline if player color is dark
		gl_Color(1,1,1)
		UseFont(fontWOutline)
		TextDrawCentered(playerID..".", m_ID.posX + widgetPosX + 10, posY + 3)
		UseFont(font)
	end
	gl_Color(1,1,1)
end

function DrawPingCpu(pingLvl, cpuLvl, posY)
	gl_Color(pingCpuColors[pingLvl].r,pingCpuColors[pingLvl].g,pingCpuColors[pingLvl].b)
	gl_Texture(pingPic)
	gl_TexRect(m_cpuping.posX + widgetPosX  + 13, posY, m_cpuping.posX + widgetPosX  + 23, posY + 16)
	gl_Color(pingCpuColors[cpuLvl].r,pingCpuColors[cpuLvl].g,pingCpuColors[cpuLvl].b)
	gl_Texture(cpuPic)
	gl_TexRect(m_cpuping.posX + widgetPosX  + 1, posY, m_cpuping.posX + widgetPosX  + 11, posY + 16)	
end

function DrawPoint(posY,pointtime)
	if right == true then
		gl_Color(1,0,0,pointtime/20)
		gl_Texture(arrowPic)
		gl_TexRect(widgetPosX - 11, posY, widgetPosX - 1, posY+ 16)
		gl_Color(1,1,1,pointtime/20)
		gl_Texture(pointPic)
		gl_TexRect(widgetPosX - 28, posY, widgetPosX - 12, posY + 16)
	else
		leftPosX = widgetPosX + widgetWidth
		gl_Color(1,0,0,pointtime/20)
		gl_Texture(arrowPic)
		gl_TexRect(leftPosX + 11, posY, leftPosX + 1, posY + 16)
		gl_Color(1,1,1,pointtime/20)
		gl_Texture(pointPic)
		gl_TexRect(leftPosX + 28, posY, leftPosX + 12, posY + 16)	
	end
	gl_Color(1,1,1,1)
end

function TakeTip(mouseX)
	if right == true then
		if mouseX >= widgetPosX - 57 and mouseX <= widgetPosX - 1 then
			tipText = "Click to take abandoned units"
		end
	else
		local leftPosX = widgetPosX + widgetWidth
		if mouseX >= leftPosX + 1 and mouseX <= leftPosX + 57 then
			tipText = "Click to take abandoned units"
		end		
	end
end

function ShareTip(mouseX, playerID)
	if playerID == myPlayerID then
		if mouseX >= m_share.posX + widgetPosX  + 1 and mouseX <= m_share.posX + widgetPosX  + 17 then
			tipText = "Double click to ask for Unit support"
		elseif mouseX >= m_share.posX + widgetPosX  + 19 and mouseX <= m_share.posX + widgetPosX  + 35 then
			tipText = "Click and drag to ask for Energy"
		elseif mouseX >= m_share.posX + widgetPosX  + 37 and mouseX <= m_share.posX + widgetPosX  + 53 then
			tipText = "Click and drag to ask for Metal"
		end
	else
		if mouseX >= m_share.posX + widgetPosX  + 1 and mouseX <= m_share.posX + widgetPosX  + 17 then
			tipText = "Double click to share Units"
		elseif mouseX >= m_share.posX + widgetPosX  + 19 and mouseX <= m_share.posX + widgetPosX  + 35 then
			tipText = "Click and drag to share Energy"
		elseif mouseX >= m_share.posX + widgetPosX  + 37 and mouseX <= m_share.posX + widgetPosX  + 53 then
			tipText = "Click and drag to share Metal"
		end
	end
end

function SpecTip(mouseX)
	if mouseX >= m_spec.posX + widgetPosX  + 1 and mouseX <= m_spec.posX + widgetPosX  + 17 then
		tipText = "Click to observe the Player"
	end	
end

function PingCpuTip(mouseX, pingLvl, cpuLvl)
	if mouseX >= m_cpuping.posX + widgetPosX  + 13 and mouseX <=  m_cpuping.posX + widgetPosX  + 23 then
		tipText = "Ping: "..pingLvl.." ms"
	elseif mouseX >= m_cpuping.posX + widgetPosX  + 1 and mouseX <=  m_cpuping.posX + widgetPosX  + 11 then		
		tipText = "Cpu Usage: "..cpuLvl.."%"
	end
end

function PointTip(mouseX)
	if right == true then
		if mouseX >= widgetPosX - 28 and mouseX <= widgetPosX - 1 then
			tipText = "Click to reach the last point set by the player"
		end
	else
		local leftPosX = widgetPosX + widgetWidth
		if mouseX >= leftPosX + 1 and mouseX <= leftPosX + 28 then
			tipText = "Click to reach the last point set by the player"
		end		
	end
end

function DrawTip(mouseX, mouseY)
		if tipText ~= nil then
			local tw = GetTextWidth(tipText) + 14
			if right ~= true then tw = -tw end
			gl_Color(0.7,0.7,0.7,0.5)
			gl_Rect(mouseX-tw,mouseY,mouseX,mouseY+30) -- !! to be changed if the widget can be anywhere on the screen
			gl_Color(1,1,1,1)
			if right == true then
				TextDrawRight(tipText,mouseX-7,mouseY+10)
			else
				TextDraw(tipText,mouseX+7,mouseY+10)
			end
		end
		tipText        = nil
end

function GetTipIdle()
	local mouseX,mouseY = Spring_GetMouseState()
	if mouseX ~= oldMouseX or mouseY ~= oldMouseY then
		tipIdleTime = now
	end
	oldMouseX,oldMouseY = mouseX,mouseY
	if tipIdleTime + 0.5 > now then
		return false
	else
		return true
	end
end

function DrawShareSlider()
	local posY
	if energyPlayer ~= nil then
		posY = widgetPosY + widgetHeight - energyPlayer.posY
		gl_Texture(barPic)
		gl_TexRect(m_share.posX + widgetPosX  + 16,posY-3,m_share.posX + widgetPosX  + 34,posY+58)
		gl_Texture(energyPic)
		gl_TexRect(m_share.posX + widgetPosX  + 17,posY+sliderPosition,m_share.posX + widgetPosX  + 33,posY+16+sliderPosition)
		gl_Texture(amountPic)
		if right == true then
			gl_TexRect(m_share.posX + widgetPosX  - 28,posY-1+sliderPosition, m_share.posX + widgetPosX  + 19,posY+17+sliderPosition)
			gl_Texture(false)
			TextDrawCentered(amountEM.."", m_share.posX + widgetPosX  - 5,posY+3+sliderPosition)
		else
			gl_TexRect(m_share.posX + widgetPosX  + 76,posY-1+sliderPosition, m_share.posX + widgetPosX  + 31,posY+17+sliderPosition)
			gl_Texture(false)
			TextDrawCentered(amountEM.."", m_share.posX + widgetPosX  + 55,posY+3+sliderPosition)				
		end
	elseif metalPlayer ~= nil then
		posY = widgetPosY + widgetHeight - metalPlayer.posY
		gl_Texture(barPic)
		gl_TexRect(m_share.posX + widgetPosX  + 32,posY-3,m_share.posX + widgetPosX  + 50,posY+58)
		gl_Texture(metalPic)
		gl_TexRect(m_share.posX + widgetPosX  + 33, posY+sliderPosition,m_share.posX + widgetPosX  + 49,posY+16+sliderPosition)
		gl_Texture(amountPic)
		if right == true then
			gl_TexRect(m_share.posX + widgetPosX  - 12,posY-1+sliderPosition, m_share.posX + widgetPosX  + 35,posY+17+sliderPosition)
			gl_Texture(false)
			TextDrawCentered(amountEM.."", m_share.posX + widgetPosX  + 11,posY+3+sliderPosition)
		else
			gl_TexRect(m_share.posX + widgetPosX  + 88,posY-1+sliderPosition, m_share.posX + widgetPosX  + 47,posY+17+sliderPosition)
			gl_Texture(false)
			TextDrawCentered(amountEM.."", m_share.posX + widgetPosX  + 71,posY+3+sliderPosition)
		end
	end
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

function SetSidePics()

-- Loads the side pics and side pics outlines for each side.
-- It first tries to look if there is any image in the mod file for the specific side
-- then it looks in the user files for specific side
-- if none of those are found, uses default image and notify the missing image.

	teamList = Spring_GetTeamList()
	for _, team in ipairs(teamList) do
		_,_,_,_,teamside = Spring_GetTeamInfo(team)
		if VFS.FileExists(LUAUI_DIRNAME.."Images/Advplayerslist/"..teamside..".png") then
			sidePics[team] = ":n:LuaUI/Images/Advplayerslist/"..teamside..".png"
			if VFS.FileExists(LUAUI_DIRNAME.."Images/Advplayerslist/"..teamside.."WO.png") then
				sidePicsWO[team] = ":n:LuaUI/Images/Advplayerslist/"..teamside.."WO.png"
			else
				sidePicsWO[team] = ":n:LuaUI/Images/Advplayerslist/noWO.png"
			end
		else
			if VFS.FileExists(LUAUI_DIRNAME.."Images/Advplayerslist/"..teamside.."_default.png") then
				sidePics[team] = ":n:LuaUI/Images/Advplayerslist/"..teamside.."_default.png"
				if VFS.FileExists(LUAUI_DIRNAME.."Images/Advplayerslist/"..teamside.."WO_default.png") then
					sidePicsWO[team] = ":n:LuaUI/Images/Advplayerslist/"..teamside.."WO_default.png"
				else
					sidePicsWO[team] = ":n:LuaUI/Images/Advplayerslist/noWO.png"
				end
			else
				if teamside ~= "" then
					Echo("Image missing for side "..teamside..", using default.")
				end
				sidePics[team] = ":n:"..LUAUI_DIRNAME.."Images/Advplayerslist/default.png"
				sidePicsWO[team] = ":n:"..LUAUI_DIRNAME.."Images/Advplayerslist/defaultWO.png"
			end
		end
	end
end

function SetPingCpuColors()

	-- Sets the colors for ping and CPU icons (green to red)

	pingCpuColors = {
	[1] = {r = 0, g = 1, b = 0},
	[2] = {r = 0.7, g = 1, b = 0},
	[3] = {r = 1, g = 1, b = 0},
	[4] = {r = 1, g = 0.6, b = 0},
	[5] = {r = 1, g = 0, b = 0}
	}
end

function GetDark(red,green,blue)                  	

	-- Determines if the player color is dark. (to determine if white outline is needed)

	if red*1.2 + green*1.1 + blue*0.8 < 0.9 then return true end
	return false
end

function Spec(teamID)
	Spring_SendCommands{"specteam "..teamID}
	specTarget = teamID
end

function widget:MousePress(x,y,button)
	local t = false       -- true if the object is a team leader
	local clickedPlayer
	local posY
	if button == 1 then
		sliderPosition = 0
		amountEM = 0
		if mySpecStatus == true then
			for _,i in ipairs(drawList) do  -- i = object #
				
				if t == true then
					clickedPlayer = player[i]
					posY = widgetPosY + widgetHeight - clickedPlayer.posY
					if m_spec.active == true then
						if IsOnRect(x, y, m_spec.posX + widgetPosX +1, posY, m_spec.posX + widgetPosX +17,posY+16) then --spec button
							teamToSpec = clickedPlayer.team
							Spring_SendCommands{"specteam "..teamToSpec}
							Spec(teamToSpec)
							return true
						end
					end
				end
				
				if i == -1 then
					t = true
				else
					t = false
					if m_point.active == true then
						if i > -1 and i < 32 then
							clickedPlayer = player[i]
							if clickedPlayer.pointTime ~= nil then
								posY = widgetPosY + widgetHeight - clickedPlayer.posY
								if right == true then
									if IsOnRect(x,y, widgetPosX - 28, posY - 1,widgetPosX - 12, posY + 17) then                           --point button
										Spring.SetCameraTarget(clickedPlayer.pointX,clickedPlayer.pointY,clickedPlayer.pointZ,1)          --                                       --
										return true                                                                                       --
									end                                                                                                   --
								else                                                                                                      --
									if IsOnRect(x,y, widgetPosX + widgetWidth + 12, posY-1,widgetPosX + widgetWidth + 28, posY + 17) then --
										Spring.SetCameraTarget(clickedPlayer.pointX,clickedPlayer.pointY,clickedPlayer.pointZ,1)                                                  --
										return true
									end
								end
							end
						end
					end
				end
			end
		else
			for _,i in ipairs(drawList) do
				if t == true then
					clickedPlayer = player[i]
					posY = widgetPosY + widgetHeight - clickedPlayer.posY
					if clickedPlayer.allyteam == myAllyTeamID then
						if m_take.active == true then
							if clickedPlayer.totake == true then
								if right == true then
									if IsOnRect(x,y, widgetPosX - 57, posY - 1,widgetPosX - 12, posY + 17) then                            --take button
										Take()                                                                                             --
										return true                                                                                        --
									end                                                                                                    --
								else                                                                                                       --
									if IsOnRect(x,y, widgetPosX + widgetWidth + 12, posY-1,widgetPosX + widgetWidth + 57, posY + 17) then  --
										Take()                                                                                             --
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
					if i > -1 and i < 32 then
						clickedPlayer = player[i]
						posY = widgetPosY + widgetHeight - clickedPlayer.posY
						if m_chat.active == true then
							if IsOnRect(x, y, m_chat.posX + widgetPosX +1, posY, m_chat.posX + widgetPosX +17,posY+16) then                            --chat button
								Spring_SendCommands("chatall","pastetext /w "..clickedPlayer.name..' \1')
								return true                                                                                                                --
							end
						end
						if m_point.active == true then
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
					end
				end
			end
		end
	end
end

function widget:MouseMove(x,y,dx,dy,button)
  local moveStartX, moveStartY
	if energyPlayer ~= nil or metalPlayer ~= nil then                            -- move energy/metal share slider
		if sliderOrigin == nil then
			sliderOrigin = y
		end
		sliderPosition = y-sliderOrigin
		if sliderPosition < 0 then sliderPosition = 0 end
		if sliderPosition > 39 then sliderPosition = 39 end
	end
end

function widget:MouseRelease(x,y,button)
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
			else
				Spring_ShareResources(energyPlayer.team,"energy",amountEM)
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
			else
				Spring_ShareResources(metalPlayer.team,"metal",amountEM)
			end
			sliderOrigin = nil
			amountEMMax = nil
			sliderPosition = nil
			amountEM = nil
			metalPlayer = nil
		end
	end
end

function widget:MapDrawCmd(playerID, cmdType, px, py, pz)           -- get the points drawn (to display point indicator)
	if m_point.active == true then
		if cmdType == "point" then
			player[playerID].pointX = px
			player[playerID].pointY = py
			player[playerID].pointZ = pz
			player[playerID].pointTime = now + 20
		end
	end
end

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)

	-- check if the mouse is in a rectangle

	return x >= BLcornerX and x <= TRcornerX
	                      and y >= BLcornerY
	                      and y <= TRcornerY

end

local function DrawGreyRect()
	gl_Color(0.2,0.2,0.2,0.8)                                   -- draw show/hide modules buttons
	gl_Rect(widgetPosX, widgetPosY, widgetPosX + widgetWidth, widgetPosY + widgetHeight)
	gl_Color(1,1,1,1)
end

local function DrawTweakButton(module, image)
	gl_Texture(image)
	gl_TexRect(localLeft + localOffset, localBottom + 11, localLeft + localOffset + 16, localBottom + 27)
	if module.active ~= true then
		gl_Texture(crossPic)
		gl_TexRect(localLeft + localOffset, localBottom + 11, localLeft + localOffset + 16, localBottom + 27)
	end
	localOffset = localOffset + 16
end

local function DrawTweakButtons()
	
	local minSize = (modulesCount-1) * 16 + 2
	localLeft     = widgetPosX
	localBottom   = widgetPosY + widgetHeight - 28
	localOffset   = 1
	
	if localLeft + minSize > vsx then localLeft = vsx - minSize end
	if localBottom < 0 then localBottom = 0 end

	
	DrawTweakButton(m_rank, rankPic)
	DrawTweakButton(m_side, sidePic)	
	DrawTweakButton(m_ID, IDPic)
	DrawTweakButton(m_name, namePic)
	DrawTweakButton(m_cpuping, cpuPingPic)
	DrawTweakButton(m_share, sharePic)
	DrawTweakButton(m_spec, specPic)
	DrawTweakButton(m_point, pointbPic)
	DrawTweakButton(m_take, takebPic)
	DrawTweakButton(m_seespec, seespecPic)
	DrawTweakButton(m_chat, chatPic)
end

local function DrawArrows()
	gl_Color(1,1,1,0.4)
	gl_Texture(arrowdPic)
	if expandDown == true then
		gl_TexRect(widgetPosX, widgetPosY - 12, widgetRight, widgetPosY - 4)
	else
		gl_TexRect(widgetPosX, widgetTop + 12, widgetRight, widgetTop + 4)
	end
		gl_Texture(arrowPic)
	if expandLeft == true then
		gl_TexRect(widgetPosX - 4, widgetPosY, widgetPosX - 12, widgetTop)
	else
		gl_TexRect(widgetRight + 4, widgetPosY, widgetRight + 12, widgetTop)
	end
	gl_Color(1,1,1,1)
	gl_Texture(false)
end

function widget:TweakDrawScreen()

	DrawGreyRect()
	DrawTweakButtons()
	DrawArrows()

end




local function checkButton(module, x, y)
		if IsOnRect(x, y, localLeft + localOffset, localBottom + 11, localLeft + localOffset + 16, localBottom + 27) then
			module.active = not module.active
			SetModulesPositionX()
			localOffset = localOffset + 16
			return true
		else
			localOffset = localOffset + 16
			return false
		end
end

function widget:TweakMousePress(x,y,button)
	if button == 1 then
		
		localLeft = widgetPosX
		localBottom = widgetPosY + widgetHeight - 28
		localOffset = 1
		if localBottom < 0 then localBottom = 0 end
		if localLeft + 181 > vsx then localLeft = vsx - 181 end
		
		if checkButton(m_rank,    x, y) then return true end
		if checkButton(m_side,    x, y) then return true end
		if checkButton(m_ID,      x, y) then return true end
		if checkButton(m_name,    x, y) then return true end
		if checkButton(m_cpuping, x, y) then return true end
		if checkButton(m_share,   x, y) then return true end
		if checkButton(m_spec,    x, y) then return true end
		if checkButton(m_point,   x, y) then return true end
		if checkButton(m_take,    x, y) then return true end
		if checkButton(m_seespec, x, y) then return true end
		if checkButton(m_chat,    x, y) then return true end

		if IsOnRect(x, y, widgetPosX, widgetPosY, widgetPosX + widgetWidth, widgetPosY + widgetHeight) then
			clickToMove = true
			return true
		end
		
	end
end


function widget:TweakMouseMove(x,y,dx,dy,button)
	if clickToMove ~= nil then
		if moveStartX == nil then                                                      -- move widget on y axis
			moveStartX = x - widgetPosX
		end
		if moveStartY == nil then                                                      -- move widget on y axis
			moveStartY = y - widgetPosY
		end
		widgetPosX = widgetPosX + dx
		widgetPosY = widgetPosY + dy
				
		if widgetPosY <= 0 then
			widgetPosY = 0
			expandDown = false
		end
		if widgetPosY + widgetHeight >= vsy then
			widgetPosY = vsy - widgetHeight
			expandDown = true
		end
		if widgetPosX <= 0 then
			widgetPosX = 0
			expandLeft = false
		end
		if widgetPosX + widgetWidth >= vsx then
			widgetPosX = vsx - widgetWidth
			expandLeft = true
		end
		widgetTop   = widgetPosY + widgetHeight
		widgetRight = widgetPosX + widgetWidth
		if widgetPosX + widgetWidth/2 > vsx/2 then
			right = true
		else
			right = false
		end
	end
end

function widget:TweakMouseRelease(x,y,button)
	clickToMove = nil                                              -- ends the share slider process
end

function widget:GetConfigData(data)      -- send
	if m_side ~= nil then
	return {
		vsx                = vsx,
		vsy                = vsy,
		widgetPosX         = widgetPosX,
		widgetPosY         = widgetPosY,
		widgetRight        = widgetRight,
		widgetTop          = widgetTop,
		expandDown         = expandDown,
		expandLeft         = expandLeft,
		m_rankActive       = m_rank.Active,
		m_sideActive       = m_side.active,
		m_IDActive         = m_ID.active,
		m_nameActive       = m_name.active,
		m_cpupingActive    = m_cpuping.active,
		m_shareActive      = m_share.active,
		m_specActive       = m_spec.active,
		m_pointActive      = m_point.active,
		m_takeActive       = m_take.active,
		m_seespecActive    = m_seespec.active,
		m_chatActive       = m_chat.active,
	}
	end
end

function widget:SetConfigData(data)      -- load
	if data.expandDown ~= nil and data.widgetRight ~= nil then
		expandDown   = data.expandDown
		expandLeft   = data.expandLeft
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
			widgetRight = data.widgetRight + dx
			if widgetRight > vsx then
				widgetRight = vsx
			end
		else
			widgetPosX  = data.widgetPosX
		end
	end
	m_rank.active         = SetDefault(data.m_rankActive, true)
	m_side.active         = SetDefault(data.m_sideActive, true)
	m_ID.active           = SetDefault(data.m_IDActive, false)
	m_name.active         = SetDefault(data.m_nameActive, true)
	m_cpuping.active      = SetDefault(data.m_cpupingActive, true)
	m_share.active        = SetDefault(data.m_shareActive, true)
	m_spec.active         = SetDefault(data.m_specActive, true)
	m_point.active        = SetDefault(data.m_pointActive, true)
	m_take.active         = SetDefault(data.m_takeActive, true)
	m_seespec.active      = SetDefault(data.m_seespecActive, true)
	m_chat.active         = SetDefault(data.m_chatActive, false)
end

function SetDefault(value, default)
	if value == nil then
		return default
	else
		return value
	end
end

function CheckPlayersChange()
	local sorting = false
	for i = 0,31 do
		local name,active,spec,teamID,allyTeamID,pingTime,cpuUsage, country, rank = Spring_GetPlayerInfo(i)
		if active == false then
			if player[i].name ~= nil then                                             -- NON SPEC PLAYER LEAVING
				if player[i].spec==false then
					if table.maxn(Spring_GetPlayerList(player[i].team,true)) == 0 then
						player[player[i].team + 32] = CreatePlayerFromTeam(player[i].team)
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
						player[player[i].team + 32] = CreatePlayerFromTeam(player[i].team)
					end
					player[i].team = nil                                                 -- remove team
				end
				player[i].spec = spec                                                  -- consider player as spec
				sorting = true
			end
			if teamID ~= player[i].team then                                               -- PLAYER CHANGING TEAM
				if table.maxn(Spring_GetPlayerList(player[i].team,true)) == 0 then           -- check if there is no more player in the team + update
					player[player[i].team + 32] = CreatePlayerFromTeam(player[i].team)         
				end
				player[i].team = teamID
				player[i].red, player[i].green, player[i].blue = Spring_GetTeamColor(teamID)
				player[i].dark = GetDark(player[i].red, player[i].green, player[i].blue)
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
-------------------------------------------------------------------------------------- Update stall / cpu / ping info for each player

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
	end
	if sorting == true then    -- sorts the list again if change needs it
		SortList()
		SetModulesPositionX()    -- change the X size if needed (change of widest name)
	end

end

function updateTake(allyTeamID)
	for i = 0,teamN-1 do
		if player[i + 32].allyTeam == allyTeamID then
			player[i + 32] = CreatePlayerFromTeam(i)
		end
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

function Take()

	-- sends the /take command to spring

	Spring_SendCommands{"take"}
	Spring_SendCommands{"say a: I took the abandoned units."}
	for i = 0,63 do
		if player[i].allyteam == myAllyTeamID then
			if player[i].totake == true then
				player[i] = CreatePlayerFromTeam(player[i].team)
				SortList()
			end
		end
	end
	return
end

function widget:GameStart()
	Init()
end

function widget:Update(frame)
	local gs = Spring_GetGameSeconds()
	if gs < 1 then
		if gs > 0 then
			Init() 
		end
	end
end

function widget:TeamDied(teamID)
	player[teamID+32]        = CreatePlayerFromTeam(teamID)
	player[teamID+32].totake = false
	SortList()
end

function widget:ViewResize(viewSizeX, viewSizeY)
	local dx, dy = vsx - viewSizeX, vsy - viewSizeY
	vsx, vsy = viewSizeX, viewSizeY
	if expandDown == true then
		widgetTop  = widgetTop - dy
		widgetPosY = widgetTop - widgetHeight
	end
	if expandLeft == true then
		widgetRight = widgetRight - dx
		widgetPosX  = widgetRight - widgetWidth
	end
end


-- Coord in % (resize) geometry will not be done
-- ajouter les décryptages de messages "widget:AddConsoleLine(line,priority)" appelé à chaque fois qu'il doit ajouter une ligne
