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

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local texts = {        -- fallback (if you want to change this, also update: language/en.lua, or it will be overwritten)
	killallunits = 'Kill all enemy units',
	killallcoms = 'Kill all enemy Commanders',
	comssurvivedguns = 'Commanders survive DGuns and commander explosions',
	unbacomsenabled = 'Unbalanced Commanders is enabled: Commander levels up and gain upgrades',
	victorycondition = 'Victory condition',
}

local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (0.80 + (vsx * vsy / 6000000))

local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glRotate = gl.Rotate
local glScale = gl.Scale
local glText = gl.Text
local glTranslate = gl.Translate
local spGetGameSeconds = Spring.GetGameSeconds

local floor = math.floor

local message = ""
local message2 = ""
local message3 = ""

local font, chobbyInterface

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = (0.80 + (vsx * vsy / 6000000))

	font = WG['fonts'].getFont(nil, 1, 0.2, 1.3)
end

function widget:Initialize()
	if WG['lang'] then
		texts = WG['lang'].getText('gametypeinfo')
	end
	widget:ViewResize()

	if Spring.GetModOptions().deathmode == "killall" then
		message = texts.killallunits
	elseif Spring.GetModOptions().deathmode == "neverend" then
		widgetHandler:RemoveWidget(self)
	else
		--if Spring.GetModOptions().deathmode=="com" then
		message = texts.killallcoms
	end

	if (tonumber(Spring.GetModOptions().preventcombomb) or 0) ~= 0 then
		message2 = texts.comssurvivedguns
	end

	if (Spring.GetModOptions().unba or "disabled") == "enabled" then
		message3 = texts.unbacomsenabled
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
		widgetHandler:RemoveWidget(self)
		return
	end

	local msg = '\255\255\255\255' .. string.format("%s %s", texts.victorycondition..": ", message)
	local msg2 = '\255\255\255\255' .. message2
	local msg3
	if blink then
		msg3 = "\255\255\222\111" .. message3
	else
		msg3 = "\255\255\150\050" .. message3
	end

	glPushMatrix()
	glTranslate((vsx * 0.5), (vsy * 0.18), 0) --has to be below where newbie info appears!
	glScale(1.5, 1.5, 1)
	font:Begin()
	font:Print(msg, 0, 15 * widgetScale, 18 * widgetScale, "oc")
	font:Print(msg2, 0, -35 * widgetScale, 12.5 * widgetScale, "oc")
	font:Print(msg3, 0, 60 * widgetScale, 18 * widgetScale, "oc")
	font:End()
	glPopMatrix()
end

function widget:GameOver()
	widgetHandler:RemoveWidget(self)
end
