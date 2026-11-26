local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Minimap",
		desc = "Standard BAR Minimap (hardened slave-mode guard for BAR Zombie Defense)",
		author = "Floris",
		date = "April 2020",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Localized functions for performance
local mathFloor = math.floor
local mathMin = math.min

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry

local minimapToWorld = require("luaui/Include/minimap_utils").minimapToWorld
local getCurrentMiniMapRotationOption = require("luaui/Include/minimap_utils").getCurrentMiniMapRotationOption
local ROTATION = require("luaui/Include/minimap_utils").ROTATION

local maxWidthFraction = 0.25
local maxAllowedWidth = maxWidthFraction
local maxAllowedHeight = Spring.GetConfigFloat("MinimapMaxHeight", 0.32)
local leftClickMove = Spring.GetConfigInt("MinimapLeftClickMove", 1) == 1

local vsx, vsy, _, vpy = spGetViewGeometry()

local minimized = false
local maximized = false

local maxHeight = maxAllowedHeight
local ratio = Game.mapX / Game.mapY
local maxWidth = mathMin(maxHeight * ratio, maxAllowedWidth * (vsx / vsy))
local usedWidth = mathFloor(maxWidth * vsy)
local usedHeight = mathFloor(maxHeight * vsy)
---@type ScreenRect
local backgroundRect = { 0, 0, 0, 0 }

local delayedSetup = false
local sec = 0
local sec2 = 0
local lastRot = -1

local spGetCameraState = Spring.GetCameraState
local spGetActiveCommand = Spring.GetActiveCommand
local math_isInRect = math.isInRect

local wasOverview = false
local leftclicked = false

local RectRound, UiElement, elementCorner, elementPadding, elementMargin
local dlistGuishader, dlistMinimap, oldMinimapGeometry, uiBgTex

---@type { l: number, b: number, r: number, t: number, outerHeight: number }?
local externalFrame = nil

local dualscreenMode = ((Spring.GetConfigInt("DualScreenMode", 0) or 0) == 1)

-- Icon density scaling: reduce icon size when many units are on the map
local iconDensityMaxUnits = 18000
local iconDensityMinScale = 0.5
local baseMinimapIconScale = Spring.GetConfigFloat("MinimapIconScale", 3.5)
local lastAppliedIconScale = nil

local function drawMiniMapSafe()
	local ok = pcall(gl.DrawMiniMap)
	if not ok then
		gl.SlaveMiniMap(true)
		if minimized then
			Spring.SendCommands("minimap minimize 1")
		end
		pcall(gl.DrawMiniMap)
	end
end

local function checkGuishader(force)
	if not WG.FlowUI or not WG.FlowUI.guishaderCheckDlist or not RectRound then
		return
	end
	dlistGuishader = WG.FlowUI.guishaderCheckDlist(dlistGuishader, "minimap", function()
		RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], elementCorner)
	end, force)
end

local function clear()
	if dlistMinimap then
		dlistMinimap = gl.DeleteList(dlistMinimap)
	end
	if uiBgTex then
		gl.DeleteTexture(uiBgTex)
		uiBgTex = nil
	end
	if WG.FlowUI and WG.FlowUI.guishaderDeleteDlist then
		WG.FlowUI.guishaderDeleteDlist("minimap")
	end
	dlistGuishader = nil
end

function widget:ViewResize()
	local newDualscreenMode = ((Spring.GetConfigInt("DualScreenMode", 0) or 0) == 1)
	if dualscreenMode ~= newDualscreenMode then
		dualscreenMode = newDualscreenMode
		if dualscreenMode then
			clear()
		else
			widget:Initialize()
		end
		return
	end

	vsx, vsy, _, vpy = spGetViewGeometry()

	local flow = WG.FlowUI
	elementPadding = (flow and flow.elementPadding) or 6
	elementCorner = (flow and flow.elementCorner) or 5
	RectRound = flow and flow.Draw and flow.Draw.RectRound or nil
	UiElement = flow and flow.Draw and flow.Draw.Element or nil
	elementMargin = (flow and flow.elementMargin) or 5

	if WG.topbar ~= nil and WG.topbar.GetPosition then
		local topbarArea = WG.topbar.GetPosition()
		if topbarArea and topbarArea[1] then
			maxAllowedWidth = mathMin(maxWidthFraction, (topbarArea[1] - (elementMargin * 6)) / vsx)
		end
	end

	maxWidth = mathMin(maxAllowedHeight * ratio, maxAllowedWidth * (vsx / vsy))
	if maxWidth >= maxAllowedWidth * (vsx / vsy) then
		maxHeight = maxWidth / ratio
	else
		maxHeight = maxAllowedHeight
	end

	usedWidth = mathFloor(maxWidth * vsy)
	usedHeight = mathFloor(maxHeight * vsy)

	backgroundRect = { 0, vsy - usedHeight - elementPadding, usedWidth + elementPadding, vsy }
	if externalFrame then
		local f = externalFrame
		usedWidth, usedHeight = mathFloor(f.r - f.l), mathFloor(f.t - f.b)
		backgroundRect = { f.l, f.b, f.r, f.t }
		if WG.FlowUI and WG.FlowUI.guishaderDeleteDlist then
			WG.FlowUI.guishaderDeleteDlist("minimap")
		end
		dlistGuishader = nil
	end

	if not dualscreenMode then
		Spring.SendCommands(
			string.format(
				"minimap geometry %i %i %i %i",
				backgroundRect[1],
				vsy - backgroundRect[4],
				usedWidth,
				usedHeight
			)
		)
		if not externalFrame then
			checkGuishader(true)
		end
	end
	if dlistMinimap then
		dlistMinimap = gl.DeleteList(dlistMinimap)
	end
	if uiBgTex then
		gl.DeleteTexture(uiBgTex)
		uiBgTex = nil
	end
end

function widget:Initialize()
	oldMinimapGeometry = Spring.GetMiniMapGeometry()
	gl.SlaveMiniMap(true)
	Spring.SetConfigInt("MinimapMinimize", 0)
	Spring.SendCommands("minimap minimize 0")

	widget:ViewResize()

	_, _, _, _, minimized, maximized = Spring.GetMiniMapGeometry()

	WG.minimap = {}
	WG.minimap.getHeight = function()
		if externalFrame then
			return externalFrame.outerHeight
		end
		return usedHeight + elementPadding
	end
	WG.minimap.setExternalFrame = function(l, b, r, t, outerHeight, resizing)
		if l then
			externalFrame = { l = l, b = b, r = r, t = t, outerHeight = outerHeight or (vsy - b) }
		elseif not externalFrame then
			return
		else
			externalFrame = nil
		end
		widget:ViewResize(vsx, vsy)
	end
	WG.minimap.getMaxHeight = function()
		return mathFloor(maxAllowedHeight * vsy), maxAllowedHeight
	end
	WG.minimap.setMaxHeight = function(value)
		Spring.SetConfigFloat("MinimapMaxHeight", value)
		maxAllowedHeight = value
		widget:ViewResize()
	end
	WG.minimap.getLeftClickMove = function()
		return leftClickMove
	end
	WG.minimap.setLeftClickMove = function(value)
		leftClickMove = value
		Spring.SetConfigInt("MinimapLeftClickMove", value and 1 or 0)
	end
	WG.minimap.setBaseIconScale = function(value)
		baseMinimapIconScale = value
	end
	WG.minimap.getRect = function()
		return backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4],
			elementPadding or 6, elementCorner or 5, elementMargin or 5, minimized, maximized
	end
end

function widget:GameStart()
	gl.SlaveMiniMap(true)
	widget:ViewResize()
end

function widget:Shutdown()
	clear()
	gl.SlaveMiniMap(false)

	Spring.SendCommands("minimap unitsize " .. baseMinimapIconScale)
	Spring.SetConfigFloat("MinimapIconScale", baseMinimapIconScale)

	if not dualscreenMode and oldMinimapGeometry then
		Spring.SendCommands("minimap geometry " .. oldMinimapGeometry)
	end
end

function widget:Update(dt)
	if not UiElement and WG.FlowUI and WG.FlowUI.Draw and WG.FlowUI.Draw.Element then
		widget:ViewResize()
	end
	local currRot = getCurrentMiniMapRotationOption()
	if lastRot ~= currRot then
		if currRot == ROTATION.DEG_90 or currRot == ROTATION.DEG_270 then
			ratio = Game.mapY / Game.mapX
		else
			ratio = Game.mapX / Game.mapY
		end
		lastRot = currRot
		widget:ViewResize()
		return
	end
	if not delayedSetup then
		sec = sec + dt
		if sec > 2 then
			delayedSetup = true
			widget:ViewResize()
		end
	end

	sec2 = sec2 + dt
	if sec2 <= 0.25 then
		return
	end
	sec2 = 0

	local cfgMaxHeight = Spring.GetConfigFloat("MinimapMaxHeight", 0.32)
	if cfgMaxHeight ~= maxAllowedHeight then
		maxAllowedHeight = cfgMaxHeight
		widget:ViewResize()
	end

	if dualscreenMode then
		return
	end

	_, _, _, _, minimized, maximized = Spring.GetMiniMapGeometry()
	if minimized or maximized then
		return
	end

	Spring.SendCommands(
		string.format("minimap geometry %i %i %i %i", backgroundRect[1], vsy - backgroundRect[4], usedWidth, usedHeight)
	)
	if not externalFrame then
		checkGuishader()
	end

	local allUnits = Spring.GetAllUnits()
	local totalUnits = allUnits and #allUnits or 0
	local unitFraction = math.min(totalUnits / iconDensityMaxUnits, 1.0)
	local densityScale = 1.0 - (1.0 - iconDensityMinScale) * unitFraction
	local resBoost = 1.0 + 0.18 * math.min(math.max((vsy - 1080) / (2880 - 1080), 0), 1)
	local scaledIconSize = baseMinimapIconScale * densityScale * resBoost
	if scaledIconSize ~= lastAppliedIconScale then
		Spring.SendCommands("minimap unitsize " .. scaledIconSize)
		lastAppliedIconScale = scaledIconSize
	end
end

local function drawBackground()
	if UiElement then
		UiElement(
			backgroundRect[1],
			backgroundRect[2],
			backgroundRect[3],
			backgroundRect[4],
			0,
			0,
			1,
			0,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil
		)
	else
		gl.Color(0.04, 0.08, 0.12, 0.78)
		gl.Rect(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4])
		gl.Color(1, 1, 1, 1)
	end
end

local st = spGetCameraState()
local stframe = 0
function widget:DrawScreen()
	if dualscreenMode and not minimized then
		drawMiniMapSafe()
		return
	end

	if minimized or maximized then
		clear()
	else
		local x, y = Spring.GetMouseState()
		if
			math_isInRect(
				x,
				y,
				backgroundRect[1],
				backgroundRect[2] - elementPadding,
				backgroundRect[3] + elementPadding,
				backgroundRect[4]
			)
		then
			if
				not math_isInRect(
					x,
					y,
					backgroundRect[1],
					backgroundRect[2] + 1,
					backgroundRect[3] - 1,
					backgroundRect[4]
				)
			then
				Spring.SetMouseCursor("cursornormal")
			end
		end
	end

	stframe = stframe + 1
	if stframe % 10 == 0 then
		st = spGetCameraState()
	end
	if st and st.name == "ov" then
		if dlistGuishader and WG.guishader then
			WG.guishader.RemoveDlist("minimap")
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		wasOverview = true
	elseif not (minimized or maximized) or (wasOverview and Spring.GetConfigInt("MinimapMinimize", 0) == 0) then
		if wasOverview and Spring.GetConfigInt("MinimapMinimize", 0) == 0 then
			gl.SlaveMiniMap(true)
			wasOverview = false
			Spring.SendCommands("minimap minimize 0")
		end

		if dlistGuishader and WG.guishader then
			WG.guishader.InsertDlist(dlistGuishader, "minimap")
		end
		if
			not uiBgTex
			and not externalFrame
			and backgroundRect[3] - backgroundRect[1] >= 1
			and backgroundRect[4] - backgroundRect[2] >= 1
			and gl.R2tHelper
		then
			uiBgTex = gl.CreateTexture(
				mathFloor(backgroundRect[3] - backgroundRect[1]),
				mathFloor(backgroundRect[4] - backgroundRect[2]),
				{
					target = GL.TEXTURE_2D,
					format = GL.RGBA8,
					fbo = true,
				}
			)
			gl.R2tHelper.RenderInRect(
				uiBgTex,
				backgroundRect[1],
				backgroundRect[2],
				backgroundRect[3],
				backgroundRect[4],
				drawBackground,
				true
			)
		end
		if uiBgTex and not externalFrame and gl.R2tHelper then
			gl.R2tHelper.BlendTexRect(
				uiBgTex,
				backgroundRect[1],
				backgroundRect[2],
				backgroundRect[3],
				backgroundRect[4],
				true
			)
		elseif not externalFrame then
			drawBackground()
		end
	end

	drawMiniMapSafe()
end

function widget:GetConfigData()
	return {}
end

function widget:SetConfigData(data)
	if data.maxHeight ~= nil and Spring.GetConfigFloat("MinimapMaxHeight", -1) == -1 then
		maxAllowedHeight = data.maxHeight
		Spring.SetConfigFloat("MinimapMaxHeight", data.maxHeight)
	end
	if data.leftClickMove ~= nil and Spring.GetConfigInt("MinimapLeftClickMove", -1) == -1 then
		leftClickMove = data.leftClickMove
		Spring.SetConfigInt("MinimapLeftClickMove", data.leftClickMove and 1 or 0)
	end
end

function widget:MouseMove(x, y)
	if not dualscreenMode then
		if leftclicked and leftClickMove then
			local px, py, pz = minimapToWorld(x, y, vpy)
			if py then
				Spring.SetCameraTarget(px, py, pz, 0.04)
			end
		end
	end
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() then
		return
	end
	if dualscreenMode then
		return
	end
	if minimized then
		return
	end
	if WG.chat and WG.chat.isMapDrawActive and WG.chat.isMapDrawActive() then
		return false
	end

	leftclicked = false

	if
		math_isInRect(
			x,
			y,
			backgroundRect[1],
			backgroundRect[2] - elementPadding,
			backgroundRect[3] + elementPadding,
			backgroundRect[4]
		)
	then
		local activeCmd = spGetActiveCommand()
		if activeCmd and activeCmd ~= 0 then
			return false
		end

		if
			not math_isInRect(x, y, backgroundRect[1], backgroundRect[2] + 1, backgroundRect[3] - 1, backgroundRect[4])
		then
			return true
		elseif button == 1 and leftClickMove then
			leftclicked = true
			local px, py, pz = minimapToWorld(x, y, vpy)
			if py then
				Spring.SetCameraTarget(px, py, pz, 0.2)
				return true
			end
		end
	end
end

function widget:MouseRelease(x, y, button)
	if dualscreenMode then
		return
	end

	leftclicked = false
end
