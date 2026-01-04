local widget = widget ---@type Widget

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


-- Localized functions for performance
local mathFloor = math.floor
local mathMin = math.min

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry

local useRenderToTexture = Spring.GetConfigFloat("ui_rendertotexture", 1) == 1		-- much faster than drawing via DisplayLists only

local minimapToWorld = VFS.Include("luaui/Include/minimap_utils.lua").minimapToWorld
local getCurrentMiniMapRotationOption = VFS.Include("luaui/Include/minimap_utils.lua").getCurrentMiniMapRotationOption
local ROTATION = VFS.Include("luaui/Include/minimap_utils.lua").ROTATION


local maxAllowedWidth = 0.26
local maxAllowedHeight = 0.32
local leftClickMove = true

local vsx, vsy, _, vpy = spGetViewGeometry()

local minimized = false
local maximized = false

local maxHeight = maxAllowedHeight
local ratio = Game.mapX / Game.mapY
local maxWidth = mathMin(maxHeight * ratio, maxAllowedWidth * (vsx / vsy))
local usedWidth = mathFloor(maxWidth * vsy)
local usedHeight = mathFloor(maxHeight * vsy)
local backgroundRect = { 0, 0, 0, 0 }

local delayedSetup = false
local sec = 0
local sec2 = 0
local lastRot = -1 --TODO: switch this to use MiniMapRotationChanged Callin when it is added to Engine

local spGetCameraState = Spring.GetCameraState
local spGetActiveCommand = Spring.GetActiveCommand
local math_isInRect = math.isInRect

local wasOverview = false
local leftclicked = false

local RectRound, UiElement, elementCorner, elementPadding, elementMargin
local dlistGuishader, dlistMinimap, oldMinimapGeometry

local dualscreenMode = ((Spring.GetConfigInt("DualScreenMode", 0) or 0) == 1)

local function checkGuishader(force)
	if WG['guishader'] then
		if force and dlistGuishader then
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader then
			dlistGuishader = gl.CreateList(function()
				RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], elementCorner)
			end)
			WG['guishader'].InsertDlist(dlistGuishader, 'minimap')
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

local function clear()
	dlistMinimap = gl.DeleteList(dlistMinimap)
	if uiBgTex then
		gl.DeleteTexture(uiBgTex)
		uiBgTex = nil
	end
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('minimap')
		dlistGuishader = nil
	end
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

	elementPadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner
	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	elementMargin = WG.FlowUI.elementMargin

	if WG['topbar'] ~= nil then
		local topbarArea = WG['topbar'].GetPosition()
		maxAllowedWidth = (topbarArea[1] - elementMargin - elementPadding) / vsx
	end

	maxWidth = mathMin(maxAllowedHeight * ratio, maxAllowedWidth * (vsx / vsy))
	if maxWidth >= maxAllowedWidth * (vsx / vsy) then
		maxHeight = maxWidth / ratio
	else
		maxHeight = maxAllowedHeight
	end

	usedWidth = mathFloor(maxWidth * vsy)
	usedHeight = mathFloor(maxHeight * vsy)

	backgroundRect = { 0, vsy - (usedHeight) - elementPadding, usedWidth + elementPadding, vsy }

	if not dualscreenMode then
		Spring.SendCommands(string.format("minimap geometry %i %i %i %i", 0, 0, usedWidth, usedHeight))
		checkGuishader(true)
	end
	dlistMinimap = gl.DeleteList(dlistMinimap)
	if uiBgTex then
		gl.DeleteTexture(uiBgTex)
		uiBgTex = nil
	end
end

function widget:Initialize()
	oldMinimapGeometry = Spring.GetMiniMapGeometry()
	gl.SlaveMiniMap(true)

	widget:ViewResize()

	if Spring.GetConfigInt("MinimapMinimize", 0) == 1 then
		Spring.SendCommands("minimap minimize 1")
	end
	_, _, _, _, minimized, maximized = Spring.GetMiniMapGeometry()

	WG['minimap'] = {}
	WG['minimap'].getHeight = function()
		return usedHeight + elementPadding
	end
	WG['minimap'].getMaxHeight = function()
		return mathFloor(maxAllowedHeight * vsy), maxAllowedHeight
	end
	WG['minimap'].setMaxHeight = function(value)
		maxAllowedHeight = value
		widget:ViewResize()
	end
	WG['minimap'].getLeftClickMove = function()
		return leftClickMove
	end
	WG['minimap'].setLeftClickMove = function(value)
		leftClickMove = value
	end
end

function widget:GameStart()
	widget:ViewResize()
end

function widget:Shutdown()
	clear()
	gl.SlaveMiniMap(false)

	if not dualscreenMode then
		Spring.SendCommands("minimap geometry " .. oldMinimapGeometry)
	end
end

function widget:Update(dt)
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
	if sec2 <= 0.25 then return end
	sec2 = 0

	if dualscreenMode then return end

	_, _, _, _, minimized, maximized = Spring.GetMiniMapGeometry()
	if minimized or maximized then
		return
	end

	Spring.SendCommands(string.format("minimap geometry %i %i %i %i", 0, 0, usedWidth, usedHeight))
	checkGuishader()
end



local function drawBackground()
	UiElement(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], 0, 0, 1, 0, nil, nil, nil, nil, nil, nil, nil, nil)
end

local st = spGetCameraState()
local stframe = 0
function widget:DrawScreen()

	if dualscreenMode and not minimized then
		gl.DrawMiniMap()
		return
	end

	if minimized or maximized then
		clear()
	else
		local x, y = Spring.GetMouseState()
		if math_isInRect(x, y, backgroundRect[1], backgroundRect[2] - elementPadding, backgroundRect[3] + elementPadding, backgroundRect[4]) then
			if not math_isInRect(x, y, backgroundRect[1], backgroundRect[2] + 1, backgroundRect[3] - 1, backgroundRect[4]) then
				Spring.SetMouseCursor('cursornormal')
			end
		end
	end

	stframe = stframe + 1
	if stframe % 10 == 0 then
		st = spGetCameraState()
	end
	if st.name == "ov" then
		-- overview camera
		if dlistGuishader and WG['guishader'] then
			WG['guishader'].RemoveDlist('minimap')
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		wasOverview = true

	elseif not (minimized or maximized) or (wasOverview and Spring.GetConfigInt("MinimapMinimize", 0) == 0) then
		if wasOverview and Spring.GetConfigInt("MinimapMinimize", 0) == 0 then
			gl.SlaveMiniMap(true)
			wasOverview = false
			Spring.SendCommands("minimap minimize 0")
		end


		if dlistGuishader and WG['guishader'] then
			WG['guishader'].InsertDlist(dlistGuishader, 'minimap')
		end
		if useRenderToTexture then
			if not uiBgTex and backgroundRect[3]-backgroundRect[1] >= 1 and backgroundRect[4]-backgroundRect[2] >= 1 then
				uiBgTex = gl.CreateTexture(mathFloor(backgroundRect[3]-backgroundRect[1]), mathFloor(backgroundRect[4]-backgroundRect[2]), {
					target = GL.TEXTURE_2D,
					format = GL.RGBA,
					fbo = true,
				})
				gl.R2tHelper.RenderToTexture(uiBgTex,
					function()
						gl.Translate(-1, -1, 0)
						gl.Scale(2 / (backgroundRect[3]-backgroundRect[1]), 2 / (backgroundRect[4]-backgroundRect[2]),	0)
						gl.Translate(-backgroundRect[1], -backgroundRect[2], 0)
						drawBackground()
					end,
					useRenderToTexture
				)
			end
			if uiBgTex then
				-- background element
				gl.R2tHelper.BlendTexRect(uiBgTex, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], useRenderToTexture)
			end
		else
			if not dlistMinimap then
				dlistMinimap = gl.CreateList(function()
					drawBackground()
				end)
			end
			gl.CallList(dlistMinimap)
		end
	end

	gl.DrawMiniMap()
end

function widget:GetConfigData()
	return {
		maxHeight = maxAllowedHeight,
		leftClickMove = leftClickMove
	}
end

function widget:SetConfigData(data)
	if data.maxHeight ~= nil then
		maxAllowedHeight = data.maxHeight
	end
	if data.leftClickMove ~= nil then
		leftClickMove = data.leftClickMove
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
	if Spring.IsGUIHidden() then return end
	if dualscreenMode then return end
	if minimized then return end

	leftclicked = false

	if math_isInRect(x, y, backgroundRect[1], backgroundRect[2] - elementPadding, backgroundRect[3] + elementPadding, backgroundRect[4]) then

		local activeCmd = spGetActiveCommand()
		if activeCmd and activeCmd ~= 0 then
			return false
		end

		if not math_isInRect(x, y, backgroundRect[1], backgroundRect[2] + 1, backgroundRect[3] - 1, backgroundRect[4]) then
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
	if dualscreenMode then return end

	leftclicked = false
end
