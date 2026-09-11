local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Top Bar Buttons",
		desc = "The menu buttons at the top right, and the quit/resign dialog.",
		author = "Floris",
		date = "Feb, 2017",
		license = "GNU GPL, v2 or later",
		layer = -95000,
		enabled = true,
		handler = true, --can use widgetHandler:x()
		modalExempt = true, -- these buttons are how the player switches and closes windows
	}
end

-- Split out of the Top Bar widget: that one owns the resource bars, wind, tidal and
-- commander counter, this one owns the button strip in the top right corner and the
-- quit/resign dialog behind its quit button. The two share the WG.topbar table, each
-- filling in its own half of the API, so either can run without the other.

-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max
local mathIsInRect = math.isInRect

-- System
local spec = Spring.GetSpectatingState()
local myTeamID = Spring.GetLocalTeamID()
local myAllyTeamID = Spring.GetLocalAllyTeamID()
local myAllyTeamList = Spring.GetTeamList(myAllyTeamID)

-- Game mode / state
local numPlayers = BAR.Utilities.GetPlayerCount()
local isSinglePlayer = BAR.Utilities.Gametype.IsSinglePlayer()
local _modOpts = Spring.GetModOptions()
local isScenario = _modOpts ~= nil and _modOpts.scenariooptions ~= nil
local chobbyLoaded = false
local gameStarted = (Spring.GetGameFrame() > 0)
local gameIsOver = false
local graphsWindowVisible = false

-- Configuration. The geometry values mirror the Top Bar's, so the strip lines up with
-- the bar whether or not that widget is running.
local cfg = {
	relXpos = 0.3,
	borderPadding = 5,
	escapeKeyPressesQuit = false,
	allowSavegame = true,
	useSkew = true,
	smallElementHeightFraction = 0.85, -- buttons height as fraction of the top bar
}

-- OpenGL
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glBlending = gl.Blending
local glColor = gl.Color

-- UI elements
local topbarArea = {}
local buttonsArea = {}

-- UI state
local orgHeight = 46
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1)) or 1
local height = orgHeight * (1 + (ui_scale - 1) / 1.7)
local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (0.80 + (vsx * vsy / 6000000))
local xPos = mathFloor(vsx * cfg.relXpos)
local mx, my = -1, -1
local showButtons = true
local autoHideButtons = false
local hoveringButtons = false
local configLoaded = false
local refreshButtons = true
---@type number
local bgpadding
---@type fun(...)
local RectRound
---@type fun(...)
local UiElement
---@type fun(...)
local UiButton
---@type fun(...)
local RectRoundCircle
---@type any
local font
---@type any
local font2

-- Display lists
-- buttons:    the baked button labels and badges
-- background: the strip's panel chrome, also handed to the blur
-- quit:       the quit/resign dialog, rebuilt every frame while it is up
---@type table<string, integer>
local dlist = {}

-- Interactions
---@type any
local quitscreenArea
---@type any
local quitscreenStayArea
---@type any
local quitscreenQuitArea
---@type any
local quitscreenResignArea
---@type any
local quitscreenTeamResignArea
---@type any
local showQuitscreen
---@type any
local hideQuitWindow
---@type boolean
local teamResign = false

-- Audio
local playSounds = true
local leftclick = "LuaUI/Sounds/tock.wav"

-- Timers
local osClock = os.clock
local now = osClock()
local nextStateCheck = 0
local nextButtonCheck = 0
local blinkDirection = true
local blinkProgress = 0

--------------------------------------------------------------------------------
local function getPlayerLiveAllyCount()
	local nAllies = 0
	for _, teamID in ipairs(myAllyTeamList) do
		if teamID ~= myTeamID then
			local _, _, isDead, hasAI = Spring.GetTeamInfo(teamID, false)
			if not isDead and not hasAI then
				nAllies = nAllies + 1
			end
		end
	end
	return nAllies
end
local function updateButtons()
	local fontsize = (height * widgetScale) / 3

	-- if not buttonsArea['buttons'] then -- With this condition it doesn't actually update buttons if they were already added
	buttonsArea.buttons = {}

	local margin = bgpadding
	local textPadding = mathFloor(fontsize * 0.8)
	local sidePadding = textPadding
	local offset = sidePadding
	local lastbutton
	local badgeMinRadius = fontsize * 0.47
	local badgeFontsize = fontsize * 0.69

	-- badge: optional number shown in a circle at the bottom right of the button text
	local function addButton(name, text, badge)
		local textWidth = font2:GetTextWidth(text) * fontsize
		-- the circle grows along with the amount of characters the number has
		local badgeRadius = 0
		if badge then
			local badgeTextWidth = font2:GetTextWidth(badge) * badgeFontsize
			badgeRadius = mathMax(badgeMinRadius, (badgeTextWidth / 2) + (fontsize * 0.25))
		end
		local badgeWidth = badgeRadius * 2
		local width = mathFloor(textWidth + badgeWidth + textPadding)
		local textCenter = buttonsArea[3] - offset - (width / 2) - (badgeWidth / 2)
		buttonsArea.buttons[name] = {
			buttonsArea[3] - offset - width,
			buttonsArea[2] + margin,
			buttonsArea[3] - offset,
			buttonsArea[4],
			text,
			textCenter,
		}
		if badge then
			local button = buttonsArea.buttons[name]
			button[7] = {
				text = badge,
				x = textCenter + (textWidth / 2) + badgeRadius + (1.5 * widgetScale),
				-- slightly below the center of the button text, so it sits at its bottom right
				y = button[2] + ((button[4] - button[2]) * 0.5) - (fontsize / 5) + (fontsize * 0.15),
				radius = badgeRadius,
				fontsize = badgeFontsize,
			}
		end
		if not lastbutton then
			buttonsArea.buttons[name][3] = buttonsArea[3]
		end
		offset = mathFloor(offset + width + 0.5)
		lastbutton = name
	end

	if not gameIsOver and chobbyLoaded then
		addButton("quit", BAR.I18N("ui.topbar.button.lobby"))
	else
		addButton("quit", BAR.I18N("ui.topbar.button.quit"))
	end
	if not gameIsOver and not spec and gameStarted and not isSinglePlayer then
		addButton("resign", BAR.I18N("ui.topbar.button.resign"))
	end

	if WG.options then
		addButton("options", BAR.I18N("ui.topbar.button.settings"))
	end
	if WG.keybinds then
		addButton("keybinds", BAR.I18N("ui.topbar.button.keys"))
	end
	if WG.changelog and not isScenario then
		addButton("changelog", BAR.I18N("ui.topbar.button.changes"))
	end
	if WG.teamstats and not isScenario then
		addButton("stats", BAR.I18N("ui.topbar.button.stats"))
	end
	-- only shown when settings differ from their default, the amount of them is put in the badge
	if WG.gameinfo and (not isSinglePlayer or BAR.Utilities.ShowDevUI()) then
		local changedCount = WG.gameinfo.getChangedModoptionsCount and WG.gameinfo.getChangedModoptionsCount() or 0
		if changedCount > 0 then
			addButton("info", BAR.I18N("ui.topbar.button.info"), tostring(changedCount))
		end
	end
	if gameIsOver then
		addButton("graphs", BAR.I18N("ui.topbar.button.graphs"))
	end
	if WG.scavengerinfo then
		addButton("scavengers", BAR.I18N("ui.topbar.button.scavengers"))
	end
	if isScenario and WG.missioninfo then
		addButton("mission", BAR.I18N("ui.topbar.button.mission"))
	end
	if isSinglePlayer and cfg.allowSavegame and WG.savegame then
		addButton("save", BAR.I18N("ui.topbar.button.save"))
	end

	buttonsArea.buttons[lastbutton][1] = buttonsArea.buttons[lastbutton][1] - sidePadding
	offset = offset + sidePadding
	buttonsArea[1] = buttonsArea[3] - offset - margin

	if dlist.buttons then
		glDeleteList(dlist.buttons)
	end
	dlist.buttons = glCreateList(function()
		for _, params in pairs(buttonsArea.buttons) do
			local badge = params[7]
			if badge then
				-- corner size 0.586 x radius makes it a regular octagon, which reads as a circle at this size
				-- the dark circle below the smaller colored one acts as its outline
				local outlineColor = { 0.18, 0.18, 0.18, 1 }
				local badgeColor = { 0.66, 0.66, 0.66, 1 }
				local innerRadius = badge.radius - mathMax(1, badge.radius * 0.15)
				RectRoundCircle(badge.x, badge.y, badge.radius, badge.radius * 0.586, 0, outlineColor, outlineColor)
				RectRoundCircle(badge.x, badge.y, innerRadius, innerRadius * 0.586, 0, badgeColor, badgeColor)
			end
		end
		font2:Begin(true)
		font2:SetTextColor(0.92, 0.92, 0.92, 1)
		font2:SetOutlineColor(0, 0, 0, 1)
		for name, params in pairs(buttonsArea.buttons) do
			font2:Print(
				params[5],
				params[6],
				params[2] + ((params[4] - params[2]) * 0.5) - (fontsize / 5),
				fontsize,
				"co"
			)
			local badge = params[7]
			if badge then
				font2:SetTextColor(0.08, 0.08, 0.08, 1)
				font2:Print(badge.text, badge.x, badge.y - (badge.fontsize * 0.32), badge.fontsize, "c")
				font2:SetTextColor(0.92, 0.92, 0.92, 1)
			end
		end
		font2:End()
	end)
end

-- The strip's panel chrome. Baked once per layout change and also handed to the blur,
-- which only reads its coverage.
local function rebuildBackground()
	if dlist.background then
		if WG.guishader then
			WG.guishader.RemoveDlist("topbar_buttons")
		end
		dlist.background = glDeleteList(dlist.background)
	end
	if not buttonsArea[1] then
		return
	end
	dlist.background = glCreateList(function()
		-- only the bottom left corner is rounded: the other three sit against the screen edge
		UiElement(
			buttonsArea[1],
			buttonsArea[2],
			buttonsArea[3],
			buttonsArea[4],
			0,
			0,
			0,
			1,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil
		)
	end)
	if WG.guishader then
		WG.guishader.InsertDlist(dlist.background, "topbar_buttons", nil, widget)
	end
end

-- Mirrors the Top Bar's own geometry so the strip lines up with the bar, without
-- depending on that widget being loaded.
local function updateLayout()
	widgetScale = (vsy / height) * 0.0425 * ui_scale
	xPos = mathFloor(vsx * cfg.relXpos)
	topbarArea = { mathFloor(xPos + (cfg.borderPadding * widgetScale)), mathFloor(vsy - (height * widgetScale)), vsx, vsy }

	-- Small elements (wind, tidal, coms, buttons) are top-aligned to a fraction of the
	-- bar height when skew is on.
	local smallVPad = cfg.useSkew
			and mathFloor((topbarArea[4] - topbarArea[2]) * (1 - cfg.smallElementHeightFraction))
		or 0
	local width = mathFloor((topbarArea[3] - topbarArea[1]) / 4)
	buttonsArea = { topbarArea[3] - width, topbarArea[2] + smallVPad, topbarArea[3], topbarArea[4] }

	updateButtons()
	rebuildBackground()
end

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()

	bgpadding = WG.FlowUI.elementPadding
	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button
	RectRoundCircle = WG.FlowUI.Draw.RectRoundCircle

	font = WG.fonts.getFont()
	font2 = WG.fonts.getFont(2)

	updateLayout()
end

local function drawQuitScreen()
	local fadeTime = 0.2
	local fadeProgress = (now - showQuitscreen) / fadeTime
	if fadeProgress > 1 then
		fadeProgress = 1
	end

	Spring.SetMouseCursor("cursornormal")

	dlist.quit = glCreateList(function()
		if WG.guishader then
			glColor(0, 0, 0, (0.18 * fadeProgress))
		else
			glColor(0, 0, 0, (0.35 * fadeProgress))
		end

		gl.Rect(0, 0, vsx, vsy)

		if not hideQuitWindow then
			-- when terminating spring, keep the faded screen

			local w = mathFloor(320 * widgetScale)
			local h = mathFloor(w / 3.5)

			local fontSize = h / 6
			local text = BAR.I18N("ui.topbar.quit.reallyQuit")
			teamResign = false

			if not spec then
				text = BAR.I18N("ui.topbar.quit.reallyQuitResign")
				if not gameIsOver and chobbyLoaded then
					if numPlayers < 3 then
						text = BAR.I18N("ui.topbar.quit.reallyResign")
					else
						if getPlayerLiveAllyCount() >= 1 then
							teamResign = true
						end
						text = BAR.I18N("ui.topbar.quit.reallyResignSpectate")
					end
				end
			end

			local padding = mathFloor(w / 90)
			local textTopPadding = padding + padding + padding + padding + padding + fontSize
			local txtWidth = font:GetTextWidth(text) * fontSize
			w = mathMax(w, txtWidth + textTopPadding + textTopPadding)

			local x = mathFloor((vsx / 2) - (w / 2))
			local y = mathFloor((vsy / 1.8) - (h / 2))
			local maxButtons = teamResign and 5 or 4
			local buttonMargin = mathFloor(h / 9)
			local buttonWidth = mathFloor((w - buttonMargin * maxButtons) / (maxButtons - 1)) -- maxButtons+1 margins for maxButtons buttons
			local buttonHeight = mathFloor(h * 0.30)

			quitscreenArea = { x, y, x + w, y + h }

			if teamResign then
				quitscreenArea[2] = quitscreenArea[2] - mathFloor(fontSize * 1.7)
			end

			quitscreenStayArea = {
				x + buttonMargin + 0 * (buttonWidth + buttonMargin),
				y + buttonMargin,
				x + buttonMargin + 0 * (buttonWidth + buttonMargin) + buttonWidth,
				y + buttonMargin + buttonHeight,
			}
			quitscreenResignArea = {
				x + buttonMargin + 1 * (buttonWidth + buttonMargin),
				y + buttonMargin,
				x + buttonMargin + 1 * (buttonWidth + buttonMargin) + buttonWidth,
				y + buttonMargin + buttonHeight,
			}
			local nextButton = 2
			if teamResign then
				quitscreenTeamResignArea = {
					x + buttonMargin + nextButton * (buttonWidth + buttonMargin),
					y + buttonMargin,
					x + buttonMargin + nextButton * (buttonWidth + buttonMargin) + buttonWidth,
					y + buttonMargin + buttonHeight,
				}
				nextButton = nextButton + 1
			end
			quitscreenQuitArea = {
				x + buttonMargin + nextButton * (buttonWidth + buttonMargin),
				y + buttonMargin,
				x + buttonMargin + nextButton * (buttonWidth + buttonMargin) + buttonWidth,
				y + buttonMargin + buttonHeight,
			}

			-- window
			UiElement(
				quitscreenArea[1],
				quitscreenArea[2],
				quitscreenArea[3],
				quitscreenArea[4],
				1,
				1,
				1,
				1,
				1,
				1,
				1,
				1,
				nil,
				{ 1, 1, 1, 0.6 + (0.34 * fadeProgress) },
				{ 0.45, 0.45, 0.4, 0.025 + (0.025 * fadeProgress) },
				nil
			)
			local color1, color2

			font:Begin(true)
			font:SetTextColor(0, 0, 0, 1)
			font:Print(
				text,
				quitscreenArea[1] + ((quitscreenArea[3] - quitscreenArea[1]) / 2),
				quitscreenArea[4] - textTopPadding,
				fontSize,
				"cn"
			)
			font:End()

			font2:Begin(true)
			font2:SetTextColor(1, 1, 1, 1)
			font2:SetOutlineColor(0, 0, 0, 0.23)

			fontSize = fontSize * 0.92

			-- stay button
			if gameIsOver or not chobbyLoaded then
				if
					mathIsInRect(
						mx,
						my,
						quitscreenStayArea[1],
						quitscreenStayArea[2],
						quitscreenStayArea[3],
						quitscreenStayArea[4]
					)
				then
					color1 = { 0, 0.4, 0, 0.4 + (0.5 * fadeProgress) }
					color2 = { 0.05, 0.6, 0.05, 0.4 + (0.5 * fadeProgress) }
				else
					color1 = { 0, 0.25, 0, 0.35 + (0.5 * fadeProgress) }
					color2 = { 0, 0.5, 0, 0.35 + (0.5 * fadeProgress) }
				end
				UiButton(
					quitscreenStayArea[1],
					quitscreenStayArea[2],
					quitscreenStayArea[3],
					quitscreenStayArea[4],
					1,
					1,
					1,
					1,
					1,
					1,
					1,
					1,
					nil,
					color1,
					color2,
					padding * 0.5
				)
				font2:Print(
					BAR.I18N("ui.topbar.quit.stay"),
					quitscreenStayArea[1] + ((quitscreenStayArea[3] - quitscreenStayArea[1]) / 2),
					quitscreenStayArea[2] + ((quitscreenStayArea[4] - quitscreenStayArea[2]) / 2) - (fontSize / 3),
					fontSize,
					"con"
				)
			end

			-- resign button
			if not spec and not gameIsOver then
				local mouseOver = false
				if
					mathIsInRect(
						mx,
						my,
						quitscreenResignArea[1],
						quitscreenResignArea[2],
						quitscreenResignArea[3],
						quitscreenResignArea[4]
					)
				then
					color1 = { 0.4, 0, 0, 0.4 + (0.5 * fadeProgress) }
					color2 = { 0.6, 0.05, 0.05, 0.4 + (0.5 * fadeProgress) }
					mouseOver = "resign"
				else
					color1 = { 0.25, 0, 0, 0.35 + (0.5 * fadeProgress) }
					color2 = { 0.5, 0, 0, 0.35 + (0.5 * fadeProgress) }
				end
				UiButton(
					quitscreenResignArea[1],
					quitscreenResignArea[2],
					quitscreenResignArea[3],
					quitscreenResignArea[4],
					1,
					1,
					1,
					1,
					1,
					1,
					1,
					1,
					nil,
					color1,
					color2,
					padding * 0.5
				)
				font2:Print(
					BAR.I18N("ui.topbar.quit.resign"),
					quitscreenResignArea[1] + ((quitscreenResignArea[3] - quitscreenResignArea[1]) / 2),
					quitscreenResignArea[2] + ((quitscreenResignArea[4] - quitscreenResignArea[2]) / 2) - (fontSize / 3),
					fontSize,
					"con"
				)

				if teamResign then
					if
						mathIsInRect(
							mx,
							my,
							quitscreenTeamResignArea[1],
							quitscreenTeamResignArea[2],
							quitscreenTeamResignArea[3],
							quitscreenTeamResignArea[4]
						)
					then
						color1 = { 0.28, 0.28, 0.28, 0.4 + (0.5 * fadeProgress) }
						color2 = { 0.45, 0.45, 0.45, 0.4 + (0.5 * fadeProgress) }
						mouseOver = "teamResign"
					else
						color1 = { 0.18, 0.18, 0.18, 0.4 + (0.5 * fadeProgress) }
						color2 = { 0.33, 0.33, 0.33, 0.4 + (0.5 * fadeProgress) }
					end
					UiButton(
						quitscreenTeamResignArea[1],
						quitscreenTeamResignArea[2],
						quitscreenTeamResignArea[3],
						quitscreenTeamResignArea[4],
						1,
						1,
						1,
						1,
						1,
						1,
						1,
						1,
						nil,
						color1,
						color2,
						padding * 0.5
					)
					font2:Print(
						BAR.I18N("ui.topbar.quit.teamResign"),
						quitscreenTeamResignArea[1] + ((quitscreenTeamResignArea[3] - quitscreenTeamResignArea[1]) / 2),
						quitscreenTeamResignArea[2]
							+ ((quitscreenTeamResignArea[4] - quitscreenTeamResignArea[2]) / 2)
							- (fontSize / 3),
						fontSize,
						"con"
					)
				end
				if mouseOver and teamResign then
					font:Print(
						BAR.I18N("ui.topbar.hint." .. mouseOver),
						quitscreenTeamResignArea[1] - buttonMargin,
						quitscreenArea[2] + (2.5 * fontSize / 3),
						fontSize * 0.9,
						"cn"
					)
				end
			end

			-- quit button
			if gameIsOver or not chobbyLoaded then
				if
					mathIsInRect(
						mx,
						my,
						quitscreenQuitArea[1],
						quitscreenQuitArea[2],
						quitscreenQuitArea[3],
						quitscreenQuitArea[4]
					)
				then
					color1 = { 0.4, 0, 0, 0.4 + (0.5 * fadeProgress) }
					color2 = { 0.6, 0.05, 0.05, 0.4 + (0.5 * fadeProgress) }
				else
					color1 = { 0.25, 0, 0, 0.35 + (0.5 * fadeProgress) }
					color2 = { 0.5, 0, 0, 0.35 + (0.5 * fadeProgress) }
				end
				UiButton(
					quitscreenQuitArea[1],
					quitscreenQuitArea[2],
					quitscreenQuitArea[3],
					quitscreenQuitArea[4],
					1,
					1,
					1,
					1,
					1,
					1,
					1,
					1,
					nil,
					color1,
					color2,
					padding * 0.5
				)
				font2:Print(
					BAR.I18N("ui.topbar.quit.quit"),
					quitscreenQuitArea[1] + ((quitscreenQuitArea[3] - quitscreenQuitArea[1]) / 2),
					quitscreenQuitArea[2] + ((quitscreenQuitArea[4] - quitscreenQuitArea[2]) / 2) - (fontSize / 3),
					fontSize,
					"con"
				)
			end

			font2:End()
		end
	end)

	-- background
	if WG.guishader then
		WG.guishader.setScreenBlur(true)
		WG.guishader.insertRenderDlist(dlist.quit)
	else
		glCallList(dlist.quit)
	end
end
-- Second return value: the window refused to close (the keybind editor raises a guard
-- when there are unsaved edits) and is still up.
local function closeWindow(name)
	if WG[name] ~= nil and WG[name].isvisible() then
		WG[name].toggle(false)
		return true, WG[name].isvisible() == true
	end
	return false, false
end

local function hideWindows()
	local closedWindow = false
	local stillOpen = false

	local function hide(name)
		local closed, blocked = closeWindow(name)
		closedWindow = closed or closedWindow
		stillOpen = blocked or stillOpen
	end

	hide("options")
	hide("scavengerinfo")
	hide("missioninfo")
	hide("keybinds")
	hide("changelog")
	hide("gameinfo")
	hide("teamstats")
	hide("widgetselector")
	if showQuitscreen then
		closedWindow = true
	end

	showQuitscreen = nil

	if WG.guishader then
		WG.guishader.setScreenBlur(false)
	end

	if gameIsOver then -- Graphs window can only be open after game end
		-- Closing Graphs window if open, no way to tell if it was open or not
		Spring.SendCommands("endgraph 0")
		graphsWindowVisible = false
	end

	return closedWindow, stillOpen
end

local function toggleWindow(name)
	local isvisible = false
	if WG[name] ~= nil then
		isvisible = WG[name].isvisible()
	end
	local _, stillOpen = hideWindows()
	-- Opening another window on top of a window that refused to close would bury its guard.
	if stillOpen then
		return isvisible
	end
	if WG[name] ~= nil and isvisible ~= true then
		WG[name].toggle()
	end
	return isvisible
end
-- Which menu button, if any, sits under these screen coords.
-- Exposed as WG.topbar.buttonAt so the window widgets (which sit on a lower layer and
-- therefore see the click first) can tell a click on the top bar apart from a click that
-- dismisses them: closing themselves there would eat the click meant to open another window.
local function buttonAt(x, y)
	if not buttonsArea.buttons then
		return nil
	end
	for name, pos in pairs(buttonsArea.buttons) do
		if mathIsInRect(x, y, pos[1], pos[2], pos[3], pos[4]) then
			return name
		end
	end
	return nil
end

local function applyButtonAction(button)
	if playSounds then
		Spring.PlaySoundFile(leftclick, 0.8, "ui")
	end

	local isvisible = false
	if button == "quit" or button == "resign" then
		if not gameIsOver and chobbyLoaded and button == "quit" then
			Spring.SendLuaMenuMsg("showLobby")
		else
			local oldShowQuitscreen
			if showQuitscreen then
				oldShowQuitscreen = showQuitscreen
				isvisible = true
			end

			hideWindows()

			if oldShowQuitscreen then
				if isvisible ~= true then
					showQuitscreen = oldShowQuitscreen
					if WG.guishader then
						WG.guishader.setScreenBlur(true)
					end
				end
			else
				showQuitscreen = now
			end
		end
	elseif button == "options" then
		toggleWindow("options")
	elseif button == "save" then
		hideWindows()
		if isSinglePlayer and cfg.allowSavegame and WG.savegame then
			local time = os.date("%Y%m%d_%H%M%S")
			Spring.SendCommands("savegame " .. time)
		end
	elseif button == "scavengers" then
		toggleWindow("scavengerinfo")
	elseif button == "mission" then
		toggleWindow("missioninfo")
	elseif button == "keybinds" then
		toggleWindow("keybinds")
	elseif button == "changelog" then
		toggleWindow("changelog")
	elseif button == "stats" then
		toggleWindow("teamstats")
	elseif button == "info" then
		toggleWindow("gameinfo")
	elseif button == "graphs" then
		isvisible = graphsWindowVisible
		hideWindows()
		if gameIsOver and not isvisible then
			Spring.SendCommands("endgraph 2")
			graphsWindowVisible = true
		end
	end
end
function widget:DrawScreen()
	now = osClock()

	if hoveringButtons then
		Spring.SetMouseCursor("cursornormal")
	end

	if refreshButtons then
		refreshButtons = false
		updateButtons()
		rebuildBackground()
	end

	if autoHideButtons then
		if buttonsArea[1] and hoveringButtons then
			if not showButtons then
				showButtons = true
			end
		elseif showButtons then
			showButtons = false
		end
	end

	if showButtons then
		if dlist.background then
			glCallList(dlist.background)
		end
		if dlist.buttons then
			glCallList(dlist.buttons)
		end
	end

	if showButtons and dlist.buttons and buttonsArea.buttons then
		-- changelog changes highlight
		if WG.changelog and WG.changelog.haschanges() then
			local button = "changelog"
			if buttonsArea.buttons[button] then
				local paddingsize = 1
				RectRound(
					buttonsArea.buttons[button][1] + paddingsize,
					buttonsArea.buttons[button][2] + paddingsize,
					buttonsArea.buttons[button][3] - paddingsize,
					buttonsArea.buttons[button][4] - paddingsize,
					3.5 * widgetScale,
					0,
					0,
					0,
					0,
					{ 1, 1, 1, 0.1 * blinkProgress }
				)
			end
		end

		-- hovered?
		if not showQuitscreen and buttonsArea.buttons and hoveringButtons then
			for button, pos in pairs(buttonsArea.buttons) do
				if mathIsInRect(mx, my, pos[1], pos[2], pos[3], pos[4]) then
					local paddingsize = 1
					RectRound(
						buttonsArea.buttons[button][1] + paddingsize,
						buttonsArea.buttons[button][2] + paddingsize,
						buttonsArea.buttons[button][3] - paddingsize,
						buttonsArea.buttons[button][4] - paddingsize,
						3.5 * widgetScale,
						0,
						0,
						0,
						0,
						{ 0, 0, 0, 0.06 }
					)
					glBlending(GL.SRC_ALPHA, GL.ONE)
					RectRound(
						buttonsArea.buttons[button][1],
						buttonsArea.buttons[button][2],
						buttonsArea.buttons[button][3],
						buttonsArea.buttons[button][4],
						3.5 * widgetScale,
						0,
						0,
						0,
						0,
						{ 1, 1, 1, 0.03 },
						{ 0.44, 0.44, 0.44, 0.2 }
					)
					local mult = 1
					RectRound(
						buttonsArea.buttons[button][1],
						buttonsArea.buttons[button][4]
							- ((buttonsArea.buttons[button][4] - buttonsArea.buttons[button][2]) * 0.4),
						buttonsArea.buttons[button][3],
						buttonsArea.buttons[button][4],
						3.3 * widgetScale,
						0,
						0,
						0,
						0,
						{ 1, 1, 1, 0 },
						{ 1, 1, 1, 0.18 * mult }
					)
					RectRound(
						buttonsArea.buttons[button][1],
						buttonsArea.buttons[button][2],
						buttonsArea.buttons[button][3],
						buttonsArea.buttons[button][2]
							+ ((buttonsArea.buttons[button][4] - buttonsArea.buttons[button][2]) * 0.25),
						3.3 * widgetScale,
						0,
						0,
						0,
						0,
						{ 1, 1, 1, 0.045 * mult },
						{ 1, 1, 1, 0 }
					)
					glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
					break
				end
			end
		end
	end
	if dlist.quit then
		if WG.guishader then
			WG.guishader.removeRenderDlist(dlist.quit)
		end
		glDeleteList(dlist.quit)
		dlist.quit = nil
	end

	if showQuitscreen then
		drawQuitScreen()
	end

	glColor(1, 1, 1, 1)
end

function widget:MousePress(x, y, button)
	if button == 1 then
		if showQuitscreen and quitscreenArea then
			if mathIsInRect(x, y, quitscreenArea[1], quitscreenArea[2], quitscreenArea[3], quitscreenArea[4]) then
				if
					(gameIsOver or not chobbyLoaded or not spec)
					and mathIsInRect(
						x,
						y,
						quitscreenStayArea[1],
						quitscreenStayArea[2],
						quitscreenStayArea[3],
						quitscreenStayArea[4]
					)
				then
					if playSounds then
						Spring.PlaySoundFile(leftclick, 0.75, "ui")
					end

					showQuitscreen = nil
					if WG.guishader then
						WG.guishader.setScreenBlur(false)
					end
				end
				if
					(gameIsOver or not chobbyLoaded)
					and mathIsInRect(
						x,
						y,
						quitscreenQuitArea[1],
						quitscreenQuitArea[2],
						quitscreenQuitArea[3],
						quitscreenQuitArea[4]
					)
				then
					if playSounds then
						Spring.PlaySoundFile(leftclick, 0.75, "ui")
					end

					if not chobbyLoaded then
						Spring.SendCommands("QuitForce") -- Exit the game completely
					else
						Spring.SendCommands("ReloadForce") -- Exit to the lobby
					end

					showQuitscreen = nil
					hideQuitWindow = now
				end
				if
					not spec
					and not gameIsOver
					and mathIsInRect(
						x,
						y,
						quitscreenResignArea[1],
						quitscreenResignArea[2],
						quitscreenResignArea[3],
						quitscreenResignArea[4]
					)
				then
					if playSounds then
						Spring.PlaySoundFile(leftclick, 0.75, "ui")
					end
					Spring.SendCommands("spectator")
					showQuitscreen = nil
					if WG.guishader then
						WG.guishader.setScreenBlur(false)
					end
				end
				if
					not spec
					and not gameIsOver
					and teamResign
					and mathIsInRect(
						x,
						y,
						quitscreenTeamResignArea[1],
						quitscreenTeamResignArea[2],
						quitscreenTeamResignArea[3],
						quitscreenTeamResignArea[4]
					)
				then
					if playSounds then
						Spring.PlaySoundFile(leftclick, 0.75, "ui")
					end
					Spring.SendCommands("say !cv resign")
					showQuitscreen = nil
					if WG.guishader then
						WG.guishader.setScreenBlur(false)
					end
				end
			else
				showQuitscreen = nil
				if WG.guishader then
					WG.guishader.setScreenBlur(false)
				end
			end
			return true
		end

		local clickedButton = buttonAt(x, y)
		if clickedButton then
			applyButtonAction(clickedButton)
			return true
		end
	else
		if showQuitscreen and quitscreenArea then
			return true
		end
	end

	-- a click on the strip itself never falls through to the world
	if hoveringButtons then
		return true
	end
end

function widget:MouseWheel(up, value) -- up = true/false , value = -1/1
	if showQuitscreen and quitscreenArea then
		return true
	end
end

function widget:KeyPress(key)
	if key == 27 then -- ESC
		if not WG.options or (WG.options.disallowEsc and not WG.options.disallowEsc()) then
			local escDidSomething = hideWindows()
			if cfg.escapeKeyPressesQuit and not escDidSomething then
				applyButtonAction("quit")
			end
		end
	end
	if showQuitscreen and quitscreenArea then
		return true
	end
end
-- WG.topbar is shared with the Top Bar widget. Consumers guard on the table, not on the
-- individual functions, so when that widget is not running its half of the API has to be
-- filled in rather than left missing. Checked from Update, which runs after every
-- widget's Initialize and again if the Top Bar is disabled mid-game.
local fallback = {}

local function provide(name, fn)
	local current = WG.topbar[name]
	if current == nil then
		fallback[name] = fn
		WG.topbar[name] = fn
	elseif fallback[name] ~= nil and current ~= fallback[name] then
		fallback[name] = nil -- the Top Bar widget took over
	end
end

local function noop() end
local function returnFalse()
	return false
end

local function provideTopBarFallbacks()
	if not WG.topbar then
		return
	end
	provide("GetPosition", function()
		return { topbarArea[1], topbarArea[2], topbarArea[3], topbarArea[4], widgetScale, buttonsArea[2] }
	end)
	provide("GetFreeArea", function()
		-- no resource bars to make room for, so everything left of the strip is free
		return { topbarArea[1], topbarArea[2], buttonsArea[1], topbarArea[4], widgetScale }
	end)
	provide("GetSkewConfig", function()
		return {
			useSkew = cfg.useSkew,
			skewTan = math.tan(math.rad(20)),
			smallElementHeightFraction = cfg.smallElementHeightFraction,
		}
	end)
	-- there are no resource bars or indicators to show, hide or update
	provide("updateTopBarEnergy", noop)
	provide("setResourceBarsVisible", noop)
	provide("setIndicatorsVisible", noop)
	provide("getResourceBarsVisible", returnFalse)
	provide("getIndicatorsVisible", returnFalse)
end

local function removeFallbacks()
	if not WG.topbar then
		return
	end
	for name, fn in pairs(fallback) do
		if WG.topbar[name] == fn then
			WG.topbar[name] = nil
		end
	end
end

-- Which buttons exist depends on widgets that may load after this one (game info, save
-- game, the scenario panels) and on game state, so the set is re-checked periodically
-- instead of only at startup.
local buttonSignature = ""
local function currentButtonSignature()
	local changedModoptions = 0
	if WG.gameinfo and WG.gameinfo.getChangedModoptionsCount then
		changedModoptions = WG.gameinfo.getChangedModoptionsCount() or 0
	end
	return table.concat({
		WG.options and 1 or 0,
		WG.keybinds and 1 or 0,
		WG.changelog and 1 or 0,
		WG.teamstats and 1 or 0,
		WG.scavengerinfo and 1 or 0,
		WG.missioninfo and 1 or 0,
		WG.savegame and 1 or 0,
		changedModoptions,
		gameIsOver and 1 or 0,
		gameStarted and 1 or 0,
		spec and 1 or 0,
		chobbyLoaded and 1 or 0,
	}, ",")
end

function widget:Update(dt)
	now = osClock()

	provideTopBarFallbacks()

	if now > nextStateCheck then
		nextStateCheck = now + 0.0333

		mx, my = Spring.GetMouseState()
		-- deliberately not gated on showButtons: with auto-hide on, hovering the empty
		-- strip is what brings the buttons back
		hoveringButtons = buttonsArea[1] ~= nil
			and mathIsInRect(mx, my, buttonsArea[1], buttonsArea[2], buttonsArea[3], buttonsArea[4])

		local _, _, isPaused = Spring.GetGameSpeed()
		if not isPaused then
			if blinkDirection then
				blinkProgress = blinkProgress + (dt * 9)
				if blinkProgress > 1 then
					blinkProgress = 1
					blinkDirection = false
				end
			else
				blinkProgress = blinkProgress - (dt / (blinkProgress * 1.5))
				if blinkProgress < 0 then
					blinkProgress = 0
					blinkDirection = true
				end
			end
		end
	end

	if now > nextButtonCheck then
		nextButtonCheck = now + 0.5
		local signature = currentButtonSignature()
		if signature ~= buttonSignature then
			buttonSignature = signature
			refreshButtons = true
		end
	end
end

function widget:GameStart()
	gameStarted = true
	refreshButtons = true
end

function widget:GameOver()
	gameIsOver = true
	refreshButtons = true
end

function widget:PlayerChanged()
	spec = Spring.GetSpectatingState()
	myAllyTeamID = Spring.GetLocalAllyTeamID()
	myTeamID = Spring.GetLocalTeamID()
	myAllyTeamList = Spring.GetTeamList(myAllyTeamID)
	refreshButtons = true
end

function widget:LanguageChanged()
	refreshButtons = true
end

function widget:MouseRelease(x, y, button)
	if showQuitscreen and quitscreenArea then
		return true
	end
end

function widget:Initialize()
	if Spring.GetMenuName and string.find(string.lower(Spring.GetMenuName()), "chobby") then
		chobbyLoaded = true
		Spring.SendLuaMenuMsg("disableLobbyButton")
	end

	-- The quit/resign dialog counts as a window: while it is up, the handler can hide the
	-- rest of the interface (springsetting WindowsHideInterface), and this widget stays.
	widgetHandler:RegisterModalWindow(widget, function()
		return showQuitscreen ~= nil
	end)

	-- This widget was split out of "Top Bar", which used to persist the auto-hide setting.
	-- Adopt it once so the setting survives the split.
	if not configLoaded and widgetHandler.configData then
		local previous = widgetHandler.configData["Top Bar"]
		if previous and previous.autoHideButtons ~= nil then
			autoHideButtons = previous.autoHideButtons
			showButtons = not autoHideButtons
		end
	end

	-- Shared with the Top Bar widget: each fills in its own half, so either can run alone.
	WG.topbar = WG.topbar or {}

	WG.topbar.showingQuit = function()
		return showQuitscreen
	end

	WG.topbar.hideWindows = function()
		hideWindows()
	end

	WG.topbar.buttonAt = function(x, y)
		return buttonAt(x, y)
	end

	-- The strip's rect, for widgets that place themselves under or beside it (ecostats,
	-- the spectator HUD). Reports the geometry whether or not the buttons are currently
	-- drawn; ask getShowButtons() for that.
	WG.topbar.GetButtonsPosition = function()
		if not buttonsArea[1] then
			return nil
		end
		return { buttonsArea[1], buttonsArea[2], buttonsArea[3], buttonsArea[4], widgetScale }
	end

	WG.topbar.setAutoHideButtons = function(value)
		autoHideButtons = value
		showButtons = not value
		refreshButtons = true
	end

	WG.topbar.getAutoHideButtons = function()
		return autoHideButtons
	end

	WG.topbar.getShowButtons = function()
		return showButtons
	end

	widget:ViewResize()
	buttonSignature = currentButtonSignature()
end

function widget:Shutdown()
	removeFallbacks()

	if dlist.buttons then
		dlist.buttons = glDeleteList(dlist.buttons)
	end
	if dlist.background then
		if WG.guishader then
			WG.guishader.RemoveDlist("topbar_buttons")
		end
		dlist.background = glDeleteList(dlist.background)
	end
	if dlist.quit then
		if WG.guishader then
			WG.guishader.removeRenderDlist(dlist.quit)
			WG.guishader.setScreenBlur(false)
		end
		dlist.quit = glDeleteList(dlist.quit)
	end

	if WG.topbar then
		WG.topbar.showingQuit = nil
		WG.topbar.hideWindows = nil
		WG.topbar.buttonAt = nil
		WG.topbar.GetButtonsPosition = nil
		WG.topbar.setAutoHideButtons = nil
		WG.topbar.getAutoHideButtons = nil
		WG.topbar.getShowButtons = nil
		-- the Top Bar widget may still be using the table for its own half
		if next(WG.topbar) == nil then
			WG.topbar = nil
		end
	end
end

function widget:GetConfigData()
	return { autoHideButtons = autoHideButtons }
end

function widget:SetConfigData(data)
	configLoaded = true
	if data.autoHideButtons ~= nil then
		autoHideButtons = data.autoHideButtons
		showButtons = not autoHideButtons
	end
end
