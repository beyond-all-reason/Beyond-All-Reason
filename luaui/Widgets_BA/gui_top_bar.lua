function widget:GetInfo()
	return {
		name		= "Top Bar",
		desc		= "Shows Resources, wind speed, commander counter, and various options.",
		author	= "Floris",
		date		= "Feb, 2017",
		license	= "GNU GPL, v2 or later",
		layer		= 0,
		enabled   = true, --enabled by default
		handler   = true, --can use widgetHandler:x()
	}
end

local height = 38
local showConversionSlider = true
local bladeSpeedMultiplier = 0.25

local armcomDefID = UnitDefNames.armcom.id
local corcomDefID = UnitDefNames.corcom.id

local bgcorner							= ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"
local barbg									= ":n:"..LUAUI_DIRNAME.."Images/resbar.dds"
local barGlowCenterTexture	= LUAUI_DIRNAME.."Images/barglow-center.dds"
local barGlowEdgeTexture		= LUAUI_DIRNAME.."Images/barglow-edge.dds"
local bladesTexture					= ":c:"..LUAUI_DIRNAME.."Images/blades.png"
local poleTexture						= LUAUI_DIRNAME.."Images/pole.png"
local comTexture						= LUAUI_DIRNAME.."Images/comIcon.png"

local vsx, vsy = gl.GetViewSizes()
local widgetScale = (0.60 + (vsx*vsy / 5000000))
local xPos = vsx*0.28
local currentWind = 0

local glTranslate				= gl.Translate
local glColor						= gl.Color
local glPushMatrix			= gl.PushMatrix
local glPopMatrix				= gl.PopMatrix
local glTexture					= gl.Texture
local glRect						= gl.Rect
local glTexRect					= gl.TexRect
local glText						= gl.Text
local glGetTextWidth		= gl.GetTextWidth
local glRotate					= gl.Rotate
local glCreateList			= gl.CreateList
local glCallList				= gl.CallList
local glDeleteList			= gl.DeleteList

local spGetSpectatingState = Spring.GetSpectatingState
local spGetTeamResources = Spring.GetTeamResources
local spGetMyTeamID = Spring.GetMyTeamID
local sformat = string.format

local spec = spGetSpectatingState()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local myTeamID = Spring.GetMyTeamID()

local spWind		  			= Spring.GetWind
local minWind		  			= Game.windMin * 1.5 -- BA added extra wind income via gadget unit_windgenerators with an additional 50%
local maxWind		  			= Game.windMax * 1.5 -- BA added extra wind income via gadget unit_windgenerators with an additional 50%
local windRotation			= 0

local vsx, vsy					= gl.GetViewSizes()
local topbarArea = {}
local barContentArea = {}
local resbarArea = {'metal', 'energy'}
local shareIndicatorArea = {'metal', 'energy'}
local dlistResbar = {}
local energyconvArea = {}
local windArea = {}
local comsArea = {}

local allyComs				= 0
local enemyComs				= 0 -- if we are counting ourselves because we are a spec
local enemyComCount			= 0 -- if we are receiving a count from the gadget part (needs modoption on)
local prevEnemyComCount		= 0

function widget:ViewResize(n_vsx,n_vsy)
	vsx, vsy = gl.GetViewSizes()
	widgetScale = (0.60 + (vsx*vsy / 5000000))
	xPos = vsx*0.28
	init()
end

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


local function short(n,f)
	if (f == nil) then
		f = 0
	end
	if (n > 9999999) then
		return sformat("%."..f.."fm",n/1000000)
	elseif (n > 9999) then
		return sformat("%."..f.."fk",n/1000)
	else
		return sformat("%."..f.."f",n)
	end
end

local function updateComs()
	local area = comsArea
	local gameframe = Spring.GetGameFrame()
	
	dlistComs = glCreateList( function()
	
		-- background
		glColor(0,0,0,0.7)
		RectRound(area[1], area[2], area[3], area[4], 5.5*widgetScale)
		local bgpadding = 3*widgetScale
		glColor(1,1,1,0.03)
		RectRound(area[1]+bgpadding, area[2]+bgpadding, area[3]-bgpadding, area[4], 5*widgetScale)
		
		if (WG['guishader_api'] ~= nil) then
			WG['guishader_api'].InsertRect(area[1], area[2], area[3], area[4], 'topbar_coms')
		end
		
		-- Commander icon
		local sizeHalf = (height/2.75)*widgetScale
		if allyComs == 1 and (gameframe % 12 < 6) then
			glColor(1,0.6,0,0.6)
		else
			glColor(1,1,1,0.3)
		end
		glTexture(comTexture)
		glTexRect(area[1]+((area[3]-area[1])/2)-sizeHalf, area[2]+((area[4]-area[2])/2)-sizeHalf, area[1]+((area[3]-area[1])/2)+sizeHalf, area[2]+((area[4]-area[2])/2)+sizeHalf)
		glTexture(false)
		
		if gameframe > 0 then
			local fontsize = (height/2.85)*widgetScale
			glText('\255\255\000\000'..enemyComs, area[3]-(2.5*widgetScale), area[2]+(4.5*widgetScale), fontsize, 'or')
			
			fontSize = (height/2.15)*widgetScale
			glText("\255\000\255\000"..allyComs, area[1]+((area[3]-area[1])/2), area[2]+((area[4]-area[2])/2)-(fontSize/5), fontSize, 'oc') -- Wind speed text
		end
	end)
end

local function updateWind(currentWind)
	local area = windArea
		
	dlistWind = glCreateList( function()
		
		-- background
		glColor(0,0,0,0.7)
		RectRound(area[1], area[2], area[3], area[4], 5.5*widgetScale)
		local bgpadding = 3*widgetScale
		glColor(1,1,1,0.03)
		RectRound(area[1]+bgpadding, area[2]+bgpadding, area[3]-bgpadding, area[4], 5*widgetScale)
		
		if (WG['guishader_api'] ~= nil) then
			WG['guishader_api'].InsertRect(area[1], area[2], area[3], area[4], 'topbar_wind')
		end
		
		local fontsize = (height/3.5)*widgetScale
		glText("\255\133\133\133"..minWind, area[3]-(2.5*widgetScale), area[4]-(4.5*widgetScale)-(fontsize/2), fontsize, 'or')
		glText("\255\133\133\133"..maxWind, area[3]-(2.5*widgetScale), area[2]+(4.5*widgetScale), fontsize, 'or')
		
		local xPos =  area[1] 
		local yPos =  area[2] + ((area[4] - area[2])/3.5)
		local oorx = 10*widgetScale
		local oory = 13*widgetScale
		
		glPushMatrix()
			
			glTranslate(xPos, yPos, 0)
			glTranslate(12*widgetScale, (height-(36*widgetScale))/2, 0) -- Spacing of icon
			glPushMatrix() -- Blades
				glTranslate(0, 9*widgetScale, 0)
				
				glTranslate(oorx, oory, 0)
				glRotate(windRotation, 0, 0, 1)
				glTranslate(-oorx, -oory, 0)
				
				glColor(1,1,1,0.3)
				glTexture(bladesTexture)
				glTexRect(0, 0, 27*widgetScale, 28*widgetScale)
				glTexture(false)
			glPopMatrix()    
			
			local poleWidth = 6 * widgetScale
			local poleHeight = 14 * widgetScale
			x,y = 9*widgetScale, 2*widgetScale -- Pole
			glTexture(poleTexture)
			glTexRect(x, y, (7*widgetScale)+x, y+(18*widgetScale))
			glTexture(false)
		glPopMatrix()    
		
		fontSize = (height/2.66)*widgetScale
		glText("\255\255\255\255"..currentWind, area[1]+((area[3]-area[1])/2), area[2]+((area[4]-area[2])/2)-(fontSize/5), fontSize, 'oc') -- Wind speed text
	end)
end


local function updateResbar(res)
	local r = {spGetTeamResources(spGetMyTeamID(),res)} -- 1 = cur 2 = cap 3 = pull 4 = income 5 = expense 6 = share
	
	local area = resbarArea[res]
	
	if dlistResbar[res] ~= nil then
		glDeleteList(dlistResbar[res])
	end
	dlistResbar[res] = glCreateList( function()
		
		local barHeight = (height*widgetScale/10)
		local barHeighPadding = 6*widgetScale --((height/2) * widgetScale) - (barHeight/2)
		local barLeftPadding = 3 * widgetScale
		local barRightPadding = 6 * widgetScale
		local barArea = {area[1]+(height*widgetScale)+barLeftPadding, area[2]+barHeighPadding, area[3]-barRightPadding, area[2]+barHeight+barHeighPadding}
		local barWidth = barArea[3] - barArea[1]
		local shareSliderHeightAdd = barHeight / 4
		local shareSliderWidth = barHeight + shareSliderHeightAdd + shareSliderHeightAdd
		
		-- background
		glColor(0,0,0,0.7)
		RectRound(area[1], area[2], area[3], area[4], 5.5*widgetScale)
		local bgpadding = 3*widgetScale
		glColor(1,1,1,0.03)
		RectRound(area[1]+bgpadding, area[2]+bgpadding, area[3]-bgpadding, area[4], 5*widgetScale)
		
		if (WG['guishader_api'] ~= nil) then
			WG['guishader_api'].InsertRect(area[1], area[2], area[3], area[4], 'topbar_'..res)
		end
		
		-- Icon
		glColor(1,1,1,1)
		local iconPadding = 3*widgetScale
		if res == 'metal' then
			glTexture(LUAUI_DIRNAME.."Images/metal.png")
		else
			glTexture(LUAUI_DIRNAME.."Images/energy.png")
		end
		glTexRect(area[1]+iconPadding, area[2]+iconPadding, area[1]+(height*widgetScale)-iconPadding, area[4]-iconPadding)
		glTexture(false)
		
		-- Bar background
		if res == 'metal' then
			glColor(0.5,0.5,0.5,0.4)
		else
			glColor(0.5,0.5,0,0.4)
		end
		glTexture(barbg)
		glTexRect(barArea[1], barArea[2], barArea[3], barArea[4])

		-- Bar value
		if res == 'metal' then
			glColor(1, 1, 1, 1)
		else
			glColor(1, 1, 0, 1)
		end
		glTexture(barbg)
		glTexRect(barArea[1], barArea[2], barArea[1]+((r[1]/r[2]) * barWidth), barArea[4])
		
		
		-- Bar value glow
		local glowSize = barHeight * 4
		if res == 'metal' then
			glColor(1, 1, 1, 0.07)
		else
			glColor(1, 1, 0, 0.07)
		end
		glTexture(barGlowCenterTexture)
		glTexRect(barArea[1], barArea[2] - glowSize, barArea[1]+((r[1]/r[2]) * barWidth), barArea[4] + glowSize)
		glTexture(barGlowEdgeTexture)
		glTexRect(barArea[1]-(glowSize*2), barArea[2] - glowSize, barArea[1], barArea[4] + glowSize)
		glTexRect((barArea[1]+((r[1]/r[2]) * barWidth))+(glowSize*2), barArea[2] - glowSize, barArea[1]+((r[1]/r[2]) * barWidth), barArea[4] + glowSize)
		
		-- Share slider
		shareIndicatorArea[res] = {barArea[1]+(r[6] * barWidth)-(shareSliderWidth/2), barArea[2]-shareSliderHeightAdd, barArea[1]+(r[6] * barWidth)+(shareSliderWidth/2), barArea[4]+shareSliderHeightAdd}
		glTexture(barbg)
		glColor(0.8, 0, 0, 1)
		glTexRect(shareIndicatorArea[res][1], shareIndicatorArea[res][2], shareIndicatorArea[res][3], shareIndicatorArea[res][4])
		
		-- Metalmaker Conversion slider
		if showConversionSlider and res == 'energy' then 
			local convValue = Spring.GetTeamRulesParam(spGetMyTeamID(), 'mmLevel')
			conversionIndicatorArea = {barArea[1]+(convValue * barWidth)-(shareSliderWidth/2), barArea[2]-shareSliderHeightAdd, barArea[1]+(convValue * barWidth)+(shareSliderWidth/2), barArea[4]+shareSliderHeightAdd}
			glTexture(barbg)
			glColor(0.85, 0.85, 0.55, 1)
			glTexRect(conversionIndicatorArea[1], conversionIndicatorArea[2], conversionIndicatorArea[3], conversionIndicatorArea[4])
		end
		glTexture(false)
		
		-- Text: current
		glColor(1, 1, 1, 1)
		glText(short(r[1]), barArea[1]+barWidth/2, barArea[2]+barHeight*2, (height/3)*widgetScale, 'ocd')
		
		-- Text: storage
		glText("\255\133\133\133"..short(r[2]), barArea[3], barArea[2]+barHeight*2, (height/3.5)*widgetScale, 'ord')
		
		-- Text: pull
		glText("\255\200\100\100"..short(r[4]), barArea[1]+(50*widgetScale), barArea[2]+barHeight*2, (height/3.5)*widgetScale, 'od')
		
		-- Text: income
		glText("\255\100\200\100"..short(r[5]), barArea[1], barArea[2]+barHeight*2, (height/3.5)*widgetScale, 'od')
		
	end)
end

function init()
	
	if dlistBackground then
		glDeleteList(dlistBackground)
	end
	
	local borderPadding = 5*widgetScale
	topbarArea = {xPos, vsy-borderPadding-(height*widgetScale), vsx, vsy}
	barContentArea = {xPos+borderPadding, vsy-(height*widgetScale), vsx-borderPadding, vsy}
	
	local filledWidth = 0
	local totalWidth = barContentArea[3] - barContentArea[1]
	local areaSeparator = borderPadding
	
	dlistBackground = glCreateList( function()
		
		--glColor(0, 0, 0, 0.66)
		--RectRound(topbarArea[1], topbarArea[2], topbarArea[3], topbarArea[4], 6*widgetScale)
		--
		--glColor(1,1,1,0.025)
		--RectRound(barContentArea[1], barContentArea[2], barContentArea[3], barContentArea[4]+(10*widgetScale), 5*widgetScale)
		
		--if (WG['guishader_api'] ~= nil) then
		--	WG['guishader_api'].InsertRect(topbarArea[1]+(borderPadding/2), topbarArea[2], topbarArea[3], topbarArea[4], 'topbar')
		--end
	end)
	
	local width = (totalWidth/4)
	resbarArea['metal'] = {barContentArea[1]+filledWidth, barContentArea[2], barContentArea[1]+filledWidth+width, barContentArea[4]}
	filledWidth = filledWidth + width + areaSeparator
	updateResbar('metal')
	
	resbarArea['energy'] = {barContentArea[1]+filledWidth, barContentArea[2], barContentArea[1]+filledWidth+width, barContentArea[4]}
	filledWidth = filledWidth + width + areaSeparator
	updateResbar('energy')
	
	--energyconvArea = {barContentArea[1]+filledWidth, barContentArea[2], barContentArea[1]+filledWidth+(totalWidth/4), barContentArea[4]}
	--filledWidth = filledWidth + (totalWidth/4) + areaSeparator
	
	width = ((height*1.18)*widgetScale)
	windArea = {barContentArea[1]+filledWidth, barContentArea[2], barContentArea[1]+filledWidth+width, barContentArea[4]}
	filledWidth = filledWidth + width + areaSeparator
	
	comsArea = {barContentArea[1]+filledWidth, barContentArea[2], barContentArea[1]+filledWidth+width, barContentArea[4]}
	filledWidth = filledWidth + width + areaSeparator
	
	WG['topbar'] = {}
	WG['topbar'].GetPosition = function()
		return {topbarArea[1], topbarArea[2], topbarArea[3], topbarArea[4], widgetScale}
	end
end

function widget:Initialize()
	Spring.SendCommands("resbar 0")
	if Spring.GetGameFrame() > 0 then
		countComs()
	end
	init()
end

function widget:GameStart()
	countComs()
end

function checkStatus()
	--update my identity
	myAllyTeamID = Spring.GetMyAllyTeamID()
	myTeamID = Spring.GetMyTeamID()
end

local gameFrame = 0
local lastFrame = -1
function widget:GameFrame(n)
	gameFrame = n
end

function widget:Update()
	if (gameFrame ~= lastFrame) then
		lastFrame = gameFrame
		updateResbar('metal')
		updateResbar('energy')
		
    _, _, _, currentWind = spWind()
    currentWind = currentWind * 1.5 -- BA added extra wind income via gadget unit_windgenerators with an additional 50%
		updateWind(sformat('%.1f', currentWind))
		if minWind == maxWind then
      windRotation = windRotation + 1
    else
      windRotation = windRotation + (currentWind * bladeSpeedMultiplier)
    end
	end
    
    -- check if the team that we are spectating changed
	if spec and myTeamID ~= spGetMyTeamID() then
		checkStatus()
		countComs()
	end
	
	updateComs()
end


function widget:DrawScreen()
	glCallList(dlistBackground)
	glCallList(dlistResbar['metal'])
	glCallList(dlistResbar['energy'])
	glCallList(dlistWind)
	glCallList(dlistComs)
end


function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	
	-- check if the mouse is in a rectangle
	return x >= BLcornerX and x <= TRcornerX
	                      and y >= BLcornerY
	                      and y <= TRcornerY
end

function widget:MouseMove(x, y)
	if draggingShareIndicator ~= nil and not spec then
		local shareValue =	(x - resbarArea[draggingShareIndicator][1]) / (resbarArea[draggingShareIndicator][3] - resbarArea[draggingShareIndicator][1])
		if shareValue < 0 then shareValue = 0 end
		if shareValue > 1 then shareValue = 1 end
		Spring.SetShareLevel(draggingShareIndicator, shareValue)
	end
	if showConversionSlider and draggingConversionIndicator and not spec then
		local convValue = 0
		if convValue < 0.15 then convValue = 0.15 end
		if convValue > 1 then convValue = 1 end
		Spring.SendLuaRulesMsg(sformat(string.char(137)..'%i', convValue))
	end
end

function widget:MousePress(x, y, button)
	if button == 1 and not spec then
		if IsOnRect(x, y, shareIndicatorArea['metal'][1], shareIndicatorArea['metal'][2], shareIndicatorArea['metal'][3], shareIndicatorArea['metal'][4]) then
			draggingShareIndicator = 'metal'
			return true
		end
		if IsOnRect(x, y, shareIndicatorArea['energy'][1], shareIndicatorArea['energy'][2], shareIndicatorArea['energy'][3], shareIndicatorArea['energy'][4]) then
			draggingShareIndicator = 'energy'
			return true
		end
		if showConversionSlider and IsOnRect(x, y, conversionIndicatorArea[1], conversionIndicatorArea[2], conversionIndicatorArea[3], conversionIndicatorArea[4]) then
			draggingConversionIndicator = true
			return true
		end
	end
end

function widget:MouseRelease(x, y, button)
	draggingShareIndicator = nil
end

function widget:PlayerChanged()
	spec = spGetSpectatingState()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	myTeamID = Spring.GetMyTeamID()
	countComs()
end

function widget:Shutdown()
	--Spring.SendCommands("resbar 1")
	glDeleteList(dlistBackground)
	glDeleteList(dlistResbar['metal'])
	glDeleteList(dlistResbar['energy'])
	glDeleteList(dlistWind)
	WG['guishader_api'].RemoveRect('topbar')
	WG['guishader_api'].RemoveRect('topbar_energy')
	WG['guishader_api'].RemoveRect('topbar_metal')
	WG['guishader_api'].RemoveRect('topbar_wind')
	WG['guishader_api'].RemoveRect('topbar_coms')
end


function isCom(unitID,unitDefID)
	if not unitDefID and unitID then
		unitDefID =  Spring.GetUnitDefID(unitID)
	end
	if not unitDefID or not UnitDefs[unitDefID] or not UnitDefs[unitDefID].customParams then
		return false
	end
	return UnitDefs[unitDefID].customParams.iscommander ~= nil
end

function countComs()
	-- recount my own ally team coms
	allyComs = 0
	local myAllyTeamList = Spring.GetTeamList(myAllyTeamID)
	for _,teamID in ipairs(myAllyTeamList) do
		allyComs = allyComs + Spring.GetTeamUnitDefCount(teamID, armcomDefID) + Spring.GetTeamUnitDefCount(teamID, corcomDefID)
	end
	countChanged = true
	
	if spec then
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

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if not isCom(unitID,unitDefID) then
		return
	end
	
	--record com created
	local _,_,_,_,_,allyTeamID = Spring.GetTeamInfo(unitTeam)
	if allyTeamID == myAllyTeamID then
		allyComs = allyComs + 1
	elseif spec then
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
	elseif spec then
		enemyComs = enemyComs - 1
	end
	countChanged = true
end