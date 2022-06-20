--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_game_type_info.lua
--  brief:   informs players of the game type at start (i.e. Comends, lineage, com continues(killall) , commander control or commander mode)
--  author:  Riku Eischer
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--  Thanks to trepan (Dave Rodgers) for the original CommanderEnds widget
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "GameTypeInfo",
		desc = "informs players of the game type at start",
		author = "Teutooni",
		date = "Jul 6, 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = 0.80 + (vsx * vsy / 6000000)

local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glScale = gl.Scale
local glTranslate = gl.Translate
local spGetGameSeconds = Spring.GetGameSeconds

local message = ""
local message2 = ""
local message3 = ""

local font, chobbyInterface

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = (0.80 + (vsx * vsy / 6000000))

	font = WG['fonts'].getFont(nil, 1.5, 0.25, 1.25)
end

function widget:Initialize()
	widget:ViewResize()

	if Spring.GetModOptions().deathmode == "killall" then
		message = Spring.I18N('ui.gametypeInfo.killAllUnits')
	elseif Spring.GetModOptions().deathmode == "neverend" then
		widgetHandler:RemoveWidget()
	else
		message = Spring.I18N('ui.gametypeInfo.killAllCommanders')
	end

	if Spring.GetModOptions().preventcombomb then
		message2 = Spring.I18N('ui.gametypeInfo.commandersSurviveDgun')
	end

	if Spring.GetModOptions().unba then
		message3 = Spring.I18N('ui.gametypeInfo.unbalancedCommanders')
	end
end

local sec = 0
local blink = false
function widget:Update(dt)
	sec = sec + dt
	if sec > 1 then
		sec = sec - 1
	end
	if sec > 0.5 then
		blink = true
	else
		blink = false
	end
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
	if spGetGameSeconds() > 0 then
		widgetHandler:RemoveWidget()
		return
	end

	local msg = '\255\255\255\255' .. string.format("%s %s", Spring.I18N('ui.gametypeInfo.victoryCondition') .. ": ", message)
	local msg2 = '\255\255\255\255' .. message2
	local msg3
	if blink then
		msg3 = "\255\255\222\111" .. message3
	else
		msg3 = "\255\255\150\050" .. message3
	end

	glPushMatrix()
	glTranslate((vsx * 0.5), (vsy * 0.19), 0) --has to be below where newbie info appears!
	glScale(1.5, 1.5, 1)
	font:Begin()
	font:Print(msg, 0, 60 * widgetScale, 17.5 * widgetScale, "oc")
	font:Print(msg2, 0, -35 * widgetScale, 13 * widgetScale, "oc")
	font:Print(msg3, 0, 100 * widgetScale, 17.5 * widgetScale, "oc")
	if Spring.GetModOptions().deathmode == "own_com" then
		font:Print("\255\255\150\150" ..Spring.I18N('ui.gametypeInfo.owncomends'), 0, 40 * widgetScale, 13 * widgetScale, "oc")
	end
	--if Spring.GetModOptions().deathmode == "com" or Spring.GetModOptions().deathmode == "own_com" then
	--	font:Print("\255\255\150\150" ..Spring.I18N('ui.gametypeInfo.dgunrule'), 0, 40 * widgetScale, 13 * widgetScale, "oc")
	--	font:Print("\255\255\140\140" ..Spring.I18N('ui.gametypeInfo.dgunruleExplanation'), 0, 25 * widgetScale, 13 * widgetScale, "oc")
	--end
	font:End()
	glPopMatrix()
end

function widget:GameOver()
	widgetHandler:RemoveWidget()
end
