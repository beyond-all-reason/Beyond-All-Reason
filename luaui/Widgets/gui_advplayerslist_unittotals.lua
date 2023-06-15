
function widget:GetInfo()
	return {
		name	= "AdvPlayersList Unit Totals",
		desc	= "Displays number of units",
		author	= "Floris",
		date	= "december 2019",
		license	= "GNU GPL, v2 or later",
		layer	= -3,
		enabled	= false,	--	loaded by default?
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

local RectRound, UiElement, elementCorner

local font, chobbyInterface, hovering

local drawlist = {}
local advplayerlistPos = {}
local widgetHeight = 22
local top, left, bottom, right = 0,0,0,0

-- calc actual player max unit limit = 32000 / (players+gaia)
local gameMaxUnits = math.min(Spring.GetModOptions().maxunits, math.floor(32000 / #Spring.GetTeamList()))

local totalUnits = 0
local totalGaiaUnits = 0

local passedTime = 0
local passedTime2 = 0

local math_isInRect = math.isInRect

function widget:Initialize()
	widget:ViewResize()
	updatePosition()
	WG['unittotals'] = {}
	WG['unittotals'].GetPosition = function()
		return {top,left,bottom,right,widgetScale}
	end
end

local function updateValues()
	local textsize = 11*widgetScale
	local textXPadding = 10*widgetScale

	if drawlist[2] ~= nil then
		glDeleteList(drawlist[2])
	end
	drawlist[2] = glCreateList( function()
		local titleColor = '\255\210\210\210'
		local valueColor = '\255\255\255\255'
		local myTotalUnits = Spring.GetTeamUnitCount(Spring.GetMyTeamID())
		local text = Spring.I18N('ui.unitTotals.totals', { titleColor = titleColor, textColor = valueColor, units = myTotalUnits, maxUnits = gameMaxUnits, totalUnits = totalUnits })

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
	passedTime = passedTime + dt
	passedTime2 = passedTime2 + dt
	if passedTime > 0.1 then
		passedTime = passedTime - 0.1
		updatePosition()
	end
	if passedTime2 > 1 then
		totalUnits = 0
		totalGaiaUnits = 0
		local allyTeamList = Spring.GetAllyTeamList()
		local numberOfAllyTeams = #allyTeamList
		for allyTeamListIndex = 1, numberOfAllyTeams do
			local allyID = allyTeamList[allyTeamListIndex]
			local teamList = Spring.GetTeamList(allyID)
			for _,teamID in pairs(teamList) do
				totalUnits = totalUnits + Spring.GetTeamUnitCount(teamID)
				if teamID == GaiaTeamID then
					totalGaiaUnits = totalGaiaUnits + Spring.GetTeamUnitCount(teamID)
				end
			end
		end
		updateValues()
		passedTime2 = passedTime2 - 1
	end
end

function updatePosition(force)
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

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end

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
