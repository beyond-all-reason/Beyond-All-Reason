local versionNumber = "1.8"

do
---------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------
-- Changelog
-- Version 1.72
-- Put drawfunction in global scope
-- Small bugfix with amount of players bug

------------------------
-- Version 1.7
------------------------
-- * Rewritten for better performance, for some reason display lists make performance worse.
--   Now about half the performance cost compared to before and even less if gamespeed > 1.
-- * Add Guardians of Kadesh faction images

------------------------
-- Version 1.61
------------------------
-- * Add TLL images also for XTA

------------------------
-- Version 1.6
------------------------
-- * Remove announcing of kills: most games have this already built in
-- * Remove sounds
-- * Some bugfixes and compatibility for EvoRTS
-- * Bug fixes and performance improvements
-- * Added TS values and better handling of screen position
-- * Improved player list management and handling of dead players
-- * Fixed bug where team bars disappear even if team is alive
-- * Added icon for tech annihilation TTL faction
-- * Added support for zombie mode (tested with XTA to detect mod option)

------------------------
-- Version 1.5
------------------------
-- * Rewritten code to increase performance, fps cost down by 50% in normal usage scenario.
-- * Now uses drawlists and gl.loadFont

------------------------
-- Version 1.41
------------------------
-- * Bug fixes and performance improvements

------------------------
-- Version 1.4
------------------------
-- * Performance improvements
-- * Font improvements
-- * Display extended info by pressing on i-button instead of overcomplicated arrows
-- * Drag widget with right button; drag infopanel with left button and close with right (yes i know, maybe counter-intuitive)
-- * Fixed opengl bugs

------------------------
-- version 1.32
------------------------
-- * Compatible with spring 95.0
-- * fixed bug with incorrect expand button location
-- * fixed spam errors bc of old tags
------------------------

end

function widget:GetInfo()
	return {
		name = "Ecostats",
		desc = "Display team eco",
		author = "Jools  (minimalized by Floris)",
		date = "jan, 2014",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true
	}
end


local loadSettings		= true

local showInfoButton	= false

---------------------------------------------------------------------------------------------------
--  Declarations
---------------------------------------------------------------------------------------------------

local bestTeam, bestKills, worstLosses 						
local killCounters 					= {}
local lossCounters 					= {}
local killedHP						= {}
local lostHP						= {}
local kMat 							= {}     -- player to player kill matrix
local PmaxDmg						= 0
local comTable 						= {}
local comDefs						= {}
local teamData 						= {}
local allyData 						= {}
local pressedToMove, pressedHPlus, pressedHMinus, pressedWPlus, pressedWMinus -- click detection for moving the widget
local pressedExpandMove 			= false
local pressedExpand 				= false
local gamestarted 					= false
local gameover						= false
local inSpecMode					= false
local expandDown                    = false
local expandLeft                    = false
local isReplay						= Spring.IsReplay()
local myAllyID						= Spring.GetLocalAllyTeamID()

local sin							= math.sin
local floor							= math.floor
local strsub						= string.sub
local strgsub						= string.gsub
local strfind						= string.find
local tconcat						= table.concat
local strchar						= string.char
local GetGameSeconds				= Spring.GetGameSeconds
local GetGameFrame					= Spring.GetGameFrame
local glTexture						= gl.Texture
local glColor						= gl.Color
local glTexRect						= gl.TexRect
local glRect						= gl.Rect
local GetGameSpeed					= Spring.GetGameSpeed
local GetTeamUnitCount				= Spring.GetTeamUnitCount


local Button 						= {}
Button["info"] 						= {}
Button["player"] 					= {}
Button["expandMove"]				= {}
Button["team"] 						= {}

local Options						= {}

local lastPlayerChange				= 0
local lastDrawUpdate				
local drawList

local vsx,vsy                    	= gl.GetViewSizes()
local right							= true
local widgetHeight					
local widgetWidth                	= 110
local widgetPosX                 	= vsx-widgetWidth
local widgetPosY                 	= 600
local widgetRight			 	    = widgetPosX + widgetWidth
local tH						 	= 60 -- team row height
local WBadge					 	= 14 -- width of player badge (side icon)
local iPosX, iPosY
local InfotablePosX, InfotablePosY	-- Expand bar bottom left coordinates
local cW 							= 100 -- column width
local infoTableHeight 				= 520
local ctrlDown 						= false
local textsize						= 11
local textlarge						= 18
local gaiaID						= Spring.GetGaiaTeamID()
local gaiaAllyID					= select(6,Spring.GetTeamInfo(gaiaID))
local LIMITSPEED					= 2.0 -- gamespseed under which to fully update dynamic graphics
local haveZombies 					= (tonumber((Spring.GetModOptions() or {}).zombies) or 0) == 1
local maxPlayers					= 0

---------------------------------------------------------------------------------------------------

local fontPath  		= "LuaUI/Fonts/ebrima.ttf" 
local font2Path  		= "LuaUI/Fonts/ebrima.ttf"
local myFont	 		= gl.LoadFont("FreeSansBold.otf",textsize, 1.9, 40) --gl.LoadFont(fontPath,textsize,2,20)
local myFontBig	 		= gl.LoadFont(font2Path,textlarge,5,40)

local bgcorner	= ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"

local images			= {
						["arm"]					= "LuaUI/Images/ecostats/arm_default.png",
						["core"]     			= "LuaUI/Images/ecostats/core_default.png",
						["tll"]					= "LuaUI/Images/ecostats/tll_default.png", -- name in Techa
						["lost"]				= "LuaUI/Images/ecostats/tll_default.png", -- name in XTA
						["guardian"]			= "LuaUI/Images/ecostats/guardian_default.png",
						["contrast"]			= "LuaUI/Images/ecostats/contrast.png",
						["checkboxon"]			= "LuaUI/Images/ecostats/chkBoxOn.png",
						["checkboxoff"]			= "LuaUI/Images/ecostats/chkBoxOff.png",
						["more"]				= "LuaUI/Images/ecostats/ButtonMore.png",
						["less"]				= "LuaUI/Images/ecostats/ButtonLess.png",
						["default"]				= "LuaUI/Images/ecostats/default.png",
						["move"]				= "LuaUI/Images/ecostats/move.png",
						["arrowleft"]			= "LuaUI/Images/ecostats/arrowL.png",
						["arrowright"]			= "LuaUI/Images/ecostats/arrowR.png",
						["info"]				= "LuaUI/Images/ecostats/info.png",
						["dead"]     			= "LuaUI/Images/ecostats/cross.png",
						["zombie"]     			= "LuaUI/Images/ecostats/cross_inv.png",
						["bar"]     			= "LuaUI/Images/ecostats/bar.png",
						["barbg"]     			= "LuaUI/Images/ecostats/barbg.png",
						["outer_colonies"]		= LUAUI_DIRNAME .. "Images/ecostats/ecommander.png", -- commander in evorts
						}

local AttackUnits			= {}
local BuilderUnits			= {}
local UnitBuildPower		= {}
local AirUnits				= {}
local MobileUnits			= {}
			
---------------------------------------------------------------------------------------------------
--  Speed ups
---------------------------------------------------------------------------------------------------

local Echo 						 = Spring.Echo
local glText            		 = gl.Text

---------------------------------------------------------------------------------------------------
--  Start
---------------------------------------------------------------------------------------------------

function widget:Initialize()
	if not (Spring.GetSpectatingState() or isReplay) then
		inSpecMode = false
		Spring.Log("widget", LOG.INFO, "Ecostats: widget loaded in active player mode")
	else
		inSpecMode = true
		Spring.Log("widget", LOG.INFO, "Ecostats: widget loaded in spectator mode")
	end
	if GetGameSeconds() > 0 then gamestarted = true end
	
	Init()
end

function removeGuiShaderRects()
	if (WG['guishader_api'] ~= nil) then
		for _, data in pairs(allyData) do
			local aID = data.aID
			local drawpos = data.drawpos
			
			if isTeamReal(aID) and (aID == Spring.GetMyAllyTeamID() or inSpecMode) and (aID ~= gaiaAllyID or haveZombies) then
				
				local posy = tH*(drawpos)
				WG['guishader_api'].RemoveRect('ecostats_'..posy)
			end
		end
		WG['guishader_api'].RemoveRect('ecostats_expandtable')
	end
end

function widget:Shutdown()
	removeGuiShaderRects()
	if (drawList) then 			gl.DeleteList(drawList) end
	if (drawListDynamic) then 	gl.DeleteList(drawListDynamic) end
	if (sideImageList) then		gl.DeleteList(sideImageList) end
end

function Init()

	
	if not Options.disable then
		Echo("Ecostats:Options not loaded, using default settings. (This is normal during first run.)")
		setDefaults()
	end
	
	bestKills = 0
	worstLosses = 0
	killCounters = {}
	lossCounters = {}
	killedHP = {}
	lostHP = {}
	kMat = {}
	teamData = {}
	allyData = {}
	comTable = {}
	
	Button["info"]	 		= {}
	Button["expandMove"]    = {}
	Button["player"] 		= {}
	Button["teamnext"]		= {}
	Button["teamprev"]		= {}
	iPosX = {}
	iPosY = {}
	
	right = widgetPosX/vsx > 0.5
	widgetHeight = getNbTeams()*tH+2
	
	for id,unitDef in ipairs(UnitDefs) do
		if unitDef.customParams.iscommander then
			table.insert(comTable,id)
			comDefs[id] = true
		end
		if #(unitDef.weapons) > 0 then
			AttackUnits[id] = true
		end
		if unitDef.isBuilder then
			BuilderUnits[id] = true
			UnitBuildPower[id] = unitDef.buildSpeed
		end
		
		if unitDef.canFly then
			AirUnits[id] = true
		end
		
		if unitDef.canMove then
			MobileUnits[id] = true
		end
	end	
	
	if right then
		InfotablePosX = widgetPosX - (180 + cW*maxPlayers)
	else
		InfotablePosX = widgetPosX + widgetWidth
	end
	InfotablePosY = widgetPosY + widgetHeight
	
	allyData  = {}
	for _, allyID in ipairs (Spring.GetAllyTeamList() ) do		
		if allyID ~= gaiaAllyID or haveZombies then
		
			local teamList = Spring.GetTeamList(allyID)
			
			local allyDataIndex = allyID +1
			allyData[allyDataIndex]						= {}
			allyData[allyDataIndex]["teams"]			= teamList
			allyData[allyDataIndex].exists				= #teamList > 0
				
			for _,teamID in pairs(teamList) do
				local myAllyID = select(6,Spring.GetTeamInfo(teamID))
				killCounters[teamID] = 0
				lossCounters[teamID] = 0
				killedHP[teamID] = 0
				lostHP[teamID] = 0
				kMat[teamID] = {}
				
				setTeamTable(teamID)
				Button["player"][teamID] = {}
				
				for sortindex,enemy in ipairs(Spring.GetTeamList()) do
					kMat[teamID][sortindex] = {enemy,0} -- maintain association: 1 = teamID, 2 = kills
				end	
			end
				
				
			setAllyData(allyID)
			
			local nbPlayers 							= #teamList
			Button["info"][allyID]						= {}
			Button["expandMove"][allyID] 				= {}
			Button["teamnext"][allyID] 					= {}
			Button["teamprev"][allyID] 					= {}
			Button["info"][allyID]["mouse"] 			= false
			Button["info"][allyID]["click"] 			= false
			Button["expandMove"][allyID]["mouse"]		= false
			Button["teamnext"][allyID]["mouse"] 		= false
			Button["teamnext"][allyID]["click"] 		= false
			Button["teamprev"][allyID]["mouse"] 		= false
			Button["teamprev"][allyID]["click"] 		= false
		end
	end
	
	maxPlayers 	= getMaxPlayers()
	
	if maxPlayers == 1 then
		WBadge = 18
	elseif maxPlayers == 2 or maxPlayers == 3 then
	    WBadge = 16
	else
		WBadge = 14
	end
	if maxPlayers * WBadge + 30 > widgetWidth then 
		widgetWidth = 30 + maxPlayers * WBadge	
	end 
	
	updateButtons()
	UpdateAllies()
	
	local frame = GetGameFrame()
	lastPlayerChange = frame
	
end

function Reinit()
	
	maxPlayers = getMaxPlayers()
		
	if (not inSpecMode) and gamestarted then 
		if widgetWidth < 60 then widgetWidth = 60 end
		if tH < 60 then tH = 60 end
	else
		if widgetWidth <  110 then widgetWidth = 110 end
		if tH < 60 then tH = 60 end
	end
	
	if maxPlayers == 1 then
		WBadge = 18
	elseif maxPlayers == 2 or maxPlayers == 3 then
	    WBadge = 16
	else
		WBadge = 14
	end
	
	if maxPlayers * WBadge + 30 > widgetWidth then 
		widgetWidth = 30 + maxPlayers * WBadge
	end	
	if widgetPosX + widgetWidth > vsx then widgetPosX = vsx-widgetWidth end
	if widgetPosX < 0 then widgetPosX = 0 end
	
	for _, allyID in ipairs (Spring.GetAllyTeamList() ) do		
		if allyID ~= gaiaAllyID or haveZombies then
			local teamList = Spring.GetTeamList(allyID)
	
			if not allyData[allyID+1] then 
				allyData[allyID+1]		= {} 
			end
		
			allyData[allyID+1]["teams"]			= teamList
			allyData[allyID+1].exists			= #teamList > 0
		end
	end
	
	UpdateAllTeams()
	
	UpdateAllies()
	updateButtons()
	
end

---------------------------------------------------------------------------------------------------
--  Save / Load
---------------------------------------------------------------------------------------------------

function setDefaults()
	Options = {}
	Options["contrastMore"] = {}
	Options["contrastLess"] = {}
	Options["contrast"] = 0.6
	Options["disable"] = {}
	Options["disable"]["On"] = false
	Options["FPBar1"] = {}
	Options["FPBar1"]["On"] = false
	Options["FPBar2"] = {}
	Options["FPBar2"]["On"] = false
	Options["BPBar1"] = {}
	Options["BPBar1"]["On"] = false
	Options["BPBar2"] = {}
	Options["BPBar2"]["On"] = false
	Options["kills1"] = {}
	Options["kills1"]["On"] = false
	Options["kills2"] = {}
	Options["kills2"]["On"] = false
	Options["widthInc"] = {}
	Options["widthDec"] = {}
	Options["heightInc"] = {}
	Options["heightDec"] = {}
	Options["resText"] = {}
	Options["removeDead"] = {}
	Options["resText"]["On"] = true
	Options["removeDead"]["On"] = false
	vsx,vsy 			= gl.GetViewSizes()
	widgetWidth 		= 110
	widgetPosX         	= vsx-widgetWidth
	widgetPosY         	= vsy
	expandDown         	= true
	expandLeft         	= true
	right 				= true
	tH					= 60
end

function widget:GetConfigData(data)      -- save
	--Echo("Saving config data")
	return {
		vsx                = vsx,
		vsy                = vsy,
		widgetPosX         = widgetPosX,
		widgetPosY         = widgetPosY,
		widgetWidth		   = widgetWidth,
		expandDown         = expandDown,
		expandLeft         = expandLeft,
		tH				   = tH,
		removeDeadOn 	   = Options.removeDead.On,
		resTextOn 	   	   = Options.resText.On,
		contrast 		   = Options.contrast,
		disableOn		   = Options.disable.On,
		FPBar1On		   = Options.FPBar1.On,
		FPBar2On		   = Options.FPBar2.On,
		BPBar1On		   = Options.BPBar1.On,
		BPBar2On		   = Options.BPBar2.On,
		kills1On 		   = Options.kills1.On,
		kills2On 		   = Options.kills2.On,
		vsx                = vsx,
		vsy                = vsy,
		widgetPosX         = widgetPosX,
		widgetPosY         = widgetPosY,
		widgetWidth		   = widgetWidth,
		expandDown         = expandDown,
		expandLeft         = expandLeft,
		right			   = right,
		tH				   = tH,
	}
end


function widget:SetConfigData(data)      -- load
	if not loadSettings then return end
	
	--Echo("Loading config data...")
	Options = {}
	Options["contrastMore"] = {}
	Options["contrastLess"] = {}
	--Options["contrast"] = data.contrast or 0.6
	Options["disable"] = {}
	Options["disable"]["On"] = data.disableOn or false
	Options["FPBar1"] = {}
	--Options["FPBar1"]["On"] = data.FPBar1On or false
	Options["FPBar2"] = {}
	--Options["FPBar2"]["On"] = data.FPBar2On or false
	Options["BPBar1"] = {}
	--Options["BPBar1"]["On"] = data.BPBar1On or false
	Options["BPBar2"] = {}
	--Options["BPBar2"]["On"] = data.BPBar2On or false
	Options["kills1"] = {}
	--Options["kills1"]["On"] = data.kills1On or false
	Options["kills2"] = {}
	--Options["kills2"]["On"] = data.kills2On or false
	Options["widthInc"] = {}
	Options["widthDec"] = {}
	Options["heightInc"] = {}
	Options["heightDec"] = {}
	Options["resText"] = {}
	Options["removeDead"] = {}
	Options["resText"]["On"] = data.resTextOn or false
	Options["removeDead"]["On"] = data.removeDeadOn or false
	vsx					= data.vsx or vsx
	vsy 				= data.vsy or vsy
	widgetPosX         	= data.widgetPosX or widgetPosX
	widgetPosY         	= data.widgetPosY or widgetPosY
	widgetWidth 		= data.widgetWidth or widgetWidth
	expandDown         	= data.expandDown or expandDown
	expandLeft         	= data.expandLeft or expandLeft
	tH					= data.tH or tH
end

---------------------------------------------------------------------------------------------------
--  Local
---------------------------------------------------------------------------------------------------

local function firstToUpper(str)
	return (str:sub(1,1):upper()..str:sub(2))
end

local function digitsep(amount)
  local formatted = amount
  while true do
    formatted, k = strgsub(formatted, "^(-?%d+)(%d%d%d)", '%1 %2')
    if (k==0) then
      break
    end
  end
  return formatted
end

local function round(num, idp)
  local mult = 10^(idp or 0)
  return floor(num * mult + 0.5) / mult
end

local function friendlyName(teamID)
	if teamID == nil then return "NONE" end
	local _,_,_,isAIteam,side,_,_,_ = Spring.GetTeamInfo(teamID)
	if isAIteam then
		if side == "arm" then return "Arm"
		elseif side == "core" then return "Core"
		elseif side == "lost" then return "Lost"
		elseif side == "guardian" then return "Guardian"
		elseif not (side == nil or #side < 1) then return side
		else return ("Team " .. teamID)
		end
	else
		names=nil
		for _,pid in ipairs(Spring.GetPlayerList(teamID,true)) do
			local name,active,spectator,_,_,_,_,_,_ = Spring.GetPlayerInfo(pid)
			if not spectator then
				names=(names and names.."," or "").."<PLAYER"..pid..">"
			end
		end
		if names == nil or #names < 1 then return ("Team " .. teamID) end
		return (names and names or "")
	end
end

local function formatRes(number)
	local label
	if number > 10000 then
		label = tconcat({floor(round(number/1000)),"k"})
	elseif number > 1000 then
		label = tconcat({strsub(round(number/1000,1),1,2+strfind(round(number/1000,1),".")),"k"})
	elseif number > 10 then
		label = strsub(round(number,0),1,3+strfind(round(number,0),"."))
	else
		label = strsub(round(number,1),1,2+strfind(round(number,1),"."))
	end
	return tostring(label)
end

local function formatRes1000(number)
	local label
	if number == nil then
		Echo(GetGameFrame(),": formatRes1000 returned nil")
		
		return nil
	end
	if number > 10000 then
		label = digitsep(round(number))
	elseif number > 1000 then
		label = digitsep(round(number))
	elseif number > 10 then
		label = strsub(round(number,0),1,3+strfind(round(number,0),"."))
	else
		label = strsub(round(number,1),1,2+strfind(round(number,1),"."))
	end
	return label
end

local function FindNextAlly(allyID)
	
	local allyDataID = allyID+1
	for i=allyDataID,#allyData do
		if allyData[i+1] and allyData[i+1].exists then return i end
	end
	return false
end

local function FindPrevAlly(allyID)
	
	local allyDataID = allyID+1
	for i=allyDataID,1,-1 do
		if allyData[i-1] and allyData[i-1].exists then return i-2 end
	end
	return false
end

-- Draw


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
	
	local offset = 0.07		-- texture offset, because else gaps could show
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


local function DrawEText(numberE, vOffset)
	if Options["resText"]["On"] then
		local label = tconcat({"",formatRes(numberE)})
		myFont:Begin()
		myFont:SetTextColor({1, 1, 0, 1})
		myFont:Print(label, widgetPosX + widgetWidth - 10, widgetPosY + widgetHeight -vOffset+tH-42,textsize,'rs')
		myFont:End()
	end
end

local function DrawMText(numberM, vOffset)
	if Options["resText"]["On"] then
		local label = tconcat({"",formatRes(numberM)})
		myFont:Begin()
		myFont:SetTextColor({0.8,0.8,0.8,1})
		myFont:Print(label, widgetPosX + widgetWidth - 10, widgetPosY + widgetHeight -vOffset+tH-30,textsize,'rs')
		myFont:End()
	end
end

local function DrawEBar(tE,vOffset)-- where tE = team Energy = [0,1]
	
	local dx = 15
	local dy = tH-35
	glColor(0.8, 0.8, 0, 0.13)
	gl.Texture(images["barbg"])
	glTexRect(
		widgetPosX + dx,
		widgetPosY + widgetHeight -vOffset+dy,
		widgetPosX + dx-5 + widgetWidth/2,
		widgetPosY + widgetHeight -vOffset+dy-3
	)
	glColor(1,1,0,1)
	gl.Texture(images["bar"])
	glTexRect(
		widgetPosX + dx,
		widgetPosY + widgetHeight -vOffset+dy,
		widgetPosX + dx + tE * (widgetWidth/2-5),
		widgetPosY + widgetHeight -vOffset+dy-3
	)
	gl.Texture(false)
	glColor(1,1,1,1)
end

local function DrawMBar(tM,vOffset) -- where tM = team Metal = [0,1]
	local dx = 15
	local dy = tH-25
	glColor(0.8, 0.8, 0.8, 0.13)
	gl.Texture(images["barbg"])
	glTexRect(
		widgetPosX + dx,
		widgetPosY + widgetHeight -vOffset+dy,
		widgetPosX + dx-5 + widgetWidth/2,
		widgetPosY + widgetHeight -vOffset+dy-3
	)
	glColor(1,1,1,1)
	gl.Texture(images["bar"])
	glTexRect(
		widgetPosX + dx,
		widgetPosY + widgetHeight -vOffset+dy,
		widgetPosX + dx + tM * (widgetWidth/2-5),
		widgetPosY + widgetHeight -vOffset+dy-3
	)
	gl.Texture(false)
	glColor(1,1,1)
end

local function DrawFPBar(tFP,vOffset,sM)-- where tFP = team Firepower = [0,1]
	if inSpecMode then
		if not Options["FPBar2"]["On"] then return end
	else
		if not Options["FPBar1"]["On"] then return end
	end
	
	local dx = 3
	local dy = tH-45
	local h = 22
	glColor(0.3,0.3,0.3)
	glRect(widgetPosX+dx-1, widgetPosY + widgetHeight -vOffset + dy + h + 1,widgetPosX+dx+7,widgetPosY + widgetHeight -vOffset + dy + h)
	glRect(widgetPosX+dx-1, widgetPosY + widgetHeight -vOffset + dy-1,widgetPosX+dx+7,widgetPosY + widgetHeight -vOffset + dy)
	glColor(0,0,0) --blue 1
	glRect(
			widgetPosX+dx+1,
			widgetPosY + widgetHeight -vOffset + dy,
			widgetPosX + dx + 2,
			widgetPosY + widgetHeight -vOffset + dy+ (1-sM)*tFP * h
			)
	glColor(0,0.2,0.4) --blue 2
	glRect(
			widgetPosX+dx+2,
			widgetPosY + widgetHeight -vOffset + dy,
			widgetPosX + dx + 3,
			widgetPosY + widgetHeight -vOffset + dy + (1-sM)*tFP * h
			)
	glColor(0,0.4,0.8) -- violet 1
	glRect(
			widgetPosX+dx+1,
			widgetPosY + widgetHeight -vOffset + dy + (1-sM)*tFP * h,
			widgetPosX + dx + 2,
			widgetPosY + widgetHeight -vOffset + dy+ tFP * h
			)
	glColor(0,0.4,1) -- violet 2
	glRect(
			widgetPosX+dx+2,
			widgetPosY + widgetHeight -vOffset + dy + (1-sM)*tFP * h,
			widgetPosX + dx + 3,
			widgetPosY + widgetHeight -vOffset + dy + tFP * h
			)
	glColor(1,1,1)
end

local function DrawBPBar(tBP,vOffset,sA)-- where tE = team Buildpower = [0,1]
	if inSpecMode then
		if not Options["BPBar2"]["On"] then return end
	else
		if not Options["BPBar1"]["On"] then return end
	end
	
	local dx = 7
	local dy = tH-45
	local h = 22
	glColor(0.3,0.3,0.3)
	glRect(
			widgetPosX+dx-1,
			widgetPosY + widgetHeight -vOffset + dy + h + 1,
			widgetPosX+dx+7,
			widgetPosY + widgetHeight -vOffset + dy + h
			)
	glRect(
			widgetPosX+dx-1,
			widgetPosY + widgetHeight -vOffset + dy-1,
			widgetPosX+dx+7,
			widgetPosY + widgetHeight -vOffset + dy
			)
	glColor(0,0.8,0) -- green 1
	glRect(
			widgetPosX+dx+1,
			widgetPosY + widgetHeight -vOffset + dy,
			widgetPosX + dx + 2,
			widgetPosY + widgetHeight -vOffset + dy + (1-sA) * tBP * h
			)
	glColor(0,0.8,0.3) --green 2
	glRect(
			widgetPosX+dx+2,
			widgetPosY + widgetHeight -vOffset + dy,
			widgetPosX + dx + 3,
			widgetPosY + widgetHeight -vOffset + dy + (1-sA) * tBP * h
			)
	glColor(1,1,0) -- yellow 1
	glRect(
			widgetPosX+dx+1,
			widgetPosY + widgetHeight -vOffset + dy + (1-sA) * tBP * h,
			widgetPosX + dx + 2,
			widgetPosY + widgetHeight -vOffset + dy+ tBP * h
			)
	glColor(0.3,1,0) --yellow 2
	glRect(
			widgetPosX+dx+2,
			widgetPosY + widgetHeight -vOffset + dy + (1-sA) * tBP * h,
			widgetPosX + dx + 3,
			widgetPosY + widgetHeight -vOffset + dy + tBP * h
			)
	glColor(0.3,0.3,0.3)
	glColor(1,1,1)
end

local function DrawKillBar(killedhp,vOffset,splits) -- where killedHP = abs. number
	local dx = 1
	local dy = 1
	local len = 0.001*killedhp/(splits+1)
	
	glColor(0,0.3,0.9,0.8)
	glRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight -vOffset+dy+1,
			widgetPosX + dx + len,
			widgetPosY + widgetHeight -vOffset+dy
			)
	glColor(0,0.2,0.5,0.8)
	glRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight -vOffset+dy,
			widgetPosX + dx + len,
			widgetPosY + widgetHeight -vOffset+dy-1
			)
	glColor(1,1,1,1)
end

local function DrawLossesBar(losthp,vOffset,splits)
	local dx = 1
	local dy = -1
	local len = 0.001*losthp/(splits+1)
	
	glColor(0.6,0.2,0.2,0.8) -- (1,0,0.3,0.8)
	glRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight -vOffset+dy+1,
			widgetPosX + dx + len,
			widgetPosY + widgetHeight -vOffset+dy
			)
	glColor(0.3,0.1,0.1,0.8) -- (0.6,0,0.4,0.8)
	glRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight -vOffset+dy,
			widgetPosX + dx + len,
			widgetPosY + widgetHeight -vOffset+dy-1
			)
	glColor(1,1,1,1)
end

local function DrawKillDeathText(kills, losses, vOffset)
	if inSpecMode then
		if not Options["kills2"]["On"] then return end
	else
		if not Options["kills1"]["On"] then return end
	end
	
	local dx = 6
	local dy = 68
	--local len = 1+floor(1+math.log(kills+1)+math.log(losses+1))
	local len  = 7 * #(tostring(losses))
	local len2 = 7 * #(tostring(kills))+len
	glColor(0.8,1,0.8,1)
	if kills > 0 then glText(kills, widgetPosX + widgetWidth - 15 - dx - len2, widgetPosY + widgetHeight -vOffset+tH-dy+2,textsize) end
	glColor(0.85,0.85,0.85,0.85)
	if kills > 0 and losses > 0 then glText("/", widgetPosX  + widgetWidth - 10 - dx - len, widgetPosY + widgetHeight -vOffset+tH-dy+2,textsize) end
	glColor(1,0.8,0.8,1)
	if losses > 0 then glText(losses, widgetPosX + widgetWidth - dx - len, widgetPosY + widgetHeight -vOffset+tH-dy+2,textsize) end
	glColor(1,1,1,1)
end

local function DrawBackground(posY)
	local y1 = widgetPosY - posY + widgetHeight
	local y2 = widgetPosY - posY + tH + widgetHeight
	glColor(0,0,0,0.6)
	RectRound(widgetPosX,y1, widgetPosX + widgetWidth, y2, 6)
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(widgetPosX,y1, widgetPosX + widgetWidth, y2, 'ecostats_'..posY)
	end
	glColor(1,1,1,1)
end


local function DrawExpandTableButtons(allyID)
	
	if Button["expandMove"][allyID]["mouse"] then
		glColor(1,1,1,1)
	else
		glColor(0.5,0.5,0.8,0.7)
	end
	
	--glTexture(images["move"])
	--glTexRect(Button["expandMove"][allyID]["x1"], Button["expandMove"][allyID]["y1"] , Button["expandMove"][allyID]["x2"], Button["expandMove"][allyID]["y2"])
	--glTexture(false)

	if Button["teamnext"][allyID]["mouse"] then
		if allyID < getNbTeams() - 1 and inSpecMode then
			glColor(0.7,0.9,1,1)
		else
			glColor(1,0.7,0.7,1)
		end
	else
		glColor(0.5,0.5,0.8,0.7)
	end
	
	glTexture(images["arrowright"])
	glTexRect(Button["teamnext"][allyID]["x1"], Button["teamnext"][allyID]["y1"] , Button["teamnext"][allyID]["x2"], Button["teamnext"][allyID]["y2"])
	glTexture(false)
	
	if Button["teamprev"][allyID]["mouse"] then
		if allyID > 0 and inSpecMode then
			glColor(0.7,0.9,1,1)
		else
			glColor(1,0.7,0.7,1)
		end
	else
		glColor(0.5,0.5,0.8,0.7)
	end
	
	glTexture(images["arrowleft"])
	glTexRect(Button["teamprev"][allyID]["x1"], Button["teamprev"][allyID]["y1"] , Button["teamprev"][allyID]["x2"], Button["teamprev"][allyID]["y2"])
	glTexture(false)
end

local expandTablePos = {}
local function DrawExpandTable(allyID)
	if not (allyData[allyID+1].exists) then return end
	pressedExpand = true
	
	local nbTeams = getNbTeams()
	local nbPlayers = #(allyData[allyID+1].teams)
	if nbPlayers > 5 then cW = 90 end
	if nbPlayers > 8 then cW = 80 end
	
	local lm  						= 20 -- left margin
	local rm  						= 35 --right margin
	local dy 						= 35 -- top margin
	local w 						= 180 + cW*nbPlayers -- infotable width
	local j
	local rs  						= 18 --row spacing
	local hBar 						= 40 -- bottom bar height
	local x1, y1, x2, y2
	local clr = {0.8, 0.8, 0.9 ,1}
	
	local posX = iPosX[allyID]
	local posY = iPosY[allyID]

	local splits = floor(0.004*PmaxDmg/hBar)
	local scale = splits*250
	
	x1 = posX
	y2 = posY
	x2 = x1 + w
	y1 = y2 - infoTableHeight
	--------------
	-- Background --
	--------------
	glTexture(false)
	
	local hasCom
	local active
	local mycomlbl
	local myactlbl
	local r,b,g,s1, s2, s3, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16, s17,s18, s19, rank, sStatus
	
	-- background
	glColor(0,0,0,0.8)
	RectRound(x1, y1, x2, y2, 8)
	-- content area
	local margin = 5
	gl.Color(0.33,0.33,0.33,0.15)
	RectRound(x1+margin, y1+margin, x2-margin, y2-margin, 8)
	
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(x1, y1, x2, y2, 'ecostats_expandtable')
	end
	expandTablePos = {x1, y1, x2, y2}
	
	local teamlbl = tconcat({"Team ",tostring(allyID)})
	
	myFontBig:Begin()
	myFontBig:SetTextColor({0.8,0.8,1,0.4})
	myFontBig:Print(teamlbl, posX + w/2 -30, posY - 38,textlarge,'o')
	myFontBig:End()
	
	--------------
	-- Headings --
	-------------
	myFont:Begin()
	myFont:SetTextColor({0.5,0.5,0.8,1})
	myFont:Print("Player:", posX + lm, posY - dy - 10 - 1*rs,textsize)
	myFont:Print("Commander:", posX + lm, posY - dy - 10- 2*rs,textsize)
	myFont:Print("Units:", posX + lm, posY - dy - 10 - 3*rs,textsize)
	myFont:Print("Metal:", posX + lm, posY - dy - 10 - 4*rs,textsize)
	myFont:Print("Energy:", posX + lm, posY - dy - 10 - 5*rs,textsize)
	myFont:Print("Firepower:", posX + lm, posY - dy - 10 - 6*rs,textsize)
	myFont:Print(".....mobile:", posX + lm, posY - dy - 5 - 7*rs,textsize)
	myFont:Print("Buildpower:", posX + lm, posY - dy - 10 - 8*rs,textsize)
	myFont:Print(".......air:", posX + lm, posY - dy - 5 - 9*rs,textsize)
	myFont:Print("Kills:", posX + lm, posY - dy - 10 - 10*rs,textsize)
	myFont:Print("Losses:", posX + lm, posY - dy - 10 - 11*rs,textsize)
	myFont:Print("Killed HP:", posX + lm, posY - dy - 10 - 12*rs,textsize)
	myFont:Print("Lost HP:", posX + lm, posY - dy - 10 - 13*rs,textsize)
	myFont:Print("Active:", posX + lm, posY - dy - 10 - 14*rs,textsize)
	myFont:Print("Faction:", posX + lm, posY - dy - 10 - 16*rs,textsize)
	myFont:Print("Country:", posX + lm, posY - dy - 10 - 17*rs,textsize)
	myFont:Print("Rank:", posX + lm, posY - dy - 10 - 18*rs,textsize,textsize)
	myFont:Print("Skill:", posX + lm, posY - dy - 10 - 19*rs,textsize,textsize)
	myFont:SetTextColor({0.4,0.4,0.2,1})
	myFont:Print("Kills:", posX + lm, posY - dy - 10 - 24*rs,textsize)	
	myFont:Print("0 HP", posX + 100, posY - dy - 10 - 24*rs - 2,textsize)
	local s0 = tconcat({formatRes1000((1+splits)*hBar/4) or ""," kHP"})
	myFont:Print(s0, posX + 135 - #s0*7, posY - dy - 10 - 24*rs + hBar-2,textsize)
	myFont:SetTextColor({0.5,0.5,0.8,0.3})
	myFont:Print("(Right-click to close)", posX + lm, posY - dy - 26*rs,textsize)
	myFont:End()
	--glColor(0.5,0.5,0.8,1)
	
	for i, teamID in pairs (Spring.GetTeamList(allyID)) do
		j = nbPlayers - i
		------------
		-- Values --
		------------
		r  		= teamData[teamID].red
		g  		= teamData[teamID].green
		b  		= teamData[teamID].blue

		if r ~= nil then
			local luminance  = (r * 0.299) + (g * 0.587) + (b * 0.114)
			if (luminance < 0.3) then
				r = r + 0.2
				g = g + 0.2
				b = b + 0.2
			end
		end
		s1 		= teamData[teamID]["leaderName"] or "(Retired)"
		if 	#s1 > cW/7 and nbPlayers > 1 then s1 = strsub(s1,1,floor(cW/7)) end
		s3 		= tostring(teamData[teamID]["unitCount"]) or ""
		hasCom 	= teamData[teamID]["hasCom"]
		s5 		= tconcat({"+", formatRes1000(teamData[teamID]["minc"]) or ""})
		s6		= tconcat({"+", formatRes1000(teamData[teamID]["einc"]) or ""})
		s7		= formatRes1000(teamData[teamID]["firepower"]) or ""
		if teamData[teamID]["firepower"] > 0 then
			s8		= tconcat({formatRes1000(100*(teamData[teamID]["firepowerMob"]/teamData[teamID]["firepower"])) or "","%"})
		else
			s8 = ""
		end
		s9		= formatRes1000(teamData[teamID]["buildpower"])
		if teamData[teamID]["firepower"] > 0 then
			s10		= tconcat({formatRes1000(100*(teamData[teamID]["buildpowerAir"]/teamData[teamID]["buildpower"]))or "","%"})
		else
			s10 = ""
		end
		s11		= tostring(teamData[teamID]["kills"])
		s12		= tostring(teamData[teamID]["losses"])
		s13		= formatRes1000(teamData[teamID]["killedhp"]) or ""
		s14		= formatRes1000(teamData[teamID]["losthp"]) or ""
		active 	= teamData[teamID]["active"]
		s16		= firstToUpper(teamData[teamID]["side"] or "") 
		s17		= string.upper(teamData[teamID]["country"] or "") 
		rank 	= teamData[teamID]["rank"]
		if rank == 0 then
			s18 = "Enlisted"
		elseif rank == 1 then
			s18 = "2nd Lieut."
		elseif rank == 2 then
			s18 = "Lieutenant"
		elseif rank == 3 then
			s18 = "Captain"
		elseif rank == 4 then
			s18 = "Major"
		elseif rank == 5 then
			s18 = "Lt.Colonel"
		elseif rank == 6 then
			s18 = "Colonel"
		elseif rank == 7 then
			s18 = "Brigadier"
		elseif rank == 8 then
			s18 = "Maj.General"
		else
			s18 = ""
		end
		s19		= teamData[teamID]["skill"]
		
		------------------
		-- Print values --
		------------------
		myFont:Begin()
		myFont:SetTextColor({r,g,b,1})
		myFont:Print(s1, posX + w - rm - j*cW, posY - dy - 10 - 1*rs,textsize,'r')
		myFont:SetTextColor(clr)
		if hasCom then
			s2 = "Yes"
			myFont:SetTextColor({0.7,1,0.7,1})
		else
			s2 = "No"
			myFont:SetTextColor({1,0.7,0.7,1})
		end
						
		myFont:Print(s2, posX + w - rm - j*cW, posY - dy - 10 - 2*rs,textsize,'r')
		myFont:SetTextColor(clr)
		if (teamData[teamID]["isDead"]) then myFont:SetTextColor({0.5,0.5,0.5,0.8}) end
		myFont:Print(s3, posX + w - rm - j*cW, posY - dy - 10 - 3*rs,textsize,'r')
		myFont:SetTextColor({0.8,0.8,1,1})
		myFont:Print(s5, posX + w - rm - j*cW, posY - dy - 10 - 4*rs,textsize,'r')
		myFont:SetTextColor({1,1,0,1})
		myFont:Print(s6, posX + w - rm - j*cW, posY - dy - 10 - 5*rs,textsize,'r')
		myFont:SetTextColor(clr)
		myFont:Print(s7, posX + w - rm - j*cW, posY - dy - 10 - 6*rs,textsize,'r')
		myFont:Print(s8, posX + w - rm + 7 - j*cW, posY - dy - 5 - 7*rs,textsize,'r')
		myFont:SetTextColor(clr)
		myFont:Print(s9, posX + w - rm - j*cW, posY - dy - 10 - 8*rs,textsize,'r')
		myFont:Print(s10, posX + w - rm + 7 - j*cW, posY - dy - 5 - 9*rs,textsize,'r')
		myFont:SetTextColor(clr)
		myFont:Print(s11, posX + w - rm - j*cW, posY - dy - 10 - 10*rs,textsize,'r')
		myFont:Print(s12, posX + w - rm - j*cW, posY - dy - 10 - 11*rs,textsize,'r')
		myFont:Print(s13, posX + w - rm - j*cW, posY - dy - 10 - 12*rs,textsize,'r')
		myFont:Print(s14, posX + w - rm - j*cW, posY - dy - 10 - 13*rs,textsize,'r')
		if active then
			s15 = "Yes"
			myFont:SetTextColor({0.7,1,0.7,1})
		else
			s15 = "No"
			myFont:SetTextColor({1,0.7,0.7,1})
		end
		myFont:Print(s15, posX + w - rm - j*cW, posY - dy - 10 - 14*rs,textsize,'r')
		myFont:SetTextColor(clr)
		myFont:Print(s16, posX + w - rm - j*cW, posY - dy - 10 - 16*rs,textsize,'r')
		myFont:Print(s17, posX + w - rm - j*cW, posY - dy - 10 - 17*rs,textsize,'r')
		myFont:Print(s18, posX + w - rm - j*cW, posY - dy - 10 - 18*rs,textsize,'r')
		myFont:Print(s19, posX + w - rm - j*cW, posY - dy - 10 - 19*rs,textsize,'r')
		
		if gamestarted then
			if not teamData[teamID]["active"] and teamData[teamID]["unitCount"] > 0 then
			myFont:SetTextColor({0.5,0.5,0.8,1})
			sStatus = "[MIA]"
			elseif teamData[teamID]["isDead"] then
			myFont:SetTextColor({0.5,0.1,0.1,1})
			sStatus = "[KIA]"
			else
			myFont:SetTextColor({0.7,1,0.7,1})
			sStatus = ""
			end
		else
			if not teamData[teamID]["active"] then
				myFont:SetTextColor({0.3,0.3,0.6,1})
				sStatus = "(Not here)"
			elseif teamData[teamID]["startx"] > 0 and teamData[teamID]["starty"] > 0 then
				myFont:SetTextColor({0.5,0.5,0.8,1})
				sStatus = "(Marked)"
			elseif teamData[teamID]["startx"] == -100 and teamData[teamID]["starty"] == -100 then
				myFont:SetTextColor({0.4,0.4,0.7,1})
				sStatus = "(Warming up)"
			else
				sStatus = ""
			end
		end
		myFont:Print(sStatus, posX + w - rm - j*cW, posY - dy - 20 - 20*rs,textsize,'r')
		myFont:End()
		
		for rank,_ in ipairs(Spring.GetTeamList()) do -- first player id in matrix is ranking, since table is sorted by most kills
			if rank < 16 then
				local r2,g2,n2,r3,g3,b3,r4,g4,b4
				local xi, yi, hi
				local enemy = kMat[teamID][rank][1] -- the associated player with rank is the actual player id that we want to plot
				
				if enemy ~= gaiaID or haveZombies then
					r2 = teamData[enemy].red or 0
					g2 = teamData[enemy].green or 0
					b2 = teamData[enemy].blue or 0
				else
					r2,g2,b2 = 1,1,1
				end
				
				local luminance  = (r2 * 0.299) + (g2 * 0.587) + (b2 * 0.114)
				
				if luminance > 0.3 then
					r3 = r2 - 0.25 * luminance
					r4 = r3 - 0.25 * luminance
					g3 = g2 - 0.25 * luminance
					g4 = g3 - 0.25 * luminance
					b3 = b2 - 0.25 * luminance
					b4 = b3 - 0.25 * luminance
				else
					r3 = r2 + 0.5 * luminance
					r4 = r3 + 0.5 * luminance
					g3 = g2 + 0.5 * luminance
					g4 = g3 + 0.5 * luminance
					b3 = b2 + 0.5 * luminance
					b4 = b3 + 0.5 * luminance
				end
							
				hi = (kMat[teamID][rank][2]/250)/(splits+1) or 0
				xi = posX + w - rm - (j+0.55)*cW - 10 + 9*rank
				yi = posY - dy - 10 - 24*rs
				
				glColor(0.1,0.1,0.05,0.7)
				--glColor(0.4,0.4,0.2,1)
				glRect(posX + w - rm - (j+0.66)*cW, yi-1, posX + w - rm - j*cW, yi)
				glRect(posX + w - rm - (j+0.66)*cW, yi+hBar, posX + w - rm - j*cW, yi+hBar+1)
				
				glColor(r2,g2,b2,1)
				glRect(
				xi+1,
				yi,
				xi+2,
				yi+hi
				)
				glColor(r3,g3,b3,1)
				glRect(
				xi+2,
				yi,
				xi+3,
				yi+hi
				)
				glColor(r4,g4,b4,1)
				glRect(
				xi+3,
				yi,
				xi+4,
				yi+hi
				)
			end
		end
		
		glColor(1,1,1,1)
		glTexture(false)
	end
end

local function DrawOptionRibbon()
	local h = 180
	local dx = 200
	local x0
	local t = 12
	
	if right then
		x0 = widgetPosX-dx
		x1 = x0 + dx + widgetWidth
	else
		x0 = widgetPosX
		x1 = x0 + dx + widgetWidth
	end
	
	Options["contrastLess"]["x1"] = x0 + 80
	Options["contrastLess"]["x2"] = x0 + 87
	Options["contrastLess"]["y2"] = widgetPosY - 20
	Options["contrastLess"]["y1"] = widgetPosY - 35
	
	Options["contrastMore"]["x1"] = x0 + 88
	Options["contrastMore"]["x2"] = x0 + 95
	Options["contrastMore"]["y2"] = widgetPosY - 20
	Options["contrastMore"]["y1"] = widgetPosY - 35
	
	Options["widthInc"]["x1"] = x0 + 200
	Options["widthInc"]["x2"] = x0 + 215
	Options["widthInc"]["y2"] = widgetPosY - 20
	Options["widthInc"]["y1"] = widgetPosY - 35
	
	Options["widthDec"]["x1"] = x0 + 180
	Options["widthDec"]["x2"] = x0 + 195
	Options["widthDec"]["y2"] = widgetPosY - 20
	Options["widthDec"]["y1"] = widgetPosY - 35
	
	Options["heightInc"]["x1"] = x0 + 200
	Options["heightInc"]["x2"] = x0 + 215
	Options["heightInc"]["y2"] = widgetPosY - 40
	Options["heightInc"]["y1"] = widgetPosY - 55
	
	Options["heightDec"]["x1"] = x0 + 180
	Options["heightDec"]["x2"] = x0 + 195
	Options["heightDec"]["y2"] = widgetPosY - 40
	Options["heightDec"]["y1"] = widgetPosY - 55
	
	Options["disable"]["x1"] = x0 + 220
	Options["disable"]["x2"] = x0 + 220 + t
	Options["disable"]["y2"] = widgetPosY - 100
	Options["disable"]["y1"] = widgetPosY - 100 - t

	Options["FPBar1"]["x1"] = x0 + 180
	Options["FPBar1"]["x2"] = x0 + 180 + t
	Options["FPBar1"]["y2"] = widgetPosY - 200
	Options["FPBar1"]["y1"] = widgetPosY - 200 - t
	
	Options["BPBar1"]["x1"] = x0 + 180
	Options["BPBar1"]["x2"] = x0 + 180 + t
	Options["BPBar1"]["y2"] = widgetPosY - 220
	Options["BPBar1"]["y1"] = widgetPosY - 220 - t
	
	Options["FPBar2"]["x1"] = x0 + 220
	Options["FPBar2"]["x2"] = x0 + 220 + t
	Options["FPBar2"]["y2"] = widgetPosY - 200
	Options["FPBar2"]["y1"] = widgetPosY - 200 - t
	
	Options["BPBar2"]["x1"] = x0 + 220
	Options["BPBar2"]["x2"] = x0 + 220 + t
	Options["BPBar2"]["y2"] = widgetPosY - 220
	Options["BPBar2"]["y1"] = widgetPosY - 220 - t
	
	Options["kills1"]["x1"] = x0 + 180
	Options["kills1"]["x2"] = x0 + 180 + t
	Options["kills1"]["y2"] = widgetPosY - 240
	Options["kills1"]["y1"] = widgetPosY - 240 - t
	
	Options["kills2"]["x1"] = x0 + 220
	Options["kills2"]["x2"] = x0 + 220 + t
	Options["kills2"]["y2"] = widgetPosY - 240
	Options["kills2"]["y1"] = widgetPosY - 240 - t
	
	Options["removeDead"]["x1"] = x0 + 220
	Options["removeDead"]["x2"] = x0 + 220 + t
	Options["removeDead"]["y2"] = widgetPosY - 140
	Options["removeDead"]["y1"] = widgetPosY - 140 - t
	
	Options["resText"]["x1"] = x0 + 220
	Options["resText"]["x2"] = x0 + 220 + t
	Options["resText"]["y2"] = widgetPosY - 160
	Options["resText"]["y1"] = widgetPosY - 160 - t
	
	
	glColor(0,0,0,0.4)                              -- draws background rectangle
	--glRect(x0,widgetPosY, x1, widgetPosY -h)
	local padding = 2
	RectRound(x0-padding, widgetPosY -h-padding, x1+padding, widgetPosY+padding, 6)
	glColor(1,1,1,1)
	glText("Adjust", x0+95, widgetPosY - 10,textsize)
	glText("Options", x0+95, widgetPosY - 90,textsize)
	glRect(x0+95,widgetPosY - 12, x0 + 137, widgetPosY-13)
	glRect(x0+95,widgetPosY - 92, x0 + 145, widgetPosY-93)
	glColor(0.8,0.8,1,0.8)
	--glText("Contrast:", x0+5, widgetPosY - 30,textsize)
	glText("Width:", x0+125, widgetPosY - 30,textsize)
	glText("Height:", x0+125, widgetPosY - 50,textsize)
	glColor(1,1,1,1)
	--[[
	glTexture(images["contrast"])
	glTexRect(
		Options["contrastLess"]["x1"],
		Options["contrastLess"]["y1"],
		Options["contrastMore"]["x2"],
		Options["contrastMore"]["y2"]
		)
		]]--
	glColor(0.8,0.8,1,0.8)
	glText("Disable for non-spectators:", x0+5, widgetPosY - 110,textsize)
	--[[
	glText("Show firepower bar:", x0+5, widgetPosY - 210,textsize)
	glText("Show buildpower bar:", x0+5, widgetPosY - 230,textsize)
	glText("Show kills and losses:", x0+5, widgetPosY - 250,textsize)]]--
	glText("Show resource text:", x0+5, widgetPosY - 170,textsize)
	glText("Remove dead teams:", x0+5, widgetPosY - 150,textsize)
	--glText("(Drag window to reposition)", x0+35, widgetPosY - 280,textsize)
	glColor(1,1,1,1)
	--glText("Player", x0+160, widgetPosY - 192,textsize)
	--glText("Spec", x0+215, widgetPosY - 192,textsize)
	if Options["disable"]["On"] then
		glTexture(images["checkboxon"])
	else
		glTexture(images["checkboxoff"])
	end
	glTexRect(
		Options["disable"]["x1"],
		Options["disable"]["y1"],
		Options["disable"]["x2"],
		Options["disable"]["y2"]
		)
		--[[
	if Options["FPBar2"]["On"] then
		glTexture(images["checkboxon"])
	else
		glTexture(images["checkboxoff"])
	end
	glTexRect(
		Options["FPBar2"]["x1"],
		Options["FPBar2"]["y1"],
		Options["FPBar2"]["x2"],
		Options["FPBar2"]["y2"]
		)
		
	if Options["BPBar2"]["On"] then
		glTexture(images["checkboxon"])
	else
		glTexture(images["checkboxoff"])
	end
	glTexRect(
		Options["BPBar2"]["x1"],
		Options["BPBar2"]["y1"],
		Options["BPBar2"]["x2"],
		Options["BPBar2"]["y2"]
		)
	
	if Options["FPBar1"]["On"] then
		glTexture(images["checkboxon"])
	else
		glTexture(images["checkboxoff"])
	end
	glTexRect(
		Options["FPBar1"]["x1"],
		Options["FPBar1"]["y1"],
		Options["FPBar1"]["x2"],
		Options["FPBar1"]["y2"]
		)
		
	if Options["BPBar1"]["On"] then
		glTexture(images["checkboxon"])
	else
		glTexture(images["checkboxoff"])
	end
	glTexRect(
		Options["BPBar1"]["x1"],
		Options["BPBar1"]["y1"],
		Options["BPBar1"]["x2"],
		Options["BPBar1"]["y2"]
		)
	Options["kills1"]["On"] = false
	glColor(0.8,0.4,0.4,0.5)
	glText("(N/A)", x0+170, widgetPosY - 250,textsize)
	glColor(1,1,1,1)
	
	if Options["kills2"]["On"] then
		glTexture(images["checkboxon"])
	else
		glTexture(images["checkboxoff"])
	end
	glTexRect(
		Options["kills2"]["x1"],
		Options["kills2"]["y1"],
		Options["kills2"]["x2"],
		Options["kills2"]["y2"]
		)
		
		]]--
	if Options["resText"]["On"] then
		glTexture(images["checkboxon"])
	else
		glTexture(images["checkboxoff"])
	end
	glTexRect(
		Options["resText"]["x1"],
		Options["resText"]["y1"],
		Options["resText"]["x2"],
		Options["resText"]["y2"]
		)
	if Options["removeDead"]["On"] then
		glTexture(images["checkboxon"])
	else
		glTexture(images["checkboxoff"])
	end
	glTexRect(
		Options["removeDead"]["x1"],
		Options["removeDead"]["y1"],
		Options["removeDead"]["x2"],
		Options["removeDead"]["y2"]
		)
	
	glTexture(images["more"])
	glTexRect(
		Options["widthInc"]["x1"],
		Options["widthInc"]["y1"],
		Options["widthInc"]["x2"],
		Options["widthInc"]["y2"]
		)
	glTexture(images["less"])
	glTexRect(
		Options["widthDec"]["x1"],
		Options["widthDec"]["y1"],
		Options["widthDec"]["x2"],
		Options["widthDec"]["y2"]
		)
		glTexture(images["more"])
	glTexRect(
		Options["heightInc"]["x1"],
		Options["heightInc"]["y1"],
		Options["heightInc"]["x2"],
		Options["heightInc"]["y2"]
		)
	glTexture(images["less"])
	glTexRect(
		Options["heightDec"]["x1"],
		Options["heightDec"]["y1"],
		Options["heightDec"]["x2"],
		Options["heightDec"]["y2"]
		)
	glTexture(false)
end

local function DrawInfoButton (allyID, active, right, big)
	
	local x1 = Button["info"][allyID]["x1"]
	local y1 = Button["info"][allyID]["y1"]
	local x2 = Button["info"][allyID]["x2"]
	local y2 = Button["info"][allyID]["y2"]

	if big then 
		x2 = x2 + 5
		y2 = y2 + 5
	end
	
	if active then
		glColor(0.8,0.8,0.2,1)
	else
		glColor(1,1,1,1)
	end
	glTexture(images["info"])
	glTexRect(x1,y1,x2,y2)
	
	glColor(1,1,1,1)
	glTexture(false)
end

local function DrawLabelC(text, vOffset)
	if widgetWidth < 67 then
		text = strsub(text, 0, 1)
	end
	glColor(0.55,0.55,0.8,0.7)
	glText(text or "", widgetPosX + 15, widgetPosY + widgetHeight -vOffset+tH-42,textsize)
end

local function DrawLabelCM(text, vOffset)
	local len = #text
	if widgetWidth < 67 then
		text = strsub(text, 0, 1)
	end
	
	myFont:Begin()
	myFont:SetTextColor({0.8,0.8,1,0.8})
	myFont:Print(text or "", widgetPosX + 30-len*1.875, widgetPosY + widgetHeight -vOffset+tH-42,textsize,'s')
	myFont:End()
end

local function DrawLabelCM2(text, vOffset)
	local len = #text
	if widgetWidth < 67 then
		text = strsub(text, 0, 1)
	end
	myFont:Begin()
	myFont:SetTextColor({0.8,0.8,1,0.8})
	myFont:Print(text or "", widgetPosX + 30-len*1.875, widgetPosY + widgetHeight -vOffset+tH-62,textsize,'s')
	myFont:End()
end

local function DrawLabelCT(text, vOffset,t)
	if widgetWidth < 67 then
		text = strsub(text, 0, 1)
	end
	local gs 
	gs,_,_ = GetGameSpeed() or 1
	
	myFont:Begin()
	myFont:SetTextColor({1-0.5*sin(20*t/gs),1-0.5*sin(20*t/gs),1-0.25*sin(20*t/gs),0.8})
	if t < 3 then
		myFont:Print(text or "", widgetPosX + 30, widgetPosY + widgetHeight -vOffset+tH-42,textsize,'s')
	else
		myFont:Print(text or "", widgetPosX + 30 + (t-3)^12, widgetPosY + widgetHeight -vOffset+tH-42,textsize,'s')
	end
	myFont:End()
end

local function DrawBox(hOffset, vOffset,r,g,b)
	local dx = 20
	local dy = 40
	--[[
	glColor(.2,.2,.2)
	glRect(widgetPosX+hOffset+dx+7, widgetPosY + widgetHeight -vOffset+dy+17, widgetPosX+hOffset+dx+8, widgetPosY + widgetHeight -vOffset+dy+3)
	glRect(widgetPosX+hOffset+dx+20, widgetPosY + widgetHeight -vOffset+dy+17, widgetPosX + hOffset + dx + 21, widgetPosY + widgetHeight -vOffset+dy+3)
	glRect(widgetPosX+hOffset+dx+7, widgetPosY + widgetHeight -vOffset+dy+17, widgetPosX + hOffset +dx + 21, widgetPosY + widgetHeight -vOffset+dy+16)
	glRect(widgetPosX+hOffset+dx+7, widgetPosY + widgetHeight -vOffset+dy+4, widgetPosX + hOffset + dx + 21, widgetPosY + widgetHeight -vOffset+dy+3)
	]]--
	glColor(r,g,b,0.5)
	RectRound(widgetPosX+hOffset+dx+8, widgetPosY + widgetHeight -vOffset+dy+4, widgetPosX + hOffset + dx + 20, widgetPosY + widgetHeight -vOffset+dy+16, 3)

	--glRect(widgetPosX+hOffset+dx+8, widgetPosY + widgetHeight -vOffset+dy+16, widgetPosX + hOffset + dx + 20, widgetPosY + widgetHeight -vOffset+dy+4)
	glColor(1,1,1,1)
end


local function DrawSideImage(sideImage, hOffset, vOffset, r, g, b, a, small, mouseOn,t,isDead,isZombie)
	local w
	local h
	local dx
	local dy

	if small then
		w = 8
		h = 8
		dx = 28 + (WBadge-14)*4
		dy = tH - 12
	else
		w = WBadge
		h = WBadge
		dx = 25 + (WBadge-14)*4
		dy = tH - 16 - (WBadge-14)
	end

	if not inSpecMode then dx = dx -10 end

	if isZombie then
		r = 1
		g = 1
		b = 1
	end

	if mouseOn and (not isDead) then
		if ctrlDown then
			glColor(1,1,1,a)
		else
			local gs 
			gs,_,_ = GetGameSpeed() or 1
			glColor(r-0.2*sin(10*t/gs),g-0.2*sin(10*t/gs),b,a)
		end
	else
		glColor(r,g,b,a)
	end
	glTexture(sideImage)
	glTexRect(
	widgetPosX + hOffset + dx,
	widgetPosY + widgetHeight - vOffset + dy,
	widgetPosX + hOffset + dx + w,
	widgetPosY + widgetHeight - vOffset + dy + h
	)
	glTexture(false)
	glColor(1,1,1,1)
end


function DrawSideImages()
	
	-- do dynamic stuff without display list
	
	local t = GetGameSeconds()
	
	for _, data in pairs(allyData) do
		local aID = data.aID
		local drawpos = data.drawpos
		
		if data.exists and drawpos and (aID == myAllyID or inSpecMode) and (aID ~= gaiaAllyID or haveZombies)then
			
			local posy = tH*(drawpos)
			local label, isAlive, hasCom
			
			-- Infobutton
			if showInfoButton then
				if not Button["info"][aID]["click"] then
					DrawInfoButton(aID, Button["info"][aID]["mouse"],right,false)
				else
					DrawInfoButton(aID, Button["info"][aID]["mouse"],right,true)
				end
				
				-- Expand table border and buttons
				if Button["info"][aID]["click"] and pressedExpand then
					DrawExpandTableButtons(aID)
				end
			end
			
			
			-- Player faction images
			for i, tID  in pairs (data.teams) do
				if tID ~= gaiaID or haveZombies then
					
					local tData = teamData[tID]
					local r = tData.red or 1
					local g = tData.green or 1
					local b = tData.blue or 1	
					local alpha, sideImg
					local side = tData.side
					local posx = WBadge*(i-1)
					if not showInfoButton then
						posx = posx - WBadge
					end
					local isZombie = haveZombies and tID == gaiaID
					sideImg = images[side] or images["default"]
					if isZombie then sideImg = images["zombie"] end
					
					data["isAlive"] = not tData.isDead
					hasCom = tData.hasCom
									
					if GetGameSeconds() > 0 then
						if not tData.isDead then
							alpha = tData.active and 1 or 0.3
							DrawSideImage(sideImg,posx,posy, r, g, b,alpha,not hasCom,Button["player"][tID]["mouse"],t, false,isZombie)
						else
							alpha = 0.8
							sideImg = images["dead"]
							
							DrawSideImage(sideImg,posx,posy, r, g, b,alpha,true,Button["player"][tID]["mouse"],t, true,isZombie) --dead, big icon
						end
					else
						DrawBox( posx, posy, r, g, b)
					end
				end
			end
			
		end
	end
end


local function drawListStandard()
	
	local maxMetal 					= 0
	local maxEnergy 				= 0
	local maxFP 					= 0
	local maxBP 					= 0
	local maxHP 					= 0
	local splits
	
	if not gamestarted then updateButtons() end
	
	for _, data in ipairs(allyData) do
		local aID = data.aID
		
		if data.exists and isTeamReal(aID) and (aID == myAllyID or inSpecMode) and (aID ~= gaiaAllyID or haveZombies) then
				
			-- Expanded table
			if Button["info"][aID]["click"] then		
				DrawExpandTable(aID)
			end
			
			maxMetal 	= (data["tM"] and data["tM"] > maxMetal and data["tM"]) or maxMetal
			maxEnergy 	= (data["tE"] and data["tE"] > maxEnergy and data["tE"]) or maxEnergy
			maxFP 		= (data["tFP"] and data["tFP"] > maxFP and data["tFP"])  or maxFP
			maxBP 		= (data["tBP"] and data["tBP"] > maxBP and data["tBP"]) or maxBP
			maxHP 		= (data["killedhp"] and data["killedhp"] > maxHP and data["killedhp"]) or maxHP
			maxHP 		= (data["losthp"] and data["losthp"] > maxHP and data["losthp"]) or maxHP
		end
	end
	
	splits = floor(0.001*maxHP/widgetWidth)
	for _, data in ipairs(allyData) do
		local aID = data.aID
		
		local drawpos = data.drawpos
		
		if data.exists and drawpos and #(data.teams) > 0 and (aID == Spring.GetMyAllyTeamID() or inSpecMode) and (aID ~= gaiaAllyID or haveZombies) then
			
			if not data["isAlive"] then
				data["isAlive"] = isTeamAlive(aID)
			end
			
			local posy = tH*(drawpos)
			
			if data["isAlive"] then DrawBackground(posy) end
			
			local t = GetGameSeconds()
			if data["isAlive"] and t > 0 and gamestarted and not gameover then
				DrawEBar(data["tE"]/maxEnergy,posy)
				DrawEText(data["tE"],posy)
				--[[DrawKillDeathText(data["kills"],data["losses"],posy)
				DrawKillBar(data["killedhp"],posy,splits)
				DrawLossesBar(data["losthp"],posy,splits)]]--
			else
				--[[
				if gamestarted and t < 5 then
					DrawLabelCT("(Go!)", posy,t)
				elseif not gamestarted then
					setPlayerActivestate()
					local nbPlayers = #(data.teams)
					local nbActive = getNbActivePlayers(aID)
					local nbPlaced = getNbPlacedPositions(aID)
					if nbActive > 0 then
						if nbPlayers > 1 and nbPlaced > 0 then
							DrawLabelCM("(On their marks)", posy)
							DrawLabelCM2(tconcat({"   ",nbPlaced,"/",nbPlayers}), posy)
						elseif nbPlayers > 1 then
							DrawLabelC("(Warming up)", posy)
						elseif nbPlayers == 1 then
							if nbPlaced == 1 then
								DrawLabelCM("(On his marks)", posy)
							else
								DrawLabelC("(Warming up)", posy)
							end
						end
					else
						DrawLabelC("(No one here)", posy)
					end
				end]]--
			end
			if data["isAlive"] and t > 5 and not gameover then
			DrawMBar(data["tM"]/maxMetal,posy)
			DrawMText(data["tM"],posy)
			end
			--[[
			if data["tFP"] and data["tFP"] > 0 and not gameover then
				DrawFPBar(data["tFP"]/maxFP,posy,data["tFPM"]/data["tFP"])
			end
			if data["tBP"] and data["tBP"] > 0 and not gameover then
				DrawBPBar(data["tBP"]/maxBP,posy,data["tBPA"]/data["tBP"])
			end]]--
		end
	end
end


---------------------------------------------------------------------------------------------------
--  General
---------------------------------------------------------------------------------------------------

function UpdateAllTeams()

	for _,data in ipairs (allyData) do
		for _,teamID in pairs(data.teams) do
			if inSpecMode or teamData[teamID].allyID == myAllyID then
				setTeamTable(teamID)
				--Echo("Updated team:",teamID,"dead:",teamData[teamID].isAI and "AI" or teamData[teamID].isDead)
			end
		end
	end
end

function UpdateAllies()
	for _, data in ipairs (allyData) do
		
		local allyID = data.aID
		if inSpecMode then
			for _, teamID in pairs (data.teams) do
				UpdateTeam(teamID)
			end
			setAllyData(allyID)
		else
			if allyID == myAllyID then
				for _, teamID in pairs (data.teams) do
					UpdateTeam(teamID)
				end
				setAllyData(allyID) 
			end
		end
	end
end

function UpdateTeam(teamID)
	
	teamData[teamID]["kills"]		= killCounters[teamID]
	teamData[teamID]["losses"]		= lossCounters[teamID]
	teamData[teamID]["killedhp"]	= killedHP[teamID]
	teamData[teamID]["losthp"]		= lostHP[teamID]
	teamData[teamID]["unitCount"]	= GetTeamUnitCount(teamID)
		
end

function UpdateAlly(allyID)
	if inSpecMode then
		setAllyData(allyID)
	else
		
		if allyID == myAllyID then 
			setAllyData(allyID)	
		end
	end
end

function setTeamTable(teamID)
	
	local side, aID, isDead, commanderAlive, minc, einc, kills, losses, x, y, kills2, losses2, leaderName, leaderID, active, unitCount, spectator, country, rank
	
	_,leaderID,isDead,isAI,side,aID,_,_ 				= Spring.GetTeamInfo(teamID)
	leaderName,active,spectator,_,_,_,_,country,rank	= Spring.GetPlayerInfo(leaderID)
		
	if teamID == gaiaID then
		if haveZombies then 
			leaderName = "(Zombie)"
		else
			leaderName = "(Gaia)"
		end
	end
	
	local tred, tgreen, tblue = Spring.GetTeamColor(teamID)
	local luminance  = (tred * 0.299) + (tgreen * 0.587) + (tblue * 0.114)
	if (luminance < 0.2) then
		tred = tred + 0.25
		tgreen = tgreen + 0.25
		tblue = tblue + 0.25
	end
	
	kills2,losses2 				= Spring.GetTeamUnitStats(teamID)
	_,_,_,minc 					= Spring.GetTeamResources(teamID,"metal")
	_,_,_,einc 					= Spring.GetTeamResources(teamID,"energy")
	x,_,y 						= Spring.GetTeamStartPosition(teamID)
	commanderAlive 				= checkCommander(teamID)
	kills 						= killCounters[teamID]
	losses 						= lossCounters[teamID]
	killedhp 					= killedHP[teamID]
	losthp 						= lostHP[teamID]
	unitCount 					= GetTeamUnitCount(teamID)
	if Game.gameShortName == "EvoRTS" then side = "outer_colonies" end
	
	local startUnitDefID = Spring.GetTeamRulesParam(teamID, 'startUnit')
	local cp = ((startUnitDefID and UnitDefs[startUnitDefID]) and UnitDefs[startUnitDefID].customParams) or nil
	if cp and cp.side then side = cp.side end
		
	if not teamData[teamID] then teamData[teamID] = {} end
		
	teamData[teamID]["teamID"] 			= teamID
	teamData[teamID]["allyID"] 			= aID
	teamData[teamID]["red"]				= tred
	teamData[teamID]["green"]			= tgreen
	teamData[teamID]["blue"]			= tblue
	teamData[teamID]["startx"]			= x
	teamData[teamID]["starty"]			= y
	teamData[teamID]["side"]			= side
	teamData[teamID]["isDead"] 			= teamData[teamID]["isDead"] or isDead
	teamData[teamID]["hasCom"]			= commanderAlive
	teamData[teamID]["minc"]			= minc
	teamData[teamID]["einc"] 			= einc
	teamData[teamID]["kills"]			= kills
	teamData[teamID]["losses"]			= losses
	teamData[teamID]["kills2"]			= kills2
	teamData[teamID]["losses2"]			= losses2
	teamData[teamID]["killedhp"]		= killedhp
	teamData[teamID]["losthp"]			= losthp
	teamData[teamID]["leaderID"]		= leaderID
	teamData[teamID]["leaderName"]		= leaderName
	teamData[teamID]["active"]			= active
	teamData[teamID]["spectator"]		= spectator
	teamData[teamID]["unitCount"]		= unitCount
	teamData[teamID]["country"]			= country
	teamData[teamID]["rank"]			= rank
	teamData[teamID]["isAI"]			= isAI
	setPlayerFP(teamID)
	setPlayerBP(teamID)
	teamData[teamID]["skill"]			= GetSkill(teamID)
end

function setAllyData(allyID)
	
	if not allyID or (allyID == gaiaAllyID and not haveZombies) then return end
	local index = allyID + 1
	
	
	if not allyData[index] then
		allyData[index] = {}
		local teamList = Spring.GetTeamList(allyID)
		allyData[index]["teams"] = teamList
		
	end
	
	if not (allyData[index].teams and #allyData[index].teams > 0) then return end
		
	local teamList = allyData[index].teams	
	local team1 = teamList[1] --leader id
	
	for _, tID in pairs (teamList) do
		if not teamData[tID] then
			setTeamTable(tID)
		end
	end
	
	allyData[index]["teams"]			= teamList
	allyData[index]["tE"] 				= getTeamSum(index,"einc")
	allyData[index]["tM"] 				= getTeamSum(index,"minc")
	allyData[index]["tFP"]				= getTeamSum(index,"firepower")
	allyData[index]["tBP"]				= getTeamSum(index,"buildpower")
	allyData[index]["tFPM"]				= getTeamSum(index,"firepowerMob")
	allyData[index]["tBPA"]				= getTeamSum(index,"buildpowerAir")
	allyData[index]["x"]				= getTeamSum(index,"startx")
	allyData[index]["y"]				= getTeamSum(index,"starty")
	allyData[index]["validPlayers"]		= getNbPlacedPositions(allyID)
	allyData[index]["kills"]			= getTeamSum(index,"kills")
	allyData[index]["losses"]			= getTeamSum(index,"losses")
	allyData[index]["killedhp"]			= getTeamSum(index,"killedhp")
	allyData[index]["losthp"]			= getTeamSum(index,"losthp")
	allyData[index]["isAlive"]			= isTeamAlive(allyID)
	allyData[index]["leader"]			= teamData[team1]["leaderName"] or "N/A"
	allyData[index]["tFP"]				= getTeamSum(index,"firepower")
	allyData[index]["tFPM"]				= getTeamSum(index,"firepowerMob")
	allyData[index]["tBP"]				= getTeamSum(index,"buildpower")
	allyData[index]["tBPA"]				= getTeamSum(index,"buildpowerAir")
	allyData[index]["aID"]				= allyID
	allyData[index]["exists"]			= #teamList > 0
	
	if Options["removeDead"]["On"] then
		allyData[index] = nil
	end
	

end

function getTeamSum(allyIndex,param)
	local tValue = 0
	
	local teamList = allyData[allyIndex]["teams"]
		
	for _,tID in pairs (teamList) do
		if tID ~= gaiaID or haveZombies then
			tValue = tValue + (teamData[tID][param] or 0)
		end
	end
	return tValue
	
end

function isTeamReal(allyID)
	if allyID == nil then return false end
	local leaderID, spectator, isDead, unitCount

	for _,tID in ipairs (Spring.GetTeamList(allyID)) do
		_,leaderID,isDead			= Spring.GetTeamInfo(tID)
		unitCount					= GetTeamUnitCount(tID)
		leaderName,active,spectator	= Spring.GetPlayerInfo(leaderID)
		if leaderName ~= nil or isDead or unitCount > 0 then return true end
	end
	return false
end

function isTeamAlive(allyID)
	
	for _,tID in pairs (allyData[allyID+1].teams) do
		if teamData[tID] and (not teamData[tID]["isDead"]) then return true end
	end
	return false
end

function getNbTeams()
	local nbTeams = 0
	
	for _,data in ipairs (allyData) do
		if #(data.teams) > 0 then nbTeams = nbTeams + 1 end
	end
	return nbTeams
end
	
function getMaxPlayers()
	local maxPlayers = 0
	local myNum
	for _,data in ipairs(allyData) do
		
		myNum = #data.teams
		if myNum > maxPlayers then maxPlayers = myNum end
	end

	return maxPlayers
end

function getNbActivePlayers(teamID)
	local nbPlayers = 0
	local leaderID,active,spectator,isDead, leaderName

	for _,pID in ipairs (Spring.GetTeamList(teamID)) do
		leaderID = teamData[pID].leaderID
		leaderName = teamData[pID].leaderName
		active = teamData[pID].active
		spectator = teamData[pID].spectator
		isDead = teamData[pID].isDead
		if not (spectator or isDead or leaderID == -1) and active then
			nbPlayers = nbPlayers +1
		end
	end
	return nbPlayers
end

function getNbPlacedPositions(teamID)
	local nbPlayers = 0
	local startx, starty, active, leaderID, unitCount, leaderName, isDead
	
	for _,pID in ipairs (Spring.GetTeamList(teamID)) do
		if teamData[pID] == nil then
			Echo("getNbPlacedPositions returned nil:",teamID)
			return nil
		end
		leaderID = teamData[pID].leaderID
		if leaderID == nil then
			Echo("getNbPlacedPositions returned nil:",teamID)
			return nil
		end
		startx = teamData[pID].startx or -1
		starty = teamData[pID].starty or -1
		active = teamData[pID].active
		leaderName,active,spectator	= Spring.GetPlayerInfo(leaderID)				
		
		isDead = teamData[pID].isDead
		if (active and startx >= 0 and starty >= 0 and leaderName ~= nil)  or isDead then
			nbPlayers = nbPlayers +1
		end
	end
	return nbPlayers
end

function checkCommander(teamID)
	local hasCom = false
	for _, commanderID in pairs (comTable) do
		if Spring.GetTeamUnitDefCount(teamID,commanderID) > 0 then 
			local unitList = Spring.GetTeamUnitsByDefs(teamID,commanderID)
			for _, uID in pairs(unitList) do
				if not Spring.GetUnitIsDead(uID) then
					hasCom = true 
				end
			end
		end
	end
	return hasCom
end

function checkDeadTeams()
	for teamID in pairs(teamData) do
		isDead = select(3,Spring.GetTeamInfo(teamID))
		teamData[teamID]["isDead"] = isDead
	end
end

function adjustFirePowers()
	for teamID in pairs(teamData) do
		setPlayerFP(teamID)
	end
end

function setPlayerFP(pID)
	local pFP = 0
	local pFPMob = 0
		
	local team = teamData[pID].allyID
	for _, unitID in ipairs(Spring.GetTeamUnits(pID)) do
		local udid = Spring.GetUnitDefID(unitID)
		if udid then
			if AttackUnits[udid] and isUnitComplete(unitID) then
				pFP = pFP + (Spring.GetUnitHealth(unitID) or 0)
				if MobileUnits[udid] then
					pFPMob = pFPMob + (Spring.GetUnitHealth(unitID) or 0)
				end
			end
		end
	end
	teamData[pID]["firepower"]			= pFP
	teamData[pID]["firepowerMob"]		= pFPMob
end

function setPlayerBP(pID)
	local pBP = 0
	local pBPair = 0	
	local team = teamData[pID].allyID
	
	for _, unitID in ipairs(Spring.GetTeamUnits(pID)) do			
		local udid = Spring.GetUnitDefID(unitID)
		if udid then
			if BuilderUnits[udid] and isUnitComplete(unitID) then
				pBP = pBP + (UnitBuildPower[udid] or 0)
				if AirUnits[udid] then
					pBPair = pBPair + (UnitBuildPower[udid] or 0)
				end
			end
		end
	end
	
	teamData[pID]["buildpower"]			= pBP
	teamData[pID]["buildpowerAir"]		= pBPair
end

function setPlayerResources()
	for teamID,data in pairs(teamData) do
		data.minc = select(4,Spring.GetTeamResources(teamID,"metal")) or 0
		data.einc = select(4,Spring.GetTeamResources(teamID,"energy")) or 0
	end
end

function setPlayerActivestate()
	local active
	local leaderID
	for tID,data in pairs(teamData) do
		_,leaderID 	= Spring.GetTeamInfo(tID)
		_,active	= Spring.GetPlayerInfo(leaderID)
		data["active"] 			= active
	end
end

function isUnitComplete(UnitID)
	local health,maxHealth,paralyzeDamage,captureProgress,buildProgress=Spring.GetUnitHealth(UnitID)
	if buildProgress and buildProgress>=1 then
		return true
	else
		return false
	end
end

function GetSkill(playerID)
	local customtable = select(10,Spring.GetPlayerInfo(playerID)) -- player custom table
	
	if not customtable then return "N/A" end
	
	local tsMu = customtable.skill 
	local tsSigma = customtable.skilluncertainty
	local tskill = ""
	if tsMu then
		tskill = tsMu and tonumber(tsMu:match("%d+%.?%d*")) or 0
		tskill = round(tskill,0)
		if strfind(tsMu, ")") then
			tskill = "\255"..strchar(190)..strchar(140)..strchar(140) .. tskill -- ')' means inferred from lobby rank
		else
		
			-- show privacy mode
			local priv = ""
			if strfind(tsMu, "~") then -- '~' means privacy mode is on
				priv = "\255"..strchar(200)..strchar(200)..strchar(200) .. "*" 		
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
				tskill = priv .. "\255"..strchar(tsRed)..strchar(tsGreen)..strchar(tsBlue) .. tskill
			else
				tskill = priv .. "\255"..strchar(195)..strchar(195)..strchar(195) .. tskill --should never happen
			end
		end
	else
		tskill = "\255"..strchar(160)..strchar(160)..strchar(160) .. "?"
	end
	return tskill
end

---------------------------------------------------------------------------------------------------
--  User interface
---------------------------------------------------------------------------------------------------

function IsOnButton(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	if BLcornerX == nil then return false end
	-- check if the mouse is in a rectangle

	return x >= BLcornerX and x <= TRcornerX
	                      and y >= BLcornerY
	                      and y <= TRcornerY

end

function updateButtons()
	
	if widgetPosX < 0 then
		widgetPosX = 0
	elseif widgetPosX + widgetWidth > vsx then
		widgetPosX = vsx-widgetWidth
	end

	if widgetPosY < 0 then
		widgetPosY = 0
	elseif widgetPosY + widgetHeight > vsy then
		widgetPosY = vsy - widgetHeight
	end
	
	widgetRight = widgetPosX + widgetWidth
	if widgetPosX + widgetWidth/2 > vsx/2 then
		right = true
	else
		right = false
	end
		
	local drawpos = 0
	
	for _, data in ipairs(allyData) do
		local allyID = data.aID
		
		if allyID and (allyID ~= gaiaAllyID or haveZombies) then 
			
			local w1 = 14
			local x1, y1, x2, y2
			local nbPlayers = #data.teams
			maxPlayers = getMaxPlayers()
			local lm = 20
			local w = 180 + cW*nbPlayers
			
			if inSpecMode then
				widgetHeight = getNbTeams()*tH+2
			else
				widgetHeight = tH+2
			end
			
			x1 	= widgetPosX + 2
			
			iPosX[allyID] = InfotablePosX
			iPosY[allyID] = InfotablePosY
			
			if iPosX[allyID] < 0 then iPosX[allyID] = 0 end
			if iPosX[allyID] + w > vsx then iPosX[allyID] = vsx - w end
			if iPosY[allyID] - infoTableHeight < 0 then iPosY[allyID] = infoTableHeight end
			if iPosY[allyID]  > vsy then iPosY[allyID] = vsy  end
			
			x2 = x1 + w1
			y1 = widgetPosY + widgetHeight - (drawpos)*tH - w1 - 3 
			y2 = y1 + w1
			
			Button["info"][allyID]["x1"] 		= x1
			Button["info"][allyID]["y1"] 		= y1
			Button["info"][allyID]["x2"] 		= x2
			Button["info"][allyID]["y2"] 		= y2
			
			local x3, y3, x4, y4
			local w2 = 18
			
			local x5, y5, x6, y6
			
			x5 	= iPosX[allyID] + lm
			x6 	= iPosX[allyID] + lm + 20
			y6 	= iPosY[allyID] - 25
			y5 	= y6 - 20
			
			Button["expandMove"][allyID]["x1"] 		= x5
			Button["expandMove"][allyID]["y1"] 		= y5
			Button["expandMove"][allyID]["x2"] 		= x6
			Button["expandMove"][allyID]["y2"] 		= y6
			
			local x7,x8,x9,x10,y7,y8,y9,y10
			
			x7 = iPosX[allyID] + w/2 - 60
			x8 = x7 + 12 
			y8 = iPosY[allyID] - 25
			y7 = y8 - 18
			
			x9 = iPosX[allyID] + w/2 + 38
			x10 = x9 + 12
			y10 = iPosY[allyID] - 25
			y9 = y10 - 18
			
			Button["teamprev"][allyID]["x1"] = x7
			Button["teamprev"][allyID]["x2"] = x8
			Button["teamnext"][allyID]["x1"] = x9
			Button["teamnext"][allyID]["x2"] = x10
			Button["teamprev"][allyID]["y1"] = y7
			Button["teamprev"][allyID]["y2"] = y8
			Button["teamnext"][allyID]["y1"] = y9
			Button["teamnext"][allyID]["y2"] = y10
		end
		
		for i,tID in pairs (data.teams) do
			Button["player"][tID]["x1"] = widgetPosX + WBadge*(i-1) + 25 + (WBadge-14)*4 
			Button["player"][tID]["x2"] = widgetPosX + WBadge*(i-1) + 25 + (WBadge-14)*4 + WBadge
			Button["player"][tID]["y1"] = widgetPosY + widgetHeight - tH*(drawpos) - 16 - (WBadge-14)
			Button["player"][tID]["y2"] = widgetPosY + widgetHeight - tH*(drawpos) - 16 - (WBadge-14) + WBadge
			Button["player"][tID]["pID"] = tID
			
			if not inSpecMode then 
				Button["player"][tID]["x1"] = widgetPosX + WBadge*(i-1) + 25 + (WBadge-14)*4  - 10
				Button["player"][tID]["x2"] = widgetPosX + WBadge*(i-1) + 25 + (WBadge-14)*4 + WBadge - 10
				
			end
		end
		
		if isTeamReal(allyID) and (allyID == Spring.GetMyAllyTeamID() or inSpecMode) then
			drawpos = drawpos + 1
		end
		data["drawpos"] = drawpos
	end
end

---------------------------------------------------------------------------------------------------
--  Call-ins
---------------------------------------------------------------------------------------------------

function widget:PlayerChanged(playerID)
	local frame = GetGameFrame()
	lastPlayerChange = frame
	if not (Spring.GetSpectatingState() or isReplay) then
		if inSpecMode then Spring.Log("widget", LOG.INFO,"Ecostats: widget now in active player mode.") end
		inSpecMode = false
		UpdateAllies()
	else
		if not inSpecMode then Spring.Log("widget", LOG.INFO,"Ecostats: widget now in spectator mode.") end
		inSpecMode = true
		Reinit()
	end
	makeStandardList()
	--drawDynamic()
end

--[[
function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if teamData[unitTeam] then
		if AttackUnits[unitDefID] then 
		
			local pFP = Spring.GetUnitHealth(unitID) or 0
			teamData[unitTeam]["firepower"]			= teamData[unitTeam]["firepower"] + pFP
			
			if MobileUnits[unitDefID] then
				teamData[unitTeam]["firepowerMob"]		= teamData[unitTeam]["firepowerMob"] + pFP
			end
		end
		
		if BuilderUnits[unitDefID] then
			local pBP = UnitBuildPower[unitDefID] or 0
			teamData[unitTeam]["buildpower"] = teamData[unitTeam]["buildpower"] + pBP
			
			if AirUnits[unitDefID] then
				teamData[unitTeam]["buildpowerAir"] = teamData[unitTeam]["buildpowerAir"] + pBP
			end	
		end
		
		if comDefs[unitDefID] then
			teamData[unitTeam]["hasCom"] = checkCommander(unitTeam)
		end
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	
	if teamData[unitTeam] and teamData[newTeam] then
		
		if AttackUnits[unitDefID] then 
			local pFP = Spring.GetUnitHealth(unitID) or 0
			teamData[newTeam]["firepower"]			= teamData[newTeam]["firepower"] + pFP
			teamData[unitTeam]["firepower"]			= teamData[unitTeam]["firepower"] - pFP
			
			if MobileUnits[unitDefID] then
				teamData[newTeam]["firepowerMob"]		= teamData[newTeam]["firepowerMob"] + pFP
				teamData[unitTeam]["firepowerMob"]		= teamData[unitTeam]["firepowerMob"] - pFP
			end
		end
		
		if BuilderUnits[unitDefID] then
			local pBP = UnitBuildPower[unitDefID] or 0
			teamData[newTeam]["buildpower"] = teamData[newTeam]["buildpower"] + pBP
			teamData[unitTeam]["buildpower"] = teamData[unitTeam]["buildpower"] - pBP
			
			if AirUnits[unitDefID] then
				teamData[newTeam]["buildpowerAir"] = teamData[newTeam]["buildpowerAir"] + pBP
				teamData[unitTeam]["buildpowerAir"] = teamData[unitTeam]["buildpowerAir"] - pBP
			end	
		end
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	-- handled by taken
	return false
end

function widget:UnitDestroyed(u,ud,ut,a,ad,at) --unitID, unitDefID, teamID, attackerID
	
	if teamData[ut] then
		if AttackUnits[ud] then 
		
			local pFP = Spring.GetUnitHealth(u) or 0
			teamData[ut]["firepower"]				= teamData[ut]["firepower"] - pFP
			
			if MobileUnits[ud] then
				teamData[ut]["firepowerMob"]		= teamData[ut]["firepowerMob"] - pFP
			end
		end
		
		if BuilderUnits[ud] then
			local pBP = UnitBuildPower[ud] or 0
			teamData[ut]["buildpower"] = teamData[ut]["buildpower"] + pBP
			
			if AirUnits[ud] then
				teamData[ut]["buildpowerAir"] = teamData[ut]["buildpowerAir"] - pBP
			end	
		end
	end
		
	a = Spring.GetUnitLastAttacker(u)
	
	if a then at = Spring.GetUnitTeam(a) end
	
	if comDefs[ud] then
		if ut and teamData[ut] then 
			teamData[ut]["hasCom"]		= checkCommander(ut)
			setTeamTable(ut)
			UpdateAllies()
		end
		if at and teamData[at] then 
			teamData[at]["hasCom"]		= checkCommander(at)
		end
	end
	
	local function sortByLargest(v1,v2)
		return v1[2] > v2[2]
	end
	
	local function sortByTeam(v1,v2)
		return v1[1] < v2[1]
	end
	
	if ut and at and (not Spring.AreTeamsAllied(ut,at)) and isUnitComplete(u) and u and a and u~=a and teamData[ut] and teamData[at] then
		local _,uhp =  Spring.GetUnitHealth(u)
		
		killCounters[at]=killCounters[at]+1
		lossCounters[ut]=lossCounters[ut]+1
		killedHP[at] =  killedHP[at] + uhp
		lostHP[ut] = lostHP[ut] + uhp
		
		table.sort(kMat[at],sortByTeam)
		
		local sortindex = ut + 1
		
		kMat[at][sortindex][2] = kMat[at][sortindex][2] + uhp
		if kMat[at][sortindex][2] > PmaxDmg then PmaxDmg = kMat[at][sortindex][2] end
		
		table.sort(kMat[at],sortByLargest)
				
		if lossCounters[ut]>worstLosses then
			worstLosses = lossCounters[ut]
		end
		if killCounters[at]>bestKills then
			bestKills=killCounters[at]
			if at~=bestTeam then
				bestTeam=at
			end
		end
	end
end
]]--

function widget:GameStart()
	gamestarted = true
end

function widget:GameOver()
	gameover = true
	UpdateAllTeams()
end

function widget:TeamDied(teamID)
		
	local frame = GetGameFrame()
	
	if teamData[teamID] then
		teamData[teamID]["isDead"] = true
	end
	
	lastPlayerChange = frame
	
	removeGuiShaderRects()
	
	if not (Spring.GetSpectatingState() or isReplay) then
		if inSpecMode then Spring.Log("widget", LOG.INFO,"Ecostats: widget now in active player mode.") end
		inSpecMode = false
		UpdateAllies()
		UpdateAllTeams()
	else
		if not inSpecMode then Spring.Log("widget", LOG.INFO,"Ecostats: widget now in spectator mode.") end
		inSpecMode = true
		UpdateAllTeams()
		Reinit()
	end	
end

function widget:MapDrawCmd(playerID, cmdType, px, py, pz, labeltext)
	if not gamestarted then 
		UpdateAllies() 
		makeStandardList()
		--drawDynamic()
	end
end

function widget:TweakMouseMove(x,y,dx,dy,button)
--[[
	if pressedExpandMove then
		for _,data in ipairs (allyData) do
			local allyID = data.aID
			if data.exists then
				if Button["info"][allyID]["click"] then nbPlayers = #(data.teams) end
			end
		end
		
		local w = 180 + cW*getMaxPlayers()
		
		InfotablePosX = InfotablePosX + dx
		InfotablePosY = InfotablePosY + dy
		
		if InfotablePosX < 0 then
			InfotablePosX = 0
		end
		
		if InfotablePosX + w  > vsx then
			InfotablePosX = vsx - w
		end
		
		updateButtons()
		setPlayerResources()
		makeStandardList()
		--drawDynamic()
		return true
	end
	
	if pressedToMove then
		if moveStartX == nil then                                                      -- move widget on y axis
			moveStartX = x - widgetPosX
		end
		if moveStartY == nil then                                                      -- move widget on y axis
			moveStartY = y - widgetPosY
		end
		widgetPosX = widgetPosX + dx
		widgetPosY = widgetPosY + dy

		updateButtons()
		setPlayerResources()
		makeStandardList()
		--drawDynamic()
		return true
	end
	return false
	]]--
	if pressedToMove ~= nil then
		if moveStartX == nil then                                                      -- move widget on y axis
			moveStartX = x - widgetPosX
		end
		if moveStartY == nil then                                                      -- move widget on y axis
			moveStartY = y - widgetPosY
		end
		widgetPosX = widgetPosX + dx
		widgetPosY = widgetPosY + dy
		
		updateButtons()
		makeStandardList()
		makeSideImageList()
		--drawDynamic()
	end
end

function widget:TweakMousePress(x, y, button)
	if button == 2 then
		if IsOnButton(x, y, widgetPosX, widgetPosY, widgetPosX + widgetWidth, widgetPosY+widgetHeight) then
			pressedToMove = true
			return true
		end
	elseif button == 1 then
		local x0, x1
		
		if right then
			x0 = widgetPosX-200
		else
			x0 = widgetPosX
		end
		x1 = x0 + 200 + widgetWidth

		--[[if IsOnButton(x, y, Options["contrastLess"]["x1"],Options["contrastLess"]["y1"],Options["contrastLess"]["x2"],Options["contrastLess"]["y2"]) then
			Options["contrast"] = Options["contrast"] - 0.1
			if Options["contrast"] < 0 then Options["contrast"] = 0 end
			Echo("Contrast = " .. formatRes1000(Options["contrast"]))
			return true
		elseif IsOnButton(x, y, Options["contrastMore"]["x1"],Options["contrastMore"]["y1"],Options["contrastMore"]["x2"],Options["contrastMore"]["y2"]) then
			Options["contrast"] = Options["contrast"] + 0.1
			if Options["contrast"] > 1.0 then Options["contrast"] = 1.0 end
			Echo("Contrast = " .. formatRes1000(Options["contrast"]))
			return true
		
		else]]--
		if IsOnButton(x, y, Options["widthInc"]["x1"],Options["widthInc"]["y1"],Options["widthInc"]["x2"],Options["widthInc"]["y2"]) then
			pressedWPlus = true
			widgetWidth = widgetWidth + 5
			if widgetWidth > 500 then widgetWidth = 500 end
			if widgetPosX + widgetWidth > vsx then widgetPosX = vsx - widgetWidth end
			return true
		
		elseif IsOnButton(x, y, Options["widthDec"]["x1"],Options["widthDec"]["y1"],Options["widthDec"]["x2"],Options["widthDec"]["y2"]) then
			pressedWMinus = true
			widgetWidth = widgetWidth - 5
			if widgetWidth < 25 then widgetWidth = 25 end
			return true		
		elseif IsOnButton(x, y, Options["heightInc"]["x1"],Options["heightInc"]["y1"],Options["heightInc"]["x2"],Options["heightInc"]["y2"]) then
			pressedHPlus = true
			tH = tH + 2
			if tH > 100 then tH = 100 end
			return true
		
		elseif IsOnButton(x, y, Options["heightDec"]["x1"],Options["heightDec"]["y1"],Options["heightDec"]["x2"],Options["heightDec"]["y2"]) then
			pressedHMinus = true
			tH = tH - 2
			if tH < 4 then tH = 4 end
			return true
			
		elseif IsOnButton(x, y, Options["disable"]["x1"],Options["disable"]["y1"],Options["disable"]["x2"],Options["disable"]["y2"]) then
			Options["disable"]["On"] = not Options["disable"]["On"]
			return true
			--[[
		elseif IsOnButton(x, y, Options["FPBar1"]["x1"],Options["FPBar1"]["y1"],Options["FPBar1"]["x2"],Options["FPBar1"]["y2"]) then
			Options["FPBar1"]["On"] = not Options["FPBar1"]["On"]	
			return true	
		elseif IsOnButton(x, y, Options["FPBar2"]["x1"],Options["FPBar2"]["y1"],Options["FPBar2"]["x2"],Options["FPBar2"]["y2"]) then
			Options["FPBar2"]["On"] = not Options["FPBar2"]["On"]	
			return true
		elseif IsOnButton(x, y, Options["BPBar1"]["x1"],Options["BPBar1"]["y1"],Options["BPBar1"]["x2"],Options["BPBar1"]["y2"]) then
			Options["BPBar1"]["On"] = not Options["BPBar1"]["On"]	
			return true	
		elseif IsOnButton(x, y, Options["BPBar2"]["x1"],Options["BPBar2"]["y1"],Options["BPBar2"]["x2"],Options["BPBar2"]["y2"]) then
			Options["BPBar2"]["On"] = not Options["BPBar2"]["On"]	
			return true	
		elseif IsOnButton(x, y, Options["kills1"]["x1"],Options["kills1"]["y1"],Options["kills1"]["x2"],Options["kills1"]["y2"]) then
			Options["kills1"]["On"] = not Options["kills1"]["On"]	
			return true		
		elseif IsOnButton(x, y, Options["kills2"]["x1"],Options["kills2"]["y1"],Options["kills2"]["x2"],Options["kills2"]["y2"]) then
			Options["kills2"]["On"] = not Options["kills2"]["On"]	
			return true	]]--
		elseif IsOnButton(x, y, Options["removeDead"]["x1"],Options["removeDead"]["y1"],Options["removeDead"]["x2"],Options["removeDead"]["y2"]) then
			Options["removeDead"]["On"] = not Options["removeDead"]["On"]	
			return true
		elseif IsOnButton(x, y, Options["resText"]["x1"],Options["resText"]["y1"],Options["resText"]["x2"],Options["resText"]["y2"]) then
			Options["resText"]["On"] = not Options["resText"]["On"]	
			return true
		elseif IsOnButton(x, y, widgetPosX, widgetPosY, widgetPosX + widgetWidth, widgetPosY + widgetHeight) or 
		IsOnButton(x, y, x0, widgetPosY - 300, x1, widgetPosY) 
		then
			--pressedToMove = true
			--return true
		end -- end Button == 1
	else
		return false
	end
end

function widget:TweakMouseRelease(x,y,button)
	pressedToMove = nil                                             
	pressedHPlus = false
	pressedHMinus = false
	pressedWPlus = false
	pressedWMinus = false
end

function widget:KeyPress(key, mods, isRepeat) 
	if (key == 0x132) and (not isRepeat) and not (mods.shift) and (not mods.alt) then -- ctrl
		ctrlDown = true
	end
	return false
end

function widget:KeyRelease(key) 
	if (key == 0x132)  then -- ctrl
		ctrlDown = false
	end
	return false
end

--[[
function widget:MouseMove(x, y, dx, dy, button)
	if pressedExpandMove then
		for _,data in ipairs (allyData) do
			local allyID = data.aID
			if data.exists then
				if Button["info"][allyID]["click"] then nbPlayers = #(data.teams) end
			end
		end
		
		local w = 180 + cW*getMaxPlayers()
		
		InfotablePosX = InfotablePosX + dx
		InfotablePosY = InfotablePosY + dy
		
		if InfotablePosX < 0 then
			InfotablePosX = 0
		end
		
		if InfotablePosX + w  > vsx then
			InfotablePosX = vsx - w
		end
		
		updateButtons()
		setPlayerResources()
		makeStandardList()
		--drawDynamic()
		return true
	end
	
	if pressedToMove then
		if moveStartX == nil then                                                      -- move widget on y axis
			moveStartX = x - widgetPosX
		end
		if moveStartY == nil then                                                      -- move widget on y axis
			moveStartY = y - widgetPosY
		end
		widgetPosX = widgetPosX + dx
		widgetPosY = widgetPosY + dy

		updateButtons()
		setPlayerResources()
		makeStandardList()
		--drawDynamic()
		return true
	end
	return false
end
]]--

function widget:MousePress(x, y, button)
	----------------
	-- LEFT BUTTON
	----------------
		
	if button == 1 then	
		
		for name, buttonType in pairs(Button) do
			if name ~= "player" then	
				for allyID,button in pairs(buttonType) do			
					local allyDataIndex = allyID+1
					if IsOnButton(x, y, button.x1, button.y1, button.x2, button.y2) then
						if name == "info" and (not Options["removeDead"]["On"] or allyData[allyDataIndex]["isAlive"]) then
							if showInfoButton then
								for id, teambutton in pairs(Button.info) do
									if id~= allyID then
										teambutton.click = false
									end
								end
								
								button.click = not button.click
								
								pressedExpand = button.click
								
								makeStandardList()
								
								return true
							end
						elseif pressedExpand and inSpecMode and Button["info"][allyID].click then
							if name == "teamnext" then									
								
								local nextAlly = FindNextAlly(allyID)
								if nextAlly then
									Button["info"][allyID]["click"] = false
									Button["info"][nextAlly]["click"] = true
									makeStandardList()
									
									return true
								end
							elseif name == "teamprev" then
								local prevAlly = FindPrevAlly(allyID)
								
								if prevAlly then
									Button["info"][allyID]["click"] = false
									Button["info"][prevAlly]["click"] = true
									
									makeStandardList()
									
									return true
								end
							end
						end
					end
				end
			elseif name == "player" then
				for teamID,button in pairs(buttonType) do
					
					button.click = false
					if IsOnButton(x, y, button.x1, button.y1, button.x2, button.y2) then
					
						if ctrlDown and teamData[teamID].hasCom then
						local com
						for _, commanderID in ipairs (comTable) do
							com  = Spring.GetTeamUnitsByDefs(teamID,commanderID)[1] or com
						end
			
						if com then
			
							local cx, cy, cz
							local camState = Spring.GetCameraState()
							cx, cy, cz = Spring.GetUnitPosition(com)
															
							if camState and cx and Game.gameShortName ~= "EvoRTS" then
								camState["px"] = cx
								camState["py"] = cy
								camState["pz"] = cz
								camState["height"] = 800
								
								Spring.SetCameraState(camState,0.75)
								if inSpecMode then Spring.SelectUnitArray({com}) end
							elseif cx then
								Spring.SetCameraTarget(cx,cy,cz,0.5)
							end
						end
					elseif not ctrlDown then
						local sx = teamData[teamID].startx
						local sz = teamData[teamID].starty
						if sx ~= nil and sz ~= nil then
							local sy = Spring.GetGroundHeight(sx,sz)
							local camState = Spring.GetCameraState()
							if camState and sx and sz and sx > 0 and sz > 0 and Game.gameShortName ~= "EvoRTS" then
								camState["px"] = sx
								camState["py"] = sy
								camState["pz"] = sz
								camState["height"] = 5000
								Spring.SetCameraState(camState,2)
							elseif sx then
								Spring.SetCameraTarget(sx,sy,sz,0.5)
							end
						end
					end
						return true
					end
				end
			end
		end	
	
		if pressedExpand then
			for _,data in ipairs (allyData) do
				if data.exists then
					local allyID = data.aID
					local x15 = iPosX[allyID]
					local y16 = iPosY[allyID]
					local x16 = x15 + 180 + cW* #(data.teams)
					local y15 = y16 - infoTableHeight
				
					if IsOnButton(x, y, x15, y15, x16, y16) then 	
						pressedExpandMove = true
						makeStandardList()
						--drawDynamic()
						return true
					end
				end
			end
		end
				
		return false
	----------------
	-- RIGHT BUTTON
	----------------
	--[[elseif button == 2 then
		if IsOnButton(x,y,widgetPosX,widgetPosY,widgetPosX+widgetWidth,widgetPosY+widgetHeight) then
			pressedToMove = true
			return true
		end]]--
	elseif button == 3 then
		local x5, y5, x6, y6
		local w
		
		for _,data in ipairs (allyData) do
			local allyID = data.aID
			if data.exists then
				if allyID ~= gaiaAllyID or haveZombies then
					w = 180 + cW * #data.teams
					
					x5 = iPosX[allyID]
					x6 = x5 + w
					y6 = iPosY[allyID]
					y5 = y6 - infoTableHeight
					
					
					if Button["info"][allyID]["click"] then	
						if IsOnButton(x, y, x5, y5, x6, y6) then
							Button["info"][allyID]["click"] = false
							pressedExpand = false
							makeStandardList()
							--drawDynamic()
							return true
						end
					end
				end
			end
		end
		
		-- second loop is needed for drag detection, because otherwise it returns true too soon
		for _,data in ipairs (allyData) do
			local allyID = data.aID
			if data.exists then
				if IsOnButton(x,y,widgetPosX,widgetPosY,widgetPosX+widgetWidth,widgetPosY+widgetHeight) then
					pressedToMove = true
					makeStandardList()
					--drawDynamic()
					return true
				else
					return false
				end
			end
		end
	else
		return false
	end
end

function widget:MouseRelease(x,y,button)
	if button == 1 then 
		pressedExpandMove = false 
	elseif button == 2 or button == 3 then
		pressedToMove = nil                                              -- ends move action
	end
end


function widget:IsAbove(x, y)
	return IsOnButton(x, y, widgetPosX, widgetPosY, widgetPosX + widgetWidth, widgetPosY+widgetHeight)
end

function widget:GetTooltip(mx, my)
	if IsOnButton(mx, my, widgetPosX, widgetPosY, widgetPosX + widgetWidth, widgetPosY+widgetHeight) then
		return string.format("In CTRL+F11 mode: Hold \255\255\255\1middle mouse button\255\255\255\255 to drag this display.\n\n"..
			"This widget shows the total economy of each team.")
	end
end

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx,vsy = gl.GetViewSizes()
	Reinit()
end

function widget:GameFrame(frameNum)
	
	if frameNum == 15 then
		UpdateAllTeams()
	end
	
	if frameNum%30 == 2 then 
		updateButtons()
		setPlayerResources()
		UpdateAllies() 
		makeStandardList()
	end
	if frameNum%60 == 5 then 
		makeSideImageList()
	end
	
	--[[ set Firepower that has changed bc of unit xp and health
	if frameNum%320 == 0 then 
		adjustFirePowers()
	end
	]]--
	
	if frameNum - lastPlayerChange == 30  then
		checkDeadTeams()
		UpdateAllies() 
		updateButtons()
		makeStandardList()
		makeSideImageList()
	end
	
	if not gamestarted and frameNum > 0 then gamestarted = true end
end

--[[
function widget:Update()
		
	if not gamestarted then
		makeStandardList()
	end
end
]]--
---------------------------------------------------------------------------------------------------
--  Draw
---------------------------------------------------------------------------------------------------

function makeStandardList()
	if (drawList) then gl.DeleteList(drawList) end
	drawList = gl.CreateList(drawListStandard)
end
function makeSideImageList()
	if (sideImageList) then gl.DeleteList(sideImageList) end
	sideImageList = gl.CreateList(DrawSideImages)
end

function widget:TweakDrawScreen()
	DrawOptionRibbon()
	updateButtons()
	makeStandardList()
	--drawDynamic()		
end

function widget:DrawScreen()
	
	if Spring.IsGUIHidden() or (not inSpecMode and Options["disable"]["On"]) then return end
	
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('ecostats_expandtable')
	end
	
	if not drawList then makeStandardList() end
	if not sideImageList then makeSideImageList() end
	
	if pressedExpand and (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(expandTablePos[1],expandTablePos[2],expandTablePos[3],expandTablePos[4],'ecostats_expandtable')
	end
	
	gl.PushMatrix()
	gl.CallList(drawList)
	gl.CallList(sideImageList)
	gl.PopMatrix()

end


-- end
