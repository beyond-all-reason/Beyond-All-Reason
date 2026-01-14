--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    	snd_volume_osd.lua
--  brief:   	volume control OSD
-- version: 	1.1
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Volume OSD",
		desc = "A sound control OSD",
		author = "Jools",
		date = "Jan 10, 2012",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end


-- Localized Spring API for performance
local spEcho = Spring.Echo

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- SETTINGS, internal, don't edit
--------------------------------------------------------------------------------
local volume
local vsx, vsy = gl.GetViewSizes()
local widgetPosX = vsx / 2.5
local widgetPosY = vsy / 7.5
local pressedToMove = false
local dt = -1

--------------------------------------------------------------------------------
-- SETTINGS, configurable
--------------------------------------------------------------------------------
local TEST_SOUND = 'LuaUI/sounds/volume_osd/pop.wav'
local step = 8 -- how many steps to change sound volume on one key press
local dtime = 3 --How long time the volume display is drawn, in seconds
local ftime = 2.5 --How long time before the volume display starts fading, in seconds
local widgetWidth = vsx / 4.5 -- in pixels (changed from 400)
local widgetHeight = vsy / 27 -- in pixels (changed from 40)
local rectangles = 25 -- number of boxes in volume bar
local boxspacing = 5 -- space between boxes
local red = 0.1 -- volume bar colour, 0 to 1.
local green = 0.7 -- volume bar colour, 0 to 1.
local blue = 0 -- volume bar colour, 0 to 1.
--------------------------------------------------------------------------------

local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local RectRound

local function sndVolumeIncreaseHandler(_, _, _, _, isRepeat)
	volume = Spring.GetConfigInt("snd_volmaster", 80)
	volume = volume + step
	if volume < 0 then
		volume = 0
	end
	if volume > 200 then
		volume = 200
	end
	Spring.SetConfigInt("snd_volmaster", volume)
	--spEcho("Volume = " .. volume)
	if not isRepeat then
		Spring.PlaySoundFile(TEST_SOUND, 1.0, 'ui')
	end
	dt = os.clock()
	return true
end

local function sndVolumeDecreaseHandler(_, _, _, _, isRepeat)
	volume = Spring.GetConfigInt("snd_volmaster", 80)
	volume = volume - step
	if volume < 0 then
		volume = 0
	end
	if volume > 200 then
		volume = 200
	end
	Spring.SetConfigInt("snd_volmaster", volume)
	--spEcho("Volume = " .. volume)
	if not isRepeat then
		Spring.PlaySoundFile(TEST_SOUND, 1.0, 'ui')
	end
	dt = os.clock()
	return true
end

function widget:Initialize()
	volume = Spring.GetConfigInt("snd_volmaster", 60)

	widgetHandler:AddAction("snd_volume_increase", sndVolumeIncreaseHandler, nil, 'pR')
	widgetHandler:AddAction("snd_volume_decrease", sndVolumeDecreaseHandler, nil, 'pR')

	widget:ViewResize(vsx, vsy)
end



function widget:DrawScreen()
	local y1 = widgetPosY
	local y2 = widgetPosY + widgetHeight
	local x1 = widgetPosX
	local x2 = widgetPosX + widgetWidth
	local ostime = os.clock()
	local t = ostime - dt
	local boxwidth = widgetWidth / rectangles

	if t < dtime and dt >= 0 then
		--dtime = 3
		local alpha
		if t < ftime then
			--ftime = 2
			alpha = 1
		else
			alpha = 3 * (dtime - t) / dtime
		end

		local padding = boxwidth / 17
		for i = 1, rectangles do
			local u1 = x1 + (i - 1) * boxwidth
			local u2 = u1 + boxwidth - boxspacing
			--gl.Rect(u1,y1,u2,y2)
			RectRound(u1, y1, u2, y2, (u2 - u1) / 4, 1, 1, 1, 1, { 0.1, 0.1, 0.1, 0.6 * alpha }, { 0, 0, 0, 0.4 * alpha })
			RectRound(u1 + padding, y1 + padding, u2 - padding, y2 - padding, (u2 - u1) / 5.5, 1, 1, 1, 1, { 1, 1, 1, 0.035 * alpha }, { 1, 1, 1, 0.02 * alpha })
		end
		local vol2 = math.floor((volume / (100 / rectangles)) / 2)
		gl.Color(0, 0.85, 0, alpha)                              -- draws filled rectangles
		local spacer2 = boxwidth / 10
		for i = 1, vol2 do
			local u1 = x1 + (i - 1) * boxwidth
			local u2 = u1 + boxwidth - boxspacing
			RectRound(u1 + spacer2, y1 + spacer2, u2 - spacer2, y2 - spacer2, ((u2 - spacer2) - (u1 + spacer2)) / 5.5, 1, 1, 1, 1, { 0, 0.5, 0, alpha * 0.8 }, { 0, 1, 0, alpha * 0.8 })
			RectRound(u1 + spacer2 + padding, y1 + spacer2 + padding, u2 - spacer2 - padding, y2 - spacer2 - padding, ((u2 - spacer2) - (u1 + spacer2)) / 6.5, 1, 1, 1, 1, { 1, 1, 1, alpha * 0.25 }, { 1, 1, 1, alpha * 0.25 })
			-- gloss
			glBlending(GL_SRC_ALPHA, GL_ONE)
			RectRound(u1 + spacer2, y2 - spacer2 - ((y2 - y1) * 0.23), u2 - spacer2, y2 - spacer2, ((u2 - spacer2) - (u1 + spacer2)) / 5.5, 1, 1, 0, 0, { 1, 1, 1, alpha * 0.035 }, { 1, 1, 1, alpha * 0.13 })
			RectRound(u1 + spacer2, y1 + spacer2, u2 - spacer2, y1 + spacer2 + ((y2 - y1) * 0.13), ((u2 - spacer2) - (u1 + spacer2)) / 5.5, 0, 0, 1, 1, { 1, 1, 1, alpha * 0.05 }, { 1, 1, 1, alpha * 0 })
			glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		end
	end
end

function IsOnButton(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
	if BLcornerX == nil then
		return false
	end
	-- check if the mouse is in a rectangle

	return x >= BLcornerX and x <= TRcornerX
		and y >= BLcornerY
		and y <= TRcornerY
end

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx = viewSizeX
	vsy = viewSizeY

	widgetWidth = vsx / 4.5 -- in pixels (changed from 400)
	widgetHeight = vsy / 27 -- in pixels (changed from 40)

	widgetPosX = vsx / 2.5
	widgetPosY = vsy / 7.5

	RectRound = WG.FlowUI.Draw.RectRound
end
