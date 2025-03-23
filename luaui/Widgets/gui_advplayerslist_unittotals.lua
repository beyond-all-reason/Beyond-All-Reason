
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

local displayFeatureCount = false

local vsx, vsy = Spring.GetViewGeometry()

local widgetScale = 1
local glPushMatrix   = gl.PushMatrix
local glPopMatrix    = gl.PopMatrix
local glCreateList   = gl.CreateList
local glDeleteList   = gl.DeleteList
local glCallList     = gl.CallList

local math_isInRect = math.isInRect
local spGetTeamUnitCount = Spring.GetTeamUnitCount

local RectRound, UiElement, elementCorner
local font, hovering

local drawlist = {}
local advplayerlistPos = {}
local widgetHeight = 22
local top, left, bottom, right = 0,0,0,0

local myTeamID = Spring.GetMyTeamID()
local totalUnits = 0
local passedTime = 0

local allyTeamList = Spring.GetAllyTeamList()
local allyTeamTeamList = {}
for i = 1, #allyTeamList do
	allyTeamTeamList[allyTeamList[i]] = Spring.GetTeamList(allyTeamList[i])
end


local function updateValues()
	local textsize = 11*widgetScale
	local textXPadding = 10*widgetScale

	if drawlist[2] ~= nil then
		glDeleteList(drawlist[2])
	end
	drawlist[2] = glCreateList( function()
		local maxUnits, currentUnits = Spring.GetTeamMaxUnits(myTeamID)
		local text = Spring.I18N('ui.unitTotals.totals', { titleColor = '\255\210\210\210', textColor = '\255\255\255\255', units = currentUnits, maxUnits = maxUnits, totalUnits = totalUnits })

		if displayFeatureCount then
			local features = Spring.GetAllFeatures()
			text = text..'    \255\170\170\170'..#features
		end

		font:Begin()
		font:Print(text, left+textXPadding, bottom+(0.3*widgetHeight*widgetScale), textsize, 'no')
		font:End()
	end)
end

local function createList()
	if drawlist[3] then
		drawlist[3] = glDeleteList(drawlist[3])
	end
	if WG['guishader'] then
		drawlist[3] = glCreateList( function()
			RectRound(left, bottom, right, top, elementCorner)
		end)
		WG['guishader'].InsertDlist(drawlist[3], 'unittotals', true)
	end
	if drawlist[1] ~= nil then
		glDeleteList(drawlist[1])
	end
	drawlist[1] = glCreateList( function()
		UiElement(left, bottom, right, top, 1,0,0,1, 1,1,0,1)
	end)
	updateValues()
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
		createList()
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
	myTeamID = Spring.GetMyTeamID()
end

function widget:Shutdown()
	if WG['guishader'] then
		WG['guishader'].RemoveDlist('unittotals')
	end
	for i=1,#drawlist do
		glDeleteList(drawlist[i])
	end
	WG['unittotals'] = nil
end

function widget:Update(dt)
	updatePosition()
	passedTime = passedTime + dt
	if passedTime > 1 and Spring.GetGameFrame() > 0 then
		totalUnits = 0
		local numberOfAllyTeams = #allyTeamList
		for allyTeamListIndex = 1, numberOfAllyTeams do
			local allyID = allyTeamList[allyTeamListIndex]
			for _,teamID in pairs(allyTeamTeamList[allyID]) do
				totalUnits = totalUnits + spGetTeamUnitCount(teamID)
			end
		end
		updateValues()
		passedTime = passedTime - 1
	end
end

function widget:ViewResize()
	local prevVsx, prevVsy = vsx, vsy
	vsx, vsy = Spring.GetViewGeometry()

	font = WG['fonts'].getFont()

	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	if prevVsy ~= vsx or prevVsy ~= vsy then
		createList()
	end
end

function widget:DrawScreen()
	hovering = false
	if drawlist[1] ~= nil then
		local mx, my, mb = Spring.GetMouseState()
		if math_isInRect(mx, my, left, bottom, right, top) then
			Spring.SetMouseCursor('cursornormal')
			hovering = true
		end
		glPushMatrix()
			glCallList(drawlist[1])
			glCallList(drawlist[2])
		glPopMatrix()
	end
end

function widget:MousePress(mx, my, mb)
	if hovering then
		return true
	end
end
