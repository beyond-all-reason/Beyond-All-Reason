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

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- SETTINGS, internal, don't edit
--------------------------------------------------------------------------------
local volume
local TextDraw            		 			= fontHandler.Draw
local vsx,vsy                    			= gl.GetViewSizes()
local widgetPosX 							= vsx/3
local widgetPosY 							= vsy/6
local pressedToMove		 					= false
local dt									= -1
--------------------------------------------------------------------------------
-- SETTINGS, configurable
--------------------------------------------------------------------------------
local TEST_SOUND 							= LUAUI_DIRNAME .. 'sounds/volume_osd/pop.wav'
local font         							= "luaui/fonts/freesansbold_14"
local step 									= 2 -- how many steps to change sound volume on one key press
local pluskey								= 270 -- numpad+ (look in uikeys.txt in spring folder for key symbols)
local minuskey								= 269 -- numpad-
local pluskey2								= 61 -- +key (duplicate key for volume+, set to same as primary to disable)
local minuskey2								= 45 -- -key  
local dtime									= 3 --How long time the volume display is drawn, in seconds
local ftime 								= 2.5 --How long time before the volume display starts fading, in seconds
local widgetWidth							= vsx/2.5 -- in pixels (changed from 400)
local widgetHeight							= vsy/25.6 -- in pixels (changed from 40)
local rectangles 							= 50 -- number of boxes in volume bar
local boxspacing 							= 2 -- space between boxes
local red									= 0.1 -- volume bar colour, 0 to 1.
local green									= 0.7 -- volume bar colour, 0 to 1.
local blue									= 0 -- volume bar colour, 0 to 1.
--------------------------------------------------------------------------------

function widget:Initialize()
  volume = Spring.GetConfigInt("snd_volmaster", 60)
  fontHandler.UseFont(font)
end

function widget:KeyPress(key, mods, isRepeat)
	if (key == pluskey or key == pluskey2) and (not mods.alt) and (not mods.shift) then -- KEY = pluskey
		volume = Spring.GetConfigInt("snd_volmaster", 60)
		volume = volume + step
		if volume < 0 then volume = 0 end
		if volume > 100 then volume = 100 end
		Spring.SetConfigInt("snd_volmaster", volume)
		--Spring.Echo("Volume = " .. volume)
		if not isRepeat then Spring.PlaySoundFile(TEST_SOUND, 1.0) end
		dt = os.clock()
		return true		
	elseif (key == minuskey or key == minuskey2) and (not mods.alt) and (not mods.shift) then -- KEY = minuskey
		volume = Spring.GetConfigInt("snd_volmaster", 60)
		volume = volume - step
		if volume < 0 then volume = 0 end
		if volume > 100 then volume = 100 end
		Spring.SetConfigInt("snd_volmaster", volume)
		--Spring.Echo("Volume = " .. volume)
		if not isRepeat then Spring.PlaySoundFile(TEST_SOUND, 1.0) end
		dt = os.clock()
		return true
	end
	return false
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
			gl.Color(0,0,0,0.1*alpha)                              -- draws background rectangle
			gl.Rect(x1,y1,x2-1,y2)
			gl.Color(0.5,1,0.5,alpha)
			TextDraw("Volume: ".. volume .. "%",x1+5,y2+5)
			gl.Color(0.3,0.3,0.3,0.6*alpha)                              -- draws empty rectangles
			
			for i = 1,rectangles do
				local u1 = x1+(i-1)*boxwidth
				local u2= u1+boxwidth-boxspacing
				gl.Rect(u1,y1,u2,y2)
			end
			
			local vol2 = math.floor(volume/(100/rectangles))
			gl.Color(0,0.8,0,alpha)                              -- draws filled rectangles
			for i = 1,vol2 do
				local u1 = x1+(i-1)*boxwidth
				local u2= u1+boxwidth-boxspacing
				gl.Color(red,green,blue,alpha)                              
				gl.Rect(u1+1,y1+1,u1+2,y2-1)
				gl.Color(red*1.2,green*1.2,blue*1.2,alpha)                              
				gl.Rect(u1+2,y1+1,u2-1,y2-1)
			end
		end
	end

function widget:TweakDrawScreen()
	local y1 = widgetPosY 
	local y2 = widgetPosY + widgetHeight
	local x1 = widgetPosX
	local x2 = widgetPosX + widgetWidth
	fontHandler.UseFont(font)
	gl.Color(0,0,0.5,1)
	gl.Rect(x1-1,y1-1,x1,y2+1)
	gl.Rect(x2-1,y1-1,x2,y2+1)
	gl.Rect(x1-1,y1-1,x2,y1)
	gl.Rect(x1-1,y2,x2,y2+1)
	gl.Color(0.5,1,0.5,1)
	TextDraw("Volume: ".. volume .. "%",x1+5,y2+5)
	gl.Color(0,0,0,0.2)                              -- draws empty rectangles
	for i = 1,40 do
		local u1 = x1+(i-1)*10
		local u2= u1+8
		gl.Rect(u1,y1,u2,y2)
	end
	
	local vol2 = math.floor(volume/2.5)
	gl.Color(0,0.8,0,1)                              -- draws filled rectangles
	for i = 1,vol2 do
		local u1 = x1+(i-1)*10
		local u2= u1+8
		gl.Rect(u1+1,y1+1,u2-1,y2-1)
	end	
end

	-----------------
	-- AID --
	-----------------

function widget:TweakMouseMove(x,y,dx,dy,button)
		if pressedToMove then
		if moveStartX == nil then                                                      -- move widget on y axis
			moveStartX = x - widgetPosX
		end
		if moveStartY == nil then                                                      -- move widget on y axis
			moveStartY = y - widgetPosY
		end
		widgetPosX = widgetPosX + dx
		widgetPosY = widgetPosY + dy

		if widgetPosY <= 0 then
			widgetPosY = 0
		end
		if widgetPosY + widgetHeight >= vsy then
			widgetPosY = vsy - widgetHeight
		end
		if widgetPosX < 5 then
			widgetPosX = 5
		end
		if widgetPosX + widgetWidth + 5 > vsx then
			widgetPosX = vsx - widgetWidth - 5
		end
	end
	
end

function widget:TweakMousePress(x, y, button)
	if button == 1 then
		if IsOnButton(x,y,widgetPosX,widgetPosY,widgetPosX+widgetWidth,widgetPosY+widgetHeight) then
			pressedToMove = true
			return true
		end
	else
		return false
	end
end

function widget:TweakMouseRelease(x,y,button)
	pressedToMove = false                                             
end

function IsOnButton(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	if BLcornerX == nil then return false end
	-- check if the mouse is in a rectangle

	return x >= BLcornerX and x <= TRcornerX
						  and y >= BLcornerY
						  and y <= TRcornerY

end

	-----------------
	-- SAVE/LOAD --
	-----------------

function widget:GetConfigData(data)      -- save
	return {
		widgetPosX         = widgetPosX,
		widgetPosY         = widgetPosY,
	}
end

function widget:SetConfigData(data)      -- load
	widgetPosX         	= data.widgetPosX or widgetPosX
	widgetPosY         	= data.widgetPosY or widgetPosY
end
