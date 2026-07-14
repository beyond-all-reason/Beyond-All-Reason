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
local mathCeil = math.ceil
local mathFloor = math.floor
local mathMax = math.max

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry

local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")
local keybindEditor = VFS.Include("luaui/Include/keybind_editor_view.lua")

local tabs = {"Keybindings", "Grid Keys", "Grid CTRL Keys", "Grid ALT Keys", "Legacy Keys", "Legacy CTRL Keys", "Legacy ALT Keys",}

local keybindsimages = {
	["Grid Keys"]        = "luaui/images/keybinds/grid_keys.png",
	['Grid CTRL Keys']   = "luaui/images/keybinds/grid_keys_CTRL.png",
	['Grid ALT Keys']    = "luaui/images/keybinds/grid_keys_ALT.png",
	['Legacy Keys']      = "luaui/images/keybinds/legacy_keys.png",
	['Legacy CTRL Keys'] = "luaui/images/keybinds/legacy_keys_CTRL.png",
	['Legacy ALT Keys']  = "luaui/images/keybinds/legacy_keys_ALT.png",
}

local tabrects = {}
local lasttab = "Keybindings"

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

local keybindColor = "\255\235\185\070"
local titleColor = "\255\254\254\254"
local descriptionColor = "\255\192\190\180"

local widgetScale = (vsy / 1080)
local centerPosX = 0.5
local centerPosY = 0.5
local screenX = mathFloor((vsx * centerPosX) - (screenWidth / 2))
local screenY = mathFloor((vsy * centerPosY) + (screenHeight / 2))
local math_isInRect = math.isInRect

local font, font2, titleRect, keybinds, backgroundGuishader, show

local function drawWindow(activetab)
	local activetab = activetab or lasttab
	if activetab == nil then activetab = 'Keybindings' end

	-- background
	UiElement(screenX, screenY - screenHeight, screenX + screenWidth, screenY, 0, 1, 1, 1, 1,1,1,1, WG.FlowUI.clampedOpacity)

	local titleFontSize = 18 * widgetScale

	local tabx = 0
	for i,tab in ipairs(tabs) do
		local tabwidth = font2:GetTextWidth(tab)
		tabrects[tab] = {
			mathFloor(screenX + tabx),
			screenY,
			mathFloor(screenX + tabx + tabwidth * titleFontSize + (titleFontSize*1.5)),
			mathFloor(screenY + (titleFontSize*1.7)),
			tabx
		}
		tabx = tabx + (tabwidth  * titleFontSize +  (titleFontSize*1.5))
		gl.Color(0, 0, 0, WG.FlowUI.clampedOpacity)
		RectRound(tabrects[tab][1], tabrects[tab][2], tabrects[tab][3], tabrects[tab][4], elementCorner, 1, 1, 0, 0)
	end

	-- title
	font2:Begin()
	font2:SetTextColor(1, 1, 1, 1)
	font2:SetOutlineColor(0, 0, 0, 0.4)
	for i,tab in ipairs(tabs) do
		local tabcolor = keybindColor
		if tab ~= activetab then
			tabcolor = titleColor
		end
		font2:Print(tabcolor .. tab, screenX + (titleFontSize * 0.75) + tabrects[tab][5], screenY + (8*widgetScale), titleFontSize, "on")
	end
	font2:End()


	if keybindsimages[activetab] then
		gl.Color(1,1,1,1)
		gl.Texture(0, ":l:"..keybindsimages[activetab])
		local zoom = 0.05
		gl.TexRect(screenX,screenY - screenHeight, screenX + screenWidth, screenY, 0 + 0.02, 1 - zoom, 1 - 0.02 , 0 + zoom)
		gl.Texture(0, false)
	end
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

	font = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(2)

	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	keybindEditor.init()
	local pad = mathFloor(8 * widgetScale)
	local tabStripH = mathFloor(30 * widgetScale)
	keybindEditor.setArea(screenX + pad, screenY - screenHeight + pad, screenX + screenWidth - pad, screenY - tabStripH, widgetScale)

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
		if lasttab == "Keybindings" then
			keybindEditor.draw()
		end
		if WG['guishader'] and backgroundGuishader == nil then
			backgroundGuishader = glCreateList(function()
				-- background
				RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 0, 1, 1, 1)
				-- title
				for k, tabrect in pairs(tabrects) do
					RectRound(tabrect[1], tabrect[2], tabrect[3], tabrect[4], elementCorner, 1, 1, 0, 0)
				end
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
	if show and lasttab == "Keybindings" and keybindEditor.isCapturing() then
		return keybindEditor.keyPress(key, scanCode)
	end

	-- Otherwise Escape closes the panel, like every other panel.
	if key == 27 then
		show = false
		keybindEditor.blur()
		return
	end

	if show and lasttab == "Keybindings" and keybindEditor.keyPress(key, scanCode) then
		return true
	end
end

-- Some engine actions (cameraflip, volume, ...) execute on key-down without
-- routing the press through LuaUI, so capture can't see the press. We still
-- get the release, so fall back to capturing on release.
function widget:KeyRelease(key, mods, label, unicode, scanCode, actions)
	if show and lasttab == "Keybindings" then
		return keybindEditor.keyRelease(key, scanCode)
	end

	return false
end

function widget:TextInput(utf8char)
	if show and lasttab == "Keybindings" then
		return keybindEditor.textInput(utf8char)
	end

	return false
end

local function mouseEvent(x, y, button, release)
	if Spring.IsGUIHidden() then
		return false
	end

	if show then
		-- on window
		if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
			if not release and lasttab == "Keybindings" then
				keybindEditor.mousePress(x, y, button)
			end
			return true
		else
			for tab, tabrect in pairs(tabrects) do
				if math_isInRect(x, y, tabrect[1], tabrect[2], tabrect[3], tabrect[4]) then
					if keybinds then
						gl.DeleteList(keybinds)
					end
					lasttab = tab
					keybindEditor.blur()
					keybinds = gl.CreateList(drawWindow, tab)
					if backgroundGuishader ~= nil then
						if WG['guishader'] then
							WG['guishader'].DeleteDlist('keybindinfo')
						else
							glDeleteList(backgroundGuishader)
						end
						backgroundGuishader = nil
					end
					return true
				end
			end
			if release or not release then
				showOnceMore = show        -- show once more because the guishader lags behind, though this will not fully fix it
				show = false
				keybindEditor.blur()
			end
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
	if show and lasttab == "Keybindings" then
		return keybindEditor.mouseWheel(up, value)
	end

	return false
end

function widget:Update()
	local want = show and lasttab == "Keybindings" and keybindEditor.wantsTextOwner()
	if want then
		widgetHandler.textOwner = widget
	elseif widgetHandler.textOwner == widget then
		widgetHandler.textOwner = nil
	end
end

function widget:Initialize()
	refreshText()

	widgetHandler:AddAction("keybindeditor", function()
		lasttab = "Keybindings"
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
