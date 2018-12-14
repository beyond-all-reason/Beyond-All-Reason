function widget:GetInfo()
	return {
		name = "Ecostats",
		desc = "Display team eco",
		author = "Floris  (original by Jools)",
		date = "nov, 2015",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end


local loadSettings		= true

---------------------------------------------------------------------------------------------------
--  Declarations
---------------------------------------------------------------------------------------------------

local PmaxDmg						= 0
local comTable 						= {}
local comDefs						= {}
local teamData 						= {}
local allyData 						= {}
local gamestarted 					= false
local gameover						= false
local inSpecMode					= false
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
local glText						= gl.Text
local GetGameSpeed					= Spring.GetGameSpeed
local GetTeamUnitCount				= Spring.GetTeamUnitCount
local GetMyAllyTeamID				= Spring.GetMyAllyTeamID
local GetTeamList					= Spring.GetTeamList
local GetTeamInfo					= Spring.GetTeamInfo

local GetPlayerInfo					= Spring.GetPlayerInfo
local GetTeamColor					= Spring.GetTeamColor
local GetTeamResources				= Spring.GetTeamResources
local Echo							= Spring.Echo

local reclaimerUnits = {}

local Button 						= {}
Button["player"] 					= {}
Button["team"] 						= {}

local Options						= {}
local tooltipAreas					= {}

local lastPlayerChange				= 0
local aliveAllyTeams				= 0
local lastDrawUpdate				
local drawList

local vsx,vsy                    	= gl.GetViewSizes()
local right							= true
local widgetHeight					
local widgetWidth                	= 130
local tH						 	= 40 -- team row height
local WBadge					 	= 14 -- width of player badge (side icon)
local iPosX, iPosY
local cW 							= 100 -- column width
local ctrlDown 						= false
local textsize						= 14
local textlarge						= 18
local gaiaID						= Spring.GetGaiaTeamID()
local gaiaAllyID					= select(6,GetTeamInfo(gaiaID))
local LIMITSPEED					= 2.0 -- gamespseed under which to fully update dynamic graphics
local haveZombies 					= (tonumber((Spring.GetModOptions() or {}).zombies) or 0) == 1
local maxPlayers					= 0

local ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)

local myFullview = select(2,Spring.GetSpectatingState())

local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()

local enableStartposbuttons = true
if (tonumber(Spring.GetModOptions().ffa_mode) or 0) == 1 then		-- spots wont match when ffa
	enableStartposbuttons = false
end

local vsx,vsy = gl.GetViewSizes()
local widgetScale = (1 + (vsx*vsy / 7500000))		-- only used for rounded corners atm
	
--To determine faction at start
local armcomDefID = UnitDefNames.armcom.id
local corcomDefID = UnitDefNames.corcom.id

local borderPadding					= 4

local avgFrames 					= 8

local xRelPos, yRelPos				= 1, 1
local widgetPosX, widgetPosY        = xRelPos*vsx, yRelPos*vsy
local widgetRight			 	    = widgetPosX + widgetWidth

local sizeMultiplier   = 1

local singleTeams = false
if #Spring.GetTeamList()-1  ==  #Spring.GetAllyTeamList()-1 then
	singleTeams = true
end

Options = {}
Options["resText"] = {}
Options["resText"]["On"] = false
Options["sticktotopbar"] = {}
Options["sticktotopbar"]["On"] = true
Options["removeDead"] = {}
Options["removeDead"]["On"] = false
	
---------------------------------------------------------------------------------------------------

local fontPath  		= "LuaUI/Fonts/ebrima.ttf" 
local font2Path  		= "LuaUI/Fonts/ebrima.ttf"
local myFont	 		= gl.LoadFont("FreeSansBold.otf",textsize, 1.9, 40) --gl.LoadFont(fontPath,textsize,2,20)

local bgcorner	= "LuaUI/Images/bgcorner.png"

local images			= {
	["arm"]					= "LuaUI/Images/ecostats/arm_default.png",
	["core"]     			= "LuaUI/Images/ecostats/core_default.png",
	["checkboxon"]			= "LuaUI/Images/ecostats/chkBoxOn.png",
	["checkboxoff"]			= "LuaUI/Images/ecostats/chkBoxOff.png",
	["default"]				= "LuaUI/Images/ecostats/default.png",
	["dead"]     			= "LuaUI/Images/ecostats/cross.png",
	["zombie"]     			= "LuaUI/Images/ecostats/cross_inv.png",
	["bar"]     			= "LuaUI/Images/ecostats/bar.png",
	["barbg"]     			= "LuaUI/Images/ecostats/barbg.png",
	["barglowcenter"]     	= ":n:LuaUI/Images/ecostats/barglow-center.png",
	["barglowedge"]     	= ":n:LuaUI/Images/ecostats/barglow-edge.png",
	["outer_colonies"]		= "LuaUI/Images/ecostats/ecommander.png", -- commander in evorts
}

---------------------------------------------------------------------------------------------------
--  Start
---------------------------------------------------------------------------------------------------

function widget:Initialize()
	if not (Spring.GetSpectatingState() or isReplay) then
		inSpecMode = false
		Spring.Echo("Ecostats: widget loaded in active player mode")
	else
		inSpecMode = true
		Spring.Echo("Ecostats: widget loaded in spectator mode")
		setReclaimerUnits()
	end
	if GetGameSeconds() > 0 then gamestarted = true end

	Init()
end

function removeGuiShaderRects()
	if WG['guishader_api'] ~= nil then
		for _, data in pairs(allyData) do
			local aID = data.aID
			if isTeamReal(aID) and (aID == GetMyAllyTeamID() or inSpecMode) and (aID ~= gaiaAllyID or haveZombies) then
				WG['guishader_api'].RemoveRect('ecostats_'..aID)
			end
		end
	end

	if WG['tooltip'] ~= nil then
		for _, data in pairs(allyData) do
			local aID = data.aID
			if isTeamReal(aID) and (aID == GetMyAllyTeamID() or inSpecMode) and (aID ~= gaiaAllyID or haveZombies) then
				if tooltipAreas['ecostats_'..aID] ~= nil then
					WG['tooltip'].RemoveTooltip('ecostats_'..aID)
					tooltipAreas['ecostats_'..aID] = nil
					local teams = Spring.GetTeamList(aID)
					for _, tID in ipairs(teams) do
						WG['tooltip'].RemoveTooltip('ecostats_team_'..tID)
					end
				end
			end
		end
	end

end

function widget:Shutdown()
	removeGuiShaderRects()
	if (drawList) then 			gl.DeleteList(drawList) end
	if (sideImageList) then		gl.DeleteList(sideImageList) end
end

function Init()
	setDefaults()
	
	teamData = {}
	allyData = {}
	comTable = {}

	Button["player"] = {}
	iPosX = {}
	iPosY = {}

	right = widgetPosX/vsx > 0.5
	widgetHeight = getNbTeams()*tH+(2*sizeMultiplier)

	for id,unitDef in ipairs(UnitDefs) do
		if unitDef.customParams.iscommander then
			table.insert(comTable,id)
			comDefs[id] = true
		end
	end

	allyData  = {}
	for _, allyID in ipairs (Spring.GetAllyTeamList() ) do
		if allyID ~= gaiaAllyID or haveZombies then

			local teamList = GetTeamList(allyID)

			local allyDataIndex = allyID +1
			allyData[allyDataIndex]						= {}
			allyData[allyDataIndex]["teams"]			= teamList
			allyData[allyDataIndex].exists				= #teamList > 0

			for _,teamID in pairs(teamList) do
				local myAllyID = select(6,GetTeamInfo(teamID))

				setTeamTable(teamID)
				Button["player"][teamID] = {}
			end

			setAllyData(allyID)
			local nbPlayers 							= #teamList
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
	WBadge = WBadge*sizeMultiplier

	if maxPlayers * WBadge + (20*sizeMultiplier) > widgetWidth then
		widgetWidth = (20*sizeMultiplier) + maxPlayers * WBadge
	end

	processScaling()
	updateButtons()
	UpdateAllies()

	local frame = GetGameFrame()
	lastPlayerChange = frame
end


function Reinit()
	maxPlayers = getMaxPlayers()
	
	if maxPlayers == 1 then
		WBadge = 18
	elseif maxPlayers == 2 or maxPlayers == 3 then
	    WBadge = 16
	else
		WBadge = 14
	end
	WBadge = WBadge*sizeMultiplier
	
	if maxPlayers * WBadge + (20*sizeMultiplier) > widgetWidth then 
		widgetWidth = (20*sizeMultiplier) + maxPlayers * WBadge
	end	
	if widgetPosX + widgetWidth > vsx then widgetPosX = vsx-widgetWidth end
	if widgetPosX < 0 then widgetPosX = 0 end
	
	for _, allyID in ipairs (Spring.GetAllyTeamList() ) do		
		if allyID ~= gaiaAllyID or haveZombies then
			local teamList = GetTeamList(allyID)
	
			if not allyData[allyID+1] then 
				allyData[allyID+1]		= {} 
			end
		
			allyData[allyID+1]["teams"]			= teamList
			allyData[allyID+1].exists			= #teamList > 0
		end
	end
	
	processScaling()
	UpdateAllTeams()
	UpdateAllies()
	updateButtons()
	makeSideImageList()
end


function processScaling()
	setDefaults()
	
	sizeMultiplier   = 0.45 + (vsx*vsy / 7000000)
	
	tH				= math.floor(tH * sizeMultiplier)
	widgetWidth		= math.floor(widgetWidth * sizeMultiplier)
	WBadge			= math.floor(WBadge * sizeMultiplier)
	cW				= math.floor(cW * sizeMultiplier)
	textsize		= math.floor(textsize * sizeMultiplier)
	borderPadding	= math.floor(borderPadding * sizeMultiplier)
end

---------------------------------------------------------------------------------------------------
--  Save / Load
---------------------------------------------------------------------------------------------------

function setDefaults()
	widgetWidth 			= 105	-- just the bars area
	right 					= true
	tH						= 32
	vsx,vsy 				= gl.GetViewSizes()
	widgetPosX, widgetPosY	= xRelPos*vsx, yRelPos*vsy
	borderPadding			= 4.5
	WBadge					= tH*0.5
	cW						= 88
	textsize				= 14
end

function widget:GetConfigData(data)      -- save
	--Echo("Saving config data")
	return {
		xRelPos            = xRelPos,
		yRelPos            = yRelPos,
		removeDeadOn 	   = Options.removeDead.On,
		resTextOn 	   	   = Options.resText.On,
		right			   = right,
	}
end


function widget:SetConfigData(data)      -- load
	if not loadSettings then return end
	
	--Echo("Loading config data...")
	Options = {}
	--Options["contrast"] = data.contrast or 0.6
	Options["resText"] = {}
	Options["resText"]["On"] = data.resTextOn or false
	Options["sticktotopbar"] = {}
	Options["sticktotopbar"]["On"] = data.sticktotopbar or true
	Options["removeDead"] = {}
	--Options["removeDead"]["On"] = data.removeDeadOn or false
	Options["removeDead"]["On"] = false
	xRelPos				= data.xRelPos or xRelPos
	yRelPos				= data.yRelPos or yRelPos

	vsx,vsy 			= gl.GetViewSizes()
	widgetPosX, widgetPosY	= xRelPos*vsx, yRelPos*vsy
	
end

---------------------------------------------------------------------------------------------------
--  Local
---------------------------------------------------------------------------------------------------

local function round(num, idp)
  local mult = 10^(idp or 0)
  return floor(num * mult + 0.5) / mult
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
	
	local offset = 0.05		-- texture offset, because else gaps could show
	local o = offset
	
	-- top left
	if py <= 0 or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, py+cs, 0)
	-- top right
	if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom left
	if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, sy-cs, 0)
	-- bottom right
	if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
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
		myFont:Print(label, widgetPosX + widgetWidth - (10*sizeMultiplier), widgetPosY + widgetHeight -vOffset+(tH*0.22),tH/2.66,'rs')
		myFont:End()
	end
end

local function DrawMText(numberM, vOffset)
	if Options["resText"]["On"] then
		local label = tconcat({"",formatRes(numberM)})
		myFont:Begin()
		myFont:SetTextColor({0.8,0.8,0.8,1})
		myFont:Print(label, widgetPosX + widgetWidth - (10*sizeMultiplier), widgetPosY + widgetHeight -vOffset+(tH*0.58),tH/2.66,'rs')
		myFont:End()
	end
end

local function DrawEBar(tE,tEp,vOffset)-- where tE = team Energy = [0,1]
	local dx = 15*sizeMultiplier
	local dy = tH*0.43
	local maxW = widgetWidth - (30*sizeMultiplier)
	local barheight = 1 + math.floor(tH * 0.08)

	if Options["resText"]["On"] then
		maxW = (widgetWidth/2) + (2*sizeMultiplier)
	end
	-- background
	glColor(0.8, 0.8, 0, 0.13)
	gl.Texture(images["barbg"])
	glTexRect(
		widgetPosX + dx,
		widgetPosY + widgetHeight -vOffset+dy,
		widgetPosX + dx+maxW,
		widgetPosY + widgetHeight -vOffset+dy-barheight
	)
	-- energy total
	glColor(1,1,0,0.7)
	gl.Texture(images["bar"])
	glTexRect(
		widgetPosX + dx,
		widgetPosY + widgetHeight -vOffset+dy,
		widgetPosX + dx + tE * maxW,
		widgetPosY + widgetHeight -vOffset+dy-barheight
	)
	-- energy production
	glColor(1,1,0,1)
	gl.Texture(images["bar"])
	glTexRect(
		widgetPosX + dx,
		widgetPosY + widgetHeight -vOffset+dy,
		widgetPosX + dx + tEp * maxW,
		widgetPosY + widgetHeight -vOffset+dy-barheight
	)

	if tE * maxW > 0.9 then
		local glowsize = 23*sizeMultiplier
		-- energy total
		glColor(1,1,0,0.032)
		gl.Texture(images["barglowcenter"])
		glTexRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight -vOffset+dy+glowsize,
			widgetPosX + dx + tE * maxW,
			widgetPosY + widgetHeight -vOffset+dy-barheight-glowsize
		)
		gl.Texture(images["barglowedge"])
		glTexRect(
			widgetPosX + dx-(glowsize*1.8),
			widgetPosY + widgetHeight -vOffset+dy+glowsize,
			widgetPosX + dx,
			widgetPosY + widgetHeight -vOffset+dy-barheight-glowsize
		)
		gl.Texture(images["barglowedge"])
		glTexRect(
			widgetPosX + dx + tE * maxW+(glowsize*1.8),
			widgetPosY + widgetHeight -vOffset+dy+glowsize,
			widgetPosX + dx + tE * maxW,
			widgetPosY + widgetHeight -vOffset+dy-barheight-glowsize
		)
		-- energy production
		glColor(1,1,0,0.032)
		gl.Texture(images["barglowcenter"])
		glTexRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight -vOffset+dy+glowsize,
			widgetPosX + dx + tEp * maxW,
			widgetPosY + widgetHeight -vOffset+dy-barheight-glowsize
		)
		gl.Texture(images["barglowedge"])
		glTexRect(
			widgetPosX + dx-(glowsize*1.8),
			widgetPosY + widgetHeight -vOffset+dy+glowsize,
			widgetPosX + dx,
			widgetPosY + widgetHeight -vOffset+dy-barheight-glowsize
		)
		gl.Texture(images["barglowedge"])
		glTexRect(
			widgetPosX + dx + tEp * maxW+(glowsize*1.8),
			widgetPosY + widgetHeight -vOffset+dy+glowsize,
			widgetPosX + dx + tEp * maxW,
			widgetPosY + widgetHeight -vOffset+dy-barheight-glowsize
		)
	end
	gl.Texture(false)
	glColor(1,1,1,1)
end


local function DrawMBar(tM,tMp,vOffset) -- where tM = team Metal = [0,1]
	local dx = 15*sizeMultiplier
	local dy = tH*0.67
	local maxW = widgetWidth - (30*sizeMultiplier)
	local barheight = 1 + math.floor(tH * 0.08)

	if Options["resText"]["On"] then
		maxW = (widgetWidth/2) + (2*sizeMultiplier)
	end
	-- background
	glColor(0.8, 0.8, 0.8, 0.13)
	gl.Texture(images["barbg"])
	glTexRect(
		widgetPosX + dx,
		widgetPosY + widgetHeight -vOffset+dy,
		widgetPosX + dx+maxW,
		widgetPosY + widgetHeight -vOffset+dy-barheight
	)
	-- metal total
	glColor(1,1,1,0.7)
	gl.Texture(images["bar"])
	glTexRect(
		widgetPosX + dx,
		widgetPosY + widgetHeight -vOffset+dy,
		widgetPosX + dx + tM * maxW,
		widgetPosY + widgetHeight -vOffset+dy-barheight
	)
	-- metal production
	glColor(1,1,1,1)
	gl.Texture(images["bar"])
	glTexRect(
		widgetPosX + dx,
		widgetPosY + widgetHeight -vOffset+dy,
		widgetPosX + dx + tMp * maxW,
		widgetPosY + widgetHeight -vOffset+dy-barheight
	)
	if tM * maxW > 0.9 then
		local glowsize = 26*sizeMultiplier
		-- metal total
		glColor(1,1,1,0.032)
		gl.Texture(images["barglowcenter"])
		glTexRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight -vOffset+dy+glowsize,
			widgetPosX + dx + tM * maxW,
			widgetPosY + widgetHeight -vOffset+dy-barheight-glowsize
		)
		gl.Texture(images["barglowedge"])
		glTexRect(
			widgetPosX + dx-(glowsize*1.8),
			widgetPosY + widgetHeight -vOffset+dy+glowsize,
			widgetPosX + dx,
			widgetPosY + widgetHeight -vOffset+dy-barheight-glowsize
		)
		gl.Texture(images["barglowedge"])
		glTexRect(
			widgetPosX + dx + tM * maxW+(glowsize*1.8),
			widgetPosY + widgetHeight -vOffset+dy+glowsize,
			widgetPosX + dx + tM * maxW,
			widgetPosY + widgetHeight -vOffset+dy-barheight-glowsize
		)
		-- metal production
		glColor(1,1,1,0.032)
		gl.Texture(images["barglowcenter"])
		glTexRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight -vOffset+dy+glowsize,
			widgetPosX + dx + tMp * maxW,
			widgetPosY + widgetHeight -vOffset+dy-barheight-glowsize
		)
		gl.Texture(images["barglowedge"])
		glTexRect(
			widgetPosX + dx-(glowsize*1.8),
			widgetPosY + widgetHeight -vOffset+dy+glowsize,
			widgetPosX + dx,
			widgetPosY + widgetHeight -vOffset+dy-barheight-glowsize
		)
		gl.Texture(images["barglowedge"])
		glTexRect(
			widgetPosX + dx + tMp * maxW+(glowsize*1.8),
			widgetPosY + widgetHeight -vOffset+dy+glowsize,
			widgetPosX + dx + tMp * maxW,
			widgetPosY + widgetHeight -vOffset+dy-barheight-glowsize
		)
	end
	gl.Texture(false)
	glColor(1,1,1)
end

local function DrawBackground(posY, allyID, sideimagesWidth)
	local y1 = widgetPosY - posY + widgetHeight
	local y2 = widgetPosY - posY + tH + widgetHeight
	local area = {widgetPosX, y1, widgetPosX+widgetWidth, y2 }

	glColor(0,0,0,ui_opacity)
	RectRound(widgetPosX+sideimagesWidth,y1, widgetPosX + widgetWidth, y2, 5*widgetScale)
	glColor(1,1,1,ui_opacity*0.04)
	RectRound(widgetPosX+sideimagesWidth+borderPadding,y1+borderPadding, widgetPosX + widgetWidth-borderPadding, y2-borderPadding, borderPadding*1.5)

	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(widgetPosX+sideimagesWidth,y1, widgetPosX + widgetWidth, y2, 'ecostats_'..allyID)
	end
	area[1] = area[1]+(widgetWidth/12)
	if WG['tooltip'] ~= nil and (tooltipAreas['ecostats_'..allyID] == nil or tooltipAreas['ecostats_'..allyID] ~= area[1]..'_'..area[2]..'_'..area[3]..'_'..area[4]) then
		WG['tooltip'].AddTooltip('ecostats_'..allyID, area, "Team metal/energy income\n(Lighter part of the bar is reclaim income)")
		tooltipAreas['ecostats_'..allyID] = area[1]..'_'..area[2]..'_'..area[3]..'_'..area[4]
	end
	glColor(1,1,1,1)
end

local function DrawOptionRibbon()
	local h = 45*sizeMultiplier
	local dx = 80*sizeMultiplier
	local x0
	local t = 12*sizeMultiplier
	
	if right then
		x0 = widgetPosX-dx
		x1 = x0 + dx + widgetWidth
	else
		x0 = widgetPosX
		x1 = x0 + dx + widgetWidth
	end
	local yPos = widgetPosY + widgetHeight - tH*(aliveAllyTeams)
	
	Options["resText"]["x1"] = x1 - (20*sizeMultiplier)
	Options["resText"]["x2"] = x1 - (20*sizeMultiplier) + t
	Options["resText"]["y2"] = yPos - (7*sizeMultiplier)
	Options["resText"]["y1"] = yPos - (7*sizeMultiplier) - t
	
	Options["sticktotopbar"]["x1"] = x1 - (20*sizeMultiplier)
	Options["sticktotopbar"]["x2"] = x1 - (20*sizeMultiplier) + t
	Options["sticktotopbar"]["y2"] = yPos - (27*sizeMultiplier)
	Options["sticktotopbar"]["y1"] = yPos - (27*sizeMultiplier) - t
	
	Options["removeDead"]["x1"] = x0 + (190*sizeMultiplier)
	Options["removeDead"]["x2"] = x0 + (190*sizeMultiplier) + t
	Options["removeDead"]["y2"] = yPos - (47*sizeMultiplier)
	Options["removeDead"]["y1"] = yPos - (47*sizeMultiplier) - t
	
	
	glColor(0,0,0,0.4)                              -- draws background rectangle
	--glRect(x0,widgetPosY, x1, widgetPosY -h)
	local padding = 2*sizeMultiplier
	RectRound(x0-padding, yPos -h-padding, x1+padding, yPos+padding, 6*sizeMultiplier)
	glColor(0.8,0.8,1,0.8)
	glText("Show resource text:", x0+(10*sizeMultiplier), Options["resText"]["y1"]+4,textsize)
	glText("Stick to Top Bar widget:", x0+(10*sizeMultiplier), Options["sticktotopbar"]["y1"]+4,textsize)
	--glText("Remove dead teams:", x0+10, Options["removeDead"]["y1"]+(textsize/2),textsize)
	glColor(1,1,1,1)
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
	if Options["sticktotopbar"]["On"] then
		glTexture(images["checkboxon"])
	else
		glTexture(images["checkboxoff"])
	end
	glTexRect(
		Options["sticktotopbar"]["x1"],
		Options["sticktotopbar"]["y1"],
		Options["sticktotopbar"]["x2"],
		Options["sticktotopbar"]["y2"]
	)
	--[[if Options["removeDead"]["On"] then
		glTexture(images["checkboxon"])
	else
		glTexture(images["checkboxoff"])
	end
	glTexRect(
		Options["removeDead"]["x1"],
		Options["removeDead"]["y1"],
		Options["removeDead"]["x2"],
		Options["removeDead"]["y2"]
	)]]--
	glTexture(false)
end

local function DrawBox(hOffset, vOffset,r,g,b)
	local w = tH*0.36
	local h = tH*0.36
	local dx = 0
	local dy = tH - (tH*0.5)
	glColor(r,g,b,0.4)
	RectRound(
		widgetPosX + hOffset + dx - w,
		widgetPosY + widgetHeight - vOffset + dy,
		widgetPosX + hOffset + dx,
		widgetPosY + widgetHeight - vOffset + dy + h,
		h*0.2
	)
	glColor(1,1,1,1)
end


local function DrawSideImage(sideImage, hOffset, vOffset, r, g, b, a, small, mouseOn,t,isDead,isZombie,tID)
	local w
	local h
	local dx
	local dy

	if small then
		w = tH*0.36
		h = tH*0.36
		dx = 0-(tH*0.06)
		dy = tH - (tH*0.43)
	else
		w = tH*0.46
		h = tH*0.46
		dx = 0
		dy = tH - h
	end

	if not inSpecMode then dx = dx -(10*sizeMultiplier) end

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
	local area = {
		widgetPosX + hOffset + dx - w,
		widgetPosY + widgetHeight - vOffset + dy,
		widgetPosX + hOffset + dx,
		widgetPosY + widgetHeight - vOffset + dy + h,
	}
	if enableStartposbuttons then
		Button["player"][tID]["x1"] = area[1]
		Button["player"][tID]["y1"] = area[2]
		Button["player"][tID]["x2"] = area[3]
		Button["player"][tID]["y2"] = area[4]
		Button["player"][tID]["pID"] = tID
	end
	if WG['tooltip'] then
		WG['tooltip'].AddTooltip('ecostats_team_'..tID, area, teamData[tID]["leaderName"])
	end
	glTexture(sideImage)
	glTexRect(area[1],area[2],area[3],area[4])
	glTexture(false)
	glColor(1,1,1,1)
end


function DrawSideImages()
	
	-- do dynamic stuff without display list
	local t = GetGameSeconds()
	
	for _, data in pairs(allyData) do
		local aID = data.aID
		local drawpos = data.drawpos
		if data.exists and drawpos and (aID == myAllyID or inSpecMode) and (aID ~= gaiaAllyID or haveZombies) and data["isAlive"] then

			local posy = tH*(drawpos) + (4*sizeMultiplier)
			local label, isAlive, hasCom

			local sideimagesWidth = 0
			for i, tID  in pairs (data.teams) do
				if tID ~= gaiaID or haveZombies then
					sideimagesWidth = -(WBadge*(i))-(WBadge*0.3)
				end
			end

			if type(data["tE"]) == "number" and drawpos and #(data.teams) > 0 then
				DrawBackground(posy-(4*sizeMultiplier), aID, sideimagesWidth)
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
					local posx = -(WBadge*(i-1))+(WBadge*0.3)
					
					local isZombie = haveZombies and tID == gaiaID
					sideImg = images[side] or images["default"]
					if isZombie then sideImg = images["zombie"] end
					
					hasCom = tData.hasCom
									
					if GetGameSeconds() > 0 then
						if not tData.isDead then
							alpha = tData.active and 1 or 0.3
							DrawSideImage(sideImg,posx,posy+(tH*0.125), r, g, b,alpha,not hasCom,Button["player"][tID]["mouse"],t, false,isZombie,tID)
						else
							alpha = 0.8
							DrawSideImage(images["dead"],posx,posy+(tH*0.125), r, g, b,alpha,true,Button["player"][tID]["mouse"],t, true,isZombie,tID) --dead, big icon
						end
					else
						DrawBox(posx, posy, r, g, b)
					end
				end
			end
		end
	end
end

local avgData = {}
local function drawListStandard()
	local maxMetal = 0
	local maxEnergy = 0
	
	if not gamestarted then updateButtons() end

	for _, data in ipairs(allyData) do
		local aID = data.aID

		if data.exists and type(data["tE"]) == "number" and isTeamReal(aID) and (aID == myAllyID or inSpecMode) and (aID ~= gaiaAllyID or haveZombies) then

			if avgData[aID] == nil then
				avgData[aID] = {}
				avgData[aID]["tE"] = data["tE"]
				avgData[aID]["tEr"] = data["tEr"]
				avgData[aID]["tM"] = data["tM"]
				avgData[aID]["tMr"] = data["tMr"]
			else
				avgData[aID]["tE"] = avgData[aID]["tE"] + ((data["tE"] - avgData[aID]["tE"])/avgFrames)
				avgData[aID]["tEr"] = avgData[aID]["tEr"] + ((data["tEr"] - avgData[aID]["tEr"])/avgFrames)
				avgData[aID]["tM"] = avgData[aID]["tM"] + ((data["tM"] - avgData[aID]["tM"])/avgFrames)
				avgData[aID]["tMr"] = avgData[aID]["tMr"] + ((data["tMr"] - avgData[aID]["tMr"])/avgFrames)
			end
			if avgData[aID]["tM"] and avgData[aID]["tM"] > maxMetal then
				maxMetal = avgData[aID]["tM"]
			end
			if avgData[aID]["tE"] and avgData[aID]["tE"] > maxEnergy then
				maxEnergy = avgData[aID]["tE"]
			end
		end
	end

	for _, data in ipairs(allyData) do
		local aID = data.aID
		if aID ~= nil then
			local drawpos = data.drawpos
			
			if data.exists and type(data["tE"]) == "number" and drawpos and #(data.teams) > 0 and (aID == myAllyID or inSpecMode) and (aID ~= gaiaAllyID or haveZombies) then
				
				if not data["isAlive"] then
					data["isAlive"] = isTeamAlive(aID)
				end
				
				local posy = tH*(drawpos)
				
				--if data["isAlive"] then DrawBackground(posy, aID) end
				
				local t = GetGameSeconds()
				if data["isAlive"] and t > 0 and gamestarted and not gameover then
					DrawEBar(avgData[aID]["tE"]/maxEnergy,(avgData[aID]["tE"]-avgData[aID]["tEr"])/maxEnergy,posy-1)
					DrawEText(avgData[aID]["tE"],posy)
				end
				if data["isAlive"] and t > 5 and not gameover then
					DrawMBar(avgData[aID]["tM"]/maxMetal,(avgData[aID]["tM"]-avgData[aID]["tMr"])/maxMetal,posy+2)
					DrawMText(avgData[aID]["tM"],posy)
				end
			end
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
	if not inSpecMode then
		setAllyData(myAllyID) 
	else
		for _, data in ipairs (allyData) do
			setAllyData(data.aID)
		end
	end
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


local reclaimerUnitDefs = {}
for udefID,def in ipairs(UnitDefs) do
	if def.isBuilder and not def.isFactory then
		reclaimerUnitDefs[udefID] = {def.metalMake,def.energyMake}
	end
end

function setReclaimerUnits()
	reclaimerUnits = {}
	local teamList = GetTeamList()
	for _, tID in pairs (teamList) do
		reclaimerUnits[tID] = {}
	end
	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local uDefID = Spring.GetUnitDefID(unitID)
		if reclaimerUnitDefs[uDefID] then
			local unitTeam = Spring.GetUnitTeam(unitID)
			reclaimerUnits[unitTeam][unitID] = uDefID
		end
	end
end

function widget:UnitCreated(uID, uDefID, uTeam, builderID)
	if inSpecMode and myFullview and reclaimerUnitDefs[uDefID] then
		if not reclaimerUnits[uTeam] then
			reclaimerUnits[uTeam] = {}
		end
		reclaimerUnits[uTeam][uID] = uDefID
	end
end

function widget:UnitDestroyed(uID, uDefID, uTeam)
	if inSpecMode and myFullview and reclaimerUnitDefs[uDefID] and reclaimerUnits[uTeam] then
		reclaimerUnits[uTeam][uID] = nil
	end
end

function widget:UnitGiven(uID, uDefID, uTeamNew, uTeam)
	if inSpecMode and myFullview and reclaimerUnitDefs[uDefID] then
		if reclaimerUnits[uTeam] then
			reclaimerUnits[uTeam][uID] = nil
			if not reclaimerUnits[uTeamNew] then
				reclaimerUnits[uTeamNew] = {}
			end
			reclaimerUnits[uTeamNew][uID] = uDefID
		end
	end
end


function getTeamProduction(teamID)
	local totalEnergyReclaim = 0
	local totalMetalReclaim = 0
	if inSpecMode and reclaimerUnits[teamID] ~= nil  then
		local teamUnits = reclaimerUnits[teamID]
		for unitID, unitDefID in pairs(teamUnits) do
			local metalMake,metalUse,energyMake,energyUse = Spring.GetUnitResources(unitID)
			if metalMake ~= nil then
				if metalMake > 0 then
					totalMetalReclaim = totalMetalReclaim + (metalMake-reclaimerUnitDefs[unitDefID][1])
				end
				if energyMake > 0 then
					totalEnergyReclaim = totalEnergyReclaim + (energyMake-reclaimerUnitDefs[unitDefID][2])
				end
			end
		end
	end
	return totalEnergyReclaim, totalMetalReclaim
end


function setTeamTable(teamID)
	
	local side, aID, isDead, commanderAlive, minc, mrecl, einc, erecl, x, y, leaderName, leaderID, active, spectator
	
	_,leaderID,isDead,isAI,side,aID,_,_ 		= GetTeamInfo(teamID)
	leaderName,active,spectator,_,_,_,_,_,_		= GetPlayerInfo(leaderID)
		
	if teamID == gaiaID then
		if haveZombies then 
			leaderName = "(Zombie)"
		else
			leaderName = "(Gaia)"
		end
	end
	
	local tred, tgreen, tblue = GetTeamColor(teamID)
	local luminance  = (tred * 0.299) + (tgreen * 0.587) + (tblue * 0.114)
	if (luminance < 0.2) then
		tred = tred + 0.25
		tgreen = tgreen + 0.25
		tblue = tblue + 0.25
	end
	
	_,_,_,minc 					= GetTeamResources(teamID,"metal")
	_,_,_,einc 					= GetTeamResources(teamID,"energy")
	erecl,mrecl					= getTeamProduction(teamID)
	x,_,y 						= Spring.GetTeamStartPosition(teamID)
	commanderAlive 				= checkCommander(teamID)
	if Game.gameShortName == "EvoRTS" then side = "outer_colonies" end
	
	local startUnitDefID = Spring.GetTeamRulesParam(teamID, 'startUnit')
	local cp = ((startUnitDefID and UnitDefs[startUnitDefID]) and UnitDefs[startUnitDefID].customParams) or nil
	if cp and cp.side then side = cp.side end
		
	-- code from ecostats widget
	if Spring.GetTeamRulesParam(teamID, 'startUnit') then
		local startunit = Spring.GetTeamRulesParam(teamID, 'startUnit')
		if startunit == armcomDefID then 
			teamside = "arm"
		else
			teamside = "core"
		end
	else
		_,_,_,_,teamside = Spring.GetTeamInfo(teamID)
	end
	side = teamside
	
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
	teamData[teamID]["mrecl"]			= minc
	teamData[teamID]["einc"] 			= einc
	teamData[teamID]["erecl"] 			= erecl
	teamData[teamID]["leaderID"]		= leaderID
	teamData[teamID]["leaderName"]		= leaderName
	teamData[teamID]["active"]			= active
	teamData[teamID]["spectator"]		= spectator
	teamData[teamID]["isAI"]			= isAI

end

function setAllyData(allyID)
	
	if not allyID or (allyID == gaiaAllyID and not haveZombies) then return end
	local index = allyID + 1
	
	if not allyData[index] then
		allyData[index] = {}
		local teamList = GetTeamList(allyID)
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
	allyData[index]["tEr"] 				= getTeamSum(index,"erecl")
	allyData[index]["tM"] 				= getTeamSum(index,"minc")
	allyData[index]["tMr"] 				= getTeamSum(index,"mrecl")
	allyData[index]["isAlive"]			= isTeamAlive(allyID)
	allyData[index]["validPlayers"]		= getNbPlacedPositions(allyID)
	allyData[index]["x"]				= getTeamSum(index,"startx")
	allyData[index]["y"]				= getTeamSum(index,"starty")
	allyData[index]["leader"]			= teamData[team1]["leaderName"] or "N/A"
	allyData[index]["aID"]				= allyID
	allyData[index]["exists"]			= #teamList > 0
	
	if not allyData[index]["isAlive"] and Options["removeDead"]["On"] then
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

	for _,tID in ipairs (GetTeamList(allyID)) do
		_,leaderID,isDead			= GetTeamInfo(tID)
		unitCount					= GetTeamUnitCount(tID)
		leaderName,active,spectator	= GetPlayerInfo(leaderID)
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

function getNbPlacedPositions(teamID)
	local nbPlayers = 0
	local startx, starty, active, leaderID, leaderName, isDead
	
	for _,pID in ipairs (GetTeamList(teamID)) do
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
		leaderName,active,spectator	= GetPlayerInfo(leaderID)				
		
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
		isDead = select(3,GetTeamInfo(teamID))
		teamData[teamID]["isDead"] = isDead
	end
end

function setPlayerResources()
	for teamID,data in pairs(teamData) do
		data.minc = select(4,GetTeamResources(teamID,"metal")) or 0
		data.einc = select(4,GetTeamResources(teamID,"energy")) or 0
		data.erecl,data.mrecl = getTeamProduction(teamID)
	end
end

---------------------------------------------------------------------------------------------------
--  User interface
---------------------------------------------------------------------------------------------------

function IsOnButton(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	if BLcornerX == nil then return false end
	-- check if the mouse is in a rectangle
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
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
	
	if Options["sticktotopbar"]["On"] and WG['topbar'] ~= nil then
		local topbarArea = WG['topbar'].GetPosition()
		widgetPosX = topbarArea[3] - widgetWidth
		widgetPosY = topbarArea[6] - widgetHeight
	end
	
	widgetRight = widgetPosX + widgetWidth
	if widgetPosX + widgetWidth/2 > vsx/2 then
		right = true
	else
		right = false
	end
		
	local drawpos = 0
	aliveAllyTeams = 0
	for _, data in ipairs(allyData) do
		local allyID = data.aID
		if isTeamReal(allyID) and (allyID == GetMyAllyTeamID() or inSpecMode) and data["isAlive"] then
			aliveAllyTeams = aliveAllyTeams + 1
			drawpos = drawpos + 1
		end
		data["drawpos"] = drawpos
	end
end

---------------------------------------------------------------------------------------------------
--  Call-ins
---------------------------------------------------------------------------------------------------

function widget:PlayerChanged(playerID)
	if not myFullview then return end

	local frame = GetGameFrame()
	lastPlayerChange = frame
	if not (Spring.GetSpectatingState() or isReplay) then
		if inSpecMode then Spring.Echo("Ecostats: widget now in active player mode.") end
		inSpecMode = false
		UpdateAllies()
	else
		if not inSpecMode then Spring.Echo("Ecostats: widget now in spectator mode.") end
		inSpecMode = true
		setReclaimerUnits()
		Reinit()
	end
	makeStandardList()
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
	--reclaimerUnits[teamID] = nil
	
	if not (Spring.GetSpectatingState() or isReplay) then
		if inSpecMode then Spring.Echo("Ecostats: widget now in active player mode.") end
		inSpecMode = false
		UpdateAllies()
		UpdateAllTeams()
	else
		if not inSpecMode then Spring.Echo("Ecostats: widget now in spectator mode.") end
		inSpecMode = true
		UpdateAllTeams()
		Reinit()
	end	
end

function widget:MapDrawCmd(playerID, cmdType, px, py, pz, labeltext)
	if not gamestarted then 
		UpdateAllies() 
		makeStandardList()
	end
end

function widget:TweakMouseMove(x,y,dx,dy,button)
	if pressedToMove ~= nil then
		if moveStartX == nil then                                                      -- move widget on y axis
			moveStartX = x - widgetPosX
		end
		if moveStartY == nil then                                                      -- move widget on y axis
			moveStartY = y - widgetPosY
		end
		xRelPos = xRelPos + (dx/vsx)
		yRelPos = yRelPos + (dy/vsy)
		if xRelPos < 0 then xRelPos = 0 end
		if yRelPos < 0 then yRelPos = 0 end
		if xRelPos > 1 then xRelPos = 1 end
		if yRelPos > 1 then yRelPos = 1 end
		
		widgetPosX, widgetPosY = xRelPos * vsx, yRelPos * vsy
		
		if widgetPosX < 0 then widgetPosX = 0 end
		if widgetPosY < 0 then yRelPos = 0 end
		if widgetPosX > vsx-widgetWidth then widgetPosY = vsx-widgetWidth end
		if widgetPosY > vsy-widgetHeight then widgetPosY = vsy-widgetHeight end
	
		updateButtons()
		makeStandardList()
		makeSideImageList()
	end
end

function widget:TweakMousePress(x, y, button)
	if button == 2 or button == 3 then
		if Options["sticktotopbar"]["On"] == false and IsOnButton(x, y, widgetPosX, widgetPosY, widgetPosX + widgetWidth, widgetPosY+widgetHeight) then
			pressedToMove = true
			return true
		end
	elseif button == 1 then
		local x0, x1
		
		if right then
			x0 = widgetPosX-(200*sizeMultiplier)
		else
			x0 = widgetPosX
		end
		x1 = x0 + (200*sizeMultiplier) + widgetWidth
		if IsOnButton(x, y, Options["resText"]["x1"],Options["resText"]["y1"],Options["resText"]["x2"],Options["resText"]["y2"]) then
			Options["resText"]["On"] = not Options["resText"]["On"]	
			return true
		elseif IsOnButton(x, y, Options["sticktotopbar"]["x1"],Options["sticktotopbar"]["y1"],Options["sticktotopbar"]["x2"],Options["sticktotopbar"]["y2"]) then
			Options["sticktotopbar"]["On"] = not Options["sticktotopbar"]["On"]	
			return true
		elseif IsOnButton(x, y, widgetPosX, widgetPosY, widgetPosX + widgetWidth, widgetPosY + widgetHeight) or 
		IsOnButton(x, y, x0, widgetPosY - (300*sizeMultiplier), x1, widgetPosY) 
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


function widget:MousePress(x, y, button)
	if not inSpecMode or not myFullview then return end

	if button == 1 then	
		
		for name, buttonType in pairs(Button) do
			if name == "player" then
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
	
		return false
	else
		return false
	end
end

function widget:MouseRelease(x,y,button)
	if button == 2 or button == 3 then
		pressedToMove = nil                                              -- ends move action
	end
end

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx,vsy = gl.GetViewSizes()
	widgetPosX, widgetPosY = xRelPos * vsx, yRelPos * vsy
	widgetScale = (1 + (vsx*vsy / 7500000))		-- only used for rounded corners atm
	Reinit()
end

function widget:GameFrame(frameNum)
	if not inSpecMode or not myFullview then return end
	
	if frameNum == 15 then
		UpdateAllTeams()
	end

	if frameNum - lastPlayerChange == 40  then
		checkDeadTeams()
		UpdateAllies()
		makeSideImageList()
	elseif frameNum%80 == 5 then
		makeSideImageList()
	end
	if frameNum%10 == 1 then
		updateButtons()
		setPlayerResources()
		UpdateAllies()
		makeStandardList()
	end
	
	if not gamestarted and frameNum > 0 then gamestarted = true end
end


---------------------------------------------------------------------------------------------------
--  Draw
---------------------------------------------------------------------------------------------------

function makeStandardList()
	if not inSpecMode then return end
	
	if (drawList) then gl.DeleteList(drawList) end
	drawList = gl.CreateList(drawListStandard)
end
function makeSideImageList()
	if not inSpecMode then return end
	
	if (sideImageList) then gl.DeleteList(sideImageList) end
	sideImageList = gl.CreateList(DrawSideImages)
end

function widget:TweakDrawScreen()
	if not inSpecMode then return end
	
	DrawOptionRibbon()
	updateButtons()
	makeStandardList()
end

local uiOpacitySec = 0.5
function widget:Update(dt)

	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec>0.5 then
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
			Reinit()
		end
	end
	if myFullview ~= select(2,Spring.GetSpectatingState()) then
		myFullview = select(2,Spring.GetSpectatingState())
		if myFullView then
			Reinit()
		else
			removeGuiShaderRects()
		end
	end
	if myFullview and not singleTeams and WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors() then
		if myTeamID ~= Spring.GetMyTeamID() then
			UpdateAllTeams()
			makeSideImageList()
		end
	end
end

function widget:DrawScreen()
	if not inSpecMode or not myFullview then return end
	
	if Spring.IsGUIHidden() or (not inSpecMode) then return end
	
	if not drawList then makeStandardList() end
	if not sideImageList then makeSideImageList() end
	
	gl.PushMatrix()
	gl.CallList(sideImageList)
	gl.CallList(drawList)
	gl.PopMatrix()
end


-- end
