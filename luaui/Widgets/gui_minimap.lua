function widget:GetInfo()
	return {
		name = "Minimap",
		desc = "",
		author = "Floris",
		date = "April 2020",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local vsx, vsy = Spring.GetViewGeometry()

local enlarged = true

local maxWidth = 0.29 * (vsx / vsy)  -- NOTE: changes in widget:ViewResize()
local maxHeight = 0.243  -- NOTE: changes in widget:ViewResize()
maxWidth = math.min(maxHeight * (Game.mapX / Game.mapY), maxWidth)

local bgBorderOrg = 0.0025
local bgBorder = bgBorderOrg
local bgMargin = 0.005

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.6) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)

local backgroundRect = { 0, 0, 0, 0 }

local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spGetCameraState = Spring.GetCameraState

local usedWidth = math.floor(maxWidth * vsy)
local usedHeight = math.floor(maxHeight * vsy)

local RectRound, UiElement, elementCorner = WG.FlowUI.elementCorner

local dlistGuishader, dlistMinimap, bgpadding, oldMinimapGeometry, chobbyInterface

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function checkGuishader(force)
	if WG['guishader'] then
		if force and dlistGuishader then
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader then
			dlistGuishader = gl.CreateList(function()
				local padding = math.floor(bgBorder * vsy)
				RectRound(backgroundRect[1], backgroundRect[2] - padding, backgroundRect[3] + padding, backgroundRect[4], elementCorner)
			end)
			WG['guishader'].InsertDlist(dlistGuishader, 'minimap')
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	local w = 0.285
	if enlarged then
		maxWidth = w * (vsx / vsy)
		maxHeight = 0.3865
	else
		maxWidth = w * (vsx / vsy)
		maxHeight = 0.243
	end
	maxWidth = math.min(maxHeight * (Game.mapX / Game.mapY), maxWidth)
	if maxWidth >= w * (vsx / vsy) then
		maxHeight = maxWidth / (Game.mapX / Game.mapY)
	end

	usedWidth = math.floor(maxWidth * vsy)
	usedHeight = math.floor(maxHeight * vsy)

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	Spring.SendCommands(string.format("minimap geometry %i %i %i %i", 0, 0, usedWidth, usedHeight))

	backgroundRect = { 0, vsy - (usedHeight), usedWidth, vsy }

	checkGuishader(true)

	clear()
end

function widget:Initialize()
	oldMinimapGeometry = spGetMiniMapGeometry()
	gl.SlaveMiniMap(true)

	widget:ViewResize()

	WG['minimap'] = {}
	WG['minimap'].getEnlarged = function()
		return enlarged
	end
	WG['minimap'].setEnlarged = function(value)
		enlarged = value
		widget:ViewResize()
	end
	WG['minimap'].getHeight = function()
		return usedHeight + bgpadding
	end
	--WG['minimap'].setHeight = function()
	--
	--    widget:ViewResize()
	--end
end

function widget:GameStart()
	widget:ViewResize()
end

function clear()
	dlistMinimap = gl.DeleteList(dlistMinimap)
end

function widget:Shutdown()
	clear()
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('minimap')
		dlistGuishader = nil
	end

	gl.SlaveMiniMap(false)
	Spring.SendCommands("minimap geometry " .. oldMinimapGeometry)
end

local delayedSetup = false
local sec = 0
local uiOpacitySec = 0
function widget:Update(dt)
	if not delayedSetup then
		sec = sec + dt
		if sec > 2 then
			delayedSetup = true
			widget:ViewResize()
		end
	end

	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec > 0.5 then
		Spring.SendCommands(string.format("minimap geometry %i %i %i %i", 0, 0, usedWidth, usedHeight))
		uiOpacitySec = 0
		checkGuishader()
		if ui_scale ~= Spring.GetConfigFloat("ui_scale", 1) then
			ui_scale = Spring.GetConfigFloat("ui_scale", 1)
			widget:ViewResize()
		end
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity", 0.6) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)
			clear()
		end
	end
end

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function drawMinimap()
	UiElement(backgroundRect[1], backgroundRect[2] - bgpadding, backgroundRect[3] + bgpadding, backgroundRect[4], 0, 0, 1, 0)
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then
		return
	end
	--local x,y,b = Spring.GetMouseState()
	--if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
	--  Spring.SetMouseCursor('cursornormal')
	--end
	local st = spGetCameraState()
	if st.name == "ov" then
		-- overview camera
		if dlistGuishader and WG['guishader'] then
			WG['guishader'].RemoveDlist('minimap')
		end
	else
		if dlistGuishader and WG['guishader'] then
			WG['guishader'].InsertDlist(dlistGuishader, 'minimap')
		end
		if not dlistMinimap then
			dlistMinimap = gl.CreateList(function()
				drawMinimap()
			end)
		end
		gl.CallList(dlistMinimap)
	end

	--gl.ResetState()
	--gl.ResetMatrices()
	gl.DrawMiniMap()
	--gl.ResetState()
	--gl.ResetMatrices()
end

function widget:GetConfigData()
	--save config
	return {
		enlarged = enlarged
	}
end

function widget:SetConfigData(data)
	--load config
	if data.enlarged ~= nil then
		enlarged = data.enlarged
	end
end

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() then
		return
	end
	local padding = math.floor(bgBorder * vsy)
	if IsOnRect(x, y, backgroundRect[1], backgroundRect[2] - padding, backgroundRect[3] + padding, backgroundRect[4]) then
		if not IsOnRect(x, y, backgroundRect[1], backgroundRect[2] + 1, backgroundRect[3] - 1, backgroundRect[4]) then
			return true
		end
	end
end
