
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name	= "AdvPlayersList Unit Totals",
		desc	= "Displays number of units",
		author	= "Floris",
		date	= "december 2019",
		license	= "GNU GPL, v2 or later",
		layer	= -3,
		enabled	= false,
	}
end


-- Localized functions for performance
local mathFloor = math.floor

-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetMyTeamID
local spGetViewGeometry = Spring.GetViewGeometry

local displayFeatureCount = false

local vsx, vsy = spGetViewGeometry()

local widgetScale = 1
local glPushMatrix   = gl.PushMatrix
local glPopMatrix    = gl.PopMatrix
local glCreateList   = gl.CreateList
local glDeleteList   = gl.DeleteList
local glCallList     = gl.CallList

local spGetTeamUnitCount = Spring.GetTeamUnitCount

local RectRound, UiElement, elementCorner
local font

local drawlist = {}
local advplayerlistPos = {}
local widgetHeight = 22
local top, left, bottom, right = 0,0,0,0

local myTeamID = spGetMyTeamID()
local totalUnits = 0
local passedTime = 0
local positionCheckTime = 0
local POSITION_CHECK_INTERVAL = 0.05

-- Pre-flatten all team IDs into a single array for fast iteration
local allTeamIDs = {}
local allTeamCount = 0
do
	local allyTeamList = Spring.GetAllyTeamList()
	for i = 1, #allyTeamList do
		local teams = Spring.GetTeamList(allyTeamList[i])
		for j = 1, #teams do
			allTeamCount = allTeamCount + 1
			allTeamIDs[allTeamCount] = teams[j]
		end
	end
end



local function drawBackground()
	UiElement(left, bottom, right, top, 1,0,0,1, 1,1,0,1, nil, nil, nil, nil)
end

local function drawContent()
	local textsize = 11*widgetScale * math.clamp(1+((1-(vsy/1200))*0.4), 1, 1.15)
	local textXPadding = 10*widgetScale

	local maxUnits, currentUnits = Spring.GetTeamMaxUnits(myTeamID)
	local text = I18N('ui.unitTotals.totals', { titleColor = '\255\210\210\210', textColor = '\255\245\245\245', units = currentUnits, maxUnits = maxUnits, totalUnits = totalUnits })

	if displayFeatureCount then
		local features = Spring.GetAllFeatures()
		text = text..'    \255\170\170\170'..#features
	end
	font:Begin(true)
	font:SetOutlineColor(0.15,0.15,0.15,0.8)
	font:Print(text, left+textXPadding, bottom+(0.48*widgetHeight*widgetScale)-(textsize*0.35), textsize, 'no')
	font:End()
end

local function refreshUiDrawing()
	if WG['guishader'] then
		if guishaderList then
			guishaderList = glDeleteList(guishaderList)
		end
		guishaderList = glCreateList( function()
			RectRound(left, bottom, right, top, elementCorner, 1,0,0,1)
		end)
		WG['guishader'].InsertDlist(guishaderList, 'unittotals', true)
	end

	if right-left >= 1 and top-bottom >= 1 then
		if not uiBgTex then
			uiBgTex = gl.CreateTexture(mathFloor(right-left), mathFloor(top-bottom), {
				target = GL.TEXTURE_2D,
				format = GL.RGBA,
				fbo = true,
			})
			gl.R2tHelper.RenderInRect(uiBgTex, left, bottom, right, top, drawBackground, true)
		end
		if not uiTex then
			uiTex = gl.CreateTexture(mathFloor(right-left), mathFloor(top-bottom), {		--*(vsy<1400 and 2 or 1)
				target = GL.TEXTURE_2D,
				format = GL.RGBA,
				fbo = true,
			})
		end
		gl.R2tHelper.RenderInRect(uiTex, left, bottom, right, top, drawContent, true)
	end
end

local function updatePosition(force)
	local prevPos = advplayerlistPos
	if WG['music'] and WG['music'].GetPosition and WG['music'].GetPosition() then
		advplayerlistPos = WG['music'].GetPosition()
	elseif WG['advplayerlist_api'] ~= nil then
		advplayerlistPos = WG['advplayerlist_api'].GetPosition()
	else
		local scale = (vsy / 880) * (1 + (Spring.GetConfigFloat("ui_scale", 1) - 1) / 1.25)
		advplayerlistPos = {0,vsx-(220*scale),0,vsx,scale}
	end
	left = advplayerlistPos[2]
	bottom = advplayerlistPos[1]
	right = advplayerlistPos[4]
	top = math.ceil(advplayerlistPos[1]+(widgetHeight*advplayerlistPos[5]))
	widgetScale = advplayerlistPos[5]
	if (prevPos[1] == nil or prevPos[1] ~= advplayerlistPos[1] or prevPos[2] ~= advplayerlistPos[2] or prevPos[5] ~= advplayerlistPos[5]) or force then
		widget:ViewResize()
	end
end

function widget:Initialize()
	widget:ViewResize()
	updatePosition()
	WG['unittotals'] = {}
	WG['unittotals'].GetPosition = function()
		return {top,left,bottom,right,widgetScale}
	end
end

function widget:PlayerChanged()
	myTeamID = spGetMyTeamID()
end

function widget:Shutdown()
	if WG['guishader'] then
		WG['guishader'].RemoveDlist('unittotals')
	end
	for i=1,#drawlist do
		glDeleteList(drawlist[i])
	end
	if guishaderList then glDeleteList(guishaderList) end
	if uiTex then
		gl.DeleteTexture(uiBgTex)
		uiBgTex = nil
		gl.DeleteTexture(uiTex)
		uiTex = nil
	end
	WG['unittotals'] = nil
end

function widget:Update(dt)
	passedTime = passedTime + dt
	positionCheckTime = positionCheckTime + dt

	-- Throttle position checks to ~4x per second instead of every frame
	if positionCheckTime >= POSITION_CHECK_INTERVAL then
		positionCheckTime = 0
		updatePosition()
	end

	if passedTime > 1 and Spring.GetGameFrame() > 0 then
		local count = 0
		for i = 1, allTeamCount do
			count = count + spGetTeamUnitCount(allTeamIDs[i])
		end
		totalUnits = count
		updateDrawing = true
		passedTime = passedTime - 1
	end
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()

	font = WG['fonts'].getFont()

	elementCorner = WG.FlowUI.elementCorner
	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	updateDrawing = true
	if uiTex then
		gl.DeleteTexture(uiBgTex)
		uiBgTex = nil
		gl.DeleteTexture(uiTex)
		uiTex = nil
	end
end

function widget:DrawScreen()
	if updateDrawing then
		updateDrawing = false
		refreshUiDrawing()
	end

	if uiBgTex then
		gl.R2tHelper.BlendTexRect(uiBgTex, left, bottom, right, top, true)
	end
	if uiTex then
		gl.R2tHelper.BlendTexRect(uiTex, left, bottom, right, top, true)
	end
end
