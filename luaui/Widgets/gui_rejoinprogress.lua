local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Rejoin progress",
		desc = "",
		author = "Floris",
		date = "April, 2023",
		license = "GNU GPL, v2 or later",
		layer = 9999,
		enabled = true,
	}
end

-- Localized functions for performance
local mathFloor = math.floor

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame

local showRejoinUI = false
local CATCH_UP_THRESHOLD = 11 * Game.gameSpeed -- only show the window if behind this much
local UPDATE_RATE_F = 5 -- frames
local UPDATE_RATE_S = UPDATE_RATE_F / Game.gameSpeed
local t = UPDATE_RATE_S

local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local vsx, vsy = gl.GetViewSizes()
local widgetScale = 1
local noiseBackgroundTexture = ":g:LuaUI/Images/rgbnoise.png"
local stripesTexture = "LuaUI/Images/stripes.png"
local barGlowCenterTexture = ":l:LuaUI/Images/barglow-center.png"
local barGlowEdgeTexture = ":l:LuaUI/Images/barglow-edge.png"
local rejoinArea = {}
local gameStarted = (spGetGameFrame() > 0)
local isReplay = Spring.IsReplay()
local RectRound, TexturedRectRound, UiElement, font2
local dlistRejoinStatic, dlistRejoinGuishader, serverFrame
local posY = 0.22
local width, height
local currentCatchup = 0
local barHeight, barWidth, edgeWidth, addedSize, glowSize, fontsize, stripesTexScale

-- Reused tables to avoid per-update allocations while rebuilding display lists.
local barArea = { 0, 0, 0, 0 }
local colorBlack03 = { 0, 0, 0, 0.03 }
local colorDark20 = { 0.15, 0.15, 0.15, 0.2 }
local colorLight16 = { 0.8, 0.8, 0.8, 0.16 }
local colorWhite0 = { 1, 1, 1, 0 }
local colorWhite007 = { 1, 1, 1, 0.07 }
local colorWhite01 = { 1, 1, 1, 0.1 }
local colorWhite013 = { 1, 1, 1, 0.13 }
local colorZero0 = { 0, 0, 0, 0 }
local colorGreenDark = { 0, 0.55, 0, 1 }
local colorGreenBright = { 0, 1, 0, 1 }

local catchingUpText = BAR.I18N("ui.rejoin.catchingUp")
local lastGameTimeText = nil
local cachedTitleText = nil

local function deleteStaticDList()
	if dlistRejoinStatic ~= nil then
		gl.DeleteList(dlistRejoinStatic)
		dlistRejoinStatic = nil
	end
end

local function deleteGuiShaderDList()
	if dlistRejoinGuishader ~= nil then
		if WG.guishader then
			WG.guishader.RemoveDlist("rejoinprogress")
		end
		gl.DeleteList(dlistRejoinGuishader)
		dlistRejoinGuishader = nil
	end
end

local function RectQuad(px, py, sx, sy, offset)
	gl.TexCoord(offset, 1 - offset)
	gl.Vertex(px, py, 0)
	gl.TexCoord(1 - offset, 1 - offset)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(1 - offset, offset)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(offset, offset)
	gl.Vertex(px, sy, 0)
end
local function DrawRect(px, py, sx, sy, zoom)
	gl.BeginEnd(GL.QUADS, RectQuad, px, py, sx, sy, zoom)
end

local function buildStaticRejoin()
	local area = rejoinArea

	if not dlistRejoinGuishader then
		dlistRejoinGuishader = gl.CreateList(function()
			RectRound(area[1], area[2], area[3], area[4], 5.5 * widgetScale, 0, 0, 1, 1)
		end)
		if WG.guishader then
			WG.guishader.InsertDlist(dlistRejoinGuishader, "rejoinprogress")
		end
	end

	deleteStaticDList()
	dlistRejoinStatic = gl.CreateList(function()
		UiElement(area[1], area[2], area[3], area[4], 1, 1, 1, 1)

		RectRound(barArea[1] - addedSize - edgeWidth, barArea[2] - addedSize - edgeWidth, barArea[3] + addedSize + edgeWidth, barArea[4] + addedSize + edgeWidth, barHeight * 0.33, 1, 1, 1, 1, colorBlack03, colorBlack03)
		RectRound(barArea[1] - addedSize, barArea[2] - addedSize, barArea[3] + addedSize, barArea[4] + addedSize, barHeight * 0.33, 1, 1, 1, 1, colorDark20, colorLight16)

		gl.Texture(noiseBackgroundTexture)
		gl.Color(1, 1, 1, 0.12)
		TexturedRectRound(barArea[1] - addedSize - edgeWidth, barArea[2] - addedSize - edgeWidth, barArea[3] + addedSize + edgeWidth, barArea[4] + addedSize + edgeWidth, barHeight * 0.33, barWidth * 0.6, 0)
		gl.Texture(false)

		gl.Blending(GL.SRC_ALPHA, GL.ONE)
		RectRound(barArea[1] - addedSize, barArea[2] + addedSize, barArea[3] + addedSize, barArea[4] + addedSize, barHeight * 0.33, 1, 1, 0, 0, colorWhite0, colorWhite007)
		RectRound(barArea[1] - addedSize, barArea[2] - addedSize, barArea[3] + addedSize, barArea[2] + addedSize + addedSize + addedSize, barHeight * 0.2, 0, 0, 1, 1, colorWhite01, colorWhite0)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		gl.Color(1, 1, 1, 1)
	end)
end

local function updateGeometry()
	local area = rejoinArea
	local barHeightPadding = 1 + mathFloor(vsy * 0.007)
	barHeight = mathFloor((height * widgetScale / 7.5) + 0.5)
	barArea[1] = area[1] + barHeightPadding
	barArea[2] = area[2] + barHeightPadding
	barArea[3] = area[3] - barHeightPadding
	barArea[4] = area[2] + barHeight + barHeightPadding
	barWidth = barArea[3] - barArea[1]
	edgeWidth = math.max(1, mathFloor(vsy / 1100))
	addedSize = mathFloor(((barArea[4] - barArea[2]) * 0.15) + 0.5)
	glowSize = barHeight * 6
	fontsize = mathFloor(height * 0.34)
	stripesTexScale = barWidth * 0.22
end

local function updateRejoinText()
	local mins = mathFloor(serverFrame / 30 / 60)
	local secs = mathFloor(((serverFrame / 30 / 60) - mins) * 60)
	local gametime = mins .. ":" .. (secs < 10 and "0" .. secs or secs)
	if gametime ~= lastGameTimeText then
		lastGameTimeText = gametime
		cachedTitleText = "\255\225\255\225" .. catchingUpText .. " \255\166\166\166" .. gametime
	end
end

local function updateRejoinState()
	if showRejoinUI and serverFrame then
		currentCatchup = spGetGameFrame() / serverFrame
		updateRejoinText()
	end
end

local function drawRejoinDynamic()
	local valueWidth = currentCatchup * barWidth

	gl.Color(0, 1, 0, 1)
	RectRound(barArea[1], barArea[2], barArea[1] + valueWidth, barArea[4], barHeight * 0.2, 1, 1, 1, 1, colorGreenDark, colorGreenBright)

	gl.Texture(stripesTexture)
	gl.Color(1, 1, 1, 0.16)
	TexturedRectRound(barArea[1], barArea[2], barArea[1] + valueWidth, barArea[4], barHeight * 0.2, 1, 1, 1, 1, stripesTexScale, -os.clock() * 0.06)

	gl.Texture(noiseBackgroundTexture)
	gl.Color(1, 1, 1, 0.07)
	TexturedRectRound(barArea[1], barArea[2], barArea[1] + valueWidth, barArea[4], barHeight * 0.2, barWidth * 0.6, 0)
	gl.Texture(false)

	gl.Blending(GL.SRC_ALPHA, GL.ONE)
	RectRound(barArea[1], barArea[4] - ((barArea[4] - barArea[2]) / 1.5), barArea[1] + valueWidth, barArea[4], barHeight * 0.2, 1, 1, 1, 1, colorZero0, colorWhite013)
	RectRound(barArea[1], barArea[2], barArea[1] + valueWidth, barArea[2] + ((barArea[4] - barArea[2]) / 2), barHeight * 0.2, 1, 1, 1, 1, colorWhite013, colorZero0)

	gl.Color(0, 1, 0, 0.08)
	gl.Texture(barGlowCenterTexture)
	DrawRect(barArea[1], barArea[2] - glowSize, barArea[1] + valueWidth, barArea[4] + glowSize, 0.008)
	gl.Texture(barGlowEdgeTexture)
	DrawRect(barArea[1] - (glowSize * 2), barArea[2] - glowSize, barArea[1], barArea[4] + glowSize, 0.008)
	DrawRect((barArea[1] + valueWidth) + (glowSize * 2), barArea[2] - glowSize, barArea[1] + valueWidth, barArea[4] + glowSize, 0.008)
	gl.Texture(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Color(1, 1, 1, 1)

	font2:Begin()
	font2:SetTextColor(0.92, 0.92, 0.92, 1)
	font2:SetOutlineColor(0, 0, 0, 1)
	font2:Print(cachedTitleText, rejoinArea[1] + ((rejoinArea[3] - rejoinArea[1]) / 2), rejoinArea[2] + barHeight * 2 + (fontsize * 0.89), fontsize, "cor")
	font2:End()
end

function widget:Update(dt)
	-- rejoin
	if not isReplay and serverFrame then
		t = t - dt
		if t <= 0 then
			t = t + UPDATE_RATE_S

			if Spring.IsGameOver() then -- not sure if widget:GameOver() even works so I do this here as well
				widgetHandler:RemoveWidget()
				return
			end

			local speedFactor, _, isPaused = Spring.GetGameSpeed()

			-- update/estimate serverFrame (because widget:GameProgress(n) only happens every 150 frames)
			if gameStarted and not isPaused then
				serverFrame = serverFrame + (speedFactor * UPDATE_RATE_F)
			end

			local framesLeft = serverFrame - spGetGameFrame()
			if framesLeft > CATCH_UP_THRESHOLD then
				if not showRejoinUI then
					showRejoinUI = true
					buildStaticRejoin()
				end
				updateRejoinState()
			elseif showRejoinUI then
				showRejoinUI = false
				deleteStaticDList()
				deleteGuiShaderDList()
			end
		end
	end
end

function widget:DrawScreen()
	if dlistRejoinStatic and showRejoinUI then
		gl.CallList(dlistRejoinStatic)
		drawRejoinDynamic()
	end
end

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()
	width = mathFloor(vsy * 0.23)
	height = mathFloor(vsy * 0.046)
	widgetScale = (vsy / height) * 0.0425
	widgetScale = widgetScale * ui_scale

	RectRound = WG.FlowUI.Draw.RectRound
	TexturedRectRound = WG.FlowUI.Draw.TexturedRectRound
	UiElement = WG.FlowUI.Draw.Element

	font2 = WG.fonts.getFont(2)

	rejoinArea = { mathFloor(0.5 * vsx) - mathFloor(width * 0.5), mathFloor(posY * vsy) - mathFloor(height * 0.5), mathFloor(0.5 * vsx) + mathFloor(width * 0.5), mathFloor(posY * vsy) + mathFloor(height * 0.5) }
	updateGeometry()
	deleteStaticDList()
	deleteGuiShaderDList()

	if showRejoinUI and serverFrame then
		buildStaticRejoin()
		updateRejoinState()
	end
end

-- used for rejoin progress functionality
function widget:GameProgress(n) -- happens every 150 frames
	serverFrame = n
end

function widget:GameOver()
	widgetHandler:RemoveWidget()
end

function widget:GameStart()
	gameStarted = true
end

function widget:RecvLuaMsg(msg, playerID)
	if not serverFrame and msg:sub(1, 12) == "ServerFrame" then
		serverFrame = tonumber(msg:sub(13))
	end
end

function widget:Initialize()
	widget:ViewResize()
	WG.rejoin = {}
	WG.rejoin.showingRejoining = function()
		return showRejoinUI
	end
end

function widget:Shutdown()
	deleteStaticDList()
	deleteGuiShaderDList()
	WG.rejoin = nil
end
