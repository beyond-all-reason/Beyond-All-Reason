--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    	snd_volume_osd.lua
--  brief:   	volume control OSD
-- version: 	1.1
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Volume OSD",
    desc      = "A sound control OSD",
    author    = "Jools",
    date      = "Jan 10, 2012",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

include('keysym.h.lua')
local pluskey								= KEYSYMS.PLUS 
local equalskey								= KEYSYMS.EQUALS -- same key as + on most qwerty keyboards
local minuskey								= KEYSYMS.MINUS 
local pluskey2								= KEYSYMS.KP_PLUS 
local minuskey2								= KEYSYMS.KP_MINUS 

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- SETTINGS, internal, don't edit
--------------------------------------------------------------------------------
local volume
local TextDraw            		 			= fontHandler.Draw
local vsx,vsy                    			= gl.GetViewSizes()
local widgetPosX 							= vsx/2.5
local widgetPosY 							= vsy/7.5
local pressedToMove		 					= false
local dt									= -1
local bgcorner = "LuaUI/Images/bgcorner.png"
--------------------------------------------------------------------------------
-- SETTINGS, configurable
--------------------------------------------------------------------------------
local TEST_SOUND 							= 'LuaUI/sounds/volume_osd/pop.wav'
local font         							= "luaui/fonts/freesansbold_14"
local step 									= 8 -- how many steps to change sound volume on one key press
local dtime									= 3 --How long time the volume display is drawn, in seconds
local ftime 								= 2.5 --How long time before the volume display starts fading, in seconds
local widgetWidth							= vsx/4.5 -- in pixels (changed from 400)
local widgetHeight							= vsy/27 -- in pixels (changed from 40)
local rectangles 							= 25 -- number of boxes in volume bar
local boxspacing 							= 5 -- space between boxes
local red									= 0.1 -- volume bar colour, 0 to 1.
local green									= 0.7 -- volume bar colour, 0 to 1.
local blue									= 0 -- volume bar colour, 0 to 1.
--------------------------------------------------------------------------------

function widget:Initialize()
  volume = Spring.GetConfigInt("snd_volmaster", 60)
  fontHandler.UseFont(font)
end

function widget:KeyPress(key, mods, isRepeat)
	if (key == pluskey or key == pluskey2 or key == equalskey) and (not mods.alt) and (not mods.shift) then -- KEY = pluskey
		volume = Spring.GetConfigInt("snd_volmaster", 80)
		volume = volume + step
		if volume < 0 then volume = 0 end
		if volume > 200 then volume = 200 end
		Spring.SetConfigInt("snd_volmaster", volume)
		--Spring.Echo("Volume = " .. volume)
		if not isRepeat then Spring.PlaySoundFile(TEST_SOUND, 1.0, 'ui') end
		dt = os.clock()
		return true		
	elseif (key == minuskey or key == minuskey2) and (not mods.alt) and (not mods.shift) then -- KEY = minuskey
		volume = Spring.GetConfigInt("snd_volmaster", 80)
		volume = volume - step
		if volume < 0 then volume = 0 end
		if volume > 200 then volume = 200 end
		Spring.SetConfigInt("snd_volmaster", volume)
		--Spring.Echo("Volume = " .. volume)
		if not isRepeat then Spring.PlaySoundFile(TEST_SOUND, 1.0, 'ui') end
		dt = os.clock()
		return true
	end
	return false
end

function RectRound(px,py,sx,sy,cs)
	
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.floor(sx),math.floor(sy),math.floor(cs)
	
	gl.Rect(px+cs, py, sx-cs, sy)
	gl.Rect(sx-cs, py+cs, sx, sy-cs)
	gl.Rect(px+cs, py+cs, px, sy-cs)
	
	if py <= 0 or px <= 0 then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(px, py+cs, px+cs, py)		-- top left
	
	if py <= 0 or sx >= vsx then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(sx, py+cs, sx-cs, py)		-- top right
	
	if sy >= vsy or px <= 0 then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(px, sy-cs, px+cs, sy)		-- bottom left
	
	if sy >= vsy or sx >= vsx then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(sx, sy-cs, sx-cs, sy)		-- bottom right
	
	gl.Texture(false)
end

function widget:DrawScreen()
	local y1 = widgetPosY 
	local y2 = widgetPosY + widgetHeight
	local x1 = widgetPosX
	local x2 = widgetPosX + widgetWidth
	local ostime = os.clock()
	local t = ostime - dt
	local boxwidth = widgetWidth/rectangles
	
	fontHandler.UseFont(font)
	
	if t < dtime and dt >= 0 then --dtime = 3
		local alpha
		if t < ftime then --ftime = 2
			alpha = 1
		else
			alpha = 3*(dtime-t)/dtime
		end
		
		gl.Color(0,0,0,0.25*alpha)                              -- draws empty rectangles
		for i = 1,rectangles do
			local u1 = x1+(i-1)*boxwidth
			local u2= u1+boxwidth-boxspacing
			--gl.Rect(u1,y1,u2,y2)
			RectRound(u1,y1,u2,y2,(u2-u1)/3)
		end
		local vol2 = math.floor((volume/(100/rectangles))/2)
		gl.Color(0,0.85,0,alpha)                              -- draws filled rectangles
		local spacer2 = boxwidth / 10
		gl.Color(0.2,1,0.2,alpha*0.8)   
		for i = 1,vol2 do
			local u1 = x1+(i-1)*boxwidth
			local u2= u1+boxwidth-boxspacing            
			RectRound(u1+spacer2,y1+spacer2,u2-spacer2,y2-spacer2,((u2-spacer2)-(u1+spacer2))/4)
		end
	end
end


function IsOnButton(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	if BLcornerX == nil then return false end
	-- check if the mouse is in a rectangle

	return x >= BLcornerX and x <= TRcornerX
						  and y >= BLcornerY
						  and y <= TRcornerY
end


function widget:ViewResize(viewSizeX, viewSizeY)
	vsx = viewSizeX
	vsy = viewSizeY
	
	widgetWidth		= vsx/4.5 -- in pixels (changed from 400)
	widgetHeight	= vsy/27 -- in pixels (changed from 40)
	
	widgetPosX 							= vsx/2.5
	widgetPosY 							= vsy/7.5
end
