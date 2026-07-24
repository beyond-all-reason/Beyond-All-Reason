local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Keybind/Mouse Info",
		desc = "Provides information on the controls",
		author = "Bluestone",
		date = "April 2015",
		license = "GNU GPL, v2 or later, Mouthwash",
		layer = -99990,
		enabled = true,
	}
end


-- Localized functions for performance
local mathFloor = math.floor

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry

local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")
local keybindEditor = VFS.Include("luaui/Include/keybind_editor_view.lua")

local doUpdate

local vsx, vsy = spGetViewGeometry()

local screenHeightOrg = 550
local screenWidthOrg = 1050
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local RectRound, UiElement, elementCorner = WG.FlowUI.elementCorner

local showOnceMore = false


local widgetScale = (vsy / 1080)
local centerPosX = 0.5
local centerPosY = 0.5
local screenX = mathFloor((vsx * centerPosX) - (screenWidth / 2))
local screenY = mathFloor((vsy * centerPosY) + (screenHeight / 2))
local math_isInRect = math.isInRect

local keybinds, backgroundGuishader, show, wasShown

local function drawWindow()
	UiElement(screenX, screenY - screenHeight, screenX + screenWidth, screenY, 0, 1, 1, 1, 1,1,1,1, WG.FlowUI.clampedOpacity)
end

local function refreshText()
	keybindEditor.refresh()
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (vsy / 1080)

	screenHeight = mathFloor(screenHeightOrg * widgetScale)
	screenWidth = mathFloor(screenWidthOrg * widgetScale)
	screenX = mathFloor((vsx * centerPosX) - (screenWidth / 2))
	screenY = mathFloor((vsy * centerPosY) + (screenHeight / 2))

	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	keybindEditor.init()
	local pad = mathFloor(8 * widgetScale)
	keybindEditor.setArea(screenX + pad, screenY - screenHeight + pad, screenX + screenWidth - pad, screenY - pad, widgetScale)

	if keybinds then
		gl.DeleteList(keybinds)
	end
	keybinds = gl.CreateList(drawWindow)

	if backgroundGuishader ~= nil then
		if WG['guishader'] then
			WG['guishader'].DeleteDlist('keybindinfo')
		else
			glDeleteList(backgroundGuishader)
		end
		backgroundGuishader = nil
	end
end



function widget:DrawScreen()

	-- draw the help
	if doUpdate then
		if keybinds then
			gl.DeleteList(keybinds)
		end
		keybinds = gl.CreateList(drawWindow)

		doUpdate = false
	end

	if not keybinds then
		keybinds = glCreateList(drawWindow)
	end

	doUpdate = false

	if show or showOnceMore then
		gl.Texture(false)	-- some other widget left it on
		glCallList(keybinds)
		keybindEditor.draw()
		if WG['guishader'] and backgroundGuishader == nil then
			backgroundGuishader = glCreateList(function()
				RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 0, 1, 1, 1)
			end)
			WG['guishader'].InsertDlist(backgroundGuishader, 'keybindinfo')
		end
		showOnceMore = false

		local x, y, pressed = Spring.GetMouseState()
		if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY)  then
			Spring.SetMouseCursor('cursornormal')
		end
	else
		if backgroundGuishader ~= nil then
			if WG['guishader'] then
				WG['guishader'].DeleteDlist('keybindinfo')
			else
				glDeleteList(backgroundGuishader)
			end
			backgroundGuishader = nil
		end
	end
end

function widget:KeyPress(key, mods, isRepeat, label, unicode, scanCode)
	-- While capturing a key, the editor gets everything - its prompt says Esc cancels.
	if show and keybindEditor.isCapturing() then
		return keybindEditor.keyPress(key, scanCode)
	end

	-- Otherwise Escape closes the panel, like every other panel.
	if key == 27 then
		show = false
		keybindEditor.blur()
		return
	end

	if show and keybindEditor.keyPress(key, scanCode) then
		return true
	end
end

-- Some engine actions (cameraflip, volume, ...) execute on key-down without
-- routing the press through LuaUI, so capture can't see the press. We still
-- get the release, so fall back to capturing on release.
function widget:KeyRelease(key, mods, label, unicode, scanCode, actions)
	if show then
		return keybindEditor.keyRelease(key, scanCode)
	end

	return false
end

function widget:TextInput(utf8char)
	if show then
		return keybindEditor.textInput(utf8char)
	end

	return false
end

local function mouseEvent(x, y, button, release)
	if Spring.IsGUIHidden() then
		return false
	end

	if show then
		if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
			if not release then
				keybindEditor.mousePress(x, y, button)
			end
			return true
		else
			showOnceMore = show -- show once more because the guishader lags behind
			show = false
			keybindEditor.blur()
		end
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function widget:MouseWheel(up, value)
	if show then
		return keybindEditor.mouseWheel(up, value)
	end

	return false
end

function widget:Update()
	-- Re-snapshot the live keymap each time the panel opens so bindings made since
	-- (e.g. a runtime /bind) show without waiting for a preset switch or keyreload.
	if show and not wasShown then
		refreshText()
	end
	wasShown = show

	local want = show and keybindEditor.wantsTextOwner()
	if want then
		widgetHandler.textOwner = widget
	elseif widgetHandler.textOwner == widget then
		widgetHandler.textOwner = nil
	end
end

function widget:Initialize()
	refreshText()

	widgetHandler:AddAction("keybindeditor", function()
		show = true
		doUpdate = true
		return true
	end, nil, "t")

	keybindEditor.setMenuToggle(function(label)
		if not (widgetHandler.DisableWidget and widgetHandler.EnableWidget) then
			return
		end
		if label == "Custom" then
			return
		end
		if label:lower():find("grid", 1, true) then
			widgetHandler:DisableWidget('Build menu')
			widgetHandler:EnableWidget('Grid menu')
		else
			widgetHandler:DisableWidget('Grid menu')
			widgetHandler:EnableWidget('Build menu')
		end
	end)

	WG['keybinds'] = {}
	WG['keybinds'].toggle = function(state)
		if state ~= nil then
			show = state
		else
			show = not show
		end
		if not show then
			keybindEditor.blur()
		end
	end
	WG['keybinds'].isvisible = function()
		return show
	end
	WG['keybinds'].reloadBindings = function()
		refreshText()
		doUpdate = true
	end
	widget:ViewResize()
end

function widget:Shutdown()
	keybindEditor.blur()
	if widgetHandler.textOwner == widget then
		widgetHandler.textOwner = nil
	end
	if keybinds then
		glDeleteList(keybinds)
		keybinds = nil
	end
	if backgroundGuishader ~= nil then
		if WG['guishader'] then
			WG['guishader'].DeleteDlist('keybindinfo')
		else
			glDeleteList(backgroundGuishader)
		end
		backgroundGuishader = nil
	end
end

function widget:LanguageChanged()
	refreshText()
	doUpdate = true
	widget:ViewResize()
end
