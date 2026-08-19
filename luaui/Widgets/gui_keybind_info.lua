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

local keybindEditor = VFS.Include("luaui/Include/keybind_editor_view.lua")

local doUpdate

local vsx, vsy = spGetViewGeometry()

local screenHeightOrg = 760
local screenWidthOrg = 1320
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
-- Input ownership is taken once on open and given back on close, rather than every
-- frame, so chat's handling is restored exactly as it was found.
local ownsInput = false
local panelHasInput = false
local textInputStarted = false
-- Keys already down when the panel opened. Their release has to be let through, or
-- whatever they started stays stuck on once the panel starts swallowing releases.
local heldAtOpen = {}

-- Panel backdrop, baked into a display list rather than redrawn per frame.
local function drawWindow()
	UiElement(screenX, screenY - screenHeight, screenX + screenWidth, screenY, 0, 1, 1, 1, 1,1,1,1, WG.FlowUI.clampedOpacity)
end

local function refreshText()
	keybindEditor.refresh()
end

-- Rebuilds every rect and display list against the new screen size.
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
		if WG.guishader then
			WG.guishader.DeleteDlist("keybindinfo")
		else
			glDeleteList(backgroundGuishader)
		end
		backgroundGuishader = nil
	end
end



-- Draws the panel and keeps the guishader rect in step with it.
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
		gl.Texture(false) -- some other widget left it on
		glCallList(keybinds)
		keybindEditor.draw()
		if WG.guishader and backgroundGuishader == nil then
			backgroundGuishader = glCreateList(function()
				RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 0, 1, 1, 1)
			end)
			WG.guishader.InsertDlist(backgroundGuishader, "keybindinfo")
		end
		showOnceMore = false

		local x, y, pressed = Spring.GetMouseState()
		if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
			Spring.SetMouseCursor("cursornormal")
		end
	else
		if backgroundGuishader ~= nil then
			if WG.guishader then
				WG.guishader.DeleteDlist("keybindinfo")
			else
				glDeleteList(backgroundGuishader)
			end
			backgroundGuishader = nil
		end
	end
end

-- The editor may want to ask about unsaved keybind changes first, in which case it
-- closes the panel itself once the player answers.
local function closePanel()
	keybindEditor.confirmClose(function()
		show = false
		keybindEditor.blur()
	end)
end

-- An open editor takes every key, so it never fires the binds being edited.
function widget:KeyPress(key, mods, isRepeat, label, unicode, scanCode)
	if not show then
		return false
	end

	-- The editor gets first refusal: a modal wants everything, and otherwise Escape may
	-- close a dropdown or cancel a capture before it reaches the panel itself.
	if not keybindEditor.keyPress(key, scanCode) and key == 27 then
		closePanel()
	end

	-- Nothing escapes an open editor: it must never fire the keybinds it is editing.
	return true
end

-- The engine runs bound actions on release as well as on press, so releases have to be
-- swallowed too. A key already down when the panel opened is let through instead, or
-- whatever it started stays stuck on.
function widget:KeyRelease(key, mods, label, unicode, scanCode, actions)
	if not show then
		return false
	end

	keybindEditor.keyRelease(key, scanCode)

	if heldAtOpen[key] then
		heldAtOpen[key] = nil

		return false
	end

	return true
end

function widget:TextInput(utf8char)
	if show then
		return keybindEditor.textInput(utf8char)
	end

	return false
end

-- Clicks inside the panel go to the editor; a click outside closes it.
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
		elseif not release then
			-- Only a press outside closes. A release out here belongs to a drag that started
			-- inside, which the handler routes to us wherever it ends up.
			showOnceMore = show -- show once more because the guishader lags behind
			closePanel()

			-- Consumed either way. With unsaved edits closePanel only raises the guard, so
			-- letting the click through would order units under an open modal.
			return true
		end
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

-- Swallowed across the whole panel, not just the list: a wheel that gets through zooms
-- the camera behind an open editor.
function widget:MouseWheel(up, value)
	if not show then
		return false
	end

	local x, y = Spring.GetMouseState()
	if not math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		return false
	end

	keybindEditor.mouseWheel(up, value)

	return true
end

-- Holds input ownership for as long as the panel is open.
function widget:Update()
	-- Re-snapshot the live keymap each time the panel opens so bindings made since
	-- (e.g. a runtime /bind) show without waiting for a preset switch or keyreload.
	if show and not wasShown then
		refreshText()
	end
	wasShown = show

	-- Text ownership is what puts this panel ahead of actionHandler, which otherwise runs
	-- before every widget and would fire the keybinds being edited. It has to go through
	-- OwnText: widgetHandler here is a per-widget proxy, so assigning textOwner on it just
	-- writes a dead field.
	if show then
		if not panelHasInput then
			panelHasInput = true
			heldAtOpen = Spring.GetPressedKeys and Spring.GetPressedKeys() or {}
			ownsInput = widgetHandler:OwnText()

			-- Chat has to be asked to let go, and toggling its input flag is the only public
			-- way to make it cancel. The flag goes straight back because gui_chat persists it,
			-- and a config save while the panel is open would leave chat input dead next
			-- launch. isInputActive is the accessor that means chat is holding input;
			-- getHandleInput is a saved option that reads true whoever the owner is, so poking
			-- on that cancels the settings search box or the widget selector's filter instead.
			if not ownsInput and WG.chat and WG.chat.isInputActive and WG.chat.isInputActive() then
				WG.chat.setHandleInput(false)
				WG.chat.setHandleInput(true)
				ownsInput = widgetHandler:OwnText()
			end
		elseif not ownsInput then
			ownsInput = widgetHandler:OwnText()
		end

		-- Only once it is ours. Starting SDL text input for a field we never took, then
		-- stopping it again on close, is what kills that field.
		if ownsInput and not textInputStarted then
			textInputStarted = true
			if Spring.SDLStartTextInput then
				Spring.SDLStartTextInput()
			end
		end
	elseif panelHasInput then
		panelHasInput = false
		if ownsInput then
			ownsInput = false
			widgetHandler:DisownText()
		end
		if textInputStarted then
			textInputStarted = false
			if Spring.SDLStopTextInput then
				Spring.SDLStopTextInput()
			end
		end
	end
end

-- Registers the panel's action, its WG surface and the build-menu hook.
function widget:Initialize()
	refreshText()

	widgetHandler:AddAction("keybindeditor", function()
		show = true
		doUpdate = true
		return true
	end, nil, "t")

	-- Sent as commands because widgetHandler here is a per-widget proxy, which carries no
	-- Enable/DisableWidget.
	keybindEditor.setMenuToggle(function(useGrid)
		if useGrid == nil then
			return
		end

		if useGrid then
			Spring.SendCommands("luaui disablewidget Build menu")
			Spring.SendCommands("luaui enablewidget Grid menu")
		else
			Spring.SendCommands("luaui disablewidget Grid menu")
			Spring.SendCommands("luaui enablewidget Build menu")
		end
	end)

	WG.keybinds = {}
	WG.keybinds.toggle = function(state)
		local wanted = state
		if wanted == nil then
			wanted = not show
		end

		if wanted then
			show = true
		else
			closePanel()
		end
	end
	WG.keybinds.isvisible = function()
		return show
	end
	WG.keybinds.reloadBindings = function()
		refreshText()
		doUpdate = true
	end
	widget:ViewResize()
end

-- Hands back input ownership and frees the display lists.
function widget:Shutdown()
	keybindEditor.blur()
	widgetHandler:DisownText()
	if ownsInput then
		ownsInput = false
		if Spring.SDLStopTextInput then
			Spring.SDLStopTextInput()
		end
	end
	if keybinds then
		glDeleteList(keybinds)
		keybinds = nil
	end
	if backgroundGuishader ~= nil then
		if WG.guishader then
			WG.guishader.DeleteDlist("keybindinfo")
		else
			glDeleteList(backgroundGuishader)
		end
		backgroundGuishader = nil
	end
end

-- Re-resolves every label against the new language.
function widget:LanguageChanged()
	refreshText()
	doUpdate = true
	widget:ViewResize()
end
