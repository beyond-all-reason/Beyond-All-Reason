
function widget:GetInfo()
	return {
		name      = "Initial Queue",
		desc      = "Allows you to queue buildings before game start",
		author    = "Niobium",
		version   = "1.6",
		date      = "7 April 2010",
		license   = "GNU GPL, v2 or later",
		layer     = -1, -- Puts it above minimap_startboxes with layer 0
		enabled   = true,
		handler   = true
	}
end
-- 12 jun 2012: "uDef.isMetalExtractor" was replaced by "uDef.extractsMetal > 0" to fix "metal" mode map switching (by [teh]decay, thx to vbs and Beherith)
-- 20 march 2013: added keyboard support with BA keybinds (Bluestone)
-- august 2013: send queue length to cmd_idle_players (BrainDamage)
-- june 2015: guishader + rounded corners + hover effect + widget scales with resolution + remembers queue after /luaui reload (Floris)


VFS.Include("unbaconfigs/buildoptions.lua")

for ct,name in pairs (armlevel1buildoptions) do
	armlevel1buildoptions[ct] = UnitDefNames[name].id
end

for ct,name in pairs (corlevel1buildoptions) do
	corlevel1buildoptions[ct] = UnitDefNames[name].id
end

local ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)

------------------------------------------------------------
-- Config
------------------------------------------------------------
-- Panel

local iconWidth = 50
local iconHeight = 50
local iconPadding = 2
local borderSize = 0
local maxCols = 5
local fontSize = 17
local margin = 6
local drawTooltip = true		-- drawBigTooltip = true... this needs to be true aswell
local drawBigTooltip = false

local borderPadding = 2.5

local hoverColor = {1,1,1,0.25}
local pushedColor = {1,0.1,0,0.33}
local clickColor = {0.66,1,0,0.25}
--local pressColor = {1,0,0,0.44}
local bgcorner = "LuaUI/Images/bgcorner.png"
local buttonhighlight = ":n:LuaUI/Images/button-highlight.dds"
local buttonpushed = ":n:LuaUI/Images/button-pushed.dds"
local customScale = 0.95
local oldUnitpics = false

-- Colors
local buildDistanceColor = {0.3, 1.0, 0.3, 0.6}
local buildLinesColor = {0.3, 1.0, 0.3, 0.6}
local borderNormalColor = {0.3, 1.0, 0.3, 0.5}
local borderClashColor = {0.7, 0.3, 0.3, 1.0}
local borderValidColor = {0.0, 1.0, 0.0, 1.0}
local borderInvalidColor = {1.0, 0.0, 0.0, 1.0}
local buildingQueuedAlpha = 0.5

local metalColor = '\255\196\196\255' -- Light blue
local energyColor = '\255\255\255\128' -- Light yellow
local buildColor = '\255\128\255\128' -- Light green
local whiteColor = '\255\255\255\255' -- White

local vsx, vsy = gl.GetViewSizes()
local widgetScale = 1	-- will adjust based on resolution

local GL_ONE                   = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA   = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA             = GL.SRC_ALPHA
local glBlending               = gl.Blending

-- Building ids
local ARMCOM = UnitDefNames["armcom"].id
local CORCOM = UnitDefNames["corcom"].id

local ARMMEX = UnitDefNames["armmex"].id
local CORMEX = UnitDefNames["cormex"].id
local ARMUWMEX = UnitDefNames["armuwmex"].id
local CORUWMEX = UnitDefNames["coruwmex"].id

local ARMSOLAR = UnitDefNames["armsolar"].id
local CORSOLAR = UnitDefNames["corsolar"].id
local ARMWIN = UnitDefNames["armwin"].id
local CORWIN = UnitDefNames["corwin"].id
local ARMTIDE = UnitDefNames["armtide"].id
local CORTIDE = UnitDefNames["cortide"].id

local ARMLLT = UnitDefNames["armllt"].id
local CORLLT = UnitDefNames["corllt"].id
local ARMRAD = UnitDefNames["armrad"].id
local CORRAD = UnitDefNames["corrad"].id
local ARMRL = UnitDefNames["armrl"].id
local CORRL = UnitDefNames["corrl"].id
local ARMTL = UnitDefNames["armtl"].id
local CORTL = UnitDefNames["cortl"].id
local ARMSONAR = UnitDefNames["armsonar"].id
local CORSONAR = UnitDefNames["corsonar"].id
local ARMFRT = UnitDefNames["armfrt"].id
local CORFRT = UnitDefNames["corfrt"].id

local ARMLAB = UnitDefNames["armlab"].id
local CORLAB = UnitDefNames["corlab"].id
local ARMVP = UnitDefNames["armvp"].id
local CORVP = UnitDefNames["corvp"].id
local ARMSY = UnitDefNames["armsy"].id
local CORSY = UnitDefNames["corsy"].id

-- these are not used for hotkeys but used for switch faction buildings

local ARMMSTOR = UnitDefNames["armmstor"].id
local CORMSTOR = UnitDefNames["cormstor"].id

local ARMESTOR = UnitDefNames["armestor"].id
local CORESTOR = UnitDefNames["corestor"].id

local ARMMAKR = UnitDefNames["armmakr"].id
local CORMAKR = UnitDefNames["cormakr"].id

local ARMEYES = UnitDefNames["armeyes"].id
local COREYES = UnitDefNames["coreyes"].id

local ARMDRAG = UnitDefNames["armdrag"].id
local CORDRAG = UnitDefNames["cordrag"].id

local ARMDL = UnitDefNames["armdl"].id
local CORDL = UnitDefNames["cordl"].id

local ARMAP = UnitDefNames["armap"].id
local CORAP = UnitDefNames["corap"].id


local ARMFRAD = UnitDefNames["armfrad"].id
local CORFRAD = UnitDefNames["corfrad"].id

local ARMUWMS = UnitDefNames["armuwms"].id
local CORUWMS = UnitDefNames["coruwms"].id

local ARMUWES = UnitDefNames["armuwes"].id
local CORUWES = UnitDefNames["coruwes"].id

local ARMFMKR = UnitDefNames["armfmkr"].id
local CORFMKR = UnitDefNames["corfmkr"].id

local ARMFDRAG = UnitDefNames["armfdrag"].id
local CORFDRAG = UnitDefNames["corfdrag"].id

local ARMPTL = UnitDefNames["armptl"].id
local CORPTL = UnitDefNames["corptl"].id

-- this info is used to switch buildings between factions
local armToCore = {}

armToCore[ARMMEX] = CORMEX
armToCore[ARMUWMEX] = CORUWMEX
armToCore[ARMSOLAR] = CORSOLAR
armToCore[ARMWIN] = CORWIN
armToCore[ARMTIDE] = CORTIDE
armToCore[ARMLLT] = CORLLT
armToCore[ARMRAD] = CORRAD
armToCore[ARMRL] = CORRL
armToCore[ARMTL] = CORTL
armToCore[ARMSONAR] = CORSONAR
armToCore[ARMFRT] = CORFRT
armToCore[ARMLAB] = CORLAB
armToCore[ARMVP] = CORVP
armToCore[ARMSY] = CORSY
armToCore[ARMMSTOR] = CORMSTOR
armToCore[ARMESTOR] = CORESTOR
armToCore[ARMMAKR] = CORMAKR
armToCore[ARMEYES] = COREYES
armToCore[ARMDRAG] = CORDRAG
armToCore[ARMDL] = CORDL
armToCore[ARMAP] = CORAP
armToCore[ARMFRAD] = CORFRAD
armToCore[ARMUWMS] = CORUWMS
armToCore[ARMUWES] = CORUWES
armToCore[ARMFMKR] = CORFMKR
armToCore[ARMFDRAG] = CORFDRAG
armToCore[ARMPTL] = CORPTL

function table_invert(t)
    local s={}
    for k,v in pairs(t) do
        s[v]=k
    end
    return s
end

local coreToArm = table_invert(armToCore)
------------------------------------------------------------
-- Globals
------------------------------------------------------------
local sDefID -- Starting unit def ID
local sDef -- UnitDefs[sDefID]

local selDefID = nil -- Currently selected def ID
local buildQueue = {}
local buildNameToID = {}
local gameStarted = false 

local wWidth, wHeight = Spring.GetWindowGeometry()
local wl, wt = 50, 0.5*wHeight

local cellRows = {} -- {{bDefID, bDefID, ...}, ...}
local panelList = nil -- Display list for panel
local areDragging = false

local isMex = {} -- isMex[uDefID] = true / nil
local weaponRange = {} -- weaponRange[uDefID] = # / nil

local changeStartUnitRegex = '^\138(%d+)$'
local startUnitParamName = 'startUnit'

local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)

local totalTime

------------------------------------------------------------
-- Local functions
------------------------------------------------------------

function wrap(str, limit)
	limit = limit or 72
	local here = 1
	local buf = ""
	local t = {}
	str:gsub("(%s*)()(%S+)()",
		function(sp, st, word, fi)
			if fi-here > limit then
				--# Break the line
				here = st
				table.insert(t, buf)
				buf = word
			else
				buf = buf..sp..word  --# Append
			end
		end)
	--# Tack on any leftovers
	if(buf ~= "") then
		table.insert(t, buf)
	end
	return t
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
	gl.BeginEnd(GL.QUADS, RectQuad, px,py,sx,sy)
end

local function TraceDefID(mx, my)
	local overRow = cellRows[1 + math.floor((wt - my) / ((iconHeight + borderSize)*widgetScale))]
	if not overRow then return nil end
	return overRow[1 + math.floor((mx - wl) / ((iconWidth + borderSize)*widgetScale))]
end
local function GetBuildingDimensions(uDefID, facing)
	local bDef = UnitDefs[uDefID]
	if (facing % 2 == 1) then
		return 4 * bDef.zsize, 4 * bDef.xsize
	else
		return 4 * bDef.xsize, 4 * bDef.zsize
	end
end
local function DrawBuilding(buildData, borderColor, buildingAlpha, drawRanges)

	local bDefID, bx, by, bz, facing = buildData[1], buildData[2], buildData[3], buildData[4], buildData[5]
	local bw, bh = GetBuildingDimensions(bDefID, facing)

	gl.DepthTest(false)
	gl.Color(borderColor)

	gl.Shape(GL.LINE_LOOP, {{v={bx - bw, by, bz - bh}},
							{v={bx + bw, by, bz - bh}},
							{v={bx + bw, by, bz + bh}},
							{v={bx - bw, by, bz + bh}}})

	if drawRanges then

		if isMex[bDefID] then
			gl.Color(1.0, 0.3, 0.3, 0.7)
			gl.DrawGroundCircle(bx, by, bz, Game.extractorRadius, 50)
		end

		local wRange = weaponRange[bDefID]
		if wRange then
			gl.Color(1.0, 0.3, 0.3, 0.7)
			gl.DrawGroundCircle(bx, by, bz, wRange, 40)
		end
	end

	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)
	if buildingAlpha == 1 then gl.Lighting(true) end
	gl.Color(1.0, 1.0, 1.0, buildingAlpha)

	gl.PushMatrix()
		gl.Translate(bx, by, bz)
		gl.Rotate(90 * facing, 0, 1, 0)
		gl.UnitShape(bDefID, Spring.GetMyTeamID(), false, true, false)
	gl.PopMatrix()

	gl.Lighting(false)
	gl.DepthTest(false)
	gl.DepthMask(false)
end
local function DrawUnitDef(uDefID, uTeam, ux, uy, uz)

	gl.Color(1.0, 1.0, 1.0, 1.0)
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)
	gl.Lighting(true)

	gl.PushMatrix()
		gl.Translate(ux, uy, uz)
		gl.UnitShape(uDefID, uTeam, false, true, false)
	gl.PopMatrix()

	gl.Lighting(false)
	gl.DepthTest(false)
	gl.DepthMask(false)
end
local function DoBuildingsClash(buildData1, buildData2)

	local w1, h1 = GetBuildingDimensions(buildData1[1], buildData1[5])
	local w2, h2 = GetBuildingDimensions(buildData2[1], buildData2[5])

	return math.abs(buildData1[2] - buildData2[2]) < w1 + w2 and
	       math.abs(buildData1[4] - buildData2[4]) < h1 + h2
end
local function SetSelDefID(defID)

	selDefID = defID

	if (isMex[selDefID] ~= nil) ~= (Spring.GetMapDrawMode() == "metal") then
		Spring.SendCommands("ShowMetalMap")
	end
end
local function GetUnitCanCompleteQueue(uID)

	local uDefID = Spring.GetUnitDefID(uID)
	if uDefID == sDefID then
		return true
	end

	-- What can this unit build ?
	local uCanBuild = {}
	local uBuilds = UnitDefs[uDefID].buildOptions
	for i = 1, #uBuilds do
		uCanBuild[uBuilds[i]] = true
	end

	-- Can it build everything that was queued ?
	for i = 1, #buildQueue do
		if not uCanBuild[buildQueue[i][1]] then
			return false
		end
	end

	return true
end
local function GetQueueBuildTime()
	local t = 0
	for i = 1, #buildQueue do
		t = t + UnitDefs[buildQueue[i][1]].buildTime
	end
	return t / sDef.buildSpeed
end
local function GetQueueCosts()
	local mCost = 0
	local eCost = 0
	local bCost = 0
	for i = 1, #buildQueue do
		local uDef = UnitDefs[buildQueue[i][1]]
		mCost = mCost + uDef.metalCost
		eCost = eCost + uDef.energyCost
		bCost = bCost + uDef.buildTime
	end
	return mCost, eCost, bCost
end

------------------------------------------------------------
-- Initialize/shutdown
------------------------------------------------------------

function widget:Initialize()
	WG['initialqueue'] = {}
	WG['initialqueue'].getOldUnitIcons = function()
		return oldUnitpics
	end
	WG['initialqueue'].setOldUnitIcons = function(value)
		oldUnitpics = value
		local _, _, _, _, mySide = Spring.GetTeamInfo(myTeamID)
		InitializeFaction(UnitDefNames[Spring.GetSideData(mySide)].id)
	end
	if (Game.startPosType == 1) or			-- Don't run if start positions are random
	   (Spring.GetGameFrame() > 0) or		-- Don't run if game has already started
	   (amNewbie) or						-- Don't run if i'm a newbie
	   (Spring.GetSpectatingState()) then	-- Don't run if we are a spec
		widgetHandler:RemoveWidget(self)
		return
	end
	-- Get our starting unit
	local _, _, _, _, mySide = Spring.GetTeamInfo(myTeamID)
	if mySide == "" then -- Don't run unless we know what faction the player is
		widgetHandler:RemoveWidget(self)
		return
	else
		local startUnitName = Spring.GetSideData(mySide)
		sDefID = UnitDefNames[startUnitName].id
		InitializeFaction(sDefID)
		WG["faction_change"] = InitializeFaction
	end
	processGuishader()
end

function processGuishader()
	if (WG['guishader_api'] ~= nil) then
		local sBuilds = UnitDefs[sDefID].buildOptions
		if (Spring.GetModOptions().unba or "disabled") == "enabled" then
			if sDef.name == "armcom" then
				sBuilds = armlevel1buildoptions
			elseif sDef.name == "corcom" then
				sBuilds = corlevel1buildoptions
			end
		end
		local numCols = math.min(#sBuilds, maxCols)
		local numRows = math.ceil(#sBuilds / numCols)
		local bgheight = ((numRows*iconHeight)+margin)*widgetScale
		local bgwidth = ((numCols*iconWidth)+margin)*widgetScale
		WG['guishader_api'].InsertRect(wl-(margin*widgetScale), wt-bgheight, wl+bgwidth, wt+margin*widgetScale, 'initialqueue')
	end
end

function RectRound(px,py,sx,sy,cs)
	
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	gl.Rect(px+cs, py, sx-cs, sy)
	gl.Rect(sx-cs, py+cs, sx, sy-cs)
	gl.Rect(px+cs, py+cs, px, sy-cs)
	
	gl.Texture(bgcorner)
	--if py <= 0 or px <= 0 then gl.Texture(false) else gl.Texture(bgcorner) end
	DrawRect(px, py+cs, px+cs, py)		-- top left
	
	--if py <= 0 or sx >= vsx then gl.Texture(false) else gl.Texture(bgcorner) end
	DrawRect(sx, py+cs, sx-cs, py)		-- top right
	
	--if sy >= vsy or px <= 0 then gl.Texture(false) else gl.Texture(bgcorner) end
	DrawRect(px, sy-cs, px+cs, sy)		-- bottom left
	
	--if sy >= vsy or sx >= vsx then gl.Texture(false) else gl.Texture(bgcorner) end
	DrawRect(sx, sy-cs, sx-cs, sy)		-- bottom right
	
	gl.Texture(false)
end

function InitializeFaction(sDefID)
	sDef = UnitDefs[sDefID]
	-- Don't run if theres nothing to show
	local sBuilds = sDef.buildOptions
	if (Spring.GetModOptions().unba or "disabled") == "enabled" then
		if sDef.name == "armcom" then
			sBuilds = armlevel1buildoptions
		elseif sDef.name == "corcom" then
			sBuilds = corlevel1buildoptions
		end
	end
	if not sBuilds or (#sBuilds == 0) then
		return
	end


	-- Set up cells
	local numCols = math.min(#sBuilds, maxCols)
	local numRows = math.ceil(#sBuilds / numCols)
	for r = 1, numRows do
		cellRows[r] = {}
	end
	for b = 0, #sBuilds - 1 do
		cellRows[1 + math.floor(b / numCols)][1 + b % numCols] = sBuilds[b + 1]
	end
	
			
	-- Set up drawing function
	local drawFunc = function()

		gl.PushMatrix()
			gl.Translate(0, borderSize, 0)

			-- background
			local bgheight = ((#cellRows*iconHeight)+margin)
			local bgwidth = ((maxCols*iconWidth)+margin)
			gl.Color(0,0,0,ui_opacity)
			RectRound(-(margin), -bgheight, bgwidth, margin, ((iconWidth+iconPadding+iconPadding)/7))
			gl.Color(1,1,1,ui_opacity*0.04)
			RectRound(-(margin)+borderPadding, -bgheight+borderPadding, bgwidth-borderPadding, margin-borderPadding, ((iconWidth+iconPadding+iconPadding)/9))

			for r = 1, #cellRows do
				local cellRow = cellRows[r]
				
				gl.Translate(0, -((iconHeight - borderSize)), 0)
				gl.PushMatrix()
					
					for c = 1, #cellRow do

						gl.Color(0, 0, 0, 1)
						--gl.Rect(-borderSize, -borderSize, iconWidth + borderSize, iconHeight + borderSize)

						gl.Color(1, 1, 1, 1)

						if oldUnitpics and UnitDefs[cellRow[c]] ~= nil and VFS.FileExists('unitpics/'..UnitDefs[cellRow[c]].name..'.dds') then
							gl.Texture('unitpics/'..UnitDefs[cellRow[c]].name..'.dds')
						else
							gl.Texture('#' .. cellRow[c])
						end
						DrawRect(iconPadding, iconPadding, (iconWidth-iconPadding), (iconHeight-iconPadding))
						gl.Texture(false)

						gl.Translate((iconWidth + borderSize), 0, 0)
					end
				gl.PopMatrix()
			end

		gl.PopMatrix()
	end

	-- delete any pre-existing displaylist
	if panelList then
		gl.DeleteList(panelList)
	end

	panelList = gl.CreateList(drawFunc)

	for uDefID, uDef in pairs(UnitDefs) do

		if uDef.extractsMetal > 0 then
			isMex[uDefID] = true
		end

		if uDef.maxWeaponRange > 16 then
			weaponRange[uDefID] = uDef.maxWeaponRange
		end
	end
end

function widget:Shutdown()
	WG['initialqueue'] = nil
	if panelList then
		gl.DeleteList(panelList)
	end
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('initialqueue')
	end
	WG["faction_change"] = nil
end


------------------------------------------------------------
-- Config
------------------------------------------------------------

function widget:GetConfigData()
	savedTable = {}
	savedTable.oldUnitpics	= oldUnitpics
	if (Spring.GetSpectatingState()) then return end
	--local wWidth, wHeight = Spring.GetWindowGeometry()
	--return {wl / wWidth, wt / wHeight}
	local _, _, _, _, mySide = Spring.GetTeamInfo(Spring.GetMyTeamID())
	if Spring.GetGameSeconds() <= 0 and  mySide ~= "" then
		local startUnitName = Spring.GetSideData(mySide)
		local sDefID = UnitDefNames[startUnitName].id
		local sBuilds = UnitDefs[sDefID].buildOptions
		if (Spring.GetModOptions().unba or "disabled") == "enabled" then
			if UnitDefs[sDefID].name == "armcom" then
				sBuilds = armlevel1buildoptions
			elseif UnitDefs[sDefID].name == "corcom" then
				sBuilds = corlevel1buildoptions
			end
		end
		local numCols = math.min(#sBuilds, maxCols)
		local numRows = math.ceil(#sBuilds / numCols)
		local bgheight = ((numRows*iconHeight)+margin)*widgetScale
		local bgwidth = ((numCols*iconWidth)+margin)*widgetScale

		savedTable.buildQueue	= buildQueue
		savedTable.wt			= wt
		savedTable.wl			= wl
		savedTable.bgheight		= bgheight
		savedTable.bgwidth		= bgwidth
		savedTable.gameid		= Game.gameID
	end
	return savedTable
end
function widget:SetConfigData(data)
	--if (Spring.GetSpectatingState()) then return end
	--local wWidth, wHeight = Spring.GetWindowGeometry()
	--wl = math.floor(wWidth * (data[1] or 0.40))
	--wt = math.floor(wHeight * (data[2] or 0.10))
	if data.oldUnitpics ~= nil then
		oldUnitpics = data.oldUnitpics
	end
	if data.wt ~= nil and data.wl ~= nil and data.bgwidth ~= nil and data.bgheight ~= nil then
		wt = data.wt
		wl = data.wl
		if wl < 0 then 
			wl = 0
		end
		if wl > vsx+data.bgwidth then
			wl = vsx+data.bgwidth
		end
		if wt < data.bgheight then
			wt = data.bgwidth
		end
		if wt > vsy then 
			wt = vsy
		end
	end
	if Spring.GetGameSeconds() <= 0 and data.buildQueue and data.gameId and data.gameId == Game.gameID then
		buildQueue = data.buildQueue
	end
end


------------------------------------------------------------
-- Drawing
------------------------------------------------------------
--local queueTimeFormat = whiteColor .. 'Queued: ' .. buildColor .. '%.1f sec ' .. whiteColor .. '[' .. metalColor .. '%d m' .. whiteColor .. ', ' .. energyColor .. '%d e' .. whiteColor .. ']'
local queueTimeFormat = whiteColor .. 'Queued ' .. metalColor .. '%dm ' .. energyColor .. '%de ' .. buildColor .. '%.1f sec'
--local queueTimeFormat = metalColor .. '%dm ' .. whiteColor .. '/ ' .. energyColor .. '%de ' .. whiteColor .. '/ ' .. buildColor .. '%.1f sec'


-- "Queued 23.9 seconds (820m / 2012e)" (I think this one is the best. Time first emphasises point and goodness of widget)
	-- Also, it is written like english and reads well, none of this colon stuff or figures stacked together




function widget:DrawScreen()
	gl.PushMatrix()
		gl.Translate(wl, wt, 0)
		gl.Scale(widgetScale,widgetScale,widgetScale)
		gl.CallList(panelList)
		gl.Scale(1/widgetScale,1/widgetScale,1/widgetScale)
		if #buildQueue > 0 then
			local mCost, eCost, bCost = GetQueueCosts()
			local buildTime = bCost / sDef.buildSpeed
			totalTime = buildTime
			gl.Text(string.format(queueTimeFormat, mCost, eCost, buildTime), 0, margin*widgetScale, fontSize*widgetScale, 'do')
		end
		
		-- draw hover
		local CurMouseState = {Spring.GetMouseState()} --{mx,my,m1,m2,m3}
		local row = 1 + math.floor((wt - CurMouseState[2]) / ((iconHeight + borderSize)*widgetScale))
		local col = 1 + math.floor((wl - CurMouseState[1]) / ((iconWidth + borderSize)*widgetScale))
		
		if TraceDefID(CurMouseState[1], CurMouseState[2]) then
			gl.Translate(-((iconWidth*widgetScale)*col), -((iconHeight*widgetScale)*row), 0)
			gl.Texture(buttonhighlight)
			gl.Color(hoverColor)
			DrawRect((iconPadding*widgetScale), (iconPadding*widgetScale), ((iconWidth-iconPadding)*widgetScale), ((iconHeight-iconPadding)*widgetScale))
			gl.Color(hoverColor[1],hoverColor[2],hoverColor[3],hoverColor[4]/1.5)
			glBlending(GL_SRC_ALPHA, GL_ONE)
			DrawRect((iconPadding*widgetScale), (iconPadding*widgetScale), ((iconWidth-iconPadding)*widgetScale), ((iconHeight-iconPadding)*widgetScale))
			glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
			if CurMouseState[3] then
				gl.Color(clickColor)
				DrawRect((iconPadding*widgetScale), (iconPadding*widgetScale), ((iconWidth-iconPadding)*widgetScale), ((iconHeight-iconPadding)*widgetScale))
				gl.Color(clickColor[1],clickColor[2],clickColor[3],clickColor[4]/1.5)
				glBlending(GL_SRC_ALPHA, GL_ONE)
				DrawRect((iconPadding*widgetScale), (iconPadding*widgetScale), ((iconWidth-iconPadding)*widgetScale), ((iconHeight-iconPadding)*widgetScale))
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
				lastClickedRow = row
				lastClickedCol = col
			end
			gl.Texture(false)
			gl.Translate(((iconWidth*widgetScale)*col), ((iconHeight*widgetScale)*row), 0)

			if drawTooltip and WG['tooltip'] ~= nil then
				local udefid = TraceDefID(CurMouseState[1], CurMouseState[2])
				local text = "\255\215\255\215"..UnitDefs[udefid].humanName.."\n\255\240\240\240"
				if drawBigTooltip and UnitDefs[udefid].customParams.description_long ~= nil then
					local lines = wrap(UnitDefs[udefid].customParams.description_long, 58)
					local description = ''
					local newline = ''
					for i, line in ipairs(lines) do
						description = description..newline..line
						newline = '\n'
					end
					text = text..description
				else
					text = text..UnitDefs[udefid].tooltip
				end
				WG['tooltip'].ShowTooltip('initialqueue', text)
			end
		end
		if selDefID ~= nil and lastClickedRow ~= nil and lastClickedCol ~= nil then
			local row, col = lastClickedRow, lastClickedCol
			gl.Translate(-((iconWidth*widgetScale)*col), -((iconHeight*widgetScale)*row), 0)
			gl.Texture(buttonpushed)
			gl.Color(pushedColor)
			DrawRect((iconPadding*widgetScale), (iconPadding*widgetScale), ((iconWidth-iconPadding)*widgetScale), ((iconHeight-iconPadding)*widgetScale))
			gl.Color(pushedColor[1],pushedColor[2],pushedColor[3],pushedColor[4]/1.5)
			glBlending(GL_SRC_ALPHA, GL_ONE)
			DrawRect((iconPadding*widgetScale), (iconPadding*widgetScale), ((iconWidth-iconPadding)*widgetScale), ((iconHeight-iconPadding)*widgetScale))
			glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
			gl.Texture(false)
			gl.Translate(((iconWidth*widgetScale)*col), ((iconHeight*widgetScale)*row), 0)
		end
	gl.PopMatrix()
end

function widget:DrawWorld()
	--don't draw anything once the game has started; after that engine can draw queues itself
	if gameStarted then return end

	-- Set up gl
	gl.LineWidth(1.49)

	-- We need data about currently selected building, for drawing clashes etc
	local selBuildData
	if selDefID then
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos then
			local bx, by, bz = Spring.Pos2BuildPos(selDefID, pos[1], pos[2], pos[3])
			local buildFacing = Spring.GetBuildFacing()
			selBuildData = {selDefID, bx, by, bz, buildFacing}
		end
	end

	local myTeamID = Spring.GetMyTeamID()
	local sx, sy, sz = Spring.GetTeamStartPosition(myTeamID) -- Returns -100, -100, -100 when none chosen
	local startChosen = (sx ~= -100)
	if startChosen then
		-- Correction for start positions in the air
		sy = Spring.GetGroundHeight(sx, sz)

		-- Draw the starting unit at start position
		DrawUnitDef(sDefID, myTeamID, sx, sy, sz)

		-- Draw start units build radius
		gl.Color(buildDistanceColor)
		gl.DrawGroundCircle(sx, sy, sz, sDef.buildDistance, 40)
    end

    -- Check for faction change
    for b = 1, #buildQueue do
        local buildData = buildQueue[b]
        local buildDataId = buildData[1]
        if sDef.id == ARMCOM then
            if coreToArm[buildDataId] ~= nil then
                buildData[1] = coreToArm[buildDataId]
                buildQueue[b] = buildData
            end
        elseif sDef.id == CORCOM then
            if armToCore[buildDataId] ~= nil then
                buildData[1] = armToCore[buildDataId]
                buildQueue[b] = buildData
            end
        end
    end

	-- Draw all the buildings
	local queueLineVerts = startChosen and {{v={sx, sy, sz}}} or {}
	for b = 1, #buildQueue do
		local buildData = buildQueue[b]

		if selBuildData and DoBuildingsClash(selBuildData, buildData) then
			DrawBuilding(buildData, borderClashColor, buildingQueuedAlpha)
		else
			DrawBuilding(buildData, borderNormalColor, buildingQueuedAlpha)
		end

		queueLineVerts[#queueLineVerts + 1] = {v={buildData[2], buildData[3], buildData[4]}}
	end

	-- Draw queue lines
	gl.Color(buildLinesColor)
	gl.LineStipple("springdefault")
		gl.Shape(GL.LINE_STRIP, queueLineVerts)
	gl.LineStipple(false)

	-- Draw selected building
	if selBuildData then
		if Spring.TestBuildOrder(selDefID, selBuildData[2], selBuildData[3], selBuildData[4], selBuildData[5]) ~= 0 then
			DrawBuilding(selBuildData, borderValidColor, 1.0, true)
		else
			DrawBuilding(selBuildData, borderInvalidColor, 1.0, true)
		end
	end

	-- Reset gl
	gl.Color(1.0, 1.0, 1.0, 1.0)
	gl.LineWidth(1.0)
end

------------------------------------------------------------
-- Game start
------------------------------------------------------------

local uiOpacitySec = 0
function widget:Update(dt)
	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec>0.5 then
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
		end
	end
end

function widget:GameFrame(n)

	if not gameStarted then
		gameStarted = true
	end

	-- Don't run if we are a spec
	local areSpec = Spring.GetSpectatingState()
	if areSpec then
		widgetHandler:RemoveWidget(self)
		return
	end
	
	-- Don't run if we didn't queue anything
	if (#buildQueue == 0) then
		widgetHandler:RemoveWidget(self)
		return
	end

	if (n < 2) then return end -- Give the unit frames 0 and 1 to spawn
	
	--inform gadget how long is our queue
	local buildTime = GetQueueBuildTime()
	Spring.SendCommands("luarules initialQueueTime " .. buildTime)
	
	if (n == 107) then
		--Spring.Echo("> Starting unit never spawned !")
		widgetHandler:RemoveWidget(self)
		return
	end
	

    local tasker
    -- Search for our starting unit
    local units = Spring.GetTeamUnits(Spring.GetMyTeamID())
    for u = 1, #units do
        local uID = units[u]
        if GetUnitCanCompleteQueue(uID) then --Spring.GetUnitDefID(uID) == sDefID then
            tasker = uID
            if Spring.GetUnitRulesParam(uID,"startingOwner") == Spring.GetMyPlayerID() then
                --we found our com even if cooping, assigning queue to this particular unit
                break
            end
        end
    end
    if tasker then
        --Spring.Echo("sending queue to unit")
        for b = 1, #buildQueue do
            local buildData = buildQueue[b]
            Spring.GiveOrderToUnit(tasker, -buildData[1], {buildData[2], buildData[3], buildData[4], buildData[5]}, {"shift"})
        end
        widgetHandler:RemoveWidget(self)
    end
end

------------------------------------------------------------
-- Mouse
------------------------------------------------------------
function widget:IsAbove(mx, my)
	return TraceDefID(mx, my)
end
local tooltipFormat = 'Build %s\n%s\n' .. metalColor .. '%d m ' .. whiteColor .. '/ ' .. energyColor .. '%d e ' .. whiteColor .. '/ ' .. buildColor .. '%.1f sec'
function widget:GetTooltip(mx, my)
	local bDefID = TraceDefID(mx, my)
	local bDef = UnitDefs[bDefID]
	return string.format(tooltipFormat, bDef.humanName, bDef.tooltip, bDef.metalCost, bDef.energyCost, bDef.buildTime / sDef.buildSpeed)
end

function SetBuildFacing()
	local wx,wy,_,_ = Spring.GetScreenGeometry()
	local _, pos = Spring.TraceScreenRay(wx/2, wy/2, true)
	if not pos then return end
	local x = pos[1]
	local z = pos[3]
	
    if math.abs(Game.mapSizeX - 2*x) > math.abs(Game.mapSizeZ - 2*z) then
      if (2*x>Game.mapSizeX) then
        facing=3
      else
        facing=1
      end
    else
      if (2*z>Game.mapSizeZ) then
        facing=2
      else
        facing=0
      end
    end
	Spring.SetBuildFacing(facing)
	
end

needBuildFacing = true

function widget:MousePress(mx, my, mButton)
	local tracedDefID = TraceDefID(mx, my)
	if tracedDefID then
		if mButton == 1 then
			if needBuildFacing then
				SetBuildFacing()
				needBuildFacing = false
			end
			SetSelDefID(tracedDefID)
			return true
		elseif mButton == 2 or mButton == 3 then
			areDragging = true
			return true
		end
	else
		if selDefID then
			if mButton == 1 then

				local mx, my = Spring.GetMouseState()
				local _, pos = Spring.TraceScreenRay(mx, my, true)
				if not pos then return end
				local bx, by, bz = Spring.Pos2BuildPos(selDefID, pos[1], pos[2], pos[3])
				local buildFacing = Spring.GetBuildFacing()

				if Spring.TestBuildOrder(selDefID, bx, by, bz, buildFacing) ~= 0 then

					local buildData = {selDefID, bx, by, bz, buildFacing}
					local _, _, meta, shift = Spring.GetModKeyState()
					if meta then
						table.insert(buildQueue, 1, buildData)

					elseif shift then

						local anyClashes = false
						for i = #buildQueue, 1, -1 do
							if DoBuildingsClash(buildData, buildQueue[i]) then
								anyClashes = true
								table.remove(buildQueue, i)
							end
						end

						if not anyClashes then
							buildQueue[#buildQueue + 1] = buildData
						end
					else
						buildQueue = {buildData}
					end

					if not shift then
						SetSelDefID(nil)
					end
				end

				return true

			elseif mButton == 3 then

				SetSelDefID(nil)
				return true
			end
		end
	end
end

function widget:MouseMove(mx, my, dx, dy, mButton)
	if areDragging then
		local sBuilds = UnitDefs[sDefID].buildOptions
		local numCols = math.min(#sBuilds, maxCols)
		local numRows = math.ceil(#sBuilds / numCols)
		local bgheight = ((numRows*iconHeight)+margin)*widgetScale
		local bgwidth = ((numCols*iconWidth)+margin)*widgetScale
		
		if wl + dx >= 0 and wl + bgwidth + dx - 1 <= vsx then 
			wl = wl + dx
		end
		if wt + dy >= bgheight and wt + bgheight + dy - 1 <= vsy+bgheight then 
			wt = wt + dy
		end
		if wl < 0 then 
			wl = 0
		end
		if wl > vsx-bgwidth then
			wl = vsx-bgwidth
		end
		if wt < bgheight then
			wt = bgheight
		end
		if wt > vsy then 
			wt = vsy
		end
		processGuishader()
	end
end


function widget:MouseRelease(mx, my, mButton)
	areDragging = false
	local tracedDefID = TraceDefID(mx, my)
	if tracedDefID then
		if mButton == 1 then
		if needBuildFacing then
			SetBuildFacing()
			needBuildFacing = false
		end
			SetSelDefID(tracedDefID)
			return true
		end
	end
end

------------------------------------------------------------
-- Keyboard -- This will only work with BA!
------------------------------------------------------------
local ZKEY = 122
local XKEY = 120
local CKEY = 99
local VKEY = 118

function widget:KeyPress(key,mods,isrepeat)
	if sDef == UnitDefs[ARMCOM] then
		if key == ZKEY then
			if 		selDefID == ARMMEX then 	SetSelDefID(ARMUWMEX)
			elseif 	selDefID == ARMUWMEX then	SetSelDefID(ARMMEX)
			else								SetSelDefID(ARMMEX)
			end		
		elseif key == XKEY then
			if 		selDefID == RMSOLAR then	SetSelDefID(ARMWIN)
			elseif 	selDefID == ARMWIN then		SetSelDefID(ARMTIDE)
			elseif 	selDefID == ARMTIDE then	SetSelDefID(ARMSOLAR)
			else 								SetSelDefID(ARMSOLAR)
			end
		elseif key == CKEY then
			if		selDefID == ARMLLT then		SetSelDefID(ARMRAD)
			elseif 	selDefID == ARMRAD then		SetSelDefID(ARMRL)
			elseif 	selDefID == ARMRL then 		SetSelDefID(ARMTL)
			elseif 	selDefID == ARMTL then 		SetSelDefID(ARMSONAR)
			elseif 	selDefID == ARMSONAR then	SetSelDefID(ARMFRT)
			elseif 	selDefID == ARMFRT then		SetSelDefID(ARMLLT)
			else 								SetSelDefID(ARMLLT)
			end
		elseif key == VKEY then
			if		selDefID == ARMLAB then		SetSelDefID(ARMVP)
			elseif 	selDefID == ARMVP then		SetSelDefID(ARMSY)
			elseif 	selDefID == ARMSY then		SetSelDefID(ARMLAB)
			else 								SetSelDefID(ARMLAB)
			end			
		end	
	elseif sDef == UnitDefs[CORCOM] then
		if key == ZKEY then
			if 		selDefID == CORMEX then 	SetSelDefID(CORUWMEX)
			elseif 	selDefID == CORUWMEX then	SetSelDefID(CORMEX)
			else								SetSelDefID(CORMEX)
			end		
		elseif key == XKEY then
			if 		selDefID == CORSOLAR then	SetSelDefID(CORWIN)
			elseif 	selDefID == CORWIN then		SetSelDefID(CORTIDE)
			elseif 	selDefID == CORTIDE then	SetSelDefID(CORSOLAR)
			else 								SetSelDefID(CORSOLAR)
			end
		elseif key == CKEY then
			if		selDefID == CORLLT then		SetSelDefID(CORRAD)
			elseif 	selDefID == CORRAD then		SetSelDefID(CORRL)
			elseif 	selDefID == CORRL then 		SetSelDefID(CORTL)
			elseif 	selDefID == CORTL then 		SetSelDefID(CORSONAR)
			elseif 	selDefID == CORSONAR then	SetSelDefID(CORFRT)
			elseif 	selDefID == CORFRT then		SetSelDefID(CORLLT)
			else 								SetSelDefID(CORLLT)
			end
		elseif key == VKEY then
			if		selDefID == CORLAB then		SetSelDefID(CORVP)
			elseif 	selDefID == CORVP then		SetSelDefID(CORSY)
			elseif 	selDefID == CORSY then		SetSelDefID(CORLAB)
			else 								SetSelDefID(CORLAB)		
			end
		end	
	end
end

function widget:ViewResize(newX,newY)
	vsx, vsy = newX, newY
	widgetScale = (0.6 + (vsx*vsy / 4000000)) * customScale
	processGuishader()
	
	local sBuilds = UnitDefs[sDefID].buildOptions
	if (Spring.GetModOptions().unba or "disabled") == "enabled" then
		if sDef.name == "armcom" then
			sBuilds = armlevel1buildoptions
		elseif sDef.name == "corcom" then
			sBuilds = corlevel1buildoptions
		end
	end
	local numCols = math.min(#sBuilds, maxCols)
	local numRows = math.ceil(#sBuilds / numCols)
	local bgheight = ((numRows*iconHeight)+margin)*widgetScale
	local bgwidth = ((numCols*iconWidth)+margin)*widgetScale
	
	if wl < 0 then 
		wl = 0
	end
	if wl > vsx-bgwidth then
		wl = vsx-bgwidth
	end
	if wt < bgheight then
		wt = bgheight
	end
	if wt > vsy then 
		wt = vsy
	end
end

------------------------------------------------------------
-- Misc
------------------------------------------------------------
function widget:TextCommand(cmd)

	-- Facing commands are only handled by spring if we have a building selected, which isn't possible pre-game
	local m = cmd:match("^buildfacing (.+)$")
	if m then

		local oldFacing = Spring.GetBuildFacing()
		local newFacing
		if (m == "inc") then
			newFacing = (oldFacing + 1) % 4
		elseif (m == "dec") then
			newFacing = (oldFacing + 3) % 4
		else
			return false
		end

		Spring.SetBuildFacing(newFacing)
		Spring.Echo("Buildings set to face " .. ({"South", "East", "North", "West"})[1 + newFacing])
		return true
	end

	local buildName = cmd:match("^buildunit_([^%s]+)$")
	if buildName then
		local bDefID = buildNameToID[buildName]
		if bDefID then
			SetSelDefID(bDefID)
			return true
		end
	end
end
